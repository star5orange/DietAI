"""m3_add_pet_advisor_style_fields

Revision ID: 836eda525ee8
Revises: 5f8e13bbb3c1
Create Date: 2026-07-22 17:07:05.002191

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '836eda525ee8'
down_revision: Union[str, Sequence[str], None] = '5f8e13bbb3c1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: 添加宠物 AI 顾问风格字段"""
    op.add_column('ai_advisor_settings',
        sa.Column('pet_advisor_style', sa.String(50), nullable=True,
                  default='vet_assistant',
                  comment='宠物顾问风格: vet_assistant/pet_nutritionist/pet_caregiver')
    )
    op.add_column('ai_advisor_settings',
        sa.Column('pet_focus_goal', sa.String(255), nullable=True,
                  comment='宠物关注目标: weight_management/nutrition_balance/daily_care/vaccine_deworming/food_transition')
    )


def downgrade() -> None:
    """Downgrade schema: 移除宠物 AI 顾问风格字段"""
    op.drop_column('ai_advisor_settings', 'pet_focus_goal')
    op.drop_column('ai_advisor_settings', 'pet_advisor_style')
