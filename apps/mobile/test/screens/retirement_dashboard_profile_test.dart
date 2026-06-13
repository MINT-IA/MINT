import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────
//  RETIREMENT DASHBOARD — D7 (même source que /home) + D8 (CTA vivant)
//
//  D7: /retraite lit le MÊME CoachProfileProvider que /home. L'état vide
//      (« 4 infos suffisent ») ne doit PAS apparaître quand un profil est
//      hydraté (avoir LPP visible sur /home dans la même minute). Il ne
//      s'affiche que si le profil est RÉELLEMENT vide.
//  D8: le CTA de l'état vide (« Commencer — 2 min ») mène à un parcours
//      qui pose réellement des questions (route /onb avec champs de saisie),
//      plus jamais vers le home coach sans formulaire.
// ─────────────────────────────────────────────────────────────────────

/// Wizard answers for a fully hydrated salaried profile with an LPP avoir.
/// Mirrors the data /home reads to render « 43'691 Avoir LPP ».
Map<String, dynamic> _hydratedAnswers() => {
      'q_birth_year': 1983,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6500.0,
      'q_pay_frequency': 'monthly',
      'q_gross_salary_annual': 102000.0,
      'q_employment_status': 'salarie',
      'q_household_type': 'single',
      'q_has_pension_fund': true,
      '_coach_avoir_lpp': 43691.0,
      'q_target_retirement_age': 65,
    };

const _localizations = [
  S.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _buildHarness({
  required CoachProfileProvider coachProvider,
  GoRouter? router,
}) {
  final app = router != null
      ? MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: _localizations,
          supportedLocales: S.supportedLocales,
          routerConfig: router,
        )
      : const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: _localizations,
          supportedLocales: S.supportedLocales,
          home: RetirementDashboardScreen(),
        );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
      ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
      ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
    ],
    child: app,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      secureStorageChannel,
      (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              secureStorage[key] = value;
            }
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key != null) {
              secureStorage.remove(key);
            }
            return null;
          case 'deleteAll':
            secureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('D7 — même source que /home', () {
    testWidgets(
        'profil hydraté (avoir LPP) → PAS d\'état vide « 4 infos suffisent »',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider()
        ..updateFromAnswers(_hydratedAnswers());
      expect(provider.hasProfile, isTrue,
          reason: 'le profil doit être hydraté (même source que /home)');

      await tester.pumpWidget(_buildHarness(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));

      // RetirementHeroZone has a fixed-width Row that overflows in the test
      // viewport (pre-existing harness limitation, cf. retirement_dashboard_test
      // .dart note). The overflow proves the DASHBOARD rendered, not State C —
      // which is exactly what D7 asserts. Drain the layout exception so the
      // text assertions below can run.
      tester.takeException();

      final l = S.of(tester.element(find.byType(RetirementDashboardScreen)))!;
      // L'état vide d'onboarding (« 4 infos suffisent… ») ne doit PAS être rendu
      // pour un profil hydraté : ce serait la contradiction D7 avec /home.
      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason:
              'D7: profil hydraté ne doit jamais afficher l\'état vide onboarding');
      expect(find.byKey(const Key('state_c_start_cta')), findsNothing,
          reason: 'D7: le CTA d\'état vide ne doit pas apparaître avec profil');
    });

    testWidgets('profil RÉELLEMENT vide → état vide affiché', (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider(); // no profile
      expect(provider.hasProfile, isFalse);

      await tester.pumpWidget(_buildHarness(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));

      final l = S.of(tester.element(find.byType(RetirementDashboardScreen)))!;
      expect(find.text(l.dashboardQuickStartBody), findsOneWidget,
          reason: 'profil vide → l\'état vide onboarding est légitime');
      expect(find.byKey(const Key('state_c_start_cta')), findsOneWidget);
    });

    // D7 DEVICE regression (FAIL #2): the device scenario is NOT a profile
    // hydrated BEFORE first pump — it is a profile that hydrates AFTER the
    // dashboard is already mounted (arriving from onboarding, the flush →
    // notifyListeners lands after /retraite is on screen). The dashboard MUST
    // leave State C and render data once the SAME provider it watches notifies.
    // Mirrors the FATCA-gate post-pump hydration pattern.
    testWidgets(
        'D7 device — profil hydraté APRÈS le premier pump → quitte l\'état vide',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1) Provider empty at mount → dashboard renders State C legitimately.
      final provider = CoachProfileProvider();
      expect(provider.hasProfile, isFalse);

      await tester.pumpWidget(_buildHarness(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));

      final l = S.of(tester.element(find.byType(RetirementDashboardScreen)))!;
      expect(find.text(l.dashboardQuickStartBody), findsOneWidget,
          reason: 'pré-hydratation : State C est légitime tant que vide');

      // 2) Onboarding flush lands: same provider hydrates + notifies, AFTER the
      //    dashboard is already on screen (the exact device order).
      provider.updateFromAnswers(_hydratedAnswers());
      expect(provider.hasProfile, isTrue,
          reason: 'post-flush : le profil est hydraté (même source que /home)');

      await tester.pump(); // process notifyListeners
      await tester.pump(const Duration(seconds: 1));
      tester.takeException(); // dashboard hero overflow proves it rendered

      // 3) State C must be GONE — the dashboard now reads the hydrated profile,
      //    exactly like /home. Device illogism : « 4 infos suffisent » persisted.
      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason: 'D7 device : profil hydraté après mount ne doit plus '
              'afficher « 4 infos suffisent »');
      expect(find.byKey(const Key('state_c_start_cta')), findsNothing,
          reason:
              'D7 device : le CTA d\'état vide doit disparaître post-flush');
    });

    // D7 device ROOT-CAUSE (FAIL #2): /retraite is a top-level route reachable
    // before the shared CoachProfileProvider has run loadFromWizard() in this
    // session. While hydration is still in flight (isLoading / isHydrating) the
    // provider's in-memory _profile is null. Pre-fix the dashboard rendered
    // State C immediately (« 4 infos suffisent ») against a provider that is
    // merely still loading — the device illogism (a profile /home renders, but
    // /retraite, reached a beat earlier, shows the empty onboarding state). The
    // dashboard MUST show a loading state — NOT State C — while the SAME
    // provider it watches is hydrating.
    testWidgets(
        'D7 device — provider en cours d\'hydratation → état chargement, '
        'PAS « 4 infos suffisent »', (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Provider is hydrating (loadFromWizard in flight): _profile still null
      // but isHydrating true — the exact "arrived before hydration" race.
      final provider = CoachProfileProvider()..startHydrating();
      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isTrue);

      await tester.pumpWidget(_buildHarness(coachProvider: provider));
      await tester.pump();

      final l = S.of(tester.element(find.byType(RetirementDashboardScreen)))!;
      // The empty onboarding state must NOT show while hydration is pending —
      // that is the D7 device illogism. A loading indicator is shown instead.
      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason: 'D7 device : pas d\'« 4 infos suffisent » pendant '
              'l\'hydratation (le profil /home arrive juste après)');
      expect(find.byKey(const Key('state_c_start_cta')), findsNothing);
      expect(find.byKey(const Key('retirement_dashboard_hydrating')),
          findsOneWidget,
          reason: 'un état chargement récupérable est rendu, pas l\'état vide');

      // Once hydration completes WITH a profile, the dashboard leaves the
      // loading state and never falls back to State C.
      provider.updateFromAnswers(_hydratedAnswers());
      provider.finishHydrating();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();

      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason: 'profil hydraté → jamais l\'état vide onboarding');
    });

    // D7 device ROOT-CAUSE (FAIL #2, device-probe-confirmed 2026-06-12): the
    // dashboard first builds with hasProfile=true, then a LATER build flips to
    // hasProfile=false with isLoaded=true / isHydrating=false / isLoading=false
    // — the shared provider's profile is CLEARED out from under the mounted
    // screen (a settled clear, e.g. a release-mode loadFromWizard that finds no
    // disk answers). Pre-fix this regressed /retraite to « 4 infos suffisent »
    // even though it had just rendered the projection. A profile that existed
    // must NOT collapse into the onboarding empty state while the screen is open.
    testWidgets(
        'D7 device — profil effacé APRÈS rendu (clear settled) → '
        'jamais « 4 infos suffisent »', (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1) Hydrated at mount → dashboard renders (no State C).
      final provider = CoachProfileProvider()
        ..updateFromAnswers(_hydratedAnswers());
      expect(provider.hasProfile, isTrue);

      await tester.pumpWidget(_buildHarness(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();

      final l = S.of(tester.element(find.byType(RetirementDashboardScreen)))!;
      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason: 'profil hydraté → dashboard, pas State C');

      // 2) Provider profile is CLEARED while the screen is open (settled clear:
      //    not hydrating, not loading). The device-proven illogism.
      await provider.clearAll();
      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isFalse);
      expect(provider.isLoading, isFalse);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();

      // 3) State C must NOT appear — the screen already had a profile.
      expect(find.text(l.dashboardQuickStartBody), findsNothing,
          reason: 'D7 device : un profil déjà rendu ne doit jamais régresser '
              'vers « 4 infos suffisent » sur un clear transitoire');
      expect(find.byKey(const Key('state_c_start_cta')), findsNothing);
    });
  });

  group('D8 — CTA vivant vers un parcours qui pose des questions', () {
    testWidgets('tap CTA état vide → route /onb (formulaire avec champ)',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider(); // empty → State C

      final router = GoRouter(
        initialLocation: '/retraite',
        routes: [
          GoRoute(
            path: '/retraite',
            builder: (_, __) => const RetirementDashboardScreen(),
          ),
          // Stub du parcours réel : un écran qui POSE une question (champ).
          GoRoute(
            path: '/onb',
            builder: (_, __) => const Scaffold(
              body: Column(
                children: [
                  Text('Question onboarding'),
                  TextField(key: Key('onb_input_field')),
                ],
              ),
            ),
          ),
          // Cible MORTE historique (D8) : home coach sans formulaire.
          GoRoute(
            path: '/coach/chat',
            builder: (_, __) => const Scaffold(
              body: Text('Home coach — aucun formulaire'),
            ),
          ),
        ],
      );

      await tester
          .pumpWidget(_buildHarness(coachProvider: provider, router: router));
      await tester.pump(const Duration(seconds: 1));

      final cta = find.byKey(const Key('state_c_start_cta'));
      expect(cta, findsOneWidget, reason: 'le CTA d\'état vide doit exister');

      await tester.tap(cta);
      await tester.pumpAndSettle();

      // D8 fermé : le CTA mène à un écran qui POSE une question (champ de saisie),
      // pas au home coach sans formulaire.
      expect(find.byKey(const Key('onb_input_field')), findsOneWidget,
          reason:
              'D8: le CTA doit mener à un parcours avec un champ de saisie réel');
      expect(find.text('Home coach — aucun formulaire'), findsNothing,
          reason: 'D8: le CTA ne doit plus pointer vers le home coach mort');
    });
  });
}
