import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_host.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_object.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_signal.dart';

/// Patrol-style integration matrix for MintAlertObject (Phase 9 Plan 09-04).
///
/// D-10 locks the file to `integration_test/` and scopes the matrix to
/// 8 golden states:
///   1. G2 × soft      → calm register, no announce
///   2. G2 × direct    → calm register, no announce
///   3. G2 × unfiltered→ calm register, no announce
///   4. G3 × soft      → grammatical break + ack CTA + first-render (no announce)
///   5. G3 × direct    → grammatical break + ack CTA + first-render (no announce)
///   6. G3 × unfiltered→ grammatical break + ack CTA + first-render (no announce)
///   7. Sensitive-topic guard → level capped at N3 under resolveLevel
///   8. Fragile-mode guard    → level capped at N3 under resolveLevel
///
/// The test runs via the standard `integration_test` binding (no external
/// patrol CLI) so it executes in the same suite as
/// `persona_lea_test.dart`/`persona_marc_test.dart`. It pumps
/// [MintAlertHost] directly with a synthetic feeder stream — the intent of
/// the matrix is to exercise the widget surface and the sensitive/fragile
/// caps of `resolveLevel`, not the full app shell.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  VoiceResolutionContext baseCtx({
    VoicePreference preference = VoicePreference.direct,
    bool sensitive = false,
    bool fragile = false,
  }) =>
      VoiceResolutionContext(
        relation: Relation.established,
        preference: preference,
        sensitiveFlag: sensitive,
        fragileFlag: fragile,
        n5Budget: 1,
      );

  Widget harness({
    required Stream<MintAlertSignal> signals,
    required VoiceResolutionContext ctx,
    required List<String> announces,
    required List<BiographyFact> acks,
  }) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: MintAlertHost(
          signals: signals,
          resolveContext: (_, __) => ctx,
          announce: (msg, _) => announces.add(msg),
          recordAck: (f) async => acks.add(f),
          hasAck: (_) async => false,
        ),
      ),
    );
  }

  MintAlertSignal signal({
    required Gravity gravity,
    required String alertId,
    String topicTag = 'debt',
  }) =>
      MintAlertSignal(
        gravity: gravity,
        factKey: 'mintAlertDebtFact',
        causeKey: 'mintAlertDebtCause',
        nextMomentKey: 'mintAlertDebtNextMoment',
        topicTag: topicTag,
        alertId: alertId,
      );

  group('MintAlertObject patrol matrix — 8 golden states', () {
    // ── Cases 1-3: G2 × each voice preference (calm register, no break)
    for (final entry in <String, VoicePreference>{
      'case-1-g2-soft': VoicePreference.soft,
      'case-2-g2-direct': VoicePreference.direct,
      'case-3-g2-unfiltered': VoicePreference.unfiltered,
    }.entries) {
      testWidgets('${entry.key}: G2 renders calm register + MINT fact',
          (tester) async {
        final controller = StreamController<MintAlertSignal>.broadcast();
        final announces = <String>[];
        final acks = <BiographyFact>[];
        await tester.pumpWidget(harness(
          signals: controller.stream,
          ctx: baseCtx(preference: entry.value),
          announces: announces,
          acks: acks,
        ));
        controller.add(signal(gravity: Gravity.g2, alertId: entry.key));
        await tester.pumpAndSettle();

        // MINT-as-subject fact line is rendered.
        expect(find.textContaining('MINT'), findsWidgets,
            reason: '${entry.key}: fact must start with MINT (anti-shame).');
        // G2 does NOT render the ack CTA.
        expect(find.byKey(Key('mint_alert_ack_${entry.key}')), findsNothing,
            reason: '${entry.key}: G2 is transient, no "Compris" CTA.');
        // No grammatical break (Divider) on G2.
        expect(find.byType(Divider), findsNothing,
            reason: '${entry.key}: G2 must not add a grammatical break.');
        // No announce on first render of a non-transition.
        expect(announces, isEmpty,
            reason:
                '${entry.key}: no announce without a G2→G3 transition.');
        await controller.close();
      });
    }

    // ── Cases 4-6: G3 × each voice preference (break + ack + liveRegion)
    for (final entry in <String, VoicePreference>{
      'case-4-g3-soft': VoicePreference.soft,
      'case-5-g3-direct': VoicePreference.direct,
      'case-6-g3-unfiltered': VoicePreference.unfiltered,
    }.entries) {
      testWidgets('${entry.key}: G3 renders break + ack CTA + liveRegion',
          (tester) async {
        final controller = StreamController<MintAlertSignal>.broadcast();
        final announces = <String>[];
        final acks = <BiographyFact>[];
        await tester.pumpWidget(harness(
          signals: controller.stream,
          ctx: baseCtx(preference: entry.value),
          announces: announces,
          acks: acks,
        ));
        controller.add(signal(gravity: Gravity.g3, alertId: entry.key));
        await tester.pumpAndSettle();

        // Grammatical break (Divider) present on G3.
        expect(find.byType(Divider), findsWidgets,
            reason: '${entry.key}: G3 must add a visual grammatical break.');
        // Ack CTA present and wrapped in Tooltip + Semantics (TalkBack 13).
        expect(find.byKey(Key('mint_alert_ack_${entry.key}')), findsOneWidget,
            reason: '${entry.key}: G3 must expose the "Compris" ack CTA.');
        // liveRegion present on the alert Semantics node.
        final semantics = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.liveRegion == true);
        expect(semantics.isNotEmpty, isTrue,
            reason: '${entry.key}: G3 must expose liveRegion: true.');
        // D-11: first render is not a transition, so announce must NOT fire.
        expect(announces, isEmpty,
            reason: '${entry.key}: first render of G3 does not announce.');

        // Tap ack — records a BiographyFact.alertAcknowledged for this id.
        await tester.tap(find.byKey(Key('mint_alert_ack_${entry.key}')));
        await tester.pumpAndSettle();
        expect(acks.length, 1);
        expect(acks.first.factType, FactType.alertAcknowledged);
        expect(acks.first.value, entry.key);
        await controller.close();
      });
    }

    // ── Case 7: sensitive-topic guard — level capped at N3.
    testWidgets('case-7: sensitive-topic guard caps level at N3',
        (tester) async {
      final capped = resolveLevel(
        gravity: Gravity.g3,
        relation: Relation.established,
        preference: VoicePreference.unfiltered, // would push toward N5
        sensitiveFlag: true, // ← the guard
        fragileFlag: false,
        n5Budget: 5,
      );
      expect(
        capped.index <= VoiceLevel.n3.index,
        isTrue,
        reason:
            'sensitiveFlag must cap the voice level at or below N3 regardless '
            'of preference (D-04 / anti-shame doctrine).',
      );

      // Render the widget too so the host path is exercised.
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        ctx: baseCtx(
          preference: VoicePreference.unfiltered,
          sensitive: true,
        ),
        announces: <String>[],
        acks: <BiographyFact>[],
      ));
      controller.add(
          signal(gravity: Gravity.g3, alertId: 'case-7', topicTag: 'death'));
      await tester.pumpAndSettle();
      expect(find.byType(MintAlertObject), findsOneWidget);
      await controller.close();
    });

    // ── Case 8: fragile-mode guard — level capped at N3.
    testWidgets('case-8: fragile-mode guard caps level at N3', (tester) async {
      final capped = resolveLevel(
        gravity: Gravity.g3,
        relation: Relation.established,
        preference: VoicePreference.unfiltered,
        sensitiveFlag: false,
        fragileFlag: true, // ← the guard
        n5Budget: 5,
      );
      expect(
        capped.index <= VoiceLevel.n3.index,
        isTrue,
        reason:
            'fragileFlag must cap the voice level at or below N3 regardless '
            'of preference (D-04 / fragility cap).',
      );

      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        ctx: baseCtx(
          preference: VoicePreference.unfiltered,
          fragile: true,
        ),
        announces: <String>[],
        acks: <BiographyFact>[],
      ));
      controller.add(signal(gravity: Gravity.g3, alertId: 'case-8'));
      await tester.pumpAndSettle();
      expect(find.byType(MintAlertObject), findsOneWidget);
      await controller.close();
    });
  });
}
