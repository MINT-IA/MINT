import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';

// ────────────────────────────────────────────────────────────
//  COMPLIANCE GUARD ADVERSARIAL TESTS — Sprint S34
// ────────────────────────────────────────────────────────────
//
// These tests verify that the 5-layer ComplianceGuard catches all
// adversarial patterns before LLM output reaches the user.
//
// Layers tested:
//   1. Banned terms (French + variants + word-boundary CRIT #5)
//   2. Prescriptive language (imperative financial instructions)
//   3. Hallucination detection (fabricated numbers)
//   4. Disclaimer injection (projections/simulations)
//   5. Length constraints (per component type)
//
// References: LSFin art. 3/8, FINMA circular 2008/21
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // Layer 1: Banned terms
  // ═══════════════════════════════════════════════════════════

  group('Layer 1 — Banned terms', () {
    test('catches "garanti" and sanitizes it', () {
      final result = ComplianceGuard.validate(
        'Ce rendement est garanti à 5% par an.',
      );
      expect(result.violations, anyElement(contains('garanti')));
      expect(result.sanitizedText.toLowerCase(), isNot(contains('garanti')));
    });

    test('catches "certain" in LLM output', () {
      final result = ComplianceGuard.validate(
        'Il est certain que tu vas économiser CHF 3000.',
      );
      expect(result.violations, anyElement(contains('certain')));
    });

    test('catches "assuré" as banned term', () {
      final result = ComplianceGuard.validate(
        'Ton capital est assuré contre les pertes.',
      );
      expect(result.violations, anyElement(contains('assuré')));
    });

    test('catches "sans risque" in various forms', () {
      final result = ComplianceGuard.validate(
        'Cet investissement est sans risque.',
      );
      expect(result.violations, anyElement(contains('sans risque')));
    });

    test('catches "optimal" as banned absolute', () {
      final result = ComplianceGuard.validate(
        'C\'est le choix optimal pour ta situation.',
      );
      expect(result.violations, anyElement(contains('optimal')));
    });

    test('catches "meilleur" as banned absolute', () {
      final result = ComplianceGuard.validate(
        'C\'est le meilleur placement pour toi.',
      );
      expect(result.violations, anyElement(contains('meilleur')));
    });

    test('catches "parfait" as banned absolute', () {
      final result = ComplianceGuard.validate(
        'Cette stratégie est parfait pour un couple.',
      );
      expect(result.violations, anyElement(contains('parfait')));
    });

    test('catches "conseiller" → should use "spécialiste"', () {
      final result = ComplianceGuard.validate(
        'Tu devrais demander à un conseiller financier.',
      );
      expect(result.violations, anyElement(contains('conseiller')));
    });

    test('triggers fallback when >2 banned terms found', () {
      final result = ComplianceGuard.validate(
        'C\'est garanti, certain, et parfait pour toi.',
      );
      expect(result.useFallback, isTrue);
      expect(result.violations.length, greaterThanOrEqualTo(3));
    });

    test('sanitizes ≤2 banned terms without fallback', () {
      final result = ComplianceGuard.validate(
        'C\'est une option adaptée. Le rendement est garanti.',
      );
      expect(result.useFallback, isFalse);
      expect(result.sanitizedText.toLowerCase(), isNot(contains('garanti')));
    });

    test('catches case-insensitive "GARANTI"', () {
      final result = ComplianceGuard.validate(
        'Le retour est GARANTI par la banque.',
      );
      expect(result.violations, anyElement(contains('garanti')));
    });

    test('catches "tu devrais" prescriptive phrasing', () {
      final result = ComplianceGuard.validate(
        'Tu devrais investir dans un 3a.',
      );
      expect(result.violations, isNotEmpty);
    });

    test('catches "nous recommandons"', () {
      final result = ComplianceGuard.validate(
        'Nous recommandons un rachat LPP cette année.',
      );
      expect(result.violations, isNotEmpty);
    });

    test('catches fuzzy "sans aucun risque" variant', () {
      final result = ComplianceGuard.validate(
        'Cet investissement est sans aucun risque.',
      );
      expect(result.violations, anyElement(contains('sans risque')));
    });

    test('clean text passes without violations', () {
      final result = ComplianceGuard.validate(
        'Ton score de solidité est de 62/100. Continue à affiner ton profil.',
      );
      expect(result.isCompliant, isTrue);
      expect(result.violations, isEmpty);
      expect(result.useFallback, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 1b: Word-boundary false positives (CRIT #5)
  // ═══════════════════════════════════════════════════════════

  group('Layer 1b — Word-boundary false positives (CRIT #5)', () {
    test('"incertain" does NOT trigger "certain" ban', () {
      final result = ComplianceGuard.validate(
        'L\'avenir est incertain, donc diversifie ton approche.',
      );
      final certainViolations = result.violations
          .where((v) => v.contains("'certain'"))
          .toList();
      expect(certainViolations, isEmpty);
    });

    test('"certains" does NOT trigger "certain" ban', () {
      final result = ComplianceGuard.validate(
        'Certains scénarios montrent une amélioration.',
      );
      final certainViolations = result.violations
          .where((v) => v.contains("'certain'"))
          .toList();
      expect(certainViolations, isEmpty);
    });

    test('"parfaitement" does NOT trigger "parfait" ban', () {
      final result = ComplianceGuard.validate(
        'Tu as parfaitement rempli ton profil.',
      );
      final parfaitViolations = result.violations
          .where((v) => v.contains("'parfait'"))
          .toList();
      expect(parfaitViolations, isEmpty);
    });

    test('"assurément" does NOT trigger "assuré" ban', () {
      final result = ComplianceGuard.validate(
        'Ton profil est assurément complet.',
      );
      final assureViolations = result.violations
          .where((v) => v.contains("'assuré'"))
          .toList();
      expect(assureViolations, isEmpty);
    });

    test('"optimale" triggers ban (feminine form added)', () {
      final result = ComplianceGuard.validate(
        'C\'est une approche optimale pour ta situation.',
      );
      expect(result.violations, anyElement(contains('optimale')));
    });

    test('exact "certain" still triggers the ban', () {
      final result = ComplianceGuard.validate(
        'Il est certain que ton capital augmentera.',
      );
      expect(result.violations, anyElement(contains('certain')));
    });

    test('exact "parfait" still triggers the ban', () {
      final result = ComplianceGuard.validate(
        'Ce plan est parfait.',
      );
      expect(result.violations, anyElement(contains('parfait')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 1c: Feminine forms (HIGH audit finding)
  // ═══════════════════════════════════════════════════════════

  group('Layer 1c — Feminine forms', () {
    test('catches "conseillère" (feminine of conseiller)', () {
      final result = ComplianceGuard.validate(
        'Demande à une conseillère financière.',
      );
      expect(result.violations, anyElement(contains('conseillère')));
    });

    test('catches "garantie" (feminine of garanti)', () {
      final result = ComplianceGuard.validate(
        'La performance garantie est de 2%.',
      );
      expect(result.violations, anyElement(contains('garantie')));
    });

    test('catches "assurée" (feminine of assuré)', () {
      final result = ComplianceGuard.validate(
        'Ta rente est assurée par la loi.',
      );
      expect(result.violations, anyElement(contains('assurée')));
    });

    test('catches "meilleure" (feminine of meilleur)', () {
      final result = ComplianceGuard.validate(
        'C\'est la meilleure stratégie.',
      );
      expect(result.violations, anyElement(contains('meilleure')));
    });

    test('catches "parfaite" (feminine of parfait)', () {
      final result = ComplianceGuard.validate(
        'Une solution parfaite pour toi.',
      );
      expect(result.violations, anyElement(contains('parfaite')));
    });

    test('"assuré" with accent is still caught (regression test)', () {
      // Critical: \b in JS/Dart regex treats é as \W, so \bassuré\b
      // would never match. French-aware boundaries fix this.
      final result = ComplianceGuard.validate(
        'Ton capital est assuré contre les pertes.',
      );
      expect(result.violations, anyElement(contains('assuré')));
    });

    test('sanitizes feminine form "garantie" → "possible dans ce scénario"', () {
      final result = ComplianceGuard.validate(
        'La performance garantie est intéressante.',
      );
      expect(result.sanitizedText.toLowerCase(), isNot(contains('garantie')));
      expect(result.sanitizedText.toLowerCase(), contains('possible'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 2: Prescriptive language
  // ═══════════════════════════════════════════════════════════

  group('Layer 2 — Prescriptive language', () {
    test('catches "fais un rachat"', () {
      final result = ComplianceGuard.validate(
        'Fais un rachat LPP de CHF 15000 cette année.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "verse sur ton"', () {
      final result = ComplianceGuard.validate(
        'Verse sur ton 3a le maximum cette année.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "achète" imperative', () {
      final result = ComplianceGuard.validate(
        'Achète un bien immobilier dans le canton de Vaud.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "vends" imperative', () {
      final result = ComplianceGuard.validate(
        'Vends tes actions avant la fin du trimestre.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "choisis la rente"', () {
      final result = ComplianceGuard.validate(
        'Choisis la rente plutôt que le capital.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "prends le capital"', () {
      final result = ComplianceGuard.validate(
        'Prends le capital, c\'est plus avantageux.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "investis dans"', () {
      final result = ComplianceGuard.validate(
        'Investis dans un fonds indiciel suisse.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "priorité absolue"', () {
      final result = ComplianceGuard.validate(
        'Rembourser ta dette est une priorité absolue.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('educational phrasing passes', () {
      final result = ComplianceGuard.validate(
        'Tu pourrais envisager un rachat LPP (LPP art. 79b). '
        'Simule l\'impact sur ton profil.',
      );
      // Should NOT trigger prescriptive violation
      final prescriptive = result.violations
          .where((v) => v.contains('prescriptif'))
          .toList();
      expect(prescriptive, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 3: Hallucination detection
  // ═══════════════════════════════════════════════════════════

  group('Layer 3 — Hallucination detection', () {
    final ctx = const CoachContext(
      firstName: 'Julien',
      age: 35,
      canton: 'VD',
      knownValues: {
        'fri_total': 62.0,
        'capital_final': 450000.0,
        'replacement_ratio': 58.0,
        'epargne_3a': 25000.0,
      },
    );

    test('detects fabricated CHF amount', () {
      final result = ComplianceGuard.validate(
        'Ton capital projeté est de CHF 900000 à la retraite.',
        context: ctx,
      );
      expect(result.violations, anyElement(contains('Hallucination')));
      expect(result.useFallback, isTrue);
    });

    test('detects fabricated percentage', () {
      final result = ComplianceGuard.validate(
        'Ton taux de remplacement est de 85.0% — très bon.',
        context: ctx,
      );
      expect(result.violations, anyElement(contains('Hallucination')));
      expect(result.useFallback, isTrue);
    });

    test('detects fabricated score', () {
      // Use a context where fri_total is closer to 95 so it passes
      // relevance check (|95-70|=25 < 30pt threshold) but still triggers
      // hallucination (|95-70|=25 > 2pt tolerance).
      final scoreCtx = const CoachContext(
        firstName: 'Julien',
        age: 35,
        canton: 'VD',
        knownValues: {
          'fri_total': 70.0,
          'capital_final': 450000.0,
          'replacement_ratio': 58.0,
          'epargne_3a': 25000.0,
        },
      );
      final result = ComplianceGuard.validate(
        'Ton score de solidité est de 95/100. Excellent.',
        context: scoreCtx,
      );
      expect(result.violations, anyElement(contains('Hallucination')));
      expect(result.useFallback, isTrue);
    });

    test('accepts correct CHF amount within tolerance', () {
      // 450000 ± 5% = 427500-472500
      final result = ComplianceGuard.validate(
        'Ton capital projeté est d\'environ CHF 450000.',
        context: ctx,
      );
      final hallucinations = result.violations
          .where((v) => v.contains('Hallucination'))
          .toList();
      expect(hallucinations, isEmpty);
    });

    test('accepts correct percentage within tolerance', () {
      // 58% ± 2pt = 56-60
      final result = ComplianceGuard.validate(
        'Ton taux de remplacement estimé est de 58.0%.',
        context: ctx,
      );
      final hallucinations = result.violations
          .where((v) => v.contains('Hallucination'))
          .toList();
      expect(hallucinations, isEmpty);
    });

    test('no hallucination check without context', () {
      final result = ComplianceGuard.validate(
        'Ton capital projeté est de CHF 999999.',
      );
      final hallucinations = result.violations
          .where((v) => v.contains('Hallucination'))
          .toList();
      expect(hallucinations, isEmpty);
    });

    // CRIT #2: legal constants are whitelisted
    test('CHF 7258 is not flagged (legal constant whitelist)', () {
      final result = ComplianceGuard.validate(
        'Le plafond 3a est de CHF 7258 par an.',
        context: ctx,
      );
      final hallucinations = result.violations
          .where((v) => v.contains('Hallucination') && v.contains('7258'))
          .toList();
      expect(hallucinations, isEmpty);
    });

    test('6.8% is not flagged (taux conversion LPP)', () {
      final result = ComplianceGuard.validate(
        'Le taux de conversion LPP est de 6.8%.',
        context: ctx,
      );
      final hallucinations = result.violations
          .where((v) => v.contains('Hallucination') && v.contains('6.8'))
          .toList();
      expect(hallucinations, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 4: Disclaimer injection
  // ═══════════════════════════════════════════════════════════

  group('Layer 4 — Disclaimer injection', () {
    test('injects disclaimer when discussing projections', () {
      final result = ComplianceGuard.validate(
        'Ta projection montre un capital de CHF 450000.',
        context: const CoachContext(
          knownValues: {'capital_final': 450000.0},
        ),
      );
      expect(result.sanitizedText.toLowerCase(), contains('outil éducatif'));
    });

    test('injects disclaimer when discussing retraite', () {
      final result = ComplianceGuard.validate(
        'À la retraite, tu recevras une rente mensuelle.',
      );
      expect(result.sanitizedText.toLowerCase(),
          anyOf(contains('outil éducatif'), contains('lsfin')));
    });

    test('does not double-inject disclaimer', () {
      const text = 'Ta projection montre un capital intéressant. '
          'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin).';
      final result = ComplianceGuard.validate(text);
      // Count occurrences of "outil éducatif"
      final matches = 'outil éducatif'
          .allMatches(result.sanitizedText.toLowerCase())
          .length;
      expect(matches, equals(1));
    });

    test('no disclaimer for non-projection text', () {
      final result = ComplianceGuard.validate(
        'Ton score de solidité est de 62/100.',
        context: const CoachContext(knownValues: {'fri_total': 62.0}),
      );
      // "score" alone shouldn't trigger disclaimer (no projection keywords)
      expect(result.isCompliant, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 5: Length constraints
  // ═══════════════════════════════════════════════════════════

  group('Layer 5 — Length constraints', () {
    test('truncates greeting over 30 words', () {
      final longGreeting = List.generate(50, (i) => 'mot$i').join(' ');
      final result = ComplianceGuard.validate(
        longGreeting,
        componentType: ComponentType.greeting,
      );
      final wordCount = result.sanitizedText.split(RegExp(r'\s+')).length;
      expect(wordCount, lessThanOrEqualTo(30));
    });

    test('truncates scoreSummary over 80 words', () {
      final longSummary = List.generate(100, (i) => 'mot$i').join(' ');
      final result = ComplianceGuard.validate(
        longSummary,
        componentType: ComponentType.scoreSummary,
      );
      final wordCount = result.sanitizedText.split(RegExp(r'\s+')).length;
      expect(wordCount, lessThanOrEqualTo(80));
    });

    test('accepts text within word limit', () {
      final result = ComplianceGuard.validate(
        'Salut Julien. Ton score est stable.',
        componentType: ComponentType.greeting,
      );
      expect(result.violations.where((v) => v.contains('trop long')), isEmpty);
    });

    test('reports length violation in violations list', () {
      final longText = List.generate(250, (i) => 'mot$i').join(' ');
      final result = ComplianceGuard.validate(
        longText,
        componentType: ComponentType.general,
      );
      expect(result.violations, anyElement(contains('trop long')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Pre-checks
  // ═══════════════════════════════════════════════════════════

  group('Pre-checks', () {
    test('empty output triggers fallback', () {
      final result = ComplianceGuard.validate('');
      expect(result.useFallback, isTrue);
      expect(result.violations, anyElement(contains('vide')));
    });

    test('whitespace-only output triggers fallback', () {
      final result = ComplianceGuard.validate('   \n  \t  ');
      expect(result.useFallback, isTrue);
    });

    test('English text triggers language violation', () {
      final result = ComplianceGuard.validate(
        'You should invest your money with this strategy. '
        'The returns would be excellent.',
      );
      expect(result.violations, anyElement(contains('anglais')));
      expect(result.useFallback, isTrue);
    });

    test('French text passes language check', () {
      final result = ComplianceGuard.validate(
        'Ton profil est bien rempli. Continue à explorer les simulateurs.',
      );
      final langViolations = result.violations
          .where((v) => v.contains('anglais'))
          .toList();
      expect(langViolations, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Combined adversarial scenarios
  // ═══════════════════════════════════════════════════════════

  group('Combined adversarial scenarios', () {
    test('multiple violations: banned + prescriptive + hallucination', () {
      final ctx = const CoachContext(
        knownValues: {'capital_final': 300000.0},
      );
      final result = ComplianceGuard.validate(
        'C\'est garanti ! Fais un rachat LPP. '
        'Ton capital sera de CHF 800000.',
        context: ctx,
      );
      expect(result.useFallback, isTrue);
      expect(result.violations.length, greaterThanOrEqualTo(2));
    });

    test('injection attempt: banned term inside HTML', () {
      final result = ComplianceGuard.validate(
        'C\'est un choix <b>garanti</b> pour ta situation.',
      );
      expect(result.violations, anyElement(contains('garanti')));
    });

    test('injection attempt: unicode obfuscation', () {
      // Test that basic obfuscation doesn't bypass the guard
      final result = ComplianceGuard.validate(
        'C\'est un choix optimal pour maximiser ton rendement.',
      );
      expect(result.violations, anyElement(contains('optimal')));
    });

    test('fully compliant output passes all layers', () {
      final ctx = const CoachContext(
        firstName: 'Julien',
        knownValues: {'fri_total': 62.0},
      );
      final result = ComplianceGuard.validate(
        'Julien, ton score de solidité est de 62/100. '
        'Continue à affiner ton profil pour des estimations plus précises.',
        context: ctx,
        componentType: ComponentType.scoreSummary,
      );
      expect(result.isCompliant, isTrue);
      expect(result.useFallback, isFalse);
      expect(result.violations, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 1d: Plural banned terms (GAP #1 coverage)
  // ═══════════════════════════════════════════════════════════

  group('Layer 1d — Plural banned terms', () {
    test('catches "garantis" (masculine plural)', () {
      final result = ComplianceGuard.validate(
        'Les rendements garantis sont impossibles.',
      );
      expect(result.violations, anyElement(contains('garantis')));
    });

    test('catches "garanties" (feminine plural)', () {
      final result = ComplianceGuard.validate(
        'Ces valeurs garanties ne sont pas réalistes.',
      );
      expect(result.violations, anyElement(contains('garanties')));
    });

    test('catches "assurés" (masculine plural)', () {
      final result = ComplianceGuard.validate(
        'Les placements assurés n\'existent pas.',
      );
      expect(result.violations, anyElement(contains('assurés')));
    });

    test('catches "assurées" (feminine plural)', () {
      final result = ComplianceGuard.validate(
        'Les performances assurées augmentent.',
      );
      expect(result.violations, anyElement(contains('assurées')));
    });

    test('catches "optimaux" (masculine plural)', () {
      final result = ComplianceGuard.validate(
        'Les résultats optimaux varient.',
      );
      expect(result.violations, anyElement(contains('optimaux')));
    });

    test('catches "optimales" (feminine plural)', () {
      final result = ComplianceGuard.validate(
        'Les solutions optimales dépendent.',
      );
      expect(result.violations, anyElement(contains('optimales')));
    });

    test('catches "meilleurs" (masculine plural)', () {
      final result = ComplianceGuard.validate(
        'Les meilleurs rendements fluctuent.',
      );
      expect(result.violations, anyElement(contains('meilleurs')));
    });

    test('catches "meilleures" (feminine plural)', () {
      final result = ComplianceGuard.validate(
        'Les meilleures performances changent.',
      );
      expect(result.violations, anyElement(contains('meilleures')));
    });

    test('catches "parfaits" (masculine plural)', () {
      final result = ComplianceGuard.validate(
        'Les placements parfaits n\'existent pas.',
      );
      expect(result.violations, anyElement(contains('parfaits')));
    });

    test('catches "parfaites" (feminine plural)', () {
      final result = ComplianceGuard.validate(
        'Les conditions parfaites sont rares.',
      );
      expect(result.violations, anyElement(contains('parfaites')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Layer 2b: Social comparison patterns (GAP #2 coverage)
  // ═══════════════════════════════════════════════════════════

  group('Layer 2b — Social comparison patterns', () {
    test('catches "top 10%" ranking', () {
      final result = ComplianceGuard.validate(
        'Tu es dans le top 10% des épargnants.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "meilleur que 80%" comparison', () {
      final result = ComplianceGuard.validate(
        'Tu es meilleur que 80% des Suisses.',
      );
      expect(result.violations, isNotEmpty);
    });

    test('catches "devant 60% des" ranking', () {
      final result = ComplianceGuard.validate(
        'Tu es devant 60% des investisseurs.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });

    test('catches "parmi les meilleurs" comparison', () {
      final result = ComplianceGuard.validate(
        'Tu es parmi les meilleurs épargnants.',
      );
      // Caught by banned term "meilleurs" and/or prescriptive pattern
      expect(result.isCompliant, isFalse);
      expect(result.violations, isNotEmpty);
    });

    test('catches "au-dessus de la moyenne" comparison', () {
      final result = ComplianceGuard.validate(
        'Ton score est au-dessus de la moyenne.',
      );
      expect(result.violations, anyElement(contains('prescriptif')));
      expect(result.useFallback, isTrue);
    });
  });
}
