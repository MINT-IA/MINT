"""merge_p86_eclairage_into_p112_head

Resolves the dual-head condition documented in
.planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md
DEFERRED-02-01-A. Pre-Plan-02-02 the alembic chain had two heads :

  - p112_audit_event_user_hash   (chain length 26, baseline Phase 02 consumes)
  - p86_eclairage_delivered      (chain length 22, anonymous-session branch)

Both branches ship valid DDL ; neither needs schema reconciliation. This is a
pure topological merge (empty upgrade/downgrade) so any new migration in
Phase 02 (p98/p113/p114/p115/p116 ...) can chain off a single head.

Revision ID: p98_merge_p86_eclairage   (project-canonical short id ; matches
the convention used since p10_scenarios_table for human-readable migration
discovery via `ls alembic/versions/ | grep p9`).

Revises: p112_audit_event_user_hash, p86_eclairage_delivered
Create Date: 2026-05-18 20:57:01.539556

References:
- .planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md
  (DEFERRED-02-01-A — pre-existing condition before Plan 02-01 W0 prereqs ran)
- .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-02-event-log-core-canary-PLAN.md
  (Plan 02-02 P0 — blocks every new alembic migration in Phase 02 until merged)
"""
from typing import Sequence, Union

from alembic import op  # noqa: F401 — kept for alembic discovery contract
import sqlalchemy as sa  # noqa: F401 — kept for alembic discovery contract


# revision identifiers, used by Alembic.
revision: str = "p98_merge_p86_eclairage"
down_revision: Union[str, Sequence[str], None] = (
    "p112_audit_event_user_hash",
    "p86_eclairage_delivered",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Pure topological merge — no DDL. See module docstring."""
    pass


def downgrade() -> None:
    """Pure topological merge — no DDL. See module docstring."""
    pass
