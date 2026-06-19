import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';

Widget _wrap({TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider()),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(375, 812),
          textScaler: textScaler,
        ),
        child: const OnboardingShellScreen(),
      ),
    ),
  );
}

void _pinIPhone13Mini(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _reachEmploymentStep(WidgetTester tester) async {
  await _tapKey(tester, 'onboarding-entry-open');
  await _tapKey(tester, 'onboarding-intent-impots');
  await _tapKey(tester, 'us-tax-person-no');
  final nationality = find.byKey(const ValueKey('onboarding-nationality-ch'));
  if (nationality.evaluate().isNotEmpty) {
    await tester.ensureVisible(nationality);
    await tester.pumpAndSettle();
    await tester.tap(nationality);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FlutterSecureStorage.setMockInitialValues({});
    FeatureFlags.enableMint2FirstExperienceEntry = true;
  });

  tearDown(() {
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  testWidgets('Mint 2 axes fit the iPhone 13 mini width without overflow',
      (tester) async {
    _pinIPhone13Mini(tester);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await _tapKey(tester, 'onboarding-entry-open');

    expect(find.text('2e pilier : rente ou capital'), findsOneWidget);
    expect(find.text('Logement : 2e / 3e pilier'), findsWidgets);
    expect(find.text('3a et rachats : impact fiscal'), findsOneWidget);
  });

  testWidgets('employment labels and canton order fit iPhone 13 mini',
      (tester) async {
    _pinIPhone13Mini(tester);
    FeatureFlags.enableMint2FirstExperienceEntry = false;

    await tester.pumpWidget(
      _wrap(textScaler: const TextScaler.linear(1.3)),
    );
    await tester.pumpAndSettle();
    await _reachEmploymentStep(tester);

    for (final label in const ['Salarié', 'Indépendant', 'Sans activité']) {
      final textRect = tester.getRect(find.text(label));
      final buttonRect = tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        ),
      );
      expect(textRect.top, greaterThanOrEqualTo(buttonRect.top + 4));
      expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom - 4));
    }

    await _tapKey(tester, 'onboarding-employment-salarie');
    await _tapKey(tester, 'onboarding-civil-marie');
    await _tapKey(tester, 'onboarding-avs-no-gaps');
    await tester.tap(find.text('Choisir ma date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'onboarding-dob-continue');
    final agTop = tester.getTopLeft(find.text('AG')).dy;
    final aiTop = tester.getTopLeft(find.text('AI')).dy;
    final arTop = tester.getTopLeft(find.text('AR')).dy;
    final beTop = tester.getTopLeft(find.text('BE')).dy;

    expect((agTop - aiTop).abs() + (agTop - arTop).abs(), lessThan(2));
    expect(agTop, lessThan(beTop));
  });
}
