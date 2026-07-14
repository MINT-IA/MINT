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
  }) : subject = LppEvidenceOwnerKind.self;

  const LppReviewConfirmation.manualPartner({
    required this.facts,
    required this.sourceDate,
  }) : subject = LppEvidenceOwnerKind.manualPartner;

  final Map<LppEvidenceFactKey, LppReviewedFact> facts;
  final DateTime? sourceDate;
  final LppEvidenceOwnerKind subject;
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

  static LppEvidenceSnapshot? fromJson(
    Map<String, dynamic> json, {
    required LppEvidenceOwnerKind expectedOwnerKind,
  }) {
    if (json.length != 2 ||
        json['snapshotId'] is! String ||
        !_isCanonicalUuidV4(json['snapshotId'] as String) ||
        json['facts'] is! Map) {
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
    if (facts.isEmpty) return null;
    return LppEvidenceSnapshot(
      snapshotId: json['snapshotId'] as String,
      facts: Map.unmodifiable(facts),
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
  });

  final LppEvidenceSnapshot? self;
  final LppEvidenceSnapshot? manualPartner;
  final LppLegacyPartnerQuarantine? legacyPartnerQuarantine;

  String toJsonString() => jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'self': self?.toJson(),
        'manualPartner': manualPartner?.toJson(),
        'legacyPartnerQuarantine': legacyPartnerQuarantine?.toJson(),
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
          !root.containsKey('manualPartner') ||
          !root.containsKey('legacyPartnerQuarantine')) {
        return null;
      }
      final rawSelf = root['self'];
      final rawManualPartner = root['manualPartner'];
      final rawQuarantine = root['legacyPartnerQuarantine'];
      if (rawSelf != null && rawSelf is! Map ||
          rawManualPartner != null && rawManualPartner is! Map ||
          rawQuarantine != null && rawQuarantine is! Map) {
        return null;
      }
      final self = rawSelf == null
          ? null
          : LppEvidenceSnapshot.fromJson(
              Map<String, dynamic>.from(rawSelf as Map),
              expectedOwnerKind: LppEvidenceOwnerKind.self,
            );
      final manualPartner = rawManualPartner == null
          ? null
          : LppEvidenceSnapshot.fromJson(
              Map<String, dynamic>.from(rawManualPartner as Map),
              expectedOwnerKind: LppEvidenceOwnerKind.manualPartner,
            );
      final quarantine = rawQuarantine == null
          ? null
          : LppLegacyPartnerQuarantine.fromJson(
              Map<String, dynamic>.from(rawQuarantine as Map),
            );
      if (rawSelf != null && self == null ||
          rawManualPartner != null && manualPartner == null ||
          rawQuarantine != null && quarantine == null) {
        return null;
      }
      if (self != null &&
          manualPartner != null &&
          manualPartner.facts.values.first.actorProfileOwnerId !=
              self.facts.values.first.profileOwnerId) {
        return null;
      }
      return LppEvidenceRoot(
        self: self,
        manualPartner: manualPartner,
        legacyPartnerQuarantine: quarantine,
      );
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

Map<String, dynamic>? _decodeLppRootEnvelope(Object? raw) {
  if (raw is! String || raw == '__secure__') return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    if (root.length != _rootKeys.length ||
        root.keys.toSet().difference(_rootKeys).isNotEmpty ||
        root['schemaVersion'] != 1 ||
        !root.containsKey('self') ||
        !root.containsKey('manualPartner') ||
        !root.containsKey('legacyPartnerQuarantine')) {
      return null;
    }
    return root;
  } on Object {
    return null;
  }
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
    final root = _decodeLppRootEnvelope(rawRoot);
    final rawSelf = root?['self'];
    if (rawSelf is! Map) return null;
    final snapshot = LppEvidenceSnapshot.fromJson(
      Map<String, dynamic>.from(rawSelf),
      expectedOwnerKind: LppEvidenceOwnerKind.self,
    );
    if (snapshot == null) return null;
    return _selectCurrent(snapshot, now: now);
  }

  static LppEvidenceSnapshot? selectManualPartner(
    Object? rawRoot, {
    required String expectedOwnerId,
    DateTime Function()? now,
  }) {
    if (!_isPseudonymousToken(expectedOwnerId)) return null;
    final snapshot = _manualPartnerSnapshot(rawRoot);
    if (snapshot == null ||
        snapshot.facts.values.any(
          (fact) => fact.profileOwnerId != expectedOwnerId,
        )) {
      return null;
    }
    return _selectCurrent(snapshot, now: now);
  }

  static String? manualPartnerOwnerId(Object? rawRoot) =>
      _manualPartnerSnapshot(rawRoot)
          ?.facts
          .values
          .first
          .profileOwnerId;

  static LppEvidenceSnapshot? _manualPartnerSnapshot(Object? rawRoot) {
    final root = _decodeLppRootEnvelope(rawRoot);
    final rawManualPartner = root?['manualPartner'];
    if (rawManualPartner is! Map) return null;
    final snapshot = LppEvidenceSnapshot.fromJson(
      Map<String, dynamic>.from(rawManualPartner),
      expectedOwnerKind: LppEvidenceOwnerKind.manualPartner,
    );
    if (snapshot == null) return null;
    final rawSelf = root?['self'];
    if (rawSelf != null) {
      if (rawSelf is! Map) return null;
      final self = LppEvidenceSnapshot.fromJson(
        Map<String, dynamic>.from(rawSelf),
        expectedOwnerKind: LppEvidenceOwnerKind.self,
      );
      if (self == null ||
          snapshot.facts.values.first.actorProfileOwnerId !=
              self.facts.values.first.profileOwnerId) {
        return null;
      }
    }
    return snapshot;
  }

  static LppEvidenceSnapshot? _selectCurrent(
    LppEvidenceSnapshot snapshot, {
    DateTime Function()? now,
  }) {
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
