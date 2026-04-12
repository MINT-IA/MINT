import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';

// ────────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET V2 — Widget Tests
// ────────────────────────────────────────────────────────────────
//
//  Validates V2 "Calm Narrative" contract:
//  - 3 variants (chat, sheet, compact)
//  - Proof hidden by default, accessible on demand
//  - No legacy patterns (left border, +pts, fixed 280, inline sources)
//  - MintTextStyles tokens only
// ────────────────────────────────────────────────────────────────

ResponseCard _makeCard({
  ResponseCardType type = ResponseCardType.pillar3a,
  String title = 'Versement 3a 2026',
  String subtitle = 'Economie fiscale estimee',
  double chiffreValue = 2200,
  String chiffreUnit = 'CHF',
  String ctaLabel = 'Simuler mon 3a',
  String ctaRoute = '/pilier-3a',
  CardUrgency urgency = CardUrgency.low,
  DateTime? deadline,
  List<String> sources = const ['OPP3 art. 7'],
  List<String> alertes = const [],
  int impactPoints = 18,
}) {
  return ResponseCard(
    id: 'test_${type.name}',
    type: type,
    title: title,
    subtitle: subtitle,
    premierEclairage: PremierEclairage(
      value: chiffreValue,
      unit: chiffreUnit,
      explanation: 'Test explanation for $title',
    ),
    cta: CardCta(label: ctaLabel, route: ctaRoute, icon: 'savings'),
    urgency: urgency,
    deadline: deadline,
    disclaimer:
        'Outil educatif — ne constitue pas un conseil financier (LSFin art. 3).',
    sources: sources,
    alertes: alertes,
    impactPoints: impactPoints,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
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
  // ── COMPACT VARIANT ──

  group('ResponseCardWidget — compact', () {
    testWidgets('renders title without chevron (S4 DELETE #4)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.compact(card: _makeCard(title: 'Rachat LPP')),
      ));

      expect(find.text('Rachat LPP'), findsOneWidget);
      // DELETE #4: chevron removed — the whole card is tappable.
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('does NOT show chiffre-choc', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.compact(
            card: _makeCard(chiffreValue: 12450)),
      ));

      expect(find.text("12'450 CHF"), findsNothing);
    });

    testWidgets('does NOT show sources inline', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.compact(card: _makeCard()),
      ));

      expect(find.text('OPP3 art. 7'), findsNothing);
    });

    testWidgets('does NOT show +pts badge', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.compact(card: _makeCard(impactPoints: 22)),
      ));

      expect(find.text('+22 pts'), findsNothing);
    });
  });

  // ── CHAT VARIANT ──

  group('ResponseCardWidget — chat', () {
    testWidgets('renders title and CTA', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(card: _makeCard()),
      ));

      expect(find.text('Versement 3a 2026'), findsOneWidget);
      expect(find.text('Simuler mon 3a'), findsOneWidget);
    });

    testWidgets('shows chiffre-choc when meaningful', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(card: _makeCard(chiffreValue: 5000)),
      ));

      expect(find.text("5'000 CHF"), findsOneWidget);
    });

    testWidgets('hides chiffre-choc when value is 0', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(card: _makeCard(chiffreValue: 0)),
      ));

      // Should not display "0 CHF" or any chiffre-choc text
      expect(find.text('0 CHF'), findsNothing);
    });

    testWidgets('does NOT show sources inline (proof on demand)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(card: _makeCard()),
      ));

      expect(find.text('OPP3 art. 7'), findsNothing);
    });

    testWidgets('shows deadline pill when set (S4 DELETE #2 — no icon)',
        (tester) async {
      final deadline = DateTime.now().add(const Duration(days: 15));
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(
          card: _makeCard(urgency: CardUrgency.high, deadline: deadline),
        ),
      ));

      // DELETE #2: schedule Icon removed — the "J-N" text carries the
      // time semantic on its own.
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.textContaining('J-'), findsOneWidget);
    });

    testWidgets('no deadline pill when no deadline', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget.chat(card: _makeCard()),
      ));

      // No deadline → no badge text rendered at all.
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.textContaining('J-'), findsNothing);
    });
  });

  // ── SHEET VARIANT ──

  group('ResponseCardWidget — sheet', () {
    testWidgets('renders full layout', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(chiffreValue: 12450),
            variant: ResponseCardVariant.sheet),
      ));

      expect(find.text('Versement 3a 2026'), findsOneWidget);
      expect(find.text('Economie fiscale estimee'), findsOneWidget);
      expect(find.text("12'450 CHF"), findsOneWidget);
      expect(find.text('Simuler mon 3a'), findsOneWidget);
    });

    testWidgets('shows explanation text', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(), variant: ResponseCardVariant.sheet),
      ));

      expect(find.textContaining('Test explanation'), findsOneWidget);
    });

    testWidgets('shows proof button (info icon) when sources exist',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(), variant: ResponseCardVariant.sheet),
      ));

      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('sources NOT shown inline — only in proof sheet',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(), variant: ResponseCardVariant.sheet),
      ));

      // Sources text should NOT be visible on the card surface
      expect(find.text('OPP3 art. 7'), findsNothing);
    });

    testWidgets('renders percentage chiffre-choc', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(chiffreValue: 65.5, chiffreUnit: '%'),
          variant: ResponseCardVariant.sheet,
        ),
      ));

      expect(find.text('65.5%'), findsOneWidget);
    });
  });

  // ── NO LEGACY PATTERNS ──

  group('ResponseCardWidget — no legacy patterns', () {
    testWidgets('no left border (V1 removed)', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(), variant: ResponseCardVariant.sheet),
      ));

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('no +pts badge (V1 removed)', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
            card: _makeCard(impactPoints: 18),
            variant: ResponseCardVariant.sheet),
      ));

      expect(find.text('+18 pts'), findsNothing);
    });

    testWidgets('no alertes inline (V1 removed)', (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardWidget(
          card: _makeCard(alertes: ['Taux inferieur a 60%']),
          variant: ResponseCardVariant.sheet,
        ),
      ));

      // Alertes are in the proof sheet, not on the card
      expect(find.text('Taux inferieur a 60%'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  // ── TYPE ICONS ──

  group('ResponseCardWidget — type icons', () {
    testWidgets('renders correct icon for each type', (tester) async {
      final types = {
        ResponseCardType.pillar3a: Icons.savings_rounded,
        ResponseCardType.lppBuyback: Icons.account_balance_rounded,
        ResponseCardType.replacementRate: Icons.trending_up_rounded,
        ResponseCardType.taxOptimization: Icons.receipt_long_rounded,
        ResponseCardType.coupleAlert: Icons.family_restroom_rounded,
        ResponseCardType.patrimoine: Icons.account_balance_wallet_rounded,
        ResponseCardType.mortgage: Icons.home_rounded,
        ResponseCardType.independant: Icons.business_center_rounded,
      };

      for (final entry in types.entries) {
        await tester.pumpWidget(_wrap(
          ResponseCardWidget(
              card: _makeCard(type: entry.key),
              variant: ResponseCardVariant.sheet),
        ));

        expect(find.byIcon(entry.value), findsWidgets,
            reason: '${entry.key.name} should show rounded icon');
      }
    });
  });

  // ── STRIP ──

  group('ResponseCardStrip', () {
    testWidgets('renders nothing when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ResponseCardStrip(cards: [])),
        ),
      );

      expect(find.byType(ResponseCardWidget), findsNothing);
    });

    testWidgets('single card renders without horizontal scroll',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ResponseCardStrip(cards: [_makeCard()]),
      ));

      expect(find.text('Versement 3a 2026'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('multiple cards render in horizontal scroll',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ResponseCardStrip(
              cards: [
                _makeCard(title: 'Card A'),
                _makeCard(title: 'Card B'),
              ],
            ),
          ),
        ),
      ));

      expect(find.byType(ListView), findsOneWidget);
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
    });
  });
}
