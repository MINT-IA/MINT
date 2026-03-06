"""P7: external data sources + banking consents

Revision ID: p7_external_data_sources
Revises: p6_household_billing
Create Date: 2026-03-06 10:00:00.000000

Adds:
- external_data_sources table (cached API responses)
- banking_consents table (persistent consent storage)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = 'p7_external_data_sources'
down_revision: Union[str, Sequence[str]] = 'p6_household_billing'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create external_data_sources and banking_consents tables."""
    bind = op.get_bind()

    def _has_table(table_name: str) -> bool:
        return inspect(bind).has_table(table_name)

    def _has_index(table_name: str, index_name: str) -> bool:
        return any(
            idx.get("name") == index_name for idx in inspect(bind).get_indexes(table_name)
        )

    # 1. Create external_data_sources table
    if not _has_table('external_data_sources'):
        op.create_table(
            'external_data_sources',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('source_type', sa.String(), nullable=False),
            sa.Column('cached_response', sa.Text(), nullable=False),
            sa.Column('fetched_at', sa.DateTime(), nullable=False),
            sa.Column('expires_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
    if _has_table('external_data_sources'):
        if not _has_index('external_data_sources', 'ix_external_data_sources_user_source'):
            op.create_index(
                'ix_external_data_sources_user_source',
                'external_data_sources',
                ['user_id', 'source_type'],
                unique=True,
            )
        if not _has_index('external_data_sources', 'ix_external_data_sources_expires'):
            op.create_index(
                'ix_external_data_sources_expires',
                'external_data_sources',
                ['expires_at'],
                unique=False,
            )

    # 2. Create banking_consents table
    if not _has_table('banking_consents'):
        op.create_table(
            'banking_consents',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('bank_id', sa.String(), nullable=False),
            sa.Column('bank_name', sa.String(), nullable=False),
            sa.Column('scopes', sa.Text(), nullable=False),
            sa.Column('status', sa.String(), nullable=False, server_default='active'),
            sa.Column('granted_at', sa.DateTime(), nullable=False),
            sa.Column('expires_at', sa.DateTime(), nullable=False),
            sa.Column('revoked_at', sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
    if _has_table('banking_consents'):
        if not _has_index('banking_consents', 'ix_banking_consents_user_id'):
            op.create_index(
                'ix_banking_consents_user_id',
                'banking_consents',
                ['user_id'],
                unique=False,
            )
        if not _has_index('banking_consents', 'ix_banking_consents_status'):
            op.create_index(
                'ix_banking_consents_status',
                'banking_consents',
                ['user_id', 'status'],
                unique=False,
            )


def downgrade() -> None:
    """Drop external_data_sources and banking_consents tables."""
    # Drop banking_consents
    with op.batch_alter_table('banking_consents', schema=None) as batch_op:
        batch_op.drop_index('ix_banking_consents_status')
        batch_op.drop_index('ix_banking_consents_user_id')
    op.drop_table('banking_consents')

    # Drop external_data_sources
    with op.batch_alter_table('external_data_sources', schema=None) as batch_op:
        batch_op.drop_index('ix_external_data_sources_expires')
        batch_op.drop_index('ix_external_data_sources_user_source')
    op.drop_table('external_data_sources')
