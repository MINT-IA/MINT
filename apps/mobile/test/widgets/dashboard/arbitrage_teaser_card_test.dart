import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/dashboard/arbitrage_teaser_card.dart';

void main() {
  setUp(() {
    FeatureFlags.enableDecisionScaffold = true;
  });

  testWidgets('arbitrage teasers frame fiscal figures as indicative',
      (tester) async {
    final profile = CoachProfile(
      birthYear: 1976,
      canton: 'VD',
      salaireBrutMensuel: 11000,
      prevoyance: const PrevoyanceProfile(
        avoirLppTotal: 300000,
        totalEpargne3a: 80000,
        rachatMaximum: 40000,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2041),
        label: 'Retraite',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArbitrageTeaserSection(profile: profile),
        ),
      ),
    );

    expect(find.text('Pistes d’arbitrage'), findsOneWidget);
    expect(find.text('Calendrier de retraits'), findsOneWidget);
    expect(find.text('Rachat LPP'), findsOneWidget);
    expect(find.textContaining('impact fiscal indicatif'), findsWidgets);
    expect(find.textContaining('L’option'), findsNothing);
    expect(find.textContaining('pourrait donner'), findsNothing);
    expect(find.textContaining('pourrait économiser'), findsNothing);
    expect(find.textContaining('réduire ton impôt'), findsNothing);
    expect(find.textContaining('économie fiscale'), findsNothing);
  });
}
