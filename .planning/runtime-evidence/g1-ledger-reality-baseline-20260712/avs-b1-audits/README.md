# AVS B1 — bounded external-audit manifest

Date: 2026-07-13

Goal: G1 Ledger Reality Baseline

Scope: archive-only record of the B1 AVS external reviews; this directory does not promote a gate ticket or accept G1.

## Audit construction

The B1 production and test changes were rearranged into **synthetic audit-only commits** so each Claude prompt stayed bounded and reviewable. These commits are evidence carriers, not product-history commits and not promotion candidates. The raw Opus outputs in this directory are byte-for-byte copies of the named `/tmp` files; they have not been edited to harmonize later findings.

The production-only slices deliberately excluded their companion tests. Consequently, the early code reviews correctly observed a red delivered state for those isolated slices, but their “tests do not compile / gating is untested” P0s were **temporary synthetic-slice P0s**, not unresolved findings in the final combined B1 state. The following test slices supplied and reconciled those tests. The first test slice then exposed a real contradictory married-without-`conjoint` contract; the second test slice resolved it and received `PASS`.

One raw heading names base `fb93a93aa`; that object does not exist. The verified base is `fb39a93aa` and the raw file is intentionally left unchanged.

## Slice chain and verdicts

| # | Raw output | Lens | Synthetic diff | Diff stat / unified=80 | Verdict | Manifest interpretation |
|---|---|---|---|---|---|---|
| 1 | `mint-g1-avs-b1-prod-code-opus.txt` | code | `fb39a93aa...56c4daea2` | 5 files, +187/−129; 2,565 lines | NO-GO | Initial production-only audit. Its test-compilation/coverage P0s were temporary because tests were intentionally outside this bounded slice. It also found product-wiring risks that required later production correction and product review. |
| 2 | `mint-g1-avs-b1-prod-product-opus.txt` | product-domain | `fb39a93aa...56c4daea2` | 5 files, +187/−129; 2,565 lines | NO-GO | Initial product audit. It caught renderable AVS-less timelines plus Forecaster, missing CTA, and couple-readiness problems. The misleading timeline P0 was subsequently removed; the P1 themes were re-audited below. |
| 3 | `mint-g1-avs-b1-final-prod-code-opus.txt` | code | `fb39a93aa...c53981c2` | 5 files, +211/−147; 2,589 lines | NO-GO | Finalized production isolated from tests. Both P0s are the expected temporary consequence of that synthetic separation: nullable API tests were absent and certificate gating had no tests inside this slice. |
| 4 | `mint-g1-avs-b1-final-tests1-code-opus.txt` | code | `c53981c2...f1d008e2e` | 3 files, +256/−44; 2,153 lines | NO-GO | Projection tests were added and passed, but the audit found an opposite sibling contract for `marié` without a `conjoint`. This was a real test-contract inconsistency, not a production P0, and was fixed in the next bounded test slice. |
| 5 | `mint-g1-avs-b1-final-tests2-code-opus.txt` | code | `f1d008e2e...adb97e47e` | 6 test files, +81/−12; 1,159 lines | **PASS** | Final test reconciliation: P0 none, P1 none; all affected tests executed green and assertions matched production fail-closed wiring. This closes the temporary/code-test blockers from slices 1, 3, and 4. |
| 6 | `mint-g1-avs-b1-final-prod-product-opus.txt` | product-domain | `5d1ea2d9d...cc72d5185` | 5 files, +211/−147; 2,589 lines | **NO-GO** | Final product review with the reconciled tests in the synthetic baseline. No P0 remains. Acceptance is still blocked by the P1s below. |

Synthetic chain details:

- `56c4daea2` is an initial production carrier with parent `fb39a93aa`.
- `c53981c2` is the finalized production carrier with parent `fb39a93aa`.
- `f1d008e2e` adds projection tests on `c53981c2`.
- `adb97e47e` adds/reconciles the remaining consumer/model tests on `f1d008e2e`.
- `5d1ea2d9d` is a final audit baseline containing reconciled tests/evidence on `fb39a93aa`; `cc72d5185` applies the finalized production slice to that baseline.

## Final gate state

**Code/test evidence:** the final bounded test slice is `PASS` with no P0/P1.

**Product/domain evidence:** still `NO-GO`, with no P0 and these remaining P1 blockers:

1. **Forecaster divergence:** `ForecasterService` still treats absent AVS gap evidence as zero/estimated while `RetirementProjectionService` requires certified readiness, creating two AVS truths for one household.
2. **Non-AVS subtotal and DataQuest handoff:** the valid LPP/3a/libre subtotal is computed but not delivered as explicit partial lucidity; `missingFields`/`avsIncluded` do not reach a clear “certify the AVS extract” CTA or specialist/data-collection handoff.
3. **Concubin readiness:** concubinage incorrectly requires certified partner AVS gaps to unlock the user's own AVS projection, although the 150% married-couple cap does not apply to concubins and each AVS rente is individual.

The raw final product audit also records P2 observations. They do not change the gate: G1/B1 remains blocked on the P1s above. No ticket is promoted by this manifest.

## Integrity

`SHA256SUMS` covers only the six immutable raw outputs. Recompute from this directory with:

```bash
shasum -a 256 -c SHA256SUMS
```
