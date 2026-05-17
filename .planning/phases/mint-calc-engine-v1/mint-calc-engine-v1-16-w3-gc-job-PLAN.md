---
phase: mint-calc-engine-v1
plan: 16
wave: 3
title: W3 — GC daily job for superseded scenarios (Finding 4 / Q4 resolution)
type: execute
depends_on: [12, 13]
files_modified:
  - services/backend/app/services/cache/gc_job.py
  - services/backend/scripts/run_gc.py
  - services/backend/tests/test_gc_job.py
  - services/backend/railway.json
autonomous: false
requirements: [D-CE-12, Finding-4]
estimated_duration: 3
must_haves:
  truths:
    - "GC job deletes `scenarios` rows where `superseded_by IS NOT NULL AND created_at < now() - interval '30 days'`"
    - "Runnable standalone via `python services/backend/scripts/run_gc.py` (Railway cron-compatible)"
    - "Railway scheduled-deploy entry added (decision: Railway cron > APScheduler per RESEARCH §Q-E.GC)"
    - "Dry-run mode (`--dry-run`) reports row count without deleting"
  artifacts:
    - path: services/backend/app/services/cache/gc_job.py
      provides: "purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int"
      min_lines: 40
    - path: services/backend/scripts/run_gc.py
      provides: "standalone entrypoint for Railway cron"
      min_lines: 30
  key_links:
    - from: services/backend/scripts/run_gc.py
      to: services/backend/app/services/cache/gc_job.py
      via: "import + invoke purge_superseded_scenarios"
      pattern: "from app.services.cache.gc_job import"
---

<objective>
Ship daily GC job to bound `scenarios` table growth. Per Finding 4: at 100 DAU × 57 calcs × 1 year = 5.8M rows projected without GC. Trim `superseded_by IS NOT NULL` rows older than 30 days.

Purpose: D-CE-12 ops hygiene. Finding 4 mitigation. Q4 resolution: Railway cron (not APScheduler) per RESEARCH §Q-E trade-off (2-replica race safety).

Output: standalone GC script + Python module + Railway service registration. **Requires operator (Julien) GO for Railway scheduled-deploy creation.**
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/models/scenario.py
@services/backend/railway.json
</context>

<interfaces>
<!-- RESEARCH §Q-E lines 819-836 trade-off + recommendation -->

Railway cron > APScheduler because:
- 2-replica race on `DELETE FROM scenarios` is real even at low scale
- Railway scheduler guarantees exactly-1× execution per tick
- Cost: 1 entry in railway.json + 1 standalone script

```sql
-- The GC query
DELETE FROM scenarios
WHERE superseded_by IS NOT NULL
  AND created_at < now() - interval '30 days'
```

Dry-run mode reports `SELECT count(*)` of would-be-deleted rows.
</interfaces>

<tasks>

<task id="W3-05-01" type="auto" tdd="true">
  <name>Task 1: gc_job module</name>
  <files>services/backend/app/services/cache/gc_job.py, services/backend/tests/test_gc_job.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-E (GC trade-off lines 819-840)
    - services/backend/app/models/scenario.py
  </read_first>
  <behavior>
    - Test 1: 100 rows with `superseded_by` set and `created_at = now() - 31 days` → GC purges all 100. Return value = 100.
    - Test 2: 100 rows with `superseded_by IS NULL` → 0 purged (live rows preserved).
    - Test 3: 100 rows with `superseded_by` set BUT `created_at = now() - 10 days` → 0 purged (within 30-day window).
    - Test 4: `dry_run=True` returns count but doesn't delete (row count after = before).
    - Test 5: `max_age_days` configurable (default 30, can override).
  </behavior>
  <action>
    ```python
    # services/backend/app/services/cache/gc_job.py
    """Phase mint-calc-engine-v1 W3 — Finding 4 GC daily job."""
    import logging
    from datetime import datetime, timedelta
    from sqlalchemy import text
    from sqlalchemy.orm import Session

    from app.models.scenario import ScenarioModel

    _logger = logging.getLogger(__name__)


    def purge_superseded_scenarios(
        db: Session,
        max_age_days: int = 30,
        dry_run: bool = False,
    ) -> int:
        """Delete scenarios rows with superseded_by IS NOT NULL older than max_age_days.

        Returns count of deleted (or would-be-deleted if dry_run=True) rows.
        """
        cutoff = datetime.utcnow() - timedelta(days=max_age_days)

        if dry_run:
            count = (
                db.query(ScenarioModel)
                .filter(
                    ScenarioModel.superseded_by.isnot(None),
                    ScenarioModel.created_at < cutoff,
                )
                .count()
            )
            _logger.info(f"GC dry-run: {count} rows would be purged (cutoff={cutoff})")
            return count

        # Bulk delete
        deleted_count = (
            db.query(ScenarioModel)
            .filter(
                ScenarioModel.superseded_by.isnot(None),
                ScenarioModel.created_at < cutoff,
            )
            .delete(synchronize_session=False)
        )
        db.commit()
        _logger.info(f"GC: {deleted_count} rows purged (cutoff={cutoff})")
        return deleted_count
    ```

    5 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_gc_job.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 5 tests green
    - `grep -c "superseded_by.isnot(None)" services/backend/app/services/cache/gc_job.py` returns ≥2
  </acceptance_criteria>
  <done>GC module live</done>
</task>

<task id="W3-05-02" type="auto" tdd="false">
  <name>Task 2: Standalone entrypoint script (Railway cron-ready)</name>
  <files>services/backend/scripts/run_gc.py</files>
  <read_first>
    - services/backend/app/core/database.py (engine + session)
    - services/backend/scripts/ (if exists — pattern precedent ; else first script in this dir)
  </read_first>
  <action>
    ```python
    #!/usr/bin/env python3
    """Phase mint-calc-engine-v1 W3 — standalone GC runner for Railway cron.

    Usage:
      python services/backend/scripts/run_gc.py
      python services/backend/scripts/run_gc.py --dry-run
      python services/backend/scripts/run_gc.py --max-age-days 60
    """
    import argparse
    import sys
    import logging

    # Initialize logging + Sentry
    logging.basicConfig(level=logging.INFO)

    from app.core.database import SessionLocal
    from app.services.cache.gc_job import purge_superseded_scenarios


    def main() -> int:
        parser = argparse.ArgumentParser()
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--max-age-days", type=int, default=30)
        args = parser.parse_args()

        db = SessionLocal()
        try:
            count = purge_superseded_scenarios(
                db,
                max_age_days=args.max_age_days,
                dry_run=args.dry_run,
            )
            print(f"GC complete: {count} rows {'would be ' if args.dry_run else ''}purged.")
            return 0
        except Exception as e:
            print(f"GC FAILED: {e}", file=sys.stderr)
            return 1
        finally:
            db.close()


    if __name__ == "__main__":
        sys.exit(main())
    ```

    Make executable: `chmod +x services/backend/scripts/run_gc.py`.
  </action>
  <verify>
    <automated>python3 services/backend/scripts/run_gc.py --dry-run --max-age-days 30 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Script runs without import errors on test DB
    - `python3 services/backend/scripts/run_gc.py --dry-run` exits 0 + prints count
    - File has executable bit
  </acceptance_criteria>
  <done>Standalone runner shipped</done>
</task>

<task id="W3-05-03" type="checkpoint:human-action" gate="blocking">
  <what-built>
    - `gc_job.py` module + `run_gc.py` standalone script
    - Tests green on test DB
  </what-built>
  <how-to-verify>
    1. Julien opens Railway dashboard → Project MINT → New service → Scheduled Job.
    2. Configure:
       - Schedule: `0 3 * * *` (daily at 03:00 UTC, low-traffic window)
       - Command: `python services/backend/scripts/run_gc.py`
       - Restart policy: on-failure (max 3 attempts)
       - Sentry init: ensure SENTRY_DSN_STAGING / _PRODUCTION env var inherited
    3. Run a one-off `--dry-run` via Railway CLI: `railway run python services/backend/scripts/run_gc.py --dry-run` — confirms zero-or-low row count on staging.
    4. After 24h of first scheduled run, verify Sentry logs show `INFO GC: X rows purged`.
  </how-to-verify>
  <resume-signal>
    Reply with:
    - "approved" → Plan 16 closes, W3 wave closes
    - "deferred — need APScheduler fallback" → executor implements APScheduler in-process variant + leader-election flag
    - "blocked — Railway not available" → escalate to orchestrator
  </resume-signal>
</task>

<task id="W3-05-99" type="auto" tdd="false">
  <name>Task 4: W3 wave-close engram</name>
  <files>(engram)</files>
  <action>
    Engram **wave-close** save (per Concern F):
    - `topic_key: calc_engine:w3:wave_close_dag_cache_complete`
    - `type: architecture`
    - `prior_finding_refs: [Plan 12 obs (composite index), Plan 13 obs (cache+singleflight), Plan 14 obs (reverse-dep map), Plan 15 obs (pre-compute), #103 panel synthesis D-CE-12+13+14 + Finding 3+4]`
    - Content: « W3 closed. DAG cache layer complete: composite partial index + reader/writer + AsyncSingleflight + read-through get_or_compute + BackgroundTasks pre-compute + Railway-cron GC job. D-CE-12 SLO sub-50ms p95 baseline. D-CE-14 SLI baselined. Finding 3 + Finding 4 closed. Plans 17-19 (W4 metrics + lints + runtime gate) consume the cache instrumentation. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Wave-close engram saved with ≥4 prior_finding_refs
    - Full suite green
  </acceptance_criteria>
  <done>W3 wave closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-16-01 | DoS | unbounded scenarios growth | mitigate | Daily GC at 30-day cutoff. Bounds table size to ~30 × daily-write-rate. |
| T-mint-calc-16-02 | Tampering | 2-replica race on DELETE | mitigate | Railway scheduled deploy guarantees 1×-exactly per tick. APScheduler in-process variant rejected per RESEARCH §Q-E. |
| T-mint-calc-16-03 | Information disclosure | dry-run output | accept | Logs row counts only, no PII. |
| T-mint-calc-16-04 | Repudiation | GC delete audit trail | mitigate | Sentry logs every run. `deleted_count` logged. Postgres WAL provides forensic trail at DB layer. |
</threat_model>

<success_criteria>
- gc_job + run_gc + tests
- Railway cron approved by Julien (checkpoint resume = "approved")
- W3 wave-close engram
</success_criteria>

<risks>
- **Railway scheduled-deploy is operator-only.** Plan 16 cannot fully autonomous-close. Documented via `autonomous: false`.
- **APScheduler fallback.** If Railway scheduled-deploy isn't available, Task 3 can pivot to APScheduler + leader-election. Adds complexity ; deferred unless forced.
- **30-day cutoff arbitrary.** May tune to 60 or 90 days based on user-facing « projection age » expectations. Initial 30d is defensive ; revisit after 1 month of metrics.
- **First run on production scenarios.** May purge a large number of old rows. Mitigation: run `--dry-run` on Railway first; review count; then enable scheduled run.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-16-w3-gc-job-SUMMARY.md` + W3 wave-close summary.
</output>
