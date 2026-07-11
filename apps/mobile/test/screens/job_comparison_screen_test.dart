import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:provider/provider.dart';

class RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  RecordingCoachProfileProvider(Map<String, dynamic> initialAnswers)
      : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
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

Widget _wrap(
  Widget child, {
  CoachProfileProvider? provider,
}) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => provider ?? RecordingCoachProfileProvider({}),
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

Widget _wrapRouter({
  required CoachProfileProvider provider,
}) {
  final router = GoRouter(
    initialLocation: '/simulator/job-comparison',
    routes: [
      GoRoute(
        path: '/simulator/job-comparison',
        builder: (context, state) => const JobComparisonScreen(),
      ),
      GoRoute(
        path: '/data-block/revenu',
        builder: (context, state) => const Scaffold(
          body: Text(
            'data block revenu',
            key: Key('data_block_revenu_stub'),
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

void main() {
  group('JobComparisonScreen', () {
    testWidgets('requires current salary and age from the ledger',
        (tester) async {
      await tester.pumpWidget(_wrap(const JobComparisonScreen()));
      await tester.pump();

      expect(find.byKey(const Key('job_compare_ledger_facts')), findsOneWidget);
      expect(find.byKey(const Key('job_compare_salary_fact')), findsOneWidget);
      expect(find.byKey(const Key('job_compare_age_fact')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('job_compare_salary_fact')),
          matching: find.text('Manquant'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('job_compare_age_fact')),
          matching: find.text('Manquant'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining("85'000"), findsNothing);
      expect(find.text('35 ans'), findsNothing);

      await tester.ensureVisible(find.text('Comparer'));
      await tester.tap(find.text('Comparer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('job_compare_result')), findsNothing);
    });

    testWidgets('routes missing current salary to the revenue DataBlock',
        (tester) async {
      await tester.pumpWidget(_wrapRouter(
        provider: RecordingCoachProfileProvider({}),
      ));
      await tester.pump();

      await tester.tap(find.text('Enrichir mon profil'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('data_block_revenu_stub')), findsOneWidget);
    });

    testWidgets('uses current job facts from the ledger when available',
        (tester) async {
      final currentYear = DateTime.now().year;
      await tester.pumpWidget(_wrap(
        const JobComparisonScreen(),
        provider: RecordingCoachProfileProvider({
          'q_gross_salary_annual': 96000,
          'q_birth_year': currentYear - 40,
        }),
      ));
      await tester.pump();

      expect(find.byKey(const Key('job_compare_ledger_facts')), findsOneWidget);
      expect(find.textContaining("96'000"), findsWidgets);
      expect(find.text('40 ans'), findsWidgets);
      expect(find.textContaining("85'000"), findsNothing);

      await tester.ensureVisible(find.text('Comparer'));
      await tester.tap(find.text('Comparer'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job_compare_result')), findsOneWidget);
    });
  });
}
