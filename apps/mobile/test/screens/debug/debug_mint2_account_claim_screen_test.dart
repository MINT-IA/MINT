import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/debug/debug_mint2_account_claim_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    ApiService.setHttpClientForTesting(null);
    secureStorage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) secureStorage[key] = value;
          return null;
        case 'read':
          return key == null ? null : secureStorage[key];
        case 'delete':
          if (key != null) secureStorage.remove(key);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    ApiService.setHttpClientForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('E2E account claim session survives install lifecycle restore gate',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(InstallLifecycleService.securePurgePendingKey, true);

    await DebugMint2AccountClaimScreen.restoreSessionForTest();

    expect(prefs.getBool(InstallLifecycleService.installMarkerKey), isTrue);
    expect(prefs.getBool(InstallLifecycleService.securePurgePendingKey), isNull);
    expect(prefs.getBool('auth_local_mode'), isFalse);
    expect(await AuthService.isLoggedIn(), isTrue);

    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          if (request.url.path == '/api/v1/profiles/me') {
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"detail":"not found"}', 404);
        }),
      ),
    );

    final authProvider = AuthProvider();
    await authProvider.checkAuth();

    expect(authProvider.userId, 'e2e-mint2-axis-user');
    expect(
      authProvider.authLifecycle.state,
      AuthLifecycleKind.signedInProfileMissing,
    );
  });
}
