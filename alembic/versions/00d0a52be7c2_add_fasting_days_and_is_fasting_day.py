"""add_fasting_days_and_is_fasting_day

Revision ID: 00d0a52be7c2
Revises: 4a6d92d326df
Create Date: 2026-07-13 16:16:08.143590

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision: str = '00d0a52be7c2'
down_revision: Union[str, Sequence[str], None] = '4a6d92d326df'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. fasting_plans 表添加 fasting_days 字段
    op.add_column(
        'fasting_plans',
        sa.Column('fasting_days', JSONB, nullable=True, comment='断食日列表，如[0,2]表示周一、周三')
    )

    # 2. fasting_checkins 表添加 is_fasting_day 字段
    op.add_column(
        'fasting_checkins',
        sa.Column('is_fasting_day', sa.Boolean, nullable=False, server_default='true', comment='当天是否是断食日')
    )

    # 3. 添加索引
    op.create_index(
        'idx_fasting_checkin_fasting_day',
        'fasting_checkins',
        ['plan_id', 'is_fasting_day']
    )


def downgrade() -> None:
    """Downgrade schema."""
    # 1. 删除索引
    op.drop_index('idx_fasting_checkin_fasting_day', 'fasting_checkins')

    # 2. 删除字段
    op.drop_column('fasting_checkins', 'is_fasting_day')
    op.drop_column('fasting_plans', 'fasting_days')
