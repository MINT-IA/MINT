// Le registre des versions — l'autorité du jumeau financier.
//
// Écrire un fait AJOUTE une version. Rien n'est jamais écrasé : la version
// précédente reçoit sa date de fin et référence son successeur. C'est ce qui
// permet de suivre un déménagement, un mariage, un changement d'emploi — et de
// répondre à « qu'est-ce que MINT savait à ce moment-là ».
//
// Le magasin plat clé-valeur existant n'est PAS remplacé. Il change de rôle :
// il devient la projection de l'état courant, alimentée par ce registre. Le
// jour où les deux divergent, c'est le registre qui a raison — d'où le contrôle
// qui refusera qu'un écran écrive directement dans la projection.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'dart:convert';

import 'package:mint_mobile/services/twin/fact_contract.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

/// Résultat d'une tentative d'ajout.
class AppendOutcome {
  const AppendOutcome._(this.version, this.superseded);

  final FactVersion version;

  /// La version que celle-ci remplace — null pour la première.
  final FactVersion? superseded;
}

class FactRegistry {
  FactRegistry({required String Function() newId, DateTime Function()? now})
      : _newId = newId,
        _now = now ?? DateTime.now;

  /// Générateur d'identifiants injecté : un registre dont les identifiants
  /// dépendent d'une horloge globale n'est pas testable de façon déterministe.
  final String Function() _newId;
  final DateTime Function() _now;

  final List<FactVersion> _versions = [];

  /// Rang de la prochaine écriture. L'horodatage ne suffit pas à ordonner
  /// l'histoire : deux écritures peuvent partager la même horloge.
  int _nextSequence = 0;

  DateTime? _lastRecordedAt;

  /// Toutes les versions, dans l'ordre d'écriture.
  List<FactVersion> get versions => List.unmodifiable(_versions);

  int get length => _versions.length;

  /// Ajoute une version et clôt la précédente du même `factId`.
  ///
  /// L'ancienne version n'est pas supprimée : elle reçoit une date de fin. Le
  /// registre ne perd jamais rien, c'est sa seule raison d'être.
  AppendOutcome append({
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
  }) {
    // Le contrat d'abord : un type absent du catalogue, ou une cardinalité
    // violée, n'entre pas. C'est ce qui empêche chaque nouvel écran
    // d'inventer son propre pseudo-identifiant — et la normalisation future
    // de devoir désambiguïser des historiques devenus inattribuables.
    final violation = FactContracts.violation(factId);
    if (violation != null) {
      throw StateError('contrat des faits : $violation');  // lint-ignore
    }

    // La règle « scalaires uniquement » n'était appliquée qu'à la RELECTURE.
    // L'écriture d'une liste réussissait donc, et c'est le chargement suivant
    // qui levait — une exception qui remonte jusqu'au `catch` du magasin de
    // réponses, lequel rend une carte VIDE. Autrement dit : une seule écriture
    // mal formée faisait disparaître tout le profil visible, au lancement
    // d'après, sans que rien ne désigne la cause.
    //
    // Refuser au moment de la faute plutôt qu'à la relecture, c'est la
    // différence entre une erreur qu'on lit et un profil qui s'efface.
    for (final entry in payload.entries) {
      if (entry.value is Map || entry.value is List) {
        throw StateError(
            'payload « ${entry.key} » : scalaire attendu — un fait qui porte ' // lint-ignore
            'une collection doit être décomposé en plusieurs membres'); // lint-ignore
      }
    }

    final recordedAt = _now().toUtc();

    // L'histoire ne recule pas. Une horloge qui régresse produirait une
    // version close AVANT d'avoir été ouverte.
    final last = _lastRecordedAt;
    if (last != null && recordedAt.isBefore(last)) {
      throw StateError(
          'horloge en régression : \$recordedAt après \$last');  // lint-ignore
    }
    // Et MINT n'enregistre pas aujourd'hui une déclaration faite demain.
    if (assertedAt.toUtc().isAfter(recordedAt)) {
      throw StateError(
          'déclaration postérieure à son enregistrement');  // lint-ignore
    }

    final previousIndex = _currentIndexOf(factId);
    final previous = previousIndex == null ? null : _versions[previousIndex];

    final version = FactVersion(
      sequence: _nextSequence++,
      factId: factId,
      versionId: _newId(),
      factType: factType,
      payload: Map<String, Object?>.unmodifiable(payload),
      effectiveFrom: effectiveFrom?.toUtc(),
      fiscalYear: fiscalYear,
      assertedAt: assertedAt.toUtc(),
      recordedAt: recordedAt,
      source: source,
      status: status,
      validUntil: validUntil?.toUtc(),
      needsConfirmation: needsConfirmation,
      supersedesVersionId: previous?.versionId,
      schemaVersion: schemaVersion,
      consentRef: consentRef,
    );

    if (previousIndex != null) {
      // La précédente cesse d'être vraie quand la suivante commence à
      // l'être — SI on sait quand. Sinon on ne fabrique pas la date : une fin
      // inconnue reste inconnue.
      _versions[previousIndex] = previous!.supersededBy(
        version.versionId,
        recordedAt,
        effectiveUntil: effectiveFrom,
      );
    }
    _versions.add(version);
    _lastRecordedAt = recordedAt;
    return AppendOutcome._(version, previous);
  }

  /// La version en vigueur d'un fait, ou null s'il n'y en a jamais eu.
  FactVersion? current(String factId) {
    final index = _currentIndexOf(factId);
    return index == null ? null : _versions[index];
  }

  /// L'état courant de tous les faits — la projection.
  List<FactVersion> currentVersions() =>
      _versions.where((v) => v.isCurrent).toList(growable: false);

  /// L'historique d'un fait, du plus ancien au plus récent.
  List<FactVersion> history(String factId) =>
      _versions.where((v) => v.factId == factId).toList(growable: false);

  /// Ce qui était VRAI de ce fait à cet instant — temps métier.
  ///
  /// À ne pas confondre avec [asOf], qui répond à « que savait MINT ». Les
  /// deux divergent dès qu'une correction est rétroactive : quelqu'un qui
  /// déclare en août avoir déménagé en mars rend `trueAt(avril)` égal à la
  /// NOUVELLE version — elle était vraie en avril — pendant que `asOf(avril)`
  /// rend l'ancienne, qui était tout ce que MINT savait alors.
  ///
  /// C'est cette distinction qui permet de reconstruire une déclaration
  /// fiscale après coup sans réécrire l'histoire.
  ///
  /// Une version SANS date d'effet ne répond pas : elle ne dit pas depuis
  /// quand elle vaut, et l'inventer serait pire que se taire. Elle est donc
  /// ignorée ici — dégradation explicite, cohérente avec `coversFiscalYear`.
  FactVersion? trueAt(String factId, DateTime moment) {
    final instant = moment.toUtc();
    FactVersion? found;
    for (final version in _versions) {
      if (version.factId != factId) continue;
      final from = version.effectiveFrom;
      if (from == null || from.isAfter(instant)) continue;
      final until = version.effectiveTo;
      if (until != null && !until.isAfter(instant)) continue;
      // À période égale, la connaissance la PLUS RÉCENTE l'emporte : une
      // correction postérieure décrit mieux le passé que la déclaration
      // d'origine.
      if (found == null || version.sequence > found.sequence) found = version;
    }
    return found;
  }

  /// Ce que MINT savait de ce fait à cet instant.
  ///
  /// C'est la question qui justifie tout le dispositif : sans elle, un
  /// historique n'est qu'un tas de lignes.
  ///
  /// À horodatage ÉGAL, c'est le rang d'écriture qui départage — la dernière
  /// version écrite à cet instant. Sans cette règle, deux écritures à la même
  /// seconde rendaient la réponse ambiguë, et une troisième la réécrivait.
  FactVersion? asOf(String factId, DateTime moment) {
    final instant = moment.toUtc();
    FactVersion? found;
    for (final version in _versions) {
      if (version.factId != factId) continue;
      if (version.recordedAt.isAfter(instant)) continue;
      final ended = version.supersededAt;
      // Une version close À l'instant demandé n'est plus celle en vigueur ;
      // sa remplaçante, écrite au même instant, l'est.
      if (ended != null && !ended.isAfter(instant)) continue;
      if (found == null || version.sequence > found.sequence) found = version;
    }
    return found;
  }

  int? _currentIndexOf(String factId) {
    for (var i = _versions.length - 1; i >= 0; i--) {
      if (_versions[i].factId == factId && _versions[i].isCurrent) return i;
    }
    return null;
  }

  // ─── Sérialisation ────────────────────────────────────────────────────

  String encode() =>
      jsonEncode(_versions.map((v) => v.toJson()).toList(growable: false));

  /// Lecture STRICTE : une entrée illisible fait échouer tout le chargement.
  ///
  /// Sauter une entrée corrompue amputerait l'historique en silence, et un
  /// historique amputé qui se croit entier est pire que pas d'historique.
  void decode(String content) {
    final raw = jsonDecode(content);
    if (raw is! List) {
      throw const FormatException('registre : liste de versions attendue');  // lint-ignore
    }
    final loaded = <FactVersion>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) {
        throw FormatException('entrée $i : objet attendu', '$entry');  // lint-ignore
      }
      loaded.add(FactVersion.fromJson(Map<String, Object?>.from(entry)));
    }
    _assertCoherent(loaded);

    // Publication atomique : le registre n'est remplacé qu'une fois tout lu
    // ET tout validé. Publier atomiquement un registre corrompu ne vaut pas
    // mieux que le publier morceau par morceau.
    _versions
      ..clear()
      ..addAll(loaded);
    _nextSequence =
        loaded.isEmpty ? 0 : loaded.map((v) => v.sequence).reduce(_max) + 1;
    _lastRecordedAt = loaded.isEmpty
        ? null
        : loaded.map((v) => v.recordedAt).reduce(_latest);
  }

  static int _max(int a, int b) => a > b ? a : b;
  static DateTime _latest(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Contrôles portant sur l'ENSEMBLE, que la lecture ligne à ligne ne peut
  /// pas faire. Chacun correspond à un registre qui passait alors qu'il était
  /// incohérent.
  static void _assertCoherent(List<FactVersion> loaded) {
    final seenVersionIds = <String>{};
    final seenSequences = <int>{};
    final currentPerFact = <String, int>{};
    final typePerFact = <String, String>{};

    for (final v in loaded) {
      final violation = FactContracts.violation(v.factId);
      if (violation != null) {
        throw FormatException('contrat des faits : $violation');  // lint-ignore
      }
      if (!seenVersionIds.add(v.versionId)) {
        throw FormatException('version « ${v.versionId} » en double');  // lint-ignore
      }
      if (!seenSequences.add(v.sequence)) {
        throw FormatException('rang ${v.sequence} en double');  // lint-ignore
      }
      final knownType = typePerFact[v.factId];
      if (knownType != null && knownType != v.factType) {
        throw FormatException(
            'le fait « ${v.factId} » change de type');  // lint-ignore
      }
      typePerFact[v.factId] = v.factType;
      if (v.isCurrent) {
        currentPerFact[v.factId] = (currentPerFact[v.factId] ?? 0) + 1;
      }
    }

    for (final entry in currentPerFact.entries) {
      if (entry.value > 1) {
        throw FormatException(
            'le fait « ${entry.key} » a ${entry.value} versions courantes');  // lint-ignore
      }
    }

    for (final v in loaded) {
      final supersedes = v.supersedesVersionId;
      if (supersedes != null && !seenVersionIds.contains(supersedes)) {
        throw FormatException(
            'chaîne rompue : ${v.versionId} remplace une version absente');  // lint-ignore
      }
    }
  }

  /// Toutes les clés que ce registre a un jour projetées, pierres tombales
  /// comprises.
  ///
  /// C'est ce qui permet au support d'effacer de la projection la valeur d'un
  /// fait supprimé : sans elle, une pierre tombale laisserait sa valeur
  /// visible — le fait serait supprimé pour le registre et bien présent pour
  /// les écrans.
  Set<String> ownedKeys() {
    final keys = <String>{};
    for (final version in _versions) {
      keys.addAll(version.payload.keys);
    }
    return keys;
  }

  /// Copie indépendante. Sert à préparer une écriture sans toucher au
  /// registre de l'appelant tant que rien n'est persisté.
  FactRegistry clone() {
    final copy = FactRegistry(newId: _newId, now: _now == DateTime.now ? null : _now);
    copy._versions.addAll(_versions);
    copy._nextSequence = _nextSequence;
    copy._lastRecordedAt = _lastRecordedAt;
    return copy;
  }

  void debugClear() => _versions.clear();
}
