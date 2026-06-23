import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/profile_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool isLoggedIn = true;

  bool deleteAccountCalled = false;

  @override
  Future<bool> deleteAccount() async {
    deleteAccountCalled = true;
    isLoggedIn = false;
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {
    isLoggedIn = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildDrawerApp({
  required AuthProvider authProvider,
  CoachProfileProvider? coachProfileProvider,
}) {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return Scaffold(
            key: scaffoldKey,
            endDrawer: const ProfileDrawer(),
            body: Center(
              child: TextButton(
                key: const ValueKey('open-profile-drawer'),
                onPressed: () => scaffoldKey.currentState!.openEndDrawer(),
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<CoachProfileProvider>.value(
        value: coachProfileProvider ?? CoachProfileProvider(),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.single.resetPhysicalSize();
    binding.platformDispatcher.views.single.resetDevicePixelRatio();
  });

  testWidgets('logged-in drawer exposes account deletion', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;

    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(_buildDrawerApp(authProvider: authProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-profile-drawer')));
    await tester.pumpAndSettle();

    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('account deletion confirmation calls auth provider',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;

    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(_buildDrawerApp(authProvider: authProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-profile-drawer')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le compte ?'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(authProvider.deleteAccountCalled, isTrue);
  });
}
