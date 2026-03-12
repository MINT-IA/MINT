import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
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
            child: TestamentInvisibleWidget(
              patrimoine: 500000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('testament'), findsWidgets);
  });

  testWidgets('shows status selector chips', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Concubin'), findsWidgets);
    expect(find.textContaining('Marié'), findsWidgets);
  });

  testWidgets('shows patrimoine amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("500'000"), findsWidgets);
  });

  testWidgets('shows distribution section', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Distribution'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('Testament', caseSensitive: false)), findsOneWidget);
  });
}
