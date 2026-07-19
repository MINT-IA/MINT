import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';

import '../support/pillar3a_beneficiary_handoff_fixture.dart';

void main() {
  test('specialist model stays pure and never imports a provider', () {
    final source = File(
      'lib/models/pillar3a_beneficiary_specialist_handoff.dart',
    ).readAsStringSync();
    final consumer = File(
      'lib/models/pillar3a_beneficiary_consumer.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('/providers/')));
    expect(consumer, isNot(contains('/providers/')));
    expect(source, contains('/models/pillar3a_beneficiary_consumer.dart'));
  });

  test('qualified consumer and specialist factories have one production caller',
      () {
    List<String> callers(String symbol) => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains(symbol))
        .map((file) => file.path)
        .toList()
      ..sort();

    expect(
      callers('fromQualifiedEvidenceRoot('),
      <String>[
        'lib/models/pillar3a_beneficiary_consumer.dart',
        'lib/providers/document_provider.dart',
      ],
    );
    expect(
      callers('tryFromConsumerResolution('),
      <String>[
        'lib/models/pillar3a_beneficiary_specialist_handoff.dart',
        'lib/providers/document_provider.dart',
      ],
    );
  });

  test('handoff is a closed metadata-only projection of known authority', () {
    final handoff = pillar3aBeneficiaryHandoffFixture();
    expect(handoff.entries, hasLength(1));
    expect(
      () => handoff.entries.add(handoff.entries.single),
      throwsUnsupportedError,
    );
    final entry = handoff.entries.single;
    expect(
      entry.documentKind,
      Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
    );
    expect(entry.sourceDate, DateTime.utc(2026, 7, 18));
    expect(entry.legalYear, 2026);
    expect(entry.temporalBasis, isA<Pillar3aBeneficiaryExactDates>());
    expect(entry.relationConfirmedAt, DateTime.utc(2026, 7, 19, 10));

    final encoded = jsonEncode(handoff.toLocalJson()).toLowerCase();
    for (final forbidden in const <String>[
      'referenceid',
      'contractreferenceid',
      'documentauthorityid',
      'ownerkind',
      'beneficiaryname',
      'beneficiaryclass',
      'beneficiaryorder',
      'beneficiaryrank',
      'beneficiaryshare',
      'raw',
      'path',
      'hash',
      'iban',
      'avsnumber',
      'certificate',
    ]) {
      expect(encoded, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('attested temporal regime remains attested and is never date-inferred',
      () {
    final entry =
        pillar3aBeneficiaryHandoffFixture(attestedRegime: true).entries.single;
    final basis = entry.temporalBasis as Pillar3aBeneficiaryAttestedRegime;
    expect(basis.regime, Pillar3aBeneficiaryRegime.post20270601);
    expect(
      entry.toLocalJson()['temporalBasis'],
      <String, Object?>{
        'kind': 'attestedRegime',
        'regime': 'post20270601',
      },
    );
  });
}
