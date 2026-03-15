import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/prix_du_silence_widget.dart';
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
            child: PrixDuSilenceWidget(
              patrimoine: 500000,
              marriedTaxRate: 0.02,
              concubinTaxRate: 0.40,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('silence'), findsWidgets);
  });

  testWidgets('shows marié scenario', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Marié'), findsWidgets);
  });

  testWidgets('shows concubin scenario', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Concubin'), findsWidgets);
  });

  testWidgets('shows patrimoine amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("500'000"), findsWidgets);
  });

  testWidgets('shows difference callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('coûte'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('silence', caseSensitive: false)), findsOneWidget);
  });
}
