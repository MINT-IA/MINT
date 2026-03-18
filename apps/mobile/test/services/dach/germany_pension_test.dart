import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/dach/germany_pension.dart';
import 'package:mint_mobile/services/dach/country_pension_service.dart';

void main() {
  // ── Constants (SGB VI, EStG 2025/2026) ──────────────────────────

  group('GermanyPension — constants', () {
    test('retirement age is 67 (SGB VI § 35, born after 1964)', () {
      expect(GermanyPension.retirementAge, 67);
    });

    test('early retirement age is 63 (SGB VI § 36)', () {
      expect(GermanyPension.earlyRetirementAge, 63);
    });

    test('Beitragsbemessungsgrenze is 90600 EUR/year (West, 2025)', () {
      expect(GermanyPension.beitragsbemessungsgrenze, 90600);
    });

    test('Beitragssatz is 18.6% (total)', () {
      expect(GermanyPension.beitragssatz, 18.6);
    });

    test('Riester max is 2100 EUR (EStG § 10a)', () {
      expect(GermanyPension.riesterMaxBeitrag, 2100);
    });

    test('Riester Grundzulage is 175 EUR (EStG § 84)', () {
      expect(GermanyPension.riesterGrundzulage, 175);
    });

    test('Riester Kinderzulage is 300 EUR (EStG § 85, born after 2008)', () {
      expect(GermanyPension.riesterKinderzulage, 300);
    });

    test('Ruerup max single is 27566 EUR (EStG § 10 Abs. 3)', () {
      expect(GermanyPension.ruerupMaxAbzug, 27566);
    });

    test('Ruerup max married is double single (55132 EUR)', () {
      expect(GermanyPension.ruerupMaxAbzugMarried, 55132);
      expect(GermanyPension.ruerupMaxAbzugMarried,
          GermanyPension.ruerupMaxAbzug * 2);
    });

    test('bAV Steuerfreimax is 7248 EUR (8% of BBG)', () {
      expect(GermanyPension.bavSteuerfreiMax, 7248);
    });
  });

  // ── Pillar definitions ──────────────────────────────────────────

  group('GermanyPension — pillars', () {
    test('has exactly 4 pillars (GRV, bAV, Riester, Ruerup)', () {
      expect(GermanyPension.pillars.length, 4);
    });

    test('pillar 1 is GRV (Gesetzliche Rentenversicherung)', () {
      expect(GermanyPension.grv.number, 1);
      expect(GermanyPension.grv.name, 'GRV');
      expect(GermanyPension.grv.legalReference, 'SGB VI');
    });

    test('pillar 2 is bAV (Betriebliche Altersvorsorge)', () {
      expect(GermanyPension.bav.number, 2);
      expect(GermanyPension.bav.name, 'bAV');
      expect(GermanyPension.bav.legalReference, 'BetrAVG');
    });

    test('pillar 3 Riester has max contribution 2100 EUR', () {
      expect(GermanyPension.riester.number, 3);
      expect(GermanyPension.riester.name, 'Riester');
      expect(GermanyPension.riester.maxContribution, 2100);
      expect(GermanyPension.riester.legalReference, contains('EStG'));
    });

    test('pillar 3 Ruerup has max contribution 27566 EUR', () {
      expect(GermanyPension.ruerup.number, 3);
      expect(GermanyPension.ruerup.name, 'Rürup');
      expect(GermanyPension.ruerup.maxContribution, 27566);
    });

    test('both Riester and Ruerup are pillar 3', () {
      expect(GermanyPension.riester.number, 3);
      expect(GermanyPension.ruerup.number, 3);
    });
  });

  // ── System definition ──────────────────────────────────────────

  group('GermanyPension — system', () {
    test('country is germany', () {
      expect(GermanyPension.system.country, DachCountry.germany);
    });

    test('currency is EUR', () {
      expect(GermanyPension.system.currencyCode, 'EUR');
    });

    test('tax system is EStG', () {
      expect(GermanyPension.system.taxSystem, 'EStG');
    });

    test('retirement age is 67', () {
      expect(GermanyPension.system.retirementAge, 67);
    });

    test('early retirement age is 63', () {
      expect(GermanyPension.system.earlyRetirementAge, 63);
    });

    test('disclaimer mentions educatif and specialiste', () {
      expect(GermanyPension.system.disclaimer, contains('éducatif'));
      expect(GermanyPension.system.disclaimer, contains('spécialiste'));
    });

    test('system includes all 4 pillars', () {
      expect(GermanyPension.system.pillars.length, 4);
    });
  });

  // ── Cross-checks with CountryPensionService ─────────────────────

  group('GermanyPension — CountryPensionService integration', () {
    test('getSystem(germany) returns GermanyPension.system', () {
      final system = CountryPensionService.getSystem(DachCountry.germany);
      expect(system.country, DachCountry.germany);
      expect(system.retirementAge, 67);
      expect(system.pillars.length, 4);
    });

    test('compare CH→DE includes Riester/Ruerup difference', () {
      final comparison = CountryPensionService.compare(
        DachCountry.switzerland,
        DachCountry.germany,
      );
      expect(
        comparison.differences.any((d) => d.description.contains('Riester')),
        isTrue,
      );
    });

    test('compare DE→CH has correct retirement ages', () {
      final comparison = CountryPensionService.compare(
        DachCountry.germany,
        DachCountry.switzerland,
      );
      final ageDiff = comparison.differences
          .firstWhere((d) => d.category == 'Âge de la retraite');
      expect(ageDiff.fromValue, '67 ans');
      expect(ageDiff.toValue, '65 ans');
    });

    test('compare DE→DE same currency, no currency difference', () {
      final comparison = CountryPensionService.compare(
        DachCountry.germany,
        DachCountry.germany,
      );
      final hasCurrencyDiff = comparison.differences
          .any((d) => d.category == 'Devise');
      expect(hasCurrencyDiff, isFalse);
    });
  });

  // ── Edge cases ──────────────────────────────────────────────────

  group('GermanyPension — edge cases', () {
    test('bAV steuerfreimax is approximately 8% of BBG', () {
      // 8% of 90600 = 7248
      final expected = GermanyPension.beitragsbemessungsgrenze * 0.08;
      expect(GermanyPension.bavSteuerfreiMax, expected);
    });

    test('all pillars have legal references', () {
      for (final pillar in GermanyPension.pillars) {
        expect(pillar.legalReference, isNotNull,
            reason: 'Pillar ${pillar.name} missing legal reference');
        expect(pillar.legalReference, isNotEmpty);
      }
    });

    test('all pillars have descriptions in French', () {
      for (final pillar in GermanyPension.pillars) {
        expect(pillar.description, isNotEmpty,
            reason: 'Pillar ${pillar.name} missing description');
      }
    });
  });
}
