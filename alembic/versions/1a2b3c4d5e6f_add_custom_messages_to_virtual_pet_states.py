"""add custom_messages to virtual_pet_states

Revision ID: 1a2b3c4d5e6f
Revises: 0da986e876fe
Create Date: 2026-07-11 10:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision = '1a2b3c4d5e6f'
down_revision = '0da986e876fe'
branch_labels = None
depends_on = None


def upgrade():
    # 添加 custom_messages 字段到 virtual_pet_states 表
    op.add_column(
        'virtual_pet_states',
        sa.Column(
            'custom_messages',
            JSONB,
            nullable=True,
            server_default=sa.text("'{}'::jsonb"),
            comment='用户自定义宠物提示语，key为场景名称'
        )
    )


def downgrade():
    # 删除 custom_messages 字段
    op.drop_column('virtual_pet_states', 'custom_messages')