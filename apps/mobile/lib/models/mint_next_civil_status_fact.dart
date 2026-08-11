/// Canonical, user-asserted civil-status fact.
///
/// `q_civil_status` is the shared sealed key (already classified sensitive);
/// the fact metadata is owned and classified with it. The legacy
/// `q_civil_status_choice` is a READ-ONLY migration alias — never written.
/// Internal tokens are stable and accent-free; UI labels are never stored and
/// the LIFD semantics live in the backend (`fiscal/civil_status.py`).
enum MintNextCivilStatus {
  celibataire,
  marie,
  partenariatEnregistre,
  concubinage,
  divorce,
  veuf,
}

extension MintNextCivilStatusId on MintNextCivilStatus {
  String get id => switch (this) {
        MintNextCivilStatus.celibataire => 'celibataire',
        MintNextCivilStatus.marie => 'marie',
        MintNextCivilStatus.partenariatEnregistre => 'partenariat_enregistre',
        MintNextCivilStatus.concubinage => 'concubinage',
        MintNextCivilStatus.divorce => 'divorce',
        MintNextCivilStatus.veuf => 'veuf',
      };

  /// Imposition commune (barème marié) — vrai pour le mariage ET le
  /// partenariat enregistré (LIFD art. 9 al. 1bis). Le concubinage est
  /// imposé séparément : les confondre est fiscalement faux.
  bool get jointTaxation =>
      this == MintNextCivilStatus.marie ||
      this == MintNextCivilStatus.partenariatEnregistre;
}

class MintNextCivilStatusFact {
  static const userDeclarationSource = 'user_declaration';

  /// Shared sealed key — the value IS the fact; deletion tombstones it.
  static const statusKey = 'q_civil_status';

  /// Legacy alias: read for migration only, never written.
  static const legacyChoiceKey = 'q_civil_status_choice';

  static const assertedAtKey = 'q_etat_civil_fact_asserted_at';
  static const sourceKey = 'q_etat_civil_fact_source';
  static const schemaVersionKey = 'q_etat_civil_fact_schema_version';
  static const needsConfirmationKey = 'q_etat_civil_fact_needs_confirmation';

  /// Complete bundle — committed and deleted atomically by the sealed
  /// canonical record.
  static const wizardKeys = <String>{
    statusKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final MintNextCivilStatus status;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextCivilStatusFact({
    required this.status,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  /// Revision fingerprint binding fiscal derivatives to this assertion.
  String get revision => assertedAt.toUtc().toIso8601String();

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        statusKey: status.id,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  static Map<String, dynamic> deletionWizardAnswers() =>
      <String, dynamic>{for (final key in wizardKeys) key: null};

  static MintNextCivilStatusFact? fromWizardAnswers(
      Map<String, dynamic> answers) {
    final status = _status(answers[statusKey]);
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (status == null ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    return MintNextCivilStatusFact(
      status: status,
      assertedAt: assertedAt.toUtc(),
      source: source,
      schemaVersion: schema,
      needsConfirmation: confirmation,
    );
  }

  static MintNextCivilStatus? _status(dynamic value) {
    for (final item in MintNextCivilStatus.values) {
      if (item.id == value) return item;
    }
    return null;
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

  @override
  bool operator ==(Object other) =>
      other is MintNextCivilStatusFact &&
      status == other.status &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode =>
      Object.hash(status, assertedAt, source, schemaVersion, needsConfirmation);
}
