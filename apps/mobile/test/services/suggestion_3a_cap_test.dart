import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';

/// W4 — D10 closure : la suggestion mensuelle « tu pourrais verser X CHF en 3a »
/// est désormais plafonnée au plafond légal annuel RESTANT (canonique du plan 04,
/// `Pillar3aRoomCalculator.remainingAnnualRoom`), pro-raté sur les mois restants
/// de l'année civile — jamais la marge libre nue.
///
/// Reproduction device D10 : marge libre 1541/mois (Marc) suggérée telle quelle
/// → ×12 ≈ 2.55× le plafond 7258. Ce test verrouille le clamp.
CoachProfile _profile({
  String employmentStatus = 'salarie',
  double salaireBrutMensuel = 8000,
  double? explicitMonthlyNetIncome,
  double? independentNetProfessionalIncomeAnnual,
  List<PlannedMonthlyContribution> plannedContributions = const [],
  bool usTaxPerson = false,
  String? nationality,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: salaireBrutMensuel,
    explicitMonthlyNetIncome: explicitMonthlyNetIncome,
    independentNetProfessionalIncomeAnnual:
        independentNetProfessionalIncomeAnnual,
    nombreDeMois: 12,
    employmentStatus: employmentStatus,
    usTaxPerson: usTaxPerson,
    nationality: nationality,
    depenses: const DepensesProfile(),
    prevoyance: const PrevoyanceProfile(canContribute3a: true),
    patrimoine: const PatrimoineProfile(),
    dettes: const DetteProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045, 1, 1),
      label: 'Retraite',
    ),
    goalsB: const [],
    plannedContributions: plannedContributions,
    checkIns: const [],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
}

void main() {
  group('BudgetLivingEngine.cappedMonthly3aSuggestion (D10 — W4)', () {
    test(
        'marge libre haute (1541) → suggestion plafonnée au plafond restant/mois '
        '(jamais la marge nue)', () {
      final profile = _profile();

      // Janvier → 12 mois restants ; plafond 7258, déjà versé 0.
      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 1541,
        now: DateTime(2026, 1, 15),
      );

      // 7258 / 12 ≈ 604.83. La D10 device (1541) doit disparaître.
      expect(suggestion, lessThanOrEqualTo(605),
          reason: 'D10 : ×12 doit rester ≤ plafond légal 7258');
      expect(suggestion, isNot(1541),
          reason: 'la marge libre nue ne doit jamais être suggérée');
      expect(suggestion, closeTo(pilier3aPlafondAvecLpp / 12, 0.5));
    });

    test(
        'profil 2 — marge libre 1462 → même clamp (≤ plafond restant/mois)', () {
      final profile = _profile();

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 1462,
        now: DateTime(2026, 1, 15),
      );

      expect(suggestion, lessThanOrEqualTo(605));
      expect(suggestion, isNot(1462));
    });

    test('marge libre BASSE (300) < plafond/mois → la marge gouverne', () {
      final profile = _profile();

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 300,
        now: DateTime(2026, 1, 15),
      );

      // min(300, 604.83) == 300 : on ne suggère jamais plus que la marge.
      expect(suggestion, closeTo(300, 0.01));
    });

    test('plafond déjà atteint (3a complet) → suggestion = 0 (pas de versement)',
        () {
      final profile = _profile(
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_full',
            label: '3a complet',
            amount: 605,
            category: '3a',
          ),
        ],
      );

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 1541,
        now: DateTime(2026, 6, 15),
      );

      expect(suggestion, 0.0,
          reason: 'plafond atteint → 0, pas une suggestion à 0 CHF dissonante');
    });

    test('US person (FATCA, plafond 0) → suggestion = 0, AUCUN versement 3a',
        () {
      final profile = _profile(usTaxPerson: true, nationality: 'US');
      expect(profile.canContribute3a, isFalse,
          reason: 'fixture sanity : US person ne peut pas cotiser 3a');

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 1541,
        now: DateTime(2026, 1, 15),
      );

      expect(suggestion, 0.0,
          reason: 'plafond 0 (plan 08) ⇒ pas de suggestion 3a du tout');
    });

    test(
        'indépendant sans LPP → clamp sur SON plafond (net×0.20), pas 7258', () {
      // Net pro 86400 → plafond 17280 (plan 04). 17280/12 = 1440.
      final profile = _profile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 9000,
        explicitMonthlyNetIncome: 7200,
        independentNetProfessionalIncomeAnnual: 86400,
      );

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 5000,
        archetype: FinancialArchetype.independentNoLpp,
        now: DateTime(2026, 1, 15),
      );

      // Doit suivre 17280/12 = 1440, PAS 7258/12 ≈ 604.83.
      expect(suggestion, closeTo(17280 / 12, 0.5));
      expect(suggestion, greaterThan(pilier3aPlafondAvecLpp / 12),
          reason: 'le plafond indépendant est plus haut que le forfait LPP');
    });

    test('décembre — 1 mois restant → tout le plafond restant tient en 1 mois',
        () {
      final profile = _profile();

      // Décembre → 1 mois restant. Plafond restant 7258 (déjà versé 0) /1.
      // Marge 1541 < 7258 ⇒ la marge gouverne (on ne peut pas verser plus
      // que ce qu'on a), mais le clamp ne réduit PAS sous la marge ici.
      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: 1541,
        now: DateTime(2026, 12, 15),
      );

      expect(suggestion, closeTo(1541, 0.01),
          reason: 'en décembre, le plafond restant /1 mois >> marge → '
              'la marge gouverne (et reste légale : un seul versement ≤ plafond)');
    });

    test('marge négative (déficit) → 0 (rien à suggérer)', () {
      final profile = _profile();

      final suggestion = BudgetLivingEngine.cappedMonthly3aSuggestion(
        profile,
        availableMonthlyMargin: -200,
        now: DateTime(2026, 1, 15),
      );

      expect(suggestion, 0.0);
    });
  });
}
