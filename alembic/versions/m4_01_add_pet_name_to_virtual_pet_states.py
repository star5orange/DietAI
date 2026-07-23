"""add pet_name to virtual_pet_states

Revision ID: m4_01_pet_name
Revises: m3_03
Create Date: 2026-07-14 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'm4_01_pet_name'
down_revision = 'm3_03'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 添加 pet_name 字段
    op.add_column('virtual_pet_states', 
        sa.Column('pet_name', sa.String(50), nullable=True, comment='用户自定义的桌宠名称')
    )
    
    # 为现有记录设置默认值
    op.execute("""
        UPDATE virtual_pet_states 
        SET pet_name = '桌宠一'
        WHERE pet_name IS NULL AND current_skin = 'default'
    """)
    
    op.execute("""
        UPDATE virtual_pet_states 
        SET pet_name = '桌宠二'
        WHERE pet_name IS NULL AND current_skin = 'christine'
    """)
    
    # 设置默认值
    op.alter_column('virtual_pet_states', 'pet_name', 
        existing_type=sa.String(50),
        nullable=False,
        server_default='桌宠一'
    )


def downgrade() -> None:
    # 删除 pet_name 字段
    op.drop_column('virtual_pet_states', 'pet_name')