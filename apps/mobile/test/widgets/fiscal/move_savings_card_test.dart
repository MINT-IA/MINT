import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/fiscal/move_savings_card.dart';

void main() {
  testWidgets('move comparison uses estimated difference wording',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MoveSavingsCard(
            cantonFrom: 'VD',
            cantonFromName: 'Vaud',
            cantonTo: 'ZG',
            cantonToName: 'Zoug',
            chargeFrom: 18000,
            chargeTo: 14000,
            economieAnnuelle: 4000,
            economieMensuelle: 333,
            economie10Ans: 40000,
            premierEclairage: 'Simulation cantonale indicative.',
          ),
        ),
      ),
    );

    expect(find.text('Écart mensuel estimé'), findsOneWidget);
    expect(find.text('Écart annuel estimé'), findsOneWidget);
    expect(find.text('Écart estimé sur 10 ans'), findsOneWidget);
    expect(find.textContaining('Économie mensuelle'), findsNothing);
    expect(find.textContaining('Économie annuelle'), findsNothing);
    expect(find.textContaining('Économie sur 10 ans'), findsNothing);
  });
}
