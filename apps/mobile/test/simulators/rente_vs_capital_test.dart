import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/rente_vs_capital_calculator.dart';

void main() {
  group('RenteVsCapitalCalculator', () {
    test('Marc: ZH single, 200k+300k, surob 5%, age 65', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 200000,
        avoirSurobligatoire: 300000,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      expect(r.renteAnnuelle, closeTo(28600, 1));
      expect(r.renteMensuelle, closeTo(2383.33, 1));
      // Progressive brackets: 100k*0.065*1.0 + 100k*0.065*1.15 + 300k*0.065*1.30
      // = 6500 + 7475 + 25350 = 39325
      expect(r.impotRetrait, closeTo(39325, 1));
      expect(r.capitalNet, closeTo(460675, 1));

      // Scenarios still follow same structure
      expect(r.scenarios.length, 3);
      expect(r.scenarios['prudent']!.breakEvenAge, isNotNull);
      expect(r.scenarios['central']!.breakEvenAge, isNotNull);
      expect(r.scenarios['optimiste']!.breakEvenAge, isNotNull);
    });

    test('Sophie: VD married, 150k+100k, surob 4.5%, age 64', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 150000,
        avoirSurobligatoire: 100000,
        tauxConversionSurob: 0.045,
        ageRetraite: 64,
        canton: 'VD',
        statutCivil: 'married',
      );

      expect(r.renteAnnuelle, closeTo(14700, 1));
      // Audit 2026-04-18 Q5 : VD = splitting intégral couple → 0.78 (pas 0.85).
      // VD base 0.08 × 0.78 = 0.0624.
      // Progressive : 100k × 0.0624 × 1.0 + 100k × 0.0624 × 1.15 + 50k × 0.0624 × 1.30
      //             = 6240 + 7176 + 4056 = 17'472.
      expect(r.impotRetrait, closeTo(17472, 1));
      expect(r.capitalNet, closeTo(232528, 1));

      expect(r.scenarios['prudent']!.breakEvenAge, isNotNull);
    });

    test('Pierre: GE single, 400k+600k, surob 5.5%, age 65', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 400000,
        avoirSurobligatoire: 600000,
        tauxConversionSurob: 0.055,
        ageRetraite: 65,
        canton: 'GE',
        statutCivil: 'single',
      );

      expect(r.renteAnnuelle, closeTo(60200, 1));
      // GE base 0.075
      // Progressive: 100k*0.075*1.0 + 100k*0.075*1.15 + 300k*0.075*1.30 + 500k*0.075*1.50
      // = 7500 + 8625 + 29250 + 56250 = 101625
      expect(r.impotRetrait, closeTo(101625, 1));
      expect(r.capitalNet, closeTo(898375, 1));

      expect(r.scenarios.length, 3);
    });

    test('Anna: BS married, 80k+20k, surob 4%, age 64', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 80000,
        avoirSurobligatoire: 20000,
        tauxConversionSurob: 0.04,
        ageRetraite: 64,
        canton: 'BS',
        statutCivil: 'married',
      );

      expect(r.renteAnnuelle, closeTo(6240, 1));
      // Audit 2026-04-18 Q5 : BS n'est pas tabulé → fallback 0.82 (pas 0.85).
      // BS base 0.075 × 0.82 = 0.0615.
      // Progressive : 100k × 0.0615 × 1.0 = 6150.
      expect(r.impotRetrait, closeTo(6150, 1));
      expect(r.capitalNet, closeTo(93850, 1));

      expect(r.scenarios['prudent']!.breakEvenAge, isNotNull);
    });

    test('Thomas: LU single, 300k+200k, surob 5.2%, age 65', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 300000,
        avoirSurobligatoire: 200000,
        tauxConversionSurob: 0.052,
        ageRetraite: 65,
        canton: 'LU',
        statutCivil: 'single',
      );

      expect(r.renteAnnuelle, closeTo(30800, 1));
      // LU base 0.055
      // Progressive: 100k*0.055*1.0 + 100k*0.055*1.15 + 300k*0.055*1.30
      // = 5500 + 6325 + 21450 = 33275
      expect(r.impotRetrait, closeTo(33275, 1));
      expect(r.capitalNet, closeTo(466725, 1));

      expect(r.scenarios['central']!.breakEvenAge, isNotNull);
    });

    test('Unsupported canton throws ArgumentError', () {
      expect(
        () => computeRenteVsCapital(
          avoirObligatoire: 100000,
          avoirSurobligatoire: 50000,
          tauxConversionSurob: 0.05,
          ageRetraite: 65,
          canton: 'XX',
          statutCivil: 'single',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Progressive brackets: 100k uses only first bracket', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 100000,
        avoirSurobligatoire: 0,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      // 100k * 0.065 * 1.0 = 6500
      expect(r.impotRetrait, closeTo(6500, 1));
    });

    test('Progressive brackets: 1M+ uses all 5 brackets', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 600000,
        avoirSurobligatoire: 600000,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      // 1.2M total, ZH base 0.065
      // 100k*0.065*1.0 + 100k*0.065*1.15 + 300k*0.065*1.30
      // + 500k*0.065*1.50 + 200k*0.065*1.70
      // = 6500 + 7475 + 25350 + 48750 + 22100 = 110175
      expect(r.impotRetrait, closeTo(110175, 1));
    });

    test('Married discount reduces tax by 15%', () {
      final single = computeRenteVsCapital(
        avoirObligatoire: 200000,
        avoirSurobligatoire: 0,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      final married = computeRenteVsCapital(
        avoirObligatoire: 200000,
        avoirSurobligatoire: 0,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'married',
      );

      // Audit 2026-04-18 Q5 : ZH splitting intégral → 0.73 (pas 0.85).
      expect(married.impotRetrait / single.impotRetrait, closeTo(0.73, 0.02));
    });

    test('All 26 cantons produce results', () {
      const cantons = [
        'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
        'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
        'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
      ];
      for (final canton in cantons) {
        final r = computeRenteVsCapital(
          avoirObligatoire: 200000,
          avoirSurobligatoire: 100000,
          tauxConversionSurob: 0.05,
          ageRetraite: 65,
          canton: canton,
          statutCivil: 'single',
        );
        expect(r.impotRetrait, greaterThan(0),
            reason: '$canton should have a positive tax');
        expect(r.capitalNet, greaterThan(0),
            reason: '$canton should have positive net capital');
      }
    });

    test('Capital time series has correct length', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 200000,
        avoirSurobligatoire: 100000,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      // From age 65 to 100 = 35 years -> 36 data points (including year 0)
      for (final scenario in r.scenarios.values) {
        expect(scenario.capitalTimeSeries.length, equals(36));
        // First value should be capitalNet
        expect(scenario.capitalTimeSeries[0], closeTo(r.capitalNet, 1));
      }
    });
  });
}
