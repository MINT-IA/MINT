import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/interactive_simulations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('3a simulation frames tax effect as estimated reduction',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Interactive3aSimulation(
          initialMonthlyContribution: 400,
          initialYears: 10,
          isEmployee: true,
        ),
      ),
    );

    expect(find.text('Réduction d’impôt estimée'), findsOneWidget);
    expect(find.text('Réduction d’impôt estimée (10 ans)'), findsOneWidget);
    expect(find.textContaining('Économie d’impôts'), findsNothing);
    expect(find.textContaining("Économie d'impôts"), findsNothing);
    expect(find.textContaining('Économies fiscales'), findsNothing);
  });

  testWidgets('LPP buyback simulation frames tax effect as estimated reduction',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InteractiveLppBuybackSimulation(
          initialBuybackAmount: 20000,
          initialMarginalTaxRate: 30,
        ),
      ),
    );

    expect(find.text('Réduction d’impôt estimée'), findsOneWidget);
    expect(find.textContaining('Économie d’impôts'), findsNothing);
    expect(find.textContaining("Économie d'impôts"), findsNothing);
    expect(find.textContaining('Économies fiscales'), findsNothing);
  });
}
