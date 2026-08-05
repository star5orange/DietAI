"""M4: add social, exam, message, proxy, device_token tables and food_records.recorded_by_user_id

Revision ID: m4_02_social_exam
Revises: m4_01_pet_name
Create Date: 2026-08-04 10:00:00.000000

新增表:
- user_relationships: 用户关系（家人/好友）
- data_permissions: 数据权限（家人间可见字段设置）
- messages: 消息表（一对一聊天、戳一戳、食物分享）
- proxy_records: 代记录日志
- exam_reports: 体检报告
- exam_metrics: 体检指标明细
- device_tokens: FCM 设备推送 token

新增字段:
- food_records.recorded_by_user_id: 代记录人 ID
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision = 'm4_02_social_exam'
down_revision = 'm4_01_pet_name'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 使用 IF NOT EXISTS 保护，因为表可能已通过 create_all() 创建

    # ================================================================
    # 1. user_relationships — 用户关系表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS user_relationships (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            related_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            relationship_type VARCHAR(10) NOT NULL,
            status VARCHAR(10) NOT NULL DEFAULT 'pending',
            created_at TIMESTAMP NOT NULL DEFAULT now(),
            updated_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_user_relationship_unique ON user_relationships (user_id, related_user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_user_relationship_user ON user_relationships (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_user_relationship_related ON user_relationships (related_user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_user_relationship_type ON user_relationships (relationship_type)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_user_relationship_status ON user_relationships (status)")

    # ================================================================
    # 2. data_permissions — 数据权限表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS data_permissions (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            target_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            visible_fields JSONB NOT NULL DEFAULT '[]'::jsonb,
            created_at TIMESTAMP NOT NULL DEFAULT now(),
            updated_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_data_permission_unique ON data_permissions (user_id, target_user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_data_permission_user ON data_permissions (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_data_permission_target ON data_permissions (target_user_id)")

    # ================================================================
    # 3. messages — 消息表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            receiver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
            content TEXT NOT NULL,
            message_type VARCHAR(20) NOT NULL DEFAULT 'text',
            extra_data JSONB,
            read_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_message_sender ON messages (sender_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_message_receiver ON messages (receiver_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_message_created ON messages (created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_message_unread ON messages (receiver_id, read_at)")

    # ================================================================
    # 4. proxy_records — 代记录日志表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS proxy_records (
            id SERIAL PRIMARY KEY,
            recorded_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            target_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            record_type VARCHAR(20) NOT NULL,
            record_id INTEGER NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_proxy_record_by_user ON proxy_records (recorded_by_user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_proxy_record_target ON proxy_records (target_user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_proxy_record_type ON proxy_records (record_type)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_proxy_record_created ON proxy_records (created_at)")

    # ================================================================
    # 5. exam_reports — 体检报告表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS exam_reports (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            exam_date DATE NOT NULL,
            report_date DATE,
            hospital_name VARCHAR(200),
            report_type VARCHAR(50),
            photo_url TEXT,
            abnormal_count INTEGER NOT NULL DEFAULT 0,
            summary TEXT,
            doctor_advice TEXT,
            compared_to_last JSONB,
            created_at TIMESTAMP NOT NULL DEFAULT now(),
            created_by INTEGER REFERENCES users(id) ON DELETE SET NULL
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_exam_report_user ON exam_reports (user_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_exam_report_date ON exam_reports (exam_date)")

    # ================================================================
    # 6. exam_metrics — 体检指标明细表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS exam_metrics (
            id SERIAL PRIMARY KEY,
            report_id INTEGER NOT NULL REFERENCES exam_reports(id) ON DELETE CASCADE,
            category VARCHAR(50),
            metric_name VARCHAR(100) NOT NULL,
            metric_value NUMERIC(10,2),
            unit VARCHAR(20),
            reference_range VARCHAR(50),
            reference_min NUMERIC(10,2),
            reference_max NUMERIC(10,2),
            status VARCHAR(10),
            is_abnormal BOOLEAN NOT NULL DEFAULT FALSE,
            ai_confidence NUMERIC(3,2),
            raw_text TEXT
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_exam_metric_report ON exam_metrics (report_id)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_exam_metric_category ON exam_metrics (category)")
    op.execute("CREATE INDEX IF NOT EXISTS idx_exam_metric_abnormal ON exam_metrics (is_abnormal)")

    # ================================================================
    # 7. device_tokens — FCM 设备推送 token 表
    # ================================================================
    op.execute("""
        CREATE TABLE IF NOT EXISTS device_tokens (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token VARCHAR(500) NOT NULL UNIQUE,
            platform VARCHAR(10),
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMP NOT NULL DEFAULT now(),
            updated_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_device_tokens_user_active ON device_tokens (user_id, is_active)")

    # ================================================================
    # 8. food_records 新增 recorded_by_user_id 字段（代记录人）
    # ================================================================
    # 检查字段是否存在
    conn = op.get_bind()
    result = conn.execute(sa.text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'food_records' AND column_name = 'recorded_by_user_id'
    """))
    if not result.fetchone():
        op.add_column(
            'food_records',
            sa.Column(
                'recorded_by_user_id', sa.Integer(),
                sa.ForeignKey('users.id', ondelete='SET NULL'),
                nullable=True,
                comment='代记录人ID（NULL=本人记录，有值=代记录人ID）',
            ),
        )


def downgrade() -> None:
    # 8. 移除 food_records.recorded_by_user_id
    op.drop_column('food_records', 'recorded_by_user_id')

    # 7. device_tokens
    op.drop_index('idx_device_tokens_user_active', table_name='device_tokens')
    op.drop_table('device_tokens')

    # 6. exam_metrics
    op.drop_index('idx_exam_metric_abnormal', table_name='exam_metrics')
    op.drop_index('idx_exam_metric_category', table_name='exam_metrics')
    op.drop_index('idx_exam_metric_report', table_name='exam_metrics')
    op.drop_table('exam_metrics')

    # 5. exam_reports
    op.drop_index('idx_exam_report_date', table_name='exam_reports')
    op.drop_index('idx_exam_report_user', table_name='exam_reports')
    op.drop_table('exam_reports')

    # 4. proxy_records
    op.drop_index('idx_proxy_record_created', table_name='proxy_records')
    op.drop_index('idx_proxy_record_type', table_name='proxy_records')
    op.drop_index('idx_proxy_record_target', table_name='proxy_records')
    op.drop_index('idx_proxy_record_by_user', table_name='proxy_records')
    op.drop_table('proxy_records')

    # 3. messages
    op.drop_index('idx_message_unread', table_name='messages')
    op.drop_index('idx_message_created', table_name='messages')
    op.drop_index('idx_message_receiver', table_name='messages')
    op.drop_index('idx_message_sender', table_name='messages')
    op.drop_table('messages')

    # 2. data_permissions
    op.drop_index('idx_data_permission_target', table_name='data_permissions')
    op.drop_index('idx_data_permission_user', table_name='data_permissions')
    op.drop_index('idx_data_permission_unique', table_name='data_permissions')
    op.drop_table('data_permissions')

    # 1. user_relationships
    op.drop_index('idx_user_relationship_status', table_name='user_relationships')
    op.drop_index('idx_user_relationship_type', table_name='user_relationships')
    op.drop_index('idx_user_relationship_related', table_name='user_relationships')
    op.drop_index('idx_user_relationship_user', table_name='user_relationships')
    op.drop_index('idx_user_relationship_unique', table_name='user_relationships')
    op.drop_table('user_relationships')
