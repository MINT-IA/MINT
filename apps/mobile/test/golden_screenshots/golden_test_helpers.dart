import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Time advanced after the initial pump so post-frame callbacks (animation
/// controllers, microtasks) flush before the snapshot is captured. After
/// MVP-GOOGLEFONTS-PURGE-V1 (2026-05-10) this no longer waits for a real
/// HTTP font fetch — Fontshare assets load synchronously via [FontLoader].
/// The duration is now FakeAsync time, not wall-clock, so 1 s is enough to
/// absorb any reasonable initState animation curve.
const Duration kFontWarmupDuration = Duration(seconds: 1);

/// Duration to wait for animations after font warmup.
const Duration kAnimationDuration = Duration(seconds: 3);

/// Loads the bundled Fontshare typefaces (Supreme + Gambarino) into the
/// test binding so widgets render with the canonical glyphs (not the
/// test-default Ahem font).
///
/// MVP-GOOGLEFONTS-PURGE-V1 (2026-05-10) — replaces the prior GoogleFonts
/// HTTP-fetch warmup, which hung FakeAsync timers in the test binding
/// (« A Timer is still pending » assertion). Bundled fonts load
/// synchronously from `assets/fonts/` ; no socket, no timer.
Future<void> _loadFontFromAssets(String family, String assetPath) async {
  final loader = FontLoader(family);
  final ByteData bytes = await rootBundle.load(assetPath);
  loader.addFont(Future<ByteData>.value(bytes));
  await loader.load();
}

/// Configures the test environment for golden screenshot capture.
///
/// - Mocks SharedPreferences
/// - Mocks path_provider (prevents MissingPluginException)
/// - Loads bundled Fontshare fonts (Supreme + Gambarino)
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

  // Load all 4 bundled font assets declared in pubspec.yaml so glyph
  // rendering matches production (Supreme regular/medium/bold + Gambarino).
  await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Regular.otf');
  await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Medium.otf');
  await _loadFontFromAssets('Supreme', 'assets/fonts/Supreme-Bold.otf');
  await _loadFontFromAssets('Gambarino', 'assets/fonts/Gambarino-Regular.otf');
}

/// Pumps the widget and advances FakeAsync time to render the post-warmup
/// frame.
///
/// MVP-GOOGLEFONTS-PURGE-V1 simplification: no more `tester.runAsync`, no
/// more real HTTP-fetch wait. Bundled fonts are loaded synchronously by
/// [setupGoldenEnvironment] before the test runs, so the only remaining
/// purpose of `warmup` is to absorb post-frame schedulings (animation
/// controllers that start a curve in initState).
///
/// We deliberately do NOT call `pumpAndSettle` because some screens
/// (e.g., PrivacyControlScreen) have indefinitely-running animations or
/// streams that would never settle ; those tests previously survived only
/// because the GoogleFonts warmup pattern bypassed full settling.
Future<void> pumpGoldenWidget(
  WidgetTester tester,
  Widget widget, {
  Duration warmup = const Duration(seconds: 1),
}) async {
  await tester.pumpWidget(widget);
  // Advance FakeAsync to flush the initial frame's post-frame callbacks
  // (AnimationController.forward(), Future.microtask, etc.).
  await tester.pump(warmup);
  // Final synchronous pump so the snapshot reflects the settled-frame state.
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
