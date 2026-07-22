import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/mortality_ofs.dart';

/// beads MINT_nosync-t5r (b) — audit T01-F33.
///
/// Bug prouvé sur dev (monte_carlo_service.dart:174) : l'espérance de vie du
/// Monte Carlo était tirée UNIFORME `82 + random.nextInt(14)` (82-95) — ni
/// genrée, ni conditionnelle à l'âge, plancher 82 et plafond 95 arbitraires.
/// Remplacée par l'inverse-CDF sur la table de mortalité OFS 2023
/// (Vollständige jährliche Sterbetafel, su-d-01.04.02.02.04/.05).
///
/// Les assertions verrouillent les propriétés que l'uniforme 82-95 ne peut
/// PAS produire : décès avant 82 possibles, survie au-delà de 95 possible,
/// moyennes conditionnelles à 65 collant aux e65 OFS (H 20.3 / F 22.8).
void main() {
  const draws = 40000;

  List<int> sample({required int currentAge, String? gender, int seed = 42}) {
    final rng = math.Random(seed);
    return List.generate(
      draws,
      (_) => MortalityOfs.sampleDeathAge(
        rng,
        currentAge: currentAge,
        gender: gender,
      ),
    );
  }

  double mean(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;

  group('MortalityOfs — table OFS 2023, pas uniforme 82-95', () {
    test('e65 hommes ≈ 20.3 ans (âge moyen de décès ≈ 85.3 ± 0.5)', () {
      final ages = sample(currentAge: 65, gender: 'M');
      // Le tirage rend l'âge entier (floor) : biais ≈ −0.5 an vs l'espérance
      // continue -> comparer à 65 + 20.3 − 0.5 = 84.8.
      expect(mean(ages), closeTo(84.8, 0.5));
    });

    test('e65 femmes ≈ 22.8 ans (âge moyen de décès ≈ 87.8 ± 0.5)', () {
      final ages = sample(currentAge: 65, gender: 'F');
      expect(mean(ages), closeTo(87.3, 0.5));
    });

    test('les femmes vivent plus longtemps que les hommes (écart OFS ≈ 2.5)',
        () {
      final gap = mean(sample(currentAge: 65, gender: 'F')) -
          mean(sample(currentAge: 65, gender: 'M'));
      expect(gap, closeTo(2.5, 0.7));
    });

    test('décès avant 82 possibles (impossible avec le plancher uniforme)',
        () {
      final ages = sample(currentAge: 65, gender: 'M');
      final before80 = ages.where((a) => a < 80).length / draws;
      // OFS 2023 : S(80)/S(65) hommes = 74.4% -> ~25% de décès avant 80.
      expect(before80, closeTo(0.25, 0.03));
    });

    test('survie au-delà de 95 possible (impossible avec le plafond 95)', () {
      final ages = sample(currentAge: 65, gender: 'M');
      final past95 = ages.where((a) => a >= 95).length / draws;
      // OFS 2023 : S(95)/S(65) hommes = 10.1%.
      expect(past95, closeTo(0.101, 0.02));
      expect(ages.any((a) => a > 95), isTrue);
    });

    test('conditionnel à l\'âge : un homme de 85 ans ne peut pas mourir à 80',
        () {
      final ages = sample(currentAge: 85, gender: 'M');
      expect(ages.every((a) => a >= 85), isTrue);
      // Espérance résiduelle à 85 (OFS H ≈ 5.8) : moyenne ≈ 90 ± 1.
      expect(mean(ages), closeTo(90.0, 1.0));
    });

    test('genre inconnu -> table femmes (prudence longévité), pas moyenne H/F',
        () {
      final unknown = mean(sample(currentAge: 65, gender: null));
      final women = mean(sample(currentAge: 65, gender: 'F'));
      expect(unknown, closeTo(women, 0.15),
          reason: 'le risque modélisé est la longévité : le fallback doit '
              'être la survie la plus longue (table F), pas la moyenne');
    });

    test('borne : jamais au-delà de 105, jamais avant l\'âge courant', () {
      for (final gender in ['M', 'F', null]) {
        final ages = sample(currentAge: 70, gender: gender);
        expect(ages.every((a) => a >= 70 && a <= 105), isTrue);
      }
    });

    test('au-delà de la table (105+) : rend l\'âge courant, jamais moins', () {
      // Codex re-review : un profil de 106-150 ans recevait un âge de décès
      // 104/105 < âge courant -> revenus projetés à zéro dès l'an 1.
      for (final age in [105, 106, 120, 150]) {
        final ages = sample(currentAge: age, gender: 'M');
        expect(ages.every((a) => a == age), isTrue,
            reason: 'à $age ans (hors table), l\'âge courant doit être '
                'rendu tel quel — pas un décès dans le passé');
      }
    });

    test('conditionnement explicite à max(âge, 60) : 30 ans == 60 ans', () {
      // La mortalité avant 60 n'est pas modélisée : la personne est réputée
      // atteindre 60 vivante. Même graine -> tirages identiques.
      expect(sample(currentAge: 30, gender: 'F'),
          sample(currentAge: 60, gender: 'F'));
    });

    test('dernière tranche (104) : décès à 104 ou 105 uniquement', () {
      final ages = sample(currentAge: 104, gender: 'F');
      expect(ages.every((a) => a == 104 || a == 105), isTrue);
    });
  });

  group('câblage Monte Carlo', () {
    test('monte_carlo_service tire sur MortalityOfs, plus d\'uniforme 82-95',
        () {
      final source = File(
        'lib/services/financial_core/monte_carlo_service.dart',
      ).readAsStringSync();
      expect(source.contains('MortalityOfs.sampleDeathAge'), isTrue,
          reason: 'le Monte Carlo doit échantillonner la table OFS');
      expect(source.contains('82 + random.nextInt(14)'), isFalse,
          reason: 'le tirage uniforme 82-95 doit avoir disparu');
      expect(source.contains('gender: profile.gender'), isTrue,
          reason: 'le tirage doit être genré depuis le profil');
    });
  });
}
