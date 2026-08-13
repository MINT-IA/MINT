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

  /// Le fait porte DEUX états, pas un état et une absence : « domicile fiscal
  /// en Suisse » et « pas de domicile fiscal en Suisse ». Quelqu'un imposé à
  /// la source sans domicile suisse — frontalier, personne résidant à
  /// l'étranger — n'a aucune commune à donner ; l'obliger à en choisir une
  /// fabriquerait une donnée fausse enregistrée comme un fait.
  ///
  /// Un fait séparé « absence de domicile » autoriserait deux faits
  /// contradictoires simultanés. L'absence appartient donc au même agrégat et
  /// remplace l'état précédent.
  static const hasSwissTaxDomicileKey = 'q_domicile_fiscal_suisse';

  static const communeNameKey = 'q_domicile_commune_name';
  static const communeBfsKey = 'q_domicile_commune_bfs';

  /// Édition du registre fédéral qui a résolu cette commune.
  ///
  /// Un numéro OFS n'est pas éternel : il change lors d'un transfert de canton
  /// (Moutier, BE 700 jusqu'au 31.12.2025, puis JU 6831). Le registre embarqué
  /// ne contient que les communes actives à sa date d'instantané ; après
  /// régénération, un numéro supprimé ne se retrouve plus. Enregistrer
  /// l'édition qui a servi permet au moins de SAVOIR contre quoi le fait a été
  /// résolu, au lieu de le découvrir quand la résolution échoue.
  static const registrySnapshotKey = 'q_domicile_registre_instantane';
  static const assertedAtKey = 'q_domicile_fact_asserted_at';
  static const sourceKey = 'q_domicile_fact_source';
  static const schemaVersionKey = 'q_domicile_fact_schema_version';
  static const needsConfirmationKey = 'q_domicile_fact_needs_confirmation';

  /// Keys owned by the fact: deleted on fact deletion. `q_canton` is shared
  /// with the pre-existing profile and intentionally excluded.
  static const ownedKeys = <String>{
    hasSwissTaxDomicileKey,
    communeNameKey,
    communeBfsKey,
    registrySnapshotKey,
    assertedAtKey,
    sourceKey,
    schemaVersionKey,
    needsConfirmationKey,
  };

  /// Vrai quand la personne est imposée dans une commune suisse.
  ///
  /// Faux : aucune commune, aucun numéro OFS, aucun canton — et surtout
  /// AUCUNE valeur sentinelle du genre « Étranger », numéro 0 ou canton du
  /// lieu de travail. Une sentinelle serait exactement la donnée fausse que
  /// cet état existe pour éviter.
  final bool hasSwissTaxDomicile;

  final String? canton;
  final String? communeName;
  final int? communeBfs;

  /// Date d'instantané du registre qui a résolu cette commune, format
  /// JJ-MM-AAAA. Null pour un fait écrit avant que le registre existe.
  final String? registrySnapshot;
  final DateTime assertedAt;
  final String source;
  final int schemaVersion;
  final bool needsConfirmation;

  /// Le seul constructeur de l'état « pas de domicile fiscal en Suisse ».
  /// Il n'accepte ni commune ni canton : la forme du constructeur interdit
  /// l'incohérence plutôt que de la contrôler après coup.
  const MintNextDomicileFact.noSwissTaxDomicile({
    required this.assertedAt,
    required this.source,
    required this.schemaVersion,
    this.needsConfirmation = false,
  })  : hasSwissTaxDomicile = false,
        canton = null,
        communeName = null,
        communeBfs = null,
        registrySnapshot = null;

  const MintNextDomicileFact({
    this.hasSwissTaxDomicile = true,
    this.canton,
    this.communeName,
    this.communeBfs,
    this.registrySnapshot,
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
  /// Null tant que le fait attend une confirmation, qu'il n'y a pas de
  /// domicile suisse, ou que la commune n'a PAS D'IDENTITÉ FÉDÉRALE.
  ///
  /// Ce dernier cas est celui des faits écrits à l'époque du champ libre :
  /// un nom tapé à la main, potentiellement mal orthographié ou ambigu, que
  /// rien ne rattache à une commune réelle. Le laisser alimenter un chiffre
  /// fiscal reviendrait à calculer sur une chaîne de caractères. Le contrat
  /// du consommateur est explicite : null veut dire « fait manquant, montre-le
  /// comme tel », jamais « devine ».
  MintNext3aDomicileContext? toConfirmedDomicileContext() =>
      needsConfirmation ||
              !hasSwissTaxDomicile ||
              canton == null ||
              communeBfs == null
          ? null
          : MintNext3aDomicileContext(
              canton: canton!,
              communeName: communeName ?? '',
              communeBfs: communeBfs,
              revision: revision,
              declaredAt: assertedAt,
            );

  /// `q_canton` est PARTAGÉE avec le profil historique. En l'absence de
  /// domicile suisse, la garder ferait survivre une donnée devenue fausse :
  /// elle est donc mise à null ici. Le raffinement — n'effacer que si la
  /// valeur présente est bien celle que ce fait avait écrite — est une lacune
  /// connue, documentée dans l'ADR.
  Map<String, dynamic> toWizardAnswers() => <String, dynamic>{
        hasSwissTaxDomicileKey: hasSwissTaxDomicile,
        cantonKey: canton,
        communeNameKey: communeName,
        communeBfsKey: communeBfs,
        registrySnapshotKey: registrySnapshot,
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

    // Clé absente = fait écrit avant l'existence de cet état, donc un fait
    // qui portait forcément une commune. On ne suppose jamais l'inverse.
    final hasSwiss = answers[hasSwissTaxDomicileKey];
    if (hasSwiss == false) {
      if (assertedAt == null ||
          source is! String ||
          source.isEmpty ||
          schema == null ||
          confirmation is! bool) {
        return null;
      }
      return MintNextDomicileFact.noSwissTaxDomicile(
        assertedAt: assertedAt.toUtc(),
        source: source,
        schemaVersion: schema,
        needsConfirmation: confirmation,
      );
    }

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
      registrySnapshot: answers[registrySnapshotKey] as String?,
      assertedAt: assertedAt.toUtc(),
      source: source,
      schemaVersion: schema,
      needsConfirmation: confirmation,
    );
  }

  /// Lecture de l'état depuis les réponses brutes, pour les consommateurs
  /// historiques qui ne connaissent pas ce modèle.
  ///
  /// Clé absente = vrai : un profil écrit avant l'existence de cet état
  /// portait forcément un domicile suisse. On ne suppose jamais l'inverse.
  static bool hasSwissTaxDomicileIn(Map<String, dynamic> answers) =>
      answers[hasSwissTaxDomicileKey] != false;

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
      hasSwissTaxDomicile == other.hasSwissTaxDomicile &&
      canton == other.canton &&
      communeName == other.communeName &&
      communeBfs == other.communeBfs &&
      registrySnapshot == other.registrySnapshot &&
      assertedAt == other.assertedAt &&
      source == other.source &&
      schemaVersion == other.schemaVersion &&
      needsConfirmation == other.needsConfirmation;

  @override
  int get hashCode => Object.hash(hasSwissTaxDomicile, canton, communeName,
      communeBfs, registrySnapshot, assertedAt, source, schemaVersion,
      needsConfirmation);
}
