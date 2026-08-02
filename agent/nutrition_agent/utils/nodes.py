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
            image_data=state.get('image_data'),
            text_description=state.get('text_description'),
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
        text_description=state.get('text_description'),
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
        state["image_analysis"] = response.content
        state["current_step"] = "image_analyzed"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"图片分析失败: {str(e)}"
    state['image_data'] = ""
    return state


def analyze_text(state: AgentState) -> AgentState:
    """第一步(文字)：根据用户文字描述分析食物"""
    try:
        text_desc = state.get("text_description", "")
        if not text_desc:
            state["error_message"] = "未提供食物描述"
            return state

        messages = [
            SystemMessage(content="""你是一位专业的营养师，擅长根据用户对食物的文字描述进行详细的食物营养分析，尤其精通中式菜肴。

## 分析要求

请根据用户的文字描述，详细推断和分析以下内容：
1. 具体的食物名称和种类（优先使用中文菜名）
2. 估计的分量和重量（1份≈多少克）
3. 烹饪方式（煎、炒、蒸、煮、炖、炸、凉拌等）
4. 可能的调料和配菜
5. 该食物的营养特点

## 中式食物参考
- 米饭1碗≈150g，炒饭1份≈300g
- 面条1碗≈200g（煮后），炒面1份≈350g
- 鸡排1份≈150-200g（炸），鸡胸肉1份≈150g
- 蔬菜1份≈100-150g
- 炒菜用油约15-30g/份，炸制用油约20-40g/份

请用中文详细描述，将用户的文字转换为可用于营养计算的详细食物描述。"""),

            HumanMessage(content=f"请根据以下食物描述进行详细分析：\n{text_desc}")
        ]

        response = state['vision_model'].invoke(messages)
        state["image_analysis"] = response.content
        state["current_step"] = "text_analyzed"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"文字分析失败: {str(e)}"
    return state


def extract_nutrition_info(state: AgentState) -> AgentState:
    """第二步：提取营养信息"""
    try:
        if not state.get("image_analysis"):
            state["error_message"] = "缺少图片分析结果"
            return state

        prompt = create_nutrition_prompt(
            image_analysis=state["image_analysis"]
        )

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
                    "food_interactions": ["相互作用1", "相互作用2", ...]
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
            state["advice_dependencies"] = advice_dependencies
            state["current_step"] = "generate_dependencies"
            print(state["current_step"])
        except Exception as e:
            print("invoke 调用异常:", e)
    except Exception as e:
        print("依赖项生成失败:", e)

    return state


def generate_nutrition_advice(state: AgentState) -> AgentState:
    """第四步：生成个性化营养建议"""
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

        # ========== 构建用户画像上下文 ==========
        body_metrics = user_prefs.get("body_metrics", {})
        daily_targets = user_prefs.get("daily_targets", {})
        today_intake = user_prefs.get("today_intake", {})
        health_goals = user_prefs.get("health_goals", [])

        # 解析活动水平
        activity_map = {1: "久坐少动", 2: "轻度活动", 3: "中度活动", 4: "高度活动", 5: "极高强度"}
        activity_label = activity_map.get(body_metrics.get("activity_level"), "未设置")

        # 解析健康目标
        goal_map = {1: "减重", 2: "增重", 3: "维持体重", 4: "增肌", 5: "减脂"}
        active_goals = [
            goal_map.get(g["goal_type"], "未知目标")
            for g in health_goals
            if isinstance(g, dict) and g.get("current_status") == 1
        ]

        # 构建用户画像摘要
        profile_lines = []
        if body_metrics:
            parts = []
            if body_metrics.get("gender"):
                parts.append(body_metrics["gender"])
            if body_metrics.get("age"):
                parts.append(f"{body_metrics['age']}岁")
            if body_metrics.get("height_cm"):
                parts.append(f"{body_metrics['height_cm']}cm")
            if body_metrics.get("weight_kg"):
                parts.append(f"{body_metrics['weight_kg']}kg")
            if parts:
                profile_lines.append(f"- 基本信息：{'，'.join(parts)}")
            if body_metrics.get("bmi"):
                profile_lines.append(f"- BMI：{body_metrics['bmi']:.1f}")
            if body_metrics.get("crowd_tag"):
                profile_lines.append(f"- 人群标签：{body_metrics['crowd_tag']}")
            if body_metrics.get("constitution_type"):
                profile_lines.append(f"- 中医体质：{body_metrics['constitution_type']}")
            profile_lines.append(f"- 活动水平：{activity_label}")
        if active_goals:
            profile_lines.append(f"- 当前目标：{'、'.join(active_goals)}")

        # 构建今日摄入对比
        intake_lines = []
        target_cal = daily_targets.get("calories", 2000)
        today_cal = today_intake.get("calories", 0)
        meal_cal = analysis.total_calories
        after_meal_cal = today_cal + meal_cal
        remaining_cal = target_cal - after_meal_cal
        budget_pct = (after_meal_cal / target_cal * 100) if target_cal > 0 else 0

        intake_lines.append(f"- 每日热量目标：{target_cal} kcal")
        intake_lines.append(f"- 今日已摄入（含本餐）：{after_meal_cal:.0f} kcal（占目标 {budget_pct:.0f}%）")
        if remaining_cal > 0:
            intake_lines.append(f"- 今日剩余可摄入：{remaining_cal:.0f} kcal")
        else:
            intake_lines.append(f"- WARNING 已超出每日目标 {abs(remaining_cal):.0f} kcal")
        if today_intake.get("protein_g"):
            intake_lines.append(f"- 今日已摄入蛋白质：{today_intake['protein_g']:.0f}g")

        # 目标感知的指导原则
        goal_guidance = ""
        if active_goals:
            first_goal = active_goals[0]
            if "减重" in first_goal or "减脂" in first_goal:
                goal_guidance = """
## 目标感知指导（减重/减脂）
- 优先推荐低热量、高饱腹感的替代食物（如蔬菜、瘦肉、豆制品）
- 建议控制碳水比例，增加蛋白质和膳食纤维
- action_items 中必须包含"控制本餐份量"相关行动
- 如已超出今日热量预算，需给出补救措施（如增加运动、下一餐减量）"""
            elif "增肌" in first_goal:
                goal_guidance = """
## 目标感知指导（增肌）
- 优先关注蛋白质摄入是否充足（建议每餐20-30g蛋白质）
- 推荐高蛋白替代食物（鸡胸肉、鱼虾、蛋清、蛋白粉等）
- 如蛋白质不足，建议补充蛋白类食物"""
            elif "增重" in first_goal:
                goal_guidance = """
## 目标感知指导（增重）
- 推荐营养密度高的食物，增加健康热量摄入
- 建议增加餐次或份量，搭配坚果、牛油果等高营养食物"""
            elif "维持" in first_goal:
                goal_guidance = """
## 目标感知指导（维持体重）
- 关注营养均衡，三大宏量营养素比例合理
- 保持热量摄入与目标持平，避免大幅波动"""

        # 构建过敏信息提示
        allergy_prompt = ""
        if allergies:
            allergy_prompt = f"""
## WARNING 过敏安全
- 用户过敏原：{allergies}
- 过敏检查结果：{allergy_warnings if allergy_warnings else '未检测到过敏原风险'}
- 替代食物推荐中**必须排除**含过敏原的食物，并在 warnings 中明确提醒。
"""

        prompt = f"""你是一位专业的注册营养师，请基于以下完整的用户数据和食物分析结果，给出**高度个性化**的营养建议。

## 食物分析结果
- 食物项目：{analysis.food_items}
- 总热量：{meal_cal:.0f} kcal
- 蛋白质：{analysis.macronutrients.protein:.0f}g | 脂肪：{analysis.macronutrients.fat:.0f}g | 碳水：{analysis.macronutrients.carbohydrates:.0f}g
- 健康等级：{analysis.health_level} (1=E很差~5=A最优)

## 用户画像
{chr(10).join(profile_lines) if profile_lines else '- （暂无身体数据）'}

## 热量预算分析
{chr(10).join(intake_lines)}

{goal_guidance}

{allergy_prompt}

## 营养知识参考
- 营养要点：{advice_dependencies.nutrition_facts}
- 健康指南：{advice_dependencies.health_guidelines}
- 食物相互作用：{advice_dependencies.food_interactions}

## 建议生成要求
1. 建议必须与用户的目标（{', '.join(active_goals) if active_goals else '未设置'}）和热量预算直接相关
2. 用日常口语，不要用"建议您控制总能量摄入"这类书面语
3. 替代食物必须是真实存在、可实际操作的食物
4. action_items 按 priority 分级：high=必须做, medium=建议做, low=可选的
5. 如果已超出热量预算，warnings 中需包含具体补救建议

请按照以下JSON格式返回：
{{
    "recommendations": ["与用户目标直接相关的具体建议"],
    "dietary_tips": ["实用的饮食技巧"],
    "warnings": ["需要注意的风险或问题"],
    "alternative_foods": ["具体的替代食物名称"],
    "action_items": [
        {{"action": "可执行的具体行动", "priority": "high/medium/low"}}
    ]
}}"""

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
                    warnings.append(f"WARNING 警告：食物「{food}」含有您的过敏原「{allergen}」，请勿食用！")
                    break

            # 交叉反应匹配
            related_terms = cross_reactivity.get(allergen, [])
            for term in related_terms:
                term_lower = term.lower()
                for food in food_items:
                    if term_lower in food or food in term_lower:
                        already_warned = any(allergen in w for w in warnings)
                        if not already_warned:
                            warnings.append(f"WARNING 注意：食物「{food}」可能含有与「{allergen}」相关的成分（{term}），请谨慎食用。")
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

        state["current_step"] = "completed"
        print(state["current_step"])

    except Exception as e:
        state["error_message"] = f"响应格式化失败: {str(e)}"

    return state
