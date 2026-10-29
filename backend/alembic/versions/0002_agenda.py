"""meeting agenda and the model's suggestion

Revision ID: 0002_agenda
Revises: 0001_create_meetings
Create Date: 2026-10-29
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0002_agenda"
down_revision = "0001_create_meetings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("meetings", sa.Column("agenda", JSONB(), nullable=True))
    op.add_column("meetings", sa.Column("ai_suggestion", JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column("meetings", "ai_suggestion")
    op.drop_column("meetings", "agenda")
