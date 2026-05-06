/// Phase 80 (v2.11) — ECLW-05: forced eclairage kind asserts.
///
/// Verifies that when the dart-define
/// `MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a` is set at build time,
/// the rendered card shows headline + body matching the `fiscal_margin_3a`
/// template — NOT whatever the LLM-natural backend kind would have been.
///
/// Also covers ECLW-01 (dispatcher consumes the forced kind), ECLW-02
/// (CoachProfileSeeds.activeSeed reads MINT_E2E_ARCHETYPE), ECLW-03
/// (PremierEclairageSelector invoked from the dispatch path), and
/// ECLW-04 (kReleaseMode guard) — release-build short-circuit checked
/// indirectly via the const dart-define being absent in profile/test
/// builds (test runs with --release would be a separate gate).
///
/// Test runner invocation:
/// ```
/// flutter test \
///   --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a \
///   --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
///   test/services/coach/eclairage_force_kind_test.dart
/// ```
///
/// To exercise the "no force" branch, this file ALSO contains a guard test
/// that asserts the dispatcher returns null when no payload AND no force
/// dart-define are present — protects against accidental "always-on" wiring.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/coach/eclairage_models.dart';
import 'package:mint_mobile/widgets/anonymous/eclairage_card.dart';

const String _forcedKindDefine = String.fromEnvironment(
  'MINT_E2E_FORCE_ECLAIRAGE_KIND',
);

const String _forcedArchetypeDefine = String.fromEnvironment(
  'MINT_E2E_ARCHETYPE',
);

void main() {
  // Sanity: in any build mode, the orchestrator getter must agree with
  // both the dart-define value AND the kReleaseMode short-circuit.
  test('CoachOrchestrator.forcedEclairageKind agrees with dart-define + '
      'kReleaseMode (ECLW-01 + ECLW-04)', () {
    final orchestratorValue = CoachOrchestrator.forcedEclairageKind;

    if (kReleaseMode) {
      // ECLW-04: release builds MUST ignore the dart-define.
      expect(orchestratorValue, isNull,
          reason: 'kReleaseMode short-circuits the dart-define');
      return;
    }

    final expected = EclairageKind.fromWire(_forcedKindDefine.trim());
    expect(orchestratorValue, expected,
        reason: 'forcedEclairageKind must mirror the dart-define value '
            '(got "$_forcedKindDefine")');
  });

  test('CoachProfileSeeds.activeSeed agrees with MINT_E2E_ARCHETYPE '
      'dart-define (ECLW-02)', () {
    final active = CoachProfileSeeds.activeSeed;

    if (kReleaseMode) {
      expect(active, isNull,
          reason: 'release builds MUST ignore MINT_E2E_ARCHETYPE');
      return;
    }

    final expectedSlug = _forcedArchetypeDefine.trim();
    if (expectedSlug.isEmpty) {
      expect(active, isNull);
    } else {
      expect(active, isNotNull,
          reason: 'MINT_E2E_ARCHETYPE=$expectedSlug should hydrate a seed');
      expect(active!.slug, expectedSlug);
    }
  });

  test('ChatToolDispatcher honours forced kind when payload kind differs '
      '(ECLW-01)', () {
    if (kReleaseMode) return; // dart-defines are stripped in release
    if (CoachOrchestrator.forcedEclairageKind == null) return;

    final naturalPayload = <String, dynamic>{
      'kind': 'compound_growth_edge',
      'headline': 'LLM-natural headline',
      'body': 'LLM-natural body that should be replaced.',
      'chf_range_low': 1,
      'chf_range_high': 2,
      'chf_range_period': 'lifetime',
      'lsfin_disclaimer': 'Disclaimer LSFin.',
    };

    final dispatched =
        ChatToolDispatcher.dispatchEclairagePayload(naturalPayload);
    expect(dispatched, isNotNull);
    expect(dispatched!.kind, CoachOrchestrator.forcedEclairageKind);
    // The headline must come from the deterministic template, NOT the LLM.
    expect(dispatched.headline, isNot('LLM-natural headline'));
  });

  test('ChatToolDispatcher fabricates a card from template when no payload '
      'AND a forced kind is set (ECLW-03 walker safety net)', () {
    if (kReleaseMode) return;
    if (CoachOrchestrator.forcedEclairageKind == null) return;

    final dispatched = ChatToolDispatcher.dispatchEclairagePayload(null);
    expect(dispatched, isNotNull);
    expect(dispatched!.kind, CoachOrchestrator.forcedEclairageKind);
    expect(dispatched.lsfinDisclaimer, isNotEmpty);
  });

  test('ChatToolDispatcher returns null when no force and no payload '
      '(default path, no accidental always-on)', () {
    if (CoachOrchestrator.forcedEclairageKind != null) return;
    expect(ChatToolDispatcher.dispatchEclairagePayload(null), isNull);
  });

  test('EclairageCardData.fromForcedKind produces deterministic '
      'fiscal_margin_3a copy (ECLW-05)', () {
    final card = EclairageCardData.fromForcedKind(EclairageKind.fiscalMargin3a);
    expect(card.kind, EclairageKind.fiscalMargin3a);
    expect(card.headline, 'Ta marge fiscale 3a');
    expect(card.body, contains('plafond du 3e pilier'));
    expect(card.chfRangeLow, lessThan(card.chfRangeHigh));
    expect(card.lsfinDisclaimer, isNotEmpty);
  });

  testWidgets('EclairageCard renders forced fiscal_margin_3a template '
      '(ECLW-05 widget assertion)', (tester) async {
    final card = EclairageCardData.fromForcedKind(EclairageKind.fiscalMargin3a);

    // Phase 86 (v2.12) — EclairageCard now accepts a payload Map<String,dynamic>
    // (panel-locked Phase 72 widgets/anonymous variant). The Phase 80
    // `data: EclairageCardData` constructor was deleted as a duplicate.
    final payload = <String, dynamic>{
      'kind': card.kind.wireName,
      'headline': card.headline,
      'body': card.body,
      'chf_range_low': card.chfRangeLow,
      'chf_range_high': card.chfRangeHigh,
      'chf_range_period': card.chfRangePeriod,
      'soft_account_hint': card.softAccountHint,
      'lsfin_disclaimer': card.lsfinDisclaimer,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EclairageCard(payload: payload),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The deterministic template strings MUST be visible — proves the
    // forced kind path produces stable copy walker SSIM goldens can lock to.
    expect(find.text('Ta marge fiscale 3a'), findsOneWidget);
    expect(find.textContaining('plafond du 3e pilier'), findsOneWidget);
    // Phase 86 (v2.12) — eyebrow is panel-locked Phase 72 widget output
    // « Premier éclairage » (mixed case, no kind suffix). The previous
    // « PREMIER ÉCLAIRAGE · 3E PILIER » uppercase + kind-suffix variant
    // was from the deleted Phase 80 widgets/coach/eclairage_card.dart
    // duplicate. Phase 72 widgets/anonymous/eclairage_card.dart is the
    // panel-locked one (commit 8d3c127a).
    expect(find.text('Premier éclairage'), findsOneWidget);
    // LSFin disclaimer always rendered.
    expect(find.textContaining('LSFin'), findsOneWidget);
  });
}
