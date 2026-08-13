// La migration des faits déjà écrits vers le registre de versions.
//
// Six faits existent aujourd'hui dans le magasin plat, sans historique : le
// domicile, l'état civil, le revenu, le logement, l'affiliation LPP et les
// versements 3a. Chacun n'a qu'une valeur, la dernière — les précédentes ont
// été écrasées et sont définitivement perdues. On ne les reconstruit pas.
//
// CE QUE CETTE MIGRATION FAIT, ET SURTOUT CE QU'ELLE NE FAIT PAS
//
// Elle enveloppe chaque valeur courante dans une version `v1` :
//
//   * `assertedAt` garde la déclaration d'origine, quand le fait la portait ;
//   * `recordedAt` est la date de migration — c'est aujourd'hui que MINT
//     écrit cette version, et prétendre autre chose serait faux ;
//   * `source` vaut `migratedV1`, qui dit exactement ce qu'il en est : la
//     valeur est réelle, son contexte d'origine est perdu ;
//   * `effectiveFrom` et `fiscalYear` restent NULS.
//
// Ce dernier point est le cœur. Il aurait été facile de déduire une date
// d'effet de la date de déclaration — et faux. Quelqu'un ayant déclaré son
// domicile en août n'y habitait pas forcément en janvier. Un fait migré ne
// répondra donc à aucune question par année, et c'est ce qui rendra la
// collecte de la date d'effet nécessaire plutôt que décorative.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

/// Un fait migrable : son identité, et les clés qu'il possède dans le magasin
/// plat.
class MigratableFact {
  const MigratableFact({
    required this.factId,
    required this.keys,
    required this.assertedAtKey,
    required this.sourceKey,
    required this.schemaVersionKey,
    required this.needsConfirmationKey,
  });

  final String factId;
  final Set<String> keys;
  final String assertedAtKey;
  final String sourceKey;
  final String schemaVersionKey;
  final String needsConfirmationKey;

  /// Les clés PORTEUSES de valeur — hors métadonnées, qui deviennent
  /// l'enveloppe et n'ont plus à encombrer le payload.
  Set<String> get payloadKeys => keys.difference({
        assertedAtKey,
        sourceKey,
        schemaVersionKey,
        needsConfirmationKey,
      });
}

/// Les six faits d'aujourd'hui, déclarés une seule fois.
///
/// Chacun tient ses clés de son propre modèle : recopier la liste ici la
/// ferait dériver au premier champ ajouté.
const List<MigratableFact> kMigratableFacts = [
  MigratableFact(
    factId: 'domicile',
    keys: MintNextDomicileFact.ownedKeys,
    assertedAtKey: MintNextDomicileFact.assertedAtKey,
    sourceKey: MintNextDomicileFact.sourceKey,
    schemaVersionKey: MintNextDomicileFact.schemaVersionKey,
    needsConfirmationKey: MintNextDomicileFact.needsConfirmationKey,
  ),
  MigratableFact(
    factId: 'etat_civil',
    keys: MintNextCivilStatusFact.wizardKeys,
    assertedAtKey: MintNextCivilStatusFact.assertedAtKey,
    sourceKey: MintNextCivilStatusFact.sourceKey,
    schemaVersionKey: MintNextCivilStatusFact.schemaVersionKey,
    needsConfirmationKey: MintNextCivilStatusFact.needsConfirmationKey,
  ),
  MigratableFact(
    factId: 'revenu',
    keys: MintNextRevenuFact.wizardKeys,
    assertedAtKey: MintNextRevenuFact.assertedAtKey,
    sourceKey: MintNextRevenuFact.sourceKey,
    schemaVersionKey: MintNextRevenuFact.schemaVersionKey,
    needsConfirmationKey: MintNextRevenuFact.needsConfirmationKey,
  ),
  MigratableFact(
    factId: 'logement',
    keys: MintNextHousingFact.wizardKeys,
    assertedAtKey: MintNextHousingFact.assertedAtKey,
    sourceKey: MintNextHousingFact.sourceKey,
    schemaVersionKey: MintNextHousingFact.schemaVersionKey,
    needsConfirmationKey: MintNextHousingFact.needsConfirmationKey,
  ),
  MigratableFact(
    factId: 'lpp_affiliation',
    keys: MintNextLppAffiliationFact.wizardKeys,
    assertedAtKey: MintNextLppAffiliationFact.assertedAtKey,
    sourceKey: MintNextLppAffiliationFact.sourceKey,
    schemaVersionKey: MintNextLppAffiliationFact.schemaVersionKey,
    needsConfirmationKey: MintNextLppAffiliationFact.needsConfirmationKey,
  ),
  MigratableFact(
    factId: 'versements_3a',
    keys: MintNextVersements3aFact.wizardKeys,
    assertedAtKey: MintNextVersements3aFact.assertedAtKey,
    sourceKey: MintNextVersements3aFact.sourceKey,
    schemaVersionKey: MintNextVersements3aFact.schemaVersionKey,
    needsConfirmationKey: MintNextVersements3aFact.needsConfirmationKey,
  ),
];

class TwinMigrationReport {
  const TwinMigrationReport({
    required this.migrated,
    required this.skipped,
    required this.orphanKeys,
  });

  /// Les faits enveloppés en `v1`.
  final List<String> migrated;

  /// Les faits absents du magasin — rien à migrer, ce n'est pas un échec.
  final List<String> skipped;

  /// Les clés du magasin qu'AUCUN fait ne revendique.
  ///
  /// Elles ne sont pas migrées, et c'est délibéré : les inventer un
  /// propriétaire serait pire que de les laisser où elles sont. Mais elles
  /// sont NOMMÉES, parce qu'une donnée sans propriétaire est une dette qu'il
  /// vaut mieux voir.
  final List<String> orphanKeys;
}

class TwinMigration {
  /// Enveloppe les faits présents dans `answers` en versions `v1`.
  ///
  /// N'écrit rien : rend le registre peuplé et le compte rendu. C'est
  /// l'appelant qui décide de persister, en une transaction.
  static TwinMigrationReport migrate({
    required Map<String, dynamic> answers,
    required FactRegistry registry,
    required DateTime migratedAt,
  }) {
    final migrated = <String>[];
    final skipped = <String>[];
    final claimed = <String>{};

    for (final fact in kMigratableFacts) {
      claimed.addAll(fact.keys);

      final payload = <String, Object?>{};
      for (final key in fact.payloadKeys) {
        final value = answers[key];
        if (value != null) payload[key] = value;
      }
      if (payload.isEmpty) {
        // Aucune valeur : ce fait n'a jamais été déclaré. Écrire une version
        // vide inventerait une déclaration.
        skipped.add(fact.factId);
        continue;
      }

      // La déclaration d'origine si elle existe, sinon la date de migration —
      // et jamais une date postérieure à l'écriture, que le registre refuse.
      final declared =
          DateTime.tryParse(answers[fact.assertedAtKey]?.toString() ?? '');
      final assertedAt = declared == null || declared.toUtc().isAfter(migratedAt)
          ? migratedAt
          : declared.toUtc();

      registry.append(
        factId: fact.factId,
        factType: fact.factId,
        payload: payload,
        assertedAt: assertedAt,
        // Dit exactement ce qu'il en est : la valeur est réelle, son contexte
        // d'origine est perdu.
        source: FactSource.migratedV1,
        needsConfirmation: answers[fact.needsConfirmationKey] == true,
        schemaVersion: answers[fact.schemaVersionKey] is int
            ? answers[fact.schemaVersionKey] as int
            : 1,
        // effectiveFrom et fiscalYear restent NULS. Les déduire de la date de
        // déclaration serait une date fabriquée.
      );
      migrated.add(fact.factId);
    }

    final orphans = answers.keys
        .where((k) => !claimed.contains(k) && answers[k] != null)
        .toList()
      ..sort();

    return TwinMigrationReport(
      migrated: migrated,
      skipped: skipped,
      orphanKeys: orphans,
    );
  }
}
