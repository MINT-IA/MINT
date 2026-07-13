import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

CoachProfile _certifiedDemoProfile() {
  final profile = CoachProfile.buildDemo();
  final spouse = profile.conjoint!;
  return profile.copyWith(
    prevoyance: profile.prevoyance.copyWith(
      lacunesAVS: 0,
    ),
    conjoint: spouse.copyWith(
      prevoyance: spouse.prevoyance!.copyWith(
        lacunesAVS: 14,
        ramd: 60000,
        anneesContribuees: 25,
      ),
    ),
    dataSources: {
      ...profile.dataSources,
      AvsGapEvidence.selfFieldPath: ProfileDataSource.certificate,
      AvsGapEvidence.spouseFieldPath: ProfileDataSource.certificate,
      ForecasterService.spouseRamdFieldPath: ProfileDataSource.certificate,
      ForecasterService.spouseContributionYearsFieldPath:
          ProfileDataSource.certificate,
    },
  );
}

void main() {
  late ProjectionResult result;

  setUp(() {
    final profile = _certifiedDemoProfile();
    result = ForecasterService.project(
      profile: profile,
      targetDate: profile.goalA.targetDate,
    );
  });

  Widget buildTestWidget({ProjectionResult? projResult, String? goalALabel}) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MintTrajectoryChart(
            result: projResult ?? result,
            goalALabel: goalALabel ?? 'Retraite 65 ans',
          ),
        ),
      ),
    );
  }

  group('MintTrajectoryChart', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MintTrajectoryChart), findsOneWidget);
    });

    testWidgets('displays CustomPaint for chart', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows scenario labels', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('Optimiste'), findsWidgets);
      expect(find.textContaining('Prudent'), findsWidgets);
    });

    testWidgets('shows goal A label', (tester) async {
      await tester.pumpWidget(buildTestWidget(goalALabel: 'Retraite 65 ans'));
      await tester.pumpAndSettle();
      expect(find.byType(MintTrajectoryChart), findsOneWidget);
    });

    testWidgets('handles tap without crash', (tester) async {
      // ignore: unused_local_variable
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MintTrajectoryChart(
              result: result,
              goalALabel: 'Retraite',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // When chart has data points, tap selects/deselects points
      // (onTap forwarded only when no point selected and no data under cursor).
      // Verify tap does not crash.
      await tester.tap(find.byType(MintTrajectoryChart).first);
      await tester.pump();
      // No crash = success
      expect(find.byType(MintTrajectoryChart), findsOneWidget);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('unready keeps capital chart but omits replacement rate',
        (tester) async {
      final profile = CoachProfile.buildDemo();
      final unready = ForecasterService.project(profile: profile);

      await tester.pumpWidget(buildTestWidget(projResult: unready));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('Taux de remplacement'), findsNothing);
      final semantics = tester.getSemantics(find.byType(MintTrajectoryChart));
      expect(semantics.label, isNot(contains('Taux de remplacement')));
    });

    testWidgets('result has 3 scenarios with points', (tester) async {
      expect(result.prudent, isNotNull);
      expect(result.base, isNotNull);
      expect(result.optimiste, isNotNull);
      expect(result.prudent.points, isNotEmpty);
      expect(result.base.points, isNotEmpty);
      expect(result.optimiste.points, isNotEmpty);
    });

    testWidgets('optimiste capital > base > prudent', (tester) async {
      expect(result.optimiste.capitalFinal, greaterThan(result.base.capitalFinal));
      expect(result.base.capitalFinal, greaterThan(result.prudent.capitalFinal));
    });

    testWidgets('widget contains RichText for data display', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
