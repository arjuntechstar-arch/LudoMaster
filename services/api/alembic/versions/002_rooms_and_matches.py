"""rooms_and_matches

Revision ID: 002_rooms_and_matches
Revises: 001_initial_schema
Create Date: 2026-10-01 12:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '002_rooms_and_matches'
down_revision: Union[str, None] = '001_initial_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.create_table(
        'rooms',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('code', sa.String(length=10), nullable=False),
        sa.Column('host_user_id', sa.String(length=36), nullable=False),
        sa.Column('mode', sa.String(length=20), nullable=False),
        sa.Column('max_players', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('bet_coins', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['host_user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_rooms_code'), 'rooms', ['code'], unique=True)

    op.create_table(
        'room_members',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('room_id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('seat_index', sa.Integer(), nullable=False),
        sa.Column('is_ready', sa.Boolean(), nullable=False),
        sa.Column('is_host', sa.Boolean(), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['room_id'], ['rooms.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('room_id', 'seat_index', name='uq_room_seat'),
        sa.UniqueConstraint('room_id', 'user_id', name='uq_room_user')
    )

    op.create_table(
        'matches',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('room_id', sa.String(length=36), nullable=True),
        sa.Column('mode', sa.String(length=20), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('winner_user_id', sa.String(length=36), nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('finished_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sequence', sa.Integer(), nullable=False),
        sa.Column('ruleset_version', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['room_id'], ['rooms.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['winner_user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_table(
        'match_players',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('match_id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=True),
        sa.Column('seat_index', sa.Integer(), nullable=False),
        sa.Column('color', sa.String(length=10), nullable=False),
        sa.Column('placement', sa.Integer(), nullable=True),
        sa.Column('coins_delta', sa.Integer(), nullable=False),
        sa.Column('xp_gained', sa.Integer(), nullable=False),
        sa.Column('is_bot', sa.Boolean(), nullable=False),
        sa.Column('disconnected_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['match_id'], ['matches.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('match_id', 'seat_index', name='uq_match_seat')
    )

    op.create_table(
        'game_snapshots',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('match_id', sa.String(length=36), nullable=False),
        sa.Column('sequence', sa.Integer(), nullable=False),
        sa.Column('state_json', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['match_id'], ['matches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_game_snapshots_match_id'), 'game_snapshots', ['match_id'], unique=False)

    op.create_table(
        'game_events',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('match_id', sa.String(length=36), nullable=False),
        sa.Column('sequence', sa.Integer(), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('payload', sa.Text(), nullable=False),
        sa.Column('server_time', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['match_id'], ['matches.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_game_events_match_id'), 'game_events', ['match_id'], unique=False)

def downgrade() -> None:
    op.drop_index(op.f('ix_game_events_match_id'), table_name='game_events')
    op.drop_table('game_events')
    op.drop_index(op.f('ix_game_snapshots_match_id'), table_name='game_snapshots')
    op.drop_table('game_snapshots')
    op.drop_table('match_players')
    op.drop_table('matches')
    op.drop_table('room_members')
    op.drop_index(op.f('ix_rooms_code'), table_name='rooms')
    op.drop_table('rooms')
