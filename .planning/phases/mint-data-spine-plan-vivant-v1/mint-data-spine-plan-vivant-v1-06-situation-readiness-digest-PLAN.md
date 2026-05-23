---
phase: mint-data-spine-plan-vivant-v1
plan: 06
type: tdd
wave: 6
depends_on:
  - mint-data-spine-plan-vivant-v1-05-visible-maestro-proof-PLAN.md
files_modified:
  - apps/mobile/lib/models/data_spine_snapshot.dart
  - apps/mobile/lib/services/data_spine/data_spine_readiness_digest_service.dart
  - apps/mobile/test/services/data_spine_readiness_digest_service_test.dart
autonomous: true
requirements:
  - REQ-DSP-06
must_haves:
  truths:
    - "Plan 06 must clarify the user's financial situation without creating a second source of truth."
    - "The digest must derive only from DataSpineSnapshot."
    - "The digest must not add or duplicate financial calculations."
---

# Plan 06 — Data Spine Readiness Digest

## Objective

Create a deterministic digest that tells Mint whether the user's data spine is
readable enough to coach, project, and plan.

The digest should answer:

- what sections are usable now;
- what domains are missing;
- what next action should be asked or shown first.

## Tasks

### Task 1 — TDD the product contract

Add service tests for three states:

- ready: situation, budget, pillars, and trajectory all have enough data;
- partial: useful current data exists, but pillars or target data are missing;
- blocked: current budget is negative and the next action must stabilize budget.

### Task 2 — Add the model contract

Add small immutable classes/enums to the data spine model:

- overall readiness status;
- per-section readiness;
- missing domains;
- next action id.

### Task 3 — Implement pure derivation service

Add a pure service that consumes `DataSpineSnapshot` only.

Do not read `CoachProfile`, wizard maps, storage, or backend state.
Do not call calculators directly. `DataSpineService` already owns the existing
budget derivation through `BudgetLivingEngine`.

### Task 4 — Verify

Run focused Flutter tests, focused analyzer, and `git diff --check`.

## Non-Goals

- No UI wiring.
- No new persistence.
- No backend changes.
- No Maestro flow.
- No new financial formulas.
