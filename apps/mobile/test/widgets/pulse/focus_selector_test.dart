import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/pulse/focus_selector.dart';

void main() {
  testWidgets('tax preview labels 3a tax impact as an estimate',
      (tester) async {
    final profile = CoachProfile(
      birthYear: 1995,
      canton: 'ZH',
      salaireBrutMensuel: 6000,
      employmentStatus: 'salarie',
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055),
        label: 'Retraite',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusSelector(
            profile: profile,
            onFocusSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Optimiser'));
    await tester.pumpAndSettle();

    expect(find.textContaining('récupérables'), findsNothing);
    expect(find.textContaining("d'impôt estimés"), findsOneWidget);
  });
}
