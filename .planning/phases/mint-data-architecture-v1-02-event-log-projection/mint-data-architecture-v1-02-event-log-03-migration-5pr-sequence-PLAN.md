---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 03
type: execute
wave: 2
depends_on: [02]
files_modified:
  - services/backend/app/services/feature_flags.py
  - services/backend/app/services/snapshots/snapshot_service.py
  - services/backend/scripts/backfill_snapshot_to_fact_event.py
  - services/backend/app/api/v1/endpoints/projection.py
  - services/backend/app/api/v1/endpoints/snapshots.py
  - services/backend/app/models/snapshot.py
  - services/backend/alembic/versions/p117_drop_snapshot_legacy.py
  - tools/checks/profile_safe_fields_parity.py
  - lefthook.yml
  - .github/workflows/backend-ci.yml
  - .github/workflows/design-lints.yml
  - services/backend/tests/integration/test_dual_write_off.py
  - services/backend/tests/integration/test_dual_write_on_staging.py
  - services/backend/tests/integration/test_backfill_idempotent.py
  - services/backend/tests/integration/test_read_cutover.py
  - services/backend/tests/services/snapshot_deprecation/__init__.py
  - services/backend/tests/services/snapshot_deprecation/test_snapshot_deprecation.py
  - services/backend/tests/integration/test_snapshot_drop.py
  - services/backend/tests/observability/test_drift_telemetry.py
  - services/backend/app/observability/counters.py
  - docs/operations/snapshot-model-decommission.md
  - apps/mobile/lib/services/coach_narrative_service.dart
  # --- iter-2 additions (promoted from iter-2 appendix; structurally required for parser visibility) ---
  - services/backend/scripts/preflight_zero_user_gate.py                                  # Task 0 B1
  - services/backend/tests/integration/test_preflight_zero_user_gate.py                   # Task 0 B1
  - tools/parity/projection_diff.py                                                       # A10
  - tools/parity/tests/test_projection_diff.py                                            # A10
  - services/backend/tests/fixtures/parity_diff_fixtures.py                               # A10
  - services/backend/alembic/versions/p118_phase02_parity_audit_table.py                  # B14
  - services/backend/app/models/phase02_parity_audit.py                                   # B14
  - services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py             # B18
  - services/backend/app/models/phase02_parity_audit_continuous.py                        # B18
  - services/backend/app/cron/continuous_drift_sampler.py                                 # B18
  - .github/workflows/pg-soak-nightly.yml                                                 # B18
  - tools/db/pre_pr3b_pg_dump.sql                                                         # B5
autonomous: false
decisions: [D-04, D-05, D-31]
checkpoint_reason: "Task 2a (PR-3a staging-backfill zero-diff gate) + Task 2b (PR-3b 7-day soak + Phase-01 D-12 HARD flip gate) require Julien approval per 0-trust §9. PR-5 drop is irreversible; Julien post-launch + 1-week observability soak gate per D-05."
requirements_addressed:
  - CONTEXT.md#D-04 constants propagation point-in-time (no retroactive re-flag — proven by PR-2 dual-write parity test)
  - CONTEXT.md#D-05 big-bang 6-PR migration sequence (PR-0 zero-user gate → PR-1 FF infra → PR-2 dual-write FF-OFF → PR-3a backfill-only → PR-3b read-cutover+HARD flip → PR-4 decommission → PR-5 drop)
  - CONTEXT.md#D-31 Phase-01 D-12 parity-lint SOFT→HARD atomic with PR-3b read cutover (TWO sub-conditions in one PR: read-cutover + HARD-flip)
threat_model_summary:
  - T-02-06 Read-cutover drift (mitigated: PR-3 atomic D-31 SOFT→HARD flip + zero-drift proof in coverage; D-12 parity-lint HARD catches future regressions at commit-time)
  - T-02-07 Orphan SnapshotModel data post-drop (mitigated: PR-5 gated on 1-week post-PR-3 observability soak + Julien checkpoint; rollback procedure documented in snapshot-model-decommission.md)
  - T-02-18 Feature-flag stuck-on after PR-4 decommission (mitigated: PR-4 removes the FF code branch + removes env-var reference; CI grep asserts zero occurrences post-merge)
  - T-02-19 Backfill non-idempotency (mitigated: D-27 UNIQUE constraint blocks dups; idempotency counter increments per duplicate; second run = 0 new rows assertion in PR-3 test)
must_haves:
  truths:
    - "PR-1: `fact_event_dual_write_enabled` feature flag added to `app/services/feature_flags.py`, default OFF in all envs; reading the flag returns False on dev + staging + prod (D-05 PR-1)."
    - "PR-2: `snapshot_service.py` writer branches on `fact_event_dual_write_enabled` flag; when ON it also writes fact_event + runs projector inside `session.begin()`; when OFF (default), only SnapshotModel write happens (D-05 PR-2). FF stays OFF in this PR — code path compiled + tested with FF-ON in test fixtures."
    - "PR-3a (backfill-only, idempotent): backfill_snapshot_to_fact_event.py idempotent (second run row-count-delta=0); 100% staging-user canonical-JSON parity audit zero diff via projection_diff.py persisted to _phase02_parity_audit."
    - "PR-3b (ATOMIC, the D-31 pair): read-cutover (/v1/projection reads fact_current) AND Phase-01 D-12 parity-lint SOFT→HARD flip in lefthook + CI are in ONE PR. 7-day continuous drift sampler clean window prerequisite met. pre_pr3b_pg_dump.sql committed."
    - "PR-4: `fact_event_dual_write_enabled` removed from `app/services/feature_flags.py`; `snapshot_service.py` dual-write branch removed; SnapshotModel writes marked deprecated via `warnings.warn(DeprecationWarning)` in any remaining writer paths (D-05 PR-4)."
    - "PR-5: Alembic p117 drops `snapshots` table; `app/models/snapshot.py` removed; rollback procedure in `docs/operations/snapshot-model-decommission.md` documents Postgres `pg_restore` from baseline (D-05 PR-5). GATED on Julien checkpoint after 1-week observability soak."
    - "Drift-resolution telemetry counter `mint_snapshot_fact_current_drift_total` wired (Plan 02-04 will assert firing); D-MOB-02 drift-resolution gauge added (D-31 read-cutover lock)."
    - "Plan 02-01 D-10 PR-A2 was SOFT-mode; PR-3 here flips it to HARD. Plan 02-04 PR-A3 (drop 3 dead Flutter-only fields) lands in W4 close-out, AFTER HARD flip — meaning the HARD flip happens WITH the 3-field drift remaining; the lint must accept this as a documented baseline (whitelist) until PR-A3 cleans it up."
  artifacts:
    - path: "services/backend/scripts/backfill_snapshot_to_fact_event.py"
      provides: "Idempotent backfill from SnapshotModel to fact_event"
      exports: ["main", "backfill_user"]
      min_lines: 80
    - path: "services/backend/alembic/versions/p117_drop_snapshot_legacy.py"
      provides: "Drop snapshots table migration (PR-5 only)"
      contains: "op.drop_table(\"snapshots\")"
    - path: "docs/operations/snapshot-model-decommission.md"
      provides: "PR-5 rollback procedure + pg_restore from baseline"
      min_lines: 50
    - path: "services/backend/tests/integration/test_read_cutover.py"
      provides: "Verifies /v1/projection reads from fact_current, parity vs SnapshotModel during dual-read window"
      contains: "fact_current"
  key_links:
    - from: "services/backend/app/services/snapshots/snapshot_service.py"
      to: "services/backend/app/services/projector/fact_projector.py"
      via: "PR-2 dual-write branch under feature flag invokes project_fact_event() inside session.begin()"
      pattern: "project_fact_event"
    - from: "services/backend/app/api/v1/endpoints/projection.py"
      to: "services/backend/app/models/fact_current.py"
      via: "PR-3 reads switch from SnapshotModel to FactCurrent PK lookup"
      pattern: "FactCurrent"
    - from: "lefthook.yml"
      to: "tools/checks/profile_safe_fields_parity.py"
      via: "PR-3 atomic flip: SOFT mode removed, --hard flag added to the lefthook + CI invocations"
      pattern: "profile_safe_fields_parity.py.*--hard"
    - from: "services/backend/scripts/backfill_snapshot_to_fact_event.py"
      to: "services/backend/app/services/projector/fact_projector.py"
      via: "Backfill emits fact_event + invokes project_fact_event() per row; UNIQUE constraint blocks dups on re-run"
      pattern: "project_fact_event"
---

<objective>
Wave 2-3 ships the 5-PR big-bang migration sequence that replaces SnapshotModel with fact_event + fact_current as the canonical user-facts substrate. Each of the 5 PRs is its own atomic task within this plan; together they execute the D-05 lock-step migration choreography. PR-3 is the "atomic trio" task (D-31): the same PR ships (a) idempotent backfill, (b) `/v1/projection` + `/v1/snapshots` read-cutover, (c) `profile_safe_fields_parity.py` SOFT→HARD flip in lefthook + CI — three changes, one PR, zero possibility of drift mid-step. PR-5 (legacy SnapshotModel drop) is gated on Julien checkpoint after 1-week observability soak.

Purpose: at the end of Wave 3, SnapshotModel is dropped; fact_current is the sole canonical projection storage; the D-12 parity-lint HARD gate catches any future Flutter↔server drift at commit-time. Every event-log slice from Phase 02 Wave 1 is now read by every backend consumer.

Output: 5 sequenced PRs landing on `dev` (PR-1 → PR-5). PR-3 carries the D-31 atomic trio. PR-5 is gated on Julien checkpoint. **`autonomous: false`** with two checkpoints (PR-3 staging-zero-drift gate + PR-5 post-soak drop gate).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-SUMMARY.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-02-event-log-core-canary-SUMMARY.md
@services/backend/app/services/snapshots/snapshot_service.py
@services/backend/app/services/feature_flags.py
@services/backend/app/models/snapshot.py
@services/backend/app/models/fact_event.py
@services/backend/app/models/fact_current.py
@services/backend/app/services/projector/fact_projector.py
@tools/checks/profile_safe_fields_parity.py
@lefthook.yml
@.github/workflows/design-lints.yml

<interfaces>
<!-- Verbatim contracts the executor needs after Plan 02-02 lands. -->

From `services/backend/app/services/feature_flags.py` (existing pattern — Phase 01 `profile_grounding_strict_mode` used the same shape):
```python
def is_enabled(flag_name: str, default: bool = False) -> bool:
    """Read flag from env var FF_<UPPER>; default False if unset."""
```
PR-1 adds: `FF_FACT_EVENT_DUAL_WRITE` env var, default `off`. Helper `is_fact_event_dual_write_enabled() -> bool`.

From `services/backend/app/services/snapshots/snapshot_service.py` (PR-2 extension point — current shape):
```python
def write_snapshot(db, user_id, inputs_hash, projection_payload, constants_version_hash):
    # 1. SnapshotModel INSERT (existing)
    # 2. NEW PR-2 branch: if is_fact_event_dual_write_enabled():
    #      with session.begin():
    #          for fact_type in EXTRACT_FROM_PAYLOAD:
    #              event = FactEvent(subject_type='user', subject_id=user_id,
    #                                fact_type=fact_type, value_enc=encrypt_value(...),
    #                                source_type='snapshot', ...)
    #              project_fact_event(session, event)
```
NB: dual-write extracts fields from the projection payload one fact_type at a time (`monthly_gross_income` already canary-proven in Plan 02-02). The full fact_type list is derived from the SnapshotModel column shape minus metadata (e.g., `gross_income`, `lpp_avoirs_vieillesse`, `pillar_3a_balance`, ...).

From `services/backend/app/api/v1/endpoints/projection.py` (PR-3 read-cutover target):
```python
# BEFORE PR-3:
@router.get("/projection/{user_id}")
def get_projection(user_id, db):
    snap = db.query(SnapshotModel).filter_by(user_id=user_id).one()
    return _build_response(snap)

# AFTER PR-3 (D-31 atomic):
@router.get("/projection/{user_id}")
def get_projection(user_id, db):
    facts = db.query(FactCurrent).filter_by(subject_type='user', subject_id=user_id).all()
    # decrypt each value_enc via decrypt_value(db, user_id, fact.value_enc)
    return _build_response_from_facts(facts)
```

From `tools/checks/profile_safe_fields_parity.py` (existing Phase 01 W4 lint — current behavior):
```python
parser.add_argument("--hard", action="store_true", default=False)
# When --hard set: exit 1 if any drift. When --hard unset (SOFT, default): exit 0 + report drift.
```
PR-3 atomic flip: every invocation in `lefthook.yml` + `.github/workflows/design-lints.yml` adds `--hard`. ALSO: 3 Flutter-only-fields-pending-drop are whitelisted via a new `--allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` flag containing the 3 field names; Plan 02-04 PR-A3 drops the fields and removes the allowlist.

Alembic head after Plan 02-02: `p116_snapshot_constants_invalidation`. PR-5 migration p117 = `down_revision="p116_snapshot_constants_invalidation"`.

Feature flag env-var name (D-05 Claude's Discretion): `FF_FACT_EVENT_DUAL_WRITE` (string `"on"`/`"off"`/`undefined`). Reason for `FF_` prefix: matches existing `FF_PROFILE_GROUNDING_STRICT_MODE` etc. naming convention.

Canary verification (D-25 W1 gate already proven): the dual-write code path is parity-tested in Plan 02-02 `test_canary_monthly_gross_income.py`. PR-2 here extends that to N fact_types in a generic parity harness.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: PR-1 (FF infrastructure, default OFF) + PR-2 (dual-write code path under FF, FF stays OFF in prod, ON in test fixtures only)</name>
  <files>
    services/backend/app/services/feature_flags.py,
    services/backend/app/services/snapshots/snapshot_service.py,
    services/backend/tests/integration/test_dual_write_off.py,
    services/backend/tests/integration/test_dual_write_on_staging.py
  </files>
  <read_first>
    services/backend/app/services/feature_flags.py (existing helper pattern — Phase 01 strict-mode flag),
    services/backend/app/services/snapshots/snapshot_service.py (full file — extension target),
    services/backend/app/services/projector/fact_projector.py (from Plan 02-02 — project_fact_event signature),
    services/backend/app/services/encryption/encrypted_value_helper.py (from Plan 02-02 — encrypt_value signature),
    services/backend/app/models/fact_event.py + fact_current.py (from Plan 02-02 — ORM shapes),
    services/backend/tests/integration/test_canary_monthly_gross_income.py (from Plan 02-02 — parity test scaffold)
  </read_first>
  <action>
**PR-1 (single commit, isolated)**:
1. **`services/backend/app/services/feature_flags.py`**: add `FF_FACT_EVENT_DUAL_WRITE` const + `is_fact_event_dual_write_enabled() -> bool` helper reading env `FF_FACT_EVENT_DUAL_WRITE`. Default `False`. Match Phase 01 strict-mode flag shape.
2. Verify dev + staging + prod env vars NOT yet set (`railway variables get FF_FACT_EVENT_DUAL_WRITE` → unset). Default OFF held.
3. Commit message: `feat(p02-pr1): add FF_FACT_EVENT_DUAL_WRITE feature flag, default OFF (D-05 PR-1)`.

**PR-2 (single commit, separate from PR-1)**:
1. **`services/backend/app/services/snapshots/snapshot_service.py`**: locate the `write_snapshot` (or equivalent) function that creates SnapshotModel rows. AFTER the SnapshotModel INSERT, add a branch:
   ```python
   from app.services.feature_flags import is_fact_event_dual_write_enabled
   from app.services.projector.fact_projector import project_fact_event
   from app.services.encryption.encrypted_value_helper import encrypt_value
   from app.models.fact_event import FactEvent
   from datetime import datetime, timezone
   import uuid_utils

   _FACT_TYPE_MAP = {
       # SnapshotModel column → fact_type (derived from SnapshotModel inspection)
       "gross_income": "monthly_gross_income",
       "lpp_avoirs_vieillesse": "lpp_avoirs_vieillesse",
       "pillar_3a_balance": "pillar_3a_balance",
       # ... all SnapshotModel scalar fields that map 1:1 to a fact_type
   }

   if is_fact_event_dual_write_enabled():
       with db.begin_nested():  # caller already in transaction; nested savepoint
           for column_name, fact_type in _FACT_TYPE_MAP.items():
               value = getattr(snapshot, column_name, None)
               if value is None:
                   continue
               event = FactEvent(
                   event_id=str(uuid_utils.uuid7()),
                   subject_type="user",
                   subject_id=user_id,
                   fact_type=fact_type,
                   value_enc=encrypt_value(db, user_id, value),
                   source_type="snapshot",
                   observed_at=snapshot.computed_at,
                   recorded_at=datetime.now(timezone.utc),
               )
               project_fact_event(db, event)
   ```
   NB: use `db.begin_nested()` (SAVEPOINT) NOT `db.begin()` — the caller's session is already in a transaction. The SnapshotModel write + fact_event/fact_current writes commit atomically as a unit per D-19 atomicity.
2. **`services/backend/tests/integration/test_dual_write_off.py` (NEW)**: pg_fixture. Assert that with `FF_FACT_EVENT_DUAL_WRITE` unset (default OFF), `write_snapshot(...)` creates 1 SnapshotModel row and 0 fact_event/fact_current rows.
3. **`services/backend/tests/integration/test_dual_write_on_staging.py` (NEW)**: pg_fixture. Monkey-patch `is_fact_event_dual_write_enabled` to return `True`. Call `write_snapshot(...)` with a profile having e.g. 5 non-null fact_type fields. Assert: 1 SnapshotModel row + 5 fact_event rows + 5 fact_current rows; each `decrypt_value(db, user_id, fact_current.value_enc) == getattr(snapshot, mapped_column_name)`. Idempotency: call again with same observed_at/source_id → 0 new fact_event rows (UNIQUE blocks), `mint_projector_idempotency_skip_total` increments by 5.
4. Commit: `feat(p02-pr2): dual-write SnapshotModel → fact_event under FF (default OFF) (D-05 PR-2)`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_dual_write_off.py tests/integration/test_dual_write_on_staging.py -q -k pg && python3 -m pytest tests/ -q -x && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/hmac_pepper_audit.py services/backend/app/ && python3 tools/checks/banned_terms_python.py services/backend/app/services/snapshots/snapshot_service.py services/backend/app/services/feature_flags.py</automated>
  </verify>
  <acceptance_criteria>
    - `git grep -n "FF_FACT_EVENT_DUAL_WRITE\|is_fact_event_dual_write_enabled" services/backend/app/services/feature_flags.py` returns ≥2 hits.
    - `cd services/backend && python3 -c "from app.services.feature_flags import is_fact_event_dual_write_enabled; assert is_fact_event_dual_write_enabled() == False"` exits 0 (default OFF).
    - `cd services/backend && python3 -m pytest tests/integration/test_dual_write_off.py -q -k pg` exits 0 — SnapshotModel created, fact_event/fact_current empty.
    - `cd services/backend && FF_FACT_EVENT_DUAL_WRITE=on python3 -m pytest tests/integration/test_dual_write_on_staging.py -q -k pg` exits 0 — parity proven for ≥5 fact_types.
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0 (full suite; baseline + delta from Plan 02-02 + ~2 new tests).
    - PR-1 and PR-2 are SEPARATE commits (git log shows two commits; PR-1 sha != PR-2 sha).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/` exits 0.
  </acceptance_criteria>
  <done>
    PR-1: FF added, default OFF, no behavior change in any env. PR-2: dual-write code path compiled + tested with FF-ON in test fixtures; in prod the FF stays OFF so SnapshotModel-only behavior unchanged. The next task (Task 2 PR-3) flips the FF to ON in staging + atomically cuts over reads + flips the parity-lint HARD.
  </done>
</task>

<task type="checkpoint:superseded" gate="blocking">
  <name>Task 2 (SUPERSEDED iter-2): PR-3 atomic trio (D-31) — backfill idempotent + /v1/projection read-cutover + profile_safe_fields_parity SOFT→HARD. Three changes ONE PR. Then Julien gates staging-zero-drift before merge to dev.</name>
  <what-built>
    <!-- SUPERSEDED in iter-2 by Task 2a + Task 2b. DO NOT EXECUTE THIS CHECKPOINT. -->
    <!-- The « atomic trio » framing was operationally unsafe per 4-way reviewer convergence (architect-review MED + database-architect MED-6 + postgres-pro MED-5 + qa-expert HIGH-1). PR-3 has been split into PR-3a (backfill-only) + PR-3b (read-cutover + HARD parity-lint flip atomic). The 2 replacement checkpoints are Task 2a + Task 2b below in the iter-2 revision block. -->

    Claude has implemented PR-3 as a single PR containing three load-bearing changes per CONTEXT D-31 atomicity rule:

    1. **`services/backend/scripts/backfill_snapshot_to_fact_event.py` (NEW)**: idempotent backfill script. Reads all SnapshotModel rows; for each row, emits fact_event for each `_FACT_TYPE_MAP` field; calls `project_fact_event` inside `session.begin()`. Re-running = 0 new rows (UNIQUE blocks dups; `mint_projector_idempotency_skip_total` increments).
    2. **`services/backend/app/api/v1/endpoints/projection.py` + `snapshots.py`**: GET /v1/projection/{user_id} (and /v1/snapshots/* if applicable) read from `FactCurrent` PK lookups instead of `SnapshotModel`. Build response by decrypting each `fact_current.value_enc` via `decrypt_value`.
    3. **`tools/checks/profile_safe_fields_parity.py`**: invocations in `lefthook.yml` + `.github/workflows/design-lints.yml` now include `--hard`. New allowlist file `tools/checks/profile_safe_fields_parity_allowlist.txt` containing exactly 3 Flutter-only field names (pending Plan 02-04 PR-A3 drop) is read by the script.

    All wired in a single Git commit (or commit chain on the SAME PR), CI green on dev. NEXT: Julien must verify zero-drift in staging before merge to dev.
  </what-built>
  <how-to-verify>
    **Pre-checkpoint Claude actions (already done before this checkpoint fires)**:
    1. Set `FF_FACT_EVENT_DUAL_WRITE=on` on Railway staging only (`railway variables set FF_FACT_EVENT_DUAL_WRITE=on --environment staging`). Prod stays OFF.
    2. Wait for staging deploy of PR-3 branch to complete (`railway logs --environment staging | grep "Application startup complete"`).
    3. Run the backfill script against Railway staging Postgres: `cd services/backend && DATABASE_URL=$STAGING_DATABASE_URL python3 scripts/backfill_snapshot_to_fact_event.py --dry-run` then `--apply`. Capture stdout in `/tmp/backfill_staging.log`.
    4. Re-run with `--apply` to verify idempotency: should report `0 new fact_event rows; N idempotency_skip increments`.
    5. Run a comparison query against staging Postgres: pick 20 random user_ids; for each compare `/v1/projection/{user_id}` output against the pre-existing `SnapshotModel`-derived projection (use a `?legacy=true` query-param escape hatch added in PR-3 for the dual-read window, removed in PR-4). Capture diff in `/tmp/projection_parity.log`.
    6. Run lefthook HARD-mode lint: `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt`; expected exit 0 (3 Flutter-only fields whitelisted, all other server-canonical fields emitted by Flutter post-Plan-02-01 PR-A2).

    **Julien verifies (in this order)**:
    1. **Open staging endpoint health**: `curl -sf https://mint-staging.up.railway.app/healthz` returns 200.
    2. **Open backfill log**: read `/tmp/backfill_staging.log` (Claude tees it). Expected first run: `Backfilled N users → M fact_event rows`. Expected second run: `0 new fact_event rows; M idempotency_skip increments`.
    3. **Open projection parity log**: read `/tmp/projection_parity.log`. Expected: `20/20 users — projection output identical between fact_current (new) and SnapshotModel-derived (legacy)`.
    4. **Sample test on staging**: pick 1 user from Julien's own staging test account; run:
       ```bash
       curl -sf "https://mint-staging.up.railway.app/v1/projection/$USER_ID" > /tmp/proj_new.json
       curl -sf "https://mint-staging.up.railway.app/v1/projection/$USER_ID?legacy=true" > /tmp/proj_legacy.json
       diff /tmp/proj_new.json /tmp/proj_legacy.json
       ```
       Expected: empty diff (zero drift).
    5. **Confirm HARD lint passes**: `cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt; echo "exit=$?"` — expect exit=0.
    6. **Confirm `mint_projector_idempotency_skip_total` is non-zero on staging** (proves backfill ran twice = idempotency proven on real data) via Railway metrics or `curl -sf https://mint-staging.up.railway.app/metrics | grep mint_projector_idempotency_skip_total`.

    **Gate decision**:
    - ALL six checks pass → type "approved — zero drift, HARD lint green, backfill idempotent on staging" → Claude merges PR-3 to dev.
    - ANY check fails → describe failure mode; Claude diagnoses + ships a fix-up commit on the same PR branch before re-asking.
  </how-to-verify>
  <resume-signal>
    « This checkpoint is SUPERSEDED by iter-2 PR-3 split. Do not type any resume signal here. Proceed directly to Task 2a (PR-3a) and Task 2b (PR-3b) — those checkpoints replace this one. »
  </resume-signal>
</task>

<task type="auto">
  <name>Task 3: PR-4 dual-write decommission (remove FF + deprecation marker on SnapshotModel writers) — autonomous, lands on dev after PR-3 merged</name>
  <files>
    services/backend/app/services/feature_flags.py,
    services/backend/app/services/snapshots/snapshot_service.py,
    services/backend/tests/services/snapshot_deprecation/__init__.py,
    services/backend/tests/services/snapshot_deprecation/test_snapshot_deprecation.py,
    services/backend/app/observability/counters.py
  </files>
  <read_first>
    services/backend/app/services/feature_flags.py (post-PR-1 state — FF helper to remove),
    services/backend/app/services/snapshots/snapshot_service.py (post-PR-2 state — dual-write branch to remove + add deprecation marker on SnapshotModel write)
  </read_first>
  <action>
**PR-4 (autonomous, single commit on dev)**:
1. **`services/backend/app/services/feature_flags.py`**: remove `FF_FACT_EVENT_DUAL_WRITE` constant + `is_fact_event_dual_write_enabled` helper. The FF served its migration purpose; readers post-PR-3 don't reference it.
2. **`services/backend/app/services/snapshots/snapshot_service.py`**: remove the `if is_fact_event_dual_write_enabled():` branch and the `_FACT_TYPE_MAP` map. Replace with:
   ```python
   import warnings
   warnings.warn(
       "SnapshotModel writes are deprecated; use fact_event + fact_current via project_fact_event(). "
       "SnapshotModel will be dropped in alembic p117 (Plan 02-03 PR-5).",
       DeprecationWarning,
       stacklevel=2,
   )
   # SnapshotModel INSERT retained for one-release deprecation cycle (PR-5 drops the table).
   ```
3. **NEW writer path post-PR-4**: any code that needs to write a user-fact MUST go directly through `project_fact_event` + `encrypt_value`. The dual-write era ends here.
4. **`services/backend/tests/services/snapshot_deprecation/test_snapshot_deprecation.py` (NEW)**: pytest `recwarn` fixture asserts that `write_snapshot(...)` emits a `DeprecationWarning` with message matching `"SnapshotModel writes are deprecated"`.
5. **Drift telemetry counter**: in `services/backend/app/observability/counters.py` add `mint_snapshot_fact_current_drift_total` Counter. Wire it in PR-3's read endpoint: when the `?legacy=true` escape hatch is invoked (during PR-3 → PR-5 dual-read window), if `fact_current`-derived output ≠ `SnapshotModel`-derived output, increment the counter. Plan 02-04 close-out activates the alarm.
6. **CI grep assertion**: `! git grep -rn "FF_FACT_EVENT_DUAL_WRITE\|is_fact_event_dual_write_enabled" services/backend/app/` returns exit 1 → 0 occurrences post-PR-4. Add a `tools/checks/no_ff_fact_event_dual_write.py` one-line lint to enforce going forward; wire as HARD lefthook on `services/backend/app/**/*.py`.
7. Commit: `refactor(p02-pr4): remove FF_FACT_EVENT_DUAL_WRITE; deprecate SnapshotModel writes (D-05 PR-4)`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/services/snapshot_deprecation -q && python3 -m pytest tests/ -q -x && ! git grep -rn "FF_FACT_EVENT_DUAL_WRITE\|is_fact_event_dual_write_enabled" services/backend/app/ && python3 tools/checks/no_ff_fact_event_dual_write.py services/backend/app/ && python3 tools/checks/banned_terms_python.py services/backend/app/services/snapshots/</automated>
  </verify>
  <acceptance_criteria>
    - `git grep -rn "FF_FACT_EVENT_DUAL_WRITE" services/backend/app/` returns 0 hits.
    - `git grep -rn "is_fact_event_dual_write_enabled" services/backend/app/` returns 0 hits.
    - `cd services/backend && python3 -m pytest tests/services/snapshot_deprecation -q` exits 0 (DeprecationWarning emitted).
    - `cd services/backend && python3 -m pytest tests/ -q` exits 0 (full suite green; ~+1 deprecation test).
    - `python3 tools/checks/no_ff_fact_event_dual_write.py services/backend/app/` exits 0.
    - `git grep -n "mint_snapshot_fact_current_drift_total" services/backend/app/observability/counters.py` returns 1 hit.
  </acceptance_criteria>
  <done>
    FF removed cleanly. SnapshotModel writers emit DeprecationWarning. Drift telemetry counter wired. One week of observability soak before PR-5 drops the table (Task 4 checkpoint).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: PR-5 SnapshotModel drop (irreversible — Julien gates after 1-week post-PR-4 observability soak)</name>
  <what-built>
    Claude has prepared PR-5: alembic p117 drops the `snapshots` table on Postgres (and SQLite), removes `services/backend/app/models/snapshot.py`, and ships `docs/operations/snapshot-model-decommission.md` documenting the rollback procedure (pg_restore from `tools/db/baseline_snapshot_2026-05-18.sql` + a fresh dump captured AT MERGE TIME of PR-5).

    BEFORE pushing the PR for merge, Claude has run the staging soak: `mint_snapshot_fact_current_drift_total` counter on Railway staging metrics over the past 7 days post-PR-4 deploy. The counter MUST read 0 (zero drift between fact_current and the legacy SnapshotModel-derived path which is still being shadow-read for parity verification).

    PR-5 is IRREVERSIBLE in the sense that re-creating `SnapshotModel` after drop requires either (a) restoring from baseline + replaying writes since baseline, or (b) deriving SnapshotModel state by reading fact_current + reconstructing. Both are operationally painful — the gate exists to ensure Julien acknowledges this before the merge.
  </what-built>
  <how-to-verify>
    **Pre-checkpoint Claude actions**:
    1. Verify PR-3 has been merged to dev for ≥ 7 days (`gh pr view <PR-3-NUM> --json mergedAt`).
    2. Verify PR-4 has been merged to dev for ≥ 5 days (`gh pr view <PR-4-NUM> --json mergedAt`).
    3. Query Railway staging metrics for the past 7 days:
       ```bash
       curl -sf https://mint-staging.up.railway.app/metrics | grep mint_snapshot_fact_current_drift_total
       ```
       Expected: counter value = 0 (or very low — < 5 over 7 days). If non-zero, INVESTIGATE before proposing PR-5.
    4. Run a full migration-test cycle against pg_fixture: `cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py -q -k pg`. The test runs alembic p117 forward, asserts `snapshots` table no longer exists, then runs `alembic downgrade` and asserts the table is re-created (downgrade idempotent).
    5. Regenerate `tools/db/baseline_snapshot_2026-05-18.sql` to capture the AT-MERGE state (rename to `tools/db/baseline_snapshot_phase02_pre_drop.sql` and commit alongside p117).
    6. Open `docs/operations/snapshot-model-decommission.md` and verify it documents: (a) how to rollback p117 in case of incident (alembic downgrade + restore from baseline_phase02_pre_drop.sql + replay fact_event back into a re-created SnapshotModel via reverse-projector script — outline only, not implemented), (b) which Sentry alarms to watch for in the 48h post-merge, (c) how to re-enable the dual-read endpoint if needed.

    **Julien verifies**:
    1. **Read drift-counter output**: `curl -sf https://mint-staging.up.railway.app/metrics | grep mint_snapshot_fact_current_drift_total`. Expected: 0 or ≤ 5 over 7 days. If higher → BLOCK PR-5, file an issue.
    2. **Read decommission runbook**: open `docs/operations/snapshot-model-decommission.md` end-to-end. Confirm the rollback procedure is intelligible + executable from the runbook alone (no tribal knowledge needed).
    3. **Confirm baseline snapshot file**: `ls -la tools/db/baseline_snapshot_phase02_pre_drop.sql` exists, ≥ 50 lines, contains `CREATE TABLE snapshots`.
    4. **Confirm pg_fixture migration test**: `cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py -q -k pg` exit 0.
    5. **Production env-var check**: `FF_FACT_EVENT_DUAL_WRITE` is NOT set on Railway production (PR-4 already removed the code path; this is a defense-in-depth check that no stale env var persists).
    6. **Sentry alarm wiring**: confirm Sentry has an alert configured on `mint_snapshot_fact_current_drift_total > 0` (Plan 02-04 close-out wires this; if pending, this checkpoint may slip to Plan 02-04 ordering).
    7. **Type the gate decision**.

    **Decision**:
    - ALL 6 checks pass + Julien acknowledges irreversibility → "approved — drop SnapshotModel, 7-day drift counter = 0, runbook readable" → Claude merges PR-5.
    - ANY check fails → describe; Claude addresses + re-asks.
    - Julien wants to slip the drop → "defer to v2.next" → Claude leaves PR-5 unmerged, opens an issue tracking the deferral; SnapshotModel stays.
  </how-to-verify>
  <resume-signal>
    Type "approved — drop SnapshotModel, 7-day drift counter = 0, runbook readable" OR "defer to v2.next — reason: <X>" OR describe failure mode for fix-up.
  </resume-signal>
</task>

<task type="auto">
  <name>Task 5: PR-5 execution (post-checkpoint approval) — ship alembic p117 + remove SnapshotModel + commit drift-resolution telemetry test + observability test</name>
  <files>
    services/backend/alembic/versions/p117_drop_snapshot_legacy.py,
    services/backend/app/models/snapshot.py,
    services/backend/tests/integration/test_snapshot_drop.py,
    services/backend/tests/integration/test_backfill_idempotent.py,
    services/backend/tests/integration/test_read_cutover.py,
    services/backend/tests/observability/test_drift_telemetry.py,
    docs/operations/snapshot-model-decommission.md,
    tools/db/baseline_snapshot_phase02_pre_drop.sql,
    services/backend/app/api/v1/endpoints/projection.py,
    services/backend/app/api/v1/endpoints/snapshots.py
  </files>
  <read_first>
    services/backend/alembic/versions/p116_snapshot_constants_invalidation.py (head before PR-5),
    services/backend/app/models/snapshot.py (file to remove),
    services/backend/app/api/v1/endpoints/projection.py + snapshots.py (post-PR-3 state — remove the `?legacy=true` escape hatch and the SnapshotModel-derived branch)
  </read_first>
  <action>
**This task fires ONLY after Task 4 checkpoint resolves "approved"**. Steps:
1. **`services/backend/alembic/versions/p117_drop_snapshot_legacy.py` (NEW)**: `down_revision = "p116_snapshot_constants_invalidation"`. `upgrade()`: `op.drop_table("snapshots")`. `downgrade()`: re-create the table with full schema (copy from current `app/models/snapshot.py` BEFORE deleting it — preserve the DDL in the migration body as a recovery anchor). The downgrade is a courtesy; recovery from production data loss requires the baseline SQL file.
2. **Remove `services/backend/app/models/snapshot.py`**: file deletion + remove all `from app.models.snapshot import SnapshotModel` imports across the codebase. The post-PR-3 read endpoints already use FactCurrent.
3. **Remove `?legacy=true` query-param escape hatch** from `services/backend/app/api/v1/endpoints/projection.py` + `snapshots.py` (introduced in PR-3 for the dual-read window). All reads now exclusively from fact_current.
4. **`services/backend/tests/integration/test_snapshot_drop.py` (NEW)**: pg_fixture. Runs alembic upgrade head; asserts `snapshots` table no longer exists in Postgres `pg_catalog.pg_tables`. Runs alembic downgrade by-one (p117 → p116); asserts `snapshots` table re-exists with full schema.
5. **`services/backend/tests/integration/test_backfill_idempotent.py` (NEW, retroactive — proves PR-3 backfill is idempotent)**: pg_fixture-based unit test for `scripts/backfill_snapshot_to_fact_event.py`. Seed fact_event with 3 rows; run backfill again; assert 0 new rows + idempotency counter increments by 3.
6. **`services/backend/tests/integration/test_read_cutover.py` (NEW, retroactive — proves PR-3 read-cutover works)**: pg_fixture. Seed fact_event + fact_current; call /v1/projection/{user_id}; assert response built from fact_current (no SnapshotModel read in handler — assertable via traceback or by mocking SnapshotModel and verifying NOT called).
7. **`services/backend/tests/observability/test_drift_telemetry.py` (NEW)**: assert `mint_snapshot_fact_current_drift_total` counter exists in `app.observability.counters` and can be incremented (smoke test).
8. **`docs/operations/snapshot-model-decommission.md` (NEW, ≥ 50 lines)**: per CONTEXT D-05 PR-5 runbook. Sections: (a) Purpose + status, (b) When this was executed, (c) Rollback procedure step-by-step (alembic downgrade + pg_restore from `tools/db/baseline_snapshot_phase02_pre_drop.sql` + replay events from fact_event into a re-created SnapshotModel via a reverse-projector outline), (d) Sentry alarms to watch in 48h post-merge, (e) Re-enabling dual-read endpoint if needed (revert PR-5 commit), (f) Counter-arguments + data gaps block per wiki-lint.
9. **`tools/db/baseline_snapshot_phase02_pre_drop.sql` (NEW)**: regenerated pg_dump of Postgres state RIGHT BEFORE PR-5 lands. Committed alongside.
10. Run full pytest + lints + wiki_lint on the new runbook.
11. Commit: `feat(p02-pr5): drop SnapshotModel table; fact_current is sole canonical projection (D-05 PR-5)`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py tests/integration/test_backfill_idempotent.py tests/integration/test_read_cutover.py tests/observability/test_drift_telemetry.py -q -k pg && python3 -m pytest tests/ -q -x && ! git ls-files services/backend/app/models/snapshot.py && ! git grep -rn "from app.models.snapshot import SnapshotModel" services/backend/ && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/wiki_lint.py lint --strict && ls -la tools/db/baseline_snapshot_phase02_pre_drop.sql && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/hmac_pepper_audit.py services/backend/app/</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py -q -k pg` exits 0; pg_fixture confirms `snapshots` table absent after upgrade, re-present after downgrade.
    - `git ls-files services/backend/app/models/snapshot.py` returns empty (file deleted).
    - `! git grep -rn "from app.models.snapshot import SnapshotModel" services/backend/` returns exit code 1 (no hits = exit 1 in `grep -E ...`; the `!` inverts to exit 0).
    - `git grep -rn "from app.models.snapshot" services/backend/` returns 0 hits.
    - `git grep -n "?legacy=true\|legacy.*query.*param" services/backend/app/api/v1/endpoints/projection.py services/backend/app/api/v1/endpoints/snapshots.py` returns 0 hits.
    - `python3 tools/checks/wiki_lint.py lint --strict` exits 0 after committing the runbook (full-suite pass; covers `.planning/**/*.md` + `docs/**/*.md`; counter-arguments + data gaps block present in `docs/operations/snapshot-model-decommission.md`).
    - `ls -la tools/db/baseline_snapshot_phase02_pre_drop.sql` shows file ≥ 50 lines, contains `CREATE TABLE snapshots` (preserved as recovery anchor).
    - Full pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (≥ Plan 02-02 baseline + new tests).
    - `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` exits 0.
    - `python3 tools/checks/hmac_pepper_audit.py services/backend/app/` exits 0.
  </acceptance_criteria>
  <done>
    SnapshotModel is dropped. fact_current is the sole canonical user-facts projection storage. Rollback procedure documented + baseline SQL committed. The W3 → W4 gate is met. The 5-PR migration sequence (D-05) ships complete.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Feature flag env var → app process | `FF_FACT_EVENT_DUAL_WRITE` controls writer code path during PR-2 → PR-3 transition |
| Backfill script → Railway staging Postgres | One-shot writer with idempotency relying on D-27 UNIQUE constraint |
| Read endpoint `/v1/projection` → fact_current PK lookup | Post-PR-3, sole canonical read path |
| Alembic p117 drop → Postgres | Irreversible without baseline restore |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-06 | Tampering / Integrity | Read-cutover drift (fact_current ≠ SnapshotModel) | mitigate | PR-3 atomic D-31 trio: backfill idempotent + read-cutover + parity-lint HARD all in same PR. Julien staging-zero-drift gate (Task 2 checkpoint) verifies before merge. `mint_snapshot_fact_current_drift_total` counter wired (Plan 02-04 close-out assertion) to catch post-merge regressions. |
| T-02-07 | Information Disclosure (data loss) | Orphan SnapshotModel data post-drop | mitigate | PR-5 (Task 4 + Task 5) gated on 1-week observability soak + Julien checkpoint. `tools/db/baseline_snapshot_phase02_pre_drop.sql` captured at merge time + committed as recovery anchor. Rollback procedure documented in `docs/operations/snapshot-model-decommission.md`. |
| T-02-18 | Tampering | Stale `FF_FACT_EVENT_DUAL_WRITE` env var persists post-PR-4 | mitigate | PR-4 removes the code reading the FF + adds CI grep assertion (`tools/checks/no_ff_fact_event_dual_write.py` HARD lefthook). Even if Railway env var stays set, app code doesn't read it. |
| T-02-19 | Tampering | Backfill non-idempotency creates dup events | mitigate | D-27 UNIQUE constraint blocks dups at DB layer. `test_backfill_idempotent.py` exercises re-run and asserts 0 new rows + idempotency counter increments. |
| T-02-20 | Repudiation | PR-5 merge without baseline capture | mitigate | Task 5 step 9 commits `tools/db/baseline_snapshot_phase02_pre_drop.sql` IN THE SAME COMMIT as the table drop. Pre-commit lint could enforce, but git review serves as the gate. |
| T-02-21 | Information Disclosure | `?legacy=true` escape hatch leaks SnapshotModel data post-Phase-02-close | mitigate | Task 5 step 3 removes the escape hatch atomically with the table drop. No path to query legacy data remains. |
</threat_model>

<verification>
**Phase-level checks for this plan:**
1. **Checkpoint ordering**: Tasks 1 → 2 (checkpoint) → 3 → 4 (checkpoint) → 5. Task 5 only fires after Task 4 resolves "approved".
2. **PR-3 atomicity is non-negotiable** (D-31): if the backfill ships separately from the read-cutover OR the lint flip ships separately, the migration choreography is broken. Reviewer guidance: if PR-3 fails review for any of the 3 components, fix-up commit on the SAME PR; do not split.
3. **Wave gate**: W3 exit = PR-5 merged + post-merge sim health check green + Sentry no critical alarms in 48h. Plan 02-04 close-out picks up after PR-5 merge.
4. **`autonomous: false`** for 2 reasons (operational gates only):
   - Task 2 (PR-3 staging-zero-drift gate, Julien-checked per CONTEXT D-31 + 0-trust §9.5 stage-3 "Merged" gate).
   - Task 4 (PR-5 post-soak drop gate, Julien-acknowledged irreversibility).
   Tasks 1, 3, 5 are autonomous (code-only; CI-gated).
5. **0-trust §9**: SUMMARY at close-out cites: (a) 5 PR URLs in order, (b) the merge timestamps proving 1-week soak between PR-4 merge and PR-5 merge, (c) drift-counter value at PR-5 merge time, (d) Julien approval strings for Tasks 2 + 4, (e) full pytest exit-0 after PR-5, (f) baseline SQL file SHA committed.
6. **No silent scope reduction**: every D-XX in CONTEXT decisions remains delivered AT FULL FIDELITY. If staging-zero-drift fails on Task 2 verify step, do NOT reduce scope — diagnose + fix + re-run.
</verification>

<success_criteria>
- [ ] PR-1 merged: `FF_FACT_EVENT_DUAL_WRITE` added, default OFF, no behavior change.
- [ ] PR-2 merged: dual-write code path compiled + tested with FF-ON in fixtures.
- [ ] PR-3 merged: atomic D-31 trio shipped (backfill idempotent + /v1/projection reads fact_current + profile_safe_fields_parity HARD); Julien staging-zero-drift gate passed.
- [ ] PR-4 merged: FF removed; SnapshotModel writers emit DeprecationWarning; drift telemetry counter wired.
- [ ] PR-5 merged: SnapshotModel table dropped; fact_current is sole canonical projection; baseline SQL committed; runbook published.
- [ ] `cd services/backend && python3 -m pytest tests/ -q` exits 0 after each PR merge.
- [ ] `! git grep -rn "from app.models.snapshot" services/backend/` returns exit code 1 (no hits) after PR-5.
- [ ] `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` exits 0 (Plan 02-04 PR-A3 will clean the 3 allowlisted fields).
- [ ] `mint_snapshot_fact_current_drift_total` counter declared + wired in PR-4 (Plan 02-04 asserts firing).
- [ ] `docs/operations/snapshot-model-decommission.md` ships ≥ 50 lines, wiki_lint clean (counter-arguments + data gaps blocks).
- [ ] `tools/db/baseline_snapshot_phase02_pre_drop.sql` committed AT PR-5 merge.
- [ ] 5 PR URLs documented in SUMMARY with merge SHAs.
- [ ] Julien checkpoint approval strings preserved verbatim in SUMMARY (Task 2 + Task 4).
- [ ] 0-trust §9.6 evidence/caveat block in SUMMARY.
</success_criteria>

<output>
After completion, create `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-SUMMARY.md`. Required content:
- 5 PR URLs + merge SHAs + merge timestamps (proving ≥7d soak between PR-3 merge and PR-5 merge).
- Per-PR `<verify>` automated command stdout.
- Julien approval strings for Task 2 + Task 4 checkpoints (verbatim).
- Drift-counter value at PR-5 merge (must be 0 or low).
- Baseline SQL file SHA committed alongside p117.
- 3 D-XX dispositions: D-04 (constants-PIT verified by PR-2 dual-write parity test), D-05 (5-PR sequence shipped), D-31 (SOFT→HARD atomic with PR-3).
- 0-trust §9.6 Evidence + Caveat block.
- `mem_save` with `topic_key: mint-data-architecture-v1-02:wave-2-3:five-pr-migration` + `prior_finding_refs` to obs #174, #178, #186, #188 + Plan 02-01 + Plan 02-02 obs.
</output>

---

<!-- ============================================================== -->
<!-- ITER-2 REVIEWS REVISION — appended 2026-05-18                 -->
<!-- STRUCTURAL CHANGE: 5-PR sequence → 6-PR sequence (PR-3 SPLIT). -->
<!-- A9 + A10 + B1 + B3 + B5 + B14 + B18 land here.                 -->
<!-- ============================================================== -->

<iter_2_revision>

## Iter-2 Reviews Revision — Plan 02-03

**Trigger:** REVIEWS.md 4-way convergence on PR-3 unsafe atomicity (architect-review MED + database-architect MED-6 + postgres-pro MED-5 + qa-expert HIGH-1) + zero-drift gate undefined (qa-expert HIGH-1 + postgres-pro MED-5).

**STRUCTURAL CHANGE — Plan 02-03 is renamed:**

| Before iter-1 | After iter-2 |
|---|---|
| filename: `*-03-migration-5pr-sequence-PLAN.md` | filename: **unchanged** (filename preserved for git history ; the « 5pr » slug in the filename is now legacy — content describes 6-PR sequence) |
| « 5-PR migration sequence » | « **6-PR migration sequence** : PR-3 split into PR-3a (backfill-only, idempotent, row-count-delta=0 gate) + PR-3b (read-cutover + HARD parity-lint flip atomic) » |
| PR ordering : PR-1 → PR-2 → PR-3 (atomic trio) → PR-4 → PR-5 | PR ordering : **PR-0 (zero-user prod gate) → PR-1 → PR-2 → PR-3a (backfill-only) → PR-3b (read-cutover + HARD flip atomic) → PR-4 → PR-5** |
| Task count : 5 | Task count : **7** (Task 0 NEW + Task 2 SPLIT into Task 2a + Task 2b) |
| `<task>` blocks : 5 | `<task>` blocks : **7** |

Recommended ROADMAP.md entry hint update : « **Plan 02-03 — 6-PR migration sequence (was: 5-PR)** : zero-user prod gate + dual-write FF infra + backfill split from cutover + deterministic drift gate. »

**Tier-A blockers handled here (3 of 11):**
- A9: PR-3 split — backfill (PR-3a) operationally separable from cutover (PR-3b). PR-3a is idempotent + row-count-delta=0 gate ; PR-3b is read-cutover + HARD parity-lint flip atomic.
- A10: `tools/parity/projection_diff.py` deterministic drift definition — canonical JSON via `sort_keys=True, default=str` + Decimal tolerance `1e-9` + missing-key==NULL rule. The « zero drift » assertion previously was « `diff /tmp/proj_new.json /tmp/proj_legacy.json` → empty diff » with no canonicalisation — qa-expert HIGH-1.
- A11 (consumer): assumes the multi-shape canary from Plan 02-02 Task 3C has been parity-PROVEN ; this is a precondition of Task 2a (backfill).

**Tier-B handled here:**
- B1: Pre-flight zero-user prod gate `SELECT COUNT(*) FROM users` at head of Plan (Task 0 NEW).
- B3: D-12 label collision rename — `Phase-01 D-12` (parity-lint) vs `D-MOB-03` (Mobile L1 audit). Updates `requirements_addressed` + all `<verify>` blocks.
- B5: 7th gate pre-HARD-flip pg_dump snapshot + restore-on-diff path (Task 2b).
- B14: 100% staging users SHA-256 canonical-JSON parity audit, persist to `_phase02_parity_audit` table (Task 2a).
- B18: Continuous drift sampler Railway cron 30min × 100 users × 7-day soak (Task 2b checkpoint).
- B19: Plan 02-03 PR-5 enumeration of Phase 01 SnapshotModel-referencing tests (Task 5 patch).
- B20: D-31 soak duration reconciled — CONTEXT says « 1-week », Plan said « ≥7 days », REVIEWS says « 14-day ». **Reconciliation : 7 days minimum, 14 days target.** CONTEXT.md change proposed below.

**Tier-C acknowledged:**
- C2: PR-3 commit-message contract → applied in Task 2a + Task 2b commit message templates below.

**Tier-A not handled here:**
- A1-A8: Plan 02-02 iter-2.

### CONTEXT.md changes proposed by this revision (PROPOSED — owner-approval required)

**D-05 (Migration strategy)** — restructure 5-PR → 6-PR:
```diff
-  - **D-05:** **Q5 — Migration strategy from SnapshotModel.** Big-bang cut-over, 5-PR sequence (postgres-pro lock).
+  - **D-05:** **Q5 — Migration strategy from SnapshotModel.** Big-bang cut-over, **6-PR sequence** (iter-2 A9 — PR-3 split per 4-way reviewer convergence on backfill-vs-cutover separability) :
     PR-1 schema introduction (additive p98) →
     PR-2 dual-write feature-flagged off →
-    PR-3 backfill script idempotent + read cut-over + HARD parity-lint flip (atomic per D-31)
+    **PR-3a backfill-only, idempotent, gated on row-count-delta=0 + 100% staging-user canonical-JSON parity audit** →
+    **PR-3b read cut-over + HARD parity-lint flip + 7th-gate pre-HARD-flip pg_dump snapshot (atomic per D-31)** →
     PR-4 dual-write decommission →
     PR-5 legacy SnapshotModel drop.
+    Reason for split (iter-2 A9): backfill interruption mid-run could leave fact_current half-populated AND reads cut over ; the original « atomic trio » framing was operationally unsafe per architect-review MED + database-architect MED-6 + postgres-pro MED-5 + qa-expert HIGH-1 (4-way convergence).
```

**D-31 (D-12 parity-lint SOFT→HARD promotion timing)** — adjust trigger PR + soak duration:
```diff
-  - **D-31:** **D-12 parity-lint SOFT→HARD promotion timing.** Atomic with **PR-3 read cut-over** in Plan 02-03 5-PR sequence.
+  - **D-31:** **D-12 parity-lint SOFT→HARD promotion timing.** Atomic with **PR-3b read cut-over** in Plan 02-03 6-PR sequence (iter-2 — PR-3a backfill ships separately as a prerequisite). **Soak duration reconciled (iter-2 B20) : 7-day minimum, 14-day target on Railway staging with continuous drift sampler (cron 30min × 100 users) ; PR-3b merges to dev only after either (a) 7-day clean window OR (b) Julien override with documented justification.** D-31 zero-drift definition deterministic per iter-2 A10 — `tools/parity/projection_diff.py` with canonical JSON `sort_keys=True, default=str` + Decimal tolerance 1e-9 + missing-key==NULL rule. Sample size is 100% of staging users, NOT 20 random — per iter-2 B14 + postgres-pro MED-5.
```

### New Task 0 — Pre-flight zero-user prod gate (Tier-B B1)

Inserted as FIRST task. Cheap and decisive : if prod has any user rows, the entire « big-bang pre-launch » premise (D-05 + CONTEXT counter-argument section) is invalid and Plan 02-03 MUST NOT proceed.

<task type="auto">
  <name>Task 0 (NEW iter-2): Pre-flight zero-user prod gate (Tier-B B1, Gemini)</name>
  <files>
    services/backend/scripts/preflight_zero_user_gate.py,
    services/backend/tests/integration/test_preflight_zero_user_gate.py
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md (counter-arguments section — « big-bang pre-launch is the only window » framing depends on zero prod users)
  </read_first>
  <action>
1. **`services/backend/scripts/preflight_zero_user_gate.py` (NEW, ≥20 LOC)**: connects to `PROD_DATABASE_URL` (env var ; if unset, exits 0 with WARN message — test path uses test DB). Runs `SELECT COUNT(*) FROM users WHERE deleted_at IS NULL` (or equivalent — grep `app/models/user.py` for soft-delete column). If count > 0:
   - exit 1
   - stdout: `BLOCKED: prod has <N> users — big-bang migration premise invalid. Plan 02-03 requires Julien escape-hatch decision (slip migration OR document deletion).`
   If count == 0:
   - exit 0
   - stdout: `OK: prod users=0 — big-bang migration safe to proceed.`
2. **`services/backend/tests/integration/test_preflight_zero_user_gate.py`**: pg_fixture seeds 0 users → expect exit 0 ; pg_fixture seeds 1 user → expect exit 1.
3. **CI integration**: add to `.github/workflows/backend-ci.yml` as a workflow_dispatch job ; NOT a per-PR gate (would need prod DB creds in CI ; instead, Claude runs the script manually before opening PR-3a as part of the « gate decision » preamble).
4. **PR description requirement**: Plan 02-03 PR-1 description MUST include the stdout of this script (exit 0 + count=0 confirmation) AS evidence that the prerequisite holds. If the script reports count > 0, Plan 02-03 STOPS and surfaces a CHECKPOINT to Julien.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_preflight_zero_user_gate.py -q -k pg && PROD_DATABASE_URL='' python3 services/backend/scripts/preflight_zero_user_gate.py 2>&1 | grep -E "WARN|OK"</automated>
  </verify>
  <acceptance_criteria>
    - Script exits 0 when `users` table is empty.
    - Script exits 1 when `users` table has any non-deleted row, with explicit BLOCKED stdout.
    - `cd services/backend && python3 -m pytest tests/integration/test_preflight_zero_user_gate.py -q -k pg` exits 0.
    - PR-1 description (when shipped per Task 1 below) includes the prod gate stdout verbatim.
  </acceptance_criteria>
  <done>
    Pre-flight zero-user prod gate active. Plan 02-03 cannot proceed if prod has any user data ; Julien must explicitly escape-hatch (slip migration to a different strategy) before any PR opens.
  </done>
</task>

### Patch to original Task 1 (PR-1 + PR-2) — D-12 label collision rename (Tier-B B3)

**Adds** a documentation rename to Task 1 ; no code change. The architect-review identified that Plan 02-03 `requirements_addressed` uses `D-12` ambiguously :
- « D-12 parity-lint SOFT→HARD » means *Phase-01 D-12* (the existing profile_safe_fields_parity lint).
- *Phase-02 D-12* in CONTEXT.md `### Area 2 — D-12` is « D-MOB-03 Mobile L1 audit POST ».

Executor running `/gsd-execute-phase` may mis-route. iter-2 renames all occurrences :

**Updated `<action>` step (insert at start of Task 1)**:

```
0. **iter-2 B3 — D-12 label rename**: replace all occurrences of « D-12 parity-lint » (or « D-12 » when meaning the Phase 01 parity-lint pattern) with « Phase-01 D-12 » in Plan 02-03 frontmatter + `<verify>` blocks + commit message templates. Replace all occurrences of « D-12 » meaning the Phase 02 Mobile L1 audit POST with « D-MOB-03 » (matches CONTEXT.md alias). After rename:
   - `requirements_addressed: - CONTEXT.md#D-12 parity-lint SOFT→HARD atomic with PR-3 read cut-over` → `requirements_addressed: - CONTEXT.md#D-31 → Phase-01 D-12 parity-lint SOFT→HARD atomic with PR-3b read cut-over`.
   - `<verify>` block « D-12 parity-lint HARD flip » → « Phase-01 D-12 parity-lint HARD flip ».
   - **NO D-MOB-03 references in this plan** (Mobile L1 audit is fully shipped in Plan 02-02 — Plan 02-03 does not touch it). The rename clarifies the routing for executors.
```

**Updated `<acceptance_criteria>` addition**:
- `git grep -n "D-12 parity-lint" .planning/phases/mint-data-architecture-v1-02-event-log-projection/` returns 0 hits (all renamed to `Phase-01 D-12 parity-lint`).
- `git grep -n "Phase-01 D-12 parity-lint" .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md` returns ≥3 hits.

### Task 2 SPLIT — Original Task 2 (PR-3 atomic trio) → Task 2a (PR-3a backfill-only) + Task 2b (PR-3b read-cutover + HARD flip) (Tier-A A9)

**Replaces** original Task 2 (single checkpoint task with 3-component atomic trio). Iter-2 splits into 2 sequential tasks, each with its own checkpoint :

- **Task 2a (NEW iter-2)** : PR-3a backfill-only, idempotent. Lands separately from read-cutover. Julien gates `row-count-delta=0` + 100% staging-user canonical-JSON parity audit (`_phase02_parity_audit` table) BEFORE Task 2b fires.
- **Task 2b (replaces original Task 2 in scope)** : PR-3b read-cutover + Phase-01 D-12 parity-lint HARD flip atomic. Lands AFTER Task 2a checkpoint resolves « approved ». Julien gates 7-day continuous-drift-sampler clean window + 7th-gate pre-HARD-flip pg_dump snapshot.

Original Task 2 content is INVALIDATED by this split. Executor MUST use the two replacement tasks below.

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2a (NEW iter-2 — replaces original Task 2 PR-3 backfill component): PR-3a backfill-only, idempotent, gated on row-count-delta=0 + 100% staging-user canonical-JSON parity audit (Tier-A A9 + A10 + Tier-B B14)</name>
  <what-built>
    Claude has implemented PR-3a as a single PR containing TWO load-bearing changes :

    1. **`services/backend/scripts/backfill_snapshot_to_fact_event.py` (NEW)** — idempotent backfill. Reads all SnapshotModel rows ; for each row, emits fact_event for each `_FACT_TYPE_MAP` field ; calls `project_fact_event` inside `session.begin()`. **NOT** read-cutover — the `/v1/projection` endpoint still reads from SnapshotModel (or both, via `?legacy=true` escape hatch) until Task 2b fires.
    2. **`tools/parity/projection_diff.py` (NEW)** — deterministic drift definition per iter-2 A10 :
       - JSON canonicalisation : `json.dumps(value, sort_keys=True, default=str, separators=(",", ":"))`.
       - Decimal tolerance : `abs(a - b) < Decimal("1e-9")` (NOT float equality).
       - Missing-key rule : a key absent from one side AND present-with-None on the other = EQUAL (NOT diff).
       - Decimal precision : preserve trailing zeros (`Decimal("12345.00")` vs `Decimal("12345.0")` — first is preserved by JSON canonical via str()).
       - Self-test mode : run against `tests/fixtures/parity_diff_fixtures.py` with 6 known-equal and 6 known-different pairs.

    NOT yet shipped (defer to Task 2b) :
    - Read endpoint cutover from SnapshotModel to FactCurrent.
    - `profile_safe_fields_parity.py` SOFT→HARD flip in lefthook + CI.

    Before this checkpoint fires, Claude has run :
    - The backfill script against Railway staging Postgres (first run + idempotent second run).
    - The new `projection_diff.py` against 100% of staging users — output persisted to a new staging table `_phase02_parity_audit` (created by an additive migration p118).
    - Captured the row-count-delta verification : `SELECT COUNT(*) FROM fact_event WHERE source_type='snapshot_backfill'` (post-run-1) == (post-run-2) — proves second run idempotent.
  </what-built>
  <how-to-verify>
    **Pre-checkpoint Claude actions** :
    1. **Run preflight zero-user prod gate (Task 0)** : `python3 services/backend/scripts/preflight_zero_user_gate.py` exit 0.
    2. **Verify Plan 02-02 Task 3C multi-shape canary parity gate PASSED** : `cd services/backend && python3 -m pytest tests/integration/test_canary_multi_shape_parity.py -q -k pg` exits 0 ; SUMMARY of Plan 02-02 documents 5/5 PASS (precondition of PR-3a).
    3. **Set `FF_FACT_EVENT_DUAL_WRITE=on` on Railway staging only** : `railway variables set FF_FACT_EVENT_DUAL_WRITE=on --environment staging`. Prod stays OFF.
    4. **Deploy PR-3a branch to staging** : wait for Application startup complete.
    5. **Run backfill — first pass** : `cd services/backend && DATABASE_URL=$STAGING_DATABASE_URL python3 scripts/backfill_snapshot_to_fact_event.py --apply > /tmp/backfill_run1.log`. Capture row-count : `psql $STAGING_DATABASE_URL -tAc "SELECT count(*) FROM fact_event WHERE source_type='snapshot_backfill'"` → record as `N_RUN1`.
    6. **Run backfill — second pass (idempotency proof)** : same command, `> /tmp/backfill_run2.log`. Capture row-count again : `N_RUN2`. **Assert `N_RUN2 == N_RUN1`** (zero new rows on second run).
    7. **Capture idempotency counter delta** : `curl -sf https://mint-staging.up.railway.app/metrics | grep mint_projector_idempotency_skip_total` → should show increment ≥ N_RUN1 (one skip per backfilled row on the re-run).
    8. **Run 100% staging-user canonical-JSON parity audit** : `DATABASE_URL=$STAGING_DATABASE_URL python3 tools/parity/projection_diff.py --audit-all-users --persist-to _phase02_parity_audit > /tmp/full_parity_audit.log`. Capture stdout + table row count : `psql $STAGING_DATABASE_URL -tAc "SELECT count(*), count(*) FILTER (WHERE diff_detected) FROM _phase02_parity_audit"` → record as `(USERS_AUDITED, USERS_WITH_DIFF)`.
    9. **Assert `USERS_WITH_DIFF == 0`**. If non-zero, BLOCK PR-3a, investigate per-user diff, ship a fix-up commit, re-run.

    **Julien verifies (in this order)** :
    1. **Open `/tmp/backfill_run1.log` + `/tmp/backfill_run2.log`** : run-1 reports `Backfilled N users → M fact_event rows` ; run-2 reports `0 new fact_event rows ; M idempotency_skip increments`.
    2. **Open `/tmp/full_parity_audit.log`** : last line reads `USERS_AUDITED=<N>, USERS_WITH_DIFF=0` (canonical-JSON diff via projection_diff.py).
    3. **Sample test on staging — pick 1 user from Julien's own test account** :
       ```bash
       USER_ID=<julien-staging-test-uid>
       curl -sf "https://mint-staging.up.railway.app/v1/projection/$USER_ID" > /tmp/proj_pre_cutover.json
       psql $STAGING_DATABASE_URL -tAc "SELECT * FROM _phase02_parity_audit WHERE user_id_hash = hmac_user_id('$USER_ID')"
       ```
       Expected : 1 row in `_phase02_parity_audit` with `diff_detected=false`.
    4. **Confirm `projection_diff.py` deterministic on local re-run** : Claude runs `python3 tools/parity/projection_diff.py --self-test` (the 12-pair fixture) → exit 0.
    5. **Type gate decision**.

    **Gate decision** :
    - All checks pass → "approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic" → Claude merges PR-3a to dev. Task 2b fires next.
    - Any check fails → describe failure mode ; Claude diagnoses + ships fix-up commit on the SAME PR-3a branch + re-runs checks.
  </how-to-verify>
  <resume-signal>
    Type "approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic" OR describe failure mode for fix-up.
  </resume-signal>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2b (NEW iter-2 — replaces original Task 2 PR-3 read-cutover + HARD-flip): PR-3b read-cutover + Phase-01 D-12 parity-lint SOFT→HARD atomic + 7th-gate pre-HARD-flip pg_dump snapshot. 7-day soak prerequisite (Tier-A A9 + Tier-B B5 + B18 + B20)</name>
  <what-built>
    Claude has implemented PR-3b as a single PR containing THREE load-bearing changes :

    1. **`services/backend/app/api/v1/endpoints/projection.py` + `snapshots.py`** : read endpoints switch from `SnapshotModel` lookups to `FactCurrent` PK lookups via `decrypt_value`. The `?legacy=true` query-param escape hatch is added (NOT removed yet — needed for the dual-read soak window in Task 3 PR-4).
    2. **`tools/checks/profile_safe_fields_parity.py`** : SOFT→HARD flip in `lefthook.yml` + `.github/workflows/design-lints.yml`. The 3 Flutter-only-fields-pending-drop are whitelisted via `tools/checks/profile_safe_fields_parity_allowlist.txt` (Plan 02-04 PR-A3 drops this allowlist).
    3. **`tools/db/pre_pr3b_pg_dump.sql`** (Tier-B B5 — 7th gate) : pg_dump snapshot of staging Postgres captured RIGHT BEFORE the read-cutover commit. Committed to git alongside the read-cutover code. If post-cutover drift is detected within 24h, the rollback procedure is `pg_restore tools/db/pre_pr3b_pg_dump.sql` on staging + revert PR-3b on dev.

    Before this checkpoint fires, Claude has run :
    - 7-day continuous-drift sampler on Railway staging — cron `*/30 * * * *` sampling 100 random users via `projection_diff.py` (canonical-JSON deterministic per A10), persisting results to `_phase02_parity_audit_continuous` table. **All 7 days must show `diff_count = 0` for at least 24 consecutive hours adjacent to the proposed PR-3b merge.**
    - Run `projection_diff.py --audit-all-users` against staging Postgres a SECOND time (after PR-3a merge + 7-day soak) — assert still zero diff.
    - Captured the pg_dump snapshot.
    - Verified Phase-01 D-12 parity-lint exits 0 in HARD mode against current dev branch (`python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt`).
  </what-built>
  <how-to-verify>
    **Pre-checkpoint Claude actions** :
    1. **Verify PR-3a merged ≥ 7 days ago** : `gh pr view <PR-3a-NUM> --json mergedAt` returns timestamp where (now - mergedAt) ≥ 7 days. iter-2 B20 — soak duration reconciled : 7-day minimum, 14-day target ; <7d → BLOCK ; 7-14d → soft-warn but proceed if drift counter clean ; ≥14d → proceed.
    2. **Continuous drift sampler 7-day clean window** : query `_phase02_parity_audit_continuous` for the last 7 days :
       ```sql
       SELECT date_trunc('hour', sampled_at) AS h, count(*) FILTER (WHERE diff_count > 0) AS dirty
       FROM _phase02_parity_audit_continuous
       WHERE sampled_at > now() - interval '7 days'
       GROUP BY 1 ORDER BY 1 DESC;
       ```
       Assert : zero rows with `dirty > 0` across the 7-day window OR at least 24 consecutive hours adjacent to NOW are clean.
    3. **Run 100% staging-user canonical-JSON parity audit (RE-RUN of Task 2a step 8)** : `python3 tools/parity/projection_diff.py --audit-all-users` → assert `USERS_WITH_DIFF == 0` still holds (no regression since PR-3a merge).
    4. **Capture pre-cutover pg_dump (7th gate, B5)** : `pg_dump --schema-only --data-only $STAGING_DATABASE_URL > tools/db/pre_pr3b_pg_dump.sql ; git add tools/db/pre_pr3b_pg_dump.sql ; git commit -m "snapshot(p02-pr3b): pre-cutover staging pg_dump for rollback (B5 7th gate)"`. The file is committed as part of the PR-3b branch.
    5. **Apply read-cutover code** : update `app/api/v1/endpoints/projection.py` + `snapshots.py` to read from `FactCurrent` via `decrypt_value`. Add `?legacy=true` escape hatch (removed in Plan 02-04 PR-5 ; lives during PR-3b soak window).
    6. **Apply Phase-01 D-12 SOFT→HARD flip** : update `lefthook.yml` + `.github/workflows/design-lints.yml` invocations of `tools/checks/profile_safe_fields_parity.py` to include `--hard`. Create `tools/checks/profile_safe_fields_parity_allowlist.txt` with the 3 Flutter-only field names (per Plan 02-04 PR-A3 cleanup).
    7. **Run local HARD mode** : `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` → assert exit 0.

    **Julien verifies (in this order)** :
    1. **Continuous drift sampler dashboard** : `curl -sf https://mint-staging.up.railway.app/metrics | grep mint_snapshot_fact_current_drift_total` returns 0 ; `psql $STAGING_DATABASE_URL -tAc "SELECT count(*) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval '24 hours' AND diff_count > 0"` returns 0.
    2. **Spot-check staging projection endpoint pre/post-cutover** (PR-3b is on a feature branch, not yet on dev) :
       ```bash
       # Pre-cutover (legacy path via ?legacy=true on the deployed PR-3b branch)
       curl -sf "https://mint-staging-pr-NN.up.railway.app/v1/projection/$USER_ID?legacy=true" > /tmp/proj_legacy_pr3b.json
       # Post-cutover (new path, default on PR-3b branch)
       curl -sf "https://mint-staging-pr-NN.up.railway.app/v1/projection/$USER_ID" > /tmp/proj_new_pr3b.json
       python3 tools/parity/projection_diff.py --pair /tmp/proj_legacy_pr3b.json /tmp/proj_new_pr3b.json
       ```
       Assert : `projection_diff.py` returns exit 0 + stdout `EQUAL` (deterministic per A10).
    3. **HARD lint local run** : `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt ; echo exit=$?` → exit 0.
    4. **Verify pg_dump snapshot committed** : `ls -la tools/db/pre_pr3b_pg_dump.sql` ≥ 50 lines, contains `CREATE TABLE fact_event` AND `CREATE TABLE fact_current` (post-p98 state).
    5. **Confirm rollback procedure exists** : `docs/operations/snapshot-model-decommission.md` Phase 02-03 Task 2b section documents how to invoke `pg_restore` + revert PR-3b on read-cutover-drift > 0 within 24h post-merge.
    6. **Type gate decision**.

    **Gate decision** :
    - All checks pass → "approved PR-3b — 7-day drift sampler clean, parity audit re-run zero diff, pg_dump snapshot committed, HARD lint green" → Claude merges PR-3b to dev.
    - <7d soak → "soak window short — defer N days" → Claude waits N days + re-runs the continuous sampler verification.
    - Any check fails → describe failure mode ; Claude diagnoses + ships fix-up commit on PR-3b branch + re-runs checks (NOT pre_pr3b_pg_dump.sql — that's append-only ; recapture happens only if PR-3b is force-pushed).
  </how-to-verify>
  <resume-signal>
    Type "approved PR-3b — 7-day drift sampler clean, parity audit re-run zero diff, pg_dump snapshot committed, HARD lint green" OR "soak window short — defer N days" OR describe failure mode.
  </resume-signal>
</task>

### New helper task — Continuous drift sampler infrastructure (Tier-B B18)

The 7-day drift sampler (referenced by Task 2b) requires Railway cron infra. Ships ahead of Task 2a as a passive monitoring component (zero functional change to user flows).

<task type="auto">
  <name>Task 2-helper (NEW iter-2): Continuous drift sampler Railway cron 30min × 100 users × 7-day soak (Tier-B B18 — runs ALL THROUGH Task 2a soak window)</name>
  <files>
    services/backend/app/cron/continuous_drift_sampler.py,
    services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py,
    services/backend/app/models/phase02_parity_audit_continuous.py,
    .github/workflows/pg-soak-nightly.yml,
    railway.json
  </files>
  <read_first>
    services/backend/app/cron/ (existing cron jobs — patterns + module shape),
    tools/parity/projection_diff.py (from Task 2a iter-2 — drift definition module),
    railway.json (Railway service config ; if cron mechanism is Railway-native cron, update here ; if it's GH Actions cron, update workflow YAML)
  </read_first>
  <action>
1. **Alembic p119 (additive migration)** : create `_phase02_parity_audit_continuous` table :
   ```sql
   CREATE TABLE _phase02_parity_audit_continuous (
     id            BIGSERIAL PRIMARY KEY,
     sampled_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
     user_id_hash  VARCHAR(64) NOT NULL,
     diff_count    INTEGER NOT NULL,
     diff_details  JSONB NOT NULL DEFAULT '{}',
     sampler_run_id UUID NOT NULL
   );
   CREATE INDEX ix_phase02_parity_audit_continuous_sampled ON _phase02_parity_audit_continuous (sampled_at DESC);
   CREATE INDEX ix_phase02_parity_audit_continuous_dirty ON _phase02_parity_audit_continuous (diff_count) WHERE diff_count > 0;
   ```
   This table is staging-only ; prod migration ships as no-op CREATE-IF-NOT-EXISTS so PR-3a doesn't fail prod runtime if it ever touches.
2. **`services/backend/app/cron/continuous_drift_sampler.py` (NEW, ~80 LOC)** :
   - On invocation, picks 100 random user_ids from `SnapshotModel` table.
   - For each, fetches `/v1/projection/<uid>` (new path) AND `/v1/projection/<uid>?legacy=true` (legacy path) AS the running service serves them.
   - Runs `projection_diff.py` on each pair.
   - Inserts result into `_phase02_parity_audit_continuous` with the `sampler_run_id` (single UUID per cron invocation).
3. **`.github/workflows/pg-soak-nightly.yml` (NEW, OR extend existing)** : GitHub Actions cron job running every 30min during the PR-3a → PR-3b soak window. Targets `$STAGING_DATABASE_URL`. Invokes `python3 -m services.backend.app.cron.continuous_drift_sampler --sample-size 100`. Captures stdout to GitHub Actions log. **Cron schedule disabled by default ; enabled manually by Claude when PR-3a merges.**
4. **`railway.json` (if Railway-native cron preferred)** : add a cron service definition with the same schedule. Pick ONE — GH Actions OR Railway-native — based on what Julien already has wired (executor : grep `railway.json` for existing cron entries ; if absent, default to GH Actions).
5. **Sentry alert wiring (operational, executor surfaces in SUMMARY)** : configure a Sentry alert rule `mint_snapshot_fact_current_drift_total > 0 in 24h window` ; route to Julien email. Plan 02-04 close-out asserts this alert is configured (not Claude-actionable — Julien-only).
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/integration/test_migration_p119.py tests/integration/test_continuous_drift_sampler.py -q -k pg && [ -f services/backend/app/cron/continuous_drift_sampler.py ] && grep -E "schedule|cron" .github/workflows/pg-soak-nightly.yml</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_migration_p119.py tests/integration/test_continuous_drift_sampler.py -q -k pg` exits 0.
    - `services/backend/app/cron/continuous_drift_sampler.py` exists with sampling logic.
    - Cron schedule is `*/30 * * * *` (every 30 min).
    - Manual smoke test on staging : `python3 -m services.backend.app.cron.continuous_drift_sampler --sample-size 5 --dry-run` exits 0 and prints 5 diff results to stdout.
  </acceptance_criteria>
  <done>
    Continuous drift sampler infrastructure ready. Runs every 30min × 100 users × 7-day window between PR-3a merge and PR-3b merge. Outputs to `_phase02_parity_audit_continuous` table for the Task 2b 7-day-clean-window verification.
  </done>
</task>

### Patch to original Task 5 (PR-5 execution) — B19 SnapshotModel-referencing tests enumeration

**Adds** a new step to original Task 5 action block — enumerate Phase 01 tests that reference `SnapshotModel` and decide per-test (delete / migrate / mark deprecated).

**Updated `<action>` step 0a (insert at top of original Task 5)** :

```
0a. **iter-2 B19 — Enumerate Phase 01 SnapshotModel-referencing tests**. Run :
   ```bash
   grep -rln "SnapshotModel" services/backend/tests/ > /tmp/snap_test_inventory.txt
   wc -l /tmp/snap_test_inventory.txt   # expected: ~5-20 test files
   ```
   For each file in the inventory, decide per-test :
   - **Delete** if the test asserts SnapshotModel-specific behavior (e.g., `test_snapshot_inputs_hash_*`) that's invalidated by PR-5 drop. Add deletion to the PR-5 commit.
   - **Migrate** if the test asserts behaviour the post-cutover code MUST preserve (e.g., projection round-trip semantics) — rewrite to use FactCurrent + decrypt_value. Add as a new test in the PR-5 commit.
   - **Mark deprecated** if the test is in a Phase 01 « end-of-life suite » directory — add `@pytest.mark.deprecated` and skip in CI ; queue for deletion in a Plan 02-04 follow-up cleanup task.

   The decision matrix is published in PR-5 description as a 3-column table : `test_file | decision (delete/migrate/deprecate) | rationale`. CI does NOT pass until the inventory is exhausted (every file in `/tmp/snap_test_inventory.txt` has a documented decision).

   Reference : qa-expert plan-patch #6.
```

**Updated `<verify>` addition for Task 5** :
```bash
grep -rln "SnapshotModel" services/backend/tests/ | wc -l  # expected: 0 after PR-5 (all migrated/deleted/deprecated-skipped)
```

**Updated `<acceptance_criteria>` addition for Task 5** :
- `grep -rln "SnapshotModel" services/backend/tests/` returns 0 hits OR only `@pytest.mark.deprecated` test files (verified via `grep -A2 "deprecated" services/backend/tests/.../test_*.py`).
- PR-5 description includes a 3-column table enumerating the per-test decisions.

### CONTEXT.md changes proposed by this revision (summary)

1. **D-05** : 5-PR → 6-PR sequence (PR-3 split into PR-3a + PR-3b). Full diff above.
2. **D-31** : trigger PR `PR-3` → `PR-3b` ; soak duration reconciled « 7-day minimum, 14-day target » ; zero-drift definition deterministic via `projection_diff.py` ; sample size 100% (NOT 20 random). Full diff above.

### VALIDATION.md additions proposed by this revision

Append to `## Per-Task Verification Map → Wave 2-3 — Backfill + dual-write + cutover (Plan 02-03)` :

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|
| 02-03-0 | 02-03 | 2 | B1 zero-user prod gate | — | `preflight_zero_user_gate.py` rejects when prod has any user rows ; big-bang migration premise validated | unit | `python3 services/backend/scripts/preflight_zero_user_gate.py` |
| 02-03-2a | 02-03 | 2 | A9 PR-3a backfill split + A10 deterministic drift + B14 100% audit | T-02-06 | `backfill_*.py` idempotent (run-2 row-count delta = 0) ; `projection_diff.py` deterministic via canonical JSON + Decimal tolerance + missing-key=NULL ; 100% staging users persisted to `_phase02_parity_audit` zero diff | integration | `pytest tests/integration/test_backfill_idempotent.py + tools/parity/projection_diff.py --self-test` |
| 02-03-2b | 02-03 | 3 | A9 PR-3b cutover + Phase-01 D-12 HARD + B5 pg_dump 7th gate | T-02-06 | Read-cutover atomic with `profile_safe_fields_parity.py --hard` ; pre-cutover `pg_dump` committed ; rollback procedure documented | integration + lint HARD | `pytest tests/integration/test_read_cutover.py && python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` |
| 02-03-2helper | 02-03 | 2 | B18 continuous sampler | T-02-06 monitoring | `continuous_drift_sampler.py` Railway cron 30min × 100 users × 7-day window ; `_phase02_parity_audit_continuous` table | integration | `pytest tests/integration/test_continuous_drift_sampler.py -q -k pg` |
| 02-03-5 (extend) | 02-03 | 3 | B19 SnapshotModel test inventory | T-02-19 | All Phase 01 SnapshotModel-referencing tests classified (delete/migrate/deprecate) before PR-5 merges | grep | `grep -rln "SnapshotModel" services/backend/tests/ | wc -l` = 0 OR all matches `@pytest.mark.deprecated` |

### Threat-model extension (append, do not rewrite)

Append to the existing STRIDE Threat Register in this plan :

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-06-EXT | Tampering / Integrity (4-way convergence) | PR-3 « atomic trio » unsafe — backfill interruption mid-run leaves fact_current half-populated AND reads cut over | mitigate (A9) | iter-2 splits PR-3 → PR-3a (backfill-only, idempotent, row-count-delta=0 gate) + PR-3b (read-cutover + HARD-flip atomic). 7-day continuous drift sampler between. Pre-HARD-flip pg_dump committed. |
| T-QA-01 | Tampering / Cutover | Drift gate « zero drift » undefined (no canonicalisation, no tolerance, no NULL-vs-missing rule, sample size 20 random) | mitigate (A10 + B14) | iter-2 `tools/parity/projection_diff.py` with canonical JSON `sort_keys=True, default=str` + Decimal tolerance 1e-9 + missing-key=NULL rule. Sample size 100% staging users persisted to `_phase02_parity_audit`. |
| T-PG-03 | DoS | Backfill exhausts Railway connection pool (40 connections vs ~100 cap) | mitigate (B15) | iter-2 backfill script uses `get_backfill_engine()` with throttled `pool_size=2, max_overflow=0` ; main engine retains `pool_timeout=10`. |
| T-02-PR3a | Performance | Backfill runs against staging during peak window | accept | iter-2 — schedule backfill outside Julien's active hours ; staging traffic pre-launch is near-zero ; the throttled pool prevents user-facing degradation. |

### Tier-C considered, deferred

- **C2 PR-3 commit-message contract** → applied below as commit message template (Task 2a + Task 2b). Sample :
  ```
  feat(p02-pr3a): backfill SnapshotModel → fact_event idempotent (D-05 PR-3a iter-2 A9)

  Iter-2 reviews revision split: backfill is now operationally separable from read-cutover.
  - Run 1: <N> users backfilled
  - Run 2: 0 new rows, <N> idempotency_skip increments (proves idempotency on real data)
  - 100% staging-user canonical-JSON parity audit via tools/parity/projection_diff.py
    persisted to _phase02_parity_audit: <N> users, 0 diff
  - Allowlist rationale: 3 Flutter-only fields whitelisted in PR-3b (Plan 02-04 PR-A3 drops)
  - Forward link: Plan 02-04 PR-A3 cleanup
  - Reviewer rotation: 4-way convergence (architect-review + database-architect + postgres-pro + qa-expert)
  ```

### `<files_modified>` additions for Plan 02-03 frontmatter

```yaml
files_modified:
  # ...original list...
  - services/backend/scripts/preflight_zero_user_gate.py                                  # Task 0 B1
  - services/backend/tests/integration/test_preflight_zero_user_gate.py                   # Task 0 B1
  - tools/parity/projection_diff.py                                                       # A10
  - tools/parity/tests/test_projection_diff.py                                            # A10
  - services/backend/tests/fixtures/parity_diff_fixtures.py                               # A10
  - services/backend/alembic/versions/p118_phase02_parity_audit_table.py                  # B14
  - services/backend/app/models/phase02_parity_audit.py                                   # B14
  - services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py             # B18
  - services/backend/app/models/phase02_parity_audit_continuous.py                        # B18
  - services/backend/app/cron/continuous_drift_sampler.py                                 # B18
  - .github/workflows/pg-soak-nightly.yml                                                  # B18
  - tools/db/pre_pr3b_pg_dump.sql                                                          # B5
```

### Iter-2 commit recommendation

Per task — 4 separate commits :
1. `docs(mint-data-architecture-v1-02-event-log-projection): plan iter-2 reviews revision part 1 — Task 0 preflight gate + Task 1 D-12 label rename (Plan 02-03)`
2. `docs(mint-data-architecture-v1-02-event-log-projection): plan iter-2 reviews revision part 2 — Task 2 SPLIT PR-3 → PR-3a + PR-3b (A9 4-way convergence) + A10 deterministic drift gate (Plan 02-03)`
3. `docs(mint-data-architecture-v1-02-event-log-projection): plan iter-2 reviews revision part 3 — B14 + B18 + B5 + B19 + B20 (Plan 02-03)`
4. (during execution) `feat(p02-pr3a): ...` then later `feat(p02-pr3b): ...` per the commit message template above.

</iter_2_revision>
