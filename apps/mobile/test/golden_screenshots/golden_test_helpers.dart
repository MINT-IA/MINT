import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';

/// iPhone 14 Pro logical dimensions (393×852).
const Size kGoldenDeviceSize = Size(393, 852);

/// Duration to wait for Google Fonts HTTP download in warmup.
const Duration kFontWarmupDuration = Duration(seconds: 5);

/// Duration to wait for animations after font warmup.
const Duration kAnimationDuration = Duration(seconds: 3);

/// Configures the test environment for golden screenshot capture.
///
/// - Mocks SharedPreferences
/// - Mocks path_provider (prevents MissingPluginException)
/// - Enables Google Fonts HTTP fetching
Future<void> setupGoldenEnvironment() async {
  SharedPreferences.setMockInitialValues({});

  // Mock path_provider to prevent MissingPluginException.
  // AnalyticsService and ReportPersistenceService use it in initState.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async => '/tmp',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider_macos'),
    (MethodCall methodCall) async => '/tmp',
  );

  // Allow Google Fonts to fetch via real HTTP.
  // Tests MUST use tester.runAsync() for the warmup test.
  GoogleFonts.config.allowRuntimeFetching = true;
  HttpOverrides.global = null;
}

/// Pumps widget inside runAsync (for real HTTP font fetch),
/// waits for fonts + animations, then does a final pump.
///
/// Use this pattern for every golden test:
/// ```dart
/// await pumpGoldenWidget(tester, buildGoldenWidget(MyScreen()));
/// await expectLater(find.byType(MyScreen), matchesGoldenFile(...));
/// ```
Future<void> pumpGoldenWidget(
  WidgetTester tester,
  Widget widget, {
  Duration warmup = const Duration(seconds: 3),
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    await Future.delayed(warmup);
  });
  // Final pump outside runAsync to render with loaded fonts.
  await tester.pump();
}

/// Sets up device viewport for consistent golden screenshots.
/// Call addTearDown(() => tester.view.resetPhysicalSize()) after this.
void setGoldenViewport(WidgetTester tester) {
  tester.view.physicalSize = kGoldenDeviceSize * 3.0;
  tester.view.devicePixelRatio = 3.0;
}

/// Wraps [child] in a fully configured MaterialApp for golden tests.
Widget buildGoldenWidget(
  Widget child, {
  CoachProfileProvider? coachProvider,
  List<SingleChildWidget> extraProviders = const [],
}) {
  final providers = <SingleChildWidget>[
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: coachProvider ?? CoachProfileProvider(),
    ),
    ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
    ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ...extraProviders,
  ];

  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00382E)),
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

/// Pre-filled with Julien's golden data (49 ans, VS, 122k CHF).
CoachProfileProvider buildJulienProvider() {
  final provider = CoachProfileProvider();
  provider.updateFromAnswers({
    'q_birth_year': 1977,
    'q_canton': 'VS',
    'q_net_income_period_chf': 8500.0,
    'q_employment_status': 'employee',
    'q_civil_status': 'marie',
    'q_children': 0,
    'q_housing_cost_period_chf': 1800.0,
    'q_has_pension_fund': 'yes',
    'q_has_3a': 'yes',
    'q_3a_annual_contribution': 7258.0,
    'q_emergency_fund': 'yes_3months',
    'q_main_goal': 'financial_health',
  });
  return provider;
}

/// Empty provider — brand-new user.
CoachProfileProvider buildEmptyProvider() {
  return CoachProfileProvider();
}
