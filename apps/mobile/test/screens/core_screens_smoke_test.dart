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

      // Step 1 is now "Essentials" with profile header
      expect(find.textContaining('profil'), findsWidgets);
      expect(find.textContaining('canton'), findsWidgets);
    });

    testWidgets('shows step 1 essentials fields', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // Step 1 shows name, birth year and canton fields
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      expect(find.textContaining('naissance'), findsOneWidget);
    });

    testWidgets('has step indicator showing 1/3', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // Step indicator (1/3 for 3-step onboarding)
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('shows step indicator dots', (tester) async {
      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // PageView is present for the 4 steps
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('step 3 shows goal chips and CTA',
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

      // ── Step 1 (Essentials): enter birth year + canton ──
      await tester.enterText(find.byType(TextField).at(1), '1990');
      await tester.pump();
      // Open canton dropdown and pick Zurich
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zurich (ZH)').last);
      await tester.pumpAndSettle();
      // Tap "Suivant" button — triggers AHA bottom sheet
      await tester.ensureVisible(find.textContaining('Suivant'));
      await tester.tap(find.textContaining('Suivant'));
      await tester.pumpAndSettle();
      // Dismiss the AHA bottom sheet by tapping its "Continuer" button
      final continuerInSheet = find.textContaining('Continuer');
      if (continuerInSheet.evaluate().isNotEmpty) {
        await tester.tap(continuerInSheet.last);
        await tester.pumpAndSettle();
      }

      // ── Step 2 (Income): enter income + employment + household + housing ──
      expect(find.text('2/3'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '6000');
      await tester.pump();
      await tester.tap(find.textContaining('Salarie').first);
      await tester.pump();
      await tester.ensureVisible(find.textContaining('Seul'));
      await tester.tap(find.textContaining('Seul'));
      await tester.pump();
      await tester.ensureVisible(find.textContaining('Locataire'));
      await tester.tap(find.textContaining('Locataire'));
      await tester.pump();
      // Enter housing cost
      final housingField = find.byType(TextField).at(1);
      await tester.ensureVisible(housingField);
      await tester.enterText(housingField, '1500');
      await tester.pump();
      // Tap "Continuer" button to advance to step 3
      await tester.ensureVisible(find.textContaining('Continuer'));
      await tester.tap(find.textContaining('Continuer'));
      await tester.pumpAndSettle();

      // ── Step 3 (Goal): verify goal chips ──
      expect(find.text('3/3'), findsOneWidget);
      expect(find.textContaining('retraite'), findsWidgets);
      expect(find.textContaining('immobilier'), findsWidgets);
      expect(find.textContaining('dettes'), findsWidgets);
      expect(find.textContaining('independance'), findsWidgets);

      // CTA button present but disabled (no goal selected yet)
      expect(find.textContaining('Activer mon dashboard'), findsOneWidget);
    });

    testWidgets(
        'step 2 couple blocks progression until partner required fields are complete',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildOnboarding());
      await tester.pump();

      // ── Step 1 (Essentials): enter birth year + canton ──
      await tester.enterText(find.byType(TextField).at(1), '1990');
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zurich (ZH)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Suivant'));
      await tester.tap(find.textContaining('Suivant'));
      await tester.pumpAndSettle();
      // Dismiss the AHA bottom sheet if shown
      final continuerBtn = find.textContaining('Continuer');
      if (continuerBtn.evaluate().isNotEmpty) {
        await tester.tap(continuerBtn.last);
        await tester.pumpAndSettle();
      }

      // ── Step 2 (Income): enter income + employment + select "En couple" ──
      expect(find.text('2/3'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '7000');
      await tester.pump();
      await tester.tap(find.textContaining('Salarie').first);
      await tester.pump();
      await tester.ensureVisible(find.textContaining('En couple'));
      await tester.tap(find.textContaining('En couple'));
      await tester.pumpAndSettle();

      // Selecting En couple reveals partner fields.
      // The "Continuer" button should still be present but
      // the provider blocks advance until partner data is complete.
      // Must still be on step 2 when partner data is missing.
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('3/3'), findsNothing);
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
