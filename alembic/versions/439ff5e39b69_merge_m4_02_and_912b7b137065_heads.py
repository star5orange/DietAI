"""merge m4_02 and 912b7b137065 heads

Revision ID: 439ff5e39b69
Revises: 912b7b137065, m4_02_social_exam
Create Date: 2026-08-04 15:59:51.054829

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '439ff5e39b69'
down_revision: Union[str, Sequence[str], None] = ('912b7b137065', 'm4_02_social_exam')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
