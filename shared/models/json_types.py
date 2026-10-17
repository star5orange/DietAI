"""跨方言 JSON 列类型。

本地开发跑 PostgreSQL，部署平台只提供 MariaDB —— 同一个模型要能在两种方言下建表。
PostgreSQL 侧保持原有的 JSONB（行为与改造前完全一致），其余方言落原生 JSON。
"""
from sqlalchemy import JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import TypeDecorator


class PortableJSON(TypeDecorator):
    """跨方言 JSON 列：PostgreSQL 仍落 JSONB，MySQL/MariaDB 落原生 JSON。"""

    impl = JSON
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(JSONB())
        return dialect.type_descriptor(JSON())
