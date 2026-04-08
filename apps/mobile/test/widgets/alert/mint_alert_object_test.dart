import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_object.dart';
import 'package:mint_mobile/widgets/alert/voice_resolution_context.dart';

/// Tests for MintAlertObject — typed, compiler-enforced alert primitive.
///
/// The whole point of this widget is that the GRAMMAR is enforced by the
/// compiler: there is no `String message` field, only
/// `{fact, cause, nextMoment}`. The rendered sentence always has MINT as
/// the subject (anti-shame doctrine).
void main() {
  const defaultContext = VoiceResolutionContext(
    relation: Relation.established,
    preference: VoicePreference.direct,
    sensitiveFlag: false,
    fragileFlag: false,
    n5Budget: 1,
  );

  Widget harness(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );

  group('MintAlertObject — typed API', () {
    testWidgets('renders fact, cause and nextMoment as separate text children',
        (tester) async {
      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g2,
          fact: 'MINT a remarqué un écart entre tes charges et ton budget',
          cause: 'Pourquoi : trois prélèvements non récurrents ce mois-ci',
          nextMoment: 'Quand on en reparle : dimanche, posément',
          alertId: 'alert-test-g2-01',
          resolutionContext: defaultContext,
        ),
      ));

      expect(
        find.textContaining('MINT a remarqué'),
        findsOneWidget,
        reason: 'fact must appear and start with MINT (sentence subject)',
      );
      expect(find.textContaining('Pourquoi'), findsOneWidget);
      expect(find.textContaining('Quand on en reparle'), findsOneWidget);
    });

    testWidgets('anti-shame grammar: MINT appears as subject of the fact',
        (tester) async {
      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g2,
          fact: 'MINT a remarqué une prime en hausse de 8%',
          cause: 'Pourquoi : ta caisse a publié un nouveau tarif',
          nextMoment: 'Quand on en reparle : la semaine prochaine',
          alertId: 'anti-shame-01',
          resolutionContext: defaultContext,
        ),
      ));

      // Find ALL text widgets rendered by the alert.
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final factText = textWidgets
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains('MINT a remarqué'), orElse: () => '');
      expect(factText.isNotEmpty, isTrue,
          reason: 'MINT must be subject of the fact statement');

      // No shame-inducing phrasing allowed in the rendered tree.
      for (final t in textWidgets) {
        final s = t.data ?? '';
        expect(s.toLowerCase().contains('tu as fait'), isFalse,
            reason: 'anti-shame: never "tu as fait..."');
        expect(s.toLowerCase().contains('tu aurais dû'), isFalse,
            reason: 'anti-shame: never "tu aurais dû..."');
      }
    });

    testWidgets('G2 renders with warningAaa accent (calm register)',
        (tester) async {
      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g2,
          fact: 'MINT a remarqué un détail à vérifier',
          cause: 'Pourquoi : une hypothèse à confirmer',
          nextMoment: 'Quand on en reparle : ce weekend',
          alertId: 'g2-accent',
          resolutionContext: defaultContext,
        ),
      ));

      final container = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.decoration is BoxDecoration);
      final deco = container.decoration as BoxDecoration;
      // G2 uses warningAaa somewhere in its border or background.
      final borderColor = (deco.border as Border?)?.top.color;
      expect(borderColor, MintColors.warningAaa,
          reason: 'G2 must use warningAaa accent token on its border');
    });

    testWidgets('G3 renders with errorAaa accent + grammatical break',
        (tester) async {
      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g3,
          fact: 'MINT a remarqué un risque important sur ta couverture',
          cause: 'Pourquoi : un trou de 3 mois identifié dans le contrat',
          nextMoment: 'Quand on en reparle : dès que possible, à tête reposée',
          alertId: 'g3-accent',
          resolutionContext: defaultContext,
        ),
      ));

      final container = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.decoration is BoxDecoration);
      final deco = container.decoration as BoxDecoration;
      final borderColor = (deco.border as Border?)?.top.color;
      expect(borderColor, MintColors.errorAaa,
          reason: 'G3 must use errorAaa accent token on its border');

      // Grammatical break: G3 must contain a Divider between fact and cause.
      expect(find.byType(Divider), findsWidgets,
          reason: 'G3 must add a visual grammatical break');
    });

    testWidgets('Semantics wrapper is liveRegion on G2 and G3',
        (tester) async {
      for (final g in [Gravity.g2, Gravity.g3]) {
        await tester.pumpWidget(harness(
          MintAlertObject(
            gravity: g,
            fact: 'MINT a remarqué un point',
            cause: 'Pourquoi : contexte',
            nextMoment: 'Quand on en reparle : bientôt',
            alertId: 'live-$g',
            resolutionContext: defaultContext,
          ),
        ));

        final semantics = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.liveRegion == true);
        expect(semantics.isNotEmpty, isTrue,
            reason: '$g must expose liveRegion: true');
      }
    });

    testWidgets('reduced-motion fallback: no animation controllers ticking',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g3,
          fact: 'MINT a remarqué quelque chose',
          cause: 'Pourquoi : contexte',
          nextMoment: 'Quand on en reparle : plus tard',
          alertId: 'reduced-motion',
          resolutionContext: defaultContext,
        ),
      ));

      // With disableAnimations, the widget must NOT schedule any persistent
      // ticker — pumping with a large delta must not throw or leave frames.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('externalAction stub throws UnimplementedError when executed',
        (tester) async {
      const stub = ExternalActionStub(label: 'Ouvrir le portail');
      expect(() => stub.execute(), throwsA(isA<UnimplementedError>()));
    });

    testWidgets('widget calls resolveLevel from voice_cursor_contract without throwing',
        (tester) async {
      // Smoke check: no VoiceLevel enum is imported by the widget file
      // other than via voice_cursor_contract. We indirectly assert by
      // building a G3 + soft + sensitive + fragile combo (heaviest cascade).
      const ctx = VoiceResolutionContext(
        relation: Relation.intimate,
        preference: VoicePreference.soft,
        sensitiveFlag: true,
        fragileFlag: true,
        n5Budget: 0,
      );
      await tester.pumpWidget(harness(
        const MintAlertObject(
          gravity: Gravity.g3,
          fact: 'MINT a remarqué un sujet sensible',
          cause: 'Pourquoi : contexte délicat',
          nextMoment: 'Quand on en reparle : à ton rythme',
          alertId: 'cascade-heavy',
          resolutionContext: ctx,
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirror of Flutter's AccessibilityFeatures for tests.
class FakeAccessibilityFeatures implements AccessibilityFeatures {
  const FakeAccessibilityFeatures({this.disableAnimations = false});
  @override
  final bool disableAnimations;
  @override
  bool get accessibleNavigation => false;
  @override
  bool get boldText => false;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;
  @override
  bool get reduceMotion => disableAnimations;
  @override
  bool get supportsAnnounce => true;
}
