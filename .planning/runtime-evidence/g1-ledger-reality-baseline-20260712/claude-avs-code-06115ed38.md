# Claude external audit — AVS typed cashflow + UTC + migration — code — `06115ed38`

## Immutable scope

- Global G1 status: **8.2/10 — NO-GO**. This report does not authorize G2/G3.
- Exact range: `f029e0514...06115ed38` (`f029e0514214bc071fd0344a987b9f9cc5c06498` → `06115ed388c4a1b30abf24314efc83893fb75eca`).
- Command (first pass only; no rerun):

```sh
env CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-audit-06115ed38.MUIdLm/repo CLAUDE_AUDIT_MAX_DIFF_LINES=11000 CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh code f029e0514
```

- Wrapper: `tools/checks/claude_external_audit.sh` exclusively; no raw Claude command.
- Model / effort: **Opus / high**.
- Started UTC: `2026-07-13T16:16:14Z`; ended UTC: `2026-07-13T16:22:58Z`.
- Exit code: **0**; stdout: 43 lines; stderr: 0 lines.

## Clean detached-clone proof

- Detached clone: `/tmp/mint-g1-avs-audit-06115ed38.MUIdLm/repo`
- Base: `f029e0514214bc071fd0344a987b9f9cc5c06498`
- HEAD: `06115ed388c4a1b30abf24314efc83893fb75eca`
- `git status --short --branch`: `## HEAD (no branch)` before and after each audit
- `git diff --no-ext-diff --unified=80 f029e0514...HEAD | wc -l`: `10226`
- Diff stat: `32 files changed, 3001 insertions(+), 269 deletions(-)`
- The four pre-existing dirty files in the primary checkout were therefore absent from both prompts.

## External verdict and MINT triage

- Claude verdict: **NO-GO**.
- **P0: none.**
- **P1 confirmed — cross-tier AVS annualization drift.** Mobile now consistently distinguishes twelve ordinary recurring payments from the separate December supplement, but the live backend still builds a recurring annual figure with thirteen payments at `services/backend/app/services/retirement/avs_estimation_service.py:156-162`, uses it for cumulative and anticipation/deferral totals at `:179-212`, and activates the flat model at `services/backend/app/constants/social_insurance.py:208-215`. The result is exposed at `services/backend/app/api/v1/endpoints/overview.py:204-217` and `/avs/estimate` at `services/backend/app/api/v1/endpoints/retirement.py:40-46`. Exact annual fields have no mobile renderer hit, which limits immediate surface reach, but does not remove the contradictory live API contract. This is a global G1 blocker, even though the backend lines are pre-existing rather than introduced by the audited mobile-only range.
- **P2 confirmed — unsafe legacy decimal boundary.** `apps/mobile/lib/services/independants_service.dart:629-646` feeds a registry `double` directly into `ChfAmount.fromLegacyDouble`; `avs_thirteenth_pension_calculator.dart:10-23` throws for sub-centime precision. It is dormant behind a default-off local flag, so it is not P1 today.
- No audit carousel was started.

## Three previously known P2s

| Known P2 | Confirmation at `06115ed38` | Evidence / disposition |
|---|---|---|
| Generic independent-scenario owner | **CONFIRMED OPEN** | `apps/mobile/lib/services/independants_service.dart:635-646` hard-codes `ownerId: 'independant-self-scenario'` rather than the real person-owned ledger identity. Dormant behind the local-only flag, but must be fixed before activation. |
| Supplement fused without a dedicated renderer | **CONFIRMED OPEN** | `independants_service.dart:649-663` folds `eligibleOldAgeCashflowWithSupplementChf` into both projection totals. `lpp_volontaire_screen.dart:445-501` renders only those aggregate bars and never reads `avsThirteenthScenario`; `rg` finds no renderer outside the service/calculator. |
| Legal-zero precedence versus missing monthly sources | **NOT CONFIRMED AS OPEN — CLOSED IN THIS RANGE** | Production resolves an official December `notEntitled` zero before the missing-history failure at `avs_thirteenth_pension_calculator.dart:665-690`. Direct tests at `avs_thirteenth_pension_calculator_test.dart:1284-1316` prove both official not-entitled and pre-2026 legal zero beat unknown prior months while keeping the annual paid base null. |

## Captured stdout (verbatim)

~~~text
# MINT External Audit — G1 AVS 13th-Pension Migration

**Audit mode:** code · **Base ref:** `f029e0514` · **HEAD:** `06115ed38` · **Diff:** 32 files / ~3001 lines (within budget)

## Verdict: **NO-GO**

The mobile diff is high-quality and internally correct, but it ships **only the mobile half** of a first-pillar-pension model change. It flips the AVS annualization from `×13` to `×12 (December supplement separate)` on mobile while the **backend still computes `×13` into the recurring annual figure** and remains wired to live endpoints. This introduces a cross-tier drift on a headline compliance number, which is exactly what the documented §4 mirror invariant forbids (`docs/calculator-graph.md`: *"the backend mirrors… two calculators with different rounding arrive in prod"*). Before this diff both tiers agreed (`×13`); after it they disagree.

---

## P1 — Mobile/backend AVS annualization drift (incomplete cross-tier migration)

**Mobile now models the 13th as a separate December cashflow, recurring annual = `monthly × 12`:**
- `apps/mobile/lib/services/independants_service.dart:629-651` — `recurringAvsAnnualMax = reg('avs.max_annual_pension', avsRenteMaxAnnuelle)` (= 2520×12 = 30 240); the `×13` path only runs behind the off-by-default, non-backend-toggleable `enableAvsThirteenthScenarioCashflow`.
- `apps/mobile/lib/widgets/coach/avs_gap_widget.dart` — `_lifetimeLoss` now `ordinaryRecurringLifetimeLoss(_renteLoss, 20)` (12 months).
- `apps/mobile/lib/l10n/app_*.arb` `avsGapCalculation` (all 6 locales): *"monthly pension × 12 months. The separate December AVS supplement is **not included**."*

**Backend still bakes the 13th into `rente_annuelle` and is live:**
- `services/backend/app/services/retirement/avs_estimation_service.py:161-162` — `nb_rentes = AVS_NOMBRE_RENTES_PAR_AN … ; rente_annuelle = rente_mensuelle * nb_rentes` (×13).
- `:181` `total_cumule = rente_annuelle * duree` and `:212` user-facing `premier_eclairage`: *"CHF {rente_annuelle}/an **(13 rentes)**"*.
- `services/backend/app/constants/social_insurance.py:214` `AVS_13EME_RENTE_ACTIVE = True`.
- Wired to clients: `services/backend/app/api/v1/endpoints/overview.py:207-217` (`values["avsRenteAnnuelle"] = round(avs.rente_annuelle)`) and `endpoints/retirement.py:40` (`POST /avs/estimate`).

**Reproduction:** `POST /api/v1/retirement/avs/estimate` (max profile) → response `rente_annuelle ≈ 32 760` + `premier_eclairage` containing `"(13 rentes)"`, while the mobile AVS-gap widget and independants projection assert `× 12` and explicitly tell the user the December supplement is excluded. Same user, same quantity, two contradictory answers.

**Mitigating factor (verified):** mobile currently reads only `avsRenteMensuelle`, not `avsRenteAnnuelle` (`Grep` across `apps/mobile` returns no `avsRenteAnnuelle` consumer), so the contradictory *annual* value is not presently rendered by a mobile screen. I could **not** confirm whether `/avs/estimate`'s `premier_eclairage`/`total_cumule` is rendered.

**What would flip this to PASS:** either (a) align `avs_estimation_service.py` + constants to the same "12 recurring + separate December" model in the same change set, or (b) prove the backend `rente_annuelle`/`premier_eclairage`/`total_cumule` fields are dead on all clients and file the backend follow-up. Concretely: `grep -rniE "avsRenteAnnuelle|premierEclairage.*rente|renteAnnuelle|totalCumule" apps/mobile/lib` — a clean result on rendered surfaces downgrades this to P2.

---

## Confirmed correct / no action (audited, PASS-quality)

- **No dangling references.** Removed symbols (`annualRente`, `avs13emeRenteActive`, `avsNombreRentesParAn`, `avs13emeRenteFactor`, `avsRenteMaxAnnuelle13m`, `avsMaxAnnualRenteForYear`, `avsMaxRenteAnnuelleForYear`) have zero remaining consumers in `apps/` (verified via `Grep`). Remaining `annualRente` hits are all `LppCalculator`. Build is clean.
- **Transition-phase fix is a genuine correctness gain.** Old `retirement_projection_service.dart` did `annualRente(monthly)/12 = monthly×13/12`, inflating a *monthly* income line by +8.33%. Now uses `monthly` directly (`:662`, `:747`). Correct.
- **Fail-closed dormancy is sound.** `AvsThirteenthPensionCalculator` (938 lines) is only reachable behind `enableAvsThirteenthScenarioCashflow = false`, correctly **excluded from `applyFromMap`** (`feature_flags.dart:71-75`) so backend flags can't promote an educational scenario to an entitlement. Not a facade risk — the wired production path (flag off, `×12`) is correct, and the calculator carries 1460 lines of tests with cent-exact rounding matching `_roundTwelfthToCent`/`_roundToWholeFranc` (spot-checked cases 04/05: 105.50→106, 317.49→317).
- **AVS couple legal changes are improvements, not regressions.** New `bothDisability` block (`avs_calculator.dart`) fails closed for married/registered AI+AI pending the LAI art. 37 al. 1bis cap provider (previously returned an uncapped sum); ordinary old-age now requires `pensionPercentage == 1`. Both fail-closed, both covered by updated `avs_couple_legal_contract_test.dart`.
- **l10n consistency is test-guarded.** `avs_gap_widget_test.dart` asserts all six ARB locales drop `×13`, keep `12`, and mention the separate December supplement.

## P2 — minor
- **`ChfAmount.fromLegacyDouble` can throw on a 3+ decimal `reg('avs.max_monthly_pension')` override** (`independants_service.dart:641`), crashing `calculateLppVolontaire`. Reachable only when the local-only flag is on, so latent, but the calculator is otherwise rigorously fail-closed — this one legacy-boundary path throws instead of returning a `providerCorrectionRequired` result.

**Bottom line:** the mobile change is correct in isolation; the blocker is that a live backend service still asserts the pre-migration `×13` annual AVS, contradicting the diff's own thesis and the §4 mirror invariant. Align or prove-dead the backend before shipping.
~~~

## Captured stderr (verbatim)

~~~text
~~~

## Gate disposition

**NO-GO.** The typed mobile foundation is an improvement, but the confirmed backend cross-tier P1 and the two still-open activation P2s prevent acceptance. G1 remains **8.2/10 NO-GO**.
