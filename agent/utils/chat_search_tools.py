"""
对话历史检索Agent工具
为LangGraph Agent提供对话历史检索能力
"""

from typing import List, Dict, Any, Optional
from langchain_core.tools import tool

from agent.utils.chat_history_search import get_chat_history_searcher


@tool
def search_chat_history(
    user_id: int,
    query: str,
    k: int = 5,
    date_range: Optional[tuple[str, str]] = None
) -> List[Dict[str, Any]]:
    """搜索相似对话历史
    
    用于AI理解用户的长期对话模式和偏好
    
    Args:
        user_id: 用户ID
        query: 查询文本(可以是用户当前问题或主题)
        k: 返回结果数量(默认5)
        date_range: 日期范围(start_date, end_date)格式为YYYY-MM-DD
        
    Returns:
        相似对话列表,每个包含:
        - session_id: 会话ID
        - title: 会话标题
        - content: 对话内容摘要
        - similarity: 相似度分数(0-1)
        - date: 对话日期
        
    Example:
        >>> search_chat_history(
        ...     user_id=123,
        ...     query="如何减肥",
        ...     k=3,
        ...     date_range=("2025-01-01", "2025-12-31")
        ... )
    """
    searcher = get_chat_history_searcher(user_id)
    
    results = searcher.search_similar_conversations(
        query=query,
        k=k,
        date_range=date_range,
        min_similarity=0.7
    )
    
    # 格式化返回结果(简化内容)
    formatted_results = []
    for result in results:
        # 截取对话内容的前300字作为摘要
        content_summary = result.get("content", "")
        if len(content_summary) > 300:
            content_summary = content_summary[:300] + "..."
        
        formatted_results.append({
            "session_id": result.get("session_id"),
            "title": result.get("title"),
            "summary": content_summary,
            "similarity": round(result.get("similarity", 0), 2),
            "message_count": result.get("message_count"),
            "date": result.get("date")
        })
    
    return formatted_results


@tool
def get_user_chat_patterns(
    user_id: int,
    recent_days: int = 30
) -> Dict[str, Any]:
    """分析用户对话模式和偏好
    
    用于AI了解用户的常见话题、对话风格和关注重点
    
    Args:
        user_id: 用户ID
        recent_days: 分析最近多少天的对话(默认30)
        
    Returns:
        用户对话模式分析结果,包含:
        - total_sessions: 会话总数
        - frequent_topics: 常见话题列表
        - avg_message_count: 平均每会话消息数
        - recent_sessions: 最近会话列表
        
    Example:
        >>> get_user_chat_patterns(user_id=123, recent_days=30)
    """
    searcher = get_chat_history_searcher(user_id)
    
    # 获取最近对话
    recent_sessions = searcher.get_recent_sessions(limit=20, days=recent_days)
    
    if not recent_sessions:
        return {
            "total_sessions": 0,
            "frequent_topics": [],
            "avg_message_count": 0,
            "recent_sessions": []
        }
    
    # 分析对话模式
    total_sessions = len(recent_sessions)
    avg_message_count = sum(
        s.get("message_count", 0) for s in recent_sessions
    ) / total_sessions if total_sessions > 0 else 0
    
    # 提取常见话题(简化版:基于标题关键词)
    topic_keywords = []
    for session in recent_sessions:
        title = session.get("title", "")
        # 提取标题中的关键词(简单实现)
        keywords = extract_keywords(title)
        topic_keywords.extend(keywords)
    
    # 统计高频关键词
    frequent_topics = get_top_keywords(topic_keywords, top_n=5)
    
    return {
        "total_sessions": total_sessions,
        "frequent_topics": frequent_topics,
        "avg_message_count": round(avg_message_count, 1),
        "recent_sessions": [
            {
                "session_id": s.get("session_id"),
                "title": s.get("title"),
                "date": s.get("date")
            }
            for s in recent_sessions[:5]
        ]
    }


def extract_keywords(text: str) -> List[str]:
    """提取文本关键词(简化实现)
    
    基于预设的关键词列表匹配
    """
    # 预设话题关键词
    topic_keywords = [
        "减肥", "增肌", "营养", "热量", "蛋白质",
        "饮食", "运动", "健康", "养生", "控糖",
        "体重", "目标", "打卡", "食谱", "计划"
    ]
    
    found_keywords = []
    for keyword in topic_keywords:
        if keyword in text:
            found_keywords.append(keyword)
    
    return found_keywords


def get_top_keywords(keywords: List[str], top_n: int = 5) -> List[Dict[str, Any]]:
    """获取高频关键词"""
    from collections import Counter
    
    if not keywords:
        return []
    
    counter = Counter(keywords)
    top_keywords = counter.most_common(top_n)
    
    return [
        {"keyword": kw, "count": count}
        for kw, count in top_keywords
    ]


# 注册所有工具
CHAT_SEARCH_TOOLS = [
    search_chat_history,
    get_user_chat_patterns
]