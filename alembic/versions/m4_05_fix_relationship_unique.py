"""fix: user_relationships UNIQUE constraint + exam_reports.photo_urls

Revision ID: m4_05_fix_relationship_unique
Revises: m4_04_merge, m4_03_followup_date
Create Date: 2026-08-13 11:00:00.000000

改动:
1. user_relationships (user_id, related_user_id) 唯一索引改为 UNIQUE
   （此前迁移创建的是普通索引，模型层 unique=True 与数据库层不一致）
2. exam_reports 新增 photo_urls JSONB 列，持久化多页体检报告的每页照片 URL
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB


# revision identifiers, used by Alembic.
revision = 'm4_05_fix_relationship_unique'
down_revision = ('m4_04_merge', 'm4_03_followup_date')
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. user_relationships 唯一约束（先删普通索引，再建 UNIQUE 索引）
    op.execute("DROP INDEX IF EXISTS idx_user_relationship_unique")
    op.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_user_relationship_unique
        ON user_relationships (user_id, related_user_id)
    """)

    # 2. exam_reports 多页照片 URL 列表
    op.execute("ALTER TABLE exam_reports ADD COLUMN IF NOT EXISTS photo_urls JSONB")
    op.execute("""
        UPDATE exam_reports SET photo_urls = jsonb_build_array(photo_url)
        WHERE photo_urls IS NULL AND photo_url IS NOT NULL
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_user_relationship_unique")
    op.execute("""
        CREATE INDEX IF NOT EXISTS idx_user_relationship_unique
        ON user_relationships (user_id, related_user_id)
    """)
    op.execute("ALTER TABLE exam_reports DROP COLUMN IF EXISTS photo_urls")
