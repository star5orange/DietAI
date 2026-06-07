"""
API 限流中间件

用法：
    # 在 main.py 中注册：
    from shared.middleware.rate_limiter import RateLimitMiddleware
    app.add_middleware(RateLimitMiddleware)

    # 或在具体路由上使用依赖注入：
    from shared.middleware.rate_limiter import rate_limit_dependency
    router.get("/sensitive")(rate_limit_dependency(max_req=10, window=60)(handler))
"""

import time
import logging
from collections import defaultdict
from typing import Optional

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)

# 默认配置：每个 IP 每分钟 120 个请求（适合一般 API 使用）
DEFAULT_MAX_REQUESTS = 120
DEFAULT_WINDOW_SECONDS = 60
# 敏感端点（写入操作）更严格：每分钟 30 个请求
WRITE_DEFAULT_MAX = 30
WRITE_DEFAULT_WINDOW = 60

# 写入类路径前缀
WRITE_PATHS = ("/api/exercises/records", "/api/water/records", "/api/reminders/",
               "/api/foods/records", "/api/notifications/responses")


class InMemorySlidingWindow:
    """基于滑动窗口的内存限流器"""

    def __init__(self):
        self._windows: dict = defaultdict(list)

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        """检查请求是否允许。返回 True 表示放行。"""
        now = time.monotonic()
        window = self._windows[key]

        # 清理过期记录
        cutoff = now - window_seconds
        while window and window[0] < cutoff:
            window.pop(0)

        if len(window) >= max_requests:
            return False

        window.append(now)
        return True

    def get_remaining(self, key: str, max_requests: int, window_seconds: int) -> int:
        """获取剩余配额"""
        now = time.monotonic()
        window = self._windows[key]
        cutoff = now - window_seconds
        active = [t for t in window if t >= cutoff]
        return max(0, max_requests - len(active))


# 全局实例
_limiter = InMemorySlidingWindow()


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    全局限流中间件。

    对写入操作（POST/PUT/DELETE）使用更严格的限制。
    使用客户端 IP + 路径前缀作为限流 key。
    """

    async def dispatch(self, request: Request, call_next):
        # 跳过健康检查和文档页
        path = request.url.path
        if path in ("/health", "/", "/docs", "/redoc", "/openapi.json"):
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        method = request.method

        # 写入操作更严格
        is_write = method in ("POST", "PUT", "DELETE") or any(
            path.startswith(p) for p in WRITE_PATHS
        )
        max_req = WRITE_DEFAULT_MAX if is_write else DEFAULT_MAX_REQUESTS
        window = WRITE_DEFAULT_WINDOW if is_write else DEFAULT_WINDOW_SECONDS
        key = f"{client_ip}:{path.split('/')[2] if len(path.split('/')) > 2 else 'root'}"

        if not _limiter.is_allowed(key, max_req, window):
            logger.warning(f"Rate limit exceeded: IP={client_ip} path={path}")
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "message": "请求过于频繁，请稍后重试",
                    "error_code": "RATE_LIMIT_EXCEEDED",
                    "retry_after_seconds": window,
                },
            )

        response = await call_next(request)
        return response


def rate_limit_dependency(max_req: int = 30, window: int = 60):
    """
    路由级别的限流依赖注入。

    用法:
        @router.post("/expensive", dependencies=[Depends(rate_limit_dependency(10, 60))])
    """
    from fastapi import Request, HTTPException

    async def _check(request: Request):
        client_ip = request.client.host if request.client else "unknown"
        key = f"{client_ip}:{request.url.path}"
        if not _limiter.is_allowed(key, max_req, window):
            raise HTTPException(
                status_code=429,
                detail="请求过于频繁，请稍后重试",
            )

    return _check
