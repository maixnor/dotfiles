"""Add comparison card columns

Revision ID: 03_add_comparison_cols
Revises: 02fe75646f72
Create Date: 2026-01-18 16:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '03_add_comparison_cols'
down_revision: Union[str, Sequence[str], None] = '02fe75646f72'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column('content_items', sa.Column('left_column_text', sa.Text(), nullable=True))
    op.add_column('content_items', sa.Column('right_column_text', sa.Text(), nullable=True))
    op.add_column('content_items', sa.Column('caption', sa.Text(), nullable=True))

def downgrade() -> None:
    op.drop_column('content_items', 'caption')
    op.drop_column('content_items', 'right_column_text')
    op.drop_column('content_items', 'left_column_text')
