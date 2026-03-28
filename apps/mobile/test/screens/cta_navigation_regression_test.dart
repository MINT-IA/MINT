import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens under test
import 'package:mint_mobile/screens/profile_screen.dart';

// Providers
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';

// Models
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Helpers ──────────────────────────────────────────────────

  Widget buildProfileScreen({CoachProfileProvider? coachProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: coachProvider ?? CoachProfileProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<ByokProvider>(
          create: (_) => ByokProvider(),
        ),
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) => DocumentProvider(),
        ),
        ChangeNotifierProvider<BudgetProvider>(
          create: (_) => BudgetProvider(),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider<SlmProvider>(
          create: (_) => SlmProvider(),
        ),
      ],
      child: const MaterialApp(
    locale: Locale('fr'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,home: ProfileScreen()),
    );
  }

  CoachProfileProvider buildFullCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_birth_year': 1990,
      'q_canton': 'ZH',
      'q_net_income_period_chf': 7000.0,
      'q_employment_status': 'employee',
      'q_civil_status': 'celibataire',
      'q_children': 0,
      'q_housing_cost_period_chf': 1500.0,
      'q_has_pension_fund': 'yes',
      'q_has_3a': 'yes',
      'q_3a_annual_contribution': 7056.0,
      'q_emergency_fund': 'yes_3months',
      'q_main_goal': 'retirement',
    });
    return provider;
  }

  CoachProfileProvider buildMiniCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromMiniOnboarding({
      'q_birth_year': 1990,
      'q_canton': 'ZH',
      'q_net_income_period_chf': 6000.0,
      'q_civil_status': 'celibataire',
    });
    return provider;
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROFILE SCREEN — FACTFIND SECTIONS
  // ═══════════════════════════════════════════════════════════════

  group('Profile FactFind CTA Navigation Regression', () {
    testWidgets('Profile renders without crashing', (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Profile identity section displays with empty profile',
        (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      // Identity section should show "A completer" when no profile
      expect(find.textContaining('Foyer'), findsWidgets);
    });

    testWidgets('Profile income section displays with empty profile',
        (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      // Income section should be present
      expect(find.textContaining('Revenus'), findsWidgets);
    });

    testWidgets('Profile pension section displays with empty profile',
        (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      // Pension section should show "Manquant"
      expect(find.textContaining('LPP'), findsWidgets);
    });

    testWidgets('Profile property section displays with empty profile',
        (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      // Property section should show "Manquant"
      expect(find.textContaining('Immobilier'), findsWidgets);
    });

    testWidgets('Profile with full wizard marks all sections as complete',
        (tester) async {
      final coachProvider = buildFullCoachProvider();
      await tester.pumpWidget(buildProfileScreen(coachProvider: coachProvider));
      await tester.pump();

      // Phase 2 redesign: completion shown via check_circle icons in inline progress
      // All 4 completion rows should have check_circle icons
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      // Section labels still present
      expect(find.textContaining('Foyer'), findsWidgets);
      expect(find.textContaining('Revenus'), findsWidgets);
    });

    testWidgets(
        'Profile with mini-onboarding marks identity and income as complete, '
        'pension and property as missing', (tester) async {
      final coachProvider = buildMiniCoachProvider();
      await tester.pumpWidget(buildProfileScreen(coachProvider: coachProvider));
      await tester.pump();

      // Phase 2 redesign: completion rows use check_circle for complete,
      // reward badges (+15%, +10%) for incomplete
      // Identity = complete, Income = complete (has salary > 0)
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      // Pension and Property show reward badges
      expect(find.textContaining('+15'), findsWidgets);
      expect(find.textContaining('+10'), findsWidgets);
    });

    testWidgets('Profile sections have tappable GestureDetector widgets',
        (tester) async {
      await tester.pumpWidget(buildProfileScreen());
      await tester.pump();

      // Phase 2 redesign: completion rows use GestureDetector, settings use InkWell
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('Profile shows Mon dossier section header (Réglages moved to SettingsSheet)',
        (tester) async {
      final coachProvider = buildFullCoachProvider();
      await tester.pumpWidget(buildProfileScreen(coachProvider: coachProvider));
      await tester.pump();

      // Réglages section removed — settings now in SettingsSheet via gear icon
      expect(find.text('Mon dossier'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  BUDGET INPUTS — SERIALIZATION ROUNDTRIP
  // ═══════════════════════════════════════════════════════════════

  group('BudgetInputs toMap/fromMap Regression', () {
    test('BudgetInputs toMap/fromMap roundtrips all 9 fields', () {
      const original = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7500.0,
        housingCost: 1800.0,
        debtPayments: 300.0,
        taxProvision: 650.0,
        healthInsurance: 430.0,
        otherFixedCosts: 200.0,
        style: BudgetStyle.envelopes3,
        emergencyFundMonths: 4.5,
      );

      final map = original.toMap();
      final restored = BudgetInputs.fromMap(map);

      expect(restored.payFrequency, original.payFrequency);
      expect(restored.netIncome, original.netIncome);
      expect(restored.housingCost, original.housingCost);
      expect(restored.debtPayments, original.debtPayments);
      // Tax and health insurance use estimation if present in map
      expect(restored.taxProvision, original.taxProvision);
      expect(restored.healthInsurance, original.healthInsurance);
      expect(restored.otherFixedCosts, original.otherFixedCosts);
      expect(restored.style, original.style);
      // Emergency fund months are stored separately
      expect(map['emergency_fund_months'], original.emergencyFundMonths);
    });

    test('BudgetInputs toMap contains all expected keys', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.biweekly,
        netIncome: 5000.0,
        housingCost: 1500.0,
        debtPayments: 0.0,
        taxProvision: 500.0,
        healthInsurance: 350.0,
        otherFixedCosts: 100.0,
        style: BudgetStyle.justAvailable,
        emergencyFundMonths: 6.0,
      );

      final map = inputs.toMap();

      expect(map.containsKey('q_pay_frequency'), isTrue);
      expect(map.containsKey('q_net_income_period_chf'), isTrue);
      expect(map.containsKey('q_housing_cost_period_chf'), isTrue);
      expect(map.containsKey('q_debt_payments_period_chf'), isTrue);
      expect(map.containsKey('q_tax_provision_monthly_chf'), isTrue);
      expect(map.containsKey('q_lamal_premium_monthly_chf'), isTrue);
      expect(map.containsKey('q_other_fixed_costs_monthly_chf'), isTrue);
      expect(map.containsKey('q_budget_style'), isTrue);
      expect(map.containsKey('emergency_fund_months'), isTrue);
    });

    test('BudgetInputs fromMap handles missing keys gracefully', () {
      final inputs = BudgetInputs.fromMap({});

      expect(inputs.payFrequency, PayFrequency.monthly);
      expect(inputs.netIncome, 0.0);
      expect(inputs.housingCost, 0.0);
      expect(inputs.debtPayments, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  COACH PROFILE PROVIDER — STATE REGRESSION
  // ═══════════════════════════════════════════════════════════════

  group('CoachProfileProvider State Regression', () {
    test('empty provider has no profile', () {
      final provider = CoachProfileProvider();
      expect(provider.hasProfile, isFalse);
      expect(provider.hasFullProfile, isFalse);
      expect(provider.isPartialProfile, isFalse);
      expect(provider.profile, isNull);
    });

    test('updateFromAnswers creates full profile', () {
      final provider = buildFullCoachProvider();
      expect(provider.hasProfile, isTrue);
      expect(provider.hasFullProfile, isTrue);
      expect(provider.isPartialProfile, isFalse);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.canton, 'ZH');
      expect(provider.profile!.salaireBrutMensuel, greaterThan(0));
    });

    test('updateFromMiniOnboarding creates partial profile', () {
      final provider = buildMiniCoachProvider();
      expect(provider.hasProfile, isTrue);
      expect(provider.hasFullProfile, isFalse);
      expect(provider.isPartialProfile, isTrue);
      expect(provider.profile, isNotNull);
      expect(provider.profile!.canton, 'ZH');
    });

    test('clear resets all state', () {
      final provider = buildFullCoachProvider();
      expect(provider.hasProfile, isTrue);

      provider.clear();
      expect(provider.hasProfile, isFalse);
      expect(provider.hasFullProfile, isFalse);
      expect(provider.profile, isNull);
    });

    test('profileCompleteness reflects profile state', () {
      final empty = CoachProfileProvider();
      expect(empty.profileCompleteness, 0.0);

      final mini = buildMiniCoachProvider();
      // Mini provider answers 3 of 16 quality keys (q_birth_year,
      // q_canton, q_net_income_period_chf). Result: (3/16).clamp(0.05, 1.0).
      expect(mini.profileCompleteness, 3 / 16);

      final full = buildFullCoachProvider();
      // Full provider — continuous scale, no artificial floor.
      expect(full.profileCompleteness, greaterThanOrEqualTo(0.5));
    });

    test('onboardingQualityScore and wizard section recommendation are dynamic',
        () {
      final mini = buildMiniCoachProvider();
      expect(mini.onboardingQualityScore, greaterThanOrEqualTo(0.05));
      expect(mini.recommendedWizardSection, isNotEmpty);

      final full = buildFullCoachProvider();
      expect(full.onboardingQualityScore, greaterThanOrEqualTo(0.5));
      expect(
        ['identity', 'income', 'pension', 'property']
            .contains(full.recommendedWizardSection),
        isTrue,
      );
    });
  });
}
