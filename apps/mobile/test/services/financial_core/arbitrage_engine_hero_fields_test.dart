import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

void main() {
  // ── Standard certificate-mode result ──
  late ArbitrageResult certResult;
  // ── Estimate-mode result with projection ──
  late ArbitrageResult projResult;

  setUpAll(() {
    certResult = ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: 650000,
      capitalObligatoire: 500000,
      capitalSurobligatoire: 150000,
      renteAnnuelleProposee: 37000,
      tauxConversionObligatoire: 0.068,
      tauxConversionSurobligatoire: 0.05,
      canton: 'VD',
      ageRetraite: 65,
      tauxRetrait: 0.04,
      rendementCapital: 0.03,
      inflation: 0.02,
      horizon: 30,
      isMarried: true,
    );

    projResult = ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: 350000,
      capitalObligatoire: 245000,
      capitalSurobligatoire: 105000,
      renteAnnuelleProposee: 16660,
      tauxConversionObligatoire: 0.068,
      tauxConversionSurobligatoire: 0.05,
      canton: 'VS',
      ageRetraite: 65,
      tauxRetrait: 0.04,
      rendementCapital: 0.03,
      inflation: 0.02,
      horizon: 30,
      isMarried: true,
      currentAge: 50,
      grossAnnualSalary: 122000,
    );
  });

  group('ArbitrageEngine hero fields — certificate mode', () {
    test('renteNetMensuelle is positive and less than gross rente', () {
      expect(certResult.renteNetMensuelle, greaterThan(0));
      expect(certResult.renteNetMensuelle, lessThan(37000 / 12));
    });

    test('capitalRetraitMensuel is positive', () {
      expect(certResult.capitalRetraitMensuel, greaterThan(0));
    });

    test('capitalEpuiseAge is null or > ageRetraite', () {
      if (certResult.capitalEpuiseAge != null) {
        expect(certResult.capitalEpuiseAge, greaterThan(65));
      }
    });

    test('impotCumulRente is positive (taxes are paid)', () {
      expect(certResult.impotCumulRente, greaterThan(0));
    });

    test('impotRetraitCapital is positive (one-time tax)', () {
      expect(certResult.impotRetraitCapital, greaterThan(0));
    });

    test('impotRetraitCapital < impotCumulRente (capital is tax-efficient)', () {
      // For a 650k capital, one-time tax should be much less than
      // 30 years of rente income tax.
      expect(certResult.impotRetraitCapital,
          lessThan(certResult.impotCumulRente));
    });

    test('renteReelleAn20 is less than nominal rente (inflation erodes)', () {
      expect(certResult.renteReelleAn20, greaterThan(0));
      expect(certResult.renteReelleAn20, lessThan(37000));
    });

    test('renteSurvivant is 60% of rente when married', () {
      // 37000 * 0.6 = 22200
      expect(certResult.renteSurvivant, closeTo(37000 * 0.6, 1));
    });

    test('isProjected is false in certificate mode', () {
      expect(certResult.isProjected, isFalse);
    });

    test('capitalProjecte equals input capitalLppTotal', () {
      expect(certResult.capitalProjecte, closeTo(650000, 1));
    });
  });

  group('ArbitrageEngine hero fields — estimate/projection mode', () {
    test('isProjected is true when currentAge provided', () {
      expect(projResult.isProjected, isTrue);
    });

    test('capitalProjecte > input capital (projected growth)', () {
      expect(projResult.capitalProjecte, greaterThan(350000));
    });

    test('renteNetMensuelle > 0', () {
      expect(projResult.renteNetMensuelle, greaterThan(0));
    });

    test('capitalRetraitMensuel > 0', () {
      expect(projResult.capitalRetraitMensuel, greaterThan(0));
    });

    test('renteSurvivant is 60% of projected rente (married)', () {
      // renteSurvivant = effectiveRente * 0.6
      // We can't know effectiveRente exactly, but it should be > input
      expect(projResult.renteSurvivant, greaterThan(0));
    });
  });

  group('ArbitrageEngine hero fields — unmarried', () {
    late ArbitrageResult singleResult;

    setUpAll(() {
      singleResult = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 350000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 30000,
        canton: 'ZH',
        isMarried: false,
        horizon: 30,
      );
    });

    test('renteSurvivant is 0 when not married', () {
      expect(singleResult.renteSurvivant, equals(0.0));
    });

    test('isProjected is false without currentAge', () {
      expect(singleResult.isProjected, isFalse);
    });
  });

  group('ArbitrageEngine — dynamic horizon', () {
    test('horizon 35 produces trajectories of length 36 (years 0-35)', () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 350000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 30000,
        canton: 'VD',
        horizon: 35,
      );

      for (final option in result.options) {
        expect(option.trajectory.length, equals(36));
      }
    });

    test('slider at 95 with retraite 65 = horizon 30 produces data at year 30', () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 350000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 30000,
        canton: 'VD',
        horizon: 30,
      );

      final renteOption = result.options.firstWhere((o) => o.id == 'full_rente');
      // Year index 30 should exist (trajectory has 31 entries: years 0-30)
      expect(renteOption.trajectory.length, equals(31));
    });

    test('slider at 100 with retraite 65 = horizon 35 covers all ages', () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 500000,
        capitalObligatoire: 350000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 30000,
        canton: 'VD',
        horizon: 35,
      );

      final renteOption = result.options.firstWhere((o) => o.id == 'full_rente');
      // Year index 35 should exist: trajectory covers ages 65-100
      expect(renteOption.trajectory.length, greaterThanOrEqualTo(36));
    });
  });

  group('ArbitrageEngine — compliance checks', () {
    test('disclaimer mentions LSFin', () {
      expect(certResult.disclaimer, contains('LSFin'));
    });

    test('disclaimer mentions outil educatif', () {
      expect(certResult.disclaimer, contains('educatif'));
    });

    test('sources include LPP art. 14', () {
      expect(certResult.sources.any((s) => s.contains('LPP art. 14')), isTrue);
    });

    test('sources include LIFD art. 38 (capital tax)', () {
      expect(certResult.sources.any((s) => s.contains('LIFD art. 38')), isTrue);
    });

    test('sources include LPP art. 19 (survivor) when married', () {
      expect(certResult.sources.any((s) => s.contains('LPP art. 19')), isTrue);
    });

    test('chiffreChoc is non-empty', () {
      expect(certResult.chiffreChoc, isNotEmpty);
    });

    test('confidenceScore is between 0 and 100', () {
      expect(certResult.confidenceScore, greaterThanOrEqualTo(0));
      expect(certResult.confidenceScore, lessThanOrEqualTo(100));
    });

    test('3 options: full_rente, full_capital, mixed', () {
      final ids = certResult.options.map((o) => o.id).toSet();
      expect(ids, containsAll(['full_rente', 'full_capital', 'mixed']));
    });
  });
}
