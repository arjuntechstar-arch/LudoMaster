"""add bot-fill preference to rooms

Revision ID: 008_room_bot_fill_option
Revises: 007_progression_usernames
Create Date: 2026-10-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "008_room_bot_fill_option"
down_revision: Union[str, None] = "007_progression_usernames"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "rooms",
        sa.Column(
            "fill_with_bots",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )


def downgrade() -> None:
    op.drop_column("rooms", "fill_with_bots")
