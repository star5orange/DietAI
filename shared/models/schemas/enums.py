from enum import IntEnum


class GenderEnum(IntEnum):
    MALE = 1
    FEMALE = 2
    OTHER = 3


class ActivityLevelEnum(IntEnum):
    SEDENTARY = 1
    LIGHTLY_ACTIVE = 2
    MODERATELY_ACTIVE = 3
    VERY_ACTIVE = 4
    EXTREMELY_ACTIVE = 5


class MealTypeEnum(IntEnum):
    BREAKFAST = 1
    LUNCH = 2
    DINNER = 3
    SNACK = 4
    LATE_NIGHT = 5


class GoalTypeEnum(IntEnum):
    LOSE_WEIGHT = 1
    GAIN_WEIGHT = 2
    MAINTAIN_WEIGHT = 3
    GAIN_MUSCLE = 4
    LOSE_FAT = 5