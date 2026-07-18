import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _modelPath = 'lib/models/pillar3a_beneficiary_evidence.dart';

const _generatedContract = r'''
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';

const _refA = '11111111-1111-4111-8111-111111111111';
const _refB = '22222222-2222-4222-8222-222222222222';
const _defaultTemporal = Object();
final _asOf = DateTime.utc(2027, 7, 2, 12);

Map<String, Object?> _exactDates({
  String? designationEffectiveDate = '2027-05-31',
  String? lastAssignmentModificationDate,
}) =>
    <String, Object?>{
      'kind': 'exactDates',
      if (designationEffectiveDate != null)
        'designationEffectiveDate': designationEffectiveDate,
      if (lastAssignmentModificationDate != null)
        'lastAssignmentModificationDate': lastAssignmentModificationDate,
    };

Map<String, Object?> _attestedRegime(
  String regime, {
  String? designationEffectiveDate,
  String? lastAssignmentModificationDate,
}) =>
    <String, Object?>{
      'kind': 'attestedRegime',
      'regime': regime,
      if (designationEffectiveDate != null)
        'designationEffectiveDate': designationEffectiveDate,
      if (lastAssignmentModificationDate != null)
        'lastAssignmentModificationDate': lastAssignmentModificationDate,
    };

Map<String, Object?> _contract({
  String relation = 'currentActiveUnpaid',
  String ref = _refA,
  String sourceDate = '2027-05-31',
  int legalYear = 2027,
  String confirmedAt = '2027-06-01T10:00:00.000Z',
  Object? temporalBasis = _defaultTemporal,
}) =>
    <String, Object?>{
      'kind': 'pillar3aBeneficiaryClause',
      'owner': 'self',
      'source': 'certificate',
      'contract': relation,
      'ref': ref,
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
  List<Map<String, Object?>> contracts, {
  int schemaVersion = 1,
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'contracts': contracts,
      ...extra,
    });

dynamic _parse(
  List<Map<String, Object?>> contracts, {
  int schemaVersion = 1,
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
      _rootJson(contracts, schemaVersion: schemaVersion, extra: extra),
      now: () => _asOf,
    );

Map<String, dynamic> _roundTripJson(dynamic root) =>
    Map<String, dynamic>.from(jsonDecode(root.toJsonString()) as Map);

void main() {
  test('schema 1 round-trips exact keys in canonical ref order', () {
    final root = _parse(<Map<String, Object?>>[
      _contract(ref: _refB, relation: 'uncertain'),
      _contract(ref: _refA),
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
    expect(contracts.map((contract) => contract['ref']), <String>[_refA, _refB]);
    for (final contract in contracts) {
      expect(contract.keys.toSet(), <String>{
        'kind',
        'owner',
        'source',
        'contract',
        'ref',
        'sourceDate',
        'legalYear',
        'confirmedAt',
        'temporalBasis',
      });
    }

    final reparsed = Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
      root.toJsonString(),
      now: () => _asOf,
    );
    expect(reparsed, root);
    expect(reparsed.hashCode, root.hashCode);
    final firstContracts = List<dynamic>.from(root.contracts as Iterable);
    final secondContracts = List<dynamic>.from(reparsed.contracts as Iterable);
    expect(firstContracts.first, secondContracts.first);
    expect(firstContracts.first.hashCode, secondContracts.first.hashCode);

    expect(
      Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
        jsonEncode(<String, Object?>{'contracts': <Object?>[_contract()]}),
        now: () => _asOf,
      ),
      isNull,
    );
    expect(
      Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
        jsonEncode(<String, Object?>{'schemaVersion': 1}),
        now: () => _asOf,
      ),
      isNull,
    );
    expect(
      _parse(<Map<String, Object?>>[_contract()], schemaVersion: 2),
      isNull,
    );
  });

  test('root cardinality and canonical Mint refs fail closed', () {
    expect(_parse(const <Map<String, Object?>>[]), isNull);
    expect(
      _parse(List<Map<String, Object?>>.generate(
        32,
        (index) => _contract(
          ref: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
      )),
      isNotNull,
    );
    expect(
      _parse(List<Map<String, Object?>>.generate(
        33,
        (index) => _contract(
          ref: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
        ),
      )),
      isNull,
    );
    expect(_parse(<Map<String, Object?>>[
      _contract(ref: _refA),
      _contract(ref: _refA, relation: 'uncertain'),
    ]), isNull);
    for (final ref in const <String>[
      '',
      'not-a-uuid',
      '11111111-1111-3111-8111-111111111111',
      '11111111-1111-4111-7111-111111111111',
      '11111111-1111-4111-8111-11111111111A',
    ]) {
      expect(_parse(<Map<String, Object?>>[_contract(ref: ref)]), isNull,
          reason: ref);
    }
    expect(_parse(<Map<String, Object?>>[_contract()]), isNotNull);
  });

  test('record vocabulary and exact required keys fail closed', () {
    for (final required in const <String>[
      'kind',
      'owner',
      'source',
      'contract',
      'ref',
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
      <String, Object?>{..._contract(), 'owner': 'partner'},
      <String, Object?>{..._contract(), 'source': 'userInput'},
    ]) {
      expect(
        _parse(<Map<String, Object?>>[invalid]),
        isNull,
        reason: jsonEncode(invalid),
      );
    }
  });

  test('relation and temporal union are closed and never mixed', () {
    for (final relation in const <String>[
      'currentActiveUnpaid',
      'uncertain',
    ]) {
      expect(_parse(<Map<String, Object?>>[
        _contract(relation: relation, temporalBasis: _exactDates()),
      ]), isNotNull, reason: relation);
      expect(_parse(<Map<String, Object?>>[
        _contract(
          relation: relation,
          temporalBasis: _exactDates(
            designationEffectiveDate: null,
            lastAssignmentModificationDate: '2027-06-01',
          ),
        ),
      ]), isNotNull, reason: relation);
      expect(_parse(<Map<String, Object?>>[
        _contract(
          relation: relation,
          temporalBasis: _attestedRegime('pre20270601'),
        ),
      ]), isNotNull, reason: relation);
      expect(_parse(<Map<String, Object?>>[
        _contract(
          relation: relation,
          temporalBasis: _attestedRegime('post20270601'),
        ),
      ]), isNotNull, reason: relation);
      expect(_parse(<Map<String, Object?>>[
        _contract(relation: relation, temporalBasis: null),
      ]), isNull, reason: relation);
    }

    expect(_parse(<Map<String, Object?>>[
      _contract(relation: 'paidOrClosed', temporalBasis: null),
    ]), isNotNull);
    expect(_parse(<Map<String, Object?>>[
      _contract(
        relation: 'paidOrClosed',
        temporalBasis: _exactDates(),
      ),
    ]), isNull);
    expect(_parse(<Map<String, Object?>>[
      _contract(relation: 'unknownRelation'),
    ]), isNull);

    expect(_parse(<Map<String, Object?>>[
      _contract(
        legalYear: 2027,
        temporalBasis: _exactDates(
          designationEffectiveDate: null,
          lastAssignmentModificationDate: null,
        ),
      ),
    ]), isNull);
    expect(_parse(<Map<String, Object?>>[
      _contract(
        legalYear: 2027,
        temporalBasis: <String, Object?>{'kind': 'attestedRegime'},
      ),
    ]), isNull);
    expect(_parse(<Map<String, Object?>>[
      _contract(
        temporalBasis: <String, Object?>{
          ..._exactDates(),
          'regime': 'pre20270601',
        },
      ),
    ]), isNull);
    expect(_parse(<Map<String, Object?>>[
      _contract(
        temporalBasis: _attestedRegime(
          'post20270601',
          designationEffectiveDate: '2027-06-01',
        ),
      ),
    ]), isNull);
  });

  test('all civil and confirmation dates are canonical and non-future', () {
    for (final invalid in <Map<String, Object?>>[
      _contract(sourceDate: '2027-6-01'),
      _contract(sourceDate: '2027-07-03'),
      _contract(confirmedAt: '2027-06-01T10:00:00Z'),
      _contract(confirmedAt: '2027-07-03T00:00:00.000Z'),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: '2027-6-01'),
      ),
      _contract(
        temporalBasis: _exactDates(designationEffectiveDate: '2027-07-03'),
      ),
      _contract(
        temporalBasis: _exactDates(
          designationEffectiveDate: null,
          lastAssignmentModificationDate: '2027-07-03',
        ),
      ),
    ]) {
      expect(_parse(<Map<String, Object?>>[invalid]), isNull,
          reason: jsonEncode(invalid));
    }
  });

  test('unknown, provider, beneficiary, and document keys reject the root', () {
    expect(
      _parse(<Map<String, Object?>>[_contract()], extra: <String, Object?>{
        'private': true,
      }),
      isNull,
    );
    for (final forbidden in const <String>[
      'providerName',
      'providerId',
      'accountNumber',
      'beneficiaryName',
      'beneficiaryRelationship',
      'beneficiaryShare',
      'documentId',
      'filename',
      'path',
      'ocrText',
      'clauseText',
      'raw',
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
    expect(_parse(<Map<String, Object?>>[
      _contract(temporalBasis: <String, Object?>{
        ..._exactDates(),
        'unknown': true,
      }),
    ]), isNull);
  });

  test('multiple contracts stay ref-scoped without provider identity', () {
    final root = _parse(<Map<String, Object?>>[
      _contract(ref: _refA),
      _contract(ref: _refB, relation: 'uncertain'),
    ]);
    expect(root, isNotNull);
    final encoded = root.toJsonString() as String;
    expect(encoded, isNot(contains('provider')));
    expect(encoded, isNot(contains('account')));
    expect(encoded, contains(_refA));
    expect(encoded, contains(_refB));
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
