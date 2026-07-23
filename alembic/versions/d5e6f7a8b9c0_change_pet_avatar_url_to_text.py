"""change pet_profiles.avatar_url from VARCHAR(2000) to TEXT

Revision ID: d5e6f7a8b9c0
Revises: c4f8a2b3d5e7
Create Date: 2026-07-22

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd5e6f7a8b9c0'
down_revision = 'c4f8a2b3d5e7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 将 pet_profiles.avatar_url 从 VARCHAR(2000) 改为 TEXT，支持超长签名 URL
    op.alter_column('pet_profiles', 'avatar_url',
                    existing_type=sa.String(2000),
                    type_=sa.Text(),
                    existing_nullable=True)


def downgrade() -> None:
    # 回滚：TEXT 改回 VARCHAR(2000)
    op.alter_column('pet_profiles', 'avatar_url',
                    existing_type=sa.Text(),
                    type_=sa.String(2000),
                    existing_nullable=True)
