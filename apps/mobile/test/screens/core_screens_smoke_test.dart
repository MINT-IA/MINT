import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Screens under test
import 'package:mint_mobile/screens/advisor/advisor_onboarding_screen.dart';
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
import 'package:mint_mobile/screens/portfolio_screen.dart';

// Dependencies for PortfolioScreen and AdvisorOnboardingScreen
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // 2. ADVISOR ONBOARDING SCREEN
  // ===========================================================================

  group('AdvisorOnboardingScreen', () {
    Widget buildOnboarding() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider(),
          ),
          ChangeNotifierProvider<OnboardingProvider>(
            create: (_) => OnboardingProvider(),
          ),
        ],
        child: const MaterialApp(
          home: AdvisorOnboardingScreen(),
        ),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      expect(find.byType(AdvisorOnboardingScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays step 1 header in French', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      expect(find.textContaining('priorite'), findsOneWidget);
      expect(find.textContaining('MINT'), findsOneWidget);
    });

    testWidgets('shows stress check cards', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // Step 1 stress check cards
      expect(find.textContaining('budget'), findsOneWidget);
      expect(find.textContaining('dettes'), findsWidgets);
      expect(find.textContaining('impots'), findsOneWidget);
      expect(find.textContaining('retraite'), findsOneWidget);
    });

    testWidgets('has step indicator and secondary link', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // Step indicator (1/4)
      expect(find.text('1/4'), findsOneWidget);

      // Secondary link to full diagnostic
      expect(
        find.textContaining('Diagnostic complet'),
        findsOneWidget,
      );
    });

    testWidgets('shows step indicator dots', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // PageView is present for the 4 steps
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('step 4 shows goal chips and projection preview',
        (tester) async {
      // Use a tall viewport to avoid offscreen tap issues
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // ── Step 1: select a stress choice ──
      await tester.tap(find.textContaining('budget'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // ── Step 2: enter birth year + canton ──
      await tester.enterText(find.byType(TextField).first, '1990');
      await tester.pump();
      // Open canton dropdown and pick first item
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zurich (ZH)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // ── Step 3: enter income + status ──
      await tester.enterText(find.byType(TextField).first, '6000');
      await tester.pump();
      await tester.tap(find.textContaining('Salarie'));
      await tester.pump();
      await tester.tap(find.textContaining('Seul'));
      await tester.pump();
      await tester.ensureVisible(find.textContaining('Voir ma projection'));
      await tester.tap(find.textContaining('Voir ma projection'));
      await tester.pumpAndSettle();

      // ── Step 4: verify goal chips ──
      expect(find.text('4/4'), findsOneWidget);
      expect(find.textContaining('retraite'), findsWidgets);
      expect(find.textContaining('immobilier'), findsOneWidget);
      expect(find.textContaining('dettes'), findsWidgets);
      expect(find.textContaining('independance'), findsOneWidget);

      // Projection preview visible (defaults to retirement)
      expect(find.textContaining('Preview trajectoire'), findsOneWidget);
      expect(find.textContaining('Prudent'), findsOneWidget);
      expect(find.textContaining('Optimiste'), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets);
      final previewTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((txt) => txt.contains('CHF'))
          .toList();
      final hasZeroPreview = previewTexts.any(
        (txt) => txt.contains('CHF 0') || txt.contains('CHF\u00A00'),
      );
      expect(
        hasZeroPreview,
        isFalse,
        reason: 'Step 4 preview should not show CHF 0 for completed inputs.',
      );

      // Compliance disclaimer present
      expect(
        find.textContaining('ne constitue pas un conseil financier'),
        findsOneWidget,
      );

      // CTA button present but disabled (no goal selected yet)
      expect(find.textContaining('Activer mon dashboard'), findsOneWidget);
    });

    testWidgets(
        'step 3 couple blocks progression until partner required fields are complete',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // Step 1
      await tester.tap(find.textContaining('budget'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // Step 2
      await tester.enterText(find.byType(TextField).first, '1990');
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zurich (ZH)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // Step 3
      await tester.enterText(find.byType(TextField).first, '7000');
      await tester.pump();
      await tester.tap(find.textContaining('Salarie'));
      await tester.pump();
      await tester.tap(find.textContaining('En couple'));
      await tester.pump();

      await tester.ensureVisible(find.textContaining('Voir ma projection'));
      await tester.tap(find.textContaining('Voir ma projection'));
      await tester.pumpAndSettle();

      // Must still be blocked on step 3 when partner data is missing.
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('4/4'), findsNothing);
      expect(find.textContaining('Infos partenaire requises'), findsOneWidget);
      expect(find.textContaining('Profil minimum prêt'), findsNothing);

      // Fill partner required data
      await tester.tap(find.textContaining('Marie'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), '1992');
      await tester.pump();
      await tester.tap(find.textContaining('Salarie').last);
      await tester.pump();

      await tester.tap(find.textContaining('Voir ma projection'));
      await tester.pumpAndSettle();

      expect(find.text('4/4'), findsOneWidget);
    });

  });

  // ===========================================================================
  // 3. CONSUMER CREDIT SIMULATOR SCREEN
  // ===========================================================================

  group('ConsumerCreditSimulatorScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(ConsumerCreditSimulatorScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.text('Crédit à la Consommation'),
        findsOneWidget,
      );
    });

    testWidgets('shows calculator input sliders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      // Input section header
      expect(find.text('PARAMÈTRES'), findsOneWidget);

      // Slider labels in French
      expect(find.text('Montant à emprunter'), findsOneWidget);
      expect(find.textContaining('Durée du remboursement'), findsOneWidget);
      expect(find.textContaining('Taux annuel effectif'), findsOneWidget);

      // At least 3 sliders
      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('shows result section with computed values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      // Result section (auto-calculated in initState)
      expect(find.text('Ta Mensualité'), findsOneWidget);
      expect(find.textContaining('intérêts'), findsWidgets);
    });

    testWidgets('displays disclaimer with legal reference', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      // Disclaimer text
      expect(
        find.textContaining('Ne constitue pas un conseil'),
        findsOneWidget,
      );
      expect(
        find.textContaining('LCC'),
        findsOneWidget,
      );
    });

    testWidgets('shows mentor guidance section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsumerCreditSimulatorScreen(),
        ),
      );
      await tester.pump();

      // Coach section
      expect(
        find.textContaining('Mentor'),
        findsWidgets,
      );
      // Guidance items
      expect(find.textContaining('Épargner'), findsOneWidget);
      expect(find.textContaining('Dettes Conseils Suisse'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 4. DEBT RISK CHECK SCREEN
  // ===========================================================================

  group('DebtRiskCheckScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(DebtRiskCheckScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French AppBar title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.text('Check-up Santé Financière'),
        findsOneWidget,
      );
    });

    testWidgets('shows questionnaire with French questions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      // Questionnaire section headers
      expect(find.text('GESTION QUOTIDIENNE'), findsOneWidget);
      expect(find.text('OBLIGATIONS'), findsOneWidget);
      expect(find.text('COMPORTEMENTS'), findsOneWidget);

      // Some question texts
      expect(
        find.textContaining('régulièrement à découvert'),
        findsOneWidget,
      );
      expect(
        find.textContaining('plusieurs crédits'),
        findsOneWidget,
      );
      expect(
        find.textContaining('retards de paiement'),
        findsOneWidget,
      );
    });

    testWidgets('shows OUI/NON choice buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      // 6 questions x 2 choices = 12 OUI/NON buttons total
      expect(find.text('OUI'), findsNWidgets(6));
      expect(find.text('NON'), findsNWidgets(6));
    });

    testWidgets('shows mentor intro and privacy note', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      // Mentor section
      expect(find.textContaining('Mentor'), findsOneWidget);
      expect(find.textContaining('60 secondes'), findsOneWidget);

      // Privacy note
      expect(
        find.textContaining('vie privée'),
        findsOneWidget,
      );
    });

    testWidgets('submit button is disabled when not all answered',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebtRiskCheckScreen(),
        ),
      );
      await tester.pump();

      // The submit button text
      expect(find.text('Analyser ma situation'), findsOneWidget);

      // FilledButton should be present but disabled (onPressed == null)
      final filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Analyser ma situation'),
      );
      expect(filledButton.onPressed, isNull);
    });
  });

  // ===========================================================================
  // 5. PORTFOLIO SCREEN (requires ProfileProvider)
  // ===========================================================================

  group('PortfolioScreen', () {
    late ProfileProvider profileProvider;

    setUp(() {
      profileProvider = ProfileProvider();
      // Set a minimal profile so the screen can render
      profileProvider.setProfile(
        Profile(
          id: 'test-user',
          householdType: HouseholdType.single,
          goal: Goal.invest,
          createdAt: DateTime(2025, 1, 1),
          hasDebt: false,
        ),
      );
    });

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PortfolioScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays French title in AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mon Patrimoine'), findsOneWidget);
    });

    testWidgets('shows wealth summary section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      // Wealth header
      expect(find.textContaining('Valeur Totale'), findsOneWidget);
      // CHF amount
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows account envelopes in French', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      // Section header
      expect(
        find.text('RÉPARTITION PAR ENVELOPPE'),
        findsOneWidget,
      );

      // Account items
      expect(find.textContaining('Libre'), findsOneWidget);
      expect(find.textContaining('Pilier 3a'), findsOneWidget);
      expect(find.textContaining('Fonds d\'urgence'), findsOneWidget);
    });

    testWidgets('shows readiness index milestones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Readiness Index'), findsOneWidget);
      expect(find.textContaining('Retraite'), findsOneWidget);
      expect(find.textContaining('Immobilier'), findsOneWidget);
      expect(find.textContaining('Protection Famille'), findsOneWidget);

      // Progress bars
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('shows coach advice when no debt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      // Coach advice (SafeModeGate passes through when hasDebt=false)
      expect(
        find.textContaining('allocation est saine'),
        findsOneWidget,
      );
    });

    testWidgets('shows safe mode warning when has debt', (tester) async {
      // Override with debt profile
      profileProvider.setProfile(
        Profile(
          id: 'test-user-debt',
          householdType: HouseholdType.single,
          goal: Goal.invest,
          createdAt: DateTime(2025, 1, 1),
          hasDebt: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ProfileProvider>.value(
            value: profileProvider,
            child: const PortfolioScreen(),
          ),
        ),
      );
      await tester.pump();

      // Safe mode warning visible
      expect(
        find.textContaining('Alerte Dettes'),
        findsOneWidget,
      );
      // Coach advice should be replaced by locked gate
      expect(
        find.textContaining('allocation est saine'),
        findsNothing,
      );
    });
  });
}
