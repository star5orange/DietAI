"""merge_all_heads

Revision ID: e7e87122be33
Revises: 00d0a52be7c2, add_target_calories, d5e6f7a8b9c0, ex01, m2_01_pet_hw
Create Date: 2026-07-31 20:31:13.610602

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7e87122be33'
down_revision: Union[str, Sequence[str], None] = ('00d0a52be7c2', 'add_target_calories', 'd5e6f7a8b9c0', 'ex01', 'm2_01_pet_hw')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
