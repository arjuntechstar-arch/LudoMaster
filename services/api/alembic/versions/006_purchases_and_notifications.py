"""purchases_and_notifications

Revision ID: 006_purchases_and_notifications
Revises: 005_admin_and_meta
Create Date: 2026-10-02 14:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '006_purchases_and_notifications'
down_revision: Union[str, None] = '005_admin_and_meta'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. purchase_orders
    op.create_table(
        'purchase_orders',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('product_id', sa.String(length=100), nullable=False),
        sa.Column('platform', sa.String(length=30), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('price_cents', sa.Integer(), nullable=False),
        sa.Column('currency_code', sa.String(length=10), nullable=False),
        sa.Column('idempotency_key', sa.String(length=100), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('idempotency_key')
    )
    op.create_index(op.f('ix_purchase_orders_user_id'), 'purchase_orders', ['user_id'], unique=False)
    op.create_index(op.f('ix_purchase_orders_product_id'), 'purchase_orders', ['product_id'], unique=False)

    # 2. purchase_receipts
    op.create_table(
        'purchase_receipts',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('order_id', sa.String(length=36), nullable=True),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('platform', sa.String(length=30), nullable=False),
        sa.Column('transaction_id', sa.String(length=255), nullable=False),
        sa.Column('raw_receipt', sa.Text(), nullable=False),
        sa.Column('verification_status', sa.String(length=20), nullable=False),
        sa.Column('granted_coins', sa.Integer(), nullable=False),
        sa.Column('granted_gems', sa.Integer(), nullable=False),
        sa.Column('verified_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['order_id'], ['purchase_orders.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('platform', 'transaction_id', name='uq_platform_transaction')
    )
    op.create_index(op.f('ix_purchase_receipts_user_id'), 'purchase_receipts', ['user_id'], unique=False)
    op.create_index(op.f('ix_purchase_receipts_transaction_id'), 'purchase_receipts', ['transaction_id'], unique=False)

    # 3. notifications
    op.create_table(
        'notifications',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('category', sa.String(length=50), nullable=False),
        sa.Column('data_payload', sa.Text(), nullable=True),
        sa.Column('is_read', sa.Boolean(), nullable=False),
        sa.Column('read_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notifications_user_id'), 'notifications', ['user_id'], unique=False)

def downgrade() -> None:
    op.drop_table('notifications')
    op.drop_table('purchase_receipts')
    op.drop_table('purchase_orders')
