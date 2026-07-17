"""Milestone3: 真实宠物健康管理 — 全部数据库变更

Revision ID: 7ef153f14795
Revises: 0da986e876fe
Create Date: 2026-07-17

包含:
- P0 新表: pet_profiles, pet_weight_records, pet_vaccine_records,
           pet_feeding_records, pet_water_records, pet_daily_summaries, pet_avatars
- 硬件表: hardware_quick_buttons, offline_sync_log
- P1 新表: pet_deworming_records, pet_food_database
- 修改表: virtual_pet_states (pet_name, custom_messages),
           fasting_plans (fasting_days), fasting_checkins (is_fasting_day)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '7ef153f14795'
down_revision: Union[str, Sequence[str], None] = '0da986e876fe'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # =============================================
    # 1. 修改现有表
    # =============================================
    op.add_column('virtual_pet_states',
        sa.Column('pet_name', sa.String(50), nullable=True, comment='用户自定义的桌宠名称'))
    op.add_column('virtual_pet_states',
        sa.Column('custom_messages', postgresql.JSONB(), nullable=True,
                  server_default=sa.text("'{}'::jsonb"), comment='用户自定义宠物提示语'))

    op.add_column('fasting_plans',
        sa.Column('fasting_days', postgresql.JSONB(), nullable=True,
                  comment='断食日列表，如[0,2]表示周一、周三'))

    op.add_column('fasting_checkins',
        sa.Column('is_fasting_day', sa.Boolean(), nullable=False,
                  server_default='true', comment='当天是否是断食日'))
    op.create_index('idx_fasting_checkin_fasting_day', 'fasting_checkins',
                    ['plan_id', 'is_fasting_day'])

    # =============================================
    # 2. 硬件表
    # =============================================
    op.create_table('hardware_quick_buttons',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=True),
        sa.Column('button_index', sa.Integer(), nullable=False),
        sa.Column('button_type', sa.String(20), nullable=False),
        sa.Column('label', sa.String(100), nullable=False),
        sa.Column('amount_ml', sa.Integer(), nullable=True),
        sa.Column('meal_type', sa.String(20), nullable=True),
        sa.Column('food_name', sa.String(100), nullable=True),
        sa.Column('calories', sa.Numeric(8, 2), nullable=True),
        sa.Column('protein', sa.Numeric(6, 2), nullable=True),
        sa.Column('amount', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'button_index', name='uq_hw_button_user_idx'),
    )
    op.create_index('idx_hw_buttons_user', 'hardware_quick_buttons', ['user_id', 'button_index'], unique=True)

    op.create_table('offline_sync_log',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('target_type', sa.String(20), nullable=False, server_default='human'),
        sa.Column('sync_type', sa.String(20), nullable=False),
        sa.Column('payload', postgresql.JSONB(), nullable=False),
        sa.Column('synced_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_offline_sync_user', 'offline_sync_log', ['user_id', 'synced_at'])

    # =============================================
    # 3. P0 真实宠物表
    # =============================================
    op.create_table('pet_profiles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(50), nullable=False),
        sa.Column('species', sa.String(20), nullable=False, comment='cat/dog/other'),
        sa.Column('breed', sa.String(100), nullable=True),
        sa.Column('gender', sa.String(10), nullable=True, comment='male/female'),
        sa.Column('birth_date', sa.Date(), nullable=True),
        sa.Column('is_neutered', sa.Boolean(), server_default='false'),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_profiles_user', 'pet_profiles', ['user_id', 'is_active'])

    op.create_table('pet_weight_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('weight', sa.Numeric(5, 2), nullable=False),
        sa.Column('measured_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_weight_pet_time', 'pet_weight_records', ['pet_id', 'measured_at'])

    op.create_table('pet_vaccine_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('vaccine_name', sa.String(100), nullable=False),
        sa.Column('vaccinated_at', sa.Date(), nullable=False),
        sa.Column('expiry_date', sa.Date(), nullable=True),
        sa.Column('next_vaccination_date', sa.Date(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_vaccine_next_date', 'pet_vaccine_records', ['next_vaccination_date'])

    op.create_table('pet_feeding_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('food_name', sa.String(200), nullable=True),
        sa.Column('amount_grams', sa.Numeric(8, 2), nullable=True),
        sa.Column('calories', sa.Numeric(8, 2), nullable=True),
        sa.Column('protein', sa.Numeric(6, 2), nullable=True),
        sa.Column('fat', sa.Numeric(6, 2), nullable=True),
        sa.Column('carbs', sa.Numeric(6, 2), nullable=True),
        sa.Column('record_time', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('from_source', sa.String(20), server_default='manual', comment='hardware/manual'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_feeding_pet_time', 'pet_feeding_records', ['pet_id', 'record_time'])

    op.create_table('pet_water_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('amount_ml', sa.Integer(), nullable=False),
        sa.Column('record_time', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('from_source', sa.String(20), server_default='manual', comment='hardware/manual'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_water_pet_time', 'pet_water_records', ['pet_id', 'record_time'])

    op.create_table('pet_daily_summaries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('summary_date', sa.Date(), nullable=False),
        sa.Column('total_calories', sa.Numeric(8, 2), server_default='0'),
        sa.Column('total_protein', sa.Numeric(6, 2), server_default='0'),
        sa.Column('total_fat', sa.Numeric(6, 2), server_default='0'),
        sa.Column('total_carbs', sa.Numeric(6, 2), server_default='0'),
        sa.Column('total_water_ml', sa.Integer(), server_default='0'),
        sa.Column('meal_count', sa.Integer(), server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_daily_summary_date', 'pet_daily_summaries', ['pet_id', 'summary_date'], unique=True)

    op.create_table('pet_avatars',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('base_image_url', sa.String(500), nullable=True),
        sa.Column('emotion_happy_url', sa.String(500), nullable=True),
        sa.Column('emotion_normal_url', sa.String(500), nullable=True),
        sa.Column('emotion_hungry_url', sa.String(500), nullable=True),
        sa.Column('emotion_weak_url', sa.String(500), nullable=True),
        sa.Column('generation_seed', sa.Integer(), nullable=True),
        sa.Column('has_gif', sa.Boolean(), server_default='false'),
        sa.Column('gif_url', sa.String(500), nullable=True),
        sa.Column('prompt_used', sa.Text(), nullable=True),
        sa.Column('ai_model', sa.String(50), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('pet_id'),
    )

    # =============================================
    # 4. P1 表
    # =============================================
    op.create_table('pet_deworming_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('pet_id', sa.Integer(), nullable=False),
        sa.Column('deworming_type', sa.String(20), nullable=False, comment='internal/external'),
        sa.Column('treated_at', sa.Date(), nullable=False),
        sa.Column('next_treatment_date', sa.Date(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['pet_id'], ['pet_profiles.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_deworming_next', 'pet_deworming_records', ['next_treatment_date'])

    op.create_table('pet_food_database',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('food_name', sa.String(200), nullable=False),
        sa.Column('brand', sa.String(100), nullable=True),
        sa.Column('category', sa.String(20), nullable=True, comment='dry_food/wet_food/snack'),
        sa.Column('suitable_species', sa.String(20), nullable=True, comment='cat/dog'),
        sa.Column('calories_per_100g', sa.Numeric(8, 2), nullable=True),
        sa.Column('protein_per_100g', sa.Numeric(6, 2), nullable=True),
        sa.Column('fat_per_100g', sa.Numeric(6, 2), nullable=True),
        sa.Column('carbs_per_100g', sa.Numeric(6, 2), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pet_food_db_species', 'pet_food_database', ['suitable_species', 'category'])

    # 5. hardware_quick_buttons FK to pet_profiles
    op.create_foreign_key('fk_hw_buttons_pet', 'hardware_quick_buttons', 'pet_profiles',
                          ['pet_id'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    op.drop_constraint('fk_hw_buttons_pet', 'hardware_quick_buttons', type_='foreignkey')

    op.drop_index('idx_pet_food_db_species', table_name='pet_food_database')
    op.drop_table('pet_food_database')
    op.drop_index('idx_pet_deworming_next', table_name='pet_deworming_records')
    op.drop_table('pet_deworming_records')

    op.drop_table('pet_avatars')
    op.drop_index('idx_pet_daily_summary_date', table_name='pet_daily_summaries')
    op.drop_table('pet_daily_summaries')
    op.drop_index('idx_pet_water_pet_time', table_name='pet_water_records')
    op.drop_table('pet_water_records')
    op.drop_index('idx_pet_feeding_pet_time', table_name='pet_feeding_records')
    op.drop_table('pet_feeding_records')
    op.drop_index('idx_pet_vaccine_next_date', table_name='pet_vaccine_records')
    op.drop_table('pet_vaccine_records')
    op.drop_index('idx_pet_weight_pet_time', table_name='pet_weight_records')
    op.drop_table('pet_weight_records')
    op.drop_index('idx_pet_profiles_user', table_name='pet_profiles')
    op.drop_table('pet_profiles')

    op.drop_index('idx_offline_sync_user', table_name='offline_sync_log')
    op.drop_table('offline_sync_log')
    op.drop_index('idx_hw_buttons_user', table_name='hardware_quick_buttons')
    op.drop_table('hardware_quick_buttons')

    op.drop_index('idx_fasting_checkin_fasting_day', table_name='fasting_checkins')
    op.drop_column('fasting_checkins', 'is_fasting_day')
    op.drop_column('fasting_plans', 'fasting_days')
    op.drop_column('virtual_pet_states', 'custom_messages')
    op.drop_column('virtual_pet_states', 'pet_name')
