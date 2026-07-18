import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _coldLppContract(CoachProfile profile) {
  Map<String, Object?> fact(
    String path,
    double? value,
  ) {
    return <String, Object?>{
      'value': value,
      'source': profile.dataSources[path]?.name,
      'hasUpdatedAt': profile.dataTimestamps.containsKey(path),
      'hasSourceDateSlot': profile.dataSourceDates.containsKey(path),
      'sourceDate': profile.dataSourceDates[path]?.toIso8601String(),
    };
  }

  return <String, Object?>{
    'retirementPensionAnnual': fact(
      'prevoyance.projectedRenteLpp',
      profile.prevoyance.projectedRenteLpp,
    ),
    'retirementCapitalLumpSum': fact(
      'prevoyance.projectedCapital65',
      profile.prevoyance.projectedCapital65,
    ),
    'disabilityPensionAnnual': fact(
      'prevoyance.disabilityCoverage',
      profile.prevoyance.disabilityCoverage,
    ),
    'disabilityCapitalLumpSum': fact(
      'prevoyance.lppDisabilityCapital',
      profile.prevoyance.lppDisabilityCapital,
    ),
    'deathCapitalLumpSum': fact(
      'prevoyance.deathCoverage',
      profile.prevoyance.deathCoverage,
    ),
  };
}

Map<String, Object?> _expectedFact(
  double value,
  String sourceDate,
) =>
    <String, Object?>{
      'value': value,
      'source': ProfileDataSource.certificate.name,
      'hasUpdatedAt': true,
      'hasSourceDateSlot': true,
      'sourceDate': sourceDate,
    };

const _activeLppSlotKey = 'lpp_evidence_active_slot_v1';
const _lppSlotPrefix = '_coach_lpp_evidence_slot_v1_';
const _activeAuthoritySlotKey = 'coach_authority_active_slot_v1';
const _authoritySlotPrefix = '_coach_authority_slot_v1_';

String _activeAuthoritySecureKey(SharedPreferences preferences) {
  final slotId = preferences.getString(_activeAuthoritySlotKey);
  expect(slotId, matches(RegExp(r'^[a-f0-9]{32}$')));
  return '$_authoritySlotPrefix$slotId';
}

Map<String, dynamic> _activeAuthorityAnswers(
  SharedPreferences preferences,
  Map<String, String> secureStorageValues,
) {
  final payload = secureStorageValues[_activeAuthoritySecureKey(preferences)]!;
  final envelope = Map<String, dynamic>.from(jsonDecode(payload) as Map);
  expect(envelope['schemaVersion'], 1);
  return Map<String, dynamic>.from(envelope['answers'] as Map);
}

String _activeAuthorityLppRoot(
  SharedPreferences preferences,
  Map<String, String> secureStorageValues,
) =>
    _activeAuthorityAnswers(
        preferences, secureStorageValues)['_coach_lpp_evidence_v1'] as String;

final class _FailingLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence {
  _FailingLppPersistence(this.answers);

  final Map<String, dynamic> answers;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    saveAttempts += 1;
    throw StateError('synthetic strict-secure failure');
  }
}

final class _RecordingLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _RecordingLppPersistence(this.answers);

  final Map<String, dynamic> answers;
  Map<String, dynamic>? lastSaved;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    saveAttempts += 1;
    lastSaved = Map<String, dynamic>.from(answers);
    this.answers
      ..clear()
      ..addAll(lastSaved!);
  }
}

final class _DelayedFirstLppPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _DelayedFirstLppPersistence(this.answers);

  final Map<String, dynamic> answers;
  final events = <String>[];
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  var loadAttempts = 0;
  var saveAttempts = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() {
    loadAttempts += 1;
    return Future<Map<String, dynamic>>.value(
      Map<String, dynamic>.from(answers),
    );
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> nextAnswers) async {
    saveAttempts += 1;
    final root = LppEvidenceRoot.fromJsonString(
      nextAnswers['_coach_lpp_evidence_v1'],
    );
    final label = root == null
        ? 'none'
        : root.self != null && root.manualPartner != null
            ? 'both'
            : root.self != null
                ? 'self'
                : 'manual';
    events.add('save-start:$label');
    if (saveAttempts == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    answers
      ..clear()
      ..addAll(Map<String, dynamic>.from(nextAnswers));
    events.add('save-done:$label');
  }
}

final class _MemoryPartnerBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

final class _PartnerStatusApi implements PartnerAccountabilityApi {
  _PartnerStatusApi(this.expiries);

  final Map<String, DateTime> expiries;

  @override
  Future<void> delete(String endpoint) async {}

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    final receiptId = endpoint.split('/').elementAt(3);
    final expiry = expiries[receiptId];
    if (expiry == null) throw StateError('unknown synthetic receipt');
    return <String, dynamic>{
      'receiptId': receiptId,
      'status': 'active',
      'noticeVersion': 'notice-v1',
      'policyVersion': 'policy-v1',
      'expiresAt': expiry.toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async =>
      throw StateError('post must not be called');
}

final class _PartnerTestGate {
  _PartnerTestGate(this.now)
      : store = PartnerAccountabilityBindingStore(
          persistence: _MemoryPartnerBindingPersistence(),
        ),
        expiries = <String, DateTime>{} {
    service = PartnerAccountabilityService(api: _PartnerStatusApi(expiries));
  }

  static const ownerId = '22222222-2222-4222-8222-222222222222';
  final DateTime Function() now;
  final PartnerAccountabilityBindingStore store;
  final Map<String, DateTime> expiries;
  late final PartnerAccountabilityService service;
  int _sequence = 0;

  Future<LppReviewConfirmation> confirmation({
    required Map<LppEvidenceFactKey, LppReviewedFact> facts,
    required DateTime? sourceDate,
  }) async {
    _sequence += 1;
    final suffix = _sequence.toString().padLeft(12, '0');
    final receiptId = '00000000-0000-4000-8000-$suffix';
    final acquisitionId = '10000000-0000-4000-8000-$suffix';
    final current = now().toUtc();
    final expiresAt = current.add(const Duration(days: 365));
    expiries[receiptId] = expiresAt;
    await store.beginPending(
      receiptId: receiptId,
      manualPartnerOwnerId: ownerId,
      now: current,
      noticeVersion: 'notice-v1',
      policyVersion: 'policy-v1',
      privacyContact: 'privacy@example.test',
      rightsChannel: 'https://example.test/rights',
    );
    await store.markReceiptCreated(
      receiptId: receiptId,
      manualPartnerOwnerId: ownerId,
      now: current,
      expiresAt: expiresAt,
    );
    return LppReviewConfirmation(
      authorization: LppAcquisitionAuthorization(
        acquisitionId: acquisitionId,
        subject: LppEvidenceOwnerKind.manualPartner,
        partnerAttested: true,
        policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
        declaredAt: current,
        documentSha256:
            '1111111111111111111111111111111111111111111111111111111111111111',
        manualPartnerOwnerId: ownerId,
        receiptId: receiptId,
      ),
      sourceDate: sourceDate,
      facts: facts,
      partnerAccountabilityContext: ManualPartnerAccountabilityContext(
        receiptId: receiptId,
        ownerId: ownerId,
        expiresAt: expiresAt,
        noticeVersion: 'notice-v1',
        policyVersion: 'policy-v1',
        receiptStatus: PartnerAccountabilityReceiptStatus.active,
      ),
    );
  }
}

LppAcquisitionAuthorization _lppAuthorization(
  LppEvidenceOwnerKind subject,
) {
  return LppAcquisitionAuthorization(
    acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
    subject: subject,
    partnerAttested: subject == LppEvidenceOwnerKind.manualPartner,
    policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
    declaredAt: DateTime.utc(2026, 1, 1),
    documentSha256:
        '1111111111111111111111111111111111111111111111111111111111111111',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  var failLppWrites = false;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          if (key != null &&
              (key.startsWith(_lppSlotPrefix) ||
                  key.startsWith(_authoritySlotPrefix)) &&
              failLppWrites) {
            throw PlatformException(code: '-34018');
          }
          if (key != null) secureStorageValues[key] = args['value'] as String;
          return null;
        case 'read':
          return key == null ? null : secureStorageValues[key];
        case 'readAll':
          return Map<String, String>.from(secureStorageValues);
        case 'delete':
          if (key != null) secureStorageValues.remove(key);
          return null;
        case 'deleteAll':
          secureStorageValues.clear();
          return null;
      }
      return null;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secureStorageValues.clear();
    failLppWrites = false;
    FeatureFlags.typedLppEvidence = true;
    FeatureFlags.partnerLppAccountabilityEnabled = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
    FeatureFlags.partnerLppAccountabilityEnabled = false;
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
  });

  test('confirmed self LPP projections and provenance survive restart',
      () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000.0,
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
    });
    await ReportPersistenceService.setCompleted(true);

    var writer = CoachProfileProvider();
    await writer.loadFromWizard();
    expect(writer.profile, isNotNull);

    await writer.acceptLppReview(
      LppReviewConfirmation(
        authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
        sourceDate: DateTime.utc(2026, 6, 30),
        facts: const {
          LppEvidenceFactKey.retirementPensionAnnualChf: LppReviewedFact(
            value: 31450.0,
            unit: LppEvidenceUnit.chfPerYear,
          ),
          LppEvidenceFactKey.retirementCapitalLumpSumChf: LppReviewedFact(
            value: 485200.0,
            unit: LppEvidenceUnit.chfLumpSum,
          ),
          LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
            value: 36800.0,
            unit: LppEvidenceUnit.chfPerYear,
          ),
          LppEvidenceFactKey.disabilityCapitalLumpSumChf: LppReviewedFact(
            value: 175000.0,
            unit: LppEvidenceUnit.chfLumpSum,
          ),
          LppEvidenceFactKey.deathCapitalLumpSumChf: LppReviewedFact(
            value: 220500.0,
            unit: LppEvidenceUnit.chfLumpSum,
          ),
        },
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final serialized = <String>[
      prefs.getString('wizard_answers_v2') ?? '',
      ...secureStorageValues.values,
    ].join('\n');
    expect(serialized, isNot(contains('RAW_OCR_')));
    expect(serialized, isNot(contains('sourceText')));
    expect(serialized, isNot(contains('rawOcr')));

    final prefsRoot = jsonDecode(
      prefs.getString('wizard_answers_v2')!,
    ) as Map<String, dynamic>;
    expect(prefsRoot['_coach_lpp_evidence_v1'], '__secure__');
    expect(prefsRoot.containsKey(_activeAuthoritySlotKey), isFalse);
    final activeSlotId = prefs.getString(_activeAuthoritySlotKey)!;
    expect(activeSlotId, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(
      prefs.getString('wizard_answers_v2'),
      isNot(contains(activeSlotId)),
    );
    final root = jsonDecode(
      _activeAuthorityLppRoot(prefs, secureStorageValues),
    ) as Map<String, dynamic>;
    expect(root.keys.toSet(), {
      'schemaVersion',
      'self',
      'manualPartner',
      'legacyPartnerQuarantine',
      'selfRegulationReference',
    });
    expect(root['schemaVersion'], 2);
    expect(root['manualPartner'], isNull);
    expect(root['legacyPartnerQuarantine'], isNull);
    expect(root['selfRegulationReference'], isNull);
    final self = root['self'] as Map<String, dynamic>;
    final facts = self['facts'] as Map<String, dynamic>;
    expect(
      facts.keys.toSet(),
      {
        'retirementPensionAnnualChf',
        'retirementCapitalLumpSumChf',
        'disabilityPensionAnnualChf',
        'disabilityCapitalLumpSumChf',
        'deathCapitalLumpSumChf',
      },
    );
    final owners = <String>{};
    final actors = <String>{};
    final updatedAts = <String>{};
    for (final entry in facts.entries) {
      final storedFact = entry.value as Map<String, dynamic>;
      expect(storedFact.keys.toSet(), {
        'value',
        'unit',
        'owner',
        'actor',
        'authorization',
        'provenance',
      });
      final owner = storedFact['owner'] as Map<String, dynamic>;
      final actor = storedFact['actor'] as Map<String, dynamic>;
      final authorization = storedFact['authorization'] as Map<String, dynamic>;
      final provenance = storedFact['provenance'] as Map<String, dynamic>;
      expect(owner['kind'], 'self');
      owners.add(owner['profileOwnerId'] as String);
      actors.add(actor['profileOwnerId'] as String);
      expect(authorization, {'mode': 'self', 'grantId': null});
      expect(provenance['source'], 'certificate');
      expect(provenance.containsKey('sourceDate'), isTrue);
      expect(provenance['sourceDate'], '2026-06-30');
      updatedAts.add(provenance['updatedAt'] as String);
    }
    expect(owners, hasLength(1));
    expect(actors, owners);
    expect(updatedAts, hasLength(1));
    expect(
      (facts['disabilityPensionAnnualChf'] as Map)['unit'],
      'CHF/year',
    );
    expect(
      (facts['disabilityCapitalLumpSumChf'] as Map)['unit'],
      'CHF/lump-sum',
    );
    expect(
      ReportPersistenceService.backendSafeAnswers({
        '_coach_lpp_evidence_v1':
            _activeAuthorityLppRoot(prefs, secureStorageValues),
      }),
      isEmpty,
    );

    writer.dispose();
    writer = CoachProfileProvider();
    await writer.loadFromWizard();
    final coldProfile = writer.profile;
    expect(coldProfile, isNotNull);

    expect(
      _coldLppContract(coldProfile!),
      <String, Object?>{
        'retirementPensionAnnual':
            _expectedFact(31450.0, '2026-06-30T00:00:00.000Z'),
        'retirementCapitalLumpSum':
            _expectedFact(485200.0, '2026-06-30T00:00:00.000Z'),
        'disabilityPensionAnnual':
            _expectedFact(36800.0, '2026-06-30T00:00:00.000Z'),
        'disabilityCapitalLumpSum':
            _expectedFact(175000.0, '2026-06-30T00:00:00.000Z'),
        'deathCapitalLumpSum':
            _expectedFact(220500.0, '2026-06-30T00:00:00.000Z'),
      },
      reason: 'confirmed person-owned LPP facts must cross the real '
          'persisted-answer boundary with canonical provenance',
    );
    for (final key in <LppEvidenceFactKey>[
      LppEvidenceFactKey.retirementPensionAnnualChf,
      LppEvidenceFactKey.retirementCapitalLumpSumChf,
      LppEvidenceFactKey.disabilityPensionAnnualChf,
      LppEvidenceFactKey.disabilityCapitalLumpSumChf,
      LppEvidenceFactKey.deathCapitalLumpSumChf,
    ]) {
      expect(
        coldProfile.prevoyance.lppEvidenceStatus(key),
        LppEvidenceStatus.available,
      );
      expect(
        coldProfile.prevoyance.lppEvidenceFact(key)?.sourceDate,
        DateTime.utc(2026, 6, 30),
      );
    }

    final mutatedRoot = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
    final mutatedFacts = (mutatedRoot['self'] as Map<String, dynamic>)['facts']
        as Map<String, dynamic>;
    (mutatedFacts['disabilityCapitalLumpSumChf']
        as Map<String, dynamic>)['unit'] = 'CHF/year';
    final mutatedAnswers = await ReportPersistenceService.loadAnswers()
      ..['_coach_lpp_evidence_v1'] = jsonEncode(mutatedRoot);
    await ReportPersistenceService.saveLppEvidenceAnswers(mutatedAnswers);

    writer.dispose();
    writer = CoachProfileProvider();
    await writer.loadFromWizard();
    final rejectedProfile = writer.profile!;
    expect(rejectedProfile.prevoyance.projectedRenteLpp, isNull);
    expect(rejectedProfile.prevoyance.projectedCapital65, isNull);
    expect(rejectedProfile.prevoyance.disabilityCoverage, isNull);
    expect(rejectedProfile.prevoyance.lppDisabilityCapital, isNull);
    expect(rejectedProfile.prevoyance.deathCoverage, isNull);
    expect(
      rejectedProfile.dataSources.keys,
      isNot(contains('prevoyance.disabilityCoverage')),
    );
  });

  test('manual partner first reuses stable self actor and stays separate',
      () async {
    final persistence = _RecordingLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      'q_partner_employment_status': 'salarie',
    });
    final now = DateTime.utc(2026, 7, 14, 12);
    final gate = _PartnerTestGate(() => now);
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => now,
    );
    await provider.loadFromWizard();

    await provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );

    var root = LppEvidenceRoot.fromJsonString(
      persistence.lastSaved!['_coach_lpp_evidence_v1'],
    )!;
    final partnerFact = root.manualPartner!.facts.values.single;
    final stableSelfActor = partnerFact.actorProfileOwnerId;
    final partnerOwner = partnerFact.profileOwnerId;
    expect(partnerOwner, isNot(stableSelfActor));
    expect(partnerFact.ownerKind, LppEvidenceOwnerKind.manualPartner);
    expect(
      partnerFact.authorizationMode,
      LppEvidenceAuthorizationMode.manualPartnerDeclaration,
    );
    expect(partnerFact.authorizationGrantId, isNull);

    await provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
            value: 92000,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );

    root = LppEvidenceRoot.fromJsonString(
      persistence.lastSaved!['_coach_lpp_evidence_v1'],
    )!;
    final selfFact = root.self!.facts.values.single;
    expect(selfFact.profileOwnerId, stableSelfActor);
    expect(selfFact.actorProfileOwnerId, stableSelfActor);
    expect(
      root.manualPartner!.facts.values.single.profileOwnerId,
      partnerOwner,
    );
    expect(
      LppEvidenceSelector.selectManualPartner(
        persistence.lastSaved!['_coach_lpp_evidence_v1'],
        expectedOwnerId: stableSelfActor,
        now: () => now,
      ),
      isNull,
    );
    expect(
      LppEvidenceSelector.selectManualPartner(
        persistence.lastSaved!['_coach_lpp_evidence_v1'],
        expectedOwnerId: partnerOwner,
        now: () => now,
      ),
      isNotNull,
    );

    final cold = CoachProfile.fromWizardAnswers(
      persistence.lastSaved!,
      now: () => now,
    );
    expect(cold.prevoyance.salaireAssure, isNull);
    expect(cold.prevoyance.avoirLppTotal, isNull);
    expect(cold.conjoint!.prevoyance!.avoirLppTotal, isNull);
    expect(cold.conjoint!.prevoyance!.salaireAssure, isNull);
  });

  test('manual partner replacement clears omitted facts and provenance',
      () async {
    final persistence = _RecordingLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      'q_partner_employment_status': 'salarie',
    });
    var now = DateTime.utc(2026, 7, 14, 10);
    final gate = _PartnerTestGate(() => now);
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => now,
    );

    await provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
        sourceDate: DateTime.utc(2026, 6, 30),
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.maximumBuybackCapitalChf: LppReviewedFact(
            value: 24000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );
    await provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
          ),
          LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
            value: 92000,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );
    final firstRoot = LppEvidenceRoot.fromJsonString(
      persistence.lastSaved!['_coach_lpp_evidence_v1'],
    )!;
    final firstSelfJson = jsonEncode(firstRoot.self!.toJson());
    final firstPartnerFact = firstRoot.manualPartner!.facts.values.first;
    final partnerOwnerId = firstPartnerFact.profileOwnerId;
    final selfActorId = firstPartnerFact.actorProfileOwnerId;
    final firstSelfProvenance = jsonEncode(
      (persistence.lastSaved!['__provenance']
          as Map)[LppEvidenceFactKey.maximumBuybackCapitalChf.profilePath],
    );

    now = DateTime.utc(2026, 7, 14, 11);
    await provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: DateTime.utc(2026, 7, 1),
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84500,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );

    final secondRoot = LppEvidenceRoot.fromJsonString(
      persistence.lastSaved!['_coach_lpp_evidence_v1'],
    )!;
    final secondPartnerFact = secondRoot.manualPartner!.facts.values.single;
    expect(secondPartnerFact.profileOwnerId, partnerOwnerId);
    expect(secondPartnerFact.actorProfileOwnerId, selfActorId);
    expect(jsonEncode(secondRoot.self!.toJson()), firstSelfJson);
    expect(provider.profile!.prevoyance.rachatMaximum, 24000);
    expect(provider.profile!.conjoint!.prevoyance!.avoirLppTotal, 84500);
    expect(provider.profile!.conjoint!.prevoyance!.salaireAssure, isNull);
    expect(
      provider.profile!.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.maximumBuybackCapitalChf,
      ),
      LppEvidenceStatus.available,
    );
    expect(
      provider.profile!.conjoint!.prevoyance!.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.available,
    );

    final provenance = Map<String, dynamic>.from(
      persistence.lastSaved!['__provenance'] as Map,
    );
    final selfPath = LppEvidenceFactKey.maximumBuybackCapitalChf.profilePath;
    final retainedPartnerPath =
        LppEvidenceFactKey.vestedBenefitsCapitalChf.manualPartnerProfilePath;
    final omittedPartnerPath =
        LppEvidenceFactKey.insuredSalaryAnnualChf.manualPartnerProfilePath;
    expect(jsonEncode(provenance[selfPath]), firstSelfProvenance);
    expect(provenance[retainedPartnerPath], <String, dynamic>{
      'source': 'certificate',
      'updatedAt': '2026-07-14T11:00:00.000Z',
      'sourceDate': '2026-07-01T00:00:00.000Z',
    });
    expect(
      (provenance[selfPath] as Map)['sourceDate'],
      '2026-06-30T00:00:00.000Z',
    );
    expect(provenance.containsKey(omittedPartnerPath), isFalse);
    expect(
        provider.profile!.dataSources.containsKey(omittedPartnerPath), isFalse);
    expect(provider.profile!.dataTimestamps.containsKey(omittedPartnerPath),
        isFalse);
    expect(provider.profile!.dataSourceDates.containsKey(omittedPartnerPath),
        isFalse);
  });

  test('concurrent self and manual acceptance preserves both slots', () async {
    final persistence = _DelayedFirstLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
        '11111111-1111-4111-8111-111111111111',
      ).toJsonString(),
    });
    final gate = _PartnerTestGate(
      () => DateTime.utc(2026, 7, 14, 12),
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();
    persistence.loadAttempts = 0;
    provider.addListener(() => persistence.events.add('notify'));

    final selfAcceptance = provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.maximumBuybackCapitalChf: LppReviewedFact(
            value: 24000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );
    await persistence.firstSaveStarted.future;
    final manualAcceptance = provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );
    persistence.releaseFirstSave.complete();
    await Future.wait(<Future<void>>[selfAcceptance, manualAcceptance]);

    final root = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(root.self, isNotNull);
    expect(root.manualPartner, isNotNull);
    final selfOwnerId = root.self!.facts.values.first.profileOwnerId;
    expect(root.manualPartner!.facts.values.first.actorProfileOwnerId,
        selfOwnerId);
    // One read per root write plus the exact activation CAS read.
    expect(persistence.loadAttempts, 3);
    expect(persistence.saveAttempts, 2);
    expect(persistence.events, <String>[
      'save-start:self',
      'save-done:self',
      'notify',
      'save-start:both',
      'save-done:both',
      'notify',
      'notify', // pending partner authority becomes active after exact CAS
    ]);
  });

  test('startup LPP migration cannot overwrite a concurrent acceptance',
      () async {
    final persistence = _DelayedFirstLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      '_coach_profile_owner_v1': const CoachProfileOwnerRoot(
        '11111111-1111-4111-8111-111111111111',
      ).toJsonString(),
    });
    final gate = _PartnerTestGate(
      () => DateTime.utc(2026, 7, 14, 12),
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();
    persistence.answers.addAll(<String, dynamic>{
      '_coach_avoir_lpp': 125000.0,
      '__provenance': <String, dynamic>{
        'prevoyance.avoirLppTotal': <String, dynamic>{
          'source': 'certificate',
          'updatedAt': '2026-07-14T10:00:00.000Z',
          'sourceDate': '2026-06-30',
        },
      },
    });
    persistence.loadAttempts = 0;
    persistence.saveAttempts = 0;
    persistence.events.clear();

    final startup = provider.loadFromWizard();
    await persistence.firstSaveStarted.future;
    final manualAcceptance = provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: DateTime.utc(2026, 7, 1),
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );
    persistence.releaseFirstSave.complete();
    await Future.wait(<Future<void>>[startup, manualAcceptance]);

    final root = LppEvidenceRoot.fromJsonString(
      persistence.answers['_coach_lpp_evidence_v1'],
    )!;
    expect(root.self, isNotNull);
    expect(root.manualPartner, isNotNull);
    final selfOwnerId = root.self!.facts.values.first.profileOwnerId;
    expect(root.manualPartner!.facts.values.first.actorProfileOwnerId,
        selfOwnerId);
    expect(provider.profile!.prevoyance.avoirLppTotal, 125000);
    expect(provider.profile!.conjoint!.prevoyance!.avoirLppTotal, 84000);
    expect(
      provider.profile!.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.available,
    );
    expect(
      provider.profile!.conjoint!.prevoyance!.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.available,
    );
    expect(
      root.self!.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]?.sourceDate,
      DateTime.utc(2026, 6, 30),
    );
    expect(
      root.manualPartner!.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]
          ?.sourceDate,
      DateTime.utc(2026, 7, 1),
    );
    // Cold inspect + migration CAS + final inspect + manual write +
    // exact activation CAS.
    expect(persistence.loadAttempts, 5);
    expect(persistence.saveAttempts, 2);
    expect(persistence.events, <String>[
      'save-start:self',
      'save-done:self',
      'save-start:both',
      'save-done:both',
    ]);
  });

  test('manual partner acceptance preserves safe self migration and quarantine',
      () async {
    final persistence = _RecordingLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      '_coach_avoir_lpp': 125000.0,
      '__provenance': <String, dynamic>{
        'prevoyance.avoirLppTotal': <String, dynamic>{
          'source': 'certificate',
          'updatedAt': '2026-07-14T10:00:00.000Z',
          'sourceDate': null,
        },
      },
      '_coach_conjoint_avoir_lpp': 987654.0,
      '_coach_conjoint_lpp_source': 'document_scan',
    });
    final gate = _PartnerTestGate(
      () => DateTime.utc(2026, 7, 14, 12),
    );
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();

    await provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
            value: 92000,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );

    final root = LppEvidenceRoot.fromJsonString(
      persistence.lastSaved!['_coach_lpp_evidence_v1'],
    )!;
    expect(
      root.self!.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf]!.value,
      125000,
    );
    expect(
      root.manualPartner!.facts[LppEvidenceFactKey.insuredSalaryAnnualChf]!
          .value,
      92000,
    );
    expect(root.legacyPartnerQuarantine!.presentKeys.toSet(), {
      '_coach_conjoint_avoir_lpp',
      '_coach_conjoint_lpp_source',
    });
    expect(persistence.lastSaved!.containsKey('_coach_avoir_lpp'), isFalse);
    expect(
      persistence.lastSaved!.keys.toSet().intersection(
            legacyPartnerLppAnswerKeys,
          ),
      isEmpty,
    );
  });

  test('manual partner evidence survives the real secure restart boundary',
      () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': 'marie',
      'q_partner_birth_year': 1982,
      'q_partner_employment_status': 'salarie',
    });
    await ReportPersistenceService.setCompleted(true);
    final gate = _PartnerTestGate(
      () => DateTime.utc(2026, 7, 14, 12),
    );
    var provider = CoachProfileProvider(
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();

    await provider.acceptLppReview(
      await gate.confirmation(
        sourceDate: DateTime.utc(2026, 6, 30),
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
          ),
          LppEvidenceFactKey.disabilityCapitalLumpSumChf: LppReviewedFact(
            value: 175000,
            unit: LppEvidenceUnit.chfLumpSum,
          ),
        },
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final prefsBytes = prefs.getString('wizard_answers_v2')!;
    final secureRoot = _activeAuthorityLppRoot(prefs, secureStorageValues);
    final root = LppEvidenceRoot.fromJsonString(secureRoot)!;
    final partnerFact = root.manualPartner!.facts.values.first;
    expect(partnerFact.sourceDate, DateTime.utc(2026, 6, 30));
    expect(prefsBytes, isNot(contains(partnerFact.profileOwnerId)));
    expect(prefsBytes, isNot(contains(partnerFact.actorProfileOwnerId)));

    provider.dispose();
    provider = CoachProfileProvider(
      partnerAccountabilityBindingStore: gate.store,
      partnerAccountabilityService: gate.service,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();

    final coldPartner = provider.profile!.conjoint!.prevoyance!;
    expect(coldPartner.avoirLppTotal, 84000);
    expect(coldPartner.lppDisabilityCapital, 175000);
    expect(coldPartner.salaireAssure, isNull);
    expect(provider.profile!.prevoyance.avoirLppTotal, isNull);
    expect(
      provider.profile!.dataSources['conjoint.prevoyance.avoirLppTotal'],
      ProfileDataSource.certificate,
    );
    expect(
      coldPartner.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.available,
    );
    expect(
      provider.profile!.dataSourceDates[
          LppEvidenceFactKey.vestedBenefitsCapitalChf.manualPartnerProfilePath],
      DateTime.utc(2026, 6, 30),
    );
    expect(
      provider.profile!.dataSources.containsKey('prevoyance.avoirLppTotal'),
      isFalse,
    );
  });

  test('manual cold hydration ignores unrelated malformed quarantine', () {
    const selfActorId = '11111111-1111-4111-8111-111111111111';
    const partnerOwnerId = '22222222-2222-4222-8222-222222222222';
    final root = LppEvidenceRoot(
      self: null,
      manualPartner: LppEvidenceSnapshot(
        snapshotId: '33333333-3333-4333-8333-333333333333',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: partnerOwnerId,
            actorProfileOwnerId: selfActorId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: DateTime.utc(2026, 6, 30),
            updatedAt: DateTime.utc(2026, 7, 14, 10),
          ),
        },
      ),
    );
    final malformedEnvelope =
        jsonDecode(root.toJsonString()) as Map<String, dynamic>;
    malformedEnvelope['legacyPartnerQuarantine'] = <String, dynamic>{
      'legacySchemaVersion': 0,
      'values': <String, dynamic>{'forbiddenRawPartnerValue': 84000},
    };
    final rawRoot = jsonEncode(malformedEnvelope);

    final selected = LppEvidenceSelector.selectManualPartner(
      rawRoot,
      expectedOwnerId: partnerOwnerId,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    expect(selected, isNotNull);

    final cold = CoachProfile.fromWizardAnswers(
      <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        '_coach_lpp_evidence_v1': rawRoot,
      },
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    final partnerPrevoyance = cold.conjoint?.prevoyance;
    expect(partnerPrevoyance, isNotNull);
    expect(partnerPrevoyance!.avoirLppTotal, 84000);
    final fact = partnerPrevoyance.lppEvidenceFact(
      LppEvidenceFactKey.vestedBenefitsCapitalChf,
    );
    expect(fact, isNotNull);
    expect(fact!.status, LppEvidenceStatus.available);
    const path = 'conjoint.prevoyance.avoirLppTotal';
    expect(cold.dataSources[path], ProfileDataSource.certificate);
    expect(cold.dataTimestamps[path], DateTime.utc(2026, 7, 14, 10));
    expect(cold.dataSourceDates[path], DateTime.utc(2026, 6, 30));
  });

  test('writer rejects a loaded grant-shaped root before save or publication',
      () async {
    const selfOwnerId = '11111111-1111-4111-8111-111111111111';
    const partnerOwnerId = '22222222-2222-4222-8222-222222222222';
    final validRoot = LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: '33333333-3333-4333-8333-333333333333',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 125000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: selfOwnerId,
            actorProfileOwnerId: selfOwnerId,
            source: 'certificate',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 7, 14, 10),
          ),
        },
      ),
      manualPartner: LppEvidenceSnapshot(
        snapshotId: '44444444-4444-4444-8444-444444444444',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: partnerOwnerId,
            actorProfileOwnerId: selfOwnerId,
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 7, 14, 10),
          ),
        },
      ),
    );
    final injected =
        jsonDecode(validRoot.toJsonString()) as Map<String, dynamic>;
    final manualFact = ((injected['manualPartner'] as Map)['facts']
        as Map)['vestedBenefitsCapitalChf'] as Map<String, dynamic>;
    manualFact['authorization'] = <String, dynamic>{
      'mode': 'linkedPartnerGrant',
      'grantId': '55555555-5555-4555-8555-555555555555',
    };
    final malformedRoot = jsonEncode(injected);
    final persistence = _RecordingLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      '_coach_lpp_evidence_v1': malformedRoot,
    });
    final provider = CoachProfileProvider(
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
          sourceDate: null,
          facts: const <LppEvidenceFactKey, LppReviewedFact>{
            LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
              value: 92000,
              unit: LppEvidenceUnit.chfPerYear,
            ),
          },
        ),
      ),
      throwsStateError,
    );

    expect(persistence.saveAttempts, 0);
    expect(persistence.answers['_coach_lpp_evidence_v1'], malformedRoot);
    expect(provider.profile, isNull);
    expect(provider.reportAnswersSnapshot, isEmpty);
    expect(notifications, 0);
  });

  test(
      'malformed secure root preserves raw bytes but quarantines LPP in memory',
      () async {
    const opaqueMalformedRoot = 'opaque-malformed-lpp-root';
    await ReportPersistenceService.saveLppEvidenceAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      '_coach_lpp_evidence_v1': opaqueMalformedRoot,
    });
    await ReportPersistenceService.setCompleted(true);
    final polluted = await ReportPersistenceService.loadAnswers()
      ..['_coach_conjoint_avoir_lpp'] = 987654.0
      ..['_coach_conjoint_taux_conversion'] = 0.06123
      ..['_coach_conjoint_lpp_source'] = 'document_scan';
    await ReportPersistenceService.saveAnswers(polluted);
    final prefs = await SharedPreferences.getInstance();
    final activeSlotIdBefore = prefs.getString(_activeAuthoritySlotKey)!;
    final bytesBefore = prefs.getString('wizard_answers_v2');
    expect(
      _activeAuthorityLppRoot(prefs, secureStorageValues),
      opaqueMalformedRoot,
    );

    final provider = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();

    final persisted = await ReportPersistenceService.loadAnswers();
    for (final key in legacyPartnerLppAnswerKeys) {
      expect(persisted.containsKey(key), isTrue, reason: key);
    }
    expect(prefs.getString('wizard_answers_v2'), bytesBefore);
    expect(persisted['_coach_lpp_evidence_v1'], opaqueMalformedRoot);
    expect(prefs.getString(_activeAuthoritySlotKey), activeSlotIdBefore);
    expect(
      _activeAuthorityLppRoot(prefs, secureStorageValues),
      opaqueMalformedRoot,
    );
    final backend = ReportPersistenceService.backendSafeAnswers(persisted);
    expect(
      backend.keys.toSet().intersection(legacyPartnerLppAnswerKeys),
      isEmpty,
    );
    expect(backend.containsKey('_coach_lpp_evidence_v1'), isFalse);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.conjoint, isNull);
    expect(provider.canonicalProfileOwnerId, isNull);
  });

  test('unreadable secure placeholder preserves bytes and blocks LPP authority',
      () async {
    const activeSlotId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wizard_answers_v2': jsonEncode(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        '_coach_lpp_evidence_v1': '__secure__',
        '_coach_conjoint_avoir_lpp': 987654.0,
        '_coach_conjoint_taux_conversion': 0.06123,
        '_coach_conjoint_lpp_source': 'document_scan',
      }),
      _activeLppSlotKey: activeSlotId,
      'wizard_completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final bytesBefore = prefs.getString('wizard_answers_v2')!;
    expect(secureStorageValues['$_lppSlotPrefix$activeSlotId'], isNull);

    final provider = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();

    final bytesAfter = prefs.getString('wizard_answers_v2')!;
    final stored = Map<String, dynamic>.from(jsonDecode(bytesAfter) as Map);
    expect(bytesAfter, bytesBefore);
    expect(stored['_coach_lpp_evidence_v1'], '__secure__');
    expect(
      stored.keys.toSet().intersection(legacyPartnerLppAnswerKeys),
      legacyPartnerLppAnswerKeys,
    );
    expect(prefs.getString(_activeLppSlotKey), activeSlotId);
    expect(secureStorageValues['$_lppSlotPrefix$activeSlotId'], isNull);
    expect(provider.reportAnswersSnapshot.containsKey('_coach_lpp_evidence_v1'),
        isFalse);
    expect(provider.profile, isNotNull);
    expect(provider.profile!.conjoint, isNull);
    expect(provider.canonicalProfileOwnerId, isNull);
  });

  test('legacy partner LPP values become metadata-only quarantine', () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_partner_birth_year': 1982,
      'q_partner_employment_status': 'salarie',
      '_coach_conjoint_avoir_lpp': 987654.0,
      '_coach_conjoint_taux_conversion': 0.06123,
      '_coach_conjoint_lpp_source': 'document_scan',
    });
    await ReportPersistenceService.setCompleted(true);
    final provider = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 14, 12),
    );

    await provider.loadFromWizard();

    final persisted = await ReportPersistenceService.loadAnswers();
    for (final key in legacyPartnerLppAnswerKeys) {
      expect(persisted.containsKey(key), isFalse, reason: key);
    }
    final rawRoot = persisted['_coach_lpp_evidence_v1'] as String;
    expect(rawRoot, isNot(contains('987654')));
    expect(rawRoot, isNot(contains('0.06123')));
    expect(rawRoot, isNot(contains('document_scan')));
    final root = LppEvidenceRoot.fromJsonString(rawRoot)!;
    expect(root.manualPartner, isNull);
    expect(root.legacyPartnerQuarantine!.reasonCodes,
        <String>['untyped_legacy_partner_lpp']);
    expect(
      root.legacyPartnerQuarantine!.presentKeys.toSet(),
      legacyPartnerLppAnswerKeys,
    );
    expect(
      provider.profile!.conjoint!.prevoyance!.lppEvidenceFact(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      isNull,
    );
    expect(
      provider.profile!.dataSources.keys,
      isNot(contains('conjoint.prevoyance.avoirLppTotal')),
    );
  });

  test('failed self LPP save publishes and notifies nothing', () async {
    final persistence = _FailingLppPersistence(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
    });
    final provider = CoachProfileProvider(lppProfilePersistence: persistence);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
          sourceDate: null,
          facts: const {
            LppEvidenceFactKey.retirementPensionAnnualChf: LppReviewedFact(
              value: 30000,
              unit: LppEvidenceUnit.chfPerYear,
            ),
          },
        ),
      ),
      throwsStateError,
    );

    expect(persistence.saveAttempts, 1);
    expect(provider.profile, isNull);
    expect(provider.reportAnswersSnapshot, isEmpty);
    expect(notifications, 0);
    expect(persistence.answers.containsKey('_coach_lpp_evidence_v1'), isFalse);
  });

  test('real secure LPP failure restores bytes and publishes nothing',
      () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
    });
    final prefs = await SharedPreferences.getInstance();
    final previousBytes = prefs.getString('wizard_answers_v2');
    failLppWrites = true;
    final provider = CoachProfileProvider();
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
          sourceDate: null,
          facts: const {
            LppEvidenceFactKey.retirementPensionAnnualChf: LppReviewedFact(
              value: 30000,
              unit: LppEvidenceUnit.chfPerYear,
            ),
          },
        ),
      ),
      throwsStateError,
    );

    expect(prefs.getString('wizard_answers_v2'), previousBytes);
    expect(secureStorageValues['_coach_lpp_evidence_v1'], isNull);
    expect(prefs.getString(_activeAuthoritySlotKey), isNull);
    expect(
      secureStorageValues.keys
          .where((key) => key.startsWith(_authoritySlotPrefix)),
      isEmpty,
    );
    expect(provider.profile, isNull);
    expect(provider.reportAnswersSnapshot, isEmpty);
    expect(notifications, 0);
  });

  test('typed LPP flag fails closed without calling a legacy writer', () async {
    FeatureFlags.typedLppEvidence = false;
    final persistence = _FailingLppPersistence(<String, dynamic>{});
    final provider = CoachProfileProvider(lppProfilePersistence: persistence);

    await expectLater(
      provider.acceptLppReview(
        LppReviewConfirmation(
          authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
          sourceDate: null,
          facts: const {
            LppEvidenceFactKey.retirementCapitalLumpSumChf: LppReviewedFact(
              value: 400000,
              unit: LppEvidenceUnit.chfLumpSum,
            ),
          },
        ),
      ),
      throwsStateError,
    );

    expect(persistence.saveAttempts, 0);
    expect(provider.profile, isNull);
  });

  test('unambiguous legacy self certificate migration is idempotent', () async {
    const stamp = '2026-01-15T12:00:00.000Z';
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      'q_has_pension_fund': 'yes',
      '_coach_avoir_lpp': 123400.0,
      '_coach_taux_conversion': 0.068,
      '_coach_lpp_source': 'document_scan',
      '__provenance': <String, dynamic>{
        'prevoyance.avoirLppTotal': <String, dynamic>{
          'source': 'certificate',
          'updatedAt': stamp,
          'sourceDate': null,
        },
        'prevoyance.tauxConversion': <String, dynamic>{
          'source': 'certificate',
          'updatedAt': stamp,
          'sourceDate': null,
        },
      },
    });
    await ReportPersistenceService.setCompleted(true);

    var provider = CoachProfileProvider();
    await provider.loadFromWizard();
    expect(provider.profile!.prevoyance.avoirLppTotal, isNull);
    expect(provider.profile!.prevoyance.tauxConversion, 0.068);
    expect(
      provider.profile!.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.availableNeedsConfirmation,
    );
    final prefs = await SharedPreferences.getInstance();
    final firstSlotId = prefs.getString(_activeAuthoritySlotKey);
    final firstRoot = _activeAuthorityLppRoot(prefs, secureStorageValues);
    expect(firstRoot, isNotNull);
    final migratedAnswers = await ReportPersistenceService.loadAnswers();
    expect(migratedAnswers.containsKey('_coach_avoir_lpp'), isFalse);
    expect(migratedAnswers.containsKey('_coach_taux_conversion'), isFalse);
    expect(migratedAnswers.containsKey('_coach_lpp_source'), isFalse);

    provider.dispose();
    provider = CoachProfileProvider();
    await provider.loadFromWizard();
    expect(prefs.getString(_activeAuthoritySlotKey), firstSlotId);
    expect(_activeAuthorityLppRoot(prefs, secureStorageValues), firstRoot);
    expect(provider.profile!.prevoyance.avoirLppTotal, isNull);
    expect(provider.profile!.prevoyance.tauxConversion, 0.068);
  });

  test('legacy certificate zero stays loose behind an authoritative empty root',
      () async {
    const stamp = '2026-01-15T12:00:00.000Z';
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      '_coach_avoir_lpp': 0,
      '_coach_lpp_source': 'document_scan',
      '__provenance': <String, dynamic>{
        'prevoyance.avoirLppTotal': <String, dynamic>{
          'source': 'certificate',
          'updatedAt': stamp,
          'sourceDate': '2026-01-14',
        },
      },
    });
    await ReportPersistenceService.setCompleted(true);

    final provider = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await provider.loadFromWizard();
    final persisted = await ReportPersistenceService.loadAnswers();

    expect(persisted.containsKey('_coach_lpp_evidence_v1'), isTrue);
    expect(persisted['_coach_avoir_lpp'], 0);
    expect(persisted['_coach_lpp_source'], 'document_scan');
    expect(
      (persisted['__provenance'] as Map)['prevoyance.avoirLppTotal'],
      isNotNull,
    );
    expect(provider.profile!.prevoyance.avoirLppTotal, isNull);
    expect(
      provider.profile!.prevoyance.lppEvidenceFact(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      isNull,
    );
    final prefs = await SharedPreferences.getInstance();
    final firstSlotId = prefs.getString(_activeAuthoritySlotKey);
    final firstRoot = _activeAuthorityLppRoot(prefs, secureStorageValues);
    expect(firstRoot, isNotNull);
    provider.dispose();

    final cold = CoachProfileProvider(
      now: () => DateTime.utc(2026, 7, 14, 12),
    );
    await cold.loadFromWizard();
    expect(prefs.getString(_activeAuthoritySlotKey), firstSlotId);
    expect(_activeAuthorityLppRoot(prefs, secureStorageValues), firstRoot);
    expect(cold.profile!.prevoyance.avoirLppTotal, isNull);
    expect(
      cold.profile!.prevoyance.lppEvidenceFact(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      isNull,
    );
    cold.dispose();
  });

  test('legacy self migration applies strict provenance lexical validation',
      () async {
    for (final provenance in <Map<String, dynamic>>[
      <String, dynamic>{
        'source': 'certificate',
        'updatedAt': '2026-01-15T12:00:00.000Z',
        'sourceDate': '2026-01-14T00:00:00.000Z',
      },
      <String, dynamic>{
        'source': 'certificate',
        'updatedAt': '2026-01-15T13:00:00.000+01:00',
        'sourceDate': '2026-01-14',
      },
    ]) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      secureStorageValues.clear();
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        '_coach_avoir_lpp': 123400.0,
        '_coach_lpp_source': 'document_scan',
        '__provenance': <String, dynamic>{
          'prevoyance.avoirLppTotal': provenance,
        },
      });
      await ReportPersistenceService.setCompleted(true);

      final provider = CoachProfileProvider(
        now: () => DateTime.utc(2026, 7, 14, 12),
      );
      await provider.loadFromWizard();
      final persisted = await ReportPersistenceService.loadAnswers();

      expect(
        persisted.containsKey('_coach_lpp_evidence_v1'),
        isFalse,
        reason: provenance.toString(),
      );
      expect(persisted['_coach_avoir_lpp'], 123400.0);
      provider.dispose();
    }
  });

  test('cold LPP provenance is derived from strict facts, not the parallel map',
      () {
    final strictUpdatedAt = DateTime.utc(2026, 1, 15, 12);
    final strictSourceDate = DateTime.utc(2026, 1, 14);
    final root = LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: '11111111-1111-4111-8111-111111111111',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 125000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '22222222-2222-4222-8222-222222222222',
            actorProfileOwnerId: '22222222-2222-4222-8222-222222222222',
            source: 'certificate',
            sourceDate: strictSourceDate,
            updatedAt: strictUpdatedAt,
          ),
        },
      ),
      manualPartner: LppEvidenceSnapshot(
        snapshotId: '33333333-3333-4333-8333-333333333333',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '44444444-4444-4444-8444-444444444444',
            actorProfileOwnerId: '22222222-2222-4222-8222-222222222222',
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 1, 15, 12),
          ),
        },
      ),
    );
    final profile = CoachProfile.fromWizardAnswers(
      <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        '_coach_lpp_evidence_v1': root.toJsonString(),
        '__provenance': <String, dynamic>{
          'prevoyance.avoirLppTotal': <String, dynamic>{
            'source': 'userInput',
            'updatedAt': '2025-12-31T23:00:00.000Z',
            'sourceDate': null,
          },
        },
      },
      now: () => DateTime.utc(2026, 7, 14, 12),
    );

    expect(profile.prevoyance.avoirLppTotal, 125000.0);
    expect(
      profile.dataSources['prevoyance.avoirLppTotal'],
      ProfileDataSource.certificate,
    );
    expect(
      profile.dataTimestamps['prevoyance.avoirLppTotal'],
      strictUpdatedAt,
    );
    expect(
      profile.dataSourceDates['prevoyance.avoirLppTotal'],
      strictSourceDate,
    );
  });

  test('partial typed root exposes nullable evidence independently of defaults',
      () {
    final root = LppEvidenceRoot(
      self: LppEvidenceSnapshot(
        snapshotId: '11111111-1111-4111-8111-111111111111',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 125000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '22222222-2222-4222-8222-222222222222',
            actorProfileOwnerId: '22222222-2222-4222-8222-222222222222',
            source: 'certificate',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 1, 15, 12),
          ),
          LppEvidenceFactKey.maximumBuybackCapitalChf: LppEvidenceFact(
            value: 42000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '22222222-2222-4222-8222-222222222222',
            actorProfileOwnerId: '22222222-2222-4222-8222-222222222222',
            source: 'userInput',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 1, 15, 12),
          ),
        },
      ),
      manualPartner: LppEvidenceSnapshot(
        snapshotId: '33333333-3333-4333-8333-333333333333',
        facts: <LppEvidenceFactKey, LppEvidenceFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppEvidenceFact(
            value: 84000,
            unit: LppEvidenceUnit.chf,
            profileOwnerId: '44444444-4444-4444-8444-444444444444',
            actorProfileOwnerId: '22222222-2222-4222-8222-222222222222',
            ownerKind: LppEvidenceOwnerKind.manualPartner,
            authorizationMode:
                LppEvidenceAuthorizationMode.manualPartnerDeclaration,
            source: 'certificate',
            sourceDate: null,
            updatedAt: DateTime.utc(2026, 1, 15, 12),
          ),
        },
      ),
    );
    final profile = CoachProfile.fromWizardAnswers(
      <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_partner_firstname': 'Partner',
        'q_lpp_buyback_available': 40000,
        '_coach_lpp_evidence_v1': root.toJsonString(),
      },
      now: () => DateTime.utc(2026, 7, 14, 12),
    );

    expect(profile.prevoyance.tauxConversion, 0.068);
    expect(profile.prevoyance.avoirLppTotal, isNull);
    expect(profile.prevoyance.rendementCaisse, 0.02);
    expect(profile.prevoyance.rachatMaximum, 42000);
    expect(
      profile.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.maximumBuybackCapitalChf,
      ),
      LppEvidenceStatus.available,
    );
    for (final absentKey in <LppEvidenceFactKey>[
      LppEvidenceFactKey.mandatoryConversionRateRatio,
      LppEvidenceFactKey.fundReturnRateRatio,
    ]) {
      expect(profile.prevoyance.lppEvidenceFact(absentKey), isNull);
      expect(profile.prevoyance.lppEvidenceStatus(absentKey), isNull);
    }
    expect(
      profile.prevoyance
          .lppEvidenceFact(
            LppEvidenceFactKey.vestedBenefitsCapitalChf,
          )
          ?.value,
      125000,
    );
    expect(
      profile.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.availableNeedsConfirmation,
    );
    final partnerPrevoyance = profile.conjoint!.prevoyance!;
    expect(partnerPrevoyance.avoirLppTotal, isNull);
    expect(
      partnerPrevoyance
          .lppEvidenceFact(LppEvidenceFactKey.vestedBenefitsCapitalChf)
          ?.value,
      84000,
    );
    expect(
      partnerPrevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
      ),
      LppEvidenceStatus.availableNeedsConfirmation,
    );
  });

  test('accepting typed self review deletes every loose self LPP key',
      () async {
    final persistence = _RecordingLppPersistence(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      '_coach_avoir_lpp': 1,
      '_coach_avoir_lpp_oblig': 2,
      '_coach_avoir_lpp_suroblig': 3,
      '_coach_salaire_assure': 4,
      '_coach_rachat_maximum': 5,
      '_coach_taux_conversion': 0.068,
      '_coach_taux_conversion_suroblig': 0.05,
      '_coach_rendement_caisse': 0.02,
      '_coach_lpp_source': 'document_scan',
    });
    final provider = CoachProfileProvider(
      lppProfilePersistence: persistence,
      now: () => DateTime.utc(2026, 7, 14, 12),
    );

    await provider.acceptLppReview(
      LppReviewConfirmation(
        authorization: _lppAuthorization(LppEvidenceOwnerKind.self),
        sourceDate: null,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 125000,
            unit: LppEvidenceUnit.chf,
          ),
        },
      ),
    );

    const looseKeys = <String>{
      '_coach_avoir_lpp',
      '_coach_avoir_lpp_oblig',
      '_coach_avoir_lpp_suroblig',
      '_coach_salaire_assure',
      '_coach_rachat_maximum',
      '_coach_taux_conversion',
      '_coach_taux_conversion_suroblig',
      '_coach_rendement_caisse',
      '_coach_lpp_source',
    };
    expect(persistence.lastSaved, isNotNull);
    expect(
        persistence.lastSaved!.keys.toSet().intersection(looseKeys), isEmpty);
  });

  test('unreadable strict root is never overwritten during cold start',
      () async {
    await ReportPersistenceService.saveLppEvidenceAnswers(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      '_coach_lpp_evidence_v1':
          const LppEvidenceRoot(self: null).toJsonString(),
    });
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('wizard_answers_v2');
    expect(before, contains('"_coach_lpp_evidence_v1":"__secure__"'));
    final activeSecureKey = _activeAuthoritySecureKey(prefs);
    secureStorageValues.remove(activeSecureKey);
    secureStorageValues['_coach_lpp_evidence_v1'] =
        'stale-fixed-root-must-not-load';

    await expectLater(
      ReportPersistenceService.loadAnswers(),
      throwsStateError,
    );

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(prefs.getString('wizard_answers_v2'), before);
    expect(
      secureStorageValues['_coach_lpp_evidence_v1'],
      'stale-fixed-root-must-not-load',
    );
    expect(secureStorageValues[activeSecureKey], isNull);
    expect(provider.profile, isNull);
  });
}
