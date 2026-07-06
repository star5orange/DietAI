from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.runnables import RunnableConfig
from datetime import datetime
from typing import List, Dict, Optional

from agent.utils.configuration import Configuration
from agent.utils.chat_states import ChatState
from agent.common_utils.model_utils import get_model
from agent.utils.prompts import CHAT_SYSTEM_PROMPTS


def initialize_chat_session(state: ChatState, config: RunnableConfig) -> ChatState:
    """初始化聊天会话"""
    configurable = Configuration.from_runnable_config(config)
    
    # 根据会话类型获取系统提示词
    system_prompt = CHAT_SYSTEM_PROMPTS.get(state['session_type'], CHAT_SYSTEM_PROMPTS['default'])
    
    # 初始化对话历史（如果是新会话）
    if not state.get('conversation_history'):
        conversation_history = [SystemMessage(content=system_prompt)]
    else:
        conversation_history = state['conversation_history']
    
    updated_state = ChatState(
        user_message=state['user_message'],
        session_id=state.get('session_id'),
        session_type=state['session_type'],
        user_id=state['user_id'],
        conversation_history=conversation_history,
        user_context=state.get('user_context', {}),
        recent_meals=state.get('recent_meals', []),
        health_goals=state.get('health_goals', {}),
        context_analysis=None,
        response_content="",
        response_metadata={},
        current_step="initialized",
        error_message=None,
        chat_model=get_model(
            model_provider=configurable.analysis_model_provider,
            model_name=configurable.analysis_model
        )
    )
    
    return updated_state


def analyze_conversation_context(state: ChatState) -> ChatState:
    """分析对话上下文"""
    try:
        # 分析用户消息内容和意图
        context_info = []
        
        # 添加用户上下文信息（结构化格式）
        if state.get('user_context'):
            uc = state['user_context']
            if isinstance(uc, dict):
                profile_lines = []
                label_map = {
                    'username': '用户名',
                    'age': '年龄',
                    'gender': '性别',
                    'height': '身高(cm)',
                    'weight': '体重(kg)',
                    'activity_level': '活动水平',
                    'crowd_tag': '人群标签',
                    'constitution_type': '体质类型',
                }
                for k, v in uc.items():
                    label = label_map.get(k, k)
                    profile_lines.append(f"{label}: {v}")
                context_info.append("【用户档案】\n" + "\n".join(profile_lines))
            else:
                context_info.append(f"用户档案: {uc}")
        
        # 添加健康目标信息
        if state.get('health_goals'):
            context_info.append(f"健康目标: {state['health_goals']}")
        
        # 添加最近饮食记录（结构化格式，便于AI理解）
        if state.get('recent_meals'):
            meals_data = state['recent_meals']
            if isinstance(meals_data, dict):
                # 今日饮食汇总
                if meals_data.get('today_summary'):
                    ts = meals_data['today_summary']
                    context_info.append(
                        f"【今日饮食汇总】日期: {ts.get('date', '今天')}, "
                        f"总热量: {ts.get('total_calories', 0)}kcal, "
                        f"蛋白质: {ts.get('total_protein', 0)}g, "
                        f"脂肪: {ts.get('total_fat', 0)}g, "
                        f"碳水: {ts.get('total_carbohydrates', 0)}g"
                    )
                # 最近饮食记录详情
                recent_list = meals_data.get('recent_meals', [])
                if recent_list and isinstance(recent_list, list):
                    meal_details = []
                    for m in recent_list[-5:]:
                        detail = f"{m.get('meal_type_name', m.get('meal_type', ''))} - {m.get('food_name', '未知食物')}"
                        if m.get('description'):
                            detail += f"({m['description']})"
                        nutrients = []
                        if m.get('calories'):
                            nutrients.append(f"{m['calories']}kcal")
                        if m.get('protein'):
                            nutrients.append(f"蛋白质{m['protein']}g")
                        if m.get('fat'):
                            nutrients.append(f"脂肪{m['fat']}g")
                        if m.get('carbohydrates'):
                            nutrients.append(f"碳水{m['carbohydrates']}g")
                        if nutrients:
                            detail += f" [{', '.join(nutrients)}]"
                        detail += f" ({m.get('record_date', '')})"
                        meal_details.append(detail)
                    context_info.append("【最近饮食记录】\n" + "\n".join(meal_details))
            elif isinstance(meals_data, list):
                context_info.append(f"最近饮食: {meals_data[-3:]}")
        
        # 分析会话类型和用户意图
        session_type_context = {
            1: "营养咨询 - 专注于饮食建议、营养搭配、膳食规划",
            2: "健康评估 - 专注于健康状况分析、指标评估、改善建议", 
            3: "食物识别 - 专注于食物识别、营养成分分析",
            4: "运动建议 - 专注于运动计划、健身指导、运动营养",
            5: "养生咨询 - 专注于节气养生、体质调理、药膳茶饮、起居建议"
        }
        
        context_analysis = f"会话类型: {session_type_context.get(state['session_type'], '通用咨询')}"
        if context_info:
            context_analysis += "\n" + "\n".join(context_info)
        
        # 注入体质/人群标签
        if state.get('crowd_tag'):
            context_analysis += f"\n人群标签: {state['crowd_tag']}"
        if state.get('constitution_type'):
            context_analysis += f"\n体质类型: {state['constitution_type']}"
        
        # 注入当前节气信息（养生咨询时特别有用）
        if state.get('session_type') == 5:
            from agent.common_utils.solar_term_utils import get_current_solar_term
            try:
                term_info = get_current_solar_term()
                context_analysis += f"\n当前节气: {term_info}"
            except Exception:
                month = datetime.now().month
                season_map = {3: "春", 4: "春", 5: "春", 6: "夏", 7: "夏", 8: "夏",
                              9: "秋", 10: "秋", 11: "秋", 12: "冬", 1: "冬", 2: "冬"}
                context_analysis += f"\n当前季节: {season_map.get(month, '未知')}"

        # 注入一周趋势数据（营养咨询和健康评估时特别有用）
        if state.get('weekly_trends') and state['session_type'] in [1, 2, 4]:
            trends = state['weekly_trends']
            summary = trends.get('summary', {})
            context_analysis += (
                f"\n一周饮食趋势: 平均每日{summary.get('avg_daily_calories', 0)}kcal, "
                f"蛋白质{summary.get('avg_daily_protein', 0)}g, "
                f"脂肪{summary.get('avg_daily_fat', 0)}g, "
                f"碳水{summary.get('avg_daily_carbs', 0)}g, "
                f"共记录{summary.get('recorded_days', 0)}天"
            )
        
        updated_state = state.copy()
        updated_state['context_analysis'] = context_analysis
        updated_state['current_step'] = "context_analyzed"
        
        return updated_state
        
    except Exception as e:
        updated_state = state.copy()
        updated_state['error_message'] = f"上下文分析失败: {str(e)}"
        updated_state['current_step'] = "context_analysis_failed"
        return updated_state


def generate_chat_response(state: ChatState) -> ChatState:
    """生成聊天回复"""
    try:
        # 构建消息历史
        messages = list(state['conversation_history'])
        
        # 添加上下文信息到系统消息中
        if state.get('context_analysis'):
            context_message = SystemMessage(
                content=f"以下是用户的实时数据，请务必参考这些数据来回答用户的问题：\n\n{state['context_analysis']}"
            )
            messages.append(context_message)
        
        # 添加用户消息
        user_message = HumanMessage(content=state['user_message'])
        messages.append(user_message)
        
        # 调用模型生成回复
        response = state['chat_model'].invoke(messages)
        
        # 更新对话历史
        updated_history = messages + [response]
        
        updated_state = state.copy()
        updated_state['conversation_history'] = updated_history
        updated_state['response_content'] = response.content
        updated_state['response_metadata'] = {
            "model": state['chat_model'].model_name,
            "session_type": state['session_type'],
            "timestamp": datetime.now().isoformat(),
            "context_used": bool(state.get('context_analysis'))
        }
        updated_state['current_step'] = "response_generated"
        
        return updated_state
        
    except Exception as e:
        updated_state = state.copy()
        updated_state['error_message'] = f"生成回复失败: {str(e)}"
        updated_state['current_step'] = "response_generation_failed"
        return updated_state


def format_chat_response(state: ChatState) -> ChatState:
    """格式化聊天回复"""
    try:
        # 构建最终响应数据
        from agent.utils.structs import ChatResponse
        
        chat_response = {
            "success": True,
            "response_content": state['response_content'],
            "session_id": state.get('session_id'),
            "session_type": state['session_type'],
            "metadata": state.get('response_metadata', {}),
            "suggestions": generate_suggestions_by_type(state['session_type'], state['user_message'])
        }
        
        updated_state = state.copy()
        updated_state['current_step'] = "completed"
        
        # 将格式化的响应存储在状态中
        updated_state['formatted_response'] = chat_response
        
        return updated_state
        
    except Exception as e:
        updated_state = state.copy()
        updated_state['error_message'] = f"格式化回复失败: {str(e)}"
        updated_state['current_step'] = "formatting_failed"
        return updated_state


def generate_suggestions_by_type(session_type: int, user_message: str) -> List[str]:
    """根据会话类型和用户消息生成建议"""
    message_lower = user_message.lower()
    
    if session_type == 1:  # 营养咨询
        if any(keyword in message_lower for keyword in ["减肥", "减重"]):
            return [
                "查看我的每日营养摄入分析",
                "制定个人减重计划",
                "推荐低热量食谱"
            ]
        elif any(keyword in message_lower for keyword in ["增肌", "健身"]):
            return [
                "了解蛋白质摄入建议",
                "查看运动营养指南",
                "制定增肌饮食计划"
            ]
        else:
            return [
                "分析我的饮食习惯",
                "获取个性化营养建议",
                "查看营养知识库"
            ]
    
    elif session_type == 2:  # 健康评估
        return [
            "查看我的健康报告",
            "分析营养摄入趋势",
            "获取改善建议"
        ]
    
    elif session_type == 3:  # 食物识别
        return [
            "上传食物图片进行识别",
            "查看营养成分详情",
            "记录到饮食日记"
        ]
    
    elif session_type == 4:  # 运动建议
        return [
            "制定运动计划",
            "了解运动营养搭配",
            "查看健身指导"
        ]
    
    elif session_type == 5:  # 养生咨询
        if any(keyword in message_lower for keyword in ["体质", "气虚", "阳虚", "阴虚", "痰湿", "湿热", "血瘀", "气郁", "特禀", "平和"]):
            return [
                "了解我的体质调理方案",
                "推荐适合体质的食材",
                "查看体质养生茶饮"
            ]
        elif any(keyword in message_lower for keyword in ["节气", "季节", "春夏秋冬"]):
            return [
                "查看当前节气养生建议",
                "了解应季食材推荐",
                "获取节气起居指南"
            ]
        else:
            return [
                "查看当前节气养生建议",
                "了解我的体质调理方案",
                "推荐养生药膳和茶饮",
                "获取起居作息建议"
            ]
    
    else:
        return [
            "开始营养咨询",
            "进行健康评估",
            "识别食物营养"
        ]