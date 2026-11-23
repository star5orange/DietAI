"""M6.02: food/water 记录表新增归属五件套（V6，PRD §5.2）

- member_id / attributed_by / attribution_confidence / device_id / client_uuid
- 全部可空；空 = 归属 user_id 本人，历史数据不做回填（A8）
- client_uuid 可空 + 唯一索引（A3 断网补传幂等去重依据）
- recorded_by_user_id 已在 M4 存在，无需新增（F12 操作者复用此列）

Revision ID: m6_02_record_attribution
Revises: m6_01_family_members
Create Date: 2026-11-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'm6_02_record_attribution'
down_revision: Union[str, Sequence[str], None] = 'm6_01_family_members'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = ['food_records', 'water_intake_records']


def upgrade() -> None:
    for table in TABLES:
        op.add_column(table, sa.Column('member_id', sa.Integer(), nullable=True,
                                       comment='归属成员ID，空=账号本人'))
        op.add_column(table, sa.Column('attributed_by', sa.String(16), nullable=True,
                                       comment='归属依据: device_bind/voice_name/screen/default/manual/reconcile（开放集合）'))
        op.add_column(table, sa.Column('attribution_confidence', sa.Float(), nullable=True,
                                       comment='归属置信度 0-1'))
        op.add_column(table, sa.Column('device_id', sa.String(64), nullable=True,
                                       comment='来源设备（device_key）'))
        op.add_column(table, sa.Column('client_uuid', sa.String(36), nullable=True,
                                       comment='客户端幂等键，断网补传去重依据（A3）'))
        op.create_foreign_key(
            f'fk_{table}_member', table, 'family_members', ['member_id'], ['id']
        )
        op.create_index(f'idx_{table}_member', table, ['member_id'])
        op.create_index(f'uq_{table}_client_uuid', table, ['client_uuid'], unique=True)


def downgrade() -> None:
    for table in TABLES:
        op.drop_index(f'uq_{table}_client_uuid', table_name=table)
        op.drop_index(f'idx_{table}_member', table_name=table)
        op.drop_constraint(f'fk_{table}_member', table, type_='foreignkey')
        for col in ['client_uuid', 'device_id', 'attribution_confidence', 'attributed_by', 'member_id']:
            op.drop_column(table, col)
