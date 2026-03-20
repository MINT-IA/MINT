import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart';

// ────────────────────────────────────────────────────────────────
//  CAP CARD — Widget Tests
// ────────────────────────────────────────────────────────────────
//
//  Validates:
//  - Renders headline, whyNow, CTA, expectedImpact, confidenceLabel
//  - Kind pill shows correct label and color
//  - Feedback pill shows when recentActionLabel provided
//  - Lisible en 3 secondes (no visual clutter)
// ────────────────────────────────────────────────────────────────

CapDecision _makeCap({
  CapKind kind = CapKind.optimize,
  String headline = 'Cette année compte encore',
  String whyNow = 'Un versement 3a peut encore alléger tes impôts.',
  String ctaLabel = 'Simuler mon 3a',
  CtaMode ctaMode = CtaMode.route,
  String? ctaRoute = '/pilier-3a',
  String? expectedImpact = 'jusqu\'à CHF 1\'240 d\'économie',
  String? confidenceLabel,
}) {
  return CapDecision(
    id: 'test_${kind.name}',
    kind: kind,
    priorityScore: 0.8,
    headline: headline,
    whyNow: whyNow,
    ctaLabel: ctaLabel,
    ctaMode: ctaMode,
    ctaRoute: ctaRoute,
    expectedImpact: expectedImpact,
    confidenceLabel: confidenceLabel,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('CapCard — basic rendering', () {
    testWidgets('renders headline', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(find.text('Cette année compte encore'), findsOneWidget);
    });

    testWidgets('renders whyNow', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(
        find.text('Un versement 3a peut encore alléger tes impôts.'),
        findsOneWidget,
      );
    });

    testWidgets('renders CTA label', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(find.text('Simuler mon 3a'), findsOneWidget);
    });

    testWidgets('renders expected impact', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(
        find.text('jusqu\'à CHF 1\'240 d\'économie'),
        findsOneWidget,
      );
    });

    testWidgets('hides expected impact when null', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(expectedImpact: null)),
      ));

      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    });

    testWidgets('renders confidence label when set', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(confidenceLabel: 'confiance 72\u00a0%')),
      ));

      expect(find.text('confiance 72\u00a0%'), findsOneWidget);
    });

    testWidgets('hides confidence label when null', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(confidenceLabel: null)),
      ));

      // No micro text for confidence
      expect(find.text('confiance'), findsNothing);
    });
  });

  group('CapCard — kind pill', () {
    testWidgets('shows Optimiser for optimize kind', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(kind: CapKind.optimize)),
      ));

      expect(find.text('Optimiser'), findsOneWidget);
    });

    testWidgets('shows Compléter for complete kind', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(kind: CapKind.complete)),
      ));

      expect(find.text('Compléter'), findsOneWidget);
    });

    testWidgets('shows Corriger for correct kind', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(kind: CapKind.correct)),
      ));

      expect(find.text('Corriger'), findsOneWidget);
    });

    testWidgets('shows Sécuriser for secure kind', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(kind: CapKind.secure)),
      ));

      expect(find.text('Sécuriser'), findsOneWidget);
    });

    testWidgets('shows Préparer for prepare kind', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap(kind: CapKind.prepare)),
      ));

      expect(find.text('Préparer'), findsOneWidget);
    });
  });

  group('CapCard — feedback pill', () {
    testWidgets('shows feedback pill when recentActionLabel set',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(
          cap: _makeCap(),
          recentActionLabel: 'Ajouté hier',
        ),
      ));

      expect(find.text('Ajouté hier'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('no feedback pill when recentActionLabel null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    });
  });

  group('CapCard — no legacy patterns', () {
    testWidgets('no left border', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      // Main container should have no border
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        if (c.decoration is BoxDecoration) {
          final d = c.decoration as BoxDecoration;
          if (d.borderRadius != null &&
              d.boxShadow != null &&
              d.boxShadow!.isNotEmpty) {
            // This is the main card container
            expect(d.border, isNull);
          }
        }
      }
    });

    testWidgets('no +pts badge', (tester) async {
      await tester.pumpWidget(_wrap(
        CapCard(cap: _makeCap()),
      ));

      expect(find.textContaining('pts'), findsNothing);
    });
  });
}
