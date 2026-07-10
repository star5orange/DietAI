"""虚拟宠物状态业务逻辑"""
import logging
import random
from datetime import date, datetime, timedelta
from typing import Optional, Dict, Any, List

from sqlalchemy.orm import Session
from sqlalchemy import func

from shared.models.pet_models import VirtualPetState, PetUnlockable
from shared.models.food_models import FoodRecord, DailyNutritionSummary
from shared.models.water_models import WaterIntakeRecord
from shared.models.user_models import UserProfile

logger = logging.getLogger(__name__)

# 经验值计算常量
EXP_PER_FOOD_RECORD = 10
EXP_PER_WATER_GOAL = 20
EXP_PER_STREAK_DAY = 15

# 等级阈值（每级所需经验）
LEVEL_EXP_THRESHOLDS = [0, 50, 120, 220, 350, 520, 750, 1050, 1400, 1850]

# Mood 类型
MOODS = ("normal", "happy", "hungry", "anxious", "weak")

# 互动反馈文案模板
INTERACT_FEEDBACK = {
    "feed": {
        "happy": [
            "宠物开心地吃掉了你给的食物！它看起来很满足～",
            "美味！宠物享用了一顿大餐，活力满满！",
        ],
        "normal": [
            "宠物吃完了食物，状态不错～",
            "宠物接受了你的喂食，继续加油保持记录哦！",
        ],
        "hungry": [
            "宠物狼吞虎咽地吃完了！看来它真的很饿，记得按时吃饭哦！",
            "终于等到食物了！宠物吃饱了，心情好多了～",
        ],
        "anxious": [
            "宠物小心地吃了食物，似乎还有些不安...保持稳定饮食它会好起来的",
            "食物让宠物稍微放松了一些，继续规律饮食吧！",
        ],
        "weak": [
            "宠物慢慢地吃下了食物...需要更多营养来恢复元气！",
            "这顿食物对虚弱的宠物来说是及时雨，记得补充蛋白质哦！",
        ],
    },
    "play": {
        "happy": [
            "宠物开心地和你玩耍，转圈圈！太有趣了～",
            "和宠物一起玩的时光总是那么快乐！",
        ],
        "normal": [
            "宠物和你玩了一会儿，心情不错！",
            "宠物享受这段玩耍时光，继续互动吧～",
        ],
        "hungry": [
            "宠物玩了一半就累了...可能是饿了，记得按时吃饭！",
            "虽然想玩但还是先给宠物喂点东西吧！",
        ],
        "anxious": [
            "玩耍让宠物稍微放松了一些，但还需要更多关心哦～",
            "宠物陪你玩了一会儿，焦虑感减轻了一些",
        ],
        "weak": [
            "宠物太虚弱了，只能轻轻陪你玩玩...多记录健康饮食帮它恢复吧！",
            "宠物努力地回应着你的互动，虽然很虚弱但还是想和你玩",
        ],
    },
    "pet": {
        "happy": [
            "宠物很享受你的抚摸，舒服地眯起了眼睛～",
            "轻柔的抚摸让宠物感到安心和幸福！",
        ],
        "normal": [
            "宠物被摸得很舒服，安静地待在你身边～",
            "你的抚摸让宠物感到温暖，继续保持！",
        ],
        "hungry": [
            "宠物蹭了蹭你的手，似乎在说：'我有点饿了...'",
            "虽然被摸很开心，但宠物的肚子在咕咕叫呢",
        ],
        "anxious": [
            "你的抚摸让宠物感到安心，焦虑感慢慢消失了",
            "宠物紧靠着你，感受到被关心的温暖～",
        ],
        "weak": [
            "宠物在你的抚摸下安静地睡着了...它需要休息来恢复体力",
            "温柔的爱抚是给虚弱宠物最好的安慰",
        ],
    },
}


def get_exp_to_next_level(level: int) -> int:
    """获取当前等级升级所需总经验"""
    if level < len(LEVEL_EXP_THRESHOLDS):
        return LEVEL_EXP_THRESHOLDS[level]
    # 超出预设等级，按公式计算
    return LEVEL_EXP_THRESHOLDS[-1] + (level - len(LEVEL_EXP_THRESHOLDS) + 1) * 200


def calc_level(exp: int) -> int:
    """根据累计经验计算等级"""
    for i, threshold in enumerate(LEVEL_EXP_THRESHOLDS):
        if exp < threshold:
            return i
    # 超出预设
    extra = exp - LEVEL_EXP_THRESHOLDS[-1]
    return len(LEVEL_EXP_THRESHOLDS) + extra // 200


def create_pet_state(db: Session, user_id: int) -> VirtualPetState:
    """创建用户的虚拟宠物初始状态"""
    existing = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if existing:
        return existing

    pet = VirtualPetState(
        user_id=user_id,
        mood="normal",
        level=1,
        exp=0,
        current_skin="default",
        unlocked_skins=["default"],
        habit_score=50,
        version=1,
    )
    db.add(pet)
    db.commit()
    db.refresh(pet)
    logger.info(f"Created pet state for user {user_id}")
    return pet


def get_pet_status(db: Session, user_id: int) -> Dict[str, Any]:
    """获取 App 端宠物完整状态"""
    pet = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if not pet:
        pet = create_pet_state(db, user_id)

    exp_to_next = get_exp_to_next_level(pet.level + 1)

    # 计算连续达标天数
    streak_days = _calc_streak_days(db, user_id)

    return {
        "mood": pet.mood,
        "level": pet.level,
        "exp": pet.exp,
        "exp_to_next": exp_to_next,
        "current_skin": pet.current_skin,
        "unlocked_skins": pet.unlocked_skins or [],
        "habit_score": pet.habit_score,
        "last_interact_at": pet.last_interact_at.isoformat() if pet.last_interact_at else None,
        "streak_days": streak_days,
    }


def get_device_status(db: Session, user_id: int) -> Dict[str, Any]:
    """获取硬件端精简状态（用于 30 秒轮询）"""
    pet = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if not pet:
        pet = create_pet_state(db, user_id)

    return {
        "mood": pet.mood,
        "level": pet.level,
        "skin": pet.current_skin,
        "version": pet.version,
        "has_new_unlock": False,  # 简化实现，后续可跟踪
    }


def interact_pet(
    db: Session, user_id: int, action: str, item_id: Optional[str] = None
) -> Dict[str, Any]:
    """用户与宠物互动

    Args:
        db: 数据库会话
        user_id: 用户ID
        action: feed | play | pet
        item_id: 交互物品（可选）

    Returns:
        互动结果
    """
    pet = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if not pet:
        pet = create_pet_state(db, user_id)

    # 互动冷却检查（30 秒内同一操作不重复给经验）
    now = datetime.utcnow()
    cooldown_ok = True
    if action == "feed":
        if pet.last_feed_at and (now - pet.last_feed_at).total_seconds() < 30:
            cooldown_ok = False
        else:
            pet.last_feed_at = now
    elif action == "play":
        if pet.last_play_at and (now - pet.last_play_at).total_seconds() < 30:
            cooldown_ok = False
        else:
            pet.last_play_at = now

    # 经验值计算
    exp_gained = 0
    if cooldown_ok:
        exp_gains = {"feed": 5, "play": 3, "pet": 1}
        exp_gained = exp_gains.get(action, 0)
        if action == "feed" and item_id:
            exp_gained += 2  # 特定物品加分

        pet.exp += exp_gained

        # 检查升级
        old_level = pet.level
        new_level = calc_level(pet.exp)
        if new_level > old_level:
            pet.level = new_level
            logger.info(f"User {user_id} pet leveled up: {old_level} -> {new_level}")

    # 更新互动时间
    pet.last_interact_at = now

    # 互动后可能提升 mood（如果宠物处于负面状态）
    if pet.mood in ("hungry", "anxious", "weak") and cooldown_ok:
        pet.mood = "normal"

    # 版本号递增
    pet.version += 1

    db.commit()
    db.refresh(pet)

    # 生成反馈文案
    feedback_text = random.choice(INTERACT_FEEDBACK.get(action, {}).get(pet.mood, ["宠物回应了你的互动～"]))

    # 检查是否有新解锁
    new_unlock = None
    if cooldown_ok:
        new_unlock = _check_unlocks(db, pet)

    return {
        "mood": pet.mood,
        "exp_gained": exp_gained,
        "feedback_text": feedback_text,
        "new_unlock": new_unlock,
    }


def get_unlockables(db: Session, user_id: int) -> Dict[str, Any]:
    """获取可解锁内容列表及用户进度"""
    pet = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if not pet:
        pet = create_pet_state(db, user_id)

    streak_days = _calc_streak_days(db, user_id)
    unlockables = db.query(PetUnlockable).filter(PetUnlockable.is_active.is_(True)).all()

    items = []
    for u in unlockables:
        is_unlocked = (u.unlock_key in (pet.unlocked_skins or []))

        progress = {
            "current_level": pet.level,
            "target_level": u.required_level,
            "current_streak": streak_days,
            "target_streak": u.required_streak,
            "current_habit_score": pet.habit_score,
            "target_habit_score": u.required_habit_score,
        }

        items.append({
            "unlock_type": u.unlock_type,
            "unlock_key": u.unlock_key,
            "name": u.name,
            "description": u.description,
            "required_level": u.required_level,
            "required_streak": u.required_streak,
            "required_habit_score": u.required_habit_score,
            "is_unlocked": is_unlocked,
            "progress": progress,
        })

    return {"unlockables": items}


def update_pet_status_on_record(db: Session, user_id: int):
    """饮食/饮水记录后更新宠物状态（供 food/water service 调用）"""
    pet = db.query(VirtualPetState).filter(VirtualPetState.user_id == user_id).first()
    if not pet:
        pet = create_pet_state(db, user_id)

    today = date.today()

    # 计算饮食达标率
    diet_compliance = _calc_diet_compliance(db, user_id, today)
    water_compliance = _calc_water_compliance(db, user_id, today)

    # 计算连续达标天数
    streak_days = _calc_streak_days(db, user_id)

    # 确定 mood
    if diet_compliance >= 0.9 and water_compliance >= 0.9:
        pet.mood = "happy"
    elif diet_compliance >= 0.6 and water_compliance >= 0.6:
        pet.mood = "normal"
    elif diet_compliance < 0.3 and water_compliance < 0.3:
        pet.mood = "weak"
    elif water_compliance < 0.5:
        pet.mood = "anxious"
    elif diet_compliance < 0.6:
        pet.mood = "hungry"
    else:
        pet.mood = "normal"

    # 更新 habit_score
    pet.habit_score = min(100, int((diet_compliance + water_compliance) / 2 * 100))

    # 经验值计算
    pet.exp += EXP_PER_FOOD_RECORD
    if water_compliance >= 1.0:
        pet.exp += EXP_PER_WATER_GOAL
    if streak_days >= 3:
        pet.exp += EXP_PER_STREAK_DAY

    # 检查升级
    new_level = calc_level(pet.exp)
    if new_level > pet.level:
        pet.level = new_level

    # 检查解锁
    _check_unlocks(db, pet)

    # 版本号递增
    pet.version += 1

    db.commit()
    logger.debug(
        f"Pet status updated: user={user_id}, mood={pet.mood}, "
        f"level={pet.level}, exp={pet.exp}, diet={diet_compliance:.0%}, water={water_compliance:.0%}"
    )


# ========== 内部辅助 ==========


def _calc_diet_compliance(db: Session, user_id: int, target_date: date) -> float:
    """计算当日饮食达标率（三餐都有记录 = 100%）"""
    records = db.query(FoodRecord).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date == target_date
    ).all()

    meal_types = set(r.meal_type for r in records)
    # 三餐（早餐=1, 午餐=2, 晚餐=3）达标即为完成
    main_meals = {1, 2, 3}
    completed = len(meal_types & main_meals)
    return min(completed / 3, 1.0)


def _calc_water_compliance(db: Session, user_id: int, target_date: date) -> float:
    """计算当日饮水达标率"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    daily_goal = profile.daily_water_goal if profile else 2000

    total_ml = db.query(func.coalesce(func.sum(WaterIntakeRecord.amount_ml), 0)).filter(
        WaterIntakeRecord.user_id == user_id,
        func.date(WaterIntakeRecord.record_time) == target_date
    ).scalar()

    return min(float(total_ml) / daily_goal, 1.0) if daily_goal > 0 else 0.0


def _calc_streak_days(db: Session, user_id: int) -> int:
    """计算连续达标天数（三餐达标 + 饮水达标）"""
    streak = 0
    today = date.today()

    for i in range(100):  # 最多回溯 100 天
        check_date = today - timedelta(days=i)
        diet = _calc_diet_compliance(db, user_id, check_date)
        water = _calc_water_compliance(db, user_id, check_date)

        if diet >= 0.6 and water >= 0.6:
            streak += 1
        else:
            break

    return streak


def _check_unlocks(db: Session, pet: VirtualPetState) -> Optional[str]:
    """检查并解锁新内容，返回解锁的 unlock_key"""
    streak = _calc_streak_days(db, pet.user_id)

    all_unlockables = db.query(PetUnlockable).filter(
        PetUnlockable.is_active.is_(True)
    ).all()

    unlocked = set(pet.unlocked_skins or [])

    for u in all_unlockables:
        if u.unlock_key in unlocked:
            continue
        can_unlock = True
        if u.required_level is not None and pet.level < u.required_level:
            can_unlock = False
        if u.required_streak is not None and streak < u.required_streak:
            can_unlock = False
        if u.required_habit_score is not None and pet.habit_score < u.required_habit_score:
            can_unlock = False
        if can_unlock:
            unlocked.add(u.unlock_key)
            pet.unlocked_skins = list(unlocked)
            logger.info(f"User {pet.user_id} unlocked: {u.unlock_key}")
            return u.unlock_key

    return None
