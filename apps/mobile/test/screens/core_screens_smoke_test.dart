import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Screens under test
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
import 'package:mint_mobile/screens/portfolio_screen.dart';

import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // 3. CONSUMER CREDIT SIMULATOR SCREEN
  // ===========================================================================

  group('ConsumerCreditSimulatorScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
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
