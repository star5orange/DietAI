"""add target_calories field

Revision ID: add_target_calories
Revises: e6a322b5c6ba
Create Date: 2026-07-14 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_target_calories'
down_revision = 'e6a322b5c6ba'
branch_labels = None
depends_on = None


def upgrade():
    # 添加 target_calories 字段到 user_profiles 表
    op.add_column('user_profiles',
        sa.Column('target_calories', sa.Integer(), nullable=True, default=2000)
    )


def downgrade():
    # 删除 target_calories 字段
    op.drop_column('user_profiles', 'target_calories')