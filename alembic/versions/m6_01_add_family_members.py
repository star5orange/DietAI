"""M6.01: 新增 family_members 表（V6 多成员归属，PRD §5.1）

Revision ID: m6_01_family_members
Revises: m5_03_label_review
Create Date: 2026-11-20
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'm6_01_family_members'
down_revision: Union[str, Sequence[str], None] = 'm5_03_label_review'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'family_members',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('home_user_id', sa.Integer(), nullable=False,
                  comment='家庭主账号ID'),
        sa.Column('display_name', sa.String(32), nullable=False, comment='显示名'),
        sa.Column('alias', sa.String(128), nullable=True,
                  comment='别名，逗号分隔（语音匹配用）'),
        sa.Column('avatar', sa.String(256), nullable=True, comment='头像 URL'),
        sa.Column('birth_year', sa.Integer(), nullable=True, comment='出生年'),
        sa.Column('member_type', sa.Integer(), nullable=False, server_default='0',
                  comment='0 成人 / 1 老人 / 2 儿童 / 3 其他'),
        sa.Column('is_managed', sa.Boolean(), nullable=False, server_default=sa.true(),
                  comment='是否由主账号代管（无账号成员为 true）'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true(),
                  comment='停用标记'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0',
                  comment='设备端展示顺序'),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['home_user_id'], ['users.id'], name='fk_family_members_home_user'),
    )
    op.create_index('idx_family_members_home', 'family_members', ['home_user_id'])


def downgrade() -> None:
    op.drop_index('idx_family_members_home', table_name='family_members')
    op.drop_table('family_members')
