"""
宠物疫苗/提醒工具

从数据库查询疫苗记录、驱虫记录，生成健康提醒。
"""

import logging
from datetime import date, datetime
from typing import Any

from langchain_core.tools import tool
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def _get_db_session() -> Session:
    """获取数据库会话"""
    from shared.models.database import SessionLocal
    return SessionLocal()


# ==================== 业务常量 ====================

# 品种推荐的疫苗计划（通用建议，非数据库数据）
_VACCINE_SCHEDULE: dict[str, list] = {
    "cat": [
        {"name": "猫三联", "age_months": "2个月", "frequency": "首年3针，之后每年1针"},
        {"name": "狂犬疫苗", "age_months": "3个月", "frequency": "每年1针"},
        {"name": "猫白血病疫苗", "age_months": "3个月", "frequency": "每年1针"},
    ],
    "dog": [
        {"name": "犬六联", "age_months": "2个月", "frequency": "首年3针，之后每年1针"},
        {"name": "狂犬疫苗", "age_months": "3个月", "frequency": "每年1针"},
        {"name": "犬窝咳", "age_months": "3个月", "frequency": "每年1针"},
    ],
}

# 通用健康护理提醒模板
_PET_REMINDER_TEMPLATES: dict[str, dict] = {
    "deworming_external": {
        "title": "体外驱虫",
        "frequency_days": 30,
        "description": "建议每月进行一次体外驱虫，预防跳蚤、蜱虫等",
    },
    "deworming_internal": {
        "title": "体内驱虫",
        "frequency_days": 90,
        "description": "建议每3个月进行一次体内驱虫",
    },
    "health_check": {
        "title": "年度体检",
        "frequency_days": 365,
        "description": "建议每年进行一次全面体检，包括血常规、生化检查",
    },
    "nails_trim": {
        "title": "剪指甲",
        "frequency_days": 14,
        "description": "建议每2周修剪一次指甲",
    },
    "teeth_clean": {
        "title": "牙齿清洁",
        "frequency_days": 7,
        "description": "建议每周为宠物刷牙2-3次",
    },
    "bath": {
        "title": "洗澡",
        "frequency_days": 30,
        "description": "建议每月洗澡1-2次，根据品种适当调整",
    },
}


def _compute_vaccine_status(next_date_val: Any) -> str:
    """根据下次接种日期计算疫苗状态"""
    if not next_date_val:
        return "未知"
    if isinstance(next_date_val, str):
        next_date_val = date.fromisoformat(next_date_val)
    if isinstance(next_date_val, datetime):
        next_date_val = next_date_val.date()

    today = date.today()
    days_left = (next_date_val - today).days

    if days_left < 0:
        return "已过期"
    elif days_left <= 30:
        return "即将到期"
    else:
        return "正常"


# ==================== 工具函数 ====================


@tool
def get_vaccine_records(pet_id: int) -> dict[str, Any]:
    """获取宠物疫苗记录。

    从数据库中查询指定宠物的疫苗接种历史，
    包含疫苗名称、接种日期、下次接种日期和状态评估。

    Args:
        pet_id: 宠物 ID

    Returns:
        疫苗记录列表和状态评估
    """
    from shared.models.pet_models import PetVaccineRecord

    db = _get_db_session()
    try:
        records = db.query(PetVaccineRecord).filter(
            PetVaccineRecord.pet_id == pet_id,
        ).order_by(PetVaccineRecord.vaccinated_at.desc()).all()

        expired = []
        upcoming = []
        normal = []

        vaccine_list = []
        for r in records:
            status = _compute_vaccine_status(r.next_vaccination_date)
            item = {
                "name": r.vaccine_name or "",
                "date": r.vaccinated_at.isoformat() if r.vaccinated_at else "",
                "next_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else "",
                "notes": r.notes or "",
                "status": status,
            }
            vaccine_list.append(item)

            if status == "已过期":
                expired.append(item)
            elif status == "即将到期":
                upcoming.append(item)
            else:
                normal.append(item)

        return {
            "pet_id": pet_id,
            "total_count": len(vaccine_list),
            "expired_count": len(expired),
            "upcoming_count": len(upcoming),
            "normal_count": len(normal),
            "records": vaccine_list,
            "summary": (
                f"共{len(vaccine_list)}项疫苗记录，"
                f"已过期{len(expired)}项，"
                f"即将到期{len(upcoming)}项，"
                f"正常{len(normal)}项。"
            ),
            "has_warning": len(expired) > 0 or len(upcoming) > 0,
        }
    except Exception as e:
        logger.error(f"查询疫苗记录失败: {e}")
        return {"error": str(e), "pet_id": pet_id, "records": []}
    finally:
        db.close()


@tool
def get_vaccine_schedule(species: str) -> dict[str, Any]:
    """获取宠物推荐疫苗接种计划（通用建议，非数据库记录）。

    Args:
        species: 物种（cat/dog）

    Returns:
        推荐的疫苗接种时间表
    """
    schedule = _VACCINE_SCHEDULE.get(species.lower(), [])

    if not schedule:
        return {"error": f"暂不支持物种: {species}"}

    return {
        "species": species,
        "schedule": schedule,
        "note": "以上为通用建议，具体接种计划请咨询兽医。",
    }


@tool
def get_health_reminders(pet_id: int = None, reminder_types: list[str] = None) -> dict[str, Any]:
    """获取宠物健康护理提醒。

    优先从数据库查询最近驱虫记录，结合通用护理模板生成提醒。

    Args:
        pet_id: 宠物 ID（可选，用于查询该宠物的驱虫记录）
        reminder_types: 提醒类型列表（可选，默认返回全部）

    Returns:
        健康护理提醒列表
    """
    reminders = []

    # 如果有 pet_id，查询数据库中的驱虫记录
    if pet_id is not None:
        try:
            from shared.models.pet_models import PetDewormingRecord

            db = _get_db_session()
            try:
                records = db.query(PetDewormingRecord).filter(
                    PetDewormingRecord.pet_id == pet_id,
                ).order_by(PetDewormingRecord.treated_at.desc()).all()

                for r in records:
                    reminders.append({
                        "type": r.deworming_type or "deworming",
                        "title": f"{'体外' if 'external' in (r.deworming_type or '') else '体内' if 'internal' in (r.deworming_type or '') else ''}驱虫",
                        "latest_date": r.treated_at.isoformat() if r.treated_at else "",
                        "next_date": r.next_treatment_date.isoformat() if r.next_treatment_date else "",
                        "notes": r.notes or "",
                        "from_database": True,
                    })
            finally:
                db.close()
        except Exception as e:
            logger.error(f"查询驱虫记录失败: {e}")

    # 筛选模板类型
    templates = _PET_REMINDER_TEMPLATES
    if reminder_types:
        templates = {k: v for k, v in templates.items() if k in reminder_types}

    # 合并通用护理模板（仅当数据库中没有同类型提醒时）
    existing_types = {r.get("type", "") for r in reminders}
    for key, val in templates.items():
        if key not in existing_types:
            reminders.append({
                "type": key,
                "title": val["title"],
                "frequency_days": val["frequency_days"],
                "description": val["description"],
                "from_database": False,
            })

    return {
        "pet_id": pet_id,
        "reminders": reminders,
    }
