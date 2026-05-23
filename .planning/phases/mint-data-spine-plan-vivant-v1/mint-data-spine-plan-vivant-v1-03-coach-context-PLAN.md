---
phase: mint-data-spine-plan-vivant-v1
plan: 03
type: tdd
wave: 3
depends_on:
  - mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-PLAN.md
  - mint-data-spine-plan-vivant-v1-02-budget-trajectory-plan-PLAN.md
files_modified:
  - apps/mobile/lib/models/coach_context_packet.dart
  - apps/mobile/lib/services/data_spine/coach_context_packet_service.dart
  - apps/mobile/test/services/coach_context_packet_service_test.dart
autonomous: true
requirements:
  - REQ-DSP-04
must_haves:
  truths:
    - "A structured packet is generated from DataSpineSnapshot and ready for Plan 04 chat/UI wiring."
    - "The packet separates known facts, missing fields, freshness, trajectory status, and suggested next questions."
    - "The packet does not let the LLM own facts or invent missing values."
    - "The packet is privacy-conscious and avoids free-text PII beyond existing display-safe fields."
    - "CoachContextPacketService never recomputes budget, trajectory, freshness, or pillar facts; it only maps DataSpineSnapshot values."
  artifacts:
    - path: "apps/mobile/lib/models/coach_context_packet.dart"
      provides: "Immutable coach context packet DTO for LLM-facing structured facts."
      contains: "class CoachContextPacket"
    - path: "apps/mobile/lib/services/data_spine/coach_context_packet_service.dart"
      provides: "Pure conversion from DataSpineSnapshot to CoachContextPacket."
      contains: "CoachContextPacketService.fromSpine"
    - path: "apps/mobile/test/services/coach_context_packet_service_test.dart"
      provides: "TDD coverage for known facts, missing fields, freshness, trajectory, and PII boundaries."
      contains: "CoachContextPacketService"
  key_links:
    - from: "apps/mobile/lib/services/data_spine/coach_context_packet_service.dart"
      to: "apps/mobile/lib/models/data_spine_snapshot.dart"
      via: "reads DataSpineSnapshot only"
      pattern: "DataSpineSnapshot"
    - from: "mint-data-spine-plan-vivant-v1-04-ui-maestro-proof-PLAN.md"
      to: "apps/mobile/lib/screens/coach/coach_chat_screen.dart, apps/mobile/lib/services/coach_llm_service.dart, apps/mobile/lib/services/coach_narrative_service.dart"
      via: "Plan 04 must replace/adapt existing raw CoachProfile context builders with CoachContextPacket, not create a fourth long-lived contract."
      pattern: "CoachContextPacket"
---

# Plan 03 — Structured Coach Context Packet

## Objective

Create a deterministic, typed coach context packet from `DataSpineSnapshot`.

Purpose: produce the clean fact contract that Plan 04 will wire into the coach/LLM path. The packet contains structured facts, missing fields, freshness/source metadata, trajectory status, and suggested next questions without reading raw `wizard_answers_v2` maps or inventing values.

Out of scope:
- no backend chat payload change yet;
- no prompt rewrite yet;
- no UI wiring;
- no persistence changes;
- no new financial calculation.

## Context

@.planning/phases/mint-data-spine-plan-vivant-v1/CONTEXT.md
@.planning/phases/mint-data-spine-plan-vivant-v1/mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-PLAN.md
@.planning/phases/mint-data-spine-plan-vivant-v1/mint-data-spine-plan-vivant-v1-02-budget-trajectory-plan-PLAN.md
@docs/coach-tool-routing.md
@docs/data-flow.md
@apps/mobile/lib/models/data_spine_snapshot.dart
@apps/mobile/lib/services/data_spine/data_spine_service.dart
@apps/mobile/lib/services/coach/coach_context_builder.dart
@apps/mobile/lib/services/coach/coach_models.dart
@apps/mobile/lib/services/coach_narrative_service.dart

## Strict Fact Allowlist

`CoachContextPacketService` may emit only these fact IDs in Plan 03:

- `profile.canton`
- `profile.birth_year`
- `budget.monthly_net`
- `budget.monthly_free`
- `budget.monthly_capacity`
- `budget.monthly_charges`
- `pillar.avs.contribution_years`
- `pillar.avs.gaps`
- `pillar.avs.estimated_monthly_pension`
- `pillar.lpp.total_balance`
- `pillar.lpp.insured_salary`
- `pillar.lpp.buyback_max`
- `pillar.3a.total_balance`
- `pillar.3a.accounts_count`
- `trajectory.status`
- `trajectory.monthly_required`
- `trajectory.monthly_gap`

Explicit exclusions:
- no `firstName`;
- no `commune`;
- no raw `wizard_answers_v2`;
- no employer/address/NPA;
- no arbitrary free-text facts;
- no age unless a future plan adds age to `DataSpineSnapshot`.

## Tasks

<task type="auto">
  <name>Task 1: Write failing packet tests</name>
  <files>apps/mobile/test/services/coach_context_packet_service_test.dart</files>
  <read_first>apps/mobile/test/services/data_spine_service_test.dart, apps/mobile/lib/models/data_spine_snapshot.dart</read_first>
  <action>Create tests before implementation. Cover known facts from the strict allowlist, missing AVS/LPP/3a fields, trajectory status/next lever, freshness/source metadata, `toSafeMap()`, source-only-from-spine behavior, and PII exclusions.</action>
  <verify>cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart</verify>
  <acceptance_criteria>
    - Test initially fails because `coach_context_packet.dart` and `coach_context_packet_service.dart` do not exist.
    - Tests assert `profile.birth_year`, not age.
    - Tests assert no `firstName`, `commune`, `employer`, `address`, `npa`, or raw wizard map keys appear in `toSafeMap()`.
  </acceptance_criteria>
  <done>Failing tests committed or staged before implementation.</done>
</task>

<task type="auto">
  <name>Task 2: Add immutable packet model with serialization</name>
  <files>apps/mobile/lib/models/coach_context_packet.dart</files>
  <read_first>apps/mobile/lib/models/data_spine_snapshot.dart, apps/mobile/lib/services/coach/coach_models.dart</read_first>
  <action>Add `CoachContextPacket`, `CoachContextFact`, `CoachMissingField`, `CoachTrajectoryContext`, and `CoachNextQuestion`. Add `toSafeMap()` methods for later chat payload serialization.</action>
  <verify>cd apps/mobile && dart analyze lib/models/coach_context_packet.dart</verify>
  <acceptance_criteria>
    - No Flutter imports.
    - No provider, storage, API, or CoachProfile dependency.
    - `toSafeMap()` contains only structured facts, missing fields, metadata, trajectory, and next questions.
    - Missing fields carry stable `fieldPath`, `domain`, and `reason`.
  </acceptance_criteria>
  <done>Model compiles and tests move from missing import to missing service behavior.</done>
</task>

<task type="auto">
  <name>Task 3: Add pure packet service</name>
  <files>apps/mobile/lib/services/data_spine/coach_context_packet_service.dart</files>
  <read_first>apps/mobile/lib/services/data_spine/data_spine_service.dart, docs/coach-tool-routing.md</read_first>
  <action>Implement `CoachContextPacketService.fromSpine(DataSpineSnapshot spine)`. Map only the strict allowlist. Pass through `BudgetSnapshot`, `TrajectorySummary`, `PillarFact.state`, and `SpineFieldMeta`; do not recompute them.</action>
  <verify>cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart</verify>
  <acceptance_criteria>
    - Reads only `DataSpineSnapshot`.
    - Emits facts only from the strict allowlist.
    - Emits missing fields for missing AVS/LPP/3a facts and missing target data.
    - Maps trajectory status to a concise next question.
    - No LLM text generation, no network, no storage, no raw CoachProfile, no wizard map.
  </acceptance_criteria>
  <done>All packet tests pass.</done>
</task>

<task type="auto">
  <name>Task 4: Preserve anti-facade handoff for Plan 04</name>
  <files>.planning/phases/mint-data-spine-plan-vivant-v1/mint-data-spine-plan-vivant-v1-04-ui-maestro-proof-PLAN.md</files>
  <read_first>apps/mobile/lib/screens/coach/coach_chat_screen.dart, apps/mobile/lib/services/coach_llm_service.dart, apps/mobile/lib/services/coach_narrative_service.dart</read_first>
  <action>Do not wire chat in Plan 03. Instead, ensure Plan 04 explicitly fails if chat integration still builds long-lived context from raw `CoachProfile` paths after packet adoption.</action>
  <verify>rg -n "CoachContextPacket|coach_context_packet" .planning/phases/mint-data-spine-plan-vivant-v1</verify>
  <acceptance_criteria>
    - Plan 04 names existing context builders as migration targets.
    - Plan 04 requires a negative facade test or grep/lint proving packet adoption.
  </acceptance_criteria>
  <done>Plan 04 handoff is explicit; Plan 03 remains model + converter + tests only.</done>
</task>

<task type="auto">
  <name>Task 5: Verify targeted perimeter</name>
  <files>apps/mobile/lib/models/coach_context_packet.dart, apps/mobile/lib/services/data_spine/coach_context_packet_service.dart, apps/mobile/test/services/coach_context_packet_service_test.dart</files>
  <read_first>AGENTS.md</read_first>
  <action>Run the smallest relevant verification set for this mobile model/service-only change.</action>
  <verify>cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart test/services/coach_context_builder_test.dart && flutter analyze lib/models/coach_context_packet.dart lib/services/data_spine/coach_context_packet_service.dart && git diff --check</verify>
  <acceptance_criteria>
    - Packet tests pass.
    - Data spine tests still pass.
    - Existing CoachContextBuilder tests still pass.
    - Analyze passes for touched Dart files.
  </acceptance_criteria>
  <done>Verification output recorded in the plan summary.</done>
</task>

## Verification

Before declaring plan complete:

```bash
cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart test/services/coach_context_builder_test.dart
cd apps/mobile && flutter analyze lib/models/coach_context_packet.dart lib/services/data_spine/coach_context_packet_service.dart
git diff --check
```

## Review Gates

Before coding:
- GSD plan review should confirm the plan is goal-backward complete for REQ-DSP-04.
- Architecture review should confirm this is not a facade: the packet has tests, `toSafeMap()`, a strict whitelist, and a clear Plan 04 migration target.

After coding:
- Code review should check PII boundary, no raw map exposure, no duplicate calculations.
- QA review should check missing-field and trajectory coverage.

## Success Criteria

- A typed coach context packet exists and is derived from the data spine.
- Tests prove known facts, missing facts, freshness, trajectory, and PII boundaries.
- No chat integration is claimed until a later plan wires the packet into the actual request path.
