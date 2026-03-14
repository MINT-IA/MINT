import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_models.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';
import 'package:mint_mobile/widgets/coach/monte_carlo_toggle_section.dart';
import 'package:mint_mobile/widgets/coach/sensitivity_snippet.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  group('MonteCarloToggleSection', () {
    test('starts in 3 Sc\u00e9narios mode', () {
      // Verify initial state is not Monte Carlo
      const widget = MonteCarloToggleSection(
        monteCarloResult: null,
        scenariosChild: Text('scenarios'),
        monteCarloAvailable: true,
      );
      expect(widget.monteCarloAvailable, isTrue);
      expect(widget.monteCarloResult, isNull);
    });

    testWidgets('shows scenarios child by default', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MonteCarloToggleSection(
            monteCarloResult: null,
            scenariosChild: Text('Sc\u00e9narios test'),
            monteCarloAvailable: false,
          ),
        ),
      ));

      expect(find.text('Sc\u00e9narios test'), findsOneWidget);
      expect(find.text('3 Sc\u00e9narios'), findsAtLeast(1));
    });

    testWidgets('toggle disabled when MC unavailable', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MonteCarloToggleSection(
            monteCarloResult: null,
            scenariosChild: Text('child'),
            monteCarloAvailable: false,
          ),
        ),
      ));

      // "Probabilit\u00e9s" toggle text should exist but be disabled (muted)
      expect(find.text('Probabilit\u00e9s'), findsAtLeast(1));
    });

    testWidgets('resets toggle when MC becomes unavailable', (tester) async {
      // Start with MC available
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MonteCarloToggleSection(
            monteCarloResult: _buildMockResult(),
            scenariosChild: const Text('child'),
            monteCarloAvailable: true,
          ),
        ),
      ));

      // Rebuild with MC unavailable — should reset to scenarios
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: MonteCarloToggleSection(
            monteCarloResult: null,
            scenariosChild: Text('child'),
            monteCarloAvailable: false,
          ),
        ),
      ));

      // Should show child (scenarios), not MC view
      expect(find.text('child'), findsOneWidget);
    });
  });

  group('MonteCarloTeaser', () {
    testWidgets('is 100% non-personalized — no user data accepted',
        (tester) async {
      // MonteCarloTeaser constructor takes NO profile/financial data params
      const teaser = MonteCarloTeaser();
      // Verify it only has onEnrich and missingCategories — no numerical data
      expect(teaser.onEnrich, isNull);
      expect(teaser.missingCategories, isEmpty);
    });

    testWidgets('displays educational message + CTA + disclaimer',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(
              missingCategories: ['lpp', '3a', 'patrimoine'],
            ),
          ),
        ),
      ));

      // Educational text
      expect(find.textContaining('futurs possibles'), findsOneWidget);
      // CTA
      expect(find.textContaining('profil pour d\u00e9bloquer'), findsOneWidget);
      // Disclaimer
      expect(find.textContaining('LSFin'), findsAtLeast(1));
      // Category chips (categories only, no values)
      expect(find.text('LPP'), findsOneWidget);
      expect(find.text('3a'), findsOneWidget);
      expect(find.text('Patrimoine'), findsOneWidget);
    });

    testWidgets('chips show max 3 categories', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(
              missingCategories: ['lpp', '3a', 'patrimoine', 'avs', 'logement'],
            ),
          ),
        ),
      ));

      // Only first 3 should appear
      expect(find.text('LPP'), findsOneWidget);
      expect(find.text('3a'), findsOneWidget);
      expect(find.text('Patrimoine'), findsOneWidget);
      expect(find.text('AVS'), findsNothing);
      expect(find.text('Logement'), findsNothing);
    });

    testWidgets('no chips when missingCategories is empty', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(missingCategories: []),
          ),
        ),
      ));

      // No category chips
      expect(find.text('LPP'), findsNothing);
      expect(find.text('AVS'), findsNothing);
    });

    testWidgets('internal categories are not leaked to UI', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(
              // Internal-only categories that could leak from enrichment prompts
              missingCategories: ['income', 'retirement_urgency'],
            ),
          ),
        ),
      ));

      // Internal categories must NOT appear as raw text
      expect(find.text('income'), findsNothing);
      expect(find.text('retirement_urgency'), findsNothing);
    });

    testWidgets('mixed internal + valid categories only show valid ones',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(
              missingCategories: ['lpp', 'income', '3a'],
            ),
          ),
        ),
      ));

      // Valid categories rendered
      expect(find.text('LPP'), findsOneWidget);
      expect(find.text('3a'), findsOneWidget);
      // Internal category not leaked
      expect(find.text('income'), findsNothing);
    });

    testWidgets('no banned terms in rendered text', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonteCarloTeaser(
              missingCategories: ['lpp'],
            ),
          ),
        ),
      ));

      // Banned terms must not appear anywhere
      expect(find.textContaining('garanti'), findsNothing);
      expect(find.textContaining('certain'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
      expect(find.textContaining('parfait'), findsNothing);
    });
  });

  group('SensitivitySnippet', () {
    test('shows max 3 variables by default', () {
      final widget = SensitivitySnippet(
        variables: List.generate(
          5,
          (i) => TornadoVariable(
            label: 'Var $i',
            category: 'lpp',
            baseValue: 1000,
            lowValue: 800,
            highValue: 1200,
            swing: 400,
            lowLabel: 'low',
            highLabel: 'high',
          ),
        ),
      );
      expect(widget.maxVariables, equals(3));
    });

    testWidgets('renders tornado bars for each variable', (tester) async {
      final variables = [
        const TornadoVariable(
          label: '\u00C2ge de d\u00e9part',
          category: 'strategy',
          baseValue: 3000,
          lowValue: 2500,
          highValue: 3500,
          swing: 1000,
          lowLabel: '63 ans',
          highLabel: '67 ans',
        ),
        const TornadoVariable(
          label: 'Avoir LPP actuel',
          category: 'lpp',
          baseValue: 3000,
          lowValue: 2700,
          highValue: 3300,
          swing: 600,
          lowLabel: '-20%',
          highLabel: '+20%',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SensitivitySnippet(variables: variables),
        ),
      ));

      // Labels
      expect(find.textContaining('influence le plus'), findsOneWidget);
      expect(find.text('\u00C2ge de d\u00e9part'), findsOneWidget);
      expect(find.text('Avoir LPP actuel'), findsOneWidget);
      // Low/high labels
      expect(find.text('63 ans'), findsOneWidget);
      expect(find.text('67 ans'), findsOneWidget);
      // Disclaimer
      expect(find.textContaining('LSFin'), findsOneWidget);
    });

    testWidgets('returns empty when no variables', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SensitivitySnippet(variables: []),
        ),
      ));

      // Should render nothing (SizedBox.shrink)
      expect(find.textContaining('influence'), findsNothing);
    });
  });
}

MonteCarloResult _buildMockResult() {
  return const MonteCarloResult(
    projection: [
      MonteCarloPoint(
          year: 2040, age: 65, p10: 2000, p25: 2500, p50: 3000, p75: 3500, p90: 4000),
    ],
    medianAt65: 3000,
    p10At65: 2000,
    p90At65: 4000,
    ruinProbability: 0.08,
    numSimulations: 500,
    disclaimer: 'Outil \u00e9ducatif (LSFin).',
    retirementAge: 65,
    sources: ['LPP art. 14'],
    alertes: [],
  );
}
