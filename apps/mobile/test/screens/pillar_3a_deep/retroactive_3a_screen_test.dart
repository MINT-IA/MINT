import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRetroactive3aScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Retroactive3aScreen(),
    );
  }

  testWidgets('Retroactive3aScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildRetroactive3aScreen());
    await tester.pump();
    expect(find.byType(Retroactive3aScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });
}
