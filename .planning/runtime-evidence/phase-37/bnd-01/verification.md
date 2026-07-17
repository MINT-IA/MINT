# G1-BND-01 verification

Accepted implementation SHA:
`ed5f2db13112f76753bc9e3abc23ff51d44b0ae3`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/legacy_provider_migration_test.dart --reporter expanded`.
- Semantic RED SHA `d9f93e30b46752e07e8660e7bcbff78aad42b3c1`:
  the exact physical-archive replay, with only the final contract test
  overlaid, exited `1`; **1 passed / 5 semantic failures** after compiling and
  reaching the real provider, registration, reader, copy and route surfaces.
- GREEN SHA `ed5f2db13112f76753bc9e3abc23ff51d44b0ae3`:
  an exact physical-archive replay exited `0`; **6 passed, 0 failed, 0
  skipped** with the identical command.
- Machine evidence: `red.json`, `green.json` and `audit-manifest.json`.

The GREEN reconciles the historical five matches to one real production
reader, `Simulator3aScreen`. It removes the unpopulated `ProfileProvider`, its
registration and the uncoupled `RecommendationCard` and `BuybackWidget`; no
compatibility facade remains. The sole live reader uses
`CoachProfile.isInDebtCrisis`, keeps missing authority nullable, describes an
emergency-fund-only crisis without falsely asserting debt, and exposes a real
diagnostic CTA when no canonical profile exists.

`models/profile.dart` is intentionally retained only as the API/Wizard DTO. It
has no provider, screen, persistence or ledger ownership.

All ticket profiles are synthetic. No private certificate, raw device
identifier, absolute local path, screenshot, raw tool log or real financial
fixture is retained in this versioned evidence.

## External audit disposition

- The first wrapper-only product-domain pass found a real P1: the canonical
  crisis predicate also covers liquidity-only cases, while the old copy
  asserted debt. The accepted SHA resolves it with generic six-language
  financial-stability wording.
- Wrapper-only Sonnet rerun `code`: **PASS**, P0=0 and P1=0.
- Wrapper-only Sonnet rerun `product-domain`: **PASS**, P0=0 and P1=0.
- No further audit carousel is authorized.
- Six P2 observations remain explicit in `audit-manifest.json`: the global
  null-profile SafeMode helper, empty-state subtitle, Swiss constant freshness,
  historical test numbering, `/pilier-3a` interaction coverage and unrelated
  Portuguese grammar. They are triaged follow-ups, not hidden closure claims.

## Decision boundary

This promotion closes only `G1-BND-01`. It does not close the distinct global
SafeMode helper inventory, activate a financial product path, close
`G1-RUNTIME-01`, complete G1, or authorize G2/G3. G1 remains **8.2/10 —
NO-GO** with **11 open hard floors**; the canonical next Wave 3 ticket is
`G1-COACH-01`.
