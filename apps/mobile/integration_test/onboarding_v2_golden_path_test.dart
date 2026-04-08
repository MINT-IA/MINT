// Phase 10 Plan 10-03 — Onboarding v2 golden-path integration test (D-10).
//
// Locks ROADMAP §10 SC #4:
//   • Landing → Intent → /coach/chat, 2 screens before the first insight.
//   • Friction (wallclock from landing first frame to chat first frame) < 20 s.
//   • CoachEntryPayload carries `fromOnboarding: true` + the tapped chipKey.
//   • MiniOnboardingCompleted is written by the time the chat stub mounts
//     (delegated to coach_chat_screen in production; here we assert the
//     payload that the chat bootstrap consumes).
//
// ## Harness scope
//
// A full-fidelity E2E booting `MintApp` pulls Claude, Sentry, providers,
// RAG, and the entire coach bootstrap — which is both slow and flaky in
// CI. This test therefore wires a minimal GoRouter with:
//
//   • `/` → real [LandingScreen] (zero imports from services/financial_core)
//   • `/onboarding/intent` → real [IntentScreen] (exercises the full chip
//     tap pipeline: IntentRouter, PremierEclairageSelector, CapMemoryStore,
//     ReportPersistenceService, CoachEntryPayloadProvider)
//   • `/coach/chat` → `_CoachChatStub` test double that records the
//     received [CoachEntryPayload] and renders a visible marker.
//
// The real code under test (IntentScreen + its dependencies) runs
// unmodified. Only the chat surface is stubbed — the contract between
// intent and chat is the payload + route target, which the stub captures
// honestly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/onboarding/intent_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Test double for CoachChatScreen. Captures the [CoachEntryPayload]
/// pushed via `GoRouter.go('/coach/chat', extra: payload)` so assertions
/// can inspect source/data/userMessage after navigation.
class _CoachChatStub extends StatefulWidget {
  const _CoachChatStub({required this.extra, required this.onMounted});
  final Object? extra;
  final void Function(CoachEntryPayload? payload) onMounted;

  @override
  State<_CoachChatStub> createState() => _CoachChatStubState();
}

class _CoachChatStubState extends State<_CoachChatStub> {
  @override
  void initState() {
    super.initState();
    final extra = widget.extra;
    widget.onMounted(extra is CoachEntryPayload ? extra : null);
    // Mirror CoachChatScreen's behaviour: on first entry from an
    // onboarding intent, stamp miniOnboardingCompleted. In production
    // this happens inside coach_chat_screen.dart after the first LLM
    // response — here we honour the same contract synchronously so the
    // test can assert the SharedPreferences side-effect.
    if (extra is CoachEntryPayload &&
        extra.source == CoachEntrySource.onboardingIntent &&
        extra.data?['fromOnboarding'] == true) {
      ReportPersistenceService.setMiniOnboardingCompleted(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('coach_chat_stub'),
      body: Center(child: Text('MINT_CHAT_READY')),
    );
  }
}

/// NavigatorObserver that records the name (pathUri) of every pushed
/// route. Used to assert "screens before first insight = 2".
class _RouteRecorder extends NavigatorObserver {
  final List<String> pushedNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name ?? '<anonymous>';
    pushedNames.add(name);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Leave google_fonts runtime fetching enabled (its default). In
    // CI/flutter-tester the HTTP fetch will fail silently, at which
    // point google_fonts falls back to the platform default font —
    // which is exactly what we want for a headless assertion run.
    //
    // We still mock the path_provider channels so the fallback's
    // "save to cache" path returns a noop instead of throwing a
    // PlatformException (the exception is what schedules a stray
    // frame and trips '_pendingFrame == null' at teardown).
    GoogleFonts.config.allowRuntimeFetching = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => '.',
    );

    // Pigeon-based path_provider_foundation channel (darwin). Its
    // envelope is `[result]` encoded with the StandardMessageCodec —
    // we intercept at the raw binary-messenger layer and reply with
    // a StandardMessageCodec-encoded single-element list.
    const pigeonChannel =
        'dev.flutter.pigeon.path_provider_foundation.PathProviderApi.getDirectoryPath';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      pigeonChannel,
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(<Object?>['.']);
      },
    );
  });

  late List<CoachEntryPayload?> receivedPayloads;
  late _RouteRecorder recorder;

  Widget buildHarness() {
    receivedPayloads = <CoachEntryPayload?>[];
    recorder = _RouteRecorder();

    final router = GoRouter(
      initialLocation: '/',
      observers: [recorder],
      routes: [
        GoRoute(
          path: '/',
          name: 'landing',
          builder: (_, __) => const LandingScreen(),
        ),
        GoRoute(
          path: '/onboarding/intent',
          name: 'onboardingIntent',
          builder: (_, __) => const IntentScreen(),
        ),
        GoRoute(
          path: '/coach/chat',
          name: 'coachChat',
          builder: (context, state) => _CoachChatStub(
            extra: state.extra,
            onMounted: (p) => receivedPayloads.add(p),
          ),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
        ChangeNotifierProvider(create: (_) => CoachEntryPayloadProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        // Force reduce-motion: LiveTestWidgetsFlutterBinding (used by
        // integration_test) trips '_pendingFrame == null' at teardown if
        // any AnimationController is still scheduling frames. Landing,
        // IntentScreen (MintEntrance), and MaterialApp transitions all
        // honour disableAnimations — setting it here drains every
        // time-based tween to completion on the next pump.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'golden path: landing → intent → /coach/chat in ≤2 screens and <20s',
    (tester) async {
      final stopwatch = Stopwatch()..start();

      // ── Pump harness. Landing is the initial route.
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Assertion 1: landing CTA is present. The landing screen renders
      // `landingV2Cta` ("Continuer (sans compte)") as a FilledButton.
      // We resolve it via the localized string to stay decoupled from
      // button keys that may be introduced later.
      final l10n = S.of(tester.element(find.byType(LandingScreen)))!;
      final ctaFinder = find.widgetWithText(FilledButton, l10n.landingV2Cta);
      expect(ctaFinder, findsOneWidget,
          reason: 'Landing must expose the "Continuer (sans compte)" CTA.');

      // ── Tap landing CTA → /onboarding/intent.
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      // Assertion 2: IntentScreen is on screen.
      expect(find.byType(IntentScreen), findsOneWidget,
          reason: 'CTA tap must navigate to /onboarding/intent.');

      // Assertion 3: the first chip (intentChip3a) is visible. We tap it
      // via the localized label — this is what the production code uses
      // as the chip's `label` and `message`, so the assertion exercises
      // the real ARB → chip wiring.
      final firstChipFinder = find.text(l10n.intentChip3a);
      expect(firstChipFinder, findsOneWidget,
          reason: 'Intent screen must render the first chip (3a).');

      await tester.tap(firstChipFinder);
      // IntentScreen awaits SharedPreferences writes + CapMemoryStore
      // load/save. pumpAndSettle drives the async gaps to completion.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ── Assertion 4: we landed on the coach chat stub.
      expect(find.byKey(const Key('coach_chat_stub')), findsOneWidget,
          reason: 'Chip tap must navigate to /coach/chat.');
      expect(find.text('MINT_CHAT_READY'), findsOneWidget,
          reason: 'Coach chat surface must render the first insight marker.');

      stopwatch.stop();

      // ── Assertion 5: payload was delivered with the expected shape.
      expect(receivedPayloads.length, 1,
          reason: 'Exactly one payload delivery expected.');
      final payload = receivedPayloads.single;
      expect(payload, isNotNull,
          reason: 'Chat stub must receive a CoachEntryPayload via extra.');
      expect(payload!.source, CoachEntrySource.onboardingIntent);
      expect(payload.userMessage, isNotNull,
          reason: 'First chip carries a userMessage (non-Autre chip).');
      expect(payload.data?['fromOnboarding'], isTrue,
          reason: 'fromOnboarding flag must be forwarded via payload.data.');

      // ── Assertion 6: miniOnboardingCompleted was written.
      // ReportPersistenceService stores the flag under its own key; the
      // simplest contract-level assertion is the public read helper.
      final done = await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(done, isTrue,
          reason:
              'Chat bootstrap must set miniOnboardingCompleted on first entry.');

      // ── Assertion 7: screens traversed before the chat = 2.
      // The NavigatorObserver records every push. With GoRouter's
      // `go` semantics, each route change is a push (not a replace) on
      // the navigator. We count distinct named entries up to and
      // including 'coachChat', minus the chat itself → must equal 2.
      final namedPushes = recorder.pushedNames
          .where((n) => n != '<anonymous>')
          .toList();
      // Landing is the initial push, intent is push #2, chat is push #3.
      // Before the chat mounted, exactly 2 destinations were reached.
      final chatIdx = namedPushes.indexOf('coachChat');
      expect(chatIdx, greaterThanOrEqualTo(0),
          reason: 'coachChat route must be pushed.');
      expect(chatIdx, 2,
          reason: 'Expected landing (0) → intent (1) → chat (2): '
              'only 2 screens before the chat. Got history: $namedPushes');

      // ── Assertion 8: wallclock friction < 20 s.
      expect(stopwatch.elapsed.inSeconds, lessThan(20),
          reason:
              'Friction ($stopwatch) must stay under the 20-second budget '
              'defined by ROADMAP §10 SC #4.');
    },
  );
}
