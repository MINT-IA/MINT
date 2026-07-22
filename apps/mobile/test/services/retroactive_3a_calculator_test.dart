import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/retroactive_3a_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Doctrine corrigée (OPP3 art. 7a, en vigueur 2025-01-01) — parité avec
/// services/backend/tests/test_pillar_3a_retroactive.py (MINT_nosync-i0v) :
///   - seules les lacunes >= 2025 sont rachetables (fenêtre 10 ans) ;
///   - le rachat rétroactif payable en UNE année civile est plafonné au
///     « petit » maximum 3a (7'258), identique avec ou sans LPP ;
///   - le cap 20% du revenu ne concerne QUE la cotisation de l'année courante.
///
/// Historique : l'ancienne suite (référence 2036) verrouillait les sommes
/// multi-années (~68'170) et le scaling grand-3a sans LPP — doctrine
/// pré-correction, cf. MINT_nosync-cli.
void main() {
  const petitMax = pilier3aPlafondAvecLpp; // 7'258

  group('Retroactive3aCalculator — doctrine OPP3 art. 7a', () {
    // ── Plancher 2025 + cap annuel = un petit max ──
    test('10-year request in 2026 fills only 2025, capped at petit max', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.35,
        referenceYear: 2026,
      );
      expect(result.totalRetroactive, petitMax); // 7'258, pas 68'170
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
    });

    test('total retroactive never exceeds one petit max, any gap/refYear', () {
      for (final refYear in [2026, 2027, 2030, 2036, 2040]) {
        for (final gap in [1, 2, 5, 10, 15]) {
          final result = Retroactive3aCalculator.calculate(
            gapYears: gap,
            tauxMarginal: 0.30,
            referenceYear: refYear,
          );
          expect(result.totalRetroactive, lessThanOrEqualTo(petitMax),
              reason: 'refYear=$refYear gap=$gap dépasse le cap annuel');
        }
      }
    });

    test('no entry before 2025 ever (gaps antérieures perdues)', () {
      for (final refYear in [2026, 2030, 2036]) {
        final result = Retroactive3aCalculator.calculate(
          gapYears: 15,
          tauxMarginal: 0.30,
          referenceYear: refYear,
        );
        for (final entry in result.breakdown) {
          expect(entry.year, greaterThanOrEqualTo(2025));
        }
      }
    });

    test('oldest eligible gap filled first (2027: 2025 before 2026)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 2,
        tauxMarginal: 0.30,
        referenceYear: 2027,
      );
      // Cap annuel un petit max → une seule lacune comblée : la plus
      // ancienne (2025, proche de sortir de la fenêtre).
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2025);
    });

    test('10-year window: in 2040 the oldest eligible gap is 2030', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 15,
        tauxMarginal: 0.30,
        referenceYear: 2040,
      );
      expect(result.breakdown.length, 1);
      expect(result.breakdown.first.year, 2030);
    });

    test('referenceYear 2025: no past year buyable yet', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2025,
      );
      expect(result.gapYears, 0);
      expect(result.totalRetroactive, 0);
      expect(result.breakdown, isEmpty);
    });

    // ── Économie fiscale ──
    test('economiesFiscales equals totalRetroactive times tauxMarginal', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );
      expect(result.economiesFiscales, result.totalRetroactive * 0.30);
    });

    test('taux marginal clamped to 0.45 (audit P1-9)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 1.5,
        referenceYear: 2026,
      );
      expect(result.economiesFiscales,
          lessThanOrEqualTo(result.totalRetroactive * 0.45 + 0.01));
    });

    // ── Année courante séparée du rachat ──
    test('current year excluded from retroactive total', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );
      expect(result.totalCurrentYear, petitMax);
      expect(result.totalContribution,
          result.totalRetroactive + result.totalCurrentYear);
      for (final entry in result.breakdown) {
        expect(entry.year, isNot(2026));
      }
    });

    // ── Sans LPP : rachat = petit max pour tous ──
    test('sans LPP retroactive equals with-LPP retroactive (petit max)', () {
      final withLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: true,
        referenceYear: 2026,
      );
      final sansLpp = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: false,
        referenceYear: 2026,
      );
      // Asymétrie réforme : le rachat rétroactif est le petit max pour tous ;
      // seule la cotisation courante diffère (grand 3a sans LPP).
      expect(sansLpp.totalRetroactive, withLpp.totalRetroactive);
      expect(sansLpp.totalRetroactive, petitMax); // pas 36'288
      expect(sansLpp.totalCurrentYear, pilier3aPlafondSansLpp);
      expect(withLpp.totalCurrentYear, petitMax);
    });

    test('sans LPP: 20% income rule applies to current year only', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.30,
        hasLpp: false,
        revenuNetAnnuel: 80000,
        referenceYear: 2026,
      );
      expect(result.totalRetroactive, petitMax); // pas 16'000 x N
      expect(result.totalCurrentYear, 16000.0); // 20% de 80k
    });

    test('sans LPP zero income: no capacity at all', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.25,
        hasLpp: false,
        revenuNetAnnuel: 0,
        referenceYear: 2026,
      );
      expect(result.totalRetroactive, 0.0);
      expect(result.totalCurrentYear, 0.0);
    });

    // ── Narratif ──
    test('premierEclairage uses the effective year, never "null"', () {
      // Chemin écran : referenceYear omis → défaut année courante.
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.30,
      );
      expect(result.premierEclairage, isNot(contains('null')));
      expect(result.premierEclairage, contains('${DateTime.now().year}'));
    });

    test('premierEclairage contains CHF amount and eligible year count', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2026,
      );
      expect(result.premierEclairage, contains('CHF'));
      expect(result.premierEclairage, contains('1 an '));
      expect(result.premierEclairage, isNot(contains('1 ans')));
      expect(result.premierEclairage, contains('2026'));
    });

    test('premierEclairage handles zero eligible years (2025)', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 5,
        tauxMarginal: 0.30,
        referenceYear: 2025,
      );
      expect(result.premierEclairage, contains('2025'));
      expect(result.premierEclairage, isNot(contains('null')));
      expect(result.premierEclairage, isNot(contains('rattraper')));
    });

    // ── Compliance ──
    test('disclaimer contains educatif and OPP3', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.25,
        referenceYear: 2026,
      );
      expect(result.disclaimer, contains('ducatif'));
      expect(result.disclaimer, contains('OPP3'));
    });

    test('sources contain OPP3 art. 7a and LIFD references', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 1,
        tauxMarginal: 0.25,
        referenceYear: 2026,
      );
      expect(result.sources.any((s) => s.contains('OPP3 art. 7a')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    // ── Goldens (parité backend test_pillar_3a_retroactive.py) ──
    test('golden Julien: 10-year belief in 2026 → 7258 / 2540.30', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 10,
        tauxMarginal: 0.35,
        hasLpp: true,
        referenceYear: 2026,
      );
      expect(result.totalRetroactive, 7258.0);
      expect(result.economiesFiscales, closeTo(2540.30, 0.01));
      expect(result.breakdown.length, 1);
    });

    test('golden Marco: independent sans LPP in 2026 → 7258 retro', () {
      final result = Retroactive3aCalculator.calculate(
        gapYears: 3,
        tauxMarginal: 0.20,
        hasLpp: false,
        referenceYear: 2026,
      );
      expect(result.totalRetroactive, 7258.0); // pas ~105'979
      expect(result.totalCurrentYear, 36288.0);
      expect(result.breakdown.length, 1);
    });
  });
}
