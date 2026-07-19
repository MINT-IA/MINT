import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

const _missingApi = 'missing-api';
final _asOf = DateTime.utc(2026, 7, 19, 12);

Map<String, Object?> _reference({
  required String referenceId,
  required String kind,
  String ownerKind = 'self',
  String source = 'certificate',
  String sourceDate = '2026-01-15',
  int legalYear = 2026,
  String confirmedAt = '2026-01-16T10:00:00.000Z',
}) =>
    <String, Object?>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': ownerKind,
      'source': source,
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
    };

final _validReferences = <Map<String, Object?>>[
  _reference(
    referenceId: '11111111-1111-4111-8111-111111111111',
    kind: 'will',
  ),
  _reference(
    referenceId: '22222222-2222-4222-8222-222222222222',
    kind: 'inheritancePact',
  ),
  _reference(
    referenceId: '33333333-3333-4333-8333-333333333333',
    kind: 'incapacityMandate',
  ),
  _reference(
    referenceId: '44444444-4444-4444-8444-444444444444',
    kind: 'advanceCareDirective',
  ),
];

CoachProfile _restore(Map<String, Object?> fields) => CoachProfile.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
          jsonEncode(<String, Object?>{
            ...CoachProfile.defaults().toJson(),
            ...fields,
          }),
        ) as Map,
      ),
    );

Object? _read(Object? Function() read) {
  try {
    return read();
  } on NoSuchMethodError {
    return _missingApi;
  }
}

Object? _regime(dynamic profile) => _read(() => profile.matrimonialRegime);

Object? _references(dynamic profile) =>
    _read(() => profile.estateInstrumentReferences);

Object? _state(dynamic profile) =>
    _read(() => profile.estateReferenceStateAt(_asOf).name);

Object? _ready(dynamic profile) =>
    _read(() => profile.estateSpecialistReadyAt(_asOf));

void _expectUnknown(dynamic profile, {String? reason}) {
  expect(_regime(profile), isNull, reason: reason);
  expect(_references(profile), isEmpty, reason: reason);
  expect(_state(profile), 'missing', reason: reason);
  expect(_ready(profile), isFalse, reason: reason);
}

void main() {
  test('SUCC-D01 default profile is explicitly unknown and fail-closed', () {
    _expectUnknown(CoachProfile.defaults());
  });

  test('SUCC-D02 household facts never infer estate facts', () {
    final profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1985,
      'q_civil_status': 'married',
      'q_partner_birth_year': 1987,
      'q_children': 2,
      'q_canton': 'GE',
    });

    expect(profile.etatCivil, CoachCivilStatus.marie);
    expect(profile.conjoint, isNotNull);
    _expectUnknown(profile);
  });

  test('SUCC-D03 non-married statuses never fabricate absence', () {
    for (final status in <String>[
      'single',
      'cohabiting',
      'registered_partner',
    ]) {
      _expectUnknown(
        CoachProfile.fromWizardAnswers(<String, dynamic>{
          'q_birth_year': 1985,
          'q_civil_status': status,
        }),
        reason: status,
      );
    }
  });

  test('SUCC-D04 legacy presence booleans are ignored and not reserialized',
      () {
    final profile = CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1985,
      'hasWill': true,
      'testamentExists': true,
      'hasPact': true,
      'hasMandate': true,
    });

    _expectUnknown(profile);
    final encoded = jsonEncode(profile.toJson());
    for (final legacyKey in <String>[
      'hasWill',
      'testamentExists',
      'hasPact',
      'hasMandate',
    ]) {
      expect(encoded, isNot(contains(legacyKey)), reason: legacyKey);
    }
  });

  test('SUCC-D05 complete explicit facts round-trip with value semantics', () {
    final profile = _restore(<String, Object?>{
      'matrimonialRegime': 'participationInAcquests',
      'estateInstrumentReferences': _validReferences,
    });
    final restored = CoachProfile.fromJson(profile.toJson());
    final dynamic dynamicProfile = profile;
    final dynamic dynamicRestored = restored;

    expect(_read(() => dynamicProfile.matrimonialRegime.name),
        'participationInAcquests');
    expect(_read(() => dynamicProfile.estateInstrumentReferences.length), 4);
    expect(
      _read(() => dynamicProfile.estateInstrumentReferences
          .map((dynamic value) => value.kind.name)
          .toList()),
      <String>[
        'will',
        'inheritancePact',
        'incapacityMandate',
        'advanceCareDirective',
      ],
    );
    expect(_state(profile), 'known');
    expect(_ready(profile), isTrue);
    expect(profile.toJson()['matrimonialRegime'], 'participationInAcquests');
    expect(profile.toJson()['estateInstrumentReferences'], _validReferences);
    expect(restored.toJson(), profile.toJson());
    expect(
      _read(() =>
          dynamicRestored.estateInstrumentReferences.first ==
          dynamicProfile.estateInstrumentReferences.first),
      isTrue,
    );
    expect(
      _read(() =>
          dynamicRestored.estateInstrumentReferences.first.hashCode ==
          dynamicProfile.estateInstrumentReferences.first.hashCode),
      isTrue,
    );

    final dynamic copied = _read(() => dynamicProfile.copyWith());
    expect(_regime(copied), _regime(profile));
    expect(_references(copied), _references(profile));
    expect(copied, profile);
    expect(copied.hashCode, profile.hashCode);
    final dynamic cleared =
        _read(() => dynamicProfile.copyWith(matrimonialRegime: null));
    expect(_regime(cleared), isNull);
    expect(_references(cleared), _references(profile));
    expect(_ready(cleared), isFalse);
    expect(cleared, isNot(profile));
    expect(
      () => dynamicProfile.estateInstrumentReferences
          .add(dynamicProfile.estateInstrumentReferences.first),
      throwsUnsupportedError,
    );
  });

  test('SUCC-D06 every required tuple member is fail-closed', () {
    const requiredKeys = <String>{
      'referenceId',
      'kind',
      'ownerKind',
      'source',
      'sourceDate',
      'legalYear',
      'confirmedAt',
    };
    for (final key in requiredKeys) {
      final incomplete = <String, Object?>{..._validReferences.first}
        ..remove(key);
      final profile = _restore(<String, Object?>{
        'matrimonialRegime': 'participationInAcquests',
        'estateInstrumentReferences': <Map<String, Object?>>[incomplete],
      });
      expect(_references(profile), isEmpty, reason: key);
      expect(_ready(profile), isFalse, reason: key);
    }

    for (final invalidOwner in <Object?>[null, 'partner', 'household']) {
      final invalid = <String, Object?>{
        ..._validReferences.first,
        'ownerKind': invalidOwner,
      };
      expect(
        _references(_restore(<String, Object?>{
          'matrimonialRegime': 'participationInAcquests',
          'estateInstrumentReferences': <Map<String, Object?>>[invalid],
        })),
        isEmpty,
        reason: '$invalidOwner',
      );
    }

    for (final invalidId in <Object?>[
      null,
      '11111111-1111-1111-8111-111111111111',
      '11111111-1111-4111-7111-111111111111',
      '11111111-1111-4111-8111-11111111111Z',
    ]) {
      final invalid = <String, Object?>{
        ..._validReferences.first,
        'referenceId': invalidId,
      };
      expect(
        _references(_restore(<String, Object?>{
          'matrimonialRegime': 'participationInAcquests',
          'estateInstrumentReferences': <Map<String, Object?>>[invalid],
        })),
        isEmpty,
        reason: '$invalidId',
      );
    }

    final malformedRoot = _restore(<String, Object?>{
      'matrimonialRegime': 'participationInAcquests',
      'estateInstrumentReferences': <String, Object?>{
        'not': 'a list',
      },
    });
    expect(_references(malformedRoot), isEmpty);
    expect(_ready(malformedRoot), isFalse);
  });

  test('SUCC-D07 non-certificate and future references are rejected', () {
    for (final invalid in <Map<String, Object?>>[
      <String, Object?>{
        ..._validReferences.first,
        'source': 'userInput',
      },
      <String, Object?>{
        ..._validReferences.first,
        'sourceDate': '2099-01-01',
      },
      <String, Object?>{
        ..._validReferences.first,
        'confirmedAt': '2099-01-01T00:00:00.000Z',
      },
    ]) {
      final profile = _restore(<String, Object?>{
        'matrimonialRegime': 'participationInAcquests',
        'estateInstrumentReferences': <Map<String, Object?>>[invalid],
      });
      expect(_references(profile), isEmpty, reason: '$invalid');
      expect(_ready(profile), isFalse, reason: '$invalid');
    }
  });

  test('SUCC-D08 raw or identifying keys are rejected without leakage', () {
    for (final privateEntry in <MapEntry<String, Object?>>[
      const MapEntry('filename', 'testament-julien.pdf'),
      const MapEntry('path', '/private/testament.pdf'),
      const MapEntry('bytes', <int>[1, 2, 3]),
      const MapEntry('ocr', 'private document text'),
      const MapEntry('identity', 'Julien Example'),
      const MapEntry('content', 'beneficiary identity'),
    ]) {
      final invalid = <String, Object?>{
        ..._validReferences.first,
        privateEntry.key: privateEntry.value,
      };
      final profile = _restore(<String, Object?>{
        'matrimonialRegime': 'participationInAcquests',
        'estateInstrumentReferences': <Map<String, Object?>>[invalid],
      });
      expect(_references(profile), isEmpty, reason: privateEntry.key);
      expect(jsonEncode(profile.toJson()),
          isNot(contains(privateEntry.value.toString())));
    }
  });

  test('SUCC-D09 duplicate kinds conflict without silent selection', () {
    final duplicateWill = _reference(
      referenceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      kind: 'will',
      sourceDate: '2026-02-01',
      confirmedAt: '2026-02-02T10:00:00.000Z',
    );
    final profile = _restore(<String, Object?>{
      'matrimonialRegime': 'participationInAcquests',
      'estateInstrumentReferences': <Map<String, Object?>>[
        ..._validReferences,
        duplicateWill,
      ],
    });

    expect(
        _read(() => (profile as dynamic).estateInstrumentReferences.length), 5);
    expect(_state(profile), 'conflict');
    expect(_ready(profile), isFalse);
    expect(
      (profile.toJson()['estateInstrumentReferences'] as List).where(
        (dynamic raw) => (raw as Map)['kind'] == 'will',
      ),
      hasLength(2),
    );
  });

  test('SUCC-D10 civil-status drift preserves facts but suspends readiness',
      () {
    final dynamic profile = _restore(<String, Object?>{
      'matrimonialRegime': 'separationOfProperty',
      'estateInstrumentReferences': _validReferences,
    });
    final dynamic changed =
        _read(() => profile.copyWith(etatCivil: CoachCivilStatus.marie));

    expect(_read(() => changed.matrimonialRegime.name), 'separationOfProperty');
    expect(_read(() => changed.estateInstrumentReferences.length), 4);
    expect(_read(() => changed.estateFactsNeedReconfirmation), isTrue);
    expect(_ready(changed), isFalse);
    expect(
      CoachProfile.fromJson(changed.toJson()).toJson(),
      changed.toJson(),
    );

    final ambiguousPayload = Map<String, dynamic>.from(profile.toJson())
      ..['etatCivil'] = 'pacs'
      ..['civilStatusNeedsConfirmation'] = true
      ..['civilStatusRawValue'] = 'pacs'
      ..['estateFactsNeedReconfirmation'] = false;
    final ambiguous = CoachProfile.fromJson(ambiguousPayload);
    expect(ambiguous.civilStatusNeedsConfirmation, isTrue);
    expect(_references(ambiguous), hasLength(4));
    expect(_ready(ambiguous), isFalse);
  });
}
