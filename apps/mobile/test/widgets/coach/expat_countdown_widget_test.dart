import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/expat_countdown_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final departure = DateTime.now().add(const Duration(days: 90));

  final deadlines = [
    const ExpatDeadline(
      label: 'Clôturer le compte 3a',
      emoji: '💰',
      daysFromDeparture: -30,
      action: 'Contacter ta banque pour clôture 3a avant départ.',
      legalRef: 'OPP3 art. 1',
      consequence: 'Impossibilité de rachat futur.',
    ),
    const ExpatDeadline(
      label: 'Transférer libre passage LPP',
      emoji: '🏦',
      daysFromDeparture: 0,
      action: 'Virer le capital LPP sur un compte de libre passage.',
      legalRef: 'LPP art. 5',
      isEuOnly: true,
    ),
  ];

  Widget buildWidget({bool isEu = false}) => MaterialApp(
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
            child: ExpatCountdownWidget(
              departureDate: departure,
              deadlines: deadlines,
              isEuDestination: isEu,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Checklist'), findsWidgets);
  });

  testWidgets('shows progress text', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('actions complétées'), findsWidgets);
  });

  testWidgets('shows deadline labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('3a'), findsWidgets);
  });

  testWidgets('shows legal references', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('OPP3'), findsWidgets);
  });

  testWidgets('hides EU-only deadlines when not EU', (tester) async {
    await tester.pumpWidget(buildWidget(isEu: false));
    // 'Virer le capital LPP' is the action text unique to the EU-only deadline card
    expect(find.textContaining('Virer le capital LPP'), findsNothing);
  });

  testWidgets('shows EU-only deadlines when isEuDestination', (tester) async {
    await tester.pumpWidget(buildWidget(isEu: true));
    expect(find.textContaining('Virer le capital LPP'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('rebours expatriation', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
