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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
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
      final expectedSeed = CoachProfileSeeds.bySlug(expectedSlug) ??
          CoachProfileSeeds.byArchetype(expectedSlug);
      expect(active, isNotNull,
          reason: 'MINT_E2E_ARCHETYPE=$expectedSlug should hydrate a seed');
      expect(active, same(expectedSeed),
          reason: 'MINT_E2E_ARCHETYPE accepts seed slugs and archetype slugs');
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
    // Hotfix 2026-06-12: forced-kind cards no longer carry hardcoded FR
    // headline/body — the localized copy is resolved by the rendering widget
    // from `kind`. So the LLM-natural headline must NOT survive (it is
    // replaced by an empty sentinel here).
    expect(dispatched.headline, isNot('LLM-natural headline'));
    expect(dispatched.headline, isEmpty);
  });

  test('ChatToolDispatcher fabricates a card from template when no payload '
      'AND a forced kind is set (ECLW-03 walker safety net)', () {
    if (kReleaseMode) return;
    if (CoachOrchestrator.forcedEclairageKind == null) return;

    final dispatched = ChatToolDispatcher.dispatchEclairagePayload(null);
    expect(dispatched, isNotNull);
    expect(dispatched!.kind, CoachOrchestrator.forcedEclairageKind);
    // Hotfix 2026-06-12: the forced-kind data class no longer bakes the LSFin
    // disclaimer — it is resolved by the rendering widget (above-input single
    // source). The sentinel is empty here; the safety-net contract is now
    // "kind is set + range is valid", not "disclaimer string present".
    expect(dispatched.lsfinDisclaimer, isEmpty);
    expect(dispatched.chfRangeLow, lessThan(dispatched.chfRangeHigh));
  });

  test('ChatToolDispatcher returns null when no force and no payload '
      '(default path, no accidental always-on)', () {
    if (CoachOrchestrator.forcedEclairageKind != null) return;
    expect(ChatToolDispatcher.dispatchEclairagePayload(null), isNull);
  });

  test('EclairageCardData.fromForcedKind carries the kind + deterministic '
      'range, NO hardcoded FR copy (ECLW-05, hotfix 2026-06-12)', () {
    // Post-hotfix contract: headline/body are EMPTY in the data class — the
    // localized copy lives in the ARBs and is resolved by the widget from
    // `kind`. This is the i18n + honest-copy fix: zero hardcoded user-facing
    // French in eclairage_models.dart.
    final card = EclairageCardData.fromForcedKind(EclairageKind.fiscalMargin3a);
    expect(card.kind, EclairageKind.fiscalMargin3a);
    expect(card.headline, isEmpty,
        reason: 'forced-kind headline is resolved from ARB by the widget');
    expect(card.body, isEmpty,
        reason: 'forced-kind body is resolved from ARB by the widget');
    expect(card.chfRangeLow, lessThan(card.chfRangeHigh));
    // kind→key map is the contract the widget consumes.
    expect(
      EclairageCardData.eclairageKindHeadlineKey(EclairageKind.fiscalMargin3a),
      'eclairageFiscalMargin3aHeadline',
    );
    expect(
      EclairageCardData.eclairageKindBodyKey(EclairageKind.fiscalMargin3a),
      'eclairageFiscalMargin3aBody',
    );
  });

  testWidgets('EclairageCard resolves forced fiscal_margin_3a copy from ARB '
      '(ECLW-05 widget assertion, hotfix 2026-06-12)', (tester) async {
    final card = EclairageCardData.fromForcedKind(EclairageKind.fiscalMargin3a);

    // Hotfix 2026-06-12 — headline/body are empty in the forced-kind data
    // class; the widget resolves them from `kind` via AppLocalizations. The
    // payload must carry the `kind` wire name so the resolution fires.
    final payload = <String, dynamic>{
      'kind': card.kind.wireName,
      'headline': card.headline, // empty — triggers ARB resolution
      'body': card.body, // empty — triggers ARB resolution
      'chf_range_low': card.chfRangeLow,
      'chf_range_high': card.chfRangeHigh,
      'chf_range_period': card.chfRangePeriod,
      'soft_account_hint': card.softAccountHint,
      'lsfin_disclaimer': card.lsfinDisclaimer,
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EclairageCard(payload: payload),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The localized fr_CH copy MUST render — proves the forced-kind path now
    // resolves stable, honest, i18n strings from the ARBs instead of the old
    // hardcoded « Ta marge fiscale 3a ».
    expect(find.text('Ta marge fiscale 3a'), findsOneWidget);
    expect(find.textContaining('plafond'), findsOneWidget);
    // Eyebrow is localized + upper-cased by `_buildEyebrow`.
    expect(find.text('PREMIER ÉCLAIRAGE'), findsOneWidget);
  });

  testWidgets('EclairageCard forced lpp_rachat_window copy is honest + '
      'conditional — no presumed certificate (BUG 2 regression, '
      'hotfix 2026-06-12)', (tester) async {
    final card =
        EclairageCardData.fromForcedKind(EclairageKind.lppRachatWindow);
    final payload = <String, dynamic>{
      'kind': card.kind.wireName,
      'headline': card.headline,
      'body': card.body,
      'chf_range_low': card.chfRangeLow,
      'chf_range_high': card.chfRangeHigh,
      'chf_range_period': card.chfRangePeriod,
      'lsfin_disclaimer': card.lsfinDisclaimer,
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: SingleChildScrollView(child: EclairageCard(payload: payload)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // BUG 2 regression guard: the old copy presumed a certificate
    // (« Selon ton certificat LPP, … ») for an anonymous user. The new copy
    // is conditional (« Si ta caisse de pension permet des rachats, … »).
    expect(find.textContaining('Selon ton certificat'), findsNothing,
        reason: 'must not presume a certificate the user never provided');
    expect(find.textContaining('Si ta caisse de pension'), findsOneWidget);
  });
}
