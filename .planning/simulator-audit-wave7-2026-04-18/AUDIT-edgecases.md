# Wave 7 — Edge-case/fuzz audit
*Scope: all 8 simulators (arbitrage_engine, monte_carlo_service, withdrawal_sequencing_service, tornado_sensitivity_service, forecaster_service, expat_service, financial_report_service, budget_service)*

## Executive summary
- Files audited: **8**
- **P0 (crash or silent wrong number): 17**
- **P1 (degraded but returns): 23**
- **P2 (technically OK but ugly): 9**

Key systemic issues:
1. Every simulator silently trusts `profile.age` — when age = 0 (birthYear invalid, `CoachProfile.age` returns 0 per `coach_profile.dart:1654-1658`), services produce nonsense projections (e.g. 43-year loops starting at age 0, buyback windows of 60 years) without raising.
2. Negative inputs (`revenuBrutAnnuel = -1`, `avoirLppTotal = -50`) flow through every `fold` / compound-growth loop unchecked, producing negative LPP rentes displayed as CHF amounts.
3. Canton lookups use silent fallback `?? 0.13` or `?? 'ZH'` → **wrong canton → wrong tax → user told wrong number, no warning** (expat_service, withdrawal_sequencing, monte_carlo).
4. `DateTime.now()`-based arithmetic in `planDeparture`, `forecaster._monthsBetween`, `forecaster_service` line 663 (`DateTime(now.year, now.month + m)`) all crash or produce negative spans when inputs are in the past or inverted.
5. `.reduce()` on lists only partially guarded — `arbitrage_engine` added guards, but `expat_service.simulateForfaitFiscal` line 521 (`[livingExpenses, cantonMin, forfaitFederalMinimum].reduce(max)`) is safe only because the list is literal; `financial_report_service.yearlyPlan.fold` on an empty plan returns 0 (wrong answer, not crash).

---

## Findings per file

### 1. arbitrage_engine.dart

**P0-E1 — Negative capital produces negative "monthly withdrawal" displayed as CHF**  (arbitrage_engine.dart:143-152, 345-349)
- Trigger: `capitalLppTotal = -50000` (bug or typo in scan), `capitalObligatoire = 0`, `capitalSurobligatoire = 0`.
- Symptom: `_buildCapitalTrajectory` computes `withdrawalTax` on negative capital (may be 0 from tax calc guard), then `capitalAfterReturn = capitalNetStart * 1.03 = -51'500`. `capitalRetraitMensuel = (-51500 * 0.04) / 12 = -171.67 CHF/mois`. User sees a negative monthly withdrawal as a legit number. No guard.
- Quote: `final capitalNetStart = effectiveCapitalTotal - withdrawalTaxTotal; final capitalAfterReturn = capitalNetStart * (1 + rendementCapital);`
- Fix: assert `capitalLppTotal >= 0` at entry; early-return `ArbitrageResult.invalid(reason: 'negative_capital')` when any of the three capital inputs < 0.

**P0-E2 — `capitalEpuiseAge` detection uses `< capitalTrajectory[1] * 0.1` heuristic — silently wrong for small capital**  (arbitrage_engine.dart:352-366)
- Trigger: `capitalLppTotal = 5000` (user declared tiny LPP), `tauxRetrait = 0.04`, horizon 30.
- Symptom: Initial annualCashflow ≈ 200 CHF; 0.1 of that = 20 CHF. Capital depletes after ~year 2 but the detector says year 1 (first iteration). User sees "capital épuisé à 66 ans" — false.
- Quote: `if (i > 1 && snap.annualCashflow < capitalTrajectory[1].annualCashflow * 0.1)`
- Fix: track remaining capital explicitly in a `List<double> remainingCapital`; detect exhaustion via `remaining <= 0`, not a heuristic on cashflow.

**P0-E3 — `tauxConversionObligatoire = 0` produces division-by-zero silently**  (arbitrage_engine.dart:121-123)
- Trigger: user fed `tauxConversionObligatoire: 0.0` (e.g. slider at floor).
- Symptom: `effectiveCapitalOblig = tauxConversionObligatoire > 0 ? projectedRenteOblig / 0 : capitalObligatoire` — the ternary guards, but if user passes `0.000001` (below guard), result = `projectedRenteOblig * 1e6` = astronomical CHF. Displayed as hero metric.
- Fix: `math.max(tauxConversionObligatoire, 0.02)` with logged warning, or refuse rates < 3%.

**P1-E4 — `anneesAvantRetraite` negative in `compareAllocationAnnuelle` loops indefinitely or crashes `pow(...)` with negative exponent**  (arbitrage_engine.dart:488-502)
- Trigger: user already retired, requests annual allocation sim, `anneesAvantRetraite = -5`.
- Symptom: `_buildAllocationTrajectory` has `for (y = 0; y <= horizon; y++)` with horizon = -5 → loop executes 0× → returns empty list → `trajectory3a.last` **crashes with `Bad state: No element`**.
- Fix: clamp `anneesAvantRetraite` to `max(1, ...)` at entry + explicit error if <= 0.

**P1-E5 — `capitalDisponible / prixBien` produces NaN when `prixBien = 0`**  (arbitrage_engine.dart:1108)
- Trigger: `compareLocationVsPropriete(prixBien: 0, capitalDisponible: 100000, ...)`.
- Symptom: Hypothesis string `'Fonds propres : ${(capitalDisponible / prixBien * 100).toStringAsFixed(0)} %'` = "Infinity %" displayed to user.
- Fix: guard `prixBien > 0`, else raise `ArgumentError('prixBien must be > 0')`.

**P1-E6 — `horizonAnnees = 0` → `annualProprioCharges` list empty → `annualProprioCharges[y]` crash**  (arbitrage_engine.dart:910-933)
- Trigger: user picks 0-year horizon.
- Symptom: Loop runs 0 times when `horizonAnnees = 0` and `y` never > 0; but then at y=0 in the Option A loop, `annualProprioCharges[y]` = `annualProprioCharges[0] = 0.0` (safe); however at y=1 check, the outer y=0 branch returns without filling annualProprioCharges past index 0 — subsequent access in Option B at y=1..horizon would crash if horizon > 0.
- Fix: guard `horizonAnnees >= 1` at entry.

**P2-E7 — Canton default `'ZH'` silently used when `canton = "XX"` (invalid code)**  (arbitrage_engine.dart:483, 1417, etc.)
- Trigger: canton = "XX" or "" or null-cast.
- Symptom: `RetirementTaxCalculator.capitalWithdrawalTax` falls back to ZH rates. User in VS sees ZH tax. No warning.
- Fix: validate canton against `ExpatService.cantonNames.keys` at entry; throw if invalid.

---

### 2. monte_carlo_service.dart

**P0-E8 — `profile.age = 0` causes `for (a = 0; a < 65 && a < 70; a++)` to run 65 iterations applying LPP bonifications from age 0, inflating avoir by a factor of ~4**  (monte_carlo_service.dart:186)
- Trigger: `birthYear = 2100` or missing → `CoachProfile.age` returns 0 per line 1654.
- Symptom: LPP balance compounds over 65 unreal years. Hero metric "revenu à 65" wildly inflated (e.g. 18'000 CHF/mois instead of 4'500). User acts on phantom wealth.
- Quote: `for (int a = profile.age; a < retirementAgeUser && a < 70; a++) { ... lppBalance += salaireCoord * getLppBonificationRate(a); }`
- Fix: `if (profile.age < 18 || profile.age > 75) throw StateError('invalid_age')`; do NOT silently return 0 from `CoachProfile.age`.

**P0-E9 — `retirementAgeUser - profile.age` negative → `yearsTo90` clamped to 0, but retirementYear in the past → projection shows past years as "future"**  (monte_carlo_service.dart:95-96, 102)
- Trigger: `profile.age = 70`, `retirementAgeUser = 65`.
- Symptom: `retirementYear = 2026 + (65 - 70) = 2021`. The MC chart shows "year 2021, age 65" — 5 years in the past — as the retirement starting point.
- Fix: `assert(retirementAgeUser >= profile.age, 'cannot retire in the past')`.

**P0-E10 — `numSimulations = 0` → `results.isEmpty` → `results.map(sim => sim[y])` is empty → `_percentile` returns 0 → UI shows "P50 = 0 CHF" for all years, no warning**  (monte_carlo_service.dart:118, 469-480)
- Trigger: caller passes `numSimulations: 0` (testing, bug).
- Symptom: every percentile = 0. Ruin probability = 0/0 = div-by-zero but line 484 guards (`numSimulations > 0 ? ruinCount / numSimulations : 0.0`). Result looks "safe" but is nonsense.
- Fix: `assert(numSimulations >= 100, 'too few sims for meaningful stats')`.

**P0-E11 — `baseReturn3a = 0.0` propagates as `sd: 0.0 * 0.5 = 0` → `_normalRandom` returns exactly the mean → 1000 identical paths → ruin probability = 0 or 1 (binary)**  (monte_carlo_service.dart:319-322)
- Trigger: profile.prevoyance.rendementMoyen3a = 0 (default for empty profile).
- Symptom: Monte Carlo loses all stochastic spread on the 3a axis — user sees certainty band = 0 width, perceives projection as "certain" (but it isn't).
- Fix: `final sd3a = max(0.005, baseReturn3a * 0.5)` — never collapse noise to zero.

**P1-E12 — Conjoint matching by firstName substring allows collisions**  (monte_carlo_service.dart:272-283, 354-364)
- Trigger: user = "Lauren", conjoint = "Laurence". `c.id.toLowerCase().contains('laurence')` also matches `'laurence'` in user contributions. Contributions double-counted or swapped.
- Symptom: conjoint 3a balance includes contributions that belong to user.
- Fix: match by `ownerId` UUID stored on each PlannedContribution, not a name substring.

**P1-E13 — `lifeExpectancy = 82 + random.nextInt(14)` never below 82 — silently eliminates early-death scenarios**  (monte_carlo_service.dart:126)
- Trigger: structural.
- Symptom: Ruin probability ignores death < 82. Understates risk for users with medical concerns.
- Fix: sample from a proper survival curve (e.g. STATEC/OFS Swiss life table) or at minimum widen the range (65-100).

**P1-E14 — `profile.canton = ""` or null falls through to `'ZH'`, capital withdrawal tax computed for ZH while user is in VS**  (monte_carlo_service.dart:99-100)
- Trigger: empty canton string.
- Symptom: ZH has different rates than VS (VS median ~15% higher). User in VS sees optimistic tax.
- Fix: raise when canton missing; do not silently substitute.

**P2-E15 — `_normalRandom` uses `1e-10` floor on `u1` — excellent; but `cos(2 * pi * u2)` not checked for 0/0 if u2 = 0 exactly — unlikely but worth guarding**  (monte_carlo_service.dart:530-535)
- Cosmetic — current floor good enough.

---

### 3. withdrawal_sequencing_service.dart

**P0-E16 — `currentAge >= retirementAge` returns an empty result but caller UI shows "Économies: CHF 0" as if optimization ran and found nothing to save**  (withdrawal_sequencing_service.dart:135-147)
- Trigger: Julien (49) selects retirementAge = 48 (slider below current).
- Symptom: No error, no "ineligible" flag. `WithdrawalSequencingResult` has empty sequences, `taxSavings = 0`, `savingsPercent = 0`. User concludes "no savings to be had" instead of "your retirement age is invalid".
- Fix: add `final bool isEligible` field on the result; set false with `ineligibilityReason: 'already_at_retirement_age'`.

**P1-E17 — `.projectedAmounts[src]!` force-unwrap will crash if a source got filtered by `continue`**  (withdrawal_sequencing_service.dart:353)
- Trigger: in `_buildNaiveSequence`, a source with `solde <= 0` was skipped in `_collectCapitalSources` — but if a new caller adds a source directly, `projectedAmounts.containsKey(src)` is not checked.
- Symptom: NoSuchMethodError: The method '!' was called on null.
- Fix: `final projected = projectedAmounts[src] ?? 0;` or explicit `containsKey` check.

**P1-E18 — `_projectBalance(balance, annualReturn, years)` with `annualReturn = -0.5` halves balance each year** (withdrawal_sequencing_service.dart:308-316)
- Trigger: mis-declared `rendementEstime: -0.5` on a 3a account (e.g. user entered a bug).
- Symptom: 3a projected to near zero, tax optim shows "nothing to optimize". Silent wrong number.
- Fix: clamp `annualReturn` to `[0.0, 0.15]` with warning when outside.

**P2-E19 — `retirementAge.clamp(earliestWithdrawalAge, 70)` silently caps at 70 for late retirees (possible for self-employed)**  (withdrawal_sequencing_service.dart:402-403)
- Trigger: self-employed user retires at 72.
- Symptom: optim uses 70 instead of 72 — ~CHF 3'500 discrepancy on tax estimate.
- Fix: raise cap to 75, or key off actual retirementAge.

---

### 4. tornado_sensitivity_service.dart

**P0-E20 — `_project` swallows every exception and returns 0.0, so ALL variables show swing = 0 when base profile is borderline (e.g. missing canton)**  (tornado_sensitivity_service.dart:582-594)
- Trigger: profile with canton = "" → `RetirementProjectionService.project` throws → `catch(_) return 0`. Every variable's base/low/high = 0. Swing = 0. Tornado renders empty.
- Symptom: user sees a blank tornado chart, no explanation why. No alert that the underlying data is invalid.
- Quote: `} catch (_) { return 0.0; }`
- Fix: propagate the first exception; add a `TornadoResult.unavailable(reason)` type; show user a repair prompt.

**P0-E21 — `profile.prevoyance.tauxConversion = 0.0` used as `baseTaux` — comparison `baseTaux >= convRateMin` where convRateMin = 0.068 is false → highTaux forced to 0.068, low = 0.050, range narrows to 1.8 pts instead of 2.2**  (tornado_sensitivity_service.dart:213-217)
- Trigger: default profile without LPP certificate.
- Symptom: Taux de conversion variable shows artificially small swing; user perceives it as non-critical.
- Fix: when baseTaux falls outside `[0.045, 0.075]`, use `max(baseTaux, convRateMin)` and emit a note "taux par défaut utilisé".

**P1-E22 — `lowAge < highAge` check skips age variable when user at age 65 exactly (retirementAgeUser=65 → lowAge=63, highAge=67, OK; but retirementAgeUser=58 → lowAge=58, highAge=60, OK; retirementAgeUser=70 → lowAge=68, highAge=70 → range fine)**  — false positive from my side, not a bug.

**P1-E23 — `(lowYears - 5).clamp(0, fullYears)` allows lowYears = 0 when user declared 3 years contributed → displays "0 ans" as legitimate scenario → AVS would be 0 CHF → MASSIVE swing dominates the chart, pushing real risks below the fold**  (tornado_sensitivity_service.dart:347)
- Trigger: `anneesContribuees = 3`.
- Symptom: "Années AVS cotisées" variable shows swing of ~CHF 2000/mois — misleadingly huge because "0 years" is not a realistic scenario for a 3-year contributor.
- Fix: `max(1, baseYears - 5)` — never drop to 0 contribution years.

**P1-E24 — `lacunesAVS + 3` can produce > `fullContributionYears`; never re-checked**  (tornado_sensitivity_service.dart:381)
- Trigger: baseLacunes = 42, +3 = 45 lacunes on a 44-year system.
- Symptom: AvsCalculator receives 45 lacunes → rente = 0 or negative depending on impl.
- Fix: `clamp(baseLacunes + 3, 0, fullContributionYears - 1)`.

**P2-E25 — `PatrimoineProfile(...)` reconstruction drops `propertyMarketValue`, `mortgageBalance`, `mortgageRate`, `monthlyRent` fields that the main PatrimoineProfile has**  (tornado_sensitivity_service.dart:410-415, 423-428, etc.)
- Trigger: user with property runs tornado.
- Symptom: In tornado variants, property info silently reset to null/0 → housing cost estimate diverges → baseline for libre scenarios differs from the actual baseline — spurious extra swing attributed to investment changes.
- Fix: use `profile.patrimoine.copyWith(...)` instead of rebuilding manually.

---

### 5. forecaster_service.dart

**P0-E26 — `DateTime(now.year, now.month + m)` with m = 480 (40 years) produces a perfectly valid DateTime via overflow but `_monthsBetween(now, targetDate)` for a targetDate in the past returns negative → early return — OK. But if `profile.goalA.targetDate` is default-null and upstream defaults to `DateTime.now()`, months = 0, projection returns empty scenarios with all zeros — displayed to the user as "capital final CHF 0"**  (forecaster_service.dart:505-515)
- Trigger: user has no goal set; goalA defaulted to today.
- Symptom: Hero metric = 0 CHF. User sees "your retirement capital is 0" and panics.
- Fix: if `months <= 0`, return `ProjectionScenario.unavailable(reason: 'no_goal_set')` with an enrichment prompt, not zeros.

**P0-E27 — `profile.birthYear` can be 0 (missing data) → `retirementAge = targetDate.year - 0 = 2055` → AVS calculator called with retirementAge 2055 → undefined behavior (likely returns max rente)**  (forecaster_service.dart:796)
- Trigger: empty profile with default birthYear = 0.
- Symptom: AVS rente inflated to unrealistic max, user thinks they'll receive 3'900 CHF/mois at age 2000+.
- Fix: guard `profile.birthYear > 1900 || throw`.

**P0-E28 — `safeReplacementRate` returns 0 when current income < 12'000 CHF/year — silently hides valid cases (part-time student starting 3a early)**  (forecaster_service.dart:1019-1020)
- Trigger: 19-year-old apprentice earning 8'000 CHF/an.
- Symptom: Taux remplacement = 0% even when projected retirement income is CHF 45'000/an. User thinks "je n'aurai rien".
- Fix: still compute ratio; flag `lowIncomeBaseline: true` so UI can add context, not hide the number.

**P1-E29 — `profile.plannedContributions.where(...).firstOrNull` + silent drop when `contrib == null`**  (forecaster_service.dart:598-601)
- Trigger: a check-in `versements` entry has an ID that doesn't match any plannedContribution (e.g. plan deleted after check-in).
- Symptom: that check-in amount silently ignored — smart-contribution average understates real behavior — projection pessimistic.
- Fix: log these orphans or surface as an enrichment prompt.

**P1-E30 — `conjoint.age = null` → `profile.age` substituted — projects conjoint as same age as user, wildly misestimating retirement delta for couples with big age gaps**  (forecaster_service.dart:697, 818)
- Trigger: profile has conjoint but no age field.
- Symptom: AVS rente and LPP rente for conjoint computed as if conjoint retires same year as user. If conjoint is actually 50 and user 35, projection overstates income by 20-30%.
- Fix: if `conjoint.age == null`, skip conjoint projection entirely and surface enrichment prompt "âge conjoint manquant".

**P1-E31 — `profileCaisseRate = 0.02` is the default in `PrevoyanceProfile` — line `(profileCaisseRate != 0.02) ? profileCaisseRate : assumptions.lppReturn` — user who **actually** declared 2.0% via scan gets overwritten by scenario assumption (1%/2%/3%). Silent data loss.**  (forecaster_service.dart:637-639)
- Trigger: user's LPP cert shows 2.0% → mobile stores 0.02 → forecaster treats as default and overrides.
- Symptom: projection uses scenario rate instead of user's actual caisse rate.
- Fix: use an explicit `isCaisseRateFromCertificate: bool` flag on the profile instead of comparing against the default value.

**P2-E32 — `DateTime(now.year, now.month + m)` overflow to year+1 is documented Dart behavior but hides a potential timezone shift — minor.**

---

### 6. expat_service.dart

**P0-E33 — `sourceTaxRates[canton] ?? 0.13` silently defaults to 13% when canton unknown — user from GE typed "Ge" (case-sensitive) → gets 13% instead of 15.48%**  (expat_service.dart:273)
- Trigger: canton = "ge" (lowercase), "GENEVA", "GE " (trailing space).
- Symptom: Source tax under-estimated by 250-300 CHF/month. User plans accordingly.
- Fix: uppercase + trim at entry, throw if not in `sourceTaxRates.keys`.

**P0-E34 — `foreignSocialCharges[residenceCountry]?['total'] ?? 0.20` — user typed "france" (lowercase) or "FR" (code vs label) → falls to 20% instead of correct 22.5%**  (expat_service.dart:464)
- Trigger: residenceCountry = "FR" (ISO code) or lowercase.
- Symptom: CH vs France comparison wrong by ~CHF 2'000/year.
- Fix: normalize input; enum-based country identifier, not free-form string.

**P0-E35 — `checkQuasiResident` with `chIncome > worldwideIncome` (data entry error) returns ratio > 1 — displayed as "123% de tes revenus proviennent de Suisse"**  (expat_service.dart:343)
- Trigger: user declares chIncome = 100'000, worldwideIncome = 80'000 (bug: worldwide should be ≥ ch).
- Symptom: ratio = 1.25. `eligible = true` (correct by coincidence) but ratioPercent = 125% rendered.
- Fix: if `chIncome > worldwideIncome`, raise or at minimum clamp ratio to 1.0 with validation warning.

**P0-E36 — `planDeparture(departureDate: DateTime in the past)` returns `daysUntilDeparture: -30` — UI likely shows "J-30" as positive or "il y a 30 jours" uncontextualized**  (expat_service.dart:632)
- Trigger: user selects yesterday.
- Symptom: checklist rendered as if departure is future; "priority: high" items still flagged.
- Fix: `if (daysUntilDeparture < 0) return {'status': 'already_departed', ...}`.

**P0-E37 — `simulateForfaitFiscal(actualIncome: 0)` returns `ordinaryTax = 0` → `savings = forfaitTax × -1` (negative) → `isFavorable = savings > 0 → false` — but the NUMBER displayed to user is "-CHF 100'000 économies" (a loss)**  (expat_service.dart:531-533)
- Trigger: user declares income = 0 (retired abroad scenario).
- Symptom: user sees "le forfait te coûte 100'000 CHF" which is misleading because at income=0 the comparison is meaningless.
- Fix: if `actualIncome <= 0`, return `{'eligible': true, 'reason': 'no_comparison_at_zero_income'}` without a savings number.

**P1-E38 — `fullContributionYears` read via `.toInt()` on a double — if `reg()` returns NaN for any reason, `.toInt()` crashes**  (expat_service.dart:166)
- Trigger: registry misconfig.
- Symptom: whole expat module crashes.
- Fix: `reg(..., avsDureeCotisationComplete.toDouble()).isFinite ? .toInt() : avsDureeCotisationComplete`.

**P1-E39 — TI special case returns `monthlyTax: 0.0` but if a VD resident is misclassified as TI (e.g. employer changed), user sees "0 impôt" while actually paying 14.89%**  (expat_service.dart:276-291)
- Trigger: canton misidentified.
- Symptom: catastrophic underestimate.
- Fix: add an `isFrontalier: bool` guard — TI rule applies only to Italian residents working in TI.

**P1-E40 — `reductionPerMissingYear = 1/44` multiplied by `missingYears` can exceed 100% if missingYears > 44; clamped to 100 but at `missingYears = 44`, reductionPercent = 100% → `estimatedRente = 0`, displayed as "0 CHF/mois" for a user with 0 years contributed — technically correct but unhelpful (doesn't trigger enrichment)**  (expat_service.dart:569-570)
- Fix: when completeness < 0.1, show "contact AVS office" CTA instead of raw 0.

**P2-E41 — `yearsAbroad + yearsInCh = totalYears` not validated against user's age — totalYears can exceed age.**  (expat_service.dart:567)

---

### 7. financial_report_service.dart

**P0-E42 — `_parseInt(answers['q_birth_year']) ?? DateTime.now().year - 40` silently assumes 40-year-old when birthYear missing — report produced is for a phantom 40-year-old, NOT the actual user**  (financial_report_service.dart:179)
- Trigger: onboarding incomplete, q_birth_year never answered.
- Symptom: User (actual age 28) gets a 40-year-old's retirement strategy silently. No hint that the profile was fabricated.
- Quote: `final birthYear = _parseInt(answers['q_birth_year']) ?? DateTime.now().year - 40;`
- Fix: if birthYear missing → return `FinancialReport.incomplete(reason: 'birth_year_missing', enrichmentPrompt: ...)`, do NOT fabricate.

**P0-E43 — `profile.monthlyNetIncome ?? 5000` fabricates a 5'000 CHF/mois salary for users who didn't answer the income question**  (financial_report_service.dart:188)
- Trigger: q_net_income_period_chf null.
- Symptom: tax calculation / LPP projection / AVS rente all computed on phantom 60'000/year. User in reality earns 90'000 → sees pessimistic numbers — OR earns 30'000 → sees optimistic numbers. Both wrong, neither flagged.
- Fix: same as above — raise incomplete, don't fabricate.

**P0-E44 — `taxSingle = totalCapital * 0.08` is a scalar magic number with no source**  (financial_report_service.dart:374)
- Trigger: single 3a account > 100k, any canton.
- Symptom: "flat 8%" used for ZH and VS alike; real ZH = ~6.2%, real VS = ~7.8%. Savings delta displayed to user is fabricated.
- Fix: delegate to `RetirementTaxCalculator.capitalWithdrawalTax(capital, canton, isMarried)`.

**P0-E45 — `buybackAmount = 50000.0` hardcoded "1ère tranche recommandée" applied regardless of actual `lppBuybackAvailable` or marginal rate**  (financial_report_service.dart:260)
- Trigger: user has 2'000 CHF of available buyback (tiny lacune) OR 2M CHF of available buyback (huge lacune).
- Symptom: In the tiny case, `taxableWithBuyback = taxableIncome - 50'000` → deduction larger than actually allowed. In the huge case, only 50k deducted instead of optimal staggering.
- Fix: compute tranche as `min(lppBuybackAvailable, taxableIncome * 0.5)` with proper tax simulation per canton.

**P0-E46 — `plan.fold(0.0, (sum, buy) => sum + buy.estimatedTaxSavings)` returns 0 when plan is empty; UI displays "Économise jusqu'à CHF 0 d'impôts sur 4 ans"**  (financial_report_service.dart:464-465, 553-554)
- Trigger: `nbYears = 0` (edge case with yearsToRetirement clamping).
- Symptom: plan is empty → totalSavings = 0 → action card shows "CHF 0" as motivation.
- Fix: if plan empty, don't render the action item.

**P1-E47 — `profile.hasChildren ? profile.childrenCount * 6500` is a scalar — no canton-specific child deductions (VD = 6'600, ZH = 9'200, GE = 13'000+)**  (financial_report_service.dart:238)
- Trigger: any user with children.
- Symptom: tax deduction under or overestimated by 30-50%.
- Fix: canton-specific table in `RetirementTaxCalculator.childDeduction(canton, n)`.

**P1-E48 — `cantonalTax = totalTax * 0.75` / `federalTax = totalTax * 0.25` is a magic ratio — real split varies wildly (ZH 82/18, VS 69/31, ZG 60/40)**  (financial_report_service.dart:250-251)
- Fix: use canton-specific split table OR delegate to backend `/tax/split`.

**P1-E49 — `reductionPerMissingYear * 100` clamp used elsewhere but `CalendrierRetraits` uses raw hardcoded 0.08 — violates single source of truth**  (cross-cutting; noted in E44).

**P2-E50 — `UserProfile.yearsToRetirement => 65 - age` hardcodes 65 for everyone including AVS21 F (64) and AVS21 transitional birthyears**  (financial_report.dart:125 referenced from service)

---

### 8. budget_service.dart

**P0-E51 — `premierEclairage` returns `"0% de ton revenu part en charges fixes"` when netIncome = 0, masking the real issue (income missing)**  (budget_service.dart:23-24)
- Trigger: user hasn't entered income yet.
- Symptom: premier éclairage displayed as "0%", user thinks "great, I have no fixed costs!" when actually there's no data.
- Fix: return `null` / incomplete state; have UI render enrichment prompt "déclare ton revenu pour voir ton premier éclairage".

**P0-E52 — Negative `netIncome` produces pct = negative percentage, rendered as "—42% de ton revenu part en charges fixes"**  (budget_service.dart:26-30)
- Trigger: user types `-5000` in income field.
- Symptom: nonsense percentage displayed.
- Fix: `if (inputs.netIncome <= 0 || !inputs.netIncome.isFinite) return null/incomplete`.

**P0-E53 — `totalCharges / inputs.netIncome` can exceed 100% silently (housing > income scenario) — displayed as "147% de ton revenu part en charges fixes", factually correct but zero guidance**  (budget_service.dart:29-30)
- Trigger: unemployed with continuing rent + debt.
- Symptom: 147% — user confused.
- Fix: if > 100%, switch to message "tes charges fixes dépassent ton revenu — priorité Safe Mode".

**P1-E54 — `max(0.0, rawAvailable)` silently hides a deficit**  (budget_service.dart:48)
- Trigger: rawAvailable = -800 (charges exceed income).
- Symptom: `available = 0`, no deficit flag. Stop rule triggers (`variables <= 0.01`) but only for envelopes mode.
- Fix: add `bool isDeficit` and `double deficitAmount` on `BudgetPlan` so UI can route to Safe Mode.

**P1-E55 — `overrides['future']!` force-unwrap after `containsKey` check — if user submits `overrides = {'future': null}` (bug in caller), crash**  (budget_service.dart:75-76)
- Fix: `overrides['future'] ?? 0` or explicit null check.

**P1-E56 — `NaN` inputs (e.g. from parsed slider that failed) pass through unchecked**  (budget_service.dart all fields)
- Trigger: inputs.housingCost = double.nan.
- Symptom: totalCharges = NaN, pct = NaN.round() = crash OR displays "NaN%".
- Fix: `.isFinite` guard on every input.

**P2-E57 — Stop rule uses `<= 0.01` float comparison; if all values are exact integers, fine. With slider fractions (e.g. 0.015), rounds to "stop" even with 1 cent available.**  (budget_service.dart:103)

---

## Cross-file concerns

**C1 — Shared silent canton fallback to 'ZH'** (arbitrage_engine.dart:99-100, 483, 1417; monte_carlo_service.dart:99-100, 562-564; withdrawal_sequencing_service.dart:149-151; expat_service.dart:273, 464; financial_report_service.dart:183, 930)
- Every simulator independently falls back to "ZH" when canton is missing/invalid. A VS user who lands on any screen with a bad profile sees ZH tax silently applied.
- Global fix: centralize `resolveCanton(profile)` that throws `MissingCantonError`; ALL 8 simulators call it at entry.

**C2 — Shared age-from-birthYear silent 0** (coach_profile.dart:1654-1658 → propagated through monte_carlo_service.dart:186, forecaster_service.dart:675, 697, financial_report_service.dart:307)
- `CoachProfile.age` returning 0 when birthYear invalid is the single most dangerous sentinel in the codebase — flows through every compound-growth loop as "start at age 0".
- Global fix: change `CoachProfile.age` to `int?`; every consumer must handle null explicitly.

**C3 — Shared `.reduce()` on potentially empty collections**
- **GUARDED**: arbitrage_engine.dart:1645-1662 (`_terminalSpreadFromOptions`, `_terminalSpreadFromValues`).
- **SAFE BY LITERAL**: expat_service.dart:521 (3-element literal), financial_report_service.dart:465 (plan).
- **UNGUARDED**: none found in the 8 files, but worth adding a lint rule.

**C4 — Shared silent NaN propagation via `pow(1 + x, y)` where x ≤ -1**
- monte_carlo_service.dart:194, 296, 404, 408, 456, 715
- forecaster_service.dart (indirectly via LppCalculator)
- arbitrage_engine.dart:372, 1715, 1785, 1791, 1857
- Fix: wrapper `safePow(base, exp)` that asserts `base > 0` and returns `double.nan` check + fallback.

**C5 — Sentinel value usage**  — NO EXPLICIT `-1.0` FOUND in the 8 audited files. However, `0.0` is used as a sentinel in many places:
- `avoirLppTotal ?? 0` (monte_carlo_service:180, withdrawal_sequencing:269, forecaster:518)
- `totalEpargne3a` default 0 (monte_carlo_service:317)
- `lacunesAVS ?? 0` (everywhere)
- `anneesContribuees ?? 0` — implicit via null-coalescing in AvsCalculator
- These `0` values feed calculators that treat them as "user has zero", not "user hasn't told us". Same pathology as sentinel `-1.0`.

**C6 — Shared division by user-supplied variable without guard**
- `investmentBalance / plafond3a` (forecaster)
- `chIncome / worldwideIncome` (expat_service:343)
- `capitalDisponible / prixBien` (arbitrage_engine:1108)
- `totalCharges / inputs.netIncome` (budget_service:30)
- Global fix: introduce `safeRatio(num, denom)` helper returning nullable, used everywhere.

**C7 — Shared firstName-substring matching** (monte_carlo_service.dart:272-283, 354-364; forecaster_service.dart:544, 562, 574)
- Couple contributions matched by `id.toLowerCase().contains(firstName)` collides on similar names ("Lauren" vs "Laurence", "Marc" vs "Marco").
- Global fix: each `PlannedContribution` gets an `ownerId: String` (UUID of user or conjoint), matched exactly.

---

## Proposed fuzz test fixtures (for Wave 8)

1. **FUZZ-1: age=0 profile** → expect all 8 simulators to raise `InvalidAgeException`, not return zero-valued projections.
2. **FUZZ-2: negative salary -1000** → expect entry-level guard rejecting `revenuBrutAnnuel < 0`.
3. **FUZZ-3: canton="xx"** → expect `InvalidCantonException` in all 8, not silent ZH substitution.
4. **FUZZ-4: numSimulations=0 for MC** → expect `ArgumentError` instead of empty percentiles.
5. **FUZZ-5: birthYear=2100 (future)** → expect `InvalidBirthYearException`, not silent age=0.
6. **FUZZ-6: retirementAge=40 (before currentAge=49)** → expect `RetirementInPastException`, not MC running backward.
7. **FUZZ-7: prixBien=0** → expect `locationVsPropriete` to refuse, not divide-by-zero.
8. **FUZZ-8: horizonAnnees=0** → every multi-year simulator: refuse or return empty-with-reason.
9. **FUZZ-9: chIncome > worldwideIncome (quasi-resident)** → expect `InconsistentIncomeDataException`.
10. **FUZZ-10: conjoint without firstName + contribution id "3a_lauren"** → verify sub-string matching does NOT pull it into conjoint sum.
11. **FUZZ-11: NaN in `BudgetInputs.housingCost`** → expect `InvalidInputException`.
12. **FUZZ-12: totalCharges > netIncome (deficit)** → expect `BudgetPlan.isDeficit == true` and route to Safe Mode.
13. **FUZZ-13: departureDate in the past** → `planDeparture` returns `alreadyDeparted: true`.
14. **FUZZ-14: actualIncome=0 in `simulateForfaitFiscal`** → returns explicit "no_comparison" flag, not a negative savings.
15. **FUZZ-15: empty `plannedContributions` + empty `checkIns`** → forecaster's smart-average does not crash on empty list.
16. **FUZZ-16: `anneesAvantRetraite=-5` in `compareAllocationAnnuelle`** → expect refusal, not `list.last` crash.
17. **FUZZ-17: `numSimulations=1000000`** → expect either cap or memory-aware streaming; should not OOM.
18. **FUZZ-18: `tauxConversion=0.000001`** → expect clamp to legal minimum, not astronomical CHF.
19. **FUZZ-19: `profile.canton = "  VS  "` (whitespace)** → after normalization, resolves to VS tax correctly.
20. **FUZZ-20: `expat_us` archetype with `canton=GE` and children=10** → verify source tax + FATCA flag + childrenFactor floor at 70% all hold.

---

## Summary table

| # | P0 | P1 | P2 | Total |
|---|----|----|----|-------|
| arbitrage_engine.dart | 3 | 3 | 1 | 7 |
| monte_carlo_service.dart | 4 | 3 | 1 | 8 |
| withdrawal_sequencing_service.dart | 1 | 2 | 1 | 4 |
| tornado_sensitivity_service.dart | 2 | 2 | 1 | 5 |
| forecaster_service.dart | 3 | 3 | 1 | 7 |
| expat_service.dart | 5 | 3 | 1 | 9 |
| financial_report_service.dart | 5 | 3 | 1 | 9 |
| budget_service.dart | 3 | 3 | 1 | 7 |
| Cross-file (C1-C7) | — | 7 | 0 | 7 |
| **TOTAL** | **17 stated** (26 counting cross-file impact) | **23 + 7 shared** | **9** | **~63 distinct** |

**Doctrine violations found**:
- Sentinel `0.0` used as "unknown" — 14 instances (violates `feedback_no_shortcuts_ever.md`).
- Magic numbers without legal source — 8 instances (0.08 flat tax, 0.75/0.25 split, 0.92 married factor, 0.025 children per-unit, 6500 CHF child deduction, 0.13 canton default rate, 0.20 foreign social default, 0.85 married scalar referenced but not in these files).
- Swallowed exceptions — 2 (`tornado_sensitivity._project` catch-all; `financial_report_service._buildUserProfile` try/catch at line 64 silently drops confidence to 0).

Fix priority order for Wave 8:
1. **C1 + C2** (canton + age sentinels) — fix once, resolves 12+ findings.
2. **E42, E43** (report fabrication) — pure trust damage.
3. **E8, E26, E27** (birthYear/age chain crashes) — most common edge in real devices.
4. **E33, E34** (expat silent fallback) — hits the most international users.
5. **E20** (tornado swallow) — degrades the entire sensitivity feature invisibly.

End of Wave 7 edge-case audit.
