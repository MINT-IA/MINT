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

class MintNext3aFiscalContext {
  const MintNext3aFiscalContext({
    this.contextVersion = 2,
    required this.taxYear,
    required this.effectiveAt,
    this.domicile,
  });

  final int contextVersion;
  final int taxYear;
  final DateTime effectiveAt;

  /// Null while no confirmed domicile fact exists.
  final MintNext3aDomicileContext? domicile;
  static const capability = 'no_attested_engine';

  bool get domicileKnown => domicile != null;

  Map<String, Object> toJson() => {
        'context_version': contextVersion,
        'tax_year': taxYear,
        'effective_at': effectiveAt.toUtc().toIso8601String(),
        'capability': capability,
        'domicile_status': domicileKnown ? 'known' : 'missing',
        if (domicile != null) 'domicile': domicile!.toJson(),
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
