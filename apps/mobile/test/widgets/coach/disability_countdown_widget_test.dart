import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/disability_countdown_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget({double savings = 28000}) => MaterialApp(
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
            child: DisabilityCountdownWidget(
              monthlyExpenses: 5200,
              initialSavings: savings,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('temps tu tiens'), findsOneWidget);
  });

  testWidgets('shows 14-month AI delay', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('14'), findsWidgets);
  });

  testWidgets('shows slider', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows months can hold for low savings', (tester) async {
    await tester.pumpWidget(buildWidget(savings: 10000));
    // 10000/5200 ≈ 1.9 mois
    expect(find.textContaining('1.'), findsWidgets);
  });

  testWidgets('shows ok message for sufficient savings', (tester) async {
    await tester.pumpWidget(buildWidget(savings: 100000));
    // 100000/5200 ≈ 19.2 mois > 14 mois
    expect(find.textContaining('couvrent'), findsOneWidget);
  });

  testWidgets('shows actions when savings insufficient', (tester) async {
    await tester.pumpWidget(buildWidget(savings: 5000));
    expect(find.textContaining('urgence'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('rebours')), findsOneWidget);
  });
}
