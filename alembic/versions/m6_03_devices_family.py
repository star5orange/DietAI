"""M6.03: devices 表新增 C6 六列（V6 设备管理，PRD 15.9.2 / 契约 C6）

- device_type / name / current_member_id / locked_member_id / firmware_version / home_user_id
- 现有数据全保留；home_user_id 由原 user_id 换算回填（绑定前为空的设备保持空）
- 旧固件不带 firmware_version → 存 null，不报错

Revision ID: m6_03_devices_family
Revises: m6_02_record_attribution
Create Date: 2026-11-21
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'm6_03_devices_family'
down_revision: Union[str, Sequence[str], None] = 'm6_02_record_attribution'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('devices', sa.Column('device_type', sa.String(16), nullable=True,
                                       comment='设备形态: clock(一人一机)/robot(一家一机)'))
    op.add_column('devices', sa.Column('name', sa.String(32), nullable=True,
                                       comment='用户自定义设备名'))
    op.add_column('devices', sa.Column('current_member_id', sa.Integer(), nullable=True,
                                       comment='设备当前成员（C4 双向同步，云端权威值）'))
    op.add_column('devices', sa.Column('locked_member_id', sa.Integer(), nullable=True,
                                       comment='锁定成员：时钟必填恒归属；空=可切换（机器人）'))
    op.add_column('devices', sa.Column('firmware_version', sa.String(32), nullable=True,
                                       comment='固件版本，sync 上报经 X-Firmware-Version 头携带'))
    op.add_column('devices', sa.Column('home_user_id', sa.Integer(), nullable=True,
                                       comment='设备归属家庭主账号（由 user_id 换算，绑定前为空）'))

    # 回填：home_user_id = 原 user_id（契约 C6"迁移时由原 user_id 换算写入"）
    op.execute("UPDATE devices SET home_user_id = user_id WHERE home_user_id IS NULL AND user_id IS NOT NULL")

    op.create_foreign_key('fk_devices_current_member', 'devices', 'family_members',
                          ['current_member_id'], ['id'])
    op.create_foreign_key('fk_devices_locked_member', 'devices', 'family_members',
                          ['locked_member_id'], ['id'])
    op.create_foreign_key('fk_devices_home_user', 'devices', 'users',
                          ['home_user_id'], ['id'])
    op.create_index('idx_devices_home', 'devices', ['home_user_id'])


def downgrade() -> None:
    op.drop_index('idx_devices_home', table_name='devices')
    op.drop_constraint('fk_devices_home_user', 'devices', type_='foreignkey')
    op.drop_constraint('fk_devices_locked_member', 'devices', type_='foreignkey')
    op.drop_constraint('fk_devices_current_member', 'devices', type_='foreignkey')
    for col in ['home_user_id', 'firmware_version', 'locked_member_id', 'current_member_id', 'name', 'device_type']:
        op.drop_column('devices', col)
