import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

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
  String ownerKind = 'self',
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
      legalYear: 2025,
      confirmedAt: '2026-07-01T00:00:00.000Z',
    ),
    'taxYear': 2025,
    'jurisdiction': 'GE',
    'subject': 'individual',
  },
};

TaxSnapshot _taxSnapshot({
  String snapshotId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  int taxYear = 2025,
  String cantonCode = 'GE',
  TaxSubjectScope subjectScope = TaxSubjectScope.individual,
}) =>
    TaxSnapshot(
      snapshotId: snapshotId,
      profileOwnerId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      taxYear: taxYear,
      basedOnTaxYear: null,
      sourceDate: DateTime.utc(2026, 6, 30),
      documentKind: TaxDocumentKind.assessmentNotice,
      assessmentStatus: TaxAssessmentStatus.inForce,
      inForceAttested: true,
      subjectScope: subjectScope,
      cantonCode: cantonCode,
      municipalityId: null,
      municipalityLabel: null,
      cantonalCommunalTaxableIncomeChf: null,
      federalTaxableIncomeChf: null,
      cantonalCommunalTaxableWealthChf: null,
      cantonalCommunalAssessedTax: null,
      federalDirectAssessedTax: null,
      explicitMarginalIncomeTaxRate: null,
      explicitAverageIncomeTaxRate: null,
      updatedAt: DateTime.utc(2026, 7, 1),
    );

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

Map<String, Object?> _precisionContract(
  Object? reference, {
  DateTime? asOf,
  bool taxContextRequired = false,
  TaxSnapshot? taxSnapshot,
  List<SpecialistReferenceEvidence> conflictingReferences = const [],
}) {
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
  final effectiveAsOf = asOf ?? _asOf;
  final usesContext = taxContextRequired || conflictingReferences.isNotEmpty;
  final state = usesContext
      ? _readDynamic(
          () => typed
              .stateAt(
                effectiveAsOf,
                taxSnapshot: taxSnapshot,
                conflictingReferences: conflictingReferences,
              )
              .name,
        )
      : _readDynamic(() => typed.stateAt(effectiveAsOf).name);
  final precisionReady = usesContext
      ? _readDynamic(
          () => typed.precisionReadyAt(
            effectiveAsOf,
            taxSnapshot: taxSnapshot,
            conflictingReferences: conflictingReferences,
          ),
        )
      : _readDynamic(() => typed.precisionReadyAt(effectiveAsOf));
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
      final isTax = field == 'latestTaxDecisionReference';
      expect(
        _precisionContract(
          _typedReference(restored, field),
          taxContextRequired: isTax,
          taxSnapshot: isTax ? _taxSnapshot() : null,
        ),
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

  test('tax reference rejects a legal year different from its tax year', () {
    final mismatched = <String, Object?>{
      ..._validReferences['latestTaxDecisionReference']!,
      'legalYear': 2026,
    };

    expect(
      _storedReference(
        _restoreWith({'latestTaxDecisionReference': mismatched}),
        'latestTaxDecisionReference',
      ),
      isNull,
    );
  });

  test('the four precision predicates remain independent', () {
    for (final knownField in _referenceFields) {
      final restored = _restoreWith(
        <String, Object?>{knownField: _validReferences[knownField]!},
      );

      for (final field in _referenceFields) {
        final expectedKnown = field == knownField;
        final isTax = field == 'latestTaxDecisionReference';
        expect(
          _precisionContract(
            _typedReference(restored, field),
            taxContextRequired: isTax && expectedKnown,
            taxSnapshot: isTax && expectedKnown ? _taxSnapshot() : null,
          ),
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

  test('Swiss civil dates use Zurich civil day and UTC confirmation', () {
    final asOf = DateTime.utc(2025, 12, 31, 23, 30);
    final common = _commonReference(
      referenceId: '12121212-1212-4212-8212-121212121212',
      kind: 'lppRegulation',
      sourceDate: '2026-01-01',
      legalYear: 2026,
      confirmedAt: '2025-12-31T23:00:00.000Z',
    );
    final cases = <(String, Map<String, Object?>)>[
      ('lppRegulationReference', common),
      (
        'lppCapitalNoticeDeadline',
        <String, Object?>{
          ...common,
          'referenceId': '13131313-1313-4313-8313-131313131313',
          'kind': 'lppCapitalNotice',
          'deadlineDate': '2026-01-01',
        },
      ),
    ];
    for (final (field, payload) in cases) {
      final evidence = _typedReference(_restoreWith({field: payload}), field);
      expect(
        _precisionContract(evidence, asOf: asOf),
        allOf(
          containsPair('state', 'known'),
          containsPair('precisionReady', true),
        ),
      );
    }

    final future = <String, Object?>{
      ...common,
      'confirmedAt': '2026-01-01T00:00:00.000Z',
    };
    expect(
      _precisionContract(
        _typedReference(
          _restoreWith({'lppRegulationReference': future}),
          'lppRegulationReference',
        ),
        asOf: asOf,
      ),
      allOf(
        containsPair('state', 'invalid'),
        containsPair('precisionReady', false),
      ),
    );
  });

  test('manualPartner hydrates with the exact BND-05 wire name', () {
    final profile = _restoreWith({
      'lppRegulationReference': _commonReference(
        referenceId: '15151515-1515-4515-8515-151515151515',
        kind: 'lppRegulation',
        ownerKind: LppEvidenceOwnerKind.manualPartner.wireName,
      ),
    });
    final stored = _storedReference(profile, 'lppRegulationReference');
    expect(stored, isNotNull);
    expect(stored!['ownerKind'], 'manualPartner');
    expect(
      _precisionContract(_typedReference(profile, 'lppRegulationReference')),
      containsPair('state', 'known'),
    );
  });

  test('confirmedAt accepts only canonical toIso8601String output', () {
    CoachProfile restored(String id, String confirmedAt) => _restoreWith({
          'lppRegulationReference': _commonReference(
            referenceId: id,
            kind: 'lppRegulation',
            confirmedAt: confirmedAt,
          ),
        });
    expect(
      _storedReference(
        restored(
          '16161616-1616-4616-8616-161616161616',
          '2026-01-16T10:00:00Z',
        ),
        'lppRegulationReference',
      ),
      isNull,
    );
    expect(
      _storedReference(
        restored(
          '17171717-1717-4717-8717-171717171717',
          DateTime.utc(2026, 1, 16, 10).toIso8601String(),
        ),
        'lppRegulationReference',
      ),
      isNotNull,
    );
  });

  test('raw OCR and local path reject a complete payload', () {
    for (final forbidden in const ['ocrText', 'path']) {
      final restored = _restoreWith({
        'lppRegulationReference': <String, Object?>{
          ..._validReferences['lppRegulationReference']!,
          forbidden: '/private/certificate-content',
        },
      });
      expect(_storedReference(restored, 'lppRegulationReference'), isNull);
    }
  });

  test('tax subject is closed on TaxSubjectScope wire names', () {
    CoachProfile restored(String subject) => _restoreWith({
          'latestTaxDecisionReference': <String, Object?>{
            ..._validReferences['latestTaxDecisionReference']!,
            'subject': subject,
          },
        });
    expect(
      _storedReference(
          restored('incomeAndWealth'), 'latestTaxDecisionReference'),
      isNull,
    );
    expect(
      _storedReference(
        restored(TaxSubjectScope.individual.name),
        'latestTaxDecisionReference',
      ),
      containsPair('subject', 'individual'),
    );
  });

  test('tax precision requires one coherent contextual TaxSnapshot', () {
    final reference = _typedReference(
      _restoreWith({
        'latestTaxDecisionReference':
            _validReferences['latestTaxDecisionReference']!,
      }),
      'latestTaxDecisionReference',
    );
    final cases = <(TaxSnapshot?, String, bool)>[
      (null, 'missing', false),
      (_taxSnapshot(), 'known', true),
      (_taxSnapshot(taxYear: 2024), 'conflict', false),
      (_taxSnapshot(cantonCode: 'VD'), 'conflict', false),
      (
        _taxSnapshot(
          snapshotId: '99999999-9999-4999-8999-999999999999',
        ),
        'conflict',
        false,
      ),
      (
        _taxSnapshot(
          subjectScope: TaxSubjectScope.jointlyAssessedCouple,
        ),
        'conflict',
        false,
      ),
    ];
    for (final (snapshot, state, ready) in cases) {
      expect(
        _precisionContract(
          reference,
          taxContextRequired: true,
          taxSnapshot: snapshot,
        ),
        allOf(
          containsPair('state', state),
          containsPair('precisionReady', ready),
        ),
      );
    }
  });

  test('divergent equal-rank peers conflict without UUID tie-break', () {
    SpecialistReferenceEvidence evidence(Map<String, Object?> payload) =>
        _typedReference(
          _restoreWith({'lppRegulationReference': payload}),
          'lppRegulationReference',
        ) as SpecialistReferenceEvidence;
    final first = evidence(_validReferences['lppRegulationReference']!);
    final second = evidence(_commonReference(
      referenceId: '18181818-1818-4818-8818-181818181818',
      kind: 'lppRegulation',
    ));
    expect(
      _precisionContract(
        first,
        conflictingReferences: [second],
      ),
      allOf(
        containsPair('state', 'conflict'),
        containsPair('precisionReady', false),
      ),
    );
  });

  test('copyWith, equality, hash, clear-null, and round-trip agree', () {
    final original = _restoreWith({
      'lppRegulationReference': _validReferences['lppRegulationReference']!,
    });
    final preserved = original.copyWith();
    final roundTrip = CoachProfile.fromJson(original.toJson());
    final cleared = original.copyWith(lppRegulationReference: null);
    final replacement = _typedReference(
      _restoreWith({
        'lppRegulationReference': _commonReference(
          referenceId: '19191919-1919-4919-8919-191919191919',
          kind: 'lppRegulation',
        ),
      }),
      'lppRegulationReference',
    ) as SpecialistReferenceEvidence;
    final changed = original.copyWith(lppRegulationReference: replacement);

    expect(preserved, original);
    expect(preserved.hashCode, original.hashCode);
    expect(roundTrip.lppRegulationReference, original.lppRegulationReference);
    expect(roundTrip.lppRegulationReference.hashCode,
        original.lppRegulationReference.hashCode);
    expect(cleared.lppRegulationReference, isNull);
    expect(changed, isNot(original));
  });

  test('calendar-year change alone does not stale durable references', () {
    final profile = _restoreWith(_validReferences);
    final nextYear = DateTime.utc(2027, 7, 17, 12);
    for (final field in const <String>[
      'lppRegulationReference',
      'pillar3aBeneficiaryClause',
      'latestTaxDecisionReference',
    ]) {
      final isTax = field == 'latestTaxDecisionReference';
      expect(
        _precisionContract(
          _typedReference(profile, field),
          asOf: nextYear,
          taxContextRequired: isTax,
          taxSnapshot: isTax ? _taxSnapshot() : null,
        ),
        allOf(
          containsPair('state', 'known'),
          containsPair('precisionReady', true),
        ),
        reason: field,
      );
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
