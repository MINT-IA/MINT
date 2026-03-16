import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/what_if_stories_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final stories = [
    const WhatIfStory(
      emoji: '\ud83d\udcc8',
      question: 'Et si ta caisse LPP passait de 1% \u00e0 2% de rendement ?',
      monthlyImpactChf: 320,
      explanation: 'V\u00e9rifie ton relevé LPP pour conna\u00eetre ton taux',
      actionLabel: 'Voir mes options LPP',
    ),
    const WhatIfStory(
      emoji: '\ud83c\udfe0',
      question: 'Et si tu d\u00e9m\u00e9nageais de ZH \u00e0 TG \u00e0 la retraite ?',
      monthlyImpactChf: 280,
      explanation: '\u00c9conomie fiscale nette',
    ),
    const WhatIfStory(
      emoji: '\u23f0',
      question: 'Et si tu travaillais 1 an de plus (66 au lieu de 65) ?',
      monthlyImpactChf: 410,
      explanation: '1 an de travail = 25 ans de bonus',
    ),
  ];

  Widget buildTestWidget() {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WhatIfStoriesWidget(stories: stories),
        ),
      ),
    );
  }

  group('WhatIfStoriesWidget', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(WhatIfStoriesWidget), findsOneWidget);
    });

    testWidgets('shows header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('changer'), findsWidgets);
    });

    testWidgets('shows all 3 stories', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('LPP'), findsWidgets);
      expect(find.textContaining('nageais'), findsWidgets);
      expect(find.textContaining('travaillais'), findsWidgets);
    });

    testWidgets('shows impact amounts', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('320'), findsWidgets);
      expect(find.textContaining('280'), findsWidgets);
    });

    testWidgets('shows action label when present', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Voir'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('handles empty stories', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: WhatIfStoriesWidget(stories: []),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(WhatIfStoriesWidget), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WhatIfStoriesWidget(
              stories: stories,
              onStoryTapped: (i) => tappedIndex = i,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('LPP').first);
      expect(tappedIndex, 0);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
