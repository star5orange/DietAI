import os
import hashlib
import time
from functools import lru_cache
from typing import Optional

from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings
from shared.config.settings import settings


# ==================== RAG 结果缓存 ====================

class RAGCache:
    """按人群标签分区的 RAG 检索结果缓存

    缓存 key = hash(query + filter_dict)，按 crowd 标签分区存储。
    默认 TTL 30 分钟，知识库更新时调用 clear_all() 失效。
    """

    def __init__(self, ttl_seconds: int = 1800):
        self._cache: dict[str, list[tuple[float, list[Document]]]] = {}
        self._ttl = ttl_seconds

    def _make_key(self, query: str, filter_dict: Optional[dict]) -> str:
        raw = query + str(filter_dict or {})
        return hashlib.md5(raw.encode()).hexdigest()

    def get(self, query: str, filter_dict: Optional[dict]) -> Optional[list[Document]]:
        key = self._make_key(query, filter_dict)
        entry = self._cache.get(key)
        if entry is None:
            return None
        cached_time, docs = entry
        if time.time() - cached_time > self._ttl:
            del self._cache[key]
            return None
        return docs

    def set(self, query: str, filter_dict: Optional[dict], docs: list[Document]):
        key = self._make_key(query, filter_dict)
        self._cache[key] = (time.time(), docs)

    def clear_all(self):
        self._cache.clear()

    @property
    def size(self) -> int:
        return len(self._cache)


# 全局缓存实例
_rag_cache = RAGCache()


def get_rag_cache() -> RAGCache:
    """获取全局 RAG 缓存实例"""
    return _rag_cache


# ==================== Embeddings & VectorStore ====================

def _get_embeddings():
    """获取 Embeddings 实例，优先使用 DashScope 兼容接口"""
    dashscope_api_key = os.getenv("DASHSCOPE_API_KEY", "")
    openai_api_key = os.getenv("OPENAI_API_KEY", "")

    if dashscope_api_key and not openai_api_key:
        return OpenAIEmbeddings(
            model="text-embedding-v3",
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
            api_key=dashscope_api_key,
            check_embedding_ctx_length=False,
            chunk_size=10,  # DashScope batch size 限制为 10
        )
    elif openai_api_key:
        return OpenAIEmbeddings()
    else:
        raise ValueError("未配置 OPENAI_API_KEY 或 DASHSCOPE_API_KEY，请在 .env 文件中配置")


@lru_cache(maxsize=1)
def rag_loader():
    persist_directory = settings.VECTOR_STORE_PATH
    embeddings = _get_embeddings()
    vector_store = Chroma(
        collection_name=settings.VECTOR_COLLECTION_NAME,
        embedding_function=embeddings,
        persist_directory=persist_directory
    )
    return vector_store


def rebuild_vector_store():
    """重建向量存储实例（知识库更新后调用）

    清除 lru_cache 缓存的旧实例，下次 rag_loader() 调用会重新加载。
    同时清除 RAG 结果缓存。
    """
    rag_loader.cache_clear()
    _rag_cache.clear_all()


# ==================== 检索方法 ====================

def rag_search(
    query: str,
    k: int = 5,
    filter: Optional[dict] = None,
    use_cache: bool = True,
) -> list[Document]:
    """带 metadata filtering 和缓存的 RAG 检索

    Args:
        query: 查询文本
        k: 返回结果数量
        filter: ChromaDB metadata 过滤条件，例如:
            - {"data_type": "food_nutrition"}  精确匹配
            - {"crowd_减脂": True}  人群标签过滤
            - {"season_夏": True}  季节过滤
            - {"data_type": "solar_term", "term": "夏至"}  多条件组合
        use_cache: 是否使用缓存（默认开启）

    Returns:
        检索到的 Document 列表
    """
    # 尝试从缓存获取
    if use_cache:
        cached = _rag_cache.get(query, filter)
        if cached is not None:
            return cached[:k]

    # 执行检索
    vector_store = rag_loader()
    if filter:
        results = vector_store.similarity_search(query, k=k, filter=filter)
    else:
        results = vector_store.similarity_search(query, k=k)

    # 写入缓存（缓存 k=5 的结果，调用方按需截取）
    if use_cache and results:
        _rag_cache.set(query, filter, results)

    return results


def rag_search_by_user_profile(
    query: str,
    k: int = 5,
    crowd: Optional[str] = None,
    season: Optional[str] = None,
    constitution: Optional[str] = None,
    data_type: Optional[str] = None,
) -> list[Document]:
    """根据用户画像进行 RAG 检索，自动构建 metadata 过滤条件

    Args:
        query: 查询文本
        k: 返回结果数量
        crowd: 人群标签 (减脂/健身/孕妇/老年/普通)
        season: 季节 (春/夏/秋/冬)
        constitution: 体质 (平和/气虚/阳虚/阴虚/痰湿/湿热/血瘀/气郁/特禀)
        data_type: 数据类型 (food_nutrition/solar_term/special_diet)

    Returns:
        检索到的 Document 列表

    Note:
        ChromaDB 的 $contains 对中文不支持，因此多值标签在入库时
        被拆分为布尔字段（如 crowd_减脂=True），使用 $eq 匹配
    """
    conditions = []
    if data_type:
        conditions.append({"data_type": data_type})
    if crowd:
        conditions.append({f"crowd_{crowd}": True})
    if season:
        conditions.append({f"season_{season}": True})
    if constitution:
        conditions.append({f"constitution_{constitution}": True})

    if len(conditions) == 0:
        filter_dict = None
    elif len(conditions) == 1:
        filter_dict = conditions[0]
    else:
        filter_dict = {"$and": conditions}

    return rag_search(query, k=k, filter=filter_dict)
