"""B4-3: 添加高频查询性能索引

Revision ID: b4c3
Revises: e6a322b5c6ba
Create Date: 2026-06-05

为 4 张表添加复合索引，优化以下高频查询：

  exercise_records       → (user_id, record_date)              — 按用户+日期查询/统计运动
  water_intake_records   → (user_id, record_time)              — 按用户+时间查询喝水
                          → (user_id, DATE(record_time))        — 按用户+日期聚合喝水
  reminders              → (user_id, reminder_type, is_enabled, remind_time)
                                                                — 提醒检查任务：查用户启用的某类提醒
  notification_responses → (user_id, reminder_id)               — 提醒响应统计
                          → (user_id, responded_at)             — 响应时间线查询

验证方法（连接数据库执行）：
  EXPLAIN ANALYZE SELECT * FROM exercise_records WHERE user_id=1 AND record_date='2026-06-05';
  EXPLAIN ANALYZE SELECT * FROM water_intake_records WHERE user_id=1 AND DATE(record_time)='2026-06-05';
  EXPLAIN ANALYZE SELECT * FROM reminders WHERE user_id=1 AND reminder_type='water' AND is_enabled=true
                         AND remind_time='10:00:00';
  EXPLAIN ANALYZE SELECT * FROM notification_responses WHERE user_id=1 ORDER BY responded_at DESC LIMIT 50;

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'b4c3'
down_revision: Union[str, Sequence[str], None] = 'e6a322b5c6ba'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """创建性能优化索引"""
    # 1. exercise_records: 按用户+日期查询运动记录和汇总
    op.create_index(
        'idx_exercise_user_date',
        'exercise_records',
        ['user_id', sa.text('record_date DESC')],
        if_not_exists=True,
    )

    # 2. water_intake_records: 按用户+时间查询喝水记录
    op.create_index(
        'idx_water_user_time',
        'water_intake_records',
        ['user_id', sa.text('record_time DESC')],
        if_not_exists=True,
    )
    # 按用户+日期聚合（用于 SUM 计算日总量）
    # PostgreSQL 表达式索引
    op.execute("""
        CREATE INDEX IF NOT EXISTS idx_water_user_date
        ON water_intake_records (user_id, (record_time::date) DESC)
    """)

    # 3. reminders: 提醒检查任务的核心查询
    # WHERE user_id=? AND reminder_type=? AND is_enabled=true AND remind_time=?
    op.create_index(
        'idx_reminders_user_type_enabled',
        'reminders',
        ['user_id', 'reminder_type', 'is_enabled', 'remind_time'],
        if_not_exists=True,
    )

    # 4a. notification_responses: 按用户+提醒ID统计响应
    op.create_index(
        'idx_notif_resp_user_reminder',
        'notification_responses',
        ['user_id', 'reminder_id'],
        if_not_exists=True,
    )
    # 4b. notification_responses: 按用户+响应时间查询（用于 streak 计算）
    op.create_index(
        'idx_notif_resp_user_time',
        'notification_responses',
        ['user_id', sa.text('responded_at DESC')],
        if_not_exists=True,
    )


def downgrade() -> None:
    """移除性能优化索引"""
    op.drop_index('idx_notif_resp_user_time', table_name='notification_responses', if_exists=True)
    op.drop_index('idx_notif_resp_user_reminder', table_name='notification_responses', if_exists=True)
    op.drop_index('idx_reminders_user_type_enabled', table_name='reminders', if_exists=True)
    op.execute('DROP INDEX IF EXISTS idx_water_user_date')
    op.drop_index('idx_water_user_time', table_name='water_intake_records', if_exists=True)
    op.drop_index('idx_exercise_user_date', table_name='exercise_records', if_exists=True)
