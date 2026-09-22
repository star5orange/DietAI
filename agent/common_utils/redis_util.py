from redis.asyncio import Redis as AsyncRedis
from shared.config.settings import get_settings

settings = get_settings()


async def get_redis_client():
    """
    获取异步 Redis 客户端。

    PRD 5.1：外部依赖必须有超时与降级。此处显式设置连接/读写超时，
    避免 Redis 挂起时无限阻塞请求；口径与 shared/config/redis_config.py
    的同步客户端保持一致。
    """
    return await AsyncRedis(
        host=settings.redis_host,
        port=settings.redis_port,
        db=settings.redis_db,
        decode_responses=True,
        password=settings.redis_password,
        socket_connect_timeout=settings.redis_socket_timeout,
        socket_timeout=settings.redis_socket_timeout,
        retry_on_timeout=False,
        health_check_interval=30,
    )

