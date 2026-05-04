# Wave 7 — Fiscal/legal Swiss-brain audit
*Scope: forecaster_service, expat_service, financial_report_service, budget_service*
*Auditor: swiss-brain (LPP / LAVS / LIFD / OPP2 / OPP3 / CC / CO / LACI / LDIP)*
*Date: 2026-04-18*
*Golden stress pair: Julien (swiss_native, VS, 49y) + Lauren (expat_us FATCA, VS, 43y)*

## Executive summary
- Files audited: 4 (forecaster_service.dart, expat_service.dart, financial_report_service.dart, budget_service.dart)
- **P0 (illegal advice / law inverted / double taxation / irreversible-decision archetype blindness): 11**
- **P1 (missing archetype-specific penalty / conditional language absent): 9**
- **P2 (wording drift / missing disclaimer on non-projection field): 7**
- **One-line verdict**: Wave 7 target files ship several **law-inverted projections** (partner 3a auto-injected on FATCA Lauren → illegal PFIC trap; 3a retirement income annualised /20 **without income-tax on rente** while LPP rente is raw gross → inconsistent double-standard; retroactive tax deductions applied to Pillar 3a which are forbidden under LIFD art. 33 al. 1 let. g; French "déduction enfants" hardcoded 6'500 CHF = **LIFD art. 35 value is 6'700 CHF 2025** and **cantonal varies 6'500–12'200** ignored; imperative wording "Ouvre ton 2e 3a", "Ouvre ton premier 3a" on unknown archetype = LSFin art. 3 let. c/8 product-advice boundary breach). **PR MUST NOT MERGE** until P0-F1, P0-F2, P0-F3, P0-R1, P0-R2, P0-R3, P0-E1, P0-E2, P0-B1, P0-X1, P0-X2 are resolved.

---

## Findings per file

### forecaster_service.dart

**P0-F1 — Partner 3a auto-injection ignores FATCA / PFIC / foreign-trust status** (forecaster_service.dart:551-568)
Legal reference: FATCA (IRC §1471-1474), IRS Notice 2014-7 (3a ≠ qualified foreign retirement plan), PFIC rules (IRC §1291-1298). Convention CH-US 1996 art. 19 does NOT shield Pilier 3a. OPP3 art. 3 al. 1 requires the assuré·e to cotise on Swiss taxable income, but FATCA/PFIC taxation at the US side creates a **net loss** on 3a for US persons.
Evidence:
```dart
if (profile.conjoint != null &&
    (profile.conjoint!.salaireBrutMensuel ?? 0) > 0 &&
    (profile.conjoint!.prevoyance?.canContribute3a ?? true)) {
  ...
  partner3aMonthly = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) / 12;
}
```
Why it breaks the law: the `canContribute3a` flag defaults to `true` — so Lauren (expat_us) is projected with an auto CHF 604.83/month partner 3a contribution she legally **must not make without paying crippling PFIC/foreign-grantor-trust US tax**. This is not a UI label — the *projection capital* is inflated by ~145'000 CHF at her retirement, driving downstream arbitrage (rente vs capital, EPL, rachat) toward an illegal position.
Fix:
- Default `canContribute3a` to **null (unknown) not true** at the CoachProfile schema layer.
- In forecaster, skip partner 3a auto-injection if archetype ∈ {expat_us, cross_border taxed abroad, independent without LPP registered abroad}.
- Surface an `archetypeBlocker` field in the projection output: "Pilier 3a non projeté : risque PFIC / foreign grantor trust (IRC §1291)".
- Legal anchor: cite IRS Notice 2014-7 + FATCA 6038D.

**P0-F2 — 3a retirement income annualised over 20 years but not treated as capital in taxable income (inverted LIFD art. 22 vs 38)** (forecaster_service.dart:927-943)
Legal reference: LIFD art. 38 al. 2 (capital withdrawn = **prestation en capital** taxed separately, once, at 1/5 of ordinary rate), LIFD art. 22 al. 1 (rentes de prévoyance = revenu imposable).
Evidence:
```dart
final threeATotal = threeABalance + partner3aBalance;
final threeATax = RetirementTaxCalculator.capitalWithdrawalTax(...);
final retrait3aAnnualise = (threeATotal - threeATax) / 20;
...
final revenuRetraiteAnnuel = renteAvsAnnuelle + renteLppUser + renteLppConjoint + retrait3aAnnualise + rendementLibreAnnuel;
```
Why it breaks the law: the code taxes 3a capital at LIFD art. 38 (correct) then adds the *net* capital/20 to retirement income. But `renteAvsAnnuelle` and `renteLppUser` are **pre-income-tax (gross)** per LIFD art. 22, while `retrait3aAnnualise` is **post-capital-tax**. Mixing gross-of-income-tax AVS/LPP with net-of-capital-tax 3a in the same `revenuRetraiteAnnuel` is arithmetically inconsistent and pushes the replacement rate (taux remplacement) 4–7 pts too high. If the user reads "je remplace 65% de mon revenu" and acts on it (cancels a rachat, reduces 3a), they've been mis-guided. Also, annualising /20 implicitly assumes a full drawdown by age 85 — no disclaimer.
Fix:
- Either treat 3a as gross rente (remove `threeATax`) and let the top-level income tax on retirement income handle it once;
- Or compute all three (AVS + LPP) net of ordinary LIFD art. 36 progressive tax to align with the 3a post-capital-tax branch;
- Add disclaimer: "Capital 3a taxé LIFD art. 38 au retrait, puis annualisé sur 20 ans à but indicatif. Rentes AVS/LPP non déduites de l'impôt sur le revenu dans cet affichage."
- Add `revenuRetraiteAnnuelNet` field for consistency.

**P0-F3 — SWR 4% on investmentBalance + savingsBalance labelled `rendementLibreAnnuel` double-counts taxable vs non-taxable** (forecaster_service.dart:936-937, :959 label "libre")
Legal reference: LIFD art. 16 al. 3 (gains en capital sur fortune privée = NON imposables) vs LIFD art. 20 (revenus mobiliers = imposables).
Evidence:
```dart
final rendementLibreAnnuel =
    (investmentBalance + savingsBalance + conjSavingsBalance) * 0.04;
```
Why it breaks the law: 4% SWR is **consommation de patrimoine + rendement**, not a revenu. In Swiss tax law, plus-value privée (art. 16 al. 3) is tax-exempt; only dividende/intérêts (art. 20) are imposables. Calling this `rendementLibreAnnuel` inside `revenuRetraiteAnnuel` and then using it in taux de remplacement vs gross salary:
1. inflates retirement "income" with tax-free capital drawdown (Julien savings), and
2. misleads the user on replacement rate.
See also CLAUDE.md §5 "NEVER double-tax: retrait tax + income tax on SWR".
Fix:
- Rename the decomposition key from `'libre'` to `'patrimoine_libre_drawdown_4pct'`.
- Split the 4% into `rendement_courant_imposable` (dividends, interest) and `consommation_capital_non_imposable` (art. 16 al. 3).
- Document disclaimer: "SWR 4% = consommation de patrimoine, non revenu imposable (LIFD art. 16 al. 3). Ne pas confondre avec rente."

**P1-F4 — Married cap CHF 3'780 applied but couple verification against concubinage omitted** (forecaster_service.dart:832-838)
Legal reference: LAVS art. 35 al. 1 (plafonnement 150% = CHF 3'780 **marié·es** uniquement), ATF 139 V 297.
Evidence:
```dart
final coupleAvs = AvsCalculator.computeCouple(
  avsUser: avsUserMonthly,
  avsConjoint: avsConjointMonthly,
  isMarried: isMarried,
);
```
Why it breaks the law: `isMarried` is derived from `profile.etatCivil == CoachCivilStatus.marie` but silently falls to `false` for `CoachCivilStatus.partenariatEnregistre` (LPart art. 13a = married-equivalent for AVS since 2007). Registered partners get cap 150% but code returns uncapped sum.
Fix: extend `isMarried` test to `in {marie, partenariatEnregistre}` and add LPart art. 13a reference.

**P1-F5 — LPP conversion rate min hardcoded to 6.8% — LPP reform 2024 drops to 6.0% (AVS21 companion reform)** (forecaster_service.dart:852, :893 via `reg('lpp.conversion_rate_min', ...)`)
Legal reference: LPP art. 14 al. 2, RO 2024 (LPP-Reform rejected in referendum 22.09.2024, so 6.8% remains valid). **No breach today**, but the hardcoded assumption must persist-or-change with legislative watch. Evidence is the reg-backed fallback — acceptable given the referendum outcome.
Fix: add a comment-source `// LPP-Reform rejetée 22.09.2024, taux 6.8% maintenu` or an ADR.

**P1-F6 — AVS rente "lacunesAVS" counted as years but no totalisation bilatérale check for expats** (forecaster_service.dart:806-811)
Legal reference: ALCP annexe II, Règlement CE 883/2004 art. 45-52 (totalisation des périodes UE-CH), Convention CH-US 2006 (pas de totalisation, mais prorata US).
Evidence:
```dart
final avsUserMonthly = AvsCalculator.computeMonthlyRente(
  currentAge: profile.age,
  retirementAge: retirementAge,
  arrivalAge: profile.arrivalAge,
  anneesContribuees: profile.prevoyance.anneesContribuees,
  lacunes: profile.prevoyance.lacunesAVS ?? 0,
  ...);
```
Why incomplete: for Lauren (expat_us), "lacunes" pre-arrivée CH are not coverable by US social security totalisation (Convention CH-US art. 5 prorata only if min. 12 trimestres US AND min. 1 année CH). The projection treats her as though voluntary AVS could always close the gap.
Fix: surface `lacunesTotalisablesAlcp` vs `lacunesTotalisablesCDI` vs `lacunesResiduelles`; for expat_us, explicit "lacunes résiduelles non comblées" line.

**P2-F7 — Disclaimer at line 324-328 missing "Pilier 3a contribution subject to US tax if US person"** (forecaster_service.dart:324-328)
Legal reference: LSFin art. 8 (information obligations).
Fix: add archetype-aware disclaimer bullet when `profile.archetype` is expat_us or FATCA flag.

**P2-F8 — "Consulte un·e specialiste pour un plan personnalise" ok, but the projection above is framed as a *result*, not a *scenario*** (forecaster_service.dart:325 "Projections educatives basees sur des hypotheses")
Legal reference: LSFin art. 3 let. c "conseil en placement" — risk of qualification if decomposition is read as a plan.
Fix: prefix the disclaimer with "Ceci n'est pas un plan financier personnalisé (LSFin art. 3)."

---

### expat_service.dart

**P0-E1 — `planDeparture` tells user to "Retirer pilier 3a" without OPP3 art. 3 conditions check** (expat_service.dart:635-642)
Legal reference: OPP3 art. 3 al. 1 let. b (retrait 3a pour départ définitif de Suisse — conditionné). LIFD art. 38 + LIS cantonale (impôt à la source sur prestations en capital prévoyance, e.g. Schwyz 4.8%, VS ~6.8%, GE tax barème cantonal).
Evidence:
```dart
{
  'id': 'pillar3a',
  'title': 'Retirer pilier 3a',
  'subtitle': 'Delai: possible des le depart. Impot de sortie reduit.',
  'timing': 'Avant le depart ou juste apres',
  ...
}
```
Why it breaks the law: three problems.
1. "Impot de sortie reduit" is **false** — there is **no reduced exit tax on 3a**. The retrait 3a pour départ is taxed under LIFD art. 38 (1/5 barème) + cantonal source tax. For Lauren (US person), the retrait triggers US ordinary income tax on the whole capital (IRS treats 3a as non-qualified).
2. Retrait 3a vers pays UE/AELE = **only surobligatoire portion can be cashed out**; obligatoire must stay on a libre-passage account (ALCP + LFLP art. 25f). For 3a this rule doesn't apply (OPP3 art. 3 al. 1 let. b permits retrait on départ définitif), but the copy conflates LPP and 3a.
3. Lauren's Pilier 3a withdrawal = PFIC exit event under US tax law. Code silently recommends it.
Fix:
- Replace "Impot de sortie reduit" with "Taxation séparée LIFD art. 38 + impôt cantonal à la source sur prestations en capital (barème 3-9% selon canton de dernier domicile)".
- For expat_us: add blocker "Consulte un·e fiscaliste CH-US avant tout retrait 3a — risque de double imposition + PFIC".
- For UE/AELE destination: add "Retrait 3a possible uniquement sur départ définitif (OPP3 art. 3 al. 1 let. b)".

**P0-E2 — `planDeparture` mentions LPP in capital "si destination hors UE/AELE" but omits the crucial ALCP art. 25f constraint** (expat_service.dart:644-652)
Legal reference: LFLP art. 25f al. 1 (entré en vigueur 01.06.2007): **la part obligatoire (LPP art. 7-8) ne peut PAS être retirée en capital** si l'assuré part dans un État UE/AELE et y est soumis à l'assurance obligatoire retraite/invalidité/décès. LFLP art. 25f al. 2: la part surobligatoire peut être retirée.
Evidence:
```dart
'subtitle': 'Si destination hors UE/AELE: retrait en capital possible. '
    'Sinon: compte de libre passage obligatoire.',
```
Why it breaks the law: the copy says "compte de libre passage obligatoire" — misleading. For UE/AELE: **obligatoire portion** must stay in libre-passage, **surobligatoire** can be cashed out. The user reading this will think 100% is blocked, deferring a legitimate surobligatoire cash-out and potentially losing flexibility.
Fix:
- Split: "UE/AELE + affiliation sécu locale → part obligatoire bloquée sur libre-passage, part surobligatoire retirable. Hors UE/AELE (ou sans affiliation sécu obligatoire) → retrait intégral possible."
- Cite LFLP art. 25f al. 1-2.

**P0-E3 — `simulateForfaitFiscal` uses hardcoded `forfaitTaxRate = 0.25` and `ordinaryTaxRate = 0.35` — both invented** (expat_service.dart:526, :530)
Legal reference: LIFD art. 14 al. 1-3 (depenses de vie × 7 règle d'échelonnement abrogée, base forfait = 7 × loyer OU valeur locative OU CHF 400'000 fédéral min); LHID art. 6 (forfait cantonal). Le taux fiscal s'applique **au barème ordinaire** LIFD art. 36 sur le forfait, pas un rate plat 25%.
Evidence:
```dart
const forfaitTaxRate = 0.25;
final forfaitTax = forfaitBase * forfaitTaxRate;
const ordinaryTaxRate = 0.35;
final ordinaryTax = actualIncome * ordinaryTaxRate;
```
Why it breaks the law: forfait taxation in Switzerland applies the ordinary progressive barème (LIFD art. 36) to the forfait base. Using a flat 25% drastically **underestimates** forfait tax (actual effective 28-38% at CHF 1M base) and the 35% ordinary is **overestimated** at mid-income ranges. The "savings" figure is fabricated. On a VD 1M forfait: real VD rate ~34% cantonal + 11.5% fédéral = ~44% not 25%. Code tells a wealthy prospect "forfait saves CHF 100k" when reality is break-even or negative.
Fix:
- Delegate forfait tax to `RetirementTaxCalculator.progressiveTax` with the forfait base as taxable income (LIFD art. 36 + cantonal coefficient); eliminate the 0.25 constant.
- For `ordinaryTax`, use the same progressive calculator on `actualIncome`.
- Add disclaimer "Estimation forfait fiscal — taux effectifs varient selon canton et commune (LIFD art. 36 + LHID art. 6). Consulte l'AFC cantonale."

**P0-E4 — `compareTaxBurden` double-counts social charges in foreign total (inverted CH convention art. 5/7 PCT)** (expat_service.dart:725-741)
Legal reference: CDI-CH-FR/DE/IT/AT art. 15 (salariés imposés dans l'État d'exercice de l'activité), Règlement CE 883/2004 art. 11-13 (lex loci laboris = cotisations dans un seul État). For a frontalier, social charges + income tax cannot both apply in CH and in the residence country — tax only in one + social only in one.
Evidence:
```dart
final foreignTaxRate = foreignEffectiveTaxRate[targetCountry] ?? 0.30;
final foreignSocialRate = foreignSocialCharges[targetCountry]?['total'] ?? 0.20;
final foreignTotalRate = foreignTaxRate + foreignSocialRate;
...
// Avoid double social charges: just combine
```
Why it breaks the law: the CH side computes `chTotalRate = chSourceRate + chSocialRate` (source tax + CH social) and foreign side computes `foreignTaxRate + foreignSocialRate`. For a frontalier France with permis G: CH source + **no CH AVS** (sometimes — optional under Règl. 883/2004) OR CH source + FR CSG if CSG non-reimbursed. The "just combine" comment is wrong — the regulation forbids double AVS. Result: the comparison is incomparable, and the "chCheaper: difference < 0" boolean misleads a user's relocation decision.
Fix:
- Introduce a `taxationModel` enum: `{frontalierOrdinary, frontalierQuasiResident, resident, expat}`.
- For each combination (canton × country × status), apply the right rule: CH source + country income tax with DTA crediting; or residence-country taxation only.
- Remove `+ socialRate` double-count; apply Règlement CE 883/2004 art. 11 (lex loci laboris).

**P1-E5 — `simulate90DayRule` uses hardcoded 90-day threshold — Accord amiable CH-FR 22.12.2022 introduces 40% télétravail limit (= ~104 jours/year)** (expat_service.dart:385, :393-436)
Legal reference: Accord amiable CH-FR du 22 décembre 2022 (télétravail transfrontalier) — télétravail jusqu'à 40% du temps de travail sans bascule d'imposition. Règlement CE 883/2004 art. 13 seuil 25% (cotisations). 90 jours ≠ 40% (40% × 220 jours = 88 jours), proche mais ambigu.
Evidence:
```dart
static const int ninetyDayRuleThreshold = 90;
...
'legalReference': 'Art. 15 al. 4 CDI CH-FR / Accord amiable du 22 decembre 2022 / Reglement CE 883/2004 art. 13',
```
Why it breaks the law: the law cited is correct, but the threshold is **not 90 jours**; it's 40% du temps de travail (≈ 88 jours for a 220-day year, 100 jours for 250-day year). The code hardcodes 90 without `workDaysPerYear` input, leading to false low-risk signals for users with long work calendars.
Fix:
- Replace `ninetyDayRuleThreshold = 90` with `teleworkThresholdPct = 0.40`.
- Compute `threshold = workDaysPerYear * 0.40`.
- Separate cotisations (Règl. 883/2004 art. 13, seuil 25%) from imposition (Accord amiable CH-FR, seuil 40%).

**P1-E6 — "Tu es éligible au statut de quasi-résident" recommendation omits GE-specific formal request delay (31.03 de l'année suivante)** (expat_service.dart:366-372)
Legal reference: RD-GE 9 avril 2014, LIS-GE art. 99 (taxation ordinaire ultérieure TOU — demande avant 31 mars de l'année suivante).
Evidence:
```dart
'recommendation': eligible
    ? 'Tu es éligible au statut de quasi-résident. Cela te permet de '
        'faire une taxation ordinaire avec déductions (3a, frais effectifs, etc.). '
        'L\'économie potentielle est estimée à ${formatChf(potentialSavings)}/an.'
    : ...
```
Why incomplete: a user reads this mid-year and waits — misses the 31.03 deadline. Also "3a deduction" is only available if cotise à un 3a lié CH (OPP3 art. 3) — FR-résident may not qualify.
Fix: add "Demande à déposer avant 31 mars de l'année suivant l'année fiscale concernée (LIS-GE art. 99)." + "Déduction 3a conditionnée à cotisations effectives sur un 3a lié CH (OPP3 art. 3)."

**P1-E7 — `estimateAvsGap` voluntary-AVS availability: restricted to non-UE/AELE residents** (expat_service.dart:575-598)
Legal reference: LAVS art. 2 + Règl. CE 883/2004 art. 11: depuis 01.04.2012, **l'AVS facultative n'est plus disponible pour les personnes résidant dans l'UE/AELE** (elles doivent cotiser à la sécu locale). Availability for non-UE/AELE only.
Evidence:
```dart
final canVolunteer = yearsAbroad > 0;
...
recommendation = '... La cotisation volontaire a l\'AVS depuis l\'etranger est fortement recommandee ...';
```
Why incomplete: code sets `canVolunteer = true` if `yearsAbroad > 0` regardless of destination. For a FR/DE/IT/AT resident, voluntary AVS is **illegal** since 2012. Code recommends an unavailable instrument.
Fix:
- Accept `residenceCountry` parameter.
- `canVolunteer = residenceCountry not in UE_AELE_countries && yearsAbroad > 0 && max 5 ans après départ (LAVS art. 2 al. 1bis)`.
- If UE/AELE: surface "Cotisations obligatoires dans le pays de résidence (lex loci domicilii) — totalisation ALCP à l'âge AVS".

**P2-E8 — Disclaimer at expat_service.dart:30-34 refers to "un-e specialiste fiscal-e" — ok, but omits US person + FATCA warning** (expat_service.dart:30-34)
Legal reference: LSFin art. 8, 6038D (IRS).
Fix: append "Pour les US persons / green card holders : consulte un·e fiscaliste CH-US avant tout retrait prévoyance (risque PFIC et FBAR)."

**P2-E9 — Source tax rates hardcoded per canton (expat_service.dart:46-73) — flat rate, not progressive, explicitly flagged with TODO but still risky** (expat_service.dart:42-45)
Legal reference: Ordonnance OIS art. 1 (barème progressif par tranches). The file already admits this in a comment ("For precise calculations, the backend endpoint /expat/frontalier/source-tax should be called"). This is P2 because the TODO is acknowledged, but the ship risk is real for high earners.
Fix: mandatory backend call for estimates over CHF 100k/year.

---

### financial_report_service.dart

**P0-R1 — "Ouvre ton premier 3a", "Ouvre ton 2e compte 3a fintech", "Échelonne rachat LPP" = product advice masquerading as education (LSFin art. 3 let. c + LSFin art. 8-9)** (financial_report_service.dart:506-565)
Legal reference: LSFin art. 3 let. c (conseil en placement = recommandation d'achat/vente d'un instrument financier déterminé), LSFin art. 8 (obligation d'information pré-contractuelle), LSFin art. 9-11 (test adéquation/caractère approprié). MINT is explicitly **no-advice** per CLAUDE.md §6.
Evidence:
```dart
'Ouvre un 2e compte 3a fintech'
'Économise jusqu\'à ${formatChfWithPrefix(displayGain)} d\'impôts sur $nbYears ans.'
'Planifie ton rachat LPP échelonné'
'Effectue 1er rachat avant 31 décembre'
```
Why it breaks the law: imperative tone + specific product-type recommendation ("fintech 3a") + quantified promise ("Économise jusqu'à CHF 12'000") = **conseil en placement** under LSFin art. 3 let. c. The `potentialGainChf` is a **promise of return**, which CLAUDE.md §6 "No-Promise" forbids. "Échelonne rachat LPP" is also a tax-planning recommendation — conseil fiscal, not éducation.
Fix:
- Reframe all action titles as conditional questions: "Un 2e compte 3a pourrait-il faire sens pour ton horizon ?" + side-by-side comparison, no ranking.
- Remove `potentialGainChf: 1500` hardcoded fallback (line 511), `12000.0` (line 527), `60000.0` (line 548).
- Replace with "gain potentiel estimé : CHF X (hypothèse)" always wrapped in `pourrait`.
- Add LSFin art. 3 let. c anchor + disclaimer "Ce n'est pas un conseil en placement".
- Cross-ref CLAUDE.md §6 banned "optimal" — "premier", "deuxième", "échelonné" tones verge on optimal framing.

**P0-R2 — `_buildLppStrategy` recommends rachat 5 ans avant retraite without OPP2 art. 60b expat cap enforcement for expat_us/non-UE** (financial_report_service.dart:393-472)
Legal reference: OPP2 art. 60b al. 1 (Wave 3 ruling cited in MEMORY.md): pour les expats arrivés < 5 ans avant rachat, plafond = 20% du salaire assuré/année. LPP art. 79b al. 3: rachat bloqué 3 ans avant retrait capital.
Evidence:
```dart
if (yearsToRetirement <= 3) {
  ... strategy = 'urgent';
} else if (yearsToRetirement <= 5) {
  ... strategy = 'optimal_now';
} else {
  startYear = retirementYear - 5;
  nbYears = 3;
  strategy = 'wait_recommended';
}
```
Why it breaks the law: no archetype check. For Lauren (expat_us arrivée il y a < 5 ans): OPP2 art. 60b caps her rachat at 20% × salaire assuré. Code proposes `buybackAvailable / nbYears` without that cap. User executes a CHF 52'949 rachat (golden value), SwissGov tax authority rejects the déduction on the portion > 20% cap → **redressement fiscal**. Also "strategy = 'urgent'" when yearsToRetirement ≤ 3 — if the user is also executing EPL in parallel, LPP art. 79b al. 3 blocks the capital retrait for 3 ans AFTER the rachat, so "urgent" advice creates a legal trap.
Fix:
- Read `profile.archetype` and `profile.arrivalAge`; if expat_us or UE-arrived<5yrs, apply OPP2 art. 60b 20% cap.
- Before recommending rachat at `yearsToRetirement <= 3`, check `profile.goalA.plannedCapitalWithdrawal` or EPL marker; if yes, surface **P0 blocker**: "Rachat interdit 3 ans avant retrait capital (LPP art. 79b al. 3)".
- The word "optimal_now" is a CLAUDE.md §6 banned absolute.

**P0-R3 — `_estimateEffectiveRate` uses `marginalRate * 0.85` for married = invented ratio** (financial_report_service.dart:636-645)
Legal reference: LIFD art. 36 al. 2bis (splitting + barème marié = facteur 50% sur part excédant seuil); LHID art. 11 (splitting cantonal varies par canton — VD ×0.5, ZH barème séparé, VS quotient familial, GE splitting modifié).
Evidence:
```dart
// Married couples benefit from splitting (~15% reduction, cf. LIFD art. 36).
return isMarried ? marginalRate * 0.85 : marginalRate;
```
Why it breaks the law: the 15% reduction is a **magic number** — the actual splitting effect varies from 8% (low income) to 25% (high income) and is canton-specific. VS applies quotient familial (not splitting), GE has semi-splitting, ZH has separate barème. Applying a flat 0.85 factor for all cantons **inverts** the right rule and produces false tax savings figures that drive user decisions on rachat LPP / 3a.
Fix:
- Delegate to `RetirementTaxCalculator.estimateMarginalRate(taxableIncome, canton, isMarried: true, children: ...)` which should implement actual cantonal splitting matrix.
- Cite `cantonalMarriedMultiplier` from Wave 3 cantonal matrix (ZH 0.73 / VS 0.81 / ZG 0.70) — extend to income tax, not just capital tax.
- If `profile.etatCivil == partenariatEnregistre` → same treatment as marié (LPart art. 13a).

**P0-R4 — "Déduction enfants" hardcoded 6'500 CHF (financial_report_service.dart:238)** (financial_report_service.dart:237-239)
Legal reference: LIFD art. 35 al. 1 let. a (déduction par enfant fédérale): **CHF 6'700 pour 2025** (indexée). LHID art. 9 al. 2 let. c (cantonal — VS CHF 7'450 ; ZH CHF 9'000 ; VD CHF 11'000 ; GE CHF 12'200 — 2024 valeurs AFC).
Evidence:
```dart
if (profile.hasChildren) {
  deductions['Déduction enfants'] = profile.childrenCount * 6500.0;
}
```
Why it breaks the law: 6'500 CHF is an **outdated pre-2023 federal value** and ignores cantonal deduction (which is typically 50-100% higher than federal). For a VS family with 2 kids: real deduction = 2 × (6'700 féd + 7'450 cant) = CHF 28'300, not CHF 13'000. Code understates by ~55% → overstates taxable income → overstates recommended rachat LPP savings → gives bad sizing advice.
Fix:
- Replace 6'500 with `reg('lifd.child_deduction_federal_2025', 6700)` + cantonal lookup.
- Add sources array reference "LIFD art. 35 al. 1 let. a" + "LHID art. 9 al. 2 let. c".

**P0-R5 — 3a projections show named providers ('fintech', 'insurance', 'bank') with rankable hardcoded rendements = No-Ranking + Product-Advice violation** (financial_report_service.dart:354-363)
Legal reference: CLAUDE.md §6 "No-Ranking", LSFin art. 3 let. c.
Evidence:
```dart
final projections = <String, double>{
  'bank': _futureValue(contribution, 0.015, ...),
  'fintech': _futureValue(contribution, 0.045, ...),
  'fintech_low_fee': _futureValue(contribution, 0.055, ...),
  'insurance': _futureValue(contribution, 0.01, ...),
};
final potentialGain = projections['fintech']! - projections['bank']!;
```
Why it breaks the law: `projections['fintech']! - projections['bank']!` = explicit ranking "fintech beats bank by CHF X". CLAUDE.md §6 forbids ranking; LSFin art. 3 let. c forbids product-type recommendation without adequation test.
Fix:
- Present side-by-side without subtraction, label "rendement moyen observé historiquement — variable selon provider".
- Delete `potentialGainVsBank` or rename to `rendement_annuel_estime_par_classe_actif` (classe d'actif, not "fintech" vs "bank").
- Add disclaimer: "Les rendements historiques ne préjugent pas des rendements futurs. Ne constitue pas une recommandation de produit."

**P0-R6 — `taxSingle = totalCapital * 0.08` and `taxMultiple = (totalCapital/2)*0.05*2` = invented tax rates (law inverted)** (financial_report_service.dart:372-378)
Legal reference: LIFD art. 38 al. 2 (capital prévoyance taxed séparément au 1/5 du barème ordinaire LIFD art. 36). Cantonal barèmes varient largement (ZH progressive par tranche CHF 12k/60k/225k, VS forfait, GE splitting). Pas de flat 5% ou 8%.
Evidence:
```dart
taxSingle = totalCapital * 0.08;
taxMultiple = (totalCapital / 2) * 0.05 * 2;
savingsMultiple = taxSingle - taxMultiple;
```
Why it breaks the law: flat 8% ignores progressive 1/5 barème. On CHF 200k single withdrawal vs 2 × CHF 100k échelonné, real ZH tax saving is ~CHF 4'500 not `200k * 0.03 = 6'000` the code computes. Worse, `taxMultiple = (totalCapital/2) * 0.05 * 2 = totalCapital * 0.05` — the "×2" cancels the /2, which means the split logic is **mathematically wrong** (same formula as single-withdrawal with rate 5% instead of 8%; "saving" is just `totalCapital * 0.03` — pure magic number).
Fix:
- Delegate to `RetirementTaxCalculator.capitalWithdrawalTax(capital, canton, isMarried)` for each scenario.
- Use the cantonal matrix from Wave 3 (ZH 0.73 / VS 0.81 / ZG 0.70).
- Remove 0.08, 0.05 constants.

**P1-R7 — RoadmapPhase "Court Terme" with empty actions list surfaces empty UI phase** (financial_report_service.dart:626-630)
Legal reference: LSFin art. 8 (information obligations — must be clear and useful).
Fix: either populate or omit the phase; never show empty recommendations to user.

**P2-R8 — LppBuybackStrategy.description contains "Économise jusqu'à {displayGain}" with `displayGain = 60000.0` fallback when `computedGain == 0`** (financial_report_service.dart:548-554)
Legal reference: CLAUDE.md §6 "No-Promise".
Fix: if computedGain == 0, show "gain estimé indisponible — compléter profil" instead of invented CHF 60'000.

**P2-R9 — "Tu seras impose sur les revenus du 1er janvier jusqu'a la date de depart. Delai de depot: 30 jours apres le depart." — incorrect** (not in this file, see expat_service.dart:689-694, but report service echoes it; noting cross-ref)
Legal reference: LIFD art. 8 al. 2, cantonal procedures (VD 30 jours, GE 30 jours, ZH 60 jours, VS 30 jours). The 30-day rule is mostly correct but varies.
Fix: "Délai cantonal (30-60 jours après le départ selon canton)".

---

### budget_service.dart

**P0-B1 — `premierEclairage` divides `totalCharges` by `inputs.netIncome` without clamp, can output >100% with zero guard on dette-crise** (budget_service.dart:23-32)
Legal reference: LP art. 93 (minimum vital), CO art. 323 (protection du salaire), LAMal art. 64a (non-paiement primes). In a dette-crise, totalCharges > netIncome → `pct > 100%`. Budget_service returns "155% de ton revenu part en charges fixes" — correct math, but **CLAUDE.md SafeMode doctrine** says: if toxic debt detected → disable optimizations, priority = debt reduction. The phrase "part en charges fixes" suggests a budget allocation exercise, not a crisis signal.
Evidence:
```dart
if (inputs.netIncome <= 0) return '0% de ton revenu part en charges fixes';
final totalCharges = inputs.housingCost + inputs.debtPayments + inputs.taxProvision + inputs.healthInsurance + inputs.otherFixedCosts;
final pct = (totalCharges / inputs.netIncome * 100).round();
return '$pct% de ton revenu part en charges fixes';
```
Why it breaks the doctrine: not strictly illegal, but the message framing on a user in dette-crise (pct > 90%) is negligent — should trigger SafeMode escalation per CLAUDE.md §7. The lack of LP art. 93 reference or dette-crise disclaimer on a critical signal = LSFin art. 8 information obligation breach (failure to contextualise a harmful number).
Fix:
- If `pct >= 70` → append "Situation fragile — priorité désendettement (LP art. 93)".
- If `pct >= 100` → trigger SafeMode flag + show "Charges > revenus — contacte un service social (CSP, Caritas) immédiatement".
- Add LP art. 93 to sources.

**P0-B2 — `sources` list cites "LP art. 93 (minimum vital / calcul du budget)" but the service never computes minimum vital** (budget_service.dart:11-17, :23-32)
Legal reference: LP art. 93 = minimum vital OP (normes ACR/CSIAS), CHF 1'200 + 850 marié + 400/enfant + loyer effectif + primes LAMal + impôts courants (dans certains cantons). Budget_service **does not** compute it — it aggregates charges. Citing LP art. 93 as a source without implementing it is a **misleading legal anchor** per LSFin art. 8.
Evidence:
```dart
static const List<String> sources = [
  'LP art. 93 (minimum vital / calcul du budget)',
  'Directives CSIAS ...',
  ...
];
```
Why it breaks the law: user reads "sources: LP art. 93" and assumes the premierEclairage computes the legal minimum vital, which it does not. LSFin art. 8 requires truthful source attribution.
Fix:
- Either implement CSIAS minimum vital formula (base + loyer effectif + LAMal + enfants) and surface it, OR
- Remove "LP art. 93 / minimum vital" from sources if not computed, OR
- Add a `minimumVitalCsias` field computed per CSIAS 2025 norms.

**P1-B3 — No dette-crise / toxic-debt classification** (budget_service.dart entire file)
Legal reference: CO art. 143 (solidarité dette), LP art. 265a (procédure amiable). CLAUDE.md §7 "Safe Mode: If toxic debt detected → disable optimizations".
Evidence: No `debtToIncomeRatio`, `isInDebtCrisis`, or SafeMode guard in this service.
Fix: compute `debtToIncomeRatio = inputs.debtPayments * 12 / (inputs.netIncome * 12)`; if > 0.33 → flag toxic; disable emergency fund recommendation and redirect to désendettement.

**P1-B4 — `BudgetStyle.envelopes3` stopRuleTriggered fires at `variables <= 0.01` without 3-month emergency fund check** (budget_service.dart:99-106)
Legal reference: none direct, but CLAUDE.md §7 requires ≥ 3 months emergency fund before any "future" allocation.
Fix: add check `if emergencyFundMonths < 3 && future > 0 → warn "Prioriser fonds d'urgence 3 mois (CSIAS) avant épargne long terme"`.

**P1-B5 — No LACI / chômage provision in budget** (budget_service.dart)
Legal reference: LACI art. 22 al. 1 let. a (70% du gain assuré sans enfant, 80% avec). For a user close to jobLoss life event, budget must provision 70-80% income drop.
Fix: accept an `employmentRiskMonths` input; compute `budget_scenario_chomage` mirror.

**P2-B6 — Disclaimer cites LSFin but never says "Non-conseil financier individualisé"** (budget_service.dart:6-9)
Fix: append "Ceci n'est pas un conseil en placement ni un plan de désendettement (LSFin art. 3)."

**P2-B7 — `premierEclairage` returns raw French sentence — no i18n** (budget_service.dart:27, :31)
Legal reference: CLAUDE.md §7 i18n mandatory. Not fiscal, but compliance-adjacent.
Fix: move to ARB key `budgetPremierEclairagePct`.

---

## Cross-file concerns

### Double taxation paths (P0)
- **forecaster_service.dart:927-943** — 3a annualised post-capital-tax summed with AVS/LPP rentes pre-income-tax. User sees inflated replacement rate.
- **expat_service.dart:725-741** — `compareTaxBurden` adds foreign income tax + foreign social to a single `foreignTotalRate` that is then applied to `annualSalary` already subject to CH source tax. User could read this as "CH taxes me, then FR taxes me again at 50%" — neither scenario is Swiss law; under CDI-CH-FR art. 15 + Règl. 883/2004 art. 11, only one jurisdiction applies.
- **financial_report_service.dart:372-378** — the taxSingle = 8% × capital ignores LIFD art. 38 1/5 barème, then `taxMultiple = totalCapital * 0.05`, then `savingsMultiple = taxSingle - taxMultiple` = pure magic number. This drives UI "économise CHF 6'000 en échelonnant".

### Missing archetype penalties (P0)
- **No FATCA blocker anywhere**: forecaster adds Lauren's partner 3a freely (P0-F1); expat_service.planDeparture tells her to retrait 3a (P0-E1); financial_report proposes "Ouvre ton 2e 3a fintech" (P0-R1). Lauren runs all three and ends up: (a) auto-enrolled in PFIC, (b) triggering IRS exit event on retrait, (c) owning an unqualified US-taxable second 3a.
- **No cross_border / permis G check** on budget_service (charges fiscales CH vs FR mix).
- **No independent_no_lpp detection** — financial_report_service._build3aAnalysis uses `maxContribution = profile.isSalaried ? 7258 : pilier3aPlafondSansLpp` but `isSalaried` is binary, doesn't capture `independent_with_lpp` archetype who gets salaried plafond.
- **No OPP2 art. 60b expat < 5 ans cap** in financial_report_service._buildLppStrategy (Wave 3 ruling not plumbed through).

### Banned terms detected (CLAUDE.md §6)
- **financial_report_service.dart:427** `strategy = 'optimal_now'` → "optimal" banned.
- **financial_report_service.dart:437** `strategy = 'wait_recommended'` → "recommended" = product-advice ton.
- **financial_report_service.dart:511** "Déduis jusqu'à CHF 7'258/an de ton revenu imposable. Économie immédiate." → "Économie immédiate" = promesse de retour.
- **financial_report_service.dart:554** "Économise jusqu'à CHF {displayGain} d'impôts" → "Économise" imperatif + quantified promise.
- **financial_report_service.dart:584** "C'est le placement le plus rentable" → "le plus rentable" banned absolute.
- **expat_service.dart:401, :408** "tu es largement sous le seuil" → ton excessivement rassurant pré-arbitrage (CLAUDE.md §7 "Jamais générique, jamais infantilisant").
- **expat_service.dart:593** "fortement recommandee" → "recommended" ton.

### Imperative "tu" verbs on product action (LSFin art. 3 let. c risk)
- "Ouvre ton premier 3a", "Ouvre un 2e compte 3a fintech", "Effectue 1er rachat avant 31 décembre", "Planifie ton rachat LPP échelonné", "Rembourse tes dettes", "Constitue ton fonds d'urgence", "Vérifie ton compte AVS", "Retirer pilier 3a", "Transferer LPP en libre passage", "Annoncer depart a la commune".
- **Not all are problematic** — retrait 3a / annonce commune / LAMal are administrative obligations (acceptable).
- **Problematic**: product-type imperatives ("Ouvre un fintech", "Planifie rachat", "Rembourse d'abord le plus haut taux") = tax/placement advice.

---

## LSFin art. 3 / 8 boundary violations (summary)

| File | Line | Wording | Verdict |
|---|---|---|---|
| financial_report_service.dart | 511 | "Déduis jusqu'à CHF 7'258/an… Économie immédiate." | **P0** — quantified promise + imperative |
| financial_report_service.dart | 531 | "Optimise ta fiscalité au retrait" | **P0** — "optimise" banned, product advice |
| financial_report_service.dart | 546-554 | "Planifie ton rachat LPP échelonné. Économise jusqu'à X d'impôts sur N ans." | **P0** — conseil fiscal quantifié sans adéquation |
| financial_report_service.dart | 584 | "C'est le placement le plus rentable" | **P0** — banned "le plus rentable" |
| financial_report_service.dart | 600 | "Constitue ton fonds d'urgence" | **P1** — imperative ok (administrative), but "Ouvre un compte Zak, Neon" in steps = product naming |
| financial_report_service.dart | 606 | "Ouvre un compte épargne gratuit (ex: Zak, Neon)" | **P0** — **named product recommendation** — direct LSFin art. 3 let. c breach |
| expat_service.dart | 638 | "Impot de sortie reduit" | **P0** — factual error + tax claim |
| expat_service.dart | 401-402 | "Tu peux continuer a travailler depuis ton domicile" | **P1** — unconditional advice without 40% pct |
| expat_service.dart | 593-597 | "La cotisation volontaire a l'AVS depuis l'etranger est fortement recommandee" | **P1** — may be illegal for UE/AELE residents |
| forecaster_service.dart | 324-328 | Disclaimer ok but `tauxRemplacementBase` above is a gross/net mixed number | **P1** — projection reads as advice |
| budget_service.dart | 6-9 | Disclaimer OK but no "non-conseil en placement" | **P2** |

---

## Priority list (actionable before merge)

### MUST FIX (P0 — 11 findings)
1. **P0-F1** forecaster partner 3a archetype blindness → null-default `canContribute3a` + FATCA blocker.
2. **P0-F2** 3a annualisation gross/net inconsistency → align all retirement income on same basis.
3. **P0-F3** SWR 4% labeled "rendement" → rename + split revenu imposable vs consommation capital.
4. **P0-E1** "Impot de sortie reduit" 3a departure → replace with LIFD art. 38 + cantonal source tax.
5. **P0-E2** LPP UE/AELE oblig/surob distinction → split per LFLP art. 25f.
6. **P0-E3** forfait flat 25% → progressive LIFD art. 36.
7. **P0-E4** compareTaxBurden double-social → Règl. CE 883/2004 lex loci laboris.
8. **P0-R1** "Ouvre ton 2e 3a fintech" imperative + quantified gain → reframe conditional, no product naming.
9. **P0-R2** _buildLppStrategy OPP2 art. 60b expat cap missing + no LPP art. 79b 3-year block check.
10. **P0-R3** `marginalRate * 0.85` invented splitting → cantonal matrix.
11. **P0-R4** Déduction enfants 6'500 CHF outdated → 6'700 féd + cantonal.
12. **P0-R5** 3a provider projections ranking (bank vs fintech) → no-ranking.
13. **P0-R6** invented 8%/5% capital tax → `RetirementTaxCalculator.capitalWithdrawalTax`.
14. **P0-B1** budget_service premierEclairage no dette-crise escalation → LP art. 93 + SafeMode trigger.
15. **P0-B2** budget sources cite LP art. 93 not implemented → remove or implement.
16. **P0 cross** — named product "Zak, Neon" at financial_report_service.dart:606 → generic category.

### SHOULD FIX (P1)
- P1-F4 partenariat enregistré LPart art. 13a.
- P1-F5 ADR for LPP 6.8% post-referendum.
- P1-F6 totalisation ALCP/US séparée.
- P1-E5 40% télétravail CH-FR vs 90 jours.
- P1-E6 GE quasi-résident deadline 31.03.
- P1-E7 AVS volontaire UE/AELE interdit.
- P1-R7 Roadmap phase "Court Terme" vide.
- P1-B3 debt-to-income ratio.
- P1-B4 emergency fund 3 mois avant future.
- P1-B5 LACI 70-80% chômage provision.

### NICE TO HAVE (P2)
- P2-F7/F8 forecaster disclaimers.
- P2-E8/E9 expat disclaimers + source tax backend call.
- P2-R8/R9 report minor wording.
- P2-B6/B7 budget i18n + LSFin mention.

---

## Recommended next step

Escalate P0-F1 + P0-R1 + P0-E1 immediately — these are the three spots where Lauren (expat_us golden) is actively guided into FATCA/PFIC traps by the current code path. All three are single-file fixes with clear legal anchors (IRC §1291, OPP3 art. 3 al. 1 let. b, LFLP art. 25f).

*Audit conducted against LPP RS 831.40, LAVS RS 831.10, OPP2 RS 831.441.1, OPP3 RS 831.461.3, LIFD RS 642.11, LHID RS 642.14, LFLP RS 831.42, LACI RS 837.0, LSFin RS 950.1, CO RS 220, CC RS 210, LP RS 281.1, CDI-CH-FR 1966 (version consolidée 2022), Règl. CE 883/2004, IRC §1291/§1471/§6038D, as in force on 2026-04-18.*
