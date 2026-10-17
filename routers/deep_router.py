"""
DietDeepAgent 统一 API 路由

提供 DietDeepAgent 的 HTTP 端点：
- POST /api/deep/chat          统一对话入口（文字 + 可选「包装食品成分表」照片）
- POST /api/deep/analyze        食物图像分析
- POST /api/deep/actions/undo   卡片「撤销」直调（最近一条 + 10 分钟窗口）
- POST /api/deep/actions/confirm 确认卡「帮我记录」直调（按卡片原参数落库，凭证券后作废）
- GET  /api/deep/daily-status   今日营养状态
- GET  /api/deep/memory/{uid}   查看用户记忆（调试用）
"""

import asyncio
import json
import logging
import re
import uuid
from datetime import datetime
from typing import Any, AsyncGenerator, Optional

from fastapi import APIRouter, Depends, HTTPException, Form, UploadFile, File, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from shared.models import conversation_models, user_models
from shared.models.database import get_db
from shared.utils.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/deep", tags=["DietDeepAgent"])


async def _resolve_deep_chat_params(
    request: Request,
    message: str,
    session_id: Optional[str],
    input_channel: str = "app",
) -> tuple[str, Optional[str], Optional[str], str, Optional[str]]:
    body: dict[str, Any] = {}
    content_type = request.headers.get("content-type", "") if request else ""

    try:
        if request and "application/json" in content_type:
            payload = await request.json()
            if isinstance(payload, dict):
                body = payload
        elif request and "form" in content_type:
            form = await request.form()
            body = dict(form)
    except Exception:
        body = {}

    session_type = str(body.get("session_type", "")) if body.get("session_type") is not None else None
    # 输入渠道（PRD 4.9）：app（默认，文本/语音）/ hardware（宠物时钟等硬件语音）。
    # 老人线渠道在模糊量词上走「默认值记录 + 事后可改」，因此必须一路传到动作上下文。
    channel = (
        str(body.get("input_channel") or "").strip()
        or str(input_channel or "").strip()
        or "app"
    )
    # 可选：包装食品成分表照片（base64，不含 data URI 前缀）。
    # 对话里图片只有「成分表评价」一种语义，故不额外传 image_purpose，
    # OCR 的 is_packaged_food 已足够区分走评价还是走「请改用餐食识别」引导。
    raw_image = body.get("image_base64")
    image_base64 = raw_image.strip() if isinstance(raw_image, str) and raw_image.strip() else None
    return (
        str(body.get("message", message) or ""),
        body.get("session_id", session_id),
        session_type,
        channel,
        image_base64,
    )


# 老人线硬件语音渠道例外（PRD 4.3 / D13）：
# App 端 System Prompt 的"叙述先确认 / 模糊量词追问"规则对硬件语音不适用，
# 不追加该段时 LLM 会照 App 规则追问，老人线"默认值记录 + 事后可改"落空。
ELDER_CHANNEL_PROMPT = """

## 老人线硬件语音渠道例外（PRD 4.3 / D13）
当前输入来自硬件语音渠道（input_channel=hardware），交互规则与 App 端不同：
- 不要向用户追问、不要等待确认：叙述性输入（如「我吃了…」「我喝了…」）直接调用对应的写操作动作执行；
- 模糊量词（一瓶水、一碗饭…）不要询问具体数值：直接调用动作，动作内部会按默认值记录并返回结果卡；
- 回复务必简短、口语化、长辈友好：不要表格、不要长段落、不要堆砌专业术语。
"""


def _get_agent():
    """延迟加载 DietDeepAgent"""
    from agent.diet_deep_agent.deep_agent import create_diet_deep_agent
    return create_diet_deep_agent()


# 缓存 agent 实例
_cached_agent = None


def _get_cached_agent():
    global _cached_agent
    if _cached_agent is None:
        _cached_agent = _get_agent()
    return _cached_agent


def _build_user_health_context(user_id: int) -> str:
    """构建用户健康档案上下文（实现已迁至 shared/services/user_health_context.py，
    与康复建议共用同一份口径）。保留此薄封装以维持既有调用点不变。"""
    from shared.services.user_health_context import build_user_health_context

    return build_user_health_context(user_id)


def _load_action_names() -> set[str]:
    """动作注册表内的动作名（只有这些工具的返回才作为卡片透传）"""
    from agent.diet_deep_agent.actions import registry as action_registry

    return set(action_registry.names)


# 需要伴随文字下发的卡片类型：待确认卡的文字本身就是追问与分析
# （PRD 4.3 量词追问、叙述性提及的饮食分析），吞掉文字用户就只剩一张卡。
# 其余卡片（今日汇总/趋势等）「卡片即结果」，文字仅落库不复述（PRD 4.8）。
TEXT_WITH_CARD_TYPES = {"pending_confirm"}


def _parse_action_card(msg: Any, action_names: set[str]) -> Optional[dict[str, Any]]:
    """把动作工具返回的 ToolMessage 解析为卡片负载。

    只有注册表动作且执行成功、card_type 非 text 时才产出卡片；
    失败结果（ok=false）交给模型在文本里解释，不单独出卡。
    """
    if getattr(msg, "type", "") != "tool":
        return None
    if (getattr(msg, "name", "") or "") not in action_names:
        return None
    content = getattr(msg, "content", "")
    if not isinstance(content, str) or not content.strip():
        return None
    try:
        payload = json.loads(content)
    except (TypeError, ValueError):
        return None
    if not isinstance(payload, dict) or not payload.get("ok"):
        return None
    if payload.get("card_type") in (None, "text"):
        return None
    return payload


def _is_failed_action(msg: Any, action_names: set[str]) -> bool:
    """注册表动作执行失败（ok=false）的 ToolMessage。

    失败不出卡、由模型文字解释（PRD 4.6 部分失败），因此文字不能吞。
    """
    if getattr(msg, "type", "") != "tool":
        return False
    if (getattr(msg, "name", "") or "") not in action_names:
        return False
    content = getattr(msg, "content", "")
    if not isinstance(content, str) or not content.strip():
        return False
    try:
        payload = json.loads(content)
    except (TypeError, ValueError):
        return False
    return isinstance(payload, dict) and payload.get("ok") is False


def _message_text(msg: Any) -> str:
    """提取消息文本（兼容多模态 content 块）"""
    content = getattr(msg, "content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict) and block.get("type") == "text":
                parts.append(str(block.get("text", "")))
        return "".join(parts)
    return ""


# ---------- 成分表评价（对话内发送包装食品成分表照片）----------

_LABEL_REVIEW_DEFAULT_ASK = "请帮我评价这张成分表，并结合我的健康档案告诉我适不适合买。"

# OCR 字段 → 中文标签与单位（元组顺序即展示顺序）
_LABEL_NUTRIENTS = (
    ("calories_per_100g", "能量", "kcal"),
    ("protein_per_100g", "蛋白质", "g"),
    ("fat_per_100g", "脂肪", "g"),
    ("carbs_per_100g", "碳水化合物", "g"),
    ("sugar_per_100g", "糖", "g"),
    ("fiber_per_100g", "膳食纤维", "g"),
    ("sodium_per_100g", "钠", "mg"),
)

# 落库列名（与 OCR 字段同名，直接展开进模型构造）
_REVIEW_NUMERIC_FIELDS = (
    "serving_size_g",
    "calories_per_100g",
    "protein_per_100g",
    "fat_per_100g",
    "carbs_per_100g",
    "sugar_per_100g",
    "fiber_per_100g",
    "sodium_per_100g",
)

# 模型按提示词约定在末行输出机器可读结论；取不到则 verdict 为 None
_VERDICT_PATTERN = re.compile(r"【购买建议】\s*(推荐购买|谨慎购买|不推荐购买)")


def _fmt_label_value(value: Any, unit: str) -> str:
    """把 OCR 数值渲染成「12 g」，未识别统一写「未标注」（不写 null 以免模型误解）"""
    if value is None:
        return "未标注"
    try:
        num = float(value)
    except (TypeError, ValueError):
        return "未标注"
    text = f"{num:.0f}" if num == int(num) else f"{num:.1f}"
    return f"{text} {unit}"


def _clip_text(value: Any, limit: int) -> Optional[str]:
    """截断超长文本，避免超出 DB 列长度导致落库失败"""
    if not value:
        return None
    text = str(value).strip()
    return text[:limit] or None


def _build_label_review_text(user_text: str, label: dict) -> str:
    """把成分表 OCR 结果拼成本轮 Agent 可见的文本。

    图片本体绝不进入 Agent 消息（markdown checkpoint 无裁剪，base64 会让存档膨胀），
    只注入结构化文本。三种形态：
    - is_packaged_food=True  → 完整结构化数值 + 用户诉求，走「成分表评价」规则
    - is_packaged_food=False → 说明不是预包装食品，引导改用餐食识别
    - is_packaged_food=None  → OCR 失败，提示重拍且禁止编造数值
    """
    ask = (user_text or "").strip() or _LABEL_REVIEW_DEFAULT_ASK
    is_packaged = label.get("is_packaged_food")

    if is_packaged is False:
        return (
            "【用户发来一张照片，但 OCR 判断它不是预包装食品成分表（可能是菜品、食材或包装正面）。"
            "请用一两句话说明：本入口只评价包装食品的成分表；想记录已经做好的饭菜，"
            "请用 App 首页「拍照记录」的餐食识别。不要输出任何营养数值，也不要给购买结论。】"
        )

    if is_packaged is not True:
        reason = (label.get("raw_text") or "").strip()
        reason_line = f"（原因：{reason}）" if reason else ""
        return (
            f"【用户发来一张成分表照片，但 OCR 未能识别出营养数据{reason_line}。"
            "请提示用户拍摄清晰完整的营养成分表后重新发送；"
            "严禁编造任何营养数值，也不要给出购买结论。】"
        )

    brand = (label.get("brand") or "").strip() or "未识别"
    food_name = (label.get("food_name") or "").strip() or "未识别"
    lines = [
        "【用户发来了一张预包装食品的成分表照片，以下为 OCR 提取结果（每 100g）】",
        f"品牌：{brand}",
        f"产品：{food_name}",
    ]
    if label.get("serving_size_g") is not None:
        lines.append(f"包装标注每份：{_fmt_label_value(label.get('serving_size_g'), 'g')}")
    for field, name, unit in _LABEL_NUTRIENTS:
        lines.append(f"{name}：{_fmt_label_value(label.get(field), unit)}")
    lines.extend(
        [
            "",
            f"【用户诉求】{ask}",
            "",
            "请按系统提示词中的「成分表评价与购买建议」规则作答。",
        ]
    )
    return "\n".join(lines)


def _extract_verdict(answer_text: str) -> Optional[str]:
    """从回答里抓机器可读结论（推荐购买/谨慎购买/不推荐购买），取不到返回 None"""
    match = _VERDICT_PATTERN.search(answer_text or "")
    return match.group(1) if match else None


def _save_label_review(
    db: Session,
    user_id: int,
    session_id: Optional[int],
    label: dict,
    answer_text: str,
) -> None:
    """把一次成分表评价落库（单表，一个商品一行；session_id 即对比容器）。

    数值全部来自 OCR（确定性），verdict 为尽力而为字段。整体容错：
    任何异常只记日志并回滚，绝不影响已经产出的回答。
    """
    try:
        from shared.models.food_label_models import FoodLabelReview

        def _num(field: str) -> Optional[float]:
            value = label.get(field)
            if value is None:
                return None
            try:
                return float(value)
            except (TypeError, ValueError):
                return None

        review = FoodLabelReview(
            user_id=user_id,
            session_id=session_id,
            brand=_clip_text(label.get("brand"), 128),
            food_name=_clip_text(label.get("food_name"), 128),
            is_packaged_food=True,
            raw_text=(label.get("raw_text") or None),
            verdict=_extract_verdict(answer_text),
            answer_text=(answer_text or None),
            **{field: _num(field) for field in _REVIEW_NUMERIC_FIELDS},
        )
        db.add(review)
        db.commit()
    except Exception as e:
        logger.warning(f"成分表评价落库失败（不影响回答）: {e}")
        db.rollback()


def _ensure_deep_session(
    db: Session,
    user_id: int,
    raw_session_id: Any,
    session_type: Optional[str],
) -> conversation_models.ConversationSession:
    """获取或创建对话会话，并绑定 deep 线程 ID（复用 DB 会话体系，历史页可读）"""
    session = None
    if raw_session_id:
        try:
            sid = int(raw_session_id)
        except (TypeError, ValueError):
            sid = None
        if sid:
            session = (
                db.query(conversation_models.ConversationSession)
                .filter(
                    conversation_models.ConversationSession.id == sid,
                    conversation_models.ConversationSession.user_id == user_id,
                )
                .first()
            )
            if session is None:
                raise HTTPException(status_code=404, detail="对话会话不存在")

    if session is None:
        try:
            stype = int(session_type) if session_type else 1
        except (TypeError, ValueError):
            stype = 1
        session = conversation_models.ConversationSession(
            user_id=user_id,
            session_type=stype,
            title=f"对话 - {datetime.now().strftime('%Y%m%d %H:%M')}",
            status=1,
        )
        db.add(session)
        db.commit()
        db.refresh(session)

    # 稳定映射 thread_id：重进同一会话可恢复 Agent 记忆
    if not session.langgraph_thread_id or not session.langgraph_thread_id.startswith("deep-"):
        session.langgraph_thread_id = f"deep-{session.id}"
        db.commit()
        db.refresh(session)
    return session


@router.post("/chat")
async def deep_chat(
    request: Request,
    message: str = "",
    session_id: Optional[str] = None,
    input_channel: str = "app",
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    DietDeepAgent 统一对话入口。

    支持文字消息（+ 可选「包装食品成分表」照片），Agent 自动规划任务并调用工具。
    返回 SSE 流式响应。

    image_base64（可选）：包装食品成分表照片的 base64（不含 data URI 前缀）。
    带图时先做 OCR，把结构化的每 100g 数值以**文本**注入本轮消息做成分评价
    （图片本体不进入 Agent 消息；评价结果落 food_label_reviews）。

    session_type 区分：
    - None / "1"~"5"：人类营养师模式，注入人类顾问风格 Prompt
    - "6"：宠物健康顾问模式，注入独立宠物 System Prompt + 宠物顾问风格 Prompt

    input_channel（PRD 4.9）：app（默认）/ hardware（老人线硬件语音，模糊量词按默认值记录）
    """
    (
        message,
        session_id,
        session_type,
        input_channel,
        image_base64,
    ) = await _resolve_deep_chat_params(request, message, session_id, input_channel)
    is_pet_session = (session_type == "6")

    # 根据 session_type 加载不同的 System Prompt
    advisor_prompt = ""

    if is_pet_session:
        # --- 宠物健康顾问模式 ---
        # 使用完全独立的宠物 System Prompt + 宠物专属顾问风格
        from agent.diet_deep_agent.prompts.pet_health_prompts import PET_ONLY_SYSTEM_PROMPT
        advisor_prompt = PET_ONLY_SYSTEM_PROMPT

        # 宠物模式同样需要注册表动作（record_pet_feeding / query_pet / undo）及其授权与撤销规则。
        # prompt_section("pet") 只列出宠物会话域的动作，人类的记录动作不出现在宠物提示词里（PRD D18）。
        from agent.diet_deep_agent.actions import registry as _action_registry
        advisor_prompt += "\n" + _action_registry.prompt_section("pet")

        # 叠加宠物专属顾问风格
        try:
            from shared.services.advisor_service import get_advisor_settings
            from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_pet_style_prompt
            settings = get_advisor_settings(next(get_db()), current_user.id)
            if settings:
                pet_style_prompt = build_pet_style_prompt(
                    pet_advisor_style=settings.get("pet_advisor_style", "vet_assistant"),
                    focus_goal=settings.get("pet_focus_goal"),
                    response_style=settings.get("response_style", "detailed")
                )
                advisor_prompt += "\n\n" + pet_style_prompt
        except Exception:
            pass
    else:
        # --- 人类营养师模式 ---
        # 注入完整的 DIET_DEEP_SYSTEM_PROMPT（已从 Agent 烘焙中移除，改为此处动态注入）
        from agent.diet_deep_agent.prompts import DIET_DEEP_SYSTEM_PROMPT
        advisor_prompt = DIET_DEEP_SYSTEM_PROMPT

        # 叠加人类顾问风格
        try:
            from shared.services.advisor_service import get_advisor_settings
            from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_style_prompt
            settings = get_advisor_settings(next(get_db()), current_user.id)
            if settings:
                style_prompt = build_style_prompt(
                    advisor_style=settings.get("advisor_style", "nutritionist"),
                    focus_goal=settings.get("focus_goal"),
                    focus_nutrient=settings.get("focus_nutrient"),
                    response_style=settings.get("response_style", "detailed")
                )
                advisor_prompt += "\n\n" + style_prompt
        except Exception:
            pass

        # 叠加用户体质档案（体质自测结果，建议与养生检索需参考）
        advisor_prompt += _build_user_health_context(current_user.id)

        # 老人线硬件语音：App 端的"先确认再记录 / 量词追问"规则不适用（PRD 4.3 / D13）
        from agent.diet_deep_agent.actions.context import ELDER_CHANNELS

        if str(input_channel or "").strip().lower() in ELDER_CHANNELS:
            advisor_prompt += ELDER_CHANNEL_PROMPT

    async def generate_response() -> AsyncGenerator[str, None]:
        # 提前初始化：异常兜底时仍要保住已产出的卡片/文本
        session: Optional[conversation_models.ConversationSession] = None
        full_text = ""
        cards: list[dict[str, Any]] = []
        try:
            # 1. 会话：复用 DB 会话体系（历史页可读），thread_id 与 Agent 记忆稳定绑定
            session = _ensure_deep_session(db, current_user.id, session_id, session_type)

            yield f"data: {json.dumps({'type': 'session', 'data': {'session_id': session.id}}, ensure_ascii=False)}\n\n"

            # 1b. 成分表照片：OCR 得到结构化数值，只把文本注入本轮消息
            #（图片本体不进 Agent 消息；OCR 是同步阻塞调用，放线程池避免卡住事件循环）
            label_payload: Optional[dict] = None
            agent_text = message
            persist_text = message
            if image_base64:
                from shared.services.food_label_ocr_service import parse_food_label

                label_payload = await asyncio.to_thread(parse_food_label, image_base64)
                agent_text = _build_label_review_text(message, label_payload)
                persist_text = message or "（发送了成分表照片）"

            # 2. 用户消息落库（带图轮落「（发送了成分表照片）」，避免 OCR 大段文本污染历史与搜索）
            db.add(
                conversation_models.ConversationMessage(
                    session_id=session.id,
                    message_type=1,
                    content=persist_text,
                )
            )
            session.last_message_at = datetime.now()
            db.commit()

            # 3. 调用 DietDeepAgent（流式：工具结果即时出卡，模型文本逐 token 下发）
            agent = _get_cached_agent()

            config = {
                "configurable": {
                    "thread_id": session.langgraph_thread_id,
                    "user_id": str(current_user.id),
                    "is_pet_session": is_pet_session,
                    "input_channel": input_channel,
                }
            }

            messages = []
            if advisor_prompt:
                messages.append({"role": "system", "content": advisor_prompt})
            messages.append({"role": "user", "content": agent_text})

            action_names = _load_action_names()
            has_action_failure = False  # 任一动作失败（ok=false）→ 文字保留给解释（PRD 4.6）

            # 历史消息 id：避免部分节点回传全量消息时重复下发文本/卡片
            seen_ids: set[str] = set()
            try:
                snapshot = await agent.aget_state(config)
                for m in (getattr(snapshot, "values", {}) or {}).get("messages") or []:
                    mid = getattr(m, "id", None)
                    if mid:
                        seen_ids.add(str(mid))
            except Exception as e:
                logger.warning(f"读取线程历史消息失败（非致命）: {e}")

            tokens_streamed = False  # messages 模式已逐 token 下发过文本

            async for mode, chunk in agent.astream(
                {"messages": messages},
                config=config,
                stream_mode=["messages", "updates"],
            ):
                # ① token 级事件：逐字下发模型文本
                if mode == "messages":
                    token_msg = chunk[0] if isinstance(chunk, (list, tuple)) and chunk else chunk
                    # messages 模式同时会流经工具消息等非模型产出，其 content 是工具返回的
                    # 卡片负载 JSON（含 confirm_token / params 等表单字段），必须只认模型消息，
                    # 否则会把表单数据当作正文吐进气泡
                    # 注意：AIMessageChunk.type 是 "AIMessageChunk"（非 "ai"）
                    if getattr(token_msg, "type", "") not in ("ai", "AIMessageChunk"):
                        continue
                    piece = _message_text(token_msg)
                    if not piece:
                        continue  # 工具调用参数等非文本 chunk
                    # 卡片即结果：卡片已由工具节点更早透传，最终文本按要求丢弃不逐字回显（PRD 4.8）
                    if cards and not has_action_failure and not any(
                        c.get("card_type") in TEXT_WITH_CARD_TYPES for c in cards
                    ):
                        continue
                    tokens_streamed = True
                    yield f"data: {json.dumps({'type': 'content', 'content': piece}, ensure_ascii=False)}\n\n"
                    continue

                # ② 节点级事件：卡片透传 / 动作失败判定 / 文本落库
                if mode != "updates" or not isinstance(chunk, dict):
                    continue
                for update in chunk.values():
                    if not isinstance(update, dict):
                        continue
                    msgs = update.get("messages")
                    if not isinstance(msgs, (list, tuple)):
                        continue
                    for msg in msgs:
                        msg_id = getattr(msg, "id", None)
                        key = str(msg_id) if msg_id else f"local-{id(msg)}"
                        if key in seen_ids:
                            continue
                        seen_ids.add(key)

                        # 动作卡片：注册表动作成功后即时透传（PRD 4.8）
                        card = _parse_action_card(msg, action_names)
                        if card:
                            cards.append(card)
                            yield f"data: {json.dumps({'type': 'card', 'card': card}, ensure_ascii=False)}\n\n"
                            continue

                        # 动作失败（ok=false）：文字需保留给用户解释（PRD 4.6 部分失败）
                        if _is_failed_action(msg, action_names):
                            has_action_failure = True

                        # 最终文本（跳过仅有工具调用的中间消息）。
                        # 功能性动作已成功出卡且无失败时，跳过模型文字复述——
                        # 卡片即结果（PRD 4.8「不在对话里堆数据」），直接调出即答
                        if getattr(msg, "type", "") == "ai" and not getattr(msg, "tool_calls", None):
                            text = _message_text(msg)
                            if text.strip():
                                full_text = f"{full_text}\n\n{text}" if full_text else text
                                # 待确认卡的文字是追问/分析本身，必须下发；
                                # 其余卡片文字仅落库不回显（PRD 4.8 卡片即结果）
                                needs_text = any(
                                    c.get("card_type") in TEXT_WITH_CARD_TYPES for c in cards
                                )
                                if cards and not has_action_failure and not needs_text:
                                    continue
                                # 已在 messages 模式逐 token 下发过 → 此处仅落库，不整段重复下发
                                if tokens_streamed:
                                    continue
                                yield f"data: {json.dumps({'type': 'content', 'content': text}, ensure_ascii=False)}\n\n"

            if not full_text.strip():
                if cards:
                    # 纯卡片轮：卡片已透传，拼接卡片摘要仅用于落库回溯，不再下发文本
                    full_text = "；".join(
                        str(c.get("message", "")) for c in cards if c.get("message")
                    ) or "已完成操作。"
                else:
                    full_text = "抱歉，我这边没有生成回复，请再试一次。"
                    yield f"data: {json.dumps({'type': 'content', 'content': full_text}, ensure_ascii=False)}\n\n"

            # 4. AI 消息落库（卡片存 metadata，历史可回溯）
            ai_message = conversation_models.ConversationMessage(
                session_id=session.id,
                message_type=2,
                content=full_text,
                message_metadata={
                    "cards": cards,
                    "agent_invocation": "diet_deep_agent",
                },
            )
            db.add(ai_message)
            session.last_message_at = datetime.now()
            session.updated_at = datetime.now()
            db.commit()
            db.refresh(ai_message)

            # 4b. 成分表评价落库（仅识别为预包装食品时；宠物会话不落）
            if label_payload and label_payload.get("is_packaged_food") is True and not is_pet_session:
                _save_label_review(
                    db,
                    user_id=current_user.id,
                    session_id=session.id,
                    label=label_payload,
                    answer_text=full_text,
                )

            yield f"data: {json.dumps({'type': 'complete', 'message_id': ai_message.id}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.exception(f"deep_chat error: {e}")
            db.rollback()

            # 中途失败兜底：已产出的卡片/文本仍落库，客户端拿到 message_id 才能保住卡片与撤销入口
            message_id = None
            if session is not None and (full_text.strip() or cards):
                if not full_text.strip():
                    full_text = "；".join(
                        str(c.get("message", "")) for c in cards if c.get("message")
                    ) or "已完成操作。"
                try:
                    ai_message = conversation_models.ConversationMessage(
                        session_id=session.id,
                        message_type=2,
                        content=full_text,
                        message_metadata={
                            "cards": cards,
                            "agent_invocation": "diet_deep_agent",
                            "partial_error": str(e),
                        },
                    )
                    db.add(ai_message)
                    session.last_message_at = datetime.now()
                    db.commit()
                    db.refresh(ai_message)
                    message_id = ai_message.id
                except Exception as persist_err:
                    logger.error(f"deep_chat 失败兜底落库失败: {persist_err}")
                    db.rollback()

            error_payload: dict[str, Any] = {
                "type": "error",
                "message": str(e),
                "error": str(e),
            }
            if message_id:
                error_payload["message_id"] = message_id
            yield f"data: {json.dumps(error_payload, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'complete', 'message_id': message_id}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        generate_response(),
        media_type="text/event-stream",
    )


@router.post("/analyze")
async def deep_analyze(
    request: Request,
    image: UploadFile = File(...),
    message: str = Form("帮我分析这张食物图片"),
    current_user: user_models.User = Depends(get_current_user),
):
    """
    食物图像分析（通过 DietDeepAgent）。

    上传图片后 Agent 自动执行完整分析流程：
    食物识别 → 营养提取 → 过敏检查 → 目标影响 → 个性化建议
    """
    import base64

    # 读取图片并编码
    image_bytes = await image.read()
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    # 解析 session_type（与 /chat 一致）
    _, _, session_type, _, _ = await _resolve_deep_chat_params(request, message, None)
    is_pet_session = (session_type == "6")

    # 根据 session_type 加载不同的 System Prompt
    advisor_prompt = ""

    if is_pet_session:
        # --- 宠物健康顾问模式 ---
        from agent.diet_deep_agent.prompts.pet_health_prompts import PET_ONLY_SYSTEM_PROMPT
        advisor_prompt = PET_ONLY_SYSTEM_PROMPT

        # 宠物模式同样需要注册表动作（record_pet_feeding / query_pet / undo）及其授权与撤销规则。
        # prompt_section("pet") 只列出宠物会话域的动作，人类的记录动作不出现在宠物提示词里（PRD D18）。
        from agent.diet_deep_agent.actions import registry as _action_registry
        advisor_prompt += "\n" + _action_registry.prompt_section("pet")
        try:
            from shared.services.advisor_service import get_advisor_settings
            from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_pet_style_prompt
            settings = get_advisor_settings(next(get_db()), current_user.id)
            if settings:
                pet_style_prompt = build_pet_style_prompt(
                    pet_advisor_style=settings.get("pet_advisor_style", "vet_assistant"),
                    focus_goal=settings.get("pet_focus_goal"),
                    response_style=settings.get("response_style", "detailed")
                )
                advisor_prompt += "\n\n" + pet_style_prompt
        except Exception:
            pass
    else:
        # --- 人类营养师模式 ---
        # 注入完整的 DIET_DEEP_SYSTEM_PROMPT（已从 Agent 烘焙中移除，改为此处动态注入）
        from agent.diet_deep_agent.prompts import DIET_DEEP_SYSTEM_PROMPT
        advisor_prompt = DIET_DEEP_SYSTEM_PROMPT

        # 叠加人类顾问风格
        try:
            from shared.services.advisor_service import get_advisor_settings
            from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_style_prompt
            settings = get_advisor_settings(next(get_db()), current_user.id)
            if settings:
                style_prompt = build_style_prompt(
                    advisor_style=settings.get("advisor_style", "nutritionist"),
                    focus_goal=settings.get("focus_goal"),
                    focus_nutrient=settings.get("focus_nutrient"),
                    response_style=settings.get("response_style", "detailed")
                )
                advisor_prompt += "\n\n" + style_prompt
        except Exception:
            pass

        # 叠加用户体质档案（体质自测结果，建议与养生检索需参考）
        advisor_prompt += _build_user_health_context(current_user.id)

    async def generate_response() -> AsyncGenerator[str, None]:
        try:
            agent = _get_cached_agent()
            thread_id = f"analyze-{uuid.uuid4().hex[:12]}"

            yield f"data: {json.dumps({'type': 'session', 'thread_id': thread_id})}\n\n"
            yield f"data: {json.dumps({'type': 'status', 'message': '正在分析食物图片...'})}\n\n"

            # 构造包含图片的消息
            user_content = [
                {"type": "text", "text": message},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                },
            ]

            config = {
                "configurable": {
                    "thread_id": thread_id,
                    "user_id": str(current_user.id),
                    "is_pet_session": is_pet_session,
                }
            }

            # 注入顾问风格 System Prompt
            messages = []
            if advisor_prompt:
                messages.append({"role": "system", "content": advisor_prompt})
            messages.append({"role": "user", "content": user_content})

            result = await agent.ainvoke(
                {"messages": messages},
                config=config,
            )

            messages = result.get("messages", [])
            if messages:
                last_msg = messages[-1]
                content = (
                    last_msg.content
                    if hasattr(last_msg, "content")
                    else str(last_msg)
                )
                yield f"data: {json.dumps({'type': 'analysis', 'content': content}, ensure_ascii=False)}\n\n"

            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.error(f"deep_analyze error: {e}")
            yield f"data: {json.dumps({'type': 'error', 'error': str(e)}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        generate_response(),
        media_type="text/event-stream",
    )


@router.post("/actions/undo")
async def deep_undo_action(
    request: Request,
    current_user: user_models.User = Depends(get_current_user),
):
    """卡片「撤销」直调（不经过 LLM）。

    撤销对象由服务端撤销日志决定（仅最近一条 + 记录后 10 分钟内，PRD 4.5）；
    客户端传卡片上的 undo_token 用于校验「点哪张撤哪张」，不传记录 ID，
    避免撤销到其他记录（尤其是其他会话的记录）。
    """
    try:
        from agent.diet_deep_agent.actions import ActionContext
        from agent.diet_deep_agent.actions.definitions.undo import UndoArgs, undo

        body: dict[str, Any] = {}
        try:
            payload = await request.json()
            if isinstance(payload, dict):
                body = payload
        except Exception:
            body = {}

        undo_token = body.get("undo_token")
        ctx = ActionContext(user_id=current_user.id, raw={"undo_token": undo_token})
        result = await undo(UndoArgs(), ctx)
        return {
            "success": result.ok,
            "message": result.message,
            "error": result.error,
            "data": result.data,
        }
    except Exception as e:
        logger.error(f"deep_undo_action error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/actions/confirm")
async def deep_confirm_action(
    request: Request,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """确认卡「帮我记录」直调（不经过 LLM，PRD 4.2）。

    卡片上的 confirm_token 指向后端预先备好的动作调用（见 actions/pending_store）：
    这里按原参数直接执行，份量、餐次、AI 估算热量都不会被模型重新理解一遍，
    凭证取出即作废——重复点击或网络重试不会写第二条。

    一轮多张卡（一次说了多样食物）用 confirm_tokens 一次性提交，
    执行的用户消息与结果卡同样落库，历史回显与撤销入口与普通轮次一致。
    """
    from agent.diet_deep_agent.actions import ActionContext, registry
    from agent.diet_deep_agent.actions.pending_store import consume_confirm

    body: dict[str, Any] = {}
    try:
        payload = await request.json()
        if isinstance(payload, dict):
            body = payload
    except Exception:
        body = {}

    raw_tokens = body.get("confirm_tokens")
    if not isinstance(raw_tokens, list):
        raw_tokens = [body.get("confirm_token")] if body.get("confirm_token") else []
    tokens = [str(t) for t in raw_tokens if t]
    if not tokens:
        raise HTTPException(status_code=400, detail="缺少 confirm_token")

    ctx = ActionContext(user_id=current_user.id, input_channel="app")
    cards: list[dict[str, Any]] = []
    messages: list[str] = []
    labels: list[str] = []
    ok_count = 0
    fail_count = 0

    for token in tokens:
        entry = await consume_confirm(token, current_user.id)
        if entry is None:  # 已用过 / 已过期 / 不属于该用户
            continue
        if entry.label:
            labels.append(entry.label)
        for call in entry.calls:
            name = str(call.get("action") or "")
            spec = registry.get(name)
            handler = registry.handler(name)
            if spec is None or handler is None:
                fail_count += 1
                messages.append("这张卡片对应的动作已不可用，请重新说一次需要记录的内容")
                continue
            kwargs = dict(call.get("params") or {})
            field = call.get("field")
            if field:
                kwargs[str(field)] = call.get("value")
            try:
                result = await handler(spec.args_schema(**kwargs), ctx)
            except Exception as e:
                logger.exception(f"确认卡动作执行失败: {name}")
                fail_count += 1
                messages.append(f"记录失败：{e}")
                continue
            if result.ok:
                ok_count += 1
            else:
                fail_count += 1
            if result.message:
                messages.append(result.message)
            if result.ok and result.card_type.value != "text":
                cards.append(json.loads(result.to_tool_output()))

    if ok_count == 0 and fail_count == 0:
        return {
            "success": False,
            "message": "这张卡片已经处理过或已超过 10 分钟，请再说一次需要记录的内容。",
            "data": {"cards": []},
        }

    summary = "；".join(messages) or "已完成。"

    # 落库：与普通轮次一致（用户消息 + 带 cards 的 AI 消息），失败不影响已完成的记录
    session_id = None
    message_id = None
    try:
        session = _ensure_deep_session(
            db, current_user.id, body.get("session_id"), body.get("session_type")
        )
        session_id = session.id
        db.add(
            conversation_models.ConversationMessage(
                session_id=session.id,
                message_type=1,
                content=f"帮我记录：{'、'.join(labels)}" if labels else "帮我记录",
            )
        )
        ai_message = conversation_models.ConversationMessage(
            session_id=session.id,
            message_type=2,
            content=summary,
            message_metadata={
                "cards": cards,
                "agent_invocation": "confirm_action",
            },
        )
        db.add(ai_message)
        session.last_message_at = datetime.now()
        db.commit()
        db.refresh(ai_message)
        message_id = ai_message.id
    except Exception as e:
        logger.warning(f"确认结果落库失败（非致命，记录已生效）: {e}")
        db.rollback()

    return {
        "success": ok_count > 0,
        "message": summary,
        "data": {
            "cards": cards,
            "session_id": session_id,
            "message_id": message_id,
        },
    }


@router.get("/daily-status")
async def deep_daily_status(
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    获取今日营养状态（直接调用工具，不经过 LLM）。
    """
    try:
        from agent.diet_deep_agent.tools.goal_tracking import get_daily_status

        result = get_daily_status.invoke({"user_id": current_user.id})
        return {"success": True, **result}

    except Exception as e:
        logger.error(f"deep_daily_status error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/memory/{user_id}")
async def get_user_memory(
    user_id: int,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    查看用户记忆文件（调试用）。

    仅允许查看自己的记忆，或管理员权限。
    """
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="只能查看自己的记忆")

    try:
        from agent.memory.memory_manager import MemoryManager
        from agent.diet_deep_agent.memory.md_store import MarkdownStore

        manager = MemoryManager(user_id)
        store = MarkdownStore()

        workspaces = await manager.get_all_workspaces()

        memories_ns = ("memories", str(user_id))
        memory_files = {}
        for filename in ["profile.md", "goals.md", "nutrition.md", "preferences.md", "insights.md"]:
            item = store.get(memories_ns, filename)
            if item:
                # value["content"] 按 StoreBackend 协议是行列表，对外仍返回字符串
                raw = item.value.get("content", "")
                text = raw if isinstance(raw, str) else "\n".join(raw)
                memory_files[filename] = text[:500]

        return {
            "user_id": user_id,
            "workspaces": {
                k: (v[:500] + "..." if v and len(v) > 500 else v)
                for k, v in workspaces.items()
            },
            "deep_agent_memories": memory_files,
        }

    except Exception as e:
        logger.error(f"get_user_memory error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
