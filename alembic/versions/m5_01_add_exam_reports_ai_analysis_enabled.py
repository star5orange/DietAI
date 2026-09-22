"""add ai_analysis_enabled to exam_reports (体检隐私：默认关闭 AI 分析)

Revision ID: m5_01_exam_ai_flag
Revises: e005e9a19ef6
Create Date: 2026-09-19 10:00:00.000000

新增字段:
- exam_reports.ai_analysis_enabled: 是否允许 AI 分析该份体检报告
  （默认关闭，仅本地私有存储；关闭时照片/文本不送往 AI）

历史数据处理:
- 开关上线前录入的报告此前已经由 AI 解析（且其指标会被 AI 顾问引用），
  统一置为 true 以保持原有行为；新报告由接口传入，默认 false。
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'm5_01_exam_ai_flag'
down_revision = 'e005e9a19ef6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 检查列是否存在（表可能已通过 create_all() 创建且含该列），不存在时再添加
    conn = op.get_bind()
    result = conn.execute(sa.text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'exam_reports' AND column_name = 'ai_analysis_enabled'
    """))
    if not result.fetchone():
        # server_default=false：已有行填充为 false，不会违反 nullable=False
        op.add_column(
            'exam_reports',
            sa.Column(
                'ai_analysis_enabled',
                sa.Boolean(),
                nullable=False,
                server_default=sa.text('false'),
                comment='是否允许 AI 分析该份体检报告（默认关闭，仅本地私有存储）',
            ),
        )
        # 历史报告（隐私开关上线前录入，已被 AI 解析）保持原有 AI 可用状态
        conn.execute(sa.text("UPDATE exam_reports SET ai_analysis_enabled = true"))


def downgrade() -> None:
    op.drop_column('exam_reports', 'ai_analysis_enabled')
