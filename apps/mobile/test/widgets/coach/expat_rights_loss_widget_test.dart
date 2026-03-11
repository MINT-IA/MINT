import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/expat_rights_loss_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  final rights = [
    const ExpatRight(
      label: 'Rente AVS réduite',
      emoji: '🏛️',
      before: 'CHF 2\'520/mois max',
      after: 'CHF 1\'710/mois (lacune 15 ans)',
      legalRef: 'LAVS art. 29bis',
      impact: 'Perte de CHF 810/mois à vie.',
      isIrreversible: true,
    ),
    const ExpatRight(
      label: 'LAMal suspendue',
      emoji: '🏥',
      before: 'Couverture complète',
      after: 'Couverture nulle hors CH',
      legalRef: 'LAMal art. 3',
      impact: 'Tu dois souscrire une assurance locale.',
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
            child: ExpatRightsLossWidget(
              rights: rights,
              destination: 'France',
              isEuDestination: isEu,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('perds'), findsWidgets);
  });

  testWidgets('shows destination', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('France'), findsWidgets);
  });

  testWidgets('shows right labels', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('AVS'), findsWidgets);
    expect(find.textContaining('LAMal'), findsWidgets);
  });

  testWidgets('shows IRRÉVERSIBLE badge for irreversible right', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('IRRÉVERSIBLE'), findsWidgets);
  });

  testWidgets('shows legal references', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('LAVS'), findsWidgets);
  });

  testWidgets('shows EU badge when isEuDestination', (tester) async {
    await tester.pumpWidget(buildWidget(isEu: true));
    expect(find.textContaining('totalisation'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('expatriation', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
