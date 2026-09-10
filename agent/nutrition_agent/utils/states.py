
from typing import Dict, List, Optional

from typing_extensions import TypedDict

from langchain_openai.chat_models.base import BaseChatOpenAI

from agent.nutrition_agent.utils.structs import NutritionAnalysis, NutritionAdvice, AdviceDependencies


class AgentState(TypedDict):
    """Agent状态管理"""
    image_dir: Optional[str]
    image_data: Optional[str]
    text_description: Optional[str]
    # 预置营养值（包装食品营养成分表：OCR/标注精确值），存在时跳过 AI 估算，仅生成建议
    preset_nutrition: Optional[Dict]
    image_analysis: Optional[str]
    nutrition_analysis: Optional[NutritionAnalysis]
    nutrition_advice: Optional[NutritionAdvice]
    advice_dependencies: Optional[AdviceDependencies]
    user_preferences: Optional[Dict]
    allergies: Optional[List[str]]  # 用户过敏原列表，如["花生","牛奶","海鲜"]
    allergy_warnings: Optional[List[str]]  # 过敏交叉检查警告
    retrieved_documents: List[str]
    conversation_history: List[Dict]
    current_step: str
    error_message: Optional[str]
    vision_model: BaseChatOpenAI
    analysis_model: BaseChatOpenAI


class InputState(TypedDict):
    image_data: Optional[str]
    text_description: Optional[str]
    user_preferences: Optional[Dict]
    # 预置营养值：由包装食品 OCR 得到（精确值），传入后跳过 AI 营养估算
    preset_nutrition: Optional[Dict]


class OutputState(TypedDict):
    nutrition_analysis: Optional[NutritionAnalysis]
    nutrition_advice: Optional[NutritionAdvice]
    advice_dependencies: Optional[AdviceDependencies]
    current_step:Optional[str]
