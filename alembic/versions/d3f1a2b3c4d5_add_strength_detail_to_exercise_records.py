"""add strength_detail to exercise_records

Revision ID: d3f1a2b3c4d5
Revises: cc7c07bf9f95
Create Date: 2026-06-12
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSON

revision = 'd3f1a2b3c4d5'
down_revision = 'cc7c07bf9f95'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('exercise_records', sa.Column('strength_detail', JSON, nullable=True))


def downgrade() -> None:
    op.drop_column('exercise_records', 'strength_detail')
