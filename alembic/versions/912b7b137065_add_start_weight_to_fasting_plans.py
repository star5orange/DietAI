"""add_start_weight_to_fasting_plans

Revision ID: 912b7b137065
Revises: e7e87122be33
Create Date: 2026-07-31 20:31:36.948262

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '912b7b137065'
down_revision: Union[str, Sequence[str], None] = 'e7e87122be33'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('fasting_plans', sa.Column('start_weight', sa.Numeric(precision=5, scale=2), nullable=True, comment='计划开始时的体重(kg)'))


def downgrade() -> None:
    op.drop_column('fasting_plans', 'start_weight')
