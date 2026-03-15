import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coachprofile.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/services/financial_core/coach_reasoner.dart';

void main() {
  // ── Helper ──────────────────────────────────────────────────

  CoachProfile profile({
    int age = 50,
    double salaire = 8000,
    int mois = 12,
    String canton = 'VS',
    String employment = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    double avoirLpp = 70000,
    double rachatMax = 100000,
    double rachatEffectue = 0,
    double rendementCaisse = 0.02,
    int nombre3a = 0,
    double totalEpargne3a = 0,
    bool canContribute3a = true,
    List<LibrePassageCompte> librePassage = const [],
    double hypotheque = 0,
    double? mortgageRate,
  }) {
    return CoachProfile(
      birthYear: DateTime.now().year - age,
      canton: canton,
      salaireBrutMensuel: salaire,
      nombreDeMois: mois,
      employmentStatus: employment,
      etatCivil: etatCivil,
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLpp,
        rachatMaximum: rachatMax + rachatEffectue,
        rachatEffectue: rachatEffectue,
        rendementCaisse: rendementCaisse,
        nombre3a: nombre3a,
        totalEpargne3a: totalEpargne3a,
        canContribute3a: canContribute3a,
        librePassage: librePassage,
      ),
      patrimoine: PatrimoineProfile(
        mortgageRate: mortgageRate,
      ),
      dettes: DetteProfile(hypotheque: hypotheque),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 15),
        label: 'Retraite',
      ),
    );
  }

  // ── analyse() basics ────────────────────────────────────────

  group('CoachReasonerService.analyse — basics', () {
    test('empty profile (no salary) → empty recommendations', () {
      final result = CoachReasonerService.analyse(
          profile(salaire: 0));
      expect(result.recommendations, isEmpty);
      expect(result.confidence.score, isNotNull);
    });

    test('already retired (age >= 65) → empty recommendations', () {
      final result = CoachReasonerService.analyse(
          profile(age: 66));
      expect(result.recommendations, isEmpty);
    });

    test('result includes confidence score', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 50000));
      expect(result.confidence.score, greaterThanOrEqualTo(0));
      expect(result.confidence.score, lessThanOrEqualTo(100));
      expect(result.confidence.level, isNotEmpty);
    });
  });

  // ── Lever 1: Rachat LPP ────────────────────────────────────

  group('Lever 1 — Rachat LPP', () {
    test('lacune > 0 → rachat recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 80000));
      final rachat = result.recommendations
          .where((r) => r.id == 'rachat_lpp');
      expect(rachat, isNotEmpty);
      expect(rachat.first.impact.amountCHF, greaterThan(0));
      expect(rachat.first.impact.period, Period.yearly);
    });

    test('no lacune → no rachat recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'rachat_lpp'),
        isFalse,
      );
    });

    test('rachat includes LSFin disclaimer', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 50000));
      final rachat = result.recommendations
          .firstWhere((r) => r.id == 'rachat_lpp');
      expect(
        rachat.assumptions.any((a) => a.contains('LSFin')),
        isTrue,
      );
    });

    test('EPL risk mentioned (LPP art. 79b al. 3)', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 50000));
      final rachat = result.recommendations
          .firstWhere((r) => r.id == 'rachat_lpp');
      expect(
        rachat.risks.any((r) => r.contains('79b')),
        isTrue,
      );
    });

    test('near retirement (3y) adds limited return warning', () {
      final result = CoachReasonerService.analyse(
          profile(age: 63, rachatMax: 50000));
      final rachat = result.recommendations
          .firstWhere((r) => r.id == 'rachat_lpp');
      expect(
        rachat.risks.any((r) => r.contains('composé')),
        isTrue,
      );
    });

    test('higher fund rate → higher impact', () {
      final low = CoachReasonerService.analyse(
          profile(rachatMax: 80000, rendementCaisse: 0.01));
      final high = CoachReasonerService.analyse(
          profile(rachatMax: 80000, rendementCaisse: 0.05));
      final impactLow = low.recommendations
          .firstWhere((r) => r.id == 'rachat_lpp').impact.amountCHF;
      final impactHigh = high.recommendations
          .firstWhere((r) => r.id == 'rachat_lpp').impact.amountCHF;
      expect(impactHigh, greaterThan(impactLow));
    });
  });

  // ── Lever 2: 3a non-maxé ───────────────────────────────────

  group('Lever 2 — 3a non-maxé', () {
    test('no 3a accounts + can contribute → 3a gap recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(nombre3a: 0, totalEpargne3a: 0, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == '3a_non_maxe'),
        isTrue,
      );
    });

    test('FATCA block → no 3a recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(canContribute3a: false, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == '3a_non_maxe'),
        isFalse,
      );
    });

    test('3a recommendation includes heuristic disclaimer', () {
      final result = CoachReasonerService.analyse(
          profile(nombre3a: 1, totalEpargne3a: 10000, rachatMax: 0));
      final reco = result.recommendations
          .firstWhere((r) => r.id == '3a_non_maxe');
      expect(
        reco.assumptions.any((a) => a.contains('heuristique')),
        isTrue,
      );
    });
  });

  // ── Lever 3: Amortissement indirect ────────────────────────

  group('Lever 3 — Amortissement indirect', () {
    test('no mortgage → no amortissement recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(hypotheque: 0, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'amortissement_indirect'),
        isFalse,
      );
    });

    test('mortgage present → amortissement recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(hypotheque: 500000, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'amortissement_indirect'),
        isTrue,
      );
    });

    test('uses profile mortgage rate when available', () {
      final result = CoachReasonerService.analyse(
          profile(hypotheque: 500000, mortgageRate: 0.02, rachatMax: 0));
      final reco = result.recommendations
          .firstWhere((r) => r.id == 'amortissement_indirect');
      expect(
        reco.assumptions.any((a) => a.contains('2.00%')),
        isTrue,
      );
    });

    test('FATCA block → no amortissement indirect', () {
      final result = CoachReasonerService.analyse(
          profile(hypotheque: 500000, canContribute3a: false, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'amortissement_indirect'),
        isFalse,
      );
    });
  });

  // ── Lever 4: Échelonnement 3a ──────────────────────────────

  group('Lever 4 — Échelonnement 3a', () {
    test('< 2 accounts → no staggering recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(age: 58, nombre3a: 1, totalEpargne3a: 50000, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'echelonnement_3a'),
        isFalse,
      );
    });

    test('>= 2 accounts near retirement → staggering recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(age: 60, nombre3a: 4, totalEpargne3a: 400000, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'echelonnement_3a'),
        isTrue,
      );
    });

    test('too far from retirement (> 10y) → no staggering', () {
      final result = CoachReasonerService.analyse(
          profile(age: 40, nombre3a: 4, totalEpargne3a: 400000, rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'echelonnement_3a'),
        isFalse,
      );
    });

    test('staggering includes separate fiscal years assumption', () {
      final result = CoachReasonerService.analyse(
          profile(age: 60, nombre3a: 4, totalEpargne3a: 400000, rachatMax: 0));
      final reco = result.recommendations
          .firstWhere((r) => r.id == 'echelonnement_3a');
      expect(
        reco.assumptions.any((a) => a.contains('années fiscales')),
        isTrue,
      );
    });

    test('staggering impact is one-off', () {
      final result = CoachReasonerService.analyse(
          profile(age: 60, nombre3a: 4, totalEpargne3a: 400000, rachatMax: 0));
      final reco = result.recommendations
          .firstWhere((r) => r.id == 'echelonnement_3a');
      expect(reco.impact.period, Period.oneoff);
    });
  });

  // ── Lever 5: Split libre passage ───────────────────────────

  group('Lever 5 — Split libre passage', () {
    test('no libre passage → no split recommendation', () {
      final result = CoachReasonerService.analyse(
          profile(rachatMax: 0));
      expect(
        result.recommendations.any((r) => r.id == 'split_libre_passage'),
        isFalse,
      );
    });

    test('single LP account near retirement → split recommendation', () {
      final result = CoachReasonerService.analyse(profile(
        age: 55,
        rachatMax: 0,
        librePassage: [
          const LibrePassageCompte(institution: 'Test', solde: 200000),
        ],
      ));
      expect(
        result.recommendations.any((r) => r.id == 'split_libre_passage'),
        isTrue,
      );
    });

    test('already 2 LP accounts → no split recommendation', () {
      final result = CoachReasonerService.analyse(profile(
        age: 55,
        rachatMax: 0,
        librePassage: [
          const LibrePassageCompte(institution: 'A', solde: 100000),
          const LibrePassageCompte(institution: 'B', solde: 100000),
        ],
      ));
      expect(
        result.recommendations.any((r) => r.id == 'split_libre_passage'),
        isFalse,
      );
    });
  });

  // ── Sorting & compliance ───────────────────────────────────

  group('Sorting & compliance', () {
    test('recommendations sorted by annualized impact descending', () {
      final result = CoachReasonerService.analyse(profile(
        age: 58,
        rachatMax: 80000,
        nombre3a: 3,
        totalEpargne3a: 150000,
      ));
      if (result.recommendations.length >= 2) {
        // Verify non-increasing annualized order
        for (int i = 0; i < result.recommendations.length - 1; i++) {
          final a = result.recommendations[i];
          final b = result.recommendations[i + 1];
          double annualize(Recommendation r) =>
              r.impact.period == Period.oneoff
                  ? r.impact.amountCHF / 7 // ~yearsToRetirement
                  : r.impact.amountCHF;
          expect(annualize(a), greaterThanOrEqualTo(annualize(b)));
        }
      }
    });

    test('no banned word "garanti" in any recommendation', () {
      final result = CoachReasonerService.analyse(profile(
        rachatMax: 80000,
        nombre3a: 2,
        totalEpargne3a: 50000,
        hypotheque: 500000,
      ));
      for (final reco in result.recommendations) {
        final allText = [
          reco.title,
          reco.summary,
          ...reco.why,
          ...reco.assumptions,
          ...reco.risks,
          ...reco.alternatives,
        ].join(' ');
        expect(allText.contains('garanti'), isFalse,
            reason: '${reco.id} contains banned word "garanti"');
      }
    });

    test('every recommendation includes LSFin disclaimer', () {
      final result = CoachReasonerService.analyse(profile(
        rachatMax: 80000,
        nombre3a: 2,
        totalEpargne3a: 50000,
        hypotheque: 500000,
      ));
      for (final reco in result.recommendations) {
        expect(
          reco.assumptions.any((a) => a.contains('LSFin')),
          isTrue,
          reason: '${reco.id} missing LSFin disclaimer',
        );
      }
    });

    test('every recommendation has at least one nextAction with deepLink', () {
      final result = CoachReasonerService.analyse(profile(
        rachatMax: 80000,
        nombre3a: 2,
        totalEpargne3a: 50000,
        hypotheque: 500000,
      ));
      for (final reco in result.recommendations) {
        expect(reco.nextActions, isNotEmpty,
            reason: '${reco.id} has no nextActions');
        expect(
          reco.nextActions.any((a) => a.deepLink != null),
          isTrue,
          reason: '${reco.id} has no deepLink',
        );
      }
    });
  });
}
