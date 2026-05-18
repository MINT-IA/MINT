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
autonomous: false
decisions: [D-04, D-05, D-31]
checkpoint_reason: "PR-3 (read cutover + D-31 SOFT→HARD atomic flip) requires Julien staging-zero-drift gate per 0-trust §9. PR-5 (SnapshotModel table drop) is irreversible; Julien post-launch + 1-week observability soak gate per CONTEXT D-05."
requirements_addressed:
  - CONTEXT.md#D-04 constants propagation point-in-time (no retroactive re-flag — proven by PR-2 dual-write parity test)
  - CONTEXT.md#D-05 big-bang 5-PR migration sequence (PR-1 FF infra → PR-2 dual-write FF-OFF → PR-3 backfill+read-cutover+HARD flip → PR-4 decommission → PR-5 drop)
  - CONTEXT.md#D-31 D-12 parity-lint SOFT→HARD atomic with PR-3 read cutover (THREE sub-conditions in one PR)
threat_model_summary:
  - T-02-06 Read-cutover drift (mitigated: PR-3 atomic D-31 SOFT→HARD flip + zero-drift proof in coverage; D-12 parity-lint HARD catches future regressions at commit-time)
  - T-02-07 Orphan SnapshotModel data post-drop (mitigated: PR-5 gated on 1-week post-PR-3 observability soak + Julien checkpoint; rollback procedure documented in snapshot-model-decommission.md)
  - T-02-18 Feature-flag stuck-on after PR-4 decommission (mitigated: PR-4 removes the FF code branch + removes env-var reference; CI grep asserts zero occurrences post-merge)
  - T-02-19 Backfill non-idempotency (mitigated: D-27 UNIQUE constraint blocks dups; idempotency counter increments per duplicate; second run = 0 new rows assertion in PR-3 test)
must_haves:
  truths:
    - "PR-1: `fact_event_dual_write_enabled` feature flag added to `app/services/feature_flags.py`, default OFF in all envs; reading the flag returns False on dev + staging + prod (D-05 PR-1)."
    - "PR-2: `snapshot_service.py` writer branches on `fact_event_dual_write_enabled` flag; when ON it also writes fact_event + runs projector inside `session.begin()`; when OFF (default), only SnapshotModel write happens (D-05 PR-2). FF stays OFF in this PR — code path compiled + tested with FF-ON in test fixtures."
    - "PR-3 (ATOMIC, the D-31 trio): (a) `services/backend/scripts/backfill_snapshot_to_fact_event.py` exists, is idempotent (second run = 0 new rows + idempotency counter increments), and is invoked on staging; (b) `/v1/projection` + `/v1/snapshots` endpoints read from `fact_current` instead of SnapshotModel (with dual-read window verifying identical output before flipping); (c) `tools/checks/profile_safe_fields_parity.py` SOFT→HARD flag flipped in lefthook + `.github/workflows/design-lints.yml` CI; zero-drift coverage proof in the test suite."
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

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: PR-3 atomic trio (D-31) — backfill idempotent + /v1/projection read-cutover + profile_safe_fields_parity SOFT→HARD. Three changes ONE PR. Then Julien gates staging-zero-drift before merge to dev.</name>
  <what-built>
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
    Type "approved — zero drift, HARD lint green, backfill idempotent on staging" OR describe failure mode (e.g., "3 users out of 20 have diff in monthly_gross_income decimal precision"). On approval, Claude merges PR-3 to dev. On failure, Claude pushes a fix-up commit + re-runs the 6 checks.
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
    <automated>cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py tests/integration/test_backfill_idempotent.py tests/integration/test_read_cutover.py tests/observability/test_drift_telemetry.py -q -k pg && python3 -m pytest tests/ -q -x && ! git ls-files services/backend/app/models/snapshot.py && ! git grep -rn "from app.models.snapshot import SnapshotModel" services/backend/ && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/wiki_lint.py --file docs/operations/snapshot-model-decommission.md && ls -la tools/db/baseline_snapshot_phase02_pre_drop.sql && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/hmac_pepper_audit.py services/backend/app/</automated>
  </verify>
  <acceptance_criteria>
    - `cd services/backend && python3 -m pytest tests/integration/test_snapshot_drop.py -q -k pg` exits 0; pg_fixture confirms `snapshots` table absent after upgrade, re-present after downgrade.
    - `git ls-files services/backend/app/models/snapshot.py` returns empty (file deleted).
    - `! git grep -rn "from app.models.snapshot import SnapshotModel" services/backend/` returns exit code 1 (no hits = exit 1 in `grep -E ...`; the `!` inverts to exit 0).
    - `git grep -rn "from app.models.snapshot" services/backend/` returns 0 hits.
    - `git grep -n "?legacy=true\|legacy.*query.*param" services/backend/app/api/v1/endpoints/projection.py services/backend/app/api/v1/endpoints/snapshots.py` returns 0 hits.
    - `python3 tools/checks/wiki_lint.py --file docs/operations/snapshot-model-decommission.md` exits 0 (counter-arguments + data gaps block present).
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
