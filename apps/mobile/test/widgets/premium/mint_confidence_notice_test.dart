import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';

void main() {
  testWidgets('optional action semantics identifies only the real CTA',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MintConfidenceNotice(
            percent: 45,
            message: 'Estimation à préciser',
            ctaLabel: 'Améliorer mes données',
            onTap: () => taps++,
            actionSemanticsIdentifier: 'mortgage_enrich_profile_cta',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Estimation à préciser'));
    expect(taps, 0, reason: 'the whole notice must not become actionable');

    final action = find.bySemanticsIdentifier('mortgage_enrich_profile_cta');
    expect(action, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MintConfidenceNotice),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );
    expect(tester.getSemantics(action).flagsCollection.isButton, isTrue);
    await tester.tap(action);
    expect(taps, 1);
    semantics.dispose();
  });

  test('Mortgage passes the exact stable action identifier', () {
    final source = File(
      'lib/screens/mortgage/affordability_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        "actionSemanticsIdentifier: 'mortgage_enrich_profile_cta'",
      ),
    );
  });
}
