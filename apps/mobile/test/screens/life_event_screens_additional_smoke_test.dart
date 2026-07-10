// ────────────────────────────────────────────────────────────
//  LIFE EVENT SCREENS (additional) — Smoke Tests
//  Screens: DivorceSimulatorScreen, FrontalierScreen,
//           ExpatScreen, UnemploymentScreen, FirstJobScreen,
//           DemenagementCantonalScreen, DecesProcheScreen
//
//  Validates: renders without crash, Scaffold present,
//  French content visible on first pump.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/demenagement_cantonal_screen.dart';
import 'package:mint_mobile/screens/deces_proche_screen.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';

// ---------------------------------------------------------------------------
//  Shared helpers
// ---------------------------------------------------------------------------

/// Wraps screen with Provider + French i18n (for screens that read a profile).
Widget _buildWrappedWithProvider(
  Widget screen, {
  CoachProfileProvider? provider,
}) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => provider ?? CoachProfileProvider(),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: screen,
    ),
  );
}

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

Widget _buildUnemploymentRouter(CoachProfileProvider provider) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ChangeNotifierProvider<CoachProfileProvider>.value(
          value: provider,
          child: const UnemploymentScreen(),
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

/// Wraps screen with French i18n only (no provider needed).
Widget _buildWrapped(Widget screen) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: screen,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  1. DivorceSimulatorScreen — complex financial simulation
  // ═══════════════════════════════════════════════════════════

  group('DivorceSimulatorScreen', () {
    Widget buildScreen() => _buildWrapped(const DivorceSimulatorScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: divorceAppBarTitle = "Divorce — Impact financier"
      expect(find.textContaining('ivorce'), findsWidgets);
    });

    testWidgets('shows situation familiale section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: divorceSituationFamiliale or divorceHeaderTitle contains "Divorce"
      // Section 1: durée du mariage
      expect(find.textContaining('mariage'), findsWidgets);
    });

    testWidgets('shows revenus section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: divorceRevenus = "REVENUS" or label "Conjoint 1"
      expect(find.textContaining('evenu'), findsWidgets);
    });

    testWidgets('shows prevoyance section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: divorcePrevoyance = "PRÉVOYANCE"
      expect(find.textContaining('évoyance'), findsWidgets);
    });

    testWidgets('shows simulate button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: divorceSimuler = "Simuler"
      expect(find.textContaining('imuler'), findsWidgets);
    });

    testWidgets('tapping simuler shows results without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Scroll to and tap Simuler button
      await tester.scrollUntilVisible(
        find.textContaining('imuler'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('imuler'));
      await tester.pumpAndSettle();
      // Results section appears
      // i18n: divorcePartageLpp = "PARTAGE LPP"
      expect(find.textContaining('LPP', skipOffstage: false), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. FrontalierScreen — 3-tab cross-border worker screen
  // ═══════════════════════════════════════════════════════════

  group('FrontalierScreen', () {
    Widget buildScreen() => _buildWrapped(const FrontalierScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: frontalierAppBarTitle = "Frontalier"
      expect(find.textContaining('rontalier'), findsWidgets);
    });

    testWidgets('shows all 3 tab labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: frontalierTabImpots, frontalierTab90Jours, frontalierTabCharges
      expect(find.text('Impôts'), findsOneWidget);
      expect(find.text('90 jours'), findsOneWidget);
      expect(find.text('Charges'), findsOneWidget);
    });

    testWidgets('Tab 1 (Impots) shows canton selector', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.textContaining('Canton'), findsWidgets);
    });

    testWidgets('Tab 2 (90 jours) renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.tap(find.text('90 jours'));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Tab 3 (Charges) renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.tap(find.text('Charges'));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. ExpatScreen — 3-tab expatriation planning screen
  // ═══════════════════════════════════════════════════════════

  group('ExpatScreen', () {
    Widget buildScreen() => _buildWrappedWithProvider(const ExpatScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: expatTitle = "Expatriation"
      expect(find.textContaining('xpatriation'), findsWidgets);
    });

    testWidgets('shows all 3 tab labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: expatTabForfait = "Forfait", expatTabDeparture = "Départ", expatTabAvs = "AVS"
      expect(find.text('Forfait'), findsOneWidget);
      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('AVS'), findsOneWidget);
    });

    testWidgets('Tab 1 (Forfait) shows fiscal content', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: expatForfaitFiscal = "Forfait fiscal"
      expect(find.textContaining('orfait'), findsWidgets);
    });

    testWidgets('Tab 2 (Depart) renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.tap(find.text('Départ'));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Tab 3 (AVS) renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.tap(find.text('AVS'));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  4. UnemploymentScreen — LACI benefits calculator
  // ═══════════════════════════════════════════════════════════

  group('UnemploymentScreen', () {
    Widget buildScreen() =>
        _buildWrappedWithProvider(const UnemploymentScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: unemploymentTitle = "Perte d'emploi"
      expect(find.textContaining("emploi"), findsWidgets);
    });

    testWidgets('shows missing ledger facts instead of local salary editor',
        (tester) async {
      final provider = RecordingCoachProfileProvider({});
      await tester.pumpWidget(_buildUnemploymentRouter(provider));
      await tester.pump();

      expect(
          find.byKey(const Key('unemployment_ledger_facts')), findsOneWidget);
      expect(find.text('Données manquantes'), findsOneWidget);
      expect(find.byType(MintAmountField), findsNothing);

      await tester
          .tap(find.byKey(const Key('unemployment_enrich_profile_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text('data-block:revenu:q_gross_salary_annual'),
        findsOneWidget,
      );
    });

    testWidgets('routes to birth year collection when salary is known',
        (tester) async {
      final provider = RecordingCoachProfileProvider({
        'q_gross_salary_annual': 96000,
      });
      await tester.pumpWidget(_buildUnemploymentRouter(provider));
      await tester.pump();

      await tester
          .tap(find.byKey(const Key('unemployment_enrich_profile_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text('data-block:revenu:q_birth_year'),
        findsOneWidget,
      );
    });

    testWidgets('routes to household composition when salary and age are known',
        (tester) async {
      final currentYear = DateTime.now().year;
      final provider = RecordingCoachProfileProvider({
        'q_gross_salary_annual': 96000,
        'q_birth_year': currentYear - 42,
      });
      await tester.pumpWidget(_buildUnemploymentRouter(provider));
      await tester.pump();

      await tester
          .tap(find.byKey(const Key('unemployment_enrich_profile_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text('data-block:compositionMenage:q_children'),
        findsOneWidget,
      );
    });

    testWidgets('uses salary and age from ledger facts', (tester) async {
      final currentYear = DateTime.now().year;
      final provider = RecordingCoachProfileProvider({
        'q_gross_salary_annual': 96000,
        'q_birth_year': currentYear - 42,
        'q_children': 0,
      });
      await tester.pumpWidget(_buildUnemploymentRouter(provider));
      await tester.pump();

      expect(
          find.byKey(const Key('unemployment_ledger_facts')), findsOneWidget);
      expect(find.text('Données connues'), findsOneWidget);
      expect(find.textContaining("8'000"), findsWidgets);
      expect(find.textContaining('42 ans'), findsWidgets);
      expect(
          find.byKey(const Key('unemployment_children_fact')), findsOneWidget);
      expect(find.byType(MintAmountField), findsNothing);
      expect(find.byType(MintPickerTile), findsOneWidget);
      expect(
        find.byKey(const Key('unemployment_confirm_contribution_months_cta')),
        findsOneWidget,
      );
      expect(find.byType(UnemploymentCounterWidget), findsNothing);

      final confirmContribution = find.byKey(
        const Key('unemployment_confirm_contribution_months_cta'),
      );
      await tester.ensureVisible(confirmContribution);
      await tester.tap(confirmContribution);
      await tester.pumpAndSettle();

      expect(find.byType(UnemploymentCounterWidget), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  5. FirstJobScreen — premier emploi salary analyzer
  // ═══════════════════════════════════════════════════════════

  group('FirstJobScreen', () {
    Widget buildScreen({CoachProfileProvider? provider}) =>
        _buildWrappedWithProvider(
          const FirstJobScreen(),
          provider: provider,
        );

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: firstJobTitle = "Premier emploi"
      expect(find.textContaining('emploi'), findsWidgets);
    });

    testWidgets('shows missing ledger facts instead of local defaults',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byKey(const Key('first_job_ledger_facts')), findsOneWidget);
      expect(find.byKey(const Key('first_job_salary_fact')), findsOneWidget);
      expect(find.byKey(const Key('first_job_age_fact')), findsOneWidget);
      expect(find.byKey(const Key('first_job_canton_fact')), findsOneWidget);
      expect(find.text('Manquant'), findsNWidgets(3));
      expect(find.byType(MintPremiumSlider), findsNothing);
      expect(find.byKey(const Key('first_job_result_cards')), findsNothing);
      expect(find.textContaining("5'000"), findsNothing);
    });

    testWidgets('uses salary age and canton from ledger facts', (tester) async {
      final currentYear = DateTime.now().year;
      await tester.pumpWidget(buildScreen(
        provider: RecordingCoachProfileProvider({
          'q_gross_salary_annual': 90000,
          'q_birth_year': currentYear - 25,
          'q_canton': 'VD',
        }),
      ));
      await tester.pump();

      expect(find.byKey(const Key('first_job_ledger_facts')), findsOneWidget);
      expect(find.textContaining("7'500"), findsWidgets);
      expect(find.text('25 ans'), findsWidgets);
      expect(find.text('VD'), findsWidgets);
      expect(
        find.byKey(
          const Key('first_job_result_cards'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byType(MintPremiumSlider, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.textContaining("5'000"), findsNothing);
    });

    testWidgets('keeps selected salary scenario after provider notify',
        (tester) async {
      final currentYear = DateTime.now().year;
      final provider = RecordingCoachProfileProvider({
        'q_gross_salary_annual': 90000,
        'q_birth_year': currentYear - 25,
        'q_canton': 'VD',
      });
      final medianResult = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6500,
        age: 25,
        canton: 'VD',
      );
      final medianEmployerCost =
          FirstJobService.formatChf(medianResult.cotisationsEmployeur);

      await tester.pumpWidget(buildScreen(provider: provider));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Médian CH'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Médian CH'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('first_job_result_cards')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(medianEmployerCost), findsOneWidget);

      await provider.mergeAnswers({'q_unrelated_notify': true});
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('first_job_result_cards')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(medianEmployerCost), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  6. DemenagementCantonalScreen — cantonal move impact
  // ═══════════════════════════════════════════════════════════

  group('DemenagementCantonalScreen', () {
    Widget buildScreen() => _buildWrapped(const DemenagementCantonalScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: demenagementTitre = "Déménagement cantonal"
      expect(find.textContaining('ménagement'), findsWidgets);
    });

    testWidgets('shows canton departure selector', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: demenagementCantonDepart = "Canton actuel"
      expect(find.textContaining('actuel'), findsWidgets);
    });

    testWidgets('shows economy CHF hero number', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Hero displays CHF delta (positive or negative)
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows checklist section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pump();
      // i18n: demenagementChecklistTitre = "Checklist déménagement"
      expect(
          find.textContaining('hecklist', skipOffstage: false), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pump();
      // i18n: demenagementDisclaimer contains "ne constitue pas"
      expect(
        find.textContaining('constitue pas', skipOffstage: false),
        findsWidgets,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  7. DecesProcheScreen — death of relative financial guide
  // ═══════════════════════════════════════════════════════════

  group('DecesProcheScreen', () {
    Widget buildScreen() => _buildWrapped(const DecesProcheScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: decesProcheTitre = "Décès d'un proche"
      expect(find.textContaining('proche'), findsWidgets);
    });

    testWidgets('shows premier éclairage hero', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Hero shows CHF amount
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('shows input section with lien parenté', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: decesProcheLienParente = "Lien avec le défunt"
      // Section label appears before the SegmentedButton choices
      expect(find.textContaining('défunt'), findsWidgets);
    });

    testWidgets('shows succession timeline after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump();
      // Timeline shows days/steps
      expect(find.textContaining('mois', skipOffstage: false), findsWidgets);
    });
  });
}
