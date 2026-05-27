"""
营养知识 RAG 检索工具 - 封装 ChromaDB 向量检索

通过 agent/common_utils/rag_utils.py 查询营养知识库。
"""

import logging
from typing import Any

from langchain_core.tools import tool

logger = logging.getLogger(__name__)


@tool
def query_nutrition_knowledge(query: str, top_k: int = 5) -> dict[str, Any]:
    """从营养知识库中检索与查询相关的专业知识。

    使用 ChromaDB 向量数据库进行语义检索，返回最相关的营养学文档片段。
    适用于需要专业营养知识支撑的回答场景。

    Args:
        query: 查询文本（如"糖尿病患者适合吃什么水果"）
        top_k: 返回结果数量（默认 5）

    Returns:
        检索到的知识片段列表
    """
    try:
        from agent.common_utils.rag_utils import rag_loader

        vector_store = rag_loader()
        results = vector_store.similarity_search_with_score(query, k=top_k)

        if not results:
            return {
                "found": False,
                "message": f"未找到与「{query}」相关的营养知识",
                "documents": [],
            }

        documents = []
        for doc, score in results:
            documents.append({
                "content": doc.page_content,
                "source": doc.metadata.get("source", "unknown"),
                "relevance_score": round(float(score), 3),
            })

        return {
            "found": True,
            "query": query,
            "document_count": len(documents),
            "documents": documents,
        }

    except Exception as e:
        logger.error(f"query_nutrition_knowledge failed: {e}")
        return {"found": False, "error": str(e), "documents": []}
