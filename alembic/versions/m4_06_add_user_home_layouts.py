"""add user_home_layouts table (首页模块布局偏好)

Revision ID: m4_06_home_layout
Revises: m4_05_fix_relationship_unique
Create Date: 2026-09-10 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# revision identifiers, used by Alembic.
revision = 'm4_06_home_layout'
down_revision = 'm4_05_fix_relationship_unique'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'user_home_layouts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('hidden_modules', JSONB(), nullable=False,
                  server_default=sa.text("'[]'::jsonb"),
                  comment='用户手动隐藏的模块ID列表'),
        sa.Column('module_order', JSONB(), nullable=True,
                  comment='用户自定义模块顺序（模块ID列表）；NULL 表示使用默认顺序'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', name='uq_home_layout_user'),
    )
    op.create_index('ix_user_home_layouts_user_id', 'user_home_layouts', ['user_id'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_user_home_layouts_user_id', table_name='user_home_layouts')
    op.drop_table('user_home_layouts')
