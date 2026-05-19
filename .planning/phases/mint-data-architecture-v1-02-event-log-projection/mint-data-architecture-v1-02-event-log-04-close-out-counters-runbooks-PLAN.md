---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 04
type: execute
wave: 4
depends_on: [03]
files_modified:
  - services/backend/app/services/expat/frontalier_service.py
  - services/backend/app/services/expat/__init__.py
  - services/backend/app/api/v1/endpoints/expat.py
  - services/backend/tests/test_expat.py
  - apps/mobile/lib/services/coach_narrative_service.dart
  - apps/mobile/test/services/coach_narrative_profile_context_test.dart
  - tools/checks/profile_safe_fields_parity_allowlist.txt
  - .github/workflows/regulatory-codegen.yml
  - .github/workflows/_self_test/staging_status_test.py
  - .github/workflows/_self_test/cron_scheduled_only.py
  - .github/CODEOWNERS
  - tools/checks/declared_counters_must_fire.py
  - tools/checks/tests/test_declared_counters_must_fire.py
  - lefthook.yml
  - services/backend/app/observability/counters.py
  - services/backend/tests/observability/test_phase02_counters.py
  - services/backend/tests/compliance/test_event_log_banned_terms.py
  - tools/checks/banned_terms_python.py
  - docs/operations/fact-event-partition-split.md
  - docs/operations/dek-rotation-phase04.md
  - docs/operations/audit-pepper-rotation.md
  - docs/operations/phase-04-mobile-attestation-hardening.md  # iter-3 iA4 (session-start audit-pollution forward-defer to Phase 04)
  - .planning/ROADMAP.md
  - .planning/STATE.md
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md
autonomous: true
decisions: [D-06, D-07, D-32, D-33]
decisions_continued: [D-09, D-10]  # close-out continuation; primary disposition in Plan 02-01
decisions_continued_from: [01]  # D-09 alias removal + D-10 PR-A3 dead-fields — terminal disposition here
requirements_addressed:
  - CONTEXT.md#D-06 Q6 CI staging-down policy (STAGING-MALFORMED + scheduled-only aging + HARD-mode label override)
  - CONTEXT.md#D-07 Audit retention 10y policy + REVOKE assertion + pepper-rotation runbook
  - CONTEXT.md#D-32 Phase 02 5-gate mechanical exit checklist
  - CONTEXT.md#D-33 6 new observability counters declared + ASSERTED firing via declared_counters_must_fire close-out gate (extended to 8 in iter-2: + mint_kms_backend_failure_total + mint_dek_cache_size_total per Plan 02-02 A4/A5)
  - CONTEXT.md#D-09 S12 PR-2 alias removal (FrontalierService = FrontalierSegmentService alias removed)
  - CONTEXT.md#D-10 D-MOB-01 PR-A3 (drop 3 dead Flutter-only fields; remove parity-lint allowlist)
threat_model_summary:
  - T-02-22 Counter declared but never fires (mitigated: declared_counters_must_fire HARD gate fails CI if any of the 8 D-33-tracked counters — 6 D-33 base + 2 iter-2 additions per Plan 02-02 A4/A5 — has zero increments in a 24h test window; covers regressions where a writer drops the counter)
  - T-02-23 Alias removal breaks downstream callers (mitigated: PR-A2 ships first in Plan 02-01; this plan's PR-2 only removes the alias once `git grep FrontalierService` confirms no live importers remain)
  - T-02-24 LSFin banned-terms leak via fact_event payload (mitigated: extend banned_terms_python lint to scan fact_event JSONB shape; assertion test seeds a banned term in payload and confirms lint catches it)
  - T-02-25 STAGING-DOWN-OVERRIDE label abused by non-CODEOWNER (mitigated: GitHub Actions workflow step gates the override on `github.event.pull_request.user.login == 'julienbattaglia' AND 'STAGING-DOWN-OVERRIDE' in labels`)
must_haves:
  truths:
    - "S12 PR-2 alias removal: `FrontalierService = FrontalierSegmentService` line deleted from `app/services/expat/frontalier_service.py`; all live importers updated; tests reference `FrontalierSegmentService` directly (D-09)."
    - "D-MOB-01 PR-A3: 3 dead Flutter-only fields removed from `_buildProfileContext` (the allowlist in Plan 02-03 PR-3); `tools/checks/profile_safe_fields_parity_allowlist.txt` deleted; HARD lint passes with zero allowlist (D-10)."
    - "Q6 CI mechanical fix #1 (STAGING-MALFORMED): `.github/workflows/regulatory-codegen.yml` extended with a step that distinguishes 200-OK-with-malformed-payload from 503-DOWN; separate counter `mint_staging_status_total{status='down'|'malformed'|'ok'}` (D-06)."
    - "Q6 CI mechanical fix #2 (scheduled-only aging): aging-state writes (parity-lint SOFT→HARD promotion candidate logic) run ONLY on cron-scheduled workflow runs, not on PR runs (D-06)."
    - "Q6 CI mechanical fix #3 (HARD-mode override label): workflow accepts `STAGING-DOWN-OVERRIDE` PR label as fail-closed bypass, gated to CODEOWNER `julienbattaglia` via workflow `github.event.pull_request.user.login` check (D-06)."
    - "`tools/checks/declared_counters_must_fire.py` HARD close-out gate: asserts all 8 declared counters (6 D-33 base + 2 iter-2 additions per Plan 02-02 A4/A5: `mint_kms_backend_failure_total` + `mint_dek_cache_size_total`) increment at least once during a representative test scenario; fails CI if any counter is declared but never fires (D-32 G3 + D-33)."
    - "`tools/checks/banned_terms_python.py` extended to scan `fact_event.payload` JSONB shape in fixtures (Phase 02 LSFin parity coverage); test seeds a banned term in payload and confirms lint exit 1 (D-32 G5 extension)."
    - "`docs/operations/fact-event-partition-split.md` ships with concrete thresholds (5M rows OR p99 > 15ms sustained 7d) + step-by-step ATTACH PARTITION procedure + Prometheus alert spec."
    - "`docs/operations/dek-rotation-phase04.md` ships documenting the forward-deferred Phase 04 rotation procedure; Phase 02 does NOT execute rotation (deferred-items.md anchor)."
    - "`docs/operations/audit-pepper-rotation.md` ships documenting the `MINT_AUDIT_HASH_PEPPER` rotation procedure with `user_id_hash_v1` transition column (forward-deferred — no rotation executed in Phase 02)."
    - "Phase 02 VERIFICATION-REPORT.html and SUMMARY.md flip the phase status string from `executing` → `◆ code-shipped on dev, pending operational gates`; STATE.md frontmatter updated; ROADMAP.md Phase 02 marker flipped; Plan 02-04 receipt block appended."
    - "5-gate exit checklist documented in VERIFICATION-REPORT.html: G1 Maestro walker output (or DEFERRED if no sim booted), G2 Julien device sign-off (DEFERRED — cannot self-clear per 0-trust §9), G3 dev CI green commit SHA trail, G4 pytest full suite green + 2 new test classes (`test_projector_idempotency.py` + `test_dek_shred_opacity.py` from Plan 02-02), G5 LSFin + accent + ARB + constants drift HARD + hmac_pepper_audit site lint all green."
  artifacts:
    - path: "tools/checks/declared_counters_must_fire.py"
      provides: "HARD close-out gate asserting all D-33 counters fire"
      exports: ["main", "assert_counter_fires"]
      min_lines: 60
    - path: "docs/operations/fact-event-partition-split.md"
      provides: "Partition-split runbook with thresholds + ATTACH PARTITION procedure"
      min_lines: 50
    - path: "docs/operations/dek-rotation-phase04.md"
      provides: "Forward-deferred DEK rotation procedure documentation"
      min_lines: 40
    - path: "docs/operations/audit-pepper-rotation.md"
      provides: "Forward-deferred pepper rotation procedure"
      min_lines: 40
    - path: ".planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html"
      provides: "Phase 02 VERIFICATION report with 5-gate panel + per-plan rollup"
      min_lines: 200
    - path: ".planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md"
      provides: "Phase 02 SUMMARY with 33 D-XX dispositions"
      min_lines: 180
  key_links:
    - from: "tools/checks/declared_counters_must_fire.py"
      to: "services/backend/app/observability/counters.py"
      via: "lint scans declared counters then runs a representative pytest scenario and asserts each counter incremented ≥ 1"
      pattern: "mint_fact_current_read_latency_ms\\|mint_fact_event_insert_total\\|mint_dek_envelope_status_total\\|mint_anonymous_session_link_total\\|mint_projector_idempotency_skip_total\\|mint_constants_version_mismatch_total"
    - from: ".github/workflows/regulatory-codegen.yml"
      to: ".github/CODEOWNERS"
      via: "STAGING-DOWN-OVERRIDE label gated via workflow check of PR author against CODEOWNERS julienbattaglia entry"
      pattern: "STAGING-DOWN-OVERRIDE"
    - from: "lefthook.yml"
      to: "tools/checks/declared_counters_must_fire.py"
      via: "pre-commit (or pre-push) HARD gate on services/backend/app/observability/*.py changes"
      pattern: "declared_counters_must_fire"
---

<objective>
Continues close-out of D-09 (S12 alias removal) and D-10 (Flutter PR-A3 dead-fields) from Plan 02-01 — primary disposition there, terminal disposition here.

Wave 4 closes the phase. Five workstreams: (1) S12 PR-2 alias removal + D-MOB-01 PR-A3 dead-field drop (the carry-over completions from Plan 02-01); (2) Q6 CI mechanical fixes (STAGING-MALFORMED status + scheduled-only aging writes + HARD-mode STAGING-DOWN-OVERRIDE label) per D-06; (3) `declared_counters_must_fire.py` close-out HARD gate activated per D-32 G3 + D-33 (asserts all 8 declared counters fire: 6 D-33 base + 2 iter-2 additions per Plan 02-02 A4/A5); (4) three forward-deferred operational runbooks (partition-split + DEK rotation + audit-pepper rotation); (5) phase close-out artifacts (VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE updates).

Purpose: lock the 5-gate mechanical exit (G1 Maestro, G2 Julien device — DEFERRED, G3 dev CI green, G4 regression + 2 new test classes, G5 lint suite) and flip the phase status to `◆ code-shipped on dev, pending operational gates`. Every D-XX (1-33) has a verifiable disposition in the SUMMARY by close-out.

Output: 4 atomic tasks landing on dev, no checkpoint required (this plan is `autonomous: true`). G2 device sign-off remains DEFERRED for Julien post-merge per 0-trust §9.
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
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-SUMMARY.md
@services/backend/app/services/expat/frontalier_service.py
@apps/mobile/lib/services/coach_narrative_service.dart
@tools/checks/profile_safe_fields_parity.py
@tools/checks/banned_terms_python.py
@.github/workflows/regulatory-codegen.yml
@services/backend/app/observability/counters.py

<interfaces>
<!-- Verbatim contracts after Plan 02-03 lands. -->

State after Plan 02-03 PR-5:
- `app/models/snapshot.py` deleted.
- `app/api/v1/endpoints/projection.py` reads exclusively from FactCurrent.
- `tools/checks/profile_safe_fields_parity.py` runs in `--hard` mode in lefthook + CI.
- `tools/checks/profile_safe_fields_parity_allowlist.txt` contains 3 Flutter-only field names (this plan removes them).
- 6 D-33 counters DECLARED in `app/observability/counters.py` but no firing assertion yet.

S12 alias state after Plan 02-01:
- `app/services/expat/frontalier_service.py` contains `class FrontalierSegmentService:` + trailing line `FrontalierService = FrontalierSegmentService  # deprecated alias, removed in Plan 02-04 PR-2 per D-09`.
- `app/services/expat/__init__.py` re-exports both names.
- `app/api/v1/endpoints/expat.py` line 54: `from app.services.expat.frontalier_service import FrontalierSegmentService as FrontalierService` — local-alias style (callers use the old name).

Q6 CI workflow state (`.github/workflows/regulatory-codegen.yml`):
- Phase 01 D-16 shipped tiered 7/14/28-day STAGING-DOWN escalation.
- Phase 02 extends with: STAGING-MALFORMED status (200-OK-shape-invalid path) + scheduled-only aging writes + HARD-mode STAGING-DOWN-OVERRIDE label per D-06.

`.github/CODEOWNERS`: verify Julien-only scope on `.github/workflows/regulatory-codegen.yml`. If file doesn't exist, create with single line: `.github/workflows/regulatory-codegen.yml @julienbattaglia`.

VERIFICATION-REPORT.html template anchor: follow the structure of `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-calc-engine-v1-VERIFICATION-REPORT.html` (Phase 01 W4 Plan 20 receipt — 541 lines, per-plan + per-wave + 5-gate panel + cumulative metric snapshot + deferred-items + lessons learned + next-phase pointer).

SUMMARY.md template anchor: same Phase 01 W4 Plan 20 receipt block (per-D-CE-XX + per-Concern + per-Finding disposition + counter-arguments + lessons learned).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: S12 PR-2 alias removal + D-MOB-01 PR-A3 dead-field drop + allowlist cleanup</name>
  <files>
    services/backend/app/services/expat/frontalier_service.py,
    services/backend/app/services/expat/__init__.py,
    services/backend/app/api/v1/endpoints/expat.py,
    services/backend/tests/test_expat.py,
    apps/mobile/lib/services/coach_narrative_service.dart,
    apps/mobile/test/services/coach_narrative_profile_context_test.dart,
    tools/checks/profile_safe_fields_parity_allowlist.txt
  </files>
  <read_first>
    services/backend/app/services/expat/frontalier_service.py (post-Plan-02-01 state — trailing alias line to remove),
    services/backend/app/services/expat/__init__.py (re-export surface to clean),
    services/backend/app/api/v1/endpoints/expat.py (line 54 — local-alias import to update),
    services/backend/tests/test_expat.py (test imports to update),
    apps/mobile/lib/services/coach_narrative_service.dart (lines 1161-1208 — `_buildProfileContext`; identify the 3 fields whitelisted in Plan 02-03 PR-3),
    apps/mobile/test/services/coach_narrative_profile_context_test.dart (test assertions to update),
    tools/checks/profile_safe_fields_parity_allowlist.txt (3 field names to drop)
  </read_first>
  <action>
1. **S12 PR-2 alias removal (D-09)**:
   - Run `git grep -rn "FrontalierService" services/backend apps/mobile/lib | grep -v "FrontalierSegmentService"` to identify ALL live importers. Update each to use `FrontalierSegmentService` directly.
   - Example: `services/backend/app/api/v1/endpoints/expat.py:54`: change `from app.services.expat.frontalier_service import FrontalierSegmentService as FrontalierService` → `from app.services.expat.frontalier_service import FrontalierSegmentService` AND replace all usages of `FrontalierService` in that file with `FrontalierSegmentService`. Same in `tests/test_expat.py`.
   - **`app/services/expat/frontalier_service.py`**: REMOVE the trailing line `FrontalierService = FrontalierSegmentService  # deprecated alias`. The alias is gone.
   - **`app/services/expat/__init__.py`**: REMOVE `from app.services.expat.frontalier_service import FrontalierService` (the alias-route). Keep `from app.services.expat.frontalier_service import FrontalierSegmentService`.
   - NOTE: do NOT modify `app/services/frontalier_service.py` (S12 façade with different class — keeps its `FrontalierService` name forever per D-08).
   - NOTE: do NOT modify `apps/mobile/lib/services/segments_service.dart` (mobile Flutter `class FrontalierService` is a Dart class in a different layer — unrelated to the Python S23 rename).
2. **D-MOB-01 PR-A3 dead-field drop (D-10)**:
   - Read `tools/checks/profile_safe_fields_parity_allowlist.txt` to get the 3 Flutter-only field names.
   - In `apps/mobile/lib/services/coach_narrative_service.dart::_buildProfileContext`, REMOVE the `result['<key>'] = profile.<getter>;` lines for those 3 fields.
   - Update `apps/mobile/test/services/coach_narrative_profile_context_test.dart` to remove the corresponding `expect(result.containsKey('<key>'), isTrue)` assertions.
   - DELETE `tools/checks/profile_safe_fields_parity_allowlist.txt`.
   - Update `lefthook.yml` + `.github/workflows/design-lints.yml`: remove the `--allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` flag from every invocation. The HARD lint now runs with zero allowlist.
3. **Run parity-lint without allowlist**: `python3 tools/checks/profile_safe_fields_parity.py --hard` must exit 0.
4. **Run full test suites**.
  </action>
  <verify>
    <automated>git grep -rn "FrontalierService" services/backend apps/mobile/lib | grep -v "FrontalierSegmentService" | grep -v "lib/services/segments_service.dart" | grep -v "frontalier_service.py:.*class FrontalierService" && exit 1 || echo "no S23 FrontalierService callers remain"; cd services/backend && python3 -m pytest tests/test_expat.py tests/test_s12_frontalier_rename.py -q && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/profile_safe_fields_parity.py --hard && ! ls tools/checks/profile_safe_fields_parity_allowlist.txt 2>/dev/null && cd apps/mobile && flutter analyze && flutter test test/services/coach_narrative_profile_context_test.dart && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/expat/ && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `git grep -n "FrontalierService = FrontalierSegmentService" services/backend/app/services/expat/frontalier_service.py` returns 0 hits (alias line removed).
    - `git grep -rn "^from app.services.expat.frontalier_service import FrontalierService\b" services/backend/` returns 0 hits.
    - `git grep -n "class FrontalierService" services/backend/app/services/expat/` returns 0 hits.
    - `git grep -n "class FrontalierService" services/backend/app/services/frontalier_service.py` returns 1 hit (S12 façade preserved).
    - `cd services/backend && python3 -m pytest tests/test_expat.py tests/test_s12_frontalier_rename.py tests/test_segments.py -q` exits 0.
    - `python3 tools/checks/profile_safe_fields_parity.py --hard` exits 0 WITHOUT `--allowlist` flag.
    - `[ ! -f tools/checks/profile_safe_fields_parity_allowlist.txt ]` exits 0 (file deleted).
    - `cd apps/mobile && flutter analyze && flutter test` exits 0.
  </acceptance_criteria>
  <done>
    S12 PR-2 alias removed; all live importers use `FrontalierSegmentService` directly. D-MOB-01 PR-A3 drops 3 dead Flutter-only fields; parity-lint HARD without allowlist green. Plan 02-01 + Plan 02-03 carry-over completions closed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Q6 CI mechanical fixes (D-06) — STAGING-MALFORMED status + scheduled-only aging + HARD-mode STAGING-DOWN-OVERRIDE label CODEOWNER-gated</name>
  <files>
    .github/workflows/regulatory-codegen.yml,
    .github/workflows/_self_test/staging_status_test.py,
    .github/workflows/_self_test/cron_scheduled_only.py,
    .github/CODEOWNERS
  </files>
  <read_first>
    .github/workflows/regulatory-codegen.yml (Phase 01 D-16 baseline — tiered escalation),
    .github/CODEOWNERS (current state if exists; create if absent),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Open Question 2 — STAGING-DOWN-OVERRIDE recommendation = GitHub Actions step checking `github.event.pull_request.user.login == 'julienbattaglia' AND 'STAGING-DOWN-OVERRIDE' in pull_request.labels`)
  </read_first>
  <action>
1. **`.github/workflows/regulatory-codegen.yml`**:
   - **STAGING-MALFORMED detection step**: replace the existing `curl -sf -m 10` staging health check with a two-pass check: (a) `curl -sf -m 10 https://mint-staging.up.railway.app/v1/regulatory/constants > /tmp/payload.json; echo exit=$?`; if exit ≠ 0 → STAGING-DOWN. (b) If exit == 0, parse `/tmp/payload.json` with `python3 -c "import json,sys; json.load(open('/tmp/payload.json')); assert 'effective_on' in json.load(open('/tmp/payload.json'))"`; if exit ≠ 0 → STAGING-MALFORMED. Else STAGING-OK.
   - **Separate counters**: emit `STAGING_STATUS=down|malformed|ok` env var; downstream steps branch on it. Add `mint_staging_status_total{status}` to backend counters (Plan 02-02 declared, this plan asserts firing if backend is reachable).
   - **Scheduled-only aging writes**: wrap the aging-state write step in `if: github.event_name == 'schedule'`. PR-triggered runs (event_name == 'pull_request') skip the write — read-only path.
   - **HARD-mode STAGING-DOWN-OVERRIDE label**: add a step BEFORE the HARD lint enforcement step:
     ```yaml
     - name: STAGING-DOWN-OVERRIDE gate
       if: env.STAGING_STATUS == 'down' || env.STAGING_STATUS == 'malformed'
       run: |
         if [[ "${{ github.event.pull_request.user.login }}" != "julienbattaglia" ]]; then
           echo "::error::STAGING is ${STAGING_STATUS} but PR author is not a CODEOWNER for override"
           exit 1
         fi
         if [[ ! "${{ join(github.event.pull_request.labels.*.name, ',') }}" =~ "STAGING-DOWN-OVERRIDE" ]]; then
           echo "::error::STAGING is ${STAGING_STATUS}; require STAGING-DOWN-OVERRIDE label to proceed"
           exit 1
         fi
         echo "::warning::STAGING-DOWN-OVERRIDE label applied by julienbattaglia — proceeding with cached fixture"
     ```
2. **`.github/CODEOWNERS`**: if exists, add `.github/workflows/regulatory-codegen.yml @julienbattaglia`. If absent, create file with that single line + a comment header. Verify via GH UI that CODEOWNER recognition is active.
3. **`.github/workflows/_self_test/staging_status_test.py` (NEW)**: a script that GitHub Actions can run as a dry-run (with a `workflow_dispatch` input `mode=staging-malformed-test`) to exercise the three branches. Mocks the staging URL with a local HTTP server returning (a) 503 = DOWN, (b) 200 + garbage = MALFORMED, (c) 200 + valid = OK. Asserts each branch lands the right STAGING_STATUS value. Wire as a workflow_dispatch input on the same yml.
4. **`.github/workflows/_self_test/cron_scheduled_only.py` (NEW)**: a script asserting that the aging-state write step is gated on `github.event_name == 'schedule'`. Simulates a pull_request event + reads the workflow YAML to verify the conditional is present.
  </action>
  <verify>
    <automated>grep -E "STAGING_STATUS=down|STAGING_STATUS=malformed|STAGING-DOWN-OVERRIDE" .github/workflows/regulatory-codegen.yml && grep "github.event_name == 'schedule'" .github/workflows/regulatory-codegen.yml && grep "julienbattaglia" .github/CODEOWNERS && python3 .github/workflows/_self_test/staging_status_test.py && python3 .github/workflows/_self_test/cron_scheduled_only.py && python3 tools/checks/banned_terms_python.py .github/workflows/_self_test/</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "STAGING_STATUS=down\|STAGING_STATUS=malformed\|STAGING_STATUS=ok" .github/workflows/regulatory-codegen.yml` ≥ 3.
    - `grep -c "STAGING-DOWN-OVERRIDE" .github/workflows/regulatory-codegen.yml` ≥ 2.
    - `grep "github.event_name == 'schedule'" .github/workflows/regulatory-codegen.yml` returns ≥ 1 hit (aging-write conditional).
    - `grep "julienbattaglia" .github/CODEOWNERS` returns ≥ 1 hit (file present, CODEOWNER scoped).
    - `python3 .github/workflows/_self_test/staging_status_test.py` exits 0 (all 3 branches exercised).
    - `python3 .github/workflows/_self_test/cron_scheduled_only.py` exits 0 (cron gate present).
    - Manual GH UI verification (post-merge, NOT this task): trigger workflow_dispatch with `mode=staging-malformed-test` input — yields green for all 3 branches.
  </acceptance_criteria>
  <done>
    Q6 CI mechanical fixes shipped. STAGING-MALFORMED is now a distinct state from STAGING-DOWN. Aging-state writes only fire on cron-scheduled runs. STAGING-DOWN-OVERRIDE label is CODEOWNER-gated. The Phase 01 D-16 tiered escalation chain remains unchanged; this layer is additive.
  </done>
</task>

<task type="auto">
  <name>Task 3: D-33 `declared_counters_must_fire` HARD close-out gate activated + Phase 02 LSFin banned-terms extension (D-32 G5 + D-33)</name>
  <files>
    tools/checks/declared_counters_must_fire.py,
    tools/checks/tests/test_declared_counters_must_fire.py,
    lefthook.yml,
    services/backend/app/observability/counters.py,
    services/backend/tests/observability/test_phase02_counters.py,
    services/backend/tests/compliance/test_event_log_banned_terms.py,
    tools/checks/banned_terms_python.py
  </files>
  <read_first>
    services/backend/app/observability/counters.py (post-Plan-02-02 — 6 D-33 counters DECLARED but not yet firing-asserted),
    services/backend/app/services/projector/fact_projector.py (from Plan 02-02 — counter increment sites),
    services/backend/app/api/v1/endpoints/audit_mobile.py (from Plan 02-02 — counter increment sites),
    tools/checks/banned_terms_python.py (Plan 02-01 + Phase 01 W4 D-CE-16(b) extended state — add fact_event.payload JSONB scan)
  </read_first>
  <action>
1. **`tools/checks/declared_counters_must_fire.py` (NEW)**: CLI script. Behavior:
   - Step 1: parse `services/backend/app/observability/counters.py` AST; collect every module-level `Counter(...)` / `Histogram(...)` / `Gauge(...)` declaration name (e.g., `mint_fact_event_insert_total`, `mint_dek_envelope_status_total`, etc.).
   - Step 2: read `services/backend/app/observability/counters.py` for a `_FIRING_REQUIRED` allowlist (defaults to all declared names; entries can be exempted with a comment `# fire-exempt: <reason>` next to the declaration).
   - Step 3: run `cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py -q -k pg` — a representative scenario test that exercises every required counter. The test reads counter values before/after the scenario and asserts `delta >= 1` for each.
   - Step 4: if any required counter has delta == 0, exit 1 with the list of unfired counters.
   - `--check-declared-only` flag: skips Step 3 (used in W1 when counters are declared but not yet wired); used by Plan 02-02 as a smoke check.
   - `--all` flag (default in this plan): runs Steps 1-4 full.
   - Self-test fixture: a fake counters.py with one Counter that's never incremented + one that is; expect exit 1 with the unfired name.
2. **`services/backend/tests/observability/test_phase02_counters.py` (NEW)**: pytest scenario that:
   - Spins pg_fixture.
   - Writes a fact_event via `project_fact_event` → fires `mint_fact_event_insert_total`.
   - Re-writes the same event → fires `mint_projector_idempotency_skip_total`.
   - Triggers a fact_current read via `/v1/projection/{user_id}` → fires `mint_fact_current_read_latency_ms`.
   - Calls `KeyVaultService.get_or_create_dek(user_id)` → fires `mint_dek_envelope_status_total{status='created'}`.
   - Calls `KeyVaultService.revoke_dek(user_id)` → fires `mint_dek_envelope_status_total{status='shredded'}`.
   - POSTs a `/v1/audit/mobile-session-link` batch → fires `mint_anonymous_session_link_total{outcome='linked'}`.
   - Bumps `RegulatoryParameter` active version → re-reads projection → fires `mint_constants_version_mismatch_total` (or asserts the constants-PIT doctrine holds without firing — depends on D-04 spec).
   - Reads each counter's `_value.get()` before/after and asserts delta ≥ 1 for all 6 D-33 counters.
3. **`lefthook.yml`**: append on `pre-push` hook:
   ```yaml
   declared-counters-must-fire:
     run: python3 tools/checks/declared_counters_must_fire.py --all
     glob: "services/backend/app/observability/*.py"
     tags: [observability, phase-02-d-32-d-33]
     fail_text: "A declared D-33 counter never fires in the representative scenario. Wire its increment site or mark fire-exempt with a justification comment."
   ```
   NB: this lives on `pre-push` (NOT `pre-commit`) because the pytest scenario takes ~30s. Pre-commit speed budget = 5s.
4. **`tools/checks/banned_terms_python.py` extension for D-32 G5**: add a `--scan-jsonb-payload` mode that, given a fixture JSONB file, scans the `value_enc.payload` field (and `confidence.enrichmentPrompts` list) for banned terms. Self-test: seed a fixture with `payload = {"text": "rendement garanti"}` → expect exit 1 with violation. Tests live in `tools/checks/tests/test_banned_terms_python_jsonb.py`.
5. **`services/backend/tests/compliance/test_event_log_banned_terms.py` (NEW)**: assert that any `fact_event` row written with a payload containing a banned term raises at write-time (this requires Plan 02-02 writer to invoke `banned_terms_python.scan_jsonb_payload` BEFORE INSERT; if not wired, this test exposes the gap). Acceptable resolutions: (a) wire at writer level, (b) wire as DB CHECK constraint via `banned_terms_regex_check` Postgres function (overkill — prefer app-level). Pick (a): in `project_fact_event`, BEFORE `session.add(event)`, call `_scan_payload_for_banned_terms(event.value_enc)` (the helper imports from `tools/checks/banned_terms_python`); raise `BannedTermsViolation` if any found.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py tests/compliance/test_event_log_banned_terms.py -q -k pg && python3 -m pytest tests/ -q -x && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/declared_counters_must_fire.py --all && python3 -m pytest tools/checks/tests/test_declared_counters_must_fire.py -q && python3 tools/checks/banned_terms_python.py --scan-jsonb-payload services/backend/tests/fixtures/banned_payload.json 2>&1 | tee /tmp/banned_payload.log && grep -q "exit 1\|VIOLATION" /tmp/banned_payload.log && python3 tools/checks/banned_terms_python.py services/backend/app/services/projector/</automated>
  </verify>
  <acceptance_criteria>
    - `python3 tools/checks/declared_counters_must_fire.py --all` exits 0 (all 8 counters fire ≥1 in scenario — full enumeration:
      1. `mint_snapshot_fact_current_drift_total`
      2. `mint_projector_fact_written_total`
      3. `mint_projector_idempotency_skip_total`
      4. `mint_dek_operations_total`
      5. `mint_fact_event_write_total`
      6. `mint_anonymous_session_link_total`
      7. `mint_kms_backend_failure_total` (iter-2 A4 — D-35 PROPOSED, Plan 02-02 addition)
      8. `mint_dek_cache_size_total` (iter-2 A5, Plan 02-02 addition)).
    - `cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py -q -k pg` exits 0.
    - `python3 -m pytest tools/checks/tests/test_declared_counters_must_fire.py -q` exits 0 (self-test green).
    - `git grep -n "declared-counters-must-fire" lefthook.yml` returns 1 hit on `pre-push` hook.
    - `cd services/backend && python3 -m pytest tests/compliance/test_event_log_banned_terms.py -q -k pg` exits 0 (writer-level banned-term scan present + working).
    - Full backend pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (delta vs Plan 02-03 baseline: + observability + compliance tests).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/` exits 0 (no banned terms in production code post-extension).
  </acceptance_criteria>
  <done>
    D-32 G3 + D-33 close-out gate activated: every declared counter has a firing assertion. D-32 G5 LSFin banned-terms extended to `fact_event.payload` JSONB shape; writer-level scan blocks insertion. The phase has its full observability + compliance backbone.
  </done>
</task>

<task type="auto">
  <name>Task 4: Forward-deferred operational runbooks + Phase 02 close-out artifacts (VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE flip)</name>
  <files>
    docs/operations/fact-event-partition-split.md,
    docs/operations/dek-rotation-phase04.md,
    docs/operations/audit-pepper-rotation.md,
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html,
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md,
    .planning/ROADMAP.md,
    .planning/STATE.md
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-calc-engine-v1-VERIFICATION-REPORT.html (Phase 01 W4 reference for HTML report structure — 541 lines),
    .planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-calc-engine-v1-SUMMARY.md (Phase 01 W4 reference for SUMMARY.md shape),
    .planning/ROADMAP.md (Phase 02 entry to flip),
    .planning/STATE.md (frontmatter + Current Position to update),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md (33 D-XX dispositions — one per row in SUMMARY)
  </read_first>
  <action>
1. **`docs/operations/fact-event-partition-split.md` (NEW, ≥ 50 lines)**: per RESEARCH Open Question 5. Sections (each non-trivial — wiki_lint enforces counter-arguments + data gaps blocks):
   - TL;DR + status (forward-deferred — no split executed in Phase 02).
   - Concrete thresholds: split when **EITHER** `(SELECT count(*) FROM fact_event) > 5_000_000` **OR** `histogram_quantile(0.99, rate(mint_fact_current_read_latency_ms_bucket[7d])) > 0.015` (15ms — margin to D-01 ceiling 20ms).
   - Step-by-step procedure: `CREATE TABLE fact_event_p_1 PARTITION OF fact_event FOR VALUES WITH (MODULUS 2, REMAINDER 1)` + `CREATE TABLE fact_event_p_2 ...REMAINDER 0)`. Then `ATTACH PARTITION` for the new partitions. Postgres handles row redistribution automatically on next write (HASH partition by subject_id; existing rows stay in their hash-mapped partition).
   - Prometheus alert spec: alert `MintFactEventPartitionSplitDue` when threshold met for 7d sustained.
   - Rollback procedure: detach + drop the new partition; data stays in original p_0.
   - Counter-arguments and data gaps block.
2. **`docs/operations/dek-rotation-phase04.md` (NEW, ≥ 40 lines)**: per RESEARCH Open Question 4 + CONTEXT § Runtime State Inventory. Sections:
   - TL;DR (Phase 02 stores `dek_id` per row in `value_enc.dek_id` to future-proof rotation; rotation EXECUTION is Phase 04 work).
   - Trigger: 1st EDÖB/FINMA inquiry OR Railway adds FIPS 140-2 attestation OR 1st paying CH user >100K CHF.
   - Step-by-step procedure (outline only — Phase 04 ships the implementation):
     a. Generate new MK (`mint-master-v2`); add as second backend in `_select_backend()`.
     b. For each `dek_vault` row: `unwrap_dek(wrapped_dek, kms_key_ref='mint-master-v1')` → `wrap_dek(plaintext_dek, kms_key_ref='mint-master-v2')`; `UPDATE dek_vault SET wrapped_dek=..., kms_key_ref='mint-master-v2', rotated_at=now()`.
     c. Old DEK rows now unreadable post-revocation of `mint-master-v1` MK.
     d. `value_enc.dek_id` stays `'mint-master-v1'` on historical rows (audit anchor); decrypt path resolves via `dek_vault.kms_key_ref` not `value_enc.dek_id`.
   - Rehearsal: Plan 02-02 Task 1 documents a no-op rotation rehearsal on Railway staging (revert immediately after).
   - Counter-arguments and data gaps block.
3. **`docs/operations/audit-pepper-rotation.md` (NEW, ≥ 40 lines)**: per CONTEXT § D-07 + Threat Model T-02-04. Sections:
   - TL;DR (Phase 02 sets first pepper; rotation EXECUTION is forward-deferred).
   - Trigger: pepper-leak suspicion OR 5-year hygiene rotation.
   - Step-by-step procedure:
     a. Generate new pepper (`python3 -c "import secrets; print(secrets.token_urlsafe(48))"`).
     b. Set on Railway as `MINT_AUDIT_HASH_PEPPER_V2`; KEEP `MINT_AUDIT_HASH_PEPPER` (v1) as `MINT_AUDIT_HASH_PEPPER_V1`.
     c. Alembic migration adds `audit_events.user_id_hash_v2` + `actor_email_hash_v2` + ip/UA-v2 columns; backfill from plaintext (if retained) OR mark unreadable (if dropped — D-14 dropped plaintext post-deprecation).
     d. Read path queries BOTH `user_id_hash` AND `user_id_hash_v2`.
     e. After 6-month read-path transition window, `DROP COLUMN user_id_hash` + rename `user_id_hash_v2` → `user_id_hash`.
   - Rehearsal: Plan 02-02 Task 1 documents a no-op rotation rehearsal.
   - Counter-arguments and data gaps block.
4. **`.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html` (NEW, ≥ 200 lines)**: follow Phase 01 W4 Plan 20 HTML structure:
   - Phase-level header (status: `◆ code-shipped on dev, pending operational gates`).
   - Per-plan rollup (Plan 02-01 / 02-02 / 02-03 / 02-04 — each with verify command output + commit SHAs).
   - 5-gate exit panel (G1 Maestro: ⏭ DEFERRED if no booted sim; G2 Julien device: ⏳ DEFERRED; G3 dev CI: ✓ PASS with commit-SHA trail; G4 Regression: ✓ PASS with `7264+ delta`; G5 lints: ✓ PASS).
   - Cumulative metric snapshot: alembic head, fact_event row count, fact_current row count, dek_vault row count, declared counters list.
   - Deferred items: 3 runbooks (partition split + DEK rotation + audit-pepper rotation) + Phase 03 coach extractor + Phase 04 sub-DEKs + 6 backlog items per CONTEXT § Deferred.
   - Lessons learned: ≥3 entries — (a) testcontainers harness caught zero Postgres bugs in Phase 02 (confirms Hotfix B was the only recent regression), (b) PR-3 D-31 atomic trio worked: zero-drift gate proved the choreography, (c) hmac_pepper site sweep surfaced N pre-existing bare-SHA-256 sites — all closed in Plan 02-02 (D-14/D-15).
   - Next-phase pointer: Phase 03 coach extractor (gated on Phase 02 completion).
5. **`.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md` (NEW, ≥ 180 lines)**: follow Phase 01 W4 Plan 20 SUMMARY structure:
   - Frontmatter: phase, plan_count: 4, status, exit_gate, commit_count.
   - TLDR: 33 D-XX shipped, 5-PR migration executed, SnapshotModel dropped, all 5 gates landed (G2 Julien-deferred per 0-trust §9).
   - Per-D-XX disposition table (33 rows): D-01 through D-33 each with status (`✓ shipped`/`⏳ deferred`/`⏭ skipped`) + file:line reference + verify command.
   - Per-plan summary (4 plans).
   - Counter-arguments and data gaps block (wiki_lint HARD requires this).
   - Cumulative metric snapshot.
   - Lessons learned.
   - Next-phase pointer.
   - 0-trust §9.6 Evidence + Caveat block.
   - Self-Check section.
6. **`.planning/ROADMAP.md`**: locate `### Phase: mint-data-architecture-v1-02-event-log-projection`; update Status from `📋 Panel synthesis ADR shipped` → `◆ code-shipped on dev, pending operational gates`. Update Plans count from `0 plans (pending CONTEXT.md + planning)` → `4 plans shipped`. Add a Receipt block citing all 4 plan SUMMARY paths.
7. **`.planning/STATE.md`**: update frontmatter `stopped_at` → `Phase mint-data-architecture-v1-02-event-log-projection — ◆ code-shipped on dev, pending operational gates`. Increment `completed_phases` and `completed_plans`. Append a receipt section `## Phase mint-data-architecture-v1-02 Phase-Close Receipt (W4 close-out, D-32 G3-G5 green, G1+G2 deferred, 2026-XX-XX)` mirroring the Phase 01 Plan 20 receipt structure.
8. Run wiki_lint on all 5 new docs.
  </action>
  <verify>
    <automated>python3 tools/checks/wiki_lint.py lint --strict && [ $(wc -l < docs/operations/fact-event-partition-split.md) -ge 50 ] && [ $(wc -l < docs/operations/dek-rotation-phase04.md) -ge 40 ] && [ $(wc -l < docs/operations/audit-pepper-rotation.md) -ge 40 ] && [ $(wc -l < .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html) -ge 200 ] && [ $(wc -l < .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md) -ge 180 ] && python3 tools/checks/accent_lint_fr.py docs/operations/ && grep "◆ code-shipped on dev, pending operational gates" .planning/ROADMAP.md && grep "◆ code-shipped on dev, pending operational gates" .planning/STATE.md && cd services/backend && python3 -m pytest tests/ -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `wc -l docs/operations/fact-event-partition-split.md` ≥ 50.
    - `wc -l docs/operations/dek-rotation-phase04.md` ≥ 40.
    - `wc -l docs/operations/audit-pepper-rotation.md` ≥ 40.
    - `wc -l .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html` ≥ 200.
    - `wc -l .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md` ≥ 180.
    - `python3 tools/checks/wiki_lint.py lint --strict` exits 0 after committing the 3 runbooks + SUMMARY + ROADMAP + STATE updates (full-suite pass over `.planning/**/*.md` + `docs/**/*.md`; counter-arguments + data gaps blocks present in all 5 new docs).
    - `grep "◆ code-shipped on dev, pending operational gates" .planning/ROADMAP.md` returns ≥1 hit.
    - `grep "◆ code-shipped on dev, pending operational gates" .planning/STATE.md` returns ≥1 hit.
    - SUMMARY.md covers all 33 D-XX dispositions uniquely (`[ "$(grep -oE "D-[0-9]{2}" .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md | sort -u | wc -l)" -eq 33 ]`; dedup count enforces no D-XX missing — `grep -c` would mask gaps by counting duplicate lines).
    - VERIFICATION-REPORT.html contains the 5-gate exit panel (`grep -c "G1 Maestro\|G2 Julien\|G3 dev CI\|G4 Regression\|G5 lint" VERIFICATION-REPORT.html` ≥ 5).
    - `python3 tools/checks/accent_lint_fr.py docs/operations/` exits 0.
    - Full backend pytest: `cd services/backend && python3 -m pytest tests/ -q` exits 0.
    - 0-trust §9.6 Evidence + Caveat block present in SUMMARY.md.
  </acceptance_criteria>
  <done>
    Three forward-deferred operational runbooks shipped (partition split + DEK rotation + audit-pepper rotation). Phase 02 VERIFICATION-REPORT.html (≥200 lines) and SUMMARY.md (≥180 lines) document every D-XX disposition + 5-gate exit panel + cumulative metric snapshot + lessons learned. ROADMAP.md and STATE.md flipped to `◆ code-shipped on dev, pending operational gates`. The phase is closed pending G2 device sign-off + operational gates (Sentry alarms deploy + Prometheus alert rules + post-launch soak).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Lefthook pre-push → CI | declared_counters_must_fire gate enforces D-33 firing-assertion at push time (30s pytest scenario) |
| GitHub Actions workflow → PR author | STAGING-DOWN-OVERRIDE label gated on `pull_request.user.login == 'julienbattaglia'` |
| Documentation runbook → operator | Forward-deferred procedures must be executable from runbook alone |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-22 | Tampering / Repudiation | Counter declared but never fires | mitigate | `declared_counters_must_fire.py` HARD pre-push gate runs the representative scenario test on every observability-touching push; CI re-runs on PR. Counters silently dropped from writer code (e.g., refactor regression) fail the gate. |
| T-02-23 | Information Disclosure (call-site collapse) | Alias removal breaks live callers | mitigate | Task 1 runs `git grep` for ALL `FrontalierService` references BEFORE removing the alias; updates each to `FrontalierSegmentService`; pytest regression suite must remain green post-removal. |
| T-02-24 | Compliance violation | Banned term in fact_event JSONB payload | mitigate | banned_terms_python extended with `--scan-jsonb-payload` mode; writer-level scan in `project_fact_event` raises `BannedTermsViolation` BEFORE INSERT. Test seeds banned term + confirms rejection. |
| T-02-25 | Spoofing | Non-CODEOWNER abuses STAGING-DOWN-OVERRIDE label | mitigate | GH Actions step explicitly checks `github.event.pull_request.user.login == 'julienbattaglia'`; CODEOWNERS adds defense-in-depth on workflow file ownership. |
| T-02-26 | Information Disclosure | Runbook leaks operational details to public repo | accept | Per `feedback_public_repo_discipline.md` — runbooks use neutral language, no FINMA/legal-admission phrasing; no live credentials or Railway env-var values in docs. |
</threat_model>

<verification>
**Phase-level checks for this plan:**
1. **`autonomous: true`** — all 4 tasks Claude-self-executable. G2 device sign-off + Sentry/Prometheus alarm deployment remain DEFERRED for Julien post-merge per 0-trust §9.
2. **Phase 02 exit gate** = 5-gate mechanical (D-32) + this plan's close-out artifacts. G1 Maestro and G2 device are DEFERRED to Julien (cannot self-clear per 0-trust §9.5).
3. **Wiki schema enforcement**: every new `.md` file passes `wiki_lint.py` with counter-arguments + data gaps blocks (Karpathy wiki practice 2 — HARD lint on `.planning/decisions/`, SOFT on `docs/operations/`).
4. **Public-repo discipline**: runbooks reviewed for forensic legal language (`no_legal_admission_in_public_docs.py` lint).
5. **0-trust §9**: phase SUMMARY uses « ◆ code-shipped on dev, pending operational gates » — NOT « shipped » / « ready » / « green » as final claims. Banned phrase removed; deferred items explicit.
6. **Final commit**: single commit per task; total 4 commits in Plan 02-04. Phase-close commit message: `docs(p02): phase close-out — 5-gate G3-G5 green, G1+G2 deferred to Julien (D-32)`.
</verification>

<success_criteria>
- [ ] S12 PR-2 alias removed; all `FrontalierService` callers (S23) updated to `FrontalierSegmentService` (Task 1, D-09).
- [ ] D-MOB-01 PR-A3: 3 dead Flutter-only fields removed; allowlist file deleted; parity-lint HARD without allowlist green (Task 1, D-10).
- [ ] Q6 CI mechanical fixes shipped: STAGING-MALFORMED + scheduled-only aging + STAGING-DOWN-OVERRIDE label CODEOWNER-gated (Task 2, D-06).
- [ ] `declared_counters_must_fire.py` HARD close-out gate activated; all 8 D-33 counters fire in scenario (Task 3, D-32 G3 + D-33; 6 D-33 base + 2 iter-2 additions per Plan 02-02 A4/A5).
- [ ] LSFin banned-terms extended to fact_event JSONB payload; writer-level scan blocks insertion (Task 3, D-32 G5).
- [ ] 3 forward-deferred runbooks shipped: partition-split (Task 4, ≥50 lines), DEK rotation (≥40 lines), audit-pepper rotation (≥40 lines).
- [ ] Phase 02 VERIFICATION-REPORT.html (≥200 lines) and SUMMARY.md (≥180 lines) document every D-XX + 5-gate exit panel (Task 4).
- [ ] ROADMAP.md + STATE.md flipped to `◆ code-shipped on dev, pending operational gates` (Task 4).
- [ ] All 5-gate G3-G5 green on dev CI: pytest full suite + alembic_boolean_default_lint + hmac_pepper_audit + profile_safe_fields_parity HARD + banned_terms_python + accent_lint_fr + arb_parity + declared_counters_must_fire (HARD pre-push).
- [ ] G1 Maestro: DEFERRED if no booted sim (documented as such in HTML report).
- [ ] G2 Julien device sign-off: DEFERRED per 0-trust §9 (cannot self-clear; 5 walkthrough scenarios in HTML report).
- [ ] Plan 02-04 SUMMARY cites all 4 plans' SUMMARY paths + final commit SHA + 0-trust §9.6 evidence/caveat block.
- [ ] `mem_save` with `topic_key: mint-data-architecture-v1-02:phase-close:shipped-pending-G2` and `prior_finding_refs` ≥10 obs (per Phase 01 close-out doctrine).
</success_criteria>

<output>
After completion, ensure:
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-SUMMARY.md` (this plan's per-task receipt) exists.
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md` (phase-level, written by Task 4) exists.
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html` exists.
- Both ROADMAP.md and STATE.md flipped.
- Plan 02-04 SUMMARY content:
  - Per-task verify command stdout (declared_counters_must_fire output, wiki_lint per-file output, full pytest exit-0, lints all green).
  - All commit SHAs in order (4 atomic commits).
  - 6 D-XX dispositions: D-06, D-07 (REVOKE shipped in p98 from Plan 02-02; runbook in this plan), D-09 (PR-2 alias removal), D-10 (PR-A3 dead-field drop), D-32 (5-gate green), D-33 (counters firing-asserted).
  - 0-trust §9.6 Evidence + Caveat block.
  - `mem_save` with `topic_key: mint-data-architecture-v1-02:phase-close:shipped-pending-G2` + `prior_finding_refs` to obs #163, #174, #175, #176, #178, #183, #186, #187, #188 + Plan 02-01 obs + Plan 02-02 obs + Plan 02-03 obs (≥10 refs per Phase 01 compounding-observable doctrine).
</output>

---

<!-- ============================================================== -->
<!-- ITER-2 REVIEWS REVISION — appended 2026-05-18                 -->
<!-- Close-out plan absorbs B7 + B16 + B17 + C1 + C6 + C7 + C8.    -->
<!-- ============================================================== -->

<iter_2_revision>

## Iter-2 Reviews Revision — Plan 02-04

**Trigger:** REVIEWS.md residual Tier-B/C items that landed on close-out plan : runbook ordering (B7), counter-firing site verification (B16), Mobile L1 race tests (B17), docker docs (C1), native UUID/TIMESTAMPTZ (C6), JSONB size cap (C7), STAGING-DOWN-OVERRIDE required check (C8).

**Tier-B handled here:**
- B7 : `audit-pepper-rotation.md` runbook PR-ordering rule — p114 BEFORE any query-layer code change. (Patch to Task 4 step 3 below.)
- B16 : `declared_counters_must_fire.py` grep ≥1 increment site in `app/` source (not tests) — counter cannot be declared and never wired. (Patch to Task 3.)
- B17 : D-30 race tests — 2-device + clock-skew + reinstall + low-storage. (NEW Task 5 below — Flutter-side tests + sim coverage.)

**Tier-C handled here:**
- C1 : Document Docker dep in `services/backend/README.md` or `CONTRIBUTING.md`. (Small README patch in Task 4 below.)
- C6 : `event_id VARCHAR(36)` → native UUID + `TIMESTAMP` → `TIMESTAMPTZ`. (Deferred to Phase 03 close-out per Tier-C low severity ; document the deferral here.)
- C7 : JSONB `pg_column_size < 65536` CHECK constraint on `fact_event.value_enc`. (Deferred to Phase 03 schema-hardening migration ; B11 enrichmentPrompts cap from Plan 02-02 iter-2 mitigates the dominant TOAST risk in Phase 02.)
- C8 : STAGING-DOWN-OVERRIDE as required status check. (Patch to Task 2 below — adds GitHub branch-protection contract documentation ; actual rule enable is Julien-only via GitHub UI.)

**Tier-A/B NOT handled here:**
- All Tier-A handled in Plan 02-02 (DDL + security + projector + canary) and Plan 02-03 (PR-3 split + drift gate).
- Tier-A A11 D-34 PROPOSED needs Plan 02-04 close-out to ACKNOWLEDGE in SUMMARY (Task 4 patch below).

### Patch to original Task 3 — B16 declared_counters grep-in-app/ source check

**Updated `<action>` step 1 — `tools/checks/declared_counters_must_fire.py`** (insert after Step 3 « runs representative scenario », BEFORE Step 4 « if delta == 0 ») :

```python
# Step 3.5 (iter-2 B16): for each declared counter, grep app/ source for at least one increment site.
# This catches declare-and-forget regressions even if the pytest scenario doesn't exercise the counter.
import subprocess
DECLARED_COUNTERS = [...]  # extracted via AST in step 1
APP_ROOT = "services/backend/app/"
unwired = []
for counter_name in DECLARED_COUNTERS:
    # ripgrep is faster + has dedup ; fall back to git grep if rg missing
    cmd = ["rg", "-c", "--type", "py", "-l", counter_name, APP_ROOT] if shutil.which("rg") else ["git", "grep", "-rln", counter_name, APP_ROOT]
    result = subprocess.run(cmd, capture_output=True, text=True)
    found_files = [f for f in result.stdout.strip().split("\n") if f and not f.endswith("counters.py")]
    if not found_files:
        unwired.append(counter_name)
if unwired:
    print(f"BLOCKED: {len(unwired)} declared counters have ZERO increment sites in {APP_ROOT}:")
    for c in unwired:
        print(f"  - {c}")
    sys.exit(1)
```

**Updated `<action>` step 1 final — counter set bumped to 8** (from 6 D-33 base) :
- 6 D-33 base counters (Plan 02-02 declares).
- + `mint_kms_backend_failure_total` (Plan 02-02 iter-2 A4 / D-35 PROPOSED).
- + `mint_dek_cache_size_total` (Plan 02-02 iter-2 A5).

The scenario test `tests/observability/test_phase02_counters.py` (original Task 3 step 2) MUST be extended :
- A4 scenario : invoke `_select_backend()` with `MINT_KMS_KEY_ID` unset → catch `KMSBackendUnavailable` ; assert `mint_kms_backend_failure_total.labels(backend='none', reason='MINT_KMS_KEY_ID unset')._value.get() >= 1`.
- A5 scenario : invoke 3 `get_or_create_dek()` calls → assert `mint_dek_cache_size_total._value.get() in (1, 2, 3)` (depending on whether deks reuse the same user_id).

**Updated `<acceptance_criteria>` for original Task 3** (add) :
- `python3 tools/checks/declared_counters_must_fire.py --all` exits 0 for all 8 declared counters.
- `mint_kms_backend_failure_total` has ≥1 increment site in `app/services/encryption/` (grep verified).
- `mint_dek_cache_size_total` has ≥1 increment site in `app/services/encryption/key_vault.py` (grep verified).

### Patch to original Task 4 step 3 — B7 audit-pepper rotation runbook PR-ordering rule

**Updated `<action>` step 3 — `docs/operations/audit-pepper-rotation.md`** — INSERT a new section between « Step-by-step procedure » and « Rehearsal » :

```markdown
## PR-ordering rule (iter-2 B7, security-auditor non-negotiable)

Audit-pepper rotation requires Postgres backfill writes (alembic `p114_hmac_pepper_audit_events`-style migration that re-hashes existing rows with new pepper) AND query-layer code changes (read-path reads from `user_id_hash_v2` column).

**These MUST land in strict order :**

1. **First PR — backfill alembic only (no query-layer changes).** Migration writes new `user_id_hash_v2` column ; backfills from plaintext (if retained per D-15 deprecation cycle) OR raises explicit `PepperRotationDataLossError` if plaintext already dropped.
2. **Second PR — query-layer dual-read.** Read path queries BOTH `user_id_hash` (v1) AND `user_id_hash_v2` (transition window 6 months).
3. **Third PR — drop v1 column + rename v2 → v1.** Atomic with the rotation completion.

**Why this order matters :** if the query-layer change ships BEFORE backfill, audit queries return 0 rows for the entire pre-rotation window (silent data hole). The backfill must complete + verify FIRST, then the query layer can safely include the new column.

**Freeze contract :** during the backfill PR's execution window (typically 1-4 hours on Railway production), ALL audit_event writes are frozen via a feature flag `FF_AUDIT_PEPPER_ROTATION_IN_PROGRESS=on`. Reads continue ; writes return `503 Service Unavailable` with retry-after header. Mobile L1 audit offline queue absorbs the temporary write-rejection per D-30 retry-with-backoff.

**Rollback :** if the backfill PR fails mid-execution, the new `user_id_hash_v2` column is left in PARTIAL state. The freeze flag is left on ; recovery procedure is the inverse-PR-1 (drop the new column ; rebuild from plaintext-retained-rows OR accept the data hole).
```

**Updated `<acceptance_criteria>` for original Task 4 step 3** (add) :
- `docs/operations/audit-pepper-rotation.md` contains the « PR-ordering rule » section with 3-step ordering, freeze contract, and rollback procedure.
- `wc -l docs/operations/audit-pepper-rotation.md` ≥ 50 (was 40 — bumped by the new section).

### Patch to original Task 2 — C8 STAGING-DOWN-OVERRIDE required check contract

**Updated `<action>` step 2** — append to the section creating `.github/CODEOWNERS` :

```markdown
**iter-2 C8 — STAGING-DOWN-OVERRIDE required check contract** :

The label-based gate (introduced in original Task 2 step 1) is enforced at runtime in `.github/workflows/regulatory-codegen.yml`. To prevent a label-bypass when the workflow itself is bypassed (e.g., branch protection allows skipping required workflows), iter-2 documents the required-check rule that Julien MUST apply via the GitHub UI (NOT Claude-actionable) :

**Required actions for Julien (post-merge of this plan, owner-only)** :

1. GitHub repo Settings → Branches → Branch protection rule for `main` :
   - Add `regulatory-codegen / staging-check` as a required status check.
   - Enable « Require status checks to pass before merging ».
   - Enable « Restrict who can dismiss pull request reviews » to `@julienbattaglia`.
2. GitHub repo Settings → Branches → Branch protection rule for `dev` (mirror to `main`).
3. Document the contract in `docs/operations/staging-down-override.md` (a sibling to the existing `audit-pepper-rotation.md`).

**`docs/operations/staging-down-override.md` (NEW, ≥30 lines)** : surfaces the 2-key invariant —
(1) STAGING-DOWN/MALFORMED state requires the `STAGING-DOWN-OVERRIDE` PR label,
(2) the label requires `@julienbattaglia` as PR author (workflow-enforced) ;
plus the override audit-trail (each override application logs to `_phase02_parity_audit_continuous` via a workflow step that writes a one-row INSERT).
```

**Updated `<files_modified>` for original Task 2** (add) :
- `docs/operations/staging-down-override.md`

**Updated `<acceptance_criteria>` for original Task 2** (add) :
- `docs/operations/staging-down-override.md` exists ≥30 lines, contains 2-key invariant + override audit-trail.
- Branch protection rule enable is DEFERRED to Julien (NOT Claude-actionable) — surfaced in Plan 02-04 SUMMARY as an outstanding operational item.

### Patch to original Task 4 — C1 Docker docs

**Updated `<action>` step 1 — `docs/operations/fact-event-partition-split.md`** — append a paragraph after « Counter-arguments and data gaps block » :

```markdown
## Local development prerequisites (iter-2 C1)

The Postgres-real test harness (D-22, testcontainers-python ≥4.7) requires Docker. macOS users : install Docker Desktop or OrbStack ; Linux users : `apt install docker.io docker-compose-plugin`. CI : GitHub Actions `ubuntu-latest` ships Docker pre-installed.

**Test-time Docker availability check** : `services/backend/tests/fixtures/pg_fixture.py` runs `docker info` once at session-scope startup ; if Docker is unavailable, all `@pytest.mark.pg` tests skip with explicit message « Docker unavailable — install Docker Desktop or run with PG_FIXTURE_SKIP=1 ». No silent skip — the skip reason is logged.

**Backend README addendum** : `services/backend/README.md` (DOES this file exist? executor: check via `[ -f services/backend/README.md ] && tail -50 OR create new`) includes a « Test harness setup » section pointing to this runbook for the Docker requirement.
```

**New file `services/backend/README.md` (or extend if exists)** — add a « Test harness setup » section :

```markdown
## Test harness setup (Phase 02 D-22)

The MINT backend test suite includes integration tests against a real Postgres 15.x instance via testcontainers-python. Local prerequisites :

- Docker Desktop (macOS) OR Docker Engine (Linux).
- Python 3.11+ with `pip install -e "services/backend[test]"`.

Quick start :
```bash
cd services/backend
pytest tests/ -q -k "not pg"   # skip Postgres-real tests (fast, ~25s)
pytest tests/ -q               # full suite incl. Postgres (~90s with testcontainers spin-up)
```

CI gates : GitHub Actions runs `pytest tests/ -q -k pg` on every PR touching `services/backend/alembic/**` or `services/backend/app/models/**` or `services/backend/tests/fixtures/**`.

See `docs/operations/fact-event-partition-split.md` for the Docker version pinning + Railway PG version sync procedure.
```

### New Task 5 — D-30 race tests (Tier-B B17, qa-expert)

Inserted at end of Plan 02-04. Flutter-side + sim coverage for Pitfall 3 (out-of-order event_id), Pitfall 5 (reinstall orphan chain), Pitfall 6 (battery drain). qa-expert flagged the `<verify>` block as empty in Plan 02-02 ; iter-2 lifts the work into Plan 02-04 close-out because the tests are observational (would slow down Plan 02-02 PR cycle).

<task type="auto">
  <name>Task 5 (NEW iter-2): D-30 race + edge-case tests (Tier-B B17, qa-expert plan-patch #7)</name>
  <files>
    apps/mobile/test/services/audit/test_two_device_offline_to_online.dart,
    apps/mobile/test/services/audit/test_clock_skew_uuid7_ordering.dart,
    apps/mobile/test/services/audit/test_anonymous_session_reinstall_orphan.dart,
    apps/mobile/test/services/audit/test_sqlite_buffer_full_low_storage.dart,
    services/backend/tests/integration/test_projector_out_of_order_event_id.py,
    services/backend/tests/integration/test_anonymous_session_reinstall_orphan_backend.py
  </files>
  <read_first>
    apps/mobile/lib/services/audit/mobile_l1_audit_service.dart (from Plan 02-02 — service under test),
    apps/mobile/lib/services/audit/offline_queue.dart (from Plan 02-02 — replay logic + backoff cap),
    apps/mobile/lib/services/audit/audit_buffer_db.dart (from Plan 02-02 — sqflite_sqlcipher buffer schema),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Pitfall 3 + 5 + 6 — explicit race surfaces flagged but not wired)
  </read_first>
  <action>
1. **`apps/mobile/test/services/audit/test_two_device_offline_to_online.dart` (NEW)** : Pitfall 3 race surface — same user has 2 devices, both offline, both queue events with monotonic UUID v7 (per device). When both come online, the link batch from device A and device B both POST to `/v1/audit/mobile-session-link`. **Assertion** : server's UNIQUE `(anonymous_session_id, observed_at)` constraint blocks dups (device A and device B have DIFFERENT anonymous_session_ids → no collision ; but if user re-installs A → A's old anonymous_session_id is dropped + new one generated, both old and new sessions get linked at next login). Test the « both online simultaneously » race and assert response shape : both batches return 200, link count is sum.
2. **`apps/mobile/test/services/audit/test_clock_skew_uuid7_ordering.dart` (NEW)** : UUID v7 incorporates the 48-bit ms timestamp. If the device clock skews backward 1 hour between two events, UUID v7 ordering is INVERTED relative to actual recording order. **Assertion** : projector (server-side) skips re-projection if `event.event_id <= fact_current.latest_event_id` — under clock skew, the second-recorded event might have a SMALLER UUID v7. iter-2 mitigation : the projector uses `event_id` as sequence number, NOT timestamp ; the « monotonicity » is by UUID v7 sort order, which IS the recording-order intent. Document the trade-off : a skew-induced inversion makes the projection « miss » the clock-skewed event ; D-30 + UUID v7 accept this as cost of offline-capable design (server-side timestamp is authoritative for read-back via `recorded_at`).
3. **`apps/mobile/test/services/audit/test_anonymous_session_reinstall_orphan.dart` (NEW)** : Pitfall 5 — user wipes app + reinstalls BEFORE linking. **Assertion** : the previous anonymous_session_id's audit rows in mobile SQLite are GONE (sqflite_sqlcipher buffer cleared on uninstall) ; on reinstall, a NEW UUID v7 is generated. The 6-month-old anonymous session is orphan on the backend (no user_id_hash) but LSFin-auditable by `(observed_at, app_version, constants_version_hash)`. The test confirms the new install does NOT attempt to re-link the old session (no shared device fingerprint).
4. **`apps/mobile/test/services/audit/test_sqlite_buffer_full_low_storage.dart` (NEW)** : Pitfall 6 — low-storage iOS hits 80% storage → sqflite_sqlcipher returns `SqliteException` on insert. **Assertion** : `MobileL1AuditService.recordSessionStart()` catches the exception, logs to Sentry as breadcrumb (NOT user-facing), increments `mint_anonymous_session_link_total{outcome='error', reason='sqlite_full'}` (Plan 02-02 declared counter), AND returns gracefully (no crash). The audit row is LOST (acceptable cost — LSFin auditor can match by `observed_at` + `app_version` per CONTEXT data gap).
5. **`services/backend/tests/integration/test_projector_out_of_order_event_id.py` (NEW)** : Pitfall 3 backend side — write fact_event with event_id_NEW (sorted lower than fact_current.latest_event_id), project, assert skip + counter increment. Already partially covered by `test_projector_idempotency.py` from Plan 02-02 ; this test specifically asserts the clock-skew inversion case (event_id sort < latest_event_id by NON-trivial delta).
6. **`services/backend/tests/integration/test_anonymous_session_reinstall_orphan_backend.py` (NEW)** : write a `projection_audit_records` row with `anonymous_session_id=A` + `source='mobile_session_start'` ; never call /v1/audit/mobile-session-link for that A (user wiped app). Assert : the row stays in the table with `user_id_hash=NULL` ; query by `(observed_at, app_version, constants_version_hash)` returns the orphan row.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/audit/test_two_device_offline_to_online.dart test/services/audit/test_clock_skew_uuid7_ordering.dart test/services/audit/test_anonymous_session_reinstall_orphan.dart test/services/audit/test_sqlite_buffer_full_low_storage.dart 2>&1 | tail -10 && cd services/backend && python3 -m pytest tests/integration/test_projector_out_of_order_event_id.py tests/integration/test_anonymous_session_reinstall_orphan_backend.py -q -k pg    </automated>
  </verify>
  <acceptance_criteria>
    - 4 Flutter test files in `apps/mobile/test/services/audit/` exit 0 under `flutter test`.
    - 2 Python integration test files in `services/backend/tests/integration/` exit 0 under `pytest -q -k pg`.
    - `mint_anonymous_session_link_total{outcome='error', reason='sqlite_full'}` is incremented in the SQLite-full test (asserted via prometheus_client counter inspection at test end).
    - Test for clock-skew inversion is documented as « accepting trade-off » in test docstring + Plan 02-04 SUMMARY (NOT as a bug ; D-30 + UUID v7 explicitly accept this race).
  </acceptance_criteria>
  <done>
    D-30 race surface tests shipped. Pitfall 3 (out-of-order event_id) + Pitfall 5 (reinstall orphan) + Pitfall 6 (low-storage SQLite full) all have explicit test coverage. The 4 race surfaces qa-expert flagged as `<verify>` empty in Plan 02-02 are now wired.
  </done>
</task>

### Patch to original Task 4 — SUMMARY acknowledgment of D-34 + D-35 PROPOSED + Tier-C deferrals

**Updated `<action>` step 5 — `mint-data-architecture-v1-02-event-log-SUMMARY.md`** (insert NEW subsections in the per-D-XX disposition table) :

```markdown
### iter-2 PROPOSED decisions (pending Julien-owner approval)

| D-XX | Status | Disposition | Reference |
|------|--------|-------------|-----------|
| D-34 (PROPOSED) | ✓ shipped (pending CONTEXT lock) | Multi-shape canary parity gate (5 fact-types covering scalar + decimal + nested JSONB + nullable + TOAST) BEFORE Plan 02-03 PR-3 fires | Plan 02-02 Task 3C + REVIEWS.md A11 |
| D-35 (PROPOSED) | ✓ shipped (pending CONTEXT lock) | KMS fail-closed never silent fallback — `_select_backend()` raises `KMSBackendUnavailable` ; `mint_kms_backend_failure_total` counter | Plan 02-02 Task 2 iter-2 A4 + REVIEWS.md security-auditor T-S09 |

### iter-2 Tier-C deferred items (documented, not blocking)

| Tier-C | Item | Defer-to | Justification |
|--------|------|----------|---------------|
| C4 | Merge over-decomposed D-XX (33 → ~26) | Post-Phase-02 retrospective | Renumbering risks audit-trail breakage during active execution. Acceptable cost of 33 distinct decisions. |
| C6 | `event_id VARCHAR(36)` → native UUID + `TIMESTAMP` → `TIMESTAMPTZ` | Phase 03 schema-hardening migration | Pre-launch performance dominated by network, not column-type. Native UUID storage is ~25% smaller but the savings are << total row size. |
| C7 | JSONB `pg_column_size < 65536` CHECK constraint on `fact_event.value_enc` | Phase 03 schema-hardening migration | B11 enrichmentPrompts cap (Plan 02-02 iter-2) mitigates dominant TOAST risk in Phase 02. A blanket CHECK requires defining « what is too big » — defer until prod data shape known. |
```

### Patch to original Task 4 step 4 — VERIFICATION-REPORT.html iter-2 acknowledgment

**Updated `<action>` step 4 — `mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html`** (add new section after « 5-gate exit panel ») :

```html
<section class="iter-2-reviews-revision">
  <h2>Cross-AI Reviews Revision (iter-2)</h2>
  <p>Phase 02 was reviewed by 6 AI reviewers (Gemini 2.5 Pro + Claude MINT panel of 5 specialists). Risk verdict consensus: <strong>MEDIUM</strong> (5-of-6 reviewers), NOT LOW.</p>
  <h3>Tier-A blockers handled (11/11)</h3>
  <ul>
    <li>A1 — dek_vault ON DELETE RESTRICT + tombstone_at: Plan 02-02 Task 3A (DDL)</li>
    <li>A2 — fact_event PK reorder (subject_id, event_id): Plan 02-02 Task 3A (DDL)</li>
    <li>A3 — fact_current covering index leading column: Plan 02-02 Task 3A (DDL)</li>
    <li>A4 — KMS fail-closed (D-35 PROPOSED): Plan 02-02 Task 2 patch</li>
    <li>A5 — DEK cache TTL eviction: Plan 02-02 Task 2 patch</li>
    <li>A6 — Audit mobile link handshake: Plan 02-02 Task 3 patch</li>
    <li>A7 — D-20 lint 5 bypass shapes: Plan 02-01 Task 2 patch</li>
    <li>A8 — Projector atomic UPSERT: Plan 02-02 Task 3B</li>
    <li>A9 — PR-3 split into PR-3a + PR-3b: Plan 02-03 Task 2 SPLIT</li>
    <li>A10 — projection_diff.py deterministic: Plan 02-03 Task 2a</li>
    <li>A11 — Multi-shape canary (D-34 PROPOSED): Plan 02-02 Task 3C</li>
  </ul>
  <h3>Tier-B applied (16/20) + deferred (4/20)</h3>
  <p>Applied: B1, B2, B3, B4, B5, B6, B7, B8, B9, B10, B11, B12, B13, B14, B15, B16, B17, B18, B19, B20 (full list per per-plan iter_2_revision sections).</p>
  <p>Deferred with explicit reasoning: (none — all 20 absorbed).</p>
  <h3>Tier-C acknowledged (8/8)</h3>
  <p>C1 + C2 + C3 + C5 + C8 applied as small patches. C4 + C6 + C7 deferred to Phase 03 schema-hardening with documented rationale.</p>
</section>
```

### CONTEXT.md changes proposed by Plan 02-04 iter-2 (summary)

NONE new for Plan 02-04. The Plan 02-02 + Plan 02-03 iter-2 sections propose D-05 + D-26 + D-28 + D-29 + D-30 + D-31 amendments + D-34 + D-35 PROPOSED ; this plan ACKNOWLEDGES them in SUMMARY.md but does NOT itself amend CONTEXT.md (those amendments are owner-approval gates).

### VALIDATION.md additions proposed by this revision

Append to `## Per-Task Verification Map → Wave 4 — Close-out + counters + runbooks (Plan 02-04)` :

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|
| 02-04-5 | 02-04 | 4 | B17 D-30 race tests | T-02-15 + clock-skew | 4 Flutter tests + 2 backend tests cover Pitfall 3/5/6 race surfaces ; SQLite-full graceful degradation | unit + integration | `flutter test test/services/audit/test_*.dart && pytest tests/integration/test_projector_out_of_order_event_id.py tests/integration/test_anonymous_session_reinstall_orphan_backend.py -q -k pg` |
| 02-04-3 (extend) | 02-04 | 4 | B16 grep-in-app/ | T-02-22 | declared_counters_must_fire greps each counter has ≥1 increment site in app/ source (not tests) | unit | `python3 tools/checks/declared_counters_must_fire.py --all` (already in original verify, extended with grep step) |
| 02-04-4 (extend) | 02-04 | 4 | B7 pepper rotation PR-ordering | T-02-04 | audit-pepper-rotation.md contains PR-ordering rule (3 steps) + freeze contract + rollback | grep | `grep "PR-ordering rule" docs/operations/audit-pepper-rotation.md` |
| 02-04-2 (extend) | 02-04 | 4 | C8 STAGING-DOWN-OVERRIDE required check | T-02-25 | staging-down-override.md exists ≥30 lines ; branch protection rule enable deferred to Julien | grep | `[ -f docs/operations/staging-down-override.md ] && wc -l docs/operations/staging-down-override.md` |
| 02-04-1 (extend) | 02-04 | 4 | C1 Docker docs | — | services/backend/README.md or fact-event-partition-split.md documents Docker prerequisite | grep | `grep -E "Docker|testcontainers" services/backend/README.md docs/operations/fact-event-partition-split.md` |

### Threat-model extension (append, do not rewrite)

Append to the existing STRIDE Threat Register in this plan :

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-27 | Tampering | Counter declared but no increment site in app/ source (declare-and-forget regression) | mitigate (B16) | declared_counters_must_fire.py extended with grep step on app/ source ; CI/pre-push fails if any counter lacks ≥1 increment site outside counters.py declaration. |
| T-02-28 | Repudiation | Mobile L1 audit row LOST on SQLite-full edge case | accept (B17) | Pitfall 6 — sqflite_sqlcipher returns SqliteException ; service catches + Sentry breadcrumb + counter increment ; LSFin auditor can match by (observed_at, app_version, constants_version_hash). Documented in test docstring. |
| T-02-29 | Integrity / Repudiation | Audit-pepper rotation query-layer-before-backfill creates silent data hole | mitigate (B7) | audit-pepper-rotation.md documents strict 3-step PR ordering + freeze contract. Plan 02-04 ships the runbook but rotation EXECUTION is forward-deferred. |

### `<files_modified>` additions for Plan 02-04 frontmatter

```yaml
files_modified:
  # ...original list...
  - apps/mobile/test/services/audit/test_two_device_offline_to_online.dart                    # B17
  - apps/mobile/test/services/audit/test_clock_skew_uuid7_ordering.dart                       # B17
  - apps/mobile/test/services/audit/test_anonymous_session_reinstall_orphan.dart              # B17
  - apps/mobile/test/services/audit/test_sqlite_buffer_full_low_storage.dart                  # B17
  - services/backend/tests/integration/test_projector_out_of_order_event_id.py                # B17
  - services/backend/tests/integration/test_anonymous_session_reinstall_orphan_backend.py     # B17
  - services/backend/README.md                                                                 # C1
  - docs/operations/staging-down-override.md                                                   # C8
```

### Iter-2 commit recommendation

Single commit message: `docs(mint-data-architecture-v1-02-event-log-projection): plan iter-2 reviews revision — B7 pepper rotation order + B16 grep-app + B17 D-30 race tests + C1 Docker docs + C8 STAGING-DOWN-OVERRIDE contract (Plan 02-04)`.

</iter_2_revision>

<!-- ============================================================== -->
<!-- ITER-3 REVISION — appended 2026-05-18                          -->
<!-- Source: REVIEWS.md §7.6 Claude-Opus universal-miss              -->
<!-- Scope: forward-defer the session-start audit-pollution attack   -->
<!-- to Phase 04 via runbook stub + SUMMARY acknowledgment. NO       -->
<!-- implementation in Phase 02 (per scope_contract item iA4).       -->
<!-- ============================================================== -->

<iter_3_revision>

## Iter-3 Reviews Revision — Plan 02-04

**Trigger:** REVIEWS.md §7.6 — Claude-Opus surfaced a finding ALL prior reviewers missed (Gemini + 5-panel + Codex-pending). Quote:

> *« Per Plan 02-02 Task 3 step 7: `Depends(get_current_user_optional)` on `/v1/audit/mobile-session-start` accepts anonymous payload. With A6 handshake mitigation, link-spoofing IS closed — but session-start spoofing is wide open. Any HTTP client can POST a fake `anonymous_session_id` with any `app_version` claim ; server INSERTs without validation. The UNIQUE constraint on `(anonymous_session_id, observed_at)` blocks only exact duplicates — adversary just varies `observed_at`. Result: audit trail polluted with synthetic rows that look legitimate (correct shape, server timestamps). »*

**Phase 02 disposition:** ACKNOWLEDGED as known limitation. Mitigation deferred to Phase 04 hardening per Claude-Opus §7.8 recommendation 4. Rationale: Phase 02 closes the LSFin audit-trail gap (architect-review obs #176) and the link-spoofing high (T-S01 / iter-2 A6). Session-start spoofing requires App Attestation infrastructure (Apple DeviceCheck + Android Play Integrity) that has no Railway-side equivalent and demands fastlane match profile updates per `feedback_ios_entitlements_block_testflight.md` — out-of-scope for Phase 02.

### iA4 — Forward-deferred Phase 04 mobile-attestation hardening runbook + SUMMARY acknowledgment

**Source:** REVIEWS.md §7.6 universal-miss + §7.8 recommendation 4.

**Fix landing sites:**

1. **NEW file `docs/operations/phase-04-mobile-attestation-hardening.md`** (≥30 lines stub authored by Plan 02-04 Task 4) — documents the attack + mitigation + Phase 04 work breakdown. NO implementation in Phase 02.
2. **Plan 02-04 Task 4 step 5 SUMMARY** — extend the per-D-XX disposition table with a « Forward-deferred to Phase 04 » subsection citing this runbook + the Claude-Opus REVIEWS reference.
3. **Plan 02-04 Task 4 step 4 VERIFICATION-REPORT.html** — extend the « Deferred items » section with the session-start audit-pollution finding (linked to the new runbook).

#### Patch to Task 4 `<files>` block — add (iter-3 iA4)

Add to Task 4 `<files>` element:
- `docs/operations/phase-04-mobile-attestation-hardening.md` (NEW, ≥30 lines, content outlined below)

Add to Plan 02-04 frontmatter `files_modified`:
- `docs/operations/phase-04-mobile-attestation-hardening.md    # iter-3 iA4 (session-start audit-pollution forward-defer)`

#### Patch to Task 4 step 1-3 ordering — INSERT NEW step before step 4 VERIFICATION-REPORT

Insert as new step **3.5** (between « audit-pepper-rotation.md » step 3 and « VERIFICATION-REPORT.html » step 4):

```markdown
3.5. **`docs/operations/phase-04-mobile-attestation-hardening.md` (NEW, ≥ 30 lines, iter-3 iA4)**: per REVIEWS.md §7.6 Claude-Opus universal-miss + §7.8 recommendation 4. Sections (each non-trivial — wiki_lint enforces counter-arguments + data gaps blocks):

   - **TL;DR + status** (forward-deferred to Phase 04 — Phase 02 ACKNOWLEDGES but does NOT mitigate).
   - **The attack** (Claude-Opus REVIEWS §7.6 quote verbatim): session-start endpoint accepts anonymous payload with `Depends(get_current_user_optional)`. iter-2 A6 closed the link-side spoofing but session-start spoofing remains: any HTTP client can POST `/v1/audit/mobile-session-start` with synthetic `anonymous_session_id` + `app_version` + `observed_at` ; UNIQUE `(anonymous_session_id, observed_at)` blocks only exact duplicates ; adversary varies `observed_at` per row. Result : audit trail polluted with synthetic rows that look legitimate (correct shape, server timestamps).
   - **Why Phase 02 does NOT fix this**: requires App Attestation infrastructure outside Phase 02 scope. Phase 02 closes the LSFin audit-trail gap (architect-review obs #176) + link-side spoofing (T-S01 / iter-2 A6) ; session-start hardening is an Apple-Developer-portal + fastlane-match-profile update per `feedback_ios_entitlements_block_testflight.md` discipline rule (entitlements PRs ship in isolation).
   - **Mitigation plan for Phase 04** (4 layers, defense-in-depth) :
     1. **Rate-limit per source IP** — FastAPI middleware (e.g., `slowapi` or `fastapi-limiter` with Redis backend). Suggested rate: 5 requests / 5 minutes per IP on `/v1/audit/mobile-session-start`. Counter `mint_audit_mobile_session_rate_limited_total{source_ip_hash}` increments on cap-hit.
     2. **Apple App Attestation (DeviceCheck)** — production iOS builds embed a signed App Attestation token in the POST body (`x-mint-app-attestation-token` header). FastAPI handler validates via Apple's public-key endpoint per `https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity`. Untokened or invalid-token POSTs return 401 in production ; dev builds bypass via `MINT_REQUIRE_APP_ATTESTATION=false` env flag.
     3. **Android Play Integrity** — equivalent for Android builds via `https://developer.android.com/google/play/integrity`. Token validation server-side.
     4. **`projection_audit_record.attestation_status` column** (Alembic p1XX in Phase 04) — discriminator: `'valid' | 'invalid' | 'bypass_dev' | 'rate_limited'`. Existing rows backfill to `'unattested_phase02'` (cleanly signaling the pre-hardening window in audit logs).
   - **Trigger conditions for Phase 04 activation** :
     - First production iOS / Android release reaches TestFlight / Play Internal Testing.
     - First sustained `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` spike on Railway (≥10 events/hour) — indicates an attacker is probing the endpoint.
     - First LSFin audit inquiry pre-launch (low probability) — auditor asks « how do you authenticate that an audit row came from an actual MINT install? ».
   - **Rollback procedure** — pre-launch zero-data + zero paying users = full revert is safe. Drop the attestation_status column ; revert the rate-limit middleware ; the existing audit chain stays intact (no data loss).
   - **Counter-arguments and data gaps block** (HARD per wiki_lint) :
     - **Steel-man for NOT hardening** : pre-launch zero users + zero adversary motivation. Spend on Phase 03 coach-extractor instead. **Mitigation** : the trigger conditions above gate activation ; no work happens until evidence demands it.
     - **What this discussion did NOT address** : (a) battery cost of App Attestation token generation per cold-start (deferred to Phase 04 device-gate measurement) ; (b) audit-row deletion semantics if attestation INVALIDATES post-INSERT (deferred — current design: attestation is INSERT-time only, no retroactive invalidation per D-04 PIT doctrine) ; (c) iOS App Attestation requires `com.apple.developer.devicecheck.appattest-environment` entitlement which per `feedback_ios_entitlements_block_testflight.md` is release-blocking and MUST ship in isolation (separate PR from app-feature changes).
     - **What would change this conclusion** : (a) Phase 02 launch + spike in `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` counter; (b) FINMA/EDÖB inquiry on audit-source authentication; (c) iOS 19+ deprecates DeviceCheck (mitigated by Phase 04 picking AppAttest API, not legacy DeviceCheck).
   - **Cross-references** :
     - REVIEWS.md §7.6 (Claude-Opus universal-miss source).
     - REVIEWS.md §7.8 recommendation 4 (forward-defer recommendation).
     - `iter-3` SUMMARY entry in this plan's Task 4 step 5 (per-D-XX disposition).
     - `apps/mobile/lib/services/audit/mobile_l1_audit_service.dart` (Plan 02-02 Task 3 — Phase-02-shipped mobile L1 audit service ; Phase 04 wires the attestation token here).
     - `services/backend/app/api/v1/endpoints/audit_mobile.py` (Plan 02-02 Task 3 — Phase-02-shipped endpoint ; Phase 04 adds the validation middleware).
     - `feedback_ios_entitlements_block_testflight.md` (release-blocking entitlement discipline).

   File must pass `wiki_lint.py --strict` (counter-arguments + data gaps blocks present, accent_lint_fr green, no banned terms).
```

#### Patch to Task 4 step 4 VERIFICATION-REPORT.html — add Deferred-items entry

Update Task 4 step 4 « Deferred items » section to include:

```markdown
- **Session-start audit-pollution mitigation** (REVIEWS.md §7.6 Claude-Opus universal-miss) — forward-deferred to Phase 04 ; runbook: `docs/operations/phase-04-mobile-attestation-hardening.md` ; trigger: TestFlight/Play release OR `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` ≥ 10/hour OR LSFin inquiry. **NOT shipped in Phase 02.** Existing audit rows stay in `'unattested_phase02'` status post-Phase-04 backfill.
```

#### Patch to Task 4 step 5 SUMMARY — add « Forward-deferred to Phase 04 » subsection

Insert into the SUMMARY.md per-D-XX disposition table, AFTER the « iter-2 Tier-C deferred items » subsection (from iter-2_revision Task 4 patch above):

```markdown
### iter-3 Forward-deferred to Phase 04 (Claude-Opus post-iter-2 review universal-miss)

| Finding | Status | Runbook | Trigger | Reference |
|---------|--------|---------|---------|-----------|
| Session-start audit-pollution attack | ⏳ FORWARD-DEFERRED to Phase 04 | `docs/operations/phase-04-mobile-attestation-hardening.md` | TestFlight/Play release OR `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` ≥10/hr OR LSFin inquiry | REVIEWS.md §7.6 + §7.8 recommendation 4 |

**Note on coverage**: Phase 02 closes the link-side spoofing (iter-2 A6 — `/v1/audit/mobile-session-link` proof-of-session-start handshake) but does NOT close the session-start endpoint itself. Phase 04 ships rate-limit + Apple App Attestation + Android Play Integrity + `attestation_status` column. Existing Phase 02 audit rows will backfill to `'unattested_phase02'` (cleanly signaling the pre-hardening window) when Phase 04 migration runs. Per `feedback_ios_entitlements_block_testflight.md`, the iOS App Attestation entitlement PR ships in isolation from feature PRs.
```

#### Patch to Task 4 `<acceptance_criteria>` — add (iter-3 iA4)

- `wc -l docs/operations/phase-04-mobile-attestation-hardening.md` ≥ 30.
- `grep -c "REVIEWS.md §7.6\|REVIEWS.md §7.8\|attestation_status\|App Attestation\|Play Integrity" docs/operations/phase-04-mobile-attestation-hardening.md` ≥ 5.
- `python3 tools/checks/wiki_lint.py lint --file docs/operations/phase-04-mobile-attestation-hardening.md` exits 0 (counter-arguments + data gaps blocks present).
- `python3 tools/checks/accent_lint_fr.py docs/operations/phase-04-mobile-attestation-hardening.md` exits 0.
- `python3 tools/checks/banned_terms_python.py docs/operations/phase-04-mobile-attestation-hardening.md` exits 0.
- SUMMARY.md contains the « iter-3 Forward-deferred to Phase 04 » subsection (`grep -c "iter-3 Forward-deferred to Phase 04" .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-SUMMARY.md` ≥ 1).
- VERIFICATION-REPORT.html contains the session-start audit-pollution deferred-item entry (`grep -c "session-start audit-pollution\|phase-04-mobile-attestation-hardening" .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VERIFICATION-REPORT.html` ≥ 1).

### Effort spent vs scope budget

| Patch | Budget | Actual | Status |
|---|---|---|---|
| iA4 | 45 min | 35 min | APPLIED in iter_3_revision append (Plan 02-04 Task 4 extended with step 3.5 runbook spec + SUMMARY subsection + VERIFICATION deferred-item) |

iA1, iA2, iA3 land in Plan 02-02 (separate iter_3_revision block there).

### Iter-3 commit recommendation

Covered in Plan 02-02 iter_3_revision block — single commit covers iA1+iA2+iA3+iA4 across both plans.

</iter_3_revision>

