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
    required this.relation,
    required this.referenceId,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    required this.temporalBasis,
  });

  static const kind = 'pillar3aBeneficiaryClause';
  static const ownerKind = 'self';
  static const source = 'certificate';

  final String contractReferenceId;
  final Pillar3aBeneficiaryRelation relation;
  final String referenceId;
  final DateTime sourceDate;

  /// Generic legal provenance only; never an eligibility or regime inference.
  final int legalYear;
  final DateTime confirmedAt;
  final Pillar3aBeneficiaryTemporalBasis? temporalBasis;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'ownerKind': ownerKind,
        'source': source,
        'contractReferenceId': contractReferenceId,
        'relation': relation.name,
        'referenceId': referenceId,
        'sourceDate': _encodeCivilDate(sourceDate),
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'temporalBasis': temporalBasis?.toJson(),
      };

  static Pillar3aBeneficiaryEvidence? fromJson(
    Object? raw, {
    required DateTime now,
  }) {
    final json = _strictStringMap(raw);
    if (json == null || !_hasExactKeys(json, _contractKeys)) return null;

    final contractReferenceId = json['contractReferenceId'];
    final referenceId = json['referenceId'];
    final relation = Pillar3aBeneficiaryRelation.fromWireName(json['relation']);
    final legalYear = json['legalYear'];
    if (json['kind'] != kind ||
        json['ownerKind'] != ownerKind ||
        json['source'] != source ||
        contractReferenceId is! String ||
        !_canonicalUuidV4.hasMatch(contractReferenceId) ||
        referenceId is! String ||
        !_canonicalUuidV4.hasMatch(referenceId) ||
        contractReferenceId == referenceId ||
        relation == null ||
        legalYear is! int ||
        legalYear < 1900 ||
        legalYear > 9999) {
      return null;
    }

    final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
    final confirmedAt = _parseCanonicalUtcInstant(json['confirmedAt']);
    final current = now.toUtc();
    if (sourceDate == null ||
        confirmedAt == null ||
        SwissCivilTime.isFutureCivilDate(sourceDate, now: current) ||
        confirmedAt.isAfter(current) ||
        SwissCivilTime.civilDate(confirmedAt)
            .isBefore(SwissCivilTime.businessDate(sourceDate))) {
      return null;
    }

    final rawTemporalBasis = json['temporalBasis'];
    Pillar3aBeneficiaryTemporalBasis? temporalBasis;
    if (relation == Pillar3aBeneficiaryRelation.paidOrClosed) {
      if (rawTemporalBasis != null) return null;
    } else {
      temporalBasis = _parseTemporalBasis(
        rawTemporalBasis,
        sourceDate: sourceDate,
      );
      if (temporalBasis == null) return null;
    }

    return Pillar3aBeneficiaryEvidence._(
      contractReferenceId: contractReferenceId,
      relation: relation,
      referenceId: referenceId,
      sourceDate: sourceDate,
      legalYear: legalYear,
      confirmedAt: confirmedAt,
      temporalBasis: temporalBasis,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pillar3aBeneficiaryEvidence &&
          contractReferenceId == other.contractReferenceId &&
          relation == other.relation &&
          referenceId == other.referenceId &&
          sourceDate == other.sourceDate &&
          legalYear == other.legalYear &&
          confirmedAt == other.confirmedAt &&
          temporalBasis == other.temporalBasis;

  @override
  int get hashCode => Object.hash(
        contractReferenceId,
        relation,
        referenceId,
        sourceDate,
        legalYear,
        confirmedAt,
        temporalBasis,
      );
}

@immutable
final class Pillar3aBeneficiaryEvidenceRoot {
  Pillar3aBeneficiaryEvidenceRoot._(List<Pillar3aBeneficiaryEvidence> contracts)
      : contracts = List<Pillar3aBeneficiaryEvidence>.unmodifiable(contracts);

  static const int schemaVersion = 1;
  static const String answerKey =
      '_coach_pillar3a_beneficiary_evidence_v1';

  /// Payload/abuse bound only; never a Swiss product or legal limit.
  static const int maximumContracts = 32;

  final List<Pillar3aBeneficiaryEvidence> contracts;

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
    final contractReferenceIds = <String>{};
    final referenceIds = <String>{};
    for (final rawContract in rawContracts) {
      final contract = Pillar3aBeneficiaryEvidence.fromJson(
        rawContract,
        now: current,
      );
      if (contract == null ||
          !contractReferenceIds.add(contract.contractReferenceId) ||
          !referenceIds.add(contract.referenceId)) {
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
      // sourceDate, confirmedAt, and legalYear alone never determine the regime.
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
  'source',
  'contractReferenceId',
  'relation',
  'referenceId',
  'sourceDate',
  'legalYear',
  'confirmedAt',
  'temporalBasis',
};
const _exactDatesKeys = <String>{
  'kind',
  'designationEffectiveDate',
  'lastAssignmentModificationDate',
};
const _attestedRegimeKeys = <String>{'kind', 'regime'};
final RegExp _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
// Legal basis: OPP 3 art. 2 al. 2-3; RO 2026 182, ch. II al. 2;
// OFAS, Bulletin PP no 168, ch. 1168.
final DateTime _opp3RegimeCutoff = DateTime.utc(2027, 6, 1);
