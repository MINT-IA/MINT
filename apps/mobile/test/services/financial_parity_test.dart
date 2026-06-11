// Parity test harness for the « mint-illogism-fixes » phase.
//
// Encode l'oracle de la matrice d'illogismes
// (.planning/reports/MATRIX-illogismes-2026-06-09.md) sous forme de tests de
// parité : pour un même input, les moteurs d'estimation financière doivent
// produire un chiffre IDENTIQUE (au centime), quelle que soit la surface
// publique empruntée. Toute régression vers la classe DIVERGENT casse la CI.
//
// Conformément à CLAUDE.md NEVER #3 (pas de calcul dupliqué L1), la source
// canonique est `LppCalculator` (financial_core L1). Les tests passent par les
// surfaces PUBLIQUES uniquement (CoachProfile.fromWizardAnswers /
// MinimalProfileService.compute) — jamais par les membres privés `_estimate*`.
//
// Groupes prévus :
//   - « Parity W1 — Avoir LPP »          (plan 01, ce fichier)
//   - « Parity W2 — Rente LPP »          (plan 02)
//   - « Parity W3 — Taux de remplacement » (plan 03)
//   - « Parity W4 — 3a »                  (plan 04)
//   - « Parity W5 — Invariants »          (plan 05)

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/cap_sequence_engine.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/financial_core/archetype_predicates.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/replacement_rate.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';

/// Construit les réponses du wizard pour un profil salarié canonique.
///
/// `q_gross_salary_annual` court-circuite la conversion net→brut afin que le
/// salaire brut soit déterministe (salaireBrutMensuel = gross / 12).
Map<String, dynamic> _salariedAnswers({
  required int age,
  required double grossAnnual,
  String? avsLacunesStatus,
  int? arrivalYear,
}) {
  final birthYear = DateTime.now().year - age;
  return <String, dynamic>{
    'q_birth_year': birthYear,
    'q_canton': 'GE',
    'q_employment_status': 'salarie',
    'q_pay_frequency': 'yearly',
    'q_gross_salary_annual': grossAnnual,
    'q_has_pension_fund': true,
    if (avsLacunesStatus != null) 'q_avs_lacunes_status': avsLacunesStatus,
    if (arrivalYear != null) 'q_avs_arrival_year': arrivalYear,
  };
}

/// Avoir LPP estimé via la surface publique CoachProfile.
double _coachAvoir(Map<String, dynamic> answers) {
  final profile = CoachProfile.fromWizardAnswers(answers);
  return profile.prevoyance.avoirLppTotal ?? 0.0;
}

/// Avoir LPP estimé via la surface publique MinimalProfileService.
double _minimalAvoir({
  required int age,
  required double grossAnnual,
  int? arrivalAge,
}) {
  final result = MinimalProfileService.compute(
    age: age,
    grossSalary: grossAnnual,
    canton: 'GE',
    employmentStatus: 'salarie',
    arrivalAge: arrivalAge,
  );
  return result.existingLpp;
}

void main() {
  group('Parity W1 — Avoir LPP', () {
    test('salarie_swiss-1 — 42/102000 : 3 chemins égaux + coord plafonné 64260',
        () {
      const age = 42;
      const gross = 102000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      // Référence canonique : accumulation balance-only depuis 25 (financial_core).
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Le salaire coordonné est plafonné à 64260 (LPP art. 8) — 102000 - 26460
      // = 75540 > 64260, donc clamp haut. Régression mesurée : clamp min-only.
      expect(
        LppCalculator.computeSalaireCoordonne(gross),
        closeTo(64260.0, 0.01),
      );

      expect(coach, closeTo(canonical, 0.01),
          reason: 'coach divergent de la source canonique');
      expect(minimal, closeTo(canonical, 0.01),
          reason: 'minimal divergent de la source canonique');
      expect(coach, closeTo(minimal, 0.01),
          reason: 'coach et minimal divergent entre eux (classe DIVERGENT)');
    });

    test('cadre_divorce_hypo-2 — 52/162000 : 3 chemins égaux au centime', () {
      const age = 52;
      const gross = 162000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Cas où l'écart historique culminait à +105% (gross 162k au-delà du
      // plafond → le clamp min-only de coach gonflait le salaire coordonné).
      expect(coach, closeTo(canonical, 0.01));
      expect(minimal, closeTo(canonical, 0.01));
      expect(coach, closeTo(minimal, 0.01));
    });

    test('jeune_diplome-1 (contrôle négatif) — 25/78000 : avoir == 0 partout',
        () {
      const age = 25;
      const gross = 78000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final minimal = _minimalAvoir(age: age, grossAnnual: gross);
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // Aucune année de bonification écoulée (boucle [25, 25)) → avoir 0.
      expect(canonical, closeTo(0.0, 0.01));
      expect(coach, closeTo(0.0, 0.01),
          reason: 'NE PAS régresser le contrôle négatif jeune diplômé');
      expect(minimal, closeTo(0.0, 0.01));
    });

    test('returning_swiss_gaps-4 — 48/120000/arrivée 43 : accumulation ~5 ans',
        () {
      const age = 48;
      const gross = 120000.0;
      const arrivalAge = 43;
      final arrivalYear = DateTime.now().year - age + arrivalAge;

      final coach = _coachAvoir(_salariedAnswers(
        age: age,
        grossAnnual: gross,
        avsLacunesStatus: 'arrived_late',
        arrivalYear: arrivalYear,
      ));
      final minimal = _minimalAvoir(
        age: age,
        grossAnnual: gross,
        arrivalAge: arrivalAge,
      );

      // Référence : accumulation démarrant à 43, pas à 25 → ~5 années
      // (43→48) au lieu de 23 (25→48).
      final canonicalArrival = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
        startAge: arrivalAge,
      );
      final canonicalFrom25 = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      // L'accumulation depuis l'arrivée est nettement inférieure à depuis 25.
      expect(canonicalArrival, lessThan(canonicalFrom25));

      expect(coach, closeTo(canonicalArrival, 0.01),
          reason: 'coach doit démarrer l\'accumulation à arrivalAge=43');
      expect(minimal, closeTo(canonicalArrival, 0.01),
          reason: 'minimal doit démarrer l\'accumulation à arrivalAge=43');
      expect(coach, closeTo(minimal, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W2 — Rente LPP (plan 02)
  //
  //  Oracle matrice §2 « Rente LPP » + « Capacité rachat LPP » :
  //  pour un même avoirLppTotal stocké, la rente mensuelle estimée est
  //  IDENTIQUE quel que soit le chemin (cap_sequence, minimal_profile, …) —
  //  fin du spread device-prouvé 250-347 CHF/mois (D4). UNE base de taux
  //  via LppCalculator.adjustedConversionRate / monthlyRenteFromAvoir.
  // ════════════════════════════════════════════════════════════════

  group('Parity W2 — Rente LPP', () {
    const memory = CapMemory();
    final l = SFr();

    /// Construit un profil retraite minimal avec un avoir LPP stocké
    /// et un taux de conversion de caisse explicite.
    CoachProfile retirementProfile({
      required double avoirLpp,
      double tauxConversion = lppTauxConversionMinDecimal,
      int birthYear = 1976, // ~50 ans
      double salaireBrutMensuel = 9000,
      int? targetRetirementAge,
      double rachatMaximum = 0,
    }) {
      return CoachProfile(
        birthYear: birthYear,
        canton: 'GE',
        salaireBrutMensuel: salaireBrutMensuel,
        employmentStatus: 'salarie',
        targetRetirementAge: targetRetirementAge,
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: avoirLpp,
          tauxConversion: tauxConversion,
          rachatMaximum: rachatMaximum,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2041),
          label: 'Retraite',
        ),
      );
    }

    /// Rente LPP mensuelle estimée via le chemin public CapSequenceEngine
    /// (step « ret_03_lpp », impactEstimate = rente mensuelle).
    double capSequenceRente(CoachProfile profile) {
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: l,
      );
      final step = seq.steps.firstWhere((s) => s.id == 'ret_03_lpp');
      return step.impactEstimate ?? 0.0;
    }

    /// Impact mensuel d'un rachat via le chemin public CapSequenceEngine
    /// (step « ret_06_rachat », impactEstimate = impact mensuel).
    double capSequenceRachatImpact(CoachProfile profile) {
      final seq = CapSequenceEngine.build(
        profile: profile,
        memory: memory,
        goalIntentTag: 'retirement_choice',
        l: l,
      );
      final step = seq.steps.firstWhere((s) => s.id == 'ret_06_rachat');
      return step.impactEstimate ?? 0.0;
    }

    // ── Task 1 : source canonique unique pour la conversion avoir → rente ──

    test('avoir 300000 — monthlyRenteFromAvoir : UNE rente (1700 CHF/mois)', () {
      const avoir = 300000.0;
      final profile = retirementProfile(avoirLpp: avoir);

      // Référence canonique : avoir × adjustedConversionRate(0.068, 65) / 12.
      // C'est exactement la formule à laquelle mariage_screen, response_card,
      // financial_summary délèguent désormais (fin du spread 250-347 CHF/mois).
      final canonical = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );

      // À l'âge de référence (65), adjustedConversionRate retourne baseRate :
      // 300000 × 0.068 / 12 = 1700 CHF/mois.
      expect(canonical, closeTo(1700.0, 0.01));
    });

    test('monthlyRenteFromAvoir — retraite anticipée 62 < 65 : réduction art.13',
        () {
      const avoir = 300000.0;

      final renteReference = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 65,
      );
      // 3 ans avant 65 → 3 × 0.002 = 0.006 de réduction → taux 0.062.
      final renteEarly = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 62,
      );
      expect(renteEarly, closeTo(300000 * 0.062 / 12, 0.01));

      // La retraite anticipée produit une rente strictement inférieure —
      // la réduction LPP art. 13 al. 2 s'applique via le canonique.
      expect(renteEarly, lessThan(renteReference),
          reason: 'la réduction retraite anticipée doit s\'appliquer');
    });

    test('minimal_profile — rente projetée applique la réduction anticipée',
        () {
      // minimal_profile PROJETTE l'avoir jusqu'à la retraite (projectToRetirement),
      // contrairement aux écrans qui convertissent l'avoir STOCKÉ. C'est une
      // opération distincte ; ici on vérifie seulement que son chemin canonique
      // applique bien la réduction retraite anticipée (LPP art. 13 al. 2).
      const age = 50;
      const gross = 108000.0;
      const avoir = 250000.0;

      final reference = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: 'GE',
        employmentStatus: 'salarie',
        existingLpp: avoir,
        targetRetirementAge: 65,
      );
      final early = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: 'GE',
        employmentStatus: 'salarie',
        existingLpp: avoir,
        targetRetirementAge: 62,
      );

      // Retraite anticipée → moins d'années d'accumulation ET taux réduit →
      // rente strictement inférieure (chemin canonique projectToRetirement).
      expect(early.lppMonthlyRente, lessThan(reference.lppMonthlyRente),
          reason: 'minimal_profile doit passer par le taux canonique réduit');
    });

    // ── Task 2 : cap_sequence (rente + impact rachat) sur la même base ──

    test('cap_sequence avoir 300000 — délègue à monthlyRenteFromAvoir', () {
      const avoir = 300000.0;
      final profile = retirementProfile(avoirLpp: avoir);

      final canonical = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );

      expect(capSequenceRente(profile), closeTo(canonical, 0.01),
          reason: 'cap_sequence doit déléguer à monthlyRenteFromAvoir');
    });

    test('cap_sequence retraite anticipée 62 < 65 — réduction art.13 al.2', () {
      const avoir = 300000.0;
      final reference = retirementProfile(avoirLpp: avoir);
      final early = retirementProfile(avoirLpp: avoir, targetRetirementAge: 62);

      final renteReference = capSequenceRente(reference);
      final renteEarly = capSequenceRente(early);

      final canonicalEarly = LppCalculator.monthlyRenteFromAvoir(
        avoir: avoir,
        baseRate: lppTauxConversionMinDecimal,
        retirementAge: 62,
      );

      // La retraite anticipée produit une rente strictement inférieure : la
      // réduction LPP art. 13 al. 2 doit transiter par le canonique.
      expect(renteEarly, lessThan(renteReference),
          reason: 'cap_sequence doit appliquer la réduction anticipée');
      expect(renteEarly, closeTo(canonicalEarly, 0.01));
    });

    test('cap_sequence rachat 50000 — impact sur la même base (fin 283 vs 242)',
        () {
      const avoir = 200000.0;
      const rachat = 50000.0;
      final profile = retirementProfile(avoirLpp: avoir, rachatMaximum: rachat);

      final impactCap = capSequenceRachatImpact(profile);

      // L'impact d'un rachat utilise la MÊME base de taux que la rente
      // (fin de la divergence 283 vs 242 CHF/mois). 50000 × 0.068 / 12.
      final canonicalImpact = LppCalculator.monthlyRenteFromAvoir(
        avoir: rachat,
        baseRate: profile.prevoyance.tauxConversion,
        retirementAge: profile.effectiveRetirementAge,
      );
      expect(canonicalImpact, closeTo(50000 * 0.068 / 12, 0.01));
      expect(impactCap, closeTo(canonicalImpact, 0.01),
          reason: 'impact rachat doit déléguer à la même base canonique');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W3 — Taux de remplacement (plan 03)
  //
  //  Oracle matrice §2 « Taux de remplacement » + « Marge libre » +
  //  « Retraite projetée » + D3 (63% vs 46.5% même session).
  //
  //  UNE définition app-wide (lock CONTEXT W1) :
  //    taux = revenu retraite mensuel (AVS+LPP, SANS soustraction de dette)
  //           / revenu NET mensuel courant (NetIncomeBreakdown), en %.
  //
  //  La source canonique est `ReplacementRate.percent` (financial_core L1).
  //  Tous les chemins publics (minimal_profile, response_card, budget_living)
  //  délèguent à ce helper — fin du mélange numérateur-net / dénominateur-brut
  //  et de la soustraction de dette dans un seul moteur.
  // ════════════════════════════════════════════════════════════════

  group('Parity W3 — Taux de remplacement', () {
    final l = SFr();

    /// Carte « taux de remplacement » via la surface publique ResponseCardService.
    ResponseCard replacementCard(CoachProfile profile) {
      final cards = ResponseCardService.generateForPulse(profile, l: l, limit: 8);
      return cards.firstWhere(
        (c) => c.type == ResponseCardType.replacementRate,
        orElse: () => throw StateError('replacement_rate card absente'),
      );
    }

    // ── Définition canonique : dénominateur NET, clamp ≥ 0, échelle % ──

    test('ReplacementRate.percent — dénominateur NET, échelle %', () {
      // 4000 retraite / 8000 net = 50%.
      expect(
        ReplacementRate.percent(
            totalMonthlyRetirement: 4000, netMonthlyIncome: 8000),
        closeTo(50.0, 0.001),
      );
    });

    test('ReplacementRate.percent — clamp ≥ 0 et net non-positif → 0', () {
      expect(
        ReplacementRate.percent(
            totalMonthlyRetirement: -100, netMonthlyIncome: 8000),
        closeTo(0.0, 0.001),
        reason: 'numérateur négatif → clamp 0',
      );
      expect(
        ReplacementRate.percent(
            totalMonthlyRetirement: 4000, netMonthlyIncome: 0),
        closeTo(0.0, 0.001),
        reason: 'net non-positif → 0 (pas de division par zéro)',
      );
    });

    // ── minimal_profile : dénominateur NET (plus BRUT) + pas de dette ──

    test(
        'minimal_profile — dénominateur NET via NetIncomeBreakdown (fin du brut)',
        () {
      const age = 50;
      const gross = 102000.0;
      const canton = 'GE';

      final result = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
      );

      // Le revenu net courant canonique (référence response_card).
      final net = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: canton,
        age: age,
      ).monthlyNetPayslip;

      // Le taux est désormais revenu_retraite / NET (champ fraction 0-1
      // conservé pour les consommateurs existants — percent / 100).
      final expectedFraction = ReplacementRate.percent(
            totalMonthlyRetirement: result.totalMonthlyRetirement,
            netMonthlyIncome: net,
          ) /
          100.0;

      expect(result.replacementRate, closeTo(expectedFraction, 0.0001),
          reason: 'le dénominateur doit être le NET (NetIncomeBreakdown), '
              'pas le brut');

      // Régression : avec un dénominateur NET (< brut), le taux est
      // strictement supérieur au taux brut historique (même numérateur).
      const grossMonthly = gross / 12;
      final ratioBrut = result.totalMonthlyRetirement / grossMonthly;
      expect(result.replacementRate, greaterThan(ratioBrut),
          reason: 'NET < BRUT ⇒ taux NET > taux BRUT historique');
    });

    test(
        'minimal_profile — la dette n\'est plus soustraite du revenu retraite '
        '(D3 §2 « Retraite projetée »)', () {
      const age = 50;
      const gross = 120000.0;
      const canton = 'GE';

      final sansDette = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
      );
      final avecDette = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        monthlyDebtService: 800,
      );

      // La composition canonique du revenu retraite = AVS + LPP (la dette est
      // une donnée budget, PAS un revenu retraite). Le service de dette ne doit
      // plus diminuer le revenu retraite total ni le taux de remplacement.
      expect(avecDette.totalMonthlyRetirement,
          closeTo(sansDette.totalMonthlyRetirement, 0.01),
          reason: 'la dette ne doit plus être soustraite du revenu retraite');
      expect(avecDette.replacementRate, closeTo(sansDette.replacementRate, 0.0001),
          reason: 'le taux de remplacement ne dépend plus du service de dette');
    });

    // ── response_card : délègue au helper (chemin de référence) ──

    test('response_card — value == ReplacementRate.percent(total, net)', () {
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 52,
        canton: 'GE',
        salaireBrutMensuel: 102000.0 / 12,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 300000,
          tauxConversion: lppTauxConversionMinDecimal,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2039),
          label: 'Retraite',
        ),
      );

      final card = replacementCard(profile);

      // La carte expose value (le %) et, dans son explication, le revenu
      // retraite total et le revenu net courant (arrondis). value doit être
      // EXACTEMENT le helper canonique appliqué à ces composantes — preuve que
      // response_card délègue à ReplacementRate.percent et n'a pas de formule
      // ad-hoc (numérateur AVS+LPP, dénominateur NET).
      final numbers = RegExp(r'\d+')
          .allMatches(card.premierEclairage.explanation)
          .map((m) => double.parse(m.group(0)!))
          .toList();
      expect(numbers.length, greaterThanOrEqualTo(2),
          reason: 'explication doit citer total retraite + net courant');
      final total = numbers[0];
      final net = numbers[1];

      final expected =
          ReplacementRate.percent(totalMonthlyRetirement: total, netMonthlyIncome: net);
      // Tolérance 0.5 pt : total/net sont arrondis à l'entier dans l'explication.
      expect(card.premierEclairage.value, closeTo(expected, 0.5),
          reason: 'response_card doit déléguer à ReplacementRate.percent');
    });

    // ── budget_living : fin de la formule mixte (NET/BRUT) ──

    test(
        'budget_living — taux NET/NET en % (fin de la formule mixte net/brut)',
        () {
      final profile = CoachProfile(
        birthYear: DateTime.now().year - 50,
        canton: 'GE',
        salaireBrutMensuel: 108000.0 / 12,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 250000,
          tauxConversion: lppTauxConversionMinDecimal,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2041),
          label: 'Retraite',
        ),
      );

      final snapshot = BudgetLivingEngine.compute(profile);
      final gap = snapshot.gap;
      expect(gap, isNotNull, reason: 'le gap retraite doit être calculé');

      final present = snapshot.present;
      final retirement = snapshot.retirement;
      expect(retirement, isNotNull);

      // Le taux canonique = revenu retraite NET / revenu présent NET, en %.
      // Plus de dénominateur brut : present.monthlyNet (NET) est le diviseur,
      // identique au numérateur du monthlyGap (les deux sont NET).
      final expected = ReplacementRate.percent(
        totalMonthlyRetirement: retirement!.monthlyNet,
        netMonthlyIncome: present.monthlyNet,
      );
      expect(gap!.replacementRate, closeTo(expected, 0.01),
          reason: 'le dénominateur doit être present.monthlyNet (NET), '
              'pas grossMonthlySalary (BRUT)');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W3 — Base nette (plan 03, Task 2)
  //
  //  Oracle matrice §2 « Marge libre mensuelle » : pour un même brut + canton,
  //  le revenu NET est IDENTIQUE par tous les chemins. Fin des ratios plats
  //  0.75 / 0.78 (spread device-prouvé ~300 CHF/mois sur 120k brut). UNE base
  //  nette canonique : NetIncomeBreakdown.compute (canton + âge aware).
  // ════════════════════════════════════════════════════════════════

  group('Parity W3 — Base nette', () {
    test('minimal_profile — dépenses dérivées du NET canonique (fin du 0.75)',
        () {
      const age = 45;
      const gross = 120000.0;
      const canton = 'GE';

      final result = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'single',
      );

      final canonicalNet = NetIncomeBreakdown.compute(
        grossSalary: gross,
        canton: canton,
        age: age,
      ).monthlyNetPayslip;

      // Les dépenses « single » = 80% du NET canonique (ratio de dépense),
      // plus 0.75 × brut comme proxy. Preuve que la base nette est canonique.
      expect(result.estimatedMonthlyExpenses, closeTo(canonicalNet * 0.80, 0.01),
          reason: 'la base nette doit venir de NetIncomeBreakdown, pas 0.75');

      // Régression : le proxy plat brut×0.75/12 produirait une autre valeur.
      const flatProxy = gross * 0.75 / 12 * 0.80;
      expect(result.estimatedMonthlyExpenses,
          isNot(closeTo(flatProxy, 0.01)),
          reason: 'ne doit plus utiliser le ratio plat 0.75');
    });

    test('coach_profile_seeds — net mensuel via NetIncomeBreakdown (fin du 0.78)',
        () {
      const age = 50;
      const grossMonthly = 10000.0; // 120k annuel
      const canton = 'GE';
      const seed = CoachProfileSeed(
        slug: 'parity_w3_base_nette',
        firstName: 'Test',
        age: age,
        canton: canton,
        archetype: 'swiss_native',
        grossMonthlySalary: grossMonthly,
        employmentStatus: 'salarie',
      );

      final answers = seed.toWizardAnswers(now: DateTime(2026));
      final net = answers['q_net_income_period_chf'] as double;

      final canonicalNet = NetIncomeBreakdown.compute(
        grossSalary: grossMonthly * 12,
        canton: canton,
        age: age,
      ).monthlyNetPayslip.roundToDouble();

      expect(net, closeTo(canonicalNet, 0.01),
          reason: 'le seed doit dériver le net du canonique, pas brut×0.78');

      // Régression : le proxy plat brut×0.78 produirait une autre valeur.
      final flatProxy = (grossMonthly * 0.78).roundToDouble();
      expect(net, isNot(closeTo(flatProxy, 0.01)),
          reason: 'ne doit plus utiliser le ratio plat 0.78');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W4 — Plafond 3a indépendant (plan 04)
  //
  //  Oracle matrice independent_no_lpp-1 (WRONG : plafond sur le BRUT) +
  //  independent_no_lpp-2 (DIVERGENT : tax_calculator sur brut vs
  //  independants_service sur net).
  //
  //  UNE base app-wide (OPP3 art. 7 al. 2) : le plafond 3a d'un indépendant
  //  sans LPP = min(20% du revenu professionnel NET, 36288). Plus jamais sur
  //  le brut nu. Référence canonique = IndependantsService.calculate3aIndependant
  //  (déjà sur le net). tax_calculator.estimate3aTaxImpact converge dessus.
  //
  //  Contrôle négatif : un salarié affilié LPP garde le plafond fixe 7258.
  // ════════════════════════════════════════════════════════════════

  group('Parity W4 — Plafond 3a indépendant', () {
    test(
        'independent_no_lpp-1/-2 — net pro 86400 : plafond 17280 sur les deux '
        'moteurs (plus jamais 21600 sur le brut 108000)', () {
      const netPro = 86400.0;
      const brut = 108000.0;
      const canton = 'GE';

      // Moteur fiscal financial_core : base = revenu professionnel NET fourni.
      final fiscalImpact = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: brut,
        canton: canton,
        hasLpp: false,
        netProfessionalIncome: netPro,
      );

      // Moteur de référence (déjà sur le net) : IndependantsService.
      final indepRef = IndependantsService.calculate3aIndependant(
        netPro,
        false, // affilieLpp
        0.30, // tauxMarginal (sans incidence sur le plafond)
      );

      // OPP3 art. 7 al. 2 : 20% du net = 17280 (< 36288, pas de cap).
      expect(fiscalImpact.annualCeiling, closeTo(17280.0, 0.01),
          reason: 'le plafond doit être 20% du NET (86400), pas du brut');
      expect(indepRef.plafond, closeTo(17280.0, 0.01),
          reason: 'référence indépendant déjà sur le net');

      // Parité inter-moteurs (fin de la classe DIVERGENT independent_no_lpp-2).
      expect(fiscalImpact.annualCeiling, closeTo(indepRef.plafond, 0.01),
          reason: 'tax_calculator et independants_service doivent converger');

      // Régression WRONG (independent_no_lpp-1) : le plafond sur le BRUT aurait
      // donné 108000 × 0.20 = 21600 (+25%). Il ne doit JAMAIS réapparaître.
      const brutBasedCeiling = brut * 0.20; // 21600
      expect(fiscalImpact.annualCeiling, isNot(closeTo(brutBasedCeiling, 0.01)),
          reason: 'le plafond ne doit plus être calculé sur le brut');
    });

    test(
        'contrôle négatif — salarié affilié LPP : plafond 7258 inchangé '
        '(salarie_swiss-6 / jeune_diplome-4 / cadre_divorce_hypo-6)', () {
      final impact = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: 108000,
        canton: 'GE',
        hasLpp: true,
      );
      expect(impact.annualCeiling, closeTo(pilier3aPlafondAvecLpp, 0.01),
          reason: 'le plafond avec LPP reste le forfait fixe 7258');
    });

    test(
        'net absent (null) — le plafond sans-LPP dérive du NET, jamais du brut '
        'nu', () {
      const brut = 108000.0;
      const canton = 'GE';
      const age = 45;

      // Aucun netProfessionalIncome fourni → l'engine dérive le net via
      // NetIncomeBreakdown (canton + âge aware), JAMAIS le brut nu.
      final impact = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: brut,
        canton: canton,
        hasLpp: false,
        age: age,
      );

      final derivedNet = NetIncomeBreakdown.compute(
        grossSalary: brut,
        canton: canton,
        age: age,
      ).netPayslip;
      final expectedCeiling =
          (derivedNet * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp);

      expect(impact.annualCeiling, closeTo(expectedCeiling, 0.01),
          reason: 'le plafond doit dériver du NET (NetIncomeBreakdown)');

      // Le net dérivé est strictement inférieur au brut → le plafond aussi.
      const brutBasedCeiling = brut * 0.20; // 21600
      expect(impact.annualCeiling, lessThan(brutBasedCeiling),
          reason: 'NET < BRUT ⇒ plafond NET < plafond brut historique');
    });

    test(
        'minimal_profile — indépendant sans LPP : plafond3a sur le NET dérivé '
        '(fin du brut)', () {
      const age = 45;
      const brut = 108000.0;
      const canton = 'GE';

      final result = MinimalProfileService.compute(
        age: age,
        grossSalary: brut,
        canton: canton,
        employmentStatus: 'independant',
      );

      // Le plafond attendu = 20% du NET dérivé (NetIncomeBreakdown), borné 36288.
      final derivedNet = NetIncomeBreakdown.compute(
        grossSalary: brut,
        canton: canton,
        age: age,
      ).netPayslip;
      final expectedCeiling =
          (derivedNet * pilier3aTauxRevenuSansLpp).clamp(0.0, pilier3aPlafondSansLpp);

      expect(result.plafond3a, closeTo(expectedCeiling, 0.01),
          reason: 'minimal_profile doit calculer le plafond sur le NET');

      // Régression : le proxy plat brut×0.20 (21600) ne doit plus apparaître.
      const brutBasedCeiling = brut * pilier3aTauxRevenuSansLpp; // 21600
      expect(result.plafond3a, isNot(closeTo(brutBasedCeiling, 0.01)),
          reason: 'minimal_profile ne doit plus calculer le plafond sur le brut');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W5 — Économie 3a (barème marié) (plan 05)
  //
  //  Oracle matrice salarie_swiss-2 (ILLOGICAL_FOR_ARCHETYPE : minimal_profile
  //  appelle estimate3aTaxImpact SANS isMarried/children → barème célibataire
  //  appliqué à un marié) + salarie_swiss-3 (DIVERGENT inter-écran : onboarding
  //  ~1405 CHF célibataire vs response_card ~1194 CHF marié pour le même input).
  //
  //  La fonction estimate3aTaxImpact ACCEPTE isMarried/children
  //  (tax_calculator.dart:535) ; le câblage manquant était dans l'appelant
  //  minimal_profile_service. Après le fix : minimal_profile transmet
  //  isMarried (householdType couple/family) + children (0, non disponible dans
  //  les inputs du service) → barème marié appliqué (familyAdjustment
  //  marie_sans_enfant=0.85, tax_calculator.dart:373) → taux marginal et
  //  économie 3a IDENTIQUES au chemin de référence response_card.
  //
  //  Référence canonique = estimate3aTaxImpact(isMarried:, children:) appelée
  //  directement (la même fonction que response_card_service.dart:674-678
  //  invoque via estimateMarginalRate avec l'état civil câblé).
  // ════════════════════════════════════════════════════════════════

  group('Parity W5 — Économie 3a (marié)', () {
    test(
        'salarie_swiss-2 — marié VD 102000 : minimal_profile applique le barème '
        'marié (taux marginal == estimate3aTaxImpact isMarried:true)', () {
      const age = 42;
      const gross = 102000.0;
      const canton = 'VD';

      // Chemin minimal_profile (onboarding) — householdType 'couple' → marié.
      final marie = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'couple',
      );

      // Référence canonique : la fonction financial_core appelée avec l'état
      // civil câblé (même fonction que response_card via estimateMarginalRate).
      final canonicalMarie = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: gross,
        canton: canton,
        hasLpp: true,
        isMarried: true,
        children: 0,
        age: age,
      );

      // Le taux marginal de l'onboarding doit être celui du barème MARIÉ.
      expect(marie.marginalTaxRate, closeTo(canonicalMarie.marginalRate, 0.0001),
          reason: 'minimal_profile doit appliquer le barème marié (0.85), '
              'pas le barème célibataire (1.00)');
      // L'économie 3a affichée doit être celle du barème marié.
      expect(marie.taxSaving3a, closeTo(canonicalMarie.estimatedTaxSaving, 0.01),
          reason: 'l\'économie 3a doit être calculée au barème marié');
    });

    test(
        'salarie_swiss-2 — régression : le barème marié donne un taux/économie '
        'STRICTEMENT inférieur au barème célibataire (fin de la surestimation '
        '+17.6%)', () {
      const age = 42;
      const gross = 102000.0;
      const canton = 'VD';

      final marie = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'couple',
      );
      final celibataire = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'single',
      );

      // familyAdjustment marie_sans_enfant=0.85 < celibataire=1.00 → le marié
      // a un taux marginal et une économie 3a strictement inférieurs.
      expect(marie.marginalTaxRate, lessThan(celibataire.marginalTaxRate),
          reason: 'le marié ne doit plus hériter du barème célibataire');
      expect(marie.taxSaving3a, lessThan(celibataire.taxSaving3a),
          reason: 'fin de la surestimation +17.6% pour un marié');

      // Le ratio des économies suit l'écart de barème (~0.85), pas 1.0.
      // 0.85 est l'ajustement marie_sans_enfant ; on borne large (≤ 0.95)
      // pour absorber le clamp marginal et l'effet sur la déduction.
      expect(marie.taxSaving3a / celibataire.taxSaving3a, lessThan(0.95),
          reason: 'l\'économie mariée doit refléter l\'ajustement familial 0.85');
    });

    test(
        'salarie_swiss-3 — parité inter-écran : onboarding et response_card '
        'produisent la MÊME économie 3a pour un marié (fin de 1405 vs 1194)', () {
      const age = 42;
      const gross = 102000.0;
      const canton = 'VD';

      // Onboarding : barème marié désormais câblé.
      final onboarding = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'couple',
      );

      // Onboarding (estimate3aTaxImpact) expose son taux marginal interne via
      // marginalTaxRate. La divergence structurelle salarie_swiss-3 était :
      // onboarding sur barème CÉLIBATAIRE vs response_card sur barème MARIÉ.
      // Référence des DEUX barèmes au point de revenu de l'onboarding.
      final marginalMarie = RetirementTaxCalculator.estimateMarginalRate(
        gross,
        canton,
        isMarried: true,
        children: 0,
      );
      final marginalCelibataire = RetirementTaxCalculator.estimateMarginalRate(
        gross,
        canton,
        isMarried: false,
        children: 0,
      );

      // L'onboarding suit désormais le barème MARIÉ (proche de marginalMarie,
      // au léger ajustement de revenu près dû à la demi-déduction), et plus du
      // tout le barème célibataire — fin de la divergence inter-écran
      // 1405 (single) vs 1194 (married). Tolérance 0.01 : estimate3aTaxImpact
      // évalue le taux à (gross - déduction/2), response_card au gross plein ;
      // les deux partagent l'ajustement familial 0.85, c'est le point clé.
      expect(onboarding.marginalTaxRate, closeTo(marginalMarie, 0.01),
          reason: 'onboarding doit utiliser le barème marié comme response_card');
      expect((onboarding.marginalTaxRate - marginalMarie).abs(),
          lessThan((onboarding.marginalTaxRate - marginalCelibataire).abs()),
          reason: 'onboarding doit être plus proche du barème marié que du '
              'barème célibataire — fin de la divergence structurelle');
    });

    test(
        'contrôle négatif — un célibataire garde le barème célibataire '
        '(pas de régression)', () {
      const age = 42;
      const gross = 102000.0;
      const canton = 'VD';

      final celibataire = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        householdType: 'single',
      );

      final canonicalCelibataire = RetirementTaxCalculator.estimate3aTaxImpact(
        grossAnnualSalary: gross,
        canton: canton,
        hasLpp: true,
        isMarried: false,
        children: 0,
        age: age,
      );

      // Un single non marié → barème célibataire inchangé (le fix ne touche
      // que le chemin marié, householdType single/null reste isMarried=false).
      expect(celibataire.marginalTaxRate,
          closeTo(canonicalCelibataire.marginalRate, 0.0001),
          reason: 'le célibataire garde le barème célibataire (1.00)');
      expect(celibataire.taxSaving3a,
          closeTo(canonicalCelibataire.estimatedTaxSaving, 0.01),
          reason: 'aucune régression sur le chemin célibataire');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Gates LPP (plan 07)
  //
  //  Oracle matrice §independent_no_lpp-3 + §cadre_divorce_hypo-1 :
  //   (1) un indépendant ne reçoit JAMAIS d'avoir LPP ESTIMÉ — même s'il
  //       répond « oui » à q_has_pension_fund (gate non-équivalent fermé) ;
  //       seule une valeur réelle saisie compte. Les deux moteurs (coach +
  //       minimal) consomment le MÊME prédicat ArchetypePredicates.
  //   (2) un divorcé ne reçoit JAMAIS d'avoir LPP estimé par âge×salaire
  //       (CC art. 122 / LFLP art. 22a : partage path-dependent) — fallback
  //       « valeur réelle requise » + confiance dégradée, plus jamais 416k.
  // ════════════════════════════════════════════════════════════════

  group('Gates LPP — predicat unifie (plan 07)', () {
    /// Réponses wizard pour un indépendant qui répond « oui » à la question
    /// caisse (le scénario exact du gate non-équivalent independent_no_lpp-3).
    Map<String, dynamic> independantAnswers({
      required int age,
      required double grossAnnual,
      required bool hasPensionFund,
      double? coachAvoirLppReel,
    }) {
      final birthYear = DateTime.now().year - age;
      return <String, dynamic>{
        'q_birth_year': birthYear,
        'q_canton': 'GE',
        'q_employment_status': 'independant',
        'q_pay_frequency': 'yearly',
        'q_gross_salary_annual': grossAnnual,
        'q_has_pension_fund': hasPensionFund,
        if (coachAvoirLppReel != null) '_coach_avoir_lpp': coachAvoirLppReel,
      };
    }

    test(
        'independent_no_lpp-3 — independant + q_has_pension_fund=true : '
        'avoir ESTIME == 0 (plus jamais ~95k), coach ET minimal alignes', () {
      const age = 39;
      const gross = 108000.0; // 9000/mo — l'input historique du gate fantome

      // Coach : meme avec hasPensionFund=true, l'ESTIMATION est interdite pour
      // un independant — seule une valeur reelle compterait.
      final coach = _coachAvoir(independantAnswers(
        age: age,
        grossAnnual: gross,
        hasPensionFund: true,
      ));

      // Minimal : gate deja sur employmentStatus=='independant'.
      final minimal = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: 'GE',
        employmentStatus: 'independant',
      ).existingLpp;

      expect(coach, closeTo(0.0, 0.01),
          reason: 'coach attribuait ~95249 CHF de LPP fantome a un '
              'independant (gate q_has_pension_fund non-equivalent)');
      expect(minimal, closeTo(0.0, 0.01),
          reason: 'minimal doit rester a 0 pour un independant');
      expect(coach, closeTo(minimal, 0.01),
          reason: 'coach et minimal doivent donner le MEME verdict LPP=0');
    });

    test(
        'independant declarant une caisse AVEC valeur reelle saisie : '
        'la valeur reelle est conservee (le gate bloque l\'ESTIMATION, '
        'pas la donnee reelle)', () {
      const age = 45;
      const gross = 120000.0;
      const valeurReelle = 84000.0;

      final coach = _coachAvoir(independantAnswers(
        age: age,
        grossAnnual: gross,
        hasPensionFund: true,
        coachAvoirLppReel: valeurReelle,
      ));

      expect(coach, closeTo(valeurReelle, 0.01),
          reason: 'une valeur reelle saisie/scannee doit etre conservee '
              'meme pour un independant');
    });

    test(
        'controle negatif — salarie avec LPP : estimation inchangee '
        '(pas de regression W1)', () {
      const age = 42;
      const gross = 102000.0;

      final coach = _coachAvoir(_salariedAnswers(age: age, grossAnnual: gross));
      final canonical = LppCalculator.accumulateAvoir(
        currentAge: age,
        grossAnnualSalary: gross,
      );

      expect(coach, closeTo(canonical, 0.01),
          reason: 'le salarie doit garder son estimation canonique '
              '(le gate independant ne doit pas le toucher)');
      expect(canonical, greaterThan(0.0),
          reason: 'sanity : un salarie de 42 ans a un avoir LPP non nul');
    });
  });

  group('Gate divorce — estimation LPP interdite (plan 07)', () {
    /// Réponses wizard pour un cadre salarié, état civil paramétrable.
    Map<String, dynamic> salariedCivilAnswers({
      required int age,
      required double grossAnnual,
      required String civilStatus,
      double? coachAvoirLppReel,
    }) {
      final birthYear = DateTime.now().year - age;
      return <String, dynamic>{
        'q_birth_year': birthYear,
        'q_canton': 'VD',
        'q_employment_status': 'salarie',
        'q_civil_status': civilStatus,
        'q_pay_frequency': 'yearly',
        'q_gross_salary_annual': grossAnnual,
        'q_has_pension_fund': true,
        if (coachAvoirLppReel != null) '_coach_avoir_lpp': coachAvoirLppReel,
      };
    }

    test(
        'cadre_divorce_hypo-1 — divorce 52/162000 sans valeur reelle : '
        'avoir LPP estime ABSENT (plus jamais 416250.42)', () {
      final profile = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'divorce',
      ));

      // L'estimation age*salaire est interdite (CC art. 122) → aucun avoir
      // estime stocke. avoirLppTotal null/0 + flag inestimable.
      expect(profile.prevoyance.avoirLppTotal ?? 0.0, closeTo(0.0, 0.01),
          reason: 'un divorce ne doit JAMAIS recevoir un avoir LPP estime '
              'par age*salaire (416250.42 historique)');
      expect(profile.prevoyance.lppEstimationBlocked, isTrue,
          reason: 'l\'etat « valeur reelle requise » doit etre expose a l\'UI');
    });

    test(
        'divorce AVEC valeur reelle saisie : valeur conservee, '
        'pas de blocage', () {
      const valeurReelle = 240000.0;
      final profile = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'divorce',
        coachAvoirLppReel: valeurReelle,
      ));

      expect(profile.prevoyance.avoirLppTotal, closeTo(valeurReelle, 0.01),
          reason: 'la valeur reelle saisie/scannee d\'un divorce est conservee');
      expect(profile.prevoyance.lppEstimationBlocked, isFalse,
          reason: 'avec une valeur reelle il n\'y a plus de blocage');
    });

    test(
        'controle negatif — un marie garde son estimation LPP '
        '(le gate ne touche que le divorce)', () {
      final divorce = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'divorce',
      ));
      final marie = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'marie',
      ));

      final canonical = LppCalculator.accumulateAvoir(
        currentAge: 52,
        grossAnnualSalary: 162000,
      );

      expect(marie.prevoyance.avoirLppTotal, closeTo(canonical, 0.01),
          reason: 'un marie/celibataire garde l\'estimation canonique');
      expect(marie.prevoyance.lppEstimationBlocked, isFalse);
      // Le divorce, lui, n'a pas d'estimation.
      expect(divorce.prevoyance.avoirLppTotal ?? 0.0, closeTo(0.0, 0.01));
    });

    test(
        'confiance degradee — le divorce sans valeur reelle a une '
        'completeness LPP < celle d\'un marie estime', () {
      final divorce = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'divorce',
      ));
      final marie = CoachProfile.fromWizardAnswers(salariedCivilAnswers(
        age: 52,
        grossAnnual: 162000,
        civilStatus: 'marie',
      ));

      final divorceScore = ConfidenceScorer.score(divorce).score;
      final marieScore = ConfidenceScorer.score(marie).score;

      expect(divorceScore, lessThan(marieScore),
          reason: 'le divorce sans valeur reelle (estimation interdite) a une '
              'confiance plus basse — l\'axe completeness se degrade');
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Parity W6 — Éligibilité 3a archétype-aware (plan 08)
  //
  //  Oracles matrice expat_us-2 (ILLOGICAL_FOR_ARCHETYPE : minimal_profile
  //  émet plafond 7258 pour un US person alors que canContribute3a==false) +
  //  frontalier-1 (canContribute3a accorde la déduction à TOUT frontalier
  //  salarié, sans test quasi-résident — contredit le hub segments_service).
  //
  //  Fix : MinimalProfileService.compute() gagne un paramètre canContribute3a
  //  (default true) ; quand false → plafond3a et taxSaving3a = 0. Le prédicat
  //  partagé ArchetypePredicates.canContribute3a est la source of truth unique
  //  (consommée par compute() ET coach_profile.canContribute3a) — fin de la
  //  divergence inter-chemin (CLAUDE.md NEVER #3). Cross-border déductible
  //  uniquement si quasi-résident GE (même prédicat que segments_service).
  // ════════════════════════════════════════════════════════════════

  group('Parity W6 — Éligibilité 3a (FATCA / frontalier)', () {
    test(
        'expat_us-2 — compute() canContribute3a:false : plafond3a==0 ET '
        'taxSaving3a==0 (plus jamais 7258 pour un US person)', () {
      const age = 42;
      const gross = 120000.0;
      const canton = 'GE';

      final usPerson = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
        canContribute3a: false,
      );

      expect(usPerson.plafond3a, 0.0,
          reason: 'un US person ne peut pas déduire en 3a (FATCA) → plafond 0');
      expect(usPerson.taxSaving3a, 0.0,
          reason: 'aucune économie d\'impôt 3a pour un US person');
      expect(usPerson.marginalTaxRate, 0.0,
          reason: 'pas de taux marginal 3a actionnable pour un US person');

      // Régression WRONG : le forfait avec-LPP 7258 ne doit JAMAIS réapparaître.
      expect(usPerson.plafond3a, isNot(closeTo(pilier3aPlafondAvecLpp, 0.01)),
          reason: 'le plafond 7258 ne doit plus être émis pour un expatUs');
    });

    test(
        'contrôle négatif salarie_swiss-6 — compute() défaut (canContribute3a '
        'true) : plafond 7258 inchangé pour un salarié affilié LPP', () {
      const age = 42;
      const gross = 102000.0;
      const canton = 'VD';

      final salarie = MinimalProfileService.compute(
        age: age,
        grossSalary: gross,
        canton: canton,
        employmentStatus: 'salarie',
      );

      expect(salarie.plafond3a, closeTo(pilier3aPlafondAvecLpp, 0.01),
          reason: 'le salarié affilié LPP garde le forfait fixe 7258 (OPP3 '
              'art. 7 al. 1) — le gate FATCA ne doit pas régresser ce profil');
      expect(salarie.taxSaving3a, greaterThan(0.0),
          reason: 'le salarié standard garde une économie 3a non nulle');
    });

    test(
        'expat_us-2 — coach_profile.canContribute3a == false pour un expatUs',
        () {
      final usPerson = CoachProfile.defaults().copyWith(
        usTaxPerson: true,
        nationality: 'US',
        canton: 'GE',
        salaireBrutMensuel: 10000,
        nombreDeMois: 12,
      );
      expect(usPerson.archetype, FinancialArchetype.expatUs,
          reason: 'fixture sanity: usTaxPerson=true → expatUs');
      expect(usPerson.canContribute3a, isFalse,
          reason: 'un US person ne peut pas contribuer en 3a déductible (FATCA)');
    });

    test(
        'frontalier-1 — coach_profile.canContribute3a == false pour un '
        'frontalier NON quasi-résident (permis G hors GE)', () {
      final frontalierVd = CoachProfile.defaults().copyWith(
        residencePermit: 'G',
        canton: 'VD', // hors GE → pas de statut quasi-résident
        nationality: 'FR',
        salaireBrutMensuel: 7000,
        nombreDeMois: 12,
      );
      expect(frontalierVd.archetype, FinancialArchetype.crossBorder,
          reason: 'fixture sanity: permis G → crossBorder');
      expect(frontalierVd.isCrossBorder, isTrue);
      expect(frontalierVd.revenuBrutAnnuel, greaterThan(0.0));
      expect(frontalierVd.canContribute3a, isFalse,
          reason: 'frontalier hors GE : pas de déduction 3a en Suisse '
              '(imposé à la source — aligné sur segments_service)');
    });

    test(
        'frontalier-1 — coach_profile.canContribute3a == true pour un '
        'frontalier GE quasi-résident (comportement déductible conservé)', () {
      final frontalierGe = CoachProfile.defaults().copyWith(
        residencePermit: 'G',
        canton: 'GE', // quasi-résident possible (LIPP GE art. 6)
        nationality: 'FR',
        salaireBrutMensuel: 7000,
        nombreDeMois: 12,
      );
      expect(frontalierGe.archetype, FinancialArchetype.crossBorder);
      expect(frontalierGe.canContribute3a, isTrue,
          reason: 'frontalier GE quasi-résident : déduction 3a conservée');
    });

    test(
        'prédicat partagé ArchetypePredicates.canContribute3a — source of '
        'truth unique (expat_us-2 + frontalier-1)', () {
      // US person → false quel que soit le canton.
      expect(
        ArchetypePredicates.canContribute3a(
          isUsPerson: true,
          isCrossBorder: false,
          workCanton: 'GE',
          grossAnnualIncome: 120000,
          prevoyanceFallback: true,
        ),
        isFalse,
        reason: 'US person bloqué (FATCA)',
      );
      // Frontalier hors GE → false même avec revenu.
      expect(
        ArchetypePredicates.canContribute3a(
          isUsPerson: false,
          isCrossBorder: true,
          workCanton: 'VD',
          grossAnnualIncome: 84000,
          prevoyanceFallback: true,
        ),
        isFalse,
        reason: 'frontalier non-GE : pas de déduction',
      );
      // Frontalier GE avec revenu → true.
      expect(
        ArchetypePredicates.canContribute3a(
          isUsPerson: false,
          isCrossBorder: true,
          workCanton: 'GE',
          grossAnnualIncome: 84000,
          prevoyanceFallback: false,
        ),
        isTrue,
        reason: 'frontalier GE quasi-résident : déductible',
      );
      // Frontalier GE sans revenu → false (rien à déduire).
      expect(
        ArchetypePredicates.canContribute3a(
          isUsPerson: false,
          isCrossBorder: true,
          workCanton: 'GE',
          grossAnnualIncome: 0,
          prevoyanceFallback: true,
        ),
        isFalse,
        reason: 'aucun revenu suisse → rien à déduire',
      );
      // Non-frontalier non-US → délègue au fallback prévoyance.
      expect(
        ArchetypePredicates.canContribute3a(
          isUsPerson: false,
          isCrossBorder: false,
          workCanton: 'ZH',
          grossAnnualIncome: 102000,
          prevoyanceFallback: true,
        ),
        isTrue,
        reason: 'salarié suisse : délègue au fallback (true)',
      );
    });
  });
}
