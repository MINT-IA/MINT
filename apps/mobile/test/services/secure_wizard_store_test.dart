import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _taxRoot = '{"schemaVersion":1,"snapshots":[],"legacyQuarantine":null}';
const _lppRootA =
    '{"schemaVersion":1,"self":null,"manualPartner":null,"legacyPartnerQuarantine":null}';
const _lppRootB =
    '{"schemaVersion":1, "self":null,"manualPartner":null,"legacyPartnerQuarantine":null}';
const _pillar3aBeneficiaryRoot =
    '{"schemaVersion":1,"contracts":[{"kind":"pillar3aBeneficiaryClause","ownerKind":"self","source":"certificate","contractReferenceId":"11111111-1111-4111-8111-111111111111","relation":"paidOrClosed","referenceId":"22222222-2222-4222-8222-222222222222","sourceDate":"2026-07-18","legalYear":2026,"confirmedAt":"2026-07-19T10:00:00.000Z","temporalBasis":null}]}';
const _activeLppSlotKey = 'lpp_evidence_active_slot_v1';
const _lppSlotPrefix = '_coach_lpp_evidence_slot_v1_';
const _activeAuthoritySlotKey = 'coach_authority_active_slot_v1';
const _authoritySlotPrefix = '_coach_authority_slot_v1_';

String _activeSecureAuthorityKey(SharedPreferences preferences) {
  final slotId = preferences.getString(_activeAuthoritySlotKey);
  expect(slotId, matches(RegExp(r'^[a-f0-9]{32}$')));
  return '$_authoritySlotPrefix$slotId';
}

Map<String, dynamic> _authorityAnswers(
  Map<String, String> secureStorageValues,
  String secureKey,
) {
  final envelope = Map<String, dynamic>.from(
    jsonDecode(secureStorageValues[secureKey]!) as Map,
  );
  expect(envelope['schemaVersion'], 1);
  return Map<String, dynamic>.from(envelope['answers'] as Map);
}

final class _FailOncePointerStore extends InMemorySharedPreferencesStore {
  _FailOncePointerStore() : super.empty();

  bool failNextPointerWrite = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failNextPointerWrite && key == 'flutter.$_activeAuthoritySlotKey') {
      failNextPointerWrite = false;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  var failWrites = false;
  var failLppWrites = false;
  var hangWrites = false;
  var delayLppReplacement = false;
  var delayFirstLppWrite = false;
  var failReadAll = false;
  Completer<void>? delayedRootAWrite;
  Completer<void>? rootAWriteStarted;
  String? prefsBytesObservedByLppWrite;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      final isLppKey = key == '_coach_lpp_evidence_v1' ||
          key == Pillar3aBeneficiaryEvidenceRoot.answerKey ||
          key.startsWith(_lppSlotPrefix) ||
          key.startsWith(_authoritySlotPrefix);
      String? authorityLppRoot;
      if (key.startsWith(_authoritySlotPrefix)) {
        try {
          authorityLppRoot = Map<String, dynamic>.from(
            (jsonDecode(args['value'] as String) as Map)['answers'] as Map,
          )['_coach_lpp_evidence_v1'] as String?;
        } on Object {
          authorityLppRoot = null;
        }
      }
      if (isLppKey) {
        final prefs = await SharedPreferences.getInstance();
        prefsBytesObservedByLppWrite = prefs.getString('wizard_answers_v2');
      }
      if (failWrites || (failLppWrites && isLppKey)) {
        throw PlatformException(code: '-34018');
      }
      if (hangWrites) return Completer<Object?>().future;
      if (delayLppReplacement &&
          isLppKey &&
          (args['value'] == _lppRootB || authorityLppRoot == _lppRootB)) {
        await Future<void>.delayed(const Duration(milliseconds: 2100));
      }
      if (delayFirstLppWrite &&
          isLppKey &&
          (args['value'] == _lppRootA || authorityLppRoot == _lppRootA)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (delayedRootAWrite != null &&
          (key.startsWith(_lppSlotPrefix) ||
              key.startsWith(_authoritySlotPrefix)) &&
          (args['value'] == _lppRootA || authorityLppRoot == _lppRootA)) {
        if (rootAWriteStarted?.isCompleted == false) {
          rootAWriteStarted?.complete();
        }
        await delayedRootAWrite!.future;
      }
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') {
      if (failReadAll) throw PlatformException(code: '-34018');
      return Map<String, String>.from(secureStorageValues);
    }
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
    failWrites = false;
    failLppWrites = false;
    hangWrites = false;
    delayLppReplacement = false;
    delayFirstLppWrite = false;
    failReadAll = false;
    delayedRootAWrite = null;
    rootAWriteStarted = null;
    prefsBytesObservedByLppWrite = null;
  });

  group('SecureWizardStore', () {
    test('treats gross salary ledger keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_gross_salary'), isTrue);
      expect(SecureWizardStore.isSensitive('q_gross_salary_annual'), isTrue);
      expect(SecureWizardStore.isSensitive('q_self_employed_income'), isTrue);
      expect(
        SecureWizardStore.isSensitive('q_company_profit_annual_chf'),
        isTrue,
      );
      expect(SecureWizardStore.isSensitive('q_net_income_period_chf'), isTrue);
    });

    test('treats broad wealth estimate as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_wealth_estimate'), isTrue);
      expect(SecureWizardStore.isSensitive('q_cash_total'), isTrue);
    });

    test('treats partner income as sensitive but not partner birth year', () {
      expect(SecureWizardStore.isSensitive('q_partner_net_income_chf'), isTrue);
      expect(SecureWizardStore.isSensitive('q_partner_birth_year'), isFalse);
    });

    test('treats debt ledger keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_has_consumer_debt'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_hypotheque'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_credit'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_leasing'), isTrue);
      expect(SecureWizardStore.isSensitive('_coach_dettes_autres'), isTrue);
    });

    test('treats the contract-scoped 3a beneficiary root as sensitive', () {
      expect(
        SecureWizardStore.isSensitive(
          Pillar3aBeneficiaryEvidenceRoot.answerKey,
        ),
        isTrue,
      );
    });

    test('does not treat public profile keys as sensitive', () {
      expect(SecureWizardStore.isSensitive('q_canton'), isFalse);
      expect(SecureWizardStore.isSensitive('q_birth_year'), isFalse);
    });

    test('does not rewrite secure placeholders', () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_gross_salary_annual': '__secure__',
      });

      expect(cleaned['q_gross_salary_annual'], '__secure__');
    });

    test('round-trips debt presence as a bool', () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_has_consumer_debt': true,
      });

      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

      expect(cleaned['q_has_consumer_debt'], '__secure__');
      expect(restored['q_has_consumer_debt'], true);
    });

    test('does not restore stale secure values absent from answers', () async {
      await SecureWizardStore.secureSensitiveKeys({
        'q_cash_total': 36000,
      });

      final restored = await SecureWizardStore.restoreSensitiveKeys({
        'q_self_employed_income': 144000,
      });

      expect(restored, containsPair('q_self_employed_income', 144000));
      expect(restored.containsKey('q_cash_total'), isFalse);
    });

    test('keeps local dev value when secure write throws', () async {
      failWrites = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': 144000,
      });

      expect(cleaned['q_net_income_period_chf'], 144000);
      expect(secureStorageValues, isEmpty);
    });

    test('keeps local dev value when secure write times out', () async {
      hangWrites = true;

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        'q_net_income_period_chf': 144000,
      });

      expect(cleaned['q_net_income_period_chf'], 144000);
      expect(secureStorageValues, isEmpty);
    });

    test('deletes stale secure debt amount when value is null', () async {
      await SecureWizardStore.secureSensitiveKeys({
        '_coach_dettes_autres': 25000,
      });

      final cleaned = await SecureWizardStore.secureSensitiveKeys({
        '_coach_dettes_autres': null,
      });
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

      expect(cleaned.containsKey('_coach_dettes_autres'), isFalse);
      expect(restored['_coach_dettes_autres'], isNull);
    });

    test('strict tax root round-trips only through secure storage', () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys(
        const {
          '_coach_tax_snapshots_v1': _taxRoot,
          'q_canton': 'VD',
        },
      );
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

      expect(cleaned, containsPair('q_canton', 'VD'));
      expect(cleaned['_coach_tax_snapshots_v1'], '__secure__');
      expect(secureStorageValues['_coach_tax_snapshots_v1'], _taxRoot);
      expect(restored['_coach_tax_snapshots_v1'], _taxRoot);
    });

    test('strict tax root preserves malformed scalar text byte-for-byte',
        () async {
      for (final rawRoot in const ['true', 'false', '123', '1.5']) {
        final cleaned = await SecureWizardStore.secureSensitiveKeys({
          '_coach_tax_snapshots_v1': rawRoot,
        });
        final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);

        expect(cleaned['_coach_tax_snapshots_v1'], '__secure__');
        expect(restored['_coach_tax_snapshots_v1'], rawRoot);
        expect(restored['_coach_tax_snapshots_v1'], isA<String>());
      }
    });

    test('pillar 3a beneficiary root round-trips only through secure storage',
        () async {
      final cleaned = await SecureWizardStore.secureSensitiveKeys(
        const <String, dynamic>{
          'q_canton': 'VD',
          Pillar3aBeneficiaryEvidenceRoot.answerKey: _pillar3aBeneficiaryRoot,
        },
      );

      expect(cleaned['q_canton'], 'VD');
      expect(
        cleaned[Pillar3aBeneficiaryEvidenceRoot.answerKey],
        '__secure__',
      );
      expect(
        secureStorageValues[Pillar3aBeneficiaryEvidenceRoot.answerKey],
        _pillar3aBeneficiaryRoot,
      );
      final restored = await SecureWizardStore.restoreSensitiveKeys(cleaned);
      expect(
        restored[Pillar3aBeneficiaryEvidenceRoot.answerKey],
        _pillar3aBeneficiaryRoot,
      );
    });

    test(
        'strict tax failure keeps SharedPreferences byte-stable and unpublished',
        () async {
      const previousBytes = '{"existing":"unchanged"}';
      SharedPreferences.setMockInitialValues({
        'wizard_answers_v2': previousBytes,
      });
      failWrites = true;
      var published = false;

      await expectLater(
        () async {
          await ReportPersistenceService.saveAnswers(
            const {'_coach_tax_snapshots_v1': _taxRoot},
          );
          published = true;
        }(),
        throwsStateError,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('wizard_answers_v2'), previousBytes);
      expect(published, isFalse);
      expect(secureStorageValues, isEmpty);
    });

    test('first LPP write failure removes staged prefs and publishes nothing',
        () async {
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('wizard_answers_v2'), isNull);
      failLppWrites = true;

      await expectLater(
        ReportPersistenceService.saveLppEvidenceAnswers(
          const <String, dynamic>{
            'q_canton': 'VD',
            '_coach_lpp_evidence_v1': _lppRootA,
          },
        ),
        throwsStateError,
      );

      expect(preferences.getString('wizard_answers_v2'), isNull);
      expect(secureStorageValues['_coach_lpp_evidence_v1'], isNull);
      expect(preferences.getString(_activeAuthoritySlotKey), isNull);
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        isEmpty,
      );
      expect(
        prefsBytesObservedByLppWrite,
        isNull,
        reason: 'the encrypted authority slot is staged before its prefs cache',
      );
    });

    test('replacement LPP failure preserves prior prefs bytes and secure root',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final previousBytes = preferences.getString('wizard_answers_v2');
      final previousSlotId = preferences.getString(_activeAuthoritySlotKey);
      final previousSecureKey = _activeSecureAuthorityKey(preferences);
      expect(
        _authorityAnswers(
            secureStorageValues, previousSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      failLppWrites = true;

      await expectLater(
        ReportPersistenceService.saveLppEvidenceAnswers(
          const <String, dynamic>{
            'q_canton': 'GE',
            '_coach_lpp_evidence_v1': _lppRootB,
          },
        ),
        throwsStateError,
      );

      expect(preferences.getString('wizard_answers_v2'), previousBytes);
      expect(preferences.getString(_activeAuthoritySlotKey), previousSlotId);
      expect(
        _authorityAnswers(
            secureStorageValues, previousSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'VD');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
    });

    test('late secure replacement cannot become active after timeout',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final previousBytes = preferences.getString('wizard_answers_v2');
      final previousSlotId = preferences.getString(_activeAuthoritySlotKey);
      final previousSecureKey = _activeSecureAuthorityKey(preferences);
      delayLppReplacement = true;

      await expectLater(
        ReportPersistenceService.saveLppEvidenceAnswers(
          const <String, dynamic>{
            'q_canton': 'GE',
            '_coach_lpp_evidence_v1': _lppRootB,
          },
        ),
        throwsStateError,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(preferences.getString('wizard_answers_v2'), previousBytes);
      expect(preferences.getString(_activeAuthoritySlotKey), previousSlotId);
      expect(
        _authorityAnswers(
            secureStorageValues, previousSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        <String>[previousSecureKey],
      );
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'VD');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
    });

    test('late first secure slot stays unavailable after timeout', () async {
      delayLppReplacement = true;

      await expectLater(
        ReportPersistenceService.saveLppEvidenceAnswers(
          const <String, dynamic>{
            'q_canton': 'GE',
            '_coach_lpp_evidence_v1': _lppRootB,
          },
        ),
        throwsStateError,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('wizard_answers_v2'), isNull);
      expect(preferences.getString(_activeAuthoritySlotKey), isNull);
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        isEmpty,
      );
      expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    });

    test('successful LPP write stages authority before placeholder cache',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
          Pillar3aBeneficiaryEvidenceRoot.answerKey: _pillar3aBeneficiaryRoot,
        },
      );

      expect(
        prefsBytesObservedByLppWrite,
        isNull,
      );
      final preferences = await SharedPreferences.getInstance();
      final activeSlotId = preferences.getString(_activeAuthoritySlotKey)!;
      final activeSecureKey = _activeSecureAuthorityKey(preferences);
      expect(secureStorageValues['_coach_lpp_evidence_v1'], isNull);
      expect(
        _authorityAnswers(
            secureStorageValues, activeSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      expect(
        _authorityAnswers(secureStorageValues, activeSecureKey)[
            Pillar3aBeneficiaryEvidenceRoot.answerKey],
        _pillar3aBeneficiaryRoot,
      );
      expect(
        jsonDecode(preferences.getString('wizard_answers_v2')!),
        containsPair(
          '_coach_pillar3a_beneficiary_evidence_v1',
          '__secure__',
        ),
      );
      expect(
        preferences.getString('wizard_answers_v2'),
        isNot(contains(activeSlotId)),
      );
      expect(_lppRootA, isNot(contains(activeSlotId)));
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'VD');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
      expect(
        restored['_coach_pillar3a_beneficiary_evidence_v1'],
        _pillar3aBeneficiaryRoot,
      );
    });

    test('successful replacement activates new slot and cleans the old slot',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final oldSlotId = preferences.getString(_activeAuthoritySlotKey);
      final oldSecureKey = _activeSecureAuthorityKey(preferences);

      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'GE',
          '_coach_lpp_evidence_v1': _lppRootB,
        },
      );

      final newSlotId = preferences.getString(_activeAuthoritySlotKey);
      final newSecureKey = _activeSecureAuthorityKey(preferences);
      expect(newSlotId, isNot(oldSlotId));
      expect(secureStorageValues[oldSecureKey], isNull);
      expect(
        _authorityAnswers(
            secureStorageValues, newSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootB,
      );
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'GE');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootB);
    });

    test('generic save versions the whole active authority atomically',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final activeSlotId = preferences.getString(_activeAuthoritySlotKey);
      final activeSecureKey = _activeSecureAuthorityKey(preferences);
      final unrelatedUpdate = await ReportPersistenceService.loadAnswers()
        ..['q_canton'] = 'GE';

      await ReportPersistenceService.saveAnswers(unrelatedUpdate);

      final replacementSlotId = preferences.getString(_activeAuthoritySlotKey);
      final replacementSecureKey = _activeSecureAuthorityKey(preferences);
      expect(replacementSlotId, isNot(activeSlotId));
      expect(secureStorageValues[activeSecureKey], isNull);
      expect(
        _authorityAnswers(secureStorageValues, replacementSecureKey)[
            '_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      expect(secureStorageValues['_coach_lpp_evidence_v1'], isNull);
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'GE');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
    });

    test('concurrent LPP saves publish matching wizard bytes and active slot',
        () async {
      delayFirstLppWrite = true;
      final first = ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'GE',
          '_coach_lpp_evidence_v1': _lppRootB,
        },
      );

      await Future.wait<void>(<Future<void>>[first, second]);

      final preferences = await SharedPreferences.getInstance();
      final activeSecureKey = _activeSecureAuthorityKey(preferences);
      expect(
        _authorityAnswers(
            secureStorageValues, activeSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootB,
      );
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        <String>[activeSecureKey],
      );
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'GE');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootB);
    });

    test('legacy migration cannot activate after a newer dedicated save',
        () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'wizard_answers_v2',
        jsonEncode(const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': '__secure__',
        }),
      );
      await SecureWizardStore.write('_coach_lpp_evidence_v1', _lppRootA);
      delayedRootAWrite = Completer<void>();
      rootAWriteStarted = Completer<void>();
      final migration = ReportPersistenceService.loadAnswers();
      await rootAWriteStarted!.future;

      final dedicated = ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'GE',
          '_coach_lpp_evidence_v1': _lppRootB,
        },
      );
      await Future<void>.delayed(Duration.zero);
      delayedRootAWrite!.complete();
      await Future.wait<Object?>(<Future<Object?>>[migration, dedicated]);

      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'GE');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootB);
    });

    test('generic save cannot erase an in-progress staged LPP placeholder',
        () async {
      delayedRootAWrite = Completer<void>();
      rootAWriteStarted = Completer<void>();
      final dedicated = ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      await rootAWriteStarted!.future;

      final generic = ReportPersistenceService.saveAnswers(
        const <String, dynamic>{'q_canton': 'GE'},
      );
      await Future<void>.delayed(Duration.zero);
      delayedRootAWrite!.complete();
      await Future.wait<void>(<Future<void>>[dedicated, generic]);

      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'GE');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
    });

    test('clearDiagnostic waits for an in-flight LPP save then purges it',
        () async {
      delayedRootAWrite = Completer<void>();
      rootAWriteStarted = Completer<void>();
      final save = ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      await rootAWriteStarted!.future;

      final clear = ReportPersistenceService.clearDiagnostic();
      await Future<void>.delayed(Duration.zero);
      delayedRootAWrite!.complete();
      await Future.wait<void>(<Future<void>>[save, clear]);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('wizard_answers_v2'), isNull);
      expect(preferences.getString(_activeAuthoritySlotKey), isNull);
      expect(
        secureStorageValues.keys.where(
          (key) =>
              key == '_coach_lpp_evidence_v1' ||
              key.startsWith(_authoritySlotPrefix),
        ),
        isEmpty,
      );
    });

    test('active-slot failure restores exact prefs and previous pointer',
        () async {
      final store = _FailOncePointerStore();
      SharedPreferencesStorePlatform.instance = store;
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final previousBytes = preferences.getString('wizard_answers_v2');
      final previousSlotId = preferences.getString(_activeAuthoritySlotKey);
      final previousSecureKey = _activeSecureAuthorityKey(preferences);
      store.failNextPointerWrite = true;

      await expectLater(
        ReportPersistenceService.saveLppEvidenceAnswers(
          const <String, dynamic>{
            'q_canton': 'GE',
            '_coach_lpp_evidence_v1': _lppRootB,
          },
        ),
        throwsStateError,
      );

      expect(preferences.getString('wizard_answers_v2'), previousBytes);
      expect(preferences.getString(_activeAuthoritySlotKey), previousSlotId);
      expect(
        _authorityAnswers(
            secureStorageValues, previousSecureKey)['_coach_lpp_evidence_v1'],
        _lppRootA,
      );
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        <String>[previousSecureKey],
      );
      final restored = await ReportPersistenceService.loadAnswers();
      expect(restored['q_canton'], 'VD');
      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
    });

    test('legacy fixed root migrates once to an active versioned slot',
        () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'wizard_answers_v2',
        jsonEncode(const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': '__secure__',
        }),
      );
      await SecureWizardStore.write('_coach_lpp_evidence_v1', _lppRootA);
      expect(preferences.getString(_activeLppSlotKey), isNull);
      expect(secureStorageValues['_coach_lpp_evidence_v1'], _lppRootA);

      final restored = await ReportPersistenceService.loadAnswers();

      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
      expect(secureStorageValues['_coach_lpp_evidence_v1'], isNull);
      final activeLegacySlot = preferences.getString(_activeLppSlotKey)!;
      expect(
        secureStorageValues['$_lppSlotPrefix$activeLegacySlot'],
        _lppRootA,
      );
    });

    test('failed legacy migration keeps the fixed root readable', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'wizard_answers_v2',
        jsonEncode(const <String, dynamic>{
          'q_canton': 'VD',
          '_coach_lpp_evidence_v1': '__secure__',
        }),
      );
      await SecureWizardStore.write('_coach_lpp_evidence_v1', _lppRootA);
      failLppWrites = true;

      final restored = await ReportPersistenceService.loadAnswers();

      expect(restored['_coach_lpp_evidence_v1'], _lppRootA);
      expect(preferences.getString(_activeLppSlotKey), isNull);
      expect(secureStorageValues['_coach_lpp_evidence_v1'], _lppRootA);
      expect(
        secureStorageValues.keys.where((key) => key.startsWith(_lppSlotPrefix)),
        isEmpty,
      );
    });

    test('deleteAll removes active and orphan versioned LPP slots', () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          '_coach_lpp_evidence_v1': _lppRootA,
        },
      );
      secureStorageValues['${_lppSlotPrefix}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'] =
          _lppRootB;

      await SecureWizardStore.deleteAll();

      expect(
        secureStorageValues.keys.where((key) => key.startsWith(_lppSlotPrefix)),
        isEmpty,
      );
    });

    test('strict purge removes fixed and unified 3a beneficiary authority',
        () async {
      await ReportPersistenceService.saveLppEvidenceAnswers(
        const <String, dynamic>{
          '_coach_lpp_evidence_v1': _lppRootA,
          Pillar3aBeneficiaryEvidenceRoot.answerKey: _pillar3aBeneficiaryRoot,
        },
      );
      await SecureWizardStore.write(
        Pillar3aBeneficiaryEvidenceRoot.answerKey,
        _pillar3aBeneficiaryRoot,
      );

      await SecureWizardStore.deleteAllStrict();

      expect(
        secureStorageValues[Pillar3aBeneficiaryEvidenceRoot.answerKey],
        isNull,
      );
      expect(
        secureStorageValues.keys
            .where((key) => key.startsWith(_authoritySlotPrefix)),
        isEmpty,
      );
    });

    test('inactive-slot cleanup retains active root and deletes every orphan',
        () async {
      const activeSlotId = '11111111111111111111111111111111';
      const orphanSlotIdA = '22222222222222222222222222222222';
      const orphanSlotIdB = '33333333333333333333333333333333';
      await SecureWizardStore.writeLppEvidenceSlot(activeSlotId, _lppRootA);
      await SecureWizardStore.writeLppEvidenceSlot(orphanSlotIdA, _lppRootB);
      await SecureWizardStore.writeLppEvidenceSlot(orphanSlotIdB, _lppRootB);

      await SecureWizardStore.deleteInactiveLppEvidenceSlots(activeSlotId);

      expect(secureStorageValues['$_lppSlotPrefix$activeSlotId'], _lppRootA);
      expect(secureStorageValues['$_lppSlotPrefix$orphanSlotIdA'], isNull);
      expect(secureStorageValues['$_lppSlotPrefix$orphanSlotIdB'], isNull);
    });

    test('inactive-slot cleanup failure never blocks active-root reads',
        () async {
      const activeSlotId = '11111111111111111111111111111111';
      const orphanSlotId = '22222222222222222222222222222222';
      await SecureWizardStore.writeLppEvidenceSlot(activeSlotId, _lppRootA);
      await SecureWizardStore.writeLppEvidenceSlot(orphanSlotId, _lppRootB);
      failReadAll = true;

      await expectLater(
        SecureWizardStore.deleteInactiveLppEvidenceSlots(activeSlotId),
        completes,
      );

      expect(
        await SecureWizardStore.readLppEvidenceSlot(activeSlotId),
        _lppRootA,
      );
      expect(secureStorageValues['$_lppSlotPrefix$orphanSlotId'], _lppRootB);
    });
  });
}
