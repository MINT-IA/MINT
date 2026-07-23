// ────────────────────────────────────────────────────────────
//  COACH CONSENT GATE — flux comportemental (beads MINT_nosync-tcr)
//
//  Exigence du design panel (gate privacy) : le grep de source ne suffit
//  pas — ce test exerce le VRAI écran via les seams officiels :
//   - CoachLlmService.registerOrchestrator : orchestrateur factice qui
//     jette CoachChatApiException('consent_required') tant que le grant
//     n'est pas accordé, puis répond normalement (miroir du backend
//     hard_block 403 -> 200 après grant) ;
//   - ConsentService.promptOverrideForTests : simule l'acceptation ou le
//     refus de la ConsentSheet sans réseau.
//
//  Verrouille : accepté -> retry automatique, réponse affichée, message
//  utilisateur NON dupliqué ; refusé -> message système coachConsentDeclined
//  avec resend one-tap, pas de spinner bloqué, aucun appel serveur en plus.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';

class _FakeGate {
  bool granted = false;
  int serverCalls = 0;
  int promptCalls = 0;

  Future<CoachResponse> orchestrate({
    required String userMessage,
    required List<ChatMessage> history,
    required CoachContext ctx,
    LlmConfig? byokConfig,
    String? memoryBlock,
    String language = 'fr',
    int cashLevel = 2,
    bool isLoggedIn = false,
  }) async {
    serverCalls++;
    if (!granted) {
      throw const CoachChatApiException(
        code: 'consent_required',
        message: 'Consent required.',
        consentPurpose: 'transfer_us_anthropic',
      );
    }
    return const CoachResponse(
      message: 'Réponse du coach après consentement.',
      disclaimer: 'Outil éducatif (LSFin).',
    );
  }
}

CoachProfileProvider _profileProvider() {
  final provider = CoachProfileProvider();
  provider.updateFromAnswers({
    'q_firstname': 'Julien',
    'q_birth_year': 1977,
    'q_canton': 'VS',
    'q_net_income_period_chf': 9080,
    'q_civil_status': 'marie',
    'q_goal': 'retraite',
  });
  return provider;
}

Widget _app(CoachProfileProvider profile) {
  // GoRouter requis : _buildCoachContext installe un callback de navigation
  // (context.go) déclenché en fin de tour — sans router le harnais crashe
  // « No GoRouter found in context ».
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CoachChatScreen()),
  ]);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider(create: (_) => ByokProvider()),
      ChangeNotifierProvider(create: (_) => MintStateProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
    ),
  );
}

Future<void> _pump(WidgetTester tester, {int frames = 80}) async {
  // Large budget : _sendMessage attend un memory-block avec timeout 2 s
  // avant d'atteindre l'orchestrateur (temps fake, avancé par pump).
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _send(WidgetTester tester, String text) async {
  final field = find.byType(TextField).first;
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await _pump(tester);
}

void main() {
  late _FakeGate gate;

  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_local_mode': false});
    // Kill-switch du hard gate archétype : le profil de test n'est pas
    // swiss_native et serait redirigé /waitlist avant d'atteindre
    // l'orchestrateur — hors sujet pour ce flux.
    FeatureFlags.enableCoachHardGate = false;
    gate = _FakeGate();
    CoachLlmService.registerOrchestrator(gate.orchestrate);
  });

  tearDown(() {
    FeatureFlags.enableCoachHardGate = true;
    ConsentService.promptOverrideForTests = null;
    CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
  });

  testWidgets(
      'accepté : sheet -> grant -> retry automatique, réponse affichée, '
      'message user non dupliqué', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    ConsentService.promptOverrideForTests = (context, purposes) async {
      gate.promptCalls++;
      expect(purposes, [ConsentPurpose.transferUsAnthropic]);
      gate.granted = true; // l'utilisateur accepte -> grant enregistré
      return true;
    };

    await tester.pumpWidget(_app(_profileProvider()));
    await _pump(tester);

    await _send(tester, 'Combien pour mon 3a ?');

    expect(gate.promptCalls, 1, reason: 'la sheet doit être présentée');
    expect(gate.serverCalls, 2,
        reason: '1er appel -> consent_required, retry après grant -> 200');
    expect(find.text('Réponse du coach après consentement.', skipOffstage: false),
        findsOneWidget);
    expect(
        find.text('Combien pour mon 3a ?', skipOffstage: false), findsOneWidget,
        reason: 'le retry ne doit PAS dupliquer le message utilisateur');
  });

  testWidgets(
      'refusé : message système explicite + resend one-tap, pas de spinner '
      'bloqué', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    ConsentService.promptOverrideForTests = (context, purposes) async {
      gate.promptCalls++;
      return false; // l'utilisateur refuse
    };

    await tester.pumpWidget(_app(_profileProvider()));
    await _pump(tester);

    await _send(tester, 'Analyse mon budget');

    expect(gate.promptCalls, 1);
    expect(gate.serverCalls, 1, reason: 'aucun retry après refus');
    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coachConsentDeclined, skipOffstage: false),
        findsOneWidget,
        reason: 'le refus doit afficher le message ARB honnête');
    // La voie de reprise promise est à un tap (suggestedAction).
    expect(find.text('Analyse mon budget', skipOffstage: false),
        findsAtLeastNWidgets(1));
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'pas de spinner bloqué après refus');
  });
}
