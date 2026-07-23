import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';

/// beads MINT_nosync-tcr — signal 403 du consent gate backend.
///
/// Bug prouvé sur dev : tout 403 était traité comme gate entitlement
/// (`debugPrint` générique + code 'entitlement'), donc flipper le backend en
/// hard_block briquait le coach pour tout utilisateur sans grant (aucun
/// chemin vers la ConsentSheet). Le deny_pointer structuré
/// {action, purpose, modal_copy_key} doit produire code 'consent_required'
/// avec le purpose, pour que l'écran présente la sheet puis rejoue.
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
            if (value != null) mockStorage[key] = value;
            return null;
          case 'read':
            return mockStorage[call.arguments['key'] as String];
          case 'delete':
            mockStorage.remove(call.arguments['key'] as String);
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

  Future<CoachChatApiException> sendExpecting403(Object detail) async {
    SharedPreferences.setMockInitialValues({'auth_local_mode': false});
    await AuthService.saveToken('test-token', 'uid', 'u@test.ch');
    final service = CoachChatApiService(baseUrl: 'https://example.test');
    service.testClient = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode({'detail': detail}),
        403,
        headers: {'content-type': 'application/json'},
      );
    });
    try {
      await service.chat(message: 'ping');
      fail('un 403 doit lever CoachChatApiException');
    } on CoachChatApiException catch (e) {
      return e;
    }
  }

  group('403 consent gate (deny_pointer) vs entitlement', () {
    test('deny_pointer structuré -> consent_required + purpose', () async {
      final e = await sendExpecting403({
        'action': 'POST /api/v1/consents/grant',
        'purpose': 'transfer_us_anthropic',
        'modal_copy_key': 'consent_modal_transfer_us_anthropic',
      });
      expect(e.code, 'consent_required',
          reason: 'le deny_pointer du consent gate ne doit pas être '
              "confondu avec le gate entitlement — c'est le signal qui "
              'déclenche la ConsentSheet puis le retry');
      expect(e.consentPurpose, 'transfer_us_anthropic');
    });

    test('detail string (entitlement classique) -> entitlement', () async {
      final e = await sendExpecting403('Premium required');
      expect(e.code, 'entitlement');
      expect(e.consentPurpose, isNull);
    });

    test('detail map sans modal_copy_key -> entitlement (pas de sheet)',
        () async {
      final e = await sendExpecting403({'reason': 'other'});
      expect(e.code, 'entitlement');
    });
  });

  group('câblage écran', () {
    test('coach_chat_screen gère consent_required (sheet -> grant -> retry)',
        () {
      final source = File('lib/screens/coach/coach_chat_screen.dart')
          .readAsStringSync();
      expect(source.contains("e.code == 'consent_required'"), isTrue);
      expect(source.contains('_handleConsentRequired'), isTrue);
      expect(source.contains('ConsentPurpose.transferUsAnthropic'), isTrue);
      expect(source.contains('coachConsentDeclined'), isTrue,
          reason: 'le refus doit afficher le message ARB explicite');
    });
  });
}
