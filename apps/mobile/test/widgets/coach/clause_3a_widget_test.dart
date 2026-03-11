import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildWidget({bool hasClause = false}) => MaterialApp(
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
            child: Clause3aWidget(
              balance3a: 85000,
              hasClause: hasClause,
              partnerName: 'Marion',
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('3a'), findsWidgets);
  });

  testWidgets('shows balance', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("85'000"), findsWidgets);
  });

  testWidgets('shows partner name', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Marion'), findsWidgets);
  });

  testWidgets('shows OPP3 legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('OPP3'), findsWidgets);
  });

  testWidgets('shows without clause state', (tester) async {
    await tester.pumpWidget(buildWidget(hasClause: false));
    expect(find.textContaining('Non'), findsWidgets);
  });

  testWidgets('shows with clause state', (tester) async {
    await tester.pumpWidget(buildWidget(hasClause: true));
    expect(find.textContaining('Oui'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('3a', caseSensitive: false)), findsOneWidget);
  });
}
