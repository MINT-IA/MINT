import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart'
    show
        accountLifecycleAuthenticatedRedirect,
        accountLifecyclePublicEntryRedirect;
import 'package:mint_mobile/models/auth_lifecycle_state.dart';

void main() {
  group('account lifecycle public entry redirect', () {
    test('restored account skips landing and auth entry points', () {
      final lifecycle = AuthLifecycleState.signedInProfileLoading(
        userId: 'user-1',
        cloudSyncEnabled: false,
      );

      expect(
        accountLifecyclePublicEntryRedirect(lifecycle: lifecycle, path: '/'),
        '/home',
      );
      expect(
        accountLifecyclePublicEntryRedirect(
          lifecycle: lifecycle,
          path: '/auth/login',
        ),
        '/home',
      );
      expect(
        accountLifecyclePublicEntryRedirect(
          lifecycle: lifecycle,
          path: '/auth/register',
        ),
        '/home',
      );
    });

    test('guest local mode stays allowed on public entry points', () {
      final lifecycle = AuthLifecycleState.guestEmpty(installId: 'install-1');

      expect(
        accountLifecyclePublicEntryRedirect(lifecycle: lifecycle, path: '/'),
        isNull,
      );
      expect(
        accountLifecyclePublicEntryRedirect(
          lifecycle: lifecycle,
          path: '/auth/login',
        ),
        isNull,
      );
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
            lifecycle: AuthLifecycleState.signedInProfileLoading(
              userId: 'user-1',
              cloudSyncEnabled: false,
            ),
            path: '/home',
          ),
          isNull,
        );
      },
    );
  });
}
