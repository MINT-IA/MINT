import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

void main() {
  group('computeDisabilityGap', () {
    // =========================================================================
    // Phase 1 — Employer coverage (CO art. 324a)
    // =========================================================================

    test('employee gets employer coverage based on canton and seniority', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BE',
        anneesAnciennete: 10,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      // BE (bernoise scale), 10 years -> 17 weeks
      expect(result.phase1DurationWeeks, 17.0);
      expect(result.phase1MonthlyBenefit, 8000.0);
      expect(result.phase1Gap, 0.0);
    });

    test('self-employed gets zero employer coverage', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(result.phase1DurationWeeks, 0.0);
      expect(result.phase1MonthlyBenefit, 0.0);
      expect(result.phase1Gap, 8000.0);
    });

    test('zurich scale gives 8 weeks at year 2 (vs 4 for bernoise)', () {
      final resultZH = computeDisabilityGap(
        revenuMensuelNet: 6000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      final resultBE = computeDisabilityGap(
        revenuMensuelNet: 6000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BE',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      // ZH year 2 -> 8 weeks, BE year 2 -> 4 weeks
      expect(resultZH.phase1DurationWeeks, 8.0);
      expect(resultBE.phase1DurationWeeks, 4.0);
    });

    test('basel scale gives 9 weeks at year 2', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 6000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BS',
        anneesAnciennete: 1,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      expect(result.phase1DurationWeeks, 9.0);
    });

    // =========================================================================
    // Phase 2 — IJM (daily indemnity insurance)
    // =========================================================================

    test('employee with IJM gets 80% coverage for 24 months', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 10000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'GE',
        anneesAnciennete: 3,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      expect(result.phase2DurationMonths, 24.0);
      expect(result.phase2MonthlyBenefit, 8000.0); // 80% of 10000
      expect(result.phase2Gap, 2000.0);
    });

    test('employee without IJM gets zero phase 2', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 10000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'VD',
        anneesAnciennete: 5,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(result.phase2MonthlyBenefit, 0.0);
      expect(result.phase2Gap, 10000.0);
    });

    test('self-employed with IJM gets 80% coverage', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 12000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'ZH',
        anneesAnciennete: 0,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      expect(result.phase2MonthlyBenefit, 9600.0); // 80% of 12000
      expect(result.phase2Gap, 2400.0);
    });

    // =========================================================================
    // Phase 3 — AI rente (LAI art. 28)
    // =========================================================================

    test('100% disability gives full AI rente 2520 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      expect(result.aiRenteMensuelle, aiRenteEntiere);
      expect(result.aiRenteMensuelle, 2520.0);
    });

    test('50% disability gives demi-rente 1260 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 50,
      );
      expect(result.aiRenteMensuelle, aiRenteDemi);
      expect(result.aiRenteMensuelle, 1260.0);
    });

    test('40% disability gives quart-rente 630 CHF', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 40,
      );
      expect(result.aiRenteMensuelle, aiRenteEntiere * 0.25);
      expect(result.aiRenteMensuelle, 630.0);
    });

    test('below 40% disability gives zero AI rente', () {
      // Use the calculator directly to test phase 3 with 39% disability.
      // The screen slider starts at 40, but the calculator should handle <40.
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 39,
      );
      expect(result.aiRenteMensuelle, 0.0);
      expect(result.phase3MonthlyBenefit, 0.0);
      expect(result.phase3Gap, 8000.0);
    });

    // =========================================================================
    // Risk level determination
    // =========================================================================

    test('self-employed without IJM = critical risk', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'ZH',
        anneesAnciennete: 0,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(result.riskLevel, 'critical');
      expect(
        result.alerts,
        contains(contains('CRITIQUE')),
      );
    });

    test('employee without IJM = high risk', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'BE',
        anneesAnciennete: 3,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(result.riskLevel, 'high');
      expect(
        result.alerts,
        contains(contains('HAUT RISQUE')),
      );
    });

    test('employee with IJM and high gap = medium risk', () {
      // With IJM + high income, the long-term AI gap is > 3000 -> medium
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 100,
        lppDisabilityBenefit: 0.0,
      );
      // phase3Gap = 8000 - 2520 = 5480 > 3000 -> medium
      expect(result.riskLevel, 'medium');
    });

    test('well-covered employee = low risk', () {
      // Low income + IJM + high LPP => small gap -> low
      final result = computeDisabilityGap(
        revenuMensuelNet: 4000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 10,
        hasIjmCollective: true,
        degreInvalidite: 100,
        lppDisabilityBenefit: 1500.0,
      );
      // phase3Gap = 4000 - (2520 + 1500) = -20 => capped logically, but gap is negative
      // -20 is not > 3000, so risk = low
      expect(result.riskLevel, 'low');
    });

    // =========================================================================
    // Edge cases
    // =========================================================================

    test('throws ArgumentError for unsupported canton', () {
      expect(
        () => computeDisabilityGap(
          revenuMensuelNet: 8000,
          statutProfessionnel: EmploymentStatusType.employee,
          canton: 'TI',
          anneesAnciennete: 5,
          hasIjmCollective: true,
          degreInvalidite: 100,
        ),
        throwsArgumentError,
      );
    });

    test('zero income returns zero gaps', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 0,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 100,
      );
      expect(result.phase1Gap, 0.0);
      expect(result.phase2Gap, 0.0);
      expect(result.phase3Gap, closeTo(-2520.0, 0.01)); // AI exceeds income
      expect(result.revenuActuel, 0.0);
    });

    // =========================================================================
    // Additional coverage tests
    // =========================================================================

    test('LPP disability benefit adds to phase 3 coverage', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 10000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 100,
        lppDisabilityBenefit: 2000.0,
      );
      expect(result.phase3MonthlyBenefit, 4520.0); // 2520 AI + 2000 LPP
      expect(result.phase3Gap, 5480.0); // 10000 - 4520
      expect(result.lppDisabilityBenefit, 2000.0);
    });

    test('60% disability gives 3/4 rente', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 60,
      );
      expect(result.aiRenteMensuelle, aiRenteEntiere * 0.75);
      expect(result.aiRenteMensuelle, 1890.0);
    });

    test('70% disability gives full rente', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.employee,
        canton: 'ZH',
        anneesAnciennete: 5,
        hasIjmCollective: true,
        degreInvalidite: 70,
      );
      expect(result.aiRenteMensuelle, aiRenteEntiere);
      expect(result.aiRenteMensuelle, 2520.0);
    });

    test('employee with 0 years seniority gets 3 weeks everywhere', () {
      for (final canton in supportedDisabilityCantons) {
        final result = computeDisabilityGap(
          revenuMensuelNet: 5000,
          statutProfessionnel: EmploymentStatusType.employee,
          canton: canton,
          anneesAnciennete: 0,
          hasIjmCollective: true,
          degreInvalidite: 100,
        );
        expect(result.phase1DurationWeeks, 3.0,
            reason: '$canton should give 3 weeks at year 0');
      }
    });

    test('self-employed alerts contain CO art. 324a reference', () {
      final result = computeDisabilityGap(
        revenuMensuelNet: 8000,
        statutProfessionnel: EmploymentStatusType.selfEmployed,
        canton: 'ZH',
        anneesAnciennete: 0,
        hasIjmCollective: false,
        degreInvalidite: 100,
      );
      expect(
        result.alerts,
        contains(contains('CO art. 324a')),
      );
    });
  });
}
