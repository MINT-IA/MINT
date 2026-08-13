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
    final recordedAt = _now().toUtc();
    final previousIndex = _currentIndexOf(factId);
    final previous = previousIndex == null ? null : _versions[previousIndex];

    final version = FactVersion(
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
      _versions[previousIndex] =
          previous!.supersededBy(version.versionId, recordedAt);
    }
    _versions.add(version);
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

  /// Ce que MINT savait de ce fait à cet instant.
  ///
  /// C'est la question qui justifie tout le dispositif : sans elle, un
  /// historique n'est qu'un tas de lignes.
  FactVersion? asOf(String factId, DateTime moment) {
    final instant = moment.toUtc();
    FactVersion? found;
    for (final version in _versions) {
      if (version.factId != factId) continue;
      if (version.recordedAt.isAfter(instant)) continue;
      final ended = version.effectiveTo;
      if (ended != null && !ended.isAfter(instant)) continue;
      found = version;
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
    // Publication atomique : le registre n'est remplacé qu'une fois tout lu.
    _versions
      ..clear()
      ..addAll(loaded);
  }

  void debugClear() => _versions.clear();
}
