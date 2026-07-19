import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rootKey = '_coach_estate_evidence_v1';
const _wizardKey = 'wizard_answers_v2';
const _activeAuthoritySlotKey = 'coach_authority_active_slot_v1';
const _authoritySlotPrefix = '_coach_authority_slot_v1_';

String _estateRoot() => jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'matrimonialRegime': <String, dynamic>{
        'kind': 'participationInAcquests',
        'source': 'userInput',
        'updatedAt': '2026-07-20T10:00:00.000Z',
      },
      'civilStatusAtConfirmation': 'celibataire',
      'estateInstrumentReferences': <Map<String, dynamic>>[
        <String, dynamic>{
          'referenceId': '11111111-1111-4111-8111-111111111111',
          'kind': 'will',
          'ownerKind': 'self',
          'source': 'certificate',
          'sourceDate': '2026-01-15',
          'legalYear': 2026,
          'confirmedAt': '2026-01-16T10:00:00.000Z',
        },
      ],
    });

Map<String, dynamic> _activeAuthorityAnswers(
  SharedPreferences preferences,
  Map<String, String> secureValues,
) {
  final slotId = preferences.getString(_activeAuthoritySlotKey);
  expect(slotId, matches(RegExp(r'^[a-f0-9]{32}$')));
  final secureKey = '$_authoritySlotPrefix$slotId';
  expect(secureValues, contains(secureKey));
  final envelope = Map<String, dynamic>.from(
    jsonDecode(secureValues[secureKey]!) as Map,
  );
  expect(envelope['schemaVersion'], 1);
  return Map<String, dynamic>.from(envelope['answers'] as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secureValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final arguments = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final key = arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          if (key != null) secureValues[key] = arguments['value'] as String;
          return null;
        case 'read':
          return key == null ? null : secureValues[key];
        case 'readAll':
          return Map<String, String>.from(secureValues);
        case 'delete':
          if (key != null) secureValues.remove(key);
          return null;
        case 'deleteAll':
          secureValues.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  test('backendSafeAnswers redacts the strict local estate authority root', () {
    final root = _estateRoot();
    final local = <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      _rootKey: root,
    };
    final before = jsonEncode(local);

    final backend = ReportPersistenceService.backendSafeAnswers(local);

    expect(
      backend,
      <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
      },
      reason: 'local estate authority must never cross backend profile sync',
    );
    expect(backend.containsKey(_rootKey), isFalse);
    expect(jsonEncode(local), before,
        reason: 'redaction must not mutate local');
  });

  test('estate root is classified as strict sensitive authority', () {
    expect(
      SecureWizardStore.isSensitive(_rootKey),
      isTrue,
      reason: 'estate references and regime must never use plaintext storage',
    );
  });

  test('saveAnswers versions estate root in the unified authority slot',
      () async {
    final root = _estateRoot();

    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_canton': 'VD',
      _rootKey: root,
    });

    final preferences = await SharedPreferences.getInstance();
    final authority = _activeAuthorityAnswers(preferences, secureValues);
    expect(authority[_rootKey], root);
    final plaintext = preferences.getString(_wizardKey);
    expect(plaintext, isNotNull);
    expect(plaintext, isNot(contains(root)));
    expect(plaintext, isNot(contains('11111111-1111-4111-8111-111111111111')));
    expect(
      Map<String, dynamic>.from(jsonDecode(plaintext!) as Map)[_rootKey],
      '__secure__',
    );
    expect((await ReportPersistenceService.loadAnswers())[_rootKey], root);
  });

  test('mutateAnswers atomically introduces and restores estate authority',
      () async {
    final root = _estateRoot();
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_canton': 'VD',
    });

    await ReportPersistenceService.mutateAnswers((current) {
      return <String, dynamic>{...current, _rootKey: root};
    });

    final preferences = await SharedPreferences.getInstance();
    final authority = _activeAuthorityAnswers(preferences, secureValues);
    expect(authority[_rootKey], root);
    final plaintext = preferences.getString(_wizardKey);
    expect(plaintext, isNot(contains(root)));
    expect(
      Map<String, dynamic>.from(jsonDecode(plaintext!) as Map)[_rootKey],
      '__secure__',
    );

    SharedPreferences.resetStatic();
    expect((await ReportPersistenceService.loadAnswers())[_rootKey], root);
  });
}
