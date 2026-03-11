import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/minimum_vital_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final items = [
    const MinimumVitalItem(
      label: 'Loyer',
      emoji: '🏠',
      amount: 1800,
      legalRef: 'LP art. 93',
    ),
    const MinimumVitalItem(
      label: 'Alimentation',
      emoji: '🍽️',
      amount: 1200,
      legalRef: 'LP art. 93',
      note: 'forfait OFS',
    ),
    const MinimumVitalItem(
      label: 'Transports',
      emoji: '🚌',
      amount: 200,
      legalRef: 'LP art. 93',
    ),
    const MinimumVitalItem(
      label: 'Assurance maladie',
      emoji: '🏥',
      amount: 400,
      legalRef: 'LAMal art. 65',
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
          body: SingleChildScrollView(
            child: MinimumVitalWidget(
              items: items,
              grossMonthly: 6000,
              totalDebts: 25000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('bouclier'), findsWidgets);
  });

  testWidgets('shows LP art 93 reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LP art. 93'), findsWidgets);
  });

  testWidgets('shows total protected', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 1800+1200+200+400 = 3600
    expect(find.textContaining("3'600"), findsWidgets);
  });

  testWidgets('shows seizable amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    // 6000-3600 = 2400
    expect(find.textContaining("2'400"), findsWidgets);
  });

  testWidgets('shows items', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Loyer'), findsOneWidget);
    expect(find.textContaining('Alimentation'), findsOneWidget);
  });

  testWidgets('shows action callout', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('avocat'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('minimum vital', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
