/// Phase 01.5 W02-T07 Task 1 — End-to-end integration test for the full
/// archetype hard-gate flow.
///
/// Exercises the cross-cutting wiring assembled across Wave 02 plans 01-06 :
///
///   * evaluateCoachArchetypeGate (plan 02-03 Task 4 — pure helper)
///   * GoRouter /waitlist redirect (plan 02-03 Task 3 — app.dart route)
///   * WaitlistScreen + WaitlistProvider (plan 02-02)
///   * WaitlistProvider.onGateSuccess callback → CoachProfileProvider.clearAll()
///     (plan 02-03 Task 6 — nLPD art. 6 minimization)
///   * FeatureFlags.enableCoachHardGate kill-switch (plan 02-04)
///   * ProfileMigrationService legacy grandfather (plan 02-05 R7 — flag-only)
///
/// Scope note (Karpathy #2 — simplicity first) : we do NOT pumpWidget the
/// full `MintApp` here. That widget pulls in Sentry, HTTP, 20+ providers,
/// auth gate + onboarding redirect logic — over-engineering for an
/// integration assertion. Instead we assemble the minimal cross-layer
/// surface (provider tree + GoRouter + the gate site evaluation) so the
/// test exercises the actual wiring between plans 02-01 → 02-06 without
/// the auth/sentry/http noise that's tangential to the gate contract.
///
/// 4 behaviors covered :
///   1. integration_expat_us_flow — usTaxPerson:true profile → gate fires →
///      /waitlist renders → submit → success → CoachProfileProvider.clearAll
///      invoked.
///   2. integration_swiss_native_flow_no_regression — nationality:'CH' →
///      gate does NOT fire → coach context built normally.
///   3. integration_kill_switch_bypass — enableCoachHardGate=false + an
///      otherwise-blocked profile → gate decision still says block but the
///      route-level wrap (gate.shouldBlock && FeatureFlags.enableCoachHardGate)
///      lets the coach proceed.
///   4. integration_independent_no_lpp_safe_local_route — independent/no-LPP
///      reaches the coach shell so the orchestrator can answer the audited
///      local topic; it is not waitlisted at the route layer.
///   5. integration_independent_with_lpp_still_waitlisted — independent with
///      LPP remains gated; the no-LPP safe route must not widen silently.
///   6. integration_legacy_user_grandfather — flag-only migration sets
///      `needsUsTaxPersonReOnboarding=true` on legacy null-nationality
///      null-usTaxPerson profiles, without writing the nationality field
///      (Codex C1 HIGH data-truth contract from plan 02-05).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/screens/coach/coach_archetype_guard.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/profile_migration_service.dart';
import 'package:mint_mobile/services/waitlist_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service shim feeding deterministic HTTP responses to WaitlistProvider.
class _FakeWaitlistService extends WaitlistService {
  _FakeWaitlistService({required this.responseBuilder}) : super.test();

  final Future<http.Response> Function(http.Request req) responseBuilder;

  @override
  Future<String> resolveSessionId() async => 'integration-test-session';

  @override
  http.Client get httpClient => MockClient((req) => responseBuilder(req));

  @override
  String get baseUrlOverride => 'https://example.test';
}

/// Stand-in coach landing widget that calls evaluateCoachArchetypeGate the
/// same way coach_chat_screen.dart:_buildCoachContext does. Keeps the test
/// lightweight (no 2545-line widget pump) while still exercising the gate
/// → context.go('/waitlist') wiring AND the FeatureFlags kill-switch wrap.
class _FakeCoachLanding extends StatefulWidget {
  const _FakeCoachLanding();

  @override
  State<_FakeCoachLanding> createState() => _FakeCoachLandingState();
}

class _FakeCoachLandingState extends State<_FakeCoachLanding> {
  bool _gateEvaluated = false;
  bool _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gateEvaluated) return;
    _gateEvaluated = true;
    final profile =
        context.read<CoachProfileProvider>().profile ?? CoachProfile.defaults();
    final gate = evaluateCoachArchetypeGate(profile);
    if (gate.shouldBlock && FeatureFlags.enableCoachHardGate) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/waitlist',
              extra: WaitlistArgs(archetype: gate.archetypeSlug));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_redirected) {
      return const Scaffold(body: Center(child: Text('redirecting...')));
    }
    return const Scaffold(
      key: Key('coach-landing-rendered'),
      body: Center(child: Text('coach rendered')),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/coach',
    routes: [
      GoRoute(
        path: '/coach',
        builder: (_, __) => const _FakeCoachLanding(),
      ),
      GoRoute(
        path: '/waitlist',
        builder: (ctx, state) {
          final args = (state.extra as WaitlistArgs?) ?? const WaitlistArgs();
          return ChangeNotifierProvider<WaitlistProvider>(
            create: (_) => WaitlistProvider(
              service: _FakeWaitlistService(
                responseBuilder: (_) async =>
                    http.Response('{"id":"abc","createdAt":"now"}', 201),
              ),
              onGateSuccess: () => ctx.read<CoachProfileProvider>().clearAll(),
            ),
            child: WaitlistScreen(args: args),
          );
        },
      ),
    ],
  );
}

Widget _wrapWithProviders({
  required CoachProfileProvider coachProvider,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
    ],
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Reset the kill switch to its production default before every test
    // (plans 02-04 made this a mutable static, so tests must restore it).
    FeatureFlags.enableCoachHardGate = true;
  });

  group('Phase 01.5 W02 — archetype hard-gate end-to-end', () {
    testWidgets(
        'integration_expat_us_flow: usTaxPerson:true profile → gate fires '
        '→ /waitlist renders → submit success → CoachProfileProvider.clearAll '
        'invoked', (tester) async {
      // Seed a profile with usTaxPerson=true (FATCA short-circuit per plan
      // 02-01). Also set a small piece of state so we can assert clearAll
      // wiped it after gate-success.
      final coachProvider = CoachProfileProvider();
      coachProvider.createFromRemoteProfile({
        'usTaxPerson': true,
        'nationality': 'US',
        'birth_year': 1990,
        'canton': 'GE',
      });
      expect(coachProvider.profile?.usTaxPerson, isTrue,
          reason: 'fixture sanity: profile carries usTaxPerson=true');
      expect(coachProvider.profile?.archetype, FinancialArchetype.expatUs,
          reason: 'fixture sanity: archetype resolves to expatUs');

      final router = _buildRouter();
      await tester.pumpWidget(_wrapWithProviders(
        coachProvider: coachProvider,
        router: router,
      ));
      await tester.pumpAndSettle();

      // The gate must have redirected — the coach landing key is gone
      // and the WaitlistScreen title is visible.
      expect(find.byKey(const Key('coach-landing-rendered')), findsNothing,
          reason: 'gate must have routed away from /coach');
      expect(find.text('Encore en chantier pour ton profil'), findsOneWidget,
          reason: '/waitlist screen must be rendered post-redirect');

      // Fill in the form + tap consent + submit.
      await tester.enterText(find.byType(TextField), 'expat@example.ch');
      await tester.tap(find.byKey(const Key('waitlist-consent-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('waitlist-cta')));
      await tester.pumpAndSettle();

      // Success screen visible.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget,
          reason: 'success state must render the check icon');

      // The clearAll callback must have wiped the profile (nLPD art. 6 —
      // plan 02-03 Task 6 contract).
      expect(coachProvider.profile, isNull,
          reason: 'onGateSuccess must invoke CoachProfileProvider.clearAll()');
      expect(coachProvider.hasProfile, isFalse);
    });

    testWidgets(
        'integration_swiss_native_flow_no_regression: nationality CH → '
        'gate does NOT fire → coach landing renders', (tester) async {
      final coachProvider = CoachProfileProvider();
      coachProvider.createFromRemoteProfile({
        'usTaxPerson': false,
        'nationality': 'CH',
        'birth_year': 1985,
        'canton': 'VD',
      });
      expect(coachProvider.profile?.archetype, FinancialArchetype.swissNative,
          reason: 'fixture sanity: swiss_native');

      final router = _buildRouter();
      await tester.pumpWidget(_wrapWithProviders(
        coachProvider: coachProvider,
        router: router,
      ));
      await tester.pumpAndSettle();

      // The coach landing must still render — no redirect.
      expect(find.byKey(const Key('coach-landing-rendered')), findsOneWidget,
          reason: 'swissNative must not be gated');
      expect(find.text('Encore en chantier pour ton profil'), findsNothing,
          reason: '/waitlist must not be rendered for swissNative');
      // Profile preserved (clearAll never called).
      expect(coachProvider.hasProfile, isTrue);
    });

    testWidgets(
        'integration_independent_no_lpp_safe_local_route: independent without '
        'LPP reaches coach shell, not waitlist', (tester) async {
      final coachProvider = CoachProfileProvider();
      coachProvider.createFromRemoteProfile({
        'usTaxPerson': false,
        'nationality': 'CH',
        'employment_status': 'independant',
        'birth_year': 1988,
        'canton': 'VD',
      });
      expect(
          coachProvider.profile?.archetype, FinancialArchetype.independentNoLpp,
          reason: 'fixture sanity: independent_no_lpp');

      final router = _buildRouter();
      await tester.pumpWidget(_wrapWithProviders(
        coachProvider: coachProvider,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coach-landing-rendered')), findsOneWidget,
          reason:
              'independent_no_lpp must reach the chat shell so the local no-LPP fallback can run');
      expect(find.text('Encore en chantier pour ton profil'), findsNothing,
          reason:
              '/waitlist must remain reserved for archetypes with no audited local guidance path');
      expect(coachProvider.hasProfile, isTrue,
          reason: 'route access must not clear the independent/no-LPP profile');
    });

    testWidgets(
        'integration_independent_with_lpp_still_waitlisted: independent with '
        'LPP remains gated at route layer', (tester) async {
      final profile = CoachProfile.defaults().copyWith(
        usTaxPerson: false,
        nationality: 'CH',
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 50000),
      );
      expect(profile.archetype, FinancialArchetype.independentWithLpp,
          reason: 'fixture sanity: independent_with_lpp');

      final coachProvider = CoachProfileProvider()..updateProfile(profile);
      final router = _buildRouter();
      await tester.pumpWidget(_wrapWithProviders(
        coachProvider: coachProvider,
        router: router,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coach-landing-rendered')), findsNothing,
          reason:
              'independent_with_lpp must not inherit the no-LPP route exception');
      expect(find.text('Encore en chantier pour ton profil'), findsOneWidget,
          reason: '/waitlist must render for independent_with_lpp');
      expect(coachProvider.hasProfile, isTrue,
          reason: 'waitlist redirect alone must not clear the profile');
    });

    testWidgets(
        'integration_kill_switch_bypass: enableCoachHardGate=false + '
        'usTaxPerson:true → gate decision still says block BUT route-level '
        'wrap bypasses the redirect', (tester) async {
      // Flip the kill switch BEFORE pumping so the gate site's
      // `gate.shouldBlock && FeatureFlags.enableCoachHardGate` short-circuits
      // to false.
      FeatureFlags.enableCoachHardGate = false;
      final coachProvider = CoachProfileProvider();
      coachProvider.createFromRemoteProfile({
        'usTaxPerson': true,
        'nationality': 'US',
        'birth_year': 1990,
        'canton': 'GE',
      });

      // Sanity: the pure decision helper still says block (the kill switch
      // does NOT change the gate evaluation — only the redirect/refusal
      // sites read the flag).
      final verdict = evaluateCoachArchetypeGate(coachProvider.profile!);
      expect(verdict.shouldBlock, isTrue,
          reason:
              'pure helper must remain flag-agnostic (plan 02-04 decision #5)');

      final router = _buildRouter();
      await tester.pumpWidget(_wrapWithProviders(
        coachProvider: coachProvider,
        router: router,
      ));
      await tester.pumpAndSettle();

      // Despite the gate saying block, the kill switch lets the coach
      // landing render — rollback contract from plan 02-04.
      expect(find.byKey(const Key('coach-landing-rendered')), findsOneWidget,
          reason:
              'kill switch off must bypass the redirect even when archetype is gated');
      expect(find.text('Encore en chantier pour ton profil'), findsNothing,
          reason: '/waitlist must NOT render when the kill switch is off');
    });

    test(
        'integration_legacy_user_grandfather: flag-only migration sets '
        'needsUsTaxPersonReOnboarding=true on legacy ambiguous profile WITHOUT '
        'rewriting the nationality field (Codex C1 HIGH data-truth contract)',
        () async {
      // Pre-seed SharedPreferences as if a legacy user (pre-01.5) opened
      // the app once : a profile is hydrated but carries null nationality
      // AND null usTaxPerson AND no migration_01_5_done flag.
      SharedPreferences.setMockInitialValues({});

      final coachProvider = CoachProfileProvider();
      // Create a deliberately-ambiguous legacy profile : every
      // archetype-discriminating signal is null. The plan 02-05 contract is
      // that the migration MUST flag this profile for re-onboarding without
      // injecting a Swiss nationality default (Codex C1 HIGH).
      coachProvider.createFromRemoteProfile({
        'birth_year': 1980,
        'canton': 'ZH',
        // No usTaxPerson, no nationality — legacy shape.
      });
      expect(coachProvider.profile?.usTaxPerson, isNull,
          reason: 'fixture sanity: legacy profile carries null usTaxPerson');
      expect(coachProvider.profile?.nationality, isNull,
          reason: 'fixture sanity: legacy profile carries null nationality');

      // Run the migration (the bootstrap hook lives in app.dart per plan
      // 02-05 ; here we invoke the service directly because the test
      // doesn't pump the full app).
      final migrated = await ProfileMigrationService()
          .grandfatherLegacyProfile(provider: coachProvider);
      expect(migrated, isTrue,
          reason: 'first run on a legacy profile must report migrated=true');

      // CRITICAL : the migration must NOT have written a nationality value.
      // This is the Codex C1 HIGH data-truth boundary fix from plan 02-05.
      expect(coachProvider.profile?.nationality, isNull,
          reason: 'data-truth boundary: migration MUST NOT inject nationality');
      expect(coachProvider.profile?.usTaxPerson, isNull,
          reason: 'data-truth boundary: migration MUST NOT inject usTaxPerson');

      // But the SharedPreferences flag must be set so the next OnboardingShell
      // entry routes to the FATCA Q step.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('coachProfile:needsUsTaxPersonReOnboarding'), isTrue,
          reason:
              'migration must mark the legacy profile for forced re-onboarding');
      expect(prefs.getBool('coachProfile:migration_01_5_done'), isTrue,
          reason: 'migration must set the done flag for idempotency');

      // Idempotency : a second invocation must be a no-op.
      final secondRun = await ProfileMigrationService()
          .grandfatherLegacyProfile(provider: coachProvider);
      expect(secondRun, isFalse,
          reason:
              'second run on a flagged profile must report migrated=false (idempotent)');
    });
  });
}
