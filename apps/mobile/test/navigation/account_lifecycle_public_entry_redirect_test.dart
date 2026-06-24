import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' show RouteBase;
import 'package:mint_mobile/app.dart'
    show
        accountLifecycleAndArchetypeRedirect,
        accountLifecycleAuthenticatedRedirect,
        accountLifecyclePublicEntryRedirect,
        routeScopeForRedirect;
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/router/route_scope.dart';
import 'package:mint_mobile/router/scoped_go_route.dart';

String? _redirect({
  required AuthLifecycleState lifecycle,
  required String path,
  RouteBase? topRoute,
  CoachProfile? profile,
  bool profileSettled = true,
}) {
  return accountLifecycleAndArchetypeRedirect(
    lifecycle: lifecycle,
    location: path,
    path: path,
    topRoute: topRoute,
    profile: profile,
    profileSettled: profileSettled,
  );
}

ScopedGoRoute _publicShellRoute(String path) {
  return ScopedGoRoute(
    path: path,
    scope: RouteScope.public,
    builder: (_, __) => throw UnimplementedError(),
  );
}

void main() {
  group('account lifecycle public entry redirect', () {
    test('restored account skips landing and auth entry points', () {
      final lifecycle = AuthLifecycleState.syncOffAccount(userId: 'user-1');

      for (final path in ['/', '/auth/login', '/auth/register']) {
        expect(
          accountLifecyclePublicEntryRedirect(
            lifecycle: lifecycle,
            path: path,
          ),
          '/home',
        );
      }
    });

    test('guest local mode stays allowed on public entry points', () {
      final lifecycle = AuthLifecycleState.guestEmpty(installId: 'install-1');

      for (final path in ['/', '/auth/login']) {
        expect(
          accountLifecyclePublicEntryRedirect(
            lifecycle: lifecycle,
            path: path,
          ),
          isNull,
        );
      }
    });

    test('fresh visitor stays on public entry points', () {
      final lifecycle = AuthLifecycleState.freshVisitor();

      expect(
        accountLifecyclePublicEntryRedirect(lifecycle: lifecycle, path: '/'),
        isNull,
      );
    });

    test('expired account session stays on public entry points', () {
      final lifecycle = AuthLifecycleState.sessionExpired();

      expect(
        accountLifecyclePublicEntryRedirect(
          lifecycle: lifecycle,
          path: '/auth/login',
        ),
        isNull,
      );
    });
  });

  group('account lifecycle authenticated redirect', () {
    test(
      'fresh visitor is sent to account creation with redirect preserved',
      () {
        final lifecycle = AuthLifecycleState.freshVisitor();

        expect(
          accountLifecycleAuthenticatedRedirect(
            lifecycle: lifecycle,
            path: '/home',
          ),
          '/auth/register?redirect=%2Fhome',
        );
      },
    );

    test(
      'expired account session is sent to login with redirect preserved',
      () {
        final lifecycle = AuthLifecycleState.sessionExpired();

        expect(
          accountLifecycleAuthenticatedRedirect(
            lifecycle: lifecycle,
            path: '/profile/bilan',
          ),
          '/auth/login?redirect=%2Fprofile%2Fbilan',
        );
      },
    );

    test(
      'explicit guest and restored account can enter authenticated routes',
      () {
        expect(
          accountLifecycleAuthenticatedRedirect(
            lifecycle: AuthLifecycleState.guestEmpty(installId: 'install-1'),
            path: '/home',
          ),
          isNull,
        );
        expect(
          accountLifecycleAuthenticatedRedirect(
            lifecycle: AuthLifecycleState.syncOffAccount(userId: 'user-1'),
            path: '/home',
          ),
          isNull,
        );
      },
    );
  });

  group('route scope fallback for redirect-only routes', () {
    test('keeps public redirect-only entry points public', () {
      expect(
        routeScopeForRedirect(path: '/start', topRoute: null),
        RouteScope.public,
      );
      expect(
        routeScopeForRedirect(path: '/anonymous/chat', topRoute: null),
        RouteScope.public,
      );
    });

    test('keeps unknown routes fail-closed', () {
      expect(
        routeScopeForRedirect(path: '/unregistered', topRoute: null),
        RouteScope.authenticated,
      );
    });

    test('uses explicit ScopedGoRoute scope when available', () {
      final route = ScopedGoRoute(
        path: '/scoped',
        scope: RouteScope.onboarding,
        builder: (_, __) => throw UnimplementedError(),
      );

      expect(
        routeScopeForRedirect(path: '/scoped', topRoute: route),
        RouteScope.onboarding,
      );
    });
  });

  group('account lifecycle + archetype hard gate', () {
    test('FATCA profile cannot enter a public-scoped app shell route', () {
      final lifecycle = AuthLifecycleState.signedInProfileLoading(
        userId: 'user-1',
        cloudSyncEnabled: false,
      );
      final publicCoachRoute = ScopedGoRoute(
        path: '/coach/chat',
        scope: RouteScope.public,
        builder: (_, __) => throw UnimplementedError(),
      );

      expect(
        accountLifecycleAndArchetypeRedirect(
          lifecycle: lifecycle,
          location: '/coach/chat',
          path: '/coach/chat',
          topRoute: publicCoachRoute,
          profile: CoachProfile.fromWizardAnswers({
            'q_us_tax_person': true,
          }),
        ),
        '/waitlist',
      );
    });

    test('restored account without settled profile is sent to onboarding', () {
      final lifecycle = AuthLifecycleState.signedInProfileMissing(
        userId: 'user-1',
        cloudSyncEnabled: false,
      );

      expect(
        _redirect(
          lifecycle: lifecycle,
          path: '/coach/chat',
          topRoute: _publicShellRoute('/coach/chat'),
        ),
        '/onb',
      );
    });

    test('profile-ready account waits on landing during profile hydration', () {
      final lifecycle = AuthLifecycleState.syncOffAccount(userId: 'user-1');

      expect(
        _redirect(
          lifecycle: lifecycle,
          path: '/',
          profileSettled: false,
        ),
        isNull,
      );
    });

    test('explicit guest without local profile cannot enter shell', () {
      final lifecycle = AuthLifecycleState.guestEmpty(installId: 'install-1');

      expect(
        _redirect(
          lifecycle: lifecycle,
          path: '/home',
        ),
        '/onb',
      );
    });
  });
}
