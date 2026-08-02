"""
LangGraph 聊天 Agent 路由
集成聊天机器人功能，支持与后端对话系统的完整交互
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta
from typing import Optional, Dict, Any, List, AsyncGenerator
import json
import logging

from shared.models.database import get_db
from shared.models import schemas, user_models, conversation_models
from shared.utils.auth import get_current_user
from shared.config.redis_config import cache_service
from langgraph_sdk import get_client
from agent.chat_agent import chat_graph
from agent.common_utils.configuration import get_agent_model_config

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["AI对话"])


def _coerce_optional_int(value: Any) -> Optional[int]:
    if value in (None, ""):
        return None
    return int(value)


def _coerce_int(value: Any, default: int) -> int:
    if value in (None, ""):
        return default
    return int(value)


async def _resolve_chat_params(
    request: Optional[Request],
    session_id: Optional[int],
    message: str,
    session_type: int,
) -> tuple[Optional[int], str, int, Optional[int]]:
    """Accept chat params from query, JSON body, or form body."""
    body: dict[str, Any] = {}
    content_type = request.headers.get("content-type", "") if request else ""

    try:
        if request and "application/json" in content_type:
            payload = await request.json()
            if isinstance(payload, dict):
                body = payload
        elif request and "form" in content_type:
            form = await request.form()
            body = dict(form)
    except Exception:
        body = {}

    resolved_session_id = _coerce_optional_int(body.get("session_id", session_id))
    resolved_message = str(body.get("message", message) or "")
    resolved_session_type = _coerce_int(body.get("session_type", session_type), 1)
    resolved_pet_id = _coerce_optional_int(body.get("pet_id"))

    return resolved_session_id, resolved_message, resolved_session_type, resolved_pet_id


async def _run_chat_agent(
    message: str,
    session_id: int,
    session_type: int,
    current_user: user_models.User,
    db: Session,
) -> tuple[str, dict[str, Any], list[str]]:
    # 宠物健康咨询时不加载人的数据，完全隔离
    if session_type == 6:
        user_context, recent_meals, health_goals, weekly_trends = {}, [], {}, {}
        diseases, allergies = [], []
    else:
        user_context, _ = await get_user_context(current_user.id, db, session_type)
        recent_meals = await get_recent_meals(current_user.id, db)
        health_goals = await get_health_goals(current_user.id, db)
        weekly_trends = await get_weekly_trends(current_user.id, db)
        diseases = await get_user_diseases(current_user.id, db)
        allergies = await get_user_allergies(current_user.id, db)
    conversation_history = await get_conversation_history(session_id, db)
    if (
        conversation_history
        and conversation_history[-1].get("role") == "user"
        and conversation_history[-1].get("content") == message
    ):
        conversation_history = conversation_history[:-1]

    result = await chat_graph.ainvoke(
        {
            "user_message": message,
            "session_id": str(session_id),
            "session_type": session_type,
            "user_id": current_user.id,
            "user_context": user_context,
            "recent_meals": recent_meals,
            "health_goals": health_goals,
            "weekly_trends": weekly_trends,
            "diseases": diseases,
            "allergies": allergies,
            "conversation_history": conversation_history,
        },
        config={"configurable": get_agent_model_config(include_vision=False)},
    )

    if result.get("error_message"):
        raise RuntimeError(result["error_message"])

    formatted = result.get("formatted_response") or {}
    full_response = result.get("response_content") or formatted.get("response_content") or ""
    metadata = result.get("response_metadata") or formatted.get("metadata") or {}
    suggestions = formatted.get("suggestions") or []

    return full_response, metadata, suggestions



@router.post("/send-message-stream")
async def send_chat_message_stream(
    request: Request = None,
    session_id: Optional[int] = None,
    message: str = "",
    session_type: int = 1,
    pet_id: Optional[int] = None,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """发送聊天消息并返回流式响应"""
    session_id, message, session_type, pet_id = await _resolve_chat_params(
        request, session_id, message, session_type
    )
    logger.info(f"[CHAT-ROUTER] send-message-stream session_type={session_type}, pet_id={pet_id}, msg_len={len(message)}")
    
    async def generate_response() -> AsyncGenerator[str, None]:
        try:
            # 1. 处理会话
            session = None
            if session_id:
                # 验证已存在的会话
                session = db.query(conversation_models.ConversationSession).filter(
                    conversation_models.ConversationSession.id == session_id,
                    conversation_models.ConversationSession.user_id == current_user.id
                ).first()
                
                if not session:
                    yield f"data: {json.dumps({'type': 'error', 'message': '对话会话不存在'}, ensure_ascii=False)}\n\n"
                    yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
                    return
            else:
                # 创建新会话
                session = conversation_models.ConversationSession(
                    user_id=current_user.id,
                    session_type=session_type,
                    title=f"对话 - {datetime.now().strftime('%Y%m%d %H:%M')}",
                    status=1
                )
                db.add(session)
                db.commit()
                db.refresh(session)
            
            # 发送会话信息
            yield f"data: {json.dumps({'type': 'session', 'data': {'session_id': session.id}})}\n\n"
            
            # 2. 创建用户消息记录
            user_message = conversation_models.ConversationMessage(
                session_id=session.id,
                message_type=1,  # 用户消息
                content=message
            )
            db.add(user_message)
            db.commit()
            db.refresh(user_message)

            # 3. 获取用户上下文数据（宠物咨询时跳过人的数据）
            if session_type == 6:
                user_context, advisor_system_prompt = {}, ''
                recent_meals, health_goals, weekly_trends = [], {}, {}
                diseases, allergies = [], []
                crowd_tag = None
                constitution_type = None
            else:
                user_context, advisor_system_prompt = await get_user_context(current_user.id, db, session_type)
                recent_meals = await get_recent_meals(current_user.id, db)
                health_goals = await get_health_goals(current_user.id, db)
                weekly_trends = await get_weekly_trends(current_user.id, db)
                diseases = await get_user_diseases(current_user.id, db)
                allergies = await get_user_allergies(current_user.id, db)
                # 提取人群标签和体质类型
                crowd_tag = user_context.get('crowd_tag')
                constitution_type = user_context.get('constitution_type')
            conversation_history = await get_conversation_history(session.id, db)

            # M3: 宠物健康咨询时加载宠物上下文
            pet_context = None
            if session_type == 6 and pet_id:
                try:
                    from shared.models.pet_models import PetProfile
                    from shared.services.pet_nutrition_calc import check_daily_completion, calculate_daily_targets
                    pet = db.query(PetProfile).filter(
                        PetProfile.id == pet_id,
                        PetProfile.user_id == current_user.id
                    ).first()
                    if pet:
                        today_summary = check_daily_completion(db, pet_id)
                        nutrition_targets = calculate_daily_targets(pet)
                        # 获取最新体重
                        latest_weight = None
                        try:
                            from shared.models.pet_models import PetWeightRecord
                            latest_w = db.query(PetWeightRecord).filter(
                                PetWeightRecord.pet_id == pet_id
                            ).order_by(PetWeightRecord.measured_at.desc()).first()
                            if latest_w:
                                latest_weight = float(latest_w.weight) if latest_w.weight else None
                        except Exception:
                            pass
                        pet_context = {
                            'pet_id': pet.id,
                            'pet_name': pet.name,
                            'species': pet.species,
                            'breed': pet.breed,
                            'gender': pet.gender,
                            'birth_date': str(pet.birth_date) if pet.birth_date else None,
                            'weight': latest_weight,
                            'is_neutered': pet.is_neutered,
                            'daily_calories': nutrition_targets.get('daily_calories'),
                            'daily_protein': nutrition_targets.get('daily_protein_g'),
                            'today_intake': today_summary,
                        }
                        # 加载疫苗记录
                        try:
                            from shared.models.pet_models import PetVaccineRecord
                            vaccines = db.query(PetVaccineRecord).filter(
                                PetVaccineRecord.pet_id == pet_id
                            ).order_by(PetVaccineRecord.vaccinated_at.desc()).limit(10).all()
                            pet_context['vaccines'] = [{
                                'name': v.vaccine_name or '',
                                'date': v.vaccinated_at.isoformat() if v.vaccinated_at else '',
                                'next_date': v.next_vaccination_date.isoformat() if v.next_vaccination_date else '',
                                'notes': v.notes or '',
                            } for v in vaccines]
                        except Exception:
                            pet_context['vaccines'] = []
                        # 加载驱虫记录
                        try:
                            from shared.models.pet_models import PetDewormingRecord
                            dewormings = db.query(PetDewormingRecord).filter(
                                PetDewormingRecord.pet_id == pet_id
                            ).order_by(PetDewormingRecord.treated_at.desc()).limit(10).all()
                            pet_context['dewormings'] = [{
                                'type': d.deworming_type or '',
                                'date': d.treated_at.isoformat() if d.treated_at else '',
                                'next_date': d.next_treatment_date.isoformat() if d.next_treatment_date else '',
                                'notes': d.notes or '',
                            } for d in dewormings]
                        except Exception:
                            pet_context['dewormings'] = []
                except ImportError:
                    pass
                except Exception as e:
                    logger.warning(f"Failed to load pet context: {e}")

            # 4. 调用 LangGraph Agent
            client = get_client(url="http://127.0.0.1:2024")

            # 创建或获取 LangGraph thread
            if not session.langgraph_thread_id or session.langgraph_thread_id.startswith("local-"):
                thread = await client.threads.create()
                session.langgraph_thread_id = thread['thread_id']
                db.commit()

            # 创建助手（如果需要）
            assistant = await client.assistants.create(
                graph_id="chat_agent",
                config={
                    "configurable": {
                        "analysis_model_provider": "deepseek",
                        "analysis_model": "deepseek-v4-flash"
                    }
                }
            )

            # 5. 流式运行聊天 Agent —— 逐 token 输出
            full_response = ""
            metadata = {}
            suggestions = []

            async for chunk in client.runs.stream(
                assistant_id=assistant["assistant_id"],
                thread_id=session.langgraph_thread_id,
                input={
                    "user_message": message,
                    "session_id": str(session.id),
                    "session_type": session_type,
                    "user_id": current_user.id,
                    "pet_id": pet_id,
                    "user_context": user_context,
                    "recent_meals": recent_meals,
                    "health_goals": health_goals,
                    "weekly_trends": weekly_trends,
                    "crowd_tag": crowd_tag,
                    "constitution_type": constitution_type,
                    "diseases": diseases,
                    "allergies": allergies,
                    "conversation_history": conversation_history,
                    "advisor_system_prompt": advisor_system_prompt,
                    "pet_context": pet_context,
                },
                stream_mode=["custom", "values"]
            ):
                if chunk.event == "custom":
                    # Token 级流式输出：逐字推送给前端
                    content = chunk.data
                    if isinstance(content, str) and content:
                        full_response += content
                        yield f"data: {json.dumps({'type': 'content', 'content': content}, ensure_ascii=False)}\n\n"

                elif chunk.event == "values":
                    state_data = chunk.data
                    if not isinstance(state_data, dict):
                        continue

                    error_msg = state_data.get("error_message")
                    if error_msg:
                        yield f"data: {json.dumps({'type': 'error', 'message': error_msg}, ensure_ascii=False)}\n\n"
                        return

                    # 从最终状态提取元数据和推荐问题
                    formatted = state_data.get("formatted_response") or {}
                    metadata = state_data.get("response_metadata") or formatted.get("metadata") or {}
                    suggestions = formatted.get("suggestions") or []

                    # 兜底：如果没有逐 token 流式输出，则用完整响应
                    if not full_response:
                        full_response = state_data.get("response_content") or formatted.get("response_content") or ""

            # 6. 合规检查：根据 session_type 使用对应的合规检查
            try:
                if session_type == 6:
                    from agent.diet_deep_agent.tools.advisor_style_prompt_manager import check_pet_compliance
                    compliance_result = check_pet_compliance(full_response)
                else:
                    from agent.diet_deep_agent.tools.advisor_style_prompt_manager import check_compliance
                    compliance_result = check_compliance(full_response)
                if not compliance_result.get("compliant", True):
                    logger.warning(f"Compliance violation in chat response: {compliance_result.get('violated_keyword')}")
            except Exception:
                pass

            # 7. 创建AI回复消息记录
            ai_message = conversation_models.ConversationMessage(
                session_id=session.id,
                message_type=2,
                content=full_response,
                message_metadata={
                    **metadata,
                    "suggestions": suggestions,
                    "stream_generated": True,
                    "agent_invocation": "local_langgraph",
                }
            )
            db.add(ai_message)
            session.last_message_at = datetime.now()
            session.updated_at = datetime.now()
            db.commit()
            db.refresh(ai_message)

            context_data = {
                "last_user_message": message,
                "last_ai_response": full_response,
                "last_message_time": ai_message.created_at.isoformat(),
                "session_type": session.session_type
            }
            cache_service.cache_conversation_context(str(session.id), context_data)

            yield f"data: {json.dumps({'type': 'complete', 'message_id': ai_message.id}, ensure_ascii=False)}\n\n"
            return
            
        except Exception as e:
            db.rollback()
            yield f"data: {json.dumps({'type': 'error', 'message': f'发送消息失败: {str(e)}'}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
    
    return StreamingResponse(
        generate_response(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control"
        }
    )


@router.post("/send-message", response_model=schemas.BaseResponse)
async def send_chat_message(
    request: Request = None,
    session_id: Optional[int] = None,
    message: str = "",
    session_type: int = 1,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """发送聊天消息并获取AI回复"""
    session_id, message, session_type = await _resolve_chat_params(
        request, session_id, message, session_type
    )
    
    try:
        # 1. 处理会话
        if session_id:
            # 验证已存在的会话
            session = db.query(conversation_models.ConversationSession).filter(
                conversation_models.ConversationSession.id == session_id,
                conversation_models.ConversationSession.user_id == current_user.id
            ).first()
            
            if not session:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="对话会话不存在"
                )
        else:
            # 创建新会话
            session = conversation_models.ConversationSession(
                user_id=current_user.id,
                session_type=session_type,
                title=f"对话 - {datetime.now().strftime('%Y%m%d %H:%M')}",
                status=1
            )
            db.add(session)
            db.commit()
            db.refresh(session)
        
        # 2. 创建用户消息记录
        user_message = conversation_models.ConversationMessage(
            session_id=session.id,
            message_type=1,  # 用户消息
            content=message
        )
        db.add(user_message)
        db.commit()
        db.refresh(user_message)

        # 3. 获取用户上下文数据
        user_context, advisor_system_prompt = await get_user_context(current_user.id, db, session_type)
        recent_meals = await get_recent_meals(current_user.id, db)
        health_goals = await get_health_goals(current_user.id, db)
        weekly_trends = await get_weekly_trends(current_user.id, db)
        diseases = await get_user_diseases(current_user.id, db)
        allergies = await get_user_allergies(current_user.id, db)
        conversation_history = await get_conversation_history(session.id, db)

        # 提取人群标签和体质类型
        crowd_tag = user_context.get('crowd_tag')
        constitution_type = user_context.get('constitution_type')

        # 4. 调用 LangGraph Agent
        client = get_client(url="http://127.0.0.1:2024")

        # 创建或获取 LangGraph thread
        if not session.langgraph_thread_id or session.langgraph_thread_id.startswith("local-"):
            thread = await client.threads.create()
            session.langgraph_thread_id = thread['thread_id']
            db.commit()

        # 创建助手（如果需要）
        assistant = await client.assistants.create(
            graph_id="chat_agent",
            config={
                "configurable": {
                    "analysis_model_provider": "deepseek",
                    "analysis_model": "deepseek-v4-flash"
                }
            }
        )

        # 运行聊天 Agent (非流式版本，兼容现有API)
        full_response = ""
        metadata = {}
        suggestions = []

        async for chunk in client.runs.stream(
            assistant_id=assistant["assistant_id"],
            thread_id=session.langgraph_thread_id,
            input={
                "user_message": message,
                "session_id": str(session.id),
                "session_type": session_type,
                "user_id": current_user.id,
                "user_context": user_context,
                "recent_meals": recent_meals,
                "health_goals": health_goals,
                "weekly_trends": weekly_trends,
                "crowd_tag": crowd_tag,
                "constitution_type": constitution_type,
                "diseases": diseases,
                "allergies": allergies,
                "conversation_history": conversation_history,
                "advisor_system_prompt": advisor_system_prompt
            },
            stream_mode="values"
        ):
            if chunk.event != "values":
                continue

            state_data = chunk.data
            if not isinstance(state_data, dict):
                continue

            response_content = state_data.get("response_content", "")
            if response_content:
                full_response = response_content

        # 5. 获取AI回复
        ai_response = full_response if full_response else '抱歉，我现在无法回复您的消息。'
        ai_message = conversation_models.ConversationMessage(
            session_id=session.id,
            message_type=2,
            content=ai_response,
            message_metadata={
                **metadata,
                "suggestions": suggestions,
                "agent_invocation": "local_langgraph",
            }
        )
        db.add(ai_message)

        session.last_message_at = datetime.now()
        session.updated_at = datetime.now()

        db.commit()
        db.refresh(ai_message)

        context_data = {
            "last_user_message": message,
            "last_ai_response": ai_response,
            "last_message_time": ai_message.created_at.isoformat(),
            "session_type": session.session_type
        }
        cache_service.cache_conversation_context(str(session.id), context_data)

        return schemas.BaseResponse(
            success=True,
            message="消息发送成功",
            data={
                "session_id": session.id,
                "langgraph_thread_id": session.langgraph_thread_id,
                "user_message": {
                    "id": user_message.id,
                    "content": user_message.content,
                    "created_at": user_message.created_at.isoformat()
                },
                "ai_response": {
                    "id": ai_message.id,
                    "content": ai_message.content,
                    "metadata": ai_message.message_metadata,
                    "created_at": ai_message.created_at.isoformat()
                },
                "suggestions": suggestions
            }
        )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"发送消息失败: {str(e)}"
        )


@router.post("/start-session", response_model=schemas.BaseResponse)
async def start_chat_session(
    session_data: schemas.ConversationSessionCreate,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """开始新的聊天会话"""
    
    try:
        # 创建新会话
        session = conversation_models.ConversationSession(
            user_id=current_user.id,
            session_type=session_data.session_type,
            title=session_data.title or f"对话 - {datetime.now().strftime('%Y%m%d %H:%M')}",
            status=1
        )
        
        db.add(session)
        db.commit()
        db.refresh(session)
        
        return schemas.BaseResponse(
            success=True,
            message="聊天会话创建成功",
            data={
                "session_id": session.id,
                "langgraph_thread_id": session.langgraph_thread_id,
                "session_type": session.session_type,
                "title": session.title,
                "created_at": session.created_at.isoformat()
            }
        )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建聊天会话失败: {str(e)}"
        )


@router.get("/sessions/{session_id}/context", response_model=schemas.BaseResponse)
async def get_session_context(
    session_id: int,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取会话上下文信息"""
    
    # 验证会话权限
    session = db.query(conversation_models.ConversationSession).filter(
        conversation_models.ConversationSession.id == session_id,
        conversation_models.ConversationSession.user_id == current_user.id
    ).first()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="对话会话不存在"
        )
    
    try:
        # 获取上下文数据
        user_context, _ = await get_user_context(current_user.id, db, session.session_type)
        recent_meals = await get_recent_meals(current_user.id, db)
        health_goals = await get_health_goals(current_user.id, db)
        
        # 获取缓存的对话上下文
        cached_context = cache_service.get_conversation_context(str(session_id))
        
        return schemas.BaseResponse(
            success=True,
            message="获取会话上下文成功",
            data={
                "session_id": session_id,
                "user_context": user_context,
                "recent_meals": recent_meals,
                "health_goals": health_goals,
                "cached_context": cached_context
            }
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取会话上下文失败: {str(e)}"
        )


# 辅助函数
async def get_user_context(user_id: int, db: Session, session_type: int = 0):
    """获取用户上下文信息，根据 session_type 构建对应的 AI 顾问风格 Prompt"""
    user = db.query(user_models.User).filter(user_models.User.id == user_id).first()
    if not user:
        return {}, ""

    # 获取用户档案信息（使用 savepoint 避免回滚影响外部事务）
    user_profile = None
    try:
        nested = db.begin_nested()
        user_profile = db.query(user_models.UserProfile).filter(
            user_models.UserProfile.user_id == user_id
        ).first()
    except Exception as e:
        logger.warning(f"查询UserProfile失败: {e}")
        try:
            nested.rollback()
        except Exception:
            pass

    context = {
        "username": user.username,
        "age": (date.today().year - user_profile.birth_date.year - ((date.today().month, date.today().day) < (user_profile.birth_date.month, user_profile.birth_date.day))) if user_profile and user_profile.birth_date else None,
        "gender": user_profile.gender if user_profile else None,
        "height": float(user_profile.height) if user_profile and user_profile.height else None,
        "weight": float(user_profile.weight) if user_profile and user_profile.weight else None,
        "activity_level": user_profile.activity_level if user_profile else None,
        "crowd_tag": user_profile.crowd_tag if user_profile else None,
        "constitution_type": user_profile.constitution_type if user_profile else None,
    }
    
    is_pet_session = (session_type == 6)

    # 根据 session_type 构建不同的 AI 顾问风格 Prompt
    advisor_system_prompt = ""
    try:
        from shared.services.advisor_service import get_advisor_settings
        advisor_settings = get_advisor_settings(db, user_id)
        if advisor_settings:
            if is_pet_session:
                # --- 宠物健康顾问模式：使用宠物专属风格 ---
                from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_pet_style_prompt
                context["pet_advisor_style"] = advisor_settings.get("pet_advisor_style")
                context["pet_focus_goal"] = advisor_settings.get("pet_focus_goal")
                context["advisor_response_style"] = advisor_settings.get("response_style")
                advisor_system_prompt = build_pet_style_prompt(
                    pet_advisor_style=advisor_settings.get("pet_advisor_style", "vet_assistant"),
                    focus_goal=advisor_settings.get("pet_focus_goal"),
                    response_style=advisor_settings.get("response_style", "detailed")
                )
                logger.info(f"[PET-CHAT] session_type={session_type}, is_pet={True}, "
                            f"pet_style={advisor_settings.get('pet_advisor_style', 'vet_assistant')}, "
                            f"prompt_len={len(advisor_system_prompt)}")
            else:
                # --- 人类营养师模式：使用人类顾问风格 ---
                from agent.diet_deep_agent.tools.advisor_style_prompt_manager import build_style_prompt
                context["advisor_style"] = advisor_settings.get("advisor_style")
                context["advisor_focus_goal"] = advisor_settings.get("focus_goal")
                context["advisor_focus_nutrient"] = advisor_settings.get("focus_nutrient")
                context["advisor_response_style"] = advisor_settings.get("response_style")
                advisor_system_prompt = build_style_prompt(
                    advisor_style=advisor_settings.get("advisor_style", "nutritionist"),
                    focus_goal=advisor_settings.get("focus_goal"),
                    focus_nutrient=advisor_settings.get("focus_nutrient"),
                    response_style=advisor_settings.get("response_style", "detailed")
                )
                logger.info(f"[HUMAN-CHAT] session_type={session_type}, is_pet={False}, "
                            f"style={advisor_settings.get('advisor_style', 'nutritionist')}, "
                            f"prompt_len={len(advisor_system_prompt)}")
        else:
            logger.info(f"[CHAT] session_type={session_type}, is_pet={is_pet_session}, "
                        f"no_advisor_settings")
    except Exception:
        logger.warning(f"[CHAT] Failed to build advisor prompt for session_type={session_type}", exc_info=True)
        pass  # 非阻塞，获取失败不影响主流程
    
    return {k: v for k, v in context.items() if v is not None}, advisor_system_prompt


async def get_recent_meals(user_id: int, db: Session, limit: int = 5) -> List[Dict[str, Any]]:
    """获取最近的饮食记录，包含今日汇总"""
    try:
        from shared.models.food_models import FoodRecord, DailyNutritionSummary
        from sqlalchemy import func
        from datetime import date

        # 获取今日饮食汇总
        today = date.today()
        today_summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date == today
        ).first()

        summary_data = None
        if today_summary:
            summary_data = {
                "date": today.isoformat(),
                "total_calories": float(today_summary.total_calories) if today_summary.total_calories else 0,
                "total_protein": float(today_summary.total_protein) if today_summary.total_protein else 0,
                "total_fat": float(today_summary.total_fat) if today_summary.total_fat else 0,
                "total_carbohydrates": float(today_summary.total_carbohydrates) if today_summary.total_carbohydrates else 0,
            }

        recent_records = db.query(FoodRecord).filter(
            FoodRecord.user_id == user_id
        ).order_by(FoodRecord.record_date.desc(), FoodRecord.created_at.desc()).limit(limit).all()

        meal_type_map = {1: "早餐", 2: "午餐", 3: "晚餐", 4: "加餐", 5: "夜宵"}
        meals = []
        for record in recent_records:
            meal_data = {
                "food_name": record.food_name,
                "description": record.description,
                "meal_type": record.meal_type,
                "meal_type_name": meal_type_map.get(record.meal_type, "其他"),
                "record_date": record.record_date.isoformat(),
            }

            # 安全地处理nutrition_detail中的decimal字段
            if record.nutrition_detail:
                nd = record.nutrition_detail
                if nd.calories is not None:
                    meal_data["calories"] = float(nd.calories)
                if nd.protein is not None:
                    meal_data["protein"] = float(nd.protein)
                if nd.fat is not None:
                    meal_data["fat"] = float(nd.fat)
                if nd.carbohydrates is not None:
                    meal_data["carbohydrates"] = float(nd.carbohydrates)

            meals.append(meal_data)

        result = {"recent_meals": meals}
        if summary_data:
            result["today_summary"] = summary_data

        return result
    except Exception as e:
        # 如果表不存在或其他错误，返回空列表，并回滚避免事务污染
        print(f"Error getting recent meals: {e}")
        db.rollback()
        return []


async def get_health_goals(user_id: int, db: Session) -> Dict[str, Any]:
    """获取健康目标"""
    try:
        from shared.models.user_models import HealthGoal
        
        goals = db.query(HealthGoal).filter(
            HealthGoal.user_id == user_id,
            HealthGoal.status == 1  # 活跃状态
        ).first()
        
        if not goals:
            return {}
        
        result = {}
        
        # 安全地转换 decimal 字段
        if hasattr(goals, 'goal_type') and goals.goal_type is not None:
            result["goal_type"] = goals.goal_type
            
        if hasattr(goals, 'target_weight') and goals.target_weight is not None:
            result["target_weight"] = float(goals.target_weight)
            
        if hasattr(goals, 'target_body_fat') and goals.target_body_fat is not None:
            result["target_body_fat"] = float(goals.target_body_fat)
            
        if hasattr(goals, 'daily_calorie_target') and goals.daily_calorie_target is not None:
            result["daily_calorie_target"] = int(goals.daily_calorie_target)
            
        if hasattr(goals, 'target_date') and goals.target_date is not None:
            result["target_date"] = goals.target_date.isoformat()
        
        return result
        
    except Exception as e:
        # 如果表不存在或其他错误，返回空字典，并回滚避免事务污染
        print(f"Error getting health goals: {e}")
        db.rollback()
        return {}


async def get_weekly_trends(user_id: int, db: Session) -> Dict[str, Any]:
    """获取用户一周饮食趋势数据，供 AI 分析使用"""
    try:
        from shared.models.food_models import FoodRecord, NutritionDetail
        from sqlalchemy import func
        from datetime import timedelta

        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=6)

        # 按天汇总营养数据
        daily_data = []
        for i in range(7):
            day = start_date + timedelta(days=i)
            stats = db.query(
                func.coalesce(func.sum(NutritionDetail.calories), 0).label('total_calories'),
                func.coalesce(func.sum(NutritionDetail.protein), 0).label('total_protein'),
                func.coalesce(func.sum(NutritionDetail.fat), 0).label('total_fat'),
                func.coalesce(func.sum(NutritionDetail.carbohydrates), 0).label('total_carbs'),
                func.count(FoodRecord.id).label('meal_count'),
            ).join(
                NutritionDetail, FoodRecord.id == NutritionDetail.food_record_id
            ).filter(
                FoodRecord.user_id == user_id,
                FoodRecord.record_date == day
            ).first()

            daily_data.append({
                "date": day.isoformat(),
                "calories": float(stats.total_calories) if stats else 0,
                "protein": float(stats.total_protein) if stats else 0,
                "fat": float(stats.total_fat) if stats else 0,
                "carbs": float(stats.total_carbs) if stats else 0,
                "meal_count": stats.meal_count if stats else 0,
            })

        # 计算平均值
        valid_days = [d for d in daily_data if d["calories"] > 0]
        if valid_days:
            avg_cal = sum(d["calories"] for d in valid_days) / len(valid_days)
            avg_protein = sum(d["protein"] for d in valid_days) / len(valid_days)
            avg_fat = sum(d["fat"] for d in valid_days) / len(valid_days)
            avg_carbs = sum(d["carbs"] for d in valid_days) / len(valid_days)
        else:
            avg_cal = avg_protein = avg_fat = avg_carbs = 0

        return {
            "daily_data": daily_data,
            "summary": {
                "avg_daily_calories": round(avg_cal, 1),
                "avg_daily_protein": round(avg_protein, 1),
                "avg_daily_fat": round(avg_fat, 1),
                "avg_daily_carbs": round(avg_carbs, 1),
                "recorded_days": len(valid_days),
            }
        }
    except Exception as e:
        print(f"Error getting weekly trends: {e}")
        db.rollback()
        return {}


async def get_conversation_history(session_id: int, db: Session, limit: int = 10) -> List[Dict[str, Any]]:
    """获取对话历史"""
    messages = db.query(conversation_models.ConversationMessage).filter(
        conversation_models.ConversationMessage.session_id == session_id
    ).order_by(conversation_models.ConversationMessage.created_at.asc()).limit(limit).all()
    
    history = []
    for msg in messages:
        history.append({
            "role": "user" if msg.message_type == 1 else "assistant",
            "content": msg.content,
            "timestamp": msg.created_at.isoformat()
        })
    
    return history


async def get_user_diseases(user_id: int, db: Session) -> List[Dict[str, Any]]:
    """获取用户疾病信息"""
    try:
        diseases = db.query(user_models.Disease).filter(
            user_models.Disease.user_id == user_id
        ).all()

        return [
            {
                "disease_name": d.disease_name,
                "severity_level": d.severity_level,
                "is_current": d.is_current,
                "notes": d.notes or "",
            }
            for d in diseases
        ]
    except Exception as e:
        logger.warning(f"获取用户疾病信息失败: {e}")
        db.rollback()
        return []


async def get_user_allergies(user_id: int, db: Session) -> List[Dict[str, Any]]:
    """获取用户过敏信息"""
    try:
        allergies = db.query(user_models.Allergy).filter(
            user_models.Allergy.user_id == user_id
        ).all()

        allergen_type_map = {1: "食物", 2: "药物", 3: "环境", 4: "其他"}

        return [
            {
                "allergen_name": a.allergen_name,
                "allergen_type": a.allergen_type,
                "allergen_type_name": allergen_type_map.get(a.allergen_type, "未知"),
                "severity_level": a.severity_level,
                "reaction_description": a.reaction_description,
            }
            for a in allergies
        ]
    except Exception as e:
        logger.warning(f"获取用户过敏信息失败: {e}")
        db.rollback()
        return []


@router.get("/sessions", response_model=schemas.BaseResponse)
async def get_chat_sessions(
        session_type: Optional[int] = None,
        keyword: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 50,
        current_user: user_models.User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """获取用户的聊天会话列表 - 支持关键词搜索和日期范围筛选"""
    try:
        query = db.query(conversation_models.ConversationSession).filter(
            conversation_models.ConversationSession.user_id == current_user.id
        )

        if session_type:
            query = query.filter(conversation_models.ConversationSession.session_type == session_type)

        # 关键词搜索：按会话标题模糊匹配
        if keyword and keyword.strip():
            query = query.filter(
                conversation_models.ConversationSession.title.ilike(f"%{keyword.strip()}%")
            )

        # 日期范围筛选：按 last_message_at 或 created_at
        if start_date:
            try:
                start_dt = datetime.strptime(start_date.strip(), "%Y-%m-%d")
                query = query.filter(
                    db.or_(
                        conversation_models.ConversationSession.last_message_at >= start_dt,
                        db.and_(
                            conversation_models.ConversationSession.last_message_at.is_(None),
                            conversation_models.ConversationSession.created_at >= start_dt,
                        ),
                    )
                )
            except ValueError:
                pass

        if end_date:
            try:
                end_dt = datetime.strptime(end_date.strip(), "%Y-%m-%d") + timedelta(days=1)
                query = query.filter(
                    db.or_(
                        conversation_models.ConversationSession.last_message_at < end_dt,
                        db.and_(
                            conversation_models.ConversationSession.last_message_at.is_(None),
                            conversation_models.ConversationSession.created_at < end_dt,
                        ),
                    )
                )
            except ValueError:
                pass

        sessions = query.order_by(
            conversation_models.ConversationSession.last_message_at.desc().nullslast(),
            conversation_models.ConversationSession.created_at.desc()
        ).limit(limit).all()

        sessions_data = []
        for session in sessions:
            # 获取最后一条消息
            last_message = db.query(conversation_models.ConversationMessage).filter(
                conversation_models.ConversationMessage.session_id == session.id
            ).order_by(conversation_models.ConversationMessage.created_at.desc()).first()

            sessions_data.append({
                "id": session.id,
                "title": session.title,
                "session_type": session.session_type,
                "session_type_name": get_session_type_name(session.session_type),
                "last_message": last_message.content[:50] + "..." if last_message and len(
                    last_message.content) > 50 else last_message.content if last_message else "暂无消息",
                "last_message_time": session.last_message_at.isoformat() if session.last_message_at else session.created_at.isoformat(),
                "message_count": db.query(conversation_models.ConversationMessage).filter(
                    conversation_models.ConversationMessage.session_id == session.id
                ).count()
            })

        return schemas.BaseResponse(
            success=True,
            message="获取会话列表成功",
            data=sessions_data
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取会话列表失败: {str(e)}"
        )


@router.get("/search", response_model=schemas.BaseResponse)
async def search_chat_messages(
        keyword: str,
        session_type: Optional[int] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 20,
        current_user: user_models.User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """按关键词搜索消息内容 - 跨所有会话搜索"""
    try:
        if not keyword or not keyword.strip():
            return schemas.BaseResponse(
                success=True,
                message="请输入搜索关键词",
                data=[]
            )

        kw = keyword.strip()

        # 先查匹配关键字的会话
        session_query = db.query(conversation_models.ConversationSession).filter(
            conversation_models.ConversationSession.user_id == current_user.id
        )

        if session_type:
            session_query = session_query.filter(
                conversation_models.ConversationSession.session_type == session_type
            )

        # 日期范围
        if start_date:
            try:
                start_dt = datetime.strptime(start_date.strip(), "%Y-%m-%d")
                session_query = session_query.filter(
                    conversation_models.ConversationSession.last_message_at >= start_dt
                )
            except ValueError:
                pass

        if end_date:
            try:
                end_dt = datetime.strptime(end_date.strip(), "%Y-%m-%d") + timedelta(days=1)
                session_query = session_query.filter(
                    conversation_models.ConversationSession.last_message_at < end_dt
                )
            except ValueError:
                pass

        user_sessions = session_query.all()
        session_ids = [s.id for s in user_sessions]

        if not session_ids:
            return schemas.BaseResponse(
                success=True,
                message="未找到匹配的对话",
                data=[]
            )

        # 搜索消息内容
        message_query = db.query(conversation_models.ConversationMessage).filter(
            conversation_models.ConversationMessage.session_id.in_(session_ids),
            conversation_models.ConversationMessage.content.ilike(f"%{kw}%")
        ).order_by(
            conversation_models.ConversationMessage.created_at.desc()
        ).limit(limit)

        messages = message_query.all()

        results = []
        for msg in messages:
            session = db.query(conversation_models.ConversationSession).filter(
                conversation_models.ConversationSession.id == msg.session_id
            ).first()

            # 截取匹配关键词前后文（最多 100 字）
            content = msg.content or ""
            idx = content.lower().find(kw.lower())
            snippet_start = max(0, idx - 30)
            snippet_end = min(len(content), idx + len(kw) + 50)
            snippet = content[snippet_start:snippet_end]
            if snippet_start > 0:
                snippet = "..." + snippet
            if snippet_end < len(content):
                snippet = snippet + "..."

            results.append({
                "id": msg.id,
                "session_id": msg.session_id,
                "session_title": session.title if session else "未知对话",
                "session_type": session.session_type if session else 0,
                "session_type_name": get_session_type_name(session.session_type) if session else "",
                "message_type": msg.message_type,
                "content_snippet": snippet,
                "highlight_keyword": kw,
                "created_at": msg.created_at.isoformat()
            })

        return schemas.BaseResponse(
            success=True,
            message=f"找到 {len(results)} 条相关消息",
            data=results
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"搜索消息失败: {str(e)}"
        )


@router.get("/sessions/{session_id}/messages", response_model=schemas.BaseResponse)
async def get_session_messages(
        session_id: int,
        limit: int = 50,
        current_user: user_models.User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """获取会话消息历史 - 前端专用"""
    try:
        # 验证会话权限
        session = db.query(conversation_models.ConversationSession).filter(
            conversation_models.ConversationSession.id == session_id,
            conversation_models.ConversationSession.user_id == current_user.id
        ).first()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="会话不存在"
            )

        # 获取消息
        messages = db.query(conversation_models.ConversationMessage).filter(
            conversation_models.ConversationMessage.session_id == session_id
        ).order_by(conversation_models.ConversationMessage.created_at.asc()).limit(limit).all()

        messages_data = []
        for msg in messages:
            messages_data.append({
                "id": msg.id,
                "role": "user" if msg.message_type == 1 else "assistant",
                "content": msg.content,
                "timestamp": msg.created_at.isoformat(),
                "metadata": msg.message_metadata
            })

        return schemas.BaseResponse(
            success=True,
            message="获取消息历史成功",
            data={
                "session_id": session_id,
                "session_title": session.title,
                "session_type": session.session_type,
                "messages": messages_data
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取消息历史失败: {str(e)}"
        )


@router.delete("/sessions", response_model=schemas.BaseResponse)
async def delete_all_sessions(
        session_type: int = None,
        current_user: user_models.User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """删除当前用户的所有聊天会话（可按类型筛选）"""
    try:
        query = db.query(conversation_models.ConversationSession).filter(
            conversation_models.ConversationSession.user_id == current_user.id
        )
        if session_type is not None:
            query = query.filter(conversation_models.ConversationSession.session_type == session_type)

        sessions = query.all()
        session_ids = [s.id for s in sessions]

        # 删除所有消息
        db.query(conversation_models.ConversationMessage).filter(
            conversation_models.ConversationMessage.session_id.in_(session_ids)
        ).delete(synchronize_session=False)

        # 删除所有会话
        for s in sessions:
            db.delete(s)

        db.commit()

        return schemas.BaseResponse(
            success=True,
            message=f"已删除 {len(sessions)} 个会话"
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除会话失败: {str(e)}"
        )


@router.delete("/sessions/{session_id}", response_model=schemas.BaseResponse)
async def delete_session(
        session_id: int,
        current_user: user_models.User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """删除聊天会话 - 前端专用"""
    try:
        # 验证会话权限
        session = db.query(conversation_models.ConversationSession).filter(
            conversation_models.ConversationSession.id == session_id,
            conversation_models.ConversationSession.user_id == current_user.id
        ).first()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="会话不存在"
            )

        # 删除所有消息
        db.query(conversation_models.ConversationMessage).filter(
            conversation_models.ConversationMessage.session_id == session_id
        ).delete()

        # 删除会话
        db.delete(session)
        db.commit()

        return schemas.BaseResponse(
            success=True,
            message="会话删除成功"
        )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除会话失败: {str(e)}"
        )


def get_session_type_name(session_type: int) -> str:
    """获取会话类型名称"""
    session_types = {
        1: "营养咨询",
        2: "健康评估",
        3: "食物识别",
        4: "运动建议",
        5: "养生咨询",
        6: "宠物健康咨询"
    }
    return session_types.get(session_type, "通用咨询")
