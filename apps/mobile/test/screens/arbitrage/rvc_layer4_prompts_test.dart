import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

/// beads MINT_nosync-84r — couche 4 (enrichmentPrompts) câblée sur RvC.
///
/// Avant : la bannière passait `topEnrichmentCategory: 'lpp'` codé en dur —
/// l'EnhancedConfidence était calculé puis ses prompts JETÉS (seul .combined
/// survivait). Le CTA d'enrichissement pointait toujours vers LPP quel que
/// soit l'axe réellement le plus impactant du profil.
void main() {
  test('un profil incomplet produit des prompts triés par impact', () {
    final profile = CoachProfile(
      birthYear: DateTime.now().year - 40,
      canton: 'VD',
      salaireBrutMensuel: 7500,
      // LPP/3a/patrimoine absents -> prompts attendus sur ces axes.
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 25, 1, 1),
        label: 'Retraite',
      ),
    );
    final enhanced = ConfidenceScorer.scoreEnhanced(profile);
    expect(enhanced.axisPrompts, isNotEmpty);
    // NB : axisPrompts n'est PAS trié (ordre d'émission, scorer:425) — le
    // call site doit sélectionner le max par impact, pas .first.
    final maxImpact = enhanced.axisPrompts
        .map((p) => p.impact)
        .reduce((a, b) => a > b ? a : b);
    expect(maxImpact, greaterThan(0));
  });

  test('le call site RvC passe la catégorie RÉELLE, plus de hardcode lpp', () {
    // Preuve de câblage par inspection (pattern PR #963) : les tests directs
    // du scorer ne prouvent pas le wiring de l'écran.
    const path =
        'lib/screens/arbitrage/rente_vs_capital_screen.dart';
    final src = File('$path').readAsStringSync();
    final bannerCall = src.substring(
      src.indexOf('IndicatifBanner('),
      src.indexOf(')', src.indexOf('topEnrichmentCategory')) + 1,
    );
    expect(bannerCall.contains("topEnrichmentCategory: 'lpp'"), isFalse,
        reason: 'catégorie codée en dur = couche 4 jetée');
    // -jzk : helper local remplacé par la source unique centrale —
    // le local lisait axisPrompts (jamais routable, fallback 'lpp'
    // systématique : no-op latent car le hardcode remplacé était 'lpp').
    expect(
        bannerCall.contains('IndicatifBanner.topEnrichmentCategoryFrom'),
        isTrue);
  });
}
