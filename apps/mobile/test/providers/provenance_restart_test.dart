import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
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

Map<String, Object?> _expectedFact(double value) => <String, Object?>{
      'value': value,
      'source': ProfileDataSource.certificate.name,
      'hasUpdatedAt': true,
      'hasSourceDateSlot': true,
      'sourceDate': null,
    };

const _activeLppSlotKey = 'lpp_evidence_active_slot_v1';
const _lppSlotPrefix = '_coach_lpp_evidence_slot_v1_';

String _activeLppSecureKey(SharedPreferences preferences) {
  final slotId = preferences.getString(_activeLppSlotKey);
  expect(slotId, matches(RegExp(r'^[a-f0-9]{32}$')));
  return '$_lppSlotPrefix$slotId';
}

final class _FailingLppPersistence implements LppProfilePersistence {
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

final class _RecordingLppPersistence implements LppProfilePersistence {
  _RecordingLppPersistence(this.answers);

  final Map<String, dynamic> answers;
  Map<String, dynamic>? lastSaved;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> answers) async {
    lastSaved = Map<String, dynamic>.from(answers);
  }
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
          if (key != null && key.startsWith(_lppSlotPrefix) && failLppWrites) {
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
  });

  tearDown(() => FeatureFlags.typedLppEvidence = false);

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
      const LppReviewConfirmation.self(
        sourceDate: null,
        facts: {
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
    expect(prefsRoot.containsKey(_activeLppSlotKey), isFalse);
    final activeSlotId = prefs.getString(_activeLppSlotKey)!;
    expect(activeSlotId, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(
      prefs.getString('wizard_answers_v2'),
      isNot(contains(activeSlotId)),
    );
    final activeSecureKey = _activeLppSecureKey(prefs);
    final root = jsonDecode(
      secureStorageValues[activeSecureKey]!,
    ) as Map<String, dynamic>;
    expect(root.keys.toSet(), {
      'schemaVersion',
      'self',
      'manualPartner',
      'legacyPartnerQuarantine',
    });
    expect(root['schemaVersion'], 1);
    expect(root['manualPartner'], isNull);
    expect(root['legacyPartnerQuarantine'], isNull);
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
      expect(provenance['sourceDate'], isNull);
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
        '_coach_lpp_evidence_v1': secureStorageValues[activeSecureKey],
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
        'retirementPensionAnnual': _expectedFact(31450.0),
        'retirementCapitalLumpSum': _expectedFact(485200.0),
        'disabilityPensionAnnual': _expectedFact(36800.0),
        'disabilityCapitalLumpSum': _expectedFact(175000.0),
        'deathCapitalLumpSum': _expectedFact(220500.0),
      },
      reason: 'confirmed person-owned LPP facts must cross the real '
          'persisted-answer boundary with canonical provenance',
    );

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
        const LppReviewConfirmation.self(
          sourceDate: null,
          facts: {
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
        const LppReviewConfirmation.self(
          sourceDate: null,
          facts: {
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
    expect(prefs.getString(_activeLppSlotKey), isNull);
    expect(
      secureStorageValues.keys.where((key) => key.startsWith(_lppSlotPrefix)),
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
        const LppReviewConfirmation.self(
          sourceDate: null,
          facts: {
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
    expect(provider.profile!.prevoyance.avoirLppTotal, 123400.0);
    expect(provider.profile!.prevoyance.tauxConversion, 0.068);
    final prefs = await SharedPreferences.getInstance();
    final firstSlotId = prefs.getString(_activeLppSlotKey);
    final firstRoot = secureStorageValues[_activeLppSecureKey(prefs)];
    expect(firstRoot, isNotNull);
    final migratedAnswers = await ReportPersistenceService.loadAnswers();
    expect(migratedAnswers.containsKey('_coach_avoir_lpp'), isFalse);
    expect(migratedAnswers.containsKey('_coach_taux_conversion'), isFalse);
    expect(migratedAnswers.containsKey('_coach_lpp_source'), isFalse);

    provider.dispose();
    provider = CoachProfileProvider();
    await provider.loadFromWizard();
    expect(prefs.getString(_activeLppSlotKey), firstSlotId);
    expect(secureStorageValues[_activeLppSecureKey(prefs)], firstRoot);
    expect(provider.profile!.prevoyance.avoirLppTotal, 123400.0);
    expect(provider.profile!.prevoyance.tauxConversion, 0.068);
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
        },
      ),
    );
    final profile = CoachProfile.fromWizardAnswers(
      <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_lpp_buyback_available': 40000,
        '_coach_lpp_evidence_v1': root.toJsonString(),
      },
      now: () => DateTime.utc(2026, 7, 14, 12),
    );

    expect(profile.prevoyance.tauxConversion, 0.068);
    expect(profile.prevoyance.rendementCaisse, 0.02);
    expect(profile.prevoyance.rachatMaximum, 40000);
    for (final absentKey in <LppEvidenceFactKey>[
      LppEvidenceFactKey.mandatoryConversionRateRatio,
      LppEvidenceFactKey.fundReturnRateRatio,
      LppEvidenceFactKey.maximumBuybackCapitalChf,
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
      const LppReviewConfirmation.self(
        sourceDate: null,
        facts: <LppEvidenceFactKey, LppReviewedFact>{
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
    final activeSecureKey = _activeLppSecureKey(prefs);
    secureStorageValues.remove(activeSecureKey);
    secureStorageValues['_coach_lpp_evidence_v1'] =
        'stale-fixed-root-must-not-load';

    final unresolved = await ReportPersistenceService.loadAnswers();
    expect(unresolved['_coach_lpp_evidence_v1'], '__secure__');

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    expect(prefs.getString('wizard_answers_v2'), before);
    expect(
      secureStorageValues['_coach_lpp_evidence_v1'],
      'stale-fixed-root-must-not-load',
    );
    expect(secureStorageValues[activeSecureKey], isNull);
    expect(provider.profile!.prevoyance.projectedRenteLpp, isNull);
  });
}
