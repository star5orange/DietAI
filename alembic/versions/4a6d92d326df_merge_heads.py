"""merge_heads

Revision ID: 4a6d92d326df
Revises: 1a2b3c4d5e6f, m3_01
Create Date: 2026-07-13 16:15:44.494641

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4a6d92d326df'
down_revision: Union[str, Sequence[str], None] = ('1a2b3c4d5e6f', 'm3_01')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
