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
    // Phase 52.1 N-3: 3s prod stability delay would slow tests; use
    // Duration.zero for non-timing-specific cases.
    MigrationNoticeListener.stabilityDelay = Duration.zero;
  });

  tearDown(() {
    // Restore production default so accidental cross-test bleed doesn't
    // hide a real timing regression.
    MigrationNoticeListener.stabilityDelay = const Duration(seconds: 3);
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
    // Phase 52.1 N-3 timing: stabilityDelay is Duration.zero in tests
    // (set in setUp), but the Timer still posts on the next event-loop
    // iteration. Use pumpAndSettle with a small Duration to drain the
    // Timer + the async _attemptShow + post-frame callback.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

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

  // Phase 52.1 N-3 — assert the re-timing: if isLoading flips back true
  // during the stability window, the pending Timer is cancelled and the
  // SnackBar does NOT fire. This is the specific regression class
  // « toast appears mid-splash / mid-refetch » we're guarding against.
  testWidgets(
    'isLoading flips back true during stability window → no SnackBar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      MigrationNoticeListener.resetForTesting();
      MigrationNoticeListener.stabilityDelay =
          const Duration(milliseconds: 500);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final auth = _MockAuthProvider()
        ..isLoggedIn = true
        ..isLoading = false;

      await tester.pumpWidget(
        _buildHarness(auth: auth, messengerKey: messengerKey),
      );
      await tester.pump();
      // Mid-window: loading flips back true (e.g. profile refetch).
      await tester.pump(const Duration(milliseconds: 200));
      auth.isLoading = true;
      auth.notifyListeners();
      // Wait past what would have been the original fire time.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('Confidentialité'),
        findsNothing,
        reason:
            'cancelling Timer mid-window must prevent the toast — '
            'this is the actual N-3 contract.',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(MigrationNoticeListener.prefsKeyShown),
        isNot(true),
        reason: 'shown flag must NOT be set when the gate cancelled the show',
      );

      // Cleanup pending timer to avoid post-test « pending timer » error.
      auth.isLoading = false;
      auth.notifyListeners();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    },
  );
}
