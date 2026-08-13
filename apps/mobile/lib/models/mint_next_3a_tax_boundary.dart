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
    this.declaredAt,
  });

  final String canton;
  final String communeName;
  final int? communeBfs;

  /// Fingerprint of the underlying fact (assertedAt UTC). Any fiscal
  /// derivative must be bound to it and treated stale when it changes.
  final String revision;

  /// Date à laquelle ce domicile a été DÉCLARÉ.
  ///
  /// Ce n'est pas la date à laquelle il était administrativement valable —
  /// MINT ne demande pas encore depuis quand la personne habite là. Faute de
  /// cette date d'effet, le fait ne peut rien dire d'une année antérieure à
  /// sa déclaration : quelqu'un ayant déménagé n'habitait pas forcément là
  /// l'an dernier. On refuse donc de répondre plutôt que de supposer.
  final DateTime? declaredAt;

  /// Ce fait peut-il parler de cette année fiscale ?
  ///
  /// Sans date d'effet, la seule réponse honnête est : à partir de l'année de
  /// la déclaration, pas avant.
  bool coversTaxYear(int taxYear) {
    final declared = declaredAt;
    if (declared == null) return true;
    return taxYear >= declared.toUtc().year;
  }

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

/// Revenu canonique vu par la préparation 3a.
///
/// [annualNetCents] est le revenu NET ENCAISSÉ annualisé — la normalisation
/// (×12 si mensuel) a été appliquée UNE seule fois, par le fait
/// ([MintNextRevenuFact.annualizedCents]) ; ce contexte ne re-multiplie
/// jamais. Null = fait manquant : la préparation l'affiche comme tel.
class MintNext3aRevenuContext {
  const MintNext3aRevenuContext({
    required this.annualNetCents,
    required this.periodToken,
    required this.revision,
  });

  final int annualNetCents;

  /// Trace de la déclaration d'origine (monthly|yearly) — jamais utilisée
  /// pour re-normaliser.
  final String periodToken;

  /// Fingerprint du fait (assertedAt UTC) — tout dérivé fiscal lié devient
  /// périmé quand elle change.
  final String revision;

  Map<String, Object?> toJson() => {
        'annual_net_cents': annualNetCents,
        'declared_period': periodToken,
        'revision': revision,
      };

  /// Un fait en attente de confirmation n'est PAS un revenu connu.
  static MintNext3aRevenuContext? fromConfirmedFact(Object? fact) {
    if (fact is! ConfirmedRevenuSource) return null;
    return fact.toConfirmedRevenuContext();
  }
}

/// Implémenté par le fait revenu canonique — évite une dépendance inverse.
abstract interface class ConfirmedRevenuSource {
  MintNext3aRevenuContext? toConfirmedRevenuContext();
}

/// Affiliation LPP confirmée vue par la préparation 3a.
///
/// Null = INCONNUE (fait absent ou en attente) — jamais « non affilié ».
/// Un « non » confirmé est un vrai contexte avec [affiliated] == false.
class MintNext3aLppAffiliationContext {
  const MintNext3aLppAffiliationContext({
    required this.affiliated,
    required this.revision,
  });

  final bool affiliated;

  /// Fingerprint du fait (assertedAt UTC) — tout dérivé fiscal lié devient
  /// périmé quand elle change.
  final String revision;

  Map<String, Object?> toJson() => {
        'affiliated': affiliated,
        'revision': revision,
      };

  /// Un fait en attente de confirmation n'est PAS une affiliation connue.
  static MintNext3aLppAffiliationContext? fromConfirmedFact(Object? fact) {
    if (fact is! ConfirmedLppAffiliationSource) return null;
    return fact.toConfirmedLppAffiliationContext();
  }
}

/// Implémenté par le fait affiliation LPP canonique.
abstract interface class ConfirmedLppAffiliationSource {
  MintNext3aLppAffiliationContext? toConfirmedLppAffiliationContext();
}

/// Versements 3a de l'année fiscale du contexte, vus par la préparation.
///
/// [totalVerseAnnualCents] est une AGRÉGATION de faits (permise hors moteur
/// attesté) ; la soustraction plafond − total (marge CHF) est une sortie du
/// moteur attesté et n'existe nulle part ici. Null = fait manquant.
class MintNext3aVersementsContext {
  const MintNext3aVersementsContext({
    required this.taxYear,
    required this.totalVerseAnnualCents,
    required this.bucketRevision,
  });

  final int taxYear;
  final int totalVerseAnnualCents;

  /// Révision du bucket annuel — tout dérivé fiscal lié à cette année
  /// devient périmé quand elle change ; une correction d'une autre année ne
  /// la touche pas.
  final String bucketRevision;

  Map<String, Object?> toJson() => {
        'tax_year': taxYear,
        'total_verse_annual_cents': totalVerseAnnualCents,
        'bucket_revision': bucketRevision,
      };

  /// Un fait en attente de confirmation n'est PAS un total connu.
  static MintNext3aVersementsContext? fromConfirmedFact(
      Object? fact, int taxYear) {
    if (fact is! ConfirmedVersements3aSource) return null;
    return fact.toConfirmedVersementsContext(taxYear);
  }
}

/// Implémenté par le fait versements 3a canonique.
abstract interface class ConfirmedVersements3aSource {
  MintNext3aVersementsContext? toConfirmedVersementsContext(int taxYear);
}

class MintNext3aFiscalContext {
  const MintNext3aFiscalContext({
    this.contextVersion = 6,
    required this.taxYear,
    required this.effectiveAt,
    this.domicile,
    this.civilStatus,
    this.revenu,
    this.lppAffiliation,
    this.versements,
  });

  final int contextVersion;
  final int taxYear;
  final DateTime effectiveAt;

  /// Null while no confirmed domicile fact exists.
  final MintNext3aDomicileContext? domicile;

  /// Null while no confirmed civil-status fact exists.
  final MintNext3aCivilStatusContext? civilStatus;

  /// Null while no confirmed revenu fact exists.
  final MintNext3aRevenuContext? revenu;

  /// Null tant que l'affiliation LPP est INCONNUE (fait absent ou en
  /// attente) — jamais un « non » implicite.
  final MintNext3aLppAffiliationContext? lppAffiliation;

  /// Null while no confirmed versements fact exists. Le total est un agrégat
  /// de faits ; AUCUNE marge n'est jamais matérialisée ici.
  final MintNext3aVersementsContext? versements;
  static const capability = 'no_attested_engine';

  /// Un domicile déclaré APRÈS l'année fiscale demandée n'est pas un domicile
  /// connu pour cette année-là. Le contrat de cette frontière est de ne jamais
  /// deviner un lieu ; répondre « Lausanne » pour 2024 parce que la personne
  /// l'a déclaré en 2026 serait précisément une supposition.
  bool get domicileKnown =>
      domicile != null && domicile!.coversTaxYear(taxYear);

  /// Vrai quand un fait existe mais ne peut pas parler de l'année demandée —
  /// à distinguer de l'absence pure, qui appelle une collecte.
  bool get domicileDeclaredAfterTaxYear =>
      domicile != null && !domicile!.coversTaxYear(taxYear);
  bool get civilStatusKnown => civilStatus != null;
  bool get revenuKnown => revenu != null;
  bool get lppAffiliationKnown => lppAffiliation != null;
  bool get versementsKnown => versements != null;

  /// Détermination du plafond 3a (v5) — FAIL-CLOSED, tokens symboliques
  /// seulement (aucun CHF : NoAttestedEngine ; les montants légaux
  /// appartiennent au moteur attesté et à l'année fiscale du contexte).
  /// L'affiliation INCONNUE domine — jamais déduite du statut d'emploi ;
  /// la petite cotisation (20 % du revenu, plafonnée) exige un revenu
  /// confirmé. Aucune marge tant que les versements n'existent pas
  /// (Lego 5) — pas de « plafond − 0 » fictif.
  String get plafond3aDetermination {
    if (!lppAffiliationKnown) return 'undetermined_lpp_affiliation_unknown';
    if (lppAffiliation!.affiliated) return 'lpp_affiliated_max';
    return revenuKnown
        ? 'non_affiliated_20pct_capped'
        : 'undetermined_revenu_missing';
  }

  Map<String, Object> toJson() => {
        'context_version': contextVersion,
        'tax_year': taxYear,
        'effective_at': effectiveAt.toUtc().toIso8601String(),
        'capability': capability,
        'domicile_status': domicileKnown
            ? 'known'
            : domicileDeclaredAfterTaxYear
                ? 'declared_after_tax_year'
                : 'missing',
        if (domicile != null) 'domicile': domicile!.toJson(),
        'civil_status_status': civilStatusKnown ? 'known' : 'missing',
        if (civilStatus != null) 'civil_status': civilStatus!.toJson(),
        'revenu_status': revenuKnown ? 'known' : 'missing',
        if (revenu != null) 'revenu': revenu!.toJson(),
        'lpp_affiliation_status':
            lppAffiliationKnown ? 'known' : 'unknown',
        if (lppAffiliation != null)
          'lpp_affiliation': lppAffiliation!.toJson(),
        'versements_status': versementsKnown ? 'known' : 'missing',
        if (versements != null) 'versements': versements!.toJson(),
        'plafond_3a_determination': plafond3aDetermination,
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
