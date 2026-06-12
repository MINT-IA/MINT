/// Coach Orchestrator Tests — Sprint S44 (Intelligence Branchement).
///
/// Tests cover:
///   1.  Fallback chain: SLM skipped when slmPluginReady=false
///   2.  Fallback chain: BYOK skipped when no apiKey
///   3.  Fallback chain: templates used when both SLM and BYOK unavailable
///   4.  Fallback chain: safeModeDegraded skips SLM and BYOK
///   5.  ComplianceGuard: termes interdits bloqués dans le résultat final
///   6.  ComplianceGuard: termes interdits bloqués dans chat response
///   7.  Termes interdits: "garanti" → jamais dans output
///   8.  Termes interdits: "optimal" → jamais dans output
///   9.  Termes interdits: "meilleur" → jamais dans output
///  10.  Mode avion: BYOK absent + SLM non dispo → templates toujours retournés
///  11.  CoachTier.fallback retourné quand SLM et BYOK désactivés
///  12.  Greeting contient le prénom de l'utilisateur
///  13.  OrchestratorOutput.text n'est jamais vide (resilience)
///  14.  generateChat retourne un CoachResponse valide en mode offline
///  15.  generateNarrativeComponent pour tous les ComponentType (smoke test)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────

/// Minimal CoachContext for tests — SLM and BYOK disabled by default.
CoachContext _ctx({
  String firstName = 'Julien',
  int age = 50,
  double friTotal = 62,
  double friDelta = 5,
  Map<String, double>? knownValues,
}) {
  return CoachContext(
    firstName: firstName,
    age: age,
    canton: 'ZH',
    archetype: 'swiss_native',
    friTotal: friTotal,
    friDelta: friDelta,
    knownValues:
        knownValues ?? const {'fri_total': 62, 'capital_final': 850000},
  );
}

/// Reset FeatureFlags to a deterministic state before each test.
void _resetFlags({
  bool slmPluginReady = false,
  bool enableSlmNarratives = false,
  bool safeModeDegraded = false,
}) {
  FeatureFlags.slmPluginReady = slmPluginReady;
  FeatureFlags.enableSlmNarratives = enableSlmNarratives;
  FeatureFlags.safeModeDegraded = safeModeDegraded;
}

// ─────────────────────────────────────────────────────────────────
//  TESTS
// ─────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Default: SLM and BYOK both disabled → pure template mode.
    _resetFlags();
  });

  // ═══════════════════════════════════════════════════════════════
  //  1. SLM skipped when slmPluginReady=false
  // ═══════════════════════════════════════════════════════════════

  test('1. SLM skipped (slmPluginReady=false) → tier is fallback', () async {
    _resetFlags(slmPluginReady: false, enableSlmNarratives: true);
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
    );

    // SLM not ready → must use template tier.
    expect(out.tier, CoachTier.fallback);
    expect(out.text, isNotEmpty);
  });

  // ═══════════════════════════════════════════════════════════════
  //  2. BYOK skipped when no apiKey
  // ═══════════════════════════════════════════════════════════════

  test('2. BYOK skipped (no apiKey) → tier is fallback', () async {
    _resetFlags();
    final ctx = _ctx();
    // byokConfig with empty apiKey
    const byokConfig = LlmConfig(
      apiKey: '',
      provider: LlmProvider.openai,
    );

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: ctx,
      byokConfig: byokConfig,
    );

    expect(out.tier, CoachTier.fallback);
    expect(out.text, isNotEmpty);
  });

  // ═══════════════════════════════════════════════════════════════
  //  3. Templates used when SLM and BYOK unavailable
  // ═══════════════════════════════════════════════════════════════

  test('3. Templates used when SLM and BYOK both unavailable', () async {
    _resetFlags();
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.scoreSummary,
      ctx: ctx,
      byokConfig: null,
    );

    expect(out.tier, CoachTier.fallback);
    expect(out.text, isNotEmpty);
    // Score summary should reference the score value.
    expect(out.text, contains('62'));
  });

  // ═══════════════════════════════════════════════════════════════
  //  4. safeModeDegraded skips SLM and BYOK
  // ═══════════════════════════════════════════════════════════════

  test('4. safeModeDegraded=true forces fallback tier', () async {
    _resetFlags(
      slmPluginReady: true,
      enableSlmNarratives: true,
      safeModeDegraded: true,
    );
    final ctx = _ctx();
    const byokConfig = LlmConfig(
      apiKey: 'sk-any-key',
      provider: LlmProvider.openai,
    );

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
      byokConfig: byokConfig,
    );

    // safeModeDegraded disables both SLM and BYOK.
    expect(out.tier, CoachTier.fallback);
    expect(out.text, isNotEmpty);
  });

  // ═══════════════════════════════════════════════════════════════
  //  5. ComplianceGuard: termes interdits bloqués dans narratif
  // ═══════════════════════════════════════════════════════════════

  test('5. ComplianceGuard blocks banned terms in narrative output', () async {
    _resetFlags();
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: ctx,
    );

    // None of the banned terms should appear in the final output.
    for (final term in ComplianceGuard.bannedTerms) {
      final pattern = RegExp(
        '(?<![a-zA-ZÀ-ÿ])${RegExp.escape(term)}(?![a-zA-ZÀ-ÿ])',
        caseSensitive: false,
      );
      expect(
        pattern.hasMatch(out.text),
        isFalse,
        reason: 'Terme interdit "$term" trouvé dans la sortie',
      );
    }
  });

  // ═══════════════════════════════════════════════════════════════
  //  6. ComplianceGuard: termes interdits bloqués dans chat
  // ═══════════════════════════════════════════════════════════════

  test('6. ComplianceGuard blocks banned terms in chat output', () async {
    _resetFlags();
    final ctx = _ctx();

    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Comment optimiser ma retraite?',
      history: const [],
      ctx: ctx,
    );

    for (final term in ComplianceGuard.bannedTerms) {
      final pattern = RegExp(
        '(?<![a-zA-ZÀ-ÿ])${RegExp.escape(term)}(?![a-zA-ZÀ-ÿ])',
        caseSensitive: false,
      );
      expect(
        pattern.hasMatch(response.message),
        isFalse,
        reason: 'Terme interdit "$term" trouvé dans le chat output',
      );
    }
  });

  // ═══════════════════════════════════════════════════════════════
  //  7. "garanti" jamais dans output
  // ═══════════════════════════════════════════════════════════════

  test('7. "garanti" jamais dans la sortie narrative', () async {
    _resetFlags();
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
    );

    expect(
      out.text.toLowerCase().contains('garanti'),
      isFalse,
      reason: 'Le terme "garanti" est interdit dans tout output coach',
    );
  });

  // ═══════════════════════════════════════════════════════════════
  //  8. "optimal" jamais dans output
  // ═══════════════════════════════════════════════════════════════

  test('8. "optimal" jamais dans la sortie narrative', () async {
    _resetFlags();
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: ctx,
    );

    expect(
      out.text.toLowerCase().contains('optimal'),
      isFalse,
      reason: 'Le terme "optimal" est interdit dans tout output coach',
    );
  });

  // ═══════════════════════════════════════════════════════════════
  //  9. "meilleur" jamais dans output
  // ═══════════════════════════════════════════════════════════════

  test('9. "meilleur" jamais dans la sortie narrative', () async {
    _resetFlags();
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.scoreSummary,
      ctx: ctx,
    );

    expect(
      out.text.toLowerCase().contains('meilleur'),
      isFalse,
      reason: 'Le terme "meilleur" est interdit dans tout output coach',
    );
  });

  // ═══════════════════════════════════════════════════════════════
  //  10. Mode avion: templates toujours retournés
  // ═══════════════════════════════════════════════════════════════

  test('10. Mode avion: templates retournés même sans réseau', () async {
    // Simulate offline: SLM not ready, no BYOK key.
    _resetFlags(slmPluginReady: false, enableSlmNarratives: false);
    final ctx = _ctx();

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.premierEclairage,
      ctx: ctx,
      byokConfig: null,
    );

    expect(out.text, isNotEmpty);
    expect(out.tier, CoachTier.fallback);
  });

  // ═══════════════════════════════════════════════════════════════
  //  11. CoachTier.fallback retourné correctement
  // ═══════════════════════════════════════════════════════════════

  test('11. Tier est fallback quand SLM et BYOK désactivés', () async {
    _resetFlags();
    final ctx = _ctx();

    final greetingOut = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
    );
    final tipOut = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: ctx,
    );

    expect(greetingOut.tier, CoachTier.fallback);
    expect(tipOut.tier, CoachTier.fallback);
  });

  // ═══════════════════════════════════════════════════════════════
  //  12. Greeting contient le prénom
  // ═══════════════════════════════════════════════════════════════

  test('12. Greeting contient le prénom de l\'utilisateur', () async {
    _resetFlags();
    final ctx = _ctx(firstName: 'Laurent');

    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.greeting,
      ctx: ctx,
    );

    expect(out.text, contains('Laurent'));
  });

  test('12b. Unknown age does not enter disability age branch', () async {
    _resetFlags();
    final out = await CoachOrchestrator.generateNarrativeComponent(
      componentType: ComponentType.tip,
      ctx: _ctx(age: 0),
    );

    expect(out.text, isNot(contains('À 0 ans')));
    expect(out.text, isNot(contains('0 ans')));
  });

  // ═══════════════════════════════════════════════════════════════
  //  13. OrchestratorOutput.text n'est jamais vide
  // ═══════════════════════════════════════════════════════════════

  test('13. OrchestratorOutput.text n\'est jamais vide (resilience)', () async {
    _resetFlags();
    final ctx = _ctx(friTotal: 0, friDelta: 0);

    for (final type in ComponentType.values) {
      final out = await CoachOrchestrator.generateNarrativeComponent(
        componentType: type,
        ctx: ctx,
      );
      expect(
        out.text.trim(),
        isNotEmpty,
        reason: 'ComponentType.$type a retourné un texte vide',
      );
    }
  });

  // ═══════════════════════════════════════════════════════════════
  //  14. generateChat retourne un CoachResponse valide en mode offline
  // ═══════════════════════════════════════════════════════════════

  test('14. generateChat retourne un CoachResponse valide (offline)', () async {
    _resetFlags();
    final ctx = _ctx();

    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Que puis-je faire pour améliorer ma retraite?',
      history: const [],
      ctx: ctx,
    );

    expect(response.message, isNotEmpty);
    expect(response.disclaimer, isNotEmpty);
    // Disclaimer must contain educational framing.
    expect(
      response.disclaimer.toLowerCase(),
      anyOf(contains('éducatif'), contains('educatif'), contains('lsfin')),
    );
  });

  test('14b. generateChat fallback answers independent no-LPP 3a question',
      () async {
    _resetFlags(safeModeDegraded: true);
    final ctx = _ctx();

    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
      history: const [],
      ctx: ctx,
      isLoggedIn: true,
    );

    final message = response.message.toLowerCase();
    expect(message, contains('revenu net d\'activité'));
    expect(message, contains('budget mensuel'));
    expect(message, contains('lpp facultative'));
    expect(message, isNot(contains('7\u00a0258')));
    expect(message, isNot(contains('salarié')));
  });

  // ═══════════════════════════════════════════════════════════════
  //  15. Smoke test: tous les ComponentType fonctionnent
  // ═══════════════════════════════════════════════════════════════

  test('15. Smoke test: tous les ComponentType retournent un résultat',
      () async {
    _resetFlags();
    final ctx = _ctx(
      knownValues: const {
        'fri_total': 62,
        'capital_final': 850000,
        'replacement_ratio': 58,
        'confidence_score': 45,
        'tax_saving': 2000,
        'months_liquidity': 4,
      },
    );

    // All component types must complete without exception.
    for (final type in ComponentType.values) {
      final out = await CoachOrchestrator.generateNarrativeComponent(
        componentType: type,
        ctx: ctx,
      );
      expect(out.text, isNotEmpty, reason: 'ComponentType.$type vide');
      expect(out.tier, isA<CoachTier>());
    }
  });

  // ═══════════════════════════════════════════════════════════════
  //  16. Codex grounding-stack review (fix_2) — fail-CLOSED guard
  //  Both the SLM and BYOK tiers route their guarded output through
  //  resolveGuardedText(). On useFallback the helper MUST return the
  //  templated safe reply, never the raw text the guard blocked.
  // ═══════════════════════════════════════════════════════════════

  group('16. resolveGuardedText fails closed (fix_2)', () {
    const rawBlocked =
        "Un rachat LPP, c'est sortir ton capital du 2e pilier avant l'heure.";

    test('useFallback renders the templated reply, NOT the raw text', () {
      final ctx = _ctx();
      const compliance = ComplianceResult(
        isCompliant: false,
        sanitizedText: '', // guard returns empty on fallback
        violations: ['definition_inversion'],
        useFallback: true,
      );

      final text = CoachOrchestrator.resolveGuardedText(
        compliance: compliance,
        rawText: rawBlocked,
        componentType: ComponentType.general,
        ctx: ctx,
      );

      expect(text, isNot(equals(rawBlocked)),
          reason: 'fail-open bug: raw blocked text rendered');
      expect(text, isNotEmpty);
      // The rendered text must not carry the inverted definition.
      expect(text.toLowerCase(), isNot(contains('sortir ton capital')));
    });

    test('prescriptive fallback also renders the templated reply', () {
      final ctx = _ctx();
      const rawPrescriptive = 'Fais un rachat de 10000 CHF cette année.';
      const compliance = ComplianceResult(
        isCompliant: false,
        sanitizedText: '',
        violations: ['prescriptive'],
        useFallback: true,
      );

      final text = CoachOrchestrator.resolveGuardedText(
        compliance: compliance,
        rawText: rawPrescriptive,
        componentType: ComponentType.tip,
        ctx: ctx,
      );

      expect(text, isNot(equals(rawPrescriptive)));
      expect(text, isNotEmpty);
    });

    test('sanitised (non-fallback) text passes through', () {
      final ctx = _ctx();
      const sanitised = 'Tu pourrais envisager un rachat selon ta situation.';
      const compliance = ComplianceResult(
        isCompliant: false,
        sanitizedText: sanitised,
        violations: ['banned:conseiller'],
        useFallback: false,
      );

      final text = CoachOrchestrator.resolveGuardedText(
        compliance: compliance,
        rawText: 'Demande à un conseiller.',
        componentType: ComponentType.general,
        ctx: ctx,
      );

      expect(text, equals(sanitised));
    });

    test('clean compliant text passes through unchanged', () {
      final ctx = _ctx();
      const clean = 'Voici une piste à explorer ensemble.';
      const compliance = ComplianceResult(
        isCompliant: true,
        sanitizedText: clean,
        violations: [],
        useFallback: false,
      );

      final text = CoachOrchestrator.resolveGuardedText(
        compliance: compliance,
        rawText: clean,
        componentType: ComponentType.general,
        ctx: ctx,
      );

      expect(text, equals(clean));
    });

    test('guard threw (null) returns raw text as last resort', () {
      final ctx = _ctx();
      const raw = 'Réponse brute du modèle.';
      final text = CoachOrchestrator.resolveGuardedText(
        compliance: null,
        rawText: raw,
        componentType: ComponentType.general,
        ctx: ctx,
      );
      expect(text, equals(raw));
    });
  });
}
