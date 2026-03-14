import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/ninety_day_plan_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final phases = [
    const PlanPhase(
      title: 'Semaine 1',
      emoji: '\ud83d\udea8',
      deadline: 'J+7',
      urgencyColor: Colors.red,
      actions: [
        PlanAction(
          label: 'Inscription caisse AVS',
          consequence: 'D\u00e9lai 90j, sinon r\u00e9troactif',
          legalRef: 'LAVS art. 12',
          isCompleted: false,
        ),
        PlanAction(
          label: 'Num\u00e9ro TVA',
          isCompleted: true,
        ),
      ],
    ),
    const PlanPhase(
      title: 'Mois 2',
      emoji: '\ud83d\udcbc',
      deadline: 'J+30',
      urgencyColor: Colors.orange,
      actions: [
        PlanAction(
          label: 'Choix LPP ou Grand 3a',
          consequence: 'Impact fiscal majeur',
        ),
      ],
    ),
  ];

  Widget buildWidget() => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: NinetyDayPlanWidget(phases: phases),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Plan 90 jours'), findsOneWidget);
  });

  testWidgets('shows all phase titles', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Semaine 1'), findsOneWidget);
    expect(find.textContaining('Mois 2'), findsOneWidget);
  });

  testWidgets('shows action items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('AVS'), findsWidgets);
    expect(find.textContaining('TVA'), findsOneWidget);
  });

  testWidgets('shows deadline labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('J+7'), findsOneWidget);
    expect(find.textContaining('J+30'), findsOneWidget);
  });

  testWidgets('shows consequence text for action', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('troactif'), findsOneWidget);
  });

  testWidgets('shows progress counter', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 1 of 3 actions completed
    expect(find.textContaining('1/3'), findsOneWidget);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('returns shrink for empty phases', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: NinetyDayPlanWidget(phases: [])),
    ));
    expect(find.textContaining('Plan 90 jours'), findsNothing);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Plan 90 jours')), findsOneWidget);
  });
}
