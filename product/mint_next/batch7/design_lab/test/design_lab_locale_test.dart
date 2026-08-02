import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  for (final locale in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    testWidgets(
      '$locale renders localized first slice without fallback marker',
      (tester) async {
        await tester.pumpWidget(MintNextDesignLabApp(locale: Locale(locale)));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:today_3a_intent')),
          findsOneWidget,
        );
        expect(find.textContaining('MISSING_'), findsNothing);
      },
    );
  }
}
