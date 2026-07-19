import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

enum Pillar3aBeneficiaryRelation {
  currentActiveUnpaid,
  uncertain,
  paidOrClosed;

  static Pillar3aBeneficiaryRelation? fromWireName(Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

enum Pillar3aBeneficiaryRegime {
  pre20270601,
  post20270601;

  static Pillar3aBeneficiaryRegime? fromWireName(Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

enum Pillar3aBeneficiaryAuthorityDocumentKind {
  confirmationInstitutionnelle,
  avenantAccuse,
  formulaireDesignationAccuse;

  static Pillar3aBeneficiaryAuthorityDocumentKind? fromWireName(Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

@immutable
sealed class Pillar3aBeneficiaryTemporalBasis {
  const Pillar3aBeneficiaryTemporalBasis();

  Map<String, Object?> toJson();
}

@immutable
final class Pillar3aBeneficiaryExactDates
    extends Pillar3aBeneficiaryTemporalBasis {
  const Pillar3aBeneficiaryExactDates._({
    required this.designationEffectiveDate,
    required this.lastAssignmentModificationDate,
  });

  final DateTime? designationEffectiveDate;
  final DateTime? lastAssignmentModificationDate;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'exactDates',
        'designationEffectiveDate':
            _encodeCivilDateOrNull(designationEffectiveDate),
        'lastAssignmentModificationDate':
            _encodeCivilDateOrNull(lastAssignmentModificationDate),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar3aBeneficiaryExactDates &&
          designationEffectiveDate == other.designationEffectiveDate &&
          lastAssignmentModificationDate ==
              other.lastAssignmentModificationDate;

  @override
  int get hashCode =>
      Object.hash(designationEffectiveDate, lastAssignmentModificationDate);
}

@immutable
final class Pillar3aBeneficiaryAttestedRegime
    extends Pillar3aBeneficiaryTemporalBasis {
  const Pillar3aBeneficiaryAttestedRegime._(this.regime);

  final Pillar3aBeneficiaryRegime regime;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'attestedRegime',
        'regime': regime.name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar3aBeneficiaryAttestedRegime && regime == other.regime;

  @override
  int get hashCode => regime.hashCode;
}

@immutable
final class Pillar3aBeneficiaryEvidence {
  const Pillar3aBeneficiaryEvidence._({
    required this.contractReferenceId,
    required this.referenceId,
    required this.documentAuthorityId,
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.temporalBasis,
    required this.relation,
    required this.relationConfirmedAt,
  });

  static const kind = 'pillar3aBeneficiaryClause';
  static const ownerKind = 'self';
  static const documentSource = 'certificate';
  static const relationSource = 'userInput';

  final String contractReferenceId;
  final String referenceId;
  final String documentAuthorityId;
  final Pillar3aBeneficiaryAuthorityDocumentKind documentKind;
  final DateTime sourceDate;

  /// Generic legal provenance only; never an eligibility or regime inference.
  final int legalYear;
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;
  final Pillar3aBeneficiaryRelation relation;
  final DateTime relationConfirmedAt;

  static Pillar3aBeneficiaryEvidence create({
    required String contractReferenceId,
    required String referenceId,
    required String documentAuthorityId,
    required Pillar3aBeneficiaryAuthorityDocumentKind documentKind,
    required DateTime sourceDate,
    required int legalYear,
    required Pillar3aBeneficiaryTemporalBasis temporalBasis,
    required Pillar3aBeneficiaryRelation relation,
    required DateTime relationConfirmedAt,
  }) {
    final candidate = fromJson(
      <String, Object?>{
        'kind': kind,
        'ownerKind': ownerKind,
        'documentSource': documentSource,
        'contractReferenceId': contractReferenceId,
        'referenceId': referenceId,
        'documentAuthorityId': documentAuthorityId,
        'documentKind': documentKind.name,
        'sourceDate': _encodeCivilDate(sourceDate),
        'legalYear': legalYear,
        'institutionAttested': true,
        'contractScoped': true,
        'temporalBasis': temporalBasis.toJson(),
        'relation': relation.name,
        'relationSource': relationSource,
        'relationConfirmedAt': relationConfirmedAt.toUtc().toIso8601String(),
      },
      now: relationConfirmedAt.toUtc(),
    );
    if (candidate == null) {
      throw ArgumentError('Invalid pillar 3a beneficiary evidence');
    }
    return candidate;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'ownerKind': ownerKind,
        'documentSource': documentSource,
        'contractReferenceId': contractReferenceId,
        'referenceId': referenceId,
        'documentAuthorityId': documentAuthorityId,
        'documentKind': documentKind.name,
        'sourceDate': _encodeCivilDate(sourceDate),
        'legalYear': legalYear,
        'institutionAttested': true,
        'contractScoped': true,
        'temporalBasis': temporalBasis.toJson(),
        'relation': relation.name,
        'relationSource': relationSource,
        'relationConfirmedAt': relationConfirmedAt.toUtc().toIso8601String(),
      };

  static Pillar3aBeneficiaryEvidence? fromJson(
    Object? raw, {
    required DateTime now,
  }) {
    final json = _strictStringMap(raw);
    if (json == null || !_hasExactKeys(json, _contractKeys)) return null;

    final contractReferenceId = json['contractReferenceId'];
    final referenceId = json['referenceId'];
    final documentAuthorityId = json['documentAuthorityId'];
    final documentKind = Pillar3aBeneficiaryAuthorityDocumentKind.fromWireName(
      json['documentKind'],
    );
    final relation = Pillar3aBeneficiaryRelation.fromWireName(json['relation']);
    final legalYear = json['legalYear'];
    if (json['kind'] != kind ||
        json['ownerKind'] != ownerKind ||
        json['documentSource'] != documentSource ||
        json['relationSource'] != relationSource ||
        contractReferenceId is! String ||
        !_canonicalUuidV4.hasMatch(contractReferenceId) ||
        referenceId is! String ||
        !_canonicalUuidV4.hasMatch(referenceId) ||
        documentAuthorityId is! String ||
        !_canonicalUuidV4.hasMatch(documentAuthorityId) ||
        <String>{
              contractReferenceId,
              referenceId,
              documentAuthorityId,
            }.length !=
            3 ||
        documentKind == null ||
        json['institutionAttested'] != true ||
        json['contractScoped'] != true ||
        relation == null ||
        legalYear is! int ||
        legalYear < 1900 ||
        legalYear > 9999) {
      return null;
    }

    final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
    final relationConfirmedAt =
        _parseCanonicalUtcInstant(json['relationConfirmedAt']);
    final current = now.toUtc();
    if (sourceDate == null ||
        relationConfirmedAt == null ||
        SwissCivilTime.isFutureCivilDate(sourceDate, now: current) ||
        relationConfirmedAt.isAfter(current) ||
        SwissCivilTime.civilDate(relationConfirmedAt)
            .isBefore(SwissCivilTime.businessDate(sourceDate))) {
      return null;
    }

    final temporalBasis = _parseTemporalBasis(
      json['temporalBasis'],
      sourceDate: sourceDate,
    );
    if (temporalBasis == null) return null;

    return Pillar3aBeneficiaryEvidence._(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
      documentKind: documentKind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      temporalBasis: temporalBasis,
      relation: relation,
      relationConfirmedAt: relationConfirmedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar3aBeneficiaryEvidence &&
          contractReferenceId == other.contractReferenceId &&
          referenceId == other.referenceId &&
          documentAuthorityId == other.documentAuthorityId &&
          documentKind == other.documentKind &&
          sourceDate == other.sourceDate &&
          legalYear == other.legalYear &&
          temporalBasis == other.temporalBasis &&
          relation == other.relation &&
          relationConfirmedAt == other.relationConfirmedAt;

  @override
  int get hashCode => Object.hash(
        contractReferenceId,
        referenceId,
        documentAuthorityId,
        documentKind,
        sourceDate,
        legalYear,
        temporalBasis,
        relation,
        relationConfirmedAt,
      );
}

@immutable
final class Pillar3aBeneficiaryEvidenceRoot {
  Pillar3aBeneficiaryEvidenceRoot._(List<Pillar3aBeneficiaryEvidence> contracts)
      : contracts = List<Pillar3aBeneficiaryEvidence>.unmodifiable(contracts);

  static const int schemaVersion = 1;
  static const String answerKey =
      '_coach_pillar3a_beneficiary_evidence_v1'; // gitleaks:allow — ledger field name, not a credential.

  /// Payload/abuse bound only; never a Swiss product or legal limit.
  static const int maximumContracts = 32;

  final List<Pillar3aBeneficiaryEvidence> contracts;

  static Pillar3aBeneficiaryEvidenceRoot fromContracts(
    List<Pillar3aBeneficiaryEvidence> contracts, {
    required DateTime now,
  }) {
    final candidate = fromJson(
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'contracts': contracts.map((contract) => contract.toJson()).toList(),
      },
      now: () => now,
    );
    if (candidate == null) {
      throw ArgumentError('Invalid pillar 3a beneficiary evidence root');
    }
    return candidate;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'contracts': contracts.map((contract) => contract.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static Pillar3aBeneficiaryEvidenceRoot? fromJson(
    Object? raw, {
    DateTime Function()? now,
  }) {
    final json = _strictStringMap(raw);
    if (json == null ||
        !_hasExactKeys(json, _rootKeys) ||
        json['schemaVersion'] is! int ||
        json['schemaVersion'] != schemaVersion) {
      return null;
    }
    final rawContracts = json['contracts'];
    if (rawContracts is! List ||
        rawContracts.isEmpty ||
        rawContracts.length > maximumContracts) {
      return null;
    }

    final current = (now ?? DateTime.now)().toUtc();
    final contracts = <Pillar3aBeneficiaryEvidence>[];
    final globallyUniqueIds = <String>{};
    for (final rawContract in rawContracts) {
      final contract = Pillar3aBeneficiaryEvidence.fromJson(
        rawContract,
        now: current,
      );
      if (contract == null ||
          !globallyUniqueIds.add(contract.contractReferenceId) ||
          !globallyUniqueIds.add(contract.referenceId) ||
          !globallyUniqueIds.add(contract.documentAuthorityId)) {
        return null;
      }
      contracts.add(contract);
    }
    contracts.sort(
      (left, right) =>
          left.contractReferenceId.compareTo(right.contractReferenceId),
    );
    return Pillar3aBeneficiaryEvidenceRoot._(contracts);
  }

  static Pillar3aBeneficiaryEvidenceRoot? fromJsonString(
    Object? raw, {
    DateTime Function()? now,
  }) {
    if (raw is! String) return null;
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    return fromJson(decoded, now: now);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar3aBeneficiaryEvidenceRoot &&
          listEquals(contracts, other.contracts);

  @override
  int get hashCode => Object.hashAll(contracts);
}

@immutable
final class Pillar3aBeneficiaryReviewConfirmation {
  const Pillar3aBeneficiaryReviewConfirmation._({
    required this.contractReferenceId,
    required this.referenceId,
    required this.documentAuthorityId,
    required this.documentKind,
    required this.relation,
    required this.sourceDate,
    required this.legalYear,
    required this.temporalBasis,
    required this.expectedPreviousReferenceId,
  });

  final String contractReferenceId;
  final String referenceId;
  final String documentAuthorityId;
  final Pillar3aBeneficiaryAuthorityDocumentKind documentKind;
  final Pillar3aBeneficiaryRelation relation;
  final DateTime sourceDate;
  final int legalYear;
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;
  final String? expectedPreviousReferenceId;

  factory Pillar3aBeneficiaryReviewConfirmation.exactDates({
    required String contractReferenceId,
    required String referenceId,
    required String documentAuthorityId,
    required Pillar3aBeneficiaryAuthorityDocumentKind documentKind,
    required Pillar3aBeneficiaryRelation relation,
    required DateTime sourceDate,
    required int legalYear,
    required DateTime? designationEffectiveDate,
    required DateTime? lastAssignmentModificationDate,
    String? expectedPreviousReferenceId,
  }) {
    _validateReviewIdentity(
      contractReferenceId,
      referenceId,
      documentAuthorityId,
      expectedPreviousReferenceId,
    );
    if (relation == Pillar3aBeneficiaryRelation.paidOrClosed ||
        (designationEffectiveDate == null &&
            lastAssignmentModificationDate == null)) {
      throw ArgumentError('Exact dates require an active relation and a date');
    }
    _validateReviewProvenance(sourceDate, legalYear);
    return Pillar3aBeneficiaryReviewConfirmation._(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
      documentKind: documentKind,
      relation: relation,
      sourceDate: sourceDate,
      legalYear: legalYear,
      temporalBasis: Pillar3aBeneficiaryExactDates._(
        designationEffectiveDate: designationEffectiveDate,
        lastAssignmentModificationDate: lastAssignmentModificationDate,
      ),
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }

  factory Pillar3aBeneficiaryReviewConfirmation.attestedRegime({
    required String contractReferenceId,
    required String referenceId,
    required String documentAuthorityId,
    required Pillar3aBeneficiaryAuthorityDocumentKind documentKind,
    required Pillar3aBeneficiaryRelation relation,
    required DateTime sourceDate,
    required int legalYear,
    required Pillar3aBeneficiaryRegime regime,
    String? expectedPreviousReferenceId,
  }) {
    _validateReviewIdentity(
      contractReferenceId,
      referenceId,
      documentAuthorityId,
      expectedPreviousReferenceId,
    );
    if (relation == Pillar3aBeneficiaryRelation.paidOrClosed) {
      throw ArgumentError('A closed contract cannot carry a regime');
    }
    _validateReviewProvenance(sourceDate, legalYear);
    return Pillar3aBeneficiaryReviewConfirmation._(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
      documentKind: documentKind,
      relation: relation,
      sourceDate: sourceDate,
      legalYear: legalYear,
      temporalBasis: Pillar3aBeneficiaryAttestedRegime._(regime),
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }

  factory Pillar3aBeneficiaryReviewConfirmation.paidOrClosed({
    required String contractReferenceId,
    required String referenceId,
    required String documentAuthorityId,
    required Pillar3aBeneficiaryAuthorityDocumentKind documentKind,
    required DateTime sourceDate,
    required int legalYear,
    required Pillar3aBeneficiaryTemporalBasis temporalBasis,
    String? expectedPreviousReferenceId,
  }) {
    _validateReviewIdentity(
      contractReferenceId,
      referenceId,
      documentAuthorityId,
      expectedPreviousReferenceId,
    );
    _validateReviewProvenance(sourceDate, legalYear);
    return Pillar3aBeneficiaryReviewConfirmation._(
      contractReferenceId: contractReferenceId,
      referenceId: referenceId,
      documentAuthorityId: documentAuthorityId,
      documentKind: documentKind,
      relation: Pillar3aBeneficiaryRelation.paidOrClosed,
      sourceDate: sourceDate,
      legalYear: legalYear,
      temporalBasis: temporalBasis,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }
}

@immutable
final class Pillar3aBeneficiaryReceipt {
  Pillar3aBeneficiaryReceipt({
    required this.referenceId,
    required this.contractReferenceId,
    required this.documentAuthorityId,
    required this.relationConfirmedAt,
  }) {
    if (!_canonicalUuidV4.hasMatch(referenceId) ||
        !_canonicalUuidV4.hasMatch(contractReferenceId) ||
        !_canonicalUuidV4.hasMatch(documentAuthorityId) ||
        <String>{
              referenceId,
              contractReferenceId,
              documentAuthorityId,
            }.length !=
            3) {
      throw ArgumentError('Invalid pillar 3a receipt identity');
    }
  }

  final String referenceId;
  final String contractReferenceId;
  final String documentAuthorityId;
  final DateTime relationConfirmedAt;
}

@immutable
final class Pillar3aBeneficiaryAuthorityCandidateV1 {
  const Pillar3aBeneficiaryAuthorityCandidateV1._({
    required this.schemaVersion,
    required this.documentAuthorityId,
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.institutionAttested,
    required this.contractScoped,
    required this.needsReview,
    required this.temporalBasis,
  });

  final int schemaVersion;
  final String documentAuthorityId;
  final Pillar3aBeneficiaryAuthorityDocumentKind documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final bool institutionAttested;
  final bool contractScoped;
  final bool needsReview;
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;

  factory Pillar3aBeneficiaryAuthorityCandidateV1.exactDates({
    required int schemaVersion,
    required String documentAuthorityId,
    required Pillar3aBeneficiaryAuthorityDocumentKind documentKind,
    required DateTime sourceDate,
    required int legalYear,
    required bool institutionAttested,
    required bool contractScoped,
    required bool needsReview,
    required DateTime? designationEffectiveDate,
    required DateTime? lastAssignmentModificationDate,
  }) {
    if (schemaVersion != 1 ||
        !_canonicalUuidV4.hasMatch(documentAuthorityId) ||
        legalYear < 1900 ||
        legalYear > 9999 ||
        !institutionAttested ||
        !contractScoped ||
        !needsReview ||
        (designationEffectiveDate == null &&
            lastAssignmentModificationDate == null)) {
      throw ArgumentError('Invalid pillar 3a authority candidate');
    }
    return Pillar3aBeneficiaryAuthorityCandidateV1._(
      schemaVersion: schemaVersion,
      documentAuthorityId: documentAuthorityId,
      documentKind: documentKind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      institutionAttested: institutionAttested,
      contractScoped: contractScoped,
      needsReview: needsReview,
      temporalBasis: Pillar3aBeneficiaryExactDates._(
        designationEffectiveDate: designationEffectiveDate,
        lastAssignmentModificationDate: lastAssignmentModificationDate,
      ),
    );
  }

  static Pillar3aBeneficiaryAuthorityCandidateV1? tryFromVisionJson(
    Object? raw,
  ) {
    final json = _strictStringMap(raw);
    if (json == null || !_hasExactKeys(json, _authorityCandidateKeys)) {
      return null;
    }
    final documentKind = Pillar3aBeneficiaryAuthorityDocumentKind.fromWireName(
      json['documentKind'],
    );
    final authorityId = json['documentAuthorityId'];
    final legalYear = json['legalYear'];
    final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
    if (json['schemaVersion'] != 1 ||
        authorityId is! String ||
        !_canonicalUuidV4.hasMatch(authorityId) ||
        documentKind == null ||
        sourceDate == null ||
        legalYear is! int ||
        legalYear < 1900 ||
        legalYear > 9999 ||
        json['institutionAttested'] != true ||
        json['contractScoped'] != true ||
        json['needsReview'] != true) {
      return null;
    }
    final temporalBasis = _parseTemporalBasis(
      json['temporalBasis'],
      sourceDate: sourceDate,
    );
    if (temporalBasis == null) return null;
    return Pillar3aBeneficiaryAuthorityCandidateV1._(
      schemaVersion: 1,
      documentAuthorityId: authorityId,
      documentKind: documentKind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      institutionAttested: true,
      contractScoped: true,
      needsReview: true,
      temporalBasis: temporalBasis,
    );
  }
}

@immutable
final class Pillar3aBeneficiaryAcquisitionCandidate {
  Pillar3aBeneficiaryAcquisitionCandidate({
    required this.contractReferenceId,
    required this.referenceId,
    required this.authority,
    this.expectedPreviousReferenceId,
  }) {
    if (!_canonicalUuidV4.hasMatch(contractReferenceId) ||
        !_canonicalUuidV4.hasMatch(referenceId) ||
        <String>{
              contractReferenceId,
              referenceId,
              authority.documentAuthorityId,
            }.length !=
            3 ||
        (expectedPreviousReferenceId != null &&
            (!_canonicalUuidV4.hasMatch(expectedPreviousReferenceId!) ||
                <String>{
                      contractReferenceId,
                      referenceId,
                      authority.documentAuthorityId,
                      expectedPreviousReferenceId!,
                    }.length !=
                    4))) {
      throw ArgumentError('Invalid pillar 3a acquisition identity');
    }
  }

  final String contractReferenceId;
  final String referenceId;
  final Pillar3aBeneficiaryAuthorityCandidateV1 authority;
  final String? expectedPreviousReferenceId;
}

void _validateReviewIdentity(
  String contractReferenceId,
  String referenceId,
  String documentAuthorityId,
  String? expectedPreviousReferenceId,
) {
  if (!_canonicalUuidV4.hasMatch(contractReferenceId) ||
      !_canonicalUuidV4.hasMatch(referenceId) ||
      !_canonicalUuidV4.hasMatch(documentAuthorityId) ||
      <String>{contractReferenceId, referenceId, documentAuthorityId}.length !=
          3 ||
      (expectedPreviousReferenceId != null &&
          (!_canonicalUuidV4.hasMatch(expectedPreviousReferenceId) ||
              expectedPreviousReferenceId == contractReferenceId ||
              expectedPreviousReferenceId == referenceId ||
              expectedPreviousReferenceId == documentAuthorityId))) {
    throw ArgumentError('Invalid pillar 3a review identity');
  }
}

void _validateReviewProvenance(DateTime sourceDate, int legalYear) {
  if (legalYear < 1900 || legalYear > 9999 || sourceDate.year < 1900) {
    throw ArgumentError('Invalid pillar 3a review provenance');
  }
}

Pillar3aBeneficiaryTemporalBasis? _parseTemporalBasis(
  Object? raw, {
  required DateTime sourceDate,
}) {
  final json = _strictStringMap(raw);
  if (json == null) return null;
  switch (json['kind']) {
    case 'exactDates':
      if (!_hasExactKeys(json, _exactDatesKeys)) return null;
      final designationEffectiveDate =
          _parseNullableCanonicalCivilDate(json['designationEffectiveDate']);
      final lastAssignmentModificationDate = _parseNullableCanonicalCivilDate(
        json['lastAssignmentModificationDate'],
      );
      if (designationEffectiveDate == _invalidCivilDate ||
          lastAssignmentModificationDate == _invalidCivilDate) {
        return null;
      }
      final designationDate = designationEffectiveDate as DateTime?;
      final modificationDate = lastAssignmentModificationDate as DateTime?;
      if (designationDate == null && modificationDate == null) return null;
      final sourceBusinessDate = SwissCivilTime.businessDate(sourceDate);
      if ((designationDate != null &&
              SwissCivilTime.businessDate(designationDate)
                  .isAfter(sourceBusinessDate)) ||
          (modificationDate != null &&
              SwissCivilTime.businessDate(modificationDate)
                  .isAfter(sourceBusinessDate))) {
        return null;
      }
      return Pillar3aBeneficiaryExactDates._(
        designationEffectiveDate: designationDate,
        lastAssignmentModificationDate: modificationDate,
      );
    case 'attestedRegime':
      if (!_hasExactKeys(json, _attestedRegimeKeys)) return null;
      final regime = Pillar3aBeneficiaryRegime.fromWireName(json['regime']);
      if (regime == null) return null;

      // Beneficiary designation or assignment modification is the determining event;
      // sourceDate, relationConfirmedAt, and legalYear alone never determine
      // the regime.
      // sourceDate only rejects post-reform evidence predating the legal cutoff.
      if (regime == Pillar3aBeneficiaryRegime.post20270601 &&
          SwissCivilTime.businessDate(sourceDate).isBefore(_opp3RegimeCutoff)) {
        return null;
      }
      return Pillar3aBeneficiaryAttestedRegime._(regime);
    default:
      return null;
  }
}

Map<String, Object?>? _strictStringMap(Object? raw) {
  if (raw is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

bool _hasExactKeys(Map<String, Object?> json, Set<String> expected) =>
    json.length == expected.length &&
    json.keys.toSet().difference(expected).isEmpty &&
    expected.every(json.containsKey);

DateTime? _parseCanonicalCivilDate(Object? raw) {
  if (raw is! String) return null;
  final parsed = SwissCivilTime.parseCanonicalCivilDate(raw);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

final Object _invalidCivilDate = Object();

Object? _parseNullableCanonicalCivilDate(Object? raw) {
  if (raw == null) return null;
  return _parseCanonicalCivilDate(raw) ?? _invalidCivilDate;
}

DateTime? _parseCanonicalUtcInstant(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || parsed.toUtc().toIso8601String() != raw) return null;
  return parsed.toUtc();
}

String _encodeCivilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _encodeCivilDateOrNull(DateTime? value) =>
    value == null ? null : _encodeCivilDate(value);

const _rootKeys = <String>{'schemaVersion', 'contracts'};
const _contractKeys = <String>{
  'kind',
  'ownerKind',
  'documentSource',
  'contractReferenceId',
  'referenceId',
  'documentAuthorityId',
  'documentKind',
  'sourceDate',
  'legalYear',
  'institutionAttested',
  'contractScoped',
  'temporalBasis',
  'relation',
  'relationSource',
  'relationConfirmedAt',
};
const _exactDatesKeys = <String>{
  'kind',
  'designationEffectiveDate',
  'lastAssignmentModificationDate',
};
const _attestedRegimeKeys = <String>{'kind', 'regime'};
const _authorityCandidateKeys = <String>{
  'schemaVersion',
  'documentAuthorityId',
  'documentKind',
  'sourceDate',
  'legalYear',
  'institutionAttested',
  'contractScoped',
  'temporalBasis',
  'needsReview',
};
final RegExp _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
// Legal basis: OPP 3 art. 2 al. 2-3; RO 2026 182, ch. II al. 2;
// OFAS, Bulletin PP no 168, ch. 1168.
final DateTime _opp3RegimeCutoff = DateTime.utc(2027, 6, 1);
