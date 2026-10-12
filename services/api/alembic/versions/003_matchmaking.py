"""matchmaking

Revision ID: 003_matchmaking
Revises: 002_rooms_and_matches
Create Date: 2026-10-01 16:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '003_matchmaking'
down_revision: Union[str, None] = '002_rooms_and_matches'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.create_table(
        'matchmaking_tickets',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('mode', sa.String(length=20), nullable=False),
        sa.Column('player_count', sa.Integer(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('region', sa.String(length=10), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('matched_match_id', sa.String(length=36), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_matchmaking_tickets_user_id'), 'matchmaking_tickets', ['user_id'], unique=False)
    op.create_index(op.f('ix_matchmaking_tickets_status'), 'matchmaking_tickets', ['status'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_matchmaking_tickets_status'), table_name='matchmaking_tickets')
    op.drop_index(op.f('ix_matchmaking_tickets_user_id'), table_name='matchmaking_tickets')
    op.drop_table('matchmaking_tickets')
