/// Phase 97.5 W3-T1 P002 — widget test for the ConfidenceScoreCard
/// MintCardActionBar wiring.
///
/// Asserts the contract (per RESEARCH §E.2 row 1) :
///   1. `Key('card_confidence_score')` is in the rendered widget tree
///      (Maestro `assertVisible: { id: card_confidence_score }` resolves)
///   2. `Semantics(identifier: 'card_confidence_score')` is present
///      (D.5 M001 mitigation, RESEARCH §B.2)
///   3. `MintCardActionBar` is a descendant of `ConfidenceScoreCard`
///   4. The 3 verb labels (« Explique-moi » / « Simule » / « Rassure-moi »)
///      render correctly via ARB
///   5. Tapping « Simule » fires the `onSimulate` callback (W3-T1 contract :
///      Explorer deep-link is owned by the parent screen for test isolation,
///      matching the W3-T1 minimum-code mirror of cap_du_jour)
///
/// 0-trust receipt : this test exits 0 deterministically and is the gate
/// per W3-T1 acceptance criterion (a).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/home/confidence_score_card.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';

class _FakeCoachProfileProvider extends ChangeNotifier
    implements CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);
  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimulateRecorder {
  int taps = 0;
}

Widget _harness({
  required _SimulateRecorder recorder,
  CoachProfile? profile,
}) {
  // Synthesize a deterministic 4-axis confidence at the middle of the
  // « partial » band (40-70) so the card renders the non-error,
  // non-perfect state with the enrichment CTA visible.
  final confidence = EnhancedConfidence.fromBareScore(55.0);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => _FakeCoachProfileProvider(profile),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      home: Scaffold(
        body: ConfidenceScoreCard(
          score: 55.0,
          confidence: confidence,
          onSimulate: () => recorder.taps++,
        ),
      ),
    ),
  );
}

void main() {
  group('ConfidenceScoreCard — W3-T1 P002 MintCardActionBar wiring', () {
    testWidgets('renders root Key(card_confidence_score)', (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('card_confidence_score')),
        findsOneWidget,
      );
    });

    testWidgets(
        'card root carries Semantics(identifier: card_confidence_score)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      // RESEARCH §B.2 D.5 M001 — Semantics.identifier is the
      // VoiceOver-readable + Maestro-resolvable card anchor.
      final semantics = tester.getSemantics(
        find.byKey(const Key('card_confidence_score')),
      );
      expect(semantics.identifier, 'card_confidence_score');
    });

    testWidgets('MintCardActionBar is a descendant of ConfidenceScoreCard',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      final actionBar = find.descendant(
        of: find.byType(ConfidenceScoreCard),
        matching: find.byType(MintCardActionBar),
      );
      expect(actionBar, findsOneWidget);
    });

    testWidgets('action bar exposes Key(mint_card_action_bar)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mint_card_action_bar')),
        findsOneWidget,
      );
    });

    testWidgets('renders 3 verb labels (Explique-moi, Simule, Rassure-moi)',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      expect(find.text('Explique-moi'), findsOneWidget);
      expect(find.text('Simule'), findsOneWidget);
      expect(find.text('Rassure-moi'), findsOneWidget);
    });

    testWidgets('tapping « Simule » fires the onSimulate callback',
        (tester) async {
      final recorder = _SimulateRecorder();
      await tester.pumpWidget(_harness(recorder: recorder));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simule'));
      await tester.pumpAndSettle();

      // W3-T1 : the test surface verifies the chip fires onSimulate ;
      // parent screen wiring to context.push('/explore?simulate=
      // confidence_score') is verified at the screen-level integration
      // test (W3 follow-on), kept out of this unit test per RESEARCH §E.2.
      expect(recorder.taps, 1);
    });
  });
}
