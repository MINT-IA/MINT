// Ce que le jumeau sait d'un fait — en trois états, jamais deux.
//
// POURQUOI TROIS ET PAS DEUX
//
// La canonicalisation des réponses lisait le magasin canonique chiffré et
// réécrivait les clés de chaque fait par-dessus ce qu'on lui donnait. Une
// valeur projetée par le jumeau était donc écrasée : deux autorités, et la
// mauvaise gagnait.
//
// Renverser l'ordre ne suffisait pas. Avec un lookup à deux états — « le
// jumeau a une valeur » ou « il n'en a pas » — une SUPPRESSION serait retombée
// dans le second cas, et le repli sur le magasin canonique aurait ressuscité
// le fait au chargement suivant. La pierre tombale du registre aurait été
// annulée par un repli.
//
// D'où trois états. Le repli sur l'ancien magasin n'est autorisé que pour
// `absent` — un fait que le jumeau n'a JAMAIS connu.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';

/// Ce que le registre dit d'un fait.
enum TwinFactState {
  /// Le jumeau n'a jamais connu ce fait. L'ancien magasin peut répondre.
  absent,

  /// Le jumeau porte une version courante. Elle fait autorité.
  alive,

  /// Le jumeau porte une pierre tombale. Le fait n'a plus cours, et
  /// AUCUN repli n'est autorisé — sinon la suppression serait annulée.
  deleted,

  /// Le registre EXISTE mais le coffre ne le rend pas à cet instant.
  ///
  /// Ce n'est surtout pas `absent`. Le coffre avale ses erreurs et rend null :
  /// une panne passagère ferait donc paraître le jumeau absent, le magasin
  /// canonique périmé reprendrait l'autorité, et une suppression pourrait
  /// ressusciter. Dans ce doute on ne projette RIEN et on ne purge RIEN : la
  /// carte ressort telle qu'elle est entrée.
  unavailable,
}

/// La réponse du registre pour un fait, prête à être projetée.
class TwinFactAnswer {
  const TwinFactAnswer._(this.state, this.wizardAnswers);

  const TwinFactAnswer.absent() : this._(TwinFactState.absent, null);

  const TwinFactAnswer.unavailable()
      : this._(TwinFactState.unavailable, null);

  final TwinFactState state;

  /// Les réponses à projeter, ou null hors de l'état `alive`.
  final Map<String, dynamic>? wizardAnswers;

  bool get isAlive => state == TwinFactState.alive;
  bool get isDeleted => state == TwinFactState.deleted;
  bool get isUnavailable => state == TwinFactState.unavailable;
}

/// Le registre interrogé fait par fait.
class TwinFactLookup {
  const TwinFactLookup._(this._registry, {this.absent = true});

  final FactRegistry? _registry;

  /// Faux quand le registre existe mais n'a pas pu être lu.
  final bool absent;

  /// Aucun registre : tous les faits sont `absent`, et rien ne change pour
  /// une installation qui n'a jamais eu de jumeau.
  static const TwinFactLookup empty = TwinFactLookup._(null);

  /// Le registre existe, mais on n'a pas pu le lire maintenant.
  static const TwinFactLookup unavailable = TwinFactLookup._(null, absent: false);

  /// Décode un registre sérialisé.
  ///
  /// Un registre illisible ne se traduit PAS par « aucun fait » : ce serait
  /// rendre la main au magasin canonique alors que le jumeau a peut-être une
  /// suppression à faire respecter. L'exception remonte.
  static TwinFactLookup decode(String? serialised) {
    if (serialised == null || serialised.isEmpty) return empty;
    // Ce registre ne sert qu'à LIRE. Le générateur d'identifiants lève plutôt
    // que d'en inventer un : personne ne doit écrire par cette porte.
    final registry = FactRegistry(
      newId: () => throw StateError(
          'le registre de consultation ne peut pas créer de version'), // lint-ignore
    );
    registry.decode(serialised);
    return TwinFactLookup._(registry);
  }

  TwinFactAnswer forFact(String factId) {
    if (!absent) return const TwinFactAnswer.unavailable();
    final registry = _registry;
    if (registry == null) return const TwinFactAnswer.absent();

    final contract = _contractFor(factId);
    if (contract == null) return const TwinFactAnswer.absent();

    final version = registry.current(factId);
    if (version == null) return const TwinFactAnswer.absent();
    if (version.isTombstone) {
      return const TwinFactAnswer._(TwinFactState.deleted, null);
    }
    return TwinFactAnswer._(
      TwinFactState.alive,
      _wizardAnswersOf(contract, version),
    );
  }

  static MigratableFact? _contractFor(String factId) {
    for (final fact in kMigratableFacts) {
      if (fact.registryId == factId) return fact;
    }
    return null;
  }

  /// L'inverse exact de la migration : la charge utile, plus les quatre clés
  /// de métadonnées que l'enveloppe avait absorbées.
  static Map<String, dynamic> _wizardAnswersOf(
    MigratableFact fact,
    FactVersion version,
  ) =>
      <String, dynamic>{
        ...version.payload,
        fact.assertedAtKey: version.assertedAt.toUtc().toIso8601String(),
        fact.sourceKey: _wizardSource(version.source),
        fact.schemaVersionKey: version.schemaVersion,
        fact.needsConfirmationKey: version.needsConfirmation,
      };

  /// La provenance, dite dans le vocabulaire du magasin plat.
  ///
  /// Un fait enveloppé lors de la migration se dit `migrated_v1` et non
  /// `user_declaration` : sa valeur est réelle, son contexte d'origine est
  /// perdu, et le prétendre déclaré serait une invention.
  static String _wizardSource(FactSource source) => switch (source) {
        FactSource.userDeclaration => 'user_declaration',
        FactSource.document => 'document',
        FactSource.connection => 'connection',
        FactSource.migratedV1 => 'migrated_v1',
      };
}
