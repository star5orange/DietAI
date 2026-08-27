"""add followup_date to exam_reports

Revision ID: m4_03_followup_date
Revises: b7e9c1f0a4d2
Create Date: 2026-08-10 10:00:00.000000

新增字段:
- exam_reports.followup_date: 建议复查日期（AI解析复查周期 / 人工设置 / 指标修正联动）
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'm4_03_followup_date'
down_revision = 'm4_04_merge'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 检查列是否存在（表可能已通过 create_all() 创建且含该列），不存在时再添加
    conn = op.get_bind()
    result = conn.execute(sa.text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'exam_reports' AND column_name = 'followup_date'
    """))
    if not result.fetchone():
        op.add_column(
            'exam_reports',
            sa.Column('followup_date', sa.Date(), nullable=True, comment='建议复查日期（AI解析复查周期）'),
        )


def downgrade() -> None:
    op.drop_column('exam_reports', 'followup_date')
