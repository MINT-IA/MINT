import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/coverage_check_screen.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  _RecordingCoachProfileProvider(Map<String, dynamic> initialAnswers)
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

Widget _buildWithRouter(CoachProfileProvider provider) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChangeNotifierProvider<CoachProfileProvider>.value(
          value: provider,
          child: const CoverageCheckScreen(),
        ),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Text(
          'data-block:${state.pathParameters['type']}:'
          '${state.uri.queryParameters['inputKey'] ?? 'none'}',
          key: const Key('data_block_route_probe'),
        ),
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, state) => Text(
          'coach:${state.uri.queryParameters['topic'] ?? 'none'}',
          key: const Key('coach_route_probe'),
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

void _setReliableViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _rowForText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byType(Row),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows missing ledger facts instead of demo profile controls',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {});

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coverage_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('coverage_missing_profile_facts')),
        findsOneWidget);
    expect(find.byKey(const Key('coverage_result_section')), findsNothing);
    expect(find.text('MODE DÉMO'), findsNothing);
    expect(
      find.descendant(
        of: _rowForText('Hypothèque en cours'),
        matching: find.byType(Switch),
      ),
      findsNothing,
    );
  });

  testWidgets('routes missing profile facts to the first missing DataQuest key',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {});

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coverage_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('data-block:revenu:q_canton'), findsOneWidget);
  });

  testWidgets('routes missing household facts to composition menage collector',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'independant',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coverage_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('data-block:composition_menage:none'), findsOneWidget);
  });

  testWidgets('routes missing employment fact to coach topic', (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coverage_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('coach:employmentStatus'), findsOneWidget);
  });

  testWidgets('routes malformed housing status back to household collector',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'independant',
      'q_children': 0,
      'q_housing_status': 'legacy_unknown',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coverage_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('data-block:composition_menage:none'), findsOneWidget);
  });

  testWidgets('routes missing owner mortgage context to patrimoine collector',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'independant',
      'q_children': 0,
      'q_housing_status': 'owner',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coverage_profile_enrich_cta')));
    await tester.pumpAndSettle();

    expect(find.text('data-block:patrimoine:_coach_dettes_hypotheque'),
        findsOneWidget);
  });

  testWidgets(
      'computes from user-provided profile facts without duplicating them',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'self_employed',
      'q_children': 2,
      'q_housing_status': 'owner',
      '_coach_dettes_hypotheque': 500000,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coverage_ledger_facts')), findsOneWidget);
    expect(
        find.byKey(const Key('coverage_missing_profile_facts')), findsNothing);
    expect(find.byKey(const Key('coverage_result_section')), findsOneWidget);
    expect(find.text('VD'), findsOneWidget);
    expect(find.text('Indépendant·e'), findsOneWidget);
    expect(
      find.descendant(
        of: _rowForText('Personnes à charge'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: _rowForText('IJM collective (employeur)'),
              matching: find.byType(Switch),
            ),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: _rowForText('LAA (assurance accident)'),
              matching: find.byType(Switch),
            ),
          )
          .value,
      isFalse,
    );
    expect(
      find.descendant(
        of: _rowForText('Hypothèque en cours'),
        matching: find.byType(Switch),
      ),
      findsNothing,
    );
  });

  testWidgets('owner with explicit zero mortgage balance is complete',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'independant',
      'q_children': 0,
      'q_housing_status': 'owner',
      '_coach_dettes_hypotheque': 0,
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coverage_ledger_facts')), findsOneWidget);
    expect(
        find.byKey(const Key('coverage_missing_profile_facts')), findsNothing);
    expect(find.byKey(const Key('coverage_result_section')), findsOneWidget);
    expect(
      find.descendant(
        of: _rowForText('Hypothèque en cours'),
        matching: find.text('CHF\u00a00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps non-working statuses displayable and computable',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'retired',
      'q_children': 0,
      'q_housing_status': 'renter',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('coverage_missing_profile_facts')), findsNothing);
    expect(find.byKey(const Key('coverage_result_section')), findsOneWidget);
    expect(find.text('Retraité·e'), findsOneWidget);
    expect(find.text('retraite'), findsNothing);
  });

  testWidgets('family housing is a complete non-mortgage coverage fact',
      (tester) async {
    _setReliableViewport(tester);
    final provider = _RecordingCoachProfileProvider(const {
      'q_canton': 'VD',
      'q_employment_status': 'independant',
      'q_children': 0,
      'q_housing_status': 'family',
    });

    await tester.pumpWidget(_buildWithRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coverage_ledger_facts')), findsOneWidget);
    expect(
        find.byKey(const Key('coverage_missing_profile_facts')), findsNothing);
    expect(find.byKey(const Key('coverage_result_section')), findsOneWidget);
    expect(find.text('Chez famille/parents'), findsOneWidget);
  });
}
