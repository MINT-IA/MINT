import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/income_converter.dart';

void main() {
  group('IncomeConverter.netMonthlyToGrossAnnual', () {
    test('salaried factor applied: 7600 net → 106 704 brut annuel', () {
      final gross = IncomeConverter.netMonthlyToGrossAnnual(7600);
      expect(gross, closeTo(7600 * 12 * 1.17, 0.01));
      expect(gross, closeTo(106704, 0.01));
    });

    test('self-employed factor applied: 6000 net → 79 200 brut annuel', () {
      final gross = IncomeConverter.netMonthlyToGrossAnnual(
        6000,
        isSalaried: false,
      );
      expect(gross, closeTo(6000 * 12 * 1.10, 0.01));
      expect(gross, closeTo(79200, 0.01));
    });

    test('zero net yields zero brut', () {
      expect(IncomeConverter.netMonthlyToGrossAnnual(0), equals(0));
    });
  });

  group('IncomeConverter.netMonthlyRangeToGrossAnnual', () {
    test('propagates range preserving order low < high', () {
      final range = IncomeConverter.netMonthlyRangeToGrossAnnual(
        (low: 7500, high: 8000),
      );
      expect(range.lowGrossAnnual, closeTo(7500 * 12 * 1.17, 0.01));
      expect(range.highGrossAnnual, closeTo(8000 * 12 * 1.17, 0.01));
      expect(range.lowGrossAnnual, lessThan(range.highGrossAnnual));
    });

    test('self-employed range uses 1.10 factor', () {
      final range = IncomeConverter.netMonthlyRangeToGrossAnnual(
        (low: 5000, high: 6000),
        isSalaried: false,
      );
      expect(range.lowGrossAnnual, closeTo(5000 * 12 * 1.10, 0.01));
      expect(range.highGrossAnnual, closeTo(6000 * 12 * 1.10, 0.01));
    });
  });

  group('IncomeConverter.factorFor', () {
    test('exposes salaried factor 1.17 and self-employed 1.10', () {
      expect(IncomeConverter.factorFor(isSalaried: true), closeTo(1.17, 0.001));
      expect(IncomeConverter.factorFor(isSalaried: false), closeTo(1.10, 0.001));
    });
  });

  // SALVAGE-01-03 (onb-02): single-source the net→gross factor.
  // The persisted-profile estimator (CoachProfile.fromWizardAnswers) must
  // derive its net→gross fallback from THIS converter, not a divergent
  // hardcoded socialChargesRate=0.13 (which yielded ~1.149, contradicting
  // the onboarding hero figure of 1.17).
  group('IncomeConverter single-source parity (onb-02)', () {
    test('main-user persisted estimator uses the SAME salaried factor as the '
        'onboarding hero (1.17), not the legacy 0.13/1.149 divergence', () {
      // Main-user fallback (no q_gross_salary_annual): a salaried profile with
      // 5000 net monthly → gross monthly via the canonical factor.
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'salarie',
      });
      // Persisted estimator must equal net * IncomeConverter.factorFor.
      final expectedGrossMonthly =
          5000 * IncomeConverter.factorFor(isSalaried: true);
      expect(profile.salaireBrutMensuel, closeTo(expectedGrossMonthly, 0.01));
      // And it must NOT equal the legacy 0.13-derived value (5000/0.87≈5747).
      const legacyGrossMonthly = 5000 / (1 - 0.13);
      expect(
        (profile.salaireBrutMensuel - legacyGrossMonthly).abs(),
        greaterThan(1.0),
        reason: 'estimator must no longer use the 0.13 socialChargesRate',
      );
    });

    test('self-employed main-user fallback uses the independant factor (1.10)',
        () {
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'independant',
      });
      final expectedGrossMonthly =
          5000 * IncomeConverter.factorFor(isSalaried: false);
      expect(profile.salaireBrutMensuel, closeTo(expectedGrossMonthly, 0.01));
    });

    test('partner (conjoint) net→gross derives via IncomeConverter, not 0.13',
        () {
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'salarie',
        'q_partner_net_income_chf': 4000,
        'q_partner_employment_status': 'salarie',
      });
      final conjoint = profile.conjoint;
      expect(conjoint, isNotNull);
      final partnerGross = conjoint!.salaireBrutMensuel;
      expect(partnerGross, isNotNull);
      final expectedPartnerGrossMonthly =
          4000 * IncomeConverter.factorFor(isSalaried: true);
      expect(partnerGross, closeTo(expectedPartnerGrossMonthly, 0.01));
      const legacyPartnerGross = 4000 / (1 - 0.13);
      expect(
        (partnerGross! - legacyPartnerGross).abs(),
        greaterThan(1.0),
        reason: 'partner path must no longer use the 0.13 socialChargesRate',
      );
    });

    test('direct gross (q_gross_salary_annual) short-circuit is preserved', () {
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'salarie',
        'q_gross_salary_annual': 120000,
      });
      // Direct gross stored → no net→gross roundtrip; 120000/12 = 10000.
      expect(profile.salaireBrutMensuel, closeTo(10000, 0.01));
    });
  });
}
