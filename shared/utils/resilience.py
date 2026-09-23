"""
统一超时降级层（PRD 5.1）

外部依赖（LLM、Redis、HTTP 服务等）必须有超时与降级，
任何超时/异常都不得向上抛出，保证「请求超时事件归零」。

本模块为纯标准库实现，不引入 tenacity/backoff 等新依赖。

提供能力：
- with_timeout：异步协程超时 + 降级
- sync_with_timeout：同步函数（独立线程）超时 + 降级
- retry_async：异步指数退避重试 + 降级
- CircuitBreaker：轻量熔断器（线程安全）

超时数值优先读取 shared.config.settings.settings 中的配置项，
读取失败时回退到本模块内置默认值。
"""

import asyncio
import inspect
import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeoutError
from typing import Any, Callable, Optional

logger = logging.getLogger(__name__)


def _get_setting(name: str, default: Any) -> Any:
    """从应用配置中读取超时/重试相关配置项，读不到时返回默认值。"""
    try:
        from shared.config.settings import settings as _settings

        value = getattr(_settings, name, None)
        if value is None:
            return default
        return value
    except Exception as exc:  # 配置未就绪时不阻塞导入
        logger.debug("读取配置 %s 失败，使用默认值 %s: %s", name, default, exc)
        return default


# 通用外部依赖默认超时（秒），优先取 ai_service_timeout 配置
DEFAULT_TIMEOUT_SECONDS: float = float(_get_setting("ai_service_timeout", 20.0))
# Redis 操作超时（秒），与 shared/config/redis_config.py 的同步客户端口径一致
REDIS_TIMEOUT_SECONDS: float = float(_get_setting("redis_socket_timeout", 0.5))
# 外部 HTTP 依赖超时（秒）
EXTERNAL_HTTP_TIMEOUT_SECONDS: float = float(_get_setting("external_http_timeout", 30.0))


async def with_timeout(
    coro,
    seconds: float,
    *,
    fallback: Any = None,
    op_name: str = "",
) -> Any:
    """
    对协程施加超时保护，超时或异常时返回 fallback，永不抛异常。

    Args:
        coro: 待执行的协程对象（或可 await 的对象）
        seconds: 超时时间（秒），<=0 时使用 DEFAULT_TIMEOUT_SECONDS
        fallback: 超时/异常时的降级返回值
        op_name: 操作名，用于日志定位

    Returns:
        协程正常返回值，或 fallback
    """
    timeout = float(seconds) if seconds and seconds > 0 else DEFAULT_TIMEOUT_SECONDS
    name = op_name or "unnamed_op"
    try:
        result = await asyncio.wait_for(coro, timeout=timeout)
        return result
    except asyncio.TimeoutError:
        logger.warning("[降级] 操作 %s 超时(>%.2fs)，返回降级值", name, timeout)
        return fallback
    except asyncio.CancelledError:
        # 上层取消（如客户端断开）需继续传播，避免吞掉协程取消语义
        logger.warning("[降级] 操作 %s 被取消", name)
        return fallback
    except Exception as exc:
        logger.warning("[降级] 操作 %s 异常(%s: %s)，返回降级值", name, type(exc).__name__, exc)
        return fallback


def sync_with_timeout(
    fn: Callable[[], Any],
    seconds: float,
    *,
    fallback: Any = None,
    op_name: str = "",
) -> Any:
    """
    同步版本的超时保护：在独立线程中执行并等待固定时长，
    超时或异常时返回 fallback，永不抛异常。

    Args:
        fn: 无参可调用对象
        seconds: 超时时间（秒），<=0 时使用 DEFAULT_TIMEOUT_SECONDS
        fallback: 超时/异常时的降级返回值
        op_name: 操作名，用于日志定位

    Returns:
        fn 正常返回值，或 fallback
    """
    timeout = float(seconds) if seconds and seconds > 0 else DEFAULT_TIMEOUT_SECONDS
    name = op_name or "unnamed_sync_op"
    executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="resilience")
    try:
        future = executor.submit(fn)
        return future.result(timeout=timeout)
    except FuturesTimeoutError:
        logger.warning("[降级] 同步操作 %s 超时(>%.2fs)，返回降级值", name, timeout)
        return fallback
    except Exception as exc:
        logger.warning("[降级] 同步操作 %s 异常(%s: %s)，返回降级值", name, type(exc).__name__, exc)
        return fallback
    finally:
        # 不阻塞等待超时线程结束，避免拖慢调用方
        executor.shutdown(wait=False)


async def retry_async(
    fn: Callable[[], Any],
    *,
    attempts: int = 3,
    base_delay: float = 0.5,
    max_delay: float = 4.0,
    fallback: Any = None,
    op_name: str = "",
) -> Any:
    """
    异步指数退避重试，全部失败后返回 fallback，永不抛异常。

    Args:
        fn: 无参可调用对象，可返回协程或普通值
        attempts: 总尝试次数（含首次）
        base_delay: 首次退避基准（秒）
        max_delay: 单次退避上限（秒）
        fallback: 全部失败时的降级返回值
        op_name: 操作名，用于日志定位

    Returns:
        fn 成功返回值，或 fallback
    """
    name = op_name or "unnamed_retry_op"
    total = max(1, int(attempts))
    last_exc: Optional[BaseException] = None

    for attempt in range(1, total + 1):
        try:
            result = fn()
            if inspect.isawaitable(result):
                result = await result
            return result
        except Exception as exc:
            last_exc = exc
            if attempt >= total:
                break
            delay = min(base_delay * (2 ** (attempt - 1)), max_delay)
            logger.warning(
                "[重试] 操作 %s 第 %d/%d 次失败(%s: %s)，%.2fs 后重试",
                name, attempt, total, type(exc).__name__, exc, delay,
            )
            await asyncio.sleep(delay)

    logger.warning(
        "[降级] 操作 %s 重试 %d 次后仍失败(%s: %s)，返回降级值",
        name, total, type(last_exc).__name__ if last_exc else "Unknown", last_exc,
    )
    return fallback


class CircuitBreaker:
    """
    轻量熔断器（线程安全）。

    连续失败达到 failure_threshold 后打开熔断，
    在 open_seconds 内 allow() 返回 False，直接走降级路径，
    避免每次请求都去等待外部依赖超时。
    """

    def __init__(
        self,
        failure_threshold: int = 3,
        open_seconds: float = 30.0,
        name: str = "",
    ) -> None:
        self.failure_threshold = int(failure_threshold)
        self.open_seconds = float(open_seconds)
        self.name = name or "circuit"
        self._lock = threading.Lock()
        self._failures = 0
        self._open_until = 0.0

    def allow(self) -> bool:
        """当前是否允许调用外部依赖（熔断打开期间返回 False）。"""
        with self._lock:
            return time.monotonic() >= self._open_until

    def note_success(self) -> None:
        """记录一次成功，重置失败计数并关闭熔断。"""
        with self._lock:
            self._failures = 0
            self._open_until = 0.0

    def note_failure(self) -> None:
        """记录一次失败，达到阈值后打开熔断。"""
        with self._lock:
            self._failures += 1
            if self._failures >= self.failure_threshold:
                self._open_until = time.monotonic() + self.open_seconds
                self._failures = 0
                logger.warning(
                    "[熔断] %s 连续失败达阈值，熔断 %.1fs",
                    self.name, self.open_seconds,
                )
