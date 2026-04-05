import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
/// Golden tests use a fixed size for consistent screenshots.
const Size kGoldenDeviceSize = Size(393, 852);

/// Configures the test environment for golden screenshot capture.
///
/// Call this in setUp() before each golden test group.
Future<void> setupGoldenEnvironment() async {
  SharedPreferences.setMockInitialValues({});
  // Allow runtime font fetching via real HTTP (not FakeAsync).
  // Tests must use tester.runAsync() to allow HTTP requests.
  GoogleFonts.config.allowRuntimeFetching = true;
  HttpOverrides.global = null;
}

/// Wraps [child] in a fully configured MaterialApp suitable for golden tests.
///
/// Includes:
/// - French localization
/// - CoachProfileProvider (optionally pre-filled)
/// - Theme with MintColors
/// - Fixed size viewport
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

/// Creates a [CoachProfileProvider] pre-filled with Julien's golden data.
///
/// Julien: 49 ans, VS (Sion), 122'207 CHF/an, swiss_native.
CoachProfileProvider buildJulienProvider() {
  final provider = CoachProfileProvider();
  provider.updateFromAnswers({
    'q_birth_year': 1977,
    'q_canton': 'VS',
    'q_net_income_period_chf': 8500.0, // ~102k net
    'q_employment_status': 'employee',
    'q_civil_status': 'marie',
    'q_children': 0,
    'q_housing_cost_period_chf': 1800.0,
    'q_has_pension_fund': 'yes',
    'q_has_3a': 'yes',
    'q_3a_annual_contribution': 7258.0,
    'q_emergency_fund': 'yes_3months',
    'q_main_goal': 'retirement',
  });
  return provider;
}

/// Creates a [CoachProfileProvider] with empty/default data.
/// Simulates a brand-new user who hasn't entered anything.
CoachProfileProvider buildEmptyProvider() {
  return CoachProfileProvider();
}
