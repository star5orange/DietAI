"""add water_intake_records.recorded_by_user_id and users.last_online_at

Revision ID: m4_03_water_recorded_last_online
Revises: b7e9c1f0a4d2
Create Date: 2026-08-10 10:00:00.000000

新增字段:
- water_intake_records.recorded_by_user_id: 代记录人 ID（NULL=本人记录）
- users.last_online_at: 用户最后在线时间（WebSocket 心跳持久化）
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'm4_03_water_recorded_last_online'
down_revision: Union[str, Sequence[str], None] = 'b7e9c1f0a4d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 使用 IF NOT EXISTS 保护，因为表可能已通过 create_all() 创建
    conn = op.get_bind()

    # 1. water_intake_records 新增 recorded_by_user_id 字段（代记录人）
    result = conn.execute(sa.text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'water_intake_records' AND column_name = 'recorded_by_user_id'
    """))
    if not result.fetchone():
        op.add_column(
            'water_intake_records',
            sa.Column(
                'recorded_by_user_id', sa.Integer(),
                sa.ForeignKey('users.id', ondelete='SET NULL'),
                nullable=True,
                comment='代记录人ID（NULL=本人记录，有值=代记录人ID）',
            ),
        )

    # 2. users 新增 last_online_at 字段（最后在线时间）
    result = conn.execute(sa.text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'last_online_at'
    """))
    if not result.fetchone():
        op.add_column(
            'users',
            sa.Column('last_online_at', sa.DateTime(), nullable=True, comment='最后在线时间'),
        )


def downgrade() -> None:
    # 2. 移除 users.last_online_at
    op.drop_column('users', 'last_online_at')

    # 1. 移除 water_intake_records.recorded_by_user_id
    op.drop_column('water_intake_records', 'recorded_by_user_id')
