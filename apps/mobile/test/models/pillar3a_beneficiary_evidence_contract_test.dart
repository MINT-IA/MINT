import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _modelPath = 'lib/models/pillar3a_beneficiary_evidence.dart';

const _generatedContract = r'''
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';

const _contractA = '11111111-1111-4111-8111-111111111111';
const _contractB = '22222222-2222-4222-8222-222222222222';
const _referenceA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _referenceB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _defaultTemporal = Object();
final _asOf = DateTime.utc(2027, 7, 2, 12);

Map<String, Object?> _exactDates({
  Object? designationEffectiveDate = '2027-05-31',
  Object? lastAssignmentModificationDate,
}) =>
    <String, Object?>{
      'kind': 'exactDates',
      'designationEffectiveDate': designationEffectiveDate,
      'lastAssignmentModificationDate': lastAssignmentModificationDate,
    };

Map<String, Object?> _attestedRegime(Object? regime) => <String, Object?>{
      'kind': 'attestedRegime',
      'regime': regime,
    };

Map<String, Object?> _contract({
  String contractReferenceId = _contractA,
  String relation = 'currentActiveUnpaid',
  String referenceId = _referenceA,
  Object? sourceDate = '2027-05-31',
  Object? legalYear = 2027,
  Object? confirmedAt = '2027-06-01T10:00:00.000Z',
  Object? temporalBasis = _defaultTemporal,
}) =>
    <String, Object?>{
      'kind': 'pillar3aBeneficiaryClause',
      'ownerKind': 'self',
      'source': 'certificate',
      'contractReferenceId': contractReferenceId,
      'relation': relation,
      'referenceId': referenceId,
      'sourceDate': sourceDate,
      'legalYear': legalYear,
      'confirmedAt': confirmedAt,
      'temporalBasis': identical(temporalBasis, _defaultTemporal)
          ? relation == 'paidOrClosed'
              ? null
              : _exactDates()
          : temporalBasis,
    };

String _rootJson(
  Object? contracts, {
  Object? schemaVersion = 1,
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'contracts': contracts,
      ...extra,
    });

dynamic _fromJsonString(String encoded) =>
    Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
      encoded,
      now: () => _asOf,
    );

dynamic _parse(
  Object? contracts, {
  Object? schemaVersion = 1,
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    _fromJsonString(
      _rootJson(contracts, schemaVersion: schemaVersion, extra: extra),
    );

Map<String, dynamic> _roundTripJson(dynamic root) =>
    Map<String, dynamic>.from(jsonDecode(root.toJsonString()) as Map);

void main() {
  test('schema 1 round-trips exact wire keys in contract id order', () {
    final root = _parse(<Map<String, Object?>>[
      _contract(
        contractReferenceId: _contractB,
        relation: 'uncertain',
        referenceId: _referenceB,
        sourceDate: '2027-06-01',
        temporalBasis: _attestedRegime('post20270601'),
      ),
      _contract(),
    ]);
    expect(root, isNotNull);

    final json = _roundTripJson(root);
    expect(json.keys.toSet(), <String>{'schemaVersion', 'contracts'});
    expect(json['schemaVersion'], 1);
    final contracts = List<Map<String, dynamic>>.from(
      (json['contracts'] as List).map(
        (raw) => Map<String, dynamic>.from(raw as Map),
      ),
    );
    expect(
      contracts.map((contract) => contract['contractReferenceId']),
      <String>[_contractA, _contractB],
    );
    expect(
      contracts.map((contract) => contract['referenceId']),
      <String>[_referenceA, _referenceB],
    );
    for (final contract in contracts) {
      expect(contract.keys.toSet(), <String>{
        'kind',
        'ownerKind',
        'source',
        'contractReferenceId',
        'relation',
        'referenceId',
        'sourceDate',
        'legalYear',
        'confirmedAt',
        'temporalBasis',
      });
    }
    expect(
      contracts.first['temporalBasis'],
      <String, Object?>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2027-05-31',
        'lastAssignmentModificationDate': null,
      },
    );
    expect(
      contracts.last['temporalBasis'],
      <String, Object?>{
        'kind': 'attestedRegime',
        'regime': 'post20270601',
      },
    );

    final reparsed = _fromJsonString(root.toJsonString() as String);
    expect(reparsed, root);
    expect(reparsed.hashCode, root.hashCode);
    final firstContracts = List<dynamic>.from(root.contracts as Iterable);
    final secondContracts = List<dynamic>.from(reparsed.contracts as Iterable);
    expect(firstContracts.first, secondContracts.first);
    expect(firstContracts.first.hashCode, secondContracts.first.hashCode);

    expect(
      _fromJsonString(
        jsonEncode(<String, Object?>{
          'contracts': <Object?>[_contract()],
        }),
      ),
      isNull,
    );
    expect(
      _fromJsonString(jsonEncode(<String, Object?>{'schemaVersion': 1})),
      isNull,
    );
    expect(
      _parse(<Map<String, Object?>>[_contract()], schemaVersion: 2),
      isNull,
    );
  });

  test('malformed JSON and wrong root shapes fail closed', () {
    for (final malformed in const <String>[
      '',
      '{',
      '{"schemaVersion":1,',
      '[1, 2',
    ]) {
      expect(_fromJsonString(malformed), isNull, reason: malformed);
    }
    for (final wrongRoot in <Object?>[
      null,
      true,
      1,
      1.0,
      'root',
      <Object?>[],
    ]) {
      expect(
        _fromJsonString(jsonEncode(wrongRoot)),
        isNull,
        reason: '$wrongRoot',
      );
    }
    for (final wrongSchema in <Object?>[null, true, 1.0, '1']) {
      expect(
        _parse(<Map<String, Object?>>[_contract()], schemaVersion: wrongSchema),
        isNull,
        reason: '$wrongSchema',
      );
    }
    for (final wrongContracts in <Object?>[
      null,
      true,
      1,
      'contracts',
      <String, Object?>{},
      <Object?>[null],
      <Object?>['contract'],
      <Object?>[<Object?>[]],
    ]) {
      expect(_parse(wrongContracts), isNull, reason: '$wrongContracts');
    }
  });

  test('cardinality and both canonical UUID identities fail closed', () {
    expect(_parse(const <Map<String, Object?>>[]), isNull);
    expect(
      _parse(List<Map<String, Object?>>.generate(
        32,
        (index) => _contract(
          contractReferenceId:
              '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          referenceId:
              '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
      )),
      isNotNull,
    );
    expect(
      _parse(List<Map<String, Object?>>.generate(
        33,
        (index) => _contract(
          contractReferenceId:
              '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          referenceId:
              '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
      )),
      isNull,
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(),
        _contract(
          contractReferenceId: _contractA,
          referenceId: _referenceB,
        ),
      ]),
      isNull,
      reason: 'contractReferenceId must be unique',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(),
        _contract(
          contractReferenceId: _contractB,
          referenceId: _referenceA,
        ),
      ]),
      isNull,
      reason: 'referenceId must be unique',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          contractReferenceId: _contractA,
          referenceId: _contractA,
        ),
      ]),
      isNull,
      reason: 'contract and authority identities must be distinct',
    );

    for (final field in const <String>[
      'contractReferenceId',
      'referenceId',
    ]) {
      for (final invalid in const <String>[
        '',
        'not-a-uuid',
        '11111111-1111-3111-8111-111111111111',
        '11111111-1111-4111-7111-111111111111',
        '11111111-1111-4111-8111-11111111111A',
      ]) {
        final record = <String, Object?>{..._contract()}..[field] = invalid;
        expect(
          _parse(<Map<String, Object?>>[record]),
          isNull,
          reason: '$field=$invalid',
        );
      }
    }
  });

  test('record vocabulary and every exact required key fail closed', () {
    for (final required in const <String>[
      'kind',
      'ownerKind',
      'source',
      'contractReferenceId',
      'relation',
      'referenceId',
      'sourceDate',
      'legalYear',
      'confirmedAt',
      'temporalBasis',
    ]) {
      final missing = <String, Object?>{..._contract()}..remove(required);
      expect(
        _parse(<Map<String, Object?>>[missing]),
        isNull,
        reason: 'missing $required',
      );
    }
    for (final invalid in <Map<String, Object?>>[
      <String, Object?>{..._contract(), 'kind': 'other'},
      <String, Object?>{..._contract(), 'ownerKind': 'partner'},
      <String, Object?>{..._contract(), 'source': 'userInput'},
      <String, Object?>{..._contract(), 'unknown': true},
    ]) {
      expect(
        _parse(<Map<String, Object?>>[invalid]),
        isNull,
        reason: jsonEncode(invalid),
      );
    }
  });

  test('relation and temporal union are exact, closed, and never mixed', () {
    for (final relation in const <String>[
      'currentActiveUnpaid',
      'uncertain',
    ]) {
      expect(
        _parse(<Map<String, Object?>>[
          _contract(relation: relation, temporalBasis: _exactDates()),
        ]),
        isNotNull,
        reason: relation,
      );
      expect(
        _parse(<Map<String, Object?>>[
          _contract(
            relation: relation,
            temporalBasis: _exactDates(
              designationEffectiveDate: null,
              lastAssignmentModificationDate: '2027-05-31',
            ),
          ),
        ]),
        isNotNull,
        reason: relation,
      );
      for (final regime in const <String>[
        'pre20270601',
        'post20270601',
      ]) {
        final isPostCutoff = regime == 'post20270601';
        expect(
          _parse(<Map<String, Object?>>[
            _contract(
              relation: relation,
              sourceDate: isPostCutoff ? '2027-06-01' : '2027-06-15',
              confirmedAt: isPostCutoff
                  ? '2027-06-01T10:00:00.000Z'
                  : '2027-06-15T10:00:00.000Z',
              temporalBasis: _attestedRegime(regime),
            ),
          ]),
          isNotNull,
          reason: isPostCutoff
              ? '$relation/post regime starts on the cutoff'
              : '$relation/pre regime may be attested after the cutoff for an '
                  'older unmodified designation',
        );
      }
      expect(
        _parse(<Map<String, Object?>>[
          _contract(relation: relation, temporalBasis: null),
        ]),
        isNull,
        reason: '$relation requires temporal evidence',
      );
    }

    expect(
      _parse(<Map<String, Object?>>[
        _contract(relation: 'paidOrClosed', temporalBasis: null),
      ]),
      isNotNull,
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          relation: 'paidOrClosed',
          temporalBasis: _exactDates(),
        ),
      ]),
      isNull,
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(relation: 'unknownRelation'),
      ]),
      isNull,
    );

    final missingDesignation = <String, Object?>{
      ..._exactDates(lastAssignmentModificationDate: '2027-06-01'),
    }..remove('designationEffectiveDate');
    final missingModification = <String, Object?>{..._exactDates()}
      ..remove('lastAssignmentModificationDate');
    for (final invalid in <Object?>[
      null,
      true,
      'exactDates',
      <Object?>[],
      _exactDates(
        designationEffectiveDate: null,
        lastAssignmentModificationDate: null,
      ),
      missingDesignation,
      missingModification,
      <String, Object?>{..._exactDates(), 'regime': 'pre20270601'},
      <String, Object?>{..._exactDates(), 'unknown': true},
      <String, Object?>{'kind': 'attestedRegime'},
      _attestedRegime(null),
      _attestedRegime('unknownRegime'),
      <String, Object?>{
        ..._attestedRegime('pre20270601'),
        'designationEffectiveDate': '2027-05-31',
      },
      <String, Object?>{
        ..._attestedRegime('post20270601'),
        'lastAssignmentModificationDate': null,
      },
      <String, Object?>{
        ..._attestedRegime('pre20270601'),
        'unknown': true,
      },
    ]) {
      expect(
        _parse(<Map<String, Object?>>[_contract(temporalBasis: invalid)]),
        isNull,
        reason: jsonEncode(invalid),
      );
    }
  });

  test('legalYear is an integer in the inclusive 1900..9999 range', () {
    for (final legalYear in const <int>[1900, 2027, 9999]) {
      expect(
        _parse(<Map<String, Object?>>[_contract(legalYear: legalYear)]),
        isNotNull,
        reason: '$legalYear',
      );
    }
    for (final legalYear in <Object?>[
      null,
      true,
      '2027',
      2027.0,
      1899,
      10000,
      -1,
    ]) {
      expect(
        _parse(<Map<String, Object?>>[_contract(legalYear: legalYear)]),
        isNull,
        reason: '$legalYear',
      );
    }
  });

  test('civil dates and confirmation UTC are canonical and non-future', () {
    for (final invalid in <Map<String, Object?>>[
      _contract(sourceDate: null),
      _contract(sourceDate: 20270531),
      _contract(sourceDate: '2027-6-01'),
      _contract(sourceDate: '2027-02-29'),
      _contract(sourceDate: '2027-04-31'),
      _contract(sourceDate: '2027-07-03'),
      _contract(sourceDate: '2027-05-31T00:00:00.000Z'),
      _contract(confirmedAt: null),
      _contract(confirmedAt: 20270601),
      _contract(confirmedAt: '2027-06-01T10:00:00Z'),
      _contract(confirmedAt: '2027-06-01T10:00:00.001Z'),
      _contract(confirmedAt: '2027-06-01T10:00:00.000z'),
      _contract(confirmedAt: '2027-06-01T10:00:00.000+00:00'),
      _contract(confirmedAt: '2027-06-01T12:00:00.000+02:00'),
      _contract(confirmedAt: '2027-07-03T00:00:00.000Z'),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: 20270531),
      ),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: '2027-6-01'),
      ),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: '2027-02-29'),
      ),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: '2027-07-03'),
      ),
      _contract(
        temporalBasis: _exactDates(
          designationEffectiveDate: null,
          lastAssignmentModificationDate: '2027-04-31',
        ),
      ),
      _contract(
        temporalBasis: _exactDates(
          designationEffectiveDate: null,
          lastAssignmentModificationDate: '2027-07-03',
        ),
      ),
    ]) {
      expect(
        _parse(<Map<String, Object?>>[invalid]),
        isNull,
        reason: jsonEncode(invalid),
      );
    }
  });

  test('evidence chronology uses Zurich civil day and the regime cutoff', () {
    expect(
      _parse(<Map<String, Object?>>[
        _contract(confirmedAt: '2027-05-30T22:00:00.000Z'),
      ]),
      isNotNull,
      reason: '22:00Z is 00:00 on 31 May in Zurich and matches sourceDate.',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(confirmedAt: '2027-05-30T21:59:59.000Z'),
      ]),
      isNull,
      reason: 'The confirmation is still 30 May in Zurich.',
    );

    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          sourceDate: '2027-06-01',
          temporalBasis: _exactDates(
            designationEffectiveDate: '2027-05-31',
            lastAssignmentModificationDate: '2027-06-01',
          ),
        ),
      ]),
      isNotNull,
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          temporalBasis: _exactDates(
            designationEffectiveDate: '2027-06-01',
          ),
        ),
      ]),
      isNull,
      reason: 'Designation effective date cannot follow the evidence date.',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          temporalBasis: _exactDates(
            designationEffectiveDate: null,
            lastAssignmentModificationDate: '2027-06-01',
          ),
        ),
      ]),
      isNull,
      reason: 'Last assignment modification cannot follow the evidence date.',
    );

    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          sourceDate: '2027-06-01',
          confirmedAt: '2027-05-31T22:00:00.000Z',
          temporalBasis: _attestedRegime('post20270601'),
        ),
      ]),
      isNotNull,
      reason: 'The post-cutoff attestation starts on 1 June Zurich civil day.',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          sourceDate: '2027-05-31',
          confirmedAt: '2027-06-01T10:00:00.000Z',
          temporalBasis: _attestedRegime('post20270601'),
        ),
      ]),
      isNull,
      reason: 'A pre-cutoff source cannot attest the post-cutoff regime.',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          sourceDate: '2027-06-01',
          confirmedAt: '2027-05-31T21:59:59.000Z',
          temporalBasis: _attestedRegime('post20270601'),
        ),
      ]),
      isNull,
      reason: 'Post-cutoff confirmation cannot precede its Zurich source day.',
    );
    expect(
      _parse(<Map<String, Object?>>[
        _contract(
          sourceDate: '2027-06-15',
          confirmedAt: '2027-06-15T10:00:00.000Z',
          temporalBasis: _attestedRegime('pre20270601'),
        ),
      ]),
      isNotNull,
      reason: 'A later attestation may confirm an older unmodified assignment.',
    );
  });

  test('unknown and privacy-sensitive keys reject the whole root', () {
    for (final rootKey in const <String>['unknown', 'private']) {
      expect(
        _parse(
          <Map<String, Object?>>[_contract()],
          extra: <String, Object?>{rootKey: true},
        ),
        isNull,
        reason: rootKey,
      );
    }
    for (final forbidden in const <String>[
      'iban',
      'sha256',
      'hash',
      'base64',
      'bytes',
      'documentBytes',
      'beneficiaryId',
      'beneficiaryName',
      'beneficiaryRelationship',
      'beneficiaryCount',
      'beneficiaryOrder',
      'beneficiaryRank',
      'beneficiaryShare',
      'relationship',
      'count',
      'order',
      'rank',
      'share',
      'avsNumber',
      'amount',
      'amountChf',
      'value',
      'designationText',
      'clauseText',
      'provider',
      'providerId',
      'providerName',
      'providerReference',
      'account',
      'accountId',
      'accountNumber',
      'document',
      'documentId',
      'documentHash',
      'file',
      'fileName',
      'filename',
      'filePath',
      'path',
      'ocr',
      'OCRText',
      'ocrText',
      'raw',
      'rawText',
      'signature',
      'login',
      'unknown',
    ]) {
      expect(
        _parse(<Map<String, Object?>>[
          <String, Object?>{..._contract(), forbidden: 'private-value'},
        ]),
        isNull,
        reason: forbidden,
      );
    }
    for (final temporal in <Map<String, Object?>>[
      <String, Object?>{..._exactDates(), 'unknown': true},
      <String, Object?>{
        ..._attestedRegime('pre20270601'),
        'unknown': true,
      },
    ]) {
      expect(
        _parse(<Map<String, Object?>>[_contract(temporalBasis: temporal)]),
        isNull,
        reason: jsonEncode(temporal),
      );
    }
  });

  test('multiple contracts stay identity-scoped without provider grouping', () {
    final root = _parse(<Map<String, Object?>>[
      _contract(),
      _contract(
        contractReferenceId: _contractB,
        relation: 'uncertain',
        referenceId: _referenceB,
      ),
    ]);
    expect(root, isNotNull);
    final encoded = root.toJsonString() as String;
    expect(encoded, isNot(contains('provider')));
    expect(encoded, isNot(contains('account')));
    expect(encoded, contains(_contractA));
    expect(encoded, contains(_contractB));
    expect(encoded, contains(_referenceA));
    expect(encoded, contains(_referenceB));
  });
}
''';

Future<ProcessResult> _runGeneratedContract() async {
  final directory = await Directory.systemTemp.createTemp(
    'mint-pillar3a-beneficiary-contract-',
  );
  final generated = File(
    '${directory.path}/pillar3a_beneficiary_generated_test.dart',
  );
  try {
    await generated.writeAsString(_generatedContract, flush: true);
    return await Process.run(
      'flutter',
      <String>['test', generated.path, '--reporter', 'expanded'],
      workingDirectory: Directory.current.path,
    );
  } finally {
    await directory.delete(recursive: true);
  }
}

void main() {
  test('dedicated production model declares the closed authority vocabulary',
      () {
    final file = File(_modelPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Missing future production model $_modelPath',
    );
    final source = file.readAsStringSync();
    for (final anchor in const <String>[
      'final class Pillar3aBeneficiaryEvidenceRoot',
      '_coach_pillar3a_beneficiary_evidence_v1',
      'pillar3aBeneficiaryClause',
      'ownerKind',
      'contractReferenceId',
      'relation',
      'referenceId',
      'currentActiveUnpaid',
      'uncertain',
      'paidOrClosed',
      'exactDates',
      'attestedRegime',
      'pre20270601',
      'post20270601',
      'designationEffectiveDate',
      'lastAssignmentModificationDate',
      'schemaVersion',
      'fromJsonString',
      'toJsonString',
      'operator ==',
      'hashCode',
    ]) {
      expect(source, contains(anchor), reason: anchor);
    }
  });

  test(
    'production parser enforces the multi-contract temporal evidence contract',
    () async {
      final result = await _runGeneratedContract();
      expect(
        result.exitCode,
        0,
        reason: 'Future pillar3a beneficiary API contract is not GREEN.\n'
            'stdout:\n${result.stdout}\n'
            'stderr:\n${result.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
