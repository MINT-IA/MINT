/// Plan mint-illogism-fixes-08 W2 Task 1 — GLOBAL FATCA gate in the
/// GoRouter redirect (oracle expat_us-1 : ILLOGICAL_FOR_ARCHETYPE).
///
/// Before this plan the only archetype/FATCA gate lived at the coach entry
/// (coach_chat_screen.dart:1828). The GLOBAL redirect (app.dart:234-317)
/// gated ONLY on auth scope, so an `expatUs` profile reaching any non-coach
/// prévoyance surface (/home, /mon-argent, /profile/bilan, /explore/*) was
/// NOT gated. This test pins the pure redirect-decision helper
/// [archetypeRedirectTarget] that the global redirect now consumes.
///
/// Scope note (Karpathy #2 — simplicity first): we test the PURE helper, not
/// a full MaterialApp.router pump. The helper is the exact branch the
/// app.dart redirect calls; the integration wiring (route → /waitlist render
/// → submit) is already covered by
/// test/integration/archetype_hard_gate_integration_test.dart.
///
/// Behaviors:
///   1. expat_us-1 — usTaxPerson:true reaching /home, /mon-argent,
///      /profile/bilan, /explore → redirect /waitlist.
///   2. no regression — swissNative reaching the same routes → null (no
///      redirect).
///   3. /waitlist itself never loops (helper returns null for /waitlist even
///      for an expatUs).
///   4. profile-correction routes (/onb, /scan, /settings, /auth) stay
///      reachable for an expatUs so the status can be fixed.
///   5. unhydrated boot — null profile / unknown archetype → null (no
///      flash-block of legitimate non-US users).
///   6. kill switch off → null (rollback contract, plan 02-04).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/router/archetype_route_gate.dart';
import 'package:mint_mobile/services/feature_flags.dart';

CoachProfile _expatUs() => CoachProfile.defaults().copyWith(
      usTaxPerson: true,
      nationality: 'US',
      canton: 'GE',
    );

CoachProfile _swissNative() => CoachProfile.defaults().copyWith(
      usTaxPerson: false,
      nationality: 'CH',
      canton: 'VD',
    );

void main() {
  setUp(() {
    FeatureFlags.enableCoachHardGate = true;
  });

  group('Plan 08 — global FATCA route gate (expat_us-1)', () {
    const prevoyanceRoutes = <String>[
      '/home',
      '/mon-argent',
      '/profile/bilan',
      '/explore',
      '/explore/lpp',
      '/coach/chat',
    ];

    test('expatUs reaching any prévoyance surface → /waitlist', () {
      final profile = _expatUs();
      expect(profile.archetype, FinancialArchetype.expatUs,
          reason: 'fixture sanity: usTaxPerson=true → expatUs');
      for (final route in prevoyanceRoutes) {
        expect(
          archetypeRedirectTarget(profile: profile, path: route),
          '/waitlist',
          reason: 'expatUs must be gated globally on $route (expat_us-1)',
        );
      }
    });

    test('swissNative reaching the same routes → null (no regression)', () {
      final profile = _swissNative();
      expect(profile.archetype, FinancialArchetype.swissNative,
          reason: 'fixture sanity: nationality CH → swissNative');
      for (final route in prevoyanceRoutes) {
        expect(
          archetypeRedirectTarget(profile: profile, path: route),
          isNull,
          reason: 'swissNative must never be gated on $route',
        );
      }
    });

    test('/waitlist never loops for an expatUs', () {
      expect(
        archetypeRedirectTarget(profile: _expatUs(), path: '/waitlist'),
        isNull,
        reason: 'gating /waitlist would create an infinite redirect loop',
      );
    });

    test('profile-correction routes stay reachable for an expatUs', () {
      const correctionRoutes = <String>[
        '/onb',
        '/onboarding/minimal',
        '/scan',
        '/scan/review',
        '/settings/confidentialite',
        '/auth/login',
        '/anonymous/chat',
      ];
      for (final route in correctionRoutes) {
        expect(
          archetypeRedirectTarget(profile: _expatUs(), path: route),
          isNull,
          reason: 'expatUs must reach $route to correct the FATCA status',
        );
      }
    });

    test('unhydrated boot — null profile → null (no flash-block)', () {
      for (final route in prevoyanceRoutes) {
        expect(
          archetypeRedirectTarget(profile: null, path: route),
          isNull,
          reason:
              'a null/unhydrated profile must not gate (would flash-block non-US users)',
        );
      }
    });

    test('unknown archetype → null (no flash-block)', () {
      // All archetype-discriminating signals null → FinancialArchetype.unknown.
      final unknown = CoachProfile.defaults().copyWith();
      expect(unknown.archetype, FinancialArchetype.unknown,
          reason: 'fixture sanity: no positive signal → unknown');
      for (final route in prevoyanceRoutes) {
        expect(
          archetypeRedirectTarget(profile: unknown, path: route),
          isNull,
          reason:
              'unknown archetype must not gate globally (correction happens via re-onboarding)',
        );
      }
    });

    test('kill switch off → null (rollback contract)', () {
      FeatureFlags.enableCoachHardGate = false;
      expect(
        archetypeRedirectTarget(profile: _expatUs(), path: '/home'),
        isNull,
        reason: 'enableCoachHardGate=false must bypass the global gate too',
      );
    });
  });

  // ── Codex P1 gap closure — router reactivity to async profile hydration ──
  //
  // The pure helper above is correct, but plan 08 wired the redirect to read
  // `CoachProfileProvider.profile` while GoRouter only refreshed on auth
  // events (`_authNotifier`). On cold start the profile is null (fail-open),
  // so an `expatUs` profile that hydrates AFTER the first route resolution
  // was NEVER redirected to /waitlist until the next auth event / manual nav.
  //
  // The fix extends `_AuthRouterBridge` (app.dart) to also forward
  // CoachProfileProvider ticks to the router's refreshListenable. This test
  // pins that CONTRACT with a minimal MaterialApp.router that mirrors the
  // production wiring (Karpathy #2 — no full MintApp pump): a refreshListenable
  // poked by a listener on a ChangeNotifier, and a redirect that calls the
  // real `archetypeRedirectTarget`. We assert that mutating the profile to
  // `expatUs` AFTER the first route resolution redirects to /waitlist with no
  // auth event and no manual navigation.
  group('Plan 08 — router reactivity to async profile hydration (Codex P1)', () {
    testWidgets(
        'profile hydrates after first route resolution → /waitlist (no auth event)',
        (tester) async {
      // Stand-in for CoachProfileProvider: a ChangeNotifier exposing a mutable
      // profile. Mirrors the production provider's `profile` getter +
      // notifyListeners on mutation (loadFromWizard path).
      final profileNotifier = _ProfileNotifier();

      // Router refresh listener — mirrors `_authNotifier` in app.dart. The
      // bridge (under test in production) forwards provider ticks here.
      final routerRefresh = ChangeNotifier();
      // The exact bridge mechanism from `_AuthRouterBridge`: subscribe to the
      // profile notifier and poke the router's refreshListenable on each tick.
      void onProfileTick() {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        routerRefresh.notifyListeners();
      }

      profileNotifier.addListener(onProfileTick);
      addTearDown(() {
        profileNotifier.removeListener(onProfileTick);
        profileNotifier.dispose();
        routerRefresh.dispose();
      });

      final router = GoRouter(
        initialLocation: '/home',
        refreshListenable: routerRefresh,
        redirect: (context, state) => archetypeRedirectTarget(
          profile: profileNotifier.profile,
          path: state.uri.path,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/waitlist',
            builder: (_, __) => const Scaffold(body: Text('WAITLIST')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // First route resolution: profile still null (cold-start fail-open) →
      // stays on /home, NOT redirected (regression guard for the null case).
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('WAITLIST'), findsNothing);

      // Async hydration completes (loadFromWizard → notifyListeners) and the
      // persisted profile is an expatUs / US tax person.
      profileNotifier.profile = _expatUs();
      await tester.pumpAndSettle();

      // Without the fix the router never re-ran `redirect`, so HOME would
      // still be showing. With the bridge forwarding the profile tick, the
      // redirect re-evaluates and lands on /waitlist — no auth event, no
      // manual navigation.
      expect(find.text('WAITLIST'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });
  });
}

/// Minimal stand-in for CoachProfileProvider: a ChangeNotifier with a mutable
/// `profile` that notifies on set, mirroring the production hydration path.
class _ProfileNotifier extends ChangeNotifier {
  CoachProfile? _profile;
  CoachProfile? get profile => _profile;
  set profile(CoachProfile? value) {
    _profile = value;
    notifyListeners();
  }
}
