import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/dashboard/retirement_checklist_card.dart';

void main() {
  testWidgets('LPP buyback checklist uses estimated tax reduction wording',
      (tester) async {
    final profile = CoachProfile(
      birthYear: 1980,
      canton: 'VD',
      salaireBrutMensuel: 11000,
      prevoyance: const PrevoyanceProfile(
        rachatMaximum: 40000,
        avoirLppTotal: 250000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetirementChecklistCard(profile: profile),
        ),
      ),
    );

    expect(find.textContaining('Réduction d’impôt estimée'), findsOneWidget);
    expect(find.textContaining('Économie d’impôt'), findsNothing);
    expect(find.textContaining("Économie d'impôt"), findsNothing);
  });
}
