// Bascule 4 — beat b4_entry_local : l'entrée canonique.
//
// En préversion, l'entrée active le mode local via l'autorité lifecycle
// PUIS ouvre la coque — jamais l'inverse, et jamais le wizard. Hors
// préversion, le comportement legacy est strictement inchangé.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/routes/legacy_onboarding_entry.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth({this.failActivation = false, this.blockNavigation = false});

  final bool failActivation;
  final bool blockNavigation;
  bool localModeEnabled = false;
  AuthLifecycleState _lifecycle = AuthLifecycleState.freshVisitor();

  @override
  AuthLifecycleState get authLifecycle => _lifecycle;

  @override
  Future<void> enableLocalMode() async {
    if (failActivation) throw StateError('activation failed');
    localModeEnabled = true;
    _lifecycle = blockNavigation
        ? AuthLifecycleState.sessionExpired()
        : AuthLifecycleState.guestEmpty(installId: 'test-install');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => PreviewShellPolicy.debugOverride = null);

  Future<_FakeAuth> pumpEntry(
    WidgetTester tester, {
    required bool preview,
    bool failActivation = false,
    bool blockNavigation = false,
  }) async {
    PreviewShellPolicy.debugOverride =
        PreviewShellPolicy.forTest(isPreviewShell: preview);
    final auth = _FakeAuth(
      failActivation: failActivation,
      blockNavigation: blockNavigation,
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => LegacyOnboardingEntry.open(context),
              child: const Text('entrer'),
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('coque-jumeau')),
        ),
        GoRoute(
          path: '/onb',
          builder: (_, __) => const Scaffold(body: Text('wizard-legacy')),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets(
      'in preview the landing CTA enables durable local mode through the '
      'lifecycle authority before navigating to the shell', (tester) async {
    final auth = await pumpEntry(tester, preview: true);
    await tester.tap(find.text('entrer'));
    await tester.pumpAndSettle();

    expect(auth.localModeEnabled, isTrue,
        reason: "le mode local est activé par l'autorité lifecycle");
    expect(auth.authLifecycle.allowsMainNavigation, isTrue);
    expect(find.text('coque-jumeau'), findsOneWidget);
    expect(find.text('wizard-legacy'), findsNothing,
        reason: 'le wizard n\'est JAMAIS traversé en préversion');
  });

  testWidgets('a failed local activation never navigates to the shell',
      (tester) async {
    final auth = await pumpEntry(tester, preview: true, failActivation: true);
    await tester.tap(find.text('entrer'));
    await tester.pumpAndSettle();

    expect(auth.localModeEnabled, isFalse);
    expect(find.text('coque-jumeau'), findsNothing,
        reason: 'aucune coque ouverte sans mode local durable');
    expect(find.text('entrer'), findsOneWidget,
        reason: "l'utilisateur reste où il était");
  });

  testWidgets(
      'an activation that does not allow navigation never opens the shell',
      (tester) async {
    await pumpEntry(tester, preview: true, blockNavigation: true);
    await tester.tap(find.text('entrer'));
    await tester.pumpAndSettle();
    expect(find.text('coque-jumeau'), findsNothing,
        reason: 'un lifecycle qui interdit la navigation ferme la porte');
  });

  testWidgets(
      'outside preview the entry keeps the legacy onboarding behaviour',
      (tester) async {
    final auth = await pumpEntry(tester, preview: false);
    await tester.tap(find.text('entrer'));
    await tester.pumpAndSettle();

    expect(find.text('wizard-legacy'), findsOneWidget,
        reason: 'hors préversion : comportement INCHANGÉ');
    expect(auth.localModeEnabled, isFalse,
        reason: 'aucune activation implicite hors préversion');
  });
}
