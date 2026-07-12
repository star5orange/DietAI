"""add fasting_plan_id to reminders

Revision ID: m3_01
Revises: 202eacfdfa1e
Create Date: 2026-07-12

Milestone 2 补充: reminders 表添加 fasting_plan_id 列，
关联轻断食计划，用于断食提醒。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'm3_01'
down_revision: Union[str, None] = '202eacfdfa1e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'reminders',
        sa.Column(
            'fasting_plan_id',
            sa.Integer(),
            sa.ForeignKey('fasting_plans.id'),
            nullable=True,
            comment='关联轻断食计划ID（M2）'
        )
    )


def downgrade() -> None:
    op.drop_column('reminders', 'fasting_plan_id')
