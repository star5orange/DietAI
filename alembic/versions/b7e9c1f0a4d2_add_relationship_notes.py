"""add note_from_user and note_from_related to user_relationships

Revision ID: b7e9c1f0a4d2
Revises: f6936fa8f76a
Create Date: 2026-08-05

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'b7e9c1f0a4d2'
down_revision: Union[str, Sequence[str], None] = 'f6936fa8f76a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """添加用户关系称谓字段（用户发起方/接收方对彼此的称呼）"""
    op.execute("ALTER TABLE user_relationships ADD COLUMN IF NOT EXISTS note_from_user VARCHAR(50)")
    op.execute("ALTER TABLE user_relationships ADD COLUMN IF NOT EXISTS note_from_related VARCHAR(50)")


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("ALTER TABLE user_relationships DROP COLUMN IF EXISTS note_from_user")
    op.execute("ALTER TABLE user_relationships DROP COLUMN IF EXISTS note_from_related")
