import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Lego 6 — marge 3a attestée (calcul dérivé scellé, jamais un fait).
///
/// Contrat : `product/mint_next/storyboard/marge_3a_attestee.storyboard.json`.
/// marge_cents = plafond attesté de l'année − total versé canonique, SIGNÉE
/// (un dépassement reste négatif, jamais clampé). Le chiffre n'existe que si
/// TOUT est attesté ; chaque manque est un état nommé, jamais un défaut
/// silencieux. Unique implémentation autorisée du calcul (guard commit-gate :
/// `mon_argent_screen.dart` ne peut pas référencer ce fichier).
class MintNextMarge3aRegulatorySet {
  const MintNextMarge3aRegulatorySet({
    required this.taxYear,
    required this.plafondLppAffiliatedCents,
    required this.grandPlafondCents,
    required this.nonAffiliatedRatePercent,
    required this.source,
    required this.effectivePeriod,
    required this.reviewedAt,
  });

  final int taxYear;
  final int plafondLppAffiliatedCents;
  final int grandPlafondCents;
  final int nonAffiliatedRatePercent;
  final String source;
  final String effectivePeriod;
  final String reviewedAt;

  bool get isComplete =>
      taxYear > 0 &&
      plafondLppAffiliatedCents > 0 &&
      grandPlafondCents > 0 &&
      nonAffiliatedRatePercent > 0 &&
      source.isNotEmpty &&
      effectivePeriod.isNotEmpty &&
      reviewedAt.isNotEmpty;

  /// Sérialisation canonique — la moindre variation de valeur change le hash.
  String get canonicalSerialization =>
      'marge3a-set-v1|$taxYear|$plafondLppAffiliatedCents|$grandPlafondCents'
      '|$nonAffiliatedRatePercent|$source|$effectivePeriod|$reviewedAt';

  String get snapshotHash =>
      sha256.convert(utf8.encode(canonicalSerialization)).toString();
}

/// Registre attesté — année bloquante : une année absente ne produit JAMAIS
/// un chiffre, un hash hors allowlist non plus.
class MintNextMarge3aRegistry {
  /// Plafonds OPP3 art. 7 en vigueur 2025/2026 — valeurs canoniques MINT
  /// (`lib/constants/social_insurance.dart`, mise à jour 2026-03-26,
  /// audit -zaw 2026-07-23) : petit 3a 7'258 CHF, grand 3a 36'288 CHF.
  static const MintNextMarge3aRegulatorySet set2026 =
      MintNextMarge3aRegulatorySet(
    taxYear: 2026,
    plafondLppAffiliatedCents: 725800,
    grandPlafondCents: 3628800,
    nonAffiliatedRatePercent: 20,
    source: 'OPP3 art. 7 — plafonds OFAS 2025/2026, constantes sociales MINT '
        '(social_insurance.dart, màj 2026-03-26, audit 2026-07-23)', // lint-ignore — provenance de données, jamais rendue telle quelle
    effectivePeriod: '2025-01-01..2026-12-31',
    reviewedAt: '2026-03-26',
  );

  static const Map<int, MintNextMarge3aRegulatorySet> sets = {2026: set2026};

  /// Allowlist des snapshots reconnus — recalculée et épinglée par test ;
  /// toute dérive de valeur invalide le jeu au lieu de le laisser passer.
  static const Set<String> allowedSnapshotHashes = {
    '3096cecd2af44aafc61d37c962133dbb62a00013aceeabe11412dc816bca1d39',
  };
}

enum MintNextMarge3aStatus {
  available,
  lppAffiliationUnknown,
  incomeMissing,
  contributionsMissing,
  unsupportedTaxYear,
  regulatoryConstantsUnattested,
  staleInputs,
}

class MintNextMarge3aResult {
  const MintNextMarge3aResult({
    required this.status,
    required this.taxYear,
    this.plafondCents,
    this.totalVerseCents,
    this.margeCents,
    this.constantsVersionHash,
    this.parameterKeys = const [],
    this.inputRevisions = const {},
  });

  final MintNextMarge3aStatus status;
  final int taxYear;
  final int? plafondCents;
  final int? totalVerseCents;

  /// SIGNÉE — négative en dépassement, jamais clampée.
  final int? margeCents;
  final String? constantsVersionHash;
  final List<String> parameterKeys;

  /// Révisions des faits d'entrée au moment du calcul — la péremption se
  /// détecte par égalité STRICTE (toute inégalité = stale).
  final Map<String, String> inputRevisions;
}

class MintNextMarge3aCalculator {
  /// Calcul pur et déterministe : mêmes entrées → même sortie, exact en
  /// centimes. Aucun accès provider/réseau/horloge.
  static MintNextMarge3aResult compute({
    required int taxYear,
    required String plafondDetermination,
    int? annualNetCents,
    String? revenuRevision,
    int? totalVerseCents,
    String? versementsBucketRevision,
    String? lppRevision,
    Map<int, MintNextMarge3aRegulatorySet>? registryOverride,
    Set<String>? allowlistOverride,
  }) {
    // Invariants de l'appelant AVANT tout état métier : une branche
    // inconnue ou un domaine numérique impossible est un bug, pas un état.
    const knownBranches = {
      'undetermined_lpp_affiliation_unknown',
      'undetermined_revenu_missing',
      'lpp_affiliated_max',
      'non_affiliated_20pct_capped',
    };
    if (!knownBranches.contains(plafondDetermination)) {
      throw ArgumentError.value(plafondDetermination, 'plafondDetermination',
          'unknown fiscal boundary branch');
    }
    if (annualNetCents != null && annualNetCents <= 0) {
      throw ArgumentError.value(annualNetCents, 'annualNetCents',
          'a canonical annualized income is strictly positive');
    }
    if (totalVerseCents != null && totalVerseCents < 0) {
      throw ArgumentError.value(totalVerseCents, 'totalVerseCents',
          'a canonical total is never negative');
    }
    // Invariant d'appelant AVANT tout retour métier — y compris quand
    // plusieurs entrées sont simultanément invalides : un revenu fourni sur
    // la branche non-LPP exige sa révision, même si les versements manquent.
    if (plafondDetermination == 'non_affiliated_20pct_capped' &&
        annualNetCents != null &&
        revenuRevision == null) {
      throw ArgumentError.value(revenuRevision, 'revenuRevision',
          'the non affiliated branch requires the revenu fact revision');
    }

    final registry = registryOverride ?? MintNextMarge3aRegistry.sets;
    final allowlist =
        allowlistOverride ?? MintNextMarge3aRegistry.allowedSnapshotHashes;

    final set = registry[taxYear];
    if (set == null) {
      return MintNextMarge3aResult(
        status: MintNextMarge3aStatus.unsupportedTaxYear,
        taxYear: taxYear,
      );
    }
    if (!set.isComplete || !allowlist.contains(set.snapshotHash)) {
      return MintNextMarge3aResult(
        status: MintNextMarge3aStatus.regulatoryConstantsUnattested,
        taxYear: taxYear,
      );
    }

    switch (plafondDetermination) {
      case 'undetermined_lpp_affiliation_unknown':
        return MintNextMarge3aResult(
          status: MintNextMarge3aStatus.lppAffiliationUnknown,
          taxYear: taxYear,
        );
      case 'undetermined_revenu_missing':
        return MintNextMarge3aResult(
          status: MintNextMarge3aStatus.incomeMissing,
          taxYear: taxYear,
        );
      case 'lpp_affiliated_max':
      case 'non_affiliated_20pct_capped':
        break;
    }

    // Les branches déterminées prouvent que le fait LPP existe : sa révision
    // est OBLIGATOIRE pour sceller — une révision omise serait un trou de
    // péremption (un fait corrigé passerait inaperçu à la revalidation).
    if (lppRevision == null) {
      throw ArgumentError.value(lppRevision, 'lppRevision',
          'a determined branch requires the LPP fact revision to seal');
    }

    if (totalVerseCents == null || versementsBucketRevision == null) {
      return MintNextMarge3aResult(
        status: MintNextMarge3aStatus.contributionsMissing,
        taxYear: taxYear,
      );
    }

    final int plafondCents;
    final parameterKeys = <String>[];
    final inputRevisions = <String, String>{
      'versements_bucket': versementsBucketRevision,
      'lpp_affiliation': lppRevision,
    };
    if (plafondDetermination == 'lpp_affiliated_max') {
      plafondCents = set.plafondLppAffiliatedCents;
      parameterKeys.add('plafond_lpp_affiliated_cents');
    } else {
      if (annualNetCents == null) {
        return MintNextMarge3aResult(
          status: MintNextMarge3aStatus.incomeMissing,
          taxYear: taxYear,
        );
      }
      // La branche non-LPP consomme le fait revenu : révision OBLIGATOIRE.
      if (revenuRevision == null) {
        throw ArgumentError.value(revenuRevision, 'revenuRevision',
            'the non affiliated branch requires the revenu fact revision');
      }
      // Arrondi normatif du contrat : floor au centime INFÉRIEUR — jamais
      // surestimer un plafond ; borné au grand plafond.
      final derived = annualNetCents * set.nonAffiliatedRatePercent ~/ 100;
      plafondCents =
          derived < set.grandPlafondCents ? derived : set.grandPlafondCents;
      parameterKeys
        ..add('non_affiliated_rate_percent')
        ..add('grand_plafond_cents');
      inputRevisions['revenu'] = revenuRevision;
    }

    return MintNextMarge3aResult(
      status: MintNextMarge3aStatus.available,
      taxYear: taxYear,
      plafondCents: plafondCents,
      totalVerseCents: totalVerseCents,
      margeCents: plafondCents - totalVerseCents,
      constantsVersionHash: set.snapshotHash,
      parameterKeys: parameterKeys,
      inputRevisions: inputRevisions,
    );
  }

  /// Re-validation d'un résultat contre les révisions ACTUELLES des faits :
  /// toute inégalité stricte (ou clé disparue) rend le résultat périmé.
  static MintNextMarge3aResult revalidate(
    MintNextMarge3aResult result,
    Map<String, String> currentRevisions,
  ) {
    if (result.status != MintNextMarge3aStatus.available) return result;
    for (final entry in result.inputRevisions.entries) {
      if (currentRevisions[entry.key] != entry.value) {
        return MintNextMarge3aResult(
          status: MintNextMarge3aStatus.staleInputs,
          taxYear: result.taxYear,
          inputRevisions: result.inputRevisions,
        );
      }
    }
    return result;
  }
}
