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

import 'dart:async';

import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';

/// Le registre a été scellé, et le coffre ne le rend plus.
///
/// Ce n'est PAS « pas encore de jumeau » : c'est une histoire qui existe et
/// qu'on ne sait plus lire. Les confondre serait le pire des deux mondes —
/// le jumeau repartirait de zéro et la première écriture recouvrirait
/// définitivement ce que le coffre finirait peut-être par rendre.
///
/// D'où une exception plutôt qu'un retour vide : celui qui branchera le
/// jumeau devra décider quoi faire, consciemment.
class TwinRegistryUnreadable implements Exception {
  const TwinRegistryUnreadable();

  @override
  String toString() =>
      'TwinRegistryUnreadable: le registre est scellé mais le coffre ne le ' // lint-ignore
      'rend pas — ne pas le confondre avec un jumeau vide.'; // lint-ignore
}

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

  /// Ce que les préférences en clair portent à la place d'une valeur scellée.
  static const securePlaceholder = '__secure__';

  @override
  Future<({String? registry, int revision})> read() async {
    final answers = await ReportPersistenceService.loadAnswers();
    return (
      registry: await _registryFrom(answers),
      revision: answers[revisionKey] is int ? answers[revisionKey] as int : 0,
    );
  }

  /// Le registre, lu là où il est réellement scellé.
  ///
  /// POURQUOI PASSER PAR LE COFFRE PLUTÔT QUE PAR LE MAGASIN
  ///
  /// Le magasin de réponses sait échouer en silence : quand son JSON ne se
  /// décode pas, il rend une carte VIDE plutôt qu'une erreur. Le registre,
  /// lui, est scellé dans le coffre et survit à cette panne. Le lire par le
  /// détour du magasin, c'était donc conclure « pas de jumeau » alors que
  /// l'histoire était intacte à côté — et l'écriture suivante l'aurait
  /// recouverte. Interroger le coffre d'abord transforme cette perte en
  /// simple récupération.
  ///
  /// Rend null quand il n'y a rien à lire, et LÈVE quand il y a quelque
  /// chose qu'on ne sait plus lire. Les confondre serait le pire des deux
  /// mondes.
  Future<String?> _registryFrom(Map<String, dynamic> answers) async {
    final sealed = await SecureWizardStore.read(registryKey);
    if (sealed != null && sealed.isNotEmpty) return sealed;

    // Le coffre ne rend rien. Reste à savoir s'il n'a jamais rien eu.
    final projected = answers[registryKey];
    // Si la clé cessait un jour d'être classée sensible, la restauration la
    // sauterait et le jeton arriverait tel quel jusqu'ici.
    if (projected == securePlaceholder) throw const TwinRegistryUnreadable();
    // Sinon : clé PRÉSENTE avec une valeur nulle = elle a été scellée et le
    // coffre l'a perdue. Clé ABSENTE = ce jumeau n'a jamais existé.
    if (answers.containsKey(registryKey)) throw const TwinRegistryUnreadable();
    return null;
  }

  /// La file d'attente des écritures.
  ///
  /// L'échange comparé lit la révision, la compare, puis écrit — et entre la
  /// comparaison et l'écriture il y a des `await`. Deux écritures lancées
  /// ensemble lisaient donc la MÊME révision, passaient toutes les deux le
  /// test, et la seconde recouvrait la première : un échange comparé qui ne
  /// compare rien. Les sérialiser rend au test le sens qu'il prétendait avoir.
  static Future<void> _queue = Future<void>.value();

  @override
  Future<bool> compareAndSwap({
    required int expectedRevision,
    required String registry,
    required Map<String, Object?> projection,
    required Map<String, Object?> metadata,
    required Set<String> ownedKeys,
  }) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    return previous.then((_) async {
      try {
        return await _swap(
          expectedRevision: expectedRevision,
          registry: registry,
          projection: projection,
          metadata: metadata,
          ownedKeys: ownedKeys,
        );
      } finally {
        done.complete();
      }
    });
  }

  Future<bool> _swap({
    required int expectedRevision,
    required String registry,
    required Map<String, Object?> projection,
    required Map<String, Object?> metadata,
    required Set<String> ownedKeys,
  }) async {
    final current = await ReportPersistenceService.loadAnswers();
    // Écrire par-dessus une histoire qu'on ne sait pas lire la détruirait
    // définitivement. La même règle qu'à la lecture, à la porte de l'écriture.
    await _registryFrom(current);
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
