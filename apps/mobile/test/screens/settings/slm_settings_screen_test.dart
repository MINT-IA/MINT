import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/slm_settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSlmScreen() {
    return ChangeNotifierProvider<SlmProvider>(
      create: (_) => SlmProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: SlmSettingsScreen(),
      ),
    );
  }

  testWidgets('SlmSettingsScreen renders without crashing', (tester) async {
    await tester.pumpWidget(buildSlmScreen());
    await tester.pump();
    expect(find.byType(SlmSettingsScreen), findsOneWidget);
  });
}
