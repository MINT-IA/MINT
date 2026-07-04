---
name: mint-flutter-dev
description: Compatibility mirror. Canonical skill lives at .agents/skills/mint-flutter-dev/SKILL.md.
---

# Mirror

Read `../../../.agents/skills/mint-flutter-dev/SKILL.md`.

If this file diverges from `.agents/skills/mint-flutter-dev/SKILL.md`, the
`.agents` file wins.

Flutter work routes through `mint-mobile` + `mint-quality-gate` by default.
External specialists require a named gap; no vendor agent catalog is checked in.

<!-- mint-data-architecture-v1-01-canonical:start -->
## Calc-engine ownership — L1 mobile-canonical (D-01..D-04, D-13)

`apps/mobile/lib/services/financial_core/` is the L1 chiffrer canonical home — single-number deterministic outputs from `(profile, constants_snapshot)`, offline-capable, mobile-canonical per Phase `mint-data-architecture-v1-01-calc-engine-canonical`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (`L1ChiffrePayload` → mobile ; `L2ComparePayload` / `L3EclairePayload` / `L4InvariantPayload` → backend).

### Stays mobile (per D-03 — UX-bound, no LSFin output)

- `apps/mobile/lib/services/financial_core/confidence_scorer.dart`
- `apps/mobile/lib/services/financial_core/bayesian_enricher.dart`
- `apps/mobile/lib/services/financial_core/coach_reasoner.dart`

### Migrates backend (per D-03 + D-11 — projection-class)

- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (FIRST per D-11)
- `apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart`
- `apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart`
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart`

### Regulatory vs MINT-doctrinal constants (D-13)

Regulatory constants (`plafond_3a`, AVS rentes, LIFD brackets, canton tax …) sync via Plan 04 build-time codegen → `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`. MINT-doctrinal constants (`safeWithdrawalRate = 4%`, expected returns, mortality tables) stay Dart-side with their OWN version field, distinct from regulatory constants — two version trails, two audit chains.

### Bundle-size budget (D-14)

Validated 4509 gzip bytes / 95.6% headroom vs 100 KB ceiling per `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md`. Re-litigate the bake-all-26-cantons posture only if compressed snapshot > 100 KB.

<!-- mint-data-architecture-v1-01-canonical:end -->
