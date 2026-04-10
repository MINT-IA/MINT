---
phase: 08a-l1.2b-mtc-11-surface-migration
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/models/response_card.dart
  - apps/mobile/test/models/response_card_test.dart
  - services/backend/app/schemas/response_card.py
  - services/backend/app/schemas/confidence.py
  - services/backend/tests/schemas/test_response_card.py
  - tools/openapi/openapi.json
  - SOT.md
autonomous: true
requirements: [MTC-12]
must_haves:
  truths:
    - "ResponseCard can carry an optional EnhancedConfidence alongside its existing fields"
    - "Backend emits EnhancedConfidence in the response_card wire shape per D-05"
    - "Round-trip JSON test proves mobile fromJson/toJson matches backend serialization byte-for-byte on all 4 axes + combined + weakestAxis + enrichmentPrompts"
    - "Existing ResponseCard call sites compile unchanged (confidence defaults to null)"
  artifacts:
    - path: apps/mobile/lib/models/response_card.dart
      provides: "EnhancedConfidence? confidence field + JSON round-trip"
      contains: "final EnhancedConfidence? confidence"
    - path: services/backend/app/schemas/response_card.py
      provides: "Optional[EnhancedConfidence] confidence field"
      contains: "confidence: Optional[EnhancedConfidence]"
    - path: services/backend/tests/schemas/test_response_card.py
      provides: "round-trip test on the new confidence field"
  key_links:
    - from: apps/mobile/lib/models/response_card.dart
      to: apps/mobile/lib/services/financial_core/confidence_scorer.dart
      via: "import of EnhancedConfidence"
      pattern: "import.*confidence_scorer"
    - from: services/backend/app/schemas/response_card.py
      to: services/backend/app/schemas/confidence.py
      via: "Optional[EnhancedConfidence] field"
      pattern: "Optional\\[EnhancedConfidence\\]"
---

<objective>
Finish Phase 4's deferred D-07 null-fallback by extending ResponseCard (mobile model) and the backend response_card schema to carry `EnhancedConfidence?` on the wire, with a JSON round-trip test proving byte-exact parity. This is the enabling refactor for Plan 08a-02 (the 11-surface consumer wire-up).

Purpose: Without this field, 10 of the 11 migration surfaces have nothing to render; MTC would stay at Phase 4's null-fallback forever.
Output: Extended model + schema + round-trip test + OpenAPI regen + SOT.md update.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-CONTEXT.md
@.planning/phases/04-p4-mtc-component-s4-migration/04-CONTEXT.md
@docs/AUDIT-01-confidence-semantics.md
@apps/mobile/lib/models/response_card.dart
@apps/mobile/lib/services/financial_core/confidence_scorer.dart
@CLAUDE.md

<interfaces>
From apps/mobile/lib/services/financial_core/confidence_scorer.dart:
  class EnhancedConfidence with 4 axes (completeness, accuracy, freshness, understanding),
  computed `combined: int`, `weakestAxis`, and `enrichmentPrompts: List<EnrichmentPrompt>`.
  Executor MUST read the actual class declarations before writing toJson/fromJson.

Wire shape (LOCKED per CONTEXT §D-05):
  {
    "completeness": 0.72,
    "accuracy": 0.85,
    "freshness": 0.91,
    "understanding": 0.60,
    "combined": 76,
    "weakestAxis": "understanding",
    "enrichmentPrompts": [
      { "axis": "understanding", "label": "...", "deepLink": "/coach/..." }
    ]
  }
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend mobile ResponseCard with optional EnhancedConfidence</name>
  <files>
    apps/mobile/lib/models/response_card.dart
    apps/mobile/test/models/response_card_test.dart
  </files>
  <behavior>
    - Test 1: A ResponseCard built without `confidence:` has `card.confidence == null` and `toJson()` output contains NO `confidence` key.
    - Test 2: A ResponseCard built with a non-null EnhancedConfidence round-trips: `fromJson(toJson())` preserves all 4 axes, combined, weakestAxis, enrichmentPrompts.
    - Test 3: `fromJson` tolerates a payload with `confidence: null` — produces a card with `confidence == null`, no throw.
    - Test 4: `fromJson` tolerates a payload without the `confidence` key at all — same result.
    - Test 5: All existing ResponseCard tests in the suite still pass (the new field is additive + defaulted).
  </behavior>
  <action>
    Read `apps/mobile/lib/services/financial_core/confidence_scorer.dart` first to confirm the actual `EnhancedConfidence` class shape (field names, axis names, EnrichmentPrompt class). Use the REAL class, do not invent.

    Then in `response_card.dart`:
    1. Add import: `import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';`
    2. Add field to `ResponseCard`: `final EnhancedConfidence? confidence;`
    3. Add to constructor as `this.confidence` optional named, default null. Place it AFTER `icon` to keep existing positional/named ordering stable (all existing call sites compile unchanged).
    4. Extend `toJson()`: add `if (confidence != null) 'confidence': confidence!.toJson(),` — no key when null.
    5. Create/extend `fromJson()` if it exists (grep — currently the file shows a `PremierEclairage.fromJson` + `CardCta.fromJson` pattern; if `ResponseCard.fromJson` does not exist, create it mirroring the `toJson` structure). Handle `json['confidence'] == null` OR missing key → `null`.
    6. If `EnhancedConfidence.toJson()` / `fromJson()` do not exist in `confidence_scorer.dart`, add them in that file as a minimal patch: toJson emits the D-05 wire shape; fromJson parses it. This is the ONE place where confidence_scorer.dart is touched in Phase 8a — the rest of the file (the computation engine) stays untouched per CONTEXT §Out of scope.

    Write tests in `test/models/response_card_test.dart` (create if absent) covering the 5 behaviors above. Use realistic EnhancedConfidence values (e.g. completeness 0.72, accuracy 0.85, freshness 0.91, understanding 0.60) — do NOT use golden couple data, these are unit tests.

    Use CONTEXT §D-03 wire rules verbatim. Do NOT double-taxe with legacy or new aliases.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/models/response_card_test.dart && flutter analyze lib/models/response_card.dart lib/services/financial_core/confidence_scorer.dart</automated>
  </verify>
  <done>
    New tests green. flutter analyze 0 errors on both files. Grep confirms `final EnhancedConfidence? confidence` present in response_card.dart. All pre-existing ResponseCard tests still green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Backend response_card schema + EnhancedConfidence Pydantic mirror + round-trip test</name>
  <files>
    services/backend/app/schemas/response_card.py
    services/backend/app/schemas/confidence.py
    services/backend/tests/schemas/test_response_card.py
    tools/openapi/openapi.json
    SOT.md
  </files>
  <behavior>
    - Test 1: `EnhancedConfidence` Pydantic model serializes to the exact D-05 wire shape (field names, camelCase aliases for `weakestAxis` and `enrichmentPrompts`).
    - Test 2: `ResponseCard` schema accepts `confidence: None` (default) and `confidence: EnhancedConfidence(...)`.
    - Test 3: Round-trip: a payload matching the D-05 shape JSON → `ResponseCard.model_validate(...)` → `.model_dump(by_alias=True)` produces byte-equivalent JSON (modulo key ordering).
    - Test 4: Existing response_card schema tests still pass unchanged.
  </behavior>
  <action>
    1. Locate the existing backend ResponseCard schema. If `services/backend/app/schemas/response_card.py` does not exist, grep for the closest analogue (`grep -rn "class ResponseCard" services/backend/app/schemas/`) and add the field there. CLAUDE.md §4 mandates backend is source of truth.
    2. Create or extend `services/backend/app/schemas/confidence.py` with a Pydantic v2 `EnhancedConfidence` model:
       - Fields: `completeness: float`, `accuracy: float`, `freshness: float`, `understanding: float`, `combined: int`, `weakest_axis: Literal['completeness','accuracy','freshness','understanding']`, `enrichment_prompts: list[EnrichmentPrompt]`
       - `EnrichmentPrompt`: `axis: str`, `label: str`, `deep_link: str`
       - `ConfigDict(populate_by_name=True, alias_generator=to_camel)` per CLAUDE.md §4.
    3. Add `confidence: Optional[EnhancedConfidence] = None` to the ResponseCard schema. Null by default — fully back-compat.
    4. Write tests in `services/backend/tests/schemas/test_response_card.py` covering the 4 behaviors above.
    5. Regenerate OpenAPI: run the project's OpenAPI dump script (check `tools/openapi/` for a `generate.sh` or similar; if none, `uvicorn app.main:app` + curl `/openapi.json` into `tools/openapi/openapi.json`). Commit the drift.
    6. Update `SOT.md` with a one-line entry in the ResponseCard section: `confidence: Optional[EnhancedConfidence]` + reference Plan 08a-01 + D-05 wire shape.

    Do NOT change the confidence computation engine anywhere on the backend. This is a schema-only change.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/schemas/test_response_card.py -q && python3 -c "from app.schemas.response_card import ResponseCard; from app.schemas.confidence import EnhancedConfidence; print('ok')"</automated>
  </verify>
  <done>
    Backend tests green. EnhancedConfidence importable. ResponseCard accepts `confidence`. OpenAPI diff committed. SOT.md updated.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Cross-stack round-trip fixture test (mobile decodes exactly what backend emits)</name>
  <files>
    apps/mobile/test/models/response_card_backend_roundtrip_test.dart
    services/backend/tests/schemas/fixtures/response_card_with_confidence.json
  </files>
  <behavior>
    - Test 1: A JSON fixture written by the backend (committed under `services/backend/tests/schemas/fixtures/response_card_with_confidence.json`) is decoded by the mobile `ResponseCard.fromJson` with no loss: all 4 axes, combined, weakestAxis, enrichmentPrompts present and equal to the fixture values.
    - Test 2: Re-serializing the mobile card with `toJson()` produces a payload whose `confidence` subtree matches the fixture byte-for-byte (modulo key ordering, handled by a deep-equal assertion, not a string compare).
    - Test 3: The backend test generates the fixture from a `ResponseCard(...)` Pydantic instance and asserts the fixture file on disk is in sync (fails if a dev changes the schema without regenerating the fixture).
  </behavior>
  <action>
    1. Add to the backend test from Task 2 an auto-update block that, when run with `PYTEST_UPDATE_FIXTURES=1`, writes the canonical `response_card_with_confidence.json` fixture. Default run asserts the on-disk file matches the in-memory serialization. This is the drift gate.
    2. In `apps/mobile/test/models/response_card_backend_roundtrip_test.dart`, load the fixture via `File('../../services/backend/tests/schemas/fixtures/response_card_with_confidence.json').readAsStringSync()` — Flutter test can read repo files via relative path from `apps/mobile/`. Decode with `jsonDecode` + `ResponseCard.fromJson` and assert all fields match the expected values hard-coded in the test.
    3. Re-serialize and deep-equal-compare against the fixture map.

    If the cross-repo file read turns out to be sandboxed in a way that breaks on CI, fall back to committing a copy of the fixture under `apps/mobile/test/fixtures/response_card_with_confidence.json` with a backend-side CI check that keeps the two copies in sync via sha256.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/models/response_card_backend_roundtrip_test.dart && cd ../../services/backend && python3 -m pytest tests/schemas/test_response_card.py -q</automated>
  </verify>
  <done>
    Fixture committed. Mobile decodes backend-emitted JSON cleanly. Drift gate catches schema changes.
  </done>
</task>

</tasks>

<verification>
- `flutter analyze` → 0 errors on touched mobile files.
- `pytest services/backend/tests/schemas/ -q` → green.
- `flutter test test/models/` → green.
- OpenAPI diff committed + SOT.md updated.
</verification>

<success_criteria>
ResponseCard (mobile + backend) carries `EnhancedConfidence?`, wire-identical, round-trip proven, back-compat preserved. Plan 08a-02 can now consume `card.confidence` at any of the 11 migration sites.
</success_criteria>

<output>
After completion, create `.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-01-SUMMARY.md`.
</output>
