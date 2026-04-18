# Wave 7 — Actuarial/mathematical audit
*Scope: arbitrage_engine, monte_carlo_service, withdrawal_sequencing_service, tornado_sensitivity_service*

Auditor: actuarial + numerical methods review, read-only.
Reference: SIA 2020 mortality table, LPP technical rate 2.5–3.5%, CH equities long-run σ ≈ 14–16%, CH bonds σ ≈ 4–5%, CH CPI μ ≈ 0.5–1.2% / σ ≈ 0.7% (SNB 2010-2024 sample).
Golden couple: Julien 49 / swiss_native / VS / 122k / LPP 70'377. Lauren 43 / expat_us / VS / 67k / LPP 19'620.

---

## Executive summary
- Files audited: 4 (total 3'930 LoC)
- **P0 count: 6** | **P1 count: 11** | **P2 count: 5**
- One-line verdict: **BLOCK**. The Monte-Carlo LPP vol (σ=3%) and free-portfolio vol (σ=8%) materially understate Swiss-equity risk; inflation is drawn once-per-trajectory (kills sequence-of-returns realism); the mixed-trajectory cashflow mixes nominal rente with deflated tax; the withdrawal sequencer schedules the largest 3a account FIRST (anti-optimal vs LIFD progressive brackets); Julien's EPL ATF ruling (rachat 3-year blocage BEFORE EPL) is not encoded anywhere in the rachat arbitrage; tornado ignores couple-AVS cap and cantonal tax variance which are often top-3 drivers.

---

## Findings per file

### arbitrage_engine.dart

**P0-A1 — Mixed trajectory mixes nominal rente cashflow with deflated tax**  (arbitrage_engine.dart:1844-1862)
Evidence:
```dart
final realRente = renteObligatoire / math.pow(1 + inflation, y);   // DEFLATED
final renteTax = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: realRente, …) * 12;                   // tax on deflated base
…
final totalNominalCashflow = renteObligatoire - renteTax + capitalWithdrawal;   // NOMINAL rente − real-base tax
cumulativeCashflow += totalNominalCashflow;
…
final realPatrimony =
    (capitalNet + cumulativeCashflow) / math.pow(1 + inflation, y);
```
Why it breaks: Two inconsistencies compound:
1. `renteObligatoire` (nominal, never indexed since LPP rentes are not indexed) is used gross, but the income tax is computed against `realRente` (deflated). Progressive income tax on a deflated base is lower than on the nominal base the user actually receives, so `totalNominalCashflow` is overstated by `(nominalTax − realTax)` each year.
2. `totalNominalCashflow` is added to `cumulativeCashflow` without deflation; then the whole cumulative is deflated once at year *y*. This double-counts inflation relative to the rente-only trajectory (`_buildRenteTrajectory` adds `netAnnual` of a *deflated* rente to `cumulativeCashflow` and never redeflates). The two trajectories are therefore not apples-to-apples and Option C ("Mixte") can appear strictly dominant on Julien's 30-year horizon purely from accounting drift of ~6-8% at horizon with inflation=2%.
Fix: pick one convention and apply it to both builders. Recommended: deflate the rente at each step (as `_buildRenteTrajectory` already does) and add `realRente - realTax + realCapitalWithdrawal` to `cumulativeCashflow`; drop the final `/ pow(1+inflation, y)` on cumulative. Apply the same change to `_buildRenteTrajectory` so both methods are symmetric.

**P0-A2 — ATF 142 II 399 / 148 II 189 rachat-EPL 3-year anti-abuse rule never enforced in rachat-vs-market arbitrage**  (arbitrage_engine.dart:1138-1401 and 513-535)
Evidence: the only reference to the 3-year lock is the label/source string (`'LPP art. 79b al. 3 (blocage 3 ans)'`) and a `blocageYears = 3` that is passed to `_buildAllocationTrajectory` but *never consumed* inside that helper (grep confirms the parameter is declared at line 1892 and never referenced in the body lines 1893-1941). The function performs no withdrawal-within-blocage check, no tax reversion, no alert.
Why it breaks: ATF 142 II 399 (reaffirmed by 148 II 189, 2022) treats a rachat followed by an EPL retrait within 3 years as abuse: the federal tax authority reverses the deduction. For Julien (49, VS, 539k lacune, planning housing purchase at 52 per his profile notes), this is the #1 tax trap MINT exists to flag. Presenting a "rachat + invest" option without surfacing the abuse risk violates the protection-first doctrine.
Fix: (1) accept a `plannedCapitalWithdrawalAge` int? and a `retraitAge = currentAge + anneesAvantRetraite - blocageYears` check; (2) if any 3a or LPP capital withdrawal is planned within 3 years of the rachat, reverse `taxSavingRachat` in the terminal snapshot *and* emit an `alertes` entry citing ATF 142 II 399 + 148 II 189; (3) same check in `compareAllocationAnnuelle` option 2.

**P0-A3 — `capitalEpuiseAge` heuristic is structurally wrong** (arbitrage_engine.dart:352-366)
Evidence:
```dart
if (i > 1 && snap.annualCashflow < capitalTrajectory[1].annualCashflow * 0.1) {
  capitalEpuiseAge = ageRetraite + i;
  break;
}
```
Why it breaks: `_buildCapitalTrajectory` uses a Trinity-Study fixed-dollar SWR (line 1782 `initialWithdrawal = capitalNetAtStart * tauxRetrait`), then inflates the *nominal* withdrawal each year (`initialWithdrawal * pow(1+inflation, y-1)`). The cashflow is then *deflated* to real terms at line 1792 (`realCashflow = actualWithdrawal / pow(1+inflation, y)`). So in real terms, `realCashflow` is ~constant every year UNTIL the capital runs out and `actualWithdrawal` gets capped by `min(nominal, max(0, capitalNet))`. The trigger "annualCashflow < 10% of year-1 cashflow" can fire 1-3 years LATE (after the capital went to zero), or NEVER fire if the capital never runs out on the horizon. For Julien's 539k net capital + 3% return + 4% SWR + 30y horizon, the capital drops to ~0 between year 28 and year 30, which produces exhaustion at `ageRetraite + ~29 ≈ 94`, but the 10%-heuristic may only trigger at year 30+ (horizon cap) → `capitalEpuiseAge = null` displayed as "capital jamais épuisé", a false reassurance.
Fix: track `capitalNet` explicitly in a parallel list or in the snapshot (add `residualCapital` field), and set `capitalEpuiseAge = retirementAge + y` on first iteration where `capitalNet <= 1.0`. If never exhausted in the horizon, return the horizon age with a flag `stillHasCapital=true`.

**P1-A4 — `_findBreakevenYear` uses wrong metric for rente-vs-capital crossover**  (arbitrage_engine.dart:2031-2054, caller 195-196)
Evidence: breakeven is computed on `netPatrimony`. But `_buildRenteTrajectory` stores `netPatrimony = cumulativeCashflow` (cumulative net income received, no residual asset) while `_buildCapitalTrajectory` stores `netPatrimony = realPatrimony` (remaining invested capital, NOT cumulative cashflow). These are two different quantities with different units (income-stock vs asset-stock). A user-facing "trajectoires se croisent vers 78 ans" (line 411) is therefore *not* a breakeven in the usual sense (point where cumulative cash of option A exceeds option B).
Why it breaks: in the golden couple, Julien's rente yields ~34k/yr; the capital trajectory residual starts at ~490k and erodes. They "cross" at the point where cumulative rente income (~34k × N) equals remaining capital, not where they become economically equivalent. Misleading.
Fix: either (a) make breakeven operate on `cumulativeNetIncome(option A) vs cumulativeNetIncome(option B)` — consistent with the `capitalTotalValue = cumulativeWithdrawals + residual` hero metric at line 386, or (b) rename to `patrimoineCrossoverYear` and make clear it is a wealth-curve crossing, not an economic-equivalence point.

**P1-A5 — Free-market wealth tax is a flat 0.3% scalar, ignoring canton + Vermögenssteuer progressivity**  (arbitrage_engine.dart:1207-1209)
Evidence:
```dart
final wealthTax = balanceMarche * 0.003;
balanceMarche -= wealthTax;
```
Why it breaks: Swiss wealth tax (Vermögenssteuer / impôt sur la fortune) is cantonal, progressive, and ranges from ~0.15% (ZG, SZ) to ~0.6%-0.85% (GE, BS, VD top brackets). A flat 0.3% under-taxes VS/GE residents by 40-150% and over-taxes ZG/NW residents by 50-100%. On a 30-year horizon compounding, a 0.3% mis-estimate on a 1M portfolio drifts by ~30k-90k terminal — big enough to flip the rachat-vs-market winner.
Fix: introduce `wealthTaxByCanton: Map<String, double>` sourced from AFC 2024 (mirror the existing `_effectiveRates100k`), progressivity brackets at 1M / 3M / 5M, married discount. Use `canton` parameter already in signature.

**P1-A6 — Valeur locative applied at full rate with no federal Eigenmietwert discount**  (arbitrage_engine.dart:920-922)
Evidence: `final valeurLocative = tempVal * tauxVL;` uses the full cantonal rate with no adjustment. But the Bundesgericht Urteil 2A.298/2003 and LIFD art. 21 al. 2 authorize a reduction to ~60-70% of market rental value (Bundessteuer) to account for the "auto-consommation". Cantons apply different effective ratios (ZH ~70%, VD ~65%, GE ~60%, VS ~70%).
Why it breaks: overestimates the taxable income by 30-40%, dragging Option B (Acheter) unfairly. For Julien buying a 1.2M chalet in VS at 2.5% nominal rental ≈ 30k VL, the federal portion should be taxed on ~21k not 30k. Roughly 2-3k/year tax, ~50-70k terminal-value drift over 20 years.
Fix: use the `HousingCostCalculator.getValeurLocativeRate(canton)` output only AFTER applying the 60-70% federal abatement; or better, delegate the whole VL calculation to `HousingCostCalculator` (single source of truth).

**P1-A7 — Canton-less retrieval path defaults to ZH silently, biasing VS Julien**  (arbitrage_engine.dart:483, 1145, 1418)
Evidence: `String canton = 'ZH'` default on `compareAllocationAnnuelle`, `compareRachatVsMarche`, `compareCalendrierRetraits`.
Why it breaks: if the caller omits `canton`, the cantonal tax factor defaults to ZH, which has the *lowest* capital-withdrawal tax (~0.065 baseRate). A Valaisan will see ~15-20% less tax than reality → rachat option looks better than it actually is. No-shortcut doctrine: defaults must be either explicit or raise in debug mode.
Fix: make `canton` a required argument on all three public APIs. Callers must always pass it from CoachProfile (which has a guaranteed non-null canton via onboarding).

**P1-A8 — Terminal-snapshot adjustment in `_buildAllocationTrajectory` uses `balance` after post-loop contribution, but reports `netPatrimony` that double-counts `cumulativeTaxSaving`**  (arbitrage_engine.dart:1926-1938)
Evidence:
```dart
// Loop already adds cumulativeTaxSaving into snapshot.netPatrimony (line 1919)
…
// After loop, overwrite terminal snapshot:
snapshots[snapshots.length - 1] = YearlySnapshot(
  …
  netPatrimony: (balance - withdrawalTax) + cumulativeTaxSaving,   // tax saving re-added
  cumulativeTaxDelta: withdrawalTax - cumulativeTaxSaving,
);
```
Why it breaks: Within the loop `netPatrimony = balance + cumulativeTaxSaving`. The rewrite at line 1935 keeps the `+ cumulativeTaxSaving`. This is *correct* for the 3a option but treats the tax saving as a permanently held liquid asset — in reality, the annual tax saving of CHF ~1'700 (3a × 25% marginal) was received the year after the contribution and will have been invested/consumed. Not flagged as P0 because it is consistent across options, but the hypothesis should be stated ("l'économie d'impôt est réinvestie à taux zéro") and ideally the tax saving should compound at `rendementMarche` to reflect its opportunity cost.
Fix: either compound `cumulativeTaxSaving` each year at `rendementMarche`, OR deflate it to t=0 present value, OR add a hypothesis line "économies d'impôt annuelles supposées détenues en cash sans rendement".

**P1-A9 — `amort_indirect` implicit return is hard-coded 2%, ignores caller-passed `rendement3a`**  (arbitrage_engine.dart:1958)
Evidence: `const rendement3a = 0.02;` is a magic constant inside `_buildAmortIndirectTrajectory`, independent of the `rendement3a` parameter on the public `compareAllocationAnnuelle` API. The two diverge silently.
Why it breaks: a caller setting `rendement3a=0.05` (VIAC Global 100) sees the 3a option compound at 5%, but the amortissement-indirect option (which IS a 3a) compounds at 2%. The comparison between "Option 1: 3a @ 5%" and "Option 3: Amort indirect @ 2%" is apples-to-oranges and invalidates the premier éclairage.
Fix: `_buildAmortIndirectTrajectory` must accept `rendement3a` as a parameter and use the caller-provided value.

**P1-A10 — Tornado sensitivity width for `tauxConversion` is ±0.5 percentage points, far below real-world variance**  (arbitrage_engine.dart:283-325)
Evidence:
```dart
final tcObligLow = math.max(reg('lpp.conversion_rate_min', …), tauxConversionObligatoire - 0.005);
final tcObligHigh = tauxConversionObligatoire + 0.005;
```
Why it breaks: the actual legislative debate (AVS 21, LPP reform) has moved the *proposed* obligatoire rate in a range of 6.0%-6.8% (80 bps), and surobligatoire across caisses ranges 4.5%-6.5% (200 bps). A ±50 bps tornado is cosmetic; users miss that they are assuming a specific trajectory of the federal rate. Downstream consequence: the tornado ranks `tauxConversion` as a minor driver when it is structurally among the top 3.
Fix: widen to ±100 bps for obligatoire (or scenario-based: low=0.06 per the rejected 2017 reform, high=0.068), ±200 bps for surobligatoire. Floor at 0 and cap at 0.08.

**P2-A11 — `_effectiveRates100k` hard-coded inside `tax_calculator` and duplicated conceptually in arbitrage hypotheses display**  (tax_calculator.dart:270-278 + arbitrage_engine.dart:428)
Evidence: `'Canton : $canton'` is displayed as an opaque string; users don't see the cantonal effective rate impact. Minor UX gap.
Fix: display "Canton : VS (taux effectif ~14.6% @ 100k)" — sourcing the rate from the map.

---

### monte_carlo_service.dart

**P0-M1 — LPP return σ=3% grossly understates Swiss pension-fund volatility**  (monte_carlo_service.dart:187-188, 289-290)
Evidence:
```dart
final lppReturnYear = _normalRandom(random, mean: 0.02, sd: 0.03);
```
Why it breaks: Swiss pension funds (average balanced portfolio ~30-40% equities + bonds + real estate) have historical σ of ~6-8% on annual returns (Pictet BVG-25 index 2000-2024: σ ≈ 6.5%; Credit Suisse Pension Fund Index: σ ≈ 7.1%). σ=3% is roughly half the empirical figure and produces Monte-Carlo bands that are ~50% too narrow on LPP balance at retirement. Julien's p90-p10 band at 65 should be ~[390k, 820k] if based on historical vol; current code produces roughly [500k, 720k]. This is a **confidence miscalibration** — the app tells users the future is more certain than it is, violating protection-first.
Fix: σ=0.065 (or load from a settings table `monte_carlo.lpp_sigma`). Document source (Pictet BVG-25 or Credit Suisse PK Index). Reduce mean to 0.015 to reflect 2020-2024 prevalent technical rates (2.5%-3.5%) minus frais de gestion.

**P0-M2 — Inflation drawn ONCE per trajectory instead of per year — kills sequence-of-returns analysis**  (monte_carlo_service.dart:124-125)
Evidence:
```dart
// Sim-level draws (stable over lifetime — reasonable simplification):
final inflationRate = _normalRandom(random, mean: 0.012, sd: 0.005).clamp(0.0, 0.05);
```
Why it breaks: the comment claims "reasonable simplification" but this is actually the **dominant** source of Monte-Carlo miscalibration. Real inflation is mean-reverting AR(1)-ish with annual σ ≈ 0.7% *around* a slow-moving regime mean. Drawing a single inflation rate per path collapses the cross-sectional variance into path-level constants, artificially compressing the tail. For a 30-year horizon a trajectory with inflation clamped at 0.5% vs one at 3.5% has completely different real withdrawals; tying that to 1 single draw means each sim is either "low-infl regime forever" or "high-infl regime forever", with zero transition risk. Ruin probability is therefore biased (typically overstated at the center of the distribution, understated in the tails).
Fix: make `inflationRate` a vector `List<double>` of length `_projectionYears`, drawn per-year (AR(1): `infl_t = 0.7*infl_{t-1} + 0.3*mean + noise`, with noise σ=0.007). Apply the same to `avsIndexation`. Minimum: independent draws per year.

**P0-M3 — `lifeExpectancy = 82 + nextInt(14)` is uniform, wrong distribution**  (monte_carlo_service.dart:126)
Evidence:
```dart
final lifeExpectancy = 82 + random.nextInt(14); // 82-95
```
Why it breaks: this is a uniform [82, 95] distribution. Real age-at-death for 65-year-old Swiss individuals conditional on reaching 65 follows roughly a Gompertz-Makeham distribution with median ≈ 86 (male) / 89 (female) per SIA 2020. The uniform draw:
1. Gives *zero probability* of death before 82, which is non-negligible (~8-10% of 65-year-olds will die before 82).
2. Gives *zero probability* of death after 95, missing the ~5-7% of long-lived retirees who drive the late-life ruin risk most.
3. Makes the distribution gender-neutral and cohort-neutral (same for Julien 49 male and Lauren 43 female expat).
Fix: pre-compute a SIA 2020 cumulative survival vector `q_x` for ages 65-110 by gender, use inverse-CDF sampling: `lifeExpectancy = inverseSurvivalSample(qx, rng, gender)`. Fallback constants in `social_insurance.dart`.

**P0-M4 — Percentile envelopes computed from per-year marginal distributions produce **non-monotonic** p10/p50/p90 paths**  (monte_carlo_service.dart:468-480)
Evidence:
```dart
for (int y = 0; y < _projectionYears; y++) {
  final values = results.map((sim) => sim[y]).toList()..sort();
  projection.add(MonteCarloPoint(
    year: retirementYear + y, …
    p10: _percentile(values, 0.10),
    p50: _percentile(values, 0.50),
    p90: _percentile(values, 0.90),
  ));
}
```
Why it breaks: the p10 trajectory shown to the user is *not* a single simulation path — it is the year-by-year 10th-percentile of the cross-section. The simulation ranked 10th in year 5 is probably not the same path ranked 10th in year 20. The "p10 curve" can therefore rise even though no simulation ever rose on its p10 path. For ruin analysis this is crucial: the user assumes "this is my worst-case path"; it is not.
Fix: compute *fan charts* correctly (this is what you have — label it as such) AND expose a second primitive: `worstPaths` = top 10% ruined paths shown as spaghetti, OR report p10 on a scalar summary (e.g., p10 of terminal wealth) not as a "trajectory". At minimum, add a disclaimer line: "Les courbes p10/p90 sont des enveloppes statistiques, non des scénarios individuels."

**P1-M5 — Free-portfolio return σ=8% is under-calibrated for Swiss equity exposure**  (monte_carlo_service.dart:388, 399)
Evidence: `_normalRandom(random, mean: 0.04, sd: 0.08)` for free wealth.
Why it breaks: 4% mean / 8% σ corresponds to a ~40/60 balanced portfolio. Empirical SPI σ ≈ 14-16%, MSCI World CHF-hedged σ ≈ 12-14%. For a retiree holding individual CH equities or a 60/40 SPI/bonds split, true σ is 10-12%. σ=8% understates equity risk by ~30-50%, narrowing the p10-p90 band on terminal wealth. Couples with concentrated CH equities (Julien scans mention VIAC Global 100 = 100% equities) see particularly understated tail risk.
Fix: parameterize via `profile.investmentAllocation` with three regimes (cash 2%/0.5%, balanced 4%/8%, equity 6%/14%); default to balanced. Cross-ref: see UBS House View or SIX SPI historical series.

**P1-M6 — AVS indexation mixed with rente indexation violates the "LPP rente NOT indexed" rule**  (monte_carlo_service.dart:407-409 vs 411-412)
Evidence: `avsConjointThisYear = avsConjointMonthly * pow(1 + avsIndexation, y)` but `lppRenteThisYear = lppMonthly` (no indexation). Correct legally (AVS is indexed, LPP is not). But the `avsUserThisYear` logic at 403-404 applies `avsIndexation` from `y - yearsUntilAvsUser` — meaning AVS is *not* indexed during the pre-63 gap. Practical issue: if a user retires at 58, AVS will have had 5 years of CPI accretion when it *does* start (Bundesamt indexiert AVS alle 2 Jahre); this model starts AVS at its current nominal value and only indexes post-activation. Understates AVS nominal ≈ 10-12% over 5 years of 2% CPI.
Fix: apply indexation from year 0 regardless of when AVS starts paying. `avsUserThisYear = avsUserMonthly * pow(1 + avsIndexation, y) when y >= yearsUntilAvsUser; 0 otherwise`.

**P1-M7 — `conjointRetirementAge` hard-set to male age 65, ignores Lauren's 64/65 transition (AVS 21)**  (monte_carlo_service.dart:109)
Evidence: `final conjointRetirementAge = reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();`
Why it breaks: AVS 21 (entered into force 2024) raised women's reference age progressively to 65 by 2028 cohort (Lauren, born 1982, reaches 65 in 2047 — so her reference age IS 65). However, for older female conjoints born before 1961, this is wrong. More importantly the single-line override `avs.reference_age_men` is hard-coded to male and ignores `conjoint.gender` which is available on line 154 for AVS computation but not used for the retirement-age decision. Creates inconsistency: AVS is computed with female adjustments but retirement trigger is male-age.
Fix: compute `conjointRetirementAge` using `AvsCalculator.referenceAgeFor(gender, birthYear)` — the helper already exists in the codebase (line 151 of social_insurance.dart per grep).

**P1-M8 — Rachat LPP buyback matching via firstName string search is brittle + silently zero on anonymous profiles**  (monte_carlo_service.dart:272-283, 354-365)
Evidence:
```dart
final conjName = conjoint.firstName?.toLowerCase() ?? '';
if (conjName.isEmpty) { conjAnnualBuyback = 0; }
else { … .where((c) => c.id.toLowerCase().contains(conjName) || c.label.toLowerCase().contains(conjName)) … }
```
Why it breaks: string-match on `firstName.toLowerCase().contains(...)`: (a) collides when user=`alex` and conjoint=`alexandra`, (b) silently returns 0 for any anonymous or Tier-3.5 local-mode user (firstName often null in that flow). The Monte Carlo then understates conjoint LPP by the full planned buyback amount, which for Lauren (52'949 lacune over 10 years ≈ 5'295/yr) is material. No-shortcut doctrine violated: attribution must be explicit, not heuristic.
Fix: add explicit `ownerId: 'user' | 'conjoint'` field on `PlannedContribution`; match on that. Migration: infer `ownerId` once on schema upgrade, never again via string search.

**P1-M9 — 3a drawdown `/ 20 years` is deterministic — ignores longevity risk**  (monte_carlo_service.dart:334)
Evidence: `threeAMonthly = threeANet > 0 ? threeANet / _pillar3aDrawdownYears / 12 : 0.0;` with `_pillar3aDrawdownYears = 20.0`.
Why it breaks: spreading 3a capital evenly over 20 years (retirement 65 → 85) means at 85+ the user has zero 3a income, regardless of the `lifeExpectancy` draw. For simulations where lifeExpectancy = 92, the user has 7 years of *zero* 3a income where the ruin check compares to 50% of inflated expenses — artificially increases `ruinCount`. Overestimates ruin probability in long-lived paths.
Fix: implement annuity-like drawdown using the sampled lifeExpectancy (or a conditional expectancy at age(y)), or implement a Trinity-style constant-real withdrawal against the 3a pool in addition to the capital pool. Simpler: `drawdownYears = lifeExpectancy - retirementAge` so each sim's 3a is spread over its own horizon.

**P1-M10 — `_normalRandom` returns raw Box-Muller, but only positive tail used via `.clamp` — introduces upward bias**  (monte_carlo_service.dart:320-322)
Evidence:
```dart
final threeAReturn = _normalRandom(random, mean: baseReturn3a, sd: baseReturn3a * 0.5).clamp(0.0, 0.10);
```
Why it breaks: for `baseReturn3a = 0.02`, the normal(0.02, 0.01) distribution has ~2.3% density below 0. Clamping at 0 creates a point mass, shifting the effective mean upward by ~0.02 × P(x<0) ≈ 5 bps. More dramatic for `baseReturn3a = 0.05` (VIAC Global): N(0.05, 0.025), ~2.3% density below 0, mean shifts up by ~0.01 × 0.023 ≈ negligible. BUT the 0.10 cap at the top removes ~2.3% on the other side, creating asymmetric bias depending on distance from the bounds.
Fix: use a proper truncated-normal sampler (rejection) OR switch to log-normal returns (closer to empirical behavior): `r_t = exp(N(μ, σ)) - 1`, which naturally bounds at -100% and has unbounded positive tail.

**P1-M11 — Capital-SWR drawdown compounds real withdrawal cap with nominal return — amplifies errors**  (monte_carlo_service.dart:417-419)
Evidence:
```dart
lppCapitalMonthly = lppCapitalNet * _safeWithdrawalRate / 12;
lppCapitalNet *= (1 + libreReturnYear - _safeWithdrawalRate);
```
Why it breaks: this mixes the 4% SWR (a real-terms withdrawal rate) with a nominal `libreReturnYear` (raw Box-Muller draw with mean 0.04 but unclamped, so can go negative). `libreReturnYear - 0.04` can easily be negative double-digits; `lppCapitalNet *= negative factor` makes the balance flip sign, which the `if (lppCapitalNet < 0) lppCapitalNet = 0;` guard catches (line 419), but the single-year check `totalMonthly < inflatedExpense * 0.5` at line 457 has already fired a ruin. More subtly: the SWR is not inflation-adjusted on the cash side — user receives a nominal `_safeWithdrawalRate * lppCapitalNet_year0` forever, not an inflation-indexed amount. In real terms after 20 years at 2% CPI, `lppCapitalMonthly` has lost 33% purchasing power without reflecting in the ruin test (which uses `inflatedExpense`).
Fix: replicate the Trinity Study correctly — `withdrawal_t = withdrawal_0 * (1+infl)^t`, deduct from capital, grow remaining at nominal return. OR express entire simulation in real terms with `realReturn = nomReturn - infl`. Pick one and be consistent.

**P2-M12 — `numSimulations` default 1000 but doc says "500 (défaut)"**  (monte_carlo_service.dart:62-69)
Evidence: dartdoc says "nombre de simulations (defaut 500)" at line 62; signature says `int numSimulations = 1000` at line 69.
Fix: doc drift; align to 1000.

---

### withdrawal_sequencing_service.dart

**P0-W1 — Optimizer schedules largest 3a account FIRST, opposite of tax-optimal sequencing**  (withdrawal_sequencing_service.dart:390, 407-411)
Evidence:
```dart
// Trier les comptes 3a par solde decroissant: le plus gros compte
// est isole dans sa propre annee fiscale pour minimiser l'impact
// des tranches progressives.
sources3a.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
…
final withdrawalAges3a = _scheduleWithdrawals(
  count: sources3a.length,
  earliestAge: earliestWithdrawalAge,   // e.g. 60
  latestAge: latestWithdrawalAge,       // e.g. 65
);
```
Why it breaks: the comment says "isoler le plus gros" is correct intent, but `_scheduleWithdrawals` (line 515-547) returns a *list sorted ascending* by age, and the accounts are assigned in the order they come in the `sources3a` list (sorted descending by balance). So:
- `sources3a[0]` (largest) → `withdrawalAges3a[0]` (earliest age, 60)
- `sources3a[last]` (smallest) → `withdrawalAges3a[last]` (latest age, 65)

The result: the largest 3a is withdrawn FIRST at age 60, starting the progressive-tax ladder at its peak. If the user has 3a accounts of 150k / 80k / 50k (Julien profile-like), the optimizer produces:
| Age | Withdrawn | LIFD bracket |
|-----|-----------|--------------|
| 60  | 150k      | spans ×1.0 and ×1.15 |
| 62  | 80k       | ×1.0 |
| 65  | 50k + LPP | ×1.0 or more |

Tax-optimal ordering actually depends on whether the brackets reset annually (they do) AND whether the large-first or large-last strategy minimizes the weighted-average bracket. On a progressive rate, **splitting the largest across as many years as possible** is optimal, but if forced to allocate one withdrawal per year, put the *smallest* in the year that will combine with LPP (last year) and the *largest* alone. The current code does the opposite: smallest alone, largest with LPP indirectly through the "shift last 3a one year earlier" rule at lines 417-423.
Fix: either (a) reverse the scheduling to `sources3a.sort((a,b) => a.currentBalance.compareTo(b.currentBalance))` so the smallest is scheduled first (paired with earlier quiet years), largest last — OR better, (b) implement an actual brute-force optimizer that tries permutations of (account → year) assignments and picks the minimum total progressive-bracket tax. With N=3 accounts and 6 years, that's 120 permutations — trivial. For N>5 use a DP on (sorted_accounts, years_budget).

**P0-W2 — OPP3 art. 3 retrait window is asymmetric between genders + not aligned with AVS 21**  (withdrawal_sequencing_service.dart:399-403)
Evidence:
```dart
final int avsReferenceAge = reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
final earliestWithdrawalAge = (avsReferenceAge - 5).clamp(currentAge, 99); // = max(currentAge, 60)
```
Why it breaks: OPP3 art. 3 al. 1 lets the bénéficiaire retire 3a **dans les 5 ans qui précèdent l'âge de référence AVS**. Post-AVS 21, women born 1964+ have reference age 65; born 1961-1963 have 65 pro rata; born before 1961 have 64. The code uses the male reference age *for everyone*. For a 58-year-old woman born 1960 (ref age 64), the earliest withdrawal age is actually 59, not 60. Conversely, the code doesn't account for the *deferral* option (OPP3 art. 3 al. 1 lit. b) which allows postponement up to age 70 if the person continues a gainful activity.
Fix: parameterize by `gender` + `birthYear` via the same AvsCalculator helper used elsewhere; `earliestWithdrawalAge = refAge - 5`, `latestWithdrawalAge = refAge + 5` (up to 70 if still working).

**P0-W3 — Withdrawal tax computed on combined year total but pro-rated back — hides the progressive regressivity benefit**  (withdrawal_sequencing_service.dart:469-497 and 186-192)
Evidence: for each `year`, total tax is computed on `totalInYear` (combined sum) then split proportionally. Naive sequence does the same with the full combined total.
Why it breaks: the optimizer and naive compute tax on the *combined* capital in each year, which is correct. BUT: Swiss federal LIFD art. 38 applies on the *sum of all capital withdrawn in one tax year at the federal level*, AND cantonal laws often have additional rules. In particular, some cantons (VS, GE, VD) tax *all capital withdrawals in one tax year together* even if from different sources (3a + LPP) — which matches the code's behavior. But other cantons (ZH, ZG) tax each source separately under specific conditions for the cantonal portion only (federal still aggregates). The code assumes everywhere-aggregation.
More critically, the `tax-savings` metric (line 202 `taxSavings = totalTaxNaive - totalTaxOptimized`) is presented as a number without confidence interval or cantonal caveats. For a 500k capital pool split into 5× 100k withdrawals in VS vs single 500k, the naive federal tax is ≈ ×1.50 multiplier on the last 200k; the optimized is ×1.00 each year → real savings ≈ 15-20% of tax. Code correctly captures the federal savings IF cantonal aggregates. But if users in ZH/ZG see the same savings displayed, they may be misled by 5-10% pp.
Fix: add `cantonalAggregationBehavior: {aggregates | separates}` map by canton. Display savings as a range `[lowEstimate, highEstimate]` with cantonal uncertainty.

**P1-W4 — Return assumption `0.02` for 3a when no detail provided is a magic default**  (withdrawal_sequencing_service.dart:261)
Evidence: `annualReturn: 0.02, // Rendement moyen prudent`
Why it breaks: magic number, no source, violates no-shortcut doctrine. Should be sourced from a cantonal/national 3a return table (average VIAC: 5%, average WIR: 0.7%, average Raiffeisen: 1.8%, average cash PostFinance: 0%).
Fix: `reg('pillar3a.default_return_prudent', 0.02)` and load from the settings table.

**P1-W5 — LPP capital portion back-calculated via `rente / conversionRate` — lossy through rounding**  (withdrawal_sequencing_service.dart:272-288)
Evidence:
```dart
final projectedLppRente = LppCalculator.projectToRetirement(…);
final effectiveConversion = LppCalculator.adjustedConversionRate(…);
final projectedBalance = projectedLppRente / effectiveConversion;
```
Why it breaks: `projectToRetirement` returns an *annual rente* (already rounded inside LppCalculator to the nearest franc usually). Dividing by a conversion rate re-multiplies the rounding error by ~15× (1/0.068). For Julien (projected rente ~34k), back-calc balance = 500k but with precision loss of ~±150 CHF. Tolerable, but the round-trip is avoidable.
Fix: add a `LppCalculator.projectBalanceToRetirement(...)` method that returns the capital directly without the rente-conversion detour. Consumers use it.

**P1-W6 — Sequencer ignores wealth-tax drag between withdrawal years**  (withdrawal_sequencing_service.dart: entire `_buildOptimizedSequence`)
Evidence: once a 3a is withdrawn at age 60 for 150k, that 150k sits in a taxable account from 60 to death. Wealth tax ~0.3-0.6% × 150k × 25 years = 12-23k. The optimizer never debits this cost, so it may recommend withdrawing-too-early.
Why it breaks: the "optimize" savings metric excludes post-withdrawal wealth tax. For users in high-wealth-tax cantons (GE, VD, BS), early withdrawal can erase the progressive-bracket savings entirely.
Fix: add a post-withdrawal wealth-tax accumulator as a cost, net against `taxSavings`. Expose `netSavingsAfterWealthTax` as the primary number.

**P1-W7 — `clamp(0, 50)` on `years` silently caps any underflow and overflow**  (withdrawal_sequencing_service.dart:337, 433, 452)
Evidence: `final years = src.alreadyProjected ? 0 : (retirementAge - currentAge).clamp(0, 50);`
Why it breaks: masks bugs (negative years if currentAge > retirementAge, though this is guarded at line 135; >50 years if retirementAge=99 for some edge user). More importantly, the clamp returns an `int` within [0, 50] but the clamp-overflow condition silently swallows. No-shortcut doctrine says: if the caller passes bad data, raise in debug.
Fix: `assert(years >= 0 && years <= 50, 'impossible withdrawal horizon: $years')` then use the raw value.

**P2-W8 — `_CapitalSource` uses `double` for amounts, precision loss at very large balances**  (withdrawal_sequencing_service.dart:559)
Evidence: all balances are `double`. Dart `double` (IEEE 754 binary64) has ~15-17 significant decimal digits. For CHF amounts this is fine up to ~10 trillion, so practically safe. Still flagged for future expansion (e.g., if MINT ever totals pension portfolios in cents × millions of users, use int-cents).
Fix: consider `int cents` in a future refactor; current state is acceptable.

---

### tornado_sensitivity_service.dart

**P0-T1 — Tornado misses the #1 driver for couples: married-AVS cap (LAVS art. 35)**  (tornado_sensitivity_service.dart: entire `compute`)
Evidence: the 14 variables listed span Age, LPP-strategy, Salaire (×3 — user, conjoint), Avoir LPP, Taux conversion, Rendement caisse, 3e pilier capital, 3a mensuel, Années AVS, Lacunes AVS, Investissements libres, Épargne liquide, Épargne libre mensuelle. Missing: **marital status / couple AVS cap**. The difference between concubin and marié for a dual-income Julien+Lauren is ~CHF 800-1'200/month at 65 (due to the 150% cap on married), which is typically top-3 for the golden couple.
Why it breaks: tornado is supposed to surface top drivers; omitting the #1 lever for couples means users don't see it.
Fix: add a variable "Statut civil (marié vs concubin)" with low=concubin, high=marié, using the same projection engine. Applies only when `profile.isCouple`.

**P0-T2 — Tornado omits canton and cantonal-tax sensitivity**  (tornado_sensitivity_service.dart: entire `compute`)
Evidence: `canton` is never varied; the projection is always computed at the user's canton. But the cantonal spread on capital-withdrawal tax is 70% ZG vs 105% BS (see the `_effectiveRates100k` and `marriedCapitalTaxDiscountFor` maps). For Julien in VS (~0.82 × base) with LPP capital 490k, moving to ZG would save ~3-4k tax; to BS would cost ~4k.
Why it breaks: cantonal tax is one of the top-5 structural drivers and users have real options (intercantonal move at retirement). Ignored.
Fix: add "Canton" variable, low=best-case canton (ZG) high=worst-case canton (JU/BS), using `_effectiveRates100k` and capital-tax maps. Clearly label as "cantonal sensitivity, not a recommendation to move".

**P0-T3 — `tauxConversion` tornado uses 5.0% lower bound — below legal LPP art. 14 minimum 6.8%**  (tornado_sensitivity_service.dart:215-217)
Evidence:
```dart
const lowTaux = 0.050;
final convRateMin = reg('lpp.conversion_rate_min', lppTauxConversionMinDecimal);
final highTaux = baseTaux >= convRateMin ? 0.072 : convRateMin;
```
Why it breaks: `lowTaux = 0.050` models a ~26% cut to the conversion rate, which is only legal for the **surobligatoire** portion (caisses set their own). For the obligatoire portion, 6.8% is the statutory floor (LPP art. 14 al. 2 — the 2017 reform to 6.0% was rejected by referendum in 2017 and again in 2024). Applying 5.0% to the entire `tauxConversion` field (which the LPP calculator uses for the full balance unless split-certificates are provided) simulates an illegal scenario. Protection-first: never model illegal scenarios as baseline sensitivities.
Fix: lowTaux = reg-aware: 6.0% (most likely future cut per political scenarios) for obligatoire; 4.5% (actual caisse minima observed) for the surobligatoire portion. Needs two separate tornado entries if split is known.

**P0-T4 — `_project` swallows all exceptions, returning 0.0 — breaks top-3 ranking**  (tornado_sensitivity_service.dart:582-594)
Evidence:
```dart
try { … } catch (_) { return 0.0; }
```
Why it breaks: if ONE of the 14 variants throws (e.g., salary goes to 0, lacune ratio becomes NaN, conversion rate out of range), the function silently returns 0. The resulting `swing = (high - low).abs()` becomes approximately `base` — which may rank the crashed variable as HIGH impact. Tornado then displays a misleading top driver. No-shortcut doctrine: log the error, tag the variable as "données insuffisantes", exclude from ranking.
Fix:
```dart
try { … } catch (e, s) {
  AppLogger.warn('tornado variant failed: $e', stack: s);
  return double.nan;
}
```
Then filter NaN out of `variables.add(...)` and emit an info banner.

**P1-T5 — Swing = (highValue - lowValue).abs() can collapse to zero incorrectly**  (tornado_sensitivity_service.dart:703, 563)
Evidence: `swing: (high - low).abs()`. Then `.sort((a, b) => b.swing.compareTo(a.swing))`. With the exception swallow (P0-T4), if both low and high crashed both return 0.0 → swing=0 → sorts to the bottom — so you don't see the bug. If only one crashed (returns 0.0) and the other succeeds (e.g., 12'000), swing=12'000 — the variable appears to swing from 0 to 12k due solely to the crash, ranking it #1.
Fix: (together with P0-T4) guard against NaN and exclude if either branch failed.

**P1-T6 — Avoir LPP swing ±30% is under-calibrated for early-career users**  (tornado_sensitivity_service.dart:182-210)
Evidence: `baseAvoir * 0.70` and `baseAvoir * 1.30`.
Why it breaks: ±30% is roughly ±2σ of LPP-balance uncertainty for a user near retirement who has certificate data. For a 28-year-old with 15 years of compounding ahead, 30% is ~1σ of the realistic balance envelope and does not represent the true uncertainty (contributions over 40 years with market variance can 3×-5× the current number). So the tornado under-reports balance-uncertainty for young users.
Fix: scale the band with horizon: `±30% if retirementAge - currentAge < 10; ±50% if 10-25; ±70% if >25`.

**P1-T7 — 3a mensuel scenario uses `base * 2` but caps at `pilier3aPlafondAvecLpp` — ignores salarié vs indépendant**  (tornado_sensitivity_service.dart:300-302)
Evidence:
```dart
const plafond3aMensuel = pilier3aPlafondAvecLpp / 12;
final cappedHigh = min(base3aMensuel * 2, plafond3aMensuel);
```
Why it breaks: `pilier3aPlafondAvecLpp = 7'258` (salarié). For an indépendant without LPP, the cap is 20% of revenu net up to 36'288/yr. The high scenario for an indépendant should be 36'288/12 = 3'024/month, not 604/month. Current code caps them at the salarié limit, making the 3a tornado near-zero for indépendants — exactly the cohort where 3a is the primary lever.
Fix: use the profile's `employmentStatus` and `prevoyance.pillar3aAnnualCap` (or recompute) to pick the right cap.

**P1-T8 — Lacunes AVS tornado uses `+3` lacunes — asymmetric and ignores realistic scan uncertainty**  (tornado_sensitivity_service.dart:376-400)
Evidence: `lacunesAVS: baseLacunes + 3` vs `lacunesAVS: 0`.
Why it breaks: low=+3 (worse than base) and high=0 (better than base) creates a one-sided scenario anchored on "user knows the base". But AVS lacunes are usually discovered AT the scan of the IK extract (CC 831.10) and most users have 0-2 lacunes, with a long right tail (returning expats with 5-10 years of gap). For expat_us Lauren this is material — the baseline can be 8-10 lacunes. `+3` then understates the downside significantly.
Fix: scale by `archetype`: swiss_native ±1, expat_eu/expat_non_eu ±3, expat_us/cross_border ±5, returning_swiss ±7.

**P1-T9 — "Top-3 drivers" requirement (per project brief) not surfaced; all 14 returned**  (tornado_sensitivity_service.dart:563, public API)
Evidence: `variables.sort((a, b) => b.swing.compareTo(a.swing)); return variables;` — returns all of them.
Why it breaks: prompt requirement § 5 says "tornado surfaces the TOP-3 drivers, not all variables". Current callers get 10-14 items; if UI renders all 14, users get cognitive overload (violates progressive-disclosure UX rule). And since several variables have similar swings, a stable top-3 is not guaranteed across reruns.
Fix: add an optional `limit: int = 3` parameter; return the top-N. UI can expand to full list on demand. Also document: "les autres variables ont un impact moindre et sont consultables en détail".

**P1-T10 — Rendement caisse LPP fixed range [0.01, 0.03] — ignores current base rate**  (tornado_sensitivity_service.dart:245-253)
Evidence: hard-coded `rendementCaisse: 0.01` (low) and `0.03` (high).
Why it breaks: if user's base rendementCaisse = 0.05 (CPE Plan Maxi, Julien's case), then "high" scenario at 3% is *lower* than the base, creating a perverse "improvement is a cut". The resulting swing is negative/zero and mislabels.
Fix: use relative ±150 bps around base: `low = max(0, base - 0.015)`, `high = base + 0.015`.

**P2-T11 — Labels like "-20%" are not i18n'd**  (tornado_sensitivity_service.dart:173-175, 205-207, etc.)
Evidence: `lowLabel: '-20%'` — bare ASCII minus sign, not locale-aware. For RTL or typographic contexts should be "−20%" (U+2212).
Fix: use proper Unicode minus in ARB files.

---

## Cross-file concerns (shared constants, duplicate logic)

**X1 — Capital withdrawal tax called in 4 different ways across files, without shared assumptions registry**
- `arbitrage_engine.dart` line 340, 1177, 1440, 1485, 1584, 1593, 1756, 1820, 1927: always passes `canton`, sometimes `isMarried`.
- `monte_carlo_service.dart` line 247, 327, 371: always passes both.
- `withdrawal_sequencing_service.dart` line 345, 474: always passes both.
All converge to `RetirementTaxCalculator.capitalWithdrawalTax` — OK. BUT: each file independently computes or estimates `isMarried` (check `profile.etatCivil == CoachCivilStatus.marie`). No shared helper. Risk of drift (e.g., concubinage enregistré, veuf, divorcé with pension splitting). Consolidate into `CoachProfile.isMaritalStatusMarried` getter.

**X2 — Inflation assumptions are hardcoded differently in each file**
- `arbitrage_engine`: `inflation = 0.02` default, deterministic.
- `monte_carlo_service`: `N(0.012, 0.005)` drawn once per sim (P0-M2).
- `withdrawal_sequencing_service`: no inflation modeling at all (assumes all withdrawals in CHF-of-the-year with no real-vs-nominal distinction).
- `tornado_sensitivity_service`: inherits whatever `RetirementProjectionService.project` uses.
This means the same user re-running the 4 tools sees 4 different sets of purchasing-power assumptions. Fix: define a single `SwissInflation.baseline` (0.01 μ / 0.007 σ per SNB) imported everywhere.

**X3 — `avsAgeReferenceHomme` used as universal default retirement age across all 4 files**
- `arbitrage_engine` line 75, 1416: `int ageRetraite = avsAgeReferenceHomme`
- `monte_carlo_service` line 85: `retirementAgeUser = avsAgeReferenceHomme`
- `withdrawal_sequencing_service` line 127, 399: same
- `tornado_sensitivity_service`: passes through the user's chosen age.

Under AVS 21, women's reference age is equalizing to 65 by 2028 cohort, but for users in transition (born 1961-1963), the default should be gender-adjusted. Fix: introduce `avsReferenceAgeFor(profile)` as the single default, everywhere.

**X4 — No shared `SwissActuarialAssumptions` settings block**
All files have local constants for return means, σ, technical rate, discount rate. Proposal: create `apps/mobile/lib/constants/actuarial_assumptions.dart` with:
```
const lppMeanReturn = 0.025;       // LPP technical rate, midpoint 2.0-3.0
const lppReturnSigma = 0.065;      // Pictet BVG-25 historical σ (2000-2024)
const inflationMeanCh = 0.010;     // SNB 2010-2024
const inflationSigmaCh = 0.007;    // SNB 2010-2024
const spiMeanReturn = 0.055;       // SPI long-run total return
const spiSigmaReturn = 0.16;       // SPI long-run σ
…
```
Sourced to the canonical references. All 4 files import and use.

**X5 — Confidence scoring not unified with `EnhancedConfidence` (4-axis)**
- `arbitrage_engine._computeArbitrageConfidence` (line 31) is a bespoke 30-95% heuristic on data-source quality only; doesn't use the project-wide `completeness × accuracy × freshness × understanding` geometric mean documented in `CLAUDE.md` § 5.
- `monte_carlo_service` returns a `MonteCarloResult` with NO confidence field, despite the project requiring "confidence score mandatory on ALL projections" (§ 5).
- `withdrawal_sequencing_service` also returns no confidence on `WithdrawalSequencingResult`.
- `tornado_sensitivity_service` returns only a swing magnitude, no confidence band per variable.
This is a systemic gap vs the CLAUDE.md doctrine "Projection without confidence score → anti-pattern (§ 9.9)". Propagate `EnhancedConfidence` on every result DTO.

---

## Compliance + no-shortcut violations

### Sentinel values found
- `arbitrage_engine.dart:1958` `const rendement3a = 0.02;` — magic constant inside a private helper, shadows the caller param (P1-A9). Technically not a sentinel but a silent override.
- `monte_carlo_service.dart:126` `lifeExpectancy = 82 + nextInt(14)` — pseudo-sentinel (bounded uniform) masquerading as an actuarial assumption (P0-M3).
- `withdrawal_sequencing_service.dart:261` `annualReturn: 0.02, // Rendement moyen prudent` — magic 2% (P1-W4).

### Magic numbers without sourcing
- `monte_carlo_service.dart:187-188` LPP σ = 0.03 — no source, incorrect (P0-M1).
- `monte_carlo_service.dart:388, 399` free-portfolio σ = 0.08 — no source (P1-M5).
- `monte_carlo_service.dart:321-322` 3a σ = `baseReturn × 0.5` — no source, arbitrary coupling.
- `arbitrage_engine.dart:1208` wealth tax = 0.003 — no source, not cantonal (P1-A5).
- `arbitrage_engine.dart:375` rente survivant = 0.6 — correct per LPP art. 19 but not cited inline (minor).
- `tornado_sensitivity_service.dart:215-217` lowTaux = 0.050 — illegal for obligatoire (P0-T3).
- `tornado_sensitivity_service.dart:246-253` rendement caisse {1%, 3%} — no source (P1-T10).
- `withdrawal_sequencing_service.dart:399` `(refAge - 5)` → OPP3 art. 3 — cited correctly in comment but refAge wrong for women (P0-W2).

### Swallowed exceptions
- `tornado_sensitivity_service.dart:591-593` `catch (_) { return 0.0; }` — masks all errors, corrupts tornado ranking (P0-T4). **Most severe silent-catch in Wave 7.**
- `monte_carlo_service.dart:272-282` string-match buyback attribution silently returns 0 on `firstName=null` (P1-M8). Not a catch but a silent fallthrough.
- `monte_carlo_service.dart:345-346` `conjointCan3a ?? true` — defaults US-person Lauren to "can contribute" if the flag is missing. For FATCA compliance (§ 5: FATCA triggers PFIC and 3a barriers for US persons), defaulting to true is unsafe. Must default `false` for `archetype == expat_us`.

### Other compliance concerns
- `arbitrage_engine.dart:390` `betterOption = capitalTotalValue > renteTotalValue ? 'capital' : 'rente'` — RANKS options despite CLAUDE.md § 6.4 "No-Ranking: arbitrage options shown side-by-side, never ranked". The variable `betterOption` leaks into `premierEclairage` text (line 406-408: "l'option $betterOption genere..."). **Compliance violation.** Fix: drop the ranking; describe the trade-off in neutral terms ("l'option capital termine avec +X CHF de valeur totale mais avec -Y CHF de revenu courant").
- `arbitrage_engine.dart:1018` `betterLabel = optionA.terminalValue > optionB.terminalValue ? 'louer' : 'acheter'` — same ranking violation.
- `arbitrage_engine.dart:394-395` same pattern.
- `monte_carlo_service.dart:491-496` "Envisage d'augmenter ton épargne ou de repousser ta retraite" — prescriptive/advisory language. LSFin-adjacent. Acceptable because conditional ("Envisage" = verb conjugation suggests possibility), but borderline. Review for Wave 8.

---

*End of Wave 7 actuarial audit. Recommended priority: fix P0-A1/A2/A3, P0-M1/M2/M3/M4, P0-W1/W2, P0-T1/T2/T3/T4 before next release. P1 items can be batched into a Wave 8 math-polish sprint.*
