"""
数据库字段加解密工具

使用 AES-256-GCM 对敏感字段进行应用层加密。
- 密文格式: base64( iv[12] + ciphertext + tag[16] )
- 加密后字符串长度约为原文的 2~3 倍，数据库列需预留足够宽度
"""

import base64
import os
import logging
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

# 单次加密的 nonce 长度 (GCM 推荐 12 字节)
_NONCE_LEN = 12


class FieldEncryption:
    """字段级加解密"""

    def __init__(self, key_b64: str):
        """
        Args:
            key_b64: Base64 编码的 32 字节 (256-bit) 密钥
        """
        key_bytes = base64.b64decode(key_b64)
        if len(key_bytes) != 32:
            raise ValueError("加密密钥必须为 32 字节 (256-bit)，请使用 generate_key() 生成")
        self._aesgcm = AESGCM(key_bytes)

    @staticmethod
    def generate_key() -> str:
        """生成一个新的 256-bit 密钥，返回 Base64 编码字符串"""
        return base64.b64encode(os.urandom(32)).decode()

    def encrypt(self, plaintext: Optional[str]) -> Optional[str]:
        """加密字符串，返回 Base64 编码的密文；输入 None 时返回 None"""
        if plaintext is None:
            return None
        if plaintext == "":
            return ""

        nonce = os.urandom(_NONCE_LEN)
        ct = self._aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
        # ct 已包含 GCM tag (16 bytes)
        return base64.b64encode(nonce + ct).decode("ascii")

    def decrypt(self, ciphertext: Optional[str]) -> Optional[str]:
        """解密 Base64 编码的密文，返回原始字符串；输入 None 时返回 None"""
        if ciphertext is None:
            return None
        if ciphertext == "":
            return ""

        raw = base64.b64decode(ciphertext)
        nonce = raw[:_NONCE_LEN]
        ct_with_tag = raw[_NONCE_LEN:]
        return self._aesgcm.decrypt(nonce, ct_with_tag, None).decode("utf-8")


# ---- 全局单例（延迟初始化） ----

_encryptor: Optional[FieldEncryption] = None


def _get_encryptor() -> FieldEncryption:
    global _encryptor
    if _encryptor is None:
        from ..config.settings import get_settings
        settings = get_settings()
        key = settings.field_encryption_key
        if not key:
            raise ValueError(
                "未设置字段加密密钥！请在 .env 中配置 DIETAI_FIELD_ENCRYPTION_KEY\n"
                "生成方式: python -c \"from shared.utils.field_encryption import FieldEncryption; print(FieldEncryption.generate_key())\""
            )
        _encryptor = FieldEncryption(key)
    return _encryptor


def encrypt_field(value: Optional[str]) -> Optional[str]:
    """便捷函数：加密字段值"""
    return _get_encryptor().encrypt(value)


def decrypt_field(value: Optional[str]) -> Optional[str]:
    """便捷函数：解密字段值"""
    return _get_encryptor().decrypt(value)
