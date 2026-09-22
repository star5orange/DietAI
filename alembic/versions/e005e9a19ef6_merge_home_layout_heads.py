"""merge home layout heads

Revision ID: e005e9a19ef6
Revises: d2278aa1f177, m4_07_home_prefs
Create Date: 2026-09-13 10:43:47.256356

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e005e9a19ef6'
down_revision: Union[str, Sequence[str], None] = ('d2278aa1f177', 'm4_07_home_prefs')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
