import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

enum LppEvidenceUnit {
  chf('CHF'),
  chfPerYear('CHF/year'),
  chfLumpSum('CHF/lump-sum'),
  ratio('ratio');

  const LppEvidenceUnit(this.wireName);

  final String wireName;
}

enum LppEvidenceStatus { available, availableNeedsConfirmation }

enum LppEvidenceOwnerKind {
  self('self'),
  manualPartner('manualPartner');

  const LppEvidenceOwnerKind(this.wireName);

  final String wireName;

  static LppEvidenceOwnerKind? fromWireName(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

enum LppEvidenceAuthorizationMode {
  self('self'),
  manualPartnerDeclaration('manualPartnerDeclaration');

  const LppEvidenceAuthorizationMode(this.wireName);

  final String wireName;

  static LppEvidenceAuthorizationMode? fromWireName(Object? value) {
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

enum LppEvidenceFactKey {
  vestedBenefitsCapitalChf(
    'vestedBenefitsCapitalChf',
    LppEvidenceUnit.chf,
    'prevoyance.avoirLppTotal',
  ),
  mandatoryVestedBenefitsCapitalChf(
    'mandatoryVestedBenefitsCapitalChf',
    LppEvidenceUnit.chf,
    'prevoyance.avoirLppObligatoire',
  ),
  extraMandatoryVestedBenefitsCapitalChf(
    'extraMandatoryVestedBenefitsCapitalChf',
    LppEvidenceUnit.chf,
    'prevoyance.avoirLppSurobligatoire',
  ),
  insuredSalaryAnnualChf(
    'insuredSalaryAnnualChf',
    LppEvidenceUnit.chfPerYear,
    'prevoyance.salaireAssure',
  ),
  maximumBuybackCapitalChf(
    'maximumBuybackCapitalChf',
    LppEvidenceUnit.chf,
    'prevoyance.rachatMaximum',
  ),
  mandatoryConversionRateRatio(
    'mandatoryConversionRateRatio',
    LppEvidenceUnit.ratio,
    'prevoyance.tauxConversion',
  ),
  extraMandatoryConversionRateRatio(
    'extraMandatoryConversionRateRatio',
    LppEvidenceUnit.ratio,
    'prevoyance.tauxConversionSuroblig',
  ),
  fundReturnRateRatio(
    'fundReturnRateRatio',
    LppEvidenceUnit.ratio,
    'prevoyance.rendementCaisse',
  ),
  retirementPensionAnnualChf(
    'retirementPensionAnnualChf',
    LppEvidenceUnit.chfPerYear,
    'prevoyance.projectedRenteLpp',
  ),
  retirementCapitalLumpSumChf(
    'retirementCapitalLumpSumChf',
    LppEvidenceUnit.chfLumpSum,
    'prevoyance.projectedCapital65',
  ),
  disabilityPensionAnnualChf(
    'disabilityPensionAnnualChf',
    LppEvidenceUnit.chfPerYear,
    'prevoyance.disabilityCoverage',
  ),
  disabilityCapitalLumpSumChf(
    'disabilityCapitalLumpSumChf',
    LppEvidenceUnit.chfLumpSum,
    'prevoyance.lppDisabilityCapital',
  ),
  deathCapitalLumpSumChf(
    'deathCapitalLumpSumChf',
    LppEvidenceUnit.chfLumpSum,
    'prevoyance.deathCoverage',
  );

  const LppEvidenceFactKey(this.wireName, this.unit, this.profilePath);

  final String wireName;
  final LppEvidenceUnit unit;
  final String profilePath;

  String get manualPartnerProfilePath => 'conjoint.$profilePath';

  static LppEvidenceFactKey? fromWireName(String value) {
    for (final key in values) {
      if (key.wireName == value) return key;
    }
    return null;
  }
}

/// Canonical balance invariant shared by acquisition, review, and persistence.
abstract final class LppBalanceCoherence {
  static const toleranceChf = 1.0;

  static bool isCoherent(Map<LppEvidenceFactKey, double> values) {
    final total = values[LppEvidenceFactKey.vestedBenefitsCapitalChf];
    if (total == null) return true;
    final mandatory =
        values[LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf];
    final extra =
        values[LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf];
    if ((mandatory != null && mandatory > total) ||
        (extra != null && extra > total)) {
      return false;
    }
    return mandatory == null ||
        extra == null ||
        (total - mandatory - extra).abs() <= toleranceChf;
  }
}

class LppReviewedFact {
  const LppReviewedFact({
    required this.value,
    required this.unit,
    this.corrected = false,
  });

  final double value;
  final LppEvidenceUnit unit;
  final bool corrected;
}

/// One volatile, per-document authorization bound before LPP review.
///
/// This object deliberately has no JSON API. It may live only in the bounded
/// in-memory scan session and must never enter routes, provenance or the
/// financial ledger.
class LppAcquisitionAuthorization {
  const LppAcquisitionAuthorization({
    required this.acquisitionId,
    required this.subject,
    required this.partnerAttested,
    required this.policyVersion,
    required this.declaredAt,
    required this.documentSha256,
    this.manualPartnerOwnerId,
    this.receiptId,
  });

  static const currentPolicyVersion = 'g1-prov02-v1';

  final String acquisitionId;
  final LppEvidenceOwnerKind subject;
  final bool partnerAttested;
  final String policyVersion;
  final DateTime declaredAt;
  final String documentSha256;
  final String? manualPartnerOwnerId;
  final String? receiptId;

  static String sha256Hex(Uint8List transmittedBytes) =>
      sha256.convert(transmittedBytes).toString();

  static bool hasValidEnvelope({
    required String acquisitionId,
    required LppEvidenceOwnerKind subject,
    required bool partnerAttested,
    required String policyVersion,
    required DateTime declaredAt,
    required DateTime now,
  }) {
    final subjectAttestationIsCoherent =
        subject == LppEvidenceOwnerKind.manualPartner
            ? partnerAttested
            : !partnerAttested;
    return _isCanonicalUuidV4(acquisitionId) &&
        subjectAttestationIsCoherent &&
        policyVersion == currentPolicyVersion &&
        declaredAt.isUtc &&
        !declaredAt.isAfter(now.toUtc());
  }

  bool isValidAt(DateTime now) {
    final hasAccountabilityBinding = subject == LppEvidenceOwnerKind.self
        ? manualPartnerOwnerId == null && receiptId == null
        : (manualPartnerOwnerId == null && receiptId == null) ||
            (_isCanonicalUuidV4(manualPartnerOwnerId ?? '') &&
                _isCanonicalUuidV4(receiptId ?? ''));
    return hasValidEnvelope(
          acquisitionId: acquisitionId,
          subject: subject,
          partnerAttested: partnerAttested,
          policyVersion: policyVersion,
          declaredAt: declaredAt,
          now: now,
        ) &&
        hasAccountabilityBinding &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(documentSha256) &&
        documentSha256 != _zeroSha256;
  }
}

class LppReviewConfirmation {
  LppReviewConfirmation({
    required Map<LppEvidenceFactKey, LppReviewedFact> facts,
    required this.sourceDate,
    required this.authorization,
    this.partnerAccountabilityContext,
  }) : facts = Map.unmodifiable(
          Map<LppEvidenceFactKey, LppReviewedFact>.of(facts),
        );

  final Map<LppEvidenceFactKey, LppReviewedFact> facts;
  final DateTime? sourceDate;
  final LppAcquisitionAuthorization authorization;
  final ManualPartnerAccountabilityContext? partnerAccountabilityContext;

  LppEvidenceOwnerKind get subject => authorization.subject;
}

final class LppCapitalNoticeReviewConfirmation {
  factory LppCapitalNoticeReviewConfirmation({
    required LppEvidenceOwnerKind ownerKind,
    required DateTime sourceDate,
    required int legalYear,
    required DateTime deadlineDate,
    required String expectedSnapshotId,
    String? expectedPreviousReferenceId,
  }) {
    if (ownerKind != LppEvidenceOwnerKind.self) {
      throw ArgumentError.value(ownerKind, 'ownerKind', 'self is required');
    }
    if (!_isCanonicalCivilInstant(sourceDate)) {
      throw ArgumentError.value(
        sourceDate,
        'sourceDate',
        'canonical UTC civil date required',
      );
    }
    if (!_isCanonicalCivilInstant(deadlineDate)) {
      throw ArgumentError.value(
        deadlineDate,
        'deadlineDate',
        'canonical UTC civil date required',
      );
    }
    if (legalYear < 1900 || legalYear > 9999) {
      throw RangeError.range(legalYear, 1900, 9999, 'legalYear');
    }
    if (!_isCanonicalUuidV4(expectedSnapshotId)) {
      throw ArgumentError.value(
        expectedSnapshotId,
        'expectedSnapshotId',
        'canonical UUIDv4 required',
      );
    }
    if (expectedPreviousReferenceId != null &&
        !_isCanonicalUuidV4(expectedPreviousReferenceId)) {
      throw ArgumentError.value(
        expectedPreviousReferenceId,
        'expectedPreviousReferenceId',
        'canonical UUIDv4 required',
      );
    }
    return LppCapitalNoticeReviewConfirmation._(
      ownerKind: ownerKind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      deadlineDate: deadlineDate,
      expectedSnapshotId: expectedSnapshotId,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }

  const LppCapitalNoticeReviewConfirmation._({
    required this.ownerKind,
    required this.sourceDate,
    required this.legalYear,
    required this.deadlineDate,
    required this.expectedSnapshotId,
    required this.expectedPreviousReferenceId,
  });

  final LppEvidenceOwnerKind ownerKind;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime deadlineDate;
  final String expectedSnapshotId;
  final String? expectedPreviousReferenceId;
}

final class LppCapitalNoticeReceipt {
  const LppCapitalNoticeReceipt({
    required this.referenceId,
    required this.snapshotId,
    required this.confirmedAt,
  });

  final String referenceId;
  final String snapshotId;
  final DateTime confirmedAt;
  String get kind => LppCapitalNoticeDeadline.kind;
  LppEvidenceOwnerKind get ownerKind => LppEvidenceOwnerKind.self;
}

final class LppRegulationAcquisitionCandidate {
  factory LppRegulationAcquisitionCandidate({
    String? expectedPreviousReferenceId,
  }) {
    if (expectedPreviousReferenceId != null &&
        !_isCanonicalUuidV4(expectedPreviousReferenceId)) {
      throw ArgumentError.value(
        expectedPreviousReferenceId,
        'expectedPreviousReferenceId',
        'canonical UUIDv4 required',
      );
    }
    return LppRegulationAcquisitionCandidate._(
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }

  const LppRegulationAcquisitionCandidate._({
    required this.expectedPreviousReferenceId,
  });

  final String? expectedPreviousReferenceId;
}

enum LppFundRelationship {
  currentFund('currentFund'),
  uncertain('uncertain'),
  formerOrOther('formerOrOther');

  const LppFundRelationship(this.wireName);

  final String wireName;

  static LppFundRelationship? fromWireName(Object? raw) => switch (raw) {
        'currentFund' => currentFund,
        'uncertain' => uncertain,
        'formerOrOther' => formerOrOther,
        _ => null,
      };
}

final class LppRegulationReviewConfirmation {
  factory LppRegulationReviewConfirmation({
    required LppEvidenceOwnerKind ownerKind,
    required DateTime sourceDate,
    required int legalYear,
    required LppFundRelationship fundRelationship,
    String? expectedPreviousReferenceId,
  }) {
    if (ownerKind != LppEvidenceOwnerKind.self) {
      throw ArgumentError.value(ownerKind, 'ownerKind', 'self is required');
    }
    if (!_isCanonicalCivilInstant(sourceDate)) {
      throw ArgumentError.value(
        sourceDate,
        'sourceDate',
        'canonical UTC civil date required',
      );
    }
    if (legalYear < 1900 || legalYear > 9999) {
      throw RangeError.range(legalYear, 1900, 9999, 'legalYear');
    }
    if (expectedPreviousReferenceId != null &&
        !_isCanonicalUuidV4(expectedPreviousReferenceId)) {
      throw ArgumentError.value(
        expectedPreviousReferenceId,
        'expectedPreviousReferenceId',
        'canonical UUIDv4 required',
      );
    }
    return LppRegulationReviewConfirmation._(
      ownerKind: ownerKind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      fundRelationship: fundRelationship,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
  }

  const LppRegulationReviewConfirmation._({
    required this.ownerKind,
    required this.sourceDate,
    required this.legalYear,
    required this.fundRelationship,
    required this.expectedPreviousReferenceId,
  });

  final LppEvidenceOwnerKind ownerKind;
  final DateTime sourceDate;
  final int legalYear;
  final LppFundRelationship fundRelationship;
  final String? expectedPreviousReferenceId;
}

final class LppRegulationReceipt {
  const LppRegulationReceipt({
    required this.referenceId,
    required this.confirmedAt,
  });

  final String referenceId;
  final DateTime confirmedAt;
  String get kind => LppRegulationReference.kind;
  LppEvidenceOwnerKind get ownerKind => LppEvidenceOwnerKind.self;
}

/// Minimal acknowledgement returned only after a strict LPP snapshot is
/// durably accepted and published by the ledger.
///
/// The receipt deliberately has no JSON representation: document references
/// persist only its opaque snapshot identity, owner and document kind. Values,
/// extraction identifiers and source material never cross that boundary.
final class LppReviewReceipt {
  LppReviewReceipt({
    required this.snapshotId,
    required this.ownerKind,
    required Set<LppEvidenceFactKey> factKeys,
  }) : factKeys = Set.unmodifiable(
          Set<LppEvidenceFactKey>.of(factKeys),
        );

  final String snapshotId;
  final LppEvidenceOwnerKind ownerKind;
  final Set<LppEvidenceFactKey> factKeys;
}

class LppEvidenceFact {
  const LppEvidenceFact({
    required this.value,
    required this.unit,
    required this.profileOwnerId,
    required this.actorProfileOwnerId,
    this.ownerKind = LppEvidenceOwnerKind.self,
    this.authorizationMode = LppEvidenceAuthorizationMode.self,
    required this.source,
    required this.sourceDate,
    required this.updatedAt,
  });

  final double value;
  final LppEvidenceUnit unit;
  final String profileOwnerId;
  final String actorProfileOwnerId;
  final LppEvidenceOwnerKind ownerKind;
  final LppEvidenceAuthorizationMode authorizationMode;
  String? get authorizationGrantId => null;
  final String source;
  final DateTime? sourceDate;
  final DateTime updatedAt;

  LppEvidenceStatus get status => source == 'certificate' && sourceDate == null
      ? LppEvidenceStatus.availableNeedsConfirmation
      : LppEvidenceStatus.available;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value,
        'unit': unit.wireName,
        'owner': <String, dynamic>{
          'kind': ownerKind.wireName,
          'profileOwnerId': profileOwnerId,
        },
        'actor': <String, dynamic>{
          'profileOwnerId': actorProfileOwnerId,
        },
        'authorization': <String, dynamic>{
          'mode': authorizationMode.wireName,
          'grantId': null,
        },
        'provenance': <String, dynamic>{
          'source': source,
          'sourceDate': sourceDate?.toIso8601String().split('T').first,
          'updatedAt': updatedAt.toUtc().toIso8601String(),
        },
      };

  static LppEvidenceFact? fromJson(
    Map<String, dynamic> json, {
    required LppEvidenceFactKey key,
    LppEvidenceOwnerKind? expectedOwnerKind,
  }) {
    if (json.keys.toSet().difference(const {
          'value',
          'unit',
          'owner',
          'actor',
          'authorization',
          'provenance',
        }).isNotEmpty ||
        json.length != 6) {
      return null;
    }
    final value = json['value'];
    final unitName = json['unit'];
    final owner = json['owner'];
    final actor = json['actor'];
    final authorization = json['authorization'];
    final provenance = json['provenance'];
    if (value is! num ||
        !value.toDouble().isFinite ||
        value < 0 ||
        unitName != key.unit.wireName ||
        owner is! Map ||
        actor is! Map ||
        authorization is! Map ||
        provenance is! Map) {
      return null;
    }
    if (key.unit == LppEvidenceUnit.ratio && value > 1) return null;
    final ownerMap = Map<String, dynamic>.from(owner);
    final actorMap = Map<String, dynamic>.from(actor);
    final authorizationMap = Map<String, dynamic>.from(authorization);
    final provenanceMap = Map<String, dynamic>.from(provenance);
    final ownerKind = LppEvidenceOwnerKind.fromWireName(ownerMap['kind']);
    final authorizationMode = LppEvidenceAuthorizationMode.fromWireName(
      authorizationMap['mode'],
    );
    if (ownerMap.length != 2 ||
        ownerKind == null ||
        (expectedOwnerKind != null && ownerKind != expectedOwnerKind) ||
        ownerMap['profileOwnerId'] is! String ||
        !_isPseudonymousToken(ownerMap['profileOwnerId'] as String) ||
        actorMap.length != 1 ||
        actorMap['profileOwnerId'] is! String ||
        !_isPseudonymousToken(actorMap['profileOwnerId'] as String) ||
        authorizationMap.length != 2 ||
        authorizationMode == null ||
        authorizationMap['grantId'] != null ||
        provenanceMap.length != 3 ||
        !provenanceMap.containsKey('sourceDate') ||
        (provenanceMap['source'] != 'certificate' &&
            provenanceMap['source'] != 'userInput')) {
      return null;
    }
    final expectedAuthorization = ownerKind == LppEvidenceOwnerKind.self
        ? LppEvidenceAuthorizationMode.self
        : LppEvidenceAuthorizationMode.manualPartnerDeclaration;
    final ownerId = ownerMap['profileOwnerId'] as String;
    final actorId = actorMap['profileOwnerId'] as String;
    if (authorizationMode != expectedAuthorization ||
        (ownerKind == LppEvidenceOwnerKind.self && actorId != ownerId) ||
        (ownerKind == LppEvidenceOwnerKind.manualPartner &&
            actorId == ownerId)) {
      return null;
    }
    final updatedAt = _parseCanonicalUtcInstant(provenanceMap['updatedAt']);
    final rawSourceDate = provenanceMap['sourceDate'];
    final sourceDate = _parseCanonicalCivilDate(rawSourceDate);
    if (updatedAt == null ||
        (rawSourceDate != null && sourceDate == null) ||
        (provenanceMap['source'] == 'userInput' && rawSourceDate != null)) {
      return null;
    }
    return LppEvidenceFact(
      value: value.toDouble(),
      unit: key.unit,
      profileOwnerId: ownerId,
      actorProfileOwnerId: actorId,
      ownerKind: ownerKind,
      authorizationMode: authorizationMode,
      source: provenanceMap['source'] as String,
      sourceDate: sourceDate,
      updatedAt: updatedAt,
    );
  }
}

final class LppCapitalNoticeDeadline {
  const LppCapitalNoticeDeadline._({
    required this.referenceId,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    required this.deadlineDate,
  });

  static const kind = 'lppCapitalNotice';

  final String referenceId;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  final DateTime deadlineDate;

  static LppCapitalNoticeDeadline create({
    required String referenceId,
    required DateTime sourceDate,
    required int legalYear,
    required DateTime confirmedAt,
    required DateTime deadlineDate,
  }) {
    final parsed = fromJson(<String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': LppEvidenceOwnerKind.self.wireName,
      'source': 'certificate',
      'sourceDate': _encodeCivilDate(sourceDate),
      'legalYear': legalYear,
      'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      'deadlineDate': _encodeCivilDate(deadlineDate),
    }, now: () => confirmedAt);
    if (parsed == null) {
      throw ArgumentError('Invalid LPP capital notice deadline');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'referenceId': referenceId,
        'kind': kind,
        'ownerKind': LppEvidenceOwnerKind.self.wireName,
        'source': 'certificate',
        'sourceDate': _encodeCivilDate(sourceDate),
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'deadlineDate': _encodeCivilDate(deadlineDate),
      };

  static LppCapitalNoticeDeadline? fromJson(
    Map<String, dynamic> json, {
    DateTime Function()? now,
  }) {
    const allowedKeys = <String>{
      'referenceId',
      'kind',
      'ownerKind',
      'source',
      'sourceDate',
      'legalYear',
      'confirmedAt',
      'deadlineDate',
    };
    if (json.length != allowedKeys.length ||
        json.keys.toSet().difference(allowedKeys).isNotEmpty ||
        json['referenceId'] is! String ||
        !_isCanonicalUuidV4(json['referenceId'] as String) ||
        json['kind'] != kind ||
        json['ownerKind'] != LppEvidenceOwnerKind.self.wireName ||
        json['source'] != 'certificate' ||
        json['legalYear'] is! int ||
        (json['legalYear'] as int) < 1900 ||
        (json['legalYear'] as int) > 9999) {
      return null;
    }
    final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
    final confirmedAt = _parseCanonicalUtcInstant(json['confirmedAt']);
    final deadlineDate = _parseCanonicalCivilDate(json['deadlineDate']);
    final current = now?.call().toUtc();
    if (sourceDate == null ||
        confirmedAt == null ||
        deadlineDate == null ||
        (current != null &&
            (confirmedAt.isAfter(current) ||
                SwissCivilTime.isFutureCivilDate(
                  sourceDate,
                  now: current,
                )))) {
      return null;
    }
    return LppCapitalNoticeDeadline._(
      referenceId: json['referenceId'] as String,
      sourceDate: sourceDate,
      legalYear: json['legalYear'] as int,
      confirmedAt: confirmedAt,
      deadlineDate: deadlineDate,
    );
  }
}

final class LppRegulationReference {
  const LppRegulationReference._({
    required this.referenceId,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    required this.fundRelationship,
  });

  static const kind = 'lppRegulation';

  final String referenceId;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  final LppFundRelationship fundRelationship;

  static LppRegulationReference create({
    required String referenceId,
    required DateTime sourceDate,
    required int legalYear,
    required DateTime confirmedAt,
    required LppFundRelationship fundRelationship,
  }) {
    if (!_isCanonicalCivilInstant(sourceDate) || !confirmedAt.isUtc) {
      throw ArgumentError('Canonical UTC LPP regulation dates are required');
    }
    final parsed = fromJson(<String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': LppEvidenceOwnerKind.self.wireName,
      'source': 'certificate',
      'sourceDate': _encodeCivilDate(sourceDate),
      'legalYear': legalYear,
      'confirmedAt': confirmedAt.toIso8601String(),
      'fundRelationship': fundRelationship.wireName,
    }, now: () => confirmedAt);
    if (parsed == null) {
      throw ArgumentError('Invalid LPP regulation reference');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'referenceId': referenceId,
        'kind': kind,
        'ownerKind': LppEvidenceOwnerKind.self.wireName,
        'source': 'certificate',
        'sourceDate': _encodeCivilDate(sourceDate),
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toIso8601String(),
        'fundRelationship': fundRelationship.wireName,
      };

  static LppRegulationReference? fromJson(
    Map<String, dynamic> json, {
    DateTime Function()? now,
  }) {
    const allowedKeys = <String>{
      'referenceId',
      'kind',
      'ownerKind',
      'source',
      'sourceDate',
      'legalYear',
      'confirmedAt',
      'fundRelationship',
    };
    if (json.length != allowedKeys.length ||
        json.keys.toSet().difference(allowedKeys).isNotEmpty ||
        json['referenceId'] is! String ||
        !_isCanonicalUuidV4(json['referenceId'] as String) ||
        json['kind'] != kind ||
        json['ownerKind'] != LppEvidenceOwnerKind.self.wireName ||
        json['source'] != 'certificate' ||
        json['legalYear'] is! int ||
        (json['legalYear'] as int) < 1900 ||
        (json['legalYear'] as int) > 9999 ||
        LppFundRelationship.fromWireName(json['fundRelationship']) == null) {
      return null;
    }
    final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
    final confirmedAt = _parseCanonicalUtcInstant(json['confirmedAt']);
    final current = (now ?? DateTime.now)().toUtc();
    if (sourceDate == null ||
        confirmedAt == null ||
        confirmedAt.isAfter(current) ||
        SwissCivilTime.isFutureCivilDate(sourceDate, now: current)) {
      return null;
    }
    return LppRegulationReference._(
      referenceId: json['referenceId'] as String,
      sourceDate: sourceDate,
      legalYear: json['legalYear'] as int,
      confirmedAt: confirmedAt,
      fundRelationship:
          LppFundRelationship.fromWireName(json['fundRelationship'])!,
    );
  }
}

class LppEvidenceSnapshot {
  const LppEvidenceSnapshot({
    required this.snapshotId,
    required this.facts,
    this.independentFacts = const {},
    this.lppCapitalNoticeDeadline,
  });

  final String snapshotId;
  final Map<LppEvidenceFactKey, LppEvidenceFact> facts;
  final Map<LppEvidenceFactKey, LppEvidenceFact> independentFacts;
  final LppCapitalNoticeDeadline? lppCapitalNoticeDeadline;

  Iterable<LppEvidenceFact> get identityFacts =>
      facts.isNotEmpty ? facts.values : independentFacts.values;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'snapshotId': snapshotId,
        'facts': <String, dynamic>{
          for (final entry in facts.entries)
            entry.key.wireName: entry.value.toJson(),
        },
        if (independentFacts.isNotEmpty)
          'independentFacts': <String, dynamic>{
            for (final entry in independentFacts.entries)
              entry.key.wireName: entry.value.toJson(),
          },
        if (lppCapitalNoticeDeadline != null)
          'lppCapitalNoticeDeadline': lppCapitalNoticeDeadline!.toJson(),
      };

  static LppEvidenceSnapshot? fromJson(
    Map<String, dynamic> json, {
    required LppEvidenceOwnerKind expectedOwnerKind,
    DateTime Function()? now,
  }) {
    const allowedKeys = {
      'snapshotId',
      'facts',
      'independentFacts',
      'lppCapitalNoticeDeadline',
    };
    if ((json.length < 2 || json.length > 4) ||
        json.keys.toSet().difference(allowedKeys).isNotEmpty ||
        json['snapshotId'] is! String ||
        !_isCanonicalUuidV4(json['snapshotId'] as String) ||
        json['facts'] is! Map ||
        (json.containsKey('independentFacts') &&
            json['independentFacts'] is! Map) ||
        (json.containsKey('lppCapitalNoticeDeadline') &&
            (expectedOwnerKind != LppEvidenceOwnerKind.self ||
                json['lppCapitalNoticeDeadline'] is! Map))) {
      return null;
    }
    final facts = <LppEvidenceFactKey, LppEvidenceFact>{};
    String? ownerId;
    String? actorId;
    DateTime? acceptanceStamp;
    for (final entry in (json['facts'] as Map).entries) {
      final key = LppEvidenceFactKey.fromWireName(entry.key.toString());
      if (key == null || entry.value is! Map || facts.containsKey(key)) {
        return null;
      }
      final fact = LppEvidenceFact.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
        key: key,
        expectedOwnerKind: expectedOwnerKind,
      );
      if (fact == null) return null;
      ownerId ??= fact.profileOwnerId;
      actorId ??= fact.actorProfileOwnerId;
      acceptanceStamp ??= fact.updatedAt;
      if (fact.profileOwnerId != ownerId ||
          fact.actorProfileOwnerId != actorId ||
          fact.updatedAt.toUtc() != acceptanceStamp.toUtc()) {
        return null;
      }
      facts[key] = fact;
    }
    final independentFacts = <LppEvidenceFactKey, LppEvidenceFact>{};
    final rawIndependent = json['independentFacts'];
    if (rawIndependent is Map) {
      if (expectedOwnerKind != LppEvidenceOwnerKind.manualPartner) return null;
      for (final entry in rawIndependent.entries) {
        final key = LppEvidenceFactKey.fromWireName(entry.key.toString());
        if (key == null ||
            entry.value is! Map ||
            independentFacts.containsKey(key)) {
          return null;
        }
        final fact = LppEvidenceFact.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
          key: key,
          expectedOwnerKind: expectedOwnerKind,
        );
        if (fact == null || fact.source != 'userInput') return null;
        ownerId ??= fact.profileOwnerId;
        actorId ??= fact.actorProfileOwnerId;
        if (fact.profileOwnerId != ownerId ||
            fact.actorProfileOwnerId != actorId) {
          return null;
        }
        independentFacts[key] = fact;
      }
    }
    if (facts.isEmpty && independentFacts.isEmpty) return null;
    final rawCapitalNotice = json['lppCapitalNoticeDeadline'];
    final capitalNotice = rawCapitalNotice == null
        ? null
        : LppCapitalNoticeDeadline.fromJson(
            Map<String, dynamic>.from(rawCapitalNotice as Map),
            now: now,
          );
    if (rawCapitalNotice != null && capitalNotice == null) return null;
    return LppEvidenceSnapshot(
      snapshotId: json['snapshotId'] as String,
      facts: Map.unmodifiable(facts),
      independentFacts: Map.unmodifiable(independentFacts),
      lppCapitalNoticeDeadline: capitalNotice,
    );
  }
}

const legacyPartnerLppAnswerKeys = <String>{
  '_coach_conjoint_avoir_lpp',
  '_coach_conjoint_taux_conversion',
  '_coach_conjoint_lpp_source',
};

const _legacyPartnerLppReasonCodes = <String>{
  'untyped_legacy_partner_lpp',
};

class LppLegacyPartnerQuarantine {
  const LppLegacyPartnerQuarantine({
    required this.reasonCodes,
    required this.presentKeys,
    required this.quarantinedAt,
  });

  final List<String> reasonCodes;
  final List<String> presentKeys;
  final DateTime quarantinedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'legacySchemaVersion': 0,
        'reasonCodes': reasonCodes,
        'presentKeys': presentKeys,
        'quarantinedAt': quarantinedAt.toUtc().toIso8601String(),
      };

  static LppLegacyPartnerQuarantine? fromJson(Map<String, dynamic> json) {
    if (json.length != 4 ||
        json['legacySchemaVersion'] != 0 ||
        json['reasonCodes'] is! List ||
        json['presentKeys'] is! List) {
      return null;
    }
    final rawReasons = json['reasonCodes'] as List;
    final rawKeys = json['presentKeys'] as List;
    if (rawReasons.isEmpty ||
        rawKeys.isEmpty ||
        rawReasons.any((value) =>
            value is! String ||
            !_legacyPartnerLppReasonCodes.contains(value)) ||
        rawKeys.any((value) =>
            value is! String || !legacyPartnerLppAnswerKeys.contains(value))) {
      return null;
    }
    final reasonCodes = rawReasons.cast<String>();
    final presentKeys = rawKeys.cast<String>();
    if (reasonCodes.toSet().length != reasonCodes.length ||
        presentKeys.toSet().length != presentKeys.length) {
      return null;
    }
    final quarantinedAt = _parseCanonicalUtcInstant(json['quarantinedAt']);
    if (quarantinedAt == null) return null;
    return LppLegacyPartnerQuarantine(
      reasonCodes: List.unmodifiable(reasonCodes),
      presentKeys: List.unmodifiable(presentKeys),
      quarantinedAt: quarantinedAt,
    );
  }
}

class LppEvidenceRoot {
  const LppEvidenceRoot({
    required this.self,
    this.manualPartner,
    this.legacyPartnerQuarantine,
    this.selfRegulationReference,
  });

  final LppEvidenceSnapshot? self;
  final LppEvidenceSnapshot? manualPartner;
  final LppLegacyPartnerQuarantine? legacyPartnerQuarantine;
  final LppRegulationReference? selfRegulationReference;

  String toJsonString() => jsonEncode(<String, dynamic>{
        'schemaVersion': 2,
        'self': self?.toJson(),
        'manualPartner': manualPartner?.toJson(),
        'legacyPartnerQuarantine': legacyPartnerQuarantine?.toJson(),
        'selfRegulationReference': selfRegulationReference?.toJson(),
      });

  static LppEvidenceRoot? fromJsonString(
    Object? raw, {
    DateTime Function()? now,
  }) {
    if (raw is! String || raw == '__secure__') return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final root = Map<String, dynamic>.from(decoded);
      final schemaVersion = root['schemaVersion'];
      final expectedKeys = switch (schemaVersion) {
        1 => _legacyRootKeys,
        2 => _rootKeys,
        _ => const <String>{},
      };
      if (root.length != expectedKeys.length ||
          root.keys.toSet().difference(expectedKeys).isNotEmpty ||
          !root.containsKey('self') ||
          !root.containsKey('manualPartner') ||
          !root.containsKey('legacyPartnerQuarantine') ||
          (schemaVersion == 2 &&
              !root.containsKey('selfRegulationReference'))) {
        return null;
      }
      Object? rawSelf = root['self'];
      final rawManualPartner = root['manualPartner'];
      final rawQuarantine = root['legacyPartnerQuarantine'];
      final rawRegulation = root['selfRegulationReference'];
      if (rawSelf != null && rawSelf is! Map ||
          rawManualPartner != null && rawManualPartner is! Map ||
          rawQuarantine != null && rawQuarantine is! Map ||
          rawRegulation != null && rawRegulation is! Map) {
        return null;
      }
      if (schemaVersion == 1 && rawSelf is Map) {
        final legacySelf = Map<String, dynamic>.from(rawSelf);
        if (legacySelf.containsKey('lppRegulationReference')) {
          final nestedRegulation = legacySelf['lppRegulationReference'];
          if (nestedRegulation is! Map ||
              !_isValidLegacyLppRegulationReference(
                Map<String, dynamic>.from(nestedRegulation),
                now: now,
              )) {
            return null;
          }
          legacySelf.remove('lppRegulationReference');
        }
        rawSelf = legacySelf;
      }
      final self = rawSelf == null
          ? null
          : LppEvidenceSnapshot.fromJson(
              Map<String, dynamic>.from(rawSelf as Map),
              expectedOwnerKind: LppEvidenceOwnerKind.self,
              now: now,
            );
      final manualPartner = rawManualPartner == null
          ? null
          : LppEvidenceSnapshot.fromJson(
              Map<String, dynamic>.from(rawManualPartner as Map),
              expectedOwnerKind: LppEvidenceOwnerKind.manualPartner,
              now: now,
            );
      final quarantine = rawQuarantine == null
          ? null
          : LppLegacyPartnerQuarantine.fromJson(
              Map<String, dynamic>.from(rawQuarantine as Map),
            );
      final regulation = rawRegulation == null
          ? null
          : LppRegulationReference.fromJson(
              Map<String, dynamic>.from(rawRegulation as Map),
              now: now,
            );
      if (rawSelf != null && self == null ||
          rawManualPartner != null && manualPartner == null ||
          rawQuarantine != null && quarantine == null ||
          rawRegulation != null && regulation == null) {
        return null;
      }
      if (self != null &&
          manualPartner != null &&
          manualPartner.identityFacts.first.actorProfileOwnerId !=
              self.identityFacts.first.profileOwnerId) {
        return null;
      }
      return LppEvidenceRoot(
        self: self,
        manualPartner: manualPartner,
        legacyPartnerQuarantine: quarantine,
        selfRegulationReference: regulation,
      );
    } on Object {
      return null;
    }
  }
}

const _legacyRootKeys = <String>{
  'schemaVersion',
  'self',
  'manualPartner',
  'legacyPartnerQuarantine',
};

const _rootKeys = <String>{
  'schemaVersion',
  'self',
  'manualPartner',
  'legacyPartnerQuarantine',
  'selfRegulationReference',
};

const _zeroSha256 =
    '0000000000000000000000000000000000000000000000000000000000000000';

bool _isValidLegacyLppRegulationReference(
  Map<String, dynamic> json, {
  DateTime Function()? now,
}) {
  const allowedKeys = <String>{
    'referenceId',
    'kind',
    'ownerKind',
    'source',
    'sourceDate',
    'legalYear',
    'confirmedAt',
  };
  if (json.length != allowedKeys.length ||
      json.keys.toSet().difference(allowedKeys).isNotEmpty ||
      json['referenceId'] is! String ||
      !_isCanonicalUuidV4(json['referenceId'] as String) ||
      json['kind'] != LppRegulationReference.kind ||
      json['ownerKind'] != LppEvidenceOwnerKind.self.wireName ||
      json['source'] != 'certificate' ||
      json['legalYear'] is! int ||
      (json['legalYear'] as int) < 1900 ||
      (json['legalYear'] as int) > 9999) {
    return false;
  }
  final sourceDate = _parseCanonicalCivilDate(json['sourceDate']);
  final confirmedAt = _parseCanonicalUtcInstant(json['confirmedAt']);
  final current = (now ?? DateTime.now)().toUtc();
  return sourceDate != null &&
      confirmedAt != null &&
      !confirmedAt.isAfter(current) &&
      !SwissCivilTime.isFutureCivilDate(sourceDate, now: current);
}

DateTime? _parseCanonicalCivilDate(Object? raw) {
  if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final canonical = DateTime.utc(parsed.year, parsed.month, parsed.day);
  final encoded = '${canonical.year.toString().padLeft(4, '0')}-'
      '${canonical.month.toString().padLeft(2, '0')}-'
      '${canonical.day.toString().padLeft(2, '0')}';
  return encoded == raw ? canonical : null;
}

String _encodeCivilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _isCanonicalCivilInstant(DateTime value) =>
    value.isUtc &&
    value.hour == 0 &&
    value.minute == 0 &&
    value.second == 0 &&
    value.millisecond == 0 &&
    value.microsecond == 0;

DateTime? _parseCanonicalUtcInstant(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || parsed.toUtc().toIso8601String() != raw) return null;
  return parsed.toUtc();
}

class LppEvidenceSelector {
  const LppEvidenceSelector._();

  static LppEvidenceSnapshot? selectSelf(
    Object? rawRoot, {
    DateTime Function()? now,
  }) {
    final snapshot = LppEvidenceRoot.fromJsonString(
      rawRoot,
      now: now,
    )?.self;
    if (snapshot == null) return null;
    return _selectCurrent(snapshot, now: now);
  }

  static LppEvidenceSnapshot? selectManualPartner(
    Object? rawRoot, {
    required String expectedOwnerId,
    DateTime Function()? now,
  }) {
    if (!_isPseudonymousToken(expectedOwnerId)) return null;
    final snapshot = _manualPartnerSnapshot(rawRoot, now: now);
    if (snapshot == null ||
        snapshot.facts.values.any(
          (fact) => fact.profileOwnerId != expectedOwnerId,
        )) {
      return null;
    }
    return _selectCurrent(snapshot, now: now);
  }

  static String? manualPartnerOwnerId(
    Object? rawRoot, {
    DateTime Function()? now,
  }) =>
      _manualPartnerSnapshot(rawRoot, now: now)
          ?.identityFacts
          .first
          .profileOwnerId;

  static String? manualPartnerSnapshotId(
    Object? rawRoot, {
    DateTime Function()? now,
  }) =>
      _manualPartnerSnapshot(rawRoot, now: now)?.snapshotId;

  static LppEvidenceSnapshot? _manualPartnerSnapshot(
    Object? rawRoot, {
    DateTime Function()? now,
  }) =>
      LppEvidenceRoot.fromJsonString(rawRoot, now: now)?.manualPartner;

  static LppEvidenceSnapshot? _selectCurrent(
    LppEvidenceSnapshot snapshot, {
    DateTime Function()? now,
  }) {
    final current = (now ?? DateTime.now)().toUtc();
    for (final fact in <LppEvidenceFact>[
      ...snapshot.facts.values,
      ...snapshot.independentFacts.values,
    ]) {
      final sourceDate = fact.sourceDate;
      if (fact.updatedAt.toUtc().isAfter(current) ||
          (sourceDate != null &&
              SwissCivilTime.isFutureCivilDate(sourceDate, now: current))) {
        return null;
      }
    }
    return snapshot;
  }
}

bool _isCanonicalUuidV4(String value) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);

bool _isPseudonymousToken(String value) => _isCanonicalUuidV4(value);
