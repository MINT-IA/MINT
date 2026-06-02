# CJT-013 Phase 02 Production Cutover Runbook — 2026-06-02

## Scope

This runbook is for closing CJT-013 only: Phase 02 event-log/fact-current
substrate must be either deployed to production with proof, or explicitly
deferred as a release blocker.

No new feature work is allowed in this runbook. The target is operational truth:
schema, migrations, flags, backfill, parity, metrics, and rollback/defer gates.

## Current Facts

Staging is proven on the real runtime DB:

- Railway staging `MINT` latest deployment: `1aa86ba1-42ae-4ace-9efa-d5d2a6ceb890`.
- Commit: `bfce5a14d6c06374fac47918fe26452646e2573a`.
- Root/config recovered correctly after the transient build view:
  `/services/backend`, `/services/backend/railway.json`, `/api/v1/health`.
- Health: `https://mint-staging.up.railway.app/api/v1/health` returns OK.
- DB target: `pgvector`.
- Alembic: `p120_fact_event_idempotency`.
- `_phase02_parity_audit`: 143 rows, 0 `diff_detected`.
- Flags: `FF_FACT_EVENT_DUAL_WRITE` and `FF_FACT_CURRENT_READ` remain unset.

Production is not Phase 02-ready:

- App health returns OK, but latest successful MINT production deploy is old:
  2026-03-30, commit `fe8fcd2497bd14aee2977c0756a0226ef813c211`.
- Later 2026-04-21 production deployments failed.
- DB target: `Postgres`.
- Alembic: `29_05_magic_link_tokens`.
- Data volume observed read-only: `users=2`, `snapshots=0`.
- Phase 02 tables are absent: `fact_event`, `fact_current`, `dek_envelope`,
  `_phase02_parity_audit`, `_phase02_parity_audit_continuous`.
- `waitlist_entries` is also absent, so production is behind more than Phase 02.

## Non-Negotiable Gates

Do not mark CJT-013 verified unless all gates below are green or the work is
explicitly deferred with a release decision.

1. Production deployment source is unambiguous:
   - branch/commit matches the intended staging promotion commit;
   - Railway service root is `/services/backend`;
   - Railway config file is `/services/backend/railway.json`;
   - healthcheck path is `/api/v1/health`;
   - start command includes `scripts/railway_pre_deploy_migrate.py`.
2. Production DB is inspected read-only before write:
   - `alembic_version`;
   - counts for `users`, `snapshots`, `fact_event`, `fact_current`,
     `_phase02_parity_audit`, `_phase02_parity_audit_continuous`,
     `waitlist_entries`;
   - flags are captured as set/unset, with secrets masked.
3. Migration runs once through the production deploy path, not by ad-hoc SQL.
4. Post-deploy production DB reaches the current Alembic head expected by code.
5. Backfill is run in dry-run mode first, then apply, then apply again:
   - second apply must be idempotent/no-op;
   - errors must be zero.
6. Full-user parity audit is persisted:
   - `_phase02_parity_audit` row count equals production user count;
   - zero rows have `diff_detected = true`.
7. Feature flags remain off unless a separate PR-3b/PR-4/PR-5 decision is made:
   - `FF_FACT_EVENT_DUAL_WRITE=unset/false`;
   - `FF_FACT_CURRENT_READ=unset/false`.
8. Metrics endpoint exposes Phase 02 counters after deploy.
9. A rollback/defer decision is recorded if any gate fails.

## Recommended Production Sequence

### 1. Freeze Promotion Target

Record the exact commit to promote. Recommended target as of this runbook:

```text
bfce5a14d6c06374fac47918fe26452646e2573a
```

If another commit is chosen, repeat staging health, DB, backfill, and parity
proof on that exact commit before production.

### 2. Preflight Production Read-Only

Capture without printing secrets:

```sh
railway service list --environment production --json
railway deployment list --service MINT --environment production --limit 5 --json
railway variable list --service MINT --environment production --json
```

For variables, only record masked targets such as:

```text
DATABASE_URL_TARGET=<service name only>
FF_FACT_EVENT_DUAL_WRITE=<set/unset>
FF_FACT_CURRENT_READ=<set/unset>
ENVIRONMENT=<value>
```

Probe DB counts using the target production database URL without echoing it.

### 3. Promote Backend

Promotion must use the normal Railway deploy path so
`scripts/railway_pre_deploy_migrate.py` runs. Do not hand-create tables.

After deploy, capture:

```sh
railway deployment list --service MINT --environment production --limit 2 --json
curl -fsS --max-time 10 https://mint-production-3a41.up.railway.app/api/v1/health
```

Required post-deploy shape:

```text
status=SUCCESS
rootDirectory=/services/backend
configFile=/services/backend/railway.json
healthcheckPath=/api/v1/health
startCommand includes railway_pre_deploy_migrate.py
health={"status":"ok"}
```

### 4. Post-Migration DB Proof

Required:

```text
ALEMBIC_VERSION=p120_fact_event_idempotency
TABLE fact_event exists=True
TABLE fact_current exists=True
TABLE fact_current.latest_event_id exists=True
TABLE _phase02_parity_audit exists=True
TABLE _phase02_parity_audit_continuous exists=True
```

If production remains at `29_05_magic_link_tokens`, stop. CJT-013 remains open.

### 5. Backfill And Idempotency

Run the tracked CLI against production in this order:

```sh
cd services/backend
python scripts/backfill_snapshot_to_fact_event.py --dry-run
python scripts/backfill_snapshot_to_fact_event.py
python scripts/backfill_snapshot_to_fact_event.py
```

Expected with the current read-only production data:

```text
snapshots_seen=0
written=0
errors=0
second_apply_written=0
```

If production data changed before cutover, update expected counts from the
preflight and require zero errors plus idempotent second apply.

### 6. Persist Production Parity Audit

Run:

```sh
PYTHONPATH=services/backend:. python3 tools/parity/projection_diff.py \
  --audit-all-users \
  --persist-to _phase02_parity_audit
```

Required:

```text
users_audited == production_users_count
diff_detected_rows == 0
```

### 7. Flag Decision

For CJT-013 closure, flags can remain off. Do not flip read/write traffic to
Phase 02 in the same operational step unless there is a separate reviewed
decision for PR-3b/PR-4/PR-5.

Required record:

```text
FF_FACT_EVENT_DUAL_WRITE=unset/false
FF_FACT_CURRENT_READ=unset/false
PR-3b/PR-4/PR-5=<deferred|approved with separate evidence>
SnapshotModel decommission=<deferred|approved with separate evidence>
```

## Rollback / Defer Criteria

Defer production promotion if any of these are true:

- Production Railway deploy does not pick `/services/backend/railway.json`.
- Healthcheck fails after deploy.
- Alembic migration does not reach the expected head.
- Backfill has any error.
- Second backfill apply is not idempotent.
- Any persisted parity row has `diff_detected = true`.
- Metrics endpoint does not expose Phase 02 counters.
- Required production variables are ambiguous or point to the wrong DB service.

Rollback action is environment-specific and must be recorded with deployment ID.
If no safe rollback is available, leave CJT-013 open and mark production Phase
02 as explicitly deferred.

## Closure Evidence Required

Append a final section to
`staging-schema-drift-20260602.md` or a new production evidence file with:

- production deployment ID and commit;
- healthcheck output;
- masked production variables;
- post-migration table/count probe;
- backfill dry-run/apply/apply proof;
- persisted parity audit count and diff count;
- metrics proof;
- final flag/decommission decision.
