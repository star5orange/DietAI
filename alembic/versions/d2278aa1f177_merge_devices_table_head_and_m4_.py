"""merge devices table head and m4 frontend head

Revision ID: d2278aa1f177
Revises: ff905333d9b6, m4_05_fix_relationship_unique
Create Date: 2026-08-27 12:17:27.960740

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd2278aa1f177'
down_revision: Union[str, Sequence[str], None] = ('ff905333d9b6', 'm4_05_fix_relationship_unique')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
