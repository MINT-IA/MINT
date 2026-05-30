import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockStorage = <String, String>{};

  setUp(() {
    mockStorage.clear();
    AuthService.resetMemoryCacheForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) {
              mockStorage[key] = value;
            }
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockStorage.remove(key);
            return null;
          case 'deleteAll':
            mockStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('CoachChatApiService packet HTTP contract', () {
    test('chat posts coach_context_packet inside profile_context', () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

      Map<String, dynamic>? capturedBody;
      final service = CoachChatApiService(baseUrl: 'https://example.test');
      service.testClient = MockClient((http.Request request) async {
        expect(request.url.toString(), 'https://example.test/coach/chat');
        expect(request.headers['Authorization'], 'Bearer test-token');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'message': 'ok',
            'toolCalls': [],
            'citationChips': [],
            'sources': [],
            'disclaimers': [],
            'tokensUsed': 1,
            'responseMeta': {'degraded': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final packet = {
        'facts': [
          {
            'id': 'budget.monthly_free',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyFree',
            'value': 2239.0,
          },
        ],
        'trajectory': {'status': 'onTrack'},
      };

      await service.chat(
        message: 'Analyse mon budget.',
        profileContext: {
          'canton': 'VD',
          'coach_context_packet': packet,
        },
      );

      final body = capturedBody!;
      expect(body['persistence_consent'], isTrue);
      final profileContext = body['profile_context'] as Map<String, dynamic>;
      expect(profileContext['canton'], 'VD');
      expect(profileContext['coach_context_packet'], packet);
      expect(body.containsKey('coach_context_packet'), isFalse);

      final emittedPacket =
          profileContext['coach_context_packet'] as Map<String, dynamic>;
      final facts = emittedPacket['facts'] as List<dynamic>;
      expect(
          (facts.single as Map<String, dynamic>)['id'], 'budget.monthly_free');
    });

    test('chat parses citationChips from server-key coach response', () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

      final service = CoachChatApiService(baseUrl: 'https://example.test');
      service.testClient = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'message': 'Ta marge libre est de CHF 2\'239.',
            'toolCalls': [],
            'citationChips': [
              {
                'toolName': 'budget_snapshot',
                'inputsHash': 'a' * 64,
                'computedAt': '2026-05-23T12:00:00Z',
                'rawResponse': {'monthlySurplus': '2239.00'},
              },
            ],
            'sources': [],
            'disclaimers': [],
            'tokensUsed': 1,
            'responseMeta': {'degraded': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final response = await service.chat(
        message: 'Combien il me reste ?',
        profileContext: const {'canton': 'VD'},
      );

      expect(response.citationChips, hasLength(1));
      final chip = response.citationChips.single;
      expect(chip.toolName, 'budget_snapshot');
      expect(chip.inputsHash, 'a' * 64);
      expect(chip.rawResponse['monthlySurplus'], '2239.00');
    });
  });
}
