"""add cost and source_tag to food_records

Revision ID: m3_02
Revises: m3_01
Create Date: 2026-07-12

Milestone 2: food_records 表添加 cost（消费金额）和 source_tag（来源标签）列，
用于消费统计功能。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'm3_02'
down_revision: Union[str, Sequence[str], None] = 'f1e2a3b4c5d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('food_records', sa.Column('cost', sa.Numeric(10, 2), nullable=True))
    op.add_column('food_records', sa.Column('source_tag', sa.String(20), nullable=True, comment="canteen/delivery/home/restaurant/snack/other"))
    op.create_index('ix_food_records_source_tag', 'food_records', ['source_tag'])


def downgrade() -> None:
    op.drop_index('ix_food_records_source_tag', table_name='food_records')
    op.drop_column('food_records', 'source_tag')
    op.drop_column('food_records', 'cost')
