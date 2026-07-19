import 'package:mint_mobile/models/pillar3a_beneficiary_consumer.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_specialist_handoff.dart';

final class _Metadata implements Pillar3aBeneficiaryRenderableDocumentMetadata {
  _Metadata({
    required this.temporalBasis,
    required this.sourceDate,
    required this.legalYear,
    required this.relationConfirmedAt,
  });

  @override
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;

  @override
  Pillar3aBeneficiaryAuthorityDocumentKind get documentKind =>
      Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle;

  @override
  final int legalYear;

  @override
  Pillar3aBeneficiaryRelation get relation =>
      Pillar3aBeneficiaryRelation.currentActiveUnpaid;

  @override
  final DateTime relationConfirmedAt;

  @override
  final DateTime sourceDate;
}

final class _Entry implements Pillar3aBeneficiaryConsumerEntry {
  _Entry(this.metadata);

  final Pillar3aBeneficiaryRenderableDocumentMetadata metadata;

  @override
  bool get hasRenderablePreciseDocumentMetadata => true;

  @override
  Pillar3aBeneficiaryRenderableDocumentMetadata?
      get renderablePreciseDocumentMetadata => metadata;

  @override
  String get scanContractReferenceId => '11111111-1111-4111-8111-111111111111';

  @override
  String get scanExpectedPreviousReferenceId =>
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  @override
  Pillar3aBeneficiaryConsumerState get state =>
      Pillar3aBeneficiaryConsumerState.knownCurrentDeclared;
}

final class _Resolution implements Pillar3aBeneficiaryConsumerResolution {
  _Resolution(this.entries);

  @override
  final List<Pillar3aBeneficiaryConsumerEntry> entries;

  @override
  Pillar3aBeneficiaryConsumerState get state =>
      Pillar3aBeneficiaryConsumerState.knownCurrentDeclared;
}

Pillar3aBeneficiarySpecialistHandoff pillar3aBeneficiaryHandoffFixture({
  bool attestedRegime = false,
}) {
  final sourceDate = attestedRegime ? '2027-07-18' : '2026-07-18';
  final relationConfirmedAt =
      attestedRegime ? '2027-07-19T10:00:00.000Z' : '2026-07-19T10:00:00.000Z';
  final now = attestedRegime
      ? DateTime.utc(2027, 7, 19, 10)
      : DateTime.utc(2026, 7, 19, 10);
  final evidence = Pillar3aBeneficiaryEvidence.fromJson(
    <String, Object?>{
      'kind': 'pillar3aBeneficiaryClause',
      'ownerKind': 'self',
      'documentSource': 'certificate',
      'contractReferenceId': '11111111-1111-4111-8111-111111111111',
      'referenceId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'documentAuthorityId': '33333333-3333-4333-8333-333333333333',
      'documentKind': 'confirmationInstitutionnelle',
      'sourceDate': sourceDate,
      'legalYear': attestedRegime ? 2027 : 2026,
      'institutionAttested': true,
      'contractScoped': true,
      'temporalBasis': attestedRegime
          ? <String, Object?>{
              'kind': 'attestedRegime',
              'regime': 'post20270601',
            }
          : <String, Object?>{
              'kind': 'exactDates',
              'designationEffectiveDate': '2026-01-15',
              'lastAssignmentModificationDate': '2026-06-12',
            },
      'relation': 'currentActiveUnpaid',
      'relationSource': 'userInput',
      'relationConfirmedAt': relationConfirmedAt,
    },
    now: now,
  )!;
  return Pillar3aBeneficiarySpecialistHandoff.tryFromConsumerResolution(
    _Resolution(<Pillar3aBeneficiaryConsumerEntry>[
      _Entry(_Metadata(
        temporalBasis: evidence.temporalBasis,
        sourceDate: evidence.sourceDate,
        legalYear: evidence.legalYear,
        relationConfirmedAt: evidence.relationConfirmedAt,
      )),
    ]),
  )!;
}
