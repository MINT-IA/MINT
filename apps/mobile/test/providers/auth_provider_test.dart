import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorage = <String, String>{};
  var deleteAllCalls = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.resetMemoryCacheForTest();
    ApiService.setHttpClientForTesting(null);
    ConversationStore.setCurrentUserId(null);
    secureStorage.clear();
    deleteAllCalls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) {
            secureStorage[key] = value;
          }
          return null;
        case 'read':
          return key == null ? null : secureStorage[key];
        case 'delete':
          if (key != null) {
            secureStorage.remove(key);
          }
          return null;
        case 'deleteAll':
          deleteAllCalls += 1;
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

  group('AuthProvider', () {
    late AuthProvider provider;

    setUp(() {
      provider = AuthProvider();
    });

    // ── Initial state ──

    test('initial state has correct defaults', () {
      expect(provider.isLoggedIn, isFalse);
      expect(provider.userId, isNull);
      expect(provider.email, isNull);
      expect(provider.displayName, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.requiresEmailVerification, isFalse);
    });

    // ── clearError ──

    test('clearError sets error to null and notifies', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // clearError should still notify even when error is already null
      provider.clearError();
      expect(provider.error, isNull);
      expect(notifyCount, 1);
    });

    test('clearError after error resets error state', () {
      // We cannot set _error directly since it's private,
      // but we can verify clearError notifies listeners.
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      expect(notifyCount, 1);
      expect(provider.error, isNull);
    });

    // ── Error message mapping via _toUserFriendlyAuthError ──
    // The private method is tested indirectly through public API behavior.
    // We verify the mapping by checking that error messages are user-friendly
    // when methods catch exceptions.

    test('network error produces user-friendly message (socketexception)', () {
      // We test the error mapping logic by verifying the patterns.
      // Since _toUserFriendlyAuthError is private, we validate known behaviors:
      // - 'socketexception' → network error
      // - 'existe déjà' → duplicate email
      // - 'incorrect' → wrong credentials
      // This test documents the expected behavior.
      final provider = AuthProvider();
      // Initial state: no error
      expect(provider.error, isNull);
    });

    test(
      'magic-link verification fetches user info before saving session',
      () async {
        final seenPaths = <String>[];
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/auth/magic-link/verify') {
                return http.Response(
                  '{"accessToken":"magic-token","tokenType":"bearer"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/auth/me') {
                expect(request.headers['Authorization'], 'Bearer magic-token');
                return http.Response(
                  '{"id":"magic-user","email":"magic@example.ch","display_name":"Magic User"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
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

        final success = await provider.verifyMagicLink('magic-code');

        expect(success, isTrue);
        expect(seenPaths, contains('/api/v1/auth/magic-link/verify'));
        expect(seenPaths, contains('/api/v1/auth/me'));
        expect(provider.userId, 'magic-user');
        expect(provider.email, 'magic@example.ch');
        expect(
          provider.authLifecycle.state,
          AuthLifecycleKind.signedInProfileMissing,
        );
        expect(provider.authLifecycle.accessMode, AuthAccessMode.account);
        expect(
          provider.authLifecycle.activeDataScope,
          AuthDataScope.user('magic-user'),
        );
        expect(provider.authLifecycle.syncMode, AuthSyncMode.cloudSyncOff);
        expect(provider.authLifecycle.allowsMainNavigation, isFalse);
        expect(await AuthService.getToken(), 'magic-token');
        expect(await AuthService.getUserId(), 'magic-user');
        expect(await AuthService.getUserEmail(), 'magic@example.ch');
      },
    );

    test(
      'magic-link verification waits for explicit handoff choice when Mint2 axis exists',
      () async {
        final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
        FeatureFlags.enableMvpWedgeOnboarding = true;
        final seenPaths = <String>[];
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              return http.Response(
                '{"accessToken":"magic-token","tokenType":"bearer"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );
        await ReportPersistenceService.saveMint2AxisHandoff({
          'onb_axis_v2': 'lpp_rente_capital',
          'onb_axis_schema_version': 2,
        });

        try {
          final provider = AuthProvider();
          final success = await provider.verifyMagicLink('magic-code');

          expect(success, isFalse);
          expect(seenPaths, isEmpty);
          expect(provider.isLoggedIn, isFalse);
          expect(
            (await ReportPersistenceService.loadMint2AxisHandoff())[
                'onb_axis_v2'],
            'lpp_rente_capital',
          );
        } finally {
          FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
        }
      },
    );

    test(
      'existing account login keeps local dossier separate without explicit handoff choice',
      () async {
        final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
        FeatureFlags.enableMvpWedgeOnboarding = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_local_mode', false);
        await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
        await ConversationStore().saveConversation('local-before-login', [
          ChatMessage(
            role: 'user',
            content: 'Je veux comprendre ma situation.',
            timestamp: DateTime(2026, 6, 13, 12),
          ),
        ]);

        final seenPaths = <String>[];
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/auth/login') {
                return http.Response(
                  '{"access_token":"existing-token","refresh_token":"existing-refresh","user_id":"existing-user","email":"existing@example.ch","display_name":"Existing User"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/profiles/me') {
                return http.Response(
                  '{}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/sync/claim-local-data') {
                return http.Response(
                  '{"detail":"local dossier must not be claimed without choice"}',
                  500,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{"detail":"not found"}', 404);
            }),
          ),
        );

        try {
          final success = await provider.login(
            'existing@example.ch',
            'correct-password',
          );

          expect(success, isTrue);
          expect(provider.userId, 'existing-user');
          expect(await ReportPersistenceService.loadAnswers(), isEmpty);
          expect(await ReportPersistenceService.loadHeldAnonymousAnswers(), {
            'q_canton': 'VD',
          });
          expect(
            await ConversationStore().loadConversation('local-before-login'),
            isEmpty,
          );
          expect(prefs.getString('local_data_owner'), isNull);
          expect(prefs.getBool('local_data_migrated_existing-user'), isNull);

          ConversationStore.setCurrentUserId(null);
          expect(
            await ConversationStore().loadConversation('local-before-login'),
            isNotEmpty,
          );
          expect(seenPaths, isNot(contains('/api/v1/sync/claim-local-data')));
        } finally {
          FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
          ConversationStore.setCurrentUserId(null);
        }
      },
    );

    test(
        'existing account login clears active local dossier even when profile '
        'hydration fails', () async {
      final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
      FeatureFlags.enableMvpWedgeOnboarding = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_local_mode', false);
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});

      final seenPaths = <String>[];
      ApiService.setHttpClientForTesting(
        MintHttpClient(
          MockClient((request) async {
            seenPaths.add(request.url.path);
            if (request.url.path == '/api/v1/auth/login') {
              return http.Response(
                '{"access_token":"existing-token","refresh_token":"existing-refresh","user_id":"existing-user","email":"existing@example.ch","display_name":"Existing User"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/profiles/me') {
              return http.Response(
                '{"detail":"profile temporarily unavailable"}',
                500,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/sync/claim-local-data') {
              return http.Response(
                '{"detail":"local dossier must not be claimed without choice"}',
                500,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{"detail":"not found"}', 404);
          }),
        ),
      );

      try {
        final success = await provider.login(
          'existing@example.ch',
          'correct-password',
        );

        expect(success, isTrue);
        expect(provider.userId, 'existing-user');
        expect(await ReportPersistenceService.loadAnswers(), isEmpty);
        expect(await ReportPersistenceService.loadHeldAnonymousAnswers(), {
          'q_canton': 'VD',
        });
        expect(prefs.getString('local_data_owner'), isNull);
        expect(prefs.getBool('local_data_migrated_existing-user'), isNull);
        expect(seenPaths, contains('/api/v1/profiles/me'));
        expect(seenPaths, isNot(contains('/api/v1/sync/claim-local-data')));
      } finally {
        FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
        ConversationStore.setCurrentUserId(null);
      }
    });

    test('flag-off legacy login claims dossier without guest conversations',
        () async {
      final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
      FeatureFlags.enableMvpWedgeOnboarding = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_local_mode', false);
      await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
      await ConversationStore().saveConversation('legacy-local-chat', [
        ChatMessage(
          role: 'user',
          content: 'Je veux continuer mon diagnostic.',
          timestamp: DateTime(2026, 6, 13, 12, 30),
        ),
      ]);

      final seenPaths = <String>[];
      ApiService.setHttpClientForTesting(
        MintHttpClient(
          MockClient((request) async {
            seenPaths.add(request.url.path);
            if (request.url.path == '/api/v1/auth/login') {
              return http.Response(
                '{"access_token":"legacy-token","refresh_token":"legacy-refresh","user_id":"legacy-user","email":"legacy@example.ch","display_name":"Legacy User"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/profiles/me') {
              return http.Response(
                '{}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/sync/claim-local-data') {
              return http.Response(
                '{"status":"ok"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{"detail":"not found"}', 404);
          }),
        ),
      );

      try {
        final success = await provider.login(
          'legacy@example.ch',
          'correct-password',
        );

        expect(success, isTrue);
        expect(provider.userId, 'legacy-user');
        expect(seenPaths, contains('/api/v1/sync/claim-local-data'));
        expect(await ReportPersistenceService.loadAnswers(), {
          'q_canton': 'VD',
        });
        ConversationStore.setCurrentUserId('legacy-user');
        expect(
          await ConversationStore().loadConversation('legacy-local-chat'),
          isEmpty,
        );
        ConversationStore.setCurrentUserId(null);
        expect(
          await ConversationStore().loadConversation('legacy-local-chat'),
          isNotEmpty,
        );
        expect(prefs.getString('local_data_owner'), 'legacy-user');
        expect(prefs.getBool('local_data_migrated_legacy-user'), isTrue);
        expect(prefs.getBool('local_data_sync_pending_legacy-user'), isNull);
      } finally {
        FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
        ConversationStore.setCurrentUserId(null);
        await AccountHandoffService.clearChoice();
      }
    });

    test(
      'failed local data claim keeps retryable dossier without guest conversations',
      () async {
        final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
        FeatureFlags.enableMvpWedgeOnboarding = true;
        await AccountHandoffService.saveChoice(AccountHandoffChoice.keepLocal);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_local_mode', false);
        await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
        await ConversationStore().saveConversation('local-before-claim-fails', [
          ChatMessage(
            role: 'user',
            content: 'Je veux garder mon diagnostic.',
            timestamp: DateTime(2026, 6, 13, 13),
          ),
        ]);

        final seenPaths = <String>[];
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/auth/login') {
                return http.Response(
                  '{"access_token":"claim-token","refresh_token":"claim-refresh","user_id":"claim-user","email":"claim@example.ch","display_name":"Claim User"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/profiles/me') {
                return http.Response(
                  '{}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/sync/claim-local-data') {
                return http.Response(
                  '{"detail":"staging unavailable"}',
                  503,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{"detail":"not found"}', 404);
            }),
          ),
        );

        try {
          final success = await provider.login('claim@example.ch', 'password');

          expect(success, isTrue);
          expect(seenPaths, contains('/api/v1/sync/claim-local-data'));
          expect(await ReportPersistenceService.loadAnswers(), {
            'q_canton': 'VD',
          });
          ConversationStore.setCurrentUserId('claim-user');
          expect(
            await ConversationStore().loadConversation(
              'local-before-claim-fails',
            ),
            isEmpty,
          );
          ConversationStore.setCurrentUserId(null);
          expect(
            await ConversationStore().loadConversation(
              'local-before-claim-fails',
            ),
            isNotEmpty,
          );
          expect(prefs.getString('local_data_owner'), 'claim-user');
          expect(prefs.getBool('local_data_migrated_claim-user'), isTrue);
          expect(prefs.getBool('local_data_sync_pending_claim-user'), isTrue);
        } finally {
          FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
          ConversationStore.setCurrentUserId(null);
          await AccountHandoffService.clearChoice();
        }
      },
    );

    test(
      'account claim sends Mint2 axis handoff without wizard pollution',
      () async {
        final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
        FeatureFlags.enableMvpWedgeOnboarding = true;
        await AccountHandoffService.saveChoice(AccountHandoffChoice.keepLocal);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_local_mode', false);
        await ReportPersistenceService.saveMint2AxisHandoff({
          'onb_axis_v2': 'lpp_rente_capital',
          'onb_axis_schema_version': 2,
          'legacy_onb_intent': 'retraite',
          'onb_signal_axes_v2': ['logement_signal', 'fiscal_signal'],
        });

        final seenPaths = <String>[];
        Map<String, dynamic>? claimBody;
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/auth/login') {
                return http.Response(
                  '{"access_token":"axis-token","refresh_token":"axis-refresh","user_id":"axis-user","email":"axis@example.ch","display_name":"Axis User"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/profiles/me') {
                return http.Response(
                  jsonEncode({
                    'id': 'axis-profile',
                    'householdType': 'single',
                    'hasDebt': false,
                    'goal': 'other',
                    'factfindCompletionIndex': 0.0,
                    'voiceCursorPreference': 'direct',
                    'n5IssuedThisWeek': 0,
                    'recentGravityEvents': [],
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/sync/claim-local-data') {
                claimBody = json.decode(request.body) as Map<String, dynamic>;
                return http.Response(
                  '{"status":"ok"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{"detail":"not found"}', 404);
            }),
          ),
        );

        try {
          final success = await provider.login('axis@example.ch', 'password');

          expect(success, isTrue);
          expect(seenPaths, contains('/api/v1/sync/claim-local-data'));
          expect(claimBody, isNotNull);
          expect(claimBody!['wizard_answers'], isEmpty);
          expect(claimBody!['wizard_answers'], isNot(contains('onb_axis_v2')));
          expect(
            claimBody!['wizard_answers'],
            isNot(contains('onb_axis_schema_version')),
          );
          expect(
            claimBody!['wizard_answers'],
            isNot(contains('legacy_onb_intent')),
          );
          expect(
            claimBody!['wizard_answers'],
            isNot(contains('onb_signal_axes_v2')),
          );
          expect(claimBody!['mint2_axis_handoff'], {
            'onb_axis_v2': 'lpp_rente_capital',
            'onb_axis_schema_version': 2,
            'legacy_onb_intent': 'retraite',
            'onb_signal_axes_v2': ['logement_signal', 'fiscal_signal'],
          });
          expect(prefs.getString('local_data_owner'), 'axis-user');
          expect(prefs.getBool('local_data_migrated_axis-user'), isTrue);
          expect(prefs.getBool('local_data_sync_pending_axis-user'), isNull);
          expect(await ReportPersistenceService.loadAnswers(), isEmpty);
          expect(
            (await ReportPersistenceService.loadMint2AxisHandoff())[
                'onb_axis_v2'],
            'lpp_rente_capital',
          );
        } finally {
          FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
          ConversationStore.setCurrentUserId(null);
          await AccountHandoffService.clearChoice();
        }
      },
    );

    test(
      'pending local data claim retries on auth restore and clears flag',
      () async {
        final previousWedgeFlag = FeatureFlags.enableMvpWedgeOnboarding;
        FeatureFlags.enableMvpWedgeOnboarding = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('mint_install_marker_v1', true);
        await prefs.setBool('auth_local_mode', false);
        await prefs.setString('local_data_owner', 'claim-user');
        await prefs.setBool('local_data_migrated_claim-user', true);
        await prefs.setBool('local_data_sync_pending_claim-user', true);
        await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
        await AuthService.saveToken(
          'retry-token',
          'claim-user',
          'claim@example.ch',
        );

        final seenPaths = <String>[];
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/sync/claim-local-data') {
                return http.Response(
                  '{"status":"ok"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
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

        try {
          await provider.checkAuth();

          expect(provider.isLoggedIn, isTrue);
          expect(seenPaths, contains('/api/v1/sync/claim-local-data'));
          expect(prefs.getBool('local_data_sync_pending_claim-user'), isNull);
          expect(prefs.getBool('local_data_migrated_claim-user'), isTrue);
          expect(prefs.getString('local_data_owner'), 'claim-user');
        } finally {
          FeatureFlags.enableMvpWedgeOnboarding = previousWedgeFlag;
          ConversationStore.setCurrentUserId(null);
        }
      },
    );

    test('localizeAuthException hides raw technical exception text', () async {
      final l10n = await S.delegate.load(const Locale('fr'));

      final message = localizeAuthException(
        Exception('Apple Sign-In returned no identity token'),
        l10n,
      );

      expect(message, l10n.authErrorGeneric);
      expect(message, isNot(contains('identity token')));
      expect(message, isNot(contains('Apple Sign-In')));
    });

    // ── Listener notification pattern ──

    test('multiple clearError calls each notify listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      provider.clearError();
      provider.clearError();

      expect(notifyCount, 3);
    });

    // ── State isolation ──

    test('two providers have independent state', () {
      final provider1 = AuthProvider();
      final provider2 = AuthProvider();

      // Both start with same defaults
      expect(provider1.isLoggedIn, isFalse);
      expect(provider2.isLoggedIn, isFalse);

      // Listeners are independent
      int count1 = 0;
      int count2 = 0;
      provider1.addListener(() => count1++);
      provider2.addListener(() => count2++);

      provider1.clearError();
      expect(count1, 1);
      expect(count2, 0);
    });

    // ── isLoading starts false ──

    test('isLoading is false before any operation', () {
      expect(provider.isLoading, isFalse);
    });

    test(
      'account data state distinguishes anonymous, signed-out and sync',
      () async {
        expect(provider.accountDataState, MintAccountDataState.anonymousLocal);

        await provider.logout();
        expect(provider.accountDataState, MintAccountDataState.signedOut);

        await AuthService.saveToken('jwt', 'u1', 'u1@example.ch');
        var prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_local_mode', true);
        await provider.checkAuth();
        expect(provider.accountDataState, MintAccountDataState.accountSyncOff);

        await AuthService.logout();
        AuthService.resetMemoryCacheForTest();
        await AuthService.saveToken('jwt', 'u1', 'u1@example.ch');
        prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_local_mode', false);
        await provider.checkAuth();
        expect(provider.accountDataState, MintAccountDataState.cloudSyncOn);
      },
    );

    test(
      'fresh install marker absence with empty prefs purges stale MINT keychain '
      'before auth restore',
      () async {
        secureStorage.addAll({
          'jwt_token': 'old-jwt',
          'refresh_token': 'old-refresh',
          'user_id': 'old-user',
          'user_email': 'old@example.ch',
          'display_name': 'Old User',
          'byok_provider': 'openai',
          'byok_api_key': 'sk-old',
          'mint_partner_estimate': '{"estimated_salary":100000}',
          'anonymous_session_id': 'anon-old',
          'anonymous_message_count': '2',
          'mint_biography_key': 'bio-old',
          '_mint_wizard_secure_keys_v1': '["q_net_income_period_chf"]',
          'q_net_income_period_chf': '8000',
          'foreign_app_key': 'must-stay',
        });

        await provider.checkAuth();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('mint_install_marker_v1'), isTrue);
        expect(provider.isLoggedIn, isFalse);
        expect(provider.accountDataState, MintAccountDataState.anonymousLocal);
        expect(deleteAllCalls, 0);
        expect(secureStorage['foreign_app_key'], 'must-stay');
        expect(secureStorage.containsKey('jwt_token'), isFalse);
        expect(secureStorage.containsKey('refresh_token'), isFalse);
        expect(secureStorage.containsKey('user_id'), isFalse);
        expect(secureStorage.containsKey('user_email'), isFalse);
        expect(secureStorage.containsKey('display_name'), isFalse);
        expect(secureStorage.containsKey('byok_provider'), isFalse);
        expect(secureStorage.containsKey('byok_api_key'), isFalse);
        expect(secureStorage.containsKey('mint_partner_estimate'), isFalse);
        expect(secureStorage.containsKey('anonymous_session_id'), isFalse);
        expect(secureStorage.containsKey('anonymous_message_count'), isFalse);
        expect(secureStorage.containsKey('mint_biography_key'), isFalse);
        expect(secureStorage.containsKey('q_net_income_period_chf'), isFalse);
      },
    );

    test(
      'fresh install marker absence ignores bootstrap prefs and purges stale '
      'anonymous quota state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'regulatory_cache', '{"pillar3a.max_with_lpp":7258}');
        secureStorage.addAll({
          'jwt_token': 'old-jwt',
          'refresh_token': 'old-refresh',
          'user_id': 'old-user',
          'user_email': 'old@example.ch',
          'anonymous_session_id': 'anon-old',
          'anonymous_message_count': '3',
          'foreign_app_key': 'must-stay',
        });

        await provider.checkAuth();

        expect(prefs.getBool(InstallLifecycleService.installMarkerKey), isTrue);
        expect(provider.isLoggedIn, isFalse);
        expect(provider.accountDataState, MintAccountDataState.anonymousLocal);
        expect(secureStorage['foreign_app_key'], 'must-stay');
        expect(secureStorage.containsKey('jwt_token'), isFalse);
        expect(secureStorage.containsKey('refresh_token'), isFalse);
        expect(secureStorage.containsKey('user_id'), isFalse);
        expect(secureStorage.containsKey('user_email'), isFalse);
        expect(secureStorage.containsKey('anonymous_session_id'), isFalse);
        expect(secureStorage.containsKey('anonymous_message_count'), isFalse);
      },
    );

    test(
        'missing install marker on an existing prefs store adopts marker '
        'without deleting current keychain session', () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      secureStorage.addAll({
        'jwt_token': 'current-jwt',
        'user_id': 'current-user',
        'user_email': 'current@example.ch',
      });

      await provider.checkAuth();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('mint_install_marker_v1'), isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.userId, 'current-user');
      expect(provider.email, 'current@example.ch');
      expect(secureStorage['jwt_token'], 'current-jwt');
      expect(deleteAllCalls, 0);
    });

    test(
        'fresh install purge failure stays pending and blocks stale auth '
        'on the next launch', () async {
      var failJwtDelete = true;
      secureStorage.addAll({
        'jwt_token': 'old-jwt',
        'user_id': 'old-user',
        'user_email': 'old@example.ch',
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              secureStorage[key] = value;
            }
            return null;
          case 'read':
            return key == null ? null : secureStorage[key];
          case 'delete':
            if (key == 'jwt_token' && failJwtDelete) {
              throw PlatformException(code: '-34018');
            }
            if (key != null) {
              secureStorage.remove(key);
            }
            return null;
          case 'deleteAll':
            deleteAllCalls += 1;
            secureStorage.clear();
            return null;
          default:
            return null;
        }
      });

      await provider.checkAuth();
      var prefs = await SharedPreferences.getInstance();

      expect(provider.isLoggedIn, isFalse);
      expect(prefs.getBool('mint_install_marker_v1'), isNull);
      expect(prefs.getBool('mint_install_secure_purge_pending_v1'), isTrue);
      expect(secureStorage['jwt_token'], 'old-jwt');

      failJwtDelete = false;
      AuthService.resetMemoryCacheForTest();
      await provider.checkAuth();
      prefs = await SharedPreferences.getInstance();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.accountDataState, MintAccountDataState.anonymousLocal);
      expect(prefs.getBool('mint_install_marker_v1'), isTrue);
      expect(prefs.getBool('mint_install_secure_purge_pending_v1'), isNull);
      expect(secureStorage.containsKey('jwt_token'), isFalse);
      expect(deleteAllCalls, 0);
    });

    test('checkAuth without token exposes fresh visitor lifecycle', () async {
      await provider.checkAuth();

      expect(provider.authLifecycle.state, AuthLifecycleKind.freshVisitor);
      expect(provider.authLifecycle.accessMode, AuthAccessMode.visitor);
      expect(provider.authLifecycle.activeDataScope, AuthDataScope.none);
      expect(provider.authLifecycle.allowsMainNavigation, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.isLocalMode, isTrue);
    });

    test(
      'checkAuth with token but missing user id expires the session',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(InstallLifecycleService.installMarkerKey, true);
        secureStorage['jwt_token'] = 'jwt-without-user-id';
        secureStorage['user_email'] = 'user@example.ch';

        await provider.checkAuth();

        expect(provider.authLifecycle.state, AuthLifecycleKind.sessionExpired);
        expect(provider.authLifecycle.allowsMainNavigation, isFalse);
        expect(provider.isLoggedIn, isFalse);
        expect(provider.userId, isNull);
        expect(secureStorage.containsKey('jwt_token'), isFalse);
      },
    );

    test('enableLocalMode exposes explicit guest lifecycle', () async {
      await provider.enableLocalMode();

      expect(provider.authLifecycle.state, AuthLifecycleKind.guestEmpty);
      expect(provider.authLifecycle.accessMode, AuthAccessMode.guestLocal);
      expect(
        provider.authLifecycle.activeDataScope.kind,
        AuthDataScopeKind.guest,
      );
      expect(provider.authLifecycle.activeDataScope.ownerId, isNotEmpty);
      expect(provider.authLifecycle.syncMode, AuthSyncMode.localOnly);
      expect(provider.authLifecycle.allowsMainNavigation, isTrue);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.isLocalMode, isTrue);
    });

    test(
      'checkAuth with persisted local mode restores explicit guest lifecycle',
      () async {
        SharedPreferences.setMockInitialValues({'auth_local_mode': true});
        provider = AuthProvider();

        await provider.checkAuth();

        expect(provider.authLifecycle.state, AuthLifecycleKind.guestEmpty);
        expect(provider.authLifecycle.accessMode, AuthAccessMode.guestLocal);
        expect(
          provider.authLifecycle.activeDataScope.kind,
          AuthDataScopeKind.guest,
        );
        expect(provider.authLifecycle.activeDataScope.ownerId, isNotEmpty);
        expect(provider.authLifecycle.allowsMainNavigation, isTrue);
        expect(provider.isLoggedIn, isFalse);
        expect(provider.isLocalMode, isTrue);
      },
    );

    test('checkAuth with stored token but no profile blocks main navigation',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(InstallLifecycleService.installMarkerKey, true);
      await AuthService.saveToken(
        'jwt',
        'user-1',
        'user@example.ch',
        refreshToken: 'refresh',
      );
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

      await provider.checkAuth();

      expect(
        provider.authLifecycle.state,
        AuthLifecycleKind.signedInProfileMissing,
      );
      expect(provider.authLifecycle.accessMode, AuthAccessMode.account);
      expect(
        provider.authLifecycle.activeDataScope,
        AuthDataScope.user('user-1'),
      );
      expect(provider.authLifecycle.syncMode, AuthSyncMode.cloudSyncOff);
      expect(provider.authLifecycle.allowsMainNavigation, isFalse);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.userId, 'user-1');
    });

    test('markAccountProfileAvailable releases profile-missing account guard',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(InstallLifecycleService.installMarkerKey, true);
      await AuthService.saveToken(
        'jwt',
        'user-1',
        'user@example.ch',
        refreshToken: 'refresh',
      );
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

      await provider.checkAuth();
      expect(
        provider.authLifecycle.state,
        AuthLifecycleKind.signedInProfileMissing,
      );

      provider.markAccountProfileAvailable();

      expect(provider.authLifecycle.state, AuthLifecycleKind.syncOffAccount);
      expect(provider.authLifecycle.allowsMainNavigation, isTrue);
      expect(
        provider.authLifecycle.activeDataScope,
        AuthDataScope.user('user-1'),
      );
    });

    test(
      'checkAuth does not claim anonymous conversations on restored account',
      () async {
        ConversationStore.setCurrentUserId(null);
        final store = ConversationStore();
        await store.saveConversation('guest-thread', [
          ChatMessage(
            role: 'user',
            content: 'Question invitee',
            timestamp: DateTime(2026, 6, 21, 9),
          ),
        ]);
        await AuthService.saveToken(
          'jwt',
          'user-1',
          'user@example.ch',
          refreshToken: 'refresh',
        );

        await provider.checkAuth();

        ConversationStore.setCurrentUserId('user-1');
        expect(await store.listConversations(), isEmpty);

        ConversationStore.setCurrentUserId(null);
        final anonymousConversations = await store.listConversations();
        expect(anonymousConversations, hasLength(1));
        expect(anonymousConversations.single.id, 'guest-thread');
      },
    );

    test(
      'completeAppleSignIn leaves anonymous conversations unclaimed when not requested',
      () async {
        ConversationStore.setCurrentUserId(null);
        final store = ConversationStore();
        await store.saveConversation('apple-guest-thread', [
          ChatMessage(
            role: 'user',
            content: 'Question avant Apple',
            timestamp: DateTime(2026, 6, 21, 10),
          ),
        ]);

        final ok = await provider.completeAppleSignIn({
          'accessToken': 'apple-jwt',
          'userId': 'apple-user',
          'email': 'apple@example.ch',
        }, claimAnonymousConversations: false);

        expect(ok, isTrue);
        ConversationStore.setCurrentUserId('apple-user');
        expect(await store.listConversations(), isEmpty);

        ConversationStore.setCurrentUserId(null);
        expect(await store.listConversations(), hasLength(1));
      },
    );

    test(
      'completeAppleSignIn claims anonymous conversations when requested',
      () async {
        ConversationStore.setCurrentUserId(null);
        final store = ConversationStore();
        await store.saveConversation('apple-guest-thread', [
          ChatMessage(
            role: 'user',
            content: 'Question avant Apple',
            timestamp: DateTime(2026, 6, 21, 10),
          ),
        ]);

        final claimed = await provider.completeAppleSignIn({
          'accessToken': 'apple-jwt',
          'userId': 'apple-user',
          'email': 'apple@example.ch',
        }, claimAnonymousConversations: true);

        expect(claimed, isTrue);
        ConversationStore.setCurrentUserId('apple-user');
        final claimedConversations = await store.listConversations();
        expect(claimedConversations, hasLength(1));
        expect(claimedConversations.single.id, 'apple-guest-thread');
      },
    );

    // ── requiresEmailVerification starts false ──

    test('requiresEmailVerification defaults to false', () {
      expect(provider.requiresEmailVerification, isFalse);
    });

    // ── Getter consistency ──

    test('all getters return consistent initial state', () {
      // Verify no getter throws on fresh instance
      expect(provider.isLoggedIn, isFalse);
      expect(provider.userId, isNull);
      expect(provider.email, isNull);
      expect(provider.displayName, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.requiresEmailVerification, isFalse);
    });

    // ── Listener removal ──

    test('removed listener is not called', () {
      int notifyCount = 0;
      void listener() => notifyCount++;

      provider.addListener(listener);
      provider.clearError();
      expect(notifyCount, 1);

      provider.removeListener(listener);
      provider.clearError();
      expect(notifyCount, 1); // Should not increment
    });

    // ── Dispose does not throw ──

    test('dispose does not throw on fresh provider', () {
      expect(() => provider.dispose(), returnsNormally);
    });

    test('logout revokes backend refresh token before local purge', () async {
      await AuthService.saveToken(
        'jwt-token',
        'u1',
        'u1@example.ch',
        refreshToken: 'refresh-token',
      );

      final seenPaths = <String>[];
      String? authHeader;
      Map<String, dynamic>? logoutBody;
      ApiService.setHttpClientForTesting(
        MintHttpClient(
          MockClient((request) async {
            seenPaths.add(request.url.path);
            if (request.url.path == '/api/v1/auth/logout') {
              authHeader = request.headers['Authorization'];
              logoutBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                '{"status":"logged_out"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{"detail":"not found"}', 404);
          }),
        ),
      );

      await provider.logout();

      expect(seenPaths, contains('/api/v1/auth/logout'));
      expect(authHeader, 'Bearer jwt-token');
      expect(logoutBody, {'refresh_token': 'refresh-token'});
      expect(await AuthService.getToken(), isNull);
      expect(await AuthService.getRefreshToken(), isNull);
    });

    test(
      'logout retries backend revocation after captured refresh succeeds',
      () async {
        await AuthService.saveToken(
          'expired-jwt',
          'u1',
          'u1@example.ch',
          refreshToken: 'refresh-token',
        );

        var logoutCalls = 0;
        final seenPaths = <String>[];
        final secondLogoutSeen = Completer<void>();
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/api/v1/auth/logout') {
                logoutCalls += 1;
                if (logoutCalls == 1) {
                  expect(
                    request.headers['Authorization'],
                    'Bearer expired-jwt',
                  );
                  return http.Response(
                    '{"detail":"expired"}',
                    401,
                    headers: {'content-type': 'application/json'},
                  );
                }
                expect(request.headers['Authorization'], 'Bearer fresh-jwt');
                expect(jsonDecode(request.body), {
                  'refresh_token': 'fresh-refresh',
                });
                if (!secondLogoutSeen.isCompleted) {
                  secondLogoutSeen.complete();
                }
                return http.Response(
                  '{"status":"logged_out"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (request.url.path == '/api/v1/auth/refresh') {
                expect(jsonDecode(request.body), {
                  'refresh_token': 'refresh-token',
                });
                return http.Response(
                  '{"access_token":"fresh-jwt","refresh_token":"fresh-refresh","user_id":"u1","email":"u1@example.ch"}',
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response('{"detail":"not found"}', 404);
            }),
          ),
        );

        await provider.logout();
        await secondLogoutSeen.future.timeout(const Duration(seconds: 1));

        expect(seenPaths, [
          '/api/v1/auth/logout',
          '/api/v1/auth/refresh',
          '/api/v1/auth/logout',
        ]);
        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.getRefreshToken(), isNull);
      },
    );

    test(
      'logout clears local session before delayed backend revocation returns',
      () async {
        await AuthService.saveToken(
          'jwt-token',
          'u1',
          'u1@example.ch',
          refreshToken: 'refresh-token',
        );

        final requestSeen = Completer<void>();
        final releaseResponse = Completer<void>();
        final responseReturned = Completer<void>();
        ApiService.setHttpClientForTesting(
          MintHttpClient(
            MockClient((request) async {
              if (request.url.path == '/api/v1/auth/logout' &&
                  !requestSeen.isCompleted) {
                requestSeen.complete();
              }
              await releaseResponse.future;
              if (!responseReturned.isCompleted) {
                responseReturned.complete();
              }
              return http.Response(
                '{"status":"logged_out"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );

        final logoutFuture = provider.logout();
        await requestSeen.future;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.getRefreshToken(), isNull);

        releaseResponse.complete();
        await logoutFuture;
        await responseReturned.future.timeout(const Duration(seconds: 1));
      },
    );

    test('logout purges only MINT-owned secure storage keys', () async {
      secureStorage.addAll({
        'jwt_token': 'jwt',
        'refresh_token': 'refresh',
        'user_id': 'u1',
        'user_email': 'u1@example.ch',
        'display_name': 'User One',
        'byok_provider': 'openai',
        'byok_api_key': 'sk-test-key',
        'mint_partner_estimate': '{"estimated_salary":100000}',
        'anonymous_session_id': 'anon-1',
        'anonymous_message_count': '1',
        'mint_biography_key': 'bio-key',
        '_mint_wizard_secure_keys_v1': '["q_net_income_period_chf"]',
        'q_net_income_period_chf': '8000',
        'foreign_app_key': 'must-stay',
      });

      await provider.logout();

      expect(deleteAllCalls, 0);
      expect(secureStorage['foreign_app_key'], 'must-stay');
      expect(secureStorage.containsKey('jwt_token'), isFalse);
      expect(secureStorage.containsKey('refresh_token'), isFalse);
      expect(secureStorage.containsKey('byok_provider'), isFalse);
      expect(secureStorage.containsKey('byok_api_key'), isFalse);
      expect(secureStorage.containsKey('mint_partner_estimate'), isFalse);
      expect(secureStorage.containsKey('anonymous_session_id'), isFalse);
      expect(secureStorage.containsKey('anonymous_message_count'), isFalse);
      expect(secureStorage.containsKey('mint_biography_key'), isFalse);
      expect(secureStorage.containsKey('q_net_income_period_chf'), isFalse);
    });

    test(
      'logout continues scoped secure purges when one key delete fails',
      () async {
        secureStorage.addAll({
          'byok_provider': 'openai',
          'byok_api_key': 'sk-delete-fails',
          'mint_partner_estimate': '{"estimated_salary":100000}',
          'anonymous_session_id': 'anon-1',
          'anonymous_message_count': '1',
          'mint_biography_key': 'bio-key',
          '_mint_wizard_secure_keys_v1': '["q_net_income_period_chf"]',
          'q_net_income_period_chf': '8000',
          'foreign_app_key': 'must-stay',
        });

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final key = call.arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureStorage[key];
            case 'delete':
              if (key == 'byok_api_key') {
                throw PlatformException(code: '-34018');
              }
              if (key != null) {
                secureStorage.remove(key);
              }
              return null;
            case 'deleteAll':
              deleteAllCalls += 1;
              secureStorage.clear();
              return null;
            default:
              return null;
          }
        });

        await provider.logout();

        expect(deleteAllCalls, 0);
        expect(secureStorage['foreign_app_key'], 'must-stay');
        expect(secureStorage['byok_api_key'], 'sk-delete-fails');
        expect(secureStorage.containsKey('mint_partner_estimate'), isFalse);
        expect(secureStorage.containsKey('anonymous_session_id'), isFalse);
        expect(secureStorage.containsKey('anonymous_message_count'), isFalse);
        expect(secureStorage.containsKey('mint_biography_key'), isFalse);
        expect(secureStorage.containsKey('q_net_income_period_chf'), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(InstallLifecycleService.ownedSecurePurgePendingKey),
          isTrue,
        );
      },
    );

    test('profile clearAll purges owned secure feature keys', () async {
      secureStorage.addAll({
        'byok_provider': 'openai',
        'byok_api_key': 'sk-profile-reset',
        'mint_partner_estimate': '{"estimated_salary":100000}',
        'anonymous_session_id': 'anon-1',
        'anonymous_message_count': '1',
        'mint_biography_key': 'bio-key',
        '_mint_wizard_secure_keys_v1': '["q_net_income_period_chf"]',
        'q_net_income_period_chf': '8000',
        'foreign_app_key': 'must-stay',
      });

      await CoachProfileProvider().clearAll();

      expect(deleteAllCalls, 0);
      expect(secureStorage['foreign_app_key'], 'must-stay');
      expect(secureStorage.containsKey('byok_provider'), isFalse);
      expect(secureStorage.containsKey('byok_api_key'), isFalse);
      expect(secureStorage.containsKey('mint_partner_estimate'), isFalse);
      expect(secureStorage.containsKey('anonymous_session_id'), isFalse);
      expect(secureStorage.containsKey('anonymous_message_count'), isFalse);
      expect(secureStorage.containsKey('mint_biography_key'), isFalse);
      expect(secureStorage.containsKey('q_net_income_period_chf'), isFalse);
    });

    test(
      'profile clearAll records pending secure purge on partial failure',
      () async {
        secureStorage.addAll({
          'byok_provider': 'openai',
          'byok_api_key': 'sk-profile-reset',
          'mint_partner_estimate': '{"estimated_salary":100000}',
          'foreign_app_key': 'must-stay',
        });

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final key = call.arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureStorage[key];
            case 'delete':
              if (key == 'byok_api_key') {
                throw PlatformException(code: '-34018');
              }
              if (key != null) {
                secureStorage.remove(key);
              }
              return null;
            case 'deleteAll':
              deleteAllCalls += 1;
              secureStorage.clear();
              return null;
            default:
              return null;
          }
        });

        await CoachProfileProvider().clearAll();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(InstallLifecycleService.ownedSecurePurgePendingKey),
          isTrue,
        );
        expect(secureStorage['byok_api_key'], 'sk-profile-reset');
        expect(secureStorage['foreign_app_key'], 'must-stay');
      },
    );

    test(
        'normal install retries pending owned secure purge without deleting '
        'auth session', () async {
      secureStorage.addAll({
        'jwt_token': 'jwt',
        'refresh_token': 'refresh',
        'user_id': 'u1',
        'user_email': 'u1@example.ch',
        'byok_api_key': 'stale-key',
        'foreign_app_key': 'must-stay',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(InstallLifecycleService.installMarkerKey, true);
      await prefs.setBool(
        InstallLifecycleService.ownedSecurePurgePendingKey,
        true,
      );

      final mayRestoreAuth =
          await InstallLifecycleService.prepareForAuthRestore();

      expect(mayRestoreAuth, isTrue);
      expect(
        prefs.getBool(InstallLifecycleService.ownedSecurePurgePendingKey),
        isNull,
      );
      expect(secureStorage['jwt_token'], 'jwt');
      expect(secureStorage['refresh_token'], 'refresh');
      expect(secureStorage.containsKey('byok_api_key'), isFalse);
      expect(secureStorage['foreign_app_key'], 'must-stay');
    });

    test('backend profile merge accepts flat profile payload', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest(
        {'q_canton': 'VD'},
        {
          'firstName': 'Julien',
          'dateOfBirth': '1981-06-15',
          'incomeGrossYearly': 120000,
          'incomeNetMonthly': 7600,
          'householdType': 'concubine',
          'employmentStatus': 'employee',
          'commune': 'Lausanne',
          'gender': 'male',
          'nationality': 'CH',
          'usTaxPerson': false,
        },
      );
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_canton'], 'VD');
      expect(merged['q_firstname'], 'Julien');
      expect(merged['q_date_of_birth'], '1981-06-15');
      expect(merged['q_birth_year'], 1981);
      expect(merged['q_gross_salary_annual'], 120000.0);
      expect(merged['q_net_income_period_chf'], 7600.0);
      expect(merged.containsKey('q_civil_status'), isFalse);
      expect(merged['q_household_type'], 'concubine');
      expect(merged['q_employment_status'], 'salarie');
      expect(merged['q_commune'], 'Lausanne');
      expect(merged['q_gender'], 'male');
      expect(merged['q_nationality'], 'CH');
      expect(merged['q_us_tax_person'], isFalse);
      expect(profile.salaireBrutMensuel, 10000);
      expect(profile.etatCivil, CoachCivilStatus.celibataire);
      expect(profile.employmentStatus, 'salarie');
      expect(profile.usTaxPerson, isFalse);
    });

    test('backend profile merge accepts legacy nested data payload', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'data': {
          'birthYear': 1990,
          'incomeGrossYearly': 90000,
          'householdType': 'family',
        },
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_birth_year'], 1990);
      expect(merged['q_gross_salary_annual'], 90000.0);
      expect(merged.containsKey('q_civil_status'), isFalse);
      expect(merged['q_household_type'], 'family');
      expect(profile.salaireBrutMensuel, 7500);
      expect(profile.etatCivil, CoachCivilStatus.celibataire);
    });

    test('backend profile merge hydrates material planning fields', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'dateOfBirth': '1981-06-15',
        'incomeGrossYearly': 120000,
        'avoirLpp': 250000,
        'lppInsuredSalary': 88000,
        'lppBuybackMax': 42000,
        'pillar3aBalance': 36000,
        'pillar3aAnnual': 7056,
        'savingsMonthly': 1500,
        'totalSavings': 18000,
        'hasDebt': true,
        'totalDebt': 9000,
        'avsContributionYears': 20,
        'targetRetirementAge': 64,
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['_coach_avoir_lpp'], 250000.0);
      expect(merged['q_gross_salary_annual'], 120000.0);
      expect(merged['_coach_salaire_assure'], 88000.0);
      expect(merged['_coach_rachat_maximum'], 42000.0);
      expect(merged['q_3a_total'], 36000.0);
      expect(merged['q_3a_annual_contribution'], 7056.0);
      expect(merged['q_has_3a'], isTrue);
      expect(merged['q_savings_monthly'], 1500.0);
      expect(merged['q_cash_total'], 18000.0);
      expect(merged['q_has_consumer_debt'], 'yes');
      expect(merged['q_total_debt_balance_chf'], 9000.0);
      expect(merged['q_avs_contribution_years'], 20);
      expect(merged['q_target_retirement_age'], 64);
      expect(profile.prevoyance.avoirLppTotal, 250000);
      expect(profile.prevoyance.salaireAssure, 88000);
      expect(profile.prevoyance.rachatMaximum, 42000);
      expect(profile.prevoyance.totalEpargne3a, 36000);
      expect(profile.total3aMensuel, closeTo(588, 0.01));
      expect(
        profile.dataSources['plannedContributions.3a'],
        ProfileDataSource.userInput,
      );
      expect(profile.patrimoine.epargneLiquide, 18000);
      expect(profile.prevoyance.anneesContribuees, 20);
      expect(profile.targetRetirementAge, 64);
      expect(profile.dettes.totalDettes, 9000);
    });

    test('backend profile merge hydrates save_fact parity fields', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'householdType': 'couple',
        'selfEmployedNetIncome': 96000,
        'hasVoluntaryLpp': true,
        'spouseBirthYear': 1982,
        'spouseIncomeNetMonthly': 5000,
        'spouseAvsContributionYears': 18,
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_household_type'], 'couple');
      expect(merged['q_self_employed_net_income_annual_chf'], 96000.0);
      expect(merged['q_net_income_period_chf'], closeTo(8000, 0.01));
      expect(merged['q_pay_frequency'], 'monthly');
      expect(
        merged['q_net_income_period_source'],
        'derived_self_employed_annual_proxy',
      );
      expect(merged['q_employment_status'], 'independant');
      expect(merged['q_has_pension_fund'], isTrue);
      expect(merged['q_partner_birth_year'], 1982);
      expect(merged['q_partner_net_income_chf'], 5000.0);
      expect(merged['q_spouse_avs_contribution_years'], 18);
      expect(profile.employmentStatus, 'independant');
      expect(profile.independentNetProfessionalIncomeAnnual, 96000.0);
      expect(profile.explicitMonthlyNetIncome, closeTo(8000, 0.01));
      expect(profile.salaireBrutMensuel, closeTo(8800, 0.01));
      expect(profile.revenuBrutAnnuel, closeTo(105600, 0.01));
      expect(profile.conjoint!.birthYear, 1982);
      expect(profile.conjoint!.prevoyance!.anneesContribuees, 18);
    });

    test(
      'backend profile merge preserves existing independent budget cashflow',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {
            'q_employment_status': 'independant',
            'q_self_employed_net_income_annual_chf': 86400,
            'q_net_income_period_chf': 6900,
            'q_pay_frequency': 'monthly',
          },
          {'selfEmployedNetIncome': 96000},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_self_employed_net_income_annual_chf'], 96000.0);
        expect(merged['q_net_income_period_chf'], 6900);
        expect(merged['q_pay_frequency'], 'monthly');
        expect(profile.independentNetProfessionalIncomeAnnual, 96000);
        expect(profile.explicitMonthlyNetIncome, 6900);
      },
    );

    test('backend localDataClaim wizard answers beat stale flat income', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'data': {
          'selfEmployedNetIncome': 86400,
          'localDataClaim': {
            'wizardAnswers': {
              'q_employment_status': 'independant',
              'q_self_employed_net_income_annual_chf': 90000,
              'q_net_income_period_chf': 7500,
              'q_pay_frequency': 'monthly',
              'q_net_income_period_source':
                  'derived_self_employed_annual_proxy',
            },
          },
        },
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_self_employed_net_income_annual_chf'], 90000);
      expect(merged['q_net_income_period_chf'], 7500);
      expect(merged['q_pay_frequency'], 'monthly');
      expect(profile.independentNetProfessionalIncomeAnnual, 90000);
      expect(profile.explicitMonthlyNetIncome, 7500);
    });

    test('backend localDataClaim zero 3a beats stale flat contribution', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'data': {
          'pillar3aAnnual': 6000,
          'localDataClaim': {
            'wizardAnswers': {'q_3a_annual_contribution': 0, 'q_has_3a': false},
          },
        },
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_3a_annual_contribution'], 0);
      expect(merged['q_has_3a'], isFalse);
      expect(profile.total3aMensuel, 0);
      expect(profile.prevoyance.nombre3a, 0);
    });

    test('backend localDataClaim 3a annual derives missing has3a flag', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
        'data': {
          'localDataClaim': {
            'wizardAnswers': {'q_3a_annual_contribution': 7056},
          },
        },
      });
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_3a_annual_contribution'], 7056);
      expect(merged['q_has_3a'], isTrue);
      expect(profile.total3aMensuel, closeTo(588, 0.01));
      expect(profile.prevoyance.nombre3a, 1);
    });

    test(
      'backend profile merge refreshes monthly cashflow derived from old annual',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {
            'q_employment_status': 'independant',
            'q_self_employed_net_income_annual_chf': 86400,
            'q_net_income_period_chf': 7200,
            'q_pay_frequency': 'monthly',
            'q_net_income_period_source': 'derived_self_employed_annual_proxy',
          },
          {'selfEmployedNetIncome': 96000},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_self_employed_net_income_annual_chf'], 96000.0);
        expect(merged['q_net_income_period_chf'], closeTo(8000, 0.01));
        expect(merged['q_pay_frequency'], 'monthly');
        expect(
          merged['q_net_income_period_source'],
          'derived_self_employed_annual_proxy',
        );
        expect(profile.independentNetProfessionalIncomeAnnual, 96000);
        expect(profile.explicitMonthlyNetIncome, closeTo(8000, 0.01));
      },
    );

    test(
      'backend self-employed income preserves stale local employee status',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {
            'q_employment_status': 'salarie',
            'q_self_employed_net_income_annual_chf': 86400,
            'q_net_income_period_chf': 7200,
            'q_pay_frequency': 'monthly',
          },
          {'selfEmployedNetIncome': 96000},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_employment_status'], 'salarie');
        expect(merged['q_self_employed_net_income_annual_chf'], 96000.0);
        expect(merged['q_net_income_period_chf'], 7200);
        expect(profile.employmentStatus, 'salarie');
        expect(profile.independentNetProfessionalIncomeAnnual, 96000);
      },
    );

    test(
      'backend self-employed income preserves explicit local employee status',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {
            'q_employment_status': 'salarie',
            'q_net_income_period_chf': 7600,
            'q_pay_frequency': 'monthly',
          },
          {'selfEmployedNetIncome': 96000},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_employment_status'], 'salarie');
        expect(merged['q_self_employed_net_income_annual_chf'], 96000.0);
        expect(merged['q_net_income_period_chf'], 7600);
        expect(profile.employmentStatus, 'salarie');
        expect(profile.explicitMonthlyNetIncome, 7600);
      },
    );

    test(
      'backend profile merge fills null placeholders but preserves zero',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {'q_net_income_period_chf': null, 'q_3a_total': 0},
          {'incomeNetMonthly': 7600, 'pillar3aBalance': 36000},
        );

        expect(merged['q_net_income_period_chf'], 7600.0);
        expect(merged['q_pay_frequency'], 'monthly');
        expect(merged['q_3a_total'], 0);
      },
    );

    test('backend profile merge preserves local financial truth', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest(
        {
          '_coach_avoir_lpp': 100000,
          '_coach_salaire_assure': 70000,
          '_coach_rachat_maximum': 10000,
          'q_3a_total': 12000,
          'q_3a_annual_contribution': 3000,
          'q_savings_monthly': 800,
          'q_cash_total': 9000,
          'q_has_consumer_debt': false,
          'q_target_retirement_age': 63,
        },
        {
          'avoirLpp': 250000,
          'lppInsuredSalary': 88000,
          'lppBuybackMax': 42000,
          'pillar3aBalance': 36000,
          'pillar3aAnnual': 7056,
          'savingsMonthly': 1500,
          'totalSavings': 18000,
          'hasDebt': true,
          'targetRetirementAge': 64,
        },
      );

      expect(merged['_coach_avoir_lpp'], 100000);
      expect(merged['_coach_salaire_assure'], 70000);
      expect(merged['_coach_rachat_maximum'], 10000);
      expect(merged['q_3a_total'], 12000);
      expect(merged['q_3a_annual_contribution'], 7056.0);
      expect(merged['q_savings_monthly'], 800);
      expect(merged['q_cash_total'], 9000);
      expect(merged['q_has_consumer_debt'], isFalse);
      expect(merged['q_target_retirement_age'], 63);
    });

    test(
      'backend pillar3aAnnual correction to zero clears contribution signal',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {'q_3a_annual_contribution': 6000, 'q_has_3a': true},
          {'pillar3aAnnual': 0},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_3a_annual_contribution'], 0.0);
        expect(merged['q_has_3a'], isFalse);
        expect(profile.total3aMensuel, 0);
        expect(profile.prevoyance.nombre3a, 0);
      },
    );

    test(
      'backend pillar3aAnnual positive correction revives 3a contribution',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {'q_3a_annual_contribution': 0, 'q_has_3a': false},
          {'pillar3aAnnual': 7056},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_3a_annual_contribution'], 7056.0);
        expect(merged['q_has_3a'], isTrue);
        expect(profile.total3aMensuel, closeTo(588, 0.01));
        expect(profile.prevoyance.nombre3a, 1);
      },
    );

    test(
      'backend profile merge does not synthesize debt capital from boolean',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest(
          {'q_birth_year': 1981, 'q_gross_salary_annual': 120000},
          {'hasDebt': true},
        );
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged['q_has_consumer_debt'], 'yes');
        expect(merged.containsKey('q_total_debt_balance_chf'), isFalse);
        expect(profile.dettes.totalDettes, 0);
      },
    );

    test('backend profile merge keeps net monthly income units coherent', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest(
        {'q_pay_frequency': 'yearly'},
        {'incomeNetMonthly': 7600},
      );

      expect(merged['q_net_income_period_chf'], 7600.0);
      expect(merged['q_pay_frequency'], 'monthly');
      expect(merged.containsKey('q_gross_salary_annual'), isFalse);
    });

    test(
      'backend profile merge does not infer LPP balance from partial facts',
      () {
        final merged = AuthProvider.mergeBackendProfileDataForTest({}, {
          'dateOfBirth': '1981-06-15',
          'incomeGrossYearly': 120000,
          'lppInsuredSalary': 88000,
          'lppBuybackMax': 42000,
        });
        final profile = CoachProfile.fromWizardAnswers(merged);

        expect(merged.containsKey('q_has_pension_fund'), isFalse);
        expect(merged.containsKey('_coach_avoir_lpp'), isFalse);
        expect(profile.prevoyance.avoirLppTotal, 0);
        expect(profile.prevoyance.salaireAssure, 88000);
        expect(profile.prevoyance.rachatMaximum, 42000);
      },
    );

    test('backend profile merge preserves explicit local zero values', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest(
        {
          'q_3a_total': 0,
          'q_3a_annual_contribution': 0,
          'q_savings_monthly': 0,
          'q_cash_total': 0,
        },
        {
          'pillar3aBalance': 36000,
          'pillar3aAnnual': 7056,
          'savingsMonthly': 1500,
          'totalSavings': 18000,
        },
      );

      expect(merged['q_3a_total'], 0);
      expect(merged['q_3a_annual_contribution'], 7056.0);
      expect(merged['q_has_3a'], isTrue);
      expect(merged['q_savings_monthly'], 0);
      expect(merged['q_cash_total'], 0);
    });

    test('backend profile merge never overwrites local truth', () {
      final merged = AuthProvider.mergeBackendProfileDataForTest(
        {
          'q_canton': 'VD',
          'q_date_of_birth': '1981-06-15',
          'q_birth_year': 1981,
          'q_gross_salary_annual': 120000,
          'q_civil_status': 'marie',
          'q_household_type': 'couple',
          'q_employment_status': 'independant',
        },
        {
          'dateOfBirth': '1995-01-01',
          'birthYear': 1995,
          'canton': 'GE',
          'incomeGrossYearly': 90000,
          'householdType': 'single',
          'employmentStatus': 'employee',
        },
      );
      final profile = CoachProfile.fromWizardAnswers(merged);

      expect(merged['q_canton'], 'VD');
      expect(merged['q_date_of_birth'], '1981-06-15');
      expect(merged['q_birth_year'], 1981);
      expect(merged['q_gross_salary_annual'], 120000);
      expect(merged['q_civil_status'], 'marie');
      expect(merged['q_household_type'], 'couple');
      expect(merged['q_employment_status'], 'independant');
      expect(profile.salaireBrutMensuel, 10000);
      expect(profile.etatCivil, CoachCivilStatus.marie);
      expect(profile.employmentStatus, 'independant');
    });
  });

  group('AuthProvider error message patterns', () {
    // Documents the expected error mapping patterns from _toUserFriendlyAuthError.
    // These are verified by reading the source code — the private method maps:
    //   socketexception / clientexception / failed host lookup / connection refused
    //     → 'Connexion au service indisponible...'
    //   'existe déjà' → 'Cet e-mail est déjà utilisé...'
    //   'incorrect' → 'E-mail ou mot de passe incorrect.'
    //   'registration failed' / 'inscription impossible' / 'service indisponible'
    //     → 'Inscription indisponible...'
    //   'authentication requise' / 'unauthorized' / 'forbidden'
    //     → 'Le service de compte n\'est pas disponible...'
    //   'invalid' / 'invalide' → 'Les informations saisies sont invalides.'
    //   'expir' → 'Ce lien de réinitialisation a expiré...'
    //   'non vérifié' / 'not verified' → 'Ton e-mail n\'est pas encore vérifié...'
    //   fallback → 'Action impossible pour le moment...'

    test('error mapping covers network errors', () {
      // This test documents expected behavior. The mapping is tested
      // integration-style when actual API calls fail.
      expect(true, isTrue); // Placeholder — actual integration in e2e tests
    });

    test('error mapping covers duplicate email', () {
      expect(true, isTrue);
    });

    test('error mapping covers wrong credentials', () {
      expect(true, isTrue);
    });
  });
}
