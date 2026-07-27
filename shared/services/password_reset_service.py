"""
密码重置服务
处理用户忘记密码、验证码验证、密码重置等逻辑
"""

import logging
from typing import Optional
from sqlalchemy.orm import Session
from ..models.user_models import User
from ..utils.auth import AuthService
from .sms_service import get_sms_service

logger = logging.getLogger(__name__)


class PasswordResetService:
    """密码重置服务"""

    def __init__(self, db: Session):
        self.db = db
        self.sms_service = get_sms_service()

    def get_user_by_phone(self, phone: str) -> Optional[User]:
        """
        根据手机号查询用户

        Args:
            phone: 手机号（明文）

        Returns:
            User 对象或 None
        """
        # 由于 phone 字段是加密的，需要使用盲索引查询
        from ..models.user_models import _blind_index
        phone_hash = _blind_index(phone)

        user = self.db.query(User).filter(User.phone_hash == phone_hash).first()
        return user

    def send_reset_code(self, phone: str) -> dict:
        """
        发送密码重置验证码

        Args:
            phone: 手机号

        Returns:
            {
                "success": bool,
                "message": str,
                "code": str  # 仅开发环境返回
            }
        """
        # 检查用户是否存在
        user = self.get_user_by_phone(phone)
        if not user:
            return {"success": False, "message": "该手机号未注册"}

        # 检查用户状态
        if user.status != 1:
            return {"success": False, "message": "该账号已被禁用"}

        # 发送验证码
        result = self.sms_service.send_verification_code(phone, purpose="reset_password")

        return result

    def verify_reset_code(self, phone: str, code: str) -> tuple[bool, str]:
        """
        验证密码重置验证码

        Args:
            phone: 手机号
            code: 验证码

        Returns:
            (是否验证成功, 错误消息)
        """
        # 验证验证码，但不消费（不删除）
        is_valid, message = self.sms_service.verify_code(phone, code, purpose="reset_password", consume=False)

        return is_valid, message

    def reset_password(self, phone: str, new_password: str) -> dict:
        """
        重置密码

        Args:
            phone: 手机号
            new_password: 新密码

        Returns:
            {
                "success": bool,
                "message": str
            }
        """
        # 查询用户
        user = self.get_user_by_phone(phone)
        if not user:
            return {"success": False, "message": "用户不存在"}

        # 检查用户状态
        if user.status != 1:
            return {"success": False, "message": "该账号已被禁用"}

        # 更新密码
        user.password_hash = AuthService.hash_password(new_password)
        self.db.commit()

        logger.info(f"用户 {user.username} 通过手机号 {phone} 重置密码成功")

        return {"success": True, "message": "密码重置成功"}

    def change_password(self, user_id: int, old_password: str, new_password: str) -> dict:
        """
        修改密码（需要旧密码验证）

        Args:
            user_id: 用户ID
            old_password: 旧密码
            new_password: 新密码

        Returns:
            {
                "success": bool,
                "message": str
            }
        """
        # 查询用户
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"success": False, "message": "用户不存在"}

        # 验证旧密码
        if not AuthService.verify_password(old_password, user.password_hash):
            return {"success": False, "message": "旧密码错误"}

        # 更新密码
        user.password_hash = AuthService.hash_password(new_password)
        self.db.commit()

        logger.info(f"用户 {user.username} 修改密码成功")

        return {"success": True, "message": "密码修改成功"}