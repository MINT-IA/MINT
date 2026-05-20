---
phase: mint-data-architecture-v1-02-deploy
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
  - tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz
  - tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz
  - tools/db/railway_pg_dump.sh
  - tools/checks/alembic_partition_safety_lint.py
  - tools/checks/tests/test_alembic_partition_safety_lint.py
  - services/backend/alembic/versions/p120_fact_event_idempotency.py
  - services/backend/app/models/fact_current.py
  - services/backend/app/services/projector/fact_projector.py
  - services/backend/app/api/v1/endpoints/audit_mobile.py
  - services/backend/app/observability/counters.py
  - services/backend/tests/integration/test_projector_idempotency_replay_skip.py
  - services/backend/tests/integration/test_projector_natural_key_pk_collision.py
  - services/backend/tests/integration/test_dual_write_replay_safe.py
  - services/backend/tests/integration/test_audit_mobile_event_id_passthrough.py
  - services/backend/tests/integration/test_fact_projector_jsonb_postgres.py
  - services/backend/tests/integration/test_dual_write_failure_rollback.py
  - services/backend/tests/integration/test_hmac_pepper_rotation.py
  - services/backend/tests/conftest.py
  - lefthook.yml
  - .github/workflows/deploy-backend.yml
autonomous: true
requirements:
  - D-27
  - D-33
requirements_addressed:
  - HANDOFF#PR-A2 D-27 EXACT-EQUALITY idempotency (latest_event_id col + IntegrityError catch + audit_mobile event_id passthrough)
  - HANDOFF#PR-A3 JSONB cast + dual-write rollback + hmac pepper rotation tests
  - HANDOFF#PR-B observability infra (drift counter declaration + alembic_partition_safety_lint + lefthook caplog rule + railway_pg_dump.sh + conftest health-check + KMS_KEY_ID naming audit + branch protection)
  - HANDOFF#PR-D staging Postgres orphan service audit (delete deferred to Wave 3 Plan 04)
  - VALIDATION#Wave-0-prerequisites (14 wave-0 gaps)
threat_model_ref: mint-data-architecture-v1-02-deploy-RESEARCH#Security-Domain (ASVS V2+V4+V5+V6+V7 + engram #194)

decisions_locked:
  - id: open-q-1
    locked: "Prod alembic gap = `29_05_magic_link_tokens` → `p119_phase02_parity_cont` = 14 linear revisions, 1 merge node (`p98_merge_p86_eclairage`). NOT a fork — devops-troubleshooter resolved (HANDOFF). Audit enumerates via `ScriptDirectory.walk_revisions` API."
    rationale: "devops finding HANDOFF + RESEARCH §Summary line 44 confirmed via Pattern A code example."
  - id: open-q-3
    locked: "Baseline pg_dump strategy = `tools/db/railway_pg_dump.sh` (this plan ships it). Pre-Wave-1 staging dump committed to `tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz` ; pre-Wave-4 prod dump to `tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz`. Retention = last 3 + monthly snapshot."
    rationale: "Phase-decision-lock orchestrator instruction + RESEARCH §Don't-Hand-Roll line 372."

must_haves:
  truths:
    - "Alembic gap from prod head `29_05_magic_link_tokens` to dev head `p119_phase02_parity_cont` is fully enumerated in `chain-audit.txt` (14 linear revs + 1 merge node)."
    - "Each revision in the chain has a documented forward-compat note + downgrade path. Test : `alembic downgrade -1` cycle exits 0 on the staging baseline replay."
    - "Pre-Wave-1 staging baseline + pre-Wave-4 prod baseline pg_dump are captured + committed under `tools/db/baselines/`."
    - "PR A2 D-27 EXACT-EQUALITY idempotency lands : `fact_current.latest_event_id String(36) NULL` col added via alembic p120 ; projector catches `IntegrityError` on PK collision and increments `mint_projector_idempotency_skip_total` ; `audit_mobile.py` accepts caller-supplied `event_id` ; 3+1 integration tests green."
    - "PR A3 lands : JSONB cast `CAST(:value_enc AS jsonb)` dialect-branched ; dual-write rollback test green ; hmac pepper rotation test green."
    - "PR B observability infra lands : `mint_snapshot_fact_current_drift_total` counter declared ; `alembic_partition_safety_lint.py` AST walk lints PARTITION BY+PK partition-col-in-key + FK NOT VALID on partitioned ; lefthook rule bans `fileConfig(` without `disable_existing_loggers=False` ; `railway_pg_dump.sh` ships ; conftest session-scope fixture asserts critical loggers `.disabled is False` ; KMS_KEY_ID vs MINT_KMS_KEY_ID naming audit captured."
  artifacts:
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt"
      provides: "Deterministic prod→dev alembic chain audit output via ScriptDirectory.walk_revisions API"
      min_lines: 30
    - path: "tools/db/railway_pg_dump.sh"
      provides: "Railway pg_dump helper supporting staging+production envs with secret-scanning safety"
      min_lines: 40
      contains: "pg_dump --no-comments --no-owner --no-privileges"
    - path: "tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz"
      provides: "Pre-Wave-1 staging baseline (rollback anchor)"
    - path: "tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz"
      provides: "Pre-Wave-4 prod baseline (rollback anchor — captured today even though prod-apply is Wave 4)"
    - path: "tools/checks/alembic_partition_safety_lint.py"
      provides: "AST walk lint banning PARTITION BY without PK partition-col-in-key (postgres-pro E2)"
      min_lines: 50
    - path: "services/backend/alembic/versions/p120_fact_event_idempotency.py"
      provides: "Additive migration : `fact_current.latest_event_id String(36) NULL`"
      min_lines: 25
    - path: "services/backend/tests/integration/test_projector_idempotency_replay_skip.py"
      provides: "D-27 EXACT-EQUALITY skip semantics test (PK collision path)"
      min_lines: 40
    - path: "services/backend/tests/integration/test_dual_write_failure_rollback.py"
      provides: "PR A3 pg_fixture rollback atomicity test (DEK-revoked mid-loop)"
      min_lines: 40
    - path: "services/backend/app/observability/counters.py"
      provides: "Adds `mint_snapshot_fact_current_drift_total` counter declaration (PR B step 1)"
      contains: "mint_snapshot_fact_current_drift_total"
  key_links:
    - from: "services/backend/app/services/projector/fact_projector.py::project_event"
      to: "services/backend/app/observability/counters.py::mint_projector_idempotency_skip_total"
      via: "PK collision IntegrityError catch increments counter then returns event_id cleanly"
      pattern: "mint_projector_idempotency_skip_total\\.inc\\("
    - from: "services/backend/app/api/v1/endpoints/audit_mobile.py"
      to: "services/backend/app/services/projector/fact_projector.py::project_event"
      via: "audit_mobile POST accepts caller-supplied event_id + passes through to projector (Mobile L1 retry path)"
      pattern: "project_event\\(.*event_id="
    - from: "tools/checks/alembic_partition_safety_lint.py"
      to: "services/backend/alembic/versions/p98_fact_event_projection.py"
      via: "AST walk validates PARTITION BY tables include partition col in PK + ban FK NOT VALID on partitioned parent"
      pattern: "PARTITION BY"
    - from: "lefthook.yml"
      to: "services/backend/alembic/env.py"
      via: "pre-push rule greps `fileConfig\\(` and exits 1 if `disable_existing_loggers=False` not on same/next line"
      pattern: "disable_existing_loggers=False"
---

<objective>
Wave 0 — chaîne alembic auditée + baselines pg_dump captées + 4-PR cleanup pré-requis (A2 D-27 idempotency + A3 JSONB cast / rollback / pepper rotation tests + B observability infra). Aucun migrate appliqué à un environnement déployé dans ce plan : tout est code + audit + tests + lints + baselines.

Purpose : verrouiller le filet déterministe (audit chaîne + pg_dump baselines) ET fermer les 3 bugs systémiques détectés par le panel 5-agent (D-27 sémantique impossible sur UUID4, _json_bind masqué par SQLite, drift counter référencé jamais déclaré) AVANT que Wave 1 ne touche staging. PR A4 (Mobile L1) appartient à Wave 3 par locked decision #5.

Output : chain-audit.txt + 2 fichiers baselines .sql.gz + alembic p120 migration (additive `latest_event_id` col) + 7 tests integration + 1 nouveau lint AST + 1 conftest health-check + counter `mint_snapshot_fact_current_drift_total` déclaré + lefthook rule caplog-prevention + audit naming KMS_KEY_ID.

PR mapping (4 PRs séquentiels par locked decision #6 — A2 + A3 partagent fact_projector.py donc pas de parallélisme) :
- PR A2 → Task 1 (D-27 idempotency : alembic p120 + projector IntegrityError catch + audit_mobile event_id passthrough + 4 integration tests)
- PR A3 → Task 2 (JSONB cast + 2 pg_fixture tests : rollback + pepper rotation)
- PR B → Task 3 (drift counter declaration + 2 lints + railway_pg_dump.sh + conftest health-check + KMS naming audit)
- Wave 0 close → Task 4 (chain audit déterministe via ScriptDirectory.walk_revisions + 2 baseline pg_dumps captés)

Out of scope this plan :
- Aucun `alembic upgrade head` sur un env déployé (Wave 1+).
- Pas de Sentry alert rule wiring (Wave 3 Plan 04 + Julien-only UI task).
- Pas de PR D polish (absorbée Wave 3 Plan 04 final-wave tasks).
- Pas de branch protection promotion (Julien-only UI task, doc dans runbook Wave 3).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md
@services/backend/Procfile
@services/backend/alembic/env.py
@services/backend/alembic/versions/p98_fact_event_projection.py
@services/backend/app/services/projector/fact_projector.py
@services/backend/app/observability/counters.py
@services/backend/app/api/v1/endpoints/audit_mobile.py
@services/backend/scripts/railway_pre_deploy_migrate.py

<interfaces>
<!-- Contracts the executor MUST respect (extraction from RESEARCH §Patterns 1-6 + Code Examples A-E). -->

State after Phase 02 substrate (PR #653 #657 #656 #655 #658 squash-merged dev HEAD `5210bf07`) :

`services/backend/app/services/projector/fact_projector.py::project_event(session, event)` :
- Currently emits UUID4 random event_id internally (line ~110).
- `_json_bind(value)` returns `json.dumps(...)` string — passed to `text()` raw SQL bind for `value_enc` column (line ~186-195).
- Sec FLAG-1 post-write divergence assertion lives at lines 151-181 (DO NOT DELETE — defense-in-depth retained per RESEARCH Anti-Patterns).
- No `event_id` parameter on signature (PR A2 adds it).
- No `IntegrityError` catch path (PR A2 adds it).

`services/backend/app/models/fact_current.py` :
- Columns : user_id, field_key, value_enc, value_hash, dek_id, recorded_at, updated_at.
- NO `latest_event_id` column (PR A2 adds it via alembic p120).

`services/backend/app/api/v1/endpoints/audit_mobile.py` :
- POST `/v1/audit_mobile` accepts AuditEventBatch payload (Pydantic v2).
- Does NOT accept caller-supplied event_id today (PR A2 bonus adds it for Mobile L1 retry idempotency).

`services/backend/app/observability/counters.py` lines 24-103 :
- 8 counters declared (verified RESEARCH §Don't-Hand-Roll + grep 2026-05-19) :
  1. `mint_fact_event_insert_total`
  2. `mint_fact_current_read_latency_ms` (Histogram)
  3. `mint_dek_envelope_status_total{status}`
  4. `mint_anonymous_session_link_total{outcome}`
  5. `mint_projector_idempotency_skip_total`
  6. `mint_constants_version_mismatch_total`
  7. `mint_kms_backend_failure_total` (iter-2 A4)
  8. `mint_dek_cache_size_total` (iter-2 A5)
- `mint_snapshot_fact_current_drift_total` IS NOT declared (PR B step 1 adds it as `Counter(name, doc, labelnames=['field_key'])`).
- Soft-import prometheus_client fallback NoOp pattern at lines 24-46.

`services/backend/alembic/env.py` lines 25-30 :
- `fileConfig(config.config_file_name, disable_existing_loggers=False)` already in place (PR #658 root-cause fix).

`services/backend/alembic.ini` :
- Single head verified : `p119_phase02_parity_cont`.

`services/backend/Procfile` :
- `web: sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8080} --timeout 120'`
- Race condition neutralised by `-w 1` (per RESEARCH Pattern 1).

`services/backend/alembic/versions/p98_fact_event_projection.py` :
- `CREATE TABLE fact_event (event_id UUID, user_id VARCHAR, ..., PRIMARY KEY (event_id, user_id)) PARTITION BY HASH (user_id);`
- Composite PK satisfies natural-key UNIQUE for D-27 EXACT-EQUALITY (per locked decision HANDOFF #2-3).
- 8 hash partitions (`fact_event_p_0` through `fact_event_p_7`).

`tools/checks/banned_terms_python.py` :
- Already extended Phase 02 substrate (PR #655 — fact_event JSONB shape).

`services/backend/scripts/railway_pre_deploy_migrate.py` :
- Bootstraps baseline stamp via `_bootstrap_alembic_if_needed()` (checks SENTINEL_TABLES users/audit_events/profiles).
- Runs `alembic upgrade head` via `subprocess.run(['alembic', 'upgrade', 'head'], check=True)`.
- Rollback : if upgrade fails, gunicorn ne démarre PAS, Railway garde la version précédente.
</interfaces>
</context>

<decision_locked>
- **Open-Q #1 (prod alembic gap reason)** — LOCKED : « No merges to main since 2026-04-21 » per devops-troubleshooter (HANDOFF). PAS un fork, PAS une divergence. 14 linear revs + 1 merge node. Task 4 enumère déterministiquement via `ScriptDirectory.walk_revisions`.
- **Open-Q #3 (baseline pg_dump strategy)** — LOCKED : `tools/db/railway_pg_dump.sh` ships in this plan. Pre-Wave-1 staging + pre-Wave-4 prod baselines captured Wave 0 (today, even though prod-apply is Wave 4 — capturing early is the rollback insurance). Retention : last 3 + monthly snapshot.
- **Open-Q #6 (PR ordering)** — LOCKED HANDOFF #6 : A2 → A3 → A4 (Wave 3) → B → D (Wave 3 Plan 04). A2/A3 share fact_projector.py — strictly serial. This plan delivers A2 + A3 + B (all backend) ; A4 deferred to Wave 3 (Plan 04) for Mobile L1 design panel + iOS entitlement isolation.
- **Open-Q #7 (D-27 semantics)** — LOCKED HANDOFF #2 : D-27 idempotency = EXACT-EQUALITY via PK collision (NOT « event_id ≤ latest_event_id » — UUID4 is random, not monotone). Mobile L1 supplies stable UUIDs for retry. UUID7 migration decoupled (arch FLAG-2 deferred Phase 03).
</decision_locked>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1 (PR A2) : D-27 EXACT-EQUALITY idempotency — alembic p120 latest_event_id col + projector IntegrityError catch + audit_mobile event_id passthrough + 4 integration tests</name>
  <files>
    services/backend/alembic/versions/p120_fact_event_idempotency.py,
    services/backend/app/models/fact_current.py,
    services/backend/app/services/projector/fact_projector.py,
    services/backend/app/api/v1/endpoints/audit_mobile.py,
    services/backend/tests/integration/test_projector_idempotency_replay_skip.py,
    services/backend/tests/integration/test_projector_natural_key_pk_collision.py,
    services/backend/tests/integration/test_dual_write_replay_safe.py,
    services/backend/tests/integration/test_audit_mobile_event_id_passthrough.py
  </files>
  <read_first>
    services/backend/app/services/projector/fact_projector.py (current shape — line ~100 `project_event` signature, line ~186 `_json_bind`, line ~151 sec FLAG-1 — DO NOT touch the sec FLAG-1 block per RESEARCH Anti-Patterns),
    services/backend/app/models/fact_current.py (current columns to extend with `latest_event_id`),
    services/backend/app/api/v1/endpoints/audit_mobile.py (POST handler to extend with optional event_id),
    services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py (head — p120 chains off this),
    services/backend/app/observability/counters.py (line 24-103 — `mint_projector_idempotency_skip_total` already declared),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern 3 D-27 idempotency redéfinie EXACT-EQUALITY + §Pattern D verbatim Python snippet + §Pitfall 7 UUID4 monotonicity caveat),
    .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md (PR A2 design ~177 LOC + lock decision #2/#3)
  </read_first>
  <behavior>
    - test_projector_idempotency_replay_skip : same event_id replayed on `project_event` → 0 new fact_event rows + `mint_projector_idempotency_skip_total` increments +1 + function returns event_id cleanly (no exception leaked).
    - test_projector_natural_key_pk_collision : insert FactEvent with (event_id=A, user_id=U), then call project_event with same A+U on a fresh nested session → IntegrityError caught, skip counter +1, fact_event count remains 1.
    - test_dual_write_replay_safe : full integration through `snapshot_service.create_snapshot()` with `FF_FACT_EVENT_DUAL_WRITE=on` SQLite override ; invoke create_snapshot twice with same canary inputs → second call increments idempotency counter +N (where N = 5 canary field_keys) ; no duplicate rows in fact_event.
    - test_audit_mobile_event_id_passthrough : POST `/v1/audit_mobile` with caller-supplied event_id `evt-stable-001` ; second POST same payload + same event_id → server returns 200 both times ; fact_event row count = 1 + idempotency_skip counter +1 on the second call.
  </behavior>
  <action>
1. **`services/backend/alembic/versions/p120_fact_event_idempotency.py` (NEW, ~30 LOC)** — additive migration adding `latest_event_id` column to `fact_current` :

```python
"""p120 fact_current idempotency latest_event_id

Revision ID: p120_fact_event_idempotency
Revises: p119_phase02_parity_cont
Create Date: 2026-05-19

D-27 EXACT-EQUALITY idempotency : adds `latest_event_id` column to `fact_current`.
Per HANDOFF locked decision #2-3 : composite PK (event_id, user_id) on fact_event
already enforces natural-key UNIQUE ; this migration only adds the `latest_event_id`
tracker column. NO new UNIQUE constraint on fact_event.
"""
from alembic import op
import sqlalchemy as sa

revision = "p120_fact_event_idempotency"
down_revision = "p119_phase02_parity_cont"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "fact_current",
        sa.Column("latest_event_id", sa.String(length=36), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("fact_current", "latest_event_id")
```

2. **`services/backend/app/models/fact_current.py`** — add `latest_event_id` to ORM (mirror alembic) :

```python
# After existing columns (recorded_at / updated_at lines), add :
latest_event_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
```

3. **`services/backend/app/services/projector/fact_projector.py`** — verbatim per RESEARCH §Pattern D + locked decision #2 :

   a. Add import : `from sqlalchemy.exc import IntegrityError` (if not already).
   b. Add `event_id: Optional[str] = None` to `project_event(session, event, *, event_id=None)` signature — when None, generate UUID4 internally (preserves current behavior for non-Mobile callers).
   c. Around the `session.add(FactEvent(...))` + `session.flush()` block, wrap in `try/except IntegrityError` :

```python
def project_event(session, event, *, event_id: Optional[str] = None) -> str:
    event_id = event_id or str(uuid4())
    try:
        with session.begin_nested():
            fe = FactEvent(
                event_id=event_id,
                user_id=event.user_id,
                field_key=event.field_key,
                value_enc=event.value_enc,
                # ... existing fields unchanged ...
            )
            session.add(fe)
            session.flush()
            # ── existing UPSERT fact_current ─────────────────────
            # NEW (D-27 PR A2) : update fact_current.latest_event_id
            session.execute(
                text(
                    "UPDATE fact_current SET latest_event_id = :eid "
                    "WHERE user_id = :uid AND field_key = :fk"
                ),
                {"eid": event_id, "uid": event.user_id, "fk": event.field_key},
            )
    except IntegrityError as ie:
        # PK collision on (event_id, user_id) = replay → idempotent skip
        msg = str(getattr(ie.orig, "pgerror", "")) + str(ie.orig)
        if "fact_event_pkey" in msg or "UNIQUE constraint failed: fact_event" in msg:
            mint_projector_idempotency_skip_total.inc()
            return event_id
        raise
    return event_id
```

   d. DO NOT touch the sec FLAG-1 post-write divergence assertion (lines 151-181 in current file) per RESEARCH Anti-Patterns. PR D may revisit Phase 03+.

4. **`services/backend/app/api/v1/endpoints/audit_mobile.py`** — bonus per HANDOFF PR A2 step 5 + locked decision #6 :

   a. Pydantic v2 schema : add `event_id: Optional[str] = Field(default=None, max_length=36, pattern=r'^[0-9a-fA-F\-]{36}$')` field to the `AuditEvent` (singular item in `AuditEventBatch`).
   b. Endpoint handler : for each event in batch, pass `event_id=event.event_id` through to `project_event(session, event, event_id=event.event_id)`.
   c. NEVER leak the IntegrityError detail to client : the projector catches it and returns the event_id ; endpoint returns 200 always for idempotent replays.
   d. Update OpenAPI canonical regen : run `python3 services/backend/scripts/generate_canonical.py` after the Pydantic change (per memory `feedback_pre_push_checklist`).

5. **`services/backend/tests/integration/test_projector_idempotency_replay_skip.py` (NEW, ≥40 LOC)** — pg_fixture-free SQLite path :
   - Setup : create User, call `project_event(session, event_a, event_id='evt-001')` → assert 1 row in fact_event.
   - Replay : call `project_event(session, event_a, event_id='evt-001')` again → assert still 1 row + counter `mint_projector_idempotency_skip_total._value.get()` delta == 1 + return value == 'evt-001'.

6. **`services/backend/tests/integration/test_projector_natural_key_pk_collision.py` (NEW, ≥40 LOC)** — `requires_pg` marker, pg_fixture :
   - Setup : INSERT raw `fact_event` row with `(event_id='evt-X', user_id='U-X', ...)`.
   - Call `project_event(session, event_X, event_id='evt-X')` → assert IntegrityError caught silently, counter +1, fact_event row count == 1.

7. **`services/backend/tests/integration/test_dual_write_replay_safe.py` (NEW, ≥60 LOC)** — pg_fixture :
   - Setup : `FF_FACT_EVENT_DUAL_WRITE=on` (monkeypatch env), create SnapshotModel canary row.
   - Invoke `snapshot_service.create_snapshot(canary_inputs)` → assert 5 fact_event rows + 5 fact_current rows.
   - Invoke again same inputs → assert still 5 fact_event rows + idempotency_skip counter delta == 5.

8. **`services/backend/tests/integration/test_audit_mobile_event_id_passthrough.py` (NEW, ≥40 LOC)** — pg_fixture + FastAPI TestClient :
   - POST `/v1/audit_mobile` with `event_id='evt-mobile-A'` → assert 200, fact_event count == 1.
   - POST again same event_id → assert 200, fact_event count == 1, idempotency_skip counter delta == 1.

9. **Pre-push checklist (per memory `feedback_pre_push_checklist`)** :
   - `grep -rn "project_event(" services/backend/` — update ALL callers if signature added a kwarg (here optional, so backwards-compat) ; confirm no break.
   - `python3 services/backend/scripts/generate_canonical.py` — regen OpenAPI canonical after Pydantic schema change.
   - `cd services/backend && python3 -m pytest tests/ -q -x --timeout=120` BEFORE the commit (no « clean » claim before exit 0).
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_projector_idempotency_replay_skip.py tests/integration/test_projector_natural_key_pk_collision.py tests/integration/test_dual_write_replay_safe.py tests/integration/test_audit_mobile_event_id_passthrough.py -q --timeout=120 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/projector/ services/backend/app/api/v1/endpoints/audit_mobile.py && python3 tools/checks/accent_lint_fr.py --scope backend && cd services/backend && alembic upgrade head && alembic downgrade -1 && alembic upgrade head</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "latest_event_id" services/backend/app/models/fact_current.py` returns ≥1 match.
    - `grep -n "except IntegrityError" services/backend/app/services/projector/fact_projector.py` returns ≥1 match.
    - `grep -n "fact_event_pkey\\|UNIQUE constraint failed: fact_event" services/backend/app/services/projector/fact_projector.py` returns ≥2 matches (handling both Postgres + SQLite error strings).
    - `grep -n "event_id" services/backend/app/api/v1/endpoints/audit_mobile.py` returns ≥3 matches (Pydantic field + handler param + passthrough).
    - `cd services/backend && python3 -m pytest tests/integration/test_projector_idempotency_replay_skip.py tests/integration/test_projector_natural_key_pk_collision.py tests/integration/test_dual_write_replay_safe.py tests/integration/test_audit_mobile_event_id_passthrough.py -q` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=120` exits 0 (full backend regression — delta vs Plan 02-04 substrate baseline 7515 = +4 new tests).
    - `cd services/backend && alembic upgrade head` exits 0 ; `alembic current` shows `p120_fact_event_idempotency`.
    - `cd services/backend && alembic downgrade -1 && alembic upgrade head` exits 0 (down/up cycle clean).
    - `python3 services/backend/scripts/generate_canonical.py` exits 0 (OpenAPI canonical regenerated).
    - Sec FLAG-1 post-write divergence assertion preserved : `grep -n "post-write divergence" services/backend/app/services/projector/fact_projector.py` returns ≥1 match (not deleted per Anti-Patterns).
    - `git diff services/backend/app/services/projector/fact_projector.py` shows ONLY the IntegrityError block + event_id param addition + latest_event_id UPDATE (no drift refactor).
  </acceptance_criteria>
  <done>
    PR A2 D-27 EXACT-EQUALITY idempotency shipped : alembic p120 adds `fact_current.latest_event_id` ; projector catches PK collision IntegrityError + increments `mint_projector_idempotency_skip_total` + returns event_id cleanly ; `audit_mobile.py` accepts caller-supplied event_id for Mobile L1 retry. 4 integration tests green. Sec FLAG-1 defense-in-depth preserved. Backwards-compat verified (existing project_event callers unaffected — event_id kwarg optional).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (PR A3) : JSONB cast dialect-branched + dual-write rollback test + hmac pepper rotation test</name>
  <files>
    services/backend/app/services/projector/fact_projector.py,
    services/backend/tests/integration/test_fact_projector_jsonb_postgres.py,
    services/backend/tests/integration/test_dual_write_failure_rollback.py,
    services/backend/tests/integration/test_hmac_pepper_rotation.py
  </files>
  <read_first>
    services/backend/app/services/projector/fact_projector.py (line ~117-149 — current `_json_bind` string-bind pattern that masks the Postgres JSONB bug per RESEARCH §Pitfall 1),
    services/backend/app/services/encryption/key_vault.py (revoke_dek + get_or_create_dek surfaces — needed for rollback test),
    services/backend/app/services/audit/hmac_pepper.py (lru_cache(maxsize=1) + MINT_AUDIT_HASH_PEPPER env interaction — needed for rotation test),
    services/backend/tests/fixtures/pg_fixture.py (testcontainers-postgres harness from Plan 02-01),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern 4 JSONB cast verbatim snippet + §Pitfall 1 _json_bind masked-by-SQLite + §Don't-Hand-Roll cast inline vs adapter)
  </read_first>
  <behavior>
    - test_fact_projector_jsonb_postgres : pg_fixture invoke project_event on a fact_event with non-trivial JSONB payload (`{"key": "value", "nested": [1, 2, 3]}`) → INSERT succeeds + JSONB column readable as parsed JSON (not string). Without the dialect-branched cast, this test fails on real Postgres with « column "value_enc" is of type jsonb but expression is of type text ».
    - test_dual_write_failure_rollback : pg_fixture + monkeypatch `key_vault.encrypt_value` to raise mid-loop (after 2 of 5 canary field_keys projected) → assert snapshot_service.create_snapshot rolls back atomically : 0 snapshot rows + 0 fact_event rows + 0 fact_current rows (no partial state).
    - test_hmac_pepper_rotation : pg_fixture + write audit_event with pepper-v1 → monkeypatch MINT_AUDIT_HASH_PEPPER=pepper-v2 + invalidate `lru_cache(maxsize=1)` via `hmac_pepper.cache_clear()` → write second audit_event → assert the two user_id_hash values DIFFER (proves rotation took effect, no stale cache).
  </behavior>
  <action>
1. **`services/backend/app/services/projector/fact_projector.py`** — dialect-branched JSONB cast per RESEARCH §Pattern 4 verbatim :

   a. Locate the `text(...)` raw SQL block inserting `value_enc` (currently line ~117-149).
   b. Replace with :

```python
if session.bind.dialect.name == "postgresql":
    insert_sql = """
        INSERT INTO fact_current (user_id, field_key, value_enc, value_hash, dek_id, recorded_at, updated_at, latest_event_id)
        VALUES (:uid, :fk, CAST(:value_enc AS jsonb), :vh, :dek, :rec, :upd, :eid)
        ON CONFLICT (user_id, field_key) DO UPDATE SET
            value_enc = EXCLUDED.value_enc,
            value_hash = EXCLUDED.value_hash,
            dek_id = EXCLUDED.dek_id,
            updated_at = EXCLUDED.updated_at,
            latest_event_id = EXCLUDED.latest_event_id
    """
else:
    # SQLite (test path) — no JSONB type ; bind as string
    insert_sql = """
        INSERT INTO fact_current (user_id, field_key, value_enc, value_hash, dek_id, recorded_at, updated_at, latest_event_id)
        VALUES (:uid, :fk, :value_enc, :vh, :dek, :rec, :upd, :eid)
        ON CONFLICT (user_id, field_key) DO UPDATE SET
            value_enc = excluded.value_enc,
            value_hash = excluded.value_hash,
            dek_id = excluded.dek_id,
            updated_at = excluded.updated_at,
            latest_event_id = excluded.latest_event_id
    """
session.execute(text(insert_sql), {
    "uid": event.user_id,
    "fk": event.field_key,
    "value_enc": _json_bind(event.value_enc),  # returns str
    "vh": event.value_hash,
    "dek": event.dek_id,
    "rec": event.recorded_at,
    "upd": event.updated_at,
    "eid": event_id,
})
```

   c. Same dialect-branch pattern applies to the `fact_event` INSERT if it also uses `text()` with JSONB column (audit fact_event `value_enc` column).
   d. Do NOT register `psycopg2.extras.Json` globally (per RESEARCH §Don't-Hand-Roll — global adapter discouraged).

2. **`services/backend/tests/integration/test_fact_projector_jsonb_postgres.py` (NEW, ≥40 LOC, `@pytest.mark.requires_pg`)** :
   - Setup : pg_fixture session, create test User + DEK.
   - Build FactEvent with `value_enc = {"text": "test", "nested": {"a": [1, 2]}, "decimal": "12345.67"}` (non-trivial JSONB).
   - Call `project_event(session, event)` → assert 1 fact_event row + 1 fact_current row.
   - Re-fetch fact_current row → assert `row.value_enc` is dict (not str) — JSONB native.
   - Negative path : monkeypatch `session.bind.dialect.name` → 'unknown' → assert fallback to SQLite-style bind (regression check).

3. **`services/backend/tests/integration/test_dual_write_failure_rollback.py` (NEW, ≥50 LOC, `@pytest.mark.requires_pg`)** :
   - Setup : pg_fixture + monkeypatch FF_FACT_EVENT_DUAL_WRITE=on + canary inputs (5 field_keys).
   - Monkeypatch `key_vault.encrypt_value` to raise `RuntimeError("DEK revoked mid-loop")` on the 3rd call (after 2 successful projects).
   - Invoke `snapshot_service.create_snapshot(canary_inputs)` → expect RuntimeError to propagate.
   - Assert : `SELECT count(*) FROM snapshots WHERE user_id=:u` → 0 ; `SELECT count(*) FROM fact_event WHERE user_id=:u` → 0 ; `SELECT count(*) FROM fact_current WHERE user_id=:u` → 0 (full atomic rollback — `session.begin_nested()` contract).

4. **`services/backend/tests/integration/test_hmac_pepper_rotation.py` (NEW, ≥40 LOC, `@pytest.mark.requires_pg`)** :
   - Setup : pg_fixture + monkeypatch.setenv("MINT_AUDIT_HASH_PEPPER", "pepper-v1-test-32-chars-padding-aaaa") + invalidate `from app.services.audit.hmac_pepper import hmac_user_id; hmac_user_id.cache_clear()`.
   - Write audit_event for user_id=U → capture `audit_events.user_id_hash` = H1.
   - monkeypatch.setenv("MINT_AUDIT_HASH_PEPPER", "pepper-v2-test-32-chars-padding-bbbb") + `hmac_user_id.cache_clear()` (verify lru_cache(maxsize=1) flushes).
   - Write audit_event for user_id=U → capture `audit_events.user_id_hash` = H2.
   - Assert H1 != H2 (proves rotation took effect post-cache-clear).
   - Negative path : without `cache_clear()` after env change, second hash would equal H1 — document this in test docstring.

5. **Pre-push checklist** :
   - `grep -rn "session.bind.dialect" services/backend/app/services/projector/` confirm 1 hit only (no drift).
   - `cd services/backend && python3 -m pytest tests/ -q --timeout=120` BEFORE the commit.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_fact_projector_jsonb_postgres.py tests/integration/test_dual_write_failure_rollback.py tests/integration/test_hmac_pepper_rotation.py -q -k pg --timeout=120 && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/projector/ && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "CAST(:value_enc AS jsonb)" services/backend/app/services/projector/fact_projector.py` returns ≥1 match (dialect-branched cast in place).
    - `grep -n "session.bind.dialect.name == \"postgresql\"" services/backend/app/services/projector/fact_projector.py` returns ≥1 match (dialect branch).
    - `cd services/backend && python3 -m pytest tests/integration/test_fact_projector_jsonb_postgres.py -q -k pg` exits 0 (the test that previously would FAIL without the cast).
    - `cd services/backend && python3 -m pytest tests/integration/test_dual_write_failure_rollback.py -q -k pg` exits 0.
    - `cd services/backend && python3 -m pytest tests/integration/test_hmac_pepper_rotation.py -q -k pg` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression).
    - Sec FLAG-1 post-write divergence assertion preserved (`grep -n "post-write divergence" services/backend/app/services/projector/fact_projector.py` returns ≥1 match).
    - No `psycopg2.extras.Json` global adapter registered (`grep -rn "register_default_jsonb\\|extras.Json" services/backend/app/` returns 0 matches outside test files).
  </acceptance_criteria>
  <done>
    PR A3 JSONB cast + rollback + pepper rotation shipped. Dialect-branched `CAST(:value_enc AS jsonb)` on Postgres ; SQLite test path preserved. 3 pg_fixture integration tests prove (a) JSONB cast survives real Postgres, (b) dual-write rollback is atomic on mid-loop failure, (c) hmac pepper rotation flushes lru_cache. RESEARCH §Pitfall 1 closed.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3 (PR B) : Observability infrastructure — drift counter declaration + alembic_partition_safety_lint + caplog lefthook rule + railway_pg_dump.sh + conftest health-check + KMS_KEY_ID naming audit</name>
  <pr_rationale>
    Per checker iteration 1 H-7 fix : PR B is intentionally a single « mega-PR » with 9 sub-items + 14 acceptance criteria. Rationale for keeping it as one PR (not splitting) :
    - Infrastructure setup is atomic : the 9 items (counter declaration + 2 lints + railway_pg_dump.sh + lefthook caplog rule + conftest health-check + KMS naming audit + alembic head verification CI step) belong to the same « Wave 0 substrate hardening » concern.
    - Lefthook rules ship with their tests : splitting `alembic_partition_safety_lint.py` from its `lefthook.yml` registration would leave one PR in an unverifiable state.
    - KMS_KEY_ID naming audit + Prometheus scrape + branch protection are config-only : no code dependency between them, but bundling avoids 3 separate review cycles for trivial config.
    - `alembic_partition_safety_lint` ships with its 2 lint targets (PARTITION BY + FK NOT VALID) as a single AST-walk module — splitting would force 2 import points.
    Keep as a single PR. Documented per checker H-7 fix to surface the rationale.
  </pr_rationale>
  <files>
    services/backend/app/observability/counters.py,
    tools/checks/alembic_partition_safety_lint.py,
    tools/checks/tests/test_alembic_partition_safety_lint.py,
    tools/db/railway_pg_dump.sh,
    lefthook.yml,
    services/backend/tests/conftest.py,
    .github/workflows/deploy-backend.yml,
    .planning/phases/mint-data-architecture-v1-02-deploy/kms-naming-audit.txt
  </files>
  <read_first>
    services/backend/app/observability/counters.py (lines 24-103 — current 8 counters declared ; `mint_snapshot_fact_current_drift_total` confirmed absent via grep 2026-05-19 per RESEARCH §Pitfall 6),
    services/backend/alembic/versions/p98_fact_event_projection.py (reference impl for what `alembic_partition_safety_lint.py` must validate — PARTITION BY HASH (user_id) + PK including user_id),
    services/backend/alembic/env.py (lines 25-30 — `disable_existing_loggers=False` already in place per RESEARCH §Pattern 6 ; the lefthook rule prevents regressions),
    services/backend/tests/conftest.py (current shape — extend with session-scope health-check fixture),
    services/backend/app/services/encryption/key_vault.py (KMS_KEY_ID vs MINT_KMS_KEY_ID call sites — audit naming),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pitfall 2 partition FK + §Pitfall 6 drift counter missing + §Pattern 6 caplog env.py + §Don't-Hand-Roll pg_dump shell script + §Code Example E alembic head verification),
    .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md (PR B 9-step inventory)
  </read_first>
  <behavior>
    - `mint_snapshot_fact_current_drift_total` declared in `counters.py` + visible in `/metrics` endpoint after counter wire-up in `continuous_drift_sampler.py` (the cron is where the increment happens — Wave 2 lit-up).
    - `alembic_partition_safety_lint.py` AST-walk : reads alembic/versions/*.py ; for any migration containing `PARTITION BY HASH (col)` validates that the same `col` is in the PRIMARY KEY of the create-table statement ; ALSO bans `ADD CONSTRAINT ... FOREIGN KEY ... NOT VALID` on parent partitioned table (must loop partitions per Pitfall 2). Fixtures : 1 good migration (p98-like) + 1 bad migration (missing partition col in PK) ; lint exits 0 on good, exit 1 on bad with explicit diagnostic.
    - lefthook rule `caplog-disable-existing-loggers` : pre-commit grep `fileConfig\(` in alembic/env.py + greps next line for `disable_existing_loggers=False` ; exit 1 if missing.
    - `railway_pg_dump.sh staging` : invokes `railway ssh -e staging --service MINT 'pg_dump --no-comments --no-owner --no-privileges $DATABASE_URL' | gzip > tools/db/baselines/staging-{date}-pre-deploy.sql.gz` ; greps for `password|api_key|secret` in output before commit ; exits 1 if any secret hit.
    - conftest health-check : session-scope autouse fixture asserts `logging.getLogger('app.services.projector').disabled is False` + same for 5+ key app loggers ; raises at session-start if regressed.
    - KMS naming audit : produces `kms-naming-audit.txt` listing every `KMS_KEY_ID` vs `MINT_KMS_KEY_ID` reference + recommendation (canonicalize on `MINT_KMS_KEY_ID` per Phase 01 convention).
  </behavior>
  <action>
1. **`services/backend/app/observability/counters.py`** — declare `mint_snapshot_fact_current_drift_total` (PR B step 1, locked decision RESEARCH §Pitfall 6) :

```python
# After the existing 8 counter declarations (line ~103), add :
mint_snapshot_fact_current_drift_total = Counter(
    "mint_snapshot_fact_current_drift_total",
    "Drift events detected between SnapshotModel (legacy) and fact_current (canonical) post-cutover. Wired in cron/continuous_drift_sampler.py — fires on every diff_count > 0 sample.",
    labelnames=["field_key"],
)
# Add to __all__ export tuple
__all__ = (
    # ... existing 8 names ...
    "mint_snapshot_fact_current_drift_total",
)
```

   - Wire in `services/backend/app/cron/continuous_drift_sampler.py` : after each `projection_diff` call, if `diff_count > 0`, `for field_key in diff_details.keys(): mint_snapshot_fact_current_drift_total.labels(field_key=field_key).inc()`.

2. **`tools/checks/alembic_partition_safety_lint.py` (NEW, ~80 LOC AST-walk)** — postgres-pro E2 + RESEARCH §Pitfall 2 :

```python
"""alembic_partition_safety_lint.py

Walks services/backend/alembic/versions/*.py AST. For every migration declaring
a `PARTITION BY HASH (col)` table, verifies the table's PRIMARY KEY includes
that partition column (Postgres ≥ 14 rule). Bans `ADD CONSTRAINT ... FOREIGN KEY
... NOT VALID` on a parent partitioned table (must loop partitions per Pitfall 2).

Exits 0 if all migrations safe ; exit 1 with diagnostic if any violation.
"""
import ast
import re
import sys
from pathlib import Path

ALEMBIC_DIR = Path("services/backend/alembic/versions")

PARTITION_RE = re.compile(r"PARTITION BY HASH\s*\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)", re.IGNORECASE)
PK_RE = re.compile(r"PRIMARY KEY\s*\(\s*([^)]+)\s*\)", re.IGNORECASE)
FK_NOT_VALID_ON_PARENT_RE = re.compile(r"ADD CONSTRAINT.*FOREIGN KEY.*NOT VALID", re.IGNORECASE | re.DOTALL)

violations: list[tuple[str, str]] = []

for migration_path in sorted(ALEMBIC_DIR.glob("*.py")):
    src = migration_path.read_text()
    # Pattern 1 : PARTITION BY HASH (col) must include col in PK
    for match in PARTITION_RE.finditer(src):
        part_col = match.group(1)
        # Search the same CREATE TABLE block for PRIMARY KEY
        block = src[match.start() - 2000 : match.start() + 200]
        pk_match = PK_RE.search(block)
        if not pk_match:
            violations.append((migration_path.name, f"PARTITION BY {part_col} found but no PRIMARY KEY in block"))
            continue
        pk_cols = [c.strip() for c in pk_match.group(1).split(",")]
        if part_col not in pk_cols:
            violations.append((migration_path.name, f"PARTITION BY {part_col} not in PK ({pk_cols}) — Postgres v14+ requires partition col in PK/UNIQUE"))
    # Pattern 2 : FK NOT VALID on parent partitioned table is hazardous (Pitfall 2)
    if FK_NOT_VALID_ON_PARENT_RE.search(src) and PARTITION_RE.search(src):
        violations.append((migration_path.name, "ADD CONSTRAINT FK NOT VALID on partitioned parent — must loop partitions (Pitfall 2 / engram #239)"))

if violations:
    for path, msg in violations:
        print(f"BLOCKED {path}: {msg}", file=sys.stderr)
    sys.exit(1)
print(f"OK : {len(list(ALEMBIC_DIR.glob('*.py')))} migrations scanned, 0 partition-safety violations.")
sys.exit(0)
```

3. **`tools/checks/tests/test_alembic_partition_safety_lint.py` (NEW, ~80 LOC)** :
   - Fixture good migration : `CREATE TABLE foo (id INT, ts TIMESTAMPTZ, PRIMARY KEY (id, ts)) PARTITION BY HASH (id);` → lint exits 0.
   - Fixture bad migration #1 : `CREATE TABLE bad (id INT, ts TIMESTAMPTZ, PRIMARY KEY (id)) PARTITION BY HASH (ts);` → lint exits 1 with diag « partition col `ts` not in PK ».
   - Fixture bad migration #2 : `CREATE TABLE p (id INT PRIMARY KEY) PARTITION BY HASH (id);` + later `ALTER TABLE p ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) NOT VALID;` → lint exits 1 with diag.
   - Validation : run against real `p98_fact_event_projection.py` → exits 0 (proves the existing migration is safe per HANDOFF #658 fix).

4. **`tools/db/railway_pg_dump.sh` (NEW, executable bit, ~60 LOC)** — RESEARCH §Don't-Hand-Roll + §Pattern B :

```bash
#!/usr/bin/env bash
# tools/db/railway_pg_dump.sh — Railway pg_dump helper for baseline capture.
# Usage : tools/db/railway_pg_dump.sh staging|production
# Output : tools/db/baselines/{env}-{YYYY-MM-DD}-pre-deploy.sql.gz
# Secret guard : greps the dump for password|api_key|secret and aborts if found.

set -euo pipefail

ENV="${1:?Usage: $0 staging|production}"
case "$ENV" in
  staging|production) ;;
  *) echo "ERROR: env must be 'staging' or 'production', got '$ENV'"; exit 1 ;;
esac

DATE=$(date -u +%Y-%m-%d)
OUT_DIR="$(dirname "$0")/baselines"
OUT_FILE="$OUT_DIR/${ENV}-${DATE}-pre-deploy.sql.gz"
mkdir -p "$OUT_DIR"

echo "Capturing baseline pg_dump for env=$ENV → $OUT_FILE"
# pg_dump via Railway shell — --no-comments --no-owner --no-privileges per Pitfall 9 (secrets safety)
TMP_FILE=$(mktemp)
trap "rm -f $TMP_FILE" EXIT
railway ssh -e "$ENV" --service MINT 'pg_dump --no-comments --no-owner --no-privileges --schema-only --data-only "$DATABASE_URL"' > "$TMP_FILE"

# Secret guard — abort if dump contains any obvious secret pattern
if grep -E -i "password\\s*[:=]|api_key|secret_key|bearer\\s+|MINT_AUDIT_HASH_PEPPER\\s*=" "$TMP_FILE" > /dev/null; then
  echo "BLOCKED: pg_dump contains potential secret patterns — review $TMP_FILE before commit." >&2
  echo "Hits :" >&2
  grep -n -E -i "password\\s*[:=]|api_key|secret_key|bearer\\s+|MINT_AUDIT_HASH_PEPPER\\s*=" "$TMP_FILE" >&2
  exit 1
fi

gzip -9 < "$TMP_FILE" > "$OUT_FILE"
LINES=$(zcat "$OUT_FILE" | wc -l)
echo "OK : $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1) compressed, $LINES lines uncompressed)"
echo "Retention reminder : keep last 3 baselines + monthly snapshot per locked decision #3."
```

5. **`lefthook.yml`** — append caplog-prevention rule per RESEARCH §Pattern 6 :

```yaml
pre-commit:
  commands:
    # ... existing commands ...
    alembic-env-disable-loggers:
      glob: "services/backend/alembic/env.py"
      run: |
        if grep -nE "fileConfig\\(" services/backend/alembic/env.py > /tmp/fc.txt; then
          if ! grep -q "disable_existing_loggers=False" services/backend/alembic/env.py; then
            echo "BLOCKED: services/backend/alembic/env.py has fileConfig() but missing disable_existing_loggers=False (caplog cascade flake — engram #239)"
            exit 1
          fi
        fi
    alembic-partition-safety:
      glob: "services/backend/alembic/versions/*.py"
      run: python3 tools/checks/alembic_partition_safety_lint.py
      fail_text: "Partition-safety lint failed — Postgres v14+ requires partition col in PK ; FK NOT VALID on partitioned parent must loop partitions."
```

6. **`services/backend/tests/conftest.py`** — append session-scope health-check fixture :

```python
import logging
import pytest

@pytest.fixture(scope="session", autouse=True)
def _assert_critical_loggers_enabled():
    """Session-start guard against `disable_existing_loggers=True` regression
    (engram obs #239 — caplog cascade flake root cause).
    """
    critical_loggers = [
        "app.services.projector",
        "app.services.snapshots",
        "app.api.v1.endpoints.projection",
        "app.api.v1.endpoints.audit_mobile",
        "app.services.encryption.key_vault",
        "app.observability.counters",
    ]
    disabled = [n for n in critical_loggers if logging.getLogger(n).disabled]
    if disabled:
        raise RuntimeError(
            f"Critical loggers disabled at session start: {disabled}. "
            "Likely cause : alembic env.py fileConfig() missing disable_existing_loggers=False. "
            "See engram #239 + RESEARCH §Pattern 6."
        )
    yield
```

7. **`.planning/phases/mint-data-architecture-v1-02-deploy/kms-naming-audit.txt` (NEW)** — KMS_KEY_ID vs MINT_KMS_KEY_ID inventory (HANDOFF PR B step 2 + devops finding) :

```text
# KMS_KEY_ID vs MINT_KMS_KEY_ID naming audit — 2026-05-19
# Per HANDOFF PR B step 2 + devops-troubleshooter finding.

## Inventory (regex `(MINT_)?KMS_KEY_ID`)
{output of `grep -rn "KMS_KEY_ID" services/backend/ tools/ .github/ docs/`}

## Per-file disposition
{For each hit : RECOMMENDATION : canonicalize on MINT_KMS_KEY_ID (Phase 01 convention) OR keep KMS_KEY_ID with rationale}

## Decision
Canonicalize on `MINT_KMS_KEY_ID` in code + Railway env vars (matches MINT_AUDIT_HASH_PEPPER + MINT_* prefix convention).
Bare `KMS_KEY_ID` references in test fixtures + docstrings : leave as legacy ref, document only.

## Out of scope
Renaming Railway env vars is an operational task (Julien-only on Railway dashboard) — NOT shipped in this PR ; tracked Wave 3 Plan 04 as runbook step.
```

8. **`.github/workflows/deploy-backend.yml`** — append alembic head verification post-deploy per RESEARCH §Pattern E :

```yaml
- name: Verify alembic upgrade succeeded post-deploy (PR B)
  if: github.event.pull_request.base.ref == 'staging' || github.event.pull_request.base.ref == 'main'
  env:
    RAILWAY_TOKEN: ${{ secrets.PROJECT_STAGING_TOKEN }}
  run: |
    npm install -g @railway/cli
    EXPECTED=$(cd services/backend && python -c "from alembic.config import Config; from alembic.script import ScriptDirectory; print(ScriptDirectory.from_config(Config('alembic.ini')).get_current_head())")
    ACTUAL=$(railway ssh -e staging --service MINT 'python -c "import os,psycopg2; c=psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur=c.cursor(); cur.execute(\"SELECT version_num FROM alembic_version\"); print(cur.fetchone()[0])"')
    test "$EXPECTED" = "$ACTUAL" || (echo "::error::alembic mismatch expected=$EXPECTED actual=$ACTUAL"; exit 1)
```

9. **Pre-push checklist** :
   - `python3 tools/checks/alembic_partition_safety_lint.py` exits 0 against ALL existing migrations.
   - `tools/db/railway_pg_dump.sh --help` (or fall back to running with bogus env to confirm script structure ; actual baseline captures happen in Task 4).
   - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (verifies conftest health-check fires + no regression).
   - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/ tools/checks/ tools/db/` exits 0.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -n "mint_snapshot_fact_current_drift_total" services/backend/app/observability/counters.py && python3 tools/checks/alembic_partition_safety_lint.py && python3 -m pytest tools/checks/tests/test_alembic_partition_safety_lint.py -q && [ -x tools/db/railway_pg_dump.sh ] && grep -n "alembic-env-disable-loggers\|alembic-partition-safety" lefthook.yml && grep -n "_assert_critical_loggers_enabled" services/backend/tests/conftest.py && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/kms-naming-audit.txt ] && cd services/backend && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/observability/ tools/checks/alembic_partition_safety_lint.py && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `grep -cE "mint_snapshot_fact_current_drift_total" services/backend/app/observability/counters.py` ≥ 1 (declared).
    - `grep -cE "mint_snapshot_fact_current_drift_total" services/backend/app/cron/continuous_drift_sampler.py` ≥ 1 (wired in cron).
    - `curl -sf $/metrics-test-endpoint | grep mint_snapshot_fact_current_drift_total` would return the metric name (post-deploy ; verified in Wave 2 not here).
    - `python3 tools/checks/alembic_partition_safety_lint.py` exits 0 against existing alembic/versions/*.py (p98 + p120 + all prior migrations).
    - `python3 -m pytest tools/checks/tests/test_alembic_partition_safety_lint.py -q` exits 0 (good fixture passes, 2 bad fixtures fail with diag).
    - `[ -x tools/db/railway_pg_dump.sh ]` returns 0 (executable bit set).
    - `bash -n tools/db/railway_pg_dump.sh` exits 0 (script syntax valid — does NOT execute the railway ssh, just parses).
    - `grep -cE "alembic-env-disable-loggers" lefthook.yml` ≥ 1 (rule registered).
    - `grep -cE "alembic-partition-safety" lefthook.yml` ≥ 1 (rule registered).
    - `grep -cE "_assert_critical_loggers_enabled" services/backend/tests/conftest.py` ≥ 1 (autouse fixture present).
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression — conftest fixture fires at session start, no logger disabled).
    - `.planning/phases/mint-data-architecture-v1-02-deploy/kms-naming-audit.txt` ≥ 20 lines + contains « Canonicalize on `MINT_KMS_KEY_ID` ».
    - `grep -cE "Verify alembic upgrade succeeded post-deploy" .github/workflows/deploy-backend.yml` ≥ 1 (post-deploy verification wired).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/ tools/checks/alembic_partition_safety_lint.py tools/db/railway_pg_dump.sh` exits 0.
  </acceptance_criteria>
  <done>
    PR B observability infra shipped : `mint_snapshot_fact_current_drift_total` counter declared + wired in cron ; `alembic_partition_safety_lint.py` AST walk lints PARTITION BY+PK + FK NOT VALID ; `railway_pg_dump.sh` shipped executable + secret-guarded ; lefthook caplog-prevention + partition-safety rules registered ; conftest session-scope health-check fixture ; KMS naming audit captured ; alembic head verification post-deploy added to GH Actions. Wave 1 has its observability + safety net ready.
  </done>
</task>

<task type="auto">
  <name>Task 4 (Wave 0 close) : Alembic chain audit déterministe + 2 baseline pg_dumps (staging + production)</name>
  <files>
    .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt,
    tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz,
    tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz
  </files>
  <read_first>
    services/backend/alembic.ini (single-head verification : `p119_phase02_parity_cont`),
    services/backend/alembic/versions/ (the actual file inventory ; chain ScriptDirectory.walk_revisions traverses),
    tools/db/railway_pg_dump.sh (from Task 3 — invocation script),
    .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md (devops resolution : « no merges to main since 2026-04-21 » — Open-Q #1 lock),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern A verbatim Python ScriptDirectory.walk_revisions snippet + §Code Example A + §Pattern B Railway DB state probe)
  </read_first>
  <action>
1. **Deterministic chain enumeration via Python** — runs `ScriptDirectory.walk_revisions` API per RESEARCH §Pattern A verbatim :

```bash
cd services/backend
python3 << 'PY' | tee ../../.planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
from alembic.config import Config
from alembic.script import ScriptDirectory
from datetime import datetime

cfg = Config('alembic.ini')
script = ScriptDirectory.from_config(cfg)

print(f"# Alembic chain audit — generated {datetime.utcnow().isoformat()}Z")
print(f"# Per HANDOFF-2026-05-19.md locked decision #1 :")
print(f"# Prod alembic head = '29_05_magic_link_tokens' (no merges to main since 2026-04-21).")
print(f"# Dev alembic head = '{script.get_current_head()}' (single head).")
print()
print(f"## Heads detected : {script.get_heads()}")
print(f"## Bases detected : {script.get_bases()}")
print()
print("## Linear chain from prod_head -> dev_head (oldest to newest applied order)")
prod_head = '29_05_magic_link_tokens'
dev_head = script.get_current_head()
gap = list(script.iterate_revisions(dev_head, prod_head))
gap_reversed = list(reversed(gap))  # apply oldest first

for i, rev in enumerate(gap_reversed, start=1):
    is_merge = len(rev.down_revision or ()) > 1 if isinstance(rev.down_revision, tuple) else False
    label = " [MERGE NODE]" if is_merge else ""
    doc_first_line = (rev.doc or '').split('\n')[0][:120]
    print(f"  {i:>2}. {rev.revision} <- {rev.down_revision}{label}")
    print(f"      {doc_first_line}")

print()
print(f"## Total revisions to apply : {len(gap_reversed)}")
print(f"## Merge nodes : {sum(1 for r in gap_reversed if isinstance(r.down_revision, tuple) and len(r.down_revision) > 1)}")
print()
print("## Per-revision forward-compat + downgrade verification")
print("## (executor runs `alembic upgrade <rev> && alembic downgrade -1` on baseline replay)")
for rev in gap_reversed:
    print(f"  - {rev.revision} : forward-compat=TBD-Wave1-replay, downgrade=TBD-Wave1-replay")

print()
print("## Locked decision #1 evidence")
print("## Per devops-troubleshooter HANDOFF : no merges to main since 2026-04-21.")
print("## NOT a fork — chain is linear with 1 merge node (p98_merge_p86_eclairage absorbing DEFERRED-02-01-A double-head).")
PY
```

2. **Verify ScriptDirectory output matches RESEARCH §Summary line 44** :
   - Total revisions = 14 (per RESEARCH).
   - 1 merge node `p98_merge_p86_eclairage` (per RESEARCH §Summary).
   - If count differs, surface discrepancy in chain-audit.txt + STOP for Julien clarification (per memory `feedback_blockers_ask_dont_defer`).

3. **Capture staging baseline pg_dump** — invoke Task 3's `tools/db/railway_pg_dump.sh staging` :

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync
./tools/db/railway_pg_dump.sh staging
# Expected output : tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz
# Secret guard pre-validated by Task 3.
```

4. **Capture production baseline pg_dump** :

```bash
./tools/db/railway_pg_dump.sh production
# Expected output : tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz
```

5. **Validate baselines** :
   - Both `.sql.gz` files exist + are non-empty (size > 1KB).
   - `zcat tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz | head -20` shows `CREATE TABLE` statements (not error output).
   - `zcat tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE"` ≥ 30 (prod has 33 tables per CONTEXT).
   - `zcat tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE"` ≥ 33 (staging has 34 tables + fact_event/fact_current/dek_envelope post-PR #660 deploy per HANDOFF).

6. **Probe staging + prod current state** (run RESEARCH §Pattern B verbatim for fresh evidence — append to chain-audit.txt as appendix) :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
echo "## Wave 0 state probes (run $(date -u +%Y-%m-%dT%H:%M:%SZ))" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
echo "### Staging probe" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
url = os.getenv(\"DATABASE_URL\")
c = psycopg2.connect(url); cur = c.cursor()
cur.execute(\"SELECT version_num FROM alembic_version\")
print(\"alembic head:\", cur.fetchone())
cur.execute(\"SELECT current_user, current_database()\")
print(\"identity:\", cur.fetchone())
cur.execute(\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=\\047fact_event\\047)\")
print(\"fact_event:\", cur.fetchone())
cur.execute(\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=\\047fact_current\\047)\")
print(\"fact_current:\", cur.fetchone())
"' >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt 2>&1

echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
echo "### Production probe" >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
railway ssh -e production --service MINT 'python3 -c "...same probe..."' >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt 2>&1
```

7. **Verify p98 REVOKE outcome on staging** (RESEARCH §Pitfall 4 — Wave 0 step 1) :

```bash
railway ssh -e staging --service MINT 'psql $DATABASE_URL -c "\\dp fact_event" 2>&1' >> .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt
# Expected : current grants column shows restricted PUBLIC (no UPDATE/DELETE) — confirms p98 REVOKE succeeded
# If grants show =arwdDxt for PUBLIC, REVOKE failed silently → document in chain-audit.txt + escalate for hotfix migration
```

8. **Commit summary** : the chain-audit.txt + 2 baseline files capture the « ground state » before any migration touches a deployed env. This is the rollback insurance.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt ] && [ $(wc -l < .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt) -ge 30 ] && grep -c "Total revisions to apply" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt && [ -f tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz ] && [ -f tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz ] && [ $(stat -f%z tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz 2>/dev/null || stat -c%s tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz) -gt 1024 ] && zcat tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE" && zcat tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE" && grep -c "alembic head" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt</automated>
  </verify>
  <acceptance_criteria>
    - `.planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` exists + ≥ 30 lines.
    - `grep -cE "Total revisions to apply : 14" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` returns 1 (matches RESEARCH §Summary expectation).
    - `grep -cE "Merge nodes : 1" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` returns 1 (matches locked decision #1).
    - `grep -cE "p98_merge_p86_eclairage" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` ≥ 1 (the single merge node identified).
    - `[ -f tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz ]` + file size > 1024 bytes.
    - `[ -f tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz ]` + file size > 1024 bytes.
    - `zcat tools/db/baselines/staging-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE"` ≥ 33 (staging has 34 tables + Phase 02 substrate post-PR #660 deploy).
    - `zcat tools/db/baselines/production-2026-05-19-pre-deploy.sql.gz | grep -c "CREATE TABLE"` ≥ 30 (prod 33 tables).
    - `grep -cE "alembic head" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` ≥ 2 (staging + production probe lines).
    - `grep -cE "fact_event" .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt` ≥ 2 (staging shows True per HANDOFF, prod shows False).
    - p98 REVOKE state documented in chain-audit.txt (either CONFIRMED or hotfix-needed).
  </acceptance_criteria>
  <done>
    Wave 0 close-out artifact set : chain-audit.txt enumerates 14 revs + 1 merge node deterministically (matches RESEARCH §Summary + locked decision #1) ; staging + prod baselines captured + secret-guard-validated ; state probes show staging post-PR #660 fact_event+fact_current present, prod still at `29_05_magic_link_tokens` (lag 14 revs) ; p98 REVOKE outcome documented. Wave 1 can proceed with full rollback insurance.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| `services/backend/app/services/projector/fact_projector.py` | PR A2 / A3 add new exception-handling branch + dialect-branched SQL — any leak of constraint name or query shape to logs is an information disclosure surface |
| `tools/db/railway_pg_dump.sh` → committed baseline | pg_dump file contains data ; secret-guard greps for password/api_key/secret patterns before commit. Baselines committed to git (NOT to .gitignore) — must be data-clean. |
| `.github/workflows/deploy-backend.yml` post-deploy alembic head verification | Reads from Railway via `railway ssh` token — token scope must be read-only on prod (`RAILWAY_TOKEN` env) |
| `lefthook.yml` pre-commit gates | Run locally per-developer ; pre-push duplicates as CI gate (so a developer skipping lefthook is caught by GH Actions) |

## STRIDE Threat Register (ASVS L1 + engram #194 deep audit)

| Threat ID | Category | Component | Severity | Disposition | Mitigation |
|-----------|----------|-----------|----------|-------------|------------|
| T-01-01 | Tampering (integrity) | Alembic chain orphan migration (a rev with no down_revision matching prod head) | high | mitigate | Task 4 `ScriptDirectory.walk_revisions` enumerates the gap deterministically ; if `iterate_revisions(dev_head, prod_head)` raises or returns empty, surface in chain-audit.txt + STOP for Julien clarification. |
| T-01-02 | Tampering | Baseline pg_dump captures snapshot mid-write (race with active workers) | medium | mitigate | `pg_dump` uses Postgres transactional consistency (single snapshot point) ; `-w 1` gunicorn worker means no migration race during capture ; document timestamp in baseline filename. |
| T-01-03 | Information disclosure | pg_dump baseline contains secrets (passwords, API keys) | high | mitigate | `tools/db/railway_pg_dump.sh` step 4 greps for `password\\|api_key\\|secret_key\\|bearer\\|MINT_AUDIT_HASH_PEPPER` patterns BEFORE writing gzipped output ; aborts with exit 1 if any match. |
| T-01-04 | Tampering | D-27 idempotency replay leaks constraint name to client via 500 response | medium | mitigate | PR A2 catches `IntegrityError` server-side ; returns 200 with event_id ; constraint name NEVER reaches client (Task 1 acceptance criterion verified via test_audit_mobile_event_id_passthrough). |
| T-01-05 | Tampering | JSONB string-bind silently corrupts data on Postgres (Pitfall 1) | high | mitigate | PR A3 dialect-branched cast `CAST(:value_enc AS jsonb)` ; pg_fixture test `test_fact_projector_jsonb_postgres.py` proves survival on real Postgres. |
| T-01-06 | Repudiation | Drift counter declared but never fires → silent observability gap (Pitfall 6) | high | mitigate | PR B step 1 declares `mint_snapshot_fact_current_drift_total` in counters.py + wires increment in `continuous_drift_sampler.py` ; Wave 3 Plan 04 Task 3 asserts firing via `declared_counters_must_fire.py` HARD gate. |
| T-01-07 | Tampering | Partition-rule regression — future migration adds PARTITION BY without partition col in PK | high | mitigate | PR B `alembic_partition_safety_lint.py` AST walk + lefthook pre-commit + GH Actions pre-merge ; engram obs #239 root cause closed via lint. |
| T-01-08 | Tampering | FK NOT VALID on partitioned parent fails Postgres 15+ silently in tests | medium | mitigate | Same lint catches `ADD CONSTRAINT FK NOT VALID` on partitioned parent. |
| T-01-09 | Tampering | Caplog cascade flake (engram #239) regresses if env.py modified | medium | mitigate | PR B lefthook rule `alembic-env-disable-loggers` + conftest session-scope `_assert_critical_loggers_enabled` fixture. Defense-in-depth (lint + runtime assertion). |
| T-01-10 | Spoofing | KMS_KEY_ID vs MINT_KMS_KEY_ID inconsistency lets caller bypass DEK envelope | medium | mitigate | PR B step 7 audit + document canonical name ; actual Railway env rename deferred Wave 3 Plan 04 (Julien-only operational task, runbook docs it). |
| T-01-11 | Information disclosure | `kms-naming-audit.txt` leaks live env var values | low | accept | The audit file lists VARIABLE NAMES only (KMS_KEY_ID / MINT_KMS_KEY_ID) — never the values (which are read from Railway env at runtime, not from committed code). Public-repo discipline verified per memory. |
| T-01-12 | Tampering | DEK-revoked mid-loop leaves snapshot half-populated | high | mitigate | PR A3 test_dual_write_failure_rollback proves `session.begin_nested()` rollback contract is atomic — 0 partial rows. |
| T-01-13 | Repudiation | hmac pepper rotation cache-stale (lru_cache(maxsize=1) interaction) | medium | mitigate | PR A3 test_hmac_pepper_rotation explicitly invalidates cache via `hmac_user_id.cache_clear()` post-rotation ; documents the explicit-flush requirement. |
| T-01-14 | Spoofing | `railway ssh` token in GH Actions reused for prod after staging-only scope | high | accept | Token scope review is operational (Julien-only) ; alembic head verification step uses `PROJECT_STAGING_TOKEN` (already scoped per `deploy-backend.yml`). |
</threat_model>

<verification>
**Phase-level checks for this plan :**

1. **`autonomous: true`** — all 4 tasks Claude-self-executable.
2. **PR ordering** : 3 commits → 3 PRs (A2, A3, B). Task 4 (chain audit + baselines) merges with PR B for operational hygiene OR ships as standalone Wave 0 close-out commit.
3. **No env mutation** : zero `alembic upgrade head` on staging or production from this plan. Migrations are coded only ; deploy happens via Wave 1 Railway auto-deploy (Plan 02).
4. **0-trust §9** : Wave 0 close uses evidence-grounded claims only. The chain-audit.txt is the deterministic artifact ; the 2 baseline files are PR sha + railway ssh probe + filesize evidence.
5. **Counter-arguments + data gaps** : RESEARCH §Counter-arguments addressed (Counter-arg #2 — 4-PR cleanup belongs pre-Wave-1 — adopted here ; Counter-arg #4 — Pre-Deploy Command migration deferred Phase 03 — adopted).
6. **Banned-terms + accent + LSFin** : all code + docs pass `banned_terms_python` + `accent_lint_fr` + `no_legal_admission_in_public_docs` ; verified per Task acceptance criteria.
7. **Engram contract** : at end of plan, `mem_save` with `topic_key: mint-data-architecture-v1-02-deploy:wave-0:alembic-chain-audit-and-prereqs` + `prior_finding_refs` to obs #233 (operational substrate gap) + #239 (fact_event PK + caplog) + #194 (Phase 02 deep security audit) + #178 (devops Q6 + counters) + Plan 02-03 + Plan 02-04 substrate close-out obs.
</verification>

<success_criteria>
- [ ] PR A2 D-27 EXACT-EQUALITY shipped : alembic p120 latest_event_id col + IntegrityError catch + audit_mobile event_id passthrough + 4 integration tests green (Task 1).
- [ ] PR A3 JSONB cast + rollback + pepper rotation shipped : 3 pg_fixture integration tests green (Task 2).
- [ ] PR B observability infra shipped : `mint_snapshot_fact_current_drift_total` declared + wired ; `alembic_partition_safety_lint.py` shipped + tested ; `railway_pg_dump.sh` executable + secret-guarded ; lefthook caplog + partition-safety rules registered ; conftest health-check fixture autouse ; KMS naming audit + alembic head post-deploy GH Actions step (Task 3).
- [ ] Wave 0 close artifact : chain-audit.txt ≥30 lines + 14 linear revs + 1 merge node confirmed + 2 baseline pg_dumps captured + secret-guard-validated + state probes appended (Task 4).
- [ ] Full backend pytest + integration suite green : `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (≥ 7519 tests = +4 from Task 1 +3 from Task 2 + ≥2 from Task 3 lint self-tests = +9 minimum vs substrate baseline 7515).
- [ ] All lints green : `banned_terms_python` + `accent_lint_fr` + `alembic_partition_safety_lint` + `alembic_boolean_default_lint` + `hmac_pepper_audit` + `wiki_lint`.
- [ ] OpenAPI canonical regen committed (Task 1 Pydantic change requires it).
- [ ] Sec FLAG-1 post-write divergence assertion preserved (Anti-Patterns compliance).
- [ ] Pre-push checklist applied per task : grep callers + regen OpenAPI/flutter gen-l10n + full pytest BEFORE commit (memory `feedback_pre_push_checklist`).
- [ ] All threats in STRIDE register have a disposition (mitigate / accept) — no « pending » severity:high threats.
- [ ] Engram observation saved with prior_finding_refs ≥6 obs.
</success_criteria>

<output>
After completion, ensure :
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-01-alembic-chain-audit-SUMMARY.md` (this plan's per-task receipt) exists.
- Per-task verify command stdout captured (lint exit codes, test exit codes, file existence assertions).
- Commit SHA trail in SUMMARY : 3 PR shas (A2 + A3 + B) + 1 Wave 0 close commit sha.
- 0-trust §9.6 Evidence + Caveat block in SUMMARY.
- `mem_save` with `topic_key: mint-data-architecture-v1-02-deploy:wave-0:alembic-audit-and-pr-A2-A3-B-cleanup` + `prior_finding_refs` ≥6 obs (#233, #239, #194, #178, Plan 02-03 obs, Plan 02-04 substrate obs).
- Forward-deferred items list : Mobile L1 wiring (Wave 3 Plan 04) + PR D polish (Wave 3 Plan 04) + Sentry alert wiring (Wave 3 Plan 04 + Julien-only UI) + branch protection promotion (Julien-only UI, runbook Wave 3).
</output>
