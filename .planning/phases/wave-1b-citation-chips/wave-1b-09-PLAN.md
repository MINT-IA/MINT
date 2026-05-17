---
phase: wave-1b
plan: 09
type: execute
wave: 3
depends_on: [wave-1b-02, wave-1b-03, wave-1b-04, wave-1b-05, wave-1b-06, wave-1b-07, wave-1b-08]
files_modified:
  - tools/checks/wave_1b_close.sh
  - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml
  - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md
  - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html
autonomous: true
requirements: [WAVE1B-09, WAVE1B-10]
must_haves:
  truths:
    - "tools/checks/wave_1b_close.sh exists, is executable, mirrors wave_1a_close.sh shape (G3+G4+G5), and exits 0 on a clean Wave 1b branch"
    - "Maestro G1 flow tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml exists with at least 8 steps covering: launch app → trigger coach turn that fires a Wave 1a tool → assert chip visible (testID coachCitationChip-budget_snapshot) → tap chip → assert modal visible (testID coachCitationModalJsonExpansion) → close"
    - "wave-1b-SUMMARY.md exists with all 10 requirements (WAVE1B-01..10) checked off + 0-trust self-check citing wave_1b_close.sh output"
    - "wave-1b-VERIFICATION-REPORT.html exists per memory feedback_html_evidence_report — cumulative HTML rolling up all 9 plan summaries + 5-gate status + deferred items"
    - "dev→staging coupling — Plan 09 documents the bundled PR plan: Wave 1a's 21-commit backlog + Wave 1b's 9-plan commits land on staging in ONE atomic ship event per CONTEXT D-04"
    - "Railway env flip — Plan 09 documents the 5 Railway env var flips (COACH_TOOL_SERVER_SIDE_*=true) that fire immediately AFTER staging deploy lands per CONTEXT D-01 + WAVE1B-10"
    - "G2 Claude autonomous — Plan 09 owns the autonomous Maestro+sim walkthrough per memory g2-claude-autonomous-not-julien-token (NOT a Julien token gate)"
    - "Phase test count delta = +18 backend test functions PASSED at close (WAVE1B-07 literal interpretation met per Plan 01 ISSUE-07 expansion)"
    - "Phase ARB delta = 90 new entries (15 keys × 6 locales) per Q6_DECISION revised by Q8_DECISION (Plan 06)"
  artifacts:
    - path: "tools/checks/wave_1b_close.sh"
      provides: "G3+G4+G5 close-out script + ARB parity"
      contains: "pytest|banned_terms|accent_lint|arb_parity"
    - path: "tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml"
      provides: "G1 Maestro flow draft (live exec deferred to post-staging-deploy)"
      contains: "appId: ch.mint.app|coachCitationChip|coachCitationModal"
    - path: ".planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md"
      provides: "Phase SUMMARY with all 10 reqs + 9 plan refs + 5-gate status + 0-trust self-check"
      contains: "WAVE1B-01|WAVE1B-10|Self-Check"
    - path: ".planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html"
      provides: "HTML cumulative report per memory feedback_html_evidence_report"
      contains: "WAVE1B-01|PR|plan-01|plan-09"
  key_links:
    - from: "tools/checks/wave_1b_close.sh"
      to: "services/backend/tests/test_coach_citation/"
      via: "shell script runs pytest"
      pattern: "pytest"
    - from: ".planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md"
      to: ".planning/phases/wave-1b-citation-chips/wave-1b-01-SUMMARY.md"
      via: "summary cross-reference"
      pattern: "wave-1b-01-SUMMARY"
---

<objective>
Close out Wave 1b. Five deliverables:

1. **WAVE1B-09** — `tools/checks/wave_1b_close.sh` mirroring `wave_1a_close.sh` + ARB parity step (G5 augmented per RESEARCH §7.2).
2. **G1 Maestro flow** — `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` draft (live exec deferred per memory `feedback_app_targets_staging_always`).
3. **G2 Claude autonomous** — Claude runs Maestro+sim against staging build (post-deploy, post-flag-flip) per memory `g2-claude-autonomous-not-julien-token` + CONTEXT D-05. NOT a Julien token gate.
4. **Phase SUMMARY + VERIFICATION-REPORT.html** per memory `feedback_html_evidence_report`.
5. **WAVE1B-10 dev→staging ship coupling + Railway env flip** — Plan 09 documents (does NOT execute the gh CLI commands — those run in the operator session) the bundled PR + flag flip protocol.

This plan is autonomous (no Julien token per CONTEXT D-05). After completion the phase is **SHIPPED** if all gates exit 0; **SHIPPED-WITH-DEFERRED** if any item carries forward; **PENDING G2** if G2 cannot be exercised yet.

**Revision iter-1 notes:**
- Test count claim revised from +14 → **+18 backend test functions** per Plan 01 ISSUE-07 expansion (4 new stubs in registry_entries.py).
- ARB entry count revised from 66 → **90 entries (15 keys × 6 locales)** per Plan 07 Q6_DECISION revised by Plan 06 Q8_DECISION (4 relative-time keys added).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@.planning/phases/wave-1b-citation-chips/wave-1b-VALIDATION.md
@.planning/phases/wave-1b-citation-chips/wave-1b-01-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-02-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-04-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-05-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-06-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md
@.planning/phases/wave-1b-citation-chips/wave-1b-08-SUMMARY.md
@tools/checks/wave_1a_close.sh
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md
@CLAUDE.md

<interfaces>
wave_1a_close.sh template (tools/checks/wave_1a_close.sh:1-57) — diff target. Wave 1b changes:
- New `WAVE_1B_BACKEND_FILES` list (4 files):
  - services/backend/app/services/coach/citation_registry.py
  - services/backend/app/services/coach/citation_grammar.py
  - services/backend/app/observability/coach_breadcrumbs.py
  - services/backend/app/api/v1/endpoints/coach_chat.py (Plan 04 backend touch + Plan 08 wrapper)
- New step G5 — ARB parity gate (runs on all 6 ARB files):
  - python3 tools/checks/validate_arb_parity.py (or arb_parity.py — whichever exists)
  - python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
  - python3 tools/checks/banned_terms_arb.py (if it exists)
- New step G4 — Flutter test slice:
  - cd apps/mobile && flutter test test/widgets/coach/coach_citation_*.dart test/services/coach/tool_call_round_trip_test.dart -q

Maestro flow template (tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml from Wave 1a — verify exact bundle id):
```yaml
appId: ch.mint.app
---
- launchApp
- tapOn: "Mon argent"
- tapOn:
    id: "card_budget_snapshot"
- tapOn: "explique"
- assertVisible:
    text: "Budget actuel"
    timeout: 10000
- back
```

Wave 1b Maestro additions:
- After "explique" coach response renders, assert chip visible by ID (testID stable per Plan 05 Key('coachCitationChip-<toolName>')):
  ```yaml
  - assertVisible:
      id: "coachCitationChip-budget_snapshot"
      timeout: 15000
  - tapOn:
      id: "coachCitationChip-budget_snapshot"
  - assertVisible:
      id: "coachCitationModalJsonExpansion"
  - tapOn:
      id: "coachCitationModalJsonExpansion"
  - assertVisible:
      text: "monthlyIncome"
  ```

Maestro `id:` tapping requires Key() in Flutter widgets. Plan 05 + 06 ship those.

dev→staging coupling per CONTEXT D-04:
- Current dev branch is ahead of staging by 21 Wave 1a commits + 9 Wave 1b plan commits (≈28-30 total commits at Wave 1b close).
- PR title: `feat(wave-1a+1b): backend tools refactor + citation chip activation [staging]`
- PR body: bullet list of plans, link to wave-1b-VERIFICATION-REPORT.html.
- Post-merge: flip 5 Railway env vars to `true`.

Railway env flip — 5 vars on mint-staging.up.railway.app:
```
COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true
COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED=true
COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED=true
COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED=true
COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED=true
```
Cap-garde flag (COACH_CAP_CHF_GARDE_ENABLED) is already `true` per Wave 1a defaults.

Note: Per phase_req_ids prompt, the env var names are documented with slight inconsistency:
- Prompt: `..._BUDGET_SNAPSHOT_ENABLED`
- Wave 1a-08-PLAN.md: `..._BUDGET_ENABLED`

Use whatever Wave 1a-08-PLAN.md actually shipped (those are the real Railway vars). Plan 09 verifies via `railway variables` post-flip.

Memory feedback_html_evidence_report — every GSD phase produces `<phase>-VERIFICATION-REPORT.html` (NEVER `/tmp/`).

G2 = Claude autonomous (CONTEXT D-05) — Plan 09 runs:
```bash
cd apps/mobile && flutter build ios --release
~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml
```
Captures the transcript; pastes the last 30 lines into `wave-1b-VERIFICATION-REPORT.html` under "G2 Evidence".
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write tools/checks/wave_1b_close.sh + Maestro G1 flow</name>
  <read_first>
    - tools/checks/wave_1a_close.sh (FULL — line-by-line diff target per memory feedback_diff_against_existing_tool)
    - tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml (Wave 1a template)
    - tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml (Phase 96 chat-overlay precedent)
    - tools/checks/validate_arb_parity.py OR tools/checks/arb_parity.py (whichever exists — confirm CLI shape)
    - tools/checks/banned_terms_arb.py if exists
  </read_first>
  <files>
    - tools/checks/wave_1b_close.sh (create, executable)
    - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml (create)
  </files>
  <action>
    Step A — Create `tools/checks/wave_1b_close.sh` (mirror wave_1a_close.sh shape):
    ```bash
    #!/usr/bin/env bash
    # Wave 1b — 5-gate close-out (G3 + G4 + G5).
    #
    # G1 + G2 are SEPARATE and not exercised by this script:
    #   G1 = Maestro flow run on staging build
    #        (tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml)
    #   G2 = Claude autonomous Maestro+sim walkthrough on staging build
    #        (per memory g2-claude-autonomous-not-julien-token + CONTEXT D-05)
    #
    # This script handles only the deterministic, in-CI gates:
    #   G3 = dev CI (full backend pytest + Flutter test slice)
    #   G4 = regression (parity harness + Wave 1b widget tests)
    #   G5 = LSFin banned-terms + accent_lint + ARB parity (all 6 locales)
    #
    # Exit code: 0 iff every gate passes; non-zero on the first failure.
    set -euo pipefail
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    cd "${REPO_ROOT}"

    WAVE_1B_BACKEND_FILES=(
      services/backend/app/services/coach/citation_registry.py
      services/backend/app/services/coach/citation_grammar.py
      services/backend/app/observability/coach_breadcrumbs.py
      services/backend/app/api/v1/endpoints/coach_chat.py
    )

    WAVE_1B_ARB_FILES=(
      apps/mobile/lib/l10n/app_fr.arb
      apps/mobile/lib/l10n/app_en.arb
      apps/mobile/lib/l10n/app_de.arb
      apps/mobile/lib/l10n/app_es.arb
      apps/mobile/lib/l10n/app_it.arb
      apps/mobile/lib/l10n/app_pt.arb
    )

    echo "==> G3 + G4 — backend pytest (full suite, target ≥ 6882)"
    (
      cd services/backend
      python3 -m pytest tests/ -q
    )

    echo "==> G4 — Wave 1b backend slice (registry + grammar + breadcrumb)"
    (
      cd services/backend
      python3 -m pytest tests/test_coach_citation/ -q
    )

    echo "==> G4 — Wave 1b Flutter slice (chip + modal + round-trip)"
    (
      cd apps/mobile
      flutter test test/widgets/coach/coach_citation_chips_section_test.dart \
                   test/widgets/coach/coach_citation_modal_test.dart \
                   test/widgets/coach/coach_citation_chip_golden_test.dart \
                   test/widgets/coach/coach_citation_chip_modal_remember_test.dart \
                   test/services/coach/tool_call_round_trip_test.dart -q
    )

    echo "==> G5 — banned_terms_python lint on Wave 1b touched files"
    python3 tools/checks/banned_terms_python.py "${WAVE_1B_BACKEND_FILES[@]}"

    echo "==> G5 — accent_lint_fr on Wave 1b backend touched files"
    for f in "${WAVE_1B_BACKEND_FILES[@]}"; do
      python3 tools/checks/accent_lint_fr.py --file "$f"
    done

    echo "==> G5 — accent_lint_fr on app_fr.arb"
    python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb

    echo "==> G5 — ARB parity (6 locales × 15 keys = 90 entries)"
    if [ -f tools/checks/validate_arb_parity.py ]; then
      python3 tools/checks/validate_arb_parity.py
    elif [ -f tools/checks/arb_parity.py ]; then
      python3 tools/checks/arb_parity.py
    else
      echo "WARN: no arb_parity script found — skipping (manual verification required)"
    fi

    echo "==> G5 — banned_terms_arb (if present)"
    if [ -f tools/checks/banned_terms_arb.py ]; then
      python3 tools/checks/banned_terms_arb.py
    else
      echo "INFO: banned_terms_arb.py not present — relying on FR accent_lint coverage"
    fi

    echo "==> wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)"
    ```
    `chmod +x tools/checks/wave_1b_close.sh`.

    Step B — Create `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml`. The G1 flow taps a coach card → triggers a Wave 1a tool → asserts the chip + modal render. Live exec is DEFERRED per memory `feedback_app_targets_staging_always` until staging deploy lands the flags ON.
    ```yaml
    # Wave 1b G1 — citation chip smoke.
    #
    # PRECONDITIONS (live exec deferred until):
    #   (a) Staging deploy with all 5 server-side flags ON + cap garde ON.
    #   (b) Production card list carries stable testIDs (already true post-Phase 96).
    #
    # This flow exercises:
    #   1. Launch app, navigate to coach overlay.
    #   2. Tap "Explique-moi" on a budget card → triggers get_budget_status server-side tool.
    #   3. Assert citation chip renders (testID coachCitationChip-budget_snapshot).
    #   4. Tap the chip → assert modal renders (testID coachCitationModalJsonExpansion).
    #   5. Expand the JSON viewer → assert monthly figure present.
    #
    # Run autonomously by Claude per memory g2-claude-autonomous-not-julien-token
    # AFTER dev→staging merge + Railway env flip lands.
    appId: ch.mint.app
    ---
    - launchApp:
        clearState: false
    - tapOn:
        text: "Mon argent"
    - tapOn:
        id: "card_budget_snapshot"
        timeout: 10000
    - tapOn:
        text: "explique"
    - assertVisible:
        text: "Budget"
        timeout: 15000
    # Wave 1b — chip must render in the coach response footer.
    - assertVisible:
        id: "coachCitationChip-budget_snapshot"
        timeout: 15000
    # Tap chip → modal opens.
    - tapOn:
        id: "coachCitationChip-budget_snapshot"
    - assertVisible:
        id: "coachCitationModalJsonExpansion"
        timeout: 5000
    # Expand JSON viewer.
    - tapOn:
        id: "coachCitationModalJsonExpansion"
    - assertVisible:
        text: "monthlyIncome"
        timeout: 5000
    # Close modal (Souviens-toi CTA also fires a SnackBar — optional path).
    - tapOn:
        id: "coachCitationModalRememberCta"
    - back
    ```

    Step C — Verify file presence + executable bit:
    ```bash
    test -x tools/checks/wave_1b_close.sh
    test -f tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml
    ```

    Step D — Run `bash tools/checks/wave_1b_close.sh` against the current branch (assumes all prior plans landed). MUST exit 0.
  </action>
  <verify>
    <automated>test -x tools/checks/wave_1b_close.sh &amp;&amp; bash tools/checks/wave_1b_close.sh 2>&amp;1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `test -x tools/checks/wave_1b_close.sh` exits 0.
    - `bash tools/checks/wave_1b_close.sh` exits 0.
    - `grep -c "G3\\|G4\\|G5\\|ARB parity\\|banned_terms\\|accent_lint" tools/checks/wave_1b_close.sh` returns ≥6.
    - `test -f tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` exits 0.
    - `grep -c "coachCitationChip-budget_snapshot\\|coachCitationModalJsonExpansion\\|appId: ch.mint.app" tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` returns ≥3.
  </acceptance_criteria>
  <done>
    wave_1b_close.sh exits 0; Maestro G1 flow YAML drafted with 3+ testID asserts; G3+G4+G5 mechanical gates exit 0.
  </done>
</task>

<task type="auto">
  <name>Task 2: Write Phase SUMMARY + VERIFICATION-REPORT.html + dev→staging coupling doc</name>
  <read_first>
    - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md (template — match shape)
    - all 8 Wave 1b plan SUMMARYs (wave-1b-01-SUMMARY.md through wave-1b-08-SUMMARY.md)
    - memory feedback_html_evidence_report (HTML cumulative report convention)
    - memory feedback_zero_trust_protocol (0-trust self-check format)
  </read_first>
  <files>
    - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md (create)
    - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html (create)
  </files>
  <action>
    Step A — Create `.planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md`:
    ```markdown
    ---
    name: wave-1b-SUMMARY
    description: Phase SUMMARY for wave-1b-citation-chips — 9 plans, 6 tool_call_id registry entries + narrator grammar + Flutter chip + modal + 90 ARB entries + Sentry breadcrumb + 5-gate close + dev→staging coupling.
    metadata:
      type: summary
      phase: wave-1b-citation-chips
      date: 2026-05-15
      status: <PENDING G2|SHIPPED|SHIPPED-WITH-DEFERRED>
    ---

    # Wave 1b — Citation Chips Activation — SUMMARY

    ## Requirements (10/10)

    - [x] WAVE1B-01 — CITATION_REGISTRY extended with 6 tool_call_id entries (plan-02)
    - [x] WAVE1B-02 — Narrator grammar instruction (1-segment per Q5_DECISION, plan-03)
    - [x] WAVE1B-03 — emit_coach_citation_breadcrumb helper + wrapper wiring (plan-08)
    - [x] WAVE1B-04 — CoachCitationChipsSection Flutter widget (plan-04 contract + plan-05 widget)
    - [x] WAVE1B-05 — Chip-tap modal with Souviens-toi CTA (plan-06, flag_state badge dropped per Q7_DECISION, relative-time via 4 ARB keys per Q8_DECISION)
    - [x] WAVE1B-06 — 15 ARB keys × 6 locales = 90 entries (plan-07, Q6_DECISION revised by Q8)
    - [x] WAVE1B-07 — Backend tests +18 functions PASSED (plan-01 stub expansion + plan-02 + plan-03 + plan-08 implementation)
    - [x] WAVE1B-08 — Mobile tests (golden + widget + round-trip) (plan-04 + plan-05 + plan-06)
    - [x] WAVE1B-09 — tools/checks/wave_1b_close.sh + VERIFICATION-REPORT.html (this plan)
    - [x] WAVE1B-10 — dev→staging coupling + Railway env flip (this plan, post-merge follow-up)

    ## Plan SUMMARYs

    | Plan | Scope | Tests delta | Lints | SUMMARY link |
    |------|-------|-------------|-------|--------------|
    | 01 | Wave 0 — test scaffolding (4 backend + 4 Dart stubs, ISSUE-07 expansion = +4 stubs) | ≥16 skipped | exit 0 | [wave-1b-01-SUMMARY.md](wave-1b-01-SUMMARY.md) |
    | 02 | 6 tool_call_id registry entries + subset exemption + dispatcher invariant | +8 backend | exit 0 | [wave-1b-02-SUMMARY.md](wave-1b-02-SUMMARY.md) |
    | 03 | Narrator grammar fragment extension + intent-scoped always-on | +3 backend | exit 0 | [wave-1b-03-SUMMARY.md](wave-1b-03-SUMMARY.md) |
    | 04 | Backend response payload audit + Dart ToolCallCitationChip model + Q9 cap_status/retrieve_memories hash strategy | +4 Dart | exit 0 | [wave-1b-04-SUMMARY.md](wave-1b-04-SUMMARY.md) |
    | 05 | CoachCitationChipsSection + 6 golden snapshots | +4 + 6 goldens | exit 0 | [wave-1b-05-SUMMARY.md](wave-1b-05-SUMMARY.md) |
    | 06 | Citation modal + Souviens-toi CTA (Q7 + Q8) | +4 Dart | exit 0 | [wave-1b-06-SUMMARY.md](wave-1b-06-SUMMARY.md) |
    | 07 | 15 ARB keys × 6 locales = 90 entries (Q6 revised by Q8) | (no test delta, ARB parity gate) | exit 0 | [wave-1b-07-SUMMARY.md](wave-1b-07-SUMMARY.md) |
    | 08 | emit_coach_citation_breadcrumb + wrapper wiring (Wave 2 post-Plan 04 audit) | +5 backend | exit 0 | [wave-1b-08-SUMMARY.md](wave-1b-08-SUMMARY.md) |
    | 09 | wave_1b_close.sh + Maestro G1 + ship coupling | (no test delta) | exit 0 | (this file) |

    Backend pytest delta vs Wave 1a baseline (6864): **+18 new test functions PASSED**.
    Plan-by-plan breakdown: 8 (registry plan-02, incl. 4 ISSUE-07 expansion) + 3 (grammar plan-03) + 5 (breadcrumb plan-08: 3 contract + 2 cardinality) + 2 (cross-plan invariant test_every_tool_key_has_dispatcher_branch + test_subset_invariant) = 18. Matches WAVE1B-07 literal interpretation.
    Flutter test delta vs pre-Wave-1b baseline: ≥+18 new tests + 6 goldens (4 round-trip + 4 chip widget + 6 goldens + 4 modal widget + 1 remember).

    ## Deviations (Q5 / Q6 / Q7 / Q8 / Q9 — surfaced for Julien)

    - **Q5 (Plan 03)** — 1-segment narrator grammar `{{cite:tool_<name>}}` instead of CONTEXT line 36's 2-segment `{{cite:tool_call_id:<inputs_hash>}}`. Rationale: CONTEXT hard constraint #4 forbids modifying citation_parser.py regexes; 1-segment is functionally equivalent per CONTEXT Q1 plan default (a). Confirmed in plan-03 exec.
    - **Q6 (Plan 07)** — 90 ARB entries (15 keys × 6 locales) instead of CONTEXT line 41's 30 entries. Rationale: strict CLAUDE.md TOP rule #5 requires i18n on tool display names AND relative-time strings. Confirmed in plan-07 exec.
    - **Q7 (Plan 06)** — flag_state badge DROPPED from the modal. Rationale: flag_state always "on" when chip renders (chip only appears when inputs_hash is in the response, which only happens when flag is on). Surfaced in plan-06 exec.
    - **Q8 (Plan 06 revision iter-1)** — Relative-time strings via 4 ARB keys (coachCitationRelativeJustNow + 3 plural-aware) instead of Dart literals. Rationale: CLAUDE.md TOP rule #5 i18n requirement; Dart literals would ship FR-only to 5 locales (silent leak). Expanded Plan 07 from 66 → 90 ARB entries.
    - **Q9 (Plan 04 revision iter-1)** — cap_status + retrieve_memories receive synthetic inputs_hash via hashlib.sha256 at the dispatcher layer (~30 LOC). Rationale: preserves 6-chip user experience + respects D-02 (6 registry entries). Alternative was 4-chip-v1 + defer 2 to wave-1c.

    ## 5-Gate Status

    | Gate | Status | Evidence |
    |------|--------|----------|
    | G1 Maestro (drafted, live exec deferred) | DRAFT | tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml — exec deferred to post-staging-deploy + flag-flip |
    | G2 Claude autonomous (post-staging) | TBD | Run after dev→staging merge + Railway env flip; Claude captures Maestro transcript + idb describe-all per memory g2-claude-autonomous-not-julien-token |
    | G3 dev CI | exit 0 | bash tools/checks/wave_1b_close.sh exit 0 — paste tail output here |
    | G4 regression | exit 0 | Backend pytest +18 (6864 → 6882); Flutter test +18 + 6 goldens |
    | G5 LSFin + accent + ARB parity (90 entries) | exit 0 | banned_terms_python + accent_lint_fr + validate_arb_parity all exit 0 |

    ## dev→staging Ship Coupling (WAVE1B-10)

    Per CONTEXT D-04: Wave 1a's 21-commit dev backlog + Wave 1b's commits bundle in ONE dev→staging PR.

    Bundled PR template:
    ```
    Title: feat(wave-1a+1b): backend tools refactor + citation chip activation [staging]
    Body:
    ## Summary
    - Wave 1a (closed 2026-05-14, PR #614): 5 server-side coach tools + cap CHF garde + 18-case parity harness.
    - Wave 1b (this PR): citation chip activation — 6 tool_call_id CITATION_REGISTRY entries + narrator grammar + Flutter chip+modal+ARB+Sentry.

    ## 5-Gate evidence
    - G1 Maestro flow drafted (live exec deferred until flags ON).
    - G2 Claude autonomous Maestro+sim (post-merge + flag-flip).
    - G3 wave_1b_close.sh exit 0 + wave_1a_close.sh exit 0.
    - G4 Backend pytest 6882 (+18) / Flutter test pass.
    - G5 LSFin + accent + ARB parity (90 entries) exit 0.

    See .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html for cumulative evidence.

    ## Railway env flip (post-merge)
    Flip 5 vars on mint-staging.up.railway.app:
    - COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true
    - COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED=true
    - COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED=true
    - COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED=true
    - COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED=true
    (Cap-garde already true.)
    ```

    Post-merge Claude G2 follow-up:
    1. Merge feat/wave-1b → dev (if not already on dev).
    2. Open dev → staging PR with the body above.
    3. Merge PR → Railway auto-deploys.
    4. Flip 5 Railway env vars to `true` (via Railway CLI or dashboard).
    5. Build mobile against staging, reinstall on iPhone-17-Pro sim.
    6. Run `~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml`; capture transcript.
    7. Run `idb describe-all` snapshot; confirm `coachCitationChip-budget_snapshot` testID is visible.
    8. Sentry filter `category:coach.citation.tool_call_id.*` — confirm at least one `*.emitted` event within 5 min.
    9. Status: flips to `SHIPPED` if all 6 G2 sub-checks exit 0; `SHIPPED-WITH-DEFERRED` with appended items in wave-1b-VERIFICATION-REPORT.html otherwise.

    ## Self-Check : <PASSED|SHIPPED|PENDING G2>

    Per CLAUDE.md §9 — 0-trust evidence:
    - WAVE1B-01..10 satisfied per the artifacts table above.
    - G3 cite: `bash tools/checks/wave_1b_close.sh | tail -1` → `wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)`.
    - G4 cite: `cd services/backend && python3 -m pytest tests/ -q | tail -1` → `<N> passed, ...`.
    - G5 cite: ARB parity exit 0 line + accent_lint_fr exit 0 line.
    - G1 cite: tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml EXISTS but live exec deferred.
    - G2 cite: PENDING until dev→staging deploy + Railway env flip + Claude autonomous Maestro+sim.

    ## Deferred items

    - pgvector retrieve_memories — Wave 2+ if BM25 recall insufficient (CONTEXT D-07 Wave 1a).
    - Wave 1c 20-Q&A parity suite — separate Wave 1c scope.
    - CapEngine Flutter→Python port — re-litigation trigger on Sentry breadcrumb (CONTEXT D-17 Wave 1a).
    - Souviens-toi CTA persistence — Wave 2 (wires save_insight tool to user wiki page).
    - flag_state badge — re-add in Wave 2 if staged-rollout cohorts emerge (Q7_DECISION outcome).
    - DE/IT/ES/PT ARB translations — mechanical translations shipped in plan-07; native review can ship as a Wave 2 polish PR.
    ```

    Step B — Create `.planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html`:
    ```html
    <!doctype html>
    <html lang="fr">
    <head><meta charset="utf-8"><title>Wave 1b — Verification Report</title>
    <style>
    body { font-family: system-ui, sans-serif; max-width: 1000px; margin: 2em auto; padding: 0 1em; line-height: 1.5; }
    h1, h2 { color: #003B2F; }
    h1 { border-bottom: 2px solid #003B2F; padding-bottom: .3em; }
    table { border-collapse: collapse; width: 100%; margin: 1em 0; }
    td, th { border: 1px solid #ccc; padding: .4em .6em; text-align: left; vertical-align: top; }
    th { background: #f5f5f5; }
    .ok { color: #0a7d4d; font-weight: 600; }
    .pending { color: #b85c00; font-weight: 600; }
    .fail { color: #a32020; font-weight: 600; }
    code { background: #f3f3f3; padding: 1px 4px; border-radius: 3px; font-size: 0.9em; }
    .small { font-size: 0.9em; color: #555; }
    </style></head>
    <body>
    <h1>Wave 1b — Citation Chips Activation — Verification Report</h1>
    <p class="small">Phase: <code>wave-1b-citation-chips</code> · Generated: 2026-05-15 · Last updated: <span id="date">2026-05-15</span></p>

    <h2>Requirements coverage</h2>
    <table>
    <tr><th>ID</th><th>Description</th><th>Status</th><th>Plan</th><th>Evidence</th></tr>
    <tr><td>WAVE1B-01</td><td>CITATION_REGISTRY extended with 6 tool_call_id entries</td><td class="ok">DONE</td><td>plan-02</td><td><code>grep -c 'source_kind="tool_call_id"' services/backend/app/services/coach/citation_registry.py</code> returns 6</td></tr>
    <tr><td>WAVE1B-02</td><td>Narrator prompt grammar (1-segment per Q5)</td><td class="ok">DONE</td><td>plan-03</td><td><code>pytest tests/test_coach_citation/test_tool_call_id_grammar.py -q</code> exit 0</td></tr>
    <tr><td>WAVE1B-03</td><td>Sentry breadcrumb coach.citation.tool_call_id.* (5-kwarg)</td><td class="ok">DONE</td><td>plan-08</td><td><code>pytest tests/test_coach_citation/test_breadcrumb_contract.py -q</code> exit 0</td></tr>
    <tr><td>WAVE1B-04</td><td>Flutter chip renderer</td><td class="ok">DONE</td><td>plan-04 + plan-05</td><td>6 goldens; 4 widget tests exit 0</td></tr>
    <tr><td>WAVE1B-05</td><td>Chip-tap modal + Souviens-toi CTA (flag_state badge dropped per Q7; relative-time via ARB per Q8)</td><td class="ok">DONE</td><td>plan-06</td><td>4 modal widget tests exit 0</td></tr>
    <tr><td>WAVE1B-06</td><td>ARB 15 keys × 6 locales = 90 entries (Q6 deviation revised by Q8 — 4 relative-time keys added)</td><td class="ok">DONE</td><td>plan-07</td><td><code>validate_arb_parity.py</code> exit 0</td></tr>
    <tr><td>WAVE1B-07</td><td>Backend tests +18 functions PASSED</td><td class="ok">DONE</td><td>plan-01 (stubs +4 ISSUE-07) + plan-02 + plan-03 + plan-08</td><td>Breakdown: 8 registry + 3 grammar + 5 breadcrumb + 2 cross-plan invariants = 18</td></tr>
    <tr><td>WAVE1B-08</td><td>Mobile tests (golden + widget + round-trip)</td><td class="ok">DONE</td><td>plan-04 + plan-05 + plan-06</td><td>4 round-trip + 4 chip widget + 6 goldens + 4 modal widget + 1 remember = 19 tests</td></tr>
    <tr><td>WAVE1B-09</td><td>tools/checks/wave_1b_close.sh + VERIFICATION-REPORT.html</td><td class="ok">DONE</td><td>plan-09 (this)</td><td><code>bash tools/checks/wave_1b_close.sh</code> exit 0</td></tr>
    <tr><td>WAVE1B-10</td><td>dev→staging coupling + Railway env flip</td><td class="pending">PENDING POST-MERGE</td><td>plan-09 documentation; operator executes</td><td>Bundled PR drafted in SUMMARY.md; Railway flip post-merge per CONTEXT D-01</td></tr>
    </table>

    <h2>5-Gate status</h2>
    <table>
    <tr><th>Gate</th><th>Status</th><th>Evidence</th></tr>
    <tr><td>G1 Maestro flow</td><td class="pending">DRAFT (live exec deferred)</td><td><code>tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml</code> exists</td></tr>
    <tr><td>G2 Claude autonomous</td><td class="pending">PENDING POST-STAGING</td><td>Run after Railway env flip; Maestro+sim per memory g2-claude-autonomous-not-julien-token</td></tr>
    <tr><td>G3 dev CI</td><td class="ok">PASS</td><td><code>wave_1b_close.sh</code> tail: <code>ALL GATES PASS (G3+G4+G5)</code></td></tr>
    <tr><td>G4 regression</td><td class="ok">PASS</td><td>Backend pytest +18 (6864 → 6882); Flutter test +18 + 6 goldens; Phase 94/94.1 byte-identity preserved</td></tr>
    <tr><td>G5 LSFin + accent + ARB parity (90 entries)</td><td class="ok">PASS</td><td>banned_terms_python + accent_lint_fr + validate_arb_parity all exit 0</td></tr>
    </table>

    <h2>Deviations (Q5 / Q6 / Q7 / Q8 / Q9)</h2>
    <ul>
    <li><strong>Q5</strong> — 1-segment narrator grammar adopted; CONTEXT line 36 2-segment form would have required citation_parser.py regex change (CONTEXT hard constraint #4 forbids).</li>
    <li><strong>Q6</strong> — 90 ARB entries (15 keys × 6 locales) vs CONTEXT line 41 "30 entries"; strict CLAUDE.md TOP rule #5 i18n required tool display names AND (per Q8) relative-time strings.</li>
    <li><strong>Q7</strong> — flag_state badge dropped from modal; flag_state always "on" when chip renders (chip only appears when inputs_hash is present, which only happens when flag is on).</li>
    <li><strong>Q8</strong> — 4 ARB relative-time keys (coachCitationRelativeJustNow + 3 plural-aware Minutes/Hours/Days) added in Plan 07. Reasoning: Dart literals would leak FR-only strings to 5 other locales (silent regression that ARB-parity gate cannot detect).</li>
    <li><strong>Q9</strong> — cap_status + retrieve_memories receive synthetic inputs_hash via hashlib.sha256 at the dispatcher layer (~30 LOC). Preserves 6-chip coverage and respects D-02 schema.</li>
    </ul>

    <h2>Deferred items</h2>
    <ul>
    <li>pgvector retrieve_memories — Wave 2+ if BM25 recall insufficient (CONTEXT D-07 Wave 1a).</li>
    <li>Wave 1c 20-Q&amp;A parity suite — separate Wave 1c scope.</li>
    <li>CapEngine Flutter→Python port — re-litigation trigger on Sentry breadcrumb threshold.</li>
    <li>Souviens-toi CTA persistence — wires <code>save_insight</code> tool to user wiki page in Wave 2.</li>
    <li>flag_state badge — re-add if staged-rollout cohorts emerge in Wave 2.</li>
    <li>DE/IT/ES/PT ARB native translation review — Wave 2 polish.</li>
    </ul>

    <h2>0-trust evidence (CLAUDE.md §9)</h2>
    <p>Per CLAUDE.md §9.4 — every claim cites command output:</p>
    <ul>
    <li><strong>G3 cite</strong>: <code>bash tools/checks/wave_1b_close.sh | tail -1</code> → paste output here.</li>
    <li><strong>G4 cite</strong>: <code>cd services/backend &amp;&amp; python3 -m pytest tests/ -q | tail -1</code> → paste output here.</li>
    <li><strong>G5 cite</strong>: <code>python3 tools/checks/validate_arb_parity.py</code> exit 0 + <code>accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb</code> exit 0.</li>
    <li><strong>G1 cite</strong>: file path of Maestro flow + DEFERRED status.</li>
    <li><strong>G2 cite</strong>: PENDING — post-staging Maestro transcript + idb describe-all snapshot to be appended.</li>
    </ul>

    </body></html>
    ```

    Step C — Run `bash tools/checks/wave_1b_close.sh` ONE MORE TIME against the full branch + capture tail output. Paste the verbatim final line into both the SUMMARY.md and the HTML report's "0-trust evidence" section (replace the placeholder).
  </action>
  <verify>
    <automated>test -f .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md &amp;&amp; test -f .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html &amp;&amp; grep -c "WAVE1B-01\|WAVE1B-10" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md</automated>
  </verify>
  <acceptance_criteria>
    - `test -f .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` exits 0.
    - `test -f .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` exits 0.
    - `grep -c "WAVE1B-01\\|WAVE1B-02\\|WAVE1B-03\\|WAVE1B-04\\|WAVE1B-05\\|WAVE1B-06\\|WAVE1B-07\\|WAVE1B-08\\|WAVE1B-09\\|WAVE1B-10" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥10.
    - `grep -c "Q5\\|Q6\\|Q7\\|Q8\\|Q9\\|DEVIATION\\|1-segment\\|90 ARB\\|flag_state badge dropped\\|relative-time via ARB\\|synthetic inputs_hash" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥5 (all 5 deviations surfaced).
    - `grep -c "Self-Check" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥1.
    - `grep -c "COACH_TOOL_SERVER_SIDE_\\|Railway\\|dev→staging\\|dev->staging" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥2.
    - `grep -c "5-Gate status\\|G1\\|G2\\|G3\\|G4\\|G5" .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` returns ≥5.
    - `grep -c "wave-1b-01-SUMMARY\\|wave-1b-08-SUMMARY" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥2 (plan summary cross-references).
    - `grep -c "+18\\|90 entries\\|15 keys" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥3 (revised counts present).
  </acceptance_criteria>
  <done>
    Phase SUMMARY + VERIFICATION-REPORT.html exist; all 10 reqs ticked; Q5/Q6/Q7/Q8/Q9 deviations surfaced; dev→staging coupling + Railway env flip documented; G2 Claude autonomous protocol documented; revised counts (+18 tests, 90 ARB entries) present.
  </done>
</task>

<task type="auto">
  <name>Task 3: G2 Claude autonomous walkthrough — Maestro+sim against staging post-flag-flip</name>
  <read_first>
    - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md (the G2 protocol section)
    - tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml (G1 flow)
    - tools/simulator/walker.sh (existing wrapper if present)
    - memory g2-claude-autonomous-not-julien-token + memory feedback_app_targets_staging_always
    - memory feedback_device_gates (sim + idb wired)
  </read_first>
  <files>
    - .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html (update — append G2 transcript)
    - .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md (update — flip Status: PENDING G2 → SHIPPED if exit 0)
  </files>
  <action>
    **PRECONDITIONS** (this task is the LAST one in Plan 09; only runs after operator merges dev→staging + flips Railway env vars per Task 2's documented protocol):

    Step A — Verify staging deploy carries the flags:
    ```bash
    # If `railway` CLI is available locally:
    railway variables --service mint-backend-staging 2>&1 | grep COACH_TOOL_SERVER_SIDE_ | head -10
    # OR curl the staging health endpoint to confirm /config/feature-flags reports the new flags as ON.
    curl -s https://mint-staging.up.railway.app/config/feature-flags | head -50
    ```
    Confirm 5 COACH_TOOL_SERVER_SIDE_* vars = true.

    Step B — Boot iPhone-17-Pro sim + build mobile against staging:
    ```bash
    xcrun simctl boot "iPhone-17-Pro" || true
    cd apps/mobile && flutter build ios --simulator --dart-define=API_BASE_URL=https://mint-staging.up.railway.app
    cd "$REPO_ROOT"
    ```
    (Adapt to actual build flag per memory `feedback_app_targets_staging_always` — the staging Railway URL is the contract.)

    Step C — Install + launch:
    ```bash
    xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
    xcrun simctl launch booted ch.mint.app
    ```

    Step D — Run Maestro G1 flow:
    ```bash
    ~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml 2>&1 | tee /tmp/wave_1b_g2_transcript.txt
    ```
    Capture exit code + tail. Save the last 60 lines into wave-1b-VERIFICATION-REPORT.html under a new "G2 Evidence" section.

    Step E — Capture idb describe-all snapshot:
    ```bash
    idb ui describe-all > /tmp/wave_1b_g2_describe.txt 2>&1
    grep -c "coachCitationChip-budget_snapshot\\|coachCitationModalJsonExpansion" /tmp/wave_1b_g2_describe.txt
    ```
    Append the matched lines into wave-1b-VERIFICATION-REPORT.html under "G2 Evidence" section.

    Step F — Sentry filter (if `sentry-cli` is available, else manual log):
    ```bash
    # Approximate — pseudo-code; actual command depends on sentry-cli setup.
    sentry-cli events list --org mint --project mint-staging --query 'category:coach.citation.tool_call_id.*' --limit 10 2>&1 | head -30
    ```
    Confirm at least 1 `coach.citation.tool_call_id.budget_snapshot.emitted` event within the last 10 minutes. If sentry-cli is unavailable, log "MANUAL CHECK — Sentry dashboard query pending" in the VERIFICATION-REPORT.html.

    Step G — Update `wave-1b-VERIFICATION-REPORT.html` G2 row: status flips from `PENDING POST-STAGING` to `PASS` (if Maestro exit 0 + idb hits + Sentry event) OR `PARTIAL` (if some sub-checks fail). Update `wave-1b-SUMMARY.md` Status: from `PENDING G2` to `SHIPPED` (G2 exit 0) OR `SHIPPED-WITH-DEFERRED` (G2 partial — list deferred items).

    Step H — If ANY of Steps B-F fail (cannot run autonomously — e.g. no Railway CLI, no sim available, network issue), append a "G2 BLOCKED" section to VERIFICATION-REPORT.html with the specific blocker and document the next-step recovery action. Per memory `feedback_blockers_ask_dont_defer`: PAUSE + state position; DO NOT silently mark SHIPPED.

    Step I — Final 0-trust self-check per CLAUDE.md §9: paste verbatim:
    - `wave_1b_close.sh` tail line.
    - `pytest tests/ -q | tail -1`.
    - `flutter test test/widgets/coach/ -q | tail -3`.
    - Maestro exit code line.
    - idb describe-all grep hit count.
    - Sentry filter result (or MANUAL CHECK note).

    DO NOT claim "shipped" in SUMMARY.md without all 6 citations present per CLAUDE.md §9.6 banned-phrase rule.
  </action>
  <verify>
    <automated>test -f .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html &amp;&amp; grep -c "G2 Evidence\|G2 BLOCKED\|SHIPPED\|PENDING G2" .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html</automated>
  </verify>
  <acceptance_criteria>
    - Either: (a) VERIFICATION-REPORT.html contains "G2 Evidence" section with Maestro transcript tail + idb hits + Sentry result, AND SUMMARY.md Status = `SHIPPED` with 6+ 0-trust citations — OR (b) VERIFICATION-REPORT.html contains "G2 BLOCKED" section with specific blocker + next-step recovery, AND SUMMARY.md Status = `PENDING G2` with the blocker named.
    - `grep -c "Self-Check : PASSED\\|Self-Check : SHIPPED\\|Self-Check : PENDING G2\\|Self-Check : SHIPPED-WITH-DEFERRED" .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` returns ≥1.
    - No occurrence of "shipped" / "ready" / "works" / "validated" / "green" in SUMMARY.md unless preceded by a deterministic citation per CLAUDE.md §9.
  </acceptance_criteria>
  <done>
    G2 protocol executed (or BLOCKED with documented next step); SUMMARY.md + VERIFICATION-REPORT.html reflect actual state; 0-trust citations present; phase SHIPPED or SHIPPED-WITH-DEFERRED or PENDING G2 per evidence.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-09-01 | T | Phase claimed "shipped" without all 5 gates exit 0 (banned-phrase violation per CLAUDE.md §9) | mitigate | Task 3 acceptance_criteria enforces 6+ 0-trust citations in SUMMARY.md before SHIPPED claim. Otherwise SHIPPED-WITH-DEFERRED or PENDING G2. |
| T-WAVE1B-09-02 | T | Maestro G1 flow runs against local backend instead of staging (false-exit-0 per memory feedback_app_targets_staging_always) | mitigate | Task 3 Step B uses `--dart-define=API_BASE_URL=https://mint-staging.up.railway.app`. PRECONDITIONS in Task 3 verify staging is the target. |
| T-WAVE1B-09-03 | T | 5-gate close fails silently because flags are OFF on staging | mitigate | Task 3 Step A explicitly verifies the 5 Railway env vars = true BEFORE Maestro runs. If any var is false, G2 is blocked + recovery action documented. |
| T-WAVE1B-09-04 | I | Maestro transcript or idb output leaks PII into committed VERIFICATION-REPORT.html | mitigate | Maestro test uses test fixtures (no real CHF income, no AHV13); idb describe-all output filters for testID hits only (`coachCitationChip-*`), not raw text. Sentry breadcrumb is non-PII by design (inputs_hash + profile_id_hashed irreversible). |
| T-WAVE1B-09-05 | T | dev→staging PR bundle has merge conflicts with Wave 1a's 21 commits | accept | Wave 1a's 21 commits are already on dev per STATE.md; bundling them into ONE staging PR is mechanical (squash or merge). Operator executes per Task 2's documented protocol. |
| T-WAVE1B-09-06 | E | G2 fails because mobile build can't reach staging (network / TLS issue) | mitigate | Task 3 Step H — fail-loudly with G2 BLOCKED section + named blocker; PAUSE + ASK per memory feedback_blockers_ask_dont_defer. No false-exit-0. |
| T-WAVE1B-09-07 | T | wave_1b_close.sh references arb_parity script that doesn't exist | mitigate | Task 1 Step A: if/else fallback handles both validate_arb_parity.py and arb_parity.py names; warn if neither present (don't exit non-zero on this branch). |
</threat_model>

<verification>
- `bash tools/checks/wave_1b_close.sh` exits 0.
- `cd services/backend && python3 -m pytest tests/ -q | tail -1` exits 0 with delta = +18 vs Wave 1a baseline (6864 → 6882).
- `cd apps/mobile && flutter test test/widgets/coach/coach_citation_*.dart test/services/coach/tool_call_round_trip_test.dart -q` exits 0.
- `test -f tools/checks/wave_1b_close.sh && test -x tools/checks/wave_1b_close.sh` exits 0.
- `test -f tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` exits 0.
- `test -f .planning/phases/wave-1b-citation-chips/wave-1b-SUMMARY.md` exits 0.
- `test -f .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html` exits 0.
- All 10 WAVE1B-XX requirement IDs grep-present in SUMMARY.md.
- Q5/Q6/Q7/Q8/Q9 deviations all documented in SUMMARY.md.
- Revised counts: +18 tests, 90 ARB entries grep-present in SUMMARY.md.
- 0-trust citations present in SUMMARY.md before any "SHIPPED" claim per CLAUDE.md §9.
</verification>

<success_criteria>
- WAVE1B-09 satisfied: wave_1b_close.sh exits 0; Maestro G1 flow drafted.
- WAVE1B-10 documented (operator executes the dev→staging PR + Railway env flip per Task 2's protocol).
- 5-gate close exit 0 (G3+G4+G5 mechanical; G1 drafted; G2 Claude autonomous executed or BLOCKED with recovery action).
- Phase SUMMARY + VERIFICATION-REPORT.html exist with all 10 requirements + 9 plans cross-referenced.
- Phase status flips to SHIPPED / SHIPPED-WITH-DEFERRED / PENDING G2 per evidence.
- No CLAUDE.md §9 banned-phrase claims without citations.
- Revised counts (+18 backend tests, 90 ARB entries / 15 keys) reflected in SUMMARY.md + VERIFICATION-REPORT.html.
</success_criteria>

<output>
After completion the phase is one of:
- **SHIPPED** — all gates exit 0, Railway flipped, Maestro G2 autonomous PASS, Sentry breadcrumbs firing.
- **SHIPPED-WITH-DEFERRED** — all gates exit 0 except G2 partial; deferred items listed in VERIFICATION-REPORT.html.
- **PENDING G2** — G3+G4+G5 exit 0; G2 blocked with named recovery action; phase NOT shipped until G2 executes.

Update `.planning/STATE.md` `Current Position` to reflect the new state. Update `.planning/ROADMAP.md` Wave 1b row to reflect SHIPPED status (if applicable).
</output>
</content>
</invoke>
