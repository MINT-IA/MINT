import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';

Widget _wrap() {
  return const MaterialApp(
    locale: Locale('fr'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: OnboardingShellScreen(),
  );
}

Future<void> _openAxes(WidgetTester tester) async {
  await tester.pumpWidget(_wrap());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': false},
    );
  });

  tearDown(() {
    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': false},
    );
  });

  testWidgets('flagged T2 shows the three Mint 2 axes at 375pt width',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': true},
    );

    await _openAxes(tester);

    expect(find.text('2e pilier : rente ou capital'), findsOneWidget);
    expect(find.text('Logement : 2e / 3e pilier'), findsWidgets);
    expect(find.text('3a et rachats : impact fiscal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signal axes stay signaletique and show no financial number',
      (tester) async {
    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': true},
    );

    await _openAxes(tester);
    await tester.tap(find.text('Logement : 2e / 3e pilier'));
    await tester.pumpAndSettle();

    expect(find.text('Logement : 2e / 3e pilier'), findsWidgets);
    expect(find.textContaining('Signalétique'), findsWidgets);
    expect(find.textContaining('/mois'), findsNothing);
    expect(find.textContaining('CHF'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
