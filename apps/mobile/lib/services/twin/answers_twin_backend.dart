// Le support du jumeau — INDÉPENDANT du magasin de réponses.
//
// POURQUOI CETTE FORME A CHANGÉ
//
// La première version mettait le registre dans le MÊME objet que sa
// projection, écrit par `saveAnswers`, pour qu'ils s'écrivent ensemble ou pas
// du tout. Deux constats ont retiré sa raison d'être à ce choix.
//
// D'ABORD, l'atomicité n'est plus nécessaire. Depuis que les canonicalisations
// lisent le jumeau, la projection est RECALCULÉE à chaque chargement : une
// divergence entre le registre et le magasin plat se répare d'elle-même au
// chargement suivant. Il n'y a plus deux vérités à tenir synchronisées, il y a
// une vérité et une vue.
//
// ENSUITE, elle coûtait cher. `saveAnswers` appelle lui aussi les cinq
// canonicalisations — lesquelles lisent le registre. La projection écrite était
// donc calculée à partir de l'ANCIEN registre, celui d'avant l'écriture en
// cours : en retard d'une version, et corrigée au chargement suivant.
// Autrement dit, on payait un aller-retour complet pour écrire une valeur
// périmée que personne ne lisait.
//
// Et surtout, ce couplage FABRIQUAIT une récurrence. Le jour où
// `writeCanonicalX` appellera le jumeau — c'est le prochain chantier — écrire
// une version aurait déclenché `saveAnswers`, donc la canonicalisation, donc
// sa branche « fait absent », donc `writeCanonicalX` à nouveau. Boucle infinie
// au démarrage.
//
// Le jumeau écrit donc désormais ses propres clés, DIRECTEMENT :
// le registre dans le coffre où il est scellé, la révision et l'enveloppe dans
// leurs propres entrées de préférences. Il ne lit ni n'écrit plus jamais le
// magasin de réponses. Le garde `twin_backend_is_not_reentrant.py` l'exige.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'dart:async';
import 'dart:convert';

import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le registre a été scellé, et le coffre ne le rend plus.
///
/// Ce n'est PAS « pas encore de jumeau » : c'est une histoire qui existe et
/// qu'on ne sait plus lire. Les confondre serait le pire des deux mondes —
/// le jumeau repartirait de zéro et la première écriture recouvrirait
/// définitivement ce que le coffre finirait peut-être par rendre.
class TwinRegistryUnreadable implements Exception {
  const TwinRegistryUnreadable();

  @override
  String toString() =>
      'TwinRegistryUnreadable: le registre est scellé mais le coffre ne le ' // lint-ignore
      'rend pas — ne pas le confondre avec un jumeau vide.'; // lint-ignore
}

class AnswersTwinBackend implements TwinBackend {
  const AnswersTwinBackend();

  /// Le registre des versions, sérialisé. Scellé dans le coffre, parce qu'il
  /// porte les mêmes valeurs sensibles que les faits qu'il enveloppe.
  static const registryKey = 'mint_twin_registry_v1';

  /// La révision, pour l'échange comparé.
  static const revisionKey = 'mint_twin_revision_v1';

  /// Ce que la projection nue ne dit pas : d'où vient chaque valeur, pour
  /// quelle année, si elle est confirmée, jusqu'à quand elle vaut.
  ///
  /// Elle reste EN CLAIR : elle ne porte aucune valeur, seulement des noms de
  /// clés qui figurent déjà dans les préférences sous forme de jetons.
  static const metadataKey = 'mint_twin_meta_v1';

  /// Les clés du jumeau lui-même, qui ne sont ni des faits ni des réponses.
  static const reservedKeys = <String>{registryKey, revisionKey, metadataKey};

  /// Ce que les préférences en clair portent à la place d'une valeur scellée.
  static const securePlaceholder = '__secure__';

  /// Marque qu'un registre a existé, même quand le coffre ne le rend pas.
  ///
  /// Sans elle, une panne du coffre serait indiscernable d'une installation
  /// neuve — et l'écriture suivante recouvrirait une histoire intacte.
  static const registryWrittenKey = 'mint_twin_registry_written_v1';

  @override
  Future<({String? registry, int revision})> read() async {
    final prefs = await SharedPreferences.getInstance();
    final sealed = await SecureWizardStore.read(registryKey);

    if (sealed == null || sealed.isEmpty) {
      // Le coffre ne rend rien. Reste à savoir s'il n'a jamais rien eu.
      if (prefs.getBool(registryWrittenKey) == true) {
        throw const TwinRegistryUnreadable();
      }
      return (registry: null, revision: 0);
    }
    if (sealed == securePlaceholder) {
      // Si la clé cessait d'être classée sensible, le jeton arriverait tel
      // quel jusqu'ici.
      throw const TwinRegistryUnreadable();
    }
    return (registry: sealed, revision: prefs.getInt(revisionKey) ?? 0);
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
    required Map<String, Object?> metadata,
  }) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    return previous.then((_) async {
      try {
        return await _swap(
          expectedRevision: expectedRevision,
          registry: registry,
          metadata: metadata,
        );
      } finally {
        done.complete();
      }
    });
  }

  Future<bool> _swap({
    required int expectedRevision,
    required String registry,
    required Map<String, Object?> metadata,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Écrire par-dessus une histoire qu'on ne sait pas lire la détruirait
    // définitivement. La même règle qu'à la lecture, à la porte de l'écriture.
    final sealed = await SecureWizardStore.read(registryKey);
    if ((sealed == null || sealed.isEmpty) &&
        prefs.getBool(registryWrittenKey) == true) {
      throw const TwinRegistryUnreadable();
    }

    if ((prefs.getInt(revisionKey) ?? 0) != expectedRevision) return false;

    // Le registre d'abord : c'est lui qui porte l'histoire. Si l'écriture des
    // préférences échouait ensuite, la révision resterait en arrière et la
    // version suivante réécrirait par-dessus — rien ne se perd. L'ordre
    // inverse perdrait une version à chaque panne.
    if (!await SecureWizardStore.write(registryKey, registry)) return false;
    await prefs.setBool(registryWrittenKey, true);
    await prefs.setString(metadataKey, json.encode(metadata));
    await prefs.setInt(revisionKey, expectedRevision + 1);
    return true;
  }
}
