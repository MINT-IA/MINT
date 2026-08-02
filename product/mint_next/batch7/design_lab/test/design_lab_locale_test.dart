import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  for (final locale in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    testWidgets(
      '$locale renders the contribution slice without fallback marker',
      (tester) async {
        await tester.pumpWidget(
          MintNextDesignLabApp(locale: Locale(locale), currentYear: 2026),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:today_3a_intent')),
          findsOneWidget,
        );
        for (final action in [
          'action:today_3a_intent.start',
          'action:orientation.continue',
          'action:fact_tax_year.confirm_current_year',
          'action:fact_tax_year.continue',
          'action:fact_lpp_affiliation.choose_yes',
        ]) {
          final finder = find.byKey(ValueKey(action));
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('node:fact_contribution')),
          findsOneWidget,
        );
        final disclosure = find.byKey(
          const ValueKey('action:fact_contribution.toggle_edge_help'),
        );
        await tester.ensureVisible(disclosure);
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('content:fact_contribution.edge_help')),
          findsOneWidget,
        );
        final unknown = find.byKey(
          const ValueKey('action:fact_contribution.choose_unknown'),
        );
        await tester.ensureVisible(unknown);
        await tester.tap(unknown);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:contribution_unknown_help')),
          findsOneWidget,
        );
        expect(find.textContaining('MISSING_'), findsNothing);
      },
    );
  }
}
