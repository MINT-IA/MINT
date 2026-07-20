import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  });

  testWidgets(
      'live first-job enrichment CTA carries origin and save returns there',
      (tester) async {
    final provider = CoachProfileProvider();
    final router = _firstJobRouter();
    addTearDown(provider.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(_minimalRouterHarness(provider, router));
    await _pumpFrames(tester, frames: 20);

    final enrichCta = find.byKey(const Key('first_job_enrich_profile_cta'));
    expect(enrichCta, findsOneWidget);
    final enrichButton = find.descendant(
      of: enrichCta,
      matching: find.byType(TextButton),
    );
    expect(enrichButton, findsOneWidget);
    await tester.ensureVisible(enrichButton);
    tester.widget<TextButton>(enrichButton).onPressed!();
    await _pumpFrames(tester);

    final collector = find.byType(DataBlockEnrichmentScreen);
    expect(collector, findsOneWidget);
    final collectorUri = GoRouterState.of(tester.element(collector)).uri;
    expect(collectorUri.path, '/data-block/revenu');
    expect(collectorUri.queryParameters['returnUri'], '/first-job');

    await tester.enterText(find.byKey(const Key('canton_picker')), 'GE');
    await tester.enterText(find.byKey(const Key('salary_input')), '96000');
    await tester.tap(find.byKey(const Key('salary_save_cta')));
    await _pumpFrames(tester);

    final returnedScreen = find.byType(FirstJobScreen);
    expect(returnedScreen, findsOneWidget);
    expect(
      GoRouterState.of(tester.element(returnedScreen)).uri.toString(),
      '/first-job',
    );
    expect(enrichCta, findsOneWidget);
  });

  testWidgets('production /first-job is fail-closed', (tester) async {
    expect(parseDataBlockReturnTarget(null), isNull);
    final original = FeatureFlags.enableFirstJobScreen;
    addTearDown(() => FeatureFlags.enableFirstJobScreen = original);
    FeatureFlags.enableFirstJobScreen = false;
    final router = await _pumpProductionRouter(tester);
    router.go('/first-job');
    await _pumpFrames(tester);
    expect(find.byType(FirstJobScreen), findsNothing);
    expect(find.text('Premier emploi'), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/explore/travail');
  });
}

GoRouter _firstJobRouter() {
  return GoRouter(
    initialLocation: '/first-job',
    routes: [
      GoRoute(
        path: '/first-job',
        builder: (context, state) => const FirstJobScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          key: Key('first_job_wrong_fallback'),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (context, state) {
          final returnTarget = parseDataBlockReturnTarget(
            state.uri.queryParameters['returnUri'],
          );
          return DataBlockEnrichmentScreen(
            blockType: state.pathParameters['type']!,
            initialInputKey: state.uri.queryParameters['inputKey'],
            returnTarget: returnTarget,
          );
        },
      ),
    ],
  );
}

Widget _minimalRouterHarness(
  CoachProfileProvider provider,
  GoRouter router,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
    ],
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

Future<GoRouter> _pumpProductionRouter(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  try {
    await tester.pumpWidget(const MintApp());
    await _pumpFrames(tester, frames: 40);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }

  final scaffold = find.byType(Scaffold);
  expect(scaffold, findsWidgets);
  return GoRouter.of(tester.element(scaffold.last));
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 12,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
