import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/budget/spending_meter.dart';

void main() {
  testWidgets('SpendingMeter labels capacity as allocation, not free money',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SpendingMeter(
            variablesAmount: 3333,
            futureAmount: 500,
            totalAvailable: 3833,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text('À répartir'), findsOneWidget);
    expect(find.text('Disponible'), findsNothing);
    expect(find.text("CHF 3'833"), findsOneWidget);
    expect(find.text('Variables 87 %'), findsOneWidget);
    expect(find.text('Futur 13 %'), findsOneWidget);
  });
}
