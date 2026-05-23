---
phase: mint-data-spine-plan-vivant-v1
plan: 01
type: tdd
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/models/data_spine_snapshot.dart
  - apps/mobile/lib/services/data_spine/data_spine_service.dart
  - apps/mobile/test/services/data_spine_service_test.dart
autonomous: true
requirements:
  - REQ-DSP-01
  - REQ-DSP-02
  - REQ-DSP-03
must_haves:
  truths:
    - "DataSpineSnapshot is derived from CoachProfile and does not persist anything."
    - "FinancialSituation exposes current identity, income, housing, wealth, debt, fiscal, and metadata summaries."
    - "PillarPosition exposes AVS, LPP, and 3a facts with known/missing/estimated state."
    - "BudgetSnapshot remains computed by the existing BudgetLivingEngine, not duplicated."
  artifacts:
    - path: "apps/mobile/lib/models/data_spine_snapshot.dart"
      provides: "Immutable typed data-spine models."
      contains: "class DataSpineSnapshot"
    - path: "apps/mobile/lib/services/data_spine/data_spine_service.dart"
      provides: "Pure derivation service from CoachProfile."
      contains: "DataSpineService.fromProfile"
    - path: "apps/mobile/test/services/data_spine_service_test.dart"
      provides: "TDD coverage for financial situation, pillars, and budget snapshot derivation."
      contains: "DataSpineService"
  key_links:
    - from: "apps/mobile/lib/services/data_spine/data_spine_service.dart"
      to: "apps/mobile/lib/services/budget_living_engine.dart"
      via: "calls BudgetLivingEngine.compute(profile)"
      pattern: "BudgetLivingEngine.compute"
---

<objective>
Create the first typed Data Spine layer for mobile.

Purpose: give Mint a stable object that calculators, UI, and coach context can read without touching raw `wizard_answers_v2` maps or letting the LLM own facts.

Output: immutable Dart models, a pure service `DataSpineService.fromProfile`, and focused tests.

Out of scope:
- no UI wiring;
- no backend changes;
- no Maestro flow;
- no mutation or persistence;
- no new financial calculation outside existing services.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-spine-plan-vivant-v1/CONTEXT.md
@docs/superpowers/specs/2026-05-23-mint-data-spine-plan-vivant-v1-design.md
@docs/data-flow.md
@docs/calculator-graph.md
@apps/mobile/lib/models/coach_profile.dart
@apps/mobile/lib/models/budget_snapshot.dart
@apps/mobile/lib/services/budget_living_engine.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write failing DataSpineService tests</name>
  <files>apps/mobile/test/services/data_spine_service_test.dart</files>
  <read_first>apps/mobile/test/services/budget_living_engine_test.dart, apps/mobile/lib/models/coach_profile.dart</read_first>
  <action>Create tests before implementation. Cover: stable identity/income/housing extraction, AVS/LPP/3a pillar status, BudgetSnapshot reuse, missing LPP state, and no persistence side effects.</action>
  <verify>cd apps/mobile && flutter test test/services/data_spine_service_test.dart</verify>
  <acceptance_criteria>
    - Test initially fails because `package:mint_mobile/services/data_spine/data_spine_service.dart` does not exist.
    - Test helper builds a minimal `CoachProfile` without touching SharedPreferences.
  </acceptance_criteria>
  <done>Failing tests committed or staged before implementation.</done>
</task>

<task type="auto">
  <name>Task 2: Add immutable data spine model</name>
  <files>apps/mobile/lib/models/data_spine_snapshot.dart</files>
  <read_first>docs/superpowers/specs/2026-05-23-mint-data-spine-plan-vivant-v1-design.md, apps/mobile/lib/models/budget_snapshot.dart</read_first>
  <action>Create `DataSpineSnapshot`, `FinancialSituation`, `FieldFreshness`, `FieldConfidence`, `SpineFieldMeta`, `PillarPosition`, `PillarSection`, and `PillarFactState`. Keep the model immutable and UI-agnostic.</action>
  <verify>cd apps/mobile && dart analyze lib/models/data_spine_snapshot.dart</verify>
  <acceptance_criteria>
    - `DataSpineSnapshot` contains `FinancialSituation situation`, `BudgetSnapshot budget`, `PillarPosition pillars`, and `DateTime computedAt`.
    - No imports from Flutter widgets, providers, storage, or API layers.
  </acceptance_criteria>
  <done>Model compiles and tests move from missing import to missing service behavior.</done>
</task>

<task type="auto">
  <name>Task 3: Add pure derivation service</name>
  <files>apps/mobile/lib/services/data_spine/data_spine_service.dart</files>
  <read_first>apps/mobile/lib/services/budget_living_engine.dart, docs/data-flow.md</read_first>
  <action>Implement `DataSpineService.fromProfile(CoachProfile profile, {DateTime? now})`. Use `BudgetLivingEngine.compute(profile)` for budget. Derive pillars from `profile.prevoyance`, AVS fields, and 3a fields. Derive field metadata from `profile.dataSources` and `profile.dataTimestamps` when available.</action>
  <verify>cd apps/mobile && flutter test test/services/data_spine_service_test.dart</verify>
  <acceptance_criteria>
    - Service has no I/O, no SharedPreferences, no network, no backend calls.
    - Missing LPP/AVS/3a values are marked missing rather than invented.
    - Budget free amount equals `BudgetLivingEngine.compute(profile).monthlyFree`.
  </acceptance_criteria>
  <done>All new data spine tests pass.</done>
</task>

<task type="auto">
  <name>Task 4: Run targeted verification</name>
  <files>apps/mobile/lib/models/data_spine_snapshot.dart, apps/mobile/lib/services/data_spine/data_spine_service.dart, apps/mobile/test/services/data_spine_service_test.dart</files>
  <read_first>AGENTS.md</read_first>
  <action>Run the smallest relevant verification set for this mobile model/service-only change.</action>
  <verify>cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart && flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart</verify>
  <acceptance_criteria>
    - New tests pass.
    - Existing budget living engine tests pass.
    - Analyze passes for touched Dart files.
  </acceptance_criteria>
  <done>Verification output recorded in the plan summary.</done>
</task>

</tasks>

<verification>
Before declaring plan complete:
- [ ] `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart`
- [ ] `cd apps/mobile && flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart`
- [ ] `git diff --check`
</verification>

<success_criteria>
- All tasks completed.
- No persistence layer added.
- No UI changed.
- DataSpineService is pure and deterministic.
- Budget still comes from BudgetLivingEngine.
</success_criteria>

<output>
After completion, create `.planning/phases/mint-data-spine-plan-vivant-v1/mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-SUMMARY.md`.
</output>
