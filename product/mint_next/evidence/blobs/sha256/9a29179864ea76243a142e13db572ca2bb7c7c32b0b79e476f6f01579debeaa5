import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  testWidgets('first slice follows accepted canonical node ids', (
    tester,
  ) async {
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));

    expect(find.byKey(const ValueKey('node:today_3a_intent')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.start')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:orientation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action:orientation.continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:fact_tax_year')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('action:fact_tax_year.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node:orientation')), findsOneWidget);
  });

  testWidgets('safe exit exposes all canonical overlay actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MintNextDesignLabApp(locale: Locale('fr')));
    await tester.tap(
      find.byKey(const ValueKey('action:today_3a_intent.open_safe_exit')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overlay:safe_exit')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('overlay-action:safe_exit.resume')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.keep_local_reference'),
      ),
      findsOneWidget,
    );
    final unavailable = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(
          const ValueKey('overlay-action:safe_exit.keep_local_reference'),
        ),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(unavailable.onPressed, isNull);
    expect(
      find.byKey(
        const ValueKey('overlay-action:safe_exit.leave_without_saving'),
      ),
      findsOneWidget,
    );
  });
}
