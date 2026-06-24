/// Home gate contract tests.
///
/// The main navigation gate is now driven by [AuthLifecycleState], not by the
/// overloaded `isLoggedIn || isLocalMode` pair. This prevents a fresh visitor
/// from being treated as a guest dossier while preserving explicit guest mode
/// and signed-in account access.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Home route gate — lifecycle contract', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WidgetsFlutterBinding.ensureInitialized();
    });

    test('fresh visitor does not enter main navigation', () {
      final state = AuthLifecycleState.freshVisitor();

      expect(state.allowsMainNavigation, isFalse);
      expect(state.accessMode, AuthAccessMode.visitor);
    });

    test('explicit guest local mode enters main navigation', () {
      final state = AuthLifecycleState.guestEmpty(installId: 'install-1');

      expect(state.allowsMainNavigation, isTrue);
      expect(state.accessMode, AuthAccessMode.guestLocal);
      expect(state.activeDataScope, AuthDataScope.guest('install-1'));
    });

    test('profile-ready account enters main navigation regardless of sync mode',
        () {
      final syncOff = AuthLifecycleState.syncOffAccount(userId: 'u1');
      final syncOn = AuthLifecycleState.cloudSyncOnAccount(userId: 'u1');

      expect(syncOff.allowsMainNavigation, isTrue);
      expect(syncOn.allowsMainNavigation, isTrue);
      expect(syncOff.hasAccountSession, isTrue);
      expect(syncOn.hasAccountSession, isTrue);
      expect(syncOff.accessMode, AuthAccessMode.account);
      expect(syncOn.accessMode, AuthAccessMode.account);
    });

    test('profile-loading account cannot enter main navigation yet', () {
      final state = AuthLifecycleState.signedInProfileLoading(
        userId: 'u1',
        cloudSyncEnabled: false,
      );

      expect(state.allowsMainNavigation, isFalse);
      expect(state.hasAccountSession, isTrue);
    });

    test(
      'guest mode is main-navigation capable but not an account session',
      () {
        final state = AuthLifecycleState.guestEmpty(installId: 'install-1');

        expect(state.allowsMainNavigation, isTrue);
        expect(state.hasAccountSession, isFalse);
      },
    );

    test('expired account session cannot enter main navigation', () {
      final state = AuthLifecycleState.sessionExpired();

      expect(state.allowsMainNavigation, isFalse);
      expect(state.hasAccountSession, isFalse);
    });

    test(
      'AuthProvider default object is not enough to enter main navigation',
      () {
        final auth = AuthProvider();

        expect(auth.authLifecycle.state, AuthLifecycleKind.sessionRestoring);
        expect(auth.authLifecycle.allowsMainNavigation, isFalse);
      },
    );
  });
}
