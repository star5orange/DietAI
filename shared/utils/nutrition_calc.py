"""
Nutrition Calculation Utilities

Shared functions for BMR, TDEE, and daily nutrition target calculations.
Used by:
- Goal Tracking Agent
- Health Router (API endpoints)
- Sync Service (memory generation)

Formulas:
- BMR: Mifflin-St Jeor equation
- TDEE: BMR * Activity Factor
- Daily Targets: TDEE +/- adjustment based on goal type
"""

from typing import Dict, Any, Optional
from datetime import date
from enum import IntEnum


class GoalType(IntEnum):
    """健康目标类型"""
    LOSE_WEIGHT = 1      # 减重
    GAIN_WEIGHT = 2      # 增重
    MAINTAIN = 3         # 维持
    BUILD_MUSCLE = 4     # 增肌
    LOSE_FAT = 5         # 减脂


class ActivityLevel(IntEnum):
    """活动水平"""
    SEDENTARY = 1        # 久坐 (很少或无运动)
    LIGHT = 2            # 轻度活动 (轻松运动/每周1-3天)
    MODERATE = 3         # 中度活动 (中等运动/每周3-5天)
    ACTIVE = 4           # 重度活动 (剧烈运动/每周6-7天)
    VERY_ACTIVE = 5      # 超重度活动 (极剧烈运动/体力劳动)


# Activity level multipliers for TDEE calculation
ACTIVITY_FACTORS: Dict[int, float] = {
    ActivityLevel.SEDENTARY: 1.2,
    ActivityLevel.LIGHT: 1.375,
    ActivityLevel.MODERATE: 1.55,
    ActivityLevel.ACTIVE: 1.725,
    ActivityLevel.VERY_ACTIVE: 1.9
}

# Activity level descriptions (Chinese)
ACTIVITY_DESCRIPTIONS: Dict[int, str] = {
    ActivityLevel.SEDENTARY: "久坐（很少或无运动）",
    ActivityLevel.LIGHT: "轻度活动（轻松运动/每周1-3天）",
    ActivityLevel.MODERATE: "中度活动（中等运动/每周3-5天）",
    ActivityLevel.ACTIVE: "重度活动（剧烈运动/每周6-7天）",
    ActivityLevel.VERY_ACTIVE: "超重度活动（极剧烈运动/体力劳动）"
}

# Calorie adjustments by goal type
CALORIE_ADJUSTMENTS: Dict[int, int] = {
    GoalType.LOSE_WEIGHT: -500,    # 500 calorie deficit
    GoalType.GAIN_WEIGHT: 300,     # 300 calorie surplus
    GoalType.MAINTAIN: 0,          # No adjustment
    GoalType.BUILD_MUSCLE: 200,    # Slight surplus for muscle
    GoalType.LOSE_FAT: -400,       # Moderate deficit for fat loss
}

# Macro ratios by goal type (protein, carbs, fat)
MACRO_RATIOS: Dict[int, Dict[str, float]] = {
    GoalType.LOSE_WEIGHT: {"protein": 0.30, "carbs": 0.35, "fat": 0.35},
    GoalType.GAIN_WEIGHT: {"protein": 0.25, "carbs": 0.50, "fat": 0.25},
    GoalType.MAINTAIN: {"protein": 0.25, "carbs": 0.50, "fat": 0.25},
    GoalType.BUILD_MUSCLE: {"protein": 0.35, "carbs": 0.40, "fat": 0.25},
    GoalType.LOSE_FAT: {"protein": 0.30, "carbs": 0.35, "fat": 0.35},
}


def calculate_age(birth_date: date) -> int:
    """
    Calculate age from birth date.

    Args:
        birth_date: Date of birth

    Returns:
        Age in years
    """
    today = date.today()
    age = today.year - birth_date.year - (
        (today.month, today.day) < (birth_date.month, birth_date.day)
    )
    return age


def calculate_bmr(
    weight: float,
    height: float,
    age: int,
    gender: int
) -> float:
    """
    Calculate Basal Metabolic Rate using Mifflin-St Jeor equation.

    Args:
        weight: Weight in kg
        height: Height in cm
        age: Age in years
        gender: 1 = Male, 2 = Female

    Returns:
        BMR in kcal/day

    Formula:
        Male:   BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age(years) + 5
        Female: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age(years) - 161
    """
    if gender == 1:  # Male
        bmr = 10 * weight + 6.25 * height - 5 * age + 5
    else:  # Female (including other genders, using female formula as default)
        bmr = 10 * weight + 6.25 * height - 5 * age - 161

    return round(bmr, 1)


def calculate_tdee(
    bmr: float,
    activity_level: int
) -> float:
    """
    Calculate Total Daily Energy Expenditure.

    Args:
        bmr: Basal Metabolic Rate in kcal/day
        activity_level: Activity level (1-5)

    Returns:
        TDEE in kcal/day
    """
    factor = ACTIVITY_FACTORS.get(activity_level, ACTIVITY_FACTORS[ActivityLevel.LIGHT])
    tdee = bmr * factor
    return round(tdee, 1)


def calculate_daily_targets(
    tdee: float,
    goal_type: int
) -> Dict[str, float]:
    """
    Calculate daily nutrition targets based on TDEE and goal type.

    Args:
        tdee: Total Daily Energy Expenditure
        goal_type: Health goal type (1-5)

    Returns:
        Dictionary with calories, protein (g), carbs (g), fat (g)
    """
    # Apply calorie adjustment based on goal
    adjustment = CALORIE_ADJUSTMENTS.get(goal_type, 0)
    calorie_target = tdee + adjustment

    # Get macro ratios for goal type
    ratios = MACRO_RATIOS.get(goal_type, MACRO_RATIOS[GoalType.MAINTAIN])

    # Calculate macro targets in grams
    # Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
    protein_target = (calorie_target * ratios["protein"]) / 4
    carbs_target = (calorie_target * ratios["carbs"]) / 4
    fat_target = (calorie_target * ratios["fat"]) / 9

    return {
        "calories": round(calorie_target),
        "protein": round(protein_target),
        "carbs": round(carbs_target),
        "fat": round(fat_target),
        "calorie_adjustment": adjustment
    }


def calculate_full_nutrition_profile(
    weight: float,
    height: float,
    age: int,
    gender: int,
    activity_level: int,
    goal_type: int
) -> Dict[str, Any]:
    """
    Calculate complete nutrition profile including BMR, TDEE, and daily targets.

    Args:
        weight: Weight in kg
        height: Height in cm
        age: Age in years
        gender: 1 = Male, 2 = Female
        activity_level: Activity level (1-5)
        goal_type: Health goal type (1-5)

    Returns:
        Complete nutrition profile dictionary
    """
    bmr = calculate_bmr(weight, height, age, gender)
    tdee = calculate_tdee(bmr, activity_level)
    daily_targets = calculate_daily_targets(tdee, goal_type)

    return {
        "bmr": bmr,
        "tdee": tdee,
        "activity_factor": ACTIVITY_FACTORS.get(activity_level, 1.375),
        "activity_description": ACTIVITY_DESCRIPTIONS.get(activity_level, "轻度活动"),
        "daily_targets": daily_targets,
        "macro_ratios": MACRO_RATIOS.get(goal_type, MACRO_RATIOS[GoalType.MAINTAIN]),
        "user_data": {
            "weight": weight,
            "height": height,
            "age": age,
            "gender": "男" if gender == 1 else "女"
        }
    }


def calculate_remaining_budget(
    daily_targets: Dict[str, float],
    consumed: Dict[str, float]
) -> Dict[str, float]:
    """
    Calculate remaining nutrition budget for the day.

    Args:
        daily_targets: Daily targets (calories, protein, carbs, fat)
        consumed: Already consumed amounts

    Returns:
        Remaining amounts
    """
    return {
        "calories": round(daily_targets.get("calories", 0) - consumed.get("calories", 0)),
        "protein": round(daily_targets.get("protein", 0) - consumed.get("protein", 0)),
        "carbs": round(daily_targets.get("carbs", 0) - consumed.get("carbs", 0)),
        "fat": round(daily_targets.get("fat", 0) - consumed.get("fat", 0))
    }


def calculate_meal_impact(
    meal_nutrition: Dict[str, float],
    daily_targets: Dict[str, float],
    remaining_before: Dict[str, float]
) -> Dict[str, Any]:
    """
    Calculate the impact of a meal on daily targets.

    Args:
        meal_nutrition: Nutrition values of the meal
        daily_targets: Daily targets
        remaining_before: Remaining budget before this meal

    Returns:
        Impact analysis including percentage of daily budget
    """
    meal_calories = meal_nutrition.get("calories", 0)
    meal_protein = meal_nutrition.get("protein", 0)
    meal_carbs = meal_nutrition.get("carbs", 0)
    meal_fat = meal_nutrition.get("fat", 0)

    # Calculate percentage of daily budget
    calorie_percentage = (meal_calories / daily_targets["calories"]) * 100 if daily_targets["calories"] > 0 else 0

    # Calculate remaining after meal
    remaining_after = {
        "calories": remaining_before.get("calories", 0) - meal_calories,
        "protein": remaining_before.get("protein", 0) - meal_protein,
        "carbs": remaining_before.get("carbs", 0) - meal_carbs,
        "fat": remaining_before.get("fat", 0) - meal_fat
    }

    # Determine if meal fits budget
    fits_budget = remaining_after["calories"] >= 0

    return {
        "meal_percentage": round(calorie_percentage, 1),
        "fits_budget": fits_budget,
        "remaining_after": {k: round(v) for k, v in remaining_after.items()},
        "exceeded_by": max(0, -remaining_after["calories"]) if not fits_budget else 0
    }


def calculate_goal_progress(
    starting_weight: float,
    current_weight: float,
    target_weight: float,
    goal_type: int
) -> Dict[str, Any]:
    """
    Calculate progress toward weight goal.

    Args:
        starting_weight: Starting weight in kg
        current_weight: Current weight in kg
        target_weight: Target weight in kg
        goal_type: Goal type (1=lose, 2=gain, etc.)

    Returns:
        Progress metrics
    """
    weight_change = current_weight - starting_weight
    total_change_needed = abs(target_weight - starting_weight)
    current_change = abs(current_weight - starting_weight)

    # Calculate progress percentage
    if total_change_needed > 0:
        progress_percentage = (current_change / total_change_needed) * 100

        # For weight loss, positive change means moving away from goal
        # For weight gain, negative change means moving away from goal
        if goal_type in [GoalType.LOSE_WEIGHT, GoalType.LOSE_FAT]:
            if weight_change > 0:  # Gained weight when trying to lose
                progress_percentage = -abs(progress_percentage)
        elif goal_type == GoalType.GAIN_WEIGHT:
            if weight_change < 0:  # Lost weight when trying to gain
                progress_percentage = -abs(progress_percentage)
    else:
        progress_percentage = 100.0 if current_weight == target_weight else 0.0

    # Determine trend
    if abs(weight_change) < 0.5:
        trend = "stable"
    elif (goal_type in [GoalType.LOSE_WEIGHT, GoalType.LOSE_FAT] and weight_change < 0) or \
         (goal_type == GoalType.GAIN_WEIGHT and weight_change > 0):
        trend = "on_track"
    else:
        trend = "off_track"

    return {
        "starting_weight": starting_weight,
        "current_weight": current_weight,
        "target_weight": target_weight,
        "weight_change": round(weight_change, 2),
        "remaining": round(abs(target_weight - current_weight), 2),
        "progress_percentage": round(min(100, max(0, progress_percentage)), 1),
        "trend": trend
    }


def get_goal_type_name(goal_type: int) -> str:
    """Get human-readable name for goal type."""
    names = {
        GoalType.LOSE_WEIGHT: "减重",
        GoalType.GAIN_WEIGHT: "增重",
        GoalType.MAINTAIN: "维持",
        GoalType.BUILD_MUSCLE: "增肌",
        GoalType.LOSE_FAT: "减脂"
    }
    return names.get(goal_type, "未知目标")
