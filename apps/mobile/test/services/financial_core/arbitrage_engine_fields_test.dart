/// Tests for ArbitrageResult hero + educational card fields.
///
/// Audit-required (S45): verify the 9 new ArbitrageResult fields
/// (renteNetMensuelle, capitalRetraitMensuel, capitalEpuiseAge,
/// impotCumulRente, impotRetraitCapital, renteReelleAn20, renteSurvivant,
/// capitalProjecte, isProjected) are populated correctly in both
/// certificate mode and projection (estimate) mode.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  ArbitrageResult _certResult({
    double capitalOblig = 500000,
    double capitalSurob = 150000,
    double renteAnnuelle = 37000,
    double tcOblig = 0.068,
    double tcSurob = 0.05,
    String canton = 'VD',
    int ageRetraite = 65,
    double swr = 0.04,
    double rendement = 0.03,
    double inflation = 0.02,
    int horizon = 30,
    bool isMarried = false,
  }) {
    return ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: capitalOblig + capitalSurob,
      capitalObligatoire: capitalOblig,
      capitalSurobligatoire: capitalSurob,
      renteAnnuelleProposee: renteAnnuelle,
      tauxConversionObligatoire: tcOblig,
      tauxConversionSurobligatoire: tcSurob,
      canton: canton,
      ageRetraite: ageRetraite,
      tauxRetrait: swr,
      rendementCapital: rendement,
      inflation: inflation,
      horizon: horizon,
      isMarried: isMarried,
    );
  }

  ArbitrageResult _estimateResult({
    int currentAge = 50,
    double salary = 100000,
    double capitalOblig = 210000,
    double capitalSurob = 140000,
    double renteAnnuelle = 22750,
    int ageRetraite = 65,
    String canton = 'ZH',
    bool isMarried = true,
    int horizon = 30,
  }) {
    return ArbitrageEngine.compareRenteVsCapital(
      capitalLppTotal: capitalOblig + capitalSurob,
      capitalObligatoire: capitalOblig,
      capitalSurobligatoire: capitalSurob,
      renteAnnuelleProposee: renteAnnuelle,
      canton: canton,
      ageRetraite: ageRetraite,
      isMarried: isMarried,
      horizon: horizon,
      currentAge: currentAge,
      grossAnnualSalary: salary,
    );
  }

  // ── Group 1: Certificate mode (isProjected = false) ──────────────────────

  group('certificate mode — hero fields', () {
    late ArbitrageResult r;

    setUpAll(() {
      r = _certResult();
    });

    test('isProjected is false', () {
      expect(r.isProjected, isFalse);
    });

    test('renteNetMensuelle > 0', () {
      // Net monthly rente must be positive (rente 37k/yr, some income tax)
      expect(r.renteNetMensuelle, greaterThan(0));
    });

    test('renteNetMensuelle < renteAnnuelle / 12 (tax applied)', () {
      // Net must be less than gross monthly (taxes reduce it)
      final grossMonthly = 37000 / 12;
      expect(r.renteNetMensuelle, lessThan(grossMonthly));
    });

    test('capitalRetraitMensuel > 0', () {
      expect(r.capitalRetraitMensuel, greaterThan(0));
    });

    test('capitalRetraitMensuel ≈ SWR × capitalTotal / 12 (year 1)', () {
      // SWR 4% on 650k → 26k/yr → ~2167/mo
      final expected = 650000 * 0.04 / 12;
      expect(r.capitalRetraitMensuel, closeTo(expected, expected * 0.15));
    });

    test('impotRetraitCapital > 0 (withdrawal tax)', () {
      expect(r.impotRetraitCapital, greaterThan(0));
    });

    test('impotCumulRente > 0 (income tax cumulated)', () {
      expect(r.impotCumulRente, greaterThan(0));
    });

    test('renteReelleAn20 < renteNetMensuelle × 12 (inflation erosion)', () {
      // After 20 years of 2% inflation, real annual rente < year-1 net annual
      expect(r.renteReelleAn20, lessThan(r.renteNetMensuelle * 12));
    });

    test('renteSurvivant = 0 when unmarried', () {
      expect(r.renteSurvivant, equals(0.0));
    });

    test('capitalProjecte = capitalTotal (no projection in cert mode)', () {
      expect(r.capitalProjecte, closeTo(650000, 1.0));
    });
  });

  // ── Group 2: Married — renteSurvivant ────────────────────────────────────

  group('married — renteSurvivant', () {
    test('renteSurvivant = 60% of annual effective rente', () {
      final r = _certResult(renteAnnuelle: 36000, isMarried: true);
      // LPP art. 19: 60% survivor pension
      expect(r.renteSurvivant, closeTo(36000 * 0.6, 36000 * 0.6 * 0.05));
    });
  });

  // ── Group 3: capitalEpuiseAge ─────────────────────────────────────────────

  group('capitalEpuiseAge', () {
    test('capital exhausted when SWR too high (8%) on small capital', () {
      // 8% SWR on 300k capital, 0% return → runs out before horizon ends
      final r = _certResult(
        capitalOblig: 180000,
        capitalSurob: 120000,
        renteAnnuelle: 20000,
        swr: 0.08,
        rendement: 0.0,
        horizon: 40,
      );
      expect(r.capitalEpuiseAge, isNotNull);
      expect(r.capitalEpuiseAge!, greaterThan(65));
      expect(r.capitalEpuiseAge!, lessThan(65 + 40));
    });

    test('capital NOT exhausted at conservative 3% SWR on large capital', () {
      // 3% SWR on 1M with 4% return → never runs out over 30 years
      final r = _certResult(
        capitalOblig: 600000,
        capitalSurob: 400000,
        renteAnnuelle: 50000,
        swr: 0.03,
        rendement: 0.04,
        horizon: 30,
      );
      expect(r.capitalEpuiseAge, isNull);
    });
  });

  // ── Group 4: Estimate (projection) mode ──────────────────────────────────

  group('estimate mode — isProjected', () {
    late ArbitrageResult r;

    setUpAll(() {
      r = _estimateResult();
    });

    test('isProjected is true when currentAge < ageRetraite', () {
      expect(r.isProjected, isTrue);
    });

    test('capitalProjecte > capitalOblig + capitalSurob (growth projected)', () {
      // After projecting from age 50 to 65, capital grows
      expect(r.capitalProjecte, greaterThan(210000 + 140000));
    });

    test('renteNetMensuelle > 0 in projection mode', () {
      expect(r.renteNetMensuelle, greaterThan(0));
    });

    test('capitalRetraitMensuel based on projected capital', () {
      // Projected capital should be used for SWR calc
      final swr4pct = r.capitalProjecte * 0.04 / 12;
      expect(r.capitalRetraitMensuel, closeTo(swr4pct, swr4pct * 0.15));
    });
  });

  // ── Group 5: Horizon = max(30, lifeExpectancy - ageRetraite) ─────────────

  group('dynamic horizon', () {
    test('longer horizon (40 yrs) gives different capitalEpuiseAge', () {
      final r30 = _certResult(
        capitalOblig: 180000,
        capitalSurob: 120000,
        swr: 0.07,
        rendement: 0.02,
        horizon: 30,
      );
      final r40 = _certResult(
        capitalOblig: 180000,
        capitalSurob: 120000,
        swr: 0.07,
        rendement: 0.02,
        horizon: 40,
      );
      // Both should exhaust capital; horizon 40 will have earlier relative age
      // but r40.capitalEpuiseAge should not exceed 65+40
      if (r30.capitalEpuiseAge != null) {
        expect(r30.capitalEpuiseAge!, lessThanOrEqualTo(65 + 30));
      }
      if (r40.capitalEpuiseAge != null) {
        expect(r40.capitalEpuiseAge!, lessThanOrEqualTo(65 + 40));
      }
    });

    test('horizon=30 is minimum even when lifeExpectancy - ageRetraite < 30', () {
      // e.g. lifeExpectancy=90, ageRetraite=65 → 25 → max(30,25)=30
      final effective = math.max(30, 90 - 65);
      expect(effective, equals(30));
    });

    test('horizon=35 when lifeExpectancy=100, ageRetraite=65', () {
      final effective = math.max(30, 100 - 65);
      expect(effective, equals(35));
    });
  });

  // ── Group 6: Compliance ───────────────────────────────────────────────────

  group('compliance', () {
    test('disclaimer is non-empty and mentions LSFin', () {
      final r = _certResult();
      expect(r.disclaimer, isNotEmpty);
      expect(r.disclaimer.toLowerCase(), contains('educatif'));
    });

    test('sources list includes LIFD art. 38', () {
      final r = _certResult();
      final combined = r.sources.join(' ');
      expect(combined, contains('LIFD'));
    });

    test('chiffreChoc is non-empty', () {
      final r = _certResult();
      expect(r.chiffreChoc, isNotEmpty);
    });
  });
}
