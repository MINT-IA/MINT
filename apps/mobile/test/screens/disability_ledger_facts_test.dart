import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';

class RecordingCoachProfileProvider extends CoachProfileProvider {
  RecordingCoachProfileProvider(Map<String, dynamic> initialAnswers)
      : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
  }

  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

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

Map<String, dynamic> answers({
  double? grossSalary,
  int? birthYear,
  double? cashTotal,
}) {
  return {
    if (grossSalary != null) 'q_gross_salary_annual': grossSalary,
    if (birthYear != null) 'q_birth_year': birthYear,
    if (cashTotal != null) 'q_cash_total': cashTotal,
    'q_canton': 'VD',
    'q_employment_status': 'salarie',
  };
}

Widget buildRouter({
  required CoachProfileProvider provider,
  required Widget child,
}) {
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
          'data-block:${state.pathParameters['type']}:${state.uri.queryParameters['inputKey']}',
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

void main() {
  group('DisabilityGapScreen ledger facts', () {
    testWidgets(
        'uses ledger facts instead of local salary, age, or savings sliders',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(
              grossSalary: 120000,
              birthYear: DateTime.now().year - 42,
              cashTotal: 36000,
            ),
          ),
          child: const DisabilityGapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintPremiumSlider), findsNothing);
      expect(
          find.byKey(const Key('disability_gap_ledger_facts')), findsOneWidget);
      expect(
          find.byKey(const Key('disability_gap_income_fact')), findsOneWidget);
      expect(find.byKey(const Key('disability_gap_age_fact')), findsOneWidget);
      expect(
          find.byKey(const Key('disability_gap_savings_fact')), findsOneWidget);
    });

    testWidgets('emits completion return when complete facts render',
        (tester) async {
      final completion = expectLater(
        ScreenCompletionTracker.stream,
        emits(predicate<ScreenReturn>((event) {
          final gap = event.updatedFields?['disabilityGapMensuel'];
          return event.route == '/invalidite' &&
              event.outcome == ScreenOutcome.completed &&
              event.nextCapSuggestion == 'assurance_invalidite' &&
              gap is num &&
              gap > 0;
        })),
      );

      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(
              grossSalary: 120000,
              birthYear: DateTime.now().year - 42,
              cashTotal: 36000,
            ),
          ),
          child: const DisabilityGapScreen(),
        ),
      );
      await tester.pump();

      await completion;
    });

    testWidgets('routes to the missing salary fact instead of defaulting',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(
              birthYear: DateTime.now().year - 42,
              cashTotal: 36000,
            ),
          ),
          child: const DisabilityGapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintPremiumSlider), findsNothing);

      await tester
          .tap(find.byKey(const Key('disability_gap_enrich_profile_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text('data-block:revenu:q_gross_salary_annual'),
        findsOneWidget,
      );
    });

    testWidgets('accepts zero cash savings as a complete ledger fact',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(
              grossSalary: 120000,
              birthYear: DateTime.now().year - 42,
              cashTotal: 0,
            ),
          ),
          child: const DisabilityGapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('disability_gap_enrich_profile_cta')),
        findsNothing,
      );
      expect(find.text('CHF 0'), findsWidgets);
      expect(find.byType(MintPremiumSlider), findsNothing);
    });
  });

  group('DisabilityInsuranceScreen ledger facts', () {
    testWidgets('uses ledger facts instead of local salary or savings sliders',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(grossSalary: 120000, cashTotal: 36000),
          ),
          child: const DisabilityInsuranceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintPremiumSlider), findsNothing);
      expect(
        find.byKey(const Key('disability_insurance_ledger_facts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('disability_insurance_income_fact')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('disability_insurance_savings_fact')),
        findsOneWidget,
      );
    });

    testWidgets('routes to the missing savings fact instead of defaulting',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(grossSalary: 120000),
          ),
          child: const DisabilityInsuranceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintPremiumSlider), findsNothing);

      await tester.tap(
        find.byKey(const Key('disability_insurance_enrich_profile_cta')),
      );
      await tester.pumpAndSettle();

      expect(find.text('data-block:patrimoine:q_cash_total'), findsOneWidget);
    });

    testWidgets('accepts zero cash savings as a complete ledger fact',
        (tester) async {
      await tester.pumpWidget(
        buildRouter(
          provider: RecordingCoachProfileProvider(
            answers(grossSalary: 120000, cashTotal: 0),
          ),
          child: const DisabilityInsuranceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('disability_insurance_enrich_profile_cta')),
        findsNothing,
      );
      expect(find.text('CHF 0'), findsWidgets);
      expect(find.byType(MintPremiumSlider), findsNothing);
    });
  });
}
