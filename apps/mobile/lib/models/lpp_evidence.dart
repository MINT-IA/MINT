import 'dart:convert';

enum LppEvidenceUnit {
  chf('CHF'),
  chfPerYear('CHF/year'),
  chfLumpSum('CHF/lump-sum'),
  ratio('ratio');

  const LppEvidenceUnit(this.wireName);

  final String wireName;
}

enum LppEvidenceStatus { available, availableNeedsConfirmation }

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

  static LppEvidenceFactKey? fromWireName(String value) {
    for (final key in values) {
      if (key.wireName == value) return key;
    }
    return null;
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

class LppReviewConfirmation {
  const LppReviewConfirmation.self({
    required this.facts,
    required this.sourceDate,
  });

  final Map<LppEvidenceFactKey, LppReviewedFact> facts;
  final DateTime? sourceDate;
}

class LppEvidenceFact {
  const LppEvidenceFact({
    required this.value,
    required this.unit,
    required this.profileOwnerId,
    required this.actorProfileOwnerId,
    required this.source,
    required this.sourceDate,
    required this.updatedAt,
  });

  final double value;
  final LppEvidenceUnit unit;
  final String profileOwnerId;
  final String actorProfileOwnerId;
  final String source;
  final DateTime? sourceDate;
  final DateTime updatedAt;

  LppEvidenceStatus get status =>
      source == 'certificate' && sourceDate == null
          ? LppEvidenceStatus.availableNeedsConfirmation
          : LppEvidenceStatus.available;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value,
        'unit': unit.wireName,
        'owner': <String, dynamic>{
          'kind': 'self',
          'profileOwnerId': profileOwnerId,
        },
        'actor': <String, dynamic>{
          'profileOwnerId': actorProfileOwnerId,
        },
        'authorization': const <String, dynamic>{
          'mode': 'self',
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
    if (ownerMap.length != 2 ||
        ownerMap['kind'] != 'self' ||
        ownerMap['profileOwnerId'] is! String ||
        !_isPseudonymousToken(ownerMap['profileOwnerId'] as String) ||
        actorMap.length != 1 ||
        actorMap['profileOwnerId'] != ownerMap['profileOwnerId'] ||
        authorizationMap.length != 2 ||
        authorizationMap['mode'] != 'self' ||
        authorizationMap['grantId'] != null ||
        provenanceMap.length != 3 ||
        !provenanceMap.containsKey('sourceDate') ||
        (provenanceMap['source'] != 'certificate' &&
            provenanceMap['source'] != 'userInput')) {
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
      profileOwnerId: ownerMap['profileOwnerId'] as String,
      actorProfileOwnerId: actorMap['profileOwnerId'] as String,
      source: provenanceMap['source'] as String,
      sourceDate: sourceDate,
      updatedAt: updatedAt,
    );
  }
}

class LppEvidenceSnapshot {
  const LppEvidenceSnapshot({
    required this.snapshotId,
    required this.facts,
  });

  final String snapshotId;
  final Map<LppEvidenceFactKey, LppEvidenceFact> facts;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'snapshotId': snapshotId,
        'facts': <String, dynamic>{
          for (final entry in facts.entries)
            entry.key.wireName: entry.value.toJson(),
        },
      };

  static LppEvidenceSnapshot? fromJson(Map<String, dynamic> json) {
    if (json.length != 2 ||
        json['snapshotId'] is! String ||
        !_isCanonicalUuidV4(json['snapshotId'] as String) ||
        json['facts'] is! Map) {
      return null;
    }
    final facts = <LppEvidenceFactKey, LppEvidenceFact>{};
    String? ownerId;
    DateTime? acceptanceStamp;
    for (final entry in (json['facts'] as Map).entries) {
      final key = LppEvidenceFactKey.fromWireName(entry.key.toString());
      if (key == null || entry.value is! Map || facts.containsKey(key)) {
        return null;
      }
      final fact = LppEvidenceFact.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
        key: key,
      );
      if (fact == null) return null;
      ownerId ??= fact.profileOwnerId;
      acceptanceStamp ??= fact.updatedAt;
      if (fact.profileOwnerId != ownerId ||
          fact.actorProfileOwnerId != ownerId ||
          fact.updatedAt.toUtc() != acceptanceStamp.toUtc()) {
        return null;
      }
      facts[key] = fact;
    }
    if (facts.isEmpty) return null;
    return LppEvidenceSnapshot(
      snapshotId: json['snapshotId'] as String,
      facts: Map.unmodifiable(facts),
    );
  }
}

class LppEvidenceRoot {
  const LppEvidenceRoot({required this.self});

  final LppEvidenceSnapshot? self;

  String toJsonString() => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'self': self?.toJson(),
        'manualPartner': null,
        'legacyPartnerQuarantine': null,
      });

  static LppEvidenceRoot? fromJsonString(Object? raw) {
    if (raw is! String || raw == '__secure__') return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final root = Map<String, dynamic>.from(decoded);
      if (root.length != _rootKeys.length ||
          root.keys.toSet().difference(_rootKeys).isNotEmpty ||
          root['schemaVersion'] != 1 ||
          !root.containsKey('self') ||
          root['manualPartner'] != null ||
          root['legacyPartnerQuarantine'] != null) {
        return null;
      }
      final rawSelf = root['self'];
      if (rawSelf == null) return const LppEvidenceRoot(self: null);
      if (rawSelf is! Map) return null;
      final self = LppEvidenceSnapshot.fromJson(
        Map<String, dynamic>.from(rawSelf),
      );
      return self == null ? null : LppEvidenceRoot(self: self);
    } on Object {
      return null;
    }
  }
}

const _rootKeys = <String>{
  'schemaVersion',
  'self',
  'manualPartner',
  'legacyPartnerQuarantine',
};

DateTime? _parseCanonicalCivilDate(Object? raw) {
  if (raw is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
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
    final snapshot = LppEvidenceRoot.fromJsonString(rawRoot)?.self;
    if (snapshot == null) return null;
    final current = (now ?? DateTime.now)().toUtc();
    final currentDay = DateTime.utc(current.year, current.month, current.day);
    for (final fact in snapshot.facts.values) {
      final sourceDate = fact.sourceDate;
      if (fact.updatedAt.toUtc().isAfter(current) ||
          (sourceDate != null &&
              DateTime.utc(sourceDate.year, sourceDate.month, sourceDate.day)
                  .isAfter(currentDay))) {
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
