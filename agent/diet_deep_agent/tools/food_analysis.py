"""
食物分析工具 - 分析食物图片或查询食物数据库

通过 LangGraph SDK 调用现有 nutrition_agent 图。
"""

import logging
from typing import Any

from langchain_core.tools import tool
from langgraph_sdk import get_client

from agent.common_utils.configuration import get_agent_model_config
from shared.config.settings import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


async def _get_langgraph_client():
    """获取 LangGraph SDK 客户端（PRD 5.1：外部依赖设置超时，避免请求无限阻塞）"""
    return get_client(url=settings.ai_service_url, timeout=settings.external_http_timeout)


async def _load_user_preferences(user_id: int) -> dict:
    """从数据库加载用户的过敏原、疾病和健康目标等偏好数据"""
    try:
        from shared.models.database import SessionLocal
        from shared.models.user_models import User, UserProfile, Disease, Allergy, HealthGoal

        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {}

            dietary_restrictions = []

            # 加载过敏原
            allergies = db.query(Allergy).filter(Allergy.user_id == user_id).all()
            for a in allergies:
                dietary_restrictions.append({
                    "type": "allergy",
                    "allergen": a.allergen_name,
                    "severity": a.severity_level or 1,
                    "reaction": a.reaction_description or "",
                })

            # 加载疾病
            diseases = db.query(Disease).filter(Disease.user_id == user_id).all()
            for d in diseases:
                dietary_restrictions.append({
                    "type": "disease",
                    "disease": d.disease_name,
                    "severity": d.severity_level or 1,
                    "is_current": d.is_current or False,
                    "notes": d.notes or "",
                })

            # 加载健康目标（HealthGoal 只有 current_status，没有 status / daily_calorie_target）
            goals = db.query(HealthGoal).filter(
                HealthGoal.user_id == user_id,
                HealthGoal.current_status == 1,
            ).first()

            health_goals = {}
            if goals:
                if goals.goal_type:
                    health_goals["goal_type"] = goals.goal_type
                if goals.target_weight:
                    health_goals["target_weight"] = float(goals.target_weight)

            return {
                "dietary_restrictions": dietary_restrictions,
                "health_goals": health_goals,
                "language": "zh-CN",
            }
        finally:
            db.close()
    except Exception as e:
        logger.warning(f"加载用户偏好失败: {e}")
        return {"language": "zh-CN"}


@tool
async def analyze_food_image(image_data: str, user_id: int) -> dict[str, Any]:
    """分析食物图片，返回完整营养数据和用户特定警告。

    当用户上传食物图片时使用此工具。返回结构化的营养分析结果，
    包含菜品识别、热量估算、宏量/微量营养素、健康等级。

    Args:
        image_data: Base64 编码的食物图片数据
        user_id: 用户 ID（用于加载用户偏好和过敏信息）

    Returns:
        营养分析结果字典，包含 nutrition_analysis、nutrition_advice 等
    """
    try:
        client = await _get_langgraph_client()

        # 加载用户偏好（过敏原、疾病、健康目标等）
        user_preferences = await _load_user_preferences(user_id)

        # 使用 nutrition_agent 分析
        assistant = await client.assistants.create(
            graph_id="nutrition_agent",
            config={"configurable": get_agent_model_config()},
        )

        thread = await client.threads.create()

        result = None
        async for chunk in client.runs.stream(
            assistant_id=assistant["assistant_id"],
            thread_id=thread["thread_id"],
            input={"image_data": image_data, "user_preferences": user_preferences},
            stream_mode="values",
        ):
            if chunk.data and chunk.data.get("current_step") == "completed":
                result = chunk.data

        if result:
            nutrition = result.get("nutrition_analysis")
            advice = result.get("nutrition_advice")

            return {
                "success": True,
                "nutrition_analysis": (
                    nutrition.dict() if hasattr(nutrition, "dict")
                    else nutrition
                ),
                "nutrition_advice": (
                    advice.dict() if hasattr(advice, "dict")
                    else advice
                ),
            }

        return {"success": False, "error": "分析未返回结果"}

    except Exception as e:
        logger.error(f"analyze_food_image failed: {e}")
        return {"success": False, "error": str(e)}


@tool
def lookup_food_database(food_name: str) -> dict[str, Any]:
    """从食物数据库查询标准营养数据（每 100g）。

    当用户用文字描述食物时使用此工具查询标准数据。

    Args:
        food_name: 食物名称（如"鸡胸肉"、"苹果"）

    Returns:
        标准营养数据，若未找到则返回提示
    """
    try:
        from shared.models.database import SessionLocal
        from shared.services.food_matching import match_food

        db = SessionLocal()
        try:
            matched = match_food(db, food_name)
            if not matched:
                return {
                    "found": False,
                    "message": (
                        f"食物库中没有「{food_name}」的营养数据，"
                        "可以使用 analyze_food_image 工具通过图片分析"
                    ),
                }

            per_100g = matched["per_100g"]
            return {
                "found": True,
                "results": [
                    {
                        "food_name": matched["matched_name"],
                        "calories": per_100g["calories"],
                        "protein": per_100g["protein"],
                        "carbs": per_100g["carbohydrates"],
                        "fat": per_100g["fat"],
                    }
                ],
                "per_100g": per_100g,
                "message": f"命中食物库「{matched['matched_name']}」（每 100g 数据）",
            }
        finally:
            db.close()

    except Exception as e:
        logger.error(f"lookup_food_database failed: {e}")
        return {"found": False, "error": str(e)}
