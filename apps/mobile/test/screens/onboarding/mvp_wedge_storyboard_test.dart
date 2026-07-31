/// Integration test du storyboard onboarding v2
/// (locked 2026-04-22, T9 email-demain killed 2026-04-24).
///
/// Vérifie les 3 flows intents (retraite / achat / impots) tour par
/// tour, de T1 (landing) à T8 (bifurcation), avec assertion sur la
/// densification du dossier à chaque tour et le flush vers
/// CoachProfileProvider au tour 8 (déclenché par Continuer, compte ou Sortir).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/app.dart' show accountLifecycleAndArchetypeRedirect;
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/income_converter.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  final List<Map<String, dynamic>> mergedCalls = [];
  final List<Map<String, dynamic>> updateCalls = [];
  bool throwOnMerge = false;
  bool leaveProfileEmptyAfterMerge = false;
  CoachProfile? _fakeProfile;

  @override
  CoachProfile? get profile => _fakeProfile;

  @override
  bool get hasProfile => _fakeProfile != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    // Sub-phase 01.5 W02-T03: the us-tax-person hard-gate writes
    // {'q_us_tax_person': bool} via the same mergeAnswers entry-point.
    // It is NOT the T8 dossier flush — exclude it from throw + log,
    // so the existing throwOnMerge tests still target the flush.
    //
    // W2 (mint-illogism-fixes-06): the archetype-truth scenes (statut
    // d'emploi / état civil / lacunes AVS) write their q_* key in-flow the
    // same way and are ALSO mirrored onto the OnboardingProvider so the T8
    // flush re-emits them. Like the us-tax gate, these in-flow writes are
    // not the dossier flush — exclude them so `mergedCalls.single` keeps
    // targeting the single authoritative T8 flush write.
    const inFlowGateKeys = <String>{
      'q_us_tax_person',
      'q_employment_status',
      'q_civil_status',
      'q_avs_lacunes_status',
    };
    final isInFlowGateWrite =
        partial.keys.every((k) => inFlowGateKeys.contains(k));
    if (isInFlowGateWrite) {
      // Gate writes succeed unconditionally — they are not the
      // failure-under-test for the T8 SnackBar story.
      return;
    }
    if (throwOnMerge) {
      throw StateError('test: mergeAnswers failed');
    }
    mergedCalls.add(Map<String, dynamic>.from(partial));
    if (!leaveProfileEmptyAfterMerge) {
      _fakeProfile = CoachProfile.fromWizardAnswers(partial);
    }
  }

  @override
  void updateFromAnswers(Map<String, dynamic> answers) {
    // Mirrors the production invariant used by the secure-store fallback:
    // updateFromAnswers seeds the current session only and must stay
    // persistence-free.
    updateCalls.add(Map<String, dynamic>.from(answers));
    _fakeProfile = CoachProfile.fromWizardAnswers(answers);
  }

  @override
  Future<void> loadFromWizard() async {}
}

class _TrackingAuthProvider extends AuthProvider {
  _TrackingAuthProvider({this.forceLoggedIn = false});

  /// Lets a widget test drive the account seal branch of `_sealAndGo`
  /// without standing up a real JWT session. `_sealAndGo` decides between
  /// `markAccountProfileAvailable()` and `enableLocalMode()` on
  /// `auth.isLoggedIn`, so overriding that getter is enough to exercise
  /// each branch.
  final bool forceLoggedIn;

  int profileAvailableCalls = 0;
  int localModeCalls = 0;

  @override
  bool get isLoggedIn => forceLoggedIn || super.isLoggedIn;

  @override
  void markAccountProfileAvailable() {
    profileAvailableCalls += 1;
    super.markAccountProfileAvailable();
  }

  @override
  Future<void> enableLocalMode() async {
    localModeCalls += 1;
    await super.enableLocalMode();
  }
}

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void _mockSecureStorageUnavailableOnWrite() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    if (call.method == 'write') {
      throw PlatformException(
        code: '-34018',
        message: 'errSecMissingEntitlement',
      );
    }
    return null;
  });
}

Future<void> _pumpShell(
  WidgetTester tester,
  _FakeCoachProfileProvider fake, {
  AuthProvider? authProvider,
  bool useRealRvcRoute = false,
}) async {
  final router = GoRouter(
    initialLocation: '/onb',
    routes: [
      GoRoute(
        path: '/onb',
        builder: (_, __) => const OnboardingShellScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home-landed')),
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, state) => Scaffold(
          body: Text(
            'coach-chat-landed:${state.uri.queryParameters['topic'] ?? ''}',
          ),
        ),
      ),
      GoRoute(
        path: '/retraite/rente-vs-capital',
        builder: (_, __) => useRealRvcRoute
            ? const RenteVsCapitalScreen()
            : const Scaffold(body: Text('rente-vs-capital-landed')),
      ),
      GoRoute(
        path: '/hypotheque',
        builder: (_, __) => const Scaffold(body: Text('hypotheque-landed')),
      ),
      GoRoute(
        path: '/pilier-3a',
        builder: (_, __) => const Scaffold(body: Text('pilier-3a-landed')),
      ),
      GoRoute(
        path: '/explore',
        builder: (_, __) => const Scaffold(body: Text('explore-landed')),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const Scaffold(body: Text('register-landed')),
      ),
      GoRoute(
        path: '/waitlist',
        builder: (_, state) => Scaffold(
          body: Text(
            'waitlist-landed:${state.extra}',
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: fake),
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider ?? AuthProvider(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _commonEntry(
  WidgetTester tester, {
  required Key intentKey,
}) async {
  // T1 → T2
  await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
  await tester.pumpAndSettle();
  expect(
    find.text('Qu’est-ce que tu veux éclairer d’abord\u00a0?'),
    findsOneWidget,
  );

  // T2 → T2.5 (tap intent card)
  // Sub-phase 01.5 W02-T03 inserted a us-tax-person gate between
  // intents and age (Security §4 nLPD art. 6 pre-financial-data).
  expect(
      find.byKey(const ValueKey('onboarding-intent-retraite')), findsOneWidget);
  expect(find.byKey(const ValueKey('onboarding-intent-achat')), findsOneWidget);
  expect(
      find.byKey(const ValueKey('onboarding-intent-impots')), findsOneWidget);
  expect(
      find.byKey(const ValueKey('onboarding-intent-explorer')), findsOneWidget);
  await tester.tap(find.byKey(intentKey));
  await tester.pumpAndSettle();
  expect(
    find.text('Es-tu citoyen ou résident fiscal aux États-Unis ?'),
    findsOneWidget,
  );

  // T2.5 → T2.6 : tap "Non" (storyboard tests default to non-US users so
  // they reach the financial-data steps; gate semantics are covered in
  // coach_route_archetype_guard_test.dart).
  await tester.tap(find.byKey(const ValueKey('us-tax-person-no')));
  await tester.pumpAndSettle();

  // T2.6 → T3 : nationality step (SALVAGE-01). Storyboard tests select
  // Suisse so the freshly-onboarded profile resolves to swissNative and
  // the coach is reachable; cross-border/expat archetypes are covered in
  // coach_route_archetype_guard_test.dart.
  expect(find.text('Quelle est ta nationalité ?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('onboarding-nationality-ch')));
  await tester.pumpAndSettle();

  // T2.7-T2.9 → W2 (mint-illogism-fixes-06) archetype-truth steps, inserted
  // between nationality and age. Storyboard tests pick the swissNative
  // baseline (salarié / marié / pas de lacunes AVS) so the resolved
  // archetype stays swissNative and the coach remains reachable. Archetype
  // variants (independant / divorce / lived_abroad) are covered in
  // mint_scene_*_test.dart + onboarding_archetype_flow_test.dart.
  expect(
      find.text('Quelle est ta situation professionnelle ?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('onboarding-employment-salarie')));
  await tester.pumpAndSettle();

  expect(find.text('Quelle est ta situation familiale ?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('onboarding-civil-marie')));
  await tester.pumpAndSettle();

  expect(find.text('As-tu passé des années hors de Suisse ?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('onboarding-avs-no-gaps')));
  await tester.pumpAndSettle();

  expect(find.text('Quelle est ta date de naissance ?'), findsOneWidget);
}

Future<void> _selectExplicitDateOfBirth(WidgetTester tester) async {
  await tester.tap(find.text('Choisir ma date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('15').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
}

Future<void> _tapCanton(WidgetTester tester, String code) async {
  final cantonFinder = find.byKey(
    ValueKey('onboarding-canton-${code.toLowerCase()}'),
  );
  await tester.tap(cantonFinder);
  await tester.pumpAndSettle();
}

Future<void> _commonData(WidgetTester tester) async {
  // T3 date de naissance → T4 : choisir explicitement une date.
  await _selectExplicitDateOfBirth(tester);
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  expect(find.text('Où tu vis ?'), findsOneWidget);

  await _tapCanton(tester, 'AG');
  expect(find.text('Combien te tombe net par mois ?'), findsOneWidget);

  // T5 revenue fourchette par défaut (7000–7500) → T6
  expect(
    find.byKey(const ValueKey('onboarding-revenue-range-continue')),
    findsOneWidget,
  );
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

int _expectedAgeForPickedOnboardingDob() {
  final now = DateTime.now();
  final dateOfBirth = DateTime(now.year - 34, 7, 15);
  var age = now.year - dateOfBirth.year;
  if (now.month < dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
    age--;
  }
  return age;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  testWidgets('T1 entry: first Swiss preview, no dossier strip yet',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    expect(find.text('Un premier aperçu suisse.'), findsOneWidget);
    expect(
      find.textContaining('ce qu’il manque avant de créer un compte'),
      findsOneWidget,
    );
    expect(find.text('Voir mon aperçu'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-entry-open')), findsOneWidget);
    expect(find.text('TON DOSSIER'), findsNothing);
  });

  testWidgets('primary CTAs expose stable semantics identifiers',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final fake = _FakeCoachProfileProvider();
    try {
      await _pumpShell(tester, fake);

      _expectSemanticsIdentifier(tester, 'onboarding-entry-open');
      await _commonEntry(
        tester,
        intentKey: const ValueKey('onboarding-intent-impots'),
      );
      await _selectExplicitDateOfBirth(tester);
      _expectSemanticsIdentifier(tester, 'onboarding-dob-continue');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await _tapCanton(tester, 'AG');
      _expectSemanticsIdentifier(tester, 'onboarding-revenue-range-continue');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      _expectSemanticsIdentifier(tester, 'onboarding-insight-view');
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      _expectSemanticsIdentifier(tester, 'onboarding-scene-continue');
      expect(
        find.byKey(const ValueKey('onboarding-scene-continue')),
        findsOneWidget,
      );
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-continue');
      _expectSemanticsIdentifier(
        tester,
        'onboarding-bifurcation-create-account',
      );
      _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-reset');
      _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-exit');
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-continue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-create-account')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-reset')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-exit')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('CJT-018: revenue range uses discrete controls, not Slider',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-impots'),
    );

    await _selectExplicitDateOfBirth(tester);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await _tapCanton(tester, 'AG');

    expect(find.text('Combien te tombe net par mois ?'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-revenue-decrease')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-revenue-increase')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-revenue-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-revenue-increase')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('onboarding-revenue-range-continue')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);
    final merged = fake.mergedCalls.single;
    expect(merged['q_net_income_range_low'], 8000);
    expect(merged['q_net_income_range_high'], 8500);
  });

  testWidgets('CJT-018: routed scenes use discrete controls, not Slider',
      (tester) async {
    final cases = <({
      Widget scene,
      String decrementId,
      String incrementId,
    })>[
      (
        scene: const MintSceneRenteTrouee(
          currentAge: 34,
          netMonthly: 7250,
          isRange: true,
        ),
        decrementId: 'onboarding-scene-life-decrease',
        incrementId: 'onboarding-scene-life-increase',
      ),
      (
        scene: const MintSceneCapaciteAchat(
          netMonthly: 7250,
          isRange: true,
        ),
        decrementId: 'onboarding-scene-apport-decrease',
        incrementId: 'onboarding-scene-apport-increase',
      ),
      (
        scene: const MintScene3aLevier(
          netMonthly: 7250,
          cantonCode: 'VD',
          isRange: true,
        ),
        decrementId: 'onboarding-scene-3a-decrease',
        incrementId: 'onboarding-scene-3a-increase',
      ),
    ];

    for (final c in cases) {
      await _pumpStandaloneScene(tester, c.scene);

      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(ValueKey(c.decrementId)), findsOneWidget);
      expect(find.byKey(ValueKey(c.incrementId)), findsOneWidget);
    }
  });

  testWidgets('US tax person answer routes to waitlist before age/canton',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);

    await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-intent-explorer')));
    await tester.pumpAndSettle();
    expect(
      find.text('Es-tu citoyen ou résident fiscal aux États-Unis ?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('us-tax-person-yes')));
    await tester.pumpAndSettle();

    expect(find.textContaining('waitlist-landed'), findsOneWidget);
    expect(find.text('Quelle est ta date de naissance ?'), findsNothing);
    expect(find.text('Où tu vis ?'), findsNothing);
  });

  testWidgets('Intent situation: scene stays neutral, not retraite fallback',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-explorer'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();

    expect(find.text('Ce que Mint peut déjà situer'), findsOneWidget);
    expect(find.text('Repères captés'), findsOneWidget);
    expect(find.text('Argovie · environ 7’250 CHF/mois net'), findsOneWidget);
    expect(find.text('À préciser ensuite'), findsOneWidget);
    expect(find.text('SCENE · TA RETRAITE PROJETEE'), findsNothing);
  });

  testWidgets('Intent retraite: dossier gains one line per tour',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );

    // After T2 validated, the dossier strip exists with intent line.
    expect(find.text('TON DOSSIER'), findsOneWidget);
    expect(find.text('Intention'), findsOneWidget);
    expect(find.text('Ma prévoyance'), findsOneWidget);

    await _commonData(tester);
    // After T5, dossier holds 4 lines: intent, date of birth, canton, revenue.
    expect(find.text('Date de naissance'), findsOneWidget);
    expect(find.text('Canton'), findsOneWidget);
    expect(find.text('Revenu net mensuel'), findsOneWidget);

    // T6 insight screen for retraite intent.
    expect(find.textContaining('Avant de te montrer'), findsOneWidget);
    expect(find.text('UN CONSTAT'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('onboarding-insight-view')), findsOneWidget);
  });

  testWidgets('Intent impots: full flow T1→T9 flushes profile once',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-impots'),
    );
    await _commonData(tester);

    // T6 insight → T7 scene
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(find.text('SCENE · TON LEVIER DIRECT'), findsOneWidget);

    // T7 scene → T8 bifurcation via Continuer
    expect(find.byKey(const ValueKey('onboarding-scene-continue')),
        findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Je peux chiffrer un rachat LPP'),
      findsOneWidget,
    );

    // T8 bifurcation: tap "Sortir" → flush + navigate to /home.
    // (2026-04-24: T9 magic-link email scene killed, bifurcation is now
    // terminal. Continuer → /coach/chat, Sortir → /home.)
    expect(
      find.byKey(const ValueKey('onboarding-bifurcation-exit')),
      findsOneWidget,
    );
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    // Landed on /home (router stub shows 'home-landed').
    expect(find.text('home-landed'), findsOneWidget);

    // Provider flushed exactly once with expected keys (no q_email now).
    expect(fake.mergedCalls, hasLength(1));
    final merged = fake.mergedCalls.single;
    expect(merged['onb_intent'], 'impots');
    // SALVAGE-01/02: flush writes q_date_of_birth as the source of truth,
    // with q_birth_year only as legacy compatibility.
    expect(merged.containsKey('q_age'), isFalse,
        reason:
            'onb-01: q_age has zero readers; flush must write q_birth_year');
    expect(merged['q_birth_year'], DateTime.now().year - 34);
    expect(merged['q_date_of_birth'],
        contains('${DateTime.now().year - 34}-07-15'));
    expect(merged['q_canton'], 'AG');
    expect(merged.containsKey('q_email'), isFalse,
        reason: 'email-demain scene killed 2026-04-24, no email captured');
    expect(merged['q_net_income_confidence'], 'medium');
    expect(merged['q_net_income_range_low'], 7000);
    expect(merged['q_net_income_range_high'], 7500);
    expect(merged['q_wants_deeper'], false);
  });

  testWidgets(
      'T8 terminal shows account/data state, understood facts, gaps and next questions',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-impots'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('État du dossier'), findsOneWidget);
    expect(find.text('Anonyme · conservé sur cet appareil'), findsOneWidget);
    expect(find.text('Ce que Mint a compris'), findsOneWidget);
    expect(find.text('Mes impôts'), findsWidgets);
    expect(find.text('Argovie'), findsWidgets);
    expect(find.text("7'000 – 7'500 CHF"), findsWidgets);
    expect(find.text('Ce qui manque'), findsOneWidget);
    expect(find.text('Certificat LPP'), findsOneWidget);
    expect(find.text('Dépenses fixes'), findsOneWidget);
    expect(find.text('Prochaines questions utiles'), findsOneWidget);
    expect(
        find.text('Quel objectif concret veux-tu éclairer ?'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Repartir de zéro'), findsOneWidget);
    expect(find.text('Sortir'), findsOneWidget);
    _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-continue');
    _expectSemanticsIdentifier(
      tester,
      'onboarding-bifurcation-create-account',
    );
    _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-reset');
    _expectSemanticsIdentifier(tester, 'onboarding-bifurcation-exit');
  });

  testWidgets(
      'SALVAGE-01: RETRAITE branch flush writes the canonical key contract '
      '(q_date_of_birth + q_birth_year + q_nationality + q_employment_status + q_has_pension_fund)',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    // T6 insight → T7 scene → T8 bifurcation → Sortir flushes to /home.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);

    final merged = fake.mergedCalls.single;
    // onb-01: date of birth + birth year compatibility, not age.
    expect(merged.containsKey('q_age'), isFalse);
    expect(merged['q_birth_year'], DateTime.now().year - 34);
    expect(merged['q_date_of_birth'],
        contains('${DateTime.now().year - 34}-07-15'));
    // archetype-waitlist: nationality Suisse → 'CH' so the profile reaches
    // swissNative and the coach-entry gate passes.
    expect(merged['q_nationality'], 'CH');
    // onb-03: employment + LPP affiliation derived at flush, no 2nd question.
    expect(merged['q_employment_status'], 'salarie');
    expect(merged.containsKey('q_has_pension_fund'), isTrue);
    expect(merged['q_has_pension_fund'], isA<bool>());
  });

  testWidgets(
      'SALVAGE-01: q_has_pension_fund true for a 7000-7500 net fourchette '
      '(gross ≈ 7250×12×1.17 ≈ 101 790 ≥ 22 680)', (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    final merged = fake.mergedCalls.single;
    expect(merged['q_has_pension_fund'], isTrue,
        reason: 'net ≈ 7250/mo → gross-annual well above the LPP seuil 22 680');
  });

  testWidgets('Intent achat: scene N2 affiche chiffre héros intervalle',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-achat'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(find.text('SCENE · CE QUE TU PEUX VISER'), findsOneWidget);
    // Chiffre héros sous forme d'intervalle « CHF X – Y » (tiret
    // demi-cadratin), présent dans le texte rendu.
    final heroFinder = find.textContaining('\u2013');
    expect(heroFinder, findsWidgets);
  });

  testWidgets('Revenu saisie exacte: confidence high + valeur exacte flushée',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );

    // T3 date of birth default, advance
    await _selectExplicitDateOfBirth(tester);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // T4 canton
    await _tapCanton(tester, 'AG');

    // T5 bascule mode exact
    await tester.tap(find.text('Je sais le chiffre exact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7600');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // T6 → T7 → T8 (terminal) : Sortir flushes + lands on /home.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);
    final merged = fake.mergedCalls.single;
    expect(merged['q_net_income_period_chf'], 7600);
    expect(merged['q_net_income_confidence'], 'high');
    expect(merged.containsKey('q_net_income_range_low'), isFalse);
  });

  testWidgets(
      'T8 seal failure: SnackBar shown on Sortir, user stays on bifurcation',
      (tester) async {
    final fake = _FakeCoachProfileProvider()..throwOnMerge = true;
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    // T6 → T7 → T8
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Tap Sortir while mergeAnswers throws.
    await tester.tap(find.text('Sortir'));
    await tester.pump(); // dispatch the tap
    await tester.pump(const Duration(milliseconds: 50)); // let the throw land

    // Error SnackBar visible, dossier NOT sealed, user still on bifurcation.
    expect(
      find.textContaining('Impossible de sceller ton dossier'),
      findsOneWidget,
    );
    // "Réessayer" is the SnackBar action label from onboardingSealRetry.
    expect(find.text('Sortir'), findsOneWidget,
        reason: 'User still on T8 bifurcation, not navigated to /home');
    expect(find.text('home-landed'), findsNothing);
    // mergeAnswers did throw — no successful merge recorded (fake only
    // appends on success; it throws before appending).
    expect(fake.mergedCalls, isEmpty);
  });

  testWidgets(
      'T8 secure-store seal failure seeds current session without plain PII',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    _mockSecureStorageUnavailableOnWrite();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);
    expect(fake.mergedCalls, isEmpty);
    expect(fake.updateCalls, hasLength(1));
    expect(fake.hasProfile, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wizard_answers_v2'), isNull);
  });

  testWidgets(
      'T8 seal failure: successful merge with empty profile stays on bifurcation',
      (tester) async {
    final fake = _FakeCoachProfileProvider()
      ..leaveProfileEmptyAfterMerge = true;
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('Impossible de sceller ton dossier'),
      findsOneWidget,
    );
    expect(find.text('Continuer'), findsOneWidget);
    expect(find.text('coach-chat-landed'), findsNothing);
    expect(fake.mergedCalls, hasLength(1));
  });

  testWidgets(
      'T8 Continuer: retirement intent opens rente vs capital decision room',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    final auth = _TrackingAuthProvider();
    await _pumpShell(tester, fake, authProvider: auth);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    // T6 → T7 → T8 : user picks "Continuer" instead of "Sortir".
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-scene-continue')),
        findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-bifurcation-continue')),
      findsOneWidget,
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // The live Mint 2 retirement axis must continue into the decision room,
    // not strand the user in generic chat.
    expect(find.text('rente-vs-capital-landed'), findsOneWidget);
    expect(find.text('coach-chat-landed'), findsNothing);

    final merged = fake.mergedCalls.single;
    expect(merged['q_wants_deeper'], isTrue);
    // An anonymous guest who continues must be switched into local mode,
    // NOT routed through the account-only markAccountProfileAvailable()
    // (a no-op when logged out — the "Anonyme · conservé sur cet appareil"
    // promise was previously broken here).
    expect(auth.localModeCalls, 1);
    expect(auth.profileAvailableCalls, 0);
    expect(auth.isLocalMode, isTrue);
    expect(auth.authLifecycle.state, AuthLifecycleKind.guestEmpty);
    expect(auth.authLifecycle.allowsMainNavigation, isTrue);
  });

  testWidgets(
      'T8 Sortir: anonymous guest is switched to local mode so /home is '
      'reachable and the dossier is remembered on relaunch',
      (tester) async {
    // Honors the on-screen promise "Anonyme · conservé sur cet appareil".
    // Before the fix, Sortir called markAccountProfileAvailable() (a no-op
    // when logged out), leaving the lifecycle at sessionRestoring/freshVisitor
    // so /home bounced to /auth/register and nothing persisted for relaunch.
    final fake = _FakeCoachProfileProvider();
    final auth = _TrackingAuthProvider();
    await _pumpShell(tester, fake, authProvider: auth);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    // The seal routes the guest through enableLocalMode(), never the
    // account-only no-op.
    expect(auth.localModeCalls, 1);
    expect(auth.profileAvailableCalls, 0);

    // Navigable local guest: allowsMainNavigation is what lets /home render
    // instead of redirecting to the registration wall.
    expect(auth.isLocalMode, isTrue);
    expect(auth.authLifecycle.state, AuthLifecycleKind.guestEmpty);
    expect(auth.authLifecycle.accessMode, AuthAccessMode.guestLocal);
    expect(auth.authLifecycle.allowsMainNavigation, isTrue);

    // The PRODUCTION redirect guard (not the stub router) must let the sealed
    // guest reach /home while a freshVisitor with the same dossier still hits
    // the registration wall. This is the actual regression being repaired.
    expect(
      accountLifecycleAndArchetypeRedirect(
        lifecycle: auth.authLifecycle,
        location: '/home',
        path: '/home',
        topRoute: null,
        profile: fake.profile,
      ),
      isNull,
      reason: 'sealed guest must stay on /home, not bounce to /auth/register',
    );
    expect(
      accountLifecycleAndArchetypeRedirect(
        lifecycle: AuthLifecycleState.freshVisitor(),
        location: '/home',
        path: '/home',
        topRoute: null,
        profile: fake.profile,
      ),
      startsWith('/auth/register'),
      reason: 'without local mode, /home is the registration wall (the bug)',
    );

    // Relaunch memory: the explicit local-mode flag is persisted, and a real
    // cold-start restore (fresh AuthProvider + checkAuth) recognises the guest
    // as guestEmpty — never freshVisitor, never the wall.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auth_local_mode'), isTrue);

    final relaunched = AuthProvider();
    await relaunched.checkAuth();
    expect(relaunched.authLifecycle.state, AuthLifecycleKind.guestEmpty);
    expect(relaunched.authLifecycle.allowsMainNavigation, isTrue);
    expect(relaunched.isLoggedIn, isFalse);
  });

  testWidgets(
      'T8 Sortir: an existing account still routes through the account seal '
      '(no local-mode downgrade)',
      (tester) async {
    // Non-regression: a logged-in user sealing their dossier must keep using
    // markAccountProfileAvailable() and must NOT be flipped into anonymous
    // local mode.
    final fake = _FakeCoachProfileProvider();
    final auth = _TrackingAuthProvider(forceLoggedIn: true);
    await _pumpShell(tester, fake, authProvider: auth);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sortir'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);
    expect(auth.profileAvailableCalls, 1);
    expect(auth.localModeCalls, 0);
  });

  testWidgets(
      'T8 Continuer: retirement dossier lands on real RvC with real age',
      (tester) async {
    E2eRuntimeFlags.proofAnchorsOverride = true;
    addTearDown(E2eRuntimeFlags.resetForTest);

    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake, useRealRvcRoute: true);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-retraite'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // AX pilote (ADR 2026-07-30) : id racine 'rente_vs_capital_screen' retire ;
    // l'arrivee sur RvC se prouve via l'ancre INTERNE 'rvc_route_state'.
    expect(find.byKey(const Key('rvc_route_state')), findsOneWidget);
    expect(find.byKey(const Key('rvc_age_state')), findsOneWidget);
    expect(
      find.text('rvc_age=${_expectedAgeForPickedOnboardingDob()}'),
      findsOneWidget,
    );
    expect(find.text('rvc_age=2026'), findsNothing);
  });

  testWidgets('T8 Continuer: non-retirement intents open real tools',
      (tester) async {
    const cases = [
      (ValueKey('onboarding-intent-achat'), 'hypotheque-landed'),
      (ValueKey('onboarding-intent-impots'), 'pilier-3a-landed'),
      (ValueKey('onboarding-intent-explorer'), 'explore-landed'),
    ];

    for (final (intentKey, expectedLanding) in cases) {
      final fake = _FakeCoachProfileProvider();
      await _pumpShell(tester, fake);
      await _commonEntry(tester, intentKey: intentKey);
      await _commonData(tester);

      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLanding), findsOneWidget);
      expect(find.textContaining('coach-chat-landed'), findsNothing);
      expect(find.text('rente-vs-capital-landed'), findsNothing);
      expect(fake.mergedCalls.single['q_wants_deeper'], isTrue);
    }
  });

  testWidgets('T8 Créer un compte: seals dossier then routes to register',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-impots'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('register-landed'), findsOneWidget);
    expect(fake.mergedCalls, hasLength(1));
    expect(fake.mergedCalls.single['q_wants_deeper'], isFalse);
  });

  testWidgets(
      'T8 Repartir de zéro resets local diagnostic without profile flush',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(
      tester,
      intentKey: const ValueKey('onboarding-intent-impots'),
    );
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repartir de zéro'));
    await tester.pumpAndSettle();

    expect(find.text('Un premier aperçu suisse.'), findsOneWidget);
    expect(fake.mergedCalls, isEmpty);
    expect(fake.updateCalls, isEmpty);
    expect(fake.hasProfile, isFalse);
  });

  // ── W4 — Scène rente_trouée honnête + hypothèse jeune étiquetée ──────
  //
  // returning_swiss_gaps-2 : la scène « rente TROUÉE » doit refléter le trou
  // de cotisation (gapFactor < 1) au lieu de calculer « sur carrière
  // complète ». jeune_diplome-2 : un jeune (<30) sans lacune voit le chiffre
  // étiqueté « hypothèse : carrière complète » (gapFactor=1.0 plus silencieux).
  group('W4 — Scène rente_trouée honnête', () {
    testWidgets(
        'profil à lacunes (arrivée 43) : la composante AVS de la scène '
        'intègre le gapFactor (< carrière complète)', (tester) async {
      const netMonthly = 7250.0;
      const currentAge = 48;
      const arrivalAge = 43;

      final grossAnnual = IncomeConverter.netMonthlyToGrossAnnual(netMonthly);

      // AVS canonique AVEC lacunes (ce que la scène DOIT refléter) vs SANS
      // (l'ancien calcul « carrière complète » bypassant le trou).
      final avsWithGap = AvsCalculator.computeMonthlyRente(
        currentAge: currentAge,
        retirementAge: avsAgeReferenceHomme,
        arrivalAge: arrivalAge,
        grossAnnualSalary: grossAnnual,
      );
      final avsFullCareer = AvsCalculator.computeMonthlyRente(
        currentAge: currentAge,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: grossAnnual,
      );

      // Pré-condition du test : le gapFactor a un effet observable.
      expect(avsWithGap, lessThan(avsFullCareer),
          reason: 'arrivée à 43 ans ⇒ AVS canonique < carrière complète');

      await _pumpStandaloneScene(
        tester,
        const MintSceneRenteTrouee(
          currentAge: currentAge,
          netMonthly: netMonthly,
          isRange: false,
          arrivalAge: arrivalAge,
        ),
      );

      // Étiquette « carrière complète » NE doit PAS apparaître pour un profil
      // à lacunes (le gapFactor != 1.0) — la scène reflète le trou, elle ne le
      // maquille pas en hypothèse de carrière pleine.
      expect(find.text('hypothèse : carrière complète'), findsNothing,
          reason: 'profil à lacunes ⇒ pas d\'étiquette carrière complète');

      // Le chiffre héros (CHF X – Y) est rendu : preuve que la scène calcule
      // bien à partir d'AvsCalculator(gap)+LppCalculator sans crasher.
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets(
        'jeune (25 ans) sans lacune : le chiffre porte l\'étiquette '
        '« hypothèse : carrière complète »', (tester) async {
      await _pumpStandaloneScene(
        tester,
        const MintSceneRenteTrouee(
          currentAge: 25,
          netMonthly: 5200,
          isRange: false,
        ),
      );

      expect(find.text('hypothèse : carrière complète'), findsOneWidget,
          reason: 'jeune (<30) gapFactor=1.0 ⇒ hypothèse étiquetée '
              '(jeune_diplome-2)');
    });

    testWidgets(
        'profil mûr (48 ans) sans lacune : pas d\'étiquette carrière complète '
        '(l\'hypothèse n\'est pertinente que pour les jeunes)', (tester) async {
      await _pumpStandaloneScene(
        tester,
        const MintSceneRenteTrouee(
          currentAge: 48,
          netMonthly: 7250,
          isRange: false,
        ),
      );

      expect(find.text('hypothèse : carrière complète'), findsNothing,
          reason: 'âge ≥ 30 : l\'étiquette ne s\'applique pas');
    });
  });
}

void _expectSemanticsIdentifier(WidgetTester tester, String identifier) {
  expect(
    tester.getSemantics(find.byKey(ValueKey(identifier))).identifier,
    identifier,
  );
}

Future<void> _pumpStandaloneScene(WidgetTester tester, Widget scene) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: scene,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
