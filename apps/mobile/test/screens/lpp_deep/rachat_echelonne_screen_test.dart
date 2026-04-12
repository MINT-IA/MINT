import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRachatScreen() {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RachatEchelonneScreen(),
      ),
    );
  }

  testWidgets('RachatEchelonneScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildRachatScreen());
    await tester.pump();
    expect(find.byType(RachatEchelonneScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });
}
