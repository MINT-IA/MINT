import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens under test
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/open_banking/open_banking_hub_screen.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';
import 'package:mint_mobile/screens/open_banking/consent_screen.dart';

// Dependencies
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

/// Helper to wrap a widget with ProfileProvider.
Widget buildWithProfileProvider(Widget child, {bool hasDebt = false}) {
  final provider = ProfileProvider();
  provider.setProfile(Profile(
    id: 'test-profile-001',
    birthYear: 1990,
    canton: 'VD',
    householdType: HouseholdType.single,
    incomeNetMonthly: 6000,
    hasDebt: hasDebt,
    goal: Goal.other,
    createdAt: DateTime(2025, 1, 1),
  ));
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<ProfileProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

/// Standard test answers for report screens (V2 / FinancialReportScreenV2).
/// Uses String for q_children as expected by ReportBuilder.
Map<String, dynamic> get testAnswersV2 => <String, dynamic>{
      'q_firstname': 'TestUser',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
      'q_pay_frequency': 'monthly',
      'q_emergency_fund': 'yes_3months',
      'q_has_consumer_debt': 'no',
      'q_housing_status': 'renter',
      'q_housing_cost_period_chf': 1500.0,
      'q_has_pension_fund': 'yes',
      'q_3a_accounts_count': 1,
      'q_3a_providers': ['bank'],
      'q_3a_annual_contribution': 7258.0,
      'q_lpp_buyback_available': 0.0,
      'q_has_investments': 'no',
    };

void main() {
  // Ensure large viewport to avoid overflow errors in tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // 4. FINANCIAL REPORT SCREEN V2
  // ===========================================================================
  group('FinancialReportScreenV2', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FinancialReportScreenV2), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows app bar with plan title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Ton Plan Mint'), findsOneWidget);
    });

    testWidgets('displays health score header', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Bonjour'), findsOneWidget);
      // The header now shows a contextual status phrase (replaces numeric score)
      expect(find.textContaining('base'), findsWidgets);
    });

    testWidgets('displays circle diagnosis section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Thematic cards replaced circles — check for a thematic card title
      expect(find.textContaining('Ton Budget'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 6. OPEN BANKING HUB SCREEN
  // ===========================================================================
  group('OpenBankingHubScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(OpenBankingHubScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // i18n: openBankingFinmaGate with accents
      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // i18n: demo mode label
      expect(find.textContaining('monstration'), findsWidgets);
    });

    testWidgets('displays Open Banking header', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Open Banking'), findsWidgets);
    });

    testWidgets('shows connected accounts section title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('COMPTES CONNECTES'), findsOneWidget);
      expect(find.text('APERCU FINANCIER'), findsOneWidget);
    });

    testWidgets('displays mock bank accounts', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show mock bank names in account cards
      expect(find.textContaining('UBS'), findsWidgets);
      expect(find.textContaining('PostFinance'), findsWidgets);
    });

    testWidgets('shows bLink badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('bLink'), findsOneWidget);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });
  });

  // ===========================================================================
  // 7. TRANSACTION LIST SCREEN
  // ===========================================================================
  group('TransactionListScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(TransactionListScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('monstration'), findsWidgets);
    });

    testWidgets('shows TRANSACTIONS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('ransaction'), findsWidgets);
    });

    testWidgets('displays period selector', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('shows category filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Toutes'), findsOneWidget);
    });

    testWidgets('displays monthly summary section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The monthly summary is far down the scroll; check it exists in the tree
      expect(find.textContaining('ynth'), findsWidgets);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });
  });

  // ===========================================================================
  // 8. CONSENT SCREEN
  // ===========================================================================
  group('ConsentScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows CONSENTEMENTS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('onsentement'), findsWidgets);
    });

    testWidgets('displays active consents section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('CONSENTEMENTS ACTIFS'), findsOneWidget);
    });

    testWidgets('displays consent cards with bank names', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Mock consents include UBS, PostFinance, Raiffeisen
      expect(find.text('UBS'), findsOneWidget);
      expect(find.text('PostFinance'), findsOneWidget);
      expect(find.text('Raiffeisen'), findsOneWidget);
    });

    testWidgets('shows revocation buttons for active consents', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // All 3 mock consents are active, so 3 revoke buttons
      expect(find.textContaining('voquer'), findsWidgets);
    });

    testWidgets('shows nLPD info card', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Tes droits (nLPD)'), findsOneWidget);
    });

    testWidgets('has add consent button', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Ajouter un consentement'), findsOneWidget);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });

    testWidgets('shows scope labels on consent cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Autorisations'), findsWidgets);
      expect(find.text('Comptes'), findsWidgets);
      expect(find.text('Soldes'), findsWidgets);
    });
  });
}
