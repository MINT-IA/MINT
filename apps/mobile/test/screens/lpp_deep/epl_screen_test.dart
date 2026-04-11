import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildEplScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: EplScreen(),
    );
  }

  testWidgets('EplScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildEplScreen());
    await tester.pump();
    expect(find.byType(EplScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });
}
