"""
对话历史向量检索工具
支持语义搜索历史对话,帮助AI理解用户的长期对话模式
"""

import os
import hashlib
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings
from shared.config.settings import settings


class ChatHistorySearcher:
    """对话历史向量检索器
    
    功能:
    1. 将历史对话向量化存储(按用户分区)
    2. 支持语义搜索相似对话
    3. 缓存热门查询结果
    """
    
    def __init__(self, user_id: int):
        self.user_id = user_id
        self.persist_directory = os.path.join(
            settings.VECTOR_STORE_PATH,
            "chat_history",
            f"user_{user_id}"
        )
        self.collection_name = f"chat_history_{user_id}"
        
        # 延迟初始化向量存储(节省资源)
        self._vector_store: Optional[Chroma] = None
        self._embeddings: Optional[OpenAIEmbeddings] = None
    
    def _get_embeddings(self) -> OpenAIEmbeddings:
        """获取Embeddings实例"""
        if self._embeddings is None:
            dashscope_api_key = os.getenv("DASHSCOPE_API_KEY", "")
            openai_api_key = os.getenv("OPENAI_API_KEY", "")
            
            if dashscope_api_key and not openai_api_key:
                self._embeddings = OpenAIEmbeddings(
                    model="text-embedding-v3",
                    base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
                    api_key=dashscope_api_key,
                    check_embedding_ctx_length=False,
                    chunk_size=10,
                )
            elif openai_api_key:
                self._embeddings = OpenAIEmbeddings()
            else:
                raise ValueError("未配置OPENAI_API_KEY或DASHSCOPE_API_KEY")
        
        return self._embeddings
    
    def _get_vector_store(self) -> Chroma:
        """获取向量存储实例"""
        if self._vector_store is None:
            os.makedirs(self.persist_directory, exist_ok=True)
            self._vector_store = Chroma(
                collection_name=self.collection_name,
                embedding_function=self._get_embeddings(),
                persist_directory=self.persist_directory
            )
        
        return self._vector_store
    
    def index_conversation(
        self,
        session_id: int,
        messages: List[Dict[str, Any]],
        session_title: Optional[str] = None
    ) -> int:
        """索引对话历史
        
        Args:
            session_id: 会话ID
            messages: 消息列表,每条消息包含role, content, timestamp
            session_title: 会话标题
            
        Returns:
            索引的文档数量
        """
        vector_store = self._get_vector_store()
        
        # 构建对话文档(合并多轮对话为一个文档)
        conversation_text = []
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            timestamp = msg.get("timestamp", "")
            
            # 格式化对话内容
            if role == "user":
                conversation_text.append(f"[用户]{content}")
            else:
                conversation_text.append(f"[AI]{content}")
        
        # 合并为完整对话文本
        full_conversation = "\n".join(conversation_text)
        
        # 创建文档对象
        doc = Document(
            page_content=full_conversation,
            metadata={
                "session_id": session_id,
                "user_id": self.user_id,
                "title": session_title or f"对话{session_id}",
                "message_count": len(messages),
                "indexed_at": datetime.now().isoformat(),
                "date": messages[0].get("timestamp", datetime.now().isoformat())[:10]  # YYYY-MM-DD
            }
        )
        
        # 添加到向量存储(使用session_id作为唯一ID,避免重复)
        try:
            vector_store.add_documents([doc], ids=[f"session_{session_id}"])
            return 1
        except Exception as e:
            print(f"索引对话失败: {e}")
            return 0
    
    def search_similar_conversations(
        self,
        query: str,
        k: int = 5,
        date_range: Optional[tuple[str, str]] = None,
        min_similarity: float = 0.7
    ) -> List[Dict[str, Any]]:
        """搜索相似对话
        
        Args:
            query: 查询文本
            k: 返回结果数量
            date_range: 日期范围(start_date, end_date)
            min_similarity: 最小相似度阈值
            
        Returns:
            相似对话列表,每个包含session_id, similarity, content, metadata
        """
        vector_store = self._get_vector_store()
        
        # 构建过滤器
        filter_dict = {"user_id": self.user_id}
        if date_range:
            start_date, end_date = date_range
            filter_dict["date"] = {"$gte": start_date, "$lte": end_date}
        
        try:
            # 执行相似度搜索
            results = vector_store.similarity_search_with_relevance_scores(
                query=query,
                k=k,
                filter=filter_dict
            )
            
            # 过滤低相似度结果
            filtered_results = []
            for doc, score in results:
                if score >= min_similarity:
                    filtered_results.append({
                        "session_id": doc.metadata.get("session_id"),
                        "title": doc.metadata.get("title"),
                        "content": doc.page_content,
                        "similarity": score,
                        "message_count": doc.metadata.get("message_count"),
                        "date": doc.metadata.get("date")
                    })
            
            return filtered_results
            
        except Exception as e:
            print(f"搜索对话失败: {e}")
            return []
    
    def search_by_keyword(
        self,
        keyword: str,
        k: int = 10,
        session_type: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """关键词搜索对话
        
        Args:
            keyword: 关键词
            k: 返回结果数量
            session_type: 会话类型过滤
            
        Returns:
            包含关键词的对话列表
        """
        # Chroma不支持关键词搜索,使用相似度搜索作为替代
        return self.search_similar_conversations(query=keyword, k=k)
    
    def delete_session(self, session_id: int) -> bool:
        """删除会话索引
        
        Args:
            session_id: 会话ID
            
        Returns:
            是否成功删除
        """
        vector_store = self._get_vector_store()
        
        try:
            vector_store.delete(ids=[f"session_{session_id}"])
            return True
        except Exception as e:
            print(f"删除对话索引失败: {e}")
            return False
    
    def get_recent_sessions(
        self,
        limit: int = 10,
        days: int = 30
    ) -> List[Dict[str, Any]]:
        """获取最近对话
        
        Args:
            limit: 返回数量
            days: 最近天数
            
        Returns:
            最近对话列表
        """
        vector_store = self._get_vector_store()
        
        # 构建日期过滤器
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        end_date = datetime.now().strftime("%Y-%m-%d")
        
        filter_dict = {
            "user_id": self.user_id,
            "date": {"$gte": start_date, "$lte": end_date}
        }
        
        try:
            # 获取所有符合条件的文档(按日期排序)
            results = vector_store.get(
                where=filter_dict,
                limit=limit
            )
            
            # 解析结果
            sessions = []
            if results and "ids" in results:
                for i, doc_id in enumerate(results["ids"]):
                    metadata = results["metadatas"][i] if "metadatas" in results else {}
                    content = results["documents"][i] if "documents" in results else ""
                    
                    sessions.append({
                        "session_id": metadata.get("session_id"),
                        "title": metadata.get("title"),
                        "content": content,
                        "message_count": metadata.get("message_count"),
                        "date": metadata.get("date")
                    })
            
            return sessions
            
        except Exception as e:
            print(f"获取最近对话失败: {e}")
            return []
    
    def clear_all(self) -> bool:
        """清空所有对话索引
        
        Returns:
            是否成功清空
        """
        vector_store = self._get_vector_store()
        
        try:
            # 获取所有文档ID
            all_docs = vector_store.get()
            if all_docs and "ids" in all_docs:
                vector_store.delete(ids=all_docs["ids"])
            return True
        except Exception as e:
            print(f"清空对话索引失败: {e}")
            return False


def get_chat_history_searcher(user_id: int) -> ChatHistorySearcher:
    """获取对话历史检索器实例
    
    Args:
        user_id: 用户ID
        
    Returns:
        ChatHistorySearcher实例
    """
    return ChatHistorySearcher(user_id)