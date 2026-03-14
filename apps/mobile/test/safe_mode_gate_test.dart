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

void main() {
  // ────────────────────────────────────────────────────────────
  // GROUP 1: SafeModeGate widget tests
  // ────────────────────────────────────────────────────────────
  group('SafeModeGate', () {
    testWidgets('shows child when hasDebt is false', (tester) async {
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
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

    testWidgets('shows "Pourquoi est-ce bloque ?" link', (tester) async {
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
          home: Scaffold(
            body: SafeModeGate(
              hasDebt: true,
              child: Text('Hidden'),
            ),
          ),
        ),
      );

      expect(find.text('Pourquoi est-ce bloqué ?'), findsOneWidget);
    });

    testWidgets('shows lock icon when gated', (tester) async {
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
          locale: const Locale('fr'),
          localizationsDelegates: const [
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
    late BuildContext testContext;

    Future<void> pumpContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          locale: const Locale('fr'),
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('returns max 5 suggestions', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 27,
        civilStatus: 'concubinage',
        childrenCount: 1,
        employmentStatus: 'independent',
        monthlyNetIncome: 8000,
        canton: 'GE',
      );

      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    testWidgets('marriage suggested for single status', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 30,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 5000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/mariage'));
    });

    testWidgets('concubinage suggested for concubinage status', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 30,
        civilStatus: 'concubinage',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/concubinage'));
    });

    testWidgets('naissance suggested for married with 0 children', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 32,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/naissance'));
    });

    testWidgets('succession suggested for age >= 50 with children', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 52,
        civilStatus: 'married',
        childrenCount: 2,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/life-event/succession'));
    });

    testWidgets('first job suggested for age <= 28', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 25,
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 4000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/first-job'));
    });

    testWidgets('housing suggested for income >= 5000 and age 25-50', (tester) async {
      await pumpContext(tester);
      final suggestions = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'married',
        childrenCount: 1,
        employmentStatus: 'employee',
        monthlyNetIncome: 7000,
        canton: 'ZH',
      );

      final routes = suggestions.map((s) => s.route).toList();
      expect(routes, contains('/mortgage/affordability'));
    });

    testWidgets('canton move suggested for high-tax cantons (GE, VD, NE, JU, BE, BS)',
        (tester) async {
      await pumpContext(tester);
      const highTaxCantons = ['GE', 'VD', 'NE', 'JU', 'BE', 'BS'];

      for (final canton in highTaxCantons) {
        final suggestions = buildLifeEventSuggestions(
          context: testContext,
          age: 35,
          civilStatus: 'married',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 6000,
          canton: canton,
        );

        final routes = suggestions.map((s) => s.route).toList();
        expect(
          routes,
          contains('/fiscal'),
          reason: 'Canton $canton should trigger canton move suggestion',
        );
      }

      // Verify a low-tax canton does NOT trigger the suggestion
      final suggestionsLowTax = buildLifeEventSuggestions(
        context: testContext,
        age: 35,
        civilStatus: 'married',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6000,
        canton: 'ZG',
      );

      final routesLowTax = suggestionsLowTax.map((s) => s.route).toList();
      expect(
        routesLowTax,
        isNot(contains('/fiscal')),
        reason: 'Low-tax canton ZG should not trigger canton move suggestion',
      );
    });
  });
}
