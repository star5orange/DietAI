"""中国食物成分表并入 food_database：新增 alias_name + extra_nutrients 两列，清理独立 cn 表"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'm6_04_food_composition'
down_revision: Union[str, Sequence[str], None] = 'm6_03_devices_family'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """加列 + 清理曾经的独立表（若存在）"""
    op.add_column('food_database', sa.Column('alias_name', sa.String(200), comment='别名/俗名'))
    op.add_column('food_database', sa.Column('extra_nutrients', sa.JSON(), comment='微量营养素打包（维生素/矿物质/脂肪酸等）'))
    op.create_index('idx_food_database_alias', 'food_database', ['alias_name'])

    op.execute('DROP TABLE IF EXISTS cn_food_composition')
    op.execute('DROP TABLE IF EXISTS cn_food_categories')


def downgrade() -> None:
    op.drop_index('idx_food_database_alias', table_name='food_database')
    op.drop_column('food_database', 'extra_nutrients')
    op.drop_column('food_database', 'alias_name')
