import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';

// ────────────────────────────────────────────────────────────────
//  RESPONSE CARD — MTC INTEGRATION TESTS (Phase 4 Plan 04-02)
// ────────────────────────────────────────────────────────────────
//
//  Task 1: S4 DELETE list honored + new `confidence` / `isProjection`
//          parameters accepted; pre-existing render paths still work.
//
//  Task 2 (second commit): MintTrameConfiance.inline mounted conditionally;
//          ARB resolution; semantics; position in the card body.
//
//  Model gap (documented in 04-02 commit message): ResponseCard does NOT
//  yet carry a confidence field. Callers pass `null` by default → no MTC
//  slot rendered (safe no-op). Phase 8a wires the model field.
// ────────────────────────────────────────────────────────────────

EnhancedConfidence _mockConfidence({
  double completeness = 85,
  double accuracy = 80,
  double freshness = 75,
  double understanding = 70,
}) {
  return EnhancedConfidence(
    completeness: completeness,
    accuracy: accuracy,
    freshness: freshness,
    understanding: understanding,
    combined: 77.0,
    level: 'high',
    baseResult: const ProjectionConfidence(
      score: 77.0,
      level: 'high',
      prompts: [],
      assumptions: [],
    ),
    axisPrompts: const [],
  );
}

ResponseCard _makeCard({
  ResponseCardType type = ResponseCardType.pillar3a,
  String title = 'Versement 3a 2026',
  String subtitle = 'Economie fiscale estimee',
  double chiffreValue = 2200,
  String chiffreUnit = 'CHF',
  List<String> sources = const ['OPP3 art. 7'],
  CardUrgency urgency = CardUrgency.low,
  DateTime? deadline,
}) {
  return ResponseCard(
    id: 'test_${type.name}',
    type: type,
    title: title,
    subtitle: subtitle,
    premierEclairage: PremierEclairage(
      value: chiffreValue,
      unit: chiffreUnit,
      explanation: 'Explication test',
    ),
    cta: const CardCta(
      label: 'Simuler mon 3a',
      route: '/pilier-3a',
      icon: 'savings',
    ),
    urgency: urgency,
    deadline: deadline,
    disclaimer: 'Outil educatif.',
    sources: sources,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    locale: const Locale('fr'),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  // ──────────────────────────────────────────────────────────────
  //  TASK 1 — Phase 3 S4 DELETE list conformance
  // ──────────────────────────────────────────────────────────────

  group('S4 DELETE list honored', () {
    testWidgets('DELETE #1 — no outer card boxShadow', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
        ),
      ));
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.boxShadow,
        anyOf(isNull, isEmpty),
        reason: 'DELETE #1: shadow-on-shadow ornament removed',
      );
    });

    testWidgets('DELETE #2 — no schedule icon in deadline pill',
        (tester) async {
      final deadline = DateTime.now().add(const Duration(days: 10));
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(urgency: CardUrgency.high, deadline: deadline),
          variant: ResponseCardVariant.chat,
        ),
      ));
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('DELETE #3+#4 — compact variant: no icon container, no chevron',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.compact(card: _makeCard(title: 'Rachat LPP')),
      ));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.savings_rounded), findsNothing);
      expect(find.text('Rachat LPP'), findsOneWidget);
    });

    testWidgets('DELETE #5 — no drag handle in proof sheet', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
        ),
      ));
      await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
      await tester.pumpAndSettle();
      final bordered = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
        final d = c.decoration;
        if (d is! BoxDecoration) return false;
        return d.color == MintColors.border;
      }).toList();
      expect(
        bordered,
        isEmpty,
        reason: 'DELETE #5: drag handle Container removed',
      );
    });

    testWidgets('DELETE #6 — no standalone "Sources" label text',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
        ),
      ));
      await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Sources'), findsNothing);
      // KEEP K14: the source row itself is still present.
      expect(find.text('OPP3 art. 7'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────
  //  TASK 1 — New constructor parameters accepted
  // ──────────────────────────────────────────────────────────────

  group('new parameters: confidence + isProjection', () {
    testWidgets('accepts confidence + isProjection without crashing',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
          confidence: _mockConfidence(),
          isProjection: true,
        ),
      ));
      expect(find.text('Versement 3a 2026'), findsOneWidget);
    });

    testWidgets('defaults: confidence null, isProjection false',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
        ),
      ));
      expect(find.text('Versement 3a 2026'), findsOneWidget);
    });

    testWidgets('KEEP K4/K10 no-regression: title + CTA label present',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(),
          variant: ResponseCardVariant.sheet,
          confidence: _mockConfidence(),
          isProjection: true,
        ),
      ));
      expect(find.text('Versement 3a 2026'), findsOneWidget);
      expect(find.text('Simuler mon 3a'), findsOneWidget);
    });
  });
}
