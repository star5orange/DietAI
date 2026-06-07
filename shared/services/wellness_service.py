import logging
import random
from typing import Optional
from datetime import date

from sqlalchemy.orm import Session
from shared.models.wellness_models import WellnessKnowledge
from shared.models.user_models import UserProfile

logger = logging.getLogger(__name__)

# 24节气列表（按2026年顺序）
SOLAR_TERMS_2026 = [
    ("小寒", "2026-01-05"), ("大寒", "2026-01-20"), ("立春", "2026-02-04"),
    ("雨水", "2026-02-18"), ("惊蛰", "2026-03-05"), ("春分", "2026-03-20"),
    ("清明", "2026-04-05"), ("谷雨", "2026-04-20"), ("立夏", "2026-05-05"),
    ("小满", "2026-05-20"), ("芒种", "2026-06-05"), ("夏至", "2026-06-21"),
    ("小暑", "2026-07-07"), ("大暑", "2026-07-22"), ("立秋", "2026-08-07"),
    ("处暑", "2026-08-23"), ("白露", "2026-09-07"), ("秋分", "2026-09-22"),
    ("寒露", "2026-10-08"), ("霜降", "2026-10-23"), ("立冬", "2026-11-07"),
    ("小雪", "2026-11-22"), ("大雪", "2026-12-07"), ("冬至", "2026-12-21"),
]


def _get_current_solar_term() -> str:
    """根据当前日期判断所属节气"""
    today = date.today()
    current = "小满"  # 默认
    for name, term_date in SOLAR_TERMS_2026:
        d = date.fromisoformat(term_date)
        if today >= d:
            current = name
    return current


def _get_current_season() -> str:
    """根据当前日期判断季节"""
    month = date.today().month
    if 3 <= month <= 5:
        return "春季"
    elif 6 <= month <= 8:
        return "夏季"
    elif 9 <= month <= 11:
        return "秋季"
    else:
        return "冬季"


def get_daily_wellness_recommendation(
    db: Session,
    solar_term: str = None,
    season: str = None,
    constitution_type: Optional[str] = None
) -> dict:
    """获取每日养生推荐（优先从数据库知识库查询）"""
    solar_term = solar_term or _get_current_solar_term()
    season = season or _get_current_season()

    # 按节气查询知识库
    knowledge = db.query(WellnessKnowledge).filter(
        WellnessKnowledge.solar_term == solar_term
    ).first()

    if not knowledge:
        knowledge = db.query(WellnessKnowledge).filter(
            WellnessKnowledge.season == season
        ).first()

    if not knowledge:
        knowledge = db.query(WellnessKnowledge).first()

    result = {
        "current_solar_term": solar_term,
        "current_season": season,
        "constitution_type": constitution_type,
        "recommended_ingredients": knowledge.recommended_foods.get("ingredients", []) if knowledge and knowledge.recommended_foods else [],
        "recommended_recipes": knowledge.recommended_foods.get("recipes", []) if knowledge and knowledge.recommended_foods else [],
        "wellness_tips": [knowledge.content] if knowledge and knowledge.content else ["保持规律作息，均衡饮食，适量运动"],
        "foods_to_avoid": knowledge.avoid_foods.get("items", []) if knowledge and knowledge.avoid_foods else [],
        "source": "knowledge_base",
    }

    return result


async def generate_ai_wellness_recommendation(
    user_id: int,
    db: Session,
    solar_term: str = None,
    season: str = None,
    constitution_type: Optional[str] = None
) -> dict:
    """调用 AI Agent (chat_agent) 生成个性化养生推荐。

    优先使用 AI 生成，失败时回退到知识库查询。
    """
    solar_term = solar_term or _get_current_solar_term()
    season = season or _get_current_season()

    # 获取用户资料以获取更多上下文
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    crowd_tag = profile.crowd_tag if profile else None

    try:
        from langgraph_sdk import get_client
        from shared.config.settings import get_settings

        settings = get_settings()
        client = get_client(url=settings.ai_service_url)

        # 构建养生推荐提示
        prompt_parts = [
            f"你是专业的养生健康顾问。",
            f"当前节气：{solar_term}，季节：{season}。",
        ]
        if constitution_type:
            prompt_parts.append(f"用户体质类型：{constitution_type}。")
        if crowd_tag:
            prompt_parts.append(f"用户健康目标：{crowd_tag}。")
        prompt_parts.append(
            "请提供今日的个性化养生推荐，以JSON格式返回，包含以下字段："
            "recommended_ingredients（推荐食材列表）、recommended_recipes（推荐食谱列表，每项含name/description/benefits）、"
            "wellness_tips（养生要点列表，3-5条）、foods_to_avoid（忌口食物列表）。"
            "请结合节气、季节、体质和健康目标给出专业建议。"
        )

        prompt = "\n".join(prompt_parts)

        assistant = await client.assistants.create(
            graph_id="chat_agent",
            config={"configurable": {"session_type": 5}}
        )
        thread = await client.threads.create()

        result = None
        async for chunk in client.runs.stream(
            assistant_id=assistant["assistant_id"],
            thread_id=thread["thread_id"],
            input={"message": prompt},
            stream_mode="values"
        ):
            if chunk.data and chunk.data.get("response_content"):
                result = chunk.data

        if result:
            import json
            content = result.get("response_content", "")
            try:
                if isinstance(content, str):
                    content = content.strip()
                    if content.startswith("```"):
                        lines = content.split("\n")
                        content = "\n".join(lines[1:-1])
                    ai_data = json.loads(content)
            except json.JSONDecodeError:
                logger.warning("AI 养生推荐返回非JSON格式，使用文本内容")
                ai_data = {
                    "recommended_ingredients": [],
                    "recommended_recipes": [],
                    "wellness_tips": [content] if content else [],
                    "foods_to_avoid": [],
                }

            return {
                "current_solar_term": solar_term,
                "current_season": season,
                "constitution_type": constitution_type,
                "crowd_tag": crowd_tag,
                "recommended_ingredients": ai_data.get("recommended_ingredients", []),
                "recommended_recipes": ai_data.get("recommended_recipes", []),
                "wellness_tips": ai_data.get("wellness_tips", []),
                "foods_to_avoid": ai_data.get("foods_to_avoid", []),
                "source": "ai_agent",
            }

    except Exception as e:
        logger.warning(f"AI 养生推荐生成失败，回退到知识库: {e}")

    # 回退到知识库
    return get_daily_wellness_recommendation(db, solar_term, season, constitution_type)


def get_solar_terms(db: Session, year: int = 2026) -> list[dict]:
    """获取该年所有节气日期"""
    # 先从数据库查询
    records = db.query(WellnessKnowledge).filter(
        WellnessKnowledge.category == "节气"
    ).all()

    db_terms = {r.solar_term: r.title for r in records if r.solar_term}

    # 合并预设日期和数据库描述
    result = []
    for name, term_date in SOLAR_TERMS_2026:
        is_current = (name == _get_current_solar_term())
        result.append({
            "name": name,
            "date": term_date,
            "description": db_terms.get(name),
            "is_current": is_current,
        })

    return result


def get_wellness_tips(
    db: Session,
    constitution_type: Optional[str] = None,
    limit: int = 5
) -> list[dict]:
    """随机获取养生知识卡片。

    优先匹配用户体质，其次随机返回。
    """
    query = db.query(WellnessKnowledge)

    if constitution_type:
        # 优先查适用体质的
        matching = query.filter(
            WellnessKnowledge.applicable_constitutions.contains([constitution_type])
        ).all()
        if matching and len(matching) >= limit:
            selected = random.sample(matching, min(limit, len(matching)))
        else:
            remaining = limit - len(matching) if matching else limit
            others = db.query(WellnessKnowledge).filter(
                ~WellnessKnowledge.applicable_constitutions.contains([constitution_type])
                if matching else True
            ).all()
            extra = random.sample(others, min(remaining, len(others))) if others else []
            selected = (matching or []) + extra
    else:
        all_knowledge = query.all()
        selected = random.sample(all_knowledge, min(limit, len(all_knowledge))) if all_knowledge else []

    return [
        {
            "id": k.id,
            "category": k.category,
            "sub_category": k.sub_category,
            "title": k.title,
            "content": k.content,
            "recommended_foods": k.recommended_foods,
            "avoid_foods": k.avoid_foods,
            "applicable_constitutions": k.applicable_constitutions,
            "season": k.season,
            "solar_term": k.solar_term,
        }
        for k in selected
    ]
