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
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  final List<Map<String, dynamic>> mergedCalls = [];
  bool throwOnMerge = false;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    if (throwOnMerge) {
      throw StateError('test: mergeAnswers failed');
    }
    mergedCalls.add(Map<String, dynamic>.from(partial));
  }

  @override
  Future<void> loadFromWizard() async {}
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
  expect(find.textContaining('Qu\u2019est-ce qui t\u2019amène'), findsOneWidget);

  // T2 → T3 (tap intent card)
  await tester.tap(find.text(intentLabel));
  await tester.pumpAndSettle();
  expect(find.text('Quel âge tu as ?'), findsOneWidget);
}

Future<void> _commonData(WidgetTester tester) async {
  // T3 age → T4 : défaut 34, just Continuer
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  expect(find.text('Où tu vis ?'), findsOneWidget);

  // T4 canton → T5 : tap VD
  await tester.tap(find.text('VD'));
  await tester.pumpAndSettle();
  expect(find.text('Combien te tombe net par mois ?'), findsOneWidget);

  // T5 revenue fourchette par défaut (7000–7500) → T6
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  testWidgets('T1 entry: only title + [Ouvrir], no dossier strip yet',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    expect(find.text('Il est temps que tu comprennes.'), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('TON DOSSIER'), findsNothing);
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
    // After T5, dossier holds 4 lines: intent, age, canton, revenue.
    expect(find.text('Âge'), findsOneWidget);
    expect(find.text('Canton'), findsOneWidget);
    expect(find.text('Revenu net mensuel'), findsOneWidget);

    // T6 insight screen for retraite intent.
    expect(find.textContaining('Avant de te montrer'), findsOneWidget);
    expect(find.text('UN CONSTAT'), findsOneWidget);
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
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Je peux chiffrer un rachat LPP'),
      findsOneWidget,
    );

    // T8 bifurcation: tap "Plus tard" → flush + navigate to /home.
    // (2026-04-24: T9 magic-link email scene killed, bifurcation is now
    // terminal. Creuser → /coach/chat, Plus tard → /home.)
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    // Landed on /home (router stub shows 'home-landed').
    expect(find.text('home-landed'), findsOneWidget);

    // Provider flushed exactly once with expected keys (no q_email now).
    expect(fake.mergedCalls, hasLength(1));
    final merged = fake.mergedCalls.single;
    expect(merged['onb_intent'], 'impots');
    expect(merged['q_age'], 34);
    expect(merged['q_canton'], 'VD');
    expect(merged.containsKey('q_email'), isFalse,
        reason: 'email-demain scene killed 2026-04-24, no email captured');
    expect(merged['q_net_income_confidence'], 'medium');
    expect(merged['q_net_income_range_low'], 7000);
    expect(merged['q_net_income_range_high'], 7500);
    expect(merged['q_wants_deeper'], false);
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

    // T3 age default 34, advance
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
      'T8 Creuser: flushes wantsDeeper=true + navigates to /coach/chat',
      (tester) async {
    final fake = _FakeCoachProfileProvider();
    await _pumpShell(tester, fake);
    await _commonEntry(tester, intentLabel: 'Ce que je toucherai, vraiment.');
    await _commonData(tester);

    // T6 → T7 → T8 : user picks "Creuser" instead of "Plus tard".
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creuser'));
    await tester.pumpAndSettle();

    // Landed on /coach/chat (router stub shows 'coach-chat-landed').
    expect(find.text('coach-chat-landed'), findsOneWidget);

    final merged = fake.mergedCalls.single;
    expect(merged['q_wants_deeper'], isTrue);
  });
}
