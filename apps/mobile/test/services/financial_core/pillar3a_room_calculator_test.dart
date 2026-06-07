import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/pillar3a_room_calculator.dart';

CoachProfile _profile({
  String employmentStatus = 'salarie',
  double salaireBrutMensuel = 8000,
  double? explicitMonthlyNetIncome,
  List<PlannedMonthlyContribution> plannedContributions = const [],
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    salaireBrutMensuel: salaireBrutMensuel,
    explicitMonthlyNetIncome: explicitMonthlyNetIncome,
    nombreDeMois: 12,
    employmentStatus: employmentStatus,
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
  group('Pillar3aRoomCalculator', () {
    test('salaried ceiling uses statutory 3a limit', () {
      final profile = _profile();

      expect(
        Pillar3aRoomCalculator.annualCeiling(profile),
        pilier3aPlafondAvecLpp,
      );
    });

    test('remaining room subtracts annual planned 3a contributions', () {
      final profile = _profile(
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_monthly',
            label: '3a mensuel',
            amount: 250,
            category: '3a',
          ),
        ],
      );

      expect(Pillar3aRoomCalculator.remainingAnnualRoom(profile), 4258);
    });

    test('remaining room is clamped to zero when plan fills the ceiling', () {
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

      expect(Pillar3aRoomCalculator.remainingAnnualRoom(profile), 0);
    });

    test('independent without LPP ceiling is income-based and capped', () {
      final profile = _profile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 8000,
      );

      expect(
        Pillar3aRoomCalculator.annualCeiling(
          profile,
          archetype: FinancialArchetype.independentNoLpp,
        ),
        19200,
      );
    });

    test('independent without LPP does not use household budget net as OPP3 base',
        () {
      final profile = _profile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 9000,
        explicitMonthlyNetIncome: 7200,
      );

      expect(
        Pillar3aRoomCalculator.annualCeiling(
          profile,
          archetype: FinancialArchetype.independentNoLpp,
        ),
        21600,
      );
    });

    test('independent without LPP keeps gross fallback when budget net is zero',
        () {
      final profile = _profile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 8000,
        explicitMonthlyNetIncome: 0,
      );

      expect(
        Pillar3aRoomCalculator.annualCeiling(
          profile,
          archetype: FinancialArchetype.independentNoLpp,
        ),
        19200,
      );
    });
  });
}
