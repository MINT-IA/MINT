// Le support réel du jumeau : le magasin de réponses déjà en place.
//
// POURQUOI CETTE FORME
//
// Le registre et sa projection doivent être écrits ENSEMBLE ou pas du tout.
// La façon la plus simple d'y parvenir n'est pas d'inventer une transaction :
// c'est de les mettre dans le MÊME objet, écrit par la même opération. Le
// registre vit donc sous une clé réservée du magasin de réponses, aux côtés
// des valeurs qu'il projette. Une écriture, un objet, aucune fenêtre pendant
// laquelle les deux pourraient diverger.
//
// Ce choix a un corollaire : le magasin de réponses reste ce que lisent les
// écrans, exactement comme avant. Rien ne casse pendant la transition — la
// projection EST le magasin, simplement plus personne n'y écrit à la main.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';

class AnswersTwinBackend implements TwinBackend {
  const AnswersTwinBackend();

  /// Le registre des versions, sérialisé. Préfixe réservé : aucune réponse
  /// utilisateur ne porte ce nom, et la migration le compte parmi les clés
  /// qu'aucun fait ne revendique — d'où son exclusion explicite plus bas.
  static const registryKey = 'mint_twin_registry_v1';

  /// La révision, pour l'échange comparé. Elle vit dans le même objet que ce
  /// qu'elle protège : une révision écrite ailleurs pourrait survivre à une
  /// écriture perdue.
  static const revisionKey = 'mint_twin_revision_v1';

  /// Ce que la projection nue ne dit pas : d'où vient chaque valeur, pour
  /// quelle année, si elle est confirmée, jusqu'à quand elle vaut.
  ///
  /// Sans cette table, un lecteur du magasin voyait CHF 4 250 sans savoir
  /// qu'il s'agissait de l'exercice 2025, extrait d'un document, et encore en
  /// attente de confirmation.
  static const metadataKey = 'mint_twin_meta_v1';

  /// Les clés du jumeau lui-même, qui ne sont ni des faits ni des réponses.
  static const reservedKeys = <String>{registryKey, revisionKey, metadataKey};

  @override
  Future<({String? registry, int revision})> read() async {
    final answers = await ReportPersistenceService.loadAnswers();
    final registry = answers[registryKey];
    final revision = answers[revisionKey];
    return (
      registry: registry is String && registry.isNotEmpty ? registry : null,
      revision: revision is int ? revision : 0,
    );
  }

  @override
  Future<bool> compareAndSwap({
    required int expectedRevision,
    required String registry,
    required Map<String, Object?> projection,
    required Map<String, Object?> metadata,
    required Set<String> ownedKeys,
  }) async {
    final current = await ReportPersistenceService.loadAnswers();
    final actual = current[revisionKey] is int ? current[revisionKey] as int : 0;
    if (actual != expectedRevision) return false;

    // Les clés dont le jumeau a la charge sont retirées puis réécrites depuis
    // la projection. Celle d'un fait SUPPRIMÉ n'y figure plus : sans ce
    // retrait, une pierre tombale laisserait sa valeur visible — le fait
    // serait supprimé pour le registre et bien présent pour les écrans.
    //
    // Tout le reste est CONSERVÉ. Le magasin porte encore des réponses
    // qu'aucun fait ne revendique ; les effacer au passage du jumeau
    // détruirait des données que personne n'a demandé de supprimer.
    final next = Map<String, dynamic>.from(current)
      ..removeWhere((key, _) => ownedKeys.contains(key))
      ..addAll(projection)
      ..[registryKey] = registry
      ..[metadataKey] = metadata
      ..[revisionKey] = expectedRevision + 1;

    return ReportPersistenceService.saveAnswers(next);
  }
}
