from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from typing import List, Optional
from datetime import datetime, date, timedelta
import base64
import json
from langgraph_sdk import get_client
from fastapi.responses import StreamingResponse, Response

from shared.models.database import get_db, SessionLocal
from shared.models.schemas import (
    BaseResponse, FoodRecordCreate, FoodRecordResponse,
    NutritionDetailCreate, NutritionDetailResponse,
    DailyNutritionSummaryResponse, DateRangeParams,
    PaginationParams, FileUploadResponse, AgentAnalysisData, NutritionFacts, Recommendations
)
from shared.utils.auth import get_current_user, AuthService
from shared.models.user_models import User
from shared.models.food_models import FoodRecord, NutritionDetail, DailyNutritionSummary, FoodDatabase
from shared.config.redis_config import cache_service
from shared.config.minio_config import minio_client
from shared.config.settings import get_settings

from agent.common_utils.configuration import get_agent_model_config
from shared.utils.model import decimal_to_float

settings = get_settings()


def _sanitize_analysis_result(result):
    """清理 analysis_result 中的 null 值，防止前端 JSON 解析崩溃"""
    if not isinstance(result, dict):
        return None
    clean = dict(result)
    for key in ("short_comment", "image_description"):
        if clean.get(key) is None:
            clean[key] = ""
    if clean.get("recommendations") is None:
        clean["recommendations"] = {}
    if clean.get("food_items") is None:
        clean["food_items"] = []
    return clean

# 食物营养成分数据库（每100g）
# 从前端 _foodNutritionDB 迁移至后端统一管理
_NUTRITION_DB = {
    '米饭': {'calories': 116, 'protein': 2.6, 'fat': 0.3, 'carbs': 25.9},
    '白米饭': {'calories': 116, 'protein': 2.6, 'fat': 0.3, 'carbs': 25.9},
    '馒头': {'calories': 221, 'protein': 7.0, 'fat': 1.1, 'carbs': 47.0},
    '面条': {'calories': 110, 'protein': 3.5, 'fat': 0.5, 'carbs': 23.0},
    '面包': {'calories': 312, 'protein': 8.3, 'fat': 5.1, 'carbs': 58.6},
    '饺子': {'calories': 196, 'protein': 7.8, 'fat': 6.5, 'carbs': 26.0},
    '包子': {'calories': 174, 'protein': 6.4, 'fat': 4.5, 'carbs': 27.0},
    '粥': {'calories': 46, 'protein': 1.1, 'fat': 0.3, 'carbs': 9.8},
    '白粥': {'calories': 46, 'protein': 1.1, 'fat': 0.3, 'carbs': 9.8},
    '鸡蛋': {'calories': 144, 'protein': 13.3, 'fat': 8.8, 'carbs': 2.8},
    '煮鸡蛋': {'calories': 144, 'protein': 13.3, 'fat': 8.8, 'carbs': 2.8},
    '煎蛋': {'calories': 199, 'protein': 14.1, 'fat': 15.2, 'carbs': 1.2},
    '牛奶': {'calories': 54, 'protein': 3.0, 'fat': 3.2, 'carbs': 3.4},
    '豆浆': {'calories': 31, 'protein': 3.0, 'fat': 1.6, 'carbs': 1.2},
    '酸奶': {'calories': 72, 'protein': 2.5, 'fat': 2.7, 'carbs': 9.3},
    '鸡胸肉': {'calories': 133, 'protein': 19.4, 'fat': 5.0, 'carbs': 2.5},
    '鸡腿': {'calories': 181, 'protein': 16.0, 'fat': 13.0, 'carbs': 0},
    '鸡翅': {'calories': 194, 'protein': 17.4, 'fat': 13.6, 'carbs': 0},
    '红烧肉': {'calories': 337, 'protein': 13.2, 'fat': 30.5, 'carbs': 4.2},
    '排骨': {'calories': 264, 'protein': 16.7, 'fat': 20.4, 'carbs': 3.5},
    '牛肉': {'calories': 125, 'protein': 19.9, 'fat': 4.2, 'carbs': 2.0},
    '猪肉': {'calories': 143, 'protein': 20.3, 'fat': 6.2, 'carbs': 1.5},
    '羊肉': {'calories': 118, 'protein': 20.5, 'fat': 3.9, 'carbs': 0},
    '鱼': {'calories': 104, 'protein': 17.6, 'fat': 3.3, 'carbs': 0},
    '三文鱼': {'calories': 139, 'protein': 17.2, 'fat': 7.8, 'carbs': 0},
    '虾': {'calories': 87, 'protein': 16.4, 'fat': 2.4, 'carbs': 0},
    '豆腐': {'calories': 81, 'protein': 8.1, 'fat': 3.7, 'carbs': 4.2},
    '蔬菜': {'calories': 23, 'protein': 1.5, 'fat': 0.3, 'carbs': 3.5},
    '白菜': {'calories': 18, 'protein': 1.5, 'fat': 0.2, 'carbs': 2.8},
    '西兰花': {'calories': 36, 'protein': 4.1, 'fat': 0.6, 'carbs': 4.3},
    '番茄': {'calories': 15, 'protein': 0.9, 'fat': 0.2, 'carbs': 2.5},
    '西红柿': {'calories': 15, 'protein': 0.9, 'fat': 0.2, 'carbs': 2.5},
    '土豆': {'calories': 76, 'protein': 2.0, 'fat': 0.2, 'carbs': 16.5},
    '黄瓜': {'calories': 15, 'protein': 0.7, 'fat': 0.2, 'carbs': 2.4},
    '胡萝卜': {'calories': 37, 'protein': 1.0, 'fat': 0.2, 'carbs': 7.7},
    '苹果': {'calories': 53, 'protein': 0.2, 'fat': 0.2, 'carbs': 13.5},
    '香蕉': {'calories': 93, 'protein': 1.4, 'fat': 0.2, 'carbs': 22.0},
    '橙子': {'calories': 48, 'protein': 0.8, 'fat': 0.2, 'carbs': 11.1},
    '葡萄': {'calories': 44, 'protein': 0.5, 'fat': 0.2, 'carbs': 10.3},
    '西瓜': {'calories': 25, 'protein': 0.5, 'fat': 0.1, 'carbs': 5.8},
    '草莓': {'calories': 30, 'protein': 1.0, 'fat': 0.2, 'carbs': 6.2},
    '沙拉': {'calories': 35, 'protein': 1.5, 'fat': 1.0, 'carbs': 5.5},
    '汉堡': {'calories': 295, 'protein': 14.0, 'fat': 14.5, 'carbs': 28.0},
    '披萨': {'calories': 266, 'protein': 11.0, 'fat': 10.0, 'carbs': 33.0},
    '炸鸡': {'calories': 279, 'protein': 18.5, 'fat': 18.0, 'carbs': 10.5},
    '薯条': {'calories': 298, 'protein': 3.3, 'fat': 15.0, 'carbs': 36.0},
    '可乐': {'calories': 43, 'protein': 0, 'fat': 0, 'carbs': 10.6},
    '咖啡': {'calories': 2, 'protein': 0.3, 'fat': 0, 'carbs': 0},
    '奶茶': {'calories': 52, 'protein': 0.8, 'fat': 1.5, 'carbs': 9.2},
    '绿茶': {'calories': 1, 'protein': 0, 'fat': 0, 'carbs': 0},
    '火锅': {'calories': 150, 'protein': 8.0, 'fat': 8.5, 'carbs': 10.0},
    '炒饭': {'calories': 174, 'protein': 4.5, 'fat': 6.5, 'carbs': 25.0},
    '炒面': {'calories': 160, 'protein': 4.0, 'fat': 5.5, 'carbs': 24.0},
    '拉面': {'calories': 130, 'protein': 5.0, 'fat': 3.0, 'carbs': 21.0},
    '方便面': {'calories': 472, 'protein': 9.5, 'fat': 21.1, 'carbs': 61.6},
    '饼干': {'calories': 433, 'protein': 7.5, 'fat': 14.8, 'carbs': 70.3},
    '蛋糕': {'calories': 348, 'protein': 7.0, 'fat': 15.0, 'carbs': 46.0},
    '巧克力': {'calories': 544, 'protein': 5.3, 'fat': 31.0, 'carbs': 60.0},
    '冰淇淋': {'calories': 127, 'protein': 2.4, 'fat': 5.3, 'carbs': 17.7},
    '花生': {'calories': 563, 'protein': 24.8, 'fat': 44.3, 'carbs': 21.7},
    '核桃': {'calories': 627, 'protein': 14.9, 'fat': 58.8, 'carbs': 19.1},
    '红枣': {'calories': 276, 'protein': 3.2, 'fat': 0.5, 'carbs': 67.8},
    '燕麦': {'calories': 367, 'protein': 15.0, 'fat': 6.7, 'carbs': 61.6},
    '玉米': {'calories': 112, 'protein': 4.0, 'fat': 1.2, 'carbs': 22.8},
    '紫薯': {'calories': 82, 'protein': 1.5, 'fat': 0.2, 'carbs': 18.0},
    '红薯': {'calories': 86, 'protein': 1.1, 'fat': 0.2, 'carbs': 20.1},
    '茄子': {'calories': 23, 'protein': 1.1, 'fat': 0.2, 'carbs': 3.6},
    '青椒': {'calories': 22, 'protein': 1.0, 'fat': 0.2, 'carbs': 3.7},
    '蘑菇': {'calories': 24, 'protein': 2.7, 'fat': 0.1, 'carbs': 4.1},
    '海带': {'calories': 16, 'protein': 1.2, 'fat': 0.1, 'carbs': 2.1},
    '紫菜': {'calories': 207, 'protein': 26.7, 'fat': 1.1, 'carbs': 22.5},
    '鸡蛋灌饼': {'calories': 248, 'protein': 8.0, 'fat': 11.0, 'carbs': 30.0},
    '油条': {'calories': 386, 'protein': 6.9, 'fat': 17.6, 'carbs': 51.0},
    '烧饼': {'calories': 326, 'protein': 8.0, 'fat': 10.5, 'carbs': 50.0},
    '煎饼果子': {'calories': 235, 'protein': 7.5, 'fat': 8.5, 'carbs': 32.0},
    '小笼包': {'calories': 204, 'protein': 8.0, 'fat': 7.5, 'carbs': 26.0},
    '馄饨': {'calories': 110, 'protein': 5.5, 'fat': 3.0, 'carbs': 14.0},
    '粽子': {'calories': 195, 'protein': 4.5, 'fat': 3.5, 'carbs': 37.0},
    '汤圆': {'calories': 311, 'protein': 5.0, 'fat': 6.0, 'carbs': 60.0},
    '月饼': {'calories': 421, 'protein': 8.0, 'fat': 19.0, 'carbs': 55.0},
}

router = APIRouter(prefix="/foods", tags=["食物记录"])


async def generate_sse_stream(
        food_data: FoodRecordCreate,
        user_id: int
, record_data=None):
    """SSE 流式生成器 — 自行管理 db session，不依赖 FastAPI DI"""
    db = SessionLocal()
    try:
        # 1. 首先发送创建记录的状态
        yield f"data: {json.dumps({'type': 'record_created', 'data': {'status': 'creating', 'message': '正在创建食物记录...'}, 'success': True}, ensure_ascii=False)}\n\n"

        # 创建食物记录
        food_record = FoodRecord(
            user_id=user_id,
            record_date=food_data.record_date,
            record_time=food_data.record_time or datetime.now(),
            meal_type=food_data.meal_type,
            food_name=food_data.food_name,
            description=food_data.description,
            image_url=food_data.image_url,
            recording_method=food_data.recording_method or 1,
            analysis_status=1,  # 待分析
            cost=food_data.cost,
            source_tag=food_data.source_tag,
        )

        db.add(food_record)
        db.commit()
        db.refresh(food_record)

        # 如果有图片URL，使用流式Agent分析（在下方处理）
        if not food_data.image_url and not food_data.description:
            # 清除相关缓存
            cache_key = f"nutrition:daily:{user_id}:{food_data.record_date}"
            cache_service.redis.delete(cache_key)

        # 构建响应数据
        response_data = {
            "id": food_record.id,
            "user_id": food_record.user_id,
            "record_date": food_record.record_date.isoformat(),
            "record_time": food_record.record_time.isoformat() if food_record.record_time else None,
            "meal_type": food_record.meal_type,
            "food_name": food_record.food_name,
            "description": food_record.description,
            "image_url": food_record.image_url,
            "recording_method": food_record.recording_method,
            "analysis_status": food_record.analysis_status,
            "cost": float(food_record.cost) if food_record.cost else None,
            "source_tag": food_record.source_tag,
            "created_at": food_record.created_at.isoformat(),
        }

        yield f"data: {json.dumps({'type': 'record_created', 'data': {'record': response_data, 'status': 'created', 'message': '食物记录创建成功'}, 'success': True}, ensure_ascii=False)}\n\n"

        # 3. 如果有图片URL或文字描述，则使用Agent进行分析
        if food_data.image_url or food_data.description:
            try:
                # 设置分析状态为处理中
                food_record.analysis_status = 2  # 分析中
                db.commit()

                is_text_analysis = not food_data.image_url and bool(food_data.description)
                analysis_type = "文字" if is_text_analysis else "图片"

                yield f"data: {json.dumps({'type': 'analysis_started', 'data': {'status': 'analyzing', 'message': f'开始分析{analysis_type}...'}, 'success': True}, ensure_ascii=False)}\n\n"

                # 使用Agent分析（流式输出）
                analysis_complete_data = None
                print(f"[SSE] 开始调用Agent分析{food_data.image_url or food_data.description}")
                if is_text_analysis:
                    async for chunk in analyze_food_text_with_agent(food_data.description, user_id, db):
                        chunk_type = chunk.get("type")
                        print(f"[SSE] 收到Agent chunk: type={chunk_type}")
                        if chunk_type == "analysis_progress":
                            yield f"data: {json.dumps({'type': 'analysis_progress', 'data': chunk['data'], 'success': True}, ensure_ascii=False)}\n\n"
                        elif chunk_type == "analysis_complete":
                            analysis_complete_data = chunk["data"]
                            serializable_data = {}
                            for k, v in analysis_complete_data.items():
                                if hasattr(v, 'model_dump'):
                                    serializable_data[k] = v.model_dump()
                                elif hasattr(v, 'dict'):
                                    serializable_data[k] = v.dict()
                                else:
                                    serializable_data[k] = v
                            print(f"[SSE] Agent文字分析完成，数据: {list(serializable_data.keys())}")
                            yield f"data: {json.dumps({'type': 'analysis_complete', 'data': serializable_data, 'success': True}, ensure_ascii=False)}\n\n"
                        elif chunk_type == "error":
                            print(f"[SSE] Agent返回错误: {chunk['data']}")
                            yield f"data: {json.dumps({'type': 'error', 'data': chunk['data'], 'success': False}, ensure_ascii=False)}\n\n"
                            break
                else:
                    async for chunk in analyze_food_image_with_agent(food_data.image_url, user_id, db):
                        chunk_type = chunk.get("type")
                        print(f"[SSE] 收到Agent chunk: type={chunk_type}")
                        if chunk_type == "analysis_progress":
                            yield f"data: {json.dumps({'type': 'analysis_progress', 'data': chunk['data'], 'success': True}, ensure_ascii=False)}\n\n"
                        elif chunk_type == "analysis_complete":
                            analysis_complete_data = chunk["data"]
                            # 确保数据可序列化（Pydantic对象转dict）
                            serializable_data = {}
                            for k, v in analysis_complete_data.items():
                                if hasattr(v, 'model_dump'):
                                    serializable_data[k] = v.model_dump()
                                elif hasattr(v, 'dict'):
                                    serializable_data[k] = v.dict()
                                else:
                                    serializable_data[k] = v
                            print(f"[SSE] Agent分析完成，数据: {list(serializable_data.keys())}")
                            yield f"data: {json.dumps({'type': 'analysis_complete', 'data': serializable_data, 'success': True}, ensure_ascii=False)}\n\n"
                        elif chunk_type == "error":
                            print(f"[SSE] Agent返回错误: {chunk['data']}")
                            yield f"data: {json.dumps({'type': 'error', 'data': chunk['data'], 'success': False}, ensure_ascii=False)}\n\n"
                            break

                print(f"[SSE] Agent分析结束, analysis_complete_data={'有数据' if analysis_complete_data else 'None'}")

                # 如果有营养分析结果，创建营养详情记录
                if analysis_complete_data:
                    try:
                        nf_data = analysis_complete_data["nutrition_facts"]
                        # 确保是dict格式
                        if hasattr(nf_data, 'model_dump'):
                            nf_data = nf_data.model_dump()
                        elif hasattr(nf_data, 'dict'):
                            nf_data = nf_data.dict()
                        nutrition_facts = NutritionFacts(**nf_data)
                        await create_nutrition_detail_from_analysis(
                            food_record.id,
                            nutrition_facts,
                            db
                        )

                        # 持久化AI分析结果
                        food_record.analysis_result = {
                            "short_comment": analysis_complete_data.get("short_comment") or "",
                            "image_description": analysis_complete_data.get("image_description") or "",
                            "food_items": nf_data.get("food_items", []),
                            "recommendations": analysis_complete_data.get("recommendations") or {},
                        }

                        # 更新分析状态为完成
                        food_record.analysis_status = 3  # 已完成
                        db.commit()

                        # 触发每日营养汇总更新
                        await update_daily_nutrition_summary(user_id, food_data.record_date, db)

                        yield f"data: {json.dumps({'type': 'nutrition_saved', 'data': {'status': 'completed', 'message': '营养分析完成并已保存'}, 'success': True}, ensure_ascii=False)}\n\n"
                    except Exception as save_err:
                        print(f"保存营养详情失败: {save_err}")
                        import traceback
                        traceback.print_exc()
                        # 即使保存失败，也标记为已完成（分析本身成功了）
                        food_record.analysis_status = 3
                        db.commit()
                        yield f"data: {json.dumps({'type': 'nutrition_saved', 'data': {'status': 'completed', 'message': '营养分析完成'}, 'success': True}, ensure_ascii=False)}\n\n"
                else:
                    # 如果分析失败，设置为待分析
                    food_record.analysis_status = 1  # 待分析
                    db.commit()
                    yield f"data: {json.dumps({'type': 'analysis_failed', 'data': {'status': 'failed', 'message': '分析失败，请稍后重试'}, 'success': False}, ensure_ascii=False)}\n\n"

            except Exception as e:
                # 分析出错，设置为待分析状态
                food_record.analysis_status = 1  # 待分析
                db.commit()
                print(f"Agent分析失败: {str(e)}")
                yield f"data: {json.dumps({'type': 'analysis_failed', 'data': {'status': 'failed', 'message': f'分析失败: {str(e)}'}, 'success': False}, ensure_ascii=False)}\n\n"

        # 清除相关缓存
        cache_key = f"nutrition:daily:{user_id}:{food_data.record_date}"
        cache_service.redis.delete(cache_key)

        # 5. 发送完成信号
        yield f"data: {json.dumps({'type': 'stream_complete', 'data': {'status': 'completed', 'message': '流程完成'}, 'success': True}, ensure_ascii=False)}\n\n"

    except Exception as e:
        db.rollback()
        yield f"data: {json.dumps({'type': 'error', 'data': {'error': str(e), 'message': f'创建食物记录失败: {str(e)}'}, 'success': False}, ensure_ascii=False)}\n\n"
        yield f"data: {json.dumps({'type': 'stream_complete', 'data': {'status': 'completed'}, 'success': True}, ensure_ascii=False)}\n\n"
    finally:
        db.close()


@router.post("/records")
async def create_food_record(
        food_data: FoodRecordCreate,
        request: Request
):
    """创建食物记录并使用Agent分析图片（流式输出）

    StreamingResponse 不能使用 Depends(get_db)，因为 FastAPI 会在返回
    StreamingResponse 后立即关闭 DI 注入的 session，而 SSE 生成器还在运行。
    改为手动解析 token，生成器内部自行管理 db session 生命周期。
    """
    # 手动解析 Authorization header，获取 user_id
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="未提供有效的认证令牌")
    token = auth_header[7:]  # 去掉 "Bearer " 前缀
    payload = AuthService.verify_token(token)
    user_id = int(payload.get("sub"))

    return StreamingResponse(
        generate_sse_stream(
            food_data=food_data,
            user_id=user_id
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )


#
@router.post("/records/traditional")
async def create_food_record_traditional(
        food_data: FoodRecordCreate,
        request: Request,
):
    """创建食物记录（传统接口，不使用流式输出）

    完全不使用 FastAPI DI (Depends)，改为手动解析 token + 管理 session，
    彻底避免 threadpool 跨线程 session 冲突。
    """
    import sys
    import traceback

    db = None
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="未提供有效的认证令牌")
        token = auth_header[7:]
        payload = AuthService.verify_token(token)
        user_id = int(payload.get("sub"))

        sys.stderr.write(f"[TRACE-v3] user_id={user_id}\n")
        sys.stderr.flush()

        db = SessionLocal()
        sys.stderr.write("[TRACE-v3] SessionLocal created\n")
        sys.stderr.flush()

        # 直接记录：待分析状态（营养详情通过 /nutrition 接口单独添加后会变为3）
        analysis_status = 1

        food_record = FoodRecord(
            user_id=user_id,
            record_date=food_data.record_date,
            record_time=food_data.record_time or datetime.now(),
            meal_type=food_data.meal_type,
            food_name=food_data.food_name,
            description=food_data.description,
            image_url=food_data.image_url,
            recording_method=food_data.recording_method or 1,
            analysis_status=analysis_status,
            cost=food_data.cost,
            source_tag=food_data.source_tag,
        )

        sys.stderr.write(f"[TRACE-v3] FoodRecord object created, calling db.add...\n")
        sys.stderr.flush()
        db.add(food_record)

        sys.stderr.write(f"[TRACE-v3] db.add done, calling db.commit...\n")
        sys.stderr.flush()
        db.commit()

        sys.stderr.write(f"[TRACE-v3] commit done, record id={food_record.id}\n")
        sys.stderr.flush()

        cache_key = f"nutrition:daily:{user_id}:{food_data.record_date}"
        cache_service.redis.delete(cache_key)

        response_data = {
            "id": food_record.id,
            "user_id": food_record.user_id,
            "record_date": food_record.record_date.isoformat(),
            "record_time": food_record.record_time.isoformat() if food_record.record_time else None,
            "meal_type": food_record.meal_type,
            "food_name": food_record.food_name,
            "description": food_record.description,
            "image_url": food_record.image_url,
            "recording_method": food_record.recording_method,
            "analysis_status": food_record.analysis_status,
            "cost": float(food_record.cost) if food_record.cost else None,
            "source_tag": food_record.source_tag,
            "created_at": food_record.created_at.isoformat(),
        }

        return BaseResponse(
            success=True,
            message="食物记录创建成功",
            data=response_data
        )

    except HTTPException:
        raise
    except Exception as e:
        sys.stderr.write(f"[TRACE-v3] EXCEPTION: {type(e).__name__}: {e}\n")
        traceback.print_exc(file=sys.stderr)
        sys.stderr.flush()
        if db is not None:
            try:
                db.rollback()
            except Exception as rb_err:
                sys.stderr.write(f"[TRACE-v3] rollback failed: {rb_err}\n")
                sys.stderr.flush()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建食物记录失败: {str(e)}"
        )
    finally:
        if db is not None:
            try:
                db.close()
            except Exception as close_err:
                sys.stderr.write(f"[TRACE-v3] close failed: {close_err}\n")
                sys.stderr.flush()


@router.put("/records/{record_id}", response_model=BaseResponse)
async def update_food_record(
        record_id: int,
        food_data: FoodRecordCreate,
        current_user: User = Depends(get_current_user),
):
    """更新食物记录"""
    user_id = current_user.id
    db = SessionLocal()
    try:
        food_record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == user_id
        ).first()

        if not food_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        food_record.record_date = food_data.record_date
        food_record.meal_type = food_data.meal_type
        food_record.food_name = food_data.food_name
        food_record.description = food_data.description
        food_record.image_url = food_data.image_url
        food_record.recording_method = food_data.recording_method or food_record.recording_method
        food_record.cost = food_data.cost
        food_record.source_tag = food_data.source_tag

        db.commit()
        db.refresh(food_record)

        cache_key = f"nutrition:daily:{user_id}:{food_data.record_date}"
        cache_service.redis.delete(cache_key)

        response_data = {
            "id": food_record.id,
            "user_id": food_record.user_id,
            "record_date": food_record.record_date.isoformat(),
            "record_time": food_record.record_time.isoformat() if food_record.record_time else None,
            "meal_type": food_record.meal_type,
            "food_name": food_record.food_name,
            "description": food_record.description,
            "image_url": food_record.image_url,
            "recording_method": food_record.recording_method,
            "analysis_status": food_record.analysis_status,
            "created_at": food_record.created_at.isoformat(),
            "updated_at": food_record.updated_at.isoformat() if hasattr(food_record, 'updated_at') else None,
        }

        return BaseResponse(
            success=True,
            message="食物记录更新成功",
            data=response_data
        )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新食物记录失败: {str(e)}"
        )
    finally:
        db.close()


@router.delete("/records/{record_id}", response_model=BaseResponse)
async def delete_food_record(
        record_id: int,
        current_user: User = Depends(get_current_user),
):
    """删除食物记录"""
    user_id = current_user.id
    db = SessionLocal()
    try:
        food_record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == user_id
        ).first()

        if not food_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == record_id
        ).delete()

        record_date = food_record.record_date
        db.delete(food_record)
        db.commit()

        # 重新计算当日营养汇总
        await update_daily_nutrition_summary(user_id, record_date, db)

        cache_key = f"nutrition:daily:{user_id}:{record_date.isoformat() if hasattr(record_date, 'isoformat') else str(record_date)}"
        cache_service.redis.delete(cache_key)

        return BaseResponse(
            success=True,
            message="食物记录删除成功"
        )

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除食物记录失败: {str(e)}"
        )
    finally:
        db.close()


async def _run_background_analysis(image_url: str, user_id: int, food_record_id: int):
    """后台运行图片分析"""
    try:
        from shared.models.database import get_db

        # 获取数据库会话
        db_gen = get_db()
        db = next(db_gen)

        try:
            # 获取食物记录
            food_record = db.query(FoodRecord).filter(FoodRecord.id == food_record_id).first()
            if not food_record:
                print(f"食物记录不存在: {food_record_id}")
                return

            # 运行分析
            analysis_complete_data = None
            async for chunk in analyze_food_image_with_agent(image_url, user_id, db):
                if chunk["type"] == "analysis_complete":
                    analysis_complete_data = chunk["data"]
                    break
                elif chunk["type"] == "error":
                    print(f"Agent分析失败: {chunk['data']}")
                    break

            # 如果有营养分析结果，创建营养详情记录
            if analysis_complete_data:
                nutrition_facts = NutritionFacts(**analysis_complete_data["nutrition_facts"])
                await create_nutrition_detail_from_analysis(
                    food_record.id,
                    nutrition_facts,
                    db
                )

                # 持久化AI分析结果（short_comment, food_items, image_description, recommendations）
                food_record.analysis_result = {
                    "short_comment": analysis_complete_data.get("short_comment", ""),
                    "image_description": analysis_complete_data.get("image_description", ""),
                    "food_items": analysis_complete_data.get("nutrition_facts", {}).get("food_items", []),
                    "recommendations": analysis_complete_data.get("recommendations"),
                }

                # 更新分析状态为完成
                food_record.analysis_status = 3  # 已完成
                db.commit()

                # 触发每日营养汇总更新
                await update_daily_nutrition_summary(user_id, food_record.record_date, db)
            else:
                # 分析失败
                food_record.analysis_status = 1  # 待分析
                db.commit()

        finally:
            db.close()

    except Exception as e:
        print(f"后台分析失败: {str(e)}")


@router.post("/records/confirm/{record_id}", response_model=BaseResponse)
async def confirm_food_record(
        record_id: int,
        current_user: User = Depends(get_current_user),
):
    """确认食物记录创建完成"""
    user_id = current_user.id
    db = SessionLocal()
    try:
        record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == user_id
        ).first()

        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        nutrition_detail = db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == record_id
        ).first()

        record_data = {
            "id": record.id,
            "user_id": record.user_id,
            "record_date": record.record_date.isoformat(),
            "record_time": record.record_time.isoformat() if record.record_time else None,
            "meal_type": record.meal_type,
            "food_name": record.food_name,
            "description": record.description,
            "image_url": minio_client.get_file_url(record.image_url) if record.image_url and not record.image_url.startswith("http") else record.image_url,
            "recording_method": record.recording_method,
            "analysis_status": record.analysis_status,
            "cost": float(record.cost) if record.cost else None,
            "source_tag": record.source_tag,
            "created_at": record.created_at.isoformat(),
            "updated_at": record.updated_at.isoformat(),
            "nutrition_detail": None
        }

        if nutrition_detail:
            record_data["nutrition_detail"] = {
                "id": nutrition_detail.id,
                "calories": float(nutrition_detail.calories),
                "protein": float(nutrition_detail.protein),
                "fat": float(nutrition_detail.fat),
                "carbohydrates": float(nutrition_detail.carbohydrates),
                "dietary_fiber": float(nutrition_detail.dietary_fiber),
                "sugar": float(nutrition_detail.sugar),
                "sodium": float(nutrition_detail.sodium),
                "cholesterol": float(nutrition_detail.cholesterol),
                "analysis_method": nutrition_detail.analysis_method
            }

        return BaseResponse(
            success=True,
            message="食物记录确认完成",
            data=record_data
        )

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"确认食物记录失败: {str(e)}"
        )
    finally:
        db.close()


async def analyze_food_image_with_agent(image_url: str, user_id: int, db: Session):
    """使用Langgraph Agent分析食物图片（流式输出）"""

    try:
        # 在进入异步流之前，先提取用户偏好数据，避免session并发问题
        user_prefs = await get_user_preferences(db, user_id)

        # 初始化Langgraph客户端
        client = get_client(url=settings.ai_service_url)
        # 从MinIO获取图片数据并转换为base64
        image_base64 = await get_image_base64_from_url(image_url)

        # 创建营养师Agent
        assistant = await client.assistants.create(
            graph_id="nutrition_agent",
            config={"configurable": get_agent_model_config()}
        )

        # 创建线程
        thread = await client.threads.create()
        async for chunk in client.runs.stream(
                assistant_id=assistant["assistant_id"],
                thread_id=thread['thread_id'],
                input={
                    "image_data": image_base64,
                    "user_preferences": user_prefs
                },
                stream_mode="values"
        ):
            if chunk.data is not None:
                if chunk.data.get("current_step") == "completed":
                    print("Agent分析完成")
                    # 提取 short_comment（nutrition_analysis 可能是 Pydantic 模型或 dict）
                    na = chunk.data.get("nutrition_analysis")
                    short_comment = ""
                    if na is not None:
                        if isinstance(na, dict):
                            short_comment = na.get("short_comment", "") or ""
                        elif hasattr(na, "short_comment"):
                            short_comment = na.short_comment or ""
                    yield {
                        "type": "analysis_complete",
                        "data": {
                            "image_description": chunk.data.get("image_analysis"),
                            "nutrition_facts": na,
                            "short_comment": short_comment,
                            "recommendations": chunk.data.get("nutrition_advice")
                        }
                    }
                else:
                    print(f"Agent正在分析: {chunk.data}")
                    print("===================")
                    print(chunk.data.get("current_step"))
                    yield {
                        "type": "analysis_progress",
                        "data": {
                            "current_step": chunk.data.get("current_step")
                        }
                    }
    except Exception as e:
        print(f"Agent分析失败: {str(e)}")
        yield {
            "type": "error",
            "data": {
                "error": str(e)
            }
        }
        raise e


async def analyze_food_text_with_agent(text_description: str, user_id: int, db: Session):
    """使用Langgraph Agent分析文字食物描述（流式输出）"""

    try:
        # 在进入异步流之前，先提取用户偏好数据，避免session并发问题
        user_prefs = await get_user_preferences(db, user_id)

        # 初始化Langgraph客户端
        client = get_client(url=settings.ai_service_url)

        # 创建营养师Agent
        assistant = await client.assistants.create(
            graph_id="nutrition_agent",
            config={"configurable": get_agent_model_config()}
        )

        # 创建线程
        thread = await client.threads.create()
        async for chunk in client.runs.stream(
                assistant_id=assistant["assistant_id"],
                thread_id=thread['thread_id'],
                input={
                    "text_description": text_description,
                    "user_preferences": user_prefs
                },
                stream_mode="values"
        ):
            if chunk.data is not None:
                if chunk.data.get("current_step") == "completed":
                    print("Agent文字分析完成")
                    na = chunk.data.get("nutrition_analysis")
                    short_comment = ""
                    if na is not None:
                        if isinstance(na, dict):
                            short_comment = na.get("short_comment", "") or ""
                        elif hasattr(na, "short_comment"):
                            short_comment = na.short_comment or ""
                    yield {
                        "type": "analysis_complete",
                        "data": {
                            "image_description": chunk.data.get("image_analysis"),
                            "nutrition_facts": na,
                            "short_comment": short_comment,
                            "recommendations": chunk.data.get("nutrition_advice")
                        }
                    }
                else:
                    print(f"Agent正在文字分析: {chunk.data}")
                    yield {
                        "type": "analysis_progress",
                        "data": {
                            "current_step": chunk.data.get("current_step")
                        }
                    }
    except Exception as e:
        print(f"Agent文字分析失败: {str(e)}")
        yield {
            "type": "error",
            "data": {
                "error": str(e)
            }
        }
        raise e


async def get_user_preferences(db: Session, user_id: int):
    """获取用户完整偏好数据，用于个性化营养建议"""
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {
                "dietary_restrictions": [],
                "health_goals": [],
                "language": "zh-CN",
                "body_metrics": {},
                "daily_targets": {},
                "today_intake": {},
            }

        # ========== 身体指标 ==========
        profile = user.profile
        body_metrics = {}
        if profile:
            body_metrics = {
                "gender": "男" if profile.gender == 1 else ("女" if profile.gender == 2 else "未设置"),
                "height_cm": float(profile.height) if profile.height else None,
                "weight_kg": float(profile.weight) if profile.weight else None,
                "bmi": float(profile.bmi) if profile.bmi else None,
                "activity_level": profile.activity_level,  # 1:久坐 2:轻度 3:中度 4:重度 5:超重度
                "crowd_tag": profile.crowd_tag or "",
                "constitution_type": profile.constitution_type or "",
            }
            # 计算年龄
            if profile.birth_date:
                today = date.today()
                age = today.year - profile.birth_date.year - ((today.month, today.day) < (profile.birth_date.month, profile.birth_date.day))
                body_metrics["age"] = age

        # ========== 每日目标 ==========
        daily_targets = {
            "calories": profile.target_calories if profile and profile.target_calories else 2000,
            "water_ml": profile.daily_water_goal if profile and profile.daily_water_goal else 2000,
        }

        # ========== 今日摄入 ==========
        today = date.today()
        today_summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date == today
        ).first()

        today_intake = {}
        if today_summary:
            today_intake = {
                "calories": float(today_summary.total_calories),
                "protein_g": float(today_summary.total_protein),
                "fat_g": float(today_summary.total_fat),
                "carbs_g": float(today_summary.total_carbohydrates),
                "fiber_g": float(today_summary.total_fiber),
                "meal_count": today_summary.meal_count,
            }
        else:
            today_intake = {
                "calories": 0, "protein_g": 0, "fat_g": 0,
                "carbs_g": 0, "fiber_g": 0, "meal_count": 0,
            }

        # ========== 饮食限制 ==========
        dietary_restrictions = []
        if user.allergies:
            dietary_restrictions.extend([
                {
                    "allergen_name": allergy.allergen_name,
                    "severity_level": allergy.severity_level,
                    "reaction_description": allergy.reaction_description,
                    "created_at": allergy.created_at.isoformat() if allergy.created_at else None,
                    "updated_at": allergy.updated_at.isoformat() if allergy.updated_at else None
                }
                for allergy in user.allergies
            ])
        if user.diseases:
            dietary_restrictions.extend([
                {
                    "disease_name": disease.disease_name,
                    "severity_level": disease.severity_level,
                    "diagnosed_date": disease.diagnosed_date.isoformat() if disease.diagnosed_date else None,
                    "is_current": disease.is_current,
                    "notes": disease.notes,
                    "created_at": disease.created_at.isoformat() if disease.created_at else None,
                    "updated_at": disease.updated_at.isoformat() if disease.updated_at else None
                }
                for disease in user.diseases
            ])

        # ========== 健康目标 ==========
        health_goals = []
        if user.health_goals:
            health_goals.extend([
                {
                    "goal_type": goal.goal_type,  # 1:减重 2:增重 3:维持 4:增肌 5:减脂
                    "target_weight": float(goal.target_weight) if goal.target_weight is not None else None,
                    "target_date": goal.target_date.isoformat() if goal.target_date else None,
                    "current_status": goal.current_status,  # 1:进行中 2:已完成 3:已暂停 4:已取消
                    "created_at": goal.created_at.isoformat() if goal.created_at else None,
                    "updated_at": goal.updated_at.isoformat() if goal.updated_at else None,
                }
                for goal in user.health_goals])
            health_goals.extend([{"goal_type_mean": "1:减重 2:增重 3:维持 4:增肌 5:减脂",
                                  "current_status_mean": "1:进行中 2:已完成 3:已暂停 4:已取消"}])

        return {
            "dietary_restrictions": dietary_restrictions,
            "health_goals": health_goals,
            "body_metrics": body_metrics,
            "daily_targets": daily_targets,
            "today_intake": today_intake,
            "language": "zh-CN",
        }

    except Exception as e:
        print(f"获取用户偏好失败: {e}")
        import traceback
        traceback.print_exc()
        return {
            "dietary_restrictions": [],
            "health_goals": [],
            "body_metrics": {},
            "daily_targets": {},
            "today_intake": {},
            "language": "zh-CN",
        }


async def get_image_base64_from_url(image_identifier: str) -> str:
    """从图片标识符获取base64编码的图片数据"""
    try:
        # 判断是URL还是对象名
        if image_identifier.startswith('http'):
            # 如果是完整的URL，需要正确提取对象名
            from urllib.parse import urlparse, unquote

            parsed_url = urlparse(image_identifier)
            # 获取路径部分并移除bucket名称
            path_parts = parsed_url.path.strip('/').split('/')
            if len(path_parts) >= 2:
                # 移除bucket名称，保留对象路径
                object_name = '/'.join(path_parts[1:])
            else:
                # 如果路径格式不正确，尝试从最后一部分提取
                object_name = path_parts[-1] if path_parts else parsed_url.path.split('/')[-1]

            # URL解码
            object_name = unquote(object_name)
        else:
            # 如果是对象名或路径，直接使用
            object_name = image_identifier

        print(f"尝试获取对象: {object_name}")

        # 获取图片数据
        image_data = minio_client.download_file(object_name)

        if image_data is None:
            raise Exception(f"无法从MinIO获取图片数据: {object_name}")

        # 转换为base64
        image_base64 = base64.b64encode(image_data).decode('utf-8')

        return image_base64

    except Exception as e:
        print(f"获取图片数据失败: {str(e)}")
        raise e


async def create_nutrition_detail_from_analysis(food_record_id: int, nutrition_facts: NutritionFacts, db: Session):
    """根据Agent分析结果创建营养详情记录"""
    try:
        # 检查是否已有营养详情
        existing_detail = db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == food_record_id
        ).first()

        if existing_detail:
            return  # 如果已存在，则不创建

        # 从分析结果中提取营养信息
        nutrition_detail = NutritionDetail(
            food_record_id=food_record_id,
            calories=nutrition_facts.total_calories or 0,
            protein=nutrition_facts.macronutrients.protein or 0,
            fat=nutrition_facts.macronutrients.fat or 0,
            carbohydrates=nutrition_facts.macronutrients.carbohydrates or 0,
            # dietary_fiber=0,
            # sugar=0,
            # sodium=0,
            # cholesterol=0,
            dietary_fiber=nutrition_facts.macronutrients.dietary_fiber or 0,
            sugar=nutrition_facts.macronutrients.sugar or 0,
            # 微量营养素
            sodium=nutrition_facts.vitamins_minerals.sodium or 0,
            cholesterol=nutrition_facts.vitamins_minerals.cholesterol or 0,

            # 维生素
            vitamin_a=nutrition_facts.vitamins_minerals.vitamin_a or 0,
            vitamin_c=nutrition_facts.vitamins_minerals.vitamin_c or 0,
            vitamin_d=nutrition_facts.vitamins_minerals.vitamin_d or 0,

            # 矿物质
            calcium=nutrition_facts.vitamins_minerals.calcium or 0,
            iron=nutrition_facts.vitamins_minerals.iron or 0,
            potassium=nutrition_facts.vitamins_minerals.potassium or 0,
            # vitamin_a=nutrition_facts.vitamins_minerals.vitamin_a or 0,
            # vitamin_c=nutrition_facts.vitamins_minerals.vitamin_c or 0,
            # vitamin_d=0,
            # calcium=nutrition_facts.vitamins_minerals.calcium or 0,
            # iron=0,
            # potassium=0,
            # confidence_score=0,#TODO:confidence_score还未实现
            analysis_method="agent_analysis"
        )

        try:
            db.add(nutrition_detail)
            db.commit()

            # 同步更新 FoodRecord 的热量值（首页展示用）
            food_record = db.query(FoodRecord).filter(FoodRecord.id == food_record_id).first()
            if food_record and food_record.total_calories == 0:
                food_record.total_calories = nutrition_facts.total_calories or 0
                db.commit()
        except Exception as e:
            db.rollback()
            print(f"添加数据库失败: {str(e)}")
            raise e

    except Exception as e:
        print(f"创建营养详情失败: {str(e)}")
        raise e


@router.get("/records", response_model=BaseResponse)
async def get_food_records(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
        start_date: Optional[date] = Query(None, description="开始日期"),
        end_date: Optional[date] = Query(None, description="结束日期"),
        meal_type: Optional[int] = Query(None, description="餐次类型"),
        page: int = Query(1, ge=1, description="页码"),
        page_size: int = Query(20, ge=1, le=100, description="每页大小")
):
    """获取食物记录列表"""
    try:
        query = db.query(FoodRecord).filter(FoodRecord.user_id == current_user.id)

        if start_date:
            query = query.filter(FoodRecord.record_date >= start_date)
        if end_date:
            query = query.filter(FoodRecord.record_date <= end_date)
        if meal_type:
            query = query.filter(FoodRecord.meal_type == meal_type)

        # 总数统计
        total = query.count()

        # 分页查询
        offset = (page - 1) * page_size
        records = query.order_by(FoodRecord.record_date.desc(), FoodRecord.created_at.desc()).offset(offset).limit(
            page_size).all()

        records_data = []
        for record in records:
            nutrition_detail = db.query(NutritionDetail).filter(
                NutritionDetail.food_record_id == record.id
            ).first()

            record_dict = {
                "id": record.id,
                "user_id": record.user_id,
                "record_date": record.record_date.isoformat(),
                "record_time": record.record_time.isoformat() if record.record_time else None,
                "meal_type": record.meal_type,
                "food_name": record.food_name,
                "description": record.description,
                "image_url": minio_client.get_file_url(record.image_url) if record.image_url and not record.image_url.startswith("http") else record.image_url,
                "recording_method": record.recording_method,
                "analysis_status": record.analysis_status,
                "analysis_result": _sanitize_analysis_result(record.analysis_result),
                "cost": float(record.cost) if record.cost else None,
                "source_tag": record.source_tag,
                "created_at": record.created_at.isoformat(),
                "updated_at": record.updated_at.isoformat()
            }

            if nutrition_detail:
                record_dict["nutrition_detail"] = {
                    "id": nutrition_detail.id,
                    "food_record_id": nutrition_detail.food_record_id,
                    "calories": float(nutrition_detail.calories),
                    "protein": float(nutrition_detail.protein),
                    "fat": float(nutrition_detail.fat),
                    "carbohydrates": float(nutrition_detail.carbohydrates),
                    "dietary_fiber": float(nutrition_detail.dietary_fiber),
                    "sugar": float(nutrition_detail.sugar),
                    "sodium": float(nutrition_detail.sodium),
                    "cholesterol": float(nutrition_detail.cholesterol),
                    "vitamin_a": float(nutrition_detail.vitamin_a),
                    "vitamin_c": float(nutrition_detail.vitamin_c),
                    "vitamin_d": float(nutrition_detail.vitamin_d),
                    "calcium": float(nutrition_detail.calcium),
                    "iron": float(nutrition_detail.iron),
                    "potassium": float(nutrition_detail.potassium),
                    "confidence_score": float(nutrition_detail.confidence_score) if nutrition_detail.confidence_score else None,
                    "analysis_method": nutrition_detail.analysis_method,
                    "created_at": nutrition_detail.created_at.isoformat(),
                    "updated_at": nutrition_detail.updated_at.isoformat()
                }
            else:
                record_dict["nutrition_detail"] = None

            records_data.append(record_dict)

        pagination_info = {
            "total": total,
            "page": page,
            "page_size": page_size,
            "total_pages": (total + page_size - 1) // page_size
        }

        # 如果查询的是单日记录，附带当日营养汇总
        summary = None
        if start_date and end_date and start_date == end_date:
            daily_summary = db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == current_user.id,
                DailyNutritionSummary.summary_date == start_date
            ).first()
            if daily_summary:
                summary = {
                    "id": daily_summary.id,
                    "user_id": daily_summary.user_id,
                    "summary_date": daily_summary.summary_date.isoformat(),
                    "total_calories": float(daily_summary.total_calories),
                    "total_protein": float(daily_summary.total_protein),
                    "total_fat": float(daily_summary.total_fat),
                    "total_carbohydrates": float(daily_summary.total_carbohydrates),
                    "total_fiber": float(daily_summary.total_fiber),
                    "total_sodium": float(daily_summary.total_sodium),
                    "meal_count": daily_summary.meal_count,
                    "water_intake": float(daily_summary.water_intake) if daily_summary.water_intake else 0.0,
                    "exercise_calories": float(daily_summary.exercise_calories) if daily_summary.exercise_calories else 0.0,
                    "health_score": float(daily_summary.health_level) if daily_summary.health_level else None,
                    "created_at": daily_summary.created_at.isoformat(),
                    "updated_at": daily_summary.updated_at.isoformat(),
                }

        return BaseResponse(
            success=True,
            message="获取食物记录列表成功",
            data={
                "records": records_data,
                "pagination": pagination_info,
                "summary": summary
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取食物记录列表失败: {str(e)}"
        )


@router.get("/records/{record_id}", response_model=BaseResponse)
async def get_food_record(
        record_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """获取食物记录详情"""
    try:
        record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == current_user.id
        ).first()

        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        # 获取营养详情
        nutrition_detail = db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == record_id
        ).first()

        record_data = {
            "id": record.id,
            "user_id": record.user_id,
            "record_date": record.record_date.isoformat(),
            "meal_type": record.meal_type,
            "food_name": record.food_name,
            "description": record.description,
            "image_url": minio_client.get_file_url(record.image_url) if record.image_url and not record.image_url.startswith("http") else record.image_url,
            "recording_method": record.recording_method,
            "analysis_status": record.analysis_status,
            "cost": float(record.cost) if record.cost else None,
            "source_tag": record.source_tag,
            "created_at": record.created_at.isoformat(),
            "updated_at": record.updated_at.isoformat(),
            "nutrition_detail": None
        }

        if nutrition_detail:
            record_data["nutrition_detail"] = {
                "id": nutrition_detail.id,
                "calories": float(nutrition_detail.calories),
                "protein": float(nutrition_detail.protein),
                "fat": float(nutrition_detail.fat),
                "carbohydrates": float(nutrition_detail.carbohydrates),
                "dietary_fiber": float(nutrition_detail.dietary_fiber),
                "sugar": float(nutrition_detail.sugar),
                "sodium": float(nutrition_detail.sodium),
                "cholesterol": float(nutrition_detail.cholesterol),
                "vitamin_a": float(nutrition_detail.vitamin_a),
                "vitamin_c": float(nutrition_detail.vitamin_c),
                "vitamin_d": float(nutrition_detail.vitamin_d),
                "calcium": float(nutrition_detail.calcium),
                "iron": float(nutrition_detail.iron),
                "potassium": float(nutrition_detail.potassium),
                "confidence_score": float(
                    nutrition_detail.confidence_score) if nutrition_detail.confidence_score else None,
                "analysis_method": nutrition_detail.analysis_method
            }

        return BaseResponse(
            success=True,
            message="获取食物记录详情成功",
            data=record_data
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取食物记录详情失败: {str(e)}"
        )


@router.post("/records/{record_id}/nutrition", response_model=BaseResponse)
async def add_nutrition_detail(
        record_id: int,
        nutrition_data: NutritionDetailCreate,
        current_user: User = Depends(get_current_user),
):
    """添加营养详情"""
    user_id = current_user.id
    db = SessionLocal()
    try:
        record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == user_id
        ).first()

        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        existing_detail = db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == record_id
        ).first()

        if existing_detail:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="该食物记录已有营养详情"
            )

        nutrition_detail = NutritionDetail(
            food_record_id=record_id,
            calories=nutrition_data.calories or 0,
            protein=nutrition_data.protein or 0,
            fat=nutrition_data.fat or 0,
            carbohydrates=nutrition_data.carbohydrates or 0,
            dietary_fiber=nutrition_data.dietary_fiber or 0,
            sugar=nutrition_data.sugar or 0,
            sodium=nutrition_data.sodium or 0,
            cholesterol=nutrition_data.cholesterol or 0,
            vitamin_a=nutrition_data.vitamin_a or 0,
            vitamin_c=nutrition_data.vitamin_c or 0,
            vitamin_d=nutrition_data.vitamin_d or 0,
            calcium=nutrition_data.calcium or 0,
            iron=nutrition_data.iron or 0,
            potassium=nutrition_data.potassium or 0,
            confidence_score=nutrition_data.confidence_score,
            analysis_method=nutrition_data.analysis_method
        )

        db.add(nutrition_detail)
        record.analysis_status = 3
        record.updated_at = datetime.utcnow()

        db.commit()
        db.refresh(nutrition_detail)

        await update_daily_nutrition_summary(user_id, record.record_date, db)

        cache_key = f"nutrition:daily:{user_id}:{record.record_date}"
        cache_service.redis.delete(cache_key)

        return BaseResponse(
            success=True,
            message="营养详情添加成功",
            data={
                "id": nutrition_detail.id,
                "food_record_id": nutrition_detail.food_record_id,
                "calories": float(nutrition_detail.calories),
                "protein": float(nutrition_detail.protein),
                "fat": float(nutrition_detail.fat),
                "carbohydrates": float(nutrition_detail.carbohydrates),
                "dietary_fiber": float(nutrition_detail.dietary_fiber),
                "sugar": float(nutrition_detail.sugar),
                "sodium": float(nutrition_detail.sodium),
                "cholesterol": float(nutrition_detail.cholesterol),
                "vitamin_a": float(nutrition_detail.vitamin_a),
                "vitamin_c": float(nutrition_detail.vitamin_c),
                "vitamin_d": float(nutrition_detail.vitamin_d),
                "calcium": float(nutrition_detail.calcium),
                "iron": float(nutrition_detail.iron),
                "potassium": float(nutrition_detail.potassium),
                "confidence_score": float(
                    nutrition_detail.confidence_score) if nutrition_detail.confidence_score else None,
                "analysis_method": nutrition_detail.analysis_method,
                "created_at": nutrition_detail.created_at.isoformat(),
                "updated_at": nutrition_detail.updated_at.isoformat()
            }
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"添加营养详情失败: {str(e)}"
        )
    finally:
        db.close()


@router.get("/daily-summary/{summary_date}", response_model=BaseResponse)
async def get_daily_nutrition_summary(
        summary_date: date,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """获取每日营养汇总"""
    try:
        # 先尝试从缓存获取
        cached_summary = cache_service.get_daily_nutrition(current_user.id, summary_date.isoformat())
        if cached_summary:
            return BaseResponse(
                success=True,
                message="获取每日营养汇总成功",
                data=cached_summary
            )

        # 从数据库获取
        summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == current_user.id,
            DailyNutritionSummary.summary_date == summary_date
        ).first()

        if not summary:
            # 如果没有汇总，生成一个
            summary = await create_daily_nutrition_summary(current_user.id, summary_date, db)

        summary_data = {
            "id": summary.id,
            "user_id": summary.user_id,
            "summary_date": summary.summary_date.isoformat(),
            "total_calories": float(summary.total_calories),
            "total_protein": float(summary.total_protein),
            "total_fat": float(summary.total_fat),
            "total_carbohydrates": float(summary.total_carbohydrates),
            "total_fiber": float(summary.total_fiber),
            "total_sodium": float(summary.total_sodium),
            "meal_count": summary.meal_count,
            "water_intake": float(summary.water_intake),
            "exercise_calories": float(summary.exercise_calories),
            "health_score": float(summary.health_level) if summary.health_level else None,
            "created_at": summary.created_at.isoformat(),
            "updated_at": summary.updated_at.isoformat()
        }

        # 缓存汇总数据
        cache_service.cache_daily_nutrition(current_user.id, summary_date.isoformat(), summary_data)

        return BaseResponse(
            success=True,
            message="获取每日营养汇总成功",
            data=summary_data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取每日营养汇总失败: {str(e)}"
        )


@router.get("/nutrition-trends", response_model=BaseResponse)
async def get_nutrition_trends(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
        start_date: Optional[date] = Query(None, description="开始日期"),
        end_date: Optional[date] = Query(None, description="结束日期"),
        metrics: Optional[str] = Query("calories,protein,fat,carbohydrates", description="指标列表，逗号分隔")
):
    """获取营养趋势"""
    try:
        # 设置默认日期范围（最近30天）
        if not end_date:
            end_date = date.today()
        if not start_date:
            start_date = end_date - timedelta(days=30)

        # 获取营养汇总数据
        summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == current_user.id,
            DailyNutritionSummary.summary_date >= start_date,
            DailyNutritionSummary.summary_date <= end_date
        ).order_by(DailyNutritionSummary.summary_date).all()

        # 解析指标列表
        metric_list = [metric.strip() for metric in metrics.split(',')]

        trends_data = {
            "date_range": {
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat()
            },
            "metrics": metric_list,
            "data": []
        }

        for summary in summaries:
            data_point = {
                "date": summary.summary_date.isoformat(),
                "values": {}
            }

            for metric in metric_list:
                if metric == "calories":
                    data_point["values"]["calories"] = float(summary.total_calories)
                elif metric == "protein":
                    data_point["values"]["protein"] = float(summary.total_protein)
                elif metric == "fat":
                    data_point["values"]["fat"] = float(summary.total_fat)
                elif metric == "carbohydrates":
                    data_point["values"]["carbohydrates"] = float(summary.total_carbohydrates)
                elif metric == "fiber":
                    data_point["values"]["fiber"] = float(summary.total_fiber)
                elif metric == "sodium":
                    data_point["values"]["sodium"] = float(summary.total_sodium)
                elif metric == "health_score":
                    data_point["values"]["health_score"] = float(summary.health_score) if summary.health_score else None

            trends_data["data"].append(data_point)

        return BaseResponse(
            success=True,
            message="获取营养趋势成功",
            data=trends_data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取营养趋势失败: {str(e)}"
        )


@router.post("/upload-image", response_model=BaseResponse)
async def upload_food_image(
        file: UploadFile = File(...),
        current_user: User = Depends(get_current_user)
):
    """上传食物图片"""
    try:
        print("上传图片开始")
        # 验证文件类型
        if file.content_type not in ["image/jpeg", "image/png", "image/gif"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不支持的文件类型，请上传JPEG、PNG或GIF格式的图片"
            )

        # 验证文件大小（10MB限制）
        file_content = await file.read()
        if len(file_content) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="文件大小不能超过10MB"
            )

        # 生成文件名
        timestamp = int(datetime.utcnow().timestamp())
        file_extension = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
        object_name = f"food_images/{current_user.id}/{timestamp}.{file_extension}"

        print("上传图片开始-minio")
        # 上传到MinIO
        success = minio_client.upload_file(object_name, file_content, file.content_type)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="文件上传失败"
            )
        print("上传图片结束-minio")
        # 获取文件URL
        file_url = minio_client.get_file_url(object_name)  # 使用默认有效期，7天
        print("获取文件URL结束")
        return BaseResponse(
            success=True,
            message="图片上传成功",
            data={
                "file_id": object_name,
                "file_name": file.filename,
                "file_url": file_url,
                "object_name": object_name,  # 用于存储到数据库
                "file_size": len(file_content),
                "content_type": file.content_type,
                "upload_time": datetime.utcnow().isoformat()
            }
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"图片上传失败: {str(e)}"
        )


@router.get("/images/data/{record_id}", response_model=BaseResponse)
async def get_food_image_data(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取食物记录的图片数据（base64）+ 营养分析数据"""
    try:
        food_record = db.query(FoodRecord).filter(
            FoodRecord.id == record_id,
            FoodRecord.user_id == current_user.id
        ).first()

        if not food_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        # 获取图片base64
        image_base64 = None
        if food_record.image_url:
            try:
                image_base64 = await get_image_base64_from_url(food_record.image_url)
            except Exception as e:
                print(f"获取图片数据失败: {e}")

        # 获取营养详情
        nutrition_detail = db.query(NutritionDetail).filter(
            NutritionDetail.food_record_id == record_id
        ).first()

        # 组装响应
        result = {
            "record_id": food_record.id,
            "food_name": food_record.food_name or "",
            "image_base64": image_base64,
            "meal_type": food_record.meal_type,
            "record_date": food_record.record_date.isoformat() if food_record.record_date else "",
            "analysis_status": food_record.analysis_status,
        }

        if nutrition_detail:
            result["nutrition_facts"] = {
                "calories": float(nutrition_detail.calories) if nutrition_detail.calories else 0,
                "protein": float(nutrition_detail.protein) if nutrition_detail.protein else 0,
                "fat": float(nutrition_detail.fat) if nutrition_detail.fat else 0,
                "carbohydrates": float(nutrition_detail.carbohydrates) if nutrition_detail.carbohydrates else 0,
                "dietary_fiber": float(nutrition_detail.dietary_fiber) if nutrition_detail.dietary_fiber else 0,
                "sugar": float(nutrition_detail.sugar) if nutrition_detail.sugar else 0,
                "sodium": float(nutrition_detail.sodium) if nutrition_detail.sodium else 0,
                "cholesterol": float(nutrition_detail.cholesterol) if nutrition_detail.cholesterol else 0,
            }

        return BaseResponse(success=True, data=result, message="获取成功")

    except HTTPException:
        raise
    except Exception as e:
        print(f"获取食物图片数据异常: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取图片数据失败: {str(e)}"
        )


@router.get("/images/url", response_model=BaseResponse)
async def get_image_url(
        object_name: str = Query(..., description="对象名称"),
        current_user: User = Depends(get_current_user),
        expires_minutes: int = Query(60, ge=1, le=10080, description="URL有效期(分钟)")
):
    """获取图片的访问URL"""
    try:
        # 验证对象名格式（确保是该用户的图片）
        if not object_name.startswith(f"food_images/{current_user.id}/"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权访问该图片"
            )

        # 检查文件是否存在
        if not minio_client.file_exists(object_name):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="图片不存在"
            )

        # 生成预签名URL
        from datetime import timedelta
        expires = timedelta(minutes=expires_minutes)
        file_url = minio_client.get_file_url(object_name, expires)

        if not file_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="生成图片URL失败"
            )

        return BaseResponse(
            success=True,
            message="获取图片URL成功",
            data={
                "object_name": object_name,
                "file_url": file_url,
                "expires_in": expires_minutes * 60,  # 转换为秒
                "expires_at": (datetime.utcnow() + expires).isoformat()
            }
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取图片URL失败: {str(e)}"
        )


# 辅助函数
async def create_daily_nutrition_summary(user_id: int, summary_date: date, db: Session) -> DailyNutritionSummary:
    """创建每日营养汇总"""
    # 统计当天的所有食物记录的营养信息
    nutrition_stats = db.query(
        func.sum(NutritionDetail.calories).label('total_calories'),
        func.sum(NutritionDetail.protein).label('total_protein'),
        func.sum(NutritionDetail.fat).label('total_fat'),
        func.sum(NutritionDetail.carbohydrates).label('total_carbohydrates'),
        func.sum(NutritionDetail.dietary_fiber).label('total_fiber'),
        func.sum(NutritionDetail.sodium).label('total_sodium'),
        func.count(FoodRecord.id).label('meal_count')
    ).select_from(FoodRecord).join(
        NutritionDetail, FoodRecord.id == NutritionDetail.food_record_id
    ).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date == summary_date
    ).first()

    summary = DailyNutritionSummary(
        user_id=user_id,
        summary_date=summary_date,
        total_calories=nutrition_stats.total_calories or 0,
        total_protein=nutrition_stats.total_protein or 0,
        total_fat=nutrition_stats.total_fat or 0,
        total_carbohydrates=nutrition_stats.total_carbohydrates or 0,
        total_fiber=nutrition_stats.total_fiber or 0,
        total_sodium=nutrition_stats.total_sodium or 0,
        meal_count=nutrition_stats.meal_count or 0,
        water_intake=_get_daily_water_intake(db, user_id, summary_date),
        exercise_calories=_get_daily_exercise_calories(db, user_id, summary_date),
        health_level=None
    )

    db.add(summary)
    db.commit()
    db.refresh(summary)

    return summary


async def update_daily_nutrition_summary(user_id: int, summary_date: date, db: Session):
    """更新每日营养汇总"""
    # 重新计算当天的营养统计
    nutrition_stats = db.query(
        func.sum(NutritionDetail.calories).label('total_calories'),
        func.sum(NutritionDetail.protein).label('total_protein'),
        func.sum(NutritionDetail.fat).label('total_fat'),
        func.sum(NutritionDetail.carbohydrates).label('total_carbohydrates'),
        func.sum(NutritionDetail.dietary_fiber).label('total_fiber'),
        func.sum(NutritionDetail.sodium).label('total_sodium'),
        func.count(FoodRecord.id).label('meal_count')
    ).select_from(FoodRecord).join(
        NutritionDetail, FoodRecord.id == NutritionDetail.food_record_id
    ).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date == summary_date
    ).first()

    # 获取或创建汇总记录
    summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date == summary_date
    ).first()

    if not summary:
        summary = DailyNutritionSummary(
            user_id=user_id,
            summary_date=summary_date
        )
        db.add(summary)

    # 更新统计数据
    summary.total_calories = nutrition_stats.total_calories or 0
    summary.total_protein = nutrition_stats.total_protein or 0
    summary.total_fat = nutrition_stats.total_fat or 0
    summary.total_carbohydrates = nutrition_stats.total_carbohydrates or 0
    summary.total_fiber = nutrition_stats.total_fiber or 0
    summary.total_sodium = nutrition_stats.total_sodium or 0
    summary.meal_count = nutrition_stats.meal_count or 0
    summary.water_intake = _get_daily_water_intake(db, user_id, summary_date)
    summary.exercise_calories = _get_daily_exercise_calories(db, user_id, summary_date)
    summary.updated_at = datetime.utcnow()

    db.commit()

    # 清除相关缓存
    cache_key = f"nutrition:daily:{user_id}:{summary_date}"
    cache_service.redis.delete(cache_key)


def _get_daily_water_intake(db: Session, user_id: int, summary_date: date) -> float:
    """查询指定日期的饮水总量(L)，从 water_intake_records 表汇总"""
    from shared.models.water_models import WaterIntakeRecord
    total_ml = db.query(func.coalesce(func.sum(WaterIntakeRecord.amount_ml), 0)).filter(
        WaterIntakeRecord.user_id == user_id,
        func.date(WaterIntakeRecord.record_time) == summary_date
    ).scalar()
    return round(float(total_ml) / 1000.0, 2)


@router.post("/records/analyze-enhanced", response_model=BaseResponse)
async def analyze_food_enhanced(
        food_data: FoodRecordCreate,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """
    M2: Enhanced nutrition analysis with AI advisor style personalization.

    Analyzes food image/description using the enhanced_nutrition_agent
    with personalized advisor settings context.
    """
    try:
        from shared.services.agent_orchestrator import get_orchestrator
        from shared.services.advisor_service import get_advisor_settings

        # Pre-load advisor settings for personalized analysis
        advisor_settings = get_advisor_settings(db, current_user.id)
        advisor_context = None
        if advisor_settings:
            advisor_context = {
                "advisor_style": advisor_settings.get("advisor_style"),
                "focus_goal": advisor_settings.get("focus_goal"),
                "focus_nutrient": advisor_settings.get("focus_nutrient"),
                "response_style": advisor_settings.get("response_style"),
            }

        # Use orchestrator for enhanced analysis
        orchestrator = get_orchestrator(db)
        result = await orchestrator.analyze_food_with_goals(
            user_id=current_user.id,
            image_data=food_data.image_url or "",
            food_description=food_data.description,
            meal_type=food_data.meal_type,
            advisor_context=advisor_context,
        )

        return BaseResponse(
            success=True,
            message="增强营养分析完成",
            data={
                "analysis": result.get("analysis"),
                "nutrition_detail": result.get("nutrition_detail"),
                "advisor_style": advisor_context.get("advisor_style") if advisor_context else None,
                "recommendations": result.get("recommendations", []),
            }
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"增强分析失败: {str(e)}"
        )




@router.get("/nutrition-db", response_model=BaseResponse)
async def search_nutrition_db(
    name: str = Query(..., description="食物名称"),
):
    """查询食物营养成分数据库

    支持精确匹配和模糊匹配，返回每100g的营养数据
    """
    result = _NUTRITION_DB.get(name)
    match_type = "exact" if result else None

    if not result:
        # 模糊匹配：食物名包含关键词（最长匹配优先）
        fuzzy_key = None
        fuzzy_len = 0
        for k in _NUTRITION_DB:
            if name in k and len(k) > fuzzy_len:
                fuzzy_key = k
                fuzzy_len = len(k)
        if fuzzy_key is None:
            # 反向：关键词包含食物名
            for k, v in _NUTRITION_DB.items():
                if k in name:
                    result = v
                    match_type = "fuzzy"
                    break
        else:
            result = _NUTRITION_DB[fuzzy_key]
            match_type = "fuzzy"

    if not result:
        return BaseResponse(
            success=True,
            message="未找到匹配的食物数据",
            data={"food_name": name, "found": False},
        )

    return BaseResponse(
        success=True,
        message="查询成功",
        data={
            "food_name": name,
            "matched_name": fuzzy_key if fuzzy_key else name,
            "found": True,
            "match_type": match_type,
            "nutrition_per_100g": {
                "calories": result["calories"],
                "protein": result["protein"],
                "fat": result["fat"],
                "carbs": result["carbs"],
            },
        },
    )


@router.get("/categories", response_model=BaseResponse)
async def get_food_categories():
    """获取食物分类列表"""
    categories = ['主食', '蔬菜', '肉类', '汤类', '小食', '饮品', '甜品', '其他']
    return BaseResponse(success=True, message="获取分类成功", data={"items": categories})


@router.get("/source-tags", response_model=BaseResponse)
async def get_source_tags():
    """获取食物来源标签"""
    tags = [
        {"value": "canteen", "label": "食堂"},
        {"value": "delivery", "label": "外卖"},
        {"value": "home", "label": "家里"},
        {"value": "restaurant", "label": "餐厅"},
        {"value": "snack", "label": "零食"},
        {"value": "other", "label": "其他"},
    ]
    return BaseResponse(success=True, message="获取来源标签成功", data={"items": tags})


def _get_daily_exercise_calories(db: Session, user_id: int, summary_date: date) -> float:
    """查询指定日期的运动消耗总热量(kcal)，从 exercise_records 表汇总"""
    from shared.models.exercise_models import ExerciseRecord
    total = db.query(func.coalesce(func.sum(ExerciseRecord.calories_burned), 0)).filter(
        ExerciseRecord.user_id == user_id,
        ExerciseRecord.record_date == summary_date
    ).scalar()
    return round(float(total), 2)
