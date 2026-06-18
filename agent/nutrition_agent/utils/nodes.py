import asyncio
from langchain_core.documents import Document

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.runnables import RunnableConfig

import json

from agent.common_utils.rag_utils import rag_loader, rag_search_by_user_profile

from agent.common_utils.image_utils import encode_image_to_base64
from agent.common_utils.redis_util import get_redis_client
from agent.common_utils.configuration import Configuration
from agent.nutrition_agent.utils.states import AgentState
from agent.nutrition_agent.utils.structs import NutritionAnalysis, NutritionAdvice, AdviceDependencies
from agent.common_utils.model_utils import get_model
from agent.nutrition_agent.utils.prompts import create_nutrition_prompt


def state_init(state: AgentState, config: RunnableConfig):
    configurable = Configuration.from_runnable_config(config)
    if state.get("image_dir") is None:
        initial_state = AgentState(
            image_data=state['image_data'],
            image_analysis=None,
            nutrition_analysis=None,
            nutrition_advice=None,
            advice_dependencies=None,
            retrieved_documents=[],
            user_preferences=state['user_preferences'],
            allergies=state.get('user_preferences', {}).get('allergies', []),
            allergy_warnings=[],
            conversation_history=[],
            current_step="starting",
            error_message=None,
            vision_model=get_model(model_provider=configurable.vision_model_provider,
                                   model_name=configurable.vision_model),
            analysis_model=get_model(model_provider=configurable.analysis_model_provider,
                                     model_name=configurable.analysis_model)
        )
        return initial_state
    image_data = encode_image_to_base64(str(state['image_dir']))
    print(configurable.analysis_model)
    print(configurable.vision_model)
    initial_state = AgentState(
        image_data=image_data,
        image_analysis=None,
        nutrition_analysis=None,
        nutrition_advice=None,
        advice_dependencies=None,
        retrieved_documents=[],
        user_preferences=state['user_preferences'],
        allergies=state.get('user_preferences', {}).get('allergies', []),
        allergy_warnings=[],
        conversation_history=[],
        current_step="starting",
        error_message=None,
        vision_model=get_model(model_provider=configurable.vision_model_provider, model_name=configurable.vision_model),
        analysis_model=get_model(model_provider=configurable.analysis_model_provider,
                                 model_name=configurable.analysis_model)
    )
    print(initial_state["current_step"])
    return initial_state


def analyze_image(state: AgentState) -> AgentState:
    """第一步：分析图片中的食物"""
    try:
        if not state.get("image_data"):
            state["error_message"] = "未提供图片数据"
            return state

        # if not state.get("image_dir"):
        #     state["error_message"] = "未提供图片数据"
        #     return state

        messages = [
            SystemMessage(content="""你是一位专业的营养师，擅长识别和分析食物图片，尤其精通中式菜肴的识别。

## 中式食物识别引导

当图片中可能包含中式食物时，请特别注意以下常见中式菜品和烹饪方式：

### 常见中式主食
- 米饭、炒饭、煲仔饭、盖浇饭、蛋炒饭
- 面条、炒面、拌面、汤面、拉面、刀削面
- 馒头、花卷、包子、饺子、馄饨、烧麦
- 粥类：白粥、皮蛋瘦肉粥、八宝粥

### 常见中式菜肴
- 炒菜类：宫保鸡丁、鱼香肉丝、回锅肉、麻婆豆腐、青椒肉丝
- 红烧类：红烧肉、红烧鱼、红烧排骨、红烧茄子
- 蒸菜类：清蒸鱼、粉蒸肉、蒸蛋羹
- 炖汤类：排骨汤、鸡汤、鱼汤、番茄蛋汤
- 凉菜类：凉拌黄瓜、皮蛋豆腐、口水鸡

### 常见中式烹饪方式及用油量参考
- 炒：用油较多（约15-30g/份）
- 煎：用油中等（约10-20g/份）
- 蒸：几乎不用油
- 煮/炖：少量用油（约5-10g/份）
- 炸：用油很多（约20-40g/份）
- 凉拌：少量香油（约3-5g/份）

### 中式调料热量注意
- 酱油、蚝油、豆瓣酱等含钠较高
- 糖醋类菜品含糖量较高
- 麻辣类菜品油脂含量较高

请详细描述图片中的所有食物，包括：
1. 具体的食物名称和种类（优先使用中文菜名）
2. 估计的分量和重量
3. 烹饪方式（煎、炒、蒸、煮、炖、炸、凉拌等）
4. 食物的新鲜程度和外观
5. 可能的调料和配菜
6. 如果是中式菜肴，请推测可能的调料和用油量
请用中文回答，尽可能详细和准确。"""),

            HumanMessage(content=[
                {
                    "type": "text",
                    "text": "请分析这张食物图片，详细描述其中的所有食物项目："
                },
                {
                    "type": "image",
                    "source_type": "base64",
                    "data": state["image_data"],
                    "mime_type": "image/jpeg"
                }
            ])
        ]

        response = state['vision_model'].invoke(messages)
        # print(f"分析结果：{response.content}")
        state["image_analysis"] = response.content
        state["current_step"] = "image_analyzed"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"图片分析失败: {str(e)}"
    state['image_data'] = ""
    return state


def extract_nutrition_info(state: AgentState) -> AgentState:
    """第二步：提取营养信息"""
    # 后期可以对食物营养分析也配一个rag
    try:
        if not state.get("image_analysis"):
            state["error_message"] = "缺少图片分析结果"
            return state

        prompt = create_nutrition_prompt(
            image_analysis=state["image_analysis"]
        )
        # prompt = f"""
        #         基于以下食物描述，请提供详细的营养分析：
        #
        #         食物描述：{state["image_analysis"]}
        #
        #         请按照以下JSON格式返回营养分析：
        #         {{
        #             "food_items": ["食物1", "食物2", ...],
        #             "total_calories": 估计总热量(数字),
        #             "macronutrients": {{
        #                 "protein": 蛋白质含量(克),
        #                 "fat": 脂肪含量(克),
        #                 "carbohydrates": 碳水化合物含量(克)
        #             }},
        #             "vitamins_minerals": {{
        #                 "vitamin_c": "维生素C含量评估",
        #                 "calcium": "钙含量评估",
        #                 "iron": "铁含量评估"
        #             }},
        #             "health_level": 健康评分等级A-E
        #         }}
        #         """

        structured_model = state['analysis_model'].with_structured_output(
            NutritionAnalysis,
            method="json_mode",
        )

        nutrition_analysis = structured_model.invoke(prompt)
        print(f"分析结果：{nutrition_analysis}")
        state["nutrition_analysis"] = nutrition_analysis
        state["current_step"] = "nutrition_extracted"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"营养分析失败: {str(e)}"

    return state


async def retrieve_nutrition_knowledge(state: AgentState) -> AgentState:
    """第三步，检索营养知识（带缓存优化 + metadata filter）"""
    try:
        if not state.get("nutrition_analysis"):
            state["error_message"] = "缺少营养分析结果"
            return state
        analysis = state["nutrition_analysis"]

        query_list = [
            f"食物项目: {', '.join(analysis.food_items)}",
            f"总热量: {analysis.total_calories} 大卡",
            f"宏量营养素: {analysis.macronutrients}",
            f"维生素和矿物质: {analysis.vitamins_minerals}"
        ]

        # 提取用户画像信息用于 metadata filter
        prefs = state.get("user_preferences") or {}
        crowd = prefs.get("crowd_tag") or prefs.get("crowd")
        constitution = prefs.get("constitution_type") or prefs.get("constitution")
        # 根据当前月份推断季节
        month = __import__("datetime").datetime.now().month
        season_map = {3: "春", 4: "春", 5: "春", 6: "夏", 7: "夏", 8: "夏",
                      9: "秋", 10: "秋", 11: "秋", 12: "冬", 1: "冬", 2: "冬"}
        season = season_map.get(month)

        # 获取 Redis 客户端
        redis_client = await get_redis_client()

        # 优化缓存 key：食物名称 + 用户画像维度，不同人群命中不同缓存
        food_key = "_".join(sorted(analysis.food_items))
        profile_suffix = ""
        if crowd:
            profile_suffix += f":{crowd}"
        if constitution:
            profile_suffix += f":{constitution}"
        if season:
            profile_suffix += f":{season}"
        cache_key = f"rag:nutrition:{food_key}{profile_suffix}"

        # 检查缓存
        cached_result = await redis_client.get(cache_key)
        if cached_result:
            search_results = [Document(page_content=content) for content in json.loads(cached_result)]
        else:
            # 使用带 metadata filter 的检索
            search_results = []
            seen_contents = set()  # 去重
            for query in query_list:
                docs = await asyncio.to_thread(
                    rag_search_by_user_profile,
                    query, k=2,
                    crowd=crowd,
                    season=season,
                    constitution=constitution,
                )
                for doc in docs:
                    content_hash = hash(doc.page_content[:200])
                    if content_hash not in seen_contents:
                        seen_contents.add(content_hash)
                        search_results.append(doc)

            # 缓存结果，设置 24 小时过期
            await redis_client.set(
                cache_key,
                json.dumps([doc.page_content for doc in search_results]),
                ex=86400  # 24小时过期
            )

        # 关闭 Redis 连接
        await redis_client.aclose()

        result=[]
        for doc in search_results:
            try:
                content = doc.page_content.strip()
                result.append(content)

            except Exception as e:
                print(f"文档查询错误: {e}")
                continue

        state["retrieved_documents"] = result
        state["current_step"] = "retrieve_nutrition_knowledge"
        print(state["current_step"])

    except Exception as e:
        print(f"营养知识检索失败，已跳过 RAG 检索: {str(e)}")
        state["retrieved_documents"] = []
        state["current_step"] = "retrieve_nutrition_knowledge"

    return state


def generate_dependencies(state: AgentState) -> AgentState:
    try:
        if not state.get("retrieved_documents"):
            advice_dependencies = AdviceDependencies(
                     nutrition_facts=[],
                     health_guidelines=[],
                     food_interactions=[])
            state["advice_dependencies"] = advice_dependencies
            print("缺少相关营养知识文档")
            return state

        documents = state["retrieved_documents"]
        user_prefs = state.get("user_preferences", {})
        prompt = f"""
                基于以下专业知识和用户信息，请提供相关营养知识参考：
                专业知识：{documents}
                用户偏好：{user_prefs}
                请按照以下json格式返回： 
                {{
                    "nutrition_facts": ["知识要点1", "知识要点2", ...],
                    "health_guidelines": ["健康指南1", "健康指南2", ...],
                    "food_interactions": ["相互作用1", "相互作用2", ...]（如果没有内容则填“无”）
                }}
                """

        model = state['analysis_model']

        structured_model = model.with_structured_output(
            AdviceDependencies,
            method="json_mode",
        )

        try:
            advice_dependencies = structured_model.invoke(prompt)
            # 确保 food_interactions 是列表
            if isinstance(advice_dependencies.food_interactions, str):
                advice_dependencies.food_interactions = [advice_dependencies.food_interactions]
            # print("调用成功，结果:", advice_dependencies)
            state["advice_dependencies"] = advice_dependencies
            state["current_step"] = "generate_dependencies"
            print(state["current_step"])
        except Exception as e:
            print("invoke 调用异常:", e)
    except Exception as e:
        print("依赖项生成失败:", e)

    return state


def generate_nutrition_advice(state: AgentState) -> AgentState:
    """第四步：生成营养建议"""
    try:
        if not state.get("advice_dependencies"):
            print("缺少相关营养知识")

        analysis = state.get("nutrition_analysis")
        if not analysis:
            print("缺少营养分析结果，跳过建议生成")
            state["nutrition_advice"] = None
            state["current_step"] = "advice_generated"
            return state

        advice_dependencies = state.get("advice_dependencies") or AdviceDependencies()
        user_prefs = state.get("user_preferences", {})
        allergies = state.get("allergies") or []
        allergy_warnings = state.get("allergy_warnings") or []

        # 构建过敏信息提示
        allergy_prompt = ""
        if allergies:
            allergy_prompt = f"""
             ⚠️ 用户过敏原：{allergies}
             过敏检查结果：{allergy_warnings if allergy_warnings else '未检测到过敏原风险'}
             请在建议中明确提醒用户注意过敏原，替代食物推荐中必须排除含过敏原的食物。
             """

        # prompt = f"""
        # 基于以下营养分析结果，请提供专业的营养建议：
        #
        # 营养分析：
        # - 食物项目：{analysis.food_items}
        # - 总热量：{analysis.total_calories}大卡
        # - 宏量营养素：{analysis.macronutrients}
        # - 维生素和矿物质：{analysis.vitamins_minerals}
        # - 健康等级：{analysis.health_level}
        #
        # 营养知识参考：使用retrieve_nutrition_knowledge工具获得相关知识参考
        # 用户偏好：{user_prefs}
        #
        # 请按照以下 JSON 格式返回建议和依据：
        # {{
        #     "nutrition_advice": {{
        #         "recommendations": ["具体建议1", "具体建议2", ...],
        #         "dietary_tips": ["饮食技巧1", "饮食技巧2", ...],
        #         "warnings": ["注意事项1", "注意事项2", ...],
        #         "alternative_foods": ["替代食物1", "替代食物2", ...]
        #     }},
        #     "advice_dependencies": {{
        #         "nutrition_facts": ["知识要点1", "知识要点2", ...],
        #         "health_guidelines": ["健康指南1", "健康指南2", ...],
        #         "food_interactions": ["相互作用1", "相互作用2", ...]（如果没有内容则填“无”）
        #     }}
        # }}
        # """

        prompt = f"""
             基于以下营养分析结果和专业知识，请提供专业的营养建议：

             营养分析：
             - 食物项目：{analysis.food_items}
             - 总热量：{analysis.total_calories}大卡
             - 蛋白质：{analysis.macronutrients.protein}g，脂肪：{analysis.macronutrients.fat}g，碳水：{analysis.macronutrients.carbohydrates}g
             - 健康等级：{analysis.health_level}

             营养知识参考：
             - 营养要点：{advice_dependencies.nutrition_facts}
             - 健康指南：{advice_dependencies.health_guidelines}
             - 食物相互作用：{advice_dependencies.food_interactions}

             用户偏好：{user_prefs}
             {allergy_prompt}
             请基于以上信息，结合科学营养学原理，给出具体、可执行的营养建议。
             请按照以下JSON格式返回建议：
             {{
                 "recommendations": ["具体建议1", "具体建议2"],
                 "dietary_tips": ["饮食技巧1", "饮食技巧2"],
                 "warnings": ["注意事项1", "注意事项2"],
                 "alternative_foods": ["替代食物1", "替代食物2"],
                 "action_items": [
                     {{"action": "具体行动描述", "priority": "high"}}
                 ]
             }}
             """

        model = state['analysis_model']

        structured_model = model.with_structured_output(
            NutritionAdvice,
            method="json_mode",
        )

        nutrition_advice = structured_model.invoke(prompt)

        state["nutrition_advice"] = nutrition_advice

        state["current_step"] = "advice_generated"
        print(state["current_step"])

    except Exception as e:
        print(f"建议生成失败: {str(e)}")
        import traceback
        traceback.print_exc()

    return state


def check_allergy_cross_contamination(state: AgentState) -> AgentState:
    """过敏交叉检查：检测食物中是否含有用户过敏原或交叉反应成分"""
    try:
        allergies = state.get("allergies") or []
        if not allergies:
            state["allergy_warnings"] = []
            state["current_step"] = "allergy_checked"
            return state

        analysis = state.get("nutrition_analysis")
        if not analysis:
            state["allergy_warnings"] = []
            state["current_step"] = "allergy_checked"
            return state

        food_items = [item.lower() for item in analysis.food_items]
        warnings = []

        # 常见过敏原交叉反应映射
        cross_reactivity = {
            "花生": ["花生", "花生油", "花生酱", "花生碎", "落花生"],
            "牛奶": ["牛奶", "奶油", "芝士", "奶酪", "黄油", "乳清", "炼乳", "酸奶", "鲜奶", "脱脂奶"],
            "鸡蛋": ["鸡蛋", "蛋", "蛋黄", "蛋白", "蛋液", "蛋挞"],
            "海鲜": ["虾", "蟹", "鱼", "贝", "蛤", "扇贝", "牡蛎", "三文鱼", "鳕鱼", "带鱼", "鱿鱼", "海参", "龙虾"],
            "大豆": ["大豆", "黄豆", "豆腐", "豆浆", "豆皮", "腐竹", "酱油", "豆瓣酱", "味噌"],
            "小麦": ["小麦", "面粉", "面条", "馒头", "面包", "饺子皮", "馄饨皮", "麦片"],
            "坚果": ["核桃", "杏仁", "腰果", "榛子", "开心果", "夏威夷果", "巴旦木", "松子"],
            "芝麻": ["芝麻", "芝麻酱", "芝麻油", "麻酱", "香油"],
        }

        for allergen in allergies:
            allergen_lower = allergen.lower()
            # 直接匹配
            for food in food_items:
                if allergen_lower in food or food in allergen_lower:
                    warnings.append(f"⚠️ 警告：食物「{food}」含有您的过敏原「{allergen}」，请勿食用！")
                    break

            # 交叉反应匹配
            related_terms = cross_reactivity.get(allergen, [])
            for term in related_terms:
                term_lower = term.lower()
                for food in food_items:
                    if term_lower in food or food in term_lower:
                        already_warned = any(allergen in w for w in warnings)
                        if not already_warned:
                            warnings.append(f"⚠️ 注意：食物「{food}」可能含有与「{allergen}」相关的成分（{term}），请谨慎食用。")
                        break

        state["allergy_warnings"] = warnings
        state["current_step"] = "allergy_checked"
        print(state["current_step"])

    except Exception as e:
        print(f"过敏检查失败: {str(e)}")
        state["allergy_warnings"] = []

    return state


def format_final_response(state: AgentState) -> AgentState:
    """第四步：格式化最终响应"""
    try:
        if state.get("error_message"):
            return state

        # 这里可以添加响应格式化逻辑
        state["current_step"] = "completed"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"响应格式化失败: {str(e)}"

    return state
