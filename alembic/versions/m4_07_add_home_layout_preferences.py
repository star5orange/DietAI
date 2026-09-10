"""add preferences to user_home_layouts (引导问卷偏好)

Revision ID: m4_07_home_prefs
Revises: m4_06_home_layout
Create Date: 2026-09-10 11:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision = 'm4_07_home_prefs'
down_revision = 'm4_06_home_layout'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'user_home_layouts',
        sa.Column(
            'preferences',
            JSONB(),
            nullable=True,
            comment='引导问卷偏好：focus + interests，用于决定首页模块显示与优先级',
        ),
    )


def downgrade() -> None:
    op.drop_column('user_home_layouts', 'preferences')
