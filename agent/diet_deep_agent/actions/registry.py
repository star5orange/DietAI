"""V5.0 动作注册表（Tool Registry，PRD 4.1 核心交互层）。

职责：
1. 注册动作（ActionSpec + handler）
2. 生成 LLM 可调用的工具：入参 schema 来自 spec.args_schema；
   user_id / thread_id / is_pet_session 由 Router 通过 config.configurable 注入，
   不进入 LLM 入参 schema（避免模型编造或串号）
3. 生成 System Prompt 中的"可用动作清单 + 授权/撤销规则"段落

V6 扩展方式：在 definitions/ 下新增动作模块并实现 register(registry)，本文件不改。
"""

import logging
from typing import Any, Awaitable, Callable, Optional

from langchain_core.runnables import RunnableConfig
from langchain_core.tools import BaseTool, StructuredTool
from pydantic import BaseModel

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.spec import ActionKind, ActionResult, ActionSpec

logger = logging.getLogger(__name__)

# 动作实现签名：handler(入参模型, 运行期上下文) -> 统一结果
ActionHandler = Callable[[BaseModel, ActionContext], Awaitable[ActionResult]]


class ActionRegistry:
    """动作注册表：注册 / 查询 / 生成工具 / 生成 Prompt 段落"""

    def __init__(self) -> None:
        self._specs: dict[str, ActionSpec] = {}
        self._handlers: dict[str, ActionHandler] = {}

    # ---------- 注册 ----------
    def register(self, spec: ActionSpec, handler: ActionHandler) -> None:
        if spec.name in self._specs:
            raise ValueError(f"动作已注册，请检查重复定义: {spec.name}")
        self._specs[spec.name] = spec
        self._handlers[spec.name] = handler

    # ---------- 查询 ----------
    def get(self, name: str) -> Optional[ActionSpec]:
        return self._specs.get(name)

    def handler(self, name: str) -> Optional[ActionHandler]:
        return self._handlers.get(name)

    def all(self) -> list[ActionSpec]:
        """按注册顺序返回全部动作"""
        return list(self._specs.values())

    @property
    def names(self) -> list[str]:
        return list(self._specs.keys())

    # ---------- LLM 工具 ----------
    def langchain_tools(self) -> list[BaseTool]:
        """把已注册动作转换为可挂到 Agent 上的工具列表"""
        return [self._build_tool(spec) for spec in self.all()]

    def _build_tool(self, spec: ActionSpec) -> BaseTool:
        handler = self._handlers[spec.name]

        async def _invoke(config: RunnableConfig = None, **kwargs: Any) -> str:
            """执行注册表动作：config 由运行时注入（语法上不在 args_schema 中）"""
            ctx = ActionContext.from_config(config)
            try:
                params = spec.args_schema(**kwargs)
            except Exception as e:
                return ActionResult.failure(spec.name, f"入参不合法：{e}").to_tool_output()
            try:
                result = await handler(params, ctx)
            except Exception as e:
                logger.exception(f"动作执行异常: {spec.name}")
                return ActionResult.failure(spec.name, f"执行失败：{e}").to_tool_output()
            if not isinstance(result, ActionResult):
                return ActionResult.failure(
                    spec.name, "动作返回值不符合 ActionResult 协议"
                ).to_tool_output()
            return result.to_tool_output()

        _invoke.__name__ = f"action_{spec.name}"
        return StructuredTool.from_function(
            coroutine=_invoke,
            args_schema=spec.args_schema,
            name=spec.name,
            description=spec.tool_description(),
        )

    # ---------- Prompt ----------
    def prompt_section(self, session: str = "human") -> str:
        """生成 System Prompt 的动作清单与授权/撤销规则（单一事实来源，避免文档与实现两处维护）

        session：会话域过滤（PRD D18）。human=人/家人对话（默认），pet=宠物模式；
        只有 spec.sessions 含该域的动作才会出现在提示词里。
        """
        lines = [
            "## 可执行动作（Tool Registry）",
            "以下动作已绑定当前用户上下文，调用时不要（也不需要）传 user_id。",
        ]
        for spec in self.all():
            if session not in spec.sessions:
                continue
            tags = ["查询" if spec.kind is ActionKind.QUERY else "写操作"]
            if spec.requires_confirmation:
                tags.append("叙述性输入需先确认")
            if spec.undoable:
                tags.append("可撤销")
            lines.append(f"- {spec.name}（{'、'.join(tags)}）：{spec.description.strip()}")
            if spec.examples:
                lines.append(f"  典型说法：{'；'.join(spec.examples)}")
        lines.extend(
            [
                "",
                "### 授权与撤销规则",
                "- 叙述性表述（如「我中午吃了宫保鸡丁」）：先问一句「要帮你记录吗？」，用户确认后再调用写操作；",
                "  明确指令（如「帮我记录：…」）：直接执行写操作，展示结果并告知可撤销（PRD 4.2）。",
                "- 写操作返回带 undo_token 时，回复末尾提示用户「10 分钟内可撤销」。",
                "- 用户说「撤销 / 刚才那条记错了」时调用 undo；若返回失败（超过 10 分钟或不是最近一条），",
                "  按结果里的提示告知用户「该条已超过可撤销时间或不是最近一条，如需修改请在对应页面操作」，不要自行改数据（PRD 4.5）。",
                "- **只有用户本轮明确表达撤销意图时才能调用 undo**：不得为了「修正份量 / 重录 / 营养没匹配上 / 换一种记法」",
                "  而自行撤销刚写入的记录。需要修正时直接再用对应的记录动作写入正确数据，并在回复中说明修正内容；",
                "  若确实需要撤销旧记录，先问用户一句「要撤销刚才那条吗？」，得到确认后再调用 undo。",
                "- 多动作批量执行时，单项失败不回滚其它成功项，明确告知失败项并支持重试（PRD 4.6）。",
                "- **对话不支持发送图片**：用户在对话框里无法发照片。需要图片识别时"
                "（食物库未命中、用户想拍菜），引导用户使用 App 首页的「拍照记录」相机入口，",
                "  由 AI 图像分析自动补营养并落库；需要上传体检报告时（低频操作），引导去「体检」页"
                "  的上传入口（页面自带隐私提醒与 AI 分析开关，默认仅本地存储）；",
                "  绝不要说「拍一张照片发我」这类对话里做不到的操作（PRD 4.9）。",
                "",
                "### 模糊量词与待确认卡（PRD 4.3 / 4.4）",
                "- 用户用了模糊量词（一瓶水、一碗饭、一杯牛奶…）时，动作会返回 card_type=pending_confirm 的待确认卡，",
                "  卡里带 options 快捷选项。此时只需用一句话复述问题并提示点选（如「一瓶水大概多少毫升？」），",
                "  **不要自己在文本里替用户假定数值**，也不要重复调用同一个动作。",
                "- **量词的可选数值一律以卡片 options 为准**：不要在回复里自行列举「350ml / 500ml / 600ml」这类备选，",
                "  更不要跳过动作、自己收集数值后再记录（选项口径由注册表统一维护）。",
                "- 用户下一轮回答的是待确认卡的选项时（如「500ml」「一碗」），直接按该数值调用卡里的 data.action",
                "  （把值填进 data.field，其余用 data.params），不要再次追问。",
                "- 明确指令 + 模糊量词混合时：明确项立即执行，模糊项出待确认卡，不阻塞、不啰嗦（PRD 4.4）。",
                "",
                "### 卡片与文字分工（PRD 4.8）",
                "- 查询类动作出卡片（今日汇总卡 / 趋势卡 / 家人状态卡 / 周报卡 / 成本卡等）后，文字回复只留一句话",
                "  （过渡或引导下一步，如「这是你今天的饮食情况，点『查看详情』看细分」）。",
                "- **不要把卡里的热量 / 饮水 / 餐次等数字在文本里复述一遍**——数据由卡片承载，细节留给页面，",
                "  对话里堆数据会让卡片和文字互相重复（PRD 4.8 呈现原则）。",
                "- 「我今天吃了…」「今天吃了多少」这类饮食查询，即使以纯文字回答（未出卡或卡片数据缺失）也要短：",
                "  一两句话先给结论（如「今天吃了 3 餐，共约 1450 大卡」），不逐餐罗列菜名、不展开营养分析；",
                "  明细引导用户看卡片或去记录页，用户要的是一眼看到答案，不是读一篇小作文。",
            ]
        )
        return "\n".join(lines)