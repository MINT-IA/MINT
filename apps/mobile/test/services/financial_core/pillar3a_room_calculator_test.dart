import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/pillar3a_room_calculator.dart';

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

    test(
        'independent without LPP uses dedicated professional net income when known',
        () {
      final profile = _profile(
        employmentStatus: 'independant',
        salaireBrutMensuel: 9000,
        explicitMonthlyNetIncome: 7200,
        independentNetProfessionalIncomeAnnual: 86400,
      );

      expect(
        Pillar3aRoomCalculator.annualCeiling(
          profile,
          archetype: FinancialArchetype.independentNoLpp,
        ),
        17280,
      );
    });

    test(
        'independent without LPP does not use household budget net as OPP3 base',
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

    // ── Codex P1 gap closure — eligibility gate (FATCA) ──────────────
    //
    // Before this fix annualCeiling() ignored eligibility and returned the
    // statutory 7258 CHF for every non-independentNoLpp archetype, INCLUDING
    // expatUs. US persons cannot contribute to 3a (FATCA — Swiss providers
    // refuse them; CLAUDE.md NEVER #7), so the deductible room must be 0.
    group('eligibility gate (expatUs / FATCA — Codex P1)', () {
      test('expatUs annual ceiling is 0 (cannot contribute 3a)', () {
        final profile = _profile(usTaxPerson: true, nationality: 'US');
        expect(profile.archetype, FinancialArchetype.expatUs,
            reason: 'fixture sanity: usTaxPerson=true → expatUs');
        expect(profile.canContribute3a, isFalse,
            reason: 'FATCA: US persons cannot contribute to 3a');

        expect(Pillar3aRoomCalculator.annualCeiling(profile), 0.0,
            reason: 'a US person has no deductible 3a room (FATCA gate)');
      });

      test('expatUs remaining room is 0', () {
        final profile = _profile(
          usTaxPerson: true,
          nationality: 'US',
          plannedContributions: const [
            PlannedMonthlyContribution(
              id: '3a_monthly',
              label: '3a mensuel',
              amount: 250,
              category: '3a',
            ),
          ],
        );

        expect(Pillar3aRoomCalculator.remainingAnnualRoom(profile), 0.0,
            reason: 'remaining room flows through the gated ceiling');
      });

      test('swissNative ceiling unaffected (no regression)', () {
        final profile = _profile(nationality: 'CH');
        expect(profile.canContribute3a, isTrue);
        expect(
          Pillar3aRoomCalculator.annualCeiling(profile),
          pilier3aPlafondAvecLpp,
        );
      });
    });
  });
}
