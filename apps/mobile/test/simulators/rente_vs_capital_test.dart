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
      // 500k >= threshold -> taux haut 8%
      expect(r.impotRetrait, closeTo(40000, 1));
      expect(r.capitalNet, closeTo(460000, 1));

      // Prudent: capital runs out before 85
      expect(r.scenarios['prudent']!.capital85, closeTo(0, 1));
      expect(r.scenarios['prudent']!.breakEvenAge, closeTo(82.6, 0.2));

      // Central: surplus at 85
      expect(r.scenarios['central']!.capital85, closeTo(55094, 500));
      expect(r.scenarios['central']!.breakEvenAge, closeTo(87.0, 0.5));

      // Optimiste: large surplus at 85
      expect(r.scenarios['optimiste']!.capital85, closeTo(268184, 500));
      expect(r.scenarios['optimiste']!.breakEvenAge, closeTo(97.8, 0.5));
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
      expect(r.impotRetrait, closeTo(17500, 1));
      expect(r.capitalNet, closeTo(232500, 1));

      expect(r.scenarios['prudent']!.breakEvenAge, closeTo(81.2, 0.2));
      expect(r.scenarios['central']!.capital85, closeTo(6895, 500));
      expect(r.scenarios['optimiste']!.capital85, closeTo(118637, 500));
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
      expect(r.impotRetrait, closeTo(105000, 1));
      expect(r.capitalNet, closeTo(895000, 1));

      // Central doesn't last to 85
      expect(r.scenarios['central']!.capital85, closeTo(0, 1));
      expect(r.scenarios['central']!.breakEvenAge, closeTo(84.8, 0.5));
      expect(r.scenarios['optimiste']!.capital85, closeTo(365794, 500));
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
      expect(r.impotRetrait, closeTo(6000, 1));
      expect(r.capitalNet, closeTo(94000, 1));

      expect(r.scenarios['prudent']!.breakEvenAge, closeTo(80.4, 0.2));
      expect(r.scenarios['optimiste']!.capital85, closeTo(36976, 500));
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
      expect(r.impotRetrait, closeTo(30000, 1));
      expect(r.capitalNet, closeTo(470000, 1));

      expect(r.scenarios['central']!.capital85, closeTo(13113, 500));
      expect(r.scenarios['optimiste']!.capital85, closeTo(219955, 500));
    });

    test('Unsupported canton throws ArgumentError', () {
      expect(
        () => computeRenteVsCapital(
          avoirObligatoire: 100000,
          avoirSurobligatoire: 50000,
          tauxConversionSurob: 0.05,
          ageRetraite: 65,
          canton: 'TI',
          statutCivil: 'single',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Threshold boundary: 500k exactly uses high rate', () {
      final r = computeRenteVsCapital(
        avoirObligatoire: 250000,
        avoirSurobligatoire: 250000,
        tauxConversionSurob: 0.05,
        ageRetraite: 65,
        canton: 'ZH',
        statutCivil: 'single',
      );

      // 500k exactly -> >= threshold -> taux haut 8%
      expect(r.impotRetrait, closeTo(40000, 1));
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
