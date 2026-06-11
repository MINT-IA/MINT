# Matrice des illogismes MINT — 2026-06-09

Findings code+registry confirmes par un agent adverse (reproduits). Grounding sim a confirmer separement. Total confirmes: 44.

## 1. Doublons d ecrans
- [medium] /mon-argent (MonArgentScreen) ~ /profile/bilan (FinancialSummaryScreen) — OBSERVED information-class overlap (not a builder-alias). Both surfaces render the same financial-situation triad patrimoine + dettes + futur from the same data sources. MonArgentScreen imports patrimoine_aggregator + patrimoine_summary_card + budget_summary_card (mon_argent_screen.dart:15,20,21). FinancialSummaryScreen ('Mon apercu' — Le Gap + 3 tiroirs) imports patrimoine_drawer_content + dettes_drawer_content + futur_drawer_content (financial_summary_screen.dart:20,21,22, header financial_summary_screen.dart:30). financial_summary_screen.dart:28 self-documents the overlap: 'Keep for /profile/bilan deep link and ProfileScreen access.' Two distinct widget trees presenting the same patrimoine/dette/futur info to the user. REPRO of the claim is structural (imports + header comments cited), not a calc-oracle case. Classification: CONFIRMED information-overlap (soft duplicate).
- [low] /decaissement (OptimisationDecaissementScreen) ~ /3a-deep/staggered-withdrawal (StaggeredWithdrawalScreen) — OBSERVED topic overlap on 3a echelonne withdrawal, same legal basis. OptimisationDecaissementScreen header: 'Ecran educatif sur l'echelonnement des retraits du pilier 3a ... LIFD art. 38, OPP3 art. 3' (optimisation_decaissement_screen.dart:1-7) and uses NO calc service (grep showed only screen_completion_tracker import, no Service/calculate). StaggeredWithdrawalScreen header: 'Ecran de simulation du retrait 3a echelonne multi-comptes ... compare l'impot en bloc vs echelonne ... LIFD art. 38' (staggered_withdrawal_screen.dart:20-24) and DOES use pillar_3a_deep_service (staggered_withdrawal_screen.dart:9). Classification: CONFIRMED topic-overlap but DIFFERENT MODE (educational text vs interactive calculator) — soft duplicate / fragmentation, not redundant computation. Lower severity because they are complementary, not identical.
- [low] /profile/privacy-control (PrivacyControlScreen) ~ /profile/privacy (PrivacyCenterScreen) ~ /settings/confidentialite (ConfidentialiteSettingsScreen) — OBSERVED clustering of three privacy/data-control surfaces that a user could plausibly conflate. Verified DISTINCT concerns: PrivacyControlScreen = biography facts 'Ce que MINT sait de toi' (privacy_control_screen.dart:14-22, BiographyProvider); PrivacyCenterScreen = consent receipts revocation hub (privacy_center_screen.dart:1-4, ConsentService); ConfidentialiteSettingsScreen = single cloud-sync opt-in toggle (confidentialite_settings_screen.dart:11-20, AuthProvider.toggleCloudSync). Classification: NOT a true duplicate (different data + actions) but fragmented privacy UX across 3 routes with no shared hub — flagged as discoverability/fragmentation risk, not redundant info.
- [low] /retraite (RetirementDashboardScreen) ~ /confidence (ConfidenceDashboardScreen) — A_REPRODUIRE. Both named 'dashboard' and both plausibly summarise retirement-readiness/score state, but content overlap was NOT verified field-by-field in this pass (only file headers + builders read). RetirementDashboardScreen (app.dart:779-781) vs ConfidenceDashboardScreen (app.dart:1536-1538, takes a ConfidenceResult). Cannot assert duplicate without reading both bodies. Classification: A_REPRODUIRE (needs body diff to confirm or clear).

## 2. Quantites a sources divergentes (pas de source unique)
- **Avoir LPP (balance estimate from age + salary)** — sites: apps/mobile/lib/services/minimal_profile_service.dart:196 (_estimateLppBalance — coord clamped [3780,64260], interest reg lpp.min_interest_rate=1.25%) / apps/mobile/lib/models/coach_profile.dart:3577 (_estimateLppAvoir — coord clamped MIN only, NO max cap; interest hardcoded 1.01=1%) / apps/mobile/lib/models/coach_profile.dart:2857 (caller of _estimateLppAvoir, user) / apps/mobile/lib/models/coach_profile.dart:3156 (caller of _estimateLppAvoir, conjoint) / apps/mobile/lib/services/financial_core/monte_carlo_service.dart:221-247 (3rd inline balance loop: lppBalance *= (1+lppReturnYear); += salaireCoord*getLppBonificationRate(a)) — REPRO (/tmp/lpp_oracle.py, registry-cited constants): age=50, grossAnnual=120000 -> Site A minimal_profile_service=179118.27, Site B coach_profile._estimateLppAvoir=253959.33, DIFF=+74841 (+41.8%). Cause #1: coach_profile omits the lppSalaireCoordMax=64260 clamp (registry lpp.max_coordinated_salary) so coord=93540 instead of 64260. Cause #2 (isolated at gross=80000, coord below cap): Site A=149237.35 vs Site B=145360.09, DIFF=-2.6% because coach_profile hardcodes 1% growth (1.01) vs registry lpp.min_interest_rate=1.25%. A 3rd inline loop exists in monte_carlo_service. None delegate to LppCalculator. Classification: DIVERGENT (>1 site, non-equal outputs) + registry-deviation in coach_profile.
- **Rente LPP mensuelle (from avoir x conversion rate)** — sites: apps/mobile/lib/screens/mariage_screen.dart:94 (avoir * 0.068 / 12, hardcoded) / apps/mobile/lib/services/response_card_service.dart:776 (avoir * lppTauxConversionSurobligDecimal=0.058 / 12) / apps/mobile/lib/services/minimal_profile_service.dart:108-111 (complementaire 0.058 vs reg 0.068 branch, then projectToRetirement) / apps/mobile/lib/screens/profile/financial_summary_screen.dart:127 (avoir * profile.tauxConversion / 12, default 0.068) / apps/mobile/lib/services/cap_sequence_engine.dart:622 (_estimateLppMonthly: avoir * profile.tauxConversion / 12) / apps/mobile/lib/services/independants_service.dart:599 (capitalLpp * _tauxConversion=0.068) — REPRO (/tmp/rente_oracle.py): same avoir=300000 -> mariage_screen 0.068=1700 CHF/mo vs response_card 0.058=1450 CHF/mo, spread=250 CHF/mo for the SAME stored avoirLppTotal. Distinct rates {0.058,0.068} applied to identical input. Additionally ALL these flat 'avoir*rate/12' sites bypass LppCalculator.adjustedConversionRate (LPP art.13 al.2 early-retirement reduction in financial_core lpp_calculator.dart:43-52), so early-retirement cases diverge further from canonical. Classification: DIVERGENT.
- **Taux de remplacement (replacement rate)** — sites: apps/mobile/lib/services/minimal_profile_service.dart:129-130 (totalMonthlyRetirement / grossMonthlySalary — denominator = GROSS/12) / apps/mobile/lib/services/response_card_service.dart:789-790 (totalMonthly / currentMonthly *100 — denominator = NET via NetIncomeBreakdown.monthlyNetPayslip) / apps/mobile/lib/services/budget_living_engine.dart:254 (retirement.monthlyNet / grossMonthlySalary *100) — DIVERGENT denominator base: minimal_profile_service divides projected retirement income by GROSS monthly salary (line 128 grossMonthlySalary = grossSalary/12), while response_card_service divides by NET monthly payslip (NetIncomeBreakdown). For gross 120000 / net ~7500, the same retirement income yields a replacement rate ~37% higher when divided by net vs gross. budget_living_engine mixes monthlyNet(retirement) over grossMonthlySalary. No single canonical replacement-rate function. Classification: DIVERGENT (incommensurable denominators). Numerator also inherits the divergent rente-LPP and AVS estimators above.
- **Marge libre mensuelle (monthly free margin / net-from-gross basis)** — sites: apps/mobile/lib/services/budget_living_engine.dart:153 (monthlyFree = monthlyNet - monthlyCharges - monthlySavings; monthlyNet via BudgetInputs — canonical budget path) / apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart:396 (monthlyFree = monthlyNet[NetIncomeBreakdown.compute] - fixedCosts - debtPayments - alreadySaving) / apps/mobile/lib/services/cap_sequence_engine.dart:653 (net = salaireBrutMensuel * 0.78 — flat ratio) / apps/mobile/lib/services/minimal_profile_service.dart:229 (netMonthly = grossAnnualSalary * 0.75 / 12 — flat ratio) / apps/mobile/lib/services/premier_eclairage_selector.dart:377 (netAnnual = grossAnnualSalary * 0.75 — flat ratio) / apps/mobile/lib/services/coach/coach_profile_seeds.dart:133 (netMonthlyIncome ?? grossMonthlySalary * 0.78) — REPRO (/tmp/net_oracle.py): gross 120000 -> net basis 7500 CHF/mo via *0.75 sites vs 7800 CHF/mo via *0.78 sites = 300 CHF/mo spread on identical gross, and BOTH bypass the canton+age-aware canonical NetIncomeBreakdown.compute used by budget_living_engine / cross_pillar_calculator. Since marge libre = net - charges, a 300 CHF/mo net divergence propagates directly into every free-margin and reallocation suggestion. Classification: DIVERGENT (flat 0.75/0.78 ratios vs canonical NetIncomeBreakdown).
- **Rente AVS mensuelle** — sites: apps/mobile/lib/services/financial_core/avs_calculator.dart:29 (AvsCalculator.computeMonthlyRente — canonical, RAMD/echelle44 + anticipation/deferral/gender) / apps/mobile/lib/services/cap_sequence_engine.dart:609-614 (_estimateAvsMonthly: 2520 * years / 44, income-blind flat formula) / apps/mobile/lib/screens/mariage_screen.dart:94 (note: this line is LPP not AVS — AVS in mariage delegates elsewhere) — REPRO (/tmp/avs_oracle.py): cap_sequence_engine._estimateAvsMonthly ignores income/RAMD and assumes full-career = max rente. years=44,RAMD=50000 -> cap_sequence=2520 CHF/mo vs canonical AvsCalculator (renteFromRAMD*gapFactor)=1865 CHF/mo, DIFF=+655; RAMD=30000 -> +998 CHF/mo overestimate. The flat formula also ignores anticipation (-6.8%/yr) and deferral bonus that financial_core applies. Most AVS sites (minimal_profile_service, response_card, retirement_projection, financial_report, forecaster) correctly delegate to AvsCalculator — cap_sequence_engine is the lone divergent estimator. Classification: DIVERGENT (income-blind site overestimates vs RAMD-based canonical).
- **Capacite rachat LPP (buyback capacity + its monthly impact)** — sites: apps/mobile/lib/services/cap_sequence_engine.dart:639-644 (_estimateRachatImpact: rachat * profile.tauxConversion / 12) / apps/mobile/lib/services/response_card_service.dart:716-730 (rachatMax read from profile.prevoyance.rachatMaximum; tax saving = rachatSimule * marginalRate) / apps/mobile/lib/services/job_comparison_service.dart:75 (avoirVieillesse * tauxConversionSurobligatoire / 100) / apps/mobile/lib/services/cap_engine.dart:203 (rachatMax read from profile, display only) — The buyback CAPACITY (rachatMaximum) is a stored profile field, not computed (read from certificate) — consistent. But the buyback monthly IMPACT/benefit is re-derived divergently: cap_sequence_engine._estimateRachatImpact uses rachat * profile.tauxConversion/12 (default 0.068), while job_comparison_service uses avoirVieillesse * tauxConversionSurobligatoire/100 (suroblig rate). Same conversion-rate inconsistency as the rente-LPP finding: a rachat of 50000 at 0.068 = 283 CHF/mo vs at 0.058 = 242 CHF/mo. No canonical 'rachat impact' helper in financial_core; these are ad-hoc. Classification: DIVERGENT (conversion-rate basis inconsistency across impact estimators).
- **Retraite projetee CHF/mois (total projected retirement income)** — sites: apps/mobile/lib/services/minimal_profile_service.dart:127 (totalMonthlyRetirement = max(0, avsMonthly + lppMonthly - debtService)) / apps/mobile/lib/services/response_card_service.dart:782 (totalMonthly = monthlyAvs + lppMonthly — no debt subtraction) / apps/mobile/lib/services/retirement_projection_service.dart:482-528 (LppCalculator.projectToRetirement + AvsCalculator, couple-aware) / apps/mobile/lib/services/coach_narrative_service.dart:280 (totalMonthly = avsMonthly + lppAnnual/12) — DIVERGENT composition: minimal_profile_service subtracts effectiveDebtService from the retirement total (line 127), response_card_service does NOT (line 782, pure avs+lpp), and each pulls a DIFFERENT lppMonthly basis (minimal_profile uses projectToRetirement at 0.058/0.068; response_card uses flat avoir*0.058/12 at line 776). So for the same profile the 'retraite projetee CHF/mois' differs both by the debt term AND by the inherited divergent LPP rente. Not numerically re-run end-to-end here (depends on multi-field profile) so the exact CHF delta is A_REPRODUIRE, but the structural divergence (different formula terms + different LPP basis) is grep-proven. Classification: DIVERGENT (formula composition differs).

## 3. Illogismes par archetype (TOUS, sans deduplication)

### Archetype: salarie_swiss (6 findings)

**salarie_swiss-1 · Avoir LPP estimé (balance) — affiché/utilisé pour rente LPP [DIVERGENT]**
- Input: Salarié 42 ans, VD, marié, 8500 CHF/mois brut = 102000/an, a une LPP
- Output MINT: Site A (minimal_profile_service.dart:196 _estimateLppBalance) = 98627.20 CHF (salaire coordonné plafonné 64260, intérêt 1.25%). Site B (coach_profile.dart:3577 _estimateLppAvoir) = 113803.81 CHF (salaire coordonné NON plafonné = 75540, intérêt 1.01=1%).
- Attendu: Salaire coordonné DOIT être plafonné à lppSalaireCoordMax=64260 (registry social_insurance.dart:63, LPP art.8). Une seule valeur d'avoir LPP attendue pour un input identique. Intérêt minimal = lpp.min_interest_rate 1.25% (social_insurance.dart:92).
- Source: apps/mobile/lib/models/coach_profile.dart:3580 (clamp min-only, pas de max cap) vs apps/mobile/lib/services/financial_core/lpp_calculator.dart:94 (clamp min ET max) ; constantes social_insurance.dart:63,92
- Reproduction: /tmp/archetype_oracle.py (constantes registry citées) : age=42, gross=102000 -> coord_capped=64260, coord_uncapped=75540 ; Site A balance=98627.20, Site B balance=113803.81, DIFF=+15176.61 (+15.4%). Cause #1: coach_profile omet le clamp max 64260 (coord=75540 au lieu de 64260). Cause #2 isolée (même cap): 1% vs 1.25% donne -1.84%. Aucun des deux ne délègue à LppCalculator.
- Illogisme: Pour CE profil (gross 102000 > seuil de plafonnement 90720 = 64260+26460), le salaire coordonné dépasse le plafond légal, donc le bug du clamp manquant MORD effectivement: deux écrans affichent un avoir LPP différent de +15.4% pour le même utilisateur marié salarié. coach_profile surestime car il ignore le plafond LPP art.8.

**salarie_swiss-2 · Économie d'impôt 3a (taxSaving3a) — onboarding minimal profile [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Salarié 42 ans, VD, MARIÉ, 102000/an, a une LPP, contribution 3a max 7258
- Output MINT: minimal_profile_service.dart:136-141 appelle estimate3aTaxImpact SANS passer isMarried ni children -> tarif célibataire appliqué. Taux marginal ~19.36%, économie 3a affichée ~1405 CHF.
- Attendu: L'archetype est marié -> tarif marié (marie_sans_enfant adj=0.85, tax_calculator.dart:373) -> taux marginal ~16.45%, économie 3a ~1194 CHF. La fonction estimate3aTaxImpact ACCEPTE isMarried (tax_calculator.dart:535) mais l'appelant ne le fournit pas (défaut false).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:136-141 (appel sans isMarried/children) ; tax_calculator.dart:412-423 (familyAdjustment) ; tax_calculator.dart:373 (marie_sans_enfant=0.85)
- Reproduction: /tmp/tax_oracle.py : VD_EFF=0.1489, factor 1.3 ; single marginal=0.1936 -> saving=1405 CHF ; married marginal=0.1645 -> saving=1194 CHF ; surestimation=211 CHF (+17.6%).
- Illogisme: minimal_profile_service connaît householdType ('couple'/married) ligne 50-51 mais ne le transmet pas au calcul fiscal 3a. Pour un marié VD, l'app surestime l'économie d'impôt 3a de ~17.6% en appliquant le barème célibataire. Le champ existe, l'info existe, elle est perdue à l'appel.

**salarie_swiss-3 · Économie d'impôt 3a — DIVERGENCE inter-écran (onboarding vs response card) [DIVERGENT]**
- Input: Même archetype marié VD 102000, vu via deux chemins de rendu
- Output MINT: response_card_service.dart:674-678 passe isMarried=true (etatCivil==marie) au calcul 3a. minimal_profile_service.dart:136-141 ne passe RIEN (false). Deux économies d'impôt différentes pour le même utilisateur selon l'écran.
- Attendu: Un même input marié doit produire une seule économie d'impôt 3a quel que soit l'écran. Soit 1194 CHF (marié, correct) partout.
- Source: apps/mobile/lib/services/response_card_service.dart:674-678 (isMarried passé) vs apps/mobile/lib/services/minimal_profile_service.dart:136-141 (isMarried omis)
- Reproduction: /tmp/tax_oracle.py : chemin response_card -> 1194 CHF (married) ; chemin minimal_profile -> 1405 CHF (single). DIFF=211 CHF pour input identique. La divergence est structurelle: un site câble l'état civil, l'autre non.
- Illogisme: Le même profil marié voit deux économies 3a distinctes (1194 vs 1405 CHF) selon qu'il est sur l'onboarding ou la response card. Incohérence de single-source-of-truth: les deux appellent financial_core mais avec des paramètres différents.

**salarie_swiss-4 · Rente LPP mensuelle (taux de conversion appliqué à l'avoir) [DIVERGENT]**
- Input: Archetype marié -> écran mariage prérempli avec avoirLppTotal ; vs response card
- Output MINT: mariage_screen.dart:94 = avoir * 0.068 / 12 (6.8%). response_card_service.dart:776 = avoir * lppTauxConversionSurobligDecimal=0.058 / 12 (5.8%). Pour avoir=98627: mariage=558.89 CHF/mo vs response_card=476.70 CHF/mo, écart=82.19 CHF/mo.
- Attendu: Un taux de conversion unique pour le même avoir stocké, ou délégation à LppCalculator.adjustedConversionRate (lpp_calculator.dart:43). Les deux taux {0.058, 0.068} sont appliqués au MÊME avoirLppTotal.
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (0.068 hardcodé) vs apps/mobile/lib/services/response_card_service.dart:776 (0.058) ; LppCalculator.adjustedConversionRate non utilisé
- Reproduction: /tmp/archetype_oracle.py : avoir=98627 -> 0.068 path=558.89/mo, 0.058 path=476.70/mo, spread=82.19/mo. Cet archetype marié atterrit sur mariage_screen (préremplissage ligne 91-95) ET sur la response card replacement_rate -> deux rentes LPP différentes pour le même avoir stocké.
- Illogisme: Cet archetype marié voit potentiellement deux rentes LPP différentes (~559 vs ~477 CHF/mo) pour le même avoir, selon l'écran. Aucun site ne passe par adjustedConversionRate (réduction LPP art.13 al.2 pour retraite anticipée), donc les cas de retraite avant 65 divergeraient encore plus du canonique.

**salarie_swiss-5 · Taux de remplacement (replacement rate) — base du dénominateur [DIVERGENT]**
- Input: Archetype marié VD, gross 102000/an = 8500/mo, net ~7055/mo
- Output MINT: minimal_profile_service.dart:129-130 = totalMonthlyRetirement / grossMonthlySalary (dénominateur BRUT). response_card_service.dart:789-790 = totalMonthly / currentMonthly (dénominateur NET via NetIncomeBreakdown.monthlyNetPayslip). budget_living_engine.dart:253-254 = retirement.monthlyNet / grossMonthlySalary (BRUT).
- Attendu: Un seul dénominateur cohérent pour le taux de remplacement. Mélanger brut et net change le résultat de ~20% pour le même utilisateur.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (GROSS) vs apps/mobile/lib/services/response_card_service.dart:789-790 (NET) vs apps/mobile/lib/services/budget_living_engine.dart:253-254 (GROSS)
- Reproduction: /tmp/archetype_oracle.py : pour revenu retraite=2000, gross_mo=8500 -> 23.5% (dénominateur brut) ; net_mo~7055 -> 28.3% (dénominateur net) ; ratio=1.205. Pour le même archetype et le même revenu de retraite, le taux affiché varie de ~20.5% selon l'écran.
- Illogisme: Le même archetype voit un taux de remplacement ~20% plus élevé sur la response card (base nette) que sur l'onboarding/budget (base brute). budget_living_engine est lui-même incohérent: numérateur NET, dénominateur BRUT (ligne 254 retirement.monthlyNet / grossMonthlySalary), ce qui mélange les bases dans une même formule.

**salarie_swiss-6 · Plafond 3a (annualCeiling) — archetype avec LPP [SOURCED]**
- Input: Salarié 42 ans, VD, marié, a une LPP
- Output MINT: Pour hasLpp=true, tax_calculator.dart:546-547 retourne reg('pillar3a.max_with_lpp')=7258. minimal_profile_service.dart:139 passe hasLpp=!isIndependantNoLpp -> true pour ce salarié -> plafond=7258.
- Attendu: Plafond 3a avec LPP = 7258 CHF (OPP3 art.7 al.1, social_insurance.dart:351). Aucun gate attendu pour ce profil standard.
- Source: apps/mobile/lib/services/financial_core/tax_calculator.dart:546-547 ; apps/mobile/lib/services/minimal_profile_service.dart:139,151 ; constante social_insurance.dart:351
- Reproduction: /tmp/archetype_oracle.py : hasLpp=True -> plafond=7258 (registry pillar3a.max_with_lpp social_insurance.dart:351). Le chemin code (isIndependantNoLpp=false pour 'salarie' -> hasLpp=true -> annualCeiling=7258) correspond à l'attendu OPP3 art.7 al.1.
- Illogisme: Aucun illogisme sur le plafond 3a pour ce profil: la valeur 7258 est correcte et le branchement hasLpp est correct. Confirme la règle attendue (plafond=7258, pas le 36288 indépendant). Pas de gate erroné détecté pour ce salarié marié.

### Archetype: independent_no_lpp (6 findings)

**independent_no_lpp-1 · 3a plafond / ceiling (onboarding -> minimal profile -> home/explorer 3a card) [WRONG]**
- Input: Independant SANS LPP, 39, GE, gross 108000/yr (9000/mo), net pro 86400/yr
- Output MINT: annualCeiling = grossAnnualSalary * 0.20 clamp 36288 = min(108000*0.20, 36288) = 21600 CHF (tax_calculator.dart:548 active branch via minimal_profile_service.dart:135-152). The literal fallback minimal_profile_service.dart:149 also uses grossSalary*0.20.
- Attendu: OPP3 art.7 al.2: 20% of REVENU NET de l'activite lucrative, plafonne a 36288. revenuNet 86400 -> min(86400*0.20, 36288) = 17280 CHF. (independants_service.dart:412 correctly uses revenuNet*0.20.)
- Source: apps/mobile/lib/services/financial_core/tax_calculator.dart:546-549 (hasLpp false -> grossAnnualSalary*pilier3aTauxRevenuSansLpp); apps/mobile/lib/services/minimal_profile_service.dart:139,148-152; constant social_insurance.dart:357 pilier3aTauxRevenuSansLpp=0.20; get_swiss_constants pillar3a.income_rate_without_lpp=0.2, pillar3a.max_without_lpp=36288
- Reproduction: /tmp/mint_archetype_oracle.py [F1]: app base GROSS 108000 -> 21600; correct base NET pro 86400 -> 17280. DIFF +4320 CHF (+25%). Registry-cited: pillar3a.income_rate_without_lpp=0.2 applies per OPP3 art.7 al.2 to net professional income.
- Illogisme: For an independant sans LPP the 3a ceiling is the headline number that justifies the archetype (36288 vs 7258). MINT computes it on GROSS while the law and the dedicated independants_service compute it on NET professional income. The user sees an inflated deductible (21600 instead of 17280), over-stating both his 3a room and the tax saving derived from it.

**independent_no_lpp-2 · 3a plafond — same quantity, two engines disagree on base [DIVERGENT]**
- Input: Independant SANS LPP, 39, GE, net pro 86400
- Output MINT: minimal_profile_service / tax_calculator: 20% x GROSS. independants_service.calculate3aIndependant: 20% x revenuNet.
- Attendu: A single source of truth for the independant 3a ceiling. Both should use revenuNet*0.20 per OPP3 art.7 al.2.
- Source: apps/mobile/lib/services/independants_service.dart:412 (min(revenuNet*0.20, 36288)) vs apps/mobile/lib/services/financial_core/tax_calculator.dart:548 (grossAnnualSalary*0.20)
- Reproduction: /tmp/mint_archetype_oracle.py [F1]: two code paths, same archetype, same intended quantity (independant 3a ceiling), produce 17280 (independants_service, net) vs 21600 (tax_calculator/minimal_profile, gross). A diff is a diff: 17280 != 21600.
- Illogisme: Two calculators in the same app compute the SAME regulatory ceiling for the SAME independant with different bases. Whichever screen the user lands on changes his 3a number — incoherent in-context for an archetype whose whole point is the elevated independant ceiling.

**independent_no_lpp-3 · LPP=0 gate — onboarding/profile engine divergence [DIVERGENT]**
- Input: Independant SANS LPP, 39, GE; q_has_pension_fund answered true OR residual 2e pilier OR mis-tap
- Output MINT: minimal_profile_service gates LPP=0 on employmentStatus=='independant' (line 68). coach_profile gates LPP=0 on !hasPensionFund derived from q_has_pension_fund (line 2786, 2853). The two gates are not equivalent: an independant who answers the pension question 'yes' passes the coach gate and gets a NON-ZERO estimated LPP avoir.
- Attendu: Per profile rules: this archetype's LPP DOIT etre 0 / aucune bonification LPP estimee. Gate should key off the independant-sans-LPP archetype, not a free-standing yes/no question, OR the two engines must use the same gate.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:67-74 (isIndependantNoLpp = employmentStatus=='independant'); apps/mobile/lib/models/coach_profile.dart:2786,2853-2859,3420-3427 (_parseBool null->false; gate = !hasPensionFund)
- Reproduction: /tmp/mint_archetype_oracle.py [F3]: gate predicate differs (employmentStatus vs q_has_pension_fund). When coach gate passes for an independant, _estimateLppAvoir(39, 9000) = 95249 CHF instead of the mandated 0. Verified _parseBool(null)=false (coach_profile.dart:3421) so only an explicit 'yes' triggers it.
- Illogisme: The archetype is defined as 'sans LPP -> 0', but only one of the two profile engines enforces that via employment status. The coach engine can attribute ~95k CHF of phantom LPP avoir (and a phantom rente) to a person who has no caisse — directly violating the archetype rule.

**independent_no_lpp-4 · LPP avoir estimate (the two estimator sites, if a non-zero LPP is ever computed for this profile) [DIVERGENT]**
- Input: age 39, gross 108000 (9000/mo) — the inputs this archetype would feed if mis-gated
- Output MINT: Site A minimal_profile_service._estimateLppBalance = 76213 CHF; Site B coach_profile._estimateLppAvoir = 95249 CHF.
- Attendu: If any LPP estimate is produced at all it must be 0 for this archetype. Independent of the archetype, the two estimators must agree and respect the lpp.max_coordinated_salary=64260 clamp and lpp.min_interest_rate=1.25%.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:196-209 (coord clamped MIN+MAX, interest reg 1.25%) vs apps/mobile/lib/models/coach_profile.dart:3577-3591 (coord clamp MIN only, NO max cap; total*1.01 hardcoded); get_swiss_constants lpp.max_coordinated_salary=64260, lpp.min_interest_rate=1.25
- Reproduction: /tmp/mint_archetype_oracle.py [F2]: Site A coord clamped to 64260; Site B coord 81540 (no max). Site A=76213.35, Site B=95249.44, DIFF +19036 (+25.0%). Cause: coach_profile omits the registry-cited 64260 max clamp and hardcodes 1.01 growth vs reg 1.25%. Neither delegates to LppCalculator.projectToRetirement (financial_core).
- Illogisme: Two non-canonical inline LPP estimators that bypass LppCalculator and disagree by 25%, and coach_profile silently drops the legal coordinated-salary ceiling (64260). For a high earner this systematically over-states LPP. NEVER #3 (no duplicate calc across the boundary): both should delegate to financial_core.

**independent_no_lpp-5 · Rente LPP mensuelle (conversion rate applied to stored avoir) [DIVERGENT]**
- Input: Same stored avoirLppTotal = 300000 across screens
- Output MINT: mariage_screen.dart:94 + cap_sequence + independants_service: avoir*0.068/12 = 1700 CHF/mo. response_card_service.dart:776 + minimal_profile complementaire: avoir*0.058/12 = 1450 CHF/mo.
- Attendu: A single conversion rate for the same avoir (registry lpp.conversion_rate=0.068 obligatoire, or lpp.conversion_rate_complementaire=0.058 — but consistently, and via LppCalculator which also applies the LPP art.13 al.2 early-retirement reduction).
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (0.068 hardcoded); apps/mobile/lib/services/response_card_service.dart:776 (0.058); apps/mobile/lib/services/independants_service.dart:599 (0.068); get_swiss_constants lpp.conversion_rate=0.068, lpp.conversion_rate_complementaire=0.058
- Reproduction: /tmp/mint_archetype_oracle.py [F4]: avoir 300000 -> 1700 vs 1450 CHF/mo, spread 250 CHF/mo for identical input. Both flat 'avoir*rate/12' bypass LppCalculator.adjustedConversionRate (lpp_calculator.dart:43-52).
- Illogisme: The same stored avoir yields a 250 CHF/mo different rente depending on which screen renders it. For an independant who later declares a caisse, the rente shown is screen-dependent and none apply the early-retirement reduction — incoherent across the app.

**independent_no_lpp-6 · Taux de remplacement (replacement rate) [DIVERGENT]**
- Input: gross 108000/yr (9000/mo), net pro ~7200/mo, hypothetical retirement income 3500/mo
- Output MINT: minimal_profile_service: income / GROSS monthly = 3500/9000 = 38.9%. response_card_service: income / NET monthly payslip = 3500/7200 = 48.6%.
- Attendu: A single denominator base for replacement rate (replacement rate is conventionally net-of-tax vs net pre-retirement income; the app must at least pick one base consistently).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (grossMonthlySalary = grossSalary/12 denominator); apps/mobile/lib/services/response_card_service.dart:784-790 (NetIncomeBreakdown.monthlyNetPayslip denominator)
- Reproduction: /tmp/mint_archetype_oracle.py [F5]: same 3500/mo retirement income -> 38.9% (gross denom) vs 48.6% (net denom), spread 9.7 pts. Denominator base differs by code path.
- Illogisme: Same person, same projected retirement income, two screens show a ~10-point different replacement rate purely because one divides by gross and the other by net. The headline 'will I have enough at retirement' number is internally inconsistent.

### Archetype: expat_us (5 findings)

**expat_us-1 · FATCA hard-gate scope — coverage of NEVER #7 gating for archetype=expatUs [ILLOGICAL_FOR_ARCHETYPE]**
- Input: US tax person, 38yo, ZH, 11000 CHF/mo brut. usTaxPerson=true -> CoachProfile.archetype getter (coach_profile.dart:1992) returns FinancialArchetype.expatUs. Expected per archetype rules: hard-gate to /waitlist, NO prevoyance number rendered anywhere (NEVER #7).
- Output MINT: The only archetype/FATCA gate in the app is at the coach entry: coach_chat_screen.dart:1828-1864 calls evaluateCoachArchetypeGate(profile) and redirects expatUs to /waitlist. The GLOBAL GoRouter redirect (app.dart:234-317) gates ONLY on auth scope (public/onboarding/authenticated) — it has NO archetype branch. Routes /home, /mon-argent, /profile/bilan, /explore/* are plain ScopedGoRoute(authenticated) with no archetype redirect. So an expatUs profile that reaches any non-coach screen is NOT gated.
- Attendu: For archetype=expatUs the app must hard-gate to /waitlist and render zero prevoyance numbers (NEVER #7). A single coach-entry gate is insufficient because prevoyance-rendering screens (/profile/bilan etc.) are reachable without passing through /coach/chat.
- Source: apps/mobile/lib/app.dart:234-317 (global redirect, no archetype branch); apps/mobile/lib/screens/coach/coach_chat_screen.dart:1828-1864 (only gate site); apps/mobile/lib/app.dart:1360-1363 (/profile/bilan route, no guard); apps/mobile/lib/models/coach_profile.dart:1992 (usTaxPerson==true -> expatUs)
- Reproduction: Static control-flow proof: grep for archetype/expatUs/canContribute3a/shouldBlock in app.dart redirect returns only the coach gate; route_metadata.dart:872 /profile/bilan and app.dart:1360 wire FinancialSummaryScreen with no redirect. Deterministic: no code path between an authenticated expatUs profile and /profile/bilan invokes evaluateCoachArchetypeGate.
- Illogisme: expatUs is hard-gated at /coach/chat only. Per NEVER #7 and the archetype contract this profile must see no prevoyance calc at all; instead the gate is point-defense on one route, leaving the prevoyance-rendering surfaces (bilan, mon-argent, premier-eclairage) ungated.

**expat_us-2 · Plafond 3a value surfaced for expatUs (with-LPP branch) [ILLOGICAL_FOR_ARCHETYPE]**
- Input: expatUs salarie, gross 132000/yr, ZH, via MinimalProfileService.compute / premier_eclairage_selector.
- Output MINT: minimal_profile_service.dart:146-152 sets plafond3a to reg('pillar3a.max_with_lpp')=7258 CHF for a salaried profile, with NO expatUs/canContribute3a check (the only branch is isIndependantNoLpp). premier_eclairage_selector.dart:289 (_buildTaxSaving3aChoc) and :169-217 (_selectByArchetype) have no expatUs branch, so a 3a tax-saving 'choc' with plafond 7258 can be emitted.
- Attendu: For expatUs canContribute3a==false (coach_profile.dart:2089) — plafond/3a tax-saving must be 0 / suppressed (FATCA: Swiss 3a providers refuse US persons). Showing 7258 CHF/an actionable plafond contradicts the app's own FATCA stance.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:146-152 (plafond3a with-LPP=7258, no FATCA guard); apps/mobile/lib/services/premier_eclairage_selector.dart:169-217 (_selectByArchetype, no expatUs branch); coach_profile.dart:2087-2090 (canContribute3a==false for expatUs)
- Reproduction: Oracle /tmp/fatca_oracle.py: with-LPP plafond branch -> 7258.0 CHF/an (registry pillar3a.max_with_lpp). Expected for expatUs = 0 / not shown. minimal_profile_service.compute() takes no archetype/usTaxPerson argument, so FATCA cannot influence its output by construction.
- Illogisme: MinimalProfileService computes a 3a plafond of 7258 CHF and the eclairage selector can pitch a 3a tax-saving action to a US person, while the app simultaneously holds canContribute3a==false for that same archetype. The calc layer is FATCA-blind.

**expat_us-3 · LPP avoir estimate divergence between two estimation sites (Site A vs Site B) [DIVERGENT]**
- Input: Same profile gross=132000/yr (11000/mo), age 38, salarie. Two code paths estimate the LPP balance from age+salary.
- Output MINT: Site A minimal_profile_service.dart:196-208 clamps coordinated salary to [3780, 64260] (registry max) and uses 1.25% interest. Site B coach_profile.dart:3577 (_estimateLppAvoir) clamps MIN only (no 64260 cap) and hardcodes 1% growth (1.01). For gross=132000 the two diverge.
- Attendu: A single canonical estimate. financial_core LppCalculator is the L1 canonical home; both inline estimators should agree and use registry lpp.max_coordinated_salary=64260 and lpp.min_interest_rate=1.25%.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:196-208 (Site A, both clamps, reg interest); apps/mobile/lib/models/coach_profile.dart:3577 (Site B, no max clamp, hardcoded 1.01)
- Reproduction: Oracle /tmp/fatca_oracle.py, gross=132000, age=38: Site A coord clamped to 64260 -> balance@38=68925.78; Site B coord=105540 (no cap) growth 1.01 -> avoir@38=111614.46; DIFF=+42688.68 (+61.9%). Cause #1: coach_profile omits lppSalaireCoordMax=64260 clamp. Cause #2: hardcoded 1% vs registry 1.25%.
- Illogisme: Two estimators for the identical input produce LPP avoirs 61.9% apart. coach_profile._estimateLppAvoir deviates from registry on both the coordinated-salary cap (lpp.max_coordinated_salary=64260) and the interest rate (lpp.min_interest_rate=1.25% vs hardcoded 1%). Neither delegates to financial_core LppCalculator.

**expat_us-4 · Rente LPP monthly — conversion-rate divergence (0.068 vs 0.058) across sites for same avoir [DIVERGENT]**
- Input: Same stored avoirLppTotal (e.g. 300000) read by mariage_screen vs response_card_service vs financial_summary_screen.
- Output MINT: mariage_screen.dart:94 uses hardcoded 0.068 (`lppRente * 0.068 / 12`). response_card_service.dart:776 uses suroblig/complementaire rate 0.058. financial_summary_screen.dart:127 uses profile.tauxConversion (default 0.068). Same avoir, different rente.
- Attendu: One conversion rate per case via financial_core LppCalculator.adjustedConversionRate (lpp_calculator.dart). A flat avoir*rate/12 at 3 distinct rates for the same stored avoir is internally inconsistent.
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (0.068 hardcoded); apps/mobile/lib/services/response_card_service.dart:776 (0.058); apps/mobile/lib/screens/profile/financial_summary_screen.dart:127 (tauxConversion default 0.068)
- Reproduction: Oracle /tmp/fatca_oracle.py, avoir=300000: 0.068 -> 1700.0 CHF/mo (mariage / financial_summary); 0.058 -> 1450.0 CHF/mo (response_card); spread=250 CHF/mo for the identical stored avoir. Registry has both lpp.conversion_rate=0.068 and lpp.conversion_rate_complementaire=0.058.
- Illogisme: The same avoirLppTotal yields a 250 CHF/mo different rente depending on which screen the user opens. None routes through LppCalculator.adjustedConversionRate, so early-retirement (LPP art.13 al.2) reductions are also bypassed.

**expat_us-5 · Replacement rate (taux de remplacement) — denominator base divergence (GROSS vs NET) [DIVERGENT]**
- Input: Same profile gross 132000/yr (~net 7500/mo). Two engines compute taux de remplacement = retirement income / current salary.
- Output MINT: minimal_profile_service.dart:128-130 divides totalMonthlyRetirement by grossMonthlySalary (= grossSalary/12). response_card_service.dart:789-790 divides totalMonthly by NET (NetIncomeBreakdown.monthlyNetPayslip). budget_living_engine.dart:254 divides by grossMonthlySalary. Same retirement income -> materially different replacement-rate percentage.
- Attendu: A single, consistent denominator base across all replacement-rate computations. Gross vs net denominators are not interchangeable; for gross 11000 / net ~7500 the same numerator gives ~36% spread in the resulting ratio.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (denominator=GROSS); apps/mobile/lib/services/response_card_service.dart:789-790 (denominator=NET payslip); apps/mobile/lib/services/budget_living_engine.dart:254 (denominator=GROSS)
- Reproduction: Deterministic from source: numerator N=totalMonthlyRetirement identical; minimal divides by 11000 (gross/12), response_card divides by ~7500 (net). Ratio_gross/Ratio_net = 7500/11000 = 0.682, i.e. the GROSS-based rate is ~31.8% lower than the NET-based rate for the same person. e.g. N=4000: gross-base=36.4% vs net-base=53.3%.
- Illogisme: Two engines report the same person's replacement rate against incompatible denominators (gross monthly vs net payslip). The user sees two different 'taux de remplacement' for one situation, and neither screen discloses which base it uses.

### Archetype: frontalier (5 findings)

**frontalier-1 · Plafond 3a + taxSaving3a affichés (home/mon-argent via MinimalProfileService) [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Frontalier France, travaille à Genève, 45 ans, 7000 CHF/mois (brut annuel 84 000). NON quasi-résident par défaut.
- Output MINT: plafond3a = reg('pillar3a.max_with_lpp') = 7258 CHF, et un taxSaving3a non nul, calculés inconditionnellement pour TOUT profil (minimal_profile_service.dart:146-153). Aucune porte quasi-résident.
- Attendu: Pour un frontalier GE NON quasi-résident : AUCUNE déduction 3a possible en Suisse (imposé à la source, accord 1973). Le 3a reste juridiquement possible mais SANS avantage fiscal CH. Le service dédié segments_service._add3aRules le dit explicitement (segments_service.dart:497-520 : GE = conditionnel quasi-résident ; non-GE = 'pas de déduction possible', isAlert:true).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:146-153 (plafond3a/taxSaving3a inconditionnels) ; apps/mobile/lib/models/coach_profile.dart:2087-2095 (canContribute3a renvoie true pour TOUT isCrossBorder && revenuBrutAnnuel>0, sans test quasi-résident) ; contraste avec apps/mobile/lib/services/segments_service.dart:494-520
- Reproduction: get_swiss_constants(pillar3a) -> pillar3a.max_with_lpp=7258 (OPP3 art.7 al.1). minimal_profile_service.dart:151 retourne ce 7258 dès que confidence==unavailable, sans aucune branche frontalier/quasi-résident. coach_profile.dart:2093 : `if (isCrossBorder && revenuBrutAnnuel > 0) return true;` accorde l'accès 3a déductible à TOUT frontalier avec salaire, alors que la règle attendue exige le statut quasi-résident GE (>=90% revenus CH + passage déclaration ordinaire).
- Illogisme: Contradiction interne entre deux chemins de code pour le MEME archetype : le hub frontalier dédié (segments_service) gate correctement le 3a sur le statut quasi-résident, mais le chemin générique home/mon-argent (minimal_profile_service + canContribute3a) affiche un plafond 3a de 7258 CHF et une économie d'impôt à un frontalier qui, par défaut (non quasi-résident), ne peut PAS déduire en Suisse. Framing inadapté et potentiellement trompeur fiscalement pour cet archetype.

**frontalier-2 · Avoir LPP estimé (balance estimate) [DIVERGENT]**
- Input: Frontalier, 45 ans, 7000 CHF/mois -> brut annuel 84 000, salaire coordonné = 84000-26460 = 57540 (sous le cap 64260).
- Output MINT: Site A minimal_profile_service._estimateLppBalance = 109 145.24 CHF ; Site B coach_profile._estimateLppAvoir = 106 748.02 CHF. Deux estimations différentes du MEME avoir pour le MEME input.
- Attendu: Une seule valeur canonique. financial_core/lpp_calculator.dart projette avec caisseReturn = reg('lpp.min_interest_rate')=1.25%. Site A respecte 1.25% ; Site B hardcode 1.01 (1%). Aucun des deux ne délègue à LppCalculator.projectToRetirement (NEVER #3 du CLAUDE.md).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:196-209 (1.25% registry) ; apps/mobile/lib/models/coach_profile.dart:3577-3591 (`total = total * 1.01 + ...`, intérêt hardcodé 1%) ; 3e boucle inline apps/mobile/lib/services/financial_core/monte_carlo_service.dart:221-247
- Reproduction: /tmp/frontalier_oracle.py avec constantes registry (coord_deduction=26460, coord_min=3780, coord_max=64260, min_interest_rate=1.25). Pour age=45/brut=84000 : coord=57540 identique des deux côtés (sous cap), Site A=109145.24 vs Site B=106748.02, DIFF=-2397.22 (-2.2%). Cause unique pour CE profil : taux d'intérêt 1.25% (registry) vs 1.01 hardcodé. Le clamp-max manquant de coach_profile n'impacte PAS ce profil (coord 57540 < 64260) mais diverge pour les salaires > ~90720.
- Illogisme: Trois sites recalculent l'avoir LPP indépendamment au lieu de déléguer à financial_core/LppCalculator. coach_profile dévie de la constante registry lpp.min_interest_rate=1.25% (hardcode 1%), produisant un avoir LPP inférieur de 2.2% pour ce frontalier selon l'écran consulté.

**frontalier-3 · Rente LPP mensuelle (avoir x taux de conversion) [DIVERGENT]**
- Input: Même frontalier, avoir LPP stocké = 109 145 CHF (estimation Site A pour ce profil).
- Output MINT: mariage_screen = 618.49 CHF/mois (avoir*0.068/12) ; response_card_service = 527.54 CHF/mois (avoir*0.058/12). Spread de 90.95 CHF/mois pour le MEME avoir stocké.
- Attendu: Un taux de conversion cohérent. Le registry expose lpp.conversion_rate=0.068 (LPP art.14) ET lpp.conversion_rate_complementaire=0.058. Aucun de ces sites ne délègue à LppCalculator.adjustedConversionRate (lpp_calculator.dart:43-52) qui applique la réduction art.13 al.2 pour départ anticipé.
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (0.068 hardcodé) ; apps/mobile/lib/services/response_card_service.dart:776-780 (0.058 suroblig) ; bypass de apps/mobile/lib/services/financial_core/lpp_calculator.dart:43-52
- Reproduction: /tmp/frontalier_oracle.py : avoir=109145.24 -> 0.068/12=618.49 vs 0.058/12=527.54, spread=90.95 CHF/mo. Deux taux distincts {0.058, 0.068} appliqués au même input selon l'écran. Constantes citées : get_swiss_constants(lpp) -> conversion_rate=0.068, conversion_rate_complementaire=0.058.
- Illogisme: L'utilisateur voit une rente LPP différente selon l'écran (mariage vs carte réponse) pour un avoir identique. Aucune des sites ne passe par le calculateur canonique, donc les cas départ-anticipé divergent encore plus.

**frontalier-4 · Taux de remplacement (replacement rate) [DIVERGENT]**
- Input: Même frontalier, brut mensuel 7000 (brut annuel 84 000).
- Output MINT: minimal_profile_service divise le revenu retraite projeté par le BRUT mensuel (7000) ; response_card_service le divise par le NET mensuel (NetIncomeBreakdown.monthlyNetPayslip, ~5600). Pour un même revenu retraite R, le second affiche un taux ~1.25x supérieur.
- Attendu: Un dénominateur unique et cohérent. Le taux de remplacement standard se calcule normalement sur le revenu NET (pouvoir d'achat). Les deux sites doivent partager la même base.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (denominateur = grossSalary/12) ; apps/mobile/lib/services/response_card_service.dart:784-790 (denominateur = NetIncomeBreakdown.monthlyNetPayslip) ; apps/mobile/lib/services/budget_living_engine.dart:254 (gross)
- Reproduction: /tmp/frontalier_oracle.py : grossMonthly=7000 ; en supposant net~80% (5600), même R donne R/5600 vs R/7000 -> ratio 1.250x, soit ~25% de taux de remplacement en plus côté response_card (base NET) vs minimal_profile_service (base BRUT). Diff structurelle de dénominateur, indépendante de la valeur de R.
- Illogisme: Pour le MEME profil, le 'taux de remplacement' affiché diffère de ~25% selon l'écran uniquement parce que le dénominateur est tantôt le brut tantôt le net. Incohérence en contexte : un frontalier comparant deux écrans verra deux taux de remplacement contradictoires.

**frontalier-5 · Salaire coordonné LPP — clamp max manquant (coach_profile) [WRONG]**
- Input: Frontalier Genève à 7000/mois est sous le cap, MAIS la méthode est partagée pour le conjoint/profils à haut revenu. Cap registry lpp.max_coordinated_salary=64260.
- Output MINT: coach_profile._estimateLppAvoir clamp UNIQUEMENT le minimum (.clamp(lppSalaireCoordMin, double.infinity)) — pas de plafond. Le coordonné peut dépasser 64260.
- Attendu: Salaire coordonné borné [3780, 64260] (LPP art.8 al.1/al.2). LppCalculator.computeSalaireCoordonne (lpp_calculator.dart:201-205) et minimal_profile_service:201-202 appliquent bien .clamp(min, max).
- Source: apps/mobile/lib/models/coach_profile.dart:3580-3581 (`(salaireBrut - lppDeductionCoordination).clamp(lppSalaireCoordMin.toDouble(), double.infinity)`) vs apps/mobile/lib/services/financial_core/lpp_calculator.dart:204
- Reproduction: get_swiss_constants(lpp) -> max_coordinated_salary=64260 (LPP art.8 al.1). coach_profile.dart:3581 omet ce plafond. Pour brut>90720 : coord = brut-26460 sans cap, ex. brut=120000 -> coord=93540 au lieu de 64260, surestimation directe de l'avoir LPP. Pour CE frontalier précis (84000) coord=57540<64260 donc non déclenché, mais la méthode est appelée aussi pour le conjoint (coach_profile.dart:3156) et tout profil haut-revenu.
- Illogisme: Déviation de la constante registry : le plancher est clampé mais pas le plafond légal LPP. Tout profil (ou conjoint) au-dessus de ~90 720 CHF de brut voit un avoir LPP surestimé via ce chemin, contrairement au calculateur canonique.

### Archetype: cadre_divorce_hypo (6 findings)

**cadre_divorce_hypo-1 · Avoir LPP estimé (home/profile/mon-argent) — pour utilisateur DIVORCÉ [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Cadre 52 ans, VD, DIVORCÉ, 13500 CHF/mois brut = 162000 CHF/an. hasPensionFund=true, aucun _coach_avoir_lpp saisi → branche d'estimation.
- Output MINT: coach_profile._estimateLppAvoir(age=52, salaireBrutMensuel=13500) = 416250.42 CHF, stocké tel quel dans prevoyance.avoirLppTotal et affiché comme nombre unique certain.
- Attendu: Pour un DIVORCÉ, l'avoir LPP réel a été partagé 50/50 au divorce (CC art. 122 / LFLP art. 22a — uniquement la part acquise pendant le mariage). Un avoir LPP ne PEUT PAS être estimé par age*salaire pour ce profil : il dépend du jugement de divorce. L'app devrait soit demander la valeur réelle, soit afficher 'estimation non fiable — partage divorce' avec un score de confiance, jamais un nombre certain.
- Source: apps/mobile/lib/models/coach_profile.dart:2850-2859 (branche estimedLpp ignore etatCivil) + :3577-3591 (_estimateLppAvoir, formule age*salaire) ; apps/mobile/lib/services/minimal_profile_service.dart : grep etatCivil/divorce = 0 résultat (aucun gate).
- Reproduction: /tmp/mint_oracle_divorce.py (constantes registry citées) : SITE B coach_profile._estimateLppAvoir = 416250.42 CHF. Aucune des branches (coach_profile.dart:2850-2859) ni minimal_profile_service ne consulte etatCivil==divorce → le même nombre serait affiché à un célibataire et à un divorcé.
- Illogisme: L'archetype divorcé voit un avoir LPP estimé (416k) présenté comme un fait certain, alors que la règle attendue interdit explicitement d'estimer la LPP par age*salaire pour ce profil (partage 50/50). Gate manquant : aucune détection de etatCivil==divorce ne déclenche un fallback 'valeur réelle requise' ou un downgrade de confiance.

**cadre_divorce_hypo-2 · Avoir LPP estimé — DIVERGENCE entre 2 sites de calcul (Site A vs Site B) [DIVERGENT]**
- Input: Même profil : age=52, gross_annual=162000 (>> plafond coordonné 64260).
- Output MINT: Site A minimal_profile_service._estimateLppBalance = 203022.70 CHF ; Site B coach_profile._estimateLppAvoir = 416250.42 CHF pour EXACTEMENT le même input.
- Attendu: Un seul site canonique (LppCalculator.computeSalaireCoordonne / projectToRetirement dans financial_core) doit produire UNE valeur. Le salaire coordonné est plafonné à lppSalaireCoordMax=64260 (registry). Deux sites = deux nombres pour le même input = bug.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:201-202 (clamp [3780,64260]) vs apps/mobile/lib/models/coach_profile.dart:3580-3581 (clamp MIN seulement, PAS de cap max) ; financial_core lpp_calculator.dart:201-205 (computeSalaireCoordonne, version canonique avec cap).
- Reproduction: /tmp/mint_oracle_divorce.py : Site A coord=64260 (cappé) → balance 203022.70 ; Site B coord=135540 (NON cappé, = 162000-26460) → balance 416250.42. DIFF = +213227.72 (+105.0%). Cause #1 : coach_profile omet le clamp lppSalaireCoordMax. Cause #2 : coach_profile hardcode 1% (1.01) au lieu de lppTauxInteretMin=1.25% (registry, social_insurance.dart:92).
- Illogisme: Deux chemins de code produisent un avoir LPP qui diffère de 105% pour le même input. Aucun ne délègue à LppCalculator (financial_core, canonique). Pour ce profil haut-revenu (162k) l'écart est maximal car coach_profile ignore le plafond coordonné.

**cadre_divorce_hypo-3 · Rente LPP mensuelle — taux de conversion divergents sur le même avoir [DIVERGENT]**
- Input: Même avoir stocké avoirLppTotal=416250.42 (Site B), profil divorcé.
- Output MINT: mariage_screen.dart:94 → 416250*0.068/12 = 2358.75 CHF/mo ; response_card_service.dart:776 → 416250*0.058/12 = 2011.88 CHF/mo. Spread = 346.88 CHF/mo pour le MÊME avoir stocké.
- Attendu: Un seul taux de conversion canonique appliqué via LppCalculator.adjustedConversionRate (qui applique aussi la réduction LPP art.13 al.2 pour retraite anticipée). Pour un avoir donné, la rente doit être unique.
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (avoir*0.068/12 hardcodé) ; apps/mobile/lib/services/response_card_service.dart:776-780 (avoir*lppTauxConversionSurobligDecimal=0.058/12) ; financial_core lpp_calculator.dart:43-52 (adjustedConversionRate, bypassé par les deux).
- Reproduction: /tmp/mint_oracle_divorce.py : rente@0.068=2358.75 vs rente@0.058=2011.88, spread=346.88 CHF/mo. Constantes citées : lppTauxConversionMinDecimal=0.068 (social_insurance.dart:74), lppTauxConversionSurobligDecimal=0.058 (:79). Les deux sites font 'avoir*rate/12' à plat sans passer par adjustedConversionRate.
- Illogisme: Le même avoir stocké produit deux rentes différentes selon l'écran. De plus, le commentaire response_card_service.dart:779 dit 'conservative 5.4%' alors que la valeur réelle utilisée est 0.058 (5.8%) — commentaire périmé/trompeur.

**cadre_divorce_hypo-4 · Taux de remplacement — base du dénominateur divergente (BRUT vs NET) [DIVERGENT]**
- Input: Même profil 52 ans VD gross 162000, même revenu de retraite projeté.
- Output MINT: minimal_profile_service:128-130 divise par le BRUT mensuel (162000/12=13500) ; response_card_service:784-790 divise par le NET payslip (NetIncomeBreakdown). Pour le même revenu de retraite (ex. 5000/mo) : RR_brut=37.0% vs RR_net≈51.4%.
- Attendu: Un taux de remplacement a une définition unique. Le standard suisse (et le sens économique pour l'utilisateur) est revenu_retraite / revenu_net courant. Mélanger brut et net dans deux écrans donne deux pourcentages incohérents pour le même utilisateur.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (grossMonthlySalary = grossSalary/12, dénominateur BRUT) vs apps/mobile/lib/services/response_card_service.dart:784-790 (currentMonthly = NetIncomeBreakdown.monthlyNetPayslip, dénominateur NET).
- Reproduction: /tmp/mint_repl_oracle.py : dénominateur BRUT 13500 → RR 37.0% ; dénominateur NET ≈9720 (proxy 0.72*brut) → RR 51.4%. Écart de 14.4 points uniquement dû au choix de base, à revenu de retraite identique.
- Illogisme: Le même utilisateur voit deux taux de remplacement éloignés de ~14 points selon l'écran (onboarding vs response card). Incohérence de définition, pas une erreur d'arrondi.

**cadre_divorce_hypo-5 · Divorce simulator — split LPP sur l'avoir TOTAL au lieu de la part acquise pendant le mariage [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Profil divorcé ouvre le simulateur divorce ; _lppConjoint1 pré-rempli depuis avoirLppTotal (=416250 estimé inflaté), _lppConjoint2=80000 défaut.
- Output MINT: life_events_service.dart:116-118 : totalLpp = lpp1+lpp2 ; split = totalLpp/2 ; transfer = /lpp1-lpp2//2. Le partage 50/50 s'applique à l'avoir TOTAL de chaque conjoint.
- Attendu: CC art. 122 / LFLP art. 22a : le partage 50/50 ne porte QUE sur la prévoyance acquise PENDANT le mariage (avoir au mariage exclu, plus intérêts). Splitter l'avoir total (incluant l'acquis avant mariage) surestime le transfert. De plus l'input est pré-rempli avec l'estimation age*salaire inflatée (finding #1/#2).
- Source: apps/mobile/lib/services/life_events_service.dart:114-130 (split sur totalLpp complet, commentaire :115 'accumulated LPP is split 50/50' sans borne mariage) ; pré-remplissage divorce_simulator_screen.dart:86-87 (_lppConjoint1 = profile.prevoyance.avoirLppTotal).
- Reproduction: life_events_service.dart:116-118 : halfLpp = (lpp1+lpp2)/2 ; transferAmount = /lpp1-lpp2//2. Aucune entrée 'avoir au mariage' n'est demandée → le calcul prend implicitement l'avoir entier. Pré-fill : divorce_simulator_screen.dart:87 _lppConjoint1 = avoirLppTotal (l'estimation inflatée du finding #2).
- Illogisme: Pour l'archetype divorcé, l'écran censé être le plus pertinent (divorce) (a) splitte l'avoir total au lieu de la seule part mariage, et (b) part d'un avoir pré-rempli inflaté de +105% (finding #2). Double erreur en contexte : le montant de transfert LPP affiché est doublement non fiable.

**cadre_divorce_hypo-6 · 3a plafond — vérification (contrôle négatif) [SOURCED]**
- Input: Cadre 52 ans salarié avec caisse LPP (hasLpp=true).
- Output MINT: minimal_profile_service.dart:146-152 → branche hasLpp → reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) = 7258 CHF.
- Attendu: Salarié affilié LPP → plafond 3a 'avec LPP' = 7258 CHF (OPP3 art. 7). Correct pour ce profil. (Le plafond sans LPP 36288 ne s'applique qu'aux indépendants sans caisse.)
- Source: apps/mobile/lib/services/minimal_profile_service.dart:146-152 ; constantes apps/mobile/lib/constants/social_insurance.dart:351 (pilier3aPlafondAvecLpp=7258) et :354 (pilier3aPlafondSansLpp=36288).
- Reproduction: /tmp/mint_repl_oracle.py : plafond_with_lpp=7258 ; le code prend bien la branche !isIndependantNoLpp → 7258. Constante registry citée social_insurance.dart:351. Pas de divergence ici : le plafond 3a est correct pour ce profil.
- Illogisme: Aucun — contrôle négatif validé. Le plafond 3a est correct et n'est PAS un illogisme pour cet archetype (l'utilisateur a une LPP, donc 7258 est attendu).

### Archetype: jeune_diplome (5 findings)

**jeune_diplome-1 · Avoir LPP actuel (current 2nd-pillar balance) — onboarding aperçu / mon-argent [SOURCED]**
- Input: age=25, gross=6500 CHF/mo (78000/yr), ZH, célibataire, salarié
- Output MINT: 0.00 CHF at BOTH estimation sites. minimal_profile_service.dart:204 loop `for (int a=25; a<age && a<65; a++)` runs ZERO iterations when age==25; coach_profile.dart:3586 `for (a=startAge=25; a<age; a++)` likewise zero. Oracle /tmp/profile_25_oracle.py: [A]=0.00, [B]=0.00.
- Attendu: 0 CHF (a 25yo just entering the workforce has accumulated essentially no LPP capital).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:196-208 ; apps/mobile/lib/models/coach_profile.dart:3577-3591 ; registry lpp.bonification (LPP art.16, bonifications start at 25)
- Reproduction: /tmp/profile_25_oracle.py site_a_lpp_balance(25,78000)=0.00 and site_b_lpp_avoir(25,6500)=0.00. Loop bound a<age with age=25 => empty range. Matches archetype rule 'LPP quasi nulle (début de carrière)'.
- Illogisme: None for the CURRENT balance — this is the one number that is correctly ~zero for the archetype. The divergence between sites A and B (cap omission + 1% vs 1.25% growth) flagged in Phase-1 context only manifests at age>25; at exactly 25 both sites agree at 0, so for THIS profile there is no observable divergence on the current avoir.

**jeune_diplome-2 · Rente AVS mensuelle — gapFactor forced to full career [ILLOGICAL_FOR_ARCHETYPE]**
- Input: age=25, gross=78000/yr RAMD, ret_age=65, no lacunes, salarié
- Output MINT: 2'400.24 CHF/mo. AvsCalculator: currentYears=(25-20)=5, futureYears=(65-25)=40, total=45→clamp 44, gapFactor=44/44=1.0; renteFromRAMD(78000)=2400.24 (interp between [76440,2370] and [79380,2427]).
- Attendu: Numerically correct per financial_core, BUT gapFactor=1.0 silently assumes the 25yo will complete a flawless 44-year contribution record (no gaps, no time abroad, no career break). For an archetype literally at career start, presenting a full-career AVS as a settled estimate is over-confident.
- Source: apps/mobile/lib/services/financial_core/avs_calculator.dart:52-67,101-102 ; Echelle44 table apps/mobile/lib/constants/social_insurance.dart:210-237
- Reproduction: /tmp/profile_25_oracle.py: cur_years=5, fut_years=40, total clamp 44, gap=1.0, rente_from_ramd(78000)=2400.24. The clamp at line 64 hides that 45>44, i.e. the model bakes in a complete career the user has not lived.
- Illogisme: Same pattern as the LPP projection: a 25yo with 5 actual contribution years is shown an AVS rente (2400 CHF/mo) computed as if 44/44 years are guaranteed. The most career-contingent user gets the most career-certain number.

**jeune_diplome-3 · Taux de remplacement (replacement rate) — divergent denominator across services [DIVERGENT]**
- Input: age=25, gross=78000/yr (6500/mo), total projected retirement income = AVS 2400.24 + LPP 1791.42 = 4191.66 CHF/mo
- Output MINT: minimal_profile_service.dart:129-130 divides by GROSS monthly (6500) => 64.5%. response_card_service.dart:789-790 divides by NET monthly payslip (~5200-5590) => 75.0%-80.6% for the SAME retirement income. Spread ≈ 11-16 percentage points on identical inputs.
- Attendu: A single, consistently-defined replacement rate. The two services pick different denominators (gross vs net), so the same user is shown materially different 'taux de remplacement' depending on which surface renders it.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (grossMonthlySalary=grossSalary/12) ; apps/mobile/lib/services/response_card_service.dart:789-790 (NetIncomeBreakdown.monthlyNetPayslip) ; apps/mobile/lib/services/budget_living_engine.dart:254
- Reproduction: /tmp/profile_25_oracle.py: total_ret=4191.66; /gross(6500)=64.5%; /net@0.80(5200)=80.6%; /net@0.83(5395)=77.7%; /net@0.86(5590)=75.0%. Same numerator, three+ denominators across services => >11pp divergence.
- Illogisme: For this profile the app can simultaneously claim a 64.5% (gross-based) and a ~77% (net-based) replacement rate from the identical projected income. The replacementRateContextGood/Average/Low thresholds (retirement_dashboard_screen.dart:472-475) then classify the SAME situation differently depending on which engine fed the rate.

**jeune_diplome-4 · Plafond 3a (3rd-pillar annual ceiling) [SOURCED]**
- Input: age=25, gross=78000/yr, salarié (hasLpp=true), ZH
- Output MINT: 7258 CHF. Path: minimal_profile_service.dart:146-152 — when taxImpact resolves it returns taxImpact.annualCeiling; fallback branch for salarié-with-LPP = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)=7258.
- Attendu: 7258 CHF (OPP3 art. 7 al. 1, tax_year 2025/2026 per registry).
- Source: apps/mobile/lib/services/minimal_profile_service.dart:146-152 ; registry pillar3a.max_with_lpp=7258 (get_swiss_constants pillar3a)
- Reproduction: get_swiss_constants(pillar3a).pillar3a.max_with_lpp=7258. Profile is salarié → hasLpp branch → 7258. Matches archetype rule 'plafond 3a=7258'. CORRECT for this profile.
- Illogisme: None. The 3a ceiling is correctly 7258 for this salaried archetype. (Note: the independant fallback at line 148-150 uses min(gross*0.20, 36288); not triggered here since employment defaults to salarié.)

**jeune_diplome-5 · Patrimoine / épargne estimée (q_cash_total) [ILLOGICAL_FOR_ARCHETYPE]**
- Input: age=25, gross=78000/yr, no savings declared
- Output MINT: 0.00 CHF. minimal_profile_service.dart:57-58 currentSavings = max(0, (age-25)*gross*0.05); for age=25 => (25-25)*78000*0.05 = 0. Stored as q_cash_total in coach_profile_provider.dart:1268.
- Attendu: An estimate of ~0 is defensible (no real data), but it is a hard 0, not flagged as unknown, and feeds liquidityMonths = savings/expenses = 0 months — which can render the 25yo as having zero emergency runway purely from an estimation artifact.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:56-59,161-162 ; apps/mobile/lib/providers/coach_profile_provider.dart:1267-1268
- Reproduction: /tmp/profile_25_oracle.py: max(0,(25-25)*78000*0.05)=0.00. liquidityMonths = 0/expenses = 0. The (age-25) factor makes the savings model structurally return exactly 0 for every 25yo regardless of salary.
- Illogisme: The savings-estimation formula is anchored at age 25, so a 25yo ALWAYS gets 0 estimated savings and 0 months liquidity — an estimation artifact, not a measured value, presented without an 'estimated/unknown' qualifier on the liquidity surface.

### Archetype: couple_acheteurs (5 findings)

**couple_acheteurs-1 · Affordability screen — revenu brut prefill (capacité d'achat couple) [DIVERGENT]**
- Input: Couple 33 ans VD, ~8200 CHF/mois brut/personne, achat immobilier. Le couple peut atteindre l'écran d'accessibilité (AffordabilityCalculator) par deux routes : auto-remplissage depuis le profil, OU suggestion coach (GoRouter prefill).
- Output MINT: Route profil (affordability_screen.dart:64-67) : revenuBrut = salaireBrutMensuel*nombreDeMois + conjoint*nombreDeMois = 196'800 CHF -> prixMaxRevenu ≈ 1'022'857 CHF. Route coach-prefill (affordability_screen.dart:115-121) : revenuBrut = salaireBrut*13 = 106'600 CHF (conjoint DÉROULÉ, et *13 codé en dur au lieu de nombreDeMois) -> prixMaxRevenu ≈ 593'333 CHF.
- Attendu: Pour CE couple, les deux routes vers le MÊME écran doivent produire le MÊME revenu de ménage (les deux salaires comptent, ASB). Oracle /tmp/prefill_oracle.py : path1=196'800, path2=106'600, DIFF=90'200 (-45.8%).
- Source: apps/mobile/lib/screens/mortgage/affordability_screen.dart:64-67 (profil, somme conjoint, *nombreDeMois) vs :115-121 (coach prefill, single *13, pas de conjoint) ; constante nombreDeMois défaut 12.0 confirmée coach_profile.dart:196
- Reproduction: /tmp/prefill_oracle.py — mêmes inputs couple : path1 revenuBrut=196'800 -> prixMaxRevenu=1'022'857 ; path2 revenuBrut=106'600 -> prixMaxRevenu=593'333. Diff 90'200 CHF / 429'524 CHF de capacité d'achat selon la route d'entrée.
- Illogisme: Pour le couple-achat-immobilier précis, la capacité d'achat affichée varie de 45.8% (1.02M vs 0.59M) selon qu'il arrive par le profil ou par une suggestion coach. La route coach laisse tomber le revenu du conjoint (incohérent avec la directive ASB que le code lui-même cite ligne 62-63) et code *13 en dur alors que le profil utilise nombreDeMois (12 par défaut). Même personne, même écran, deux réponses.

**couple_acheteurs-2 · Avoir LPP estimé (balance) — divergence entre sites pour le profil age 33 / gross 98'400 [DIVERGENT]**
- Input: Personne du couple, 33 ans, 8200 CHF/mois = 98'400 CHF/an brut, salariée (donc soumise LPP).
- Output MINT: Site A minimal_profile_service.dart:196 (_estimateLppBalance) = 37'599.95 CHF (coord plafonné à 64'260, intérêt registry 1.25%). Site B coach_profile.dart:3577 (_estimateLppAvoir) = 41'724.98 CHF (coord NON plafonné = 71'940, intérêt codé en dur 1.01 = 1%).
- Attendu: Un seul avoir LPP estimé pour un profil donné. Oracle /tmp/lpp_arch2.py avec constantes registry (lppDeductionCoordination=26'460, lppSalaireCoordMax=64'260, lppTauxInteretMin=1.25%) : la valeur canonique respecte le clamp max et l'intérêt registry.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:201-208 (clamp MIN+MAX, reg('lpp.min_interest_rate')) vs apps/mobile/lib/models/coach_profile.dart:3580-3589 (clamp MIN seul via double.infinity, total*1.01 codé en dur)
- Reproduction: /tmp/lpp_arch2.py — age=33, gross=98'400 : Site A=37'599.95 (coordA=64'260, 1.25%) ; Site B=41'724.98 (coordB=71'940 non plafonné, 1.00%) ; DIFF=+4'125.03 (+10.97%). Cause #1 : coach_profile omet le clamp lppSalaireCoordMax (coord 71'940 vs 64'260, +12%). Cause #2 : intérêt 1.00% codé en dur vs registry 1.25%.
- Illogisme: Pour CE profil précis l'avoir LPP diffère de ~11% selon le service appelé. Aucun des deux ne délègue à LppCalculator (financial_core). coach_profile.dart viole deux constantes registry (plafond de coordination + taux d'intérêt minimum).

**couple_acheteurs-3 · Rente LPP mensuelle — taux de conversion divergent sur le même avoir stocké [DIVERGENT]**
- Input: Couple, écran mariage et carte de réponse coach peuvent tous deux afficher une rente LPP à partir de l'avoir stocké (avoirLppTotal). Pour ce couple jeune en achat immobilier, ces deux surfaces sont atteignables.
- Output MINT: mariage_screen.dart:94 : avoir*0.068/12. response_card_service.dart:776 : avoir*0.058/12. Sur avoir=200'000 : 1'133.33 CHF/mois vs 966.67 CHF/mois.
- Attendu: Une rente cohérente pour un avoir donné, idéalement via LppCalculator.adjustedConversionRate (financial_core lpp_calculator.dart). Oracle /tmp/lpp_arch2.py : écart 166.67 CHF/mois pour input identique.
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (0.068 codé en dur) vs apps/mobile/lib/services/response_card_service.dart:776 (lppTauxConversionSurobligDecimal=0.058)
- Reproduction: /tmp/lpp_arch2.py — avoir=200'000 : mariage 0.068/12=1'133.33 CHF/mois ; response_card 0.058/12=966.67 CHF/mois ; spread=166.67 CHF/mois pour le MÊME avoir stocké. Les deux contournent LppCalculator.adjustedConversionRate.
- Illogisme: Deux taux distincts {0.058, 0.068} appliqués au même input produisent deux rentes différentes selon l'écran. Pour le couple, l'écran mariage (atteignable s'ils se marient) et la carte coach donnent des chiffres LPP incohérents entre eux.

**couple_acheteurs-4 · Taux de remplacement — dénominateur GROSS vs NET selon l'écran [DIVERGENT]**
- Input: Profil salarié (membre du couple), 8200 CHF/mois brut. Le taux de remplacement est calculé sur trois surfaces différentes.
- Output MINT: minimal_profile_service.dart:129-130 et budget_living_engine.dart:253-254 : revenu retraite / GROSS mensuel. response_card_service.dart:789-790 : revenu retraite / NET (NetIncomeBreakdown.monthlyNetPayslip).
- Attendu: Un seul dénominateur pour un taux de remplacement comparable entre écrans. Oracle /tmp/repl_oracle.py.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (grossMonthlySalary) + apps/mobile/lib/services/budget_living_engine.dart:251-254 (grossMonthlySalary) vs apps/mobile/lib/services/response_card_service.dart:783-790 (currentMonthly = NetIncomeBreakdown net)
- Reproduction: /tmp/repl_oracle.py — revenu retraite 4500/mois, gross 8200, net ~6560 : GROSS-denom=54.9% ; NET-denom=68.6% ; spread=13.7 points pour les mêmes inputs. Dénominateur différent entre minimal_profile/budget_living (GROSS) et response_card (NET).
- Illogisme: Le même profil voit deux taux de remplacement écartés de ~14 points selon l'écran. Un taux de remplacement n'a de sens que rapporté au NET (revenu disponible) ; le calcul GROSS sous-estime systématiquement le maintien de niveau de vie.

**couple_acheteurs-5 · Affordability — règle des fonds propres durs 10% et règle du tiers pour le couple [SOURCED]**
- Input: Couple revenu brut 196'800 CHF/an, achat VD. Test : prix 1'000'000, épargne 170k + 3a 30k (hard=200k) + LPP 100k.
- Output MINT: mortgage_service.dart AffordabilityCalculator : fondsPropresTotal = épargne + 3a + min(LPP, prix*10%) = 300'000 ; fondsPropresRequis = prix*20% = 200'000 -> fondsPropresOk=true. ratioCharges = (hypothèque*6% + prix*1%)/revenu = 26.4% <= 33.33% -> capaciteOk=true.
- Attendu: Apport 20% dont >=10% de fonds propres durs (hors LPP) ; règle du tiers charges<=33% au taux théorique 5%. Oracle /tmp/tiers_oracle.py.
- Source: apps/mobile/lib/services/mortgage_service.dart:147 (min(lpp, prix*regPart2e)) + :160 (ratioCharges) + :136-138 (prixMaxEquity = hardEquity/(FP_MIN-PART_2E) quand LPP plafonne)
- Reproduction: /tmp/tiers_oracle.py + /tmp/aff_oracle.py — Le cap LPP à prix*10% force structurellement les fonds propres durs à fournir >=10% : au prix-cible, FP total <= hard + prix*10%, donc atteindre 20% requiert hard>=10%. La branche prixMaxEquity (mortgage_service.dart:135-138) résout hardEquity/(0.20-0.10)=hard/0.10, équivalent exact au plancher 10% dur. ratioCharges au taux théorique 5%+1%+1% confirmé conforme.
- Illogisme: AUCUN illogisme pour ce profil : la règle des 10% durs et la règle du tiers (5% théorique) sont correctement implémentées et délèguent aux constantes registry. EPL impot délègue à RetirementTaxCalculator.progressiveTax (financial_core). Ce site de calcul immobilier — le cœur de l'archetype — est cohérent.

### Archetype: returning_swiss_gaps (6 findings)

**returning_swiss_gaps-1 · Rente AVS mensuelle — onboarding minimal profile (MinimalProfileResult.avsMonthlyRente) [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Suisse de retour, 48 ans, BE, lacunes AVS, 10000 CHF/mois brut (120000/an), retraite 65. Lacunes AVS DOIVENT réduire la rente.
- Output MINT: 2520.00 CHF/mois (= rente AVS MAXIMALE, gapFactor=1.0, effYears=44)
- Attendu: Rente RÉDUITE par les lacunes. Pour un arrivalAge=43 (rentré il y a 5 ans), gapFactor=0.5 → 1260.00 CHF/mois. La rente ne doit PAS être au max pour ce profil.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:92-98 (computeMonthlyRente appelé SANS arrivalAge/lacunes/anneesContribuees) vs financial_core/avs_calculator.dart:53-67 (gapFactor dérivé de currentYears qui dépend de arrivalAge). Constante: avs.full_contribution_years=44, avs.max_monthly_pension=2520 (registry v30.7).
- Reproduction: /tmp/profile_oracle.py — [A] AVS no-lacunes = 2520.00/mo (gapFactor=1.0000, effYears=44) ; [B] AVS arrivalAge=43 = 1260.00/mo (gapFactor=0.5000, effYears=22). DIFF = 1260.00/mo = 50.0% de surestimation quand les lacunes sont ignorées. baseRente(RAMD=120000)=2520 (salaire > sommet échelle 88200, donc plafonné au max).
- Illogisme: L'onboarding (MinimalProfileService.compute) calcule l'AVS comme une carrière complète (gapFactor=1.0) et affiche la rente AU MAXIMUM (2520 CHF) — exactement le comportement interdit par la règle archetype « la rente AVS ne doit PAS être affichée au max ». Les lacunes du Suisse de retour sont totalement ignorées sur cet écran, alors que response_card_service.dart:767 et forecaster_service.dart:829 passent bien arrivalAge. Incohérence intra-app : même personne, deux chemins, écart de 1260 CHF/mois (×2).

**returning_swiss_gaps-2 · Rente AVS mensuelle — scène d'onboarding hero 'Ta retraite projetée' (MintSceneRenteTrouee) [ILLOGICAL_FOR_ARCHETYPE]**
- Input: Suisse de retour, 48 ans, lacunes AVS, revenu dérivé du net mensuel. Écran hero affichant la fourchette de rente projetée.
- Output MINT: AVS composante = 2520.00 CHF/mois (carrière complète assumée, retraite 65)
- Attendu: Rente réduite par les lacunes (ex. 1260 CHF/mo si arrivalAge=43). La scène doit refléter le trou de cotisation du profil retour.
- Source: apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:47-51 (computeMonthlyRente SANS arrivalAge/lacunes ; commentaire ligne 46 'sur carrière complète'). LPP composante ligne 57 = grossAnnual*0.34/12 (heuristique forfaitaire, bypass LppCalculator).
- Reproduction: /tmp/profile_oracle.py — même résultat que finding 1 : [A]=2520.00/mo vs [B]arrivalAge=43=1260.00/mo, écart 50.0%. La LPP de cette scène (0.34 forfait) ne délègue pas à LppCalculator.projectToRetirement.
- Illogisme: La scène ironiquement nommée 'rente_trouee' (rente trouée = avec lacunes) calcule l'AVS SANS aucune lacune et la plafonne au maximum. Pour un Suisse de retour, l'écran le plus visible du parcours présente donc une rente au max — framing inadapté qui efface précisément le 'trou' que le nom de la scène promet de montrer.

**returning_swiss_gaps-3 · Avoir LPP estimé (balance) — divergence entre deux sites d'estimation [DIVERGENT]**
- Input: 48 ans, 120000/an brut, sans valeur LPP saisie (estimation). Deux estimateurs coexistent.
- Output MINT: Site A (minimal_profile_service)=155800.42 CHF ; Site B (coach_profile._estimateLppAvoir, sans arrivalAge)=221308.72 CHF
- Attendu: Valeur unique et cohérente. Avec le clamp registry lpp.max_coordinated_salary=64260 et lpp.min_interest_rate=1.25%, le site A est le plus aligné au registry.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:196-209 (clamp [3780,64260], intérêt reg lpp.min_interest_rate=1.25%) vs apps/mobile/lib/models/coach_profile.dart:3577-3591 (clamp MIN seulement, PAS de cap max ; intérêt hardcodé 1.01=1%). Constantes: lpp.coordination_deduction=26460, lpp.max_coordinated_salary=64260, lpp.min_interest_rate=1.25 (registry v30.7).
- Reproduction: /tmp/profile_oracle.py — [LPP-A] coord=64260 bal@48=155800.42 ; [LPP-B] coordNOCAP=93540 bal@48=221308.72. DIFF B-A=+65508.29 (+42.0%). Cause #1: coach_profile omet le clamp max (coord=93540 au lieu de 64260). Cause #2: 1% vs 1.25%.
- Illogisme: Deux estimateurs d'avoir LPP produisent +42% d'écart sur le même input, et coach_profile dévie du registry (omet lpp.max_coordinated_salary=64260, hardcode 1% au lieu de lpp.min_interest_rate=1.25%). Aucun ne délègue à LppCalculator. Pour ce profil l'avoir LPP est sur-estimé de ~65500 CHF selon l'écran consulté.

**returning_swiss_gaps-4 · Avoir LPP estimé — prise en compte des lacunes LPP (arrivalAge) côté coach_profile [DIVERGENT]**
- Input: Suisse de retour arrivé à 43 ans (lacunes LPP : pas de cotisation 25→43). Règle archetype: LPP partielle (années manquantes).
- Output MINT: Avec arrivalAge=43 : bal@48=61886.58 CHF (5 ans cotisés) ; SANS arrivalAge : bal@48=221308.72 CHF (23 ans assumés)
- Attendu: 61886.58 CHF (LPP partielle, démarrage à l'arrivée). C'est le comportement correct quand arrivalAge est plumbé.
- Source: apps/mobile/lib/models/coach_profile.dart:3584 (startAge = arrivalAge.clamp(25,65)) et caller ligne 2857 (arrivalAge: computedArrivalAge passé). Contraste avec minimal_profile_service.dart:196 (_estimateLppBalance n'accepte PAS arrivalAge → toujours start 25).
- Reproduction: /tmp/profile_oracle.py — [LPP-B+arr] arrivalAge=43 bal@48=61886.58 vs [LPP-B] sans arr=221308.72. Écart ×3.6 selon que arrivalAge est plumbé ou non.
- Illogisme: coach_profile gère correctement la LPP partielle (démarrage à arrivalAge) mais minimal_profile_service._estimateLppBalance (onboarding) n'a pas de paramètre arrivalAge — il démarre toujours à 25 ans. Donc l'onboarding sur-estime la LPP du Suisse de retour de ~×3.6 par rapport au profil coach. Incohérence de plumbing entre les deux couches pour le MÊME archetype.

**returning_swiss_gaps-5 · Rente LPP mensuelle — taux de conversion divergent appliqué au même avoir [DIVERGENT]**
- Input: Avoir LPP stocké identique (ex. 300000 CHF), affiché sur plusieurs écrans.
- Output MINT: mariage_screen=1700.00 CHF/mois (taux 0.068) vs response_card_service=1450.00 CHF/mois (taux 0.058)
- Attendu: Valeur unique pour un même avoir stocké. Le taux doit être unique et idéalement passer par LppCalculator.adjustedConversionRate (réduction retraite anticipée LPP art.13 al.2).
- Source: apps/mobile/lib/screens/mariage_screen.dart:94 (avoir*0.068/12, hardcodé) vs apps/mobile/lib/services/response_card_service.dart:776-779 (avoir*lpp.conversion_rate_suroblig=0.058/12). Constantes: lpp.conversion_rate=0.068, lpp.conversion_rate_complementaire=0.058 (registry v30.7).
- Reproduction: /tmp/profile_oracle.py — [RENTE] avoir=300000 : 0.068→1700.00/mo ; 0.058→1450.00/mo ; spread=250.00/mo. Deux taux distincts appliqués au même input. Aucun site ne passe par LppCalculator.adjustedConversionRate (avs_calculator/lpp_calculator.dart:43-52).
- Illogisme: Le même avoir LPP stocké donne deux rentes différentes (1700 vs 1450, écart 250 CHF/mois soit ~15%) selon l'écran. Tous les sites bypassent LppCalculator (aucune réduction retraite anticipée appliquée), donc pour un Suisse de retour envisageant une retraite anticipée, la divergence s'aggrave davantage.

**returning_swiss_gaps-6 · Taux de remplacement — base du dénominateur divergente (brut vs net) [DIVERGENT]**
- Input: 120000/an brut, même revenu de retraite projeté. Affiché en onboarding et en response card.
- Output MINT: minimal_profile_service: revenu_retraite / (brut/12=10000) ; response_card_service: revenu_retraite / net_payslip mensuel (~7500)
- Attendu: Dénominateur cohérent entre écrans. Brut et net donnent des taux de remplacement très différents pour le même profil.
- Source: apps/mobile/lib/services/minimal_profile_service.dart:128-130 (grossMonthlySalary=grossSalary/12 ; replacementRate=totalMonthlyRetirement/grossMonthlySalary) vs apps/mobile/lib/services/response_card_service.dart:784-790 (currentMonthly=NetIncomeBreakdown.monthlyNetPayslip ; replacementRate=totalMonthly/currentMonthly*100). budget_living_engine.dart:254 utilise aussi grossMonthlySalary.
- Reproduction: Dénominateurs structurellement différents : brut/12=10000 (minimal_profile) vs net~7500 (response_card via NetIncomeBreakdown). Pour un revenu retraite identique R, taux_brut = R/10000 et taux_net = R/7500 → taux_net = taux_brut × (10000/7500) = 1.33× le taux brut. Écart de +33% sur le pourcentage affiché pour le même profil, par construction.
- Illogisme: Le taux de remplacement est défini sur deux bases incompatibles (brut côté onboarding, net côté response card). Pour ce profil, l'onboarding affichera un taux ~25% plus bas (dénominateur brut plus grand) que la response card pour exactement le même revenu de retraite — l'utilisateur voit deux pourcentages contradictoires sans explication.

## 4. Synthese par classe
- DIVERGENT: 27
- ILLOGICAL_FOR_ARCHETYPE: 10
- SOURCED: 5
- WRONG: 2

(Archetypes couverts: salarie_swiss, independent_no_lpp, expat_us, frontalier, cadre_divorce_hypo, jeune_diplome, couple_acheteurs, returning_swiss_gaps ; 8/8)

## 5. Annexe — Grounding device (iPhone 16e, build staging, 2026-06-09→11)

Findings confirmés PHYSIQUEMENT à l'écran (captures `.planning/_walker/audit-live/`), complémentaires aux findings code+registry ci-dessus. Conduite manuelle idb + flows Maestro.

| # | Finding device | Preuve | Lien matrice |
|---|---|---|---|
| D1 | Onboarding ne demande JAMAIS le statut d'emploi ni l'état civil → tout profil traité salarié-avec-LPP ; « Ce que MINT sait de toi » liste honnêtement 3 données mais le home affiche un hero LPP estimé | p25-profil.png, p26-ce-que-mint-sait.png | racine des ILLOGICAL_FOR_ARCHETYPE |
| D2 | Hero « Avoir LPP » estimé affiché NU sur /home avec « Fiabilité 44% » ailleurs — violation SOT §5 Confidence Gate (<50 → gated ; <70 → bandes obligatoires) ; Mon Argent>Prévoyance tague « estimé », /home non | ind-home.png vs ind-prevoyance.png | salarie_swiss-1/2 |
| D3 | Taux de remplacement : onboarding « 63% » vs home « 46.5% » même session (Marc) | p13-insight.png vs p16-coach.png | *-taux-remplacement (RR divergent) |
| D4 | Taux de conversion LPP : Mariage>Protection rente 248 CHF = avoir×0.068 ✓ ; Rente vs Capital rente 35'886/an ÷ capital 619'013 = 0.058 ✓ — les DEUX taux rendus dans la même session | ind-mariage-protection.png, ind-rvc-mid.png | *-rente-lpp (0.068 vs 0.058) |
| D5 | RvC : défauts FICTIFS codés en dur (age '50' / salaire '100000' / LPP '350000', rente_vs_capital_screen.dart:62-66) rendus indiscernables d'un prefill réel ; indépendant sans LPP (seed) → « Capital estimé à 65 ans ~812'886 » sur LPP fantôme ; défauts contournent ProfileDataSource | illog02-cold.png ; flow bug__ILLOG01 (OPEN-RED) | independent_no_lpp-3 (LPP fantôme) |
| D6 | ILLOG-02 (NOUVEAU, P1 a11y) : RenteVsCapitalScreen rend les pixels mais arbre AX (quasi) VIDE — triangulé Maestro (assert fail sur écran visible) + idb (1 élément) + screenshot ; reproduit froid+chaud | run ~/.maestro/tests/2026-06-11_065259 ; flow bug__ILLOG02 (OPEN-RED) | nouveau |
| D7 | Contradiction inter-surfaces : /home affirme « 43'691 Avoir LPP » pendant que /retraite dit « 4 infos suffisent » (= aucune donnée) — même profil, même minute | ind-home.png vs ind-projection.png | divergence des moteurs/champs |
| D8 | CTA mort : « Commencer — 2 min » (tableau retraite) → home coach, AUCUN formulaire, aucune question | ind-proj-form.png | nouveau |
| D9 | Écran Mariage invente un conjoint fictif « Revenu 2 : 60'000 » + « Pénalité +1'407/an » pour profil sans état civil | ind-mariage.png | violation Identity couche-3 |
| D10 | Suggestion 3a sur-plafond reproductible : « verser 1541 CHF en 3a » (Marc) / « 1462 CHF » (profil 2) — mensuel ×12 ≈ 2.4× le plafond 7'258, jamais mentionné | p17-monargent.png, ind-futur.png | salarie_swiss / 3a |
| D11 | Fuites de clés brutes en labels a11y : « coach-context-point-de-depart », « ouvrir-profil-drawer » | p16-coach.png, p19-explorer.png | i18n/a11y |
| D12 | Fiabilité incohérente : Mon Argent « 44% » vs RvC « 50% » (et données réelles de Marc → « 30% » vs fiction → « 50% » : confiance inversée, A_REPRODUIRE) | ind-rvc.png | confidence engines |

Rétractation (0-TRUST) : la claim « âge prérempli ✓ » des passes Marc/profil-2 est RETIRÉE — le défaut codé en dur '50' coïncidait avec l'âge des deux profils de test, donc non prouvable.

Flows de régression enregistrés (convention D-36, `tools/simulator/flows/regression/_INDEX.md`) : `bug__ILLOG01__rvc_fiction_defaults.yaml` (gated par ILLOG02) + `bug__ILLOG02__rvc_ax_tree_empty.yaml` — RED capturé, gate GREEN défini.
