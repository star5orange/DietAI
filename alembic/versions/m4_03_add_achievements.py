"""M4: add health_achievements table (健康家庭成就)

Revision ID: m4_03_achievements
Revises: 439ff5e39b69
Create Date: 2026-08-10 12:00:00.000000

新增表:
- health_achievements: 健康成就表（家庭健康日等）
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision = 'm4_03_achievements'
down_revision = '439ff5e39b69'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 使用 IF NOT EXISTS 保护，因为表可能已通过 create_all() 创建
    op.execute("""
        CREATE TABLE IF NOT EXISTS health_achievements (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            achievement_type VARCHAR(50) NOT NULL,
            title VARCHAR(100) NOT NULL,
            metadata JSONB,
            unlocked_at TIMESTAMP NOT NULL DEFAULT now()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS idx_health_achievement_user_type ON health_achievements (user_id, achievement_type)")


def downgrade() -> None:
    op.drop_index('idx_health_achievement_user_type', table_name='health_achievements')
    op.drop_table('health_achievements')
