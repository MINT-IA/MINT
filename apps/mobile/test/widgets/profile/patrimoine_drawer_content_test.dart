import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/profile/patrimoine_drawer_content.dart';

CoachProfile _profileWithAvsGap({
  required int years,
  required ProfileDataSource source,
}) {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
    prevoyance: PrevoyanceProfile(lacunesAVS: years),
    dataSources: {
      AvsGapEvidence.selfFieldPath: source,
    },
  );
}

Widget _app(CoachProfile profile) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PatrimoineDrawerContent(profile: profile),
      ),
    ),
  );
}

void main() {
  testWidgets('declared AVS gap years stay neutral instead of rendering',
      (tester) async {
    await tester.pumpWidget(_app(_profileWithAvsGap(
      years: 7,
      source: ProfileDataSource.userInput,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Lacunes'), findsNothing);
    expect(find.text('7 ans'), findsNothing);
  });

  testWidgets('certificate-backed AVS gap years render as certified evidence',
      (tester) async {
    await tester.pumpWidget(_app(_profileWithAvsGap(
      years: 7,
      source: ProfileDataSource.certificate,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Lacunes'), findsOneWidget);
    expect(find.text('7 ans'), findsOneWidget);
  });
}
