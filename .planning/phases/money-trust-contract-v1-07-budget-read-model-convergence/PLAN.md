# Money Trust Contract v1 — 07 Budget Read Model Convergence

Centralize the budget hydration contract used by Mon Argent and Budget so the
same fresh source wins on both surfaces.

## Goal

Remove duplicated screen-level source arbitration for budget inputs and prove
the rule in provider tests:

- no profile: restore local budget inputs;
- partial profile: prefer a richer saved budget when it exists;
- complete profile: rebuild from the canonical profile and replace stale cache.

## Scope

- `BudgetProvider` hydration policy.
- `BudgetContainerScreen` startup wiring.
- `MonArgentScreen` startup wiring.
- Budget setup convergence test covering profile, provider, and persistence.

## Out of Scope

- Financial report migration to the budget read model.
- BudgetSnapshot/DataSpine income model convergence.
- New visual design for Mon Argent or Budget.

## Acceptance

- Provider tests cover all three hydration branches.
- Existing Mon Argent and Budget screen tests still pass.
- Budget setup save proves values land in storage, profile, and provider.
- No new route, no new store, no large refactor.
