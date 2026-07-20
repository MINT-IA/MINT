import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart' show firstJobFeatureRedirect;
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:provider/provider.dart';

class _ProfileProvider extends CoachProfileProvider {
  _ProfileProvider() {
    _profile = CoachProfile.fromWizardAnswers({
      'q_gross_salary_annual': 96000,
      'q_birth_year': DateTime.now().year - 25,
      'q_canton': 'VD',
    });
  }

  late final CoachProfile _profile;

  @override
  CoachProfile get profile => _profile;

  @override
  bool get hasProfile => true;
}

Widget _app() => ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _ProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: FirstJobScreen(),
      ),
    );

void main() {
  test('production flag redirects /first-job and backend cannot enable it', () {
    final original = FeatureFlags.enableFirstJobScreen;
    addTearDown(() => FeatureFlags.enableFirstJobScreen = original);
    FeatureFlags.enableFirstJobScreen = false;
    FeatureFlags.applyFromMap({'enableFirstJobScreen': true});

    expect(FeatureFlags.enableFirstJobScreen, isFalse);
    expect(firstJobFeatureRedirect(), '/explore/travail');
  });

  test('canonical CHF formatter cannot produce the malformed projection', () {
    expect(formatChfWithPrefix(1641000), "CHF\u00a01'641'000");
    expect(formatChfWithPrefix(1641000), isNot(contains("1641'000")));
  });

  test('salary model keeps LPP and exact net unknown without evidence', () {
    final result = FirstJobService.analyzeSalary(
      salaireBrutMensuel: 8000,
      age: 25,
      canton: 'VD',
    );

    expect(result.lppEmploye, isNull);
    expect(result.netEstime, isNull);
  });

  testWidgets('assembled screen has one salary story and one checklist',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 7000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('first_job_salary_authority'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('first_job_enrich_profile_cta'),
        findsOneWidget);
    expect(
        find.bySemanticsIdentifier('first_job_lamal_handoff'), findsOneWidget);
    expect(find.bySemanticsIdentifier('first_job_checklist'), findsOneWidget);
    expect(find.byKey(const Key('first_job_salary_authority')), findsOneWidget);
    expect(find.byKey(const Key('first_job_checklist')), findsOneWidget);
    expect(find.byKey(const Key('first_salary_film')), findsNothing);
    expect(find.byType(JobChangeChecklistWidget), findsNothing);
    expect(find.textContaining('TOP'), findsNothing);
    expect(find.textContaining('Suggestion /mois'), findsNothing);
    expect(find.textContaining('Évite'), findsNothing);
    expect(find.textContaining('Privilégie'), findsNothing);
    expect(find.byKey(const Key('first_job_lamal_handoff')), findsOneWidget);

    final salary = formatChfWithPrefix(8000);
    expect(find.text(salary), findsOneWidget);
    expect(find.textContaining('LPP exacte : à confirmer'), findsOneWidget);
    expect(find.textContaining('Net exact : à confirmer'), findsOneWidget);
  });
}
