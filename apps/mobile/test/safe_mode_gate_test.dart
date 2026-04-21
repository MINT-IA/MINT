import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/widgets/recommendation_card.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';

void main() {
  // ────────────────────────────────────────────────────────────
  // GROUP 1: SafeModeGate widget tests
  // ────────────────────────────────────────────────────────────
  group('SafeModeGate', () {
    testWidgets('shows child when hasDebt is false', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: false,
              child: Text('Optimization content'),
            ),
          ),
        ),
      );

      expect(find.text('Optimization content'), findsOneWidget);
    });

    testWidgets('shows locked state when hasDebt is true', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('Optimization content'),
            ),
          ),
        ),
      );

      // The child should NOT be visible
      expect(find.text('Optimization content'), findsNothing);
      // The locked title should be visible
      expect(find.text('Concentration Prioritaire'), findsOneWidget);
    });

    testWidgets('shows default locked title', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      expect(find.text('Concentration Prioritaire'), findsOneWidget);
    });

    testWidgets('shows custom locked title', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              lockedTitle: 'Mode protection active',
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      expect(find.text('Mode protection active'), findsOneWidget);
      // Default title should NOT appear
      expect(find.text('Concentration Prioritaire'), findsNothing);
    });

    testWidgets('shows custom locked message', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              lockedMessage: 'Rembourse tes dettes en priorite.',
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      expect(find.text('Rembourse tes dettes en priorite.'), findsOneWidget);
    });

    testWidgets('shows "Pourquoi est-ce en pause ?" link', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      // ARB key safeModeWhyBlockedLink updated in Change 3: "bloqué" → "en pause"
      expect(find.text('Pourquoi est-ce en pause\u00a0?'), findsOneWidget);
    });

    testWidgets('shows lock icon when gated', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_person), findsOneWidget);
    });

    testWidgets('child is not rendered when gated', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Column(
                children: [
                  Text('Secret optimization'),
                  Icon(Icons.trending_up),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Secret optimization'), findsNothing);
      expect(find.byIcon(Icons.trending_up), findsNothing);
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 2: RecommendationCard SafeMode behavior
  // ────────────────────────────────────────────────────────────
  group('RecommendationCard', () {
    Recommendation makeRecommendation({
      String title = 'Ouvrir un 3e pilier',
      String summary = 'Economise jusqu\'a 2000 CHF d\'impots par an.',
      String kind = 'fiscalite',
      double impactAmount = 2000,
      Period impactPeriod = Period.yearly,
      List<EvidenceLink> evidenceLinks = const [],
      List<NextAction> nextActions = const [],
    }) {
      return Recommendation(
        id: 'rec-1',
        kind: kind,
        title: title,
        summary: summary,
        why: ['Deduction fiscale directe'],
        assumptions: ['Revenu imposable > 50k'],
        impact: Impact(amountCHF: impactAmount, period: impactPeriod),
        risks: ['Fonds bloques jusqu\'a la retraite'],
        alternatives: ['Versement partiel'],
        evidenceLinks: evidenceLinks,
        nextActions: nextActions.isEmpty
            ? [
                const NextAction(
                  type: NextActionType.simulate,
                  label: 'Simuler mon economie',
                ),
              ]
            : nextActions,
      );
    }

    testWidgets('card renders title correctly', (tester) async {
      final rec = makeRecommendation(title: 'Ouvrir un 3e pilier');

      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecommendationCard(recommendation: rec),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ouvrir un 3e pilier'), findsOneWidget);
    });

    testWidgets('card renders description', (tester) async {
      final rec = makeRecommendation(
        summary: 'Economise jusqu\'a 2000 CHF d\'impots par an.',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecommendationCard(recommendation: rec),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Economise jusqu\'a 2000 CHF d\'impots par an.'),
        findsOneWidget,
      );
    });

    testWidgets('card has action button', (tester) async {
      final rec = makeRecommendation(
        nextActions: [
          const NextAction(
            type: NextActionType.simulate,
            label: 'Simuler mon economie',
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecommendationCard(recommendation: rec),
              ),
            ),
          ),
        ),
      );

      // The button should display the first nextAction label
      expect(find.text('Simuler mon economie'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('card shows priority indicator (kind badge)', (tester) async {
      final rec = makeRecommendation(kind: 'fiscalite');

      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecommendationCard(recommendation: rec),
              ),
            ),
          ),
        ),
      );

      // The kind is displayed uppercase as a badge
      expect(find.text('FISCALITE'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 3: buildLifeEventSuggestions logic
  // ────────────────────────────────────────────────────────────
  group('buildLifeEventSuggestions', () {
    final sFr = SFr();

    test('returns max 5 suggestions', () {
      final suggestions = buildLifeEventSuggestions(
        age: 27,
        civilStatus: 'concubinage',
        childrenCount: 1,
        employmentStatus: 'independent',
        monthlyNetIncome: 8000,
        canton: 'GE',
        s: sFr,
      );

      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    test('marriage suggested for single status', () {
      final suggestions = buildLifeEventSuggestions(
        age: 30,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 5000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugMariage));
    });

    test('concubinage suggested for concubinage status', () {
      final suggestions = buildLifeEventSuggestions(
        age: 30,
        civilStatus: 'concubinage',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugConcubinage));
    });

    test('naissance suggested for married with 0 children', () {
      final suggestions = buildLifeEventSuggestions(
        age: 32,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugNaissance));
    });

    test('succession suggested for age >= 50 with children', () {
      final suggestions = buildLifeEventSuggestions(
        age: 52,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugSuccession));
    });

    test('first job suggested for age <= 28', () {
      final suggestions = buildLifeEventSuggestions(
        age: 25,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugPremierEmploi));
    });

    test('housing suggested for income >= 5000 and age 25-50', () {
      final suggestions = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'married',
        childrenCount: 1,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
        s: sFr,
      );

      final titles = suggestions.map((s) => s.title).toList();
      expect(titles, contains(sFr.lifeEventSugAchatImmo));
    });

    // TODO(safe-mode): test that gate fires when Signal A triggers isInDebtCrisis
    // TODO(safe-mode): test that gate fires when Signal B triggers isInDebtCrisis
    // TODO(safe-mode): test that gate fires when Signal C triggers isInDebtCrisis
    // TODO(safe-mode): test that reasons list is shown in why-blocked sheet
    // TODO(safe-mode): test that ctaRoute navigates to désendettement screen
    // TODO(safe-mode): test that gate clears when isInDebtCrisis becomes false (reactive)

    test('canton move suggested for high-tax cantons (GE, VD, NE, JU, BE, BS)',
        () {
      const highTaxCantons = ['GE', 'VD', 'NE', 'JU', 'BE', 'BS'];

      for (final canton in highTaxCantons) {
        final suggestions = buildLifeEventSuggestions(
          age: 35,
          civilStatus: 'married',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 6000,
          canton: canton,
          s: sFr,
        );

        final titles = suggestions.map((s) => s.title).toList();
        expect(
          titles,
          contains(sFr.lifeEventSugDemenagement),
          reason: 'Canton $canton should trigger canton move suggestion',
        );
      }

      // Verify a low-tax canton does NOT trigger the suggestion
      final suggestionsLowTax = buildLifeEventSuggestions(
        age: 35,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZG',
        s: sFr,
      );

      final titlesLowTax = suggestionsLowTax.map((s) => s.title).toList();
      expect(
        titlesLowTax,
        isNot(contains(sFr.lifeEventSugDemenagement)),
        reason: 'Low-tax canton ZG should not trigger canton move suggestion',
      );
    });
  });

  // ────────────────────────────────────────────────────────────
  // GROUP 4: SafeModeGate smoke tests — hasDebt → gate contract
  // ────────────────────────────────────────────────────────────
  group('SafeModeGate — debt-crisis smoke tests', () {
    testWidgets('smoke: hasDebt false → optimization child visible', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: false,
              child: Text('3a optimization content'),
            ),
          ),
        ),
      );
      expect(find.text('3a optimization content'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person), findsNothing);
    });

    testWidgets('smoke: hasDebt true → optimization child hidden, lock shown', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('LPP optimization content'),
            ),
          ),
        ),
      );
      expect(find.text('LPP optimization content'), findsNothing);
      expect(find.byIcon(Icons.lock_person), findsOneWidget);
    });

    testWidgets('smoke: reasons list rendered in gate body', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              reasons: ['LP art. 5 — retrait possible malgré les dettes'],
              child: Text('EPL content'),
            ),
          ),
        ),
      );
      expect(find.text('LP art. 5 — retrait possible malgré les dettes'), findsOneWidget);
      expect(find.text('EPL content'), findsNothing);
    });

    // TODO(safe-mode): test that gate fires when Signal A triggers isInDebtCrisis
    // TODO(safe-mode): test that gate fires when Signal B triggers isInDebtCrisis
    // TODO(safe-mode): test that gate fires when Signal C triggers isInDebtCrisis
    // TODO(safe-mode): test that ctaRoute navigates to désendettement screen
    // TODO(safe-mode): test that gate clears when isInDebtCrisis becomes false (reactive)
    // TODO(safe-mode): test that AgentTaskType.lppCertificateRequest blocked in SafeMode
  });
}
