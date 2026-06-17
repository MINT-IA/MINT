import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';

Widget _wrap(GoRouter router) {
  return MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/onb',
    routes: [
      GoRoute(
        path: '/onb',
        builder: (context, state) => const OnboardingShellScreen(),
      ),
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('RvC route sentinel', key: ValueKey('rvc-sentinel')),
          ),
        ),
      ),
    ],
  );
}

Future<void> _openAxes(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(_wrap(router));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FeatureFlags.enableMint2FirstExperienceEntry = true;
  });

  tearDown(() {
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  testWidgets('live Mint 2 axis routes directly to the RvC gate',
      (tester) async {
    final router = _router();

    await _openAxes(tester, router);
    await tester
        .tap(find.byKey(const ValueKey('mint2-axis-lpp_rente_capital')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/rente-vs-capital');
    expect(find.byKey(const ValueKey('rvc-sentinel')), findsOneWidget);
    expect(find.byType(OnboardingShellScreen), findsNothing);
  });
}
