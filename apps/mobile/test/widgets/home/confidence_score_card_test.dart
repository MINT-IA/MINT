import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/home/confidence_score_card.dart';

// ────────────────────────────────────────────────────────────
//  CONFIDENCE SCORE CARD TEST — Phase 08-01 / UXP-02
//
//  Tests:
//  1. Score=75 → zone label "Bonne estimation"
//  2. Score=50 → zone label "Estimation large"
//  3. Score=30 → zone label "On devine beaucoup"
//  4. Enrichment action label rendered when enrichmentPrompts non-empty
//  5. Score=96 → perfect state text rendered
//  6. hasError=true → error state with retry button
// ────────────────────────────────────────────────────────────

Widget _buildApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: child,
      ),
    ),
  );
}

const _testPrompt = EnrichmentPrompt(
  label: 'Ajoute ton salaire',
  impact: 12,
  category: 'income',
  action: 'Renseigne ton salaire brut mensuel',
);

void main() {
  group('ConfidenceScoreCard', () {
    testWidgets('score=75 renders zone label Bonne estimation', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 75,
          enrichmentPrompts: const [_testPrompt],
        ),
      ));
      await tester.pump();
      expect(find.text('Bonne estimation'), findsOneWidget);
    });

    testWidgets('score=50 renders zone label Estimation large', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 50,
          enrichmentPrompts: const [_testPrompt],
        ),
      ));
      await tester.pump();
      expect(find.text('Estimation large'), findsOneWidget);
    });

    testWidgets('score=30 renders zone label On devine beaucoup', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 30,
          enrichmentPrompts: const [_testPrompt],
        ),
      ));
      await tester.pump();
      expect(find.text('On devine beaucoup'), findsOneWidget);
    });

    testWidgets('renders enrichment action label when prompts non-empty', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 50,
          enrichmentPrompts: const [_testPrompt],
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Ajoute ton salaire'), findsOneWidget);
    });

    testWidgets('score=96 renders perfect state text', (tester) async {
      await tester.pumpWidget(_buildApp(
        const ConfidenceScoreCard(
          score: 96,
          enrichmentPrompts: [],
        ),
      ));
      await tester.pump();
      // The perfect state text contains "très précise"
      expect(
        find.textContaining('tr\u00e8s pr\u00e9cise'),
        findsOneWidget,
      );
    });

    testWidgets('hasError=true renders error state with retry button', (tester) async {
      bool retryCalled = false;
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 0,
          hasError: true,
          onRetry: () => retryCalled = true,
        ),
      ));
      await tester.pump();
      // Error message present
      expect(find.textContaining('Impossible de calculer'), findsOneWidget);
      // Retry button present
      expect(find.text('R\u00e9essayer'), findsOneWidget);
      // Retry button is tappable
      await tester.tap(find.text('R\u00e9essayer'));
      expect(retryCalled, isTrue);
    });

    testWidgets('enrichment CTA tap calls onEnrichmentTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 50,
          enrichmentPrompts: const [_testPrompt],
          onEnrichmentTap: () => tapped = true,
        ),
      ));
      await tester.pump();
      await tester.tap(find.textContaining('Ajoute ton salaire'));
      expect(tapped, isTrue);
    });

    testWidgets('score=96 with prompts still shows perfect state', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceScoreCard(
          score: 96,
          enrichmentPrompts: const [_testPrompt],
        ),
      ));
      await tester.pump();
      expect(find.textContaining('tr\u00e8s pr\u00e9cise'), findsOneWidget);
      // Enrichment CTA must NOT appear
      expect(find.textContaining('Pour aller plus loin'), findsNothing);
    });
  });
}
