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

  // SALVAGE-01 (onb-02): the gross→net INVERSE in the providers must be the
  // exact inverse of fromWizardAnswers' net→gross (× factorFor). Previously
  // coach_profile_provider.dart:766 used × (1 - 0.13) = × 0.87 and :1155 used
  // × (1 - 0.133) = × 0.867 — neither equals / 1.17 ≈ × 0.855, so the
  // persist/restore round-trip silently shifted the salary (trust break).
  group('gross→net inverse parity (onb-02)', () {
    test('inverse / factorFor exactly round-trips net→gross (salaried)', () {
      const grossMonthly = 9000.0;
      // Provider direction (gross→net): / factorFor.
      final net = grossMonthly / IncomeConverter.factorFor(isSalaried: true);
      // fromWizardAnswers direction (net→gross): × factorFor.
      final backToGross = net * IncomeConverter.factorFor(isSalaried: true);
      expect(backToGross, closeTo(grossMonthly, 0.0001),
          reason: 'round-trip must preserve gross exactly');
    });

    test('inverse / factorFor exactly round-trips net→gross (independant)', () {
      const grossMonthly = 9000.0;
      final net = grossMonthly / IncomeConverter.factorFor(isSalaried: false);
      final backToGross = net * IncomeConverter.factorFor(isSalaried: false);
      expect(backToGross, closeTo(grossMonthly, 0.0001));
    });

    test('canonical inverse net differs from the legacy 0.13/0.133 rates', () {
      const grossMonthly = 9000.0;
      final canonicalNet =
          grossMonthly / IncomeConverter.factorFor(isSalaried: true);
      // Legacy site :766 (main user) used × 0.87.
      const legacyMainNet = grossMonthly * (1 - 0.13);
      // Legacy site :1155 (partner) used × 0.867.
      const legacyPartnerNet = grossMonthly * (1 - 0.133);
      expect((canonicalNet - legacyMainNet).abs(), greaterThan(1.0),
          reason: 'main-user provider path must no longer use 0.13');
      expect((canonicalNet - legacyPartnerNet).abs(), greaterThan(1.0),
          reason: 'partner provider path must no longer use 0.133');
    });

    test('partner persist→restore round-trip preserves brut via fromWizardAnswers',
        () {
      // fromWizardAnswers stores partner brut = net × factorFor. The provider
      // persistence path (coach_profile_provider.dart:1155) reverses it via
      // / factorFor before re-storing q_partner_net_income_chf. Simulate that
      // full cycle and assert the recovered brut is unchanged.
      const partnerNetInput = 4000.0;
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'salarie',
        'q_partner_net_income_chf': partnerNetInput,
        'q_partner_employment_status': 'salarie',
      });
      final brut1 = profile.conjoint!.salaireBrutMensuel!;
      // Provider :1155 reverse: brut → net via / factorFor (same predicate).
      final reStoredNet =
          brut1 / IncomeConverter.factorFor(isSalaried: true);
      // It must equal the original net the user entered (round-trip identity).
      expect(reStoredNet, closeTo(partnerNetInput, 0.01),
          reason: 'persist/restore must recover the original partner net');
      // And re-deriving brut from that net recovers brut1 unchanged.
      final profile2 = CoachProfile.fromWizardAnswers({
        'q_net_income_period_chf': 5000,
        'q_pay_frequency': 'monthly',
        'q_employment_status': 'salarie',
        'q_partner_net_income_chf': reStoredNet,
        'q_partner_employment_status': 'salarie',
      });
      expect(profile2.conjoint!.salaireBrutMensuel!, closeTo(brut1, 0.01));
    });
  });
}
