// PR-D (TRANCHE-FIRSTJOB-SPEC §1 T3 / §3.1) — /home life-event entry.
//
// Partial 12D grid proofs on LifeEventSuggestionsSection as mounted on /home:
//   D1  route reachable — the firstJob card navigates to /first-job (back-nav
//       preserved via context.push over a root route).
//   D7  Semantics — the card exposes identifier `home-lifeevent-card-firstJob`
//       as a button.
//   D4  no suggestion -> SizedBox.shrink (no empty section).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/aujourdhui/home_life_events.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

const _firstJob = LifeEventSuggestion(
  title: 'Premier emploi',
  reason: 'Ton premier salaire suisse',
  icon: Icons.school_outlined,
  route: '/first-job',
  color: MintColors.info,
);

Finder _bySemanticsIdentifier(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
    );

Widget _harness(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: '/first-job',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('FIRST-JOB-SCREEN'))),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
  );
}

void main() {
  testWidgets('D7 — firstJob card exposes home-lifeevent-card-firstJob button',
      (tester) async {
    await tester.pumpWidget(_harness(
      const LifeEventSuggestionsSection(
        suggestions: [_firstJob],
        cardIdentifier: homeLifeEventCardIdentifier,
      ),
    ));
    await tester.pumpAndSettle();

    final card = _bySemanticsIdentifier('home-lifeevent-card-firstJob');
    expect(card, findsOneWidget);
    final semantics = tester.widget<Semantics>(card);
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.label, 'Premier emploi');
  });

  testWidgets('D1 — tapping the firstJob card navigates to /first-job',
      (tester) async {
    await tester.pumpWidget(_harness(
      const LifeEventSuggestionsSection(
        suggestions: [_firstJob],
        cardIdentifier: homeLifeEventCardIdentifier,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FIRST-JOB-SCREEN'), findsNothing);
    await tester.tap(_bySemanticsIdentifier('home-lifeevent-card-firstJob'));
    await tester.pumpAndSettle();

    expect(find.text('FIRST-JOB-SCREEN'), findsOneWidget);
  });

  testWidgets('D4 — empty suggestions render SizedBox.shrink, no section',
      (tester) async {
    await tester.pumpWidget(_harness(
      const LifeEventSuggestionsSection(
        suggestions: [],
        cardIdentifier: homeLifeEventCardIdentifier,
      ),
    ));
    await tester.pumpAndSettle();

    // No header, no card, no home identifier — just a collapsed section.
    expect(_bySemanticsIdentifier('home-lifeevent-card-firstJob'),
        findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('scoped id — non-firstJob card carries no home identifier',
      (tester) async {
    const mariage = LifeEventSuggestion(
      title: 'Mariage',
      reason: 'r',
      icon: Icons.favorite_outline,
      route: '/mariage',
      color: MintColors.error,
    );
    await tester.pumpWidget(_harness(
      const LifeEventSuggestionsSection(
        suggestions: [mariage],
        cardIdentifier: homeLifeEventCardIdentifier,
      ),
    ));
    await tester.pumpAndSettle();

    expect(_bySemanticsIdentifier('home-lifeevent-card-firstJob'),
        findsNothing);
    // The card itself still renders (it is just not under contract yet).
    expect(find.text('Mariage'), findsOneWidget);
  });
}
