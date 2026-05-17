# calc_harness — MINT Mobile↔Backend differential CI harness (Dart side)

> Source decision : CONTEXT 92.5 D-04 (`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-CONTEXT.md`).
> Plan : `92.5-01-differential-harness-PLAN.md` (Wave 1, requirement CALC-01).

## Purpose

Pure-Dart CLI that imports `package:mint_mobile/services/financial_core/...` directly and exposes them over JSONL stdin/stdout. Drives the Mobile side of the **Mobile↔Backend differential CI gate** (G6 — wired in plan 92.5-04). Mobile is canonical per ADR-20260223-unified-financial-engine ; this binary is the deterministic, Flutter-free entrypoint the Python pytest spawns once per session.

## Build

```bash
cd apps/mobile
dart compile exe tools/calc_harness/main.dart -o /tmp/calc_harness_dart
```

> **Wave 2 caveat.** The current `package:mint_mobile/constants/social_insurance.dart` transitively imports `package:flutter/foundation.dart` (`debugPrint`) plus `regulatory_sync_service.dart` (`SharedPreferences`). Until plan 92.5-04 extracts a pure-Dart core (or replaces those imports), `dart compile exe` will fail with « target of URI doesn't exist : 'package:flutter/foundation.dart' ». The Python test side handles this gracefully by skipping the assertion suite when `/tmp/calc_harness_dart` is absent.

## Drive

```bash
cat services/backend/tests/fixtures/calc_diff_v1.jsonl \
    | /tmp/calc_harness_dart \
    > /tmp/dart_out.jsonl
```

The Python test `services/backend/tests/test_calc_diff_harness.py` does this internally via a `subprocess.run` with `input=...` ; you only need to run it manually for ad-hoc debugging.

## Why a pure-Dart CLI

- **No Flutter runtime** → fast cold-start (≈50 ms for 80 fixtures), CI-friendly.
- **Deterministic** → no async I/O surprise, no SharedPreferences cache, no network sync.
- **Direct import** → never re-implements calculator logic, always reflects the canonical Dart source. Per CLAUDE.md §4 NEVER #3 + ADR-20260223.

## Owner

- This plan : Phase 92.5 plan `92.5-01-differential-harness-PLAN.md`.
- G6 gate consumer : Phase 92.5 plan `92.5-04-PLAN.md` (Wave 2 — wires `.github/workflows/calc-rigor.yml` + builds the binary on every PR touching `financial_core/` or `services/backend/app/services/`).
- Failure-comment template : `.github/workflows/calc-rigor-failure-comment.md` (Wave 2 deliverable).

## Differential axes covered

| Axis | Mobile call site | Backend helper |
| --- | --- | --- |
| `capital_withdrawal_tax` | `RetirementTaxCalculator.capitalWithdrawalTax` | `calculate_progressive_capital_tax(amount, base_rate)` × cantonal rate |
| `lpp_bonification_rate` | `getLppBonificationRate(age)` (top-level) | `get_lpp_bonification_rate(age)` |
| `avs_rente_from_ramd` | `AvsCalculator.renteFromRAMD(salary)` | `rente_from_ramd(salary)` |
| `ai_rente_monthly` | `aiRenteEntiere * bareme[degree]` (mapped inline) | `get_ai_rente_monthly(degree)` |

Out of scope for this plan (deferred to backlog 999.4 / Phase 92.6) : `AvsCalculator.computeMonthlyRente`, `LppCalculator.projectToRetirement`. These have NO Python parity today — full port = ~1200 LOC of error-prone work that contradicts the ADR. See CONTEXT D-01, D-03.
