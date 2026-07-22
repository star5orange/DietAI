"""expand pet avatar url fields from 500 to 2000

Revision ID: c4f8a2b3d5e7
Revises: 
Create Date: 2026-07-21

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c4f8a2b3d5e7'
down_revision = 'm4_01_pet_name'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 扩展 pet_avatars 表的 URL 字段长度从 500 到 2000
    op.alter_column('pet_avatars', 'base_image_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_happy_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_normal_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_hungry_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_weak_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'gif_url',
                    existing_type=sa.String(500),
                    type_=sa.String(2000),
                    existing_nullable=True)


def downgrade() -> None:
    # 回滚：将 URL 字段长度从 2000 改回 500
    op.alter_column('pet_avatars', 'base_image_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_happy_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_normal_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_hungry_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'emotion_weak_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
    op.alter_column('pet_avatars', 'gif_url',
                    existing_type=sa.String(2000),
                    type_=sa.String(500),
                    existing_nullable=True)
