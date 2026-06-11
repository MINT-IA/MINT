/// D12 — Une seule source de confiance par profil.
///
/// Reproduit puis verrouille l'incoherence « 44% (Mon Argent) vs 50% (RvC)
/// vs 30% (donnees reelles) » de la matrice (MATRIX D12, A_REPRODUIRE).
///
/// Mecanisme racine (cite file:line dans le SUMMARY) :
///   - Mon Argent / home lisent `ConfidenceScorer.scoreEnhanced(profile).combined`
///     (confidence_scorer.dart:831-836, moyenne geometrique 4-axes).
///   - RvC lisait `ArbitrageEngine._computeArbitrageConfidence` — un 3e moteur
///     local a l'ecran (arbitrage_engine.dart:38-56) qui renvoyait un plancher
///     code en dur de 50.0 quand `dataSources` est null/vide (ligne 42/45).
///   - Apres le plan 10 (fiction tuee), un RvC vide retombe sur ce 50.0, tandis
///     qu'un profil reel mais partiel obtient le ratio (<50). D'ou l'inversion
///     « fiction 50% > reel 30% ».
///
/// Fix (strangler-fig) : `compareRenteVsCapital` accepte une confiance canonique
/// optionnelle (`EnhancedConfidence.combined`) calculee par l'appelant sur le
/// MEME profil. Quand elle est fournie, l'engine l'utilise telle quelle → un
/// profil = un score sur toutes les surfaces. Le plancher trompeur de 50.0 pour
/// l'absence de donnees est supprime du fallback heuristique (l'absence de
/// donnees doit donner une confiance basse, pas 50).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  // ── Helper : profil minimal valide (age via birthYear, canton, salaire) ──
  CoachProfile profileOf({
    required int age,
    required double grossAnnual,
    required String canton,
  }) {
    return CoachProfile(
      birthYear: DateTime.now().year - age,
      canton: canton,
      salaireBrutMensuel: grossAnnual / 12,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + (65 - age), 1, 1),
        label: 'Retraite',
      ),
    );
  }

  group('D12 — source de confiance unique', () {
    test(
        'RvC honore la confiance canonique fournie (un profil = un score, '
        'plus de 3e moteur local)', () {
      // Un profil reel mais partiel : confiance canonique calculee une fois.
      final profile = profileOf(age: 40, grossAnnual: 90000, canton: 'VD');
      final canonical = ConfidenceScorer.scoreEnhanced(profile).combined;

      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 300000,
        capitalObligatoire: 200000,
        capitalSurobligatoire: 100000,
        renteAnnuelleProposee: 20000,
        canton: 'VD',
        // La surface passe la confiance canonique du profil.
        canonicalConfidence: canonical,
      );

      // RvC affiche EXACTEMENT la confiance canonique — pas un score local.
      expect(result.confidenceScore, closeTo(canonical, 0.001),
          reason:
              'RvC doit refleter EnhancedConfidence.combined, pas un moteur '
              'd\'arbitrage local divergent (D12).');
    });

    test(
        'inversion fiction>reel supprimee : l\'absence de donnees ne rend plus '
        '50% (plancher trompeur retire)', () {
      // Cas « fiction » de la matrice : aucune source de donnees (ex. ecran vide
      // post-plan-10). Avant le fix, `_computeArbitrageConfidence` renvoyait
      // 50.0 ici. Apres : pas de confiance canonique + pas de sources → confiance
      // basse, jamais un 50 qui depasse un profil reel partiel.
      final fictionResult = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 300000,
        capitalObligatoire: 200000,
        capitalSurobligatoire: 100000,
        renteAnnuelleProposee: 20000,
        canton: 'VD',
        // ni canonicalConfidence ni dataSources → cas « fiction / vide »
      );

      // Un profil reel mais partiel (donnees user, pas certificat) : confiance
      // canonique modeste mais > 0.
      final realProfile =
          profileOf(age: 35, grossAnnual: 78000, canton: 'GE');
      final realCanonical =
          ConfidenceScorer.scoreEnhanced(realProfile).combined;

      // L'inversion est fermee : la fiction (sans donnees) ne doit JAMAIS
      // depasser le profil reel.
      expect(fictionResult.confidenceScore, lessThanOrEqualTo(realCanonical),
          reason:
              'Inversion D12 : la fiction (sans source) ne doit pas afficher '
              'une confiance superieure a un profil reel.');
      // Et concretement, l'absence de donnees ne rend plus le plancher 50.
      expect(fictionResult.confidenceScore, lessThan(50.0),
          reason:
              'Le plancher trompeur de 50.0 pour l\'absence de donnees est '
              'retire (arbitrage_engine.dart).');
    });

    test(
        'fallback heuristique : plus de donnees connues → confiance plus haute '
        '(monotonie preservee, sans canonicalConfidence)', () {
      // Sans confiance canonique, le fallback reste monotone : un profil avec
      // des sources certificat doit scorer plus haut qu'un profil sans source.
      final withCert = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 300000,
        capitalObligatoire: 200000,
        capitalSurobligatoire: 100000,
        renteAnnuelleProposee: 20000,
        canton: 'VD',
        dataSources: const {
          'capitalLppTotal': ProfileDataSource.certificate,
          'renteAnnuelle': ProfileDataSource.certificate,
          'tauxConversion': ProfileDataSource.certificate,
          'canton': ProfileDataSource.certificate,
        },
      );
      final noSource = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 300000,
        capitalObligatoire: 200000,
        capitalSurobligatoire: 100000,
        renteAnnuelleProposee: 20000,
        canton: 'VD',
      );
      expect(withCert.confidenceScore,
          greaterThan(noSource.confidenceScore),
          reason: 'Plus de donnees connues → confiance plus haute.');
    });
  });
}
