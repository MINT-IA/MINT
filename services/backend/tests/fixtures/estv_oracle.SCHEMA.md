# estv_oracle_2025.jsonl — Schema & Lifecycle (Phase 92.5 CALC-03)

> Source decisions : CONTEXT 92.5 [D-11, D-12, D-13, D-14] (`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-CONTEXT.md`).
> Roadmap anchor : ROADMAP §92.5 success criterion #3 (ESTV oracle pin, ±5 CHF tolerance).
> Capture utility : `services/backend/tests/scripts/capture_estv_oracle.py` (manual annual cadence).

## Purpose

Frozen fixture set driving the **MINT vs ESTV oracle pin** (`services/backend/tests/test_estv_oracle.py`). Each line is one self-contained JSON object captured live from `swisstaxcalculator.estv.admin.ch`. The pytest matcher asserts that MINT-computed canton tax (via `app.constants.social_insurance.calculate_progressive_capital_tax` + cantonal multiplier from `TAUX_IMPOT_RETRAIT_CAPITAL`) agrees with the ESTV expected value within ±5 CHF (CONTEXT D-14). NEVER re-implements `_calculate_*()` mirrors — CLAUDE.md §4 NEVER #3, ADR-20260223.

## Matrix (CONTEXT D-12)

| Dimension | Values | Count |
| --- | --- | --- |
| canton | `ZH`, `VD`, `GE`, `BE`, `BS` (top 5 by population) | 5 |
| marital/income combo | `single_60k`, `single_100k`, `married_100k`, `married_150k`, `married_200k` | 5 |
| age | `40`, `60` | 2 |

Total : **5 x 5 x 2 = 50 vectors exact** (CONTEXT D-12, no edge-case ceiling — the ESTV oracle is a clean external grounding axis, not an exhaustive coverage tool).

## Fields (one JSON object per JSONL line)

| Field | Type | Description |
| --- | --- | --- |
| `id` | `string` | Stable identifier `<canton>__<combo_label>__age<N>` (e.g. `ZH__single_60k__age40`). Used by pytest parametrize IDs and by the freshness lint. |
| `canton` | `string` | Two-letter canton code (one of `CANTONS` in `capture_estv_oracle.py`). |
| `marital_status` | `string` | `single` or `married`. Passé en `is_married` à `estimate_capital_withdrawal_tax` : la part cantonale mariée interpole l'étalon ESTV `CANTONAL_CAPITAL_TAX_MARRIED_CHF` (le rabais forfaitaire par canton a été supprimé — triage AnnAssign #1095). |
| `gross_income_chf` | `int` | Annual gross income in CHF, integer for stable test IDs. |
| `age` | `int` | Age in years (`40` or `60`). Reserved for future age-conditional matchers ; not currently consumed by the capital-tax matcher. |
| `expected_tax_chf` | `float \| null` | The ESTV expected tax value in CHF. **`null` on first commit** (scaffold) ; populated only after Julien drives a real Playwright capture. The pytest matcher cleanly skips per-vector when this field is null. |
| `expected_capture_date` | `string` | ISO `YYYY-MM-DD` UTC. Read by `tools/checks/estv_oracle_freshness.py` to flag staleness. |
| `source_url` | `string` | The ESTV calculator URL (`https://swisstaxcalculator.estv.admin.ch/...`). Stored per-vector for citation when a divergence is reported. |
| `source_label` | `string` | Human-readable combo label (`single_60k`, etc.). Mirrors the matrix entry. |

### Example line (after a real capture)

```json
{"id": "ZH__single_60k__age40", "canton": "ZH", "marital_status": "single", "gross_income_chf": 60000, "age": 40, "expected_tax_chf": 4327.50, "expected_capture_date": "2026-12-03", "source_url": "https://swisstaxcalculator.estv.admin.ch/#/calculator/income-wealth-tax", "source_label": "single_60k"}
```

## Lifecycle (CONTEXT D-10)

Any change to `expected_tax_chf` or `expected_capture_date` requires a **separate commit with prefix `fix(estv-oracle):`** so the audit log distinguishes oracle re-captures from ordinary feature commits. Example :

```
fix(estv-oracle): re-capture 2026-12 ESTV publication cycle (50 vectors)
```

The capture utility itself (`capture_estv_oracle.py`) overwrites the JSONL atomically. Re-runs are idempotent.

## 14-month freshness contract (CONTEXT D-13)

`tools/checks/estv_oracle_freshness.py` reads each line's `expected_capture_date` and emits a stderr `[freshness] STALE <id>` WARN line when a vector is older than 14 months (≈420 days). The lint exits 0 by default (WARN-only — annual capture cadence + occasional ESTV downtime should not block CI). A `--strict` flag is reserved for a future opt-in once the capture cadence becomes mechanical.

## 0-trust note (CLAUDE.md §9)

The fixture is shipped **EMPTY** on first commit (CALC-03 plan 92.5-03). `expected_tax_chf` populates only after Julien runs `python3 -m tests.scripts.capture_estv_oracle` with the operator-tuned Playwright selectors. Per the 0-trust protocol, we do NOT claim « ESTV oracle ready » until at least 1 vector with non-null `expected_tax_chf` is committed AND its matcher is observed PASSING in CI. The pytest runner cleanly auto-SKIPs when the fixture is empty or fully scaffolded.

> Citation : CONTEXT 92.5 D-11, CONTEXT 92.5 D-12, CONTEXT 92.5 D-13, CONTEXT 92.5 D-14.
