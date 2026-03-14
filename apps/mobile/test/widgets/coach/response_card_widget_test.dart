import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';

// ────────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — Widget Tests
// ────────────────────────────────────────────────────────────────

ResponseCard _makeCard({
  ResponseCardType type = ResponseCardType.pillar3a,
  String title = 'Versement 3a 2026',
  String subtitle = 'Economie fiscale estimee',
  double chiffreValue = 2200,
  String chiffreUnit = 'CHF',
  String ctaLabel = 'Simuler mon 3a',
  String ctaRoute = '/simulator/3a',
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
    chiffreChoc: ChiffreChoc(
      value: chiffreValue,
      unit: chiffreUnit,
      explanation: 'Test explanation for $title',
    ),
    cta: CardCta(label: ctaLabel, route: ctaRoute, icon: 'savings'),
    urgency: urgency,
    deadline: deadline,
    disclaimer: 'Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).',
    sources: sources,
    alertes: alertes,
    impactPoints: impactPoints,
  );
}

void main() {
  group('ResponseCardWidget', () {
    testWidgets('renders title and subtitle', (tester) async {
      final card = _makeCard(title: 'Rachat LPP', subtitle: 'Potentiel');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.text('Rachat LPP'), findsOneWidget);
      expect(find.text('Potentiel'), findsOneWidget);
    });

    testWidgets('renders chiffre-choc formatted', (tester) async {
      final card = _makeCard(chiffreValue: 12450, chiffreUnit: 'CHF');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.text("12'450 CHF"), findsOneWidget);
    });

    testWidgets('renders percentage chiffre-choc', (tester) async {
      final card = _makeCard(chiffreValue: 65.5, chiffreUnit: '%');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.text('65.5%'), findsOneWidget);
    });

    testWidgets('renders CTA button', (tester) async {
      final card = _makeCard(ctaLabel: 'Simuler un rachat');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.text('Simuler un rachat'), findsOneWidget);
      // CTA is a GestureDetector with styled Container, not a FilledButton
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('renders sources', (tester) async {
      final card = _makeCard(sources: ['LPP art. 79b', 'LIFD art. 33']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.textContaining('LPP art. 79b'), findsOneWidget);
    });

    testWidgets('renders deadline badge when present', (tester) async {
      final card = _makeCard(
        urgency: CardUrgency.high,
        deadline: DateTime.now().add(const Duration(days: 20)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      // Deadline badge shows "J-20" format for days <= 30
      expect(find.textContaining('J-'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('no deadline badge when no deadline', (tester) async {
      final card = _makeCard(); // no deadline
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('renders alerte when present', (tester) async {
      final card = _makeCard(
        alertes: ['Taux inferieur au seuil recommande de 60%'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('60%'), findsOneWidget);
    });

    testWidgets('no alerte section when empty', (tester) async {
      final card = _makeCard(alertes: []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders explanation text', (tester) async {
      final card = _makeCard(title: 'Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
        ),
      );

      expect(find.textContaining('Test explanation'), findsOneWidget);
    });

    testWidgets('renders type icon for each card type', (tester) async {
      final types = {
        ResponseCardType.pillar3a: Icons.savings,
        ResponseCardType.lppBuyback: Icons.account_balance,
        ResponseCardType.replacementRate: Icons.trending_up,
        ResponseCardType.taxOptimization: Icons.receipt_long,
        ResponseCardType.coupleAlert: Icons.family_restroom,
        ResponseCardType.patrimoine: Icons.account_balance_wallet,
        ResponseCardType.mortgage: Icons.home,
        ResponseCardType.independant: Icons.business_center,
      };

      for (final entry in types.entries) {
        final card = _makeCard(type: entry.key);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: ResponseCardWidget(card: card))),
          ),
        );

        expect(find.byIcon(entry.value), findsWidgets,
            reason: '${entry.key.name} should show ${entry.value}');
      }
    });
  });

  group('ResponseCardStrip', () {
    testWidgets('renders nothing when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ResponseCardStrip(cards: [])),
        ),
      );

      expect(find.byType(ResponseCardStrip), findsOneWidget);
      expect(find.byType(ResponseCardWidget), findsNothing);
    });

    testWidgets('renders multiple cards', (tester) async {
      final cards = [
        _makeCard(type: ResponseCardType.pillar3a, title: 'Card 1'),
        _makeCard(type: ResponseCardType.lppBuyback, title: 'Card 2'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResponseCardStrip(cards: cards)),
        ),
      );

      expect(find.byType(ResponseCardWidget), findsNWidgets(2));
      expect(find.text('Card 1'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
    });

    testWidgets('uses horizontal scroll', (tester) async {
      final cards = [
        _makeCard(type: ResponseCardType.pillar3a, title: 'A'),
        _makeCard(type: ResponseCardType.lppBuyback, title: 'B'),
        _makeCard(type: ResponseCardType.replacementRate, title: 'C'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResponseCardStrip(cards: cards)),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
    });
  });
}
