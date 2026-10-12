"""friends_and_social

Revision ID: 004_friends_and_social
Revises: 003_matchmaking
Create Date: 2026-10-01 18:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '004_friends_and_social'
down_revision: Union[str, None] = '003_matchmaking'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. friendships
    op.create_table(
        'friendships',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('friend_user_id', sa.String(length=36), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['friend_user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'friend_user_id', name='uq_friendship_pair')
    )
    op.create_index(op.f('ix_friendships_user_id'), 'friendships', ['user_id'], unique=False)
    op.create_index(op.f('ix_friendships_friend_user_id'), 'friendships', ['friend_user_id'], unique=False)

    # 2. blocks
    op.create_table(
        'blocks',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('blocker_id', sa.String(length=36), nullable=False),
        sa.Column('blocked_id', sa.String(length=36), nullable=False),
        sa.Column('reason', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['blocker_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['blocked_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('blocker_id', 'blocked_id', name='uq_block_pair')
    )
    op.create_index(op.f('ix_blocks_blocker_id'), 'blocks', ['blocker_id'], unique=False)
    op.create_index(op.f('ix_blocks_blocked_id'), 'blocks', ['blocked_id'], unique=False)

    # 3. reports
    op.create_table(
        'reports',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('reporter_id', sa.String(length=36), nullable=False),
        sa.Column('reported_user_id', sa.String(length=36), nullable=False),
        sa.Column('category', sa.String(length=30), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('match_id', sa.String(length=36), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['reporter_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['reported_user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_reports_reporter_id'), 'reports', ['reporter_id'], unique=False)
    op.create_index(op.f('ix_reports_reported_user_id'), 'reports', ['reported_user_id'], unique=False)

    # 4. room_invites
    op.create_table(
        'room_invites',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('room_id', sa.String(length=36), nullable=False),
        sa.Column('sender_id', sa.String(length=36), nullable=False),
        sa.Column('recipient_id', sa.String(length=36), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['room_id'], ['rooms.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['sender_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['recipient_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_room_invites_room_id'), 'room_invites', ['room_id'], unique=False)
    op.create_index(op.f('ix_room_invites_recipient_id'), 'room_invites', ['recipient_id'], unique=False)

def downgrade() -> None:
    op.drop_table('room_invites')
    op.drop_table('reports')
    op.drop_table('blocks')
    op.drop_table('friendships')
