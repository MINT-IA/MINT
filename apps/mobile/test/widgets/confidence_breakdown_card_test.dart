import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/confidence_breakdown_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders localized data quality heading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ConfidenceBreakdownCard(
          completeness: 0.8,
          accuracy: 0.7,
          freshness: 0.9,
        ),
      ),
    );

    expect(find.text('Qualité des données'), findsOneWidget);
    expect(find.textContaining('Precision'), findsNothing);
    expect(find.textContaining('donnees'), findsNothing);
  });
}
