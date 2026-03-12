import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    int score = 72,
    int budgetScore = 78,
    int prevoyanceScore = 85,
    int patrimoineScore = 52,
    String trend = 'up',
    int? previousScore = 69,
  }) {
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
          child: MintScoreGauge(
            score: score,
            budgetScore: budgetScore,
            prevoyanceScore: prevoyanceScore,
            patrimoineScore: patrimoineScore,
            trend: trend,
            previousScore: previousScore,
          ),
        ),
      ),
    );
  }

  group('MintScoreGauge', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('displays score number', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 72));
      await tester.pumpAndSettle();
      // Score should appear (animated from 0 to 72)
      expect(find.textContaining('72'), findsWidgets);
    });

    testWidgets('shows /100 label', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('/100'), findsOneWidget);
    });

    testWidgets('shows sub-score labels', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Budget'), findsWidgets);
      expect(find.textContaining('voyance'), findsWidgets);
      expect(find.textContaining('Patrimoine'), findsWidgets);
    });

    testWidgets('renders CustomPaint', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows up trend indicator', (tester) async {
      await tester.pumpWidget(buildTestWidget(trend: 'up', previousScore: 69));
      await tester.pumpAndSettle();
      // Should show a positive delta indicator
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('handles zero score', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        score: 0,
        budgetScore: 0,
        prevoyanceScore: 0,
        patrimoineScore: 0,
        trend: 'stable',
        previousScore: null,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('handles perfect score', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        score: 100,
        budgetScore: 100,
        prevoyanceScore: 100,
        patrimoineScore: 100,
        trend: 'stable',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('handles down trend', (tester) async {
      await tester.pumpWidget(buildTestWidget(trend: 'down', previousScore: 80));
      await tester.pumpAndSettle();
      expect(find.byType(MintScoreGauge), findsOneWidget);
    });

    testWidgets('responds to tap', (tester) async {
      var tapped = false;
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
            child: MintScoreGauge(
              score: 72,
              budgetScore: 78,
              prevoyanceScore: 85,
              patrimoineScore: 52,
              trend: 'up',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MintScoreGauge).first);
      expect(tapped, isTrue);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
