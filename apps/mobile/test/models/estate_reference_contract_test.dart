import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

const _rootKey = '_coach_estate_evidence_v1';
final _asOf = DateTime.utc(2026, 7, 20, 10);

Map<String, dynamic> _arrangement({
  required String confirmationId,
  required String kind,
  required String civilStatus,
}) =>
    <String, dynamic>{
      'confirmationId': confirmationId,
      'kind': kind,
      'source': 'userInput',
      'confirmedAt': '2026-07-20T10:00:00.000Z',
      'civilStatusAtConfirmation': civilStatus,
    };

Map<String, dynamic> _present({
  required String evidenceId,
  required String civilStatus,
}) =>
    <String, dynamic>{
      'state': 'confirmedPresent',
      'evidence': <String, dynamic>{
        'evidenceId': evidenceId,
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': '2026-01-15',
        'legalYear': 2026,
        'confirmedAt': '2026-01-16T10:00:00.000Z',
        'civilStatusAtConfirmation': civilStatus,
      },
    };

Map<String, dynamic> _absent({
  required String evidenceId,
  required String civilStatus,
}) =>
    <String, dynamic>{
      'state': 'confirmedAbsent',
      'confirmation': <String, dynamic>{
        'evidenceId': evidenceId,
        'ownerKind': 'self',
        'source': 'userInput',
        'confirmedAt': '2026-07-20T10:00:00.000Z',
        'civilStatusAtConfirmation': civilStatus,
      },
    };

Map<String, dynamic> _unknown() => <String, dynamic>{'state': 'unknown'};

String _root({
  Map<String, dynamic>? matrimonialRegime,
  Map<String, dynamic>? registeredPartnershipPropertyRegime,
  Map<String, dynamic>? will,
  Map<String, dynamic>? inheritancePact,
  Map<String, dynamic>? incapacityMandate,
  Map<String, dynamic>? advanceCareDirective,
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'matrimonialRegime': matrimonialRegime,
      'registeredPartnershipPropertyRegime':
          registeredPartnershipPropertyRegime,
      'estateInstruments': <String, dynamic>{
        'will': will ?? _unknown(),
        'inheritancePact': inheritancePact ?? _unknown(),
        'incapacityMandate': incapacityMandate ?? _unknown(),
        'advanceCareDirective': advanceCareDirective ?? _unknown(),
      },
    });

CoachProfile _profile({
  required String civilStatus,
  String? root,
}) =>
    CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': civilStatus,
      if (root != null) _rootKey: root,
    }, now: () => _asOf);

dynamic _read(dynamic profile, dynamic Function(dynamic) reader, String api) {
  try {
    return reader(profile);
  } on NoSuchMethodError {
    fail('CoachProfile must expose $api for the scoped estate survey.');
  }
}

bool _surveyComplete(dynamic profile) => _read(
      profile,
      (dynamic value) => value.estateReferenceSurveyCompleteAt(_asOf),
      'estateReferenceSurveyCompleteAt',
    ) as bool;

String _handoffCompleteness(dynamic profile) => _read(
      profile,
      (dynamic value) => value.estateReferenceHandoffCompletenessAt(_asOf).name,
      'estateReferenceHandoffCompletenessAt',
    ) as String;

dynamic _slot(dynamic profile, String kind) =>
    _slots(profile).where((dynamic slot) => slot.kind.name == kind).single;

List<dynamic> _slots(dynamic profile) => _read(
      profile,
      (dynamic value) => value.estateInstrumentSlots,
      'four explicit estateInstrumentSlots',
    ) as List<dynamic>;

void main() {
  test('estate aggregate state exposes only live reachable branches', () {
    expect(
      EstateReferenceState.values.map((state) => state.name),
      <String>['known', 'missing', 'invalid', 'needsReconfirmation'],
    );
  });

  test('SUCC-R01 default exposes four unknown slots, never inferred absence',
      () {
    final dynamic profile = _profile(civilStatus: 'celibataire');
    expect(_slots(profile), hasLength(4));
    expect(
      _slots(profile).map((dynamic slot) => slot.state.name).toSet(),
      {'unknown'},
    );
    expect(_surveyComplete(profile), isFalse);
    expect(_handoffCompleteness(profile), 'partial');
  });

  test('SUCC-R02 married survey requires marriage-only arrangement', () {
    final dynamic complete = _profile(
      civilStatus: 'marie',
      root: _root(
        matrimonialRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'participationInAcquests',
          civilStatus: 'marie',
        ),
        will: _present(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'marie',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'marie',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'marie',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'marie',
        ),
      ),
    );

    expect(_surveyComplete(complete), isTrue);
    expect(_handoffCompleteness(complete), 'surveyComplete');
    expect(
      _read(
        complete,
        (dynamic value) => value.matrimonialRegime.name,
        'scoped matrimonialRegime confirmation',
      ),
      'participationInAcquests',
    );
    expect(
      _read(
        complete,
        (dynamic value) => value.registeredPartnershipPropertyRegime,
        'distinct registeredPartnershipPropertyRegime',
      ),
      isNull,
    );
  });

  test('SUCC-R03 registered partnership uses a distinct LPart enum', () {
    final dynamic profile = _profile(
      civilStatus: 'registered_partner',
      root: _root(
        registeredPartnershipPropertyRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'statutorySeparationOfProperty',
          civilStatus: 'registeredPartnership',
        ),
      ),
    );
    final dynamic arrangement = _read(
      profile,
      (dynamic value) => value.registeredPartnershipPropertyRegime,
      'RegisteredPartnershipPropertyRegimeKind',
    );

    expect(arrangement.kind.name, 'statutorySeparationOfProperty');
    expect(arrangement.kind, isNot(isA<MatrimonialRegimeKind>()));
    expect(_surveyComplete(profile), isFalse,
        reason: 'unknown instrument slots are not confirmed absent');
  });

  test('SUCC-R04 non-union arrangement is computed N/A, never persisted', () {
    for (final civilStatus in <String>[
      'celibataire',
      'divorce',
      'veuf',
      'concubinage',
    ]) {
      final dynamic profile = _profile(
        civilStatus: civilStatus,
        root: _root(
          will: _absent(
            evidenceId: '11111111-1111-4111-8111-111111111111',
            civilStatus: civilStatus,
          ),
          inheritancePact: _absent(
            evidenceId: '22222222-2222-4222-8222-222222222222',
            civilStatus: civilStatus,
          ),
          incapacityMandate: _absent(
            evidenceId: '33333333-3333-4333-8333-333333333333',
            civilStatus: civilStatus,
          ),
          advanceCareDirective: _absent(
            evidenceId: '44444444-4444-4444-8444-444444444444',
            civilStatus: civilStatus,
          ),
        ),
      );
      expect(
        _read(
          profile,
          (dynamic value) => value.currentEstateArrangementApplicability.name,
          'currentEstateArrangementApplicability',
        ),
        'notApplicable',
        reason: civilStatus,
      );
      expect(_surveyComplete(profile), isTrue, reason: civilStatus);
    }
  });

  test('SUCC-R05 ambiguous civil status remains unknown and incomplete', () {
    final dynamic profile = _profile(
      civilStatus: 'pacs',
      root: _root(
        will: _absent(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'celibataire',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'celibataire',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'celibataire',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'celibataire',
        ),
      ),
    );

    expect(profile.civilStatusNeedsConfirmation, isTrue);
    expect(
      _read(
        profile,
        (dynamic value) => value.currentEstateArrangementApplicability.name,
        'currentEstateArrangementApplicability',
      ),
      'unknown',
    );
    expect(_surveyComplete(profile), isFalse);
  });

  test('SUCC-R06 each confirmation is civil-status scoped independently', () {
    final dynamic profile = _profile(
      civilStatus: 'marie',
      root: _root(
        matrimonialRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'participationInAcquests',
          civilStatus: 'marie',
        ),
        will: _present(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'celibataire',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'marie',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'marie',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'marie',
        ),
      ),
    );

    expect(_slots(profile), hasLength(4),
        reason: 'one stale slot must not erase unrelated confirmations');
    expect(_slot(profile, 'will').state.name, 'stale');
    for (final kind in <String>[
      'inheritancePact',
      'incapacityMandate',
      'advanceCareDirective',
    ]) {
      expect(_slot(profile, kind).state.name, 'confirmedAbsent', reason: kind);
    }
    expect(_surveyComplete(profile), isFalse);
    expect(_handoffCompleteness(profile), 'partial');
  });

  test('SUCC-R07 household facts and legacy booleans never infer slots', () {
    final dynamic profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1985,
      'q_civil_status': 'married',
      'q_partner_birth_year': 1987,
      'q_children': 2,
      'q_canton': 'GE',
      'hasWill': true,
      'testamentExists': true,
      'hasPact': false,
      'hasMandate': true,
    }, now: () => _asOf);

    expect(profile.etatCivil, CoachCivilStatus.marie);
    expect(profile.conjoint, isNotNull);
    expect(
      _slots(profile).map((dynamic slot) => slot.state.name).toSet(),
      {'unknown'},
    );
    expect(_surveyComplete(profile), isFalse);
    final encoded = jsonEncode(profile.toJson());
    for (final key in <String>[
      'hasWill',
      'testamentExists',
      'hasPact',
      'hasMandate',
    ]) {
      expect(encoded, isNot(contains(key)), reason: key);
    }
  });

  test('SUCC-R08 present evidence requires every strict tuple key', () {
    final valid = Map<String, dynamic>.from(
      _present(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        civilStatus: 'celibataire',
      )['evidence'] as Map,
    );
    for (final key in <String>{
      'evidenceId',
      'ownerKind',
      'source',
      'sourceDate',
      'legalYear',
      'confirmedAt',
      'civilStatusAtConfirmation',
    }) {
      final incomplete = Map<String, dynamic>.from(valid)..remove(key);
      final dynamic profile = _profile(
        civilStatus: 'celibataire',
        root: _root(
          will: <String, dynamic>{
            'state': 'confirmedPresent',
            'evidence': incomplete,
          },
          inheritancePact: _absent(
            evidenceId: '22222222-2222-4222-8222-222222222222',
            civilStatus: 'celibataire',
          ),
          incapacityMandate: _absent(
            evidenceId: '33333333-3333-4333-8333-333333333333',
            civilStatus: 'celibataire',
          ),
          advanceCareDirective: _absent(
            evidenceId: '44444444-4444-4444-8444-444444444444',
            civilStatus: 'celibataire',
          ),
        ),
      );
      expect(_slot(profile, 'will').state.name, 'invalid', reason: key);
      expect(_slots(profile), hasLength(4), reason: key);
      expect(_surveyComplete(profile), isFalse, reason: key);
    }
  });

  test('SUCC-R09 present evidence rejects invalid identity and time fields',
      () {
    final valid = Map<String, dynamic>.from(
      _present(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        civilStatus: 'celibataire',
      )['evidence'] as Map,
    );
    for (final mutation in <Map<String, Object?>>[
      {'evidenceId': 'not-a-uuid-v4'},
      {'ownerKind': 'partner'},
      {'source': 'userInput'},
      {'sourceDate': '2026-02-30'},
      {'legalYear': 1899},
      {'confirmedAt': '2026-07-20T12:00:00.000+02:00'},
      {'sourceDate': '2099-01-01'},
      {'confirmedAt': '2099-01-01T00:00:00.000Z'},
    ]) {
      final invalid = <String, dynamic>{...valid, ...mutation};
      final dynamic profile = _profile(
        civilStatus: 'celibataire',
        root: _root(
          will: <String, dynamic>{
            'state': 'confirmedPresent',
            'evidence': invalid,
          },
        ),
      );
      expect(_slot(profile, 'will').state.name, 'invalid', reason: '$mutation');
      expect(_surveyComplete(profile), isFalse, reason: '$mutation');
    }
  });

  test('SUCC-R10 present evidence rejects raw extras without leakage', () {
    for (final extra in <MapEntry<String, Object?>>[
      const MapEntry('filename', 'testament-julien.pdf'),
      const MapEntry('path', '/private/testament.pdf'),
      const MapEntry('bytes', <int>[1, 2, 3]),
      const MapEntry('ocr', 'private document text'),
      const MapEntry('identity', 'Julien Example'),
      const MapEntry('content', 'beneficiary identity'),
    ]) {
      final present = _present(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        civilStatus: 'celibataire',
      );
      (present['evidence'] as Map<String, dynamic>)[extra.key] = extra.value;
      final dynamic profile = _profile(
        civilStatus: 'celibataire',
        root: _root(will: present),
      );
      expect(_slot(profile, 'will').state.name, 'invalid', reason: extra.key);
      expect(
          jsonEncode(profile.toJson()), isNot(contains(extra.value.toString())),
          reason: extra.key);
    }
  });

  test('SUCC-R11 absent confirmation is strict and raw-free', () {
    final valid = Map<String, dynamic>.from(
      _absent(
        evidenceId: '11111111-1111-4111-8111-111111111111',
        civilStatus: 'celibataire',
      )['confirmation'] as Map,
    );
    for (final key in <String>{
      'evidenceId',
      'ownerKind',
      'source',
      'confirmedAt',
      'civilStatusAtConfirmation',
    }) {
      final incomplete = Map<String, dynamic>.from(valid)..remove(key);
      final dynamic profile = _profile(
        civilStatus: 'celibataire',
        root: _root(
          will: <String, dynamic>{
            'state': 'confirmedAbsent',
            'confirmation': incomplete,
          },
        ),
      );
      expect(_slot(profile, 'will').state.name, 'invalid', reason: key);
    }
    for (final mutation in <Map<String, Object?>>[
      {'evidenceId': 'not-a-uuid-v4'},
      {'ownerKind': 'partner'},
      {'source': 'certificate'},
      {'confirmedAt': '2099-01-01T00:00:00.000Z'},
      {'confirmedAt': '2026-07-20T12:00:00.000+02:00'},
      {'filename': 'absence.txt'},
      {'content': 'private reason'},
    ]) {
      final invalid = <String, dynamic>{...valid, ...mutation};
      final dynamic profile = _profile(
        civilStatus: 'celibataire',
        root: _root(
          will: <String, dynamic>{
            'state': 'confirmedAbsent',
            'confirmation': invalid,
          },
        ),
      );
      expect(_slot(profile, 'will').state.name, 'invalid', reason: '$mutation');
      expect(jsonEncode(profile.toJson()),
          isNot(contains(mutation.values.last.toString())));
    }
  });

  test('SUCC-R12 estateInstruments requires exactly four named slots', () {
    final validRoot = Map<String, dynamic>.from(
      jsonDecode(_root()) as Map,
    );
    final missing = Map<String, dynamic>.from(
      validRoot['estateInstruments'] as Map,
    )..remove('will');
    final dynamic missingProfile = _profile(
      civilStatus: 'celibataire',
      root: jsonEncode(<String, dynamic>{
        ...validRoot,
        'estateInstruments': missing,
      }),
    );
    expect(_slots(missingProfile), hasLength(4));
    expect(_slot(missingProfile, 'will').state.name, 'unknown');
    expect(_surveyComplete(missingProfile), isFalse);

    final extra = Map<String, dynamic>.from(
      validRoot['estateInstruments'] as Map,
    )..['codicil'] = _unknown();
    final dynamic extraProfile = _profile(
      civilStatus: 'celibataire',
      root: jsonEncode(<String, dynamic>{
        ...validRoot,
        'estateInstruments': extra,
      }),
    );
    expect(_slots(extraProfile), hasLength(4));
    expect(_surveyComplete(extraProfile), isFalse);
  });

  test('SUCC-R13 malformed slot is invalid without erasing other slots', () {
    final dynamic profile = _profile(
      civilStatus: 'celibataire',
      root: _root(
        will: <String, dynamic>{
          'state': 'confirmedAbsent',
          'confirmation': 'not-an-object',
        },
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'celibataire',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'celibataire',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'celibataire',
        ),
      ),
    );
    expect(_slots(profile), hasLength(4));
    expect(_slot(profile, 'will').state.name, 'invalid');
    expect(
      _slots(profile)
          .where((dynamic slot) => slot.kind.name != 'will')
          .map((dynamic slot) => slot.state.name)
          .toSet(),
      {'confirmedAbsent'},
    );
    expect(_surveyComplete(profile), isFalse);
    expect(_handoffCompleteness(profile), 'partial');
  });

  test('SUCC-R14 one explicit slot yields partial handoff, not survey complete',
      () {
    final dynamic profile = _profile(
      civilStatus: 'celibataire',
      root: _root(
        will: _absent(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'celibataire',
        ),
      ),
    );
    expect(_slot(profile, 'will').state.name, 'confirmedAbsent');
    expect(_handoffCompleteness(profile), 'partial');
    expect(_surveyComplete(profile), isFalse);
  });

  test('SUCC-R15 staged legacy global-civil-status root is rejected', () {
    final dynamic profile = _profile(
      civilStatus: 'celibataire',
      root: jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'matrimonialRegime': null,
        'civilStatusAtConfirmation': 'celibataire',
        'estateInstrumentReferences': <dynamic>[],
      }),
    );

    expect(_slots(profile).map((dynamic slot) => slot.state.name).toSet(),
        {'unknown'});
    expect(_surveyComplete(profile), isFalse);
  });

  group('SUCC-R16 authority root refuses noncanonical slots', () {
    final evidence = EstateInstrumentEvidence(
      evidenceId: '11111111-1111-4111-8111-111111111111',
      sourceDate: _fixedSourceDate,
      legalYear: 2026,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.celibataire,
    );
    final canonicalUnknown = <EstateInstrumentSlot>[
      for (final kind in EstateInstrumentKind.values)
        EstateInstrumentSlot.unknown(kind),
    ];
    final cases = <String, List<EstateInstrumentSlot>>{
      'stale': <EstateInstrumentSlot>[
        EstateInstrumentSlot.present(
          EstateInstrumentKind.will,
          evidence,
        ).stale(),
        ...canonicalUnknown.skip(1),
      ],
      'invalid': <EstateInstrumentSlot>[
        const EstateInstrumentSlot.invalid(EstateInstrumentKind.will),
        ...canonicalUnknown.skip(1),
      ],
      'duplicated': <EstateInstrumentSlot>[
        for (var index = 0; index < EstateInstrumentKind.values.length; index++)
          const EstateInstrumentSlot.unknown(EstateInstrumentKind.will),
      ],
      'missing': canonicalUnknown.take(3).toList(growable: false),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final root = EstateEvidenceRoot(
          matrimonialRegime: null,
          registeredPartnershipPropertyRegime: null,
          estateInstruments: entry.value,
        );
        expect(root.toJsonString, throwsStateError);
      });
    }
  });

  test('SUCC-V01 profile JSON round-trip preserves LPart and all four slots',
      () {
    final profile = _profile(
      civilStatus: 'registered_partner',
      root: _root(
        registeredPartnershipPropertyRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'statutorySeparationOfProperty',
          civilStatus: 'registeredPartnership',
        ),
        will: _present(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'registeredPartnership',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'registeredPartnership',
        ),
        incapacityMandate: _unknown(),
        advanceCareDirective: _unknown(),
      ),
    );
    final restored = CoachProfile.fromJson(profile.toJson());

    expect(
      restored.registeredPartnershipPropertyRegime,
      profile.registeredPartnershipPropertyRegime,
    );
    expect(
      restored.estateInstrumentSlots
          .map((slot) => (slot.kind.name, slot.state.name))
          .toList(),
      profile.estateInstrumentSlots
          .map((slot) => (slot.kind.name, slot.state.name))
          .toList(),
    );
    expect(restored.estateInstrumentSlots, profile.estateInstrumentSlots);
    final encoded = jsonEncode(restored.toJson()).toLowerCase();
    for (final forbidden in <String>[
      'filename',
      'path',
      'bytes',
      'ocr',
      'identity',
      'content',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
  });

  test('SUCC-V02 copyWith replaces and explicitly clears LPart confirmation',
      () {
    final profile = _profile(
      civilStatus: 'registered_partner',
      root: _root(
        registeredPartnershipPropertyRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'statutorySeparationOfProperty',
          civilStatus: 'registeredPartnership',
        ),
      ),
    );
    final replacement = RegisteredPartnershipPropertyRegimeConfirmation(
      confirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind:
          RegisteredPartnershipPropertyRegimeKind.statutorySeparationOfProperty,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final dynamic dynamicProfile = profile;

    final dynamic replaced = dynamicProfile.copyWith(
      registeredPartnershipPropertyRegime: replacement,
    );
    expect(replaced.registeredPartnershipPropertyRegime, replacement);
    final dynamic cleared = replaced.copyWith(
      registeredPartnershipPropertyRegime: null,
    );
    expect(cleared.registeredPartnershipPropertyRegime, isNull);
  });

  test('SUCC-V03 copyWith can replace the immutable four-slot view', () {
    final profile = _profile(civilStatus: 'celibataire');
    final slots = <EstateInstrumentSlot>[
      EstateInstrumentSlot.absent(
        EstateInstrumentKind.will,
        EstateInstrumentAbsenceConfirmation(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          confirmedAt: _fixedConfirmationInstant,
          civilStatusAtConfirmation: CoachCivilStatus.celibataire,
        ),
      ),
      for (final kind in EstateInstrumentKind.values.skip(1))
        EstateInstrumentSlot.unknown(kind),
    ];
    final dynamic replaced = (profile as dynamic).copyWith(
      estateInstrumentSlots: slots,
    );

    expect(replaced.estateInstrumentSlots, slots);
    expect(replaced.estateInstrumentSlots, isNot(same(slots)));
    expect(
      () => replaced.estateInstrumentSlots.add(slots.first),
      throwsUnsupportedError,
    );
  });

  test('SUCC-V04 nested estate objects have value equality and stable hashes',
      () {
    final matrimonialA = EstateMatrimonialRegimeConfirmation(
      confirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: MatrimonialRegimeKind.participationInAcquests,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.marie,
    );
    final matrimonialB = EstateMatrimonialRegimeConfirmation(
      confirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: MatrimonialRegimeKind.participationInAcquests,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.marie,
    );
    final lpartA = RegisteredPartnershipPropertyRegimeConfirmation(
      confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      kind:
          RegisteredPartnershipPropertyRegimeKind.statutorySeparationOfProperty,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final lpartB = RegisteredPartnershipPropertyRegimeConfirmation(
      confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      kind:
          RegisteredPartnershipPropertyRegimeKind.statutorySeparationOfProperty,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final evidenceA = EstateInstrumentEvidence(
      evidenceId: '11111111-1111-4111-8111-111111111111',
      sourceDate: _fixedSourceDate,
      legalYear: 2026,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final evidenceB = EstateInstrumentEvidence(
      evidenceId: '11111111-1111-4111-8111-111111111111',
      sourceDate: _fixedSourceDate,
      legalYear: 2026,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final absenceA = EstateInstrumentAbsenceConfirmation(
      evidenceId: '22222222-2222-4222-8222-222222222222',
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final absenceB = EstateInstrumentAbsenceConfirmation(
      evidenceId: '22222222-2222-4222-8222-222222222222',
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
    );
    final slotA = EstateInstrumentSlot.present(
      EstateInstrumentKind.will,
      evidenceA,
    );
    final slotB = EstateInstrumentSlot.present(
      EstateInstrumentKind.will,
      evidenceB,
    );

    expect(matrimonialA, matrimonialB);
    expect(matrimonialA.hashCode, matrimonialB.hashCode);
    expect(lpartA, lpartB);
    expect(lpartA.hashCode, lpartB.hashCode);
    expect(evidenceA, evidenceB);
    expect(evidenceA.hashCode, evidenceB.hashCode);
    expect(absenceA, absenceB);
    expect(absenceA.hashCode, absenceB.hashCode);
    expect(slotA, slotB);
    expect(slotA.hashCode, slotB.hashCode);
  });

  test('SUCC-V05 direct JSON preserves stale slots with carried evidence', () {
    final presentEvidence = EstateInstrumentEvidence(
      evidenceId: '11111111-1111-4111-8111-111111111111',
      sourceDate: _fixedSourceDate,
      legalYear: 2026,
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.marie,
    );
    final absenceConfirmation = EstateInstrumentAbsenceConfirmation(
      evidenceId: '22222222-2222-4222-8222-222222222222',
      confirmedAt: _fixedConfirmationInstant,
      civilStatusAtConfirmation: CoachCivilStatus.marie,
    );
    final stalePresent = EstateInstrumentSlot.present(
      EstateInstrumentKind.will,
      presentEvidence,
    ).stale();
    final staleAbsent = EstateInstrumentSlot.absent(
      EstateInstrumentKind.inheritancePact,
      absenceConfirmation,
    ).stale();
    final profile = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.celibataire,
      estateInstrumentSlots: <EstateInstrumentSlot>[
        stalePresent,
        staleAbsent,
        const EstateInstrumentSlot.unknown(
          EstateInstrumentKind.incapacityMandate,
        ),
        const EstateInstrumentSlot.unknown(
          EstateInstrumentKind.advanceCareDirective,
        ),
      ],
      estateFactsNeedReconfirmation: true,
    );

    final restored = CoachProfile.fromJson(profile.toJson());
    final restoredPresent = restored.estateInstrumentSlots.singleWhere(
      (slot) => slot.kind == EstateInstrumentKind.will,
    );
    final restoredAbsent = restored.estateInstrumentSlots.singleWhere(
      (slot) => slot.kind == EstateInstrumentKind.inheritancePact,
    );

    expect(
      (
        restoredPresent.state,
        restoredPresent.evidence,
        restoredAbsent.state,
        restoredAbsent.absenceConfirmation,
        restored.estateFactsNeedReconfirmation,
        restored.estateReferenceStateAt(_asOf),
      ),
      (
        EstateInstrumentSlotState.stale,
        presentEvidence,
        EstateInstrumentSlotState.stale,
        absenceConfirmation,
        true,
        EstateReferenceState.needsReconfirmation,
      ),
    );
  });

  test('SUCC-V06 direct JSON preserves an invalid slot state', () {
    final profile = CoachProfile.defaults().copyWith(
      estateInstrumentSlots: <EstateInstrumentSlot>[
        const EstateInstrumentSlot.invalid(EstateInstrumentKind.will),
        for (final kind in EstateInstrumentKind.values.skip(1))
          EstateInstrumentSlot.unknown(kind),
      ],
    );

    final restored = CoachProfile.fromJson(profile.toJson());

    expect(
      (
        restored.estateInstrumentSlots
            .singleWhere((slot) => slot.kind == EstateInstrumentKind.will)
            .state,
        restored.estateReferenceStateAt(_asOf),
      ),
      (
        EstateInstrumentSlotState.invalid,
        EstateReferenceState.invalid,
      ),
    );
  });

  test('SUCC-V07 direct JSON serializes only the four-slot instrument SOT', () {
    const evidenceId = '11111111-1111-4111-8111-111111111111';
    final profile = _profile(
      civilStatus: 'celibataire',
      root: _root(
        will: _present(
          evidenceId: evidenceId,
          civilStatus: 'celibataire',
        ),
      ),
    );
    expect(profile.estateInstrumentReferences, hasLength(1));

    final projection = profile.toJson();
    final encoded = jsonEncode(projection);
    final slots = Map<String, dynamic>.from(
      projection['estateInstrumentSlots'] as Map,
    );

    expect(
      (
        projection.containsKey('estateInstrumentReferences'),
        RegExp(RegExp.escape(evidenceId)).allMatches(encoded).length,
      ),
      (
        false,
        1,
      ),
    );
    expect(
      slots.keys,
      unorderedEquals(<String>{
        'will',
        'inheritancePact',
        'incapacityMandate',
        'advanceCareDirective',
      }),
    );
  });

  test('SUCC-P01 LPart enum exposes only the adjudicated legal categories', () {
    expect(
      RegisteredPartnershipPropertyRegimeKind.values
          .map((value) => value.name)
          .toSet(),
      <String>{
        'statutorySeparationOfProperty',
        'agreedParticipationInAcquestsDivision',
        'otherPropertyAgreement',
      },
    );
  });

  test('SUCC-P02 survey refuses confirmations after the evaluation instant',
      () {
    final profile = _profile(
      civilStatus: 'marie',
      root: _root(
        matrimonialRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'participationInAcquests',
          civilStatus: 'marie',
        ),
        will: _absent(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'marie',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'marie',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'marie',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'marie',
        ),
      ),
    );

    expect(profile.estateReferenceSurveyCompleteAt(_asOf), isTrue);
    expect(
      profile.estateReferenceSurveyCompleteAt(
        _asOf.subtract(const Duration(days: 1)),
      ),
      isFalse,
    );
  });

  test('SUCC-P03 survey refuses a present source date after asOf', () {
    final present = _present(
      evidenceId: '11111111-1111-4111-8111-111111111111',
      civilStatus: 'celibataire',
    );
    final evidence = present['evidence'] as Map<String, dynamic>
      ..['sourceDate'] = '2026-07-20'
      ..['confirmedAt'] = '2026-01-16T10:00:00.000Z';
    expect(evidence['sourceDate'], '2026-07-20');
    Map<String, dynamic> earlyAbsent(String id) {
      final slot = _absent(evidenceId: id, civilStatus: 'celibataire');
      (slot['confirmation'] as Map<String, dynamic>)['confirmedAt'] =
          '2026-01-16T10:00:00.000Z';
      return slot;
    }

    final profile = _profile(
      civilStatus: 'celibataire',
      root: _root(
        will: present,
        inheritancePact: earlyAbsent('22222222-2222-4222-8222-222222222222'),
        incapacityMandate: earlyAbsent('33333333-3333-4333-8333-333333333333'),
        advanceCareDirective:
            earlyAbsent('44444444-4444-4444-8444-444444444444'),
      ),
    );

    expect(
      profile.estateReferenceSurveyCompleteAt(DateTime.utc(2026, 7, 19)),
      isFalse,
    );
  });

  test('SUCC-P04 direct profile refuses duplicated or missing slot kinds', () {
    EstateInstrumentSlot absence(EstateInstrumentKind kind, String id) =>
        EstateInstrumentSlot.absent(
          kind,
          EstateInstrumentAbsenceConfirmation(
            evidenceId: id,
            confirmedAt: _fixedConfirmationInstant,
            civilStatusAtConfirmation: CoachCivilStatus.celibataire,
          ),
        );
    final dynamic base = CoachProfile.defaults();
    final dynamic duplicated = base.copyWith(
      etatCivil: CoachCivilStatus.celibataire,
      estateInstrumentSlots: <EstateInstrumentSlot>[
        absence(
            EstateInstrumentKind.will, '11111111-1111-4111-8111-111111111111'),
        absence(
            EstateInstrumentKind.will, '22222222-2222-4222-8222-222222222222'),
        absence(
            EstateInstrumentKind.will, '33333333-3333-4333-8333-333333333333'),
        absence(
            EstateInstrumentKind.will, '44444444-4444-4444-8444-444444444444'),
      ],
    );
    final dynamic missing = base.copyWith(
      etatCivil: CoachCivilStatus.celibataire,
      estateInstrumentSlots: <EstateInstrumentSlot>[
        absence(
            EstateInstrumentKind.will, '11111111-1111-4111-8111-111111111111'),
        absence(EstateInstrumentKind.inheritancePact,
            '22222222-2222-4222-8222-222222222222'),
        absence(EstateInstrumentKind.incapacityMandate,
            '33333333-3333-4333-8333-333333333333'),
      ],
    );

    expect(duplicated.estateReferenceSurveyCompleteAt(_asOf), isFalse);
    expect(missing.estateReferenceSurveyCompleteAt(_asOf), isFalse);
  });

  test('SUCC-P05 direct profile refuses arrangement and slots out of scope',
      () {
    final registeredSlots = <EstateInstrumentSlot>[
      for (var index = 0; index < EstateInstrumentKind.values.length; index++)
        EstateInstrumentSlot.absent(
          EstateInstrumentKind.values[index],
          EstateInstrumentAbsenceConfirmation(
            evidenceId: '${index + 1}${index + 1}${index + 1}${index + 1}'
                '${index + 1}${index + 1}${index + 1}${index + 1}-1111-4111-8111-111111111111',
            confirmedAt: _fixedConfirmationInstant,
            civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
          ),
        ),
    ];
    final dynamic wrongArrangement =
        (CoachProfile.defaults() as dynamic).copyWith(
      etatCivil: CoachCivilStatus.registeredPartnership,
      registeredPartnershipPropertyRegime:
          RegisteredPartnershipPropertyRegimeConfirmation(
        confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        kind: RegisteredPartnershipPropertyRegimeKind
            .statutorySeparationOfProperty,
        confirmedAt: _fixedConfirmationInstant,
        civilStatusAtConfirmation: CoachCivilStatus.marie,
      ),
      estateInstrumentSlots: registeredSlots,
    );
    final mismatchedSlots = <EstateInstrumentSlot>[
      for (var index = 0; index < EstateInstrumentKind.values.length; index++)
        EstateInstrumentSlot.absent(
          EstateInstrumentKind.values[index],
          EstateInstrumentAbsenceConfirmation(
            evidenceId: '${index + 1}${index + 1}${index + 1}${index + 1}'
                '${index + 1}${index + 1}${index + 1}${index + 1}-2222-4222-8222-222222222222',
            confirmedAt: _fixedConfirmationInstant,
            civilStatusAtConfirmation: CoachCivilStatus.marie,
          ),
        ),
    ];
    final dynamic wrongSlots = (CoachProfile.defaults() as dynamic).copyWith(
      etatCivil: CoachCivilStatus.registeredPartnership,
      registeredPartnershipPropertyRegime:
          RegisteredPartnershipPropertyRegimeConfirmation(
        confirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        kind: RegisteredPartnershipPropertyRegimeKind
            .statutorySeparationOfProperty,
        confirmedAt: _fixedConfirmationInstant,
        civilStatusAtConfirmation: CoachCivilStatus.registeredPartnership,
      ),
      estateInstrumentSlots: mismatchedSlots,
    );

    expect(wrongArrangement.estateReferenceSurveyCompleteAt(_asOf), isFalse);
    expect(wrongSlots.estateReferenceSurveyCompleteAt(_asOf), isFalse);
  });

  test('SUCC-P06 marriage applicability requires a scoped confirmation', () {
    final marriedWithoutConfirmation = CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.marie,
      matrimonialRegime: MatrimonialRegimeKind.participationInAcquests,
    );

    expect(
      marriedWithoutConfirmation.currentEstateArrangementApplicability,
      EstateArrangementApplicability.unknown,
    );
  });

  test('SUCC-P07 LPart applicability rejects a mismatched civil scope', () {
    final partnershipWithMismatchedConfirmation =
        CoachProfile.defaults().copyWith(
      etatCivil: CoachCivilStatus.registeredPartnership,
      registeredPartnershipPropertyRegime:
          RegisteredPartnershipPropertyRegimeConfirmation(
        confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        kind: RegisteredPartnershipPropertyRegimeKind
            .statutorySeparationOfProperty,
        confirmedAt: _fixedConfirmationInstant,
        civilStatusAtConfirmation: CoachCivilStatus.marie,
      ),
    );

    expect(
      partnershipWithMismatchedConfirmation
          .currentEstateArrangementApplicability,
      EstateArrangementApplicability.unknown,
    );
  });

  test('SUCC-P08 legacy reconfirmation marker drives aggregate state', () {
    final legacyProjection = CoachProfile.defaults().toJson()
      ..['estateFactsNeedReconfirmation'] = true;

    final restored = CoachProfile.fromJson(legacyProjection);

    expect(restored.estateFactsNeedReconfirmation, isTrue);
    expect(
      restored.estateReferenceStateAt(_asOf),
      EstateReferenceState.needsReconfirmation,
    );
  });
}

final _fixedConfirmationInstant = DateTime.utc(2026, 7, 20, 10);
final _fixedSourceDate = DateTime.utc(2026, 1, 15);
