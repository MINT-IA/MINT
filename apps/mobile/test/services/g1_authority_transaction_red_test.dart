import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _legacyPlanKey = 'financial_plan_v1';
const _activePlanSlotKey = 'financial_plan_active_slot_v1';
const _activeLppSlotKey = 'lpp_evidence_active_slot_v1';
const _activeAuthoritySlotKey = 'coach_authority_active_slot_v1';
const _authorityStagingSlotKey = 'coach_authority_staging_slot_v1';
const _planPurgeJournalPreference = 'financial_plan_purge_pending_v1';
const _planCleanupPendingKey = 'financial_plan_cleanup_pending_v1';
const _planSlotPrefix = '_financial_plan_slot_v1_';
const _lppSlotPrefix = '_coach_lpp_evidence_slot_v1_';
const _authoritySlotPrefix = '_coach_authority_slot_v1_';
const _ownerKey = '_coach_profile_owner_v1';
const _taxKey = '_coach_tax_snapshots_v1';
const _lppKey = '_coach_lpp_evidence_v1';
const _pillar3aKey = // gitleaks:allow — ledger field name, not a credential.
    '_coach_pillar3a_beneficiary_evidence_v1';

const _lppRootA =
    '{"schemaVersion":1,"self":null,"manualPartner":null,"legacyPartnerQuarantine":{"legacySchemaVersion":0,"reasonCodes":["A"],"presentKeys":["legacy_a"],"quarantinedAt":"2026-07-16T08:00:00.000Z"}}';
const _lppRootB =
    '{"schemaVersion":1,"self":null,"manualPartner":null,"legacyPartnerQuarantine":{"legacySchemaVersion":0,"reasonCodes":["B"],"presentKeys":["legacy_b"],"quarantinedAt":"2026-07-16T09:00:00.000Z"}}';
const _taxRootA =
    '{"schemaVersion":1,"snapshots":[],"legacyQuarantine":{"legacySchemaVersion":0,"reasonCodes":["A"],"values":{},"quarantinedAt":"2026-07-16T08:00:00.000Z"}}';
const _taxRootB =
    '{"schemaVersion":1,"snapshots":[],"legacyQuarantine":{"legacySchemaVersion":0,"reasonCodes":["B"],"values":{},"quarantinedAt":"2026-07-16T09:00:00.000Z"}}';

final class _ControllablePreferencesStore
    extends InMemorySharedPreferencesStore {
  _ControllablePreferencesStore([Map<String, Object> data = const {}])
      : super.withData({
          for (final entry in data.entries)
            entry.key.startsWith('flutter.')
                ? entry.key
                : 'flutter.${entry.key}': entry.value,
        });

  final failSetKeys = <String>{};
  final failRemoveKeys = <String>{};
  final throwRemoveKeys = <String>{};
  bool mutateBeforeFalse = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!failSetKeys.contains(key)) {
      return super.setValue(valueType, key, value);
    }
    if (mutateBeforeFalse) {
      await super.setValue(valueType, key, value);
    }
    return false;
  }

  @override
  Future<bool> remove(String key) async {
    if (throwRemoveKeys.contains(key)) {
      throw StateError('synthetic preference removal failure');
    }
    if (!failRemoveKeys.contains(key)) return super.remove(key);
    if (mutateBeforeFalse) await super.remove(key);
    return false;
  }
}

final class _BlockingBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  final readReached = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() async {
    readReached.complete();
    await releaseRead.future;
    return null;
  }

  @override
  Future<void> write(String value) async {}
}

String _manualPartnerLppRoot() => LppEvidenceRoot(
      self: null,
      manualPartner: LppEvidenceSnapshot(
        snapshotId: '33333333-3333-4333-8333-333333333333',
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 120000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '22222222-2222-4222-8222-222222222222',
            actorProfileOwnerId: _owner,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: DateTime.utc(2026, 6, 30),
            updatedAt: DateTime.utc(2026, 7, 16, 12),
          ),
        },
      ),
    ).toJsonString();

FinancialPlan _plan(String id) => FinancialPlan(
      id: id,
      goalDescription: 'Plan synthétique',
      goalCategory: 'goal_retirement_plan',
      monthlyTarget: 1250,
      milestones: const [],
      projectedOutcome: 250000,
      targetDate: DateTime.utc(2051, 1, 1),
      generatedAt: DateTime.utc(2026, 7, 16, 9),
      profileHashAtGeneration: 'hash',
      coachNarrative: 'Narrative.',
      confidenceLevel: 80,
      sources: const ['LPP art. 8'],
      disclaimer: 'Outil éducatif.',
    );

Map<String, dynamic> _authorityJournal(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map);

String _stagedAuthoritySlot(String raw) => raw.startsWith('{')
    ? _authorityJournal(raw)['stagedSlotId'] as String
    : raw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureValues = <String, String>{};
  var failLppWrites = false;
  var failAuthorityDeletes = false;
  final failDeleteBeforeMutationKeys = <String>{};
  final failDeleteAfterMutationKeys = <String>{};
  Completer<void>? blockedLppWrite;
  Completer<void>? lppWriteStarted;
  Completer<void>? releaseSensitiveReads;
  Completer<void>? sensitiveReadsReached;
  var sensitiveReadsTarget = 0;
  var sensitiveReadCount = 0;
  var authorityWriteCount = 0;
  int? blockedAuthorityWriteOrdinal;
  Completer<void>? authorityWriteReached;
  Completer<void>? releaseAuthorityWrite;
  var failSensitiveReads = false;
  var secureWriteCount = 0;

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _ControllablePreferencesStore();
    secureValues.clear();
    failLppWrites = false;
    failAuthorityDeletes = false;
    failDeleteBeforeMutationKeys.clear();
    failDeleteAfterMutationKeys.clear();
    blockedLppWrite = null;
    lppWriteStarted = null;
    releaseSensitiveReads = null;
    sensitiveReadsReached = null;
    sensitiveReadsTarget = 0;
    sensitiveReadCount = 0;
    authorityWriteCount = 0;
    blockedAuthorityWriteOrdinal = null;
    authorityWriteReached = null;
    releaseAuthorityWrite = null;
    failSensitiveReads = false;
    secureWriteCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final arguments = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final key = arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          if (key == null) return null;
          secureWriteCount++;
          if (key.startsWith(_authoritySlotPrefix)) {
            authorityWriteCount++;
            if (authorityWriteCount == blockedAuthorityWriteOrdinal) {
              secureValues[key] = arguments['value'] as String;
              authorityWriteReached?.complete();
              await releaseAuthorityWrite!.future;
              return null;
            }
          }
          if (failLppWrites &&
              (key.startsWith(_lppSlotPrefix) ||
                  key.startsWith(_authoritySlotPrefix))) {
            throw PlatformException(code: 'write-failed');
          }
          if (blockedLppWrite != null &&
              (key.startsWith(_lppSlotPrefix) ||
                  key.startsWith(_authoritySlotPrefix))) {
            if (lppWriteStarted?.isCompleted == false) {
              lppWriteStarted?.complete();
            }
            await blockedLppWrite!.future;
          }
          secureValues[key] = arguments['value'] as String;
          return null;
        case 'read':
          if (key == 'q_gross_salary_annual' && failSensitiveReads) {
            throw PlatformException(code: '-34018');
          }
          if (key == 'q_gross_salary_annual' &&
              releaseSensitiveReads != null &&
              sensitiveReadCount < sensitiveReadsTarget) {
            sensitiveReadCount++;
            if (sensitiveReadCount == sensitiveReadsTarget) {
              sensitiveReadsReached?.complete();
            }
            await releaseSensitiveReads!.future;
          }
          return key == null ? null : secureValues[key];
        case 'readAll':
          return Map<String, String>.from(secureValues);
        case 'delete':
          if (key != null) {
            if (failAuthorityDeletes && key.startsWith(_authoritySlotPrefix)) {
              throw PlatformException(code: 'authority-delete-failed');
            }
            if (failDeleteBeforeMutationKeys.contains(key)) {
              throw PlatformException(code: 'delete-failed-before-mutation');
            }
            secureValues.remove(key);
            if (failDeleteAfterMutationKeys.contains(key)) {
              throw PlatformException(code: 'delete-failed-after-mutation');
            }
          }
          return null;
        case 'deleteAll':
          secureValues.clear();
          return null;
      }
      return null;
    });
  });

  test('concurrent profile merges retain both values and provenance stamps',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_primary_focus': 'baseline',
    });
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);
    provider.updateFromAnswers(await ReportPersistenceService.loadAnswers());

    sensitiveReadsTarget = 2;
    releaseSensitiveReads = Completer<void>();
    sensitiveReadsReached = Completer<void>();
    final mergeX = provider.mergeAnswersWithProvenance(
      {'q_canton': 'GE'},
    );
    final mergeY = provider.mergeAnswersWithProvenance(
      {'q_date_of_birth': '1986-08-01'},
    );
    await Future.any<void>([
      sensitiveReadsReached!.future,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
    releaseSensitiveReads!.complete();
    await Future.wait([mergeX, mergeY]);

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'GE');
    expect(persisted['q_date_of_birth'], '1986-08-01');
    final provenance =
        Map<String, dynamic>.from(persisted['__provenance'] as Map);
    final timestamps = Map<String, dynamic>.from(
      persisted['_coach_data_timestamps'] as Map,
    );
    expect(provenance, containsPair('canton', isNotNull));
    expect(provenance, containsPair('dateOfBirth', isNotNull));
    expect(timestamps, containsPair('canton', isNotNull));
    expect(timestamps, containsPair('dateOfBirth', isNotNull));
  });

  test('primary focus interleave cannot overwrite a concurrent profile merge',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
      'q_primary_focus': 'baseline',
    });
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);
    provider.updateFromAnswers(await ReportPersistenceService.loadAnswers());

    sensitiveReadsTarget = 1;
    releaseSensitiveReads = Completer<void>();
    sensitiveReadsReached = Completer<void>();
    final merge = provider.mergeAnswersWithProvenance({'q_canton': 'GE'});
    await sensitiveReadsReached!.future;
    final focus = provider.updatePrimaryFocus('retirement');
    await Future<void>.delayed(Duration.zero);
    releaseSensitiveReads!.complete();
    await Future.wait([merge, focus]);

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'GE');
    expect(persisted['q_primary_focus'], 'retirement');
    expect(provider.profile?.canton, 'GE');
    expect(provider.reportAnswersSnapshot['q_primary_focus'], 'retirement');
  });

  test('owner resolution and concurrent merge share one canonical tail',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_gross_salary_annual': 96000,
      'q_canton': 'VD',
    });
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);
    provider.updateFromAnswers(await ReportPersistenceService.loadAnswers());

    sensitiveReadsTarget = 1;
    releaseSensitiveReads = Completer<void>();
    sensitiveReadsReached = Completer<void>();
    final owner = provider.ensureCanonicalProfileOwner();
    await sensitiveReadsReached!.future;
    final merge = provider.mergeAnswersWithProvenance({'q_canton': 'GE'});
    await Future<void>.delayed(Duration.zero);
    releaseSensitiveReads!.complete();
    final ownerId = await owner;
    await merge;

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'GE');
    expect(
      CoachProfileOwnerRoot.fromJsonString(persisted[_ownerKey])
          ?.profileOwnerId,
      ownerId,
    );
    expect(provider.profile?.canton, 'GE');
    expect(provider.canonicalProfileOwnerId, ownerId);
  });

  test('mutation publication runs in durable order before the tail releases',
      () async {
    final publications = <String>[];
    final first = ReportPersistenceService.mutateAnswers(
      (current) => Map<String, dynamic>.from(current)..['q_canton'] = 'GE',
      publish: (persisted) {
        publications.add('first:${persisted['q_canton']}');
      },
    );
    final second = ReportPersistenceService.mutateAnswers(
      (current) => Map<String, dynamic>.from(current)
        ..['q_date_of_birth'] = '1986-08-01',
      publish: (persisted) {
        publications.add(
          'second:${persisted['q_canton']}:${persisted['q_date_of_birth']}',
        );
      },
    );

    await Future.wait([first, second]);

    expect(
      publications,
      ['first:GE', 'second:GE:1986-08-01'],
    );
  });

  test('mutation migrates legacy LPP root without awaiting its own tail',
      () async {
    final wizardBytes = jsonEncode({
      'q_canton': 'VD',
      _lppKey: '__secure__',
    });
    final store = _ControllablePreferencesStore({
      'wizard_answers_v2': wizardBytes,
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    secureValues[_lppKey] = _lppRootA;

    final persisted = await ReportPersistenceService.mutateAnswers(
      (current) => Map<String, dynamic>.from(current)
        ..['q_date_of_birth'] = '1986-08-01',
    ).timeout(const Duration(milliseconds: 500));

    expect(persisted[_lppKey], _lppRootA);
    expect(persisted['q_canton'], 'VD');
    expect(persisted['q_date_of_birth'], '1986-08-01');
  });

  test('provider canonical writers cannot bypass the mutation boundary', () {
    final source = File(
      'lib/providers/coach_profile_provider.dart',
    ).readAsStringSync();
    final providerBody = source.substring(
      source.indexOf('class CoachProfileProvider extends ChangeNotifier'),
    );

    expect(
      providerBody,
      isNot(contains('ReportPersistenceService.loadAnswers()')),
      reason: 'canonical RMW writers must read inside mutateAnswers',
    );
    expect(
      providerBody,
      isNot(contains('ReportPersistenceService.saveAnswers(')),
      reason: 'canonical writers must commit through mutateAnswers',
    );
    expect(providerBody, isNot(contains('_taxProfilePersistence.saveAnswers')));
    expect(providerBody, isNot(contains('_lppProfilePersistence.saveAnswers')));
    expect(
      source,
      contains(
        'abstract interface class TaxProfilePersistence\n'
        '    implements CanonicalAnswerMutationPersistence',
      ),
    );
    expect(
      source,
      contains(
        'abstract interface class LppProfilePersistence\n'
        '    implements CanonicalAnswerMutationPersistence',
      ),
    );
  });

  test('ordinary reader cannot reconcile an in-flight authority commit',
      () async {
    const ownerRoot = CoachProfileOwnerRoot(_owner);
    await ReportPersistenceService.saveAnswers({
      'q_canton': 'VD',
      _ownerKey: ownerRoot.toJsonString(),
    });

    authorityWriteCount = 0;
    blockedAuthorityWriteOrdinal = 2;
    authorityWriteReached = Completer<void>();
    releaseAuthorityWrite = Completer<void>();
    final saveB = ReportPersistenceService.saveAnswers({
      'q_canton': 'GE',
      'q_date_of_birth': '1986-08-01',
      _ownerKey: ownerRoot.toJsonString(),
    });
    await authorityWriteReached!.future;

    var readerCompleted = false;
    final reader = ReportPersistenceService.loadAnswers().then((value) {
      readerCompleted = true;
      return value;
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(readerCompleted, isFalse);

    releaseAuthorityWrite!.complete();
    await saveB;
    final observed = await reader;
    expect(observed['q_canton'], 'GE');
    expect(observed['q_date_of_birth'], '1986-08-01');

    SharedPreferences.resetStatic();
    final cold = await ReportPersistenceService.loadAnswers();
    expect(cold['q_canton'], 'GE');
    expect(cold['q_date_of_birth'], '1986-08-01');
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString(_activeAuthoritySlotKey);
    expect(active, isNotNull);
    expect(secureValues, contains('$_authoritySlotPrefix$active'));
  });

  test('no-op mutation publishes without rotating strict authority', () async {
    const ownerRoot = CoachProfileOwnerRoot(_owner);
    await ReportPersistenceService.saveAnswers({
      'q_canton': 'VD',
      _ownerKey: ownerRoot.toJsonString(),
    });
    final prefs = await SharedPreferences.getInstance();
    final pointerBefore = prefs.getString(_activeAuthoritySlotKey);
    failLppWrites = true;
    Map<String, dynamic>? published;

    final result = await ReportPersistenceService.mutateAnswers(
      (current) => null,
      publish: (persisted) => published = persisted,
    );

    expect(result['q_canton'], 'VD');
    expect(published?['q_canton'], 'VD');
    expect(prefs.getString(_activeAuthoritySlotKey), pointerBefore);
  });

  test('canonical mutation durably removes one strict authority root',
      () async {
    const ownerRoot = CoachProfileOwnerRoot(_owner);
    await ReportPersistenceService.saveAnswers({
      'q_canton': 'VD',
      _ownerKey: ownerRoot.toJsonString(),
      _taxKey: _taxRootA,
      _lppKey: _lppRootA,
      _pillar3aKey: '{invalid',
    });
    await ReportPersistenceService.saveAnswers({'q_canton': 'GE'});
    expect(
      (await ReportPersistenceService.loadAnswers())[_pillar3aKey],
      '{invalid',
    );

    final published = await ReportPersistenceService.mutateAnswers(
      (current) => Map<String, dynamic>.from(current)..remove(_pillar3aKey),
    );
    expect(published, isNot(contains(_pillar3aKey)));

    SharedPreferences.resetStatic();
    final cold = await ReportPersistenceService.loadAnswers();
    expect(cold, isNot(contains(_pillar3aKey)));
    expect(cold[_ownerKey], ownerRoot.toJsonString());
    expect(cold[_taxKey], _taxRootA);
    expect(cold[_lppKey], _lppRootA);
    expect(cold['q_canton'], 'GE');
  });

  test('cold loose hydration tolerates unavailable sensitive placeholder',
      () async {
    final exactBytes = jsonEncode({
      'q_canton': 'GE',
      'q_gross_salary_annual': '__secure__',
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', exactBytes);
    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    secureWriteCount = 0;
    failSensitiveReads = true;
    final provider = CoachProfileProvider();
    addTearDown(provider.dispose);

    await provider.loadFromWizard();

    expect(provider.profile?.canton, 'GE');
    expect(
      provider.reportAnswersSnapshot['q_gross_salary_annual'],
      '__secure__',
    );
    expect(
      provider.profile?.userProvidedFields,
      isNot(contains('grossSalaryAnnual')),
    );
    expect(
      provider.profile?.userProvidedFields,
      isNot(contains('salary')),
    );
    expect(
      provider.profile?.dataSources,
      isNot(contains('salaireBrutMensuel')),
    );
    expect(
      provider.profile?.dataTimestamps,
      isNot(contains('salaireBrutMensuel')),
    );
    expect(prefs.getString('wizard_answers_v2'), exactBytes);
    expect(secureWriteCount, 0);
  });

  test('cold load cannot republish a snapshot older than a queued writer',
      () async {
    const ownerRoot = CoachProfileOwnerRoot(_owner);
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1980,
      'q_canton': 'VD',
      _ownerKey: ownerRoot.toJsonString(),
      _lppKey: _manualPartnerLppRoot(),
    });
    await ReportPersistenceService.setMiniOnboardingCompleted(true);
    final previousTypedLpp = FeatureFlags.typedLppEvidence;
    final previousAccountability = FeatureFlags.partnerLppAccountabilityEnabled;
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.partnerLppAccountabilityEnabled = true;
    addTearDown(() {
      FeatureFlags.typedLppEvidence = previousTypedLpp;
      FeatureFlags.partnerLppAccountabilityEnabled = previousAccountability;
    });
    final bindingPersistence = _BlockingBindingPersistence();
    final provider = CoachProfileProvider(
      partnerAccountabilityBindingStore: PartnerAccountabilityBindingStore(
        persistence: bindingPersistence,
        operationTimeout: const Duration(seconds: 5),
      ),
    );
    addTearDown(provider.dispose);

    final coldLoad = provider.loadFromWizard();
    await bindingPersistence.readReached.future;
    await provider.mergeAnswersWithProvenance({'q_canton': 'GE'});
    expect(provider.profile?.canton, 'GE');

    bindingPersistence.releaseRead.complete();
    await coldLoad;

    expect((await ReportPersistenceService.loadAnswers())['q_canton'], 'GE');
    expect(provider.profile?.canton, 'GE');
    expect(provider.reportAnswersSnapshot['q_canton'], 'GE');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('active plan pointer with absent payload blocks every mutation',
      () async {
    const missingSlot = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final store = _ControllablePreferencesStore({
      _activePlanSlotKey: missingSlot,
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(
        FinancialPlanService.save(_plan('new')), throwsStateError);
    await expectLater(FinancialPlanService.delete('old'), throwsStateError);

    final persisted = await store.getAll();
    expect(persisted['flutter.$_activePlanSlotKey'], missingSlot);
    expect(
      secureValues.keys.where((key) => key.startsWith(_planSlotPrefix)),
      isEmpty,
    );
  });

  test('malformed legacy plan plaintext is purged fail closed', () async {
    final store = _ControllablePreferencesStore({
      _legacyPlanKey: 'owner=$_owner salary=96000 {{{',
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;

    expect(await FinancialPlanService.loadAll(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_legacyPlanKey), isFalse);
  });

  test('failed first LPP publication leaves no fixed owner residue', () async {
    failLppWrites = true;
    const ownerRoot = CoachProfileOwnerRoot(_owner);

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: ownerRoot.toJsonString(),
        _lppKey: _lppRootA,
        'q_canton': 'VD',
      }),
      throwsStateError,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wizard_answers_v2'), isNull);
    expect(prefs.getString(_activeLppSlotKey), isNull);
    expect(secureValues[_ownerKey], isNull);
    expect(
      secureValues.keys.where((key) => key.startsWith(_lppSlotPrefix)),
      isEmpty,
    );
  });

  test(
      'authority cache performs no fixed sensitive write before pointer commit',
      () async {
    final store = _ControllablePreferencesStore()
      ..failSetKeys.add('flutter.$_activeAuthoritySlotKey');
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _lppKey: _lppRootB,
        'q_gross_salary_annual': 96000,
      }),
      throwsStateError,
    );

    expect(secureValues['q_gross_salary_annual'], isNull);
    expect(secureValues[_ownerKey], isNull);
    expect(secureValues[_lppKey], isNull);
  });

  test('failed staging-slot deletion keeps journal until cold retry purges it',
      () async {
    final store = _ControllablePreferencesStore()
      ..failSetKeys.add('flutter.wizard_answers_v2');
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    failAuthorityDeletes = true;

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      }),
      throwsStateError,
    );

    final prefs = await SharedPreferences.getInstance();
    final journal = prefs.getString(_authorityStagingSlotKey)!;
    final staged = _stagedAuthoritySlot(journal);
    expect(staged, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(secureValues['$_authoritySlotPrefix$staged'], isNotNull);
    expect(prefs.getString(_activeAuthoritySlotKey), isNull);

    failAuthorityDeletes = false;
    store.failSetKeys.clear();
    SharedPreferences.resetStatic();
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.getString(_authorityStagingSlotKey), isNull);
    expect(secureValues['$_authoritySlotPrefix$staged'], isNull);
  });

  test('failed cache rollback retains journal and never exposes staged B',
      () async {
    final store = _ControllablePreferencesStore()
      ..failSetKeys.add('flutter.$_activeAuthoritySlotKey')
      ..failRemoveKeys.add('flutter.wizard_answers_v2');
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      }),
      throwsStateError,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_activeAuthoritySlotKey), isNull);
    expect(prefs.getString(_authorityStagingSlotKey), isNotNull);
    expect(await ReportPersistenceService.loadAnswersReadOnly(), isEmpty);

    store.failSetKeys.clear();
    store.failRemoveKeys.clear();
    SharedPreferences.resetStatic();
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_authorityStagingSlotKey), isFalse);
    expect(coldPrefs.containsKey('wizard_answers_v2'), isFalse);
  });

  test('cold reader never combines staged B metadata with active A LPP root',
      () async {
    await ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _lppKey: _lppRootA,
      'q_canton': 'VD',
    });
    blockedLppWrite = Completer<void>();
    lppWriteStarted = Completer<void>();

    final replacement = ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _lppKey: _lppRootB,
      'q_canton': 'GE',
    });
    await lppWriteStarted!.future;

    try {
      final coldView = await ReportPersistenceService.loadAnswersReadOnly();
      expect(coldView['q_canton'], 'VD');
      expect(coldView[_lppKey], _lppRootA);
    } finally {
      blockedLppWrite!.complete();
      await replacement;
    }
  });

  test('post-commit legacy cleanup failure returns success with exact B',
      () async {
    final store = _ControllablePreferencesStore();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    final prefs = await SharedPreferences.getInstance();
    const legacySlot = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    await prefs.setString(_activeLppSlotKey, legacySlot);
    secureValues['$_lppSlotPrefix$legacySlot'] = _lppRootA;
    store.failRemoveKeys.add('flutter.$_activeLppSlotKey');

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      }),
      completes,
    );

    expect(prefs.getString(_activeAuthoritySlotKey), isNotNull);
    expect(prefs.getString(_activeLppSlotKey), legacySlot);
    final cold = await ReportPersistenceService.loadAnswersReadOnly();
    expect(cold['q_canton'], 'GE');
    expect(cold[_lppKey], _lppRootB);
    expect(cold[_lppKey], isNot('__secure__'));
  });

  for (final removalFailure in <String>['false', 'exception']) {
    test(
        'plan legacy cleanup $removalFailure after pointer returns B and retries cold',
        () async {
      final legacyBytes = jsonEncode([_plan('legacy').toJson()]);
      final store =
          _ControllablePreferencesStore({_legacyPlanKey: legacyBytes});
      if (removalFailure == 'false') {
        store.failRemoveKeys.add('flutter.$_legacyPlanKey');
      } else {
        store.throwRemoveKeys.add('flutter.$_legacyPlanKey');
      }
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = store;

      final migrated = await FinancialPlanService.loadAll();

      expect(migrated.single.id, 'legacy');
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getString(_activePlanSlotKey);
      expect(active, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(prefs.getString(_legacyPlanKey), legacyBytes);
      expect(prefs.getString(_planCleanupPendingKey), active);

      store.failRemoveKeys.clear();
      store.throwRemoveKeys.clear();
      SharedPreferences.resetStatic();
      expect((await FinancialPlanService.loadAll()).single.id, 'legacy');

      final coldPrefs = await SharedPreferences.getInstance();
      expect(coldPrefs.containsKey(_legacyPlanKey), isFalse);
      expect(coldPrefs.containsKey(_planCleanupPendingKey), isFalse);
      expect(
        secureValues.keys.where((key) => key.startsWith(_planSlotPrefix)),
        hasLength(1),
      );
    });
  }

  test('first-publication crash restores exact loose A from rollback slot',
      () async {
    const orphanSlot = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const rollbackSlot = 'dddddddddddddddddddddddddddddddd';
    final prefs = await SharedPreferences.getInstance();
    final exactA = jsonEncode({
      'q_canton': 'VD',
      'q_date_of_birth': '1986-08-01',
      'q_primary_focus': 'retirement',
      'q_gross_salary_annual': '__secure__',
      '__provenance': {
        'canton': {'source': 'userInput'},
        'dateOfBirth': {'source': 'userInput'},
      },
      '_coach_data_timestamps': {
        'canton': '2026-07-16T08:00:00.000Z',
        'dateOfBirth': '2026-07-16T08:00:00.000Z',
      },
    });
    secureValues['q_gross_salary_annual'] = '96000';
    secureValues['$_authoritySlotPrefix$orphanSlot'] = jsonEncode({
      'schemaVersion': 1,
      'answers': {
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _taxKey: _taxRootB,
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      },
    });
    secureValues['$_authoritySlotPrefix$rollbackSlot'] = jsonEncode({
      'schemaVersion': 1,
      'kind': 'authorityRollback',
      'wizardBytes': exactA,
    });
    await prefs.setString(
      'wizard_answers_v2',
      jsonEncode({
        _ownerKey: '__secure__',
        _taxKey: '__secure__',
        _lppKey: '__secure__',
        'q_canton': 'GE',
      }),
    );
    await prefs.setString(
      _authorityStagingSlotKey,
      jsonEncode({
        'schemaVersion': 2,
        'stagedSlotId': orphanSlot,
        'rollbackSlotId': rollbackSlot,
        'previousActiveSlotId': null,
      }),
    );

    final cold = await ReportPersistenceService.loadAnswers();

    expect(cold, {
      ...Map<String, dynamic>.from(jsonDecode(exactA) as Map),
      'q_gross_salary_annual': 96000,
    });
    expect(prefs.getString('wizard_answers_v2'), exactA);
    expect(prefs.getString(_activeAuthoritySlotKey), isNull);
    expect(prefs.getString(_authorityStagingSlotKey), isNull);
    expect(secureValues['$_authoritySlotPrefix$orphanSlot'], isNull);
    expect(secureValues['$_authoritySlotPrefix$rollbackSlot'], isNull);
    expect(secureValues['q_gross_salary_annual'], '96000');
    expect(cold, isNot(contains(_ownerKey)));
    expect(cold, isNot(contains(_taxKey)));
    expect(cold, isNot(contains(_lppKey)));
  });

  test('replacement crash exposes exact A and never republishes staged B',
      () async {
    await ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _taxKey: _taxRootA,
      _lppKey: _lppRootA,
      'q_canton': 'VD',
    });
    final prefs = await SharedPreferences.getInstance();
    const orphanSlot = 'cccccccccccccccccccccccccccccccc';
    secureValues['$_authoritySlotPrefix$orphanSlot'] = jsonEncode({
      'schemaVersion': 1,
      'answers': {
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _taxKey: _taxRootB,
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      },
    });
    await prefs.setString(
      'wizard_answers_v2',
      jsonEncode({
        _ownerKey: '__secure__',
        _taxKey: '__secure__',
        _lppKey: '__secure__',
        'q_canton': 'GE',
      }),
    );
    await prefs.setString(_authorityStagingSlotKey, orphanSlot);

    final cold = await ReportPersistenceService.loadAnswersReadOnly();
    expect(cold['q_canton'], 'VD');
    expect(cold[_taxKey], _taxRootA);
    expect(cold[_lppKey], _lppRootA);
    expect(cold.values, isNot(contains('__secure__')));

    await ReportPersistenceService.saveAnswers({
      ...cold,
      'q_birth_year': 1981,
    });

    final republished = await ReportPersistenceService.loadAnswersReadOnly();
    expect(republished['q_canton'], 'VD');
    expect(republished[_taxKey], _taxRootA);
    expect(republished[_lppKey], _lppRootA);
    expect(republished.values, isNot(contains('__secure__')));
    expect(prefs.getString(_authorityStagingSlotKey), isNull);
    expect(secureValues['$_authoritySlotPrefix$orphanSlot'], isNull);
  });

  test('replacement journal restores active A and removes B before-image',
      () async {
    await ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _taxKey: _taxRootA,
      _lppKey: _lppRootA,
      'q_canton': 'VD',
      'q_primary_focus': 'retirement',
    });
    final prefs = await SharedPreferences.getInstance();
    final activeA = prefs.getString(_activeAuthoritySlotKey)!;
    final exactCacheA = prefs.getString('wizard_answers_v2')!;
    const stagedB = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    const rollbackA = 'ffffffffffffffffffffffffffffffff';
    secureValues['$_authoritySlotPrefix$stagedB'] = jsonEncode({
      'schemaVersion': 1,
      'answers': {
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _taxKey: _taxRootB,
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      },
    });
    secureValues['$_authoritySlotPrefix$rollbackA'] = jsonEncode({
      'schemaVersion': 1,
      'kind': 'authorityRollback',
      'wizardBytes': exactCacheA,
    });
    await prefs.setString(
      'wizard_answers_v2',
      jsonEncode({
        _ownerKey: '__secure__',
        _taxKey: '__secure__',
        _lppKey: '__secure__',
        'q_canton': 'GE',
      }),
    );
    await prefs.setString(
      _authorityStagingSlotKey,
      jsonEncode({
        'schemaVersion': 2,
        'stagedSlotId': stagedB,
        'rollbackSlotId': rollbackA,
        'previousActiveSlotId': activeA,
      }),
    );

    SharedPreferences.resetStatic();
    final cold = await ReportPersistenceService.loadAnswers();
    final coldPrefs = await SharedPreferences.getInstance();

    expect(cold['q_canton'], 'VD');
    expect(cold['q_primary_focus'], 'retirement');
    expect(cold[_taxKey], _taxRootA);
    expect(cold[_lppKey], _lppRootA);
    expect(coldPrefs.getString('wizard_answers_v2'), exactCacheA);
    expect(coldPrefs.getString(_activeAuthoritySlotKey), activeA);
    expect(coldPrefs.getString(_authorityStagingSlotKey), isNull);
    expect(secureValues['$_authoritySlotPrefix$activeA'], isNotNull);
    expect(secureValues['$_authoritySlotPrefix$stagedB'], isNull);
    expect(secureValues['$_authoritySlotPrefix$rollbackA'], isNull);
  });

  test('post-commit staging-journal cleanup failure still returns exact B',
      () async {
    final store = _ControllablePreferencesStore()
      ..failRemoveKeys.add('flutter.$_authorityStagingSlotKey');
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(
      ReportPersistenceService.saveLppEvidenceAnswers({
        _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
        _lppKey: _lppRootB,
        'q_canton': 'GE',
      }),
      completes,
    );

    final prefs = await SharedPreferences.getInstance();
    final activeSlot = prefs.getString(_activeAuthoritySlotKey);
    expect(activeSlot, isNotNull);
    expect(
      _stagedAuthoritySlot(prefs.getString(_authorityStagingSlotKey)!),
      activeSlot,
    );
    final cold = await ReportPersistenceService.loadAnswersReadOnly();
    expect(cold['q_canton'], 'GE');
    expect(cold[_lppKey], _lppRootB);
    expect(cold.values, isNot(contains('__secure__')));
  });

  test('authority cleanup tombstone purges superseded A on cold restart',
      () async {
    await ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _lppKey: _lppRootA,
      'q_canton': 'VD',
    });
    final prefs = await SharedPreferences.getInstance();
    final oldSlot = prefs.getString(_activeAuthoritySlotKey)!;
    secureValues['q_gross_salary_annual'] = '96000';
    failAuthorityDeletes = true;

    await ReportPersistenceService.saveLppEvidenceAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _lppKey: _lppRootB,
      'q_canton': 'GE',
      'q_gross_salary_annual': 120000,
    });

    final active = prefs.getString(_activeAuthoritySlotKey)!;
    expect(active, isNot(oldSlot));
    expect(
      _stagedAuthoritySlot(prefs.getString(_authorityStagingSlotKey)!),
      active,
    );
    expect(secureValues['$_authoritySlotPrefix$oldSlot'], isNotNull);
    expect((await ReportPersistenceService.loadAnswersReadOnly())[_lppKey],
        _lppRootB);
    expect(
      (await ReportPersistenceService.loadAnswersReadOnly())[
          'q_gross_salary_annual'],
      120000,
    );
    expect(secureValues['q_gross_salary_annual'], isNull);

    failAuthorityDeletes = false;
    SharedPreferences.resetStatic();
    expect((await ReportPersistenceService.loadAnswers())[_lppKey], _lppRootB);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_authorityStagingSlotKey), isFalse);
    expect(secureValues['$_authoritySlotPrefix$oldSlot'], isNull);
    expect(secureValues['$_authoritySlotPrefix$active'], isNotNull);
    expect(
      secureValues.keys.where((key) => key.startsWith(_authoritySlotPrefix)),
      ['$_authoritySlotPrefix$active'],
    );
  });

  test('plan cleanup tombstone purges superseded A on cold restart', () async {
    await FinancialPlanService.save(_plan('before'));
    final prefs = await SharedPreferences.getInstance();
    final oldSlot = prefs.getString(_activePlanSlotKey)!;
    final oldKey = '$_planSlotPrefix$oldSlot';
    failDeleteBeforeMutationKeys.add(oldKey);

    await FinancialPlanService.save(_plan('after'));

    final active = prefs.getString(_activePlanSlotKey)!;
    expect(active, isNot(oldSlot));
    expect(prefs.getString(_planCleanupPendingKey), active);
    expect(secureValues[oldKey], isNotNull);
    expect((await FinancialPlanService.loadCurrent())?.id, 'after');

    failDeleteBeforeMutationKeys.clear();
    SharedPreferences.resetStatic();
    expect((await FinancialPlanService.loadCurrent())?.id, 'after');

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_planCleanupPendingKey), isFalse);
    expect(secureValues[oldKey], isNull);
    expect(secureValues['$_planSlotPrefix$active'], isNotNull);
  });

  test('strict placeholders without prior authority are rejected pre-commit',
      () async {
    await expectLater(
      ReportPersistenceService.saveAnswers({
        _ownerKey: '__secure__',
        _taxKey: '__secure__',
        _lppKey: '__secure__',
        'q_canton': 'GE',
      }),
      throwsStateError,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_activeAuthoritySlotKey), isNull);
    expect(
      secureValues.keys.where((key) => key.startsWith(_authoritySlotPrefix)),
      isEmpty,
    );
  });

  test('tax replacement prefs failure restores exact prior secure authority',
      () async {
    final store = _ControllablePreferencesStore();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    final ownerRoot = const CoachProfileOwnerRoot(_owner).toJsonString();
    await ReportPersistenceService.saveAnswers({
      _ownerKey: ownerRoot,
      _taxKey: _taxRootA,
      'q_canton': 'VD',
    });
    final prefs = await SharedPreferences.getInstance();
    final bytesBefore = prefs.getString('wizard_answers_v2');
    final secureBefore = Map<String, String>.from(secureValues);
    store.failSetKeys.add('flutter.wizard_answers_v2');

    await expectLater(
      ReportPersistenceService.saveAnswers({
        _ownerKey: ownerRoot,
        _taxKey: _taxRootB,
        'q_canton': 'GE',
      }),
      throwsStateError,
    );

    expect(prefs.getString('wizard_answers_v2'), bytesBefore);
    expect(secureValues, secureBefore);
    expect((await ReportPersistenceService.loadAnswers())[_taxKey], _taxRootA);
  });

  test('diagnostic reset purges financial plan and reports false removals',
      () async {
    final store = _ControllablePreferencesStore()..mutateBeforeFalse = true;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    await FinancialPlanService.save(_plan('private'));
    final prefs = await SharedPreferences.getInstance();
    final planPointer = prefs.getString(_activePlanSlotKey)!;
    final planSecureKey = '$_planSlotPrefix$planPointer';
    expect(secureValues[planSecureKey], isNotNull);
    store.failRemoveKeys.add('flutter.$_activePlanSlotKey');

    await expectLater(
      ReportPersistenceService.clearDiagnostic(),
      throwsStateError,
    );

    expect(prefs.containsKey(_activePlanSlotKey), isFalse);
    expect(secureValues[planSecureKey], isNull);
    expect(prefs.getBool(_planPurgeJournalPreference), isTrue);

    store.failRemoveKeys.clear();
    SharedPreferences.resetStatic();
    expect(await FinancialPlanService.loadAll(), isEmpty);
    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_planPurgeJournalPreference), isFalse);
  });

  test('cold start resumes purge before pointer removal', () async {
    await FinancialPlanService.save(_plan('private'));
    final prefs = await SharedPreferences.getInstance();
    final planPointer = prefs.getString(_activePlanSlotKey)!;
    final planSecureKey = '$_planSlotPrefix$planPointer';
    await prefs.setBool(_planPurgeJournalPreference, true);

    SharedPreferences.resetStatic();
    expect(await FinancialPlanService.loadAll(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_activePlanSlotKey), isFalse);
    expect(coldPrefs.containsKey(_planPurgeJournalPreference), isFalse);
    expect(secureValues[planSecureKey], isNull);
  });

  test('cold start resumes purge after pointer removal', () async {
    await FinancialPlanService.save(_plan('private'));
    final prefs = await SharedPreferences.getInstance();
    final planPointer = prefs.getString(_activePlanSlotKey)!;
    final planSecureKey = '$_planSlotPrefix$planPointer';
    await prefs.setBool(_planPurgeJournalPreference, true);
    await prefs.remove(_activePlanSlotKey);
    expect(secureValues[planSecureKey], isNotNull);

    SharedPreferences.resetStatic();
    expect(await FinancialPlanService.loadAll(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_planPurgeJournalPreference), isFalse);
    expect(secureValues[planSecureKey], isNull);
  });

  test('secure purge error retains journal and cold retry is idempotent',
      () async {
    await FinancialPlanService.save(_plan('private'));
    final prefs = await SharedPreferences.getInstance();
    final planPointer = prefs.getString(_activePlanSlotKey)!;
    final planSecureKey = '$_planSlotPrefix$planPointer';
    failDeleteBeforeMutationKeys.add(planSecureKey);

    await expectLater(FinancialPlanService.clear(), throwsStateError);

    expect(prefs.containsKey(_activePlanSlotKey), isFalse);
    expect(prefs.getBool(_planPurgeJournalPreference), isTrue);
    expect(secureValues[planSecureKey], isNotNull);

    failDeleteBeforeMutationKeys.clear();
    SharedPreferences.resetStatic();
    expect(await FinancialPlanService.loadAll(), isEmpty);
    expect(await FinancialPlanService.loadAll(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_planPurgeJournalPreference), isFalse);
    expect(secureValues[planSecureKey], isNull);
  });

  test('cold start finalizes a purge after secure deletion', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_planPurgeJournalPreference, true);

    SharedPreferences.resetStatic();
    expect(await FinancialPlanService.loadAll(), isEmpty);

    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.containsKey(_planPurgeJournalPreference), isFalse);
  });

  test(
      'provider reset publishes no empty memory when prefs purge reports false',
      () async {
    final store = _ControllablePreferencesStore()..mutateBeforeFalse = true;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    await ReportPersistenceService.saveAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _taxKey: _taxRootA,
      'q_birth_year': 1981,
      'q_canton': 'VD',
    });
    await FinancialPlanService.save(_plan('private'));
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    expect(provider.profile, isNotNull);
    final profileBefore = provider.profile;
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    final prefs = await SharedPreferences.getInstance();
    final authoritySlot = prefs.getString(_activeAuthoritySlotKey)!;
    final planSlot = prefs.getString(_activePlanSlotKey)!;
    store.failRemoveKeys.add('flutter.$_activeAuthoritySlotKey');

    await expectLater(provider.clear(), throwsStateError);

    expect(provider.profile, same(profileBefore));
    expect(notifications, 0);
    expect(prefs.containsKey(_activeAuthoritySlotKey), isFalse);
    expect(prefs.containsKey(_activePlanSlotKey), isFalse);
    expect(secureValues['$_authoritySlotPrefix$authoritySlot'], isNull);
    expect(secureValues['$_planSlotPrefix$planSlot'], isNull);
  });

  test('diagnostic reset reports secure delete error after purging all bytes',
      () async {
    await ReportPersistenceService.saveAnswers({
      _ownerKey: const CoachProfileOwnerRoot(_owner).toJsonString(),
      _taxKey: _taxRootA,
      'q_birth_year': 1981,
      'q_canton': 'VD',
    });
    await FinancialPlanService.save(_plan('private'));
    final prefs = await SharedPreferences.getInstance();
    final authoritySlot = prefs.getString(_activeAuthoritySlotKey)!;
    final authorityKey = '$_authoritySlotPrefix$authoritySlot';
    final planSlot = prefs.getString(_activePlanSlotKey)!;
    final planKey = '$_planSlotPrefix$planSlot';
    failDeleteAfterMutationKeys.add(authorityKey);

    await expectLater(
      ReportPersistenceService.clearDiagnostic(),
      throwsStateError,
    );

    expect(prefs.containsKey(_activeAuthoritySlotKey), isFalse);
    expect(prefs.containsKey(_activePlanSlotKey), isFalse);
    expect(secureValues[authorityKey], isNull);
    expect(secureValues[planKey], isNull);
    expect(
      secureValues.keys.where((key) =>
          key.startsWith(_authoritySlotPrefix) ||
          key.startsWith(_planSlotPrefix)),
      isEmpty,
    );
  });
}
