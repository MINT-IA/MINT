# CJT-013 Staging Phase 02 Runtime Proof — 2026-06-02

## Scope

Runtime proof for Phase 02 event-log/fact-current deployment after pushing
`8d736f397ed4b7c6dc6f3679483f3629320756c7` to `staging`.

## GitHub / Railway

- GitHub CI run `26829856888` completed successfully on
  `8d736f397ed4b7c6dc6f3679483f3629320756c7`.
- Successful jobs included backend tests, Flutter services/screens/widgets,
  PG integration (testcontainers), CI Gate, semantic copy lints, design lints,
  route/screen registry parity, WCAG, PII log gate.
- Railway deployment `a1d2fc4d-2ce5-49f7-9e41-986477e22eaa` is `SUCCESS`.
- Railway deployment metadata:
  - branch: `staging`
  - commit: `8d736f397ed4b7c6dc6f3679483f3629320756c7`
  - commit message: `test: accept phase02 p120 pg head`
  - rootDirectory: `/services/backend`
  - startCommand: `python scripts/railway_pre_deploy_migrate.py && gunicorn ...`
- Railway deployment logs show:
  - `[migrate] running: alembic upgrade head`
  - `[migrate] success`
  - `/api/v1/health` returned `200`

## Railway DB Target

The first manual probe targeted `mint-postgres-staging`, which is an active
Railway database but is not the database referenced by the `MINT` service.
`MINT.DATABASE_URL` points to the active `pgvector` service
(`pgvector.railway.internal`). `pgvector` exposes `DATABASE_PUBLIC_URL`, so the
final proof uses that database target.

Do not treat `mint-postgres-staging` as the app runtime DB unless Railway
variables are changed.

## Runtime DB Probe

Non-sensitive query results:

```text
target = pgvector
alembic_version = p120_fact_event_idempotency

tables present:
_phase02_parity_audit
_phase02_parity_audit_continuous
fact_current
fact_event
waitlist_entries
snapshots
users

row counts:
_phase02_parity_audit = 143
_phase02_parity_audit_continuous = 0
fact_current = 0
fact_event = 0
snapshots = 0
users = 143

fact_current columns:
user_id, field_key, value_enc, confidence, valid_from, updated_at, latest_event_id
```

## Projection Audit

Command class: `STAGING_DATABASE_URL=<pgvector DATABASE_PUBLIC_URL>
PYTHONPATH=services/backend:. python3 tools/parity/projection_diff.py
--audit-all-users --persist-to _phase02_parity_audit`

```text
AUDIT_RUN_ID=36b085bc-acd5-4910-893d-bf745e6daac7
USERS_AUDITED=143
USERS_WITH_DIFF=0
PERSISTED_ROWS=143
```

Post-check:

```text
AUDIT_ROWS=143
AUDIT_DIFF_ROWS=0
```

## Backfill x2

The staging runtime DB has `snapshots=0`, so the backfill is a no-op against
historical data. This matches the deploy plan assumption that staging has users
but no historical snapshots.

Dry run:

```json
{
  "dry_run": true,
  "errors": 0,
  "fact_events_skipped_idempotent": 0,
  "fact_events_written": 0,
  "snapshots_seen": 0
}
```

Apply run 1:

```json
{
  "dry_run": false,
  "errors": 0,
  "fact_events_skipped_idempotent": 0,
  "fact_events_written": 0,
  "snapshots_seen": 0
}
```

Apply run 2:

```json
{
  "dry_run": false,
  "errors": 0,
  "fact_events_skipped_idempotent": 0,
  "fact_events_written": 0,
  "snapshots_seen": 0
}
```

Post-check:

```text
FACT_EVENT_ROWS=0
FACT_CURRENT_ROWS=0
SNAPSHOT_ROWS=0
```

## Flag / Metrics Proof

```text
FF_FACT_EVENT_DUAL_WRITE=unset
FF_FACT_CURRENT_READ=unset
DATABASE_URL_TARGET=pgvector
```

`/metrics` exposes:

```text
mint_fact_event_insert_total
mint_dek_envelope_status_total
mint_projector_idempotency_skip_total 0.0
mint_snapshot_fact_current_drift_total
```

## Backfill Script Bug Found And Fixed

The first staging dry-run attempt found a real script bug:

```text
TypeError: get_backfill_engine() takes 0 positional arguments but 1 was given
```

Root cause: tests covered `backfill_user()` but not the CLI/run-backfill path.
Fix: `get_backfill_engine(database_url: str | None = None)` now honors the
explicit URL passed by the backfill script. Regression test:
`test_run_backfill_honors_explicit_database_url`.

Local proof after fix:

```text
ruff check app/core/database.py scripts/backfill_snapshot_to_fact_event.py tests/integration/test_backfill_idempotent.py
All checks passed

pytest tests/integration/test_backfill_idempotent.py -q
5 passed
```

## Interpretation

The staging DB schema, audit path, backfill no-op idempotence, flags, and Phase
02 metrics are now proven against the actual `MINT.DATABASE_URL` target. CJT-013
still remains a release blocker until prod/read-cutover decisions are handled:
prod probe, PR-3b/PR-4/PR-5 or explicit deferral, SnapshotModel decommission
decision, and final Phase 02 deploy report.
