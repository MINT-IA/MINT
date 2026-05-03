import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/widgets/auth/migration_notice_listener.dart';

// Phase 52 T-52-04 — widget test for the one-time migration notification.
//
// Three cases per the design panel spec:
//  1. legacy user (auth_local_mode = false, no migration_shown key)
//     → SnackBar shows + prefs key set
//  2. re-mount with migration_shown = true → no SnackBar
//  3. new user (no auth_local_mode key) → no SnackBar

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool isLoggedIn = true;
  @override
  bool isLoading = false;

  // Unused getters / methods — return defaults / throw on call so the
  // test surfaces accidental coupling.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildHarness({
  required AuthProvider auth,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
  VoidCallback? onCtaTap,
}) {
  return MaterialApp(
    scaffoldMessengerKey: messengerKey,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: Builder(
        builder: (ctx) => MigrationNoticeListener(
          getMessenger: () => messengerKey.currentState,
          getNavContext: () => ctx,
          onCtaTap: onCtaTap ?? () {},
          child: const Scaffold(body: Text('home')),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MigrationNoticeListener.resetForTesting();
  });

  testWidgets('legacy user → SnackBar shows + migration_shown set', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_local_mode': false});
    MigrationNoticeListener.resetForTesting();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    final auth = _MockAuthProvider();

    await tester.pumpWidget(
      _buildHarness(auth: auth, messengerKey: messengerKey),
    );
    await tester.pump();
    // Allow the async _check() + post-frame callback to fire.
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Confidentialité'),
      findsOneWidget,
      reason: 'SnackBar with migration toast should be visible',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(MigrationNoticeListener.prefsKeyShown),
      true,
      reason: 'shown flag must be persisted',
    );
  });

  testWidgets('migration_shown already true → no SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_local_mode': false,
      MigrationNoticeListener.prefsKeyShown: true,
    });
    MigrationNoticeListener.resetForTesting();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    final auth = _MockAuthProvider();

    await tester.pumpWidget(
      _buildHarness(auth: auth, messengerKey: messengerKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Confidentialité'),
      findsNothing,
      reason: 'no SnackBar should fire when migration was already shown',
    );
  });

  testWidgets('new user (no auth_local_mode key) → no SnackBar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    MigrationNoticeListener.resetForTesting();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    final auth = _MockAuthProvider();

    await tester.pumpWidget(
      _buildHarness(auth: auth, messengerKey: messengerKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Confidentialité'),
      findsNothing,
      reason: 'new users (no auth_local_mode persisted) must not see toast',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(MigrationNoticeListener.prefsKeyShown),
      false,
      reason: 'shown flag must not be set when toast did not fire',
    );
  });
}
