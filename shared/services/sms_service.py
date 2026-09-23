"""
短信发送服务
支持开发环境模拟模式和生产环境真实短信发送
"""

import random
import logging
from typing import Optional
from datetime import datetime, timedelta
import redis
from ..config.settings import get_settings

logger = logging.getLogger(__name__)


class SMSService:
    """短信发送服务"""

    def __init__(self):
        self.settings = get_settings()
        # PRD 5.1：外部依赖（Redis）必须设置超时，避免故障时无限阻塞短信链路
        self.redis_client = redis.Redis(
            host=self.settings.redis_host,
            port=self.settings.redis_port,
            password=self.settings.redis_password,
            db=self.settings.redis_db,
            decode_responses=True,
            socket_connect_timeout=self.settings.redis_socket_timeout,
            socket_timeout=self.settings.redis_socket_timeout,
            retry_on_timeout=False,
        )
        # 验证码有效期（秒）
        self.code_expire_seconds = 300  # 5分钟
        # 验证码长度
        self.code_length = 6
        # 发送频率限制（秒）
        self.send_interval = 60  # 60秒内只能发送一次
        # 每日发送次数限制
        self.daily_limit = 10

    def _generate_code(self) -> str:
        """生成随机验证码"""
        return ''.join([str(random.randint(0, 9)) for _ in range(self.code_length)])

    def _get_redis_key(self, phone: str, key_type: str = "code") -> str:
        """
        获取 Redis key

        Args:
            phone: 手机号
            key_type: 类型 (code-验证码, interval-发送间隔, daily-每日次数)
        """
        return f"sms:{key_type}:{phone}"

    def _check_send_permission(self, phone: str) -> tuple[bool, str]:
        """
        检查发送权限

        Returns:
            (是否允许发送, 错误消息)
        """
        # 检查发送间隔
        interval_key = self._get_redis_key(phone, "interval")
        try:
            if self.redis_client.exists(interval_key):
                ttl = self.redis_client.ttl(interval_key)
                return False, f"发送过于频繁，请{ttl}秒后再试"
        except Exception as e:
            # Redis 故障时采用「安全失败」：拒绝发送，避免击穿频率限制
            logger.warning(f"[降级] 短信发送间隔检查失败(Redis不可用): {e}")
            return False, "短信服务暂时不可用，请稍后重试"

        # 检查每日发送次数
        daily_key = self._get_redis_key(phone, "daily")
        try:
            daily_count = int(self.redis_client.get(daily_key) or 0)
        except Exception as e:
            logger.warning(f"[降级] 短信每日次数检查失败(Redis不可用): {e}")
            return False, "短信服务暂时不可用，请稍后重试"
        if daily_count >= self.daily_limit:
            return False, "今日发送次数已达上限"

        return True, ""

    def send_verification_code(self, phone: str, purpose: str = "reset_password") -> dict:
        """
        发送验证码

        Args:
            phone: 手机号
            purpose: 用途 (reset_password-重置密码)

        Returns:
            {
                "success": bool,
                "message": str,
                "code": str  # 仅开发环境返回
            }
        """
        # 检查发送权限
        can_send, error_msg = self._check_send_permission(phone)
        if not can_send:
            return {"success": False, "message": error_msg}

        # 生成验证码
        code = self._generate_code()

        # 存储验证码到 Redis
        code_key = self._get_redis_key(phone, "code")
        try:
            self.redis_client.setex(code_key, self.code_expire_seconds, f"{code}:{purpose}")
        except Exception as e:
            # 验证码无法落库时后续校验必然失败，直接返回明确失败结果
            logger.warning(f"[降级] 短信验证码写入失败(Redis不可用): {e}")
            return {"success": False, "message": "短信服务暂时不可用，请稍后重试"}

        # 设置发送间隔（限流为尽力而为，失败仅告警不影响本次发送）
        interval_key = self._get_redis_key(phone, "interval")
        try:
            self.redis_client.setex(interval_key, self.send_interval, "1")
        except Exception as e:
            logger.warning(f"[降级] 短信发送间隔写入失败(Redis不可用): {e}")

        # 增加每日发送次数（同上，失败仅告警）
        daily_key = self._get_redis_key(phone, "daily")
        try:
            if not self.redis_client.exists(daily_key):
                # 如果不存在，设置过期时间为当天结束
                now = datetime.now()
                end_of_day = datetime(now.year, now.month, now.day, 23, 59, 59)
                ttl = int((end_of_day - now).total_seconds())
                self.redis_client.setex(daily_key, ttl, 1)
            else:
                self.redis_client.incr(daily_key)
        except Exception as e:
            logger.warning(f"[降级] 短信每日次数写入失败(Redis不可用): {e}")

        # 发送短信（根据配置选择模式）
        if self.settings.debug:
            # 开发环境：模拟发送，打印到日志
            logger.info(f"[模拟短信] 手机号: {phone}, 验证码: {code}, 用途: {purpose}")
            logger.warning(f"📱 验证码: {code} (有效期5分钟)")
            return {
                "success": True,
                "message": "验证码已发送",
                "code": code  # 开发环境返回验证码，方便测试
            }
        else:
            # 生产环境：调用真实短信服务
            try:
                result = self._send_real_sms(phone, code, purpose)
                return result
            except Exception as e:
                logger.error(f"发送短信失败: {e}")
                return {"success": False, "message": "短信发送失败，请稍后重试"}

    def _send_real_sms(self, phone: str, code: str, purpose: str) -> dict:
        """
        调用真实短信服务
        可接入火山引擎短信、阿里云短信等服务
        """
        # TODO: 接入火山引擎短信服务
        # 示例代码（需要配置火山引擎短信 API Key）:
        #
        # from volcengine.sms.SmsService import SmsService
        #
        # sms_service = SmsService()
        # sms_service.set_cred(self.settings.volc_sms_access_key, self.settings.volc_sms_secret_key)
        #
        # result = sms_service.send(
        #     snsAccountId="your_account_id",
        #     sign="DietAI",
        #     templateID="your_template_id",
        #     phoneNumbers=[phone],
        #     templateParams=[code]
        # )
        #
        # if result["ResponseMetadata"]["Error"]:
        #     raise Exception(result["ResponseMetadata"]["Error"]["Message"])

        # 临时方案：开发环境打印到控制台
        logger.info(f"[真实短信] 手机号: {phone}, 验证码: {code}, 用途: {purpose}")
        logger.warning(f"⚠️ 请接入火山引擎短信服务或阿里云短信服务")

        return {
            "success": True,
            "message": "验证码已发送",
        }

    def verify_code(self, phone: str, code: str, purpose: str = "reset_password", consume: bool = True) -> tuple[bool, str]:
        """
        验证验证码

        Args:
            phone: 手机号
            code: 验证码
            purpose: 用途
            consume: 是否消费验证码（验证后删除）

        Returns:
            (是否验证成功, 错误消息)
        """
        code_key = self._get_redis_key(phone, "code")

        # 检查验证码是否存在
        try:
            stored_value = self.redis_client.get(code_key)
        except Exception as e:
            logger.warning(f"[降级] 短信验证码读取失败(Redis不可用): {e}")
            return False, "验证码校验服务暂时不可用，请稍后重试"
        if not stored_value:
            return False, "验证码已过期或不存在"

        # 解析存储的值
        try:
            stored_code, stored_purpose = stored_value.split(":")
        except ValueError:
            return False, "验证码格式错误"

        # 验证用途
        if stored_purpose != purpose:
            return False, "验证码用途不匹配"

        # 验证验证码
        if stored_code != code:
            return False, "验证码错误"

        # 验证成功，根据参数决定是否删除验证码
        if consume:
            try:
                self.redis_client.delete(code_key)
            except Exception as e:
                # 删除失败不影响本次校验结果，验证码会按 TTL 自然过期
                logger.warning(f"[降级] 短信验证码删除失败(Redis不可用): {e}")

        return True, "验证成功"

    def clear_daily_limit(self, phone: str):
        """清除每日发送限制（用于测试）"""
        daily_key = self._get_redis_key(phone, "daily")
        try:
            self.redis_client.delete(daily_key)
        except Exception as e:
            logger.warning(f"[降级] 清除短信每日次数失败(Redis不可用): {e}")


# 单例模式
_sms_service_instance: Optional[SMSService] = None


def get_sms_service() -> SMSService:
    """获取短信服务实例"""
    global _sms_service_instance
    if _sms_service_instance is None:
        _sms_service_instance = SMSService()
    return _sms_service_instance