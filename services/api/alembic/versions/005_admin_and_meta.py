"""admin_and_meta

Revision ID: 005_admin_and_meta
Revises: 004_friends_and_social
Create Date: 2026-10-02 12:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '005_admin_and_meta'
down_revision: Union[str, None] = '004_friends_and_social'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. admin_users
    op.create_table(
        'admin_users',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('username', sa.String(length=50), nullable=False),
        sa.Column('email', sa.String(length=100), nullable=False),
        sa.Column('hashed_password', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=20), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('username'),
        sa.UniqueConstraint('email')
    )
    op.create_index(op.f('ix_admin_users_username'), 'admin_users', ['username'], unique=True)
    op.create_index(op.f('ix_admin_users_email'), 'admin_users', ['email'], unique=True)

    # 2. admin_audit_logs
    op.create_table(
        'admin_audit_logs',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('admin_id', sa.String(length=36), nullable=False),
        sa.Column('admin_username', sa.String(length=50), nullable=False),
        sa.Column('action', sa.String(length=50), nullable=False),
        sa.Column('target_type', sa.String(length=50), nullable=False),
        sa.Column('target_id', sa.String(length=100), nullable=True),
        sa.Column('details', sa.Text(), nullable=True),
        sa.Column('ip_address', sa.String(length=45), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_admin_audit_logs_admin_id'), 'admin_audit_logs', ['admin_id'], unique=False)
    op.create_index(op.f('ix_admin_audit_logs_action'), 'admin_audit_logs', ['action'], unique=False)

def downgrade() -> None:
    op.drop_table('admin_audit_logs')
    op.drop_table('admin_users')
