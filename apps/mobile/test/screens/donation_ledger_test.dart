import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget _buildDonationRouter(CoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/life-event/donation',
    routes: [
      GoRoute(
        path: '/life-event/donation',
        builder: (_, __) => const DonationScreen(),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) => Scaffold(
          body: Text(
            'data-block ${state.pathParameters['type']} ${state.uri.queryParameters['inputKey']}',
            key: const Key('data_block_stub'),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('blocks calculation when ledger facts are missing',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(const {});

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_ledger_facts')), findsOneWidget);
    expect(find.byKey(const Key('donation_age_fact')), findsOneWidget);
    expect(find.byKey(const Key('donation_canton_fact')), findsOneWidget);
    expect(find.byKey(const Key('donation_children_fact')), findsOneWidget);
    expect(find.byKey(const Key('donation_wealth_fact')), findsOneWidget);
    expect(find.text('Manquant', skipOffstage: false), findsWidgets);

    expect(find.text('55 ans', skipOffstage: false), findsNothing);
    expect(find.textContaining("800'000", skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('donation_result_cards')), findsNothing);
  });

  testWidgets('routes missing wealth fact to the patrimoine DataBlock',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const Key('donation_wealth_missing_cta')));
    await tester.tap(find.byKey(const Key('donation_wealth_missing_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_stub')), findsOneWidget);
    expect(find.textContaining('patrimoine q_wealth_estimate'), findsOneWidget);
  });

  testWidgets('routes missing household facts to the household DataBlock',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_wealth_estimate': 1250000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const Key('donation_children_missing_cta')));
    await tester.tap(find.byKey(const Key('donation_children_missing_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_stub')), findsOneWidget);
    expect(
      find.textContaining('composition_menage q_children'),
      findsOneWidget,
    );
  });

  testWidgets('uses ledger facts to unlock the donation calculation',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 1250000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.text('62 ans', skipOffstage: false), findsWidgets);
    expect(find.text('GE', skipOffstage: false), findsWidgets);
    expect(
      find.text('Assiette successorale nette estimée', skipOffstage: false),
      findsWidgets,
    );
    expect(find.textContaining("1'250'000", skipOffstage: false), findsWidgets);
    expect(find.text('Manquant', skipOffstage: false), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsOneWidget);
    expect(find.text('IMPÔT SUR LA DONATION', skipOffstage: false),
        findsOneWidget);
    expect(
      find.text('Estimé — à confirmer', skipOffstage: false),
      findsWidgets,
    );
    expect(find.textContaining('GE', skipOffstage: false), findsWidgets);
  });

  testWidgets('uses net estate details when they exceed the broad estimate',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 500000,
      'q_property_market_value': 900000,
      '_coach_dettes_hypotheque': 100000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.textContaining("800'000", skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('Estimation et détails patrimoniaux divergent',
          skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining("900'000", skipOffstage: false), findsNothing);
    expect(find.textContaining("500'000", skipOffstage: false), findsNothing);
  });

  testWidgets('uses detailed net estate facts without a broad estimate',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_cash_total': 200000,
      'q_investments_total': 300000,
      'q_property_market_value': 900000,
      '_coach_dettes_hypotheque': 100000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.textContaining("1'300'000", skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('Base partielle', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const Key('donation_wealth_missing_cta')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsOneWidget);
  });

  testWidgets('does not use emergency-fund heuristics as estate cash',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_emergency_fund': 'yes_6months',
      'q_housing_cost_period_chf': 2000,
      'q_lamal_premium_monthly_chf': 500,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('donation_wealth_missing_cta')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Base reconstruite', skipOffstage: false),
      findsNothing,
    );

    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsNothing);
  });

  testWidgets('marks a single-asset detailed estate base as partial',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'celibataire',
      'q_cash_total': 100000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.textContaining("100'000", skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('Base partielle', skipOffstage: false),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsOneWidget);
    expect(
      find.textContaining('dépassement possible', skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('actifs actuellement connus', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Dépassement de', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('includes user-provided investments in the net estate base',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 500000,
      'q_property_market_value': 900000,
      '_coach_dettes_hypotheque': 100000,
      'q_investments_total': 300000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.textContaining("1'100'000", skipOffstage: false), findsWidgets);
  });

  testWidgets('does not let gross property override wealth without mortgage',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 500000,
      'q_property_market_value': 900000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    expect(find.textContaining("500'000", skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('hypothèque manquante', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('donation_wealth_fact')),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
    await tester
        .ensureVisible(find.byKey(const Key('donation_estate_mortgage_cta')));
    await tester.tap(find.byKey(const Key('donation_estate_mortgage_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_stub')), findsOneWidget);
    expect(
      find.textContaining('patrimoine _coach_dettes_hypotheque'),
      findsOneWidget,
    );
    expect(find.textContaining("900'000", skipOffstage: false), findsNothing);
  });

  testWidgets('non-exempt relationship shows tax confirmation state',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'GE',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 1250000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tiers'));
    await tester.tap(find.text('Tiers'));
    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsOneWidget);
    expect(
        find.text('Estimé — à confirmer', skipOffstage: false), findsWidgets);
    expect(find.textContaining('30%', skipOffstage: false), findsNothing);
  });

  testWidgets('descendant gift shows tax confirmation state', (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'LU',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 1250000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('donation_simulate_cta')));
    await tester.tap(find.byKey(const Key('donation_simulate_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('donation_result_cards')), findsOneWidget);
    expect(
        find.text('Estimé — à confirmer', skipOffstage: false), findsWidgets);
    expect(find.text('Exonérée', skipOffstage: false), findsNothing);
  });

  testWidgets('property scenario asks for property value from the ledger',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'VD',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 1250000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Immobilier'));
    await tester.tap(find.text('Immobilier'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('donation_property_missing_cta')));
    await tester.tap(find.byKey(const Key('donation_property_missing_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_stub')), findsOneWidget);
    expect(
      find.textContaining('patrimoine q_property_market_value'),
      findsOneWidget,
    );
  });

  testWidgets('property scenario asks for mortgage balance from the ledger',
      (tester) async {
    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 62,
      'q_canton': 'VD',
      'q_children': 2,
      'q_civil_status': 'marie',
      'q_wealth_estimate': 1250000,
      'q_property_market_value': 900000,
    });

    await tester.pumpWidget(_buildDonationRouter(provider));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Immobilier'));
    await tester.tap(find.text('Immobilier'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('donation_mortgage_missing_cta')));
    await tester.tap(find.byKey(const Key('donation_mortgage_missing_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data_block_stub')), findsOneWidget);
    expect(
      find.textContaining('patrimoine _coach_dettes_hypotheque'),
      findsOneWidget,
    );
  });
}
