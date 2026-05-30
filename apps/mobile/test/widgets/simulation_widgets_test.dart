import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/simulation_widgets.dart';

void main() {
  group('LppBuybackSimulation', () {
    testWidgets('labels tax impact as indicative, not immediate saving',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LppBuybackSimulation(
              buybackAmount: 50000,
              marginalTaxRate: 25,
            ),
          ),
        ),
      );

      expect(find.text('Impact fiscal indicatif'), findsOneWidget);
      expect(find.text('CHF 12500'), findsOneWidget);
      expect(find.byIcon(Icons.calculate), findsOneWidget);
      expect(find.byIcon(Icons.savings), findsNothing);
      expect(find.text('Économie fiscale immédiate'), findsNothing);
      expect(find.textContaining('économie d’impôt'), findsNothing);
      expect(find.textContaining("économie d'impôt"), findsNothing);
      expect(find.textContaining('gain fiscal'), findsNothing);
      expect(find.textContaining('tu économises'), findsNothing);
      expect(find.textContaining('tu economises'), findsNothing);
      expect(find.textContaining('rendement fiscal'), findsNothing);
      expect(find.textContaining('garanti'), findsNothing);
      expect(find.textContaining('optimal'), findsNothing);
      expect(find.textContaining('sans risque'), findsNothing);
      expect(find.textContaining('certain'), findsNothing);
      expect(find.textContaining('assuré'), findsNothing);
      expect(find.textContaining('meilleur'), findsNothing);
      expect(find.textContaining('parfait'), findsNothing);
    });
  });
}
