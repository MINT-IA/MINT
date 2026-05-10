# calc_diff_v1.jsonl — Schema & Lifecycle (Phase 92.5 CALC-01)

> Source decisions : CONTEXT 92.5 [D-08, D-09, D-10] (`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-CONTEXT.md`).
> Roadmap anchor : ROADMAP §92.5 success criterion #1 (post-D-02 patch — 80–100 fixtures, NOT 200).

## Purpose

Frozen-by-design fixture set driving the **Mobile↔Backend differential CI harness** (`services/backend/tests/test_calc_diff_harness.py`). Each line is one self-contained JSON object. The Dart binary `apps/mobile/tools/calc_harness/main.dart` (built via `dart compile exe`) reads this file as JSONL on stdin ; the Python test asserts per-axis tolerance against existing helpers in `services/backend/app/constants/social_insurance.py` (NEVER new mirror classes — CLAUDE.md §4 NEVER #3, ADR-20260223).

## Matrix (CONTEXT D-08)

| Dimension | Values | Count |
| --- | --- | --- |
| archetype | `swiss_native`, `expat_eu`, `expat_us`, `cross_border`, `independent_no_lpp`, `young_starter`, `near_retirement`, `couple_dual_earner` | 8 |
| canton | `ZH`, `VD`, `GE`, `BE`, `BS` (top 5 by population) | 5 |
| phase-de-vie | `working_age` (age 35), `retirement_proche` (age 60) | 2 |

Total : **8 × 5 × 2 = 80 fixtures**. Optional +20 hand-curated edge cases (FATCA / frontalier / `independent_no_lpp` corner cases) max → 100 ceiling per CONTEXT D-08. Deferred to a follow-up commit when the first divergence requires reproduction in isolation.

## Fields (CONTEXT D-09)

| Field | Type | Description |
| --- | --- | --- |
| `id` | `string` | Stable identifier `<archetype>__<canton>__<phase>` (used by Python test to join Mobile and Backend outputs) |
| `archetype` | `string` | One of the 8 archetypes (lowercase, snake_case) |
| `canton` | `string` | 2-letter Swiss canton code (uppercase) |
| `phase` | `string` | `working_age` or `retirement_proche` |
| `age` | `int` | 35 (`working_age`) or 60 (`retirement_proche`) |
| `gross_annual_salary` | `float` | RAMD proxy in CHF — input to `rente_from_ramd` and the Mobile `AvsCalculator.renteFromRAMD` |
| `lpp_balance` | `float` | Current LPP balance in CHF — used as the capital-withdrawal input |
| `marital_status` | `string` | `single` or `married` (only `couple_dual_earner` rows = `married`) |
| `ai_disability_degree` | `int` | 0..100 disability degree input to `get_ai_rente_monthly`. All baseline rows = 0 ; non-zero edge cases handled by the Hypothesis property suite (plan 92.5-02). |
| `capital_withdrawal_amount` | `float` | CHF amount fed to `calculate_progressive_capital_tax` × cantonal rate. By default = `lpp_balance`. |
| `expected_axes` | `object` | **Empty `{}` on initial commit** per CONTEXT D-09. Populated by the first Mobile baseline run, then frozen alongside the next `fix(calc-fixtures):` commit. |

## Lifecycle (CONTEXT D-10)

Any change to a fixture row OR to the `expected_axes` dictionary REQUIRES a separate commit prefixed `fix(calc-fixtures):` with a one-line ADR-style note explaining WHY the value moved (e.g. « 2026-XX-XX OFAS table refresh », « Dart `RetirementTaxCalculator.capitalWithdrawalTax` rate update », « new `married_capital_tax_discount` per-canton helper landed »).

The lefthook lint `tools/checks/calc_diff_fixture_checksum.py` (Wave 2 — plan 92.5-04) tracks the file checksum and flags accidental drift on PRs that don't carry the `fix(calc-fixtures):` prefix.

## Citation

- CONTEXT D-08 — deterministic 8 × 5 × 2 matrix justification
- CONTEXT D-09 — `expected_axes` empty on initial commit, frozen on next baseline run
- CONTEXT D-10 — lifecycle rule + checksum lint

## Cross-references

- Test runner : `services/backend/tests/test_calc_diff_harness.py`
- Dart side : `apps/mobile/tools/calc_harness/main.dart`
- Backend helpers : `services/backend/app/constants/social_insurance.py` (functions: `calculate_progressive_capital_tax`, `get_lpp_bonification_rate`, `rente_from_ramd`, `get_ai_rente_monthly`)
- Canonical source : ADR-20260223-unified-financial-engine (Mobile financial_core/ is canonical)
- Tolerance contract : CONTEXT D-06 (rentes ±1 CHF, canton tax ±5 CHF, ratios ±0.05)
