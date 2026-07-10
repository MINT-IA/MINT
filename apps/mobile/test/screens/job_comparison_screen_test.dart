import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:provider/provider.dart';

Widget _buildScreen(CoachProfileProvider provider) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: JobComparisonScreen(),
    ),
  );
}

Widget _buildRoutedScreen(CoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/simulator/job-comparison',
    routes: [
      GoRoute(
        path: '/simulator/job-comparison',
        builder: (context, state) => const JobComparisonScreen(),
      ),
      GoRoute(
        path: '/data-block/revenu',
        builder: (context, state) => Scaffold(
          body: Text(
            'inputKey=${state.uri.queryParameters['inputKey'] ?? 'none'}',
          ),
        ),
      ),
    ],
  );

  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

CoachProfileProvider _provider(Map<String, dynamic> answers) {
  return CoachProfileProvider()..updateFromAnswers(answers);
}

void main() {
  group('JobComparisonScreen ledger facts', () {
    testWidgets('requires current salary and age before comparison',
        (tester) async {
      await tester.pumpWidget(_buildScreen(_provider({})));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job_compare_ledger_facts')), findsOneWidget);
      expect(find.byKey(const Key('job_compare_submit')), findsNothing);
      expect(find.textContaining("85'000"), findsNothing);
      expect(find.text('35 ans'), findsNothing);
      expect(find.byKey(const Key('job_compare_result')), findsNothing);
    });

    testWidgets('uses ledger salary and age for the current job',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _provider({
            'q_gross_salary_annual': 120000,
            'q_birth_year': DateTime.now().year - 42,
            'q_canton': 'GE',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job_compare_ledger_facts')), findsOneWidget);
      expect(
        find.byKey(const Key('job_compare_current_salary_fact')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('job_compare_age_fact')), findsOneWidget);
      expect(find.textContaining("120'000"), findsWidgets);
      expect(find.text('42 ans'), findsOneWidget);
      expect(find.textContaining('confirmer'), findsOneWidget);
      expect(find.textContaining("85'000"), findsNothing);
      expect(find.text('35 ans'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('job_compare_submit')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('job_compare_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_compare_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job_compare_result')), findsOneWidget);
    });

    testWidgets('clears the comparison result when ledger facts change',
        (tester) async {
      final provider = _provider({
        'q_gross_salary_annual': 120000,
        'q_birth_year': DateTime.now().year - 42,
        'q_canton': 'GE',
      });

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('job_compare_submit')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('job_compare_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_compare_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job_compare_result')), findsOneWidget);

      provider.updateFromAnswers({
        'q_gross_salary_annual': 130000,
        'q_birth_year': DateTime.now().year - 42,
        'q_canton': 'GE',
      });
      await tester.pumpAndSettle();

      expect(find.textContaining("130'000"), findsWidgets);
      expect(find.byKey(const Key('job_compare_result')), findsNothing);
    });

    testWidgets('enrichment CTA routes to missing salary input',
        (tester) async {
      await tester.pumpWidget(_buildRoutedScreen(_provider({})));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_compare_ledger_fact_cta')));
      await tester.pumpAndSettle();

      expect(find.text('inputKey=q_gross_salary_annual'), findsOneWidget);
    });

    testWidgets('ledger facts CTA routes to missing birth year input',
        (tester) async {
      await tester.pumpWidget(
        _buildRoutedScreen(
          _provider({
            'q_gross_salary_annual': 120000,
            'q_canton': 'GE',
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_compare_ledger_fact_cta')));
      await tester.pumpAndSettle();

      expect(find.text('inputKey=q_birth_year'), findsOneWidget);
    });

    testWidgets('ledger facts CTA routes to revenue block when facts are known',
        (tester) async {
      await tester.pumpWidget(
        _buildRoutedScreen(
          _provider({
            'q_gross_salary_annual': 120000,
            'q_birth_year': DateTime.now().year - 42,
            'q_canton': 'GE',
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job_compare_ledger_fact_cta')));
      await tester.pumpAndSettle();

      expect(find.text('inputKey=none'), findsOneWidget);
    });
  });
}
