import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  _RecordingCoachProfileProvider(
    Map<String, dynamic> initialAnswers, {
    CoachProfile? profileOverride,
  }) : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride =
        profileOverride ?? CoachProfile.fromWizardAnswers(_answers);
  }

  @override
  CoachProfile? get profile => _profileOverride;

  @override
  bool get hasProfile => _profileOverride != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    _answers.addAll(partial);
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
    notifyListeners();
  }
}

Widget _buildWithProvider(
  CoachProfileProvider provider,
  Widget child,
) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

Widget _buildWithRouter(
  CoachProfileProvider provider,
  Widget child,
) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChangeNotifierProvider<CoachProfileProvider>.value(
          value: provider,
          child: child,
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Text(
          'data-block:${state.pathParameters['type']}:'
          '${state.uri.queryParameters['inputKey']}',
          key: const Key('data_block_route_probe'),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
}

Map<String, dynamic> _answers({
  double? grossSalaryAnnual,
  int? birthYear,
  double? cashTotal,
}) {
  return {
    if (grossSalaryAnnual != null) 'q_gross_salary_annual': grossSalaryAnnual,
    if (birthYear != null) 'q_birth_year': birthYear,
    if (cashTotal != null) 'q_cash_total': cashTotal,
    'q_employment_status': 'salarie',
  };
}

void main() {
  testWidgets('reads salary age and savings from ledger facts only',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      birthYear: DateTime.now().year - 45,
      cashTotal: 42000,
    ));

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityGapScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('disability_gap_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('disability_gap_salary_fact')), findsOneWidget);
    expect(find.byKey(const Key('disability_gap_age_fact')), findsOneWidget);
    expect(
        find.byKey(const Key('disability_gap_savings_fact')), findsOneWidget);
    expect(find.text("CHF 8'000"), findsWidgets);
    expect(find.text('45 ans'), findsWidgets);
    expect(find.text("CHF 42'000"), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('disability_gap_result_section')), findsOneWidget);
    expect(find.byType(MintPremiumSlider), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('does not unlock results from unprovided profile defaults',
      (tester) async {
    final phantomProfile = CoachProfile.defaults().copyWith(
      birthYear: DateTime.now().year - 45,
      salaireBrutMensuel: 8000,
      patrimoine: const PatrimoineProfile(epargneLiquide: 42000),
      userProvidedFields: const {},
    );
    final provider = _RecordingCoachProfileProvider(
      const {},
      profileOverride: phantomProfile,
    );

    await tester.pumpWidget(_buildWithProvider(
      provider,
      const DisabilityGapScreen(),
    ));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('disability_gap_ledger_facts')), findsOneWidget);
    expect(
        find.byKey(const Key('disability_gap_result_section')), findsNothing);
    expect(find.text("CHF 8'000"), findsNothing);
    expect(find.text('45 ans'), findsNothing);
    expect(find.text("CHF 42'000"), findsNothing);
    expect(find.text('Manquant'), findsNWidgets(3));
    expect(find.byType(MintPremiumSlider), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('routes the next missing fact to its targeted data block',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(_answers(
      grossSalaryAnnual: 96000,
      birthYear: DateTime.now().year - 45,
    ));

    await tester.pumpWidget(_buildWithRouter(
      provider,
      const DisabilityGapScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('disability_gap_enrich_cta')));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:patrimoine:q_cash_total'),
      findsOneWidget,
    );
  });
}
