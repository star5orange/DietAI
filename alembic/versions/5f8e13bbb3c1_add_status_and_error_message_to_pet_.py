"""add_status_and_error_message_to_pet_avatars

Revision ID: 5f8e13bbb3c1
Revises: 7ef153f14795
Create Date: 2026-07-17

PetAvatar 表添加 status 和 error_message 字段，用于 AI 生成流程追踪。
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '5f8e13bbb3c1'
down_revision: Union[str, Sequence[str], None] = '7ef153f14795'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('pet_avatars',
        sa.Column('status', sa.String(20), nullable=False, server_default='none',
                  comment='none/processing/done/failed'))
    op.add_column('pet_avatars',
        sa.Column('error_message', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('pet_avatars', 'error_message')
    op.drop_column('pet_avatars', 'status')
