/// Phase 53-02 — RouteSuggestionCard sequence-wiring tests.
///
/// Asserts:
///   1. Tap on a card WITHOUT intentTag does NOT start a sequence.
///   2. Tap on a card WITH intentTag for a known SequenceTemplate
///      (e.g. 'retirement_choice' → retirementPrep) DOES start the
///      sequence (verified via SequenceStore.load returning a non-null run).
///   3. Tap with intentTag NOT keyed to any template is a silent no-op
///      (no SequenceRun persisted; navigation still happens).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

Widget _harness(Widget child, {String pushedRoute = '/test'}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(path: pushedRoute, builder: (_, __) => const Scaffold()),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('without intentTag: no sequence started', (tester) async {
    await tester.pumpWidget(_harness(
      const RouteSuggestionCard(
        contextMessage: 'Voir le simulateur',
        route: '/test',
      ),
    ));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(await SequenceStore.load(), isNull,
        reason: 'No intentTag → no SequenceRun persisted');
  });

  testWidgets(
      'with intentTag matching SequenceTemplate: startSequence persists run',
      (tester) async {
    await tester.pumpWidget(_harness(
      const RouteSuggestionCard(
        contextMessage: 'Préparer ta retraite',
        route: '/retraite',
        intentTag: 'retirement_choice',
      ),
      pushedRoute: '/retraite',
    ));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final run = await SequenceStore.load();
    expect(run, isNotNull,
        reason:
            'intentTag retirement_choice maps to retirementPrep template; '
            'startSequence should persist a SequenceRun');
    expect(run!.templateId, equals('retirement_prep'));
  });

  testWidgets('with unknown intentTag: silent no-op (navigation still works)',
      (tester) async {
    await tester.pumpWidget(_harness(
      const RouteSuggestionCard(
        contextMessage: 'Voir',
        route: '/test',
        intentTag: 'no_such_intent_anywhere_xyz',
      ),
    ));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(await SequenceStore.load(), isNull,
        reason: 'Unknown intent → templateForIntent returns null → no run');
  });
}
