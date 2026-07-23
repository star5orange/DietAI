from typing import Dict, List, Optional, TypedDict, Annotated
from langchain_core.messages import BaseMessage
from langgraph.graph import MessagesState, add_messages
from langchain_openai.chat_models.base import BaseChatOpenAI


class ChatState(TypedDict):
    """聊天机器人状态管理"""
    # 输入信息
    user_message: str
    session_id: Optional[str]
    session_type: int  # 1:营养咨询 2:健康评估 3:食物识别 4:运动建议 5:养生咨询 6:宠物健康
    user_id: int
    pet_id: Optional[int]  # 宠物ID（session_type=6时必填）

    # 上下文信息
    conversation_history: Annotated[List[BaseMessage], add_messages]
    user_context: Optional[Dict]  # 用户档案、健康目标等
    recent_meals: Optional[List[Dict]]  # 最近的饮食记录
    health_goals: Optional[Dict]  # 健康目标
    weekly_trends: Optional[Dict]  # 一周饮食趋势数据
    crowd_tag: Optional[str]  # 人群标签（如"减脂,健身"）
    constitution_type: Optional[str]  # 体质类型（如"气虚","痰湿"）
    advisor_system_prompt: Optional[str]  # AI顾问风格 System Prompt（M2）
    pet_context: Optional[Dict]  # 宠物档案信息（品种、年龄、体重等）

    # 处理过程
    context_analysis: Optional[str]  # 上下文分析结果
    response_content: str  # 生成的回复内容
    response_metadata: Optional[Dict]  # 回复的元数据

    # 控制信息
    current_step: str
    error_message: Optional[str]

    # 模型配置
    chat_model: BaseChatOpenAI


class ChatInputState(TypedDict):
    """聊天输入状态"""
    user_message: str
    session_id: Optional[str]
    session_type: int
    user_id: int
    pet_id: Optional[int]  # 宠物ID
    conversation_history: Optional[List[BaseMessage]]
    user_context: Optional[Dict]
    recent_meals: Optional[List[Dict]]
    health_goals: Optional[Dict]
    weekly_trends: Optional[Dict]
    crowd_tag: Optional[str]
    constitution_type: Optional[str]
    advisor_system_prompt: Optional[str]  # AI顾问风格 System Prompt（M2）
    pet_context: Optional[Dict]  # 宠物档案信息
