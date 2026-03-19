import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/dach/austria_pension.dart';
import 'package:mint_mobile/services/dach/country_pension_service.dart';

void main() {
  // ── Constants (ASVG 2025/2026) ──────────────────────────────────

  group('AustriaPension — constants', () {
    test('retirement age men is 65 (ASVG § 253)', () {
      expect(AustriaPension.retirementAgeMen, 65);
    });

    test('retirement age women 2025 is 61 (ASVG § 253 transition)', () {
      expect(AustriaPension.retirementAgeWomen2025, 61);
    });

    test('women equality year is 2033', () {
      expect(AustriaPension.womenEqualityYear, 2033);
    });

    test('early retirement age is 62 (ASVG § 253b Korridorpension)', () {
      expect(AustriaPension.earlyRetirementAge, 62);
    });

    test('Hoechstbeitragsgrundlage monthly is 6060 EUR', () {
      expect(AustriaPension.hoechstbeitragsgrundlageMonthly, 6060);
    });

    test('Hoechstbeitragsgrundlage yearly is 84840 EUR (6060 x 14)', () {
      expect(AustriaPension.hoechstbeitragsgrundlageYearly, 84840);
      expect(AustriaPension.hoechstbeitragsgrundlageYearly,
          AustriaPension.hoechstbeitragsgrundlageMonthly * 14);
    });

    test('pension contribution rate is 22.8%', () {
      expect(AustriaPension.pensionsbeitragssatz, 22.8);
    });

    test('Pensionskonto is available online', () {
      expect(AustriaPension.pensionskontoAvailable, isTrue);
    });

    test('Zukunftsvorsorge max is 3066.32 EUR', () {
      expect(AustriaPension.zukunftsvorsorgeMax, 3066.32);
    });
  });

  // ── Pillar definitions ──────────────────────────────────────────

  group('AustriaPension — pillars', () {
    test('has exactly 3 pillars', () {
      expect(AustriaPension.pillars.length, 3);
    });

    test('pillar 1 is PV (Pensionsversicherung)', () {
      expect(AustriaPension.pv.number, 1);
      expect(AustriaPension.pv.name, 'PV');
      expect(AustriaPension.pv.legalReference, 'ASVG');
    });

    test('pillar 2 is Betriebspension', () {
      expect(AustriaPension.betriebspension.number, 2);
      expect(AustriaPension.betriebspension.name, 'Betriebspension');
      expect(AustriaPension.betriebspension.legalReference, 'PKG');
    });

    test('pillar 3 is Zukunftsvorsorge with max contribution', () {
      expect(AustriaPension.zukunftsvorsorge.number, 3);
      expect(AustriaPension.zukunftsvorsorge.maxContribution,
          AustriaPension.zukunftsvorsorgeMax);
      expect(
          AustriaPension.zukunftsvorsorge.legalReference, 'EStG-AT § 108g');
    });

    test('pillars are ordered 1, 2, 3', () {
      expect(AustriaPension.pillars.map((p) => p.number).toList(),
          [1, 2, 3]);
    });
  });

  // ── System definition ──────────────────────────────────────────

  group('AustriaPension — system', () {
    test('country is austria', () {
      expect(AustriaPension.system.country, DachCountry.austria);
    });

    test('currency is EUR', () {
      expect(AustriaPension.system.currencyCode, 'EUR');
    });

    test('tax system is EStG-AT', () {
      expect(AustriaPension.system.taxSystem, 'EStG-AT');
    });

    test('retirement age is 65 (men reference)', () {
      expect(AustriaPension.system.retirementAge, 65);
    });

    test('early retirement age is 62', () {
      expect(AustriaPension.system.earlyRetirementAge, 62);
    });

    test('disclaimer mentions educatif and specialiste', () {
      expect(AustriaPension.system.disclaimer, contains('éducatif'));
      expect(AustriaPension.system.disclaimer, contains('spécialiste'));
    });
  });

  // ── womenRetirementAgeForYear ───────────────────────────────────

  group('AustriaPension — womenRetirementAgeForYear', () {
    test('returns 60 for years <= 2023', () {
      expect(AustriaPension.womenRetirementAgeForYear(2020), 60);
      expect(AustriaPension.womenRetirementAgeForYear(2023), 60);
    });

    test('returns 65 for years >= 2033', () {
      expect(AustriaPension.womenRetirementAgeForYear(2033), 65);
      expect(AustriaPension.womenRetirementAgeForYear(2040), 65);
    });

    test('transitions linearly between 2024-2032', () {
      // 2024: 60 + 0.5 → 61 (ceil)
      expect(AustriaPension.womenRetirementAgeForYear(2024), 61);
      // 2025: 60 + 1.0 → 61
      expect(AustriaPension.womenRetirementAgeForYear(2025), 61);
      // 2026: 60 + 1.5 → 62
      expect(AustriaPension.womenRetirementAgeForYear(2026), 62);
      // 2028: 60 + 2.5 → 63
      expect(AustriaPension.womenRetirementAgeForYear(2028), 63);
      // 2030: 60 + 3.5 → 64
      expect(AustriaPension.womenRetirementAgeForYear(2030), 64);
      // 2032: 60 + 4.5 → 65
      expect(AustriaPension.womenRetirementAgeForYear(2032), 65);
    });

    test('result is always clamped between 60 and 65', () {
      for (int year = 2020; year <= 2040; year++) {
        final age = AustriaPension.womenRetirementAgeForYear(year);
        expect(age, greaterThanOrEqualTo(60),
            reason: 'Year $year: age $age < 60');
        expect(age, lessThanOrEqualTo(65),
            reason: 'Year $year: age $age > 65');
      }
    });

    test('age is monotonically non-decreasing', () {
      int previous = 0;
      for (int year = 2020; year <= 2040; year++) {
        final age = AustriaPension.womenRetirementAgeForYear(year);
        expect(age, greaterThanOrEqualTo(previous),
            reason: 'Year $year: $age < previous $previous');
        previous = age;
      }
    });
  });
}
