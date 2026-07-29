# Phase 20 — Summary

## What Changed
- Added `isHousingMissing` and `isHealthMissing` to `BudgetInputs`.
- Updated `BudgetInputs.fromCoachProfile` so:
  - trusted/user-provided housing and LAMal are accepted;
  - `ProfileDataSource.estimated` LAMal stays estimated;
  - absent housing/LAMal are marked missing;
  - other fixed costs are summed from sourced sub-posts only.
- Updated `BudgetInputs.fromMap`/`toMap` to persist the new meta flags and
  mark legacy maps without housing as missing.
- Updated Budget UI LAMal quality tag to show `manquant` when LAMal is absent.
- Added `mintapp:///mon-argent?section=month` so product CTAs and Maestro can
  open the monthly budget section directly instead of relying on a fragile chip
  tap.
- Added `flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`.

## Why It Matters
Mint cannot be trusted if it cannot tell the difference between a value the user
entered, a Mint estimate, and a missing fact. This phase keeps that distinction
through storage, budget computation, UI labels, and runtime navigation.

## Files
- `apps/mobile/lib/domain/budget/budget_inputs.dart`
- `apps/mobile/lib/app.dart`
- `apps/mobile/lib/screens/budget/budget_screen.dart`
- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
- `apps/mobile/test/domain/budget/budget_service_test.dart`
- `apps/mobile/test/data/budget/budget_local_store_test.dart`
- `apps/mobile/test/providers/budget/budget_provider_test.dart`
- `apps/mobile/test/screens/mon_argent_screen_test.dart`
- `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`

## Review
- Claude Opus first pass flagged two real blockers: estimated LAMal source was
  being collapsed, and legacy missing housing meta defaulted to not missing.
- Both blockers were fixed with regression tests.
- The Claude CLI wrapper was hardened to use `--output-format json` and parse
  `.result`, avoiding empty/truncated Codex pipe output.
