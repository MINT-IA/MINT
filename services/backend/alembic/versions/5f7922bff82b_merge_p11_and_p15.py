"""merge_p11_and_p15

Revision ID: 5f7922bff82b
Revises: p11_recent_gravity_events, p15_earmark_tags
Create Date: 2026-04-14 12:57:11.694242

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5f7922bff82b'
down_revision: Union[str, Sequence[str], None] = ('p11_recent_gravity_events', 'p15_earmark_tags')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
