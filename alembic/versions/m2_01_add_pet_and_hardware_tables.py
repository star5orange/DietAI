"""m2_01 add pet and hardware tables

Revision ID: m2_01_pet_hw
Revises: f1e2a3b4c5d6
Create Date: 2026-07-13

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'm2_01_pet_hw'
down_revision: Union[str, Sequence[str], None] = 'f1e2a3b4c5d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # virtual_pet_state
    op.create_table('virtual_pet_states',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('pet_type', sa.String(length=20), nullable=True, server_default='cat'),
        sa.Column('pet_name', sa.String(length=50), nullable=True, server_default='小橘'),
        sa.Column('level', sa.Integer(), nullable=True, server_default='1'),
        sa.Column('exp', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('mood', sa.String(length=20), nullable=True, server_default='calm'),
        sa.Column('current_skin', sa.String(length=50), nullable=True, server_default='default'),
        sa.Column('streak_days', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('last_interact_at', sa.DateTime(), nullable=True),
        sa.Column('version', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('is_visible', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('custom_messages', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('state_updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_virtual_pet_states_id'), 'virtual_pet_states', ['id'], unique=False)
    op.create_index('idx_pet_state_user', 'virtual_pet_states', ['user_id'], unique=False)
    op.create_index('idx_pet_state_updated', 'virtual_pet_states', ['state_updated_at'], unique=False)

    # pet_unlocks
    op.create_table('pet_unlocks',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('unlock_type', sa.String(length=20), nullable=False),
        sa.Column('unlock_key', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('required_level', sa.Integer(), nullable=True),
        sa.Column('required_streak', sa.Integer(), nullable=True),
        sa.Column('is_unlocked', sa.Boolean(), nullable=True, server_default='false'),
        sa.Column('unlocked_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'unlock_type', 'unlock_key', name='uq_pet_unlock_user_type_key')
    )
    op.create_index(op.f('ix_pet_unlocks_id'), 'pet_unlocks', ['id'], unique=False)
    op.create_index('idx_pet_unlock_user_type', 'pet_unlocks', ['user_id', 'unlock_type'], unique=False)

    # hardware_quick_buttons
    op.create_table('hardware_quick_buttons',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('button_index', sa.Integer(), nullable=False),
        sa.Column('button_type', sa.String(length=20), nullable=False),
        sa.Column('label', sa.String(length=50), nullable=False),
        sa.Column('amount_ml', sa.Integer(), nullable=True),
        sa.Column('meal_type', sa.String(length=20), nullable=True),
        sa.Column('food_name', sa.String(length=100), nullable=True),
        sa.Column('calories', sa.Integer(), nullable=True),
        sa.Column('protein', sa.Numeric(precision=6, scale=2), nullable=True),
        sa.Column('amount', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'button_index', name='uq_hw_button_user_idx')
    )
    op.create_index(op.f('ix_hardware_quick_buttons_id'), 'hardware_quick_buttons', ['id'], unique=False)

    # offline_sync_logs
    op.create_table('offline_sync_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('synced_count', sa.Integer(), nullable=False),
        sa.Column('failed_count', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('sync_details', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_offline_sync_logs_id'), 'offline_sync_logs', ['id'], unique=False)
    op.create_index('idx_sync_log_user', 'offline_sync_logs', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index('idx_sync_log_user', table_name='offline_sync_logs')
    op.drop_index(op.f('ix_offline_sync_logs_id'), table_name='offline_sync_logs')
    op.drop_table('offline_sync_logs')

    op.drop_index(op.f('ix_hardware_quick_buttons_id'), table_name='hardware_quick_buttons')
    op.drop_table('hardware_quick_buttons')

    op.drop_index('idx_pet_unlock_user_type', table_name='pet_unlocks')
    op.drop_index(op.f('ix_pet_unlocks_id'), table_name='pet_unlocks')
    op.drop_table('pet_unlocks')

    op.drop_index('idx_pet_state_updated', table_name='virtual_pet_states')
    op.drop_index('idx_pet_state_user', table_name='virtual_pet_states')
    op.drop_index(op.f('ix_virtual_pet_states_id'), table_name='virtual_pet_states')
    op.drop_table('virtual_pet_states')
