import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

const _referenceFields = <String>{
  'lppRegulationReference',
  'lppCapitalNoticeDeadline',
  'pillar3aBeneficiaryClause',
  'latestTaxDecisionReference',
};

const _missingApi = 'missing-api';
final _asOf = DateTime.utc(2026, 7, 17, 12);

Map<String, Object?> _commonReference({
  required String referenceId,
  required String kind,
  String source = 'certificate',
  String sourceDate = '2026-01-15',
  int legalYear = 2026,
  String confirmedAt = '2026-01-16T10:00:00.000Z',
}) =>
    <String, Object?>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': 'self',
      'source': source,
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
    };

final _validReferences = <String, Map<String, Object?>>{
  'lppRegulationReference': _commonReference(
    referenceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    kind: 'lppRegulation',
  ),
  'lppCapitalNoticeDeadline': <String, Object?>{
    ..._commonReference(
      referenceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: 'lppCapitalNotice',
    ),
    'deadlineDate': '2026-09-30',
  },
  'pillar3aBeneficiaryClause': <String, Object?>{
    ..._commonReference(
      referenceId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      kind: 'pillar3aBeneficiaryClause',
    ),
    'contractReferenceId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  },
  'latestTaxDecisionReference': <String, Object?>{
    ..._commonReference(
      referenceId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      kind: 'taxAssessmentDecision',
      sourceDate: '2026-06-30',
    ),
    'taxYear': 2025,
    'jurisdiction': 'GE',
    'subject': 'incomeAndWealth',
  },
};

CoachProfile _restoreWith(Map<String, Object?> specialistFields) {
  final encoded = jsonEncode(<String, Object?>{
    ...CoachProfile.defaults().toJson(),
    ...specialistFields,
  });
  return CoachProfile.fromJson(
    Map<String, dynamic>.from(jsonDecode(encoded) as Map),
  );
}

Map<String, dynamic>? _storedReference(
  CoachProfile profile,
  String field,
) {
  final raw = profile.toJson()[field];
  return raw is Map ? Map<String, dynamic>.from(raw) : null;
}

bool _educationalOnlyFor(CoachProfile profile, String field) =>
    _storedReference(profile, field) == null;

Object? _readDynamic(Object? Function() read) {
  try {
    return read();
  } on NoSuchMethodError {
    return _missingApi;
  }
}

Object? _typedReference(dynamic profile, String field) => switch (field) {
      'lppRegulationReference' =>
        _readDynamic(() => profile.lppRegulationReference),
      'lppCapitalNoticeDeadline' =>
        _readDynamic(() => profile.lppCapitalNoticeDeadline),
      'pillar3aBeneficiaryClause' =>
        _readDynamic(() => profile.pillar3aBeneficiaryClause),
      'latestTaxDecisionReference' =>
        _readDynamic(() => profile.latestTaxDecisionReference),
      _ => throw ArgumentError.value(field, 'field'),
    };

Map<String, Object?> _precisionContract(Object? reference) {
  if (reference == _missingApi) {
    return const <String, Object?>{
      'type': _missingApi,
      'state': _missingApi,
      'precisionReady': _missingApi,
      'educationalOnly': _missingApi,
    };
  }
  if (reference == null) {
    return const <String, Object?>{
      'type': null,
      'state': 'missing',
      'precisionReady': false,
      'educationalOnly': true,
    };
  }

  final dynamic typed = reference;
  final state = _readDynamic(() => typed.stateAt(_asOf).name);
  final precisionReady = _readDynamic(() => typed.precisionReadyAt(_asOf));
  return <String, Object?>{
    'type': reference.runtimeType.toString(),
    'state': state,
    'precisionReady': precisionReady,
    'educationalOnly':
        precisionReady == _missingApi ? _missingApi : precisionReady != true,
  };
}

void main() {
  test('the four profile properties are typed precision-bearing evidence', () {
    final dynamic restored = _restoreWith(_validReferences);

    for (final field in _referenceFields) {
      expect(
        _precisionContract(_typedReference(restored, field)),
        <String, Object?>{
          'type': 'SpecialistReferenceEvidence',
          'state': 'known',
          'precisionReady': true,
          'educationalOnly': false,
        },
        reason:
            '$field must be a typed value object whose as-of predicate, not '
            'a raw echoed Map, authorizes precise meaning.',
      );
    }
  });

  test('the four complete specialist references survive the existing JSON path',
      () {
    final restored = _restoreWith(_validReferences);

    for (final entry in _validReferences.entries) {
      expect(
        _storedReference(restored, entry.key),
        entry.value,
        reason: 'A complete certificate-backed ${entry.key} tuple must survive '
            'CoachProfile.fromJson -> toJson without document contents.',
      );
      expect(
        _educationalOnlyFor(restored, entry.key),
        isFalse,
        reason: '${entry.key} alone owns its precision predicate.',
      );
    }
  });

  test('incomplete, non-certificate, and future tuples fail closed', () {
    final invalidByField = <String, Map<String, Object?>>{
      'lppRegulationReference': <String, Object?>{
        'filename': 'reglement.pdf',
        'kind': 'lppRegulation',
      },
      'lppCapitalNoticeDeadline': <String, Object?>{
        ..._commonReference(
          referenceId: '11111111-1111-4111-8111-111111111111',
          kind: 'lppCapitalNotice',
          source: 'userInput',
        ),
        'deadlineDate': '2026-09-30',
      },
      'pillar3aBeneficiaryClause': <String, Object?>{
        ..._commonReference(
          referenceId: '22222222-2222-4222-8222-222222222222',
          kind: 'pillar3aBeneficiaryClause',
          sourceDate: '2999-01-01',
          confirmedAt: '2999-01-02T10:00:00.000Z',
        ),
        'contractReferenceId': '33333333-3333-4333-8333-333333333333',
      },
      'latestTaxDecisionReference': <String, Object?>{
        ..._commonReference(
          referenceId: '44444444-4444-4444-8444-444444444444',
          kind: 'taxAssessmentDecision',
        )..remove('legalYear'),
        'taxYear': 2025,
        'jurisdiction': 'GE',
        'subject': 'incomeAndWealth',
      },
    };

    for (final entry in invalidByField.entries) {
      final restored = _restoreWith(<String, Object?>{entry.key: entry.value});
      expect(
        _storedReference(restored, entry.key),
        isNull,
        reason: '${entry.key} must reject its entire invalid tuple.',
      );
      expect(
        _educationalOnlyFor(restored, entry.key),
        isTrue,
        reason: 'Invalid evidence must preserve educational-only output.',
      );
    }
  });

  test('the four precision predicates remain independent', () {
    for (final knownField in _referenceFields) {
      final restored = _restoreWith(
        <String, Object?>{knownField: _validReferences[knownField]!},
      );

      for (final field in _referenceFields) {
        final expectedKnown = field == knownField;
        expect(
          _precisionContract(_typedReference(restored, field)),
          expectedKnown
              ? <String, Object?>{
                  'type': 'SpecialistReferenceEvidence',
                  'state': 'known',
                  'precisionReady': true,
                  'educationalOnly': false,
                }
              : <String, Object?>{
                  'type': null,
                  'state': 'missing',
                  'precisionReady': false,
                  'educationalOnly': true,
                },
          reason: '$knownField must not qualify $field.',
        );
      }
    }
  });

  test('CoachProfile stays independent from provider document authority', () {
    final source = File('lib/models/coach_profile.dart').readAsStringSync();

    expect(
      source,
      isNot(contains('providers/document_provider.dart')),
      reason: 'The model accepts an opaque BND-05 identity but must not import '
          'ConfirmedDocumentReference from the provider layer.',
    );
  });
}
