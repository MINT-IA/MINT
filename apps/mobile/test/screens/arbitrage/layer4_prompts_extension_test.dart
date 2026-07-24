import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';

/// beads MINT_nosync-jzk — extension du pattern couche-4 (-84r) aux deux
/// autres écrans qui rendent IndicatifBanner.
///
/// Avant : location_vs_propriete passait `topEnrichmentCategory:
/// 'patrimoine'` et allocation_annuelle `'3a'` codés en dur — chaque écran
/// calculait l'EnhancedConfidence puis JETAIT ses axisPrompts (seul
/// .combined survivait). Le CTA d'enrichissement pointait toujours vers la
/// même catégorie quel que soit l'axe le plus impactant du profil réel.
///
/// Les autres parcours du bead (affordability, mariage, déménagement,
/// first_job, repayment, expat) ne rendent PAS IndicatifBanner — en
/// ajouter une est un travail d'écran séparé (panel design), pas un
/// câblage : vérifié par le test d'inventaire ci-dessous.
void main() {
  test('profil LPP complet -> catégorie routable, PAS le fallback lpp', () {
    // Panel -jzk fix critique 3 : le test v1 lisait axisPrompts
    // (freshness/accuracy/understanding uniquement — jamais routable,
    // fallback 'lpp' systématique) et était trivialement vert. Le helper
    // central lit baseResult.prompts (EVI décroissant) et ne retient que
    // les catégories ROUTABLES (_categoryToRoute).
    final profile = CoachProfile(
      birthYear: DateTime.now().year - 40,
      canton: 'VD',
      salaireBrutMensuel: 7500,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 250000,
        avoirLppObligatoire: 180000,
        totalEpargne3a: 0,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 25, 1, 1),
        label: 'Retraite',
      ),
    );
    final enhanced = ConfidenceScorer.scoreEnhanced(profile);
    final category = IndicatifBanner.topEnrichmentCategoryFrom(enhanced);
    expect(category, isNotNull);
    expect(category, isNot(equals('lpp')),
        reason: 'LPP renseigné : le CTA doit viser un axe MANQUANT du '
            'profil réel, pas le fallback');
  });

  test('helper null-safe et catégories non routables filtrées', () {
    expect(IndicatifBanner.topEnrichmentCategoryFrom(null), isNull);
  });

  test('location_vs_propriete passe la catégorie RÉELLE, plus de hardcode',
      () {
    const path = 'lib/screens/arbitrage/location_vs_propriete_screen.dart';
    final src = File(path).readAsStringSync();
    final bannerCall = src.substring(
      src.indexOf('IndicatifBanner('),
      src.indexOf(')', src.indexOf('topEnrichmentCategory')) + 1,
    );
    expect(bannerCall.contains("topEnrichmentCategory: 'patrimoine'"),
        isFalse,
        reason: 'catégorie codée en dur = couche 4 jetée');
    expect(
        bannerCall.contains('IndicatifBanner.topEnrichmentCategoryFrom'), isTrue);
    expect(src.contains('_canonicalEnhanced'), isTrue,
        reason: 'garder l\'EnhancedConfidence complet, pas que .combined');
  });

  test('allocation_annuelle passe la catégorie RÉELLE, plus de hardcode',
      () {
    const path = 'lib/screens/arbitrage/allocation_annuelle_screen.dart';
    final src = File(path).readAsStringSync();
    final bannerCall = src.substring(
      src.indexOf('IndicatifBanner('),
      src.indexOf(')', src.indexOf('topEnrichmentCategory')) + 1,
    );
    expect(bannerCall.contains("topEnrichmentCategory: '3a'"), isFalse,
        reason: 'catégorie codée en dur = couche 4 jetée');
    expect(
        bannerCall.contains('IndicatifBanner.topEnrichmentCategoryFrom'), isTrue);
    expect(src.contains('_canonicalEnhanced'), isTrue,
        reason: 'garder l\'EnhancedConfidence complet, pas que .combined');
  });

  test('inventaire : IndicatifBanner ne vit que sur les 3 écrans arbitrage',
      () {
    // Si un futur parcours (affordability, mariage...) ajoute la bannière,
    // ce test le détecte : il devra câbler _topPromptCategory (pattern -84r)
    // et non une catégorie en dur.
    final hits = <String>[];
    void scan(Directory d) {
      for (final f in d.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.dart')) {
          if (f.readAsStringSync().contains('IndicatifBanner(')) {
            hits.add(f.path);
          }
        }
      }
    }

    scan(Directory('lib/screens'));
    expect(
      hits.map((p) => p.split('/').last).toSet(),
      {
        'rente_vs_capital_screen.dart',
        'location_vs_propriete_screen.dart',
        'allocation_annuelle_screen.dart',
      },
      reason: 'nouvel écran à bannière -> câbler le pattern couche 4',
    );
  });
}
