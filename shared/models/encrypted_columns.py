"""
SQLAlchemy 自定义加密列类型

使用方式与普通 String/Text 完全一致，读写时自动加解密：
    disease_name = Column(EncryptedString(200))

写入: model.disease_name = "高血压"  → 数据库存储密文
读取: print(model.disease_name)     → 自动解密返回 "高血压"
"""

from sqlalchemy import String, Text, TypeDecorator


class EncryptedString(TypeDecorator):
    """自动加解密的 String 类型

    数据库列使用 String 存储 Base64 编码的密文，
    加密后长度约为原文的 2~3 倍，内部自动按 3 倍扩大列宽。
    """
    impl = String
    cache_ok = True

    def __init__(self, length: int, **kwargs):
        # 加密后长度约为原文 3 倍，预留余量
        encrypted_length = length * 3 + 64
        super().__init__(encrypted_length, **kwargs)

    def process_bind_param(self, value, dialect):
        """写入数据库前加密"""
        if value is None:
            return None
        from ..utils.field_encryption import encrypt_field
        return encrypt_field(value)

    def process_result_value(self, value, dialect):
        """从数据库读取后解密"""
        if value is None:
            return None
        from ..utils.field_encryption import decrypt_field
        return decrypt_field(value)


class EncryptedText(TypeDecorator):
    """自动加解密的 Text 类型

    用于可能较长的加密字段（如 notes、reaction_description）。
    """
    impl = Text
    cache_ok = True

    def process_bind_param(self, value, dialect):
        """写入数据库前加密"""
        if value is None:
            return None
        from ..utils.field_encryption import encrypt_field
        return encrypt_field(value)

    def process_result_value(self, value, dialect):
        """从数据库读取后解密"""
        if value is None:
            return None
        from ..utils.field_encryption import decrypt_field
        return decrypt_field(value)
