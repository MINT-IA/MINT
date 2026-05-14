---
phase: wave-1a
plan: 04
type: tdd
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/services/couple_optimizer/__init__.py
  - services/backend/app/services/couple_optimizer/couple_optimizer.py
  - services/backend/app/models/coach_tools/couple_optimization.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_couple_optimizer.py
  - services/backend/tests/test_coach_tools_couple_optimization.py
autonomous: true
requirements: [WAVE1A-05, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Python port of Flutter CoupleOptimizer exists at app.services.couple_optimizer mirroring Dart methods 1:1 (optimize / _analyzeLppBuybackOrder / _analyze3aContributionOrder / _analyzeAvsCap / _analyzeMarriagePenalty)"
    - "Coach tool get_couple_optimization recomputes server-side from ProfileModel.data when flag ON"
    - "Per-method numeric parity ±0.01 CHF between Flutter (apps/mobile/lib/services/financial_core/couple_optimizer.dart) and Python (services/backend/app/services/couple_optimizer/couple_optimizer.py) on the 18 unit-test fixture cases"
    - "Calls into existing Python financial_core peers (AVS / tax) when available — otherwise mirror the Dart math line-by-line"
    - "When flag OFF, dispatcher falls back to _format_couple_optimization(ctx) byte-identical"
  artifacts:
    - path: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      provides: "CoupleOptimizer.optimize(profile_data) + 4 sub-analysis methods, mirror of Dart"
      contains: "class CoupleOptimizer"
      min_lines: 200
    - path: "services/backend/app/models/coach_tools/couple_optimization.py"
      provides: "CoupleOptimizationResponse Pydantic v2 model + 4 nested sub-result models (lppBuyback, pillar3a, avsCap, marriagePenalty)"
      contains: "class CoupleOptimizationResponse(BaseModel)"
    - path: "services/backend/tests/test_couple_optimizer.py"
      provides: "≥18 unit tests covering the 4 analyses × 4-5 cases each"
      contains: "def test_"
      min_lines: 250
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_couple_optimization sibling + flag-gated dispatcher branch"
      contains: "_compute_couple_optimization"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED setting"
      contains: "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED"
  key_links:
    - from: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      to: "apps/mobile/lib/services/financial_core/couple_optimizer.dart"
      via: "1:1 port of class methods + enum + result models"
      pattern: "class CoupleOptimizer"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/couple_optimizer/couple_optimizer.py"
      via: "CoupleOptimizer.optimize() in _compute_couple_optimization"
      pattern: "CoupleOptimizer"
---

<objective>
Port the Flutter `CoupleOptimizer` (`apps/mobile/lib/services/financial_core/couple_optimizer.dart`, 423 lines, 4 analyses) to Python at `services/backend/app/services/couple_optimizer/`. Per CONTEXT D-02 (option a — port to Python recommended) + RESEARCH §3 caveat #5. This is the ONLY plan in Wave 1a that introduces NEW financial math (because no Python equivalent exists). All math must mirror the Dart implementation 1:1 with parity tests ±0.01 CHF.

The Flutter file analyses:
1. **LPP buyback order** — who buys back first? (highest marginal tax rate wins).
2. **3a contribution order** — who contributes first? + FATCA check.
3. **AVS couple cap** — LAVS art. 35 plafonnement at 150% for married couples.
4. **Marriage penalty** — is being married more or less tax-efficient?

The Dart file delegates to `TaxCalculator`, `AvsCalculator`, `RetirementTaxCalculator`. The Python port MUST delegate to the Python equivalents in `app.services` IF they exist (grep during read_first); otherwise mirror the Dart helpers inline.

Wave 1a D-13 contract: emitted user-facing French strings (`reason`, `tradeOff`) MUST be byte-identical to the legacy `_format_couple_optimization(ctx)` output when the same input data flows through. The simplest path is for the Python service to return DATACLASSES with French strings copied verbatim from Dart, and let the dispatcher emit either (a) the legacy formatter output OR (b) the JSON-serialized Pydantic model — both paths produce the same FR strings.

Purpose: provide server-side ground-truth for couple optimization CHF claims (`savingDelta`, `monthlyReduction`, `annualDelta`), so the coach can no longer hallucinate them from a missing/stale `ctx["couple_optimization"]`.
Output: NEW Python service + 18 unit tests + dispatcher path + flag.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@apps/mobile/lib/services/financial_core/couple_optimizer.dart
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/inputs_hash.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Flutter source-of-truth (read FULL file):
File apps/mobile/lib/services/financial_core/couple_optimizer.dart (423 lines).

Key classes / enums:
- `enum CoupleWinner { mainUser, conjoint, noPreference }`
- `class CoupleAnalysisResult { winner, savingDelta, reason, tradeOff }`
- `class AvsCoupleCapResult { capApplied, monthlyReduction, userRenteBeforeCap, conjointRenteBeforeCap, totalAfterCap }`
- `class MarriagePenaltyResult { hasPenalty, annualDelta, ... }`
- `class CoupleOptimizationResult { lppBuyback, pillar3a, avsCap, marriagePenalty }`
- `class CoupleOptimizer { static optimize(...), _analyzeLppBuybackOrder, _analyze3aContributionOrder, _analyzeAvsCap, _analyze_MarriagePenalty }`

Legacy formatter (BYTE-IDENTITY TARGET FOR FR STRINGS):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2361-2415:
The strings « Optimisation couple : », « Rachat LPP : {winner} en premier ({reason}) », « Économie différentielle : {chf} », « Note : {trade_off} », « 3a : {winner} en premier ({reason}) », « AVS couple : plafonnement appliqué (LAVS art. 35) », « Réduction mensuelle : {chf} », « AVS couple : pas de plafonnement (revenus sous le seuil) », « Pénalité mariage : {chf}/an de surcharge », « Bonus mariage : {chf}/an d'avantage ». The Python port MUST emit `reason`, `tradeOff` strings byte-identical to the Dart equivalents (copy from Dart inline strings verbatim).

Existing dispatcher branch (REPLACE):
File services/backend/app/api/v1/endpoints/coach_chat.py line 1924-1925:
```python
if name == "get_couple_optimization":
    return _format_couple_optimization(ctx)
```

Settings flag:
```python
COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED: bool = False
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Port Flutter CoupleOptimizer to Python with 18 RED-GREEN unit tests</name>
  <read_first>
    - apps/mobile/lib/services/financial_core/couple_optimizer.dart (FULL 423 lines — this is the source of truth being ported)
    - apps/mobile/lib/services/financial_core/tax_calculator.dart (read methods CoupleOptimizer.dart depends on — marginal rate, capital tax)
    - apps/mobile/lib/services/financial_core/avs_calculator.dart (read AVS rente methods used by `_analyzeAvsCap`)
    - apps/mobile/lib/models/coach_profile.dart (read the Profile / Conjoint struct that the Dart method reads from)
    - services/backend/app/services/retirement/avs_estimation_service.py (Python AVS — reuse if applicable; mirror Dart constants otherwise)
    - services/backend/app/services/coach/inputs_hash.py
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2361-2415 (FR strings reference)
    - services/backend/app/constants/social_insurance.py (Swiss LPP / LAVS constants — Python mirror, reuse)
  </read_first>
  <files>
    - services/backend/app/services/couple_optimizer/__init__.py (create)
    - services/backend/app/services/couple_optimizer/couple_optimizer.py (create, ~200-300 lines mirroring Dart)
    - services/backend/tests/test_couple_optimizer.py (create, ≥18 tests)
    - services/backend/app/models/coach_tools/couple_optimization.py (create — Pydantic models)
    - services/backend/app/models/coach_tools/__init__.py (modify — add export)
    - services/backend/app/core/config.py (modify — add flag)
  </files>
  <behavior>
    Test counts per analysis (TDD RED-GREEN cycles):
    - LPP buyback order (4 tests): (a) user higher marginal rate → winner=main_user, savingDelta>0; (b) conjoint higher rate → winner=conjoint; (c) equal rates → winner=no_preference, savingDelta≈0; (d) FATCA US conjoint → winner=main_user (cannot buyback US).
    - 3a contribution order (4 tests): (a) user higher marginal rate → main_user; (b) conjoint higher → conjoint; (c) FATCA US user → conjoint wins; (d) both FATCA US → noPreference with explanatory reason FR string.
    - AVS couple cap (4 tests): (a) married + combined rente >150% AVS max → capApplied=True, monthlyReduction>0; (b) married + combined < 150% cap → capApplied=False; (c) single status → method returns None; (d) concubinage → method returns None (per LAVS art. 35 applies to marriage only).
    - Marriage penalty (4 tests): (a) double-income same canton high → hasPenalty=True, annualDelta>0; (b) single-income → no penalty / advantage flagged; (c) cross-canton edge → uses higher-tax canton.
    - Plus 2 integration tests: full `optimize()` returns `CoupleOptimizationResult` with all 4 sub-results when input is valid; returns `.empty()` when civil_status not couple.
    - **Total: 18 unit tests.**
  </behavior>
  <action>
    Step A — Read `apps/mobile/lib/services/financial_core/couple_optimizer.dart` IN FULL. Note every method signature, every constant referenced, every string emitted in `reason` / `tradeOff` fields. The Python port copies these strings verbatim (per Wave 1a D-13).

    Step B — Create `services/backend/app/services/couple_optimizer/__init__.py`:
    ```python
    """Wave 1a D-02 — Python port of Flutter CoupleOptimizer.

    Mirror of apps/mobile/lib/services/financial_core/couple_optimizer.dart.
    Per CLAUDE.md rule 4, financial_core is the source of truth — this port
    must reach ±0.01 CHF parity with the Dart implementation (test_couple_optimizer
    + plan-07 parity harness enforce).
    """
    from app.services.couple_optimizer.couple_optimizer import (
        CoupleOptimizer,
        CoupleOptimizationResult,
        CoupleAnalysisResult,
        AvsCoupleCapResult,
        MarriagePenaltyResult,
        CoupleWinner,
    )

    __all__ = [
        "CoupleOptimizer",
        "CoupleOptimizationResult",
        "CoupleAnalysisResult",
        "AvsCoupleCapResult",
        "MarriagePenaltyResult",
        "CoupleWinner",
    ]
    ```

    Step C — Create `services/backend/app/services/couple_optimizer/couple_optimizer.py`:
    - Define `class CoupleWinner(str, Enum)` with members `MAIN_USER = "main_user"`, `CONJOINT = "conjoint"`, `NO_PREFERENCE = "no_preference"` (mirror Dart enum, snake_case JSON values matching legacy `_format_couple_optimization` text — verify exact strings in Dart's `.toString()` output).
    - Define dataclasses `CoupleAnalysisResult`, `AvsCoupleCapResult`, `MarriagePenaltyResult`, `CoupleOptimizationResult` mirroring the Dart classes — fields, types, defaults all preserved.
    - Define `class CoupleOptimizer:` with:
      - `@staticmethod def optimize(profile_data: dict) -> CoupleOptimizationResult`
      - 4 private static methods `_analyze_lpp_buyback_order`, `_analyze_3a_contribution_order`, `_analyze_avs_cap`, `_analyze_marriage_penalty` — Python snake_case for Dart camelCase.
    - Each method's body mirrors the Dart logic LINE BY LINE. If the Dart calls `TaxCalculator.marginalRate(profile)`, the Python equivalent calls the Python tax service (read `services/backend/app/services/fiscal/` and `services/backend/app/services/retirement/` to find a match). If no Python equivalent exists, mirror the Dart math inline (with a comment `# MIRROR Dart {file:line}` for traceability).
    - All FR strings (`reason`, `tradeOff`) copied verbatim from Dart source. Use `accent_lint_fr.py` to validate after.
    - Decimal quantization on all CHF outputs.

    Step D — Create `services/backend/tests/test_couple_optimizer.py` with 18 tests per `<behavior>`. Each test asserts `result.savingDelta` (or equivalent CHF field) is within ±Decimal("0.01") of the expected value derived from the Dart implementation (executor computes the expected by running mental math on the Dart algorithm; plan-07 cross-validates with the Dart harness).

    Step E — Create `services/backend/app/models/coach_tools/couple_optimization.py`:
    ```python
    """Wave 1a D-03 — get_couple_optimization response model.

    Nested structure mirrors Dart CoupleOptimizationResult.
    """
    from datetime import datetime
    from decimal import Decimal
    from typing import Optional
    from pydantic import BaseModel, ConfigDict, Field
    from pydantic.alias_generators import to_camel


    class LppBuybackOrderResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        winner: str  # "main_user" | "conjoint" | "no_preference"
        saving_delta: Decimal
        reason: str
        trade_off: str


    class Pillar3aOrderResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        winner: str
        reason: str
        trade_off: str


    class AvsCapResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        cap_applied: bool
        monthly_reduction: Decimal
        user_rente_before_cap: Decimal
        conjoint_rente_before_cap: Decimal
        total_after_cap: Decimal


    class MarriagePenaltyResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        has_penalty: bool
        annual_delta: Decimal


    class CoupleOptimizationResponse(BaseModel):
        model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
        lpp_buyback: Optional[LppBuybackOrderResponse] = None
        pillar_3a: Optional[Pillar3aOrderResponse] = None
        avs_cap: Optional[AvsCapResponse] = None
        marriage_penalty: Optional[MarriagePenaltyResponse] = None
        inputs_hash: str = Field(..., min_length=64, max_length=64)
        computed_at: datetime
    ```

    Step F — DO NOT modify `services/backend/app/models/coach_tools/__init__.py`. Consumers import directly from the per-tool file.

    Step G — Flag verification (plan-00 added all 6 flags; plan-04 only READS `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED`). Verify:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_couple_optimizer.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from app.services.couple_optimizer import CoupleOptimizer, CoupleOptimizationResult; print('ok')"` exits 0.
    - `python3 -c "from app.models.coach_tools.couple_optimization import CoupleOptimizationResponse; print('ok')"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `wc -l services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥200.
    - `wc -l services/backend/tests/test_couple_optimizer.py` returns ≥250.
    - `pytest services/backend/tests/test_couple_optimizer.py -q` exits 0 with ≥18 tests collected.
    - `grep -c "MIRROR Dart\|# Mirror Dart\|# mirror Dart" services/backend/app/services/couple_optimizer/couple_optimizer.py` returns ≥1 (traceability comment for inline ports).
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/couple_optimizer/couple_optimizer.py` exits 0 (FR strings verbatim from Dart preserve accents).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py` exits 0.
  </acceptance_criteria>
  <done>
    Python port + 18 unit tests green; per-method parity ±0.01 CHF asserted in tests; FR strings byte-identical to Dart.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_couple_optimization + dispatcher + ≥5 dispatcher tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1920-1930 (dispatcher entry)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2361-2415 (legacy formatter — preserve)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (breadcrumb pattern)
    - services/backend/app/services/couple_optimizer/couple_optimizer.py (just created in Task 1)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/tests/test_coach_tools_couple_optimization.py (create)
  </files>
  <behavior>
    - Test 1: dispatcher with flag OFF returns legacy `_format_couple_optimization(ctx)` byte-identical.
    - Test 2: dispatcher with flag ON returns parseable `CoupleOptimizationResponse` JSON with camelCase nested keys.
    - Test 3: dispatcher with flag ON + single-status profile → returns response with `lppBuyback=None, pillar3a=None, avsCap=None, marriagePenalty=None` + valid `inputsHash`.
    - Test 4: dispatcher with flag ON + db is None → fallback to legacy.
    - Test 5: inputs_hash deterministic.
    - Test 6: emit_coach_tool_breadcrumb is called with tool_name="couple_optimization" + all 5 D-15 kwargs (inputs_hash, profile_id_hashed, elapsed_ms, flag_state). Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` and assert called once with the 5 expected kwargs (payload structure check).
    - Test 7: FR strings in legacy fallback match the strings the Python port emits in `result.lpp_buyback.reason` (cross-source byte-identity assertion).
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, insert `_compute_couple_optimization(user_id: str | None, ctx: dict, db) -> str` ABOVE `_format_couple_optimization` (line ~2361). Mirror the PANEL-FIXED pattern from plan-01 Task 2:
    - signature uses `user_id`, NOT `profile_id` (panel fix backend-architect obs-d518b856d7e4fe1a)
    - DB lookup: `db.query(ProfileModel).filter(ProfileModel.user_id == user_id).order_by(ProfileModel.updated_at.desc()).first()`
    - pass `profile.data` directly (no `dict(...)` copy)
    - `except Exception as exc: logger.warning(...)` fallback (NOT bare `except ValueError`)
    
    Service call: `CoupleOptimizer.optimize(profile.data)`. Emit breadcrumb via the plan-00 helper:

    ```python
    import time
    import logging
    from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
    from app.utils.hashing import hash_profile_id

    # ... inside _compute_couple_optimization, after Pydantic response built ...
    elapsed_ms = int((time.perf_counter() - _t0) * 1000)
    emit_coach_tool_breadcrumb(
        tool_name="couple_optimization",
        inputs_hash=response.inputs_hash,
        profile_id_hashed=hash_profile_id(user_id),
        elapsed_ms=elapsed_ms,
        flag_state="on",
    )
    ```

    Step B — Replace dispatcher branch INSIDE the marker pair shipped by plan-00. Locate the EXACT 4-line block:
    ```python
        # >>> dispatch: get_couple_optimization
        if name == "get_couple_optimization":
            return _format_couple_optimization(ctx)
        # <<< dispatch: get_couple_optimization
    ```
    Replace WITH (markers preserved verbatim):
    ```python
        # >>> dispatch: get_couple_optimization
        if name == "get_couple_optimization":
            return _compute_couple_optimization(user_id=user_id, ctx=ctx, db=db)
        # <<< dispatch: get_couple_optimization
    ```

    Step C — Create `services/backend/tests/test_coach_tools_couple_optimization.py` with Tests 1-7.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_tools_couple_optimization.py tests/test_couple_optimizer.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/couple_optimizer/couple_optimizer.py services/backend/app/models/coach_tools/couple_optimization.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `grep -c "_format_couple_optimization" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy preserved + fallback calls).
    - `grep -c "COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_couple_optimizer.py tests/test_coach_tools_couple_optimization.py -q` exits 0 with ≥25 total tests (18 port + 7 dispatcher).
    - `grep -E "tool_name=\"couple_optimization\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥4 (plans 01 + 02 + 03 + this).
    - `grep -E "profile_id_hashed=hash_profile_id\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥4.
    - `grep -E "elapsed_ms\s*=\s*int\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥4.
    - `python3 tools/checks/banned_terms_python.py <touched files>` exits 0.
    - `python3 tools/checks/accent_lint_fr.py <touched files>` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through Python port; ≥25 tests green; FR strings byte-identical Dart↔Python.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-04-01 | T | Legacy `_format_couple_optimization` regression when flag OFF | mitigate | Task-2 Test 1 byte-identity. |
| T-WAVE1A-04-02 | I | LSFin banned-terms leak via newly-emitted Python FR strings | mitigate | Strings copied VERBATIM from Dart; `banned_terms_python.py` enforces; Dart source is already LSFin-clean per the existing Flutter `accent_lint_fr` + banned-terms gates. |
| T-WAVE1A-04-03 | I | PII leak in Sentry breadcrumb | mitigate | Payload `{inputs_hash, flag_state}` only. |
| T-WAVE1A-04-04 | T | numeric drift Flutter ↔ Python | mitigate | 18 unit tests assert per-method parity ±0.01 CHF; plan-07 parity harness adds 3-archetype cross-validation. |
| T-WAVE1A-04-05 | T (port-specific) | Port introduces calculation divergence vs Dart source-of-truth | mitigate | (a) Inline port comments cite Dart `file:line` for every non-trivial branch; (b) 18 unit-test cases include all 4 analyses × edge-case coverage; (c) plan-07 parity harness re-cross-validates against fixture profiles. |
</threat_model>

<verification>
- `pytest tests/test_couple_optimizer.py tests/test_coach_tools_couple_optimization.py -q` exits 0 with ≥25 tests.
- `pytest services/backend/ -q` full suite — zero regressions.
- `banned_terms_python.py` + `accent_lint_fr.py` green.
- `wc -l services/backend/app/services/couple_optimizer/couple_optimizer.py` ≥200 lines (true port, not stub).
- Dart-traceability comments present (`grep MIRROR Dart`).
</verification>

<success_criteria>
- WAVE1A-05 satisfied: Python port at `app.services.couple_optimizer` exists, mirrors Dart 1:1, parity ±0.01 CHF on 18 unit tests.
- WAVE1A-09 satisfied: Pydantic v2 camelCase response with nested structure.
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED` flag exists, default False.
- ≥25 new backend tests (18 port + 7 dispatcher), lints green, no FR-string drift Dart↔Python.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-04-SUMMARY.md` with files, tests, lints, port-vs-Dart traceability table (which Dart `file:line` was mirrored where), 0-trust self-check.
</output>
