---
phase: mint-calc-engine-v1
plan: 12
wave: 3
title: W3 — Alembic composite index migration (D-CE-12 Finding 3 critical gap)
type: execute
depends_on: [01]
files_modified:
  - services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py
  - services/backend/tests/test_scenarios_cache_index.py
autonomous: true
requirements: [D-CE-12]
estimated_duration: 2
must_haves:
  truths:
    - "Alembic migration creates `idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` via `op.get_context().autocommit_block()`"
    - "Migration is dialect-safe: PostgreSQL uses `CREATE INDEX CONCURRENTLY IF NOT EXISTS`; SQLite uses plain `CREATE INDEX IF NOT EXISTS`"
    - "Downgrade path symmetric: `DROP INDEX CONCURRENTLY IF EXISTS` on PG, plain `DROP INDEX` on SQLite"
    - "Post-deploy verification query shows Index Scan, not Seq Scan, on cache-lookup query plan"
  artifacts:
    - path: services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py
      provides: "Alembic migration p110 with autocommit_block + dialect branch"
      min_lines: 50
    - path: services/backend/tests/test_scenarios_cache_index.py
      provides: "Tests for index existence + EXPLAIN ANALYZE Index Scan + autocommit_block presence"
      min_lines: 50
  key_links:
    - from: services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py
      to: services/backend/alembic/versions/p95_dag_invalidation.py
      via: "down_revision points to p95_dag_invalidation"
      pattern: "down_revision"
---

<objective>
Ship the composite partial index Phase 95 left missing. Without it, the cache-lookup query (D-CE-12 read-side) is a seq-scan and MAKES performance WORSE for power users. This is the Finding 3 critical gap.

Purpose: D-CE-12 + Finding 3. CONCURRENTLY-safe migration via `autocommit_block()`. Both PG (production) and SQLite (test) paths.

Output: 1 Alembic migration + 1 test file. Plan 13 (cache_reader/writer) then consumes the index.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/alembic/versions/p95_dag_invalidation.py
@services/backend/app/models/scenario.py
</context>

<interfaces>
<!-- RESEARCH §Q-D lines 600-694 -->

Migration shape:
```python
def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite path — no CONCURRENTLY, no partial WHERE
        op.execute(f"CREATE INDEX IF NOT EXISTS {INDEX_NAME} ON scenarios (profile_id, kind, inputs_hash, created_at)")
        return
    with op.get_context().autocommit_block():
        op.execute(f"""
            CREATE INDEX CONCURRENTLY IF NOT EXISTS {INDEX_NAME}
            ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
            WHERE superseded_by IS NULL
        """)
```

Down rev: p95_dag_invalidation (existing additive migration for scenarios.inputs_hash + scenarios.superseded_by per Phase 95).
</interfaces>

<tasks>

<task id="W3-01-01" type="auto" tdd="true">
  <name>Task 1: Alembic migration p110 with autocommit_block</name>
  <files>services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-D (lines 600-694 verbatim)
    - services/backend/alembic/versions/p95_dag_invalidation.py (down_revision parent)
    - services/backend/alembic/env.py (environment config)
  </read_first>
  <behavior>
    - Test 1: Migration file parses syntactically (`ast.parse`).
    - Test 2: `down_revision == "p95_dag_invalidation"` (or whatever the actual revision id is — verify).
    - Test 3: Migration contains `autocommit_block` token (PG safety).
    - Test 4: Migration contains `CREATE INDEX CONCURRENTLY` (PG path).
    - Test 5: Migration contains the dialect branch (`if bind.dialect.name != "postgresql"`).
    - Test 6: `IF NOT EXISTS` present (idempotent re-run safe).
    - Test 7: Partial index clause `WHERE superseded_by IS NULL` present.
    - Test 8: Downgrade symmetric (DROP INDEX path).
  </behavior>
  <action>
    Create `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` matching RESEARCH §Q-D lines 611-664 verbatim:

    ```python
    """Phase mint-calc-engine-v1 W3 — D-CE-12 composite index for cache lookup.

    Revision ID: p110_scenarios_cache_lookup_index
    Revises:     p95_dag_invalidation  # VERIFY actual revision id from p95 file
    Create Date: 2026-05-XX

    Adds the composite partial index Phase 95 left missing:
      (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL

    Without it, the read-side cache lookup is a seq-scan and MAKES performance
    WORSE for power users (Phase 95 critical gap, panel Finding 3).

    Footgun mitigation: CREATE INDEX CONCURRENTLY cannot run in a transaction.
    Alembic's autocommit_block() wraps the call cleanly.
    """
    from alembic import op


    revision = "p110_scenarios_cache_lookup_index"
    down_revision = "p95_dag_invalidation"   # VERIFY: read p95 file, set its actual revision id
    branch_labels = None
    depends_on = None


    INDEX_NAME = "idx_scenarios_cache_lookup"


    def upgrade() -> None:
        bind = op.get_bind()
        if bind.dialect.name != "postgresql":
            # SQLite path (pytest in-memory) — no CONCURRENTLY, no partial WHERE.
            op.execute(
                f"CREATE INDEX IF NOT EXISTS {INDEX_NAME} "
                f"ON scenarios (profile_id, kind, inputs_hash, created_at)"
            )
            return

        # PostgreSQL — CONCURRENTLY + partial index.
        with op.get_context().autocommit_block():
            op.execute(
                f"""
                CREATE INDEX CONCURRENTLY IF NOT EXISTS {INDEX_NAME}
                ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
                WHERE superseded_by IS NULL
                """
            )


    def downgrade() -> None:
        bind = op.get_bind()
        if bind.dialect.name != "postgresql":
            op.execute(f"DROP INDEX IF EXISTS {INDEX_NAME}")
            return
        with op.get_context().autocommit_block():
            op.execute(f"DROP INDEX CONCURRENTLY IF EXISTS {INDEX_NAME}")
    ```

    VERIFY before commit: open `services/backend/alembic/versions/p95_dag_invalidation.py` (or whatever Phase 95 named it) and copy the EXACT `revision = "..."` value for `down_revision`. RESEARCH says `p95_dag_invalidation` but verify.
  </action>
  <verify>
    <automated>python3 -c "import ast; ast.parse(open('services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py').read()); print('OK')"</automated>
  </verify>
  <acceptance_criteria>
    - File ≥50 lines
    - `grep -c "autocommit_block" services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` returns ≥2 (upgrade + downgrade)
    - `grep -c "CREATE INDEX CONCURRENTLY" services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` returns ≥1
    - `grep -c "WHERE superseded_by IS NULL" services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` returns ≥1
    - `grep -c "if bind.dialect.name != \"postgresql\"" services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` returns ≥2 (upgrade + downgrade dialect branch)
    - `down_revision` points to actual previous revision id (verified by grep of p95 file)
  </acceptance_criteria>
  <done>Migration written</done>
</task>

<task id="W3-01-02" type="auto" tdd="true">
  <name>Task 2: Migration tests (upgrade/downgrade + index existence + EXPLAIN ANALYZE)</name>
  <files>services/backend/tests/test_scenarios_cache_index.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md W3-01-01..03
    - services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py
  </read_first>
  <behavior>
    - Test 1 (sqlite, fast): `alembic upgrade head` succeeds without error.
    - Test 2 (sqlite, fast): Index exists post-upgrade. Query SQLite schema: `SELECT name FROM sqlite_master WHERE type='index' AND name='idx_scenarios_cache_lookup'` returns ≥1 row.
    - Test 3 (sqlite, fast): `alembic downgrade -1` succeeds + index dropped.
    - Test 4 (PG-only, skipped on SQLite): EXPLAIN ANALYZE of cache-lookup query shows `Index Scan using idx_scenarios_cache_lookup`, NOT `Seq Scan`.
    - Test 5: Migration is idempotent — re-running upgrade is no-op (no error).
  </behavior>
  <action>
    ```python
    # services/backend/tests/test_scenarios_cache_index.py
    """D-CE-12 + Finding 3 — composite index migration tests."""
    import os
    import pytest
    from sqlalchemy import inspect, text

    from app.core.database import engine


    INDEX_NAME = "idx_scenarios_cache_lookup"


    @pytest.fixture(scope="module")
    def applied_migration(alembic_engine, alembic_config):
        """Apply the p110 migration via Alembic against test DB."""
        from alembic.command import upgrade
        upgrade(alembic_config, "head")
        yield
        # Downgrade for cleanup
        from alembic.command import downgrade
        downgrade(alembic_config, "-1")


    def test_index_exists_after_upgrade(applied_migration):
        insp = inspect(engine)
        indexes = insp.get_indexes("scenarios")
        names = {idx["name"] for idx in indexes}
        assert INDEX_NAME in names, f"Index missing. Found: {names}"


    @pytest.mark.skipif(
        engine.dialect.name != "postgresql",
        reason="EXPLAIN ANALYZE is postgres-specific",
    )
    def test_explain_analyze_uses_index(applied_migration):
        """D-CE-12 SLO: cache-lookup query MUST use Index Scan, not Seq Scan."""
        with engine.connect() as conn:
            # Insert ≥100 rows for the planner to prefer index
            for i in range(100):
                conn.execute(text("""
                    INSERT INTO scenarios (profile_id, kind, inputs_hash, created_at, superseded_by)
                    VALUES (gen_random_uuid(), :kind, :hash, now(), NULL)
                """), {"kind": f"k{i % 10}", "hash": f"h{i:064d}"})

            result = conn.execute(text("""
                EXPLAIN ANALYZE
                SELECT * FROM scenarios
                WHERE profile_id = gen_random_uuid()
                  AND kind = 'k0'
                  AND inputs_hash = 'h0000000000000000000000000000000000000000000000000000000000000000'
                  AND superseded_by IS NULL
                ORDER BY created_at DESC LIMIT 1
            """))
            plan_text = "\n".join(row[0] for row in result)
            assert "Index Scan" in plan_text or "Bitmap Index Scan" in plan_text, (
                f"Expected Index Scan, got plan: {plan_text}"
            )


    def test_idempotent_upgrade(alembic_config):
        """Re-running upgrade is no-op (IF NOT EXISTS guard)."""
        from alembic.command import upgrade
        upgrade(alembic_config, "head")
        upgrade(alembic_config, "head")  # second run = no error
    ```
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_scenarios_cache_index.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4-5 tests green (PG-only test may skip on SQLite test env)
    - SQLite-path test (Test 1-3, 5) green
    - If running on PG: Test 4 confirms Index Scan
    - `python3 tools/checks/banned_terms_python.py services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py services/backend/tests/test_scenarios_cache_index.py` exits 0
  </acceptance_criteria>
  <done>Migration + tests green</done>
</task>

<task id="W3-01-99" type="auto" tdd="false">
  <name>Task 3: Apply migration on staging (optional) + engram</name>
  <files>(deployment + engram)</files>
  <read_first>
    - .planning/STATE.md
  </read_first>
  <action>
    Engram save:
    - `topic_key: calc_engine:w3:composite_index_finding_3_closed`
    - `type: bugfix`
    - `prior_finding_refs: [#103 panel synthesis Finding 3, Plan 95 obs (Phase 95 critical gap), Plan 01 obs]`
    - Content: « D-CE-12 composite partial index migration `idx_scenarios_cache_lookup (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` ships at `alembic/versions/p110_*.py`. autocommit_block CONCURRENTLY-safe. Phase 95 Finding 3 critical gap closed. Plan 13 cache_reader consumes the index. »

    Note in SUMMARY: « Staging migration runs via Railway deploy ; production runs during low-traffic window (03-06 CET). Estimated ~5-10 min wall-clock on Railway PG14+ scenarios table per RESEARCH §Q-D. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
    - Deployment note in SUMMARY
  </acceptance_criteria>
  <done>W3-01 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-12-01 | DoS | seq-scan on cache lookup | mitigate | Index closes the performance regression. Test 4 EXPLAIN ANALYZE proves Index Scan. |
| T-mint-calc-12-02 | DoS | migration locks table | mitigate | CONCURRENTLY + autocommit_block — no table locks. |
| T-mint-calc-12-03 | Tampering | migration replay corruption | mitigate | IF NOT EXISTS makes upgrade idempotent. Test 5 verifies. |
| T-mint-calc-12-04 | Information disclosure | EXPLAIN ANALYZE result | accept | Test runs on test DB only. No production-data leak. |
</threat_model>

<success_criteria>
- 1 migration + 1 test file
- ≥4 tests green
- autocommit_block + CONCURRENTLY both present
- Idempotent upgrade verified
- Engram observation persisted with Finding 3 reference
</success_criteria>

<risks>
- **down_revision pointer**. Must match actual previous Alembic revision id. Verify by reading p95 file.
- **PG-only test skips on SQLite test runner**. Plan acceptance criterion allows skip. Production verification ships via Railway deploy + post-deploy EXPLAIN ANALYZE.
- **5.8M-row backfill on first CONCURRENTLY run**. Per RESEARCH §Q-D ~5-10 min wall-clock. Schedule during low-traffic window.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-12-w3-composite-index-migration-SUMMARY.md`.
</output>
