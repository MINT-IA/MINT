import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/disability_reset_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DisabilityResetWidget(
              currentAge: 45,
              currentSalary: 100000,
              reducedSalary: 55000,
              capitalBefore: 520000,
              capitalAfter: 310000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('reset'), findsWidgets);
  });

  testWidgets('shows age and LPP rate', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('45 ans'), findsWidgets);
    expect(find.textContaining('15'), findsWidgets);
  });

  testWidgets('shows capital before and after', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("520'000"), findsWidgets);
    expect(find.textContaining("310'000"), findsWidgets);
  });

  testWidgets('shows capital delta', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("210'000"), findsWidgets);
  });

  testWidgets('shows monthly rente lost', (tester) async {
    await tester.pumpWidget(buildWidget());
    // Shows per-month rente impact
    expect(find.textContaining('/mois'), findsWidgets);
  });

  testWidgets('shows narrative text', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('retraite'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Reset silencieux')), findsOneWidget);
  });
}
