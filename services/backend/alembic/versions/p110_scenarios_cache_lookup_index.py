"""Phase mint-calc-engine-v1 W3 Plan 12 — D-CE-12 composite index for cache lookup.

Revision ID : p110_scenarios_cache_idx   (24 chars ; was originally
              `p110_scenarios_cache_lookup_index` (33 chars) but `lefthook
              alembic_revision_length` hook flagged it as >32, the Postgres
              `alembic_version.version_num VARCHAR(32)` cap — see footnote
              about the 2026-05-12 Railway incident that introduced this lint).
Revises     : p97_snapshots_fk_defaults   (the actual revision id ; see footnote)
Create Date : 2026-05-17

Adds the composite partial index Phase 95 left missing :
  (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL

Without it, the D-CE-12 read-side cache lookup (Plan 13's `cache_reader`) is a
seq-scan on the `scenarios` table and MAKES performance WORSE for power users
(the more rows they have, the slower a cache MISS check becomes). This is the
Finding 3 critical gap from the W3-planning panel synthesis.

Footgun mitigation
==================
`CREATE INDEX CONCURRENTLY` cannot run inside a transaction block. Alembic wraps
every migration in `BEGIN ... COMMIT` by default, so a naive
`op.execute("CREATE INDEX CONCURRENTLY ...")` fails with `ERROR: CREATE INDEX
CONCURRENTLY cannot run inside a transaction block`. Alembic's
`op.get_context().autocommit_block()` context manager ends the surrounding
transaction, runs the wrapped statements in autocommit mode, and re-opens a
transaction afterwards. Same primitive used in `pg_enum_add_value` migrations.

Cited at RESEARCH §Q-D (lines 600-694) :
  - lyjia.us/blog/p/alembic-migrations-outside-transaction-block
  - sqlalchemy.github.io/alembic/discussions/1461
  - postgresql.org/docs/current/sql-createindex.html (IF NOT EXISTS for
    CONCURRENTLY supported on PG 9.6+, Railway runs PG 14+)

Dialect branch
==============
SQLite (pytest in-memory test path) supports neither `CONCURRENTLY` nor
`WHERE` partial predicates in the same form. The dialect guard ships a plain
`CREATE INDEX IF NOT EXISTS` for the test path — enough to verify the index is
applied + dropped + idempotent in CI without requiring a live Postgres instance.

Production EXPLAIN ANALYZE verification ships post-deploy on Railway PG14+
(see SUMMARY.md « Deployment notes »). RESEARCH §Q-D verification query :
  EXPLAIN ANALYZE SELECT * FROM scenarios
   WHERE profile_id = '<uuid>' AND kind = 'lpp_rachat'
     AND inputs_hash = '<hex>'  AND superseded_by IS NULL
   ORDER BY created_at DESC LIMIT 1;
Expected post-deploy : `Index Scan using idx_scenarios_cache_lookup`.

Backfill consideration
======================
At 100 DAU × 57 calcs × 1 year ≈ 5.8M rows projected. CONCURRENTLY scales : it
does a 2-pass build without blocking writes. On a 5.8M row table on Railway
hardware, expect ~5-10 min wall-clock. Schedule during low-traffic window
(Sentry traffic dashboard shows trough 03-06 CET). No application-side
backfill needed — the index covers existing rows automatically once built.

Down-revision footnote
======================
RESEARCH §Q-D line 615 + 630 cites the long-form
`p97_snapshots_fk_and_server_defaults`. That string is 36 characters and was
truncated to `p97_snapshots_fk_defaults` (25 chars) in the p97 file's
`revision = "..."` field — Postgres' `alembic_version.version_num` column is
`VARCHAR(32)` and the long form blew up Railway staging deploy 2026-05-12T11:14Z
with `psycopg2.errors.StringDataRightTruncation` (see p97 file line 49 comment).
Plan 12 reads the actual revision id from the file at plan-time and chains
correctly onto `p97_snapshots_fk_defaults`.
"""
from alembic import op


revision = "p110_scenarios_cache_idx"  # 24 chars (Postgres ≤32 cap, lefthook-enforced)
down_revision = "p97_snapshots_fk_defaults"
branch_labels = None
depends_on = None


INDEX_NAME = "idx_scenarios_cache_lookup"


def upgrade() -> None:
    """Create the composite partial index, dialect-aware."""
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite (pytest in-memory) — no CONCURRENTLY, no partial WHERE clause.
        # Plain composite index is enough for the test path (existence + idempotence).
        op.execute(
            f"CREATE INDEX IF NOT EXISTS {INDEX_NAME} "
            f"ON scenarios (profile_id, kind, inputs_hash, created_at)"
        )
        return

    # PostgreSQL — production path with CONCURRENTLY + partial WHERE + DESC order
    # on created_at (cache reader does `ORDER BY created_at DESC LIMIT 1`).
    # IF NOT EXISTS makes deploy retries safe (e.g. Railway partial-failure replay).
    with op.get_context().autocommit_block():
        op.execute(
            f"""
            CREATE INDEX CONCURRENTLY IF NOT EXISTS {INDEX_NAME}
            ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
            WHERE superseded_by IS NULL
            """
        )


def downgrade() -> None:
    """Drop the index, dialect-aware. Symmetric with upgrade."""
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite — plain DROP INDEX, no autocommit gymnastics needed.
        op.execute(f"DROP INDEX IF EXISTS {INDEX_NAME}")
        return

    # PostgreSQL — DROP INDEX CONCURRENTLY also requires autocommit_block.
    # IF EXISTS makes downgrade replay safe.
    with op.get_context().autocommit_block():
        op.execute(f"DROP INDEX CONCURRENTLY IF EXISTS {INDEX_NAME}")
