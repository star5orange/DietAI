"""T16 健康档案挂成员：allergies / diseases / health_goals 加可空 member_id

NULL = 账号级（历史数据不回填，所有成员共享）；有值 = 归属具体成员。
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'm6_05_health_profile_member'
down_revision: Union[str, Sequence[str], None] = 'm6_04_food_composition'
branch_labels = None
depends_on = None

TABLES = ('allergies', 'diseases', 'health_goals')


def upgrade() -> None:
    for table in TABLES:
        op.add_column(table, sa.Column('member_id', sa.Integer(), nullable=True,
                                       comment='归属成员ID，空=账号级（所有成员可见）'))
        op.create_foreign_key(f'fk_{table}_member', table, 'family_members', ['member_id'], ['id'])
        op.create_index(f'idx_{table}_member', table, ['member_id'])


def downgrade() -> None:
    for table in TABLES:
        op.drop_index(f'idx_{table}_member', table_name=table)
        op.drop_constraint(f'fk_{table}_member', table, type_='foreignkey')
        op.drop_column(table, 'member_id')
