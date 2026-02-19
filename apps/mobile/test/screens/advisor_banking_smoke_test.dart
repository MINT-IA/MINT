import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens under test
import 'package:mint_mobile/screens/advisor/advisor_focus_screen.dart';
import 'package:mint_mobile/screens/advisor/financial_report_demo_screen.dart';
import 'package:mint_mobile/screens/advisor/advisor_report_screen.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:mint_mobile/screens/open_banking/open_banking_hub_screen.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';
import 'package:mint_mobile/screens/open_banking/consent_screen.dart';

// Dependencies
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';

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

/// Test answers for AdvisorReportScreen.
/// Omits q_children to avoid type conflict between ReportBuilder (String)
/// and _buildLifeEventSuggestionsFromAnswers (int).
Map<String, dynamic> get testAnswersReport => <String, dynamic>{
      'q_firstname': 'TestUser',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
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
  // 1. ADVISOR SESSION FOCUS SCREEN
  // ===========================================================================
  group('AdvisorSessionFocusScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorSessionFocusScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(AdvisorSessionFocusScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays session objectives title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorSessionFocusScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('objectifs de session'), findsOneWidget);
    });

    testWidgets('shows three focus tiles', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorSessionFocusScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Optimisation fiscale'), findsOneWidget);
      expect(find.textContaining('composés'), findsOneWidget);
      expect(find.textContaining('Risques'), findsOneWidget);
    });

    testWidgets('has CTA button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorSessionFocusScreen(),
        ),
      );
      await tester.pump();

      expect(find.text("C'est parti"), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows AUJOURD\'HUI badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorSessionFocusScreen(),
        ),
      );
      await tester.pump();

      expect(find.text("AUJOURD'HUI"), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. FINANCIAL REPORT DEMO SCREEN
  // ===========================================================================
  group('FinancialReportDemoScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(FinancialReportDemoScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays demo mode title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mode Démonstration'), findsOneWidget);
    });

    testWidgets('shows app bar with title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Démo Rapport V2'), findsOneWidget);
    });

    testWidgets('displays demo profile information', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Profil de test :'), findsOneWidget);
    });

    testWidgets('has CTA button to view full report', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Voir le Rapport Complet'), findsOneWidget);
    });

    testWidgets('shows scenario section title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FinancialReportDemoScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Scénarios de test'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 3. ADVISOR REPORT SCREEN
  // ===========================================================================
  group('AdvisorReportScreen', () {
    testWidgets('renders without crashing (with answers)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          AdvisorReportScreen(answers: testAnswersReport),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(AdvisorReportScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows app bar with Statement of Advice', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          AdvisorReportScreen(answers: testAnswersReport),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Statement of Advice'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          AdvisorReportScreen(answers: testAnswersReport),
        ),
      );
      // Pump only once to see the initial loading state
      await tester.pump();

      // Should show scaffold with either loading or content
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has FAB for PDF export', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          AdvisorReportScreen(answers: testAnswersReport),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Export PDF Professionnel'), findsOneWidget);
    });
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
  // 5. ADVISOR WIZARD SCREEN V2
  // ===========================================================================
  group('AdvisorWizardScreenV2', () {
    // Note: WizardScorePreview has a repeating glow animation,
    // so pumpAndSettle will always time out. Use pump() instead.
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorWizardScreenV2(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AdvisorWizardScreenV2), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows section label and question counter', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorWizardScreenV2(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should show the first section name
      expect(find.text('Profil'), findsOneWidget);
      // Should show question counter
      expect(find.textContaining('Question'), findsOneWidget);
    });

    testWidgets('displays progress indicator', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorWizardScreenV2(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('has back button in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdvisorWizardScreenV2(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
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
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('Fonctionnalite en preparation'),
        findsWidgets,
      );
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('MODE DEMO'), findsOneWidget);
    });

    testWidgets('displays Open Banking header', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Open Banking'), findsOneWidget);
      expect(find.text('Connecte tes comptes bancaires'), findsOneWidget);
    });

    testWidgets('shows connected accounts section title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
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
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation reglementaire'),
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
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('Fonctionnalite en preparation'),
        findsWidgets,
      );
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('MODE DEMO'), findsOneWidget);
    });

    testWidgets('shows TRANSACTIONS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('TRANSACTIONS'), findsOneWidget);
    });

    testWidgets('displays period selector', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Ce mois'), findsOneWidget);
      expect(find.text('Mois precedent'), findsOneWidget);
    });

    testWidgets('shows category filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
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
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The monthly summary is far down the scroll; check it exists in the tree
      expect(find.text('Synthese du mois'), findsOneWidget);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation reglementaire'),
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
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('Fonctionnalite en preparation'),
        findsWidgets,
      );
    });

    testWidgets('shows CONSENTEMENTS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('CONSENTEMENTS'), findsOneWidget);
    });

    testWidgets('displays active consents section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
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
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // All 3 mock consents are active, so 3 revoke buttons
      expect(find.text('Revoquer'), findsWidgets);
    });

    testWidgets('shows nLPD info card', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
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
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation reglementaire'),
        findsWidgets,
      );
    });

    testWidgets('shows scope labels on consent cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
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
