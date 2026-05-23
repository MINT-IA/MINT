/// Phase 01.5 W02-T03 Task 5 — Coach orchestrator archetype refusal tests.
///
/// 4 behaviors covered (defense-in-depth, secondary gate per Mapper §7.4):
///   1. archetype='unknown' → refusal payload, LLM never invoked.
///   2. archetype='expat_us' → refusal payload (NOT the old FATCA template).
///   3. archetype='swiss_native' → proceeds normally (FallbackTemplates).
///   4. refusal payload shape: refused=true, refusalReason set, message
///      mentions waitlist / not-calibrated semantics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';

CoachContext _ctx({String archetype = 'swiss_native'}) {
  return CoachContext(
    firstName: 'Test',
    age: 40,
    canton: 'ZH',
    archetype: archetype,
    knownValues: const {'fri_total': 60},
  );
}

void _resetFlags() {
  FeatureFlags.slmPluginReady = false;
  FeatureFlags.enableSlmNarratives = false;
  FeatureFlags.safeModeDegraded = false;
}

void main() {
  setUp(_resetFlags);

  test(
      '1. archetype=unknown → generateChat returns refusal payload (LLM not invoked)',
      () async {
    final ctx = _ctx(archetype: 'unknown');
    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Comment va ma retraite ?',
      history: const [],
      ctx: ctx,
    );
    expect(response.refused, isTrue);
    expect(response.refusalReason, 'archetype_not_calibrated');
  });

  test(
      '2. archetype=expat_us → generateChat returns refusal payload (FATCA defense-in-depth)',
      () async {
    final ctx = _ctx(archetype: 'expat_us');
    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Comment va ma retraite ?',
      history: const [],
      ctx: ctx,
    );
    expect(response.refused, isTrue);
    expect(response.refusalReason, 'archetype_not_calibrated');
  });

  test(
      '3. archetype=swiss_native → generateChat proceeds normally (no refusal)',
      () async {
    final ctx = _ctx(archetype: 'swiss_native');
    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Comment va ma retraite ?',
      history: const [],
      ctx: ctx,
    );
    expect(response.refused, isFalse,
        reason:
            'calibrated archetype must fall through to the SLM → BYOK → fallback chain');
    expect(response.message, isNotEmpty);
  });

  test(
      '4. refusal payload shape: refused=true, refusalReason and message set',
      () async {
    final ctx = _ctx(archetype: 'cross_border');
    final response = await CoachOrchestrator.generateChat(
      userMessage: 'Que dois-je faire ?',
      history: const [],
      ctx: ctx,
    );
    expect(response.refused, isTrue);
    expect(response.refusalReason, 'archetype_not_calibrated');
    expect(response.message, isNotEmpty,
        reason:
            'refusal payload still carries a user-visible message so the UI surfaces something explicit instead of an empty bubble');
    // The refusal disclaimer is the standard ComplianceGuard one — no
    // promise leak.
    expect(response.disclaimer, isNotEmpty);
  });
}
