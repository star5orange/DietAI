"""merge m4_03_water_recorded_last_online and m4_03_achievements heads

Revision ID: m4_04_merge
Revises: m4_03_water_recorded_last_online, m4_03_achievements
Create Date: 2026-08-10 10:30:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'm4_04_merge'
down_revision: Union[str, Sequence[str], None] = ('m4_03_water_recorded_last_online', 'm4_03_achievements')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
