"""
养生知识 RAG 检索工具 - 按节气/体质精准检索 ChromaDB

使用 rag_utils.rag_search_by_user_profile 实现 metadata filtering，
支持按人群标签、体质类型、季节、数据类型精准检索。
"""

import logging
from datetime import datetime
from typing import Any, Optional

from langchain_core.tools import tool

logger = logging.getLogger(__name__)


@tool
def query_wellness_knowledge(
    query: str,
    crowd: Optional[str] = None,
    constitution: Optional[str] = None,
    season: Optional[str] = None,
    data_type: Optional[str] = None,
    top_k: int = 5,
) -> dict[str, Any]:
    """从养生知识库中检索节气养生、体质调理、特殊人群饮食建议。

    支持按人群标签、体质类型、季节等维度精准过滤，返回最相关的养生知识。

    Args:
        query: 查询文本（如"夏季养生茶饮"、"痰湿体质饮食建议"）
        crowd: 人群标签过滤（如"减脂"、"健身"、"孕妇"，逗号分隔）
        constitution: 体质类型过滤（如"气虚"、"痰湿"、"阴虚"）
        season: 季节过滤（如"春"、"夏"、"秋"、"冬"）
        data_type: 数据类型过滤（"solar_term"=节气养生, "special_diet"=特殊人群饮食）
        top_k: 返回结果数量（默认 5）

    Returns:
        检索到的养生知识片段列表
    """
    try:
        from agent.common_utils.rag_utils import rag_search_by_user_profile

        docs = rag_search_by_user_profile(
            query=query,
            k=top_k,
            crowd=crowd,
            constitution=constitution,
            season=season,
            data_type=data_type,
        )

        if not docs:
            return {
                "found": False,
                "message": f"未找到与「{query}」相关的养生知识",
                "documents": [],
            }

        documents = []
        for doc in docs:
            documents.append({
                "content": doc.page_content[:500],
                "metadata": doc.metadata,
            })

        return {
            "found": True,
            "query": query,
            "filters": {
                "crowd": crowd,
                "constitution": constitution,
                "season": season,
                "data_type": data_type,
            },
            "document_count": len(documents),
            "documents": documents,
        }

    except Exception as e:
        logger.error(f"query_wellness_knowledge failed: {e}")
        return {"found": False, "error": str(e), "documents": []}


@tool
def get_current_season_wellness(
    crowd: Optional[str] = None,
    constitution: Optional[str] = None,
) -> dict[str, Any]:
    """获取当前季节的养生建议，自动判断当前节气和季节。

    Args:
        crowd: 人群标签（如"减脂"、"健身"）
        constitution: 体质类型（如"气虚"、"痰湿"）

    Returns:
        当前季节的养生建议，包含节气饮食、起居建议、宜忌食物
    """
    try:
        from agent.common_utils.rag_utils import rag_search_by_user_profile

        # Determine current season
        month = datetime.now().month
        season_map = {
            1: "冬", 2: "冬", 3: "春",
            4: "春", 5: "春", 6: "夏",
            7: "夏", 8: "夏", 9: "秋",
            10: "秋", 11: "秋", 12: "冬",
        }
        current_season = season_map.get(month, "")

        if not current_season:
            return {"found": False, "message": "无法判断当前季节"}

        # Search solar term wellness
        solar_docs = rag_search_by_user_profile(
            query="节气饮食养生建议宜忌",
            k=3,
            season=current_season,
            constitution=constitution,
            data_type="solar_term",
        )

        # Search special diet if crowd specified
        diet_docs = []
        if crowd:
            diet_docs = rag_search_by_user_profile(
                query="饮食建议营养方案",
                k=2,
                crowd=crowd,
                constitution=constitution,
                data_type="special_diet",
            )

        all_docs = list(solar_docs) + list(diet_docs)

        if not all_docs:
            return {
                "found": False,
                "season": current_season,
                "message": f"未找到{current_season}季养生建议",
            }

        documents = []
        for doc in all_docs:
            documents.append({
                "content": doc.page_content[:500],
                "metadata": doc.metadata,
            })

        return {
            "found": True,
            "season": current_season,
            "month": month,
            "filters": {"crowd": crowd, "constitution": constitution},
            "document_count": len(documents),
            "documents": documents,
        }

    except Exception as e:
        logger.error(f"get_current_season_wellness failed: {e}")
        return {"found": False, "error": str(e)}
