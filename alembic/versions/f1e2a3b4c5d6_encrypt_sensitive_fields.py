"""encrypt_sensitive_fields: 加密敏感字段 + 新增盲索引列

Revision ID: f1e2a3b4c5d6
Revises: d3f1a2b3c4d5
Create Date: 2026-06-14

变更内容：
  1. users 表：
     - email 列宽从 100 扩大到 364（加密后约为原文 3 倍 + 64）
     - phone 列宽从 20 扩大到 124
     - 新增 email_hash (VARCHAR 64, UNIQUE) 盲索引列
     - 新增 phone_hash (VARCHAR 64, UNIQUE) 盲索引列
     - 删除 email 上的原有 unique 约束（密文无法做唯一约束）
     - 删除 phone 上的原有 unique 约束

  2. user_profiles 表：
     - real_name 列宽从 100 扩大到 364
     - occupation 列宽从 100 扩大到 364
     - region 列宽从 100 扩大到 364

  3. diseases 表：
     - disease_code 列宽从 20 扩大到 124
     - disease_name 列宽从 200 扩大到 664
     - notes 从 Text 扩大（Text 无长度限制，无需改动）

  4. allergies 表：
     - allergen_name 列宽从 100 扩大到 364
     - reaction_description 从 Text 扩大（Text 无长度限制，无需改动）

  5. weight_records 表：
     - notes 从 Text 扩大（Text 无长度限制，无需改动）

注意：此迁移仅修改表结构，不迁移已有数据。
      已有明文数据需运行数据迁移脚本单独处理。
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'f1e2a3b4c5d6'
down_revision: Union[str, Sequence[str], None] = 'd3f1a2b3c4d5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ========== users 表 ==========
    # 删除原有的 unique 约束（PostgreSQL 命名规则：uq_<table>_<column>）
    # 先尝试删除可能存在的 unique 约束
    op.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS uq_users_email")
    op.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS uq_users_phone")
    # 也尝试 PostgreSQL 默认命名
    op.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key")
    op.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_phone_key")

    # 扩大加密字段列宽
    op.alter_column('users', 'email',
                    existing_type=sa.String(100),
                    type_=sa.String(364),
                    existing_nullable=True)
    op.alter_column('users', 'phone',
                    existing_type=sa.String(20),
                    type_=sa.String(124),
                    existing_nullable=True)

    # 新增盲索引列
    op.add_column('users', sa.Column('email_hash', sa.String(64), nullable=True))
    op.add_column('users', sa.Column('phone_hash', sa.String(64), nullable=True))

    # 创建盲索引 unique 约束
    op.create_unique_constraint('uq_users_email_hash', 'users', ['email_hash'])
    op.create_unique_constraint('uq_users_phone_hash', 'users', ['phone_hash'])
    op.create_index('ix_users_email_hash', 'users', ['email_hash'])
    op.create_index('ix_users_phone_hash', 'users', ['phone_hash'])

    # ========== user_profiles 表 ==========
    op.alter_column('user_profiles', 'real_name',
                    existing_type=sa.String(100),
                    type_=sa.String(364),
                    existing_nullable=True)
    op.alter_column('user_profiles', 'occupation',
                    existing_type=sa.String(100),
                    type_=sa.String(364),
                    existing_nullable=True)
    op.alter_column('user_profiles', 'region',
                    existing_type=sa.String(100),
                    type_=sa.String(364),
                    existing_nullable=True)

    # ========== diseases 表 ==========
    op.alter_column('diseases', 'disease_code',
                    existing_type=sa.String(20),
                    type_=sa.String(124),
                    existing_nullable=True)
    op.alter_column('diseases', 'disease_name',
                    existing_type=sa.String(200),
                    type_=sa.String(664),
                    existing_nullable=False)

    # ========== allergies 表 ==========
    op.alter_column('allergies', 'allergen_name',
                    existing_type=sa.String(100),
                    type_=sa.String(364),
                    existing_nullable=False)


def downgrade() -> None:
    # ========== allergies 表 ==========
    op.alter_column('allergies', 'allergen_name',
                    existing_type=sa.String(364),
                    type_=sa.String(100),
                    existing_nullable=False)

    # ========== diseases 表 ==========
    op.alter_column('diseases', 'disease_name',
                    existing_type=sa.String(664),
                    type_=sa.String(200),
                    existing_nullable=False)
    op.alter_column('diseases', 'disease_code',
                    existing_type=sa.String(124),
                    type_=sa.String(20),
                    existing_nullable=True)

    # ========== user_profiles 表 ==========
    op.alter_column('user_profiles', 'region',
                    existing_type=sa.String(364),
                    type_=sa.String(100),
                    existing_nullable=True)
    op.alter_column('user_profiles', 'occupation',
                    existing_type=sa.String(364),
                    type_=sa.String(100),
                    existing_nullable=True)
    op.alter_column('user_profiles', 'real_name',
                    existing_type=sa.String(364),
                    type_=sa.String(100),
                    existing_nullable=True)

    # ========== users 表 ==========
    op.drop_index('ix_users_phone_hash', table_name='users')
    op.drop_index('ix_users_email_hash', table_name='users')
    op.drop_constraint('uq_users_phone_hash', 'users', type_='unique')
    op.drop_constraint('uq_users_email_hash', 'users', type_='unique')
    op.drop_column('users', 'phone_hash')
    op.drop_column('users', 'email_hash')

    op.alter_column('users', 'phone',
                    existing_type=sa.String(124),
                    type_=sa.String(20),
                    existing_nullable=True)
    op.alter_column('users', 'email',
                    existing_type=sa.String(364),
                    type_=sa.String(100),
                    existing_nullable=True)

    # 恢复原有 unique 约束
    op.create_unique_constraint('uq_users_email', 'users', ['email'])
    op.create_unique_constraint('uq_users_phone', 'users', ['phone'])
