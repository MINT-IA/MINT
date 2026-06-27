import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';

const _mint2AxisHandoffKey = 'mint2_axis_handoff_v1';
const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Widget _wrap(GoRouter router, {AuthProvider? authProvider}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider ?? AuthProvider(),
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
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

Future<void> _openAxes(
  WidgetTester tester,
  GoRouter router, {
  AuthProvider? authProvider,
}) async {
  await tester.pumpWidget(_wrap(router, authProvider: authProvider));
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets(
      'live Mint 2 axis routes directly to the RvC gate with dossier axis',
      (tester) async {
    final router = _router();
    final authProvider = AuthProvider();

    await _openAxes(tester, router, authProvider: authProvider);
    await tester
        .tap(find.byKey(const ValueKey('mint2-axis-lpp_rente_capital')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/rente-vs-capital');
    expect(find.byKey(const ValueKey('rvc-sentinel')), findsOneWidget);
    expect(find.byType(OnboardingShellScreen), findsNothing);
    expect(authProvider.authLifecycle.state, AuthLifecycleKind.guestEmpty);
    expect(authProvider.authLifecycle.allowsMainNavigation, isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wizard_answers_v2'), isNull);
    final handoff = json.decode(prefs.getString(_mint2AxisHandoffKey)!)
        as Map<String, dynamic>;
    expect(handoff['onb_axis_v2'], 'lpp_rente_capital');
    expect(handoff['onb_axis_schema_version'], 2);
    expect(answers, isNot(contains('q_net_income_period_chf')));
    expect(answers, isNot(contains('renteNetMensuelle')));
    expect(answers, isNot(contains('capitalProjecte')));
  });

  testWidgets('live Mint 2 axis preserves sealed wizard placeholders',
      (tester) async {
    final rawWizard = json.encode({
      'q_canton': 'VD',
      'q_net_income_period_chf': '__secure__',
    });
    SharedPreferences.setMockInitialValues({
      'wizard_answers_v2': rawWizard,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      if (call.method == 'read') {
        throw PlatformException(
          code: '-34018',
          message: 'errSecMissingEntitlement',
        );
      }
      return null;
    });
    final router = _router();

    await _openAxes(tester, router);
    await tester
        .tap(find.byKey(const ValueKey('mint2-axis-lpp_rente_capital')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wizard_answers_v2'), rawWizard);
    final handoff = json.decode(prefs.getString(_mint2AxisHandoffKey)!)
        as Map<String, dynamic>;
    expect(handoff['onb_axis_v2'], 'lpp_rente_capital');
  });
}
