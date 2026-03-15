import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_slider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final scenarios = [
    const RetirementAgeScenario(
        age: 63, monthlyIncome: 4510, deltaPercent: -14, lifetimeDelta: -174000),
    const RetirementAgeScenario(
        age: 64, monthlyIncome: 4850, deltaPercent: -7),
    const RetirementAgeScenario(
        age: 65, monthlyIncome: 5234, deltaPercent: 0),
    const RetirementAgeScenario(
        age: 66, monthlyIncome: 5644, deltaPercent: 8),
    const RetirementAgeScenario(
        age: 67, monthlyIncome: 6050, deltaPercent: 16),
  ];

  Widget buildTestWidget({int initialAge = 65}) {
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
          child: EarlyRetirementSlider(
            scenarios: scenarios,
            monthlyIncomeAt65: 5234,
            initialAge: initialAge,
          ),
        ),
      ),
    );
  }

  group('EarlyRetirementSlider', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(EarlyRetirementSlider), findsOneWidget);
    });

    testWidgets('shows "Et si je partais" header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('partais'), findsWidgets);
    });

    testWidgets('shows initial age 65', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialAge: 65));
      await tester.pumpAndSettle();
      expect(find.textContaining('65'), findsWidgets);
    });

    testWidgets('shows slider', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows zone label', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialAge: 65));
      await tester.pumpAndSettle();
      expect(find.textContaining('Standard'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('handles empty scenarios', (tester) async {
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
          body: EarlyRetirementSlider(
            scenarios: [],
            monthlyIncomeAt65: 5234,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(EarlyRetirementSlider), findsOneWidget);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
