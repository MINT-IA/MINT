import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/hero_retirement_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    HeroCardMode mode = HeroCardMode.full,
    double? monthlyIncome,
    double? replacementRatio,
    double? rangeMin,
    double? rangeMax,
    double? currentMonthlySalary,
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
          child: HeroRetirementCard(
            mode: mode,
            monthlyIncome: monthlyIncome,
            replacementRatio: replacementRatio,
            rangeMin: rangeMin,
            rangeMax: rangeMax,
            currentMonthlySalary: currentMonthlySalary,
          ),
        ),
      ),
    );
  }

  group('HeroRetirementCard', () {
    testWidgets('renders without crashing in full mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        monthlyIncome: 5234,
        replacementRatio: 63,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(HeroRetirementCard), findsOneWidget);
    });

    testWidgets('shows "Ton salaire apres 65" header in full mode',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(monthlyIncome: 5234));
      await tester.pumpAndSettle();
      expect(find.textContaining('salaire'), findsWidgets);
    });

    testWidgets('P1-A: shows before/after when currentMonthlySalary set',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        monthlyIncome: 5234,
        replacementRatio: 63,
        currentMonthlySalary: 8333,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining("Aujourd'hui"), findsOneWidget);
      expect(find.textContaining('retraite'), findsWidgets);
    });

    testWidgets('P1-A: replacement ratio shows human explanation',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        monthlyIncome: 5234,
        replacementRatio: 63,
        currentMonthlySalary: 8333,
      ));
      await tester.pumpAndSettle();
      // Non-breaking space (\u00a0) before % per French typography rules
      expect(find.textContaining('63\u00a0%'), findsWidgets);
      expect(find.textContaining('train de vie'), findsWidgets);
    });

    testWidgets('renders range mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        mode: HeroCardMode.range,
        rangeMin: 3500,
        rangeMax: 5500,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(HeroRetirementCard), findsOneWidget);
      expect(find.textContaining('Entre'), findsWidgets);
    });

    testWidgets('renders educational mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        mode: HeroCardMode.educational,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(HeroRetirementCard), findsOneWidget);
      expect(find.textContaining('manque'), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget(monthlyIncome: 5234));
      await tester.pumpAndSettle();
      expect(find.textContaining('conseil'), findsWidgets);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget(monthlyIncome: 5234));
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
