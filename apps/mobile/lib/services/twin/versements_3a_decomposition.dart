// Les versements 3a, éclatés en un fait par versement.
//
// POURQUOI CE FICHIER EXISTE
//
// Le magasin plat porte les versements 3a comme une LISTE dans une seule clé.
// Le registre n'accepte que des scalaires — non par pédanterie, mais parce
// qu'un fait qui porte une collection ne peut pas avoir d'historique : corriger
// un versement réécrirait la liste entière, et l'histoire des autres avec.
// C'est exactement ce que le contrat de ce fait déclare depuis le début : il
// est MULTIPLE.
//
// CE QUE LA DÉCOMPOSITION RÉVÈLE
//
// Chaque versement portait déjà tout ce qu'il fallait, sans qu'on s'en serve :
//
//   * un identifiant stable opaque — la clé de membre que le contrat réclame,
//     et la raison pour laquelle « une correction ne devient jamais
//     suppression + doublon » ;
//   * une année fiscale explicitement épinglée — c'est `fiscalYear` de
//     l'enveloppe ;
//   * une date de crédit effective — c'est `effectiveFrom`.
//
// Deux des quatre champs d'un versement appartiennent donc à l'ENVELOPPE, pas
// à la charge utile. L'enveloppe des seize champs cesse ici d'être une
// promesse : elle porte ce que la liste ne savait pas dire.
//
// ET CE QU'ELLE SIMPLIFIE
//
// La révision par année servait à périmer le contexte fiscal d'une année sans
// toucher aux autres. Elle était TENUE À LA MAIN — bumpée à chaque mutation,
// avec un compteur en renfort parce que deux mutations à la même seconde
// produisaient le même horodatage. Ici elle se DÉRIVE des identités de version
// de l'année : elle change exactement quand quelque chose de cette année-là
// change, et jamais autrement. Un invariant maintenu par construction plutôt
// que par discipline.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/services/twin/fact_contract.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

class Versements3aDecomposition {
  const Versements3aDecomposition._();

  static const factType = 'versements_3a';

  /// Les clés de la charge utile — le strict reste, une fois l'enveloppe
  /// servie.
  static const amountKey = 'amount_cents';
  static const accountKey = 'account_ref';

  /// Écrit un fait par versement dans le registre.
  ///
  /// Chaque versement garde SON histoire : corriger l'un n'écrit rien sur les
  /// autres, là où la liste les réécrivait tous.
  static void decompose(
    MintNextVersements3aFact fact, {
    required FactRegistry registry,
    required FactSource source,
    DateTime? assertedAt,
  }) {
    final declare = assertedAt ?? fact.assertedAt;
    for (final entry in fact.entries) {
      registry.append(
        factId: FactContracts.of(factType)!.factIdFor(memberKey: entry.id),
        factType: factType,
        payload: <String, Object?>{
          amountKey: entry.amountCents,
          if (entry.accountRef != null) accountKey: entry.accountRef,
        },
        assertedAt: declare,
        source: source,
        // L'année fiscale est ÉPINGLÉE, jamais déduite de la date de crédit :
        // depuis 2026 un rachat peut viser une année antérieure.
        fiscalYear: entry.taxYear,
        effectiveFrom: entry.creditedAt,
        needsConfirmation: fact.needsConfirmation,
        schemaVersion: fact.schemaVersion,
      );
    }
  }

  /// Reconstitue le fait agrégé à partir des versements du registre.
  ///
  /// Rend null quand le registre n'en porte aucun — à distinguer d'un fait
  /// vide, qui est une déclaration (« je n'ai rien versé ») et non une
  /// absence.
  ///
  /// La date de déclaration se LIT sur les versions, jamais sur l'horloge.
  /// Prendre l'heure courante ici serait un piège discret : la révision du
  /// fait en dérive, elle changerait donc à CHAQUE chargement, et tout ce qui
  /// s'y adosse se périmerait en permanence — un cache qui n'en est plus un.
  static MintNextVersements3aFact? recompose(
    FactRegistry registry, {
    required String source,
    required int schemaVersion,
  }) {
    // Le registre a-t-il jamais entendu parler de versements 3a ? Les pierres
    // tombales comptent : quelqu'un qui a supprimé tous ses versements A
    // répondu, et lui reposer la question serait une relance. C'est l'inverse
    // de quelqu'un qui n'a jamais rien dit.
    final connu =
        registry.currentVersions().any((v) => v.factType == factType);
    if (!connu) return null;

    final versions = registry
        .currentVersions()
        .where((v) => v.factType == factType && !v.isTombstone)
        .toList();

    final entries = <MintNextVersement3aEntry>[];
    for (final version in versions) {
      final entry = _entryOf(version);
      // Une version que ce modèle ne sait pas relire n'est pas silencieusement
      // ignorée : elle ferait disparaître un versement du total, donc de la
      // déduction fiscale, sans que rien ne le dise.
      if (entry == null) {
        throw FormatException(
            'versement « ${version.factId} » illisible : ' // lint-ignore
            'montant, date de crédit ou année fiscale manquants'); // lint-ignore
      }
      entries.add(entry);
    }
    entries.sort((a, b) => a.creditedAt.compareTo(b.creditedAt));

    // La déclaration la plus récente, tombes comprises : supprimer un
    // versement est une déclaration comme une autre.
    final connues = registry
        .currentVersions()
        .where((v) => v.factType == factType)
        .toList();
    final assertedAt = connues
        .map((v) => v.assertedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return MintNextVersements3aFact(
      entries: entries,
      bucketRevisions: bucketRevisionsOf(registry),
      assertedAt: assertedAt,
      source: source,
      schemaVersion: schemaVersion,
      needsConfirmation: versions.any((v) => v.needsConfirmation),
    );
  }

  /// La révision de chaque année fiscale, DÉRIVÉE des versions en vigueur.
  ///
  /// Elle change exactement quand un versement de cette année-là est ajouté,
  /// corrigé ou supprimé — parce qu'une correction produit une nouvelle
  /// identité de version, et qu'une suppression retire la sienne. Et elle ne
  /// change jamais quand une AUTRE année bouge : corriger 2025 ne doit pas
  /// périmer le contexte 2026.
  static Map<int, String> bucketRevisionsOf(FactRegistry registry) {
    final parAnnee = <int, List<String>>{};
    for (final version in registry.currentVersions()) {
      if (version.factType != factType || version.isTombstone) continue;
      final year = version.fiscalYear;
      if (year == null) continue;
      (parAnnee[year] ??= <String>[]).add(version.versionId);
    }
    return {
      for (final entry in parAnnee.entries)
        entry.key: (entry.value..sort()).join('|'),
    };
  }

  static MintNextVersement3aEntry? _entryOf(FactVersion version) {
    final id = FactContracts.memberOf(version.factId);
    final amount = version.payload[amountKey];
    final creditedAt = version.effectiveFrom;
    final taxYear = version.fiscalYear;
    if (id == null ||
        id.isEmpty ||
        amount is! int ||
        amount <= 0 ||
        creditedAt == null ||
        taxYear == null) {
      return null;
    }
    final accountRef = version.payload[accountKey];
    return MintNextVersement3aEntry(
      id: id,
      amountCents: amount,
      creditedAt: creditedAt,
      taxYear: taxYear,
      accountRef: accountRef is String ? accountRef : null,
    );
  }
}
