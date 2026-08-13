// La transaction du jumeau — registre et projection écrits ensemble, ou pas
// du tout.
//
// POURQUOI
//
// Le registre des versions vit en mémoire ; le magasin plat clé-valeur est ce
// que lisent les écrans. Tant que les deux sont écrits séparément, une panne
// entre les deux écritures laisse un jumeau qui se contredit : une version
// ajoutée dont la projection ignore l'existence, ou l'inverse. Et deux
// processus qui écrivent en même temps peuvent perdre une version, ou en
// laisser deux courantes pour le même fait.
//
// La relecture adversariale du registre a nommé ce manque comme le principal.
// Il est traité ici par deux moyens, et aucun n'est une promesse :
//
//   * UNE SEULE écriture porte le registre ET sa projection. Elle réussit
//     entièrement ou échoue entièrement.
//   * La lecture emporte une révision ; l'écriture la rend. Si l'état a bougé
//     entre-temps, l'écriture est REFUSÉE plutôt que d'écraser ce qu'un autre
//     vient d'écrire.
//
// La projection n'est jamais fournie par l'appelant : elle est DÉRIVÉE du
// registre. C'est ce qui empêche les deux de diverger — un écran ne peut pas
// écrire dans la projection sans passer par une version.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

/// Ce qu'une lecture rend : l'état, et la révision qui permettra d'écrire.
class TwinSnapshot {
  const TwinSnapshot({required this.registry, required this.revision});

  final FactRegistry registry;

  /// Ce que l'état valait au moment de la lecture. Une écriture qui ne la
  /// rend pas exacte sera refusée.
  final int revision;
}

/// Levée quand l'état a changé depuis la lecture.
///
/// Ce n'est pas une erreur technique : c'est la seule réponse honnête à deux
/// écritures concurrentes. L'appelant relit et recommence.
class TwinConcurrencyException implements Exception {
  const TwinConcurrencyException(this.expected, this.actual);

  final int expected;
  final int actual;

  @override
  String toString() =>
      'TwinConcurrencyException(lu à la révision $expected, état à $actual)';  // lint-ignore
}

/// Le support de stockage. Une seule méthode d'écriture, qui porte les deux
/// contenus : impossible d'en écrire un sans l'autre.
abstract interface class TwinBackend {
  Future<({String? registry, int revision})> read();

  /// Écrit registre ET projection en une opération. Doit être atomique :
  /// après un échec, le support garde son état précédent.
  Future<void> write({
    required String registry,
    required Map<String, Object?> projection,
    required int revision,
  });
}

class TwinStore {
  TwinStore(this._backend, {required String Function() newId,
      DateTime Function()? now})
      : _newId = newId,
        _now = now;

  final TwinBackend _backend;
  final String Function() _newId;
  final DateTime Function()? _now;

  /// Lit l'état complet. Un registre illisible fait échouer la lecture — un
  /// jumeau amputé qui se croit entier est pire qu'un jumeau absent.
  Future<TwinSnapshot> read() async {
    final stored = await _backend.read();
    final registry = FactRegistry(newId: _newId, now: _now);
    final content = stored.registry;
    if (content != null && content.isNotEmpty) {
      registry.decode(content);
    }
    return TwinSnapshot(registry: registry, revision: stored.revision);
  }

  /// Ajoute une version et publie la projection qui en découle, en une seule
  /// écriture.
  ///
  /// Rend la version ajoutée. Lève [TwinConcurrencyException] si l'état a
  /// bougé depuis la lecture — dans ce cas RIEN n'est écrit, et l'appelant
  /// relit avant de recommencer.
  Future<FactVersion> append(
    TwinSnapshot snapshot, {
    required String factId,
    required String factType,
    required Map<String, Object?> payload,
    required DateTime assertedAt,
    required FactSource source,
    FactStatus status = FactStatus.confirmed,
    DateTime? effectiveFrom,
    int? fiscalYear,
    DateTime? validUntil,
    bool needsConfirmation = false,
    int schemaVersion = 1,
    String? consentRef,
  }) async {
    final current = await _backend.read();
    if (current.revision != snapshot.revision) {
      // Refuser plutôt qu'écraser. L'autre écriture a peut-être ajouté une
      // version que celle-ci ne connaît pas ; publier par-dessus la perdrait.
      throw TwinConcurrencyException(snapshot.revision, current.revision);
    }

    final version = snapshot.registry
        .append(
          factId: factId,
          factType: factType,
          payload: payload,
          assertedAt: assertedAt,
          source: source,
          status: status,
          effectiveFrom: effectiveFrom,
          fiscalYear: fiscalYear,
          validUntil: validUntil,
          needsConfirmation: needsConfirmation,
          schemaVersion: schemaVersion,
          consentRef: consentRef,
        )
        .version;

    await _backend.write(
      registry: snapshot.registry.encode(),
      projection: projectionOf(snapshot.registry),
      revision: snapshot.revision + 1,
    );
    return version;
  }

  /// La projection, DÉRIVÉE du registre et jamais fournie de l'extérieur.
  ///
  /// C'est la garantie que les deux ne divergent pas : il n'existe aucun
  /// chemin pour écrire dans la projection sans ajouter une version.
  static Map<String, Object?> projectionOf(FactRegistry registry) {
    final projection = <String, Object?>{};
    for (final version in registry.currentVersions()) {
      projection.addAll(version.payload);
    }
    return Map<String, Object?>.unmodifiable(projection);
  }
}
