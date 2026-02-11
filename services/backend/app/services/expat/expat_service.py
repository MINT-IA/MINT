"""
Simulateur de planification fiscale pour l'expatriation / impatriation en Suisse.

Couvre le forfait fiscal, la double imposition, les lacunes AVS,
la planification de depart et la comparaison fiscale internationale.

Sources:
    - LIFD art. 14 (imposition d'apres la depense / forfait fiscal)
    - LIFD art. 6, 7 (assujettissement illimite / limite)
    - LAVS art. 1a (assujettissement obligatoire AVS)
    - LAVS art. 2 (assurance facultative AVS pour Suisses a l'etranger)
    - LPP art. 2 (libre passage)
    - OLP art. 10, 16 (prestations de libre passage)
    - OPP2 art. 11 (versement en especes du libre passage)
    - LIFD art. 38 (imposition du capital de prevoyance)
    - Conventions de double imposition (CDI) bilaterales
    - Convention modele OCDE art. 15, 18, 21 (revenus, pensions, autres)
    - CC art. 23 (domicile civil)

Sprint S23 — Expatriation + Frontaliers.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict
from datetime import date

from app.constants.social_insurance import (
    AVS_RENTE_MAX_MENSUELLE as _AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE as _AVS_RENTE_MIN_MENSUELLE,
    AVS_VOLONTAIRE_COTISATION_MIN,
    AVS_VOLONTAIRE_COTISATION_MAX,
    AVS_DUREE_COTISATION_COMPLETE,
)


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ta situation personnelle, du canton, du pays de destination et des "
    "conventions de double imposition en vigueur. Ne constitue pas un "
    "conseil fiscal ou juridique (LSFin/LLCA). Consulte un ou une specialiste."
)

# ---------------------------------------------------------------------------
# Forfait fiscal (imposition d'apres la depense)
# Source: LIFD art. 14, lois cantonales
# ---------------------------------------------------------------------------

# Base minimale forfait fiscal par canton (CHF)
# Source: LIFD art. 14 al. 3 (base minimale federale CHF 400'000)
# Cantons ayant aboli le forfait fiscal: ZH, SH, AR, AI, BS, BL
FORFAIT_FISCAL_BASE_CANTONALE = {
    "VD": 1_000_000,   # LI-VD art. 60 (minimum cantonal VD)
    "GE": 600_000,     # LIPP-GE art. 15 (minimum cantonal GE)
    "VS": 250_000,     # LF-VS art. 12 (minimum cantonal VS)
    "ZG": 500_000,     # StG-ZG § 12 (minimum cantonal ZG)
    "BE": 400_000,     # StG-BE art. 14 (base federale)
    "LU": 400_000,     # StG-LU § 14 (base federale)
    "TI": 400_000,     # LT-TI art. 7 (base federale)
    "FR": 400_000,     # LICD-FR art. 12 (base federale)
    "NE": 500_000,     # LCdir-NE art. 14 (minimum cantonal NE)
    "JU": 400_000,     # LI-JU art. 12 (base federale)
    "SG": 400_000,     # StG-SG art. 12 (base federale)
    "GR": 400_000,     # StG-GR art. 11 (base federale)
    "TG": 400_000,     # StG-TG § 12 (base federale)
    "SO": 400_000,     # StG-SO § 11 (base federale)
    "AG": 400_000,     # StG-AG § 12 (base federale)
    "SZ": 400_000,     # StG-SZ § 12 (base federale)
    "OW": 400_000,     # StG-OW art. 12 (base federale)
    "NW": 400_000,     # StG-NW art. 12 (base federale)
    "UR": 400_000,     # StG-UR art. 12 (base federale)
    "GL": 400_000,     # StG-GL art. 12 (base federale)
}

# Base minimale federale (LIFD art. 14 al. 3)
FORFAIT_FEDERAL_MINIMUM = 400_000  # CHF

# Cantons ayant aboli le forfait fiscal (par votation populaire)
CANTONS_SANS_FORFAIT = {"ZH", "SH", "AR", "AI", "BS", "BL"}

# Taux d'imposition moyen estime pour le forfait fiscal
# (bareme ordinaire applique au montant forfaitaire)
# Source: LIFD art. 36, lois cantonales
FORFAIT_TAUX_ESTIMES = {
    "VD": 0.35, "GE": 0.38, "VS": 0.28, "ZG": 0.22,
    "BE": 0.32, "LU": 0.30, "TI": 0.33, "FR": 0.34,
    "NE": 0.36, "JU": 0.37, "SG": 0.30, "GR": 0.30,
    "TG": 0.28, "SO": 0.31, "AG": 0.30, "SZ": 0.24,
    "OW": 0.28, "NW": 0.26, "UR": 0.29, "GL": 0.30,
}
_DEFAULT_FORFAIT_TAUX = 0.32

# ---------------------------------------------------------------------------
# Conventions de double imposition (CDI)
# Source: CDI bilaterales CH, convention modele OCDE
# ---------------------------------------------------------------------------

CDI_PARTENAIRES = {
    "FR": {
        "label": "France",
        "date_convention": "1966 (revisee 2009)",
        "pension_avs": "residence",  # Art. 20 CDI CH-FR: pensions imposees a la residence
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,  # Art. 11 CDI CH-FR: 15% max retenue a la source
        "interets_taux_max": 0.0,     # Art. 12 CDI CH-FR: 0% (pas de retenue)
        "immobilier": "situation",     # Art. 6 CDI CH-FR: imposes dans l'Etat de situation
        "source": "CDI CH-FR du 09.09.1966, revisee (RS 0.672.934.91)",
    },
    "DE": {
        "label": "Allemagne",
        "date_convention": "1971 (revisee 2002)",
        "pension_avs": "residence",
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 0.0,
        "immobilier": "situation",
        "source": "CDI CH-DE du 11.08.1971, revisee (RS 0.672.913.62)",
    },
    "IT": {
        "label": "Italie",
        "date_convention": "1976 (revisee 2020)",
        "pension_avs": "source",  # Exception: pensions publiques CH imposees en CH
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 12.5,
        "immobilier": "situation",
        "source": "CDI CH-IT du 09.03.1976, revisee (RS 0.672.945.41)",
    },
    "AT": {
        "label": "Autriche",
        "date_convention": "1974 (revisee 2012)",
        "pension_avs": "residence",
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 0.0,
        "immobilier": "situation",
        "source": "CDI CH-AT du 30.01.1974, revisee (RS 0.672.916.31)",
    },
    "UK": {
        "label": "Royaume-Uni",
        "date_convention": "1977 (revisee 2007)",
        "pension_avs": "residence",
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 0.0,
        "immobilier": "situation",
        "source": "CDI CH-UK du 08.12.1977, revisee (RS 0.672.936.711)",
    },
    "US": {
        "label": "Etats-Unis",
        "date_convention": "1996",
        "pension_avs": "residence",  # Avec credit d'impot possible
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 0.0,
        "immobilier": "situation",
        "source": "CDI CH-US du 02.10.1996 (RS 0.672.933.61)",
    },
    "ES": {
        "label": "Espagne",
        "date_convention": "1966 (revisee 2011)",
        "pension_avs": "residence",
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 0.0,
        "immobilier": "situation",
        "source": "CDI CH-ES du 26.04.1966, revisee (RS 0.672.933.21)",
    },
    "PT": {
        "label": "Portugal",
        "date_convention": "2012",
        "pension_avs": "residence",
        "pension_lpp": "residence",
        "dividendes_taux_max": 15.0,
        "interets_taux_max": 10.0,
        "immobilier": "situation",
        "source": "CDI CH-PT du 26.09.2012 (RS 0.672.965.41)",
    },
}

# ---------------------------------------------------------------------------
# AVS — cotisations volontaires pour Suisses a l'etranger
# Source: LAVS art. 2, OAVS art. 13bis
# ---------------------------------------------------------------------------

# AVS volontaire — imported from app.constants.social_insurance:
#   AVS_VOLONTAIRE_COTISATION_MIN, AVS_VOLONTAIRE_COTISATION_MAX
# Rente AVS — imported from app.constants.social_insurance:
#   _AVS_RENTE_MAX_MENSUELLE, _AVS_RENTE_MIN_MENSUELLE, AVS_DUREE_COTISATION_COMPLETE

# Local aliases for backward compatibility within this module
AVS_COTISATION_MIN_VOLONTAIRE = AVS_VOLONTAIRE_COTISATION_MIN
AVS_COTISATION_MAX_VOLONTAIRE = AVS_VOLONTAIRE_COTISATION_MAX
AVS_RENTE_MAX_MENSUELLE = _AVS_RENTE_MAX_MENSUELLE
AVS_RENTE_MIN_MENSUELLE = _AVS_RENTE_MIN_MENSUELLE
AVS_ANNEES_COTISATION_PLEINES = AVS_DUREE_COTISATION_COMPLETE

# Reduction de rente par annee de lacune (LAVS art. 29ter, 52c)
AVS_REDUCTION_PAR_ANNEE_LACUNE = round(AVS_RENTE_MAX_MENSUELLE / AVS_ANNEES_COTISATION_PLEINES, 2)

# ---------------------------------------------------------------------------
# Libre passage LPP
# Source: LPP art. 2, LFLP art. 2, 5, OLP art. 10, 16
# ---------------------------------------------------------------------------

# Le capital LPP est transfere sur un compte de libre passage
# si la personne quitte la Suisse (LFLP art. 2 al. 1)
# Versement en especes possible si depart hors UE/AELE (OLP art. 16)
# ou si le montant est inferieur au montant minimal (LPP art. 2 al. 1)

# Delai pour le retrait du 3e pilier apres depart (LIFD art. 38, OPP3 art. 3 al. 2)
DELAI_RETRAIT_3A_ANNEES = 1  # 1 an apres le depart de Suisse

# Taux d'imposition du capital de prevoyance (LIFD art. 38)
# Taux reduit: 1/5 du taux normal
TAUX_IMPOSITION_CAPITAL_PREVOYANCE = {
    "ZH": 0.065, "BE": 0.075, "LU": 0.055, "BS": 0.080,
    "VD": 0.085, "GE": 0.090, "ZG": 0.040, "FR": 0.080,
    "VS": 0.060, "NE": 0.085, "JU": 0.080, "SZ": 0.045,
    "AG": 0.060, "SG": 0.060, "TI": 0.070, "GR": 0.060,
    "TG": 0.055, "BL": 0.070, "AR": 0.055, "AI": 0.050,
    "GL": 0.060, "SH": 0.065, "OW": 0.050, "NW": 0.048,
    "UR": 0.055, "SO": 0.065,
}
_DEFAULT_TAUX_CAPITAL = 0.065

# ---------------------------------------------------------------------------
# Taux d'imposition globaux estimes par pays (revenus + charges sociales)
# Source: OCDE, estimations simplifiees pour un salaire de CHF 100'000
# ---------------------------------------------------------------------------

TAUX_GLOBAL_PAR_PAYS = {
    "CH_ZH": {"label": "Suisse (Zurich)", "taux_impot": 0.22, "taux_social": 0.13, "total": 0.35},
    "CH_GE": {"label": "Suisse (Geneve)", "taux_impot": 0.28, "taux_social": 0.13, "total": 0.41},
    "CH_ZG": {"label": "Suisse (Zoug)", "taux_impot": 0.15, "taux_social": 0.13, "total": 0.28},
    "CH_VS": {"label": "Suisse (Valais)", "taux_impot": 0.24, "taux_social": 0.13, "total": 0.37},
    "CH_VD": {"label": "Suisse (Vaud)", "taux_impot": 0.26, "taux_social": 0.13, "total": 0.39},
    "FR": {"label": "France", "taux_impot": 0.30, "taux_social": 0.23, "total": 0.53},
    "DE": {"label": "Allemagne", "taux_impot": 0.32, "taux_social": 0.21, "total": 0.53},
    "IT": {"label": "Italie", "taux_impot": 0.35, "taux_social": 0.10, "total": 0.45},
    "AT": {"label": "Autriche", "taux_impot": 0.33, "taux_social": 0.18, "total": 0.51},
    "UK": {"label": "Royaume-Uni", "taux_impot": 0.27, "taux_social": 0.12, "total": 0.39},
    "US": {"label": "Etats-Unis", "taux_impot": 0.28, "taux_social": 0.08, "total": 0.36},
    "ES": {"label": "Espagne", "taux_impot": 0.30, "taux_social": 0.06, "total": 0.36},
    "PT": {"label": "Portugal", "taux_impot": 0.28, "taux_social": 0.11, "total": 0.39},
}

# ---------------------------------------------------------------------------
# Checklist de depart
# ---------------------------------------------------------------------------

CHECKLIST_DEPART = [
    {"priorite": "haute", "action": "Annoncer le depart a la commune de domicile (CC art. 23)",
     "delai": "Au plus tard le jour du depart"},
    {"priorite": "haute", "action": "Transferer le 2e pilier (LPP) sur un compte de libre passage (LFLP art. 2)",
     "delai": "Dans les 6 mois apres la fin du contrat"},
    {"priorite": "haute", "action": "Retirer ou transferer le 3e pilier (3a) dans l'annee (OPP3 art. 3 al. 2)",
     "delai": "Dans les 12 mois apres le depart de Suisse"},
    {"priorite": "haute", "action": "Remplir la declaration fiscale de l'annee de depart (LIFD art. 42)",
     "delai": "Annee suivant le depart"},
    {"priorite": "haute", "action": "Resilier ou adapter l'assurance maladie LAMal (LAMal art. 3)",
     "delai": "Le jour du depart"},
    {"priorite": "moyenne", "action": "S'inscrire a l'AVS facultative si Suisse a l'etranger (LAVS art. 2)",
     "delai": "Dans les 12 mois apres le depart"},
    {"priorite": "moyenne", "action": "Verifier la convention de double imposition avec le pays de destination",
     "delai": "Avant le depart"},
    {"priorite": "moyenne", "action": "Informer la caisse de compensation AVS du depart (OAVS art. 134)",
     "delai": "30 jours avant le depart"},
    {"priorite": "moyenne", "action": "Cloturer ou maintenir les comptes bancaires suisses",
     "delai": "Avant ou apres le depart"},
    {"priorite": "basse", "action": "Verifier les implications pour le permis de sejour / retour en Suisse",
     "delai": "Avant le depart"},
    {"priorite": "basse", "action": "Optimiser le timing du depart (fin d'annee fiscale = imposition prorata)",
     "delai": "Planification en amont"},
    {"priorite": "basse", "action": "Prevoir une adresse de correspondance en Suisse pour le fisc",
     "delai": "Avant le depart"},
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _estimate_ordinary_tax(revenu: float, canton: str) -> float:
    """Estime l'impot ordinaire total (IFD + cantonal + communal).

    Estimation simplifiee basee sur un taux effectif moyen par canton.
    Source: LIFD art. 36, lois cantonales.
    """
    if revenu <= 0:
        return 0.0
    canton_key = f"CH_{canton.upper()}"
    data = TAUX_GLOBAL_PAR_PAYS.get(canton_key)
    if data:
        taux = data["taux_impot"]
    else:
        taux = 0.25  # estimation par defaut
    return round(revenu * taux, 2)


# ---------------------------------------------------------------------------
# Dataclasses de resultat
# ---------------------------------------------------------------------------

@dataclass
class ForfaitFiscalResult:
    """Resultat de la simulation du forfait fiscal."""
    canton: str                         # Canton de residence
    eligible: bool                      # Eligible au forfait fiscal
    base_forfaitaire: float             # Base forfaitaire retenue (CHF)
    depenses_reelles: float             # Depenses de train de vie declarees (CHF)
    revenu_reel: float                  # Revenu reel declare (CHF)
    impot_forfait: float                # Impot sur la base forfaitaire (CHF)
    impot_ordinaire: float              # Impot ordinaire sur le revenu reel (CHF)
    economie: float                     # Economie forfait vs ordinaire (CHF)
    conditions: List[str]               # Conditions d'eligibilite
    recommandation: str                 # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class DoubleTaxationResult:
    """Resultat de l'analyse de double imposition."""
    pays_residence: str                 # Pays de residence
    convention_existe: bool             # CDI en vigueur
    date_convention: str                # Date de la convention
    repartition: Dict[str, str]         # Type de revenu -> pays qui impose
    taux_dividendes_max: float          # Retenue a la source max sur dividendes (%)
    taux_interets_max: float            # Retenue a la source max sur interets (%)
    optimisations: List[str]            # Conseils d'optimisation
    recommandation: str                 # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class AVSGapResult:
    """Resultat de l'estimation des lacunes AVS."""
    annees_cotisation_ch: int           # Annees de cotisation en Suisse
    annees_a_letranger: int             # Annees a l'etranger
    annees_totales: int                 # Total des annees
    annees_manquantes: int              # Annees manquantes pour rente complete
    rente_estimee_mensuelle: float      # Rente AVS estimee mensuelle (CHF)
    rente_max_mensuelle: float          # Rente AVS maximale mensuelle (CHF)
    reduction_mensuelle: float          # Reduction mensuelle (CHF)
    reduction_annuelle: float           # Reduction annuelle (CHF)
    cotisation_volontaire_possible: bool  # Peut cotiser a l'AVS facultative
    cotisation_min: float               # Cotisation min annuelle (CHF)
    cotisation_max: float               # Cotisation max annuelle (CHF)
    recommandation: str                 # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class DeparturePlanResult:
    """Resultat de la planification de depart."""
    date_depart: str                    # Date de depart prevue
    canton: str                         # Canton actuel
    pillar_3a_balance: float            # Solde 3e pilier (CHF)
    lpp_balance: float                  # Solde LPP (CHF)
    impot_capital_3a: float             # Impot sur le retrait 3a (CHF)
    impot_capital_lpp: float            # Impot sur le retrait LPP (CHF)
    delai_retrait_3a: str               # Delai pour retirer le 3a
    checklist: List[Dict[str, str]]     # Checklist de depart
    timing_optimal: str                 # Conseil sur le timing optimal
    recommandation: str                 # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class TaxComparisonResult:
    """Resultat de la comparaison fiscale internationale."""
    salaire_brut: float                 # Salaire brut annuel (CHF)
    canton: str                         # Canton CH actuel
    pays_cible: str                     # Pays de destination
    # Suisse
    impot_ch: float                     # Impot total CH (CHF)
    charges_sociales_ch: float          # Charges sociales CH (CHF)
    total_ch: float                     # Total prelevements CH (CHF)
    net_ch: float                       # Revenu net CH (CHF)
    # Pays cible
    impot_cible: float                  # Impot total pays cible (CHF)
    charges_sociales_cible: float       # Charges sociales pays cible (CHF)
    total_cible: float                  # Total prelevements pays cible (CHF)
    net_cible: float                    # Revenu net pays cible (CHF)
    # Comparaison
    difference_nette: float             # Net CH - Net cible (positif = CH avantageux)
    exit_tax_note: str                  # Note sur l'exit tax
    recommandation: str                 # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class ExpatService:
    """Simulateur de planification fiscale pour l'expatriation/impatriation.

    Regles cles:
    - Forfait fiscal: disponible pour non-Suisses sans activite lucrative en CH
      (LIFD art. 14), aboli dans certains cantons
    - Pas d'exit tax en Suisse (contrairement a FR, DE, US) — avantage majeur
    - CDI bilaterales: ~100 conventions, repartition de l'imposition
    - AVS: lacunes possibles si annees a l'etranger (LAVS art. 29ter)
    - LPP: libre passage obligatoire au depart (LFLP art. 2)
    - 3a: retrait dans les 12 mois apres depart (OPP3 art. 3 al. 2)
    """

    def simulate_forfait_fiscal(
        self,
        canton: str,
        living_expenses: float,
        actual_income: float,
    ) -> ForfaitFiscalResult:
        """Simule le forfait fiscal (imposition d'apres la depense).

        Le forfait fiscal est reserve aux personnes de nationalite etrangere
        qui s'etablissent en Suisse pour la premiere fois ou apres une absence
        de 10 ans, et qui n'exercent pas d'activite lucrative en Suisse.

        Args:
            canton: Canton de residence (2 lettres).
            living_expenses: Depenses de train de vie annuelles (CHF).
            actual_income: Revenu reel annuel (CHF).

        Returns:
            ForfaitFiscalResult avec l'analyse.
        """
        canton_upper = canton.upper()

        # Verifier eligibilite
        if canton_upper in CANTONS_SANS_FORFAIT:
            return ForfaitFiscalResult(
                canton=canton_upper,
                eligible=False,
                base_forfaitaire=0.0,
                depenses_reelles=living_expenses,
                revenu_reel=actual_income,
                impot_forfait=0.0,
                impot_ordinaire=_estimate_ordinary_tax(actual_income, canton_upper),
                economie=0.0,
                conditions=[
                    f"Le canton {canton_upper} a aboli le forfait fiscal par votation populaire."
                ],
                recommandation=(
                    f"Le forfait fiscal n'est pas disponible dans le canton {canton_upper}. "
                    f"Cantons ayant aboli : {', '.join(sorted(CANTONS_SANS_FORFAIT))}. "
                    f"Envisage un autre canton si le forfait fiscal est important pour toi."
                ),
                sources=[
                    "LIFD art. 14 (imposition d'apres la depense)",
                    f"Votation cantonale {canton_upper} (abolition du forfait fiscal)",
                ],
            )

        # Base forfaitaire = max(base cantonale, base federale, 7x loyer annuel estime)
        base_cantonale = FORFAIT_FISCAL_BASE_CANTONALE.get(canton_upper, FORFAIT_FEDERAL_MINIMUM)
        base_federale = FORFAIT_FEDERAL_MINIMUM
        base_depenses = living_expenses  # Les depenses de train de vie
        base_forfaitaire = max(base_cantonale, base_federale, base_depenses)

        # Impot sur le forfait
        taux_forfait = FORFAIT_TAUX_ESTIMES.get(canton_upper, _DEFAULT_FORFAIT_TAUX)
        impot_forfait = round(base_forfaitaire * taux_forfait, 2)

        # Impot ordinaire pour comparaison
        impot_ordinaire = _estimate_ordinary_tax(actual_income, canton_upper)

        economie = round(impot_ordinaire - impot_forfait, 2)

        conditions = [
            "Nationalite etrangere (pas de nationalite suisse)",
            "Premiere installation en Suisse ou retour apres 10 ans d'absence",
            "Pas d'activite lucrative en Suisse",
            f"Base minimale: CHF {base_cantonale:,.0f} (canton {canton_upper})",
            f"Base minimale federale: CHF {base_federale:,.0f} (LIFD art. 14 al. 3)",
        ]

        if economie > 0:
            recommandation = (
                f"Le forfait fiscal dans le canton {canton_upper} pourrait te permettre "
                f"d'economiser environ CHF {economie:,.0f}/an par rapport a l'imposition "
                f"ordinaire. Base forfaitaire: CHF {base_forfaitaire:,.0f}. "
                f"Impot forfaitaire estime: CHF {impot_forfait:,.0f}/an."
            )
        else:
            recommandation = (
                f"L'imposition ordinaire est plus avantageuse que le forfait fiscal "
                f"dans ton cas (difference: CHF {abs(economie):,.0f}/an). "
                f"Le forfait fiscal n'est interessant que si ton revenu reel depasse "
                f"significativement la base forfaitaire."
            )

        sources = [
            "LIFD art. 14 (imposition d'apres la depense / forfait fiscal)",
            "LIFD art. 14 al. 3 (base minimale CHF 400'000)",
            f"Loi cantonale {canton_upper} (base minimale cantonale)",
            "ATF 135 II 274 (conditions du forfait fiscal)",
        ]

        return ForfaitFiscalResult(
            canton=canton_upper,
            eligible=True,
            base_forfaitaire=base_forfaitaire,
            depenses_reelles=living_expenses,
            revenu_reel=actual_income,
            impot_forfait=impot_forfait,
            impot_ordinaire=impot_ordinaire,
            economie=economie,
            conditions=conditions,
            recommandation=recommandation,
            sources=sources,
        )

    def check_double_taxation(
        self,
        residence_country: str,
        income_types: Optional[List[str]] = None,
    ) -> DoubleTaxationResult:
        """Analyse la repartition de l'imposition selon la CDI applicable.

        Args:
            residence_country: Code pays de residence (FR, DE, IT, AT, UK, US, ES, PT).
            income_types: Types de revenus a analyser (salaire, pension_avs, pension_lpp,
                         dividendes, interets, immobilier). Si None, tous les types.

        Returns:
            DoubleTaxationResult avec la repartition.
        """
        country = residence_country.upper()
        cdi = CDI_PARTENAIRES.get(country)

        if income_types is None:
            income_types = ["salaire", "pension_avs", "pension_lpp",
                          "dividendes", "interets", "immobilier"]

        if cdi is None:
            return DoubleTaxationResult(
                pays_residence=country,
                convention_existe=False,
                date_convention="N/A",
                repartition={t: "a verifier (pas de CDI repertoriee)" for t in income_types},
                taux_dividendes_max=0.0,
                taux_interets_max=0.0,
                optimisations=[
                    "Verifie si une convention de double imposition existe avec ce pays.",
                    "Sans CDI, risque de double imposition effective.",
                    "Consulte un fiscaliste specialise en droit international.",
                ],
                recommandation=(
                    f"Pas de convention de double imposition repertoriee avec {country}. "
                    f"La Suisse a signe ~100 CDI. Verifie sur le site du SFI (Secretariat "
                    f"d'Etat aux questions financieres internationales)."
                ),
                sources=[
                    "Convention modele OCDE (base des CDI bilaterales)",
                    "SFI — liste des CDI suisses (www.sif.admin.ch)",
                ],
            )

        # Construire la repartition
        repartition = {}
        for income_type in income_types:
            if income_type == "salaire":
                repartition["salaire"] = "Etat d'exercice de l'activite (convention modele OCDE art. 15)"
            elif income_type == "pension_avs":
                if cdi["pension_avs"] == "residence":
                    repartition["pension_avs"] = f"Impose dans l'Etat de residence ({cdi['label']})"
                else:
                    repartition["pension_avs"] = "Impose dans l'Etat source (Suisse)"
            elif income_type == "pension_lpp":
                if cdi["pension_lpp"] == "residence":
                    repartition["pension_lpp"] = f"Impose dans l'Etat de residence ({cdi['label']})"
                else:
                    repartition["pension_lpp"] = "Impose dans l'Etat source (Suisse)"
            elif income_type == "dividendes":
                repartition["dividendes"] = (
                    f"Retenue a la source max {cdi['dividendes_taux_max']}%, "
                    f"avec credit d'impot dans l'Etat de residence"
                )
            elif income_type == "interets":
                if cdi["interets_taux_max"] == 0:
                    repartition["interets"] = "Pas de retenue a la source (0%), impose a la residence"
                else:
                    repartition["interets"] = (
                        f"Retenue a la source max {cdi['interets_taux_max']}%, "
                        f"avec credit d'impot"
                    )
            elif income_type == "immobilier":
                repartition["immobilier"] = "Impose dans l'Etat de situation du bien (OCDE art. 6)"

        optimisations = [
            "La Suisse n'a PAS d'exit tax — tu peux quitter sans impot sur les plus-values latentes.",
            f"Planifie le timing du depart pour optimiser la declaration de l'annee de depart.",
        ]
        if cdi.get("pension_avs") == "residence":
            optimisations.append(
                f"Tes rentes AVS seront imposees en {cdi['label']} — verifie si le taux y est avantageux."
            )
        if cdi.get("dividendes_taux_max", 0) > 0:
            optimisations.append(
                f"Les dividendes de source suisse auront une retenue de max {cdi['dividendes_taux_max']}% — "
                f"recuperable par la procedure de degrevement (formulaire DA-1)."
            )

        recommandation = (
            f"Convention de double imposition CH-{country} ({cdi['date_convention']}) : "
            f"la repartition de l'imposition est definie pour chaque type de revenu. "
            f"La Suisse n'applique PAS d'exit tax, ce qui est un avantage majeur "
            f"par rapport a la France (exit tax), l'Allemagne (Wegzugsbesteuerung) "
            f"ou les Etats-Unis (expatriation tax)."
        )

        sources = [
            cdi["source"],
            "Convention modele OCDE art. 6, 10, 11, 13, 15, 18, 21",
            "LIFD art. 6, 7 (assujettissement illimite / limite)",
        ]

        return DoubleTaxationResult(
            pays_residence=country,
            convention_existe=True,
            date_convention=cdi["date_convention"],
            repartition=repartition,
            taux_dividendes_max=cdi["dividendes_taux_max"],
            taux_interets_max=cdi["interets_taux_max"],
            optimisations=optimisations,
            recommandation=recommandation,
            sources=sources,
        )

    def estimate_avs_gap(
        self,
        years_abroad: int,
        years_in_ch: int,
    ) -> AVSGapResult:
        """Estime la reduction de rente AVS due aux annees a l'etranger.

        Chaque annee de cotisation manquante reduit la rente AVS
        proportionnellement (LAVS art. 29ter).

        Args:
            years_abroad: Nombre d'annees a l'etranger (sans cotisation AVS CH).
            years_in_ch: Nombre d'annees de cotisation en Suisse.

        Returns:
            AVSGapResult avec l'estimation de la lacune.
        """
        annees_totales = years_abroad + years_in_ch
        annees_manquantes = max(0, AVS_ANNEES_COTISATION_PLEINES - years_in_ch)

        # Rente estimee = rente max * (annees_ch / 44)
        ratio = min(1.0, years_in_ch / AVS_ANNEES_COTISATION_PLEINES) if AVS_ANNEES_COTISATION_PLEINES > 0 else 0.0
        rente_estimee = round(AVS_RENTE_MAX_MENSUELLE * ratio, 2)
        # Minimum si au moins 1 an de cotisation
        if years_in_ch > 0 and rente_estimee < AVS_RENTE_MIN_MENSUELLE:
            rente_estimee = AVS_RENTE_MIN_MENSUELLE

        reduction_mensuelle = round(AVS_RENTE_MAX_MENSUELLE - rente_estimee, 2)
        reduction_annuelle = round(reduction_mensuelle * 12, 2)

        # Cotisation volontaire possible pour les Suisses a l'etranger
        cotisation_volontaire = years_abroad > 0

        if annees_manquantes > 0:
            recommandation = (
                f"Avec {years_in_ch} annees de cotisation AVS en Suisse, ta rente est "
                f"estimee a CHF {rente_estimee:,.0f}/mois (max: CHF {AVS_RENTE_MAX_MENSUELLE:,.0f}). "
                f"Il te manque {annees_manquantes} annees pour la rente complete. "
                f"Reduction estimee: CHF {reduction_mensuelle:,.0f}/mois "
                f"(CHF {reduction_annuelle:,.0f}/an)."
            )
            if cotisation_volontaire:
                recommandation += (
                    f" Si tu es de nationalite suisse, tu peux cotiser a l'AVS facultative "
                    f"(CHF {AVS_COTISATION_MIN_VOLONTAIRE:,.0f} a CHF {AVS_COTISATION_MAX_VOLONTAIRE:,.0f}/an)."
                )
        else:
            recommandation = (
                f"Avec {years_in_ch} annees de cotisation, tu as droit a la rente "
                f"AVS maximale de CHF {AVS_RENTE_MAX_MENSUELLE:,.0f}/mois. Aucune lacune."
            )

        sources = [
            "LAVS art. 29ter (rente complete si 44 annees de cotisation)",
            "LAVS art. 34 al. 1 (rente maximale: CHF 2'520/mois en 2025)",
            "LAVS art. 34 al. 5 (rente minimale: CHF 1'260/mois)",
            "LAVS art. 2 (assurance AVS facultative pour Suisses a l'etranger)",
            "OAVS art. 13bis (cotisation facultative: CHF 514-25'700/an)",
        ]

        return AVSGapResult(
            annees_cotisation_ch=years_in_ch,
            annees_a_letranger=years_abroad,
            annees_totales=annees_totales,
            annees_manquantes=annees_manquantes,
            rente_estimee_mensuelle=rente_estimee,
            rente_max_mensuelle=AVS_RENTE_MAX_MENSUELLE,
            reduction_mensuelle=reduction_mensuelle,
            reduction_annuelle=reduction_annuelle,
            cotisation_volontaire_possible=cotisation_volontaire,
            cotisation_min=AVS_COTISATION_MIN_VOLONTAIRE,
            cotisation_max=AVS_COTISATION_MAX_VOLONTAIRE,
            recommandation=recommandation,
            sources=sources,
        )

    def plan_departure(
        self,
        departure_date: str,
        canton: str,
        pillar_3a_balance: float,
        lpp_balance: float,
    ) -> DeparturePlanResult:
        """Planifie le depart de Suisse avec les impacts financiers.

        Args:
            departure_date: Date de depart prevue (format YYYY-MM-DD).
            canton: Canton de domicile actuel (2 lettres).
            pillar_3a_balance: Solde du 3e pilier a (CHF).
            lpp_balance: Solde LPP / libre passage (CHF).

        Returns:
            DeparturePlanResult avec la checklist et les estimations.
        """
        canton_upper = canton.upper()

        # Impot sur le capital de prevoyance (LIFD art. 38)
        taux_capital = TAUX_IMPOSITION_CAPITAL_PREVOYANCE.get(canton_upper, _DEFAULT_TAUX_CAPITAL)
        impot_3a = round(pillar_3a_balance * taux_capital, 2)
        impot_lpp = round(lpp_balance * taux_capital, 2)

        # Determiner si le depart est optimal (fin d'annee)
        try:
            dep_date = date.fromisoformat(departure_date)
            mois_depart = dep_date.month
            if mois_depart >= 11:
                timing_optimal = (
                    "Bon timing : un depart en fin d'annee permet de n'etre impose "
                    "que sur la periode janvier-depart pour l'annee en cours. "
                    "L'imposition est prorata temporis (LIFD art. 42)."
                )
            elif mois_depart <= 2:
                timing_optimal = (
                    "Depart en debut d'annee : tu seras impose sur seulement quelques "
                    "mois. Attention a bien remplir la declaration de l'annee precedente "
                    "et de l'annee de depart."
                )
            else:
                timing_optimal = (
                    f"Depart en cours d'annee (mois {mois_depart}). L'imposition est "
                    f"prorata temporis. Si possible, envisage de decaler le depart en "
                    f"fin d'annee pour optimiser la fiscalite."
                )
        except (ValueError, TypeError):
            timing_optimal = (
                "Date de depart non analysable. En general, un depart en fin d'annee "
                "permet d'optimiser la fiscalite (imposition prorata temporis)."
            )

        delai_retrait_3a = (
            f"Tu as {DELAI_RETRAIT_3A_ANNEES} an apres ton depart de Suisse pour "
            f"retirer ton 3e pilier (OPP3 art. 3 al. 2). Apres ce delai, le capital "
            f"reste bloque jusqu'a la retraite."
        )

        recommandation = (
            f"Depart prevu le {departure_date} depuis le canton {canton_upper}. "
            f"La Suisse n'a PAS d'exit tax — c'est un avantage majeur. "
            f"Impot estime sur le retrait du capital de prevoyance : "
            f"3a: CHF {impot_3a:,.0f}, LPP: CHF {impot_lpp:,.0f} "
            f"(taux canton {canton_upper}: {taux_capital*100:.1f}%). "
            f"Total des avoirs de prevoyance: CHF {pillar_3a_balance + lpp_balance:,.0f}."
        )

        sources = [
            "LIFD art. 38 (imposition du capital de prevoyance a taux reduit)",
            "LIFD art. 42 (assujettissement prorata temporis au depart)",
            "LFLP art. 2 (libre passage obligatoire)",
            "OPP3 art. 3 al. 2 (delai de retrait 3a : 1 an)",
            "OLP art. 16 (versement en especes si depart hors UE/AELE)",
            "CC art. 23 (domicile civil — annonce de depart)",
        ]

        return DeparturePlanResult(
            date_depart=departure_date,
            canton=canton_upper,
            pillar_3a_balance=pillar_3a_balance,
            lpp_balance=lpp_balance,
            impot_capital_3a=impot_3a,
            impot_capital_lpp=impot_lpp,
            delai_retrait_3a=delai_retrait_3a,
            checklist=CHECKLIST_DEPART,
            timing_optimal=timing_optimal,
            recommandation=recommandation,
            sources=sources,
        )

    def compare_tax_burden(
        self,
        salary: float,
        canton: str,
        target_country: str,
    ) -> TaxComparisonResult:
        """Compare la charge fiscale totale CH vs pays de destination.

        Args:
            salary: Salaire brut annuel (CHF).
            canton: Canton CH actuel (2 lettres).
            target_country: Code pays de destination (FR, DE, IT, AT, UK, US, ES, PT).

        Returns:
            TaxComparisonResult avec la comparaison.
        """
        canton_upper = canton.upper()
        country = target_country.upper()

        # --- Charges CH ---
        canton_key = f"CH_{canton_upper}"
        ch_data = TAUX_GLOBAL_PAR_PAYS.get(canton_key)
        if ch_data is None:
            # Utiliser une estimation par defaut
            ch_data = {"label": f"Suisse ({canton_upper})", "taux_impot": 0.25, "taux_social": 0.13, "total": 0.38}

        impot_ch = round(salary * ch_data["taux_impot"], 2)
        charges_ch = round(salary * ch_data["taux_social"], 2)
        total_ch = round(impot_ch + charges_ch, 2)
        net_ch = round(salary - total_ch, 2)

        # --- Charges pays cible ---
        cible_data = TAUX_GLOBAL_PAR_PAYS.get(country)
        if cible_data is None:
            cible_data = {"label": country, "taux_impot": 0.30, "taux_social": 0.15, "total": 0.45}

        impot_cible = round(salary * cible_data["taux_impot"], 2)
        charges_cible = round(salary * cible_data["taux_social"], 2)
        total_cible = round(impot_cible + charges_cible, 2)
        net_cible = round(salary - total_cible, 2)

        difference = round(net_ch - net_cible, 2)

        exit_tax_note = (
            "La Suisse n'applique PAS d'exit tax (contrairement a la France "
            "avec l'exit tax sur les plus-values, l'Allemagne avec la Wegzugsbesteuerung, "
            "ou les Etats-Unis avec l'expatriation tax). C'est un avantage majeur du depart "
            "depuis la Suisse."
        )

        if difference > 0:
            recommandation = (
                f"En Suisse ({canton_upper}), tu gardes ~CHF {difference:,.0f}/an de plus "
                f"qu'en {cible_data['label']}. Net CH: CHF {net_ch:,.0f} vs "
                f"net {cible_data['label']}: CHF {net_cible:,.0f}."
            )
        elif difference < 0:
            recommandation = (
                f"En {cible_data['label']}, tu garderais ~CHF {abs(difference):,.0f}/an de plus "
                f"qu'en Suisse ({canton_upper}). Net {cible_data['label']}: CHF {net_cible:,.0f} vs "
                f"net CH: CHF {net_ch:,.0f}."
            )
        else:
            recommandation = (
                f"La charge fiscale est comparable entre la Suisse ({canton_upper}) "
                f"et {cible_data['label']}. Net: ~CHF {net_ch:,.0f}."
            )

        sources = [
            "LIFD art. 36 (baremes IFD)",
            "LAVS art. 5 (cotisations AVS/AI/APG)",
            "LACI art. 3 (cotisations AC)",
            f"Legislation fiscale {cible_data['label']} (estimation simplifiee)",
            "OCDE — statistiques fiscales comparatives",
        ]

        return TaxComparisonResult(
            salaire_brut=salary,
            canton=canton_upper,
            pays_cible=country,
            impot_ch=impot_ch,
            charges_sociales_ch=charges_ch,
            total_ch=total_ch,
            net_ch=net_ch,
            impot_cible=impot_cible,
            charges_sociales_cible=charges_cible,
            total_cible=total_cible,
            net_cible=net_cible,
            difference_nette=difference,
            exit_tax_note=exit_tax_note,
            recommandation=recommandation,
            sources=sources,
        )
