import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/data_spine/coach_packet_insight_presenter.dart';
import 'package:mint_mobile/widgets/coach/coach_packet_insight_card.dart';

void main() {
  testWidgets('renders the visible packet-backed coach proof', (tester) async {
    const insight = CoachPacketInsight(
      title: 'Point de départ',
      knownLabel: 'Déjà clair',
      knownText: 'Capacité mensuelle: CHF 1\'200',
      nextLabel: 'Prochaine pièce',
      nextText: 'Objectif à atteindre',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CoachPacketInsightCard(insight: insight),
          ),
        ),
      ),
    );

    expect(find.text('Point de départ'), findsOneWidget);
    expect(find.text('Déjà clair'), findsOneWidget);
    expect(find.text('Capacité mensuelle: CHF 1\'200'), findsOneWidget);
    expect(find.text('Prochaine pièce'), findsOneWidget);
    expect(find.text('Objectif à atteindre'), findsOneWidget);
    expect(find.textContaining('packet'), findsNothing);
  });
}
