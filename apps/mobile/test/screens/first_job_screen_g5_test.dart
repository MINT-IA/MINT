import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, CoachProfileProvider provider) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders G5 tax and 3a summary from canonical profile facts',
      (tester) async {
    final provider = CoachProfileProvider()
      ..updateFromAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_birth_year': 2001,
        'q_3a_annual_contribution': 3000,
      });

    await tester.pumpWidget(_wrap(const FirstJobScreen(), provider));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('first_salary_tax_3a_summary')),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(
        find.byKey(const Key('first_salary_tax_3a_summary')), findsOneWidget);
    expect(find.byKey(const Key('first_salary_tax_3a_status_salary')),
        findsOneWidget);
    expect(find.byKey(const Key('first_salary_tax_3a_status_3a_known')),
        findsOneWidget);
    expect(find.byKey(const Key('first_salary_tax_3a_pillar3a_cta')),
        findsOneWidget);
  });

  testWidgets('surfaces DataQuest CTA when first salary facts are missing',
      (tester) async {
    final provider = CoachProfileProvider();

    await tester.pumpWidget(_wrap(const FirstJobScreen(), provider));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('first_salary_tax_3a_summary')),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(
        find.byKey(const Key('first_salary_tax_3a_summary')), findsOneWidget);
    expect(
        find.byKey(const Key('first_salary_tax_3a_data_cta')), findsOneWidget);
  });

  testWidgets('does not render legacy analysis widgets in first-job path',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider()
      ..updateFromAnswers({
        'q_gross_salary_annual': 96000,
        'q_canton': 'GE',
        'q_birth_year': 2001,
      });

    await tester.pumpWidget(_wrap(const FirstJobScreen(), provider));
    await tester.pump();

    expect(
        find.byKey(const Key('first_salary_tax_3a_summary')), findsOneWidget);
    expect(find.byKey(const Key('first_salary_tax_3a_room')), findsOneWidget);
    expect(find.byType(FirstSalaryFilmWidget), findsNothing);
    expect(find.byType(Budget503020Widget), findsNothing);
    expect(find.textContaining('Et si tu avais commencé'), findsNothing);
    expect(find.textContaining('Checklist changement de job'), findsNothing);
  });
}
