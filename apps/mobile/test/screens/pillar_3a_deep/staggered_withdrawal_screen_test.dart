import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildStaggeredScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: StaggeredWithdrawalScreen(),
    );
  }

  testWidgets('StaggeredWithdrawalScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildStaggeredScreen());
    await tester.pump();
    expect(find.byType(StaggeredWithdrawalScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });
}
