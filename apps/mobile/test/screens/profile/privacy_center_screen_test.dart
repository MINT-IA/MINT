import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool isLoggedIn = true;

  @override
  AuthLifecycleState get authLifecycle =>
      AuthLifecycleState.cloudSyncOnAccount(userId: 'test-user');

  bool deleteAccountCalled = false;

  @override
  Future<bool> deleteAccount() async {
    deleteAccountCalled = true;
    isLoggedIn = false;
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildPrivacyCenterApp(_FakeAuthProvider authProvider) {
  final router = GoRouter(
    initialLocation: '/profile/privacy',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (_, __) => const PrivacyCenterScreen(),
      ),
    ],
  );

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
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
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          if (request.url.path == '/api/v1/consents') {
            return http.Response(
              '{"consents":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"detail":"not found"}', 404);
        }),
      ),
    );
  });

  tearDown(() {
    ApiService.setHttpClientForTesting(null);
  });

  testWidgets(
    'logged-in privacy center exposes account deletion and confirms it',
    (tester) async {
      final authProvider = _FakeAuthProvider();

      await tester.pumpWidget(_buildPrivacyCenterApp(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Ma vie privée'), findsOneWidget);
      expect(find.text('Supprimer mon compte'), findsOneWidget);

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le compte ?'), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(authProvider.deleteAccountCalled, isTrue);
      expect(find.text('home'), findsOneWidget);
    },
  );
}
