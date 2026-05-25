import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';
import 'package:mint_mobile/widgets/coach/micro_action_card.dart';
import 'package:mint_mobile/widgets/coach/retirement_hero_zone.dart';

void main() {
  testWidgets('RetirementHeroZone formats delta since last visit as CHF',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetirementHeroZone(
            monthlyIncome: 6200,
            replacementRate: 68,
            decomposition: {'avs': 24000, 'lpp': 36000, '3a': 12000},
            monthlyPrudent: 5400,
            monthlyOptimiste: 7000,
            confidenceScore: 76,
            deltaSinceLastVisit: 12345,
            currentAge: 42,
          ),
        ),
      ),
    );

    expect(
      find.text("+CHF\u00a012'345/mois depuis ta dernière visite"),
      findsOneWidget,
    );
    expect(
      find.text('+CHF 12345/mois depuis ta dernière visite'),
      findsNothing,
    );
  });

  testWidgets('MicroActionCard formats yearly CHF impact', (tester) async {
    const action = MicroAction(
      id: 'impact',
      title: 'Verse ton 3a',
      description: 'Prépare ton versement annuel',
      category: '3a',
      estimatedMinutes: 7,
      estimatedImpactChf: 12345,
      deeplink: '/pillar-3a',
      priorityScore: 80,
      urgency: MicroActionUrgency.high,
      icon: Icons.savings_outlined,
      source: 'Test',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MicroActionCard(action: action),
        ),
      ),
    );

    expect(find.text("~CHF\u00a012'345/an"), findsOneWidget);
    expect(find.text('~CHF 12345/an'), findsNothing);
  });
}
