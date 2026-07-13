"""add monthly_food_budget to user_profiles

Revision ID: m3_03
Revises: 1a2b3c4d5e6f
Create Date: 2026-07-13

Milestone 2: user_profiles 表添加 monthly_food_budget 列
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'm3_03'
down_revision: Union[str, Sequence[str], None] = '1a2b3c4d5e6f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('user_profiles',
        sa.Column('monthly_food_budget', sa.Numeric(10, 2), nullable=True, server_default='0'))


def downgrade() -> None:
    op.drop_column('user_profiles', 'monthly_food_budget')
