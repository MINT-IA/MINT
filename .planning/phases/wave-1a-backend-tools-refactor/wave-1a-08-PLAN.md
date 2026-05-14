---
phase: wave-1a
plan: 08
type: execute
wave: 3
depends_on: [wave-1a-07]
files_modified:
  - services/backend/tests/test_coach_tools/test_regulatory_constant_dispatcher.py
  - services/backend/tests/test_coach_tools/test_dispatcher_flags.py
  - tools/checks/wave_1a_close.sh
  - tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml
  - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md
  - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html
autonomous: false
requirements: [WAVE1A-07, WAVE1A-10]
must_haves:
  truths:
    - "get_regulatory_constant dispatcher routes to RegulatoryRegistry.get(key, jurisdiction) — confirmed by ≥5 dispatcher tests covering valid key / missing key / canton override / fallback to CH / suggestions list"
    - "All 5 server-side per-tool flags + the cap-garde flag exist in settings.py with correct defaults (per-tool=False, cap-garde=True)"
    - "Dispatcher routing test covers each tool with flag ON and flag OFF — 12 cases (6 tools × 2 states), zero regressions in legacy path"
    - "5-gate close-out script tools/checks/wave_1a_close.sh exits 0 when all gates green: G3 dev CI (pytest + lints) + G4 regression (pytest count ≥ baseline + 50) + G5 LSFin+accent"
    - "Maestro G1 flow coach_tools_server_side_smoke.yaml drafted (DEFERRED execution per memory feedback_app_targets_staging_always — runs against staging build with flags ON, post-merge)"
    - "Phase SUMMARY.md lists every requirement (WAVE1A-01..10) with checkboxes + every plan summary referenced + 0-trust self-check pasted from each plan SUMMARY"
    - "VERIFICATION-REPORT.html cumulative report exists at .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html (per memory feedback_html_evidence_report)"
  artifacts:
    - path: "services/backend/tests/test_coach_tools/test_regulatory_constant_dispatcher.py"
      provides: "≥5 tests confirming get_regulatory_constant routes to RegulatoryRegistry"
      contains: "def test_"
    - path: "services/backend/tests/test_coach_tools/test_dispatcher_flags.py"
      provides: "12 dispatcher routing tests (6 tools × flag ON/OFF)"
      contains: "def test_"
    - path: "tools/checks/wave_1a_close.sh"
      provides: "G3+G4+G5 close-out script"
      contains: "pytest\\|banned_terms\\|accent_lint"
    - path: "tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml"
      provides: "Maestro G1 flow contract (DEFERRED live run — drafted only)"
      contains: "appId\\|tapOn"
    - path: ".planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md"
      provides: "Phase summary with all 10 requirements ticked + 8 plan summaries cross-referenced + Self-Check section"
      contains: "WAVE1A-01\\|WAVE1A-10\\|Self-Check"
    - path: ".planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html"
      provides: "HTML cumulative report per memory feedback_html_evidence_report"
      contains: "PR\\|plan-01\\|plan-08"
  key_links:
    - from: "tools/checks/wave_1a_close.sh"
      to: "services/backend/tests/test_coach_tools_parity.py"
      via: "shell script runs pytest"
      pattern: "pytest"
    - from: ".planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md"
      to: ".planning/phases/wave-1a-backend-tools-refactor/wave-1a-01-SUMMARY.md"
      via: "summary cross-reference"
      pattern: "wave-1a-01-SUMMARY"
---

<objective>
Close out Wave 1a. Three deliverables:

1. **WAVE1A-07** — Confirm `get_regulatory_constant` dispatcher works (already wired on `RegulatoryRegistry` per audit §1 line 39 — Wave 1a only ADDS confirmation tests, no refactor).
2. **WAVE1A-10** — Verify all 5 per-tool flags + cap-garde flag exist with correct defaults; add 12 dispatcher routing tests (6 tools × flag ON/OFF).
3. **5-gate close** — G1 Maestro flow drafted, G2 Julien device walkthrough (checkpoint), G3 dev CI script, G4 regression test (pytest ≥6617), G5 LSFin+accent lints.

Per CONTEXT D-14 + memory `feedback_perimeter_5_gates`: no « ready » claim before all 5 gates green. Per memory `feedback_html_evidence_report`: every GSD phase produces `wave-1a-VERIFICATION-REPORT.html`.

This is the ONLY non-autonomous plan in Wave 1a — final task is a `checkpoint:human-verify` for Julien G2 (device walkthrough on staging build).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VALIDATION.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-00-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-01-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-02-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-03-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-04-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-05-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-06-SUMMARY.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-07-SUMMARY.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/regulatory/registry.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Existing get_regulatory_constant handler (READ-ONLY — confirm contract, do not refactor):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2418-2471:
`_handle_regulatory_constant(tool_input)` calls `RegulatoryRegistry.instance().get(key, jurisdiction)` and formats output.

Existing RegulatoryRegistry:
File services/backend/app/services/regulatory/registry.py — already canonical source for Swiss regulatory constants (pillar3a, lpp, avs, mortgage, tax keys).

Dispatcher call:
```python
if name == "get_regulatory_constant":
    return _handle_regulatory_constant(tool_input)
```

Wave 1a's 6 flags to assert exist:
1. `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED` (default False) — plan-01.
2. `COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED` (default False) — plan-02.
3. `COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED` (default False) — plan-03.
4. `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED` (default False) — plan-04.
5. `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED` (default False) — plan-05.
6. `COACH_CAP_CHF_GARDE_ENABLED` (default True) — plan-06.

Maestro flow template (existing pattern at tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml):
```yaml
appId: ch.mint.app
---
- launchApp
- tapOn: "Mon coach"
- tapOn: "explique"
- assertVisible: "Voyons ensemble"
# ... etc.
```

Memory `feedback_app_targets_staging_always`: mobile/sim/walker MUST hit Railway staging — never local backend for E2E.

Memory `feedback_html_evidence_report`: every GSD phase produces `wave-1a-VERIFICATION-REPORT.html`. NEVER `/tmp/` paths.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: get_regulatory_constant validation tests + dispatcher routing tests (WAVE1A-07 + WAVE1A-10)</name>
  <read_first>
    - services/backend/app/services/regulatory/registry.py (FULL — confirm RegulatoryRegistry.get + keys + canton behavior)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2418-2471 (legacy _handle_regulatory_constant)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1900-1930 (full dispatcher entry — all 6 tools' branches as modified by plans 01-06)
    - services/backend/app/core/config.py (verify all 6 flags exist with correct defaults from plans 01-06)
  </read_first>
  <files>
    - services/backend/tests/test_coach_tools/test_regulatory_constant_dispatcher.py (create)
    - services/backend/tests/test_coach_tools/test_dispatcher_flags.py (create)
  </files>
  <behavior>
    test_regulatory_constant_dispatcher.py (5 tests, WAVE1A-07):
    - Test 1: tool_input `{"key": "pillar3a.max_with_lpp"}` → returns string containing the registry value + source + effective_from line.
    - Test 2: tool_input `{"key": "unknown.key"}` → returns string starting with `"Constante 'unknown.key' non trouvée."`.
    - Test 3: tool_input `{"key": "capital_tax.cantonal", "canton": "VD"}` → returns the VD-specific value (canton override path).
    - Test 4: tool_input `{}` (no key) → returns `"Erreur : clé manquante. Fournis un key comme 'pillar3a.max_with_lpp'."`.
    - Test 5: tool_input `{"key": "pillar3a.unknown"}` → returns string containing `Suggestions :` followed by ≥1 candidate (the namespace-prefix match logic).

    test_dispatcher_flags.py (12 tests, WAVE1A-10):
    - 6 tests asserting flag-OFF path = legacy (call the dispatcher with each `name` ∈ {get_budget_status, get_retirement_projection, get_cross_pillar_analysis, get_couple_optimization, retrieve_memories, get_cap_status} with respective flag=False, assert output matches `_format_*(ctx)` byte-identical OR for cap_status `_format_cap_status(ctx)` unchanged).
    - 6 tests asserting flag-ON path produces server-side output (JSON shape for the 5 server-side tools; garded text for cap_status). For each, assert the dispatcher result type / key presence matching the Pydantic response model.
    - Plus a single test `test_all_six_flags_exist_with_correct_defaults` that asserts `settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED == False`, ..., `settings.COACH_CAP_CHF_GARDE_ENABLED == True`.
  </behavior>
  <action>
    Step A — Create `services/backend/tests/test_coach_tools/test_regulatory_constant_dispatcher.py` with Tests 1-5. Use `RegulatoryRegistry.instance()` setup or mock keys as needed.

    Step B — Create `services/backend/tests/test_coach_tools/test_dispatcher_flags.py` with 12 + 1 = 13 tests. Pattern:
    ```python
    import json
    import pytest
    from app.api.v1.endpoints.coach_chat import (
        _format_budget_status, _compute_budget_status,
        _format_retirement_projection, _compute_retirement_projection,
        # ...
    )
    from app.core.config import settings


    def test_budget_status_flag_off_routes_to_legacy(monkeypatch, db_session):
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", False)
        ctx = {"monthly_income": 7500, "monthly_expenses": 5200, "months_liquidity": 4.6}
        result = _compute_budget_status(profile_id="x", ctx=ctx, db=db_session)
        assert result == _format_budget_status(ctx)


    def test_budget_status_flag_on_routes_to_server_side(monkeypatch, db_session):
        monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED", True)
        # setup ProfileModel...
        # result is JSON
        result = _compute_budget_status(profile_id="...", ctx={...}, db=db_session)
        data = json.loads(result)
        assert "monthlyIncome" in data and "inputsHash" in data


    # ... mirror for the other 5 tools


    def test_all_six_flags_exist_with_correct_defaults():
        assert settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED is False
        assert settings.COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED is False
        assert settings.COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED is False
        assert settings.COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED is False
        assert settings.COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED is False
        assert settings.COACH_CAP_CHF_GARDE_ENABLED is True
    ```
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools/test_regulatory_constant_dispatcher.py tests/test_coach_tools/test_dispatcher_flags.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `pytest tests/test_coach_tools/test_regulatory_constant_dispatcher.py -q` exits 0 with ≥5 tests.
    - `pytest tests/test_coach_tools/test_dispatcher_flags.py -q` exits 0 with ≥13 tests.
    - `grep -c "COACH_TOOL_SERVER_SIDE_\|COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/core/config.py` returns ≥6.
    - `grep -c "settings.COACH_TOOL_SERVER_SIDE_\|settings.COACH_CAP_CHF_GARDE_ENABLED" services/backend/tests/test_coach_tools/test_dispatcher_flags.py` returns ≥6.
  </acceptance_criteria>
  <done>
    18 new tests (5 regulatory + 13 dispatcher); WAVE1A-07 confirmed; WAVE1A-10 confirmed.
  </done>
</task>

<task type="auto">
  <name>Task 2: 5-gate close-out script + Maestro flow draft + Phase SUMMARY + VERIFICATION-REPORT.html</name>
  <read_first>
    - tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml (existing Maestro pattern)
    - tools/checks/banned_terms_python.py (CLI usage)
    - tools/checks/accent_lint_fr.py (CLI usage)
    - All 7 prior plan SUMMARYs (wave-1a-01..07-SUMMARY.md) — cross-reference data for the phase SUMMARY
    - memory feedback_html_evidence_report (HTML cumulative report convention)
  </read_first>
  <files>
    - tools/checks/wave_1a_close.sh (create)
    - tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml (create — draft, deferred run)
    - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md (create)
    - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html (create)
  </files>
  <action>
    Step A — Create `tools/checks/wave_1a_close.sh` (executable, bash):
    ```bash
    #!/usr/bin/env bash
    # Wave 1a 5-gate close — G3 (CI) + G4 (regression) + G5 (lints).
    # G1 + G2 are separate (Maestro flow + Julien device walkthrough).
    set -euo pipefail
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    cd "${REPO_ROOT}"

    echo "==> G3+G4 — backend pytest"
    cd services/backend
    python3 -m pytest tests/ -q
    cd "${REPO_ROOT}"

    echo "==> G5 — LSFin banned-terms lint on Wave 1a touched files"
    python3 tools/checks/banned_terms_python.py \
      services/backend/app/services/coaching_engine.py \
      services/backend/app/services/retirement/retirement_projection_service.py \
      services/backend/app/services/arbitrage/cross_pillar_service.py \
      services/backend/app/services/couple_optimizer/couple_optimizer.py \
      services/backend/app/services/memory/bm25.py \
      services/backend/app/api/v1/endpoints/coach_chat.py \
      services/backend/app/models/coach_tools/*.py

    echo "==> G5 — accent_lint_fr on Wave 1a touched files"
    python3 tools/checks/accent_lint_fr.py \
      services/backend/app/services/coaching_engine.py \
      services/backend/app/services/retirement/retirement_projection_service.py \
      services/backend/app/services/arbitrage/cross_pillar_service.py \
      services/backend/app/services/couple_optimizer/couple_optimizer.py \
      services/backend/app/services/memory/bm25.py \
      services/backend/app/api/v1/endpoints/coach_chat.py \
      services/backend/app/models/coach_tools/*.py

    echo "==> G4 — parity harness alone (sub-set, fast)"
    cd services/backend
    python3 -m pytest tests/test_coach_tools_parity.py -q
    cd "${REPO_ROOT}"

    echo "==> wave_1a_close.sh: ALL GATES GREEN (G3+G4+G5)"
    ```
    `chmod +x tools/checks/wave_1a_close.sh`.

    Step B — Create `tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml` (draft per memory `feedback_app_targets_staging_always` — live exit-0 DEFERRED to staging deploy):

    ```yaml
    # Wave 1a G1 — server-side coach tools smoke.
    #
    # PRECONDITIONS (DEFERRED — see Task 3 checkpoint):
    #   (a) Staging deploy with all 5 server-side flags ON + cap garde ON.
    #   (b) Production card list carries stable testIDs.
    #   (c) Anthropic key on Railway staging (per memory anthropic_key_on_railway).
    #
    # This flow taps a coach card invoking each refactored tool, captures
    # the response, and asserts the visible inputs_hash chip appears
    # (Wave 1b will surface this UI-side; Wave 1a-only smoke = response
    # returned, no crash).
    appId: ch.mint.app
    ---
    - launchApp
    - tapOn:
        text: "Mon argent"
    - tapOn:
        id: "card_budget_snapshot"
    - tapOn:
        text: "explique"
    - assertVisible:
        text: "Budget actuel"
        timeout: 10000
    - back
    - tapOn:
        id: "card_lpp_projection"
    - tapOn:
        text: "explique"
    - assertVisible:
        text: "Projection retraite"
        timeout: 10000
    - back
    # ... mirror for cross_pillar, couple, cap_status cards
    ```

    Step C — Create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md`:

    ```markdown
    ---
    name: wave-1a-SUMMARY
    description: Phase SUMMARY for wave-1a-backend-tools-refactor — 8 plans shipped, 6/7 READ-numeric coach tools recompute server-side, parity harness shipped, 5-gate close.
    metadata:
      type: summary
      phase: wave-1a-backend-tools-refactor
      date: 2026-05-14
      status: <PENDING G2|READY|SHIPPED>
    ---

    # Wave 1a — Backend Tools Refactor — SUMMARY

    ## Requirements (10/10)

    - [ ] WAVE1A-01 — get_budget_status server-side (plan-01)
    - [ ] WAVE1A-02 — get_retirement_projection server-side (plan-02)
    - [ ] WAVE1A-03 — get_cross_pillar_analysis server-side (plan-03)
    - [ ] WAVE1A-04 — get_cap_status CHF garde middleware (plan-06)
    - [ ] WAVE1A-05 — get_couple_optimization Python port (plan-04)
    - [ ] WAVE1A-06 — retrieve_memories BM25 wrapper (plan-05)
    - [ ] WAVE1A-07 — get_regulatory_constant validation tests (plan-08 Task 1)
    - [ ] WAVE1A-08 — parity harness + 18 fixtures (plan-07)
    - [ ] WAVE1A-09 — Pydantic v2 camelCase response models (every plan)
    - [ ] WAVE1A-10 — per-tool rollback flags + dispatcher routing tests (plan-08 Task 1)

    ## Plan SUMMARYs

    | Plan | Tool | Tests added | Lints | SUMMARY link |
    |------|------|-------------|-------|--------------|
    | 00 | scaffolding (Wave 0) | TBD | ✅ | wave-1a-00-SUMMARY.md |
    | 01 | get_budget_status | TBD | ✅ | wave-1a-01-SUMMARY.md |
    | 02 | get_retirement_projection | TBD | ✅ | wave-1a-02-SUMMARY.md |
    | 03 | get_cross_pillar_analysis | TBD | ✅ | wave-1a-03-SUMMARY.md |
    | 04 | get_couple_optimization | TBD | ✅ | wave-1a-04-SUMMARY.md |
    | 05 | retrieve_memories | TBD | ✅ | wave-1a-05-SUMMARY.md |
    | 06 | get_cap_status garde | TBD | ✅ | wave-1a-06-SUMMARY.md |
    | 07 | parity harness | TBD | — | wave-1a-07-SUMMARY.md |
    | 08 | rollout + close | TBD | ✅ | (this file) |

    Total backend tests added (target ≥50, actual TBD per CONTEXT D-11).
    Baseline pytest count: 6567 (per STATE.md 2026-05-11). Target ≥6617.
    Actual: TBD — paste output of `pytest services/backend/ -q | tail -1`.

    ## 5-Gate Status

    | Gate | Status | Evidence |
    |------|--------|----------|
    | G1 Maestro | DRAFT (live run deferred to post-staging-deploy) | tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml |
    | G2 Julien device | PENDING | Task 3 checkpoint |
    | G3 dev CI | TBD | tools/checks/wave_1a_close.sh exit 0 output |
    | G4 regression | TBD | pytest count delta (≥+50) |
    | G5 LSFin+accent | TBD | banned_terms_python.py + accent_lint_fr.py exit 0 |

    ## Self-Check : <PASSED|FAILED|PENDING G2>

    0-trust evidence (CLAUDE.md §9) — every claim cites the command output:
    - WAVE1A-01..10 ticked: cite `pytest services/backend/tests/test_coach_tools/` exit code 0.
    - Lints green: cite the closing line of `tools/checks/wave_1a_close.sh` output.
    - Banned-terms clean: cite `banned_terms_python.py` exit 0.
    - Parity harness green: cite `pytest tests/test_coach_tools_parity.py -q | tail -3`.
    - G1 status: DRAFT — Maestro flow file exists but live run deferred.
    - G2 status: PENDING — Julien G2 token required (« approved » / « not approved — issue: X »).
    ```

    Step D — Create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html` cumulative HTML per memory `feedback_html_evidence_report`. Use a simple HTML skeleton (no JS, no external CSS) listing PRs opened during Wave 1a, panel verdicts (if any), test count delta, deferred items. Layout:

    ```html
    <!doctype html>
    <html lang="fr">
    <head><meta charset="utf-8"><title>Wave 1a — Verification Report</title>
    <style>body{font-family:system-ui,sans-serif;max-width:900px;margin:2em auto;padding:0 1em;line-height:1.5}h1,h2{color:#003B2F}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:.4em .6em;text-align:left}.ok{color:#0a7d4d}.pending{color:#b85c00}.fail{color:#a32020}</style></head>
    <body>
    <h1>Wave 1a — Backend Tools Refactor — Verification Report</h1>
    <p>Phase: <code>wave-1a-backend-tools-refactor</code> · Generated: <span id="date">2026-05-14</span></p>
    <h2>Requirements coverage</h2>
    <table><tr><th>ID</th><th>Description</th><th>Status</th><th>Plan</th></tr>
    <tr><td>WAVE1A-01</td><td>get_budget_status server-side</td><td class="pending">PENDING</td><td>plan-01</td></tr>
    <!-- mirror for WAVE1A-02 .. 10 -->
    </table>
    <h2>5-Gate status</h2>
    <table><tr><th>Gate</th><th>Status</th><th>Evidence</th></tr>
    <!-- 5 rows -->
    </table>
    <h2>Deferred items</h2>
    <ul>
      <li>CapEngine Flutter→Python port — re-litigation trigger: <code>coach.cap.cap_chf_uncited</code> Sentry breadcrumb &gt; 5/day for ≥1 week (CONTEXT D-17).</li>
      <li>pgvector for retrieve_memories — Wave 2+ if BM25 recall insufficient (CONTEXT D-07).</li>
      <li>20 paires Q&amp;A parity suite — Wave 1c scope (CONTEXT D-06).</li>
      <li><code>source_kind="tool_call_id"</code> CITATION_REGISTRY entries — Wave 1b scope.</li>
    </ul>
    </body></html>
    ```
  </action>
  <verify>
    <automated>bash tools/checks/wave_1a_close.sh</automated>
  </verify>
  <acceptance_criteria>
    - `tools/checks/wave_1a_close.sh` is executable: `test -x tools/checks/wave_1a_close.sh` exits 0.
    - `bash tools/checks/wave_1a_close.sh` exits 0 (full backend pytest + parity + lints).
    - `test -f tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml` exits 0.
    - `grep -c "appId: ch.mint.app" tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml` returns 1.
    - `test -f .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` exits 0.
    - `grep -c "WAVE1A-01\|WAVE1A-02\|WAVE1A-03\|WAVE1A-04\|WAVE1A-05\|WAVE1A-06\|WAVE1A-07\|WAVE1A-08\|WAVE1A-09\|WAVE1A-10" .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` returns ≥10.
    - `test -f .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html` exits 0.
    - `grep -c "Self-Check" .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` returns ≥1.
  </acceptance_criteria>
  <done>
    Close-out script green; Maestro flow drafted; SUMMARY.md + VERIFICATION-REPORT.html exist with all requirements tracked.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: G2 Julien device walkthrough on staging build (5-gate close)</name>
  <what-built>
    - 8 plans shipped: budget_status / retirement_projection / cross_pillar / couple_optimization / retrieve_memories server-side; cap_status CHF garde; parity harness + 18 fixtures; rollout flags + close-out.
    - 6 per-tool flags wired (5 default OFF, cap-garde default ON).
    - 18 parity tests covering 6 tools × 3 archetypes with ±0.01 CHF tolerance.
    - Maestro G1 flow drafted at `tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml`.
    - Phase SUMMARY + VERIFICATION-REPORT.html in place.
  </what-built>
  <how-to-verify>
    1. **Staging deploy precondition** — confirm the Wave 1a branch is on staging Railway with all 5 server-side flags AND cap-garde flag set:
       ```
       COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true
       COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED=true
       COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED=true
       COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED=true
       COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED=true
       COACH_CAP_CHF_GARDE_ENABLED=true
       ```
       on `mint-staging.up.railway.app`. The mobile app TestFlight build MUST target staging (per memory `feedback_app_targets_staging_always`).
    2. **Maestro G1 live run** — run `bash tools/simulator/walker.sh --flow coach_tools_server_side_smoke` on a booted iOS sim against the staging build. Confirm exit 0 + `idb ui describe-all` snapshot captures « Budget actuel », « Projection retraite », « Analyse inter-piliers », « Cap du jour » texts on screen.
    3. **Sentry breadcrumbs** — open Sentry staging project filter `category:coach.tool.*`. Confirm `coach.tool.budget_status.invoked`, `coach.tool.retirement_projection.invoked`, etc. all appear within 5 min of the Maestro run, payload contains `inputs_hash` (64 hex chars) and `flag_state: "on"`.
    4. **Cap garde test (T-WAVE1A-04 mitigation evidence)** — trigger a chat session on staging that invokes `get_cap_status` with a fixture profile whose cap_expected_impact contains un-cited CHF (insert via Railway admin or fixture seed). Confirm:
       (a) The visible chat response contains `[montant indisponible]` instead of the CHF amount.
       (b) Sentry breadcrumb `coach.cap.cap_chf_uncited` fires with the redacted snippet payload.
    5. **Cross-user isolation test (T-WAVE1A-05-04)** — log in as user A on the sim, ask the coach `« qu'est-ce que tu retiens de moi à propos de 3a ? »`. Confirm the coach mentions only insights saved BY user A (not user B). Repeat with user B.
    6. **Spot-check numeric** — on staging, open the chat overlay on a budget card, ask `« quel est mon surplus mensuel ? »`. The coach response MUST cite the exact CHF figure consistent with the budget card's displayed value (±0.01 CHF). This is the user-facing parity sanity check.
  </how-to-verify>
  <resume-signal>
    Type one of:
    - `approved` — Wave 1a G2 green; phase shipped; merge feature → dev → staging → main.
    - `approved-with-issues: <description>` — G2 partial, ship with documented deferred items appended to wave-1a-VERIFICATION-REPORT.html.
    - `not approved — issue: <description>` — Wave 1a phase reopens; revision mode via `/gsd-plan-phase wave-1a-backend-tools-refactor --revise` with the checker feedback.
  </resume-signal>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-08-01 | T | Phase shipped without 5-gate green (« ready » without citation per CLAUDE.md §9) | mitigate | Task 3 is a `checkpoint:human-verify` — phase cannot close without Julien token. SUMMARY.md « Self-Check » section CITES the wave_1a_close.sh output verbatim before « Status: SHIPPED ». |
| T-WAVE1A-08-02 | I | LSFin banned-terms regression in any touched file across the 7 prior plans | mitigate | `tools/checks/wave_1a_close.sh` runs `banned_terms_python.py` on ALL touched files in one go (G5 gate). |
| T-WAVE1A-08-03 | I | PII leak in VERIFICATION-REPORT.html (synthetic fixture names slipping into committed file) | mitigate | Persona names are « julien » (founder), « lauren » (synthetic persona); no real CHF income, no AHV13 → file passes `pii_fixture_scan.py` in plan-07. |
| T-WAVE1A-08-04 | T | Maestro flow run BEFORE staging deploy returns false-green (against local backend) | mitigate | Task 3 step 1 explicitly cites memory `feedback_app_targets_staging_always` — staging-only is the contract. Plan-08 ships the flow DRAFT; live run is post-staging-deploy. |
| T-WAVE1A-08-05 | E | 5-gate close-out fails silently because flags are OFF on staging | mitigate | Task 3 step 1 explicitly lists the 6 env vars + expected values; the Sentry breadcrumb check in step 3 confirms server-side path actually ran (breadcrumbs only fire from `_compute_*` path, not from `_format_*` legacy). |
</threat_model>

<verification>
- `bash tools/checks/wave_1a_close.sh` exits 0.
- `pytest services/backend/ -q | tail -1` shows ≥6617 passed.
- `test -f .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` exits 0.
- `test -f .planning/phases/wave-1a-backend-tools-refactor/wave-1a-VERIFICATION-REPORT.html` exits 0.
- `test -f tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml` exits 0.
- All 10 WAVE1A-XX requirement IDs grep-present in SUMMARY.md.
- Julien G2 token recorded on this PR / in this SUMMARY before « SHIPPED » claim.
</verification>

<success_criteria>
- WAVE1A-07 satisfied: 5 dispatcher tests confirm `get_regulatory_constant` routing.
- WAVE1A-10 satisfied: 13 dispatcher tests confirm all 6 flags exist + dispatcher routes flag ON / OFF correctly per tool.
- 5-gate close-out script exists and exits 0 (G3+G4+G5 mechanical gates).
- G1 Maestro flow drafted (live run deferred).
- G2 Julien token captured.
- Phase SUMMARY + VERIFICATION-REPORT.html shipped with all 10 requirements tracked + 0-trust self-check.
- Phase ready to merge feature → dev → staging → main.
</success_criteria>

<output>
After completion + Julien G2 token, finalize `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` Status field to one of: `SHIPPED` (approved) / `SHIPPED-WITH-DEFERRED` (approved-with-issues, deferred items listed in VERIFICATION-REPORT.html) / `REOPENED` (not approved — issue documented, revision mode). DO NOT claim « shipped » without the citation per CLAUDE.md §9.
</output>
