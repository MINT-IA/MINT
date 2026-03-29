"""P8: JWT token blacklist for JTI persistence

Revision ID: p8_token_blacklist
Revises: p7_external_data_sources
Create Date: 2026-03-29 10:00:00.000000

Adds:
- token_blacklist table (revoked JWT JTIs for replay attack prevention)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = 'p8_token_blacklist'
down_revision: Union[str, Sequence[str]] = 'p7_external_data_sources'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create token_blacklist table."""
    bind = op.get_bind()

    def _has_table(table_name: str) -> bool:
        return inspect(bind).has_table(table_name)

    def _has_index(table_name: str, index_name: str) -> bool:
        return any(
            idx.get("name") == index_name for idx in inspect(bind).get_indexes(table_name)
        )

    if not _has_table('token_blacklist'):
        op.create_table(
            'token_blacklist',
            sa.Column('jti', sa.String(64), nullable=False),
            sa.Column('expires_at', sa.DateTime(), nullable=False),
            sa.Column('blacklisted_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.PrimaryKeyConstraint('jti'),
        )
    if _has_table('token_blacklist'):
        if not _has_index('token_blacklist', 'ix_token_blacklist_expires_at'):
            op.create_index(
                'ix_token_blacklist_expires_at',
                'token_blacklist',
                ['expires_at'],
                unique=False,
            )


def downgrade() -> None:
    """Drop token_blacklist table."""
    with op.batch_alter_table('token_blacklist', schema=None) as batch_op:
        batch_op.drop_index('ix_token_blacklist_expires_at')
    op.drop_table('token_blacklist')
