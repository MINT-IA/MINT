import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/prompt_registry.dart';

// ────────────────────────────────────────────────────────────
//  PROMPT REGISTRY TESTS — Sprint S34 / LLM Prompts
// ────────────────────────────────────────────────────────────
//
// Tests cover:
//   1. version is a valid semver string
//   2. baseSystemPrompt contains all mandatory compliance rules
//   3. baseSystemPrompt lists all banned terms
//   4. dashboardGreeting includes user context
//   5. scoreSummary includes FRI score and delta
//   6. dailyTip includes fiscal season
//   7. chiffreChocNarrative includes confidence score
//   8. scenarioNarration includes known values
//   9. getPrompt() dispatches all component types correctly
//  10. getPrompt() returns baseSystemPrompt for unknown type
//  11. enrichmentGuide includes block-specific context
//  12. enrichmentGuide with blockType='lpp' includes salary data
//  13. COMPLIANCE: all prompts contain conditional language rules
//  14. COMPLIANCE: all prompts contain "JAMAIS" (never) rules
// ────────────────────────────────────────────────────────────

/// Helper to build a CoachContext for prompt testing.
CoachContext _ctx({
  String firstName = 'Julien',
  double friTotal = 72,
  double friDelta = 3,
  String primaryFocus = 'retirement',
  int daysSinceLastVisit = 5,
  String fiscalSeason = '3a_deadline',
  double confidenceScore = 85,
  Map<String, double> knownValues = const {},
  Map<String, String> dataReliability = const {},
  int age = 49,
  String canton = 'VS',
  String archetype = 'swiss_native',
}) {
  return CoachContext(
    firstName: firstName,
    friTotal: friTotal,
    friDelta: friDelta,
    primaryFocus: primaryFocus,
    daysSinceLastVisit: daysSinceLastVisit,
    fiscalSeason: fiscalSeason,
    confidenceScore: confidenceScore,
    knownValues: knownValues,
    dataReliability: dataReliability,
    age: age,
    canton: canton,
    archetype: archetype,
  );
}

void main() {
  group('PromptRegistry', () {
    // ═══════════════════════════════════════════════════════════
    // VERSION
    // ═══════════════════════════════════════════════════════════

    test('version is a valid semver string', () {
      expect(PromptRegistry.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    // ═══════════════════════════════════════════════════════════
    // BASE SYSTEM PROMPT — COMPLIANCE
    // ═══════════════════════════════════════════════════════════

    test('baseSystemPrompt contains mandatory compliance rules', () {
      final prompt = PromptRegistry.baseSystemPrompt;

      // Must mention "JAMAIS" (never) for advice prohibition
      expect(prompt, contains('JAMAIS'));
      // Must enforce conditional language
      expect(prompt, contains('conditionnel'));
      expect(prompt, contains('pourrait'));
      // Must prohibit comparison with others
      expect(prompt, contains('JAMAIS'));
      // Must mention uncertainty
      expect(prompt, contains('incertitude'));
      // Must use "tu" (informal)
      expect(prompt, contains('tutoies'));
    });

    test('baseSystemPrompt lists all banned terms', () {
      final prompt = PromptRegistry.baseSystemPrompt;

      for (final term in [
        'garanti',
        'certain',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
      ]) {
        expect(
          prompt.contains(term),
          isTrue,
          reason: 'Banned term "$term" must be listed in baseSystemPrompt',
        );
      }
      // "conseiller" must be banned with alternative
      expect(prompt, contains('conseiller'));
      expect(prompt, contains('sp\u00e9cialiste'));
    });

    test('baseSystemPrompt prohibits inventing numbers', () {
      final prompt = PromptRegistry.baseSystemPrompt;
      expect(prompt, contains('inventer'));
    });

    // ═══════════════════════════════════════════════════════════
    // COMPONENT PROMPTS
    // ═══════════════════════════════════════════════════════════

    test('dashboardGreeting includes user context fields', () {
      final ctx = _ctx(
        firstName: 'Lauren',
        friTotal: 60,
        friDelta: -2,
        daysSinceLastVisit: 14,
        fiscalSeason: '3a_deadline',
      );
      final prompt = PromptRegistry.dashboardGreeting(ctx);

      expect(prompt, contains('Lauren'));
      expect(prompt, contains('60/100'));
      expect(prompt, contains('-2'));
      expect(prompt, contains('14'));
      expect(prompt, contains('3a_deadline'));
      // Includes base system prompt
      expect(prompt, contains('MINT'));
    });

    test('scoreSummary includes FRI score and delta', () {
      final ctx = _ctx(friTotal: 72, friDelta: 5);
      final prompt = PromptRegistry.scoreSummary(ctx);

      expect(prompt, contains('72/100'));
      expect(prompt, contains('+5'));
    });

    test('scoreSummary handles negative delta with sign', () {
      final ctx = _ctx(friTotal: 65, friDelta: -3);
      final prompt = PromptRegistry.scoreSummary(ctx);

      expect(prompt, contains('-3'));
    });

    test('dailyTip includes fiscal season and priority', () {
      final ctx = _ctx(
        primaryFocus: 'tax_optimization',
        fiscalSeason: 'tax_declaration',
      );
      final prompt = PromptRegistry.dailyTip(ctx);

      expect(prompt, contains('tax_optimization'));
      expect(prompt, contains('tax_declaration'));
    });

    test('chiffreChocNarrative includes confidence score', () {
      final ctx = _ctx(
        knownValues: {
          'confidence_score': 85,
          'chiffre_choc_value': 45000,
        },
      );
      final prompt = PromptRegistry.chiffreChocNarrative(ctx);

      expect(prompt, contains('85'));
      expect(prompt, contains('45000'));
    });

    test('scenarioNarration includes known values', () {
      final ctx = _ctx(
        primaryFocus: 'rente_vs_capital',
        knownValues: {'capital_final': 500000},
      );
      final prompt = PromptRegistry.scenarioNarration(ctx);

      expect(prompt, contains('rente_vs_capital'));
      expect(prompt, contains('500000'));
    });

    // ═══════════════════════════════════════════════════════════
    // ENRICHMENT GUIDE
    // ═══════════════════════════════════════════════════════════

    test('enrichmentGuide with lpp block includes salary data', () {
      final ctx = _ctx(
        knownValues: {'salaire_brut': 122207, 'avoir_lpp': 70377},
        dataReliability: {'avoirLpp': 'estimated'},
      );
      final prompt = PromptRegistry.enrichmentGuide(ctx, 'lpp');

      expect(prompt, contains('lpp'));
      expect(prompt, contains('122207'));
      expect(prompt, contains('estimated'));
    });

    test('enrichmentGuide with avs block includes archetype', () {
      final ctx = _ctx(archetype: 'expat_eu');
      final prompt = PromptRegistry.enrichmentGuide(ctx, 'avs');

      expect(prompt, contains('expat_eu'));
    });

    test('enrichmentGuide with 3a block includes 3a constants', () {
      final ctx = _ctx(knownValues: {'epargne_3a': 15000});
      final prompt = PromptRegistry.enrichmentGuide(ctx, '3a');

      expect(prompt, contains('15000'));
      // Should contain the pillar 3a ceiling
      expect(prompt, contains('7258'));
    });

    test('enrichmentGuide with unknown block gives generic context', () {
      final ctx = _ctx();
      final prompt = PromptRegistry.enrichmentGuide(ctx, 'unknown_block');

      expect(prompt, contains('unknown_block'));
      expect(prompt, contains('confiance'));
    });

    // ═══════════════════════════════════════════════════════════
    // getPrompt() DISPATCH
    // ═══════════════════════════════════════════════════════════

    test('getPrompt() dispatches all known component types', () {
      final ctx = _ctx();

      // Each should return a non-empty prompt containing base system prompt
      final types = [
        'greeting',
        'score_summary',
        'tip',
        'chiffre_choc',
        'scenario',
      ];

      for (final type in types) {
        final prompt = PromptRegistry.getPrompt(type, ctx);
        expect(
          prompt.contains('MINT'),
          isTrue,
          reason: 'getPrompt("$type") should include base system prompt',
        );
        expect(
          prompt.length > PromptRegistry.baseSystemPrompt.length,
          isTrue,
          reason: 'getPrompt("$type") should add context beyond base prompt',
        );
      }
    });

    test('getPrompt("enrichment_guide") uses blockType parameter', () {
      final ctx = _ctx();
      final prompt = PromptRegistry.getPrompt(
        'enrichment_guide',
        ctx,
        blockType: 'lpp',
      );
      expect(prompt, contains('lpp'));
      expect(prompt, contains('certificat'));
    });

    test('getPrompt("enrichment_guide") defaults to "general" block', () {
      final ctx = _ctx();
      final prompt = PromptRegistry.getPrompt('enrichment_guide', ctx);
      // Should not crash, uses 'general' as fallback blockType
      expect(prompt, contains('confiance'));
    });

    test('getPrompt() returns baseSystemPrompt for unknown type', () {
      final ctx = _ctx();
      final prompt = PromptRegistry.getPrompt('nonexistent_type', ctx);

      expect(prompt, PromptRegistry.baseSystemPrompt);
    });

    // ═══════════════════════════════════════════════════════════
    // COMPLIANCE: ALL PROMPTS INCLUDE SAFETY RULES
    // ═══════════════════════════════════════════════════════════

    test('all component prompts include base system prompt compliance', () {
      final ctx = _ctx();

      final prompts = [
        PromptRegistry.dashboardGreeting(ctx),
        PromptRegistry.scoreSummary(ctx),
        PromptRegistry.dailyTip(ctx),
        PromptRegistry.chiffreChocNarrative(ctx),
        PromptRegistry.scenarioNarration(ctx),
        PromptRegistry.enrichmentGuide(ctx, 'lpp'),
      ];

      for (final prompt in prompts) {
        expect(prompt, contains('JAMAIS'));
        expect(prompt, contains('conditionnel'));
        expect(prompt, contains('garanti'));
      }
    });
  });
}
