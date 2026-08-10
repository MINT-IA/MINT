enum PrimaryHomeTenure { tenant, ownerOccupier, other, unknown }

extension PrimaryHomeTenureId on PrimaryHomeTenure {
  String get id => switch (this) {
        PrimaryHomeTenure.tenant => 'tenant',
        PrimaryHomeTenure.ownerOccupier => 'owner_occupier',
        PrimaryHomeTenure.other => 'other',
        PrimaryHomeTenure.unknown => 'unknown',
      };
}

enum HousingMortgageStatus { yes, no, unknown }

extension HousingMortgageStatusId on HousingMortgageStatus {
  String get id => name;
}

enum MortgageStatementAvailability { ready, findLater, unknown }

extension MortgageStatementAvailabilityId on MortgageStatementAvailability {
  String get id => switch (this) {
        MortgageStatementAvailability.ready => 'ready',
        MortgageStatementAvailability.findLater => 'find_later',
        MortgageStatementAvailability.unknown => 'unknown',
      };
}

/// Canonical, user-asserted primary-home fact stored in wizard answers.
///
/// Money is represented as integer cents so persistence never introduces a
/// binary floating-point rounding loss.
class MintNextHousingFact {
  static const userDeclarationSource = 'user_declaration';

  static const tenureKey = 'q_housing_status';
  static const mortgageStatusKey = 'q_housing_mortgage_status';
  static const statementAvailabilityKey =
      'q_housing_mortgage_statement_availability';
  static const statementYearKey = 'q_housing_mortgage_statement_year';
  static const annualInterestCentsKey =
      'q_housing_mortgage_annual_interest_cents';
  static const debtBalanceCentsKey = 'q_housing_mortgage_debt_balance_cents';
  static const assertedAtKey = 'q_housing_fact_asserted_at';
  static const sourceKey = 'q_housing_fact_source';
  static const schemaVersionKey = 'q_housing_fact_schema_version';
  static const needsConfirmationKey = 'q_housing_fact_needs_confirmation';

  static const wizardKeys = <String>{
    tenureKey,
    mortgageStatusKey,
    statementAvailabilityKey,
    statementYearKey,
    annualInterestCentsKey,
    debtBalanceCentsKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final PrimaryHomeTenure tenure;
  final HousingMortgageStatus? mortgageStatus;
  final MortgageStatementAvailability? statementAvailability;
  final int? statementYear;
  final int? annualInterestCents;
  final int? debtBalanceCents;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextHousingFact({
    required this.tenure,
    this.mortgageStatus,
    this.statementAvailability,
    this.statementYear,
    this.annualInterestCents,
    this.debtBalanceCents,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        tenureKey: tenure.id,
        mortgageStatusKey: mortgageStatus?.id,
        statementAvailabilityKey: statementAvailability?.id,
        statementYearKey: statementYear,
        annualInterestCentsKey: annualInterestCents,
        debtBalanceCentsKey: debtBalanceCents,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  static Map<String, dynamic> deletionWizardAnswers() =>
      <String, dynamic>{for (final key in wizardKeys) key: null};

  static MintNextHousingFact? fromWizardAnswers(Map<String, dynamic> answers) {
    final tenure = _tenure(answers[tenureKey]);
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (tenure == null ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    return MintNextHousingFact(
      tenure: tenure,
      mortgageStatus: _mortgage(answers[mortgageStatusKey]),
      statementAvailability: _availability(answers[statementAvailabilityKey]),
      statementYear: _int(answers[statementYearKey]),
      annualInterestCents: _int(answers[annualInterestCentsKey]),
      debtBalanceCents: _int(answers[debtBalanceCentsKey]),
      assertedAt: assertedAt.toUtc(),
      source: source,
      schemaVersion: schema,
      needsConfirmation: confirmation,
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      return value.isFinite && value == value.truncateToDouble()
          ? value.toInt()
          : null;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static PrimaryHomeTenure? _tenure(dynamic value) {
    for (final item in PrimaryHomeTenure.values) {
      if (item.id == value) return item;
    }
    return null;
  }

  static HousingMortgageStatus? _mortgage(dynamic value) {
    for (final item in HousingMortgageStatus.values) {
      if (item.id == value) return item;
    }
    return null;
  }

  static MortgageStatementAvailability? _availability(dynamic value) {
    for (final item in MortgageStatementAvailability.values) {
      if (item.id == value) return item;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is MintNextHousingFact &&
      tenure == other.tenure &&
      mortgageStatus == other.mortgageStatus &&
      statementAvailability == other.statementAvailability &&
      statementYear == other.statementYear &&
      annualInterestCents == other.annualInterestCents &&
      debtBalanceCents == other.debtBalanceCents &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode => Object.hash(
        tenure,
        mortgageStatus,
        statementAvailability,
        statementYear,
        annualInterestCents,
        debtBalanceCents,
        assertedAt,
        source,
        schemaVersion,
        needsConfirmation,
      );
}
