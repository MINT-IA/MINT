import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';

/// Canonical, user-asserted LPP affiliation fact (Lego 4).
///
/// CONTRAT SÉMANTIQUE : l'affiliation ACTUELLE à une caisse de pension LPP
/// (2e pilier) déclarée par la personne. Booléen strict stocké, mais la
/// lecture métier est TRI-ÉTAT ([MintNextLppAffiliationStatus]) : absence,
/// corruption ou tombstone ne valent JAMAIS « non ». Posséder un certificat
/// LPP ≠ être affilié ; un capital LPP ≠ être affilié aujourd'hui ; le
/// statut d'emploi ne prouve rien. Clés possédées, aucune projection legacy
/// (aucun consommateur historique ne lit une clé d'affiliation partagée).
enum MintNextLppAffiliationStatus { confirmedYes, confirmedNo, unknown }

class MintNextLppAffiliationFact implements ConfirmedLppAffiliationSource {
  static const userDeclarationSource = 'user_declaration';

  static const valueKey = 'q_lpp_affiliation_fact_value';
  static const assertedAtKey = 'q_lpp_affiliation_fact_asserted_at';
  static const sourceKey = 'q_lpp_affiliation_fact_source';
  static const schemaVersionKey = 'q_lpp_affiliation_fact_schema_version';
  static const needsConfirmationKey =
      'q_lpp_affiliation_fact_needs_confirmation';

  /// Complete owned bundle — committed and deleted atomically by the sealed
  /// canonical record.
  static const wizardKeys = <String>{
    valueKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final bool affiliated;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextLppAffiliationFact({
    required this.affiliated,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  /// Revision fingerprint binding fiscal derivatives to this assertion.
  String get revision => assertedAt.toUtc().toIso8601String();

  /// Lecture métier tri-état — l'UNIQUE porte de sortie vers la fiscalité.
  /// Un fait absent ou en attente de confirmation est INCONNU, jamais
  /// « non affilié ».
  static MintNextLppAffiliationStatus statusOf(
          MintNextLppAffiliationFact? fact) =>
      fact == null || fact.needsConfirmation
          ? MintNextLppAffiliationStatus.unknown
          : fact.affiliated
              ? MintNextLppAffiliationStatus.confirmedYes
              : MintNextLppAffiliationStatus.confirmedNo;

  @override
  MintNext3aLppAffiliationContext? toConfirmedLppAffiliationContext() =>
      needsConfirmation
          ? null
          : MintNext3aLppAffiliationContext(
              affiliated: affiliated,
              revision: revision,
            );

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        valueKey: affiliated,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  static Map<String, dynamic> deletionWizardAnswers() =>
      <String, dynamic>{for (final key in wizardKeys) key: null};

  static MintNextLppAffiliationFact? fromWizardAnswers(
      Map<String, dynamic> answers) {
    final value = answers[valueKey];
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (value is! bool ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    return MintNextLppAffiliationFact(
      affiliated: value,
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

  @override
  bool operator ==(Object other) =>
      other is MintNextLppAffiliationFact &&
      affiliated == other.affiliated &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode => Object.hash(
      affiliated, assertedAt, source, schemaVersion, needsConfirmation);
}
