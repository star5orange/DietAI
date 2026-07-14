"""milestone2_new_tables_and_fields

Revision ID: 0da986e876fe
Revises: f1e2a3b4c5d6
Create Date: 2026-07-10 09:49:30.254892

Milestone 2 数据库变更:
- 新增表: virtual_pet_states, pet_unlockables, ai_advisor_settings, fasting_plans, fasting_checkins
- 修改表: food_records (cost, source_tag), user_profiles (monthly_food_budget), reminders (fasting_plan_id)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0da986e876fe'
down_revision: Union[str, Sequence[str], None] = 'f1e2a3b4c5d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Milestone 2 数据库升级"""

    # ========== 1. 修改 food_records 表 ==========
    op.add_column('food_records', sa.Column('cost', sa.Numeric(10, 2), nullable=True, comment='消费金额(元)'))
    op.add_column('food_records', sa.Column('source_tag', sa.String(20), nullable=True, comment='消费来源: canteen/delivery/home/restaurant/snack/other'))
    op.create_check_constraint('chk_cost_non_negative', 'food_records', 'cost >= 0')
    op.create_check_constraint('chk_cost_max', 'food_records', 'cost <= 99999.99')
    op.create_index('idx_food_records_source_tag', 'food_records', ['source_tag'])

    # ========== 2. 修改 user_profiles 表 ==========
    op.add_column('user_profiles', sa.Column('monthly_food_budget', sa.Numeric(10, 2), server_default='0', nullable=True, comment='月度饮食预算(元)'))
    op.create_check_constraint('chk_budget_non_negative', 'user_profiles', 'monthly_food_budget >= 0')

    # ========== 3. 创建 virtual_pet_states 表 ==========
    op.create_table(
        'virtual_pet_states',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('mood', sa.String(20), nullable=False, server_default='normal', comment='normal/happy/hungry/anxious/weak'),
        sa.Column('level', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('exp', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('current_skin', sa.String(50), nullable=False, server_default='default'),
        sa.Column('unlocked_skins', postgresql.JSONB(), nullable=False, server_default='[]'),
        sa.Column('habit_score', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('version', sa.Integer(), nullable=False, server_default='1', comment='状态版本号，硬件轮询用'),
        sa.Column('last_interact_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('last_feed_at', sa.DateTime(), nullable=True),
        sa.Column('last_play_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_state_user', 'virtual_pet_states', ['user_id'], unique=True)
    op.create_index('idx_pet_state_mood', 'virtual_pet_states', ['mood'])
    op.create_index('idx_pet_state_updated', 'virtual_pet_states', ['updated_at'])

    # ========== 4. 创建 pet_unlockables 表 ==========
    op.create_table(
        'pet_unlockables',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('unlock_type', sa.String(20), nullable=False, comment='skin/action/effect'),
        sa.Column('unlock_key', sa.String(50), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('required_level', sa.Integer(), nullable=True),
        sa.Column('required_streak', sa.Integer(), nullable=True),
        sa.Column('required_habit_score', sa.Integer(), nullable=True),
        sa.Column('asset_url', sa.String(255), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('unlock_key'),
    )

    # ========== 5. 创建 ai_advisor_settings 表 ==========
    op.create_table(
        'ai_advisor_settings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('advisor_style', sa.String(30), nullable=False, server_default='nutritionist',
                  comment='nutritionist/fitness_coach/tcm_healer/encouraging_friend'),
        sa.Column('focus_goal', sa.String(30), nullable=True,
                  comment='fat_loss/muscle_gain/sugar_control/wellness/balanced'),
        sa.Column('focus_nutrient', sa.String(30), nullable=True,
                  comment='calories/protein/carb/fat/micronutrient'),
        sa.Column('response_style', sa.String(30), nullable=False, server_default='detailed',
                  comment='concise/detailed/example_rich'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_advisor_settings_user', 'ai_advisor_settings', ['user_id'], unique=True)

    # ========== 6. 创建 fasting_plans 表 ==========
    op.create_table(
        'fasting_plans',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('plan_type', sa.String(20), nullable=False, comment='16_8/5_2/basic_fasting'),
        sa.Column('target_weight', sa.Numeric(5, 2), nullable=True),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=True),
        sa.Column('status', sa.String(20), nullable=False, server_default='active',
                  comment='active/paused/stopped/completed'),
        sa.Column('eating_window_start', sa.Time(), nullable=False, server_default='08:00'),
        sa.Column('eating_window_end', sa.Time(), nullable=False, server_default='16:00'),
        sa.Column('disclaimer_accepted', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('disclaimer_accepted_at', sa.DateTime(), nullable=True),
        sa.Column('health_assessment', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_fasting_plans_user', 'fasting_plans', ['user_id'])
    op.create_index('idx_fasting_plans_status', 'fasting_plans', ['status', 'user_id'])
    op.create_index('idx_fasting_plans_date', 'fasting_plans', ['start_date', 'end_date'])

    # ========== 7. 创建 fasting_checkins 表 ==========
    op.create_table(
        'fasting_checkins',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('plan_id', sa.Integer(), nullable=False),
        sa.Column('checkin_date', sa.Date(), nullable=False),
        sa.Column('weight', sa.Numeric(5, 2), nullable=True),
        sa.Column('feeling', sa.String(30), nullable=False, server_default='normal',
                  comment='good/normal/tired/uncomfortable'),
        sa.Column('completed', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('discomfort', postgresql.JSONB(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['plan_id'], ['fasting_plans.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_fasting_checkin_plan_date', 'fasting_checkins', ['plan_id', 'checkin_date'], unique=True)
    op.create_index('idx_fasting_checkin_discomfort', 'fasting_checkins', ['discomfort'])

    # ========== 8. 修改 reminders 表 ==========
    op.add_column('reminders', sa.Column('fasting_plan_id', sa.Integer(), nullable=True, comment='关联断食计划'))
    op.create_foreign_key(
        'fk_reminders_fasting_plan',
        'reminders', 'fasting_plans',
        ['fasting_plan_id'], ['id'],
        ondelete='SET NULL'
    )

    # ========== 9. 插入 pet_unlockables 种子数据 ==========
    op.execute("""
        INSERT INTO pet_unlockables (unlock_type, unlock_key, name, description, required_level, required_streak, required_habit_score)
        VALUES
        ('skin', 'default', '默认外观', '可爱的基础宠物形象', 1, NULL, NULL),
        ('skin', 'summer', '夏日清凉', '夏日海滩风格外观', 3, NULL, NULL),
        ('skin', 'sporty', '运动活力', '运动装备外观', 5, NULL, NULL),
        ('action', 'happy_spin', '开心转圈', '达标后的开心转圈动作', NULL, 3, NULL),
        ('action', 'feed_eat', '进食动画', '喂食时的进食动作', NULL, NULL, NULL),
        ('effect', 'gold_sparkle', '金色光效', '升级时的金色闪光效果', 10, NULL, NULL)
    """)


def downgrade() -> None:
    """Milestone 2 数据库回滚"""

    # 删除种子数据
    op.execute("DELETE FROM pet_unlockables WHERE unlock_key IN ('default', 'summer', 'sporty', 'happy_spin', 'feed_eat', 'gold_sparkle')")

    # 删除 reminders 外键和字段
    op.drop_constraint('fk_reminders_fasting_plan', 'reminders', type_='foreignkey')
    op.drop_column('reminders', 'fasting_plan_id')

    # 删除 fasting_checkins 表
    op.drop_index('idx_fasting_checkin_discomfort', table_name='fasting_checkins')
    op.drop_index('idx_fasting_checkin_plan_date', table_name='fasting_checkins')
    op.drop_table('fasting_checkins')

    # 删除 fasting_plans 表
    op.drop_index('idx_fasting_plans_date', table_name='fasting_plans')
    op.drop_index('idx_fasting_plans_status', table_name='fasting_plans')
    op.drop_index('idx_fasting_plans_user', table_name='fasting_plans')
    op.drop_table('fasting_plans')

    # 删除 ai_advisor_settings 表
    op.drop_index('idx_advisor_settings_user', table_name='ai_advisor_settings')
    op.drop_table('ai_advisor_settings')

    # 删除 pet_unlockables 表
    op.drop_table('pet_unlockables')

    # 删除 virtual_pet_states 表
    op.drop_index('idx_pet_state_updated', table_name='virtual_pet_states')
    op.drop_index('idx_pet_state_mood', table_name='virtual_pet_states')
    op.drop_index('idx_pet_state_user', table_name='virtual_pet_states')
    op.drop_table('virtual_pet_states')

    # 删除 user_profiles 约束和字段
    op.drop_constraint('chk_budget_non_negative', 'user_profiles', type_='check')
    op.drop_column('user_profiles', 'monthly_food_budget')

    # 删除 food_records 索引、约束和字段
    op.drop_index('idx_food_records_source_tag', table_name='food_records')
    op.drop_constraint('chk_cost_max', 'food_records', type_='check')
    op.drop_constraint('chk_cost_non_negative', 'food_records', type_='check')
    op.drop_column('food_records', 'source_tag')
    op.drop_column('food_records', 'cost')
