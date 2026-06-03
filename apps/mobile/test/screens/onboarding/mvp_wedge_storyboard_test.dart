/// Integration test du storyboard onboarding v2
/// (locked 2026-04-22, T9 email-demain killed 2026-04-24).
///
/// Vérifie les 3 flows intents (retraite / achat / impots) tour par
/// tour, de T1 (landing) à T8 (bifurcation), avec assertion sur la
/// densification du dossier à chaque tour et le flush vers
/// CoachProfileProvider au tour 8 (déclenché par Creuser ou Plus tard).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';

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
    final isUsTaxPersonGateOnly =
        partial.length == 1 && partial.containsKey('q_us_tax_person');
    if (isUsTaxPersonGateOnly) {
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
  _FakeCoachProfileProvider fake,
) async {
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
        builder: (_, __) => const Scaffold(body: Text('coach-chat-landed')),
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
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: fake,
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
  required String intentLabel,
}) async {
  // T1 → T2
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  expect(
      find.textContaining('Qu\u2019est-ce qui t\u2019amène'), findsOneWidget);

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
  await tester.tap(find.text(intentLabel));
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

Future<void> _commonData(WidgetTester tester) async {
  // T3 date de naissance → T4 : choisir explicitement une date.
  await _selectExplicitDateOfBirth(tester);
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  expect(find.text('Où tu vis ?'), findsOneWidget);

  // T4 canton → T5 : tap VD
  expect(find.byKey(const ValueKey('onboarding-canton-vd')), findsOneWidget);
  await tester.tap(find.text('VD'));
  await tester.pumpAndSettle();
  expect(find.text('Combien te tombe net par mois ?'), findsOneWidget);

  // T5 revenue fourchette par défaut (7000–7500) → T6
  expect(
    find.byKey(const ValueKey('onboarding-revenue-range-continue')),
    findsOneWidget,
  );
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  testWidgets('T1 entry: only title + [Ouvrir], no dossier strip yet',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    expect(find.text('Il est temps que tu comprennes.'), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-entry-open')), findsOneWidget);
    expect(find.text('TON DOSSIER'), findsNothing);
  });

  testWidgets('primary CTAs expose stable non-T6 semantics identifiers',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final fake = _FakeCoachProfileProvider();
    try {
      await _pumpShell(tester, fake);

      _expectSemanticsIdentifier(tester, 'onboarding-entry-open');
      await _commonEntry(tester, intentLabel: 'Ce que je paie de trop.');
      await _selectExplicitDateOfBirth(tester);
      _expectSemanticsIdentifier(tester, 'onboarding-dob-continue');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VD'));
      await tester.pumpAndSettle();
      _expectSemanticsIdentifier(tester, 'onboarding-revenue-range-continue');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // T6-T8 remain excluded from this contract while CJT-018 investigates
      // stale full-history AX frames on the lower onboarding CTAs.
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-scene-continue')),
        findsOneWidget,
      );
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-creuser')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-bifurcation-plus-tard')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('US tax person answer routes to waitlist before age/canton',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);

    await tester.tap(find.byKey(const ValueKey('onboarding-entry-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je regarde d’abord.'));
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

  testWidgets('Intent retraite: dossier gains one line per tour',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');

    // After T2 validated, the dossier strip exists with intent line.
    expect(find.text('TON DOSSIER'), findsOneWidget);
    expect(find.text('Intention'), findsOneWidget);
    expect(find.text('Ma retraite'), findsOneWidget);

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
    await _commonEntry(tester, intentLabel: 'Ce que je paie de trop.');
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

    // T8 bifurcation: tap "Plus tard" → flush + navigate to /home.
    // (2026-04-24: T9 magic-link email scene killed, bifurcation is now
    // terminal. Creuser → /coach/chat, Plus tard → /home.)
    expect(
      find.byKey(const ValueKey('onboarding-bifurcation-plus-tard')),
      findsOneWidget,
    );
    await tester.tap(find.text('Plus tard'));
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
    expect(merged['q_canton'], 'VD');
    expect(merged.containsKey('q_email'), isFalse,
        reason: 'email-demain scene killed 2026-04-24, no email captured');
    expect(merged['q_net_income_confidence'], 'medium');
    expect(merged['q_net_income_range_low'], 7000);
    expect(merged['q_net_income_range_high'], 7500);
    expect(merged['q_wants_deeper'], false);
  });

  testWidgets(
      'SALVAGE-01: RETRAITE branch flush writes the canonical key contract '
      '(q_date_of_birth + q_birth_year + q_nationality + q_employment_status + q_has_pension_fund)',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    // T6 insight → T7 scene → T8 bifurcation → Plus tard flushes to /home.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
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
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    final merged = fake.mergedCalls.single;
    expect(merged['q_has_pension_fund'], isTrue,
        reason: 'net ≈ 7250/mo → gross-annual well above the LPP seuil 22 680');
  });

  testWidgets('Intent achat: scene N2 affiche chiffre héros intervalle',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je peux viser.');
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
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');

    // T3 date of birth default, advance
    await _selectExplicitDateOfBirth(tester);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // T4 canton
    await tester.tap(find.text('VD'));
    await tester.pumpAndSettle();

    // T5 bascule mode exact
    await tester.tap(find.text('Je sais le chiffre exact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7600');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // T6 → T7 → T8 (terminal) : Plus tard flushes + lands on /home.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.text('home-landed'), findsOneWidget);
    final merged = fake.mergedCalls.single;
    expect(merged['q_net_income_period_chf'], 7600);
    expect(merged['q_net_income_confidence'], 'high');
    expect(merged.containsKey('q_net_income_range_low'), isFalse);
  });

  testWidgets(
      'T8 seal failure: SnackBar shown on Plus tard, user stays on bifurcation',
      (tester) async {
    final fake = _FakeCoachProfileProvider()..throwOnMerge = true;
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    // T6 → T7 → T8
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Tap Plus tard while mergeAnswers throws.
    await tester.tap(find.text('Plus tard'));
    await tester.pump(); // dispatch the tap
    await tester.pump(const Duration(milliseconds: 50)); // let the throw land

    // Error SnackBar visible, dossier NOT sealed, user still on bifurcation.
    expect(
      find.textContaining('Impossible de sceller ton dossier'),
      findsOneWidget,
    );
    // "Réessayer" is the SnackBar action label from onboardingSealRetry.
    expect(find.text('Plus tard'), findsOneWidget,
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
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    _mockSecureStorageUnavailableOnWrite();
    await tester.tap(find.text('Plus tard'));
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
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Creuser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('Impossible de sceller ton dossier'),
      findsOneWidget,
    );
    expect(find.text('Creuser'), findsOneWidget);
    expect(find.text('coach-chat-landed'), findsNothing);
    expect(fake.mergedCalls, hasLength(1));
  });

  testWidgets('T8 Creuser: flushes wantsDeeper=true + navigates to /coach/chat',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    // T6 → T7 → T8 : user picks "Creuser" instead of "Plus tard".
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-scene-continue')),
        findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('onboarding-bifurcation-creuser')),
      findsOneWidget,
    );
    await tester.tap(find.text('Creuser'));
    await tester.pumpAndSettle();

    // Landed on /coach/chat (router stub shows 'coach-chat-landed').
    expect(find.text('coach-chat-landed'), findsOneWidget);

    final merged = fake.mergedCalls.single;
    expect(merged['q_wants_deeper'], isTrue);
  });
}

void _expectSemanticsIdentifier(WidgetTester tester, String identifier) {
  expect(
    tester.getSemantics(find.byKey(ValueKey(identifier))).identifier,
    identifier,
  );
}
