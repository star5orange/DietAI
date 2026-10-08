"""add rehab advice cache columns to diseases (健康页康复建议)

Revision ID: m5_02_rehab_advice
Revises: m5_01_exam_ai_flag
Create Date: 2026-10-07 12:00:00.000000

新增字段:
- diseases.rehab_advice: AI 生成的康复建议（JSON 字符串），按疾病缓存
- diseases.rehab_advice_sig: 生成时的输入签名（疾病名/严重程度/诊断日期/备注/
  过敏原/并发疾病），签名变化才重建；刻意不含病程天数，避免每日重建
- diseases.rehab_advice_generated_at: 生成时间（仅展示用，不参与失效判断）

说明:
- main.py 的 create_tables() 只建新表，不会给已存在的 diseases 表加列，
  所以本迁移必须执行。
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'm5_02_rehab_advice'
down_revision = 'm5_01_exam_ai_flag'
branch_labels = None
depends_on = None

_NEW_COLUMNS = (
    ('rehab_advice', sa.Text()),
    ('rehab_advice_sig', sa.String(length=64)),
    ('rehab_advice_generated_at', sa.DateTime()),
)


def upgrade() -> None:
    conn = op.get_bind()
    for column_name, column_type in _NEW_COLUMNS:
        # 检查列是否存在（表可能已通过 create_all() 创建且含该列），不存在时再添加
        result = conn.execute(
            sa.text(
                """
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'diseases' AND column_name = :column_name
                """
            ),
            {"column_name": column_name},
        )
        if not result.fetchone():
            op.add_column(
                'diseases',
                sa.Column(column_name, column_type, nullable=True),
            )


def downgrade() -> None:
    for column_name, _ in _NEW_COLUMNS:
        op.drop_column('diseases', column_name)