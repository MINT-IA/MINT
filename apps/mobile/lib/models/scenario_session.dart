import 'package:uuid/uuid.dart';

const scenarioSessionSchemaVersion = 1;

enum ScenarioKind { epl, renteCapital }

enum ScenarioStatus { draft, calculated, completed, abandoned }

enum RenteCapitalInputMode { estimate, certificate }

sealed class ScenarioLevers {
  const ScenarioLevers();

  ScenarioKind get kind;

  Map<String, Object?> toJson();

  static ScenarioLevers fromJson(
    ScenarioKind kind,
    Map<String, dynamic> json,
  ) =>
      switch (kind) {
        ScenarioKind.epl => EplScenarioLevers.fromJson(json),
        ScenarioKind.renteCapital => RenteCapitalScenarioLevers.fromJson(json),
      };
}

final class EplScenarioLevers extends ScenarioLevers {
  const EplScenarioLevers({
    required this.requestedWithdrawal,
    this.lppBalanceOverride,
    this.ageOverride,
    this.cantonOverride,
    this.recentBuybackOverride,
    this.yearsSinceBuybackOverride,
  });

  factory EplScenarioLevers.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'requestedWithdrawal',
      'lppBalanceOverride',
      'ageOverride',
      'cantonOverride',
      'recentBuybackOverride',
      'yearsSinceBuybackOverride',
    });
    return EplScenarioLevers(
      requestedWithdrawal: _requiredNonNegativeDouble(
        json['requestedWithdrawal'],
        'requestedWithdrawal',
      ),
      lppBalanceOverride: _optionalNonNegativeDouble(
        json['lppBalanceOverride'],
        'lppBalanceOverride',
      ),
      ageOverride:
          _optionalIntInRange(json['ageOverride'], 'ageOverride', 18, 99),
      cantonOverride: _optionalCanton(json['cantonOverride']),
      recentBuybackOverride:
          _optionalBool(json['recentBuybackOverride'], 'recentBuybackOverride'),
      yearsSinceBuybackOverride: _optionalIntInRange(
        json['yearsSinceBuybackOverride'],
        'yearsSinceBuybackOverride',
        0,
        100,
      ),
    );
  }

  @override
  ScenarioKind get kind => ScenarioKind.epl;

  final double requestedWithdrawal;
  final double? lppBalanceOverride;
  final int? ageOverride;
  final String? cantonOverride;
  final bool? recentBuybackOverride;
  final int? yearsSinceBuybackOverride;

  @override
  Map<String, Object?> toJson() => {
        'requestedWithdrawal': requestedWithdrawal,
        if (lppBalanceOverride != null)
          'lppBalanceOverride': lppBalanceOverride,
        if (ageOverride != null) 'ageOverride': ageOverride,
        if (cantonOverride != null) 'cantonOverride': cantonOverride,
        if (recentBuybackOverride != null)
          'recentBuybackOverride': recentBuybackOverride,
        if (yearsSinceBuybackOverride != null)
          'yearsSinceBuybackOverride': yearsSinceBuybackOverride,
      };
}

final class RenteCapitalScenarioLevers extends ScenarioLevers {
  const RenteCapitalScenarioLevers({
    required this.retirementAge,
    required this.annualBuyback,
    required this.hasEpl,
    required this.eplAmount,
    required this.returnRatePercent,
    required this.withdrawalRatePercent,
    required this.inflationPercent,
    required this.lifeExpectancy,
    this.inputMode = RenteCapitalInputMode.estimate,
    this.currentAgeOverride,
    this.grossAnnualSalaryOverride,
    this.lppTotalOverride,
    this.lppObligatoryOverride,
    this.lppExtraMandatoryOverride,
    this.annualPensionOverride,
    this.obligatoryConversionRateOverride,
    this.extraMandatoryConversionRateOverride,
    this.cantonOverride,
    this.marriedOverride,
  });

  factory RenteCapitalScenarioLevers.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'retirementAge',
      'annualBuyback',
      'hasEpl',
      'eplAmount',
      'returnRatePercent',
      'withdrawalRatePercent',
      'inflationPercent',
      'lifeExpectancy',
      'inputMode',
      'currentAgeOverride',
      'grossAnnualSalaryOverride',
      'lppTotalOverride',
      'lppObligatoryOverride',
      'lppExtraMandatoryOverride',
      'annualPensionOverride',
      'obligatoryConversionRateOverride',
      'extraMandatoryConversionRateOverride',
      'cantonOverride',
      'marriedOverride',
    });
    return RenteCapitalScenarioLevers(
      retirementAge:
          _requiredIntInRange(json['retirementAge'], 'retirementAge', 50, 75),
      annualBuyback:
          _requiredNonNegativeDouble(json['annualBuyback'], 'annualBuyback'),
      hasEpl: _requiredBool(json['hasEpl'], 'hasEpl'),
      eplAmount: _requiredNonNegativeDouble(json['eplAmount'], 'eplAmount'),
      returnRatePercent:
          _requiredRate(json['returnRatePercent'], 'returnRatePercent'),
      withdrawalRatePercent: _requiredRate(
        json['withdrawalRatePercent'],
        'withdrawalRatePercent',
      ),
      inflationPercent:
          _requiredRate(json['inflationPercent'], 'inflationPercent'),
      lifeExpectancy: _requiredDoubleInRange(
          json['lifeExpectancy'], 'lifeExpectancy', 50, 120),
      inputMode: _parseInputMode(json['inputMode']),
      currentAgeOverride: _optionalIntInRange(
        json['currentAgeOverride'],
        'currentAgeOverride',
        18,
        99,
      ),
      grossAnnualSalaryOverride: _optionalNonNegativeDouble(
        json['grossAnnualSalaryOverride'],
        'grossAnnualSalaryOverride',
      ),
      lppTotalOverride: _optionalNonNegativeDouble(
          json['lppTotalOverride'], 'lppTotalOverride'),
      lppObligatoryOverride: _optionalNonNegativeDouble(
        json['lppObligatoryOverride'],
        'lppObligatoryOverride',
      ),
      lppExtraMandatoryOverride: _optionalNonNegativeDouble(
        json['lppExtraMandatoryOverride'],
        'lppExtraMandatoryOverride',
      ),
      annualPensionOverride: _optionalNonNegativeDouble(
        json['annualPensionOverride'],
        'annualPensionOverride',
      ),
      obligatoryConversionRateOverride: _optionalRate(
        json['obligatoryConversionRateOverride'],
        'obligatoryConversionRateOverride',
      ),
      extraMandatoryConversionRateOverride: _optionalRate(
        json['extraMandatoryConversionRateOverride'],
        'extraMandatoryConversionRateOverride',
      ),
      cantonOverride: _optionalCanton(json['cantonOverride']),
      marriedOverride:
          _optionalBool(json['marriedOverride'], 'marriedOverride'),
    );
  }

  @override
  ScenarioKind get kind => ScenarioKind.renteCapital;

  final int retirementAge;
  final double annualBuyback;
  final bool hasEpl;
  final double eplAmount;
  final double returnRatePercent;
  final double withdrawalRatePercent;
  final double inflationPercent;
  final double lifeExpectancy;
  final RenteCapitalInputMode inputMode;
  final int? currentAgeOverride;
  final double? grossAnnualSalaryOverride;
  final double? lppTotalOverride;
  final double? lppObligatoryOverride;
  final double? lppExtraMandatoryOverride;
  final double? annualPensionOverride;
  final double? obligatoryConversionRateOverride;
  final double? extraMandatoryConversionRateOverride;
  final String? cantonOverride;
  final bool? marriedOverride;

  @override
  Map<String, Object?> toJson() => {
        'retirementAge': retirementAge,
        'annualBuyback': annualBuyback,
        'hasEpl': hasEpl,
        'eplAmount': eplAmount,
        'returnRatePercent': returnRatePercent,
        'withdrawalRatePercent': withdrawalRatePercent,
        'inflationPercent': inflationPercent,
        'lifeExpectancy': lifeExpectancy,
        'inputMode': inputMode.name,
        if (currentAgeOverride != null)
          'currentAgeOverride': currentAgeOverride,
        if (grossAnnualSalaryOverride != null)
          'grossAnnualSalaryOverride': grossAnnualSalaryOverride,
        if (lppTotalOverride != null) 'lppTotalOverride': lppTotalOverride,
        if (lppObligatoryOverride != null)
          'lppObligatoryOverride': lppObligatoryOverride,
        if (lppExtraMandatoryOverride != null)
          'lppExtraMandatoryOverride': lppExtraMandatoryOverride,
        if (annualPensionOverride != null)
          'annualPensionOverride': annualPensionOverride,
        if (obligatoryConversionRateOverride != null)
          'obligatoryConversionRateOverride': obligatoryConversionRateOverride,
        if (extraMandatoryConversionRateOverride != null)
          'extraMandatoryConversionRateOverride':
              extraMandatoryConversionRateOverride,
        if (cantonOverride != null) 'cantonOverride': cantonOverride,
        if (marriedOverride != null) 'marriedOverride': marriedOverride,
      };
}

final class ScenarioSession {
  const ScenarioSession({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.levers,
  });

  factory ScenarioSession.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'schemaVersion',
      'id',
      'kind',
      'status',
      'createdAt',
      'updatedAt',
      'levers',
    });
    if (json['schemaVersion'] != scenarioSessionSchemaVersion) {
      throw const FormatException('Unsupported scenario schema');
    }
    final id = json['id'];
    if (id is! String || !isOpaqueScenarioId(id)) {
      throw const FormatException('Invalid scenario ID');
    }
    final kind = _parseKind(json['kind']);
    final status = _parseStatus(json['status']);
    final createdAt = _parseInstant(json['createdAt'], 'createdAt');
    final updatedAt = _parseInstant(json['updatedAt'], 'updatedAt');
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid scenario timestamps');
    }
    final rawLevers = json['levers'];
    if (rawLevers is! Map) {
      throw const FormatException('Invalid scenario levers');
    }
    final levers = ScenarioLevers.fromJson(
      kind,
      Map<String, dynamic>.from(rawLevers),
    );
    if (levers.kind != kind) {
      throw const FormatException('Scenario kind mismatch');
    }
    return ScenarioSession(
      id: id,
      kind: kind,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      levers: levers,
    );
  }

  final String id;
  final ScenarioKind kind;
  final ScenarioStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScenarioLevers levers;

  bool get isTerminal =>
      status == ScenarioStatus.completed || status == ScenarioStatus.abandoned;

  ScenarioSession? transition(ScenarioStatus next, DateTime now) {
    final valid = switch ((status, next)) {
      (ScenarioStatus.draft, ScenarioStatus.calculated) => true,
      (ScenarioStatus.draft, ScenarioStatus.abandoned) => true,
      (ScenarioStatus.calculated, ScenarioStatus.completed) => true,
      (ScenarioStatus.calculated, ScenarioStatus.abandoned) => true,
      _ => false,
    };
    if (!valid || now.isBefore(updatedAt)) return null;
    return ScenarioSession(
      id: id,
      kind: kind,
      status: next,
      createdAt: createdAt,
      updatedAt: now,
      levers: levers,
    );
  }

  ScenarioSession? replaceLevers(ScenarioLevers next, DateTime now) {
    if (isTerminal || next.kind != kind || now.isBefore(updatedAt)) return null;
    return ScenarioSession(
      id: id,
      kind: kind,
      status: status,
      createdAt: createdAt,
      updatedAt: now,
      levers: next,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': scenarioSessionSchemaVersion,
        'id': id,
        'kind': kind.name,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'levers': levers.toJson(),
      };
}

bool isOpaqueScenarioId(String id) =>
    id.length == 36 && id[14] == '4' && Uuid.isValidUUID(fromString: id);

ScenarioKind _parseKind(Object? value) => switch (value) {
      'epl' => ScenarioKind.epl,
      'renteCapital' => ScenarioKind.renteCapital,
      _ => throw const FormatException('Invalid scenario kind'),
    };

ScenarioStatus _parseStatus(Object? value) => switch (value) {
      'draft' => ScenarioStatus.draft,
      'calculated' => ScenarioStatus.calculated,
      'completed' => ScenarioStatus.completed,
      'abandoned' => ScenarioStatus.abandoned,
      _ => throw const FormatException('Invalid scenario status'),
    };

RenteCapitalInputMode _parseInputMode(Object? value) => switch (value) {
      'estimate' || null => RenteCapitalInputMode.estimate,
      'certificate' => RenteCapitalInputMode.certificate,
      _ => throw const FormatException('Invalid rente-capital input mode'),
    };

DateTime _parseInstant(Object? value, String field) {
  if (value is! String) throw FormatException('Invalid $field');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $field');
  return parsed.toUtc();
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unexpected scenario field');
  }
}

double _requiredNonNegativeDouble(Object? value, String field) {
  final parsed = _requiredDouble(value, field);
  if (parsed < 0) throw FormatException('Invalid $field');
  return parsed;
}

double? _optionalNonNegativeDouble(Object? value, String field) {
  if (value == null) return null;
  return _requiredNonNegativeDouble(value, field);
}

double _requiredRate(Object? value, String field) =>
    _requiredDoubleInRange(value, field, -50, 100);

double? _optionalRate(Object? value, String field) {
  if (value == null) return null;
  return _requiredRate(value, field);
}

double _requiredDoubleInRange(
  Object? value,
  String field,
  double minimum,
  double maximum,
) {
  final parsed = _requiredDouble(value, field);
  if (parsed < minimum || parsed > maximum) {
    throw FormatException('Invalid $field');
  }
  return parsed;
}

double _requiredDouble(Object? value, String field) {
  if (value is! num) throw FormatException('Invalid $field');
  final parsed = value.toDouble();
  if (!parsed.isFinite) throw FormatException('Invalid $field');
  return parsed;
}

int _requiredIntInRange(
  Object? value,
  String field,
  int minimum,
  int maximum,
) {
  if (value is! int || value < minimum || value > maximum) {
    throw FormatException('Invalid $field');
  }
  return value;
}

int? _optionalIntInRange(
  Object? value,
  String field,
  int minimum,
  int maximum,
) {
  if (value == null) return null;
  return _requiredIntInRange(value, field, minimum, maximum);
}

bool _requiredBool(Object? value, String field) {
  if (value is! bool) throw FormatException('Invalid $field');
  return value;
}

bool? _optionalBool(Object? value, String field) {
  if (value == null) return null;
  return _requiredBool(value, field);
}

String? _optionalCanton(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(value)) {
    throw const FormatException('Invalid canton override');
  }
  return value;
}
