"""体质自测相关的 Pydantic schemas"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict

# 九种中医体质类型
CONSTITUTION_TYPES = {
    "平和质": "体态适中，面色红润，精力充沛",
    "气虚质": "疲乏无力，气短懒言，易出汗",
    "阳虚质": "畏寒怕冷，手足不温，喜热饮食",
    "阴虚质": "手足心热，口干咽燥，喜冷饮",
    "痰湿质": "体形肥胖，腹部肥满，口黏苔腻",
    "湿热质": "面垢油光，口苦口干，易生痤疮",
    "血瘀质": "肤色晦暗，容易出现瘀斑，口唇暗淡",
    "气郁质": "神情抑郁，忧虑脆弱，闷闷不乐",
    "特禀质": "过敏体质，易打喷嚏，易起荨麻疹",
}

# 体质对应的饮食建议
CONSTITUTION_DIET_ADVICE: Dict[str, Dict[str, list]] = {
    "平和质": {
        "recommended": ["主食粗细搭配", "多吃新鲜蔬果", "适量优质蛋白"],
        "avoid": ["避免偏食", "避免过饱过饥"],
    },
    "气虚质": {
        "recommended": ["山药", "红枣", "鸡肉", "小米", "黄芪炖鸡"],
        "avoid": ["生冷食物", "油腻食物", "空心菜", "生萝卜"],
    },
    "阳虚质": {
        "recommended": ["羊肉", "韭菜", "核桃", "生姜", "肉桂"],
        "avoid": ["寒凉食物", "冷饮", "西瓜", "梨", "螃蟹"],
    },
    "阴虚质": {
        "recommended": ["百合", "银耳", "鸭肉", "梨", "蜂蜜"],
        "avoid": ["辛辣燥热", "油炸食品", "羊肉", "韭菜", "辣椒"],
    },
    "痰湿质": {
        "recommended": ["薏米", "赤小豆", "冬瓜", "山药", "海带"],
        "avoid": ["肥甘厚腻", "甜食", "油炸", "酒类"],
    },
    "湿热质": {
        "recommended": ["绿豆", "苦瓜", "黄瓜", "冬瓜", "薏米"],
        "avoid": ["辛辣温热", "油腻食物", "酒类", "甜食"],
    },
    "血瘀质": {
        "recommended": ["山楂", "醋", "黑豆", "玫瑰花茶", "红糖"],
        "avoid": ["油腻食物", "生冷食物", "过多盐分"],
    },
    "气郁质": {
        "recommended": ["玫瑰花茶", "柑橘", "莲子", "小麦", "百合"],
        "avoid": ["咖啡浓茶", "辛辣刺激", "酒精"],
    },
    "特禀质": {
        "recommended": ["蜂蜜", "山药", "红枣", "糯米"],
        "avoid": ["已知过敏食物", "海鲜发物", "辛辣食物"],
    },
}

# 自测题目（9题），每题的选项对应不同体质的得分
# 每题 1-5 分评分，分数分配到相关体质
QUIZ_QUESTIONS = [
    {
        "id": 1,
        "question": "您是否经常感到精力充沛、不易疲劳？",
        "category": "精力状态",
        "constitution_scores": {
            "平和质": {"agree": 5, "neutral": 3, "disagree": 0},
            "气虚质": {"agree": 0, "neutral": 2, "disagree": 5},
            "阳虚质": {"agree": 0, "neutral": 2, "disagree": 4},
        },
    },
    {
        "id": 2,
        "question": "您是否比一般人怕冷，手脚容易冰凉？",
        "category": "寒热感知",
        "constitution_scores": {
            "阳虚质": {"agree": 5, "neutral": 3, "disagree": 0},
            "阴虚质": {"agree": 0, "neutral": 1, "disagree": 3},
            "平和质": {"agree": 0, "neutral": 2, "disagree": 5},
        },
    },
    {
        "id": 3,
        "question": "您是否经常口干舌燥，喜欢喝冷饮？",
        "category": "津液状态",
        "constitution_scores": {
            "阴虚质": {"agree": 5, "neutral": 3, "disagree": 0},
            "湿热质": {"agree": 3, "neutral": 2, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 2, "disagree": 5},
        },
    },
    {
        "id": 4,
        "question": "您的体型是否偏胖，腹部比较松软？",
        "category": "体型特征",
        "constitution_scores": {
            "痰湿质": {"agree": 5, "neutral": 3, "disagree": 0},
            "气虚质": {"agree": 2, "neutral": 1, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 2, "disagree": 5},
        },
    },
    {
        "id": 5,
        "question": "您的面部和头发是否容易出油，容易长痘痘？",
        "category": "皮肤状态",
        "constitution_scores": {
            "湿热质": {"agree": 5, "neutral": 3, "disagree": 0},
            "痰湿质": {"agree": 3, "neutral": 2, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 1, "disagree": 5},
        },
    },
    {
        "id": 6,
        "question": "您的皮肤是否容易瘀青，嘴唇颜色偏暗？",
        "category": "血液循环",
        "constitution_scores": {
            "血瘀质": {"agree": 5, "neutral": 3, "disagree": 0},
            "阴虚质": {"agree": 1, "neutral": 1, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 1, "disagree": 5},
        },
    },
    {
        "id": 7,
        "question": "您是否经常感到情绪低落、闷闷不乐？",
        "category": "情绪状态",
        "constitution_scores": {
            "气郁质": {"agree": 5, "neutral": 3, "disagree": 0},
            "气虚质": {"agree": 2, "neutral": 1, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 1, "disagree": 5},
        },
    },
    {
        "id": 8,
        "question": "您是否容易过敏（如打喷嚏、皮肤痒、食物过敏）？",
        "category": "过敏倾向",
        "constitution_scores": {
            "特禀质": {"agree": 5, "neutral": 3, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 1, "disagree": 5},
        },
    },
    {
        "id": 9,
        "question": "您是否经常感到胸闷、叹气、胁肋胀满？",
        "category": "气机状态",
        "constitution_scores": {
            "气郁质": {"agree": 5, "neutral": 3, "disagree": 0},
            "痰湿质": {"agree": 2, "neutral": 1, "disagree": 0},
            "平和质": {"agree": 0, "neutral": 1, "disagree": 5},
        },
    },
]


class QuizAnswer(BaseModel):
    """单题答案"""
    question_id: int = Field(..., ge=1, le=9, description="题目编号 1-9")
    score: int = Field(..., ge=1, le=5, description="同意程度: 1=非常不同意, 2=不同意, 3=一般, 4=同意, 5=非常同意")


class ConstitutionQuizRequest(BaseModel):
    """体质自测请求"""
    answers: List[QuizAnswer] = Field(..., min_items=9, max_items=9, description="9道题目的答案")


class ConstitutionTypeInfo(BaseModel):
    """单个体质类型信息"""
    name: str = Field(..., description="体质名称")
    score: float = Field(..., description="该体质综合得分")
    description: str = Field(..., description="体质特征描述")


class ConstitutionQuizResponse(BaseModel):
    """体质自测响应"""
    recommended_type: str = Field(..., description="推荐的体质标签")
    confidence: float = Field(..., description="推荐的置信度 (0-1)")
    all_scores: List[ConstitutionTypeInfo] = Field(..., description="所有体质的得分详情")
    diet_advice: Dict[str, list] = Field(..., description="推荐饮食建议")
    characteristics: str = Field(..., description="体质特征描述")
