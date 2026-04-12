import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_host.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_signal.dart';
import 'package:mint_mobile/widgets/alert/voice_resolution_context.dart';

/// Unit tests for [MintAlertHost] — Phase 9 Plan 09-04.
///
/// The host is the stateful wrapper responsible for:
///   * G3 ack persistence (ALERT-05 / D-06)
///   * SemanticsService.announce on G2→G3 transitions (ALERT-08 / D-11)
///   * G2 auto-dismissibility vs G3 persistence
///
/// All I/O is behind typedef seams so these tests are hermetic (no DB).
void main() {
  const ctx = VoiceResolutionContext(
    relation: Relation.established,
    preference: VoicePreference.direct,
    sensitiveFlag: false,
    fragileFlag: false,
    n5Budget: 1,
  );

  VoiceResolutionContext resolve(BuildContext _, MintAlertSignal __) => ctx;

  Widget harness({
    required Stream<MintAlertSignal> signals,
    AnnounceFn? announce,
    RecordAckFn? recordAck,
    HasAckFn? hasAck,
  }) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: MintAlertHost(
          signals: signals,
          resolveContext: resolve,
          announce: announce,
          recordAck: recordAck,
          hasAck: hasAck,
        ),
      ),
    );
  }

  MintAlertSignal signal({
    required Gravity gravity,
    String alertId = 'alert-1',
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

  group('MintAlertHost — G2→G3 announce (D-11)', () {
    testWidgets('first render of G3 does NOT fire announce', (tester) async {
      final announces = <String>[];
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        announce: (msg, _) => announces.add(msg),
        hasAck: (_) async => false,
      ));
      controller.add(signal(gravity: Gravity.g3));
      await tester.pumpAndSettle();

      expect(
        announces,
        isEmpty,
        reason:
            'First render is the initial state — no transition, no announce.',
      );
      await controller.close();
    });

    testWidgets('G2 → G3 transition fires announce exactly once',
        (tester) async {
      final announces = <String>[];
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        announce: (msg, _) => announces.add(msg),
        hasAck: (_) async => false,
      ));
      controller.add(signal(gravity: Gravity.g2));
      await tester.pumpAndSettle();
      controller.add(signal(gravity: Gravity.g3));
      await tester.pumpAndSettle();

      expect(announces.length, 1,
          reason: 'Exactly one announce on G2→G3 transition.');
      expect(announces.first.contains('MINT'), isTrue,
          reason: 'Announce text is MINT-as-subject (D-03).');
      await controller.close();
    });

    testWidgets('idle G3 → G3 update does NOT fire announce', (tester) async {
      final announces = <String>[];
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        announce: (msg, _) => announces.add(msg),
        hasAck: (_) async => false,
      ));
      controller.add(signal(gravity: Gravity.g3));
      await tester.pumpAndSettle();
      controller.add(signal(gravity: Gravity.g3));
      await tester.pumpAndSettle();

      expect(announces, isEmpty,
          reason: 'Idle G3→G3 updates must not re-announce.');
      await controller.close();
    });
  });

  group('MintAlertHost — G3 ack persistence (D-06)', () {
    testWidgets('tapping "Compris" records an alertAcknowledged fact',
        (tester) async {
      final records = <BiographyFact>[];
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        recordAck: (f) async => records.add(f),
        hasAck: (_) async => false,
      ));
      controller.add(signal(gravity: Gravity.g3, alertId: 'ack-target'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mint_alert_ack_ack-target')));
      await tester.pumpAndSettle();

      expect(records.length, 1);
      expect(records.first.factType, FactType.alertAcknowledged);
      expect(records.first.value, 'ack-target',
          reason: 'value must hold the alertId (D-06).');
      await controller.close();
    });

    testWidgets('after ack, re-emitting same alertId renders nothing',
        (tester) async {
      final ackedIds = <String>{};
      final controller = StreamController<MintAlertSignal>.broadcast();
      await tester.pumpWidget(harness(
        signals: controller.stream,
        recordAck: (f) async => ackedIds.add(f.value),
        hasAck: (id) async => ackedIds.contains(id),
      ));
      controller.add(signal(gravity: Gravity.g3, alertId: 'persistent-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mint_alert_ack_persistent-1')));
      await tester.pumpAndSettle();

      // Now the feeder re-emits the same alert — should be suppressed.
      controller.add(signal(gravity: Gravity.g3, alertId: 'persistent-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mint_alert_ack_persistent-1')), findsNothing,
          reason:
              'Ack was recorded — subsequent renders of same alertId are suppressed.');
      await controller.close();
    });
  });

  group('MintAlertHost — G2 auto-dismiss vs G3 persistence', () {
    testWidgets(
        'G2 alerts can be dropped via dismissIfG2; G3 cannot be dropped that way',
        (tester) async {
      final controller = StreamController<MintAlertSignal>.broadcast();
      final hostKey = GlobalKey<State<MintAlertHost>>();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MintAlertHost(
            key: hostKey,
            signals: controller.stream,
            resolveContext: resolve,
            announce: (_, __) {},
            recordAck: (_) async {},
            hasAck: (_) async => false,
          ),
        ),
      ));
      controller.add(signal(gravity: Gravity.g2, alertId: 'g2-drop'));
      controller.add(signal(gravity: Gravity.g3, alertId: 'g3-sticky'));
      await tester.pumpAndSettle();

      // Both present.
      expect(find.byKey(const Key('mint_alert_ack_g3-sticky')), findsOneWidget);

      // Dismiss the G2 (auto-dismiss path).
      // ignore: invalid_use_of_protected_member
      final state = hostKey.currentState! as dynamic;
      state.dismissIfG2('g2-drop');
      state.dismissIfG2('g3-sticky'); // must be a no-op on G3
      await tester.pumpAndSettle();

      // G3 ack CTA still present — G3 is sticky.
      expect(find.byKey(const Key('mint_alert_ack_g3-sticky')), findsOneWidget,
          reason: 'G3 persists until ack — dismissIfG2 is a no-op.');
      await controller.close();
    });
  });
}
