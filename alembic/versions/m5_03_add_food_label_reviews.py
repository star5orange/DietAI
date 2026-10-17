"""add food_label_reviews table (购买前的成分表评价与对比留存)

Revision ID: m5_03_label_review
Revises: m5_02_rehab_advice
Create Date: 2026-10-09 22:00:00.000000

新增表:
- food_label_reviews: 用户在对话里发送包装食品成分表照片后，OCR 得到的结构化
  每 100g 营养数值 + AI 给出的评价原文与购买结论。同一 session_id 串起一次采购
  对比（多商品并列），故不另建对比分组表。

说明:
- 表结构若已由 main.py 的 create_tables()（create_all）建出，则本迁移跳过，
  老库则在此显式建表，保证两种库状态一致。
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'm5_03_label_review'
down_revision = 'm5_02_rehab_advice'
branch_labels = None
depends_on = None

_TABLE = 'food_label_reviews'


def upgrade() -> None:
    conn = op.get_bind()
    if sa.inspect(conn).has_table(_TABLE):
        return

    op.create_table(
        _TABLE,
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=True),
        sa.Column('brand', sa.String(length=128), nullable=True),
        sa.Column('food_name', sa.String(length=128), nullable=True),
        sa.Column('serving_size_g', sa.Float(), nullable=True),
        sa.Column('calories_per_100g', sa.Float(), nullable=True),
        sa.Column('protein_per_100g', sa.Float(), nullable=True),
        sa.Column('fat_per_100g', sa.Float(), nullable=True),
        sa.Column('carbs_per_100g', sa.Float(), nullable=True),
        sa.Column('sugar_per_100g', sa.Float(), nullable=True),
        sa.Column('fiber_per_100g', sa.Float(), nullable=True),
        sa.Column('sodium_per_100g', sa.Float(), nullable=True),
        sa.Column('is_packaged_food', sa.Boolean(), nullable=False,
                  server_default=sa.text('true')),
        sa.Column('raw_text', sa.Text(), nullable=True),
        sa.Column('verdict', sa.String(length=16), nullable=True),
        sa.Column('answer_text', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(
            ['session_id'], ['conversation_sessions.id'], ondelete='SET NULL'
        ),
    )
    op.create_index('idx_food_label_review_user', _TABLE, ['user_id'])
    op.create_index('idx_food_label_review_session', _TABLE, ['session_id'])


def downgrade() -> None:
    op.drop_table(_TABLE)