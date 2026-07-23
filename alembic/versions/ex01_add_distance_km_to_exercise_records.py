"""add distance_km to exercise_records

Revision ID: ex01
Revises: 836eda525ee8
Create Date: 2026-07-22

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ex01'
down_revision: Union[str, Sequence[str], None] = '836eda525ee8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: 添加运动距离字段"""
    op.add_column('exercise_records',
        sa.Column('distance_km', sa.Numeric(5, 2), nullable=True,
                  comment='运动距离(公里)，适用于跑步/骑行/游泳/步行')
    )


def downgrade() -> None:
    """Downgrade schema: 移除运动距离字段"""
    op.drop_column('exercise_records', 'distance_km')
