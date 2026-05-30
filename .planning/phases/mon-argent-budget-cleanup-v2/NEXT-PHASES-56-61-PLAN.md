# Next Phases 56-61 — Trust, Data Spine, QA

## Context
Phases 50-55 removed over-promising fiscal copy from visible budget, 3a, LPP, PDF, and sequence-summary surfaces. PR #682 is clean on GitHub at head `dcca18f01` before this plan.

## Expert Input Already Integrated
- Product/IA audit: Budget should answer monthly survivability; Mon Argent should answer liquid/debt/illiquid/property position; arbitrage comes after clean data.
- Architecture audit: avoid raw `profile.depenses.totalMensuel` on readiness, benchmark, streak, and report surfaces.
- QA audit: Maestro needs positive continuity assertions, not only absence of absurd values.

## Phase 56 — Remaining Visible Fiscal Trust Copy
Scope:
- Replace remaining user-facing/assistive `économie fiscale` copy in `couple_optimizer.dart` and `top_cantons_widget.dart`.
- Leave comments/internal field names for a later mechanical cleanup unless they leak to UI.

Acceptance:
- Targeted tests assert new indicative wording and reject old phrases.
- No calculation changes.

## Phase 57 — Navigation Readiness Uses Plausible Expenses
Scope:
- Replace readiness/custom-gate checks that use raw `profile.depenses.totalMensuel` with `BudgetInputs.plausibleMonthlyFixedExpensesFromProfile(profile)`.

Acceptance:
- A profile with impossible housing only does not satisfy readiness.
- Existing navigation tests pass.

## Phase 58 — Benchmark + Emergency Fund Plausibility
Scope:
- Use plausible monthly expenses for cantonal benchmark fixed charges and streak emergency-fund milestone.

Acceptance:
- Implausible housing is ignored, plausible LAMal/transport remain counted.
- Emergency-fund threshold no longer explodes on invalid rent.

## Phase 59 — Rapport V2 Uses Signed PresentBudget
Scope:
- Replace clamped `BudgetPlan.available` in Rapport V2 budget section with `PresentBudget.monthlyFree`.

Acceptance:
- Deficit months show negative free cash rather than CHF 0.
- Tests compare with Budget/Mon Argent read model semantics.

## Phase 60 — Coach Whisper Uses Real Monthly Free
Scope:
- Base 3a/cashflow whispers on signed `monthlyFree`, not clamped allocation `available`.

Acceptance:
- High available-before-savings but low free-after-savings does not trigger an oversized 3a suggestion.

## Phase 61 — Maestro Positive Continuity Assertions
Scope:
- Strengthen money trust chain Maestro flow with positive assertions for Budget, Mon Argent, and Coach values.

Acceptance:
- Flow asserts expected calculated values appear, not only that absurd numbers are absent.
- Regex kept tolerant where accessibility text is not yet stable.

## Deferrals
- Full Mon Argent IA redesign.
- Backend packet fallback cleanup.
- PDF design-token/fontSize debt.
- Internal variable/comment renames that do not leak to users.
