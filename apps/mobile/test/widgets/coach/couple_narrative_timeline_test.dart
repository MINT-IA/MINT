import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/couple_narrative_timeline.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final acts = [
    const CoupleAct(
      number: 1,
      title: 'Vous travaillez tous les deux',
      period: '2026\u20132041 (15 ans)',
      monthlyIncome: 13333,
      insight: 'Fen\u00eatre pour \u00e9pargner ensemble',
    ),
    const CoupleAct(
      number: 2,
      title: 'Julien est \u00e0 la retraite, Lauren travaille encore',
      period: '2041\u20132046 (5 ans)',
      monthlyIncome: 10234,
      deltaPercent: -23,
      insight: 'Le creux\u00a0: 5 ans de revenu r\u00e9duit',
      isDip: true,
    ),
    const CoupleAct(
      number: 3,
      title: 'Retraite \u00e0 deux',
      period: '2046+ (25+ ans)',
      monthlyIncome: 8890,
      deltaPercent: -13,
      insight: 'Le plateau\u00a0: vos revenus stabilis\u00e9s',
    ),
  ];

  Widget buildTestWidget({String? coachTip}) {
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
          child: CoupleNarrativeTimeline(
            acts: acts,
            partner1Name: 'Julien',
            partner2Name: 'Lauren',
            coachTip: coachTip,
          ),
        ),
      ),
    );
  }

  group('CoupleNarrativeTimeline', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(CoupleNarrativeTimeline), findsOneWidget);
    });

    testWidgets('shows header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('histoire'), findsWidgets);
    });

    testWidgets('shows 3 acts', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('ACTE 1'), findsOneWidget);
      expect(find.textContaining('ACTE 2'), findsOneWidget);
      expect(find.textContaining('ACTE 3'), findsOneWidget);
    });

    testWidgets('shows act titles', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('travaillez'), findsWidgets);
      expect(find.textContaining('retraite'), findsWidgets);
    });

    testWidgets('shows income changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('-23%'), findsWidgets);
    });

    testWidgets('shows coach tip when present', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        coachTip: 'Le moment id\u00e9al pour retirer le 3a.',
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('3a'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('handles empty acts', (tester) async {
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
          body: CoupleNarrativeTimeline(
            acts: const [],
            partner1Name: 'A',
            partner2Name: 'B',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CoupleNarrativeTimeline), findsOneWidget);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
