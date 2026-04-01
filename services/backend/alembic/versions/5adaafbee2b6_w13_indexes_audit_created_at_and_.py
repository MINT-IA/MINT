"""w13_indexes_audit_created_at_and_analytics_compound

Revision ID: 5adaafbee2b6
Revises: p7_external_data_sources
Create Date: 2026-04-01 21:44:45.911466

Adds:
- Index on audit_events.created_at (time-range queries on audit log)
- Compound index (user_id, timestamp) on analytics_events (per-user event lookups)
"""
from typing import Sequence, Union

from alembic import op
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = '5adaafbee2b6'
down_revision: Union[str, Sequence[str], None] = 'p7_external_data_sources'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add performance indexes for audit and analytics queries."""
    bind = op.get_bind()

    def _has_index(table_name: str, index_name: str) -> bool:
        return any(
            idx.get("name") == index_name
            for idx in inspect(bind).get_indexes(table_name)
        )

    # 1. Index on audit_events.created_at for time-range queries
    if not _has_index("audit_events", "ix_audit_events_created_at"):
        with op.batch_alter_table('audit_events', schema=None) as batch_op:
            batch_op.create_index(
                batch_op.f('ix_audit_events_created_at'),
                ['created_at'],
                unique=False,
            )

    # 2. Compound index (user_id, timestamp) on analytics_events
    if not _has_index("analytics_events", "ix_analytics_events_user_timestamp"):
        with op.batch_alter_table('analytics_events', schema=None) as batch_op:
            batch_op.create_index(
                'ix_analytics_events_user_timestamp',
                ['user_id', 'timestamp'],
                unique=False,
            )


def downgrade() -> None:
    """Remove W13 indexes."""
    with op.batch_alter_table('audit_events', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_audit_events_created_at'))

    with op.batch_alter_table('analytics_events', schema=None) as batch_op:
        batch_op.drop_index('ix_analytics_events_user_timestamp')
