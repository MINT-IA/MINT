// Tranche firstJob PR-E (E2) — contrat HTTP du handoff coach (Codex P1).
//
// Double ceinture du contrat SPEC §4.3 côté client, testée SANS pré-seed DB :
//   1. MoneyTruthReceiptApiService.store() POSTe le receipt au store.
//   2. CoachChatApiService.chat() porte receiptId + inputsHash + receiptInputs
//      dans le body coach (chemin pending si le store a échoué).

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/money_truth_receipt_api_service.dart';
import 'package:mint_mobile/services/first_job_service.dart';

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

  makeReceipt() => FirstJobService.buildNetSalaryReceipt(
        salaireBrutMensuel: 6788,
        age: 30,
        canton: 'ZH',
        receiptId: 'rcpt-handoff',
        computedAt: '2026-07-29T10:00:00Z',
      );

  group('Ceinture 1 — store POST', () {
    test('store() POSTe le receipt à /lucidity/receipts (body {receipt})',
        () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final service =
          MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
      service.testClient = MockClient((http.Request request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'status': 'stored',
            'receiptId': 'rcpt-handoff',
            'inputsHash': capturedBody!['receipt']['inputsHash'],
          }),
          200,
        );
      });

      final ok = await service.store(makeReceipt());

      expect(ok, isTrue);
      expect(capturedUri.toString(), 'https://example.test/lucidity/receipts');
      expect(capturedBody, isNotNull);
      final receipt = capturedBody!['receipt'] as Map<String, dynamic>;
      expect(receipt['receiptId'], 'rcpt-handoff');
      expect(receipt['claimId'], 'firstjob.net_salary.v1');
      expect(receipt['base'], 'net');
      expect((receipt['inputsHash'] as String).length, 64);
      // Le receipt porte le net (valeur) et sa bande — pas un recalcul.
      expect(receipt['value'], isA<num>());
      expect(receipt['range'], isNotNull);
    });

    test('store() best-effort : pas de token -> false, aucune exception',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service =
          MoneyTruthReceiptApiService(baseUrl: 'https://example.test');
      service.testClient =
          MockClient((r) async => http.Response('{}', 200));
      final ok = await service.store(makeReceipt());
      expect(ok, isFalse, reason: 'sans token, le store ne peut pas résoudre');
    });
  });

  group('Ceinture 2 — coach request porte les 3 params', () {
    test('chat() met receipt_id + inputs_hash + receipt_inputs dans le body',
        () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

      Map<String, dynamic>? capturedBody;
      final service = CoachChatApiService(baseUrl: 'https://example.test');
      service.testClient = MockClient((http.Request request) async {
        expect(request.url.toString(), 'https://example.test/coach/chat');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'ok', 'sources': [], 'disclaimers': []}),
          200,
        );
      });

      final inputs = {
        'salaireBrutMensuel': 6788.0,
        'age': 30,
        'canton': 'ZH',
        'tauxActivite': 100.0,
        'etatCivil': 'celibataire',
      };
      await service.chat(
        message: 'explique mon net',
        receiptId: 'rcpt-handoff',
        inputsHash: 'a' * 64,
        receiptInputs: inputs,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['receipt_id'], 'rcpt-handoff');
      expect(capturedBody!['inputs_hash'], 'a' * 64);
      expect(capturedBody!['receipt_inputs'], inputs);
    });

    test('chat() sans receiptId : aucun champ receipt dans le body', () async {
      SharedPreferences.setMockInitialValues({'auth_local_mode': false});
      await AuthService.saveToken('test-token', 'uid', 'u@test.ch');

      Map<String, dynamic>? capturedBody;
      final service = CoachChatApiService(baseUrl: 'https://example.test');
      service.testClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'ok', 'sources': [], 'disclaimers': []}),
          200,
        );
      });

      await service.chat(message: 'bonjour');

      expect(capturedBody!.containsKey('receipt_id'), isFalse);
      expect(capturedBody!.containsKey('receipt_inputs'), isFalse);
    });
  });
}
