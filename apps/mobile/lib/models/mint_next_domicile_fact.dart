import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';

/// Canonical, user-asserted fiscal-domicile fact stored in wizard answers.
///
/// The canton reuses the shared legacy key `q_canton` (already consumed by
/// tax surfaces); the commune and the fact metadata are owned by this fact.
/// The BFS commune code is nullable until a verified national dataset lands.
/// The fact is effective-dated (assertedAt); the tax year belongs to the
/// consumer's fiscal context, never to the fact itself.
class MintNextDomicileFact implements ConfirmedDomicileSource {
  static const userDeclarationSource = 'user_declaration';

  /// Shared legacy key — written by this fact, never deleted by it.
  static const cantonKey = 'q_canton';

  static const communeNameKey = 'q_domicile_commune_name';
  static const communeBfsKey = 'q_domicile_commune_bfs';
  static const assertedAtKey = 'q_domicile_fact_asserted_at';
  static const sourceKey = 'q_domicile_fact_source';
  static const schemaVersionKey = 'q_domicile_fact_schema_version';
  static const needsConfirmationKey = 'q_domicile_fact_needs_confirmation';

  /// Keys owned by the fact: deleted on fact deletion. `q_canton` is shared
  /// with the pre-existing profile and intentionally excluded.
  static const ownedKeys = <String>{
    communeNameKey,
    communeBfsKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  final String canton;
  final String communeName;
  final int? communeBfs;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  const MintNextDomicileFact({
    required this.canton,
    required this.communeName,
    this.communeBfs,
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    required this.needsConfirmation,
  });

  /// Revision fingerprint binding fiscal derivatives to this assertion.
  String get revision => assertedAt.toUtc().toIso8601String();

  /// Null tant que le fait attend une confirmation : un domicile proposé
  /// n'est jamais « connu » pour un consommateur fiscal.
  @override
  MintNext3aDomicileContext? toConfirmedDomicileContext() => needsConfirmation
      ? null
      : MintNext3aDomicileContext(
          canton: canton,
          communeName: communeName,
          communeBfs: communeBfs,
          revision: revision,
        );

  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        cantonKey: canton,
        communeNameKey: communeName,
        communeBfsKey: communeBfs,
        assertedAtKey: assertedAt.toUtc().toIso8601String(),
        sourceKey: source,
        schemaVersionKey: schemaVersion,
        needsConfirmationKey: needsConfirmation,
      };

  /// Nulls only the owned keys so unrelated answers — including the shared
  /// legacy `q_canton` — survive deletion.
  static Map<String, dynamic> deletionWizardAnswers() =>
      <String, dynamic>{for (final key in ownedKeys) key: null};

  static MintNextDomicileFact? fromWizardAnswers(Map<String, dynamic> answers) {
    final canton = answers[cantonKey];
    final communeName = answers[communeNameKey];
    final assertedAt =
        DateTime.tryParse(answers[assertedAtKey]?.toString() ?? '');
    final source = answers[sourceKey];
    final schema = _int(answers[schemaVersionKey]);
    final confirmation = answers[needsConfirmationKey];
    if (canton is! String ||
        canton.isEmpty ||
        communeName is! String ||
        communeName.trim().isEmpty ||
        assertedAt == null ||
        source is! String ||
        source.isEmpty ||
        schema == null ||
        confirmation is! bool) {
      return null;
    }
    return MintNextDomicileFact(
      canton: canton,
      communeName: communeName.trim(),
      communeBfs: _int(answers[communeBfsKey]),
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
      other is MintNextDomicileFact &&
      canton == other.canton &&
      communeName == other.communeName &&
      communeBfs == other.communeBfs &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode => Object.hash(canton, communeName, communeBfs, assertedAt,
      source, schemaVersion, needsConfirmation);
}
