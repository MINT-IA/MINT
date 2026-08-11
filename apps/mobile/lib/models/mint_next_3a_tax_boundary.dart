/// Canonical fiscal-domicile summary as seen by the 3a preparation.
///
/// Read from the confirmed domicile fact; null means the fact is missing and
/// the preparation must show it as such — never guess a location.
class MintNext3aDomicileContext {
  const MintNext3aDomicileContext({
    required this.canton,
    required this.communeName,
    this.communeBfs,
    required this.revision,
  });

  final String canton;
  final String communeName;
  final int? communeBfs;

  /// Fingerprint of the underlying fact (assertedAt UTC). Any fiscal
  /// derivative must be bound to it and treated stale when it changes.
  final String revision;

  Map<String, Object?> toJson() => {
        'canton': canton,
        'commune_name': communeName,
        'commune_bfs': communeBfs,
        'revision': revision,
      };

  /// Un fait en attente de confirmation n'est PAS un domicile connu :
  /// le contrat du consommateur parle d'un fait confirmé.
  static MintNext3aDomicileContext? fromConfirmedFact(Object? fact) {
    if (fact is! ConfirmedDomicileSource) return null;
    return fact.toConfirmedDomicileContext();
  }
}

/// Implémenté par le fait domicile canonique — évite une dépendance inverse.
abstract interface class ConfirmedDomicileSource {
  MintNext3aDomicileContext? toConfirmedDomicileContext();
}

/// Situation civile canonique vue par la préparation 3a.
///
/// Distingue l'imposition commune (mariage, partenariat enregistré — LIFD
/// art. 9 al. 1bis) de la séparée. Null = fait manquant : la préparation
/// l'affiche comme tel, jamais de statut deviné.
class MintNext3aCivilStatusContext {
  const MintNext3aCivilStatusContext({
    required this.statusToken,
    required this.jointTaxation,
    required this.revision,
  });

  /// Token stable sans accent (celibataire|marie|partenariat_enregistre|
  /// concubinage|divorce|veuf) — jamais un libellé UI.
  final String statusToken;
  final bool jointTaxation;

  /// Fingerprint du fait (assertedAt UTC) — tout dérivé fiscal lié devient
  /// périmé quand elle change.
  final String revision;

  Map<String, Object?> toJson() => {
        'status': statusToken,
        'joint_taxation': jointTaxation,
        'revision': revision,
      };

  /// Un fait en attente de confirmation n'est PAS une situation connue.
  static MintNext3aCivilStatusContext? fromConfirmedFact(Object? fact) {
    if (fact is! ConfirmedCivilStatusSource) return null;
    return fact.toConfirmedCivilStatusContext();
  }
}

/// Implémenté par le fait état civil canonique — évite une dépendance inverse.
abstract interface class ConfirmedCivilStatusSource {
  MintNext3aCivilStatusContext? toConfirmedCivilStatusContext();
}

class MintNext3aFiscalContext {
  const MintNext3aFiscalContext({
    this.contextVersion = 3,
    required this.taxYear,
    required this.effectiveAt,
    this.domicile,
    this.civilStatus,
  });

  final int contextVersion;
  final int taxYear;
  final DateTime effectiveAt;

  /// Null while no confirmed domicile fact exists.
  final MintNext3aDomicileContext? domicile;

  /// Null while no confirmed civil-status fact exists.
  final MintNext3aCivilStatusContext? civilStatus;
  static const capability = 'no_attested_engine';

  bool get domicileKnown => domicile != null;
  bool get civilStatusKnown => civilStatus != null;

  Map<String, Object> toJson() => {
        'context_version': contextVersion,
        'tax_year': taxYear,
        'effective_at': effectiveAt.toUtc().toIso8601String(),
        'capability': capability,
        'domicile_status': domicileKnown ? 'known' : 'missing',
        if (domicile != null) 'domicile': domicile!.toJson(),
        'civil_status_status': civilStatusKnown ? 'known' : 'missing',
        if (civilStatus != null) 'civil_status': civilStatus!.toJson(),
      };
}

class Pillar3aTaxDeltaRequest {
  const Pillar3aTaxDeltaRequest({required this.context});
  final MintNext3aFiscalContext context;
}

sealed class Pillar3aTaxDeltaResult {
  const Pillar3aTaxDeltaResult();
}

class Pillar3aTaxDeltaUnavailable extends Pillar3aTaxDeltaResult {
  const Pillar3aTaxDeltaUnavailable();

  @override
  bool operator ==(Object other) => other is Pillar3aTaxDeltaUnavailable;
  @override
  int get hashCode => runtimeType.hashCode;
}
