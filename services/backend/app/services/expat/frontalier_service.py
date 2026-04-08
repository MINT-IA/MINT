"""
Simulateur fiscal et social pour les travailleurs frontaliers en Suisse.

Calcule l'impot a la source, verifie le statut quasi-resident,
simule la regle des 90 jours, compare les charges sociales et
estime les options LAMal vs assurance pays de residence.

Sources:
    - LIFD art. 83 (obligation d'impot a la source pour frontaliers)
    - LIFD art. 84 (calcul de l'impot a la source)
    - LIFD art. 85 (bareme impot a la source)
    - LIFD art. 99a (statut quasi-resident, rectification)
    - Accords bilateraux CH-UE (ALCP art. 21)
    - Accord CH-FR du 11.04.1983 (regime special frontaliers FR-GE)
    - Accord CH-IT du 03.10.1974 (exception Tessin-Italie)
    - Reglement CE 883/2004 art. 11 (securite sociale dans le pays d'emploi)
    - LAVS art. 5 (cotisations AVS/AI/APG)
    - LACI art. 3 (cotisations assurance-chomage)
    - LPP art. 2, 7, 8 (prevoyance professionnelle obligatoire)
    - LAMal art. 3, 6 (droit d'option frontaliers)
    - Ordonnance sur la libre circulation (OLCP) art. 9

Sprint S23 — Expatriation + Frontaliers.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from app.constants.social_insurance import (
    AVS_COTISATION_SALARIE,
    AC_COTISATION_SALARIE,
    AC_COTISATION_SOLIDARITE_SALARIE,
    AC_PLAFOND_SALAIRE_ASSURE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_MAX,
    LPP_BONIFICATIONS_DICT,
    get_lpp_bonification_rate,
)


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ton canton de travail, de ta situation personnelle et des accords "
    "bilateraux en vigueur. Ne constitue pas un conseil fiscal ou juridique "
    "(LSFin/LLCA). Consulte un ou une specialiste."
)

# ---------------------------------------------------------------------------
# Constantes impot a la source frontaliers (2025/2026)
# ---------------------------------------------------------------------------

# Taux de base impot a la source — bareme C (celibataire) et C1 (marie)
# Source: LIFD art. 85, ordonnances cantonales impot a la source
# Les taux effectifs dependent du canton, du revenu et de la situation familiale.
# Ci-dessous : taux moyens estimes pour un revenu median CHF 80'000.

# Cantons avec accords speciaux (LIFD art. 83, accords bilateraux)
# GE: regime special — accord CH-FR du 11.04.1983 : frontaliers FR imposes en CH
# TI: accord CH-IT du 03.10.1974 : frontaliers IT imposes en Italie
#     (retrocession de 38.8% de l'impot a la source au fisc italien)

CANTON_SOURCE_TAX_RATES = {
    # Canton: {"base_rate": taux de base %, "multiplier": multiplicateur cantonal+communal}
    # Source: ordonnances cantonales impot a la source 2024/2025
    "GE": {"base_rate": 0.0, "multiplier": 1.0, "special": "quasi_resident"},
    # GE: regime special — pas d'impot a la source standard
    # mais imposition ordinaire si quasi-resident (LIFD art. 99a, LIPP-GE art. 6)
    "VD": {"base_rate": 4.5, "multiplier": 1.55},
    # VD: 4.5% base + multiplicateur cantonal/communal (LI-VD art. 174)
    "VS": {"base_rate": 4.5, "multiplier": 1.40},
    # VS: 4.5% base + multiplicateur (LF-VS art. 108)
    "BS": {"base_rate": 4.5, "multiplier": 1.45},
    # BS: 4.5% base + multiplicateur (StG-BS § 120)
    "TI": {"base_rate": 0.0, "multiplier": 1.0, "special": "italie"},
    # TI: accord CH-IT — frontaliers IT imposes en Italie
    # Retrocession de 38.8% (accord du 03.10.1974 art. 3)
    "BE": {"base_rate": 4.5, "multiplier": 1.52},
    # BE: standard source tax (StG-BE art. 119)
    "ZH": {"base_rate": 4.5, "multiplier": 1.48},
    # ZH: standard source tax (StG-ZH § 95)
    "AG": {"base_rate": 4.5, "multiplier": 1.42},
    # AG: standard source tax (StG-AG § 120)
    "SG": {"base_rate": 4.5, "multiplier": 1.40},
    # SG: standard source tax (StG-SG art. 112)
    "LU": {"base_rate": 4.5, "multiplier": 1.38},
    # LU: standard source tax (StG-LU § 108)
    "FR": {"base_rate": 4.5, "multiplier": 1.50},
    # FR: standard source tax (LICD-FR art. 136)
    "NE": {"base_rate": 4.5, "multiplier": 1.52},
    # NE: standard source tax (LCdir-NE art. 159)
    "JU": {"base_rate": 4.5, "multiplier": 1.55},
    # JU: standard source tax (LI-JU art. 142)
    "SO": {"base_rate": 4.5, "multiplier": 1.45},
    # SO: standard source tax (StG-SO § 118)
    "BL": {"base_rate": 4.5, "multiplier": 1.44},
    # BL: standard source tax (StG-BL § 114)
    "SH": {"base_rate": 4.5, "multiplier": 1.40},
    # SH: standard source tax (StG-SH art. 107)
    "TG": {"base_rate": 4.5, "multiplier": 1.38},
    # TG: standard source tax (StG-TG § 110)
    "GR": {"base_rate": 4.5, "multiplier": 1.42},
    # GR: standard source tax (StG-GR art. 105)
    "ZG": {"base_rate": 4.5, "multiplier": 1.22},
    # ZG: standard source tax (StG-ZG § 92) — canton a faible fiscalite
    "SZ": {"base_rate": 4.5, "multiplier": 1.24},
    # SZ: standard source tax (StG-SZ § 95)
    "OW": {"base_rate": 4.5, "multiplier": 1.30},
    # OW: standard source tax (StG-OW art. 98)
    "NW": {"base_rate": 4.5, "multiplier": 1.28},
    # NW: standard source tax (StG-NW art. 98)
    "UR": {"base_rate": 4.5, "multiplier": 1.32},
    # UR: standard source tax (StG-UR art. 100)
    "GL": {"base_rate": 4.5, "multiplier": 1.35},
    # GL: standard source tax (StG-GL art. 110)
    "AR": {"base_rate": 4.5, "multiplier": 1.30},
    # AR: standard source tax (StG-AR art. 100)
    "AI": {"base_rate": 4.5, "multiplier": 1.28},
    # AI: standard source tax (StG-AI art. 95)
}
_DEFAULT_SOURCE_TAX = {"base_rate": 4.5, "multiplier": 1.40}

# Bareme simplifie impot a la source par tranche (LIFD art. 85)
# Utilise pour estimer l'impot a la source federal avant multiplicateur cantonal
SOURCE_TAX_BRACKETS = [
    (20_000, 0.0),      # Exonere jusqu'a CHF 20'000
    (40_000, 2.0),      # 2% sur la tranche 20'001-40'000
    (60_000, 5.0),      # 5% sur la tranche 40'001-60'000
    (80_000, 8.0),      # 8% sur la tranche 60'001-80'000
    (100_000, 10.0),    # 10% sur la tranche 80'001-100'000
    (120_000, 12.0),    # 12% sur la tranche 100'001-120'000
    (150_000, 14.0),    # 14% sur la tranche 120'001-150'000
    (200_000, 15.0),    # 15% sur la tranche 150'001-200'000
    (float("inf"), 15.5),  # 15.5% au-dela de 200'000
]

# Deductions impot a la source (LIFD art. 85, OIS)
# Deduction par enfant a charge (bareme C1/C2)
DEDUCTION_ENFANT_SOURCE = 3_500.0  # CHF/enfant (LIFD art. 85, OIS art. 5)
# Deduction double activite maries (approximation)
DEDUCTION_MARIES_SOURCE = 2_700.0  # CHF (LIFD art. 35 al. 1 let. c, applique a la source)
# Deduction impot ecclesiastique si pas affilie
DEDUCTION_EGLISE = 0.0  # CHF (pas de deduction, mais surcharge si affilie)
# Supplement eglise (moyenne cantonale)
SUPPLEMENT_EGLISE = 0.08  # 8% en moyenne (lois cantonales sur l'impot ecclesiastique)

# Seuil quasi-resident (GE) — LIFD art. 99a, LIPP-GE art. 6 al. 6
QUASI_RESIDENT_SEUIL = 0.90  # 90% du revenu mondial gagne en Suisse

# Regle des 90 jours — convention modele OCDE art. 15 al. 2
# Source: accords bilateraux, circulaire AFC 2015 "exercice effectif de l'activite"
REGLE_90_JOURS_SEUIL = 90  # jours de teletravail depuis le domicile a l'etranger

# ---------------------------------------------------------------------------
# Charges sociales (2025/2026)
# Source: LAVS art. 5, LACI art. 3, LAPG art. 27, LAI art. 3
# ---------------------------------------------------------------------------

# AVS/AI/APG — cotisation salarie (LAVS art. 5 al. 1)
# Source of truth: app.constants.social_insurance
AVS_AI_APG_TAUX_EMPLOYE = AVS_COTISATION_SALARIE       # 5.3%
AVS_AI_APG_TAUX_EMPLOYEUR = AVS_COTISATION_SALARIE     # 5.3%

# AC (chomage) — cotisation salarie (LACI art. 3 al. 2)
# Source of truth: app.constants.social_insurance
AC_TAUX_EMPLOYE = AC_COTISATION_SALARIE               # 1.1%
AC_TAUX_EMPLOYEUR = AC_COTISATION_SALARIE             # 1.1%
AC_PLAFOND = AC_PLAFOND_SALAIRE_ASSURE                # CHF (LACI art. 3 al. 2, 2025)

# AC solidarite — sur la tranche depassant le plafond (LACI art. 3 al. 3)
# Source of truth: app.constants.social_insurance
AC_SOLIDARITE_TAUX = AC_COTISATION_SOLIDARITE_SALARIE  # 0.5%

# LPP — estimation simplifiee (LPP art. 8, 16)
# Source of truth: app.constants.social_insurance
# LPP_DEDUCTION_COORDINATION, LPP_SEUIL_ENTREE, LPP_SALAIRE_MAX are imported directly

# Taux de bonification LPP par age (LPP art. 16)
# Source of truth: app.constants.social_insurance
LPP_BONIFICATION_RATES = dict(LPP_BONIFICATIONS_DICT)

# AANP (accidents non professionnels) — estimation
AANP_TAUX = 0.014  # ~1.4% (LAA art. 91, moyenne)

# ---------------------------------------------------------------------------
# Charges sociales pays voisins (estimations simplifiees 2025)
# Source: securite sociale respective de chaque pays
# ---------------------------------------------------------------------------

CHARGES_SOCIALES_PAYS = {
    "FR": {
        "label": "France",
        "taux_employe_total": 0.225,  # ~22.5% (CSG 9.2% + CRDS 0.5% + secu ~13%)
        "taux_employeur_total": 0.45,  # ~45%
        # Source: Code de la securite sociale (CSS), CGI art. 1600-0S
        "source": "CSS art. L241-1, CGI art. 1600-0S (CSG/CRDS)",
    },
    "DE": {
        "label": "Allemagne",
        "taux_employe_total": 0.205,  # ~20.5%
        "taux_employeur_total": 0.21,  # ~21%
        # Source: SGB IV, SGB V, SGB VI
        "source": "SGB IV §§ 20ff (Sozialversicherung DE)",
    },
    "IT": {
        "label": "Italie",
        "taux_employe_total": 0.10,  # ~10%
        "taux_employeur_total": 0.30,  # ~30%
        # Source: D.Lgs. 314/1997, TUIR
        "source": "D.Lgs. 314/1997, INPS (contributi previdenziali IT)",
    },
    "AT": {
        "label": "Autriche",
        "taux_employe_total": 0.18,  # ~18%
        "taux_employeur_total": 0.22,  # ~22%
        # Source: ASVG (Allgemeines Sozialversicherungsgesetz)
        "source": "ASVG §§ 51ff (Sozialversicherung AT)",
    },
    # FIX-163: Liechtenstein frontaliers (EEA member, Swiss customs union)
    "LI": {
        "label": "Liechtenstein",
        "taux_employe_total": 0.12,  # ~12% (AHV/IV/FAK + ALV)
        "taux_employeur_total": 0.15,  # ~15%
        # Source: AHVG (LI), bilateral CH-LI social security agreement
        "source": "AHVG LI, accord bilatéral CH-LI",
    },
}

# ---------------------------------------------------------------------------
# Primes LAMal estimees (LAMal art. 61, OPAS)
# Primes mensuelles moyennes pour adultes avec franchise 300, 2025
# ---------------------------------------------------------------------------

LAMAL_PRIMES_MENSUELLES = {
    # Canton: prime mensuelle moyenne adulte, franchise 300 CHF
    # Source: OFSP, primes LAMal 2025
    "GE": 580.0, "VD": 540.0, "BS": 520.0, "BE": 480.0,
    "ZH": 460.0, "TI": 500.0, "LU": 430.0, "AG": 440.0,
    "SG": 420.0, "FR": 470.0, "VS": 430.0, "NE": 510.0,
    "JU": 490.0, "SO": 450.0, "BL": 470.0, "SH": 430.0,
    "TG": 410.0, "GR": 400.0, "ZG": 380.0, "SZ": 400.0,
    "OW": 390.0, "NW": 380.0, "UR": 400.0, "GL": 410.0,
    "AR": 400.0, "AI": 380.0,
}
_DEFAULT_LAMAL_PRIME = 460.0

# Primes mensuelles estimees dans les pays voisins (securite sociale + complementaire)
# Source: estimations basees sur les systemes de sante respectifs
ASSURANCE_RESIDENCE_PRIMES = {
    "FR": {"prime_mensuelle": 0.0, "cotisation_pct": 0.131,
            "source": "CSS art. L241-1 (assurance maladie couverte par cotisations sociales FR)"},
    # FR: couverture maladie incluse dans les cotisations sociales (~13.1%)
    "DE": {"prime_mensuelle": 420.0, "cotisation_pct": 0.0,
            "source": "SGB V §§ 220ff (Krankenversicherung, ~14.6% du salaire brut)"},
    # DE: Gesetzliche Krankenversicherung ~420 CHF/mois equivalent
    "IT": {"prime_mensuelle": 0.0, "cotisation_pct": 0.098,
            "source": "D.Lgs. 502/1992 (SSN, cotisation ~9.8%)"},
    # IT: SSN inclus dans les cotisations sociales
    "AT": {"prime_mensuelle": 0.0, "cotisation_pct": 0.077,
            "source": "ASVG § 51 (Krankenversicherung ~7.7% du salaire brut)"},
    # AT: couverture maladie incluse dans les cotisations sociales
    # FIX-163: Liechtenstein
    "LI": {"prime_mensuelle": 350.0, "cotisation_pct": 0.0,
            "source": "KVG LI (assurance maladie obligatoire, ~350 CHF/mois)"},
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _calculate_source_tax_progressive(salary: float) -> float:
    """Calcule l'impot a la source par tranches progressives.

    Source: LIFD art. 85, baremes impot a la source.
    """
    if salary <= 0:
        return 0.0
    tax = 0.0
    prev = 0.0
    for threshold, rate_pct in SOURCE_TAX_BRACKETS:
        if salary <= prev:
            break
        taxable = min(salary, threshold) - prev
        if taxable > 0:
            tax += taxable * (rate_pct / 100)
        prev = threshold
    return round(tax, 2)


def _get_lpp_rate(age: int) -> float:
    """Retourne le taux de bonification LPP selon l'age (LPP art. 16)."""
    return get_lpp_bonification_rate(age)


# ---------------------------------------------------------------------------
# Dataclasses de resultat
# ---------------------------------------------------------------------------

@dataclass
class SourceTaxResult:
    """Resultat du calcul d'impot a la source pour frontalier."""
    salaire_brut: float                # Salaire brut annuel (CHF)
    canton: str                        # Canton de travail
    impot_source: float                # Impot a la source estime (CHF)
    taux_effectif: float               # Taux effectif d'imposition (%)
    impot_ordinaire_estime: float      # Impot ordinaire estime pour comparaison (CHF)
    taux_ordinaire_estime: float       # Taux ordinaire estime (%)
    difference: float                  # Difference source - ordinaire (CHF)
    regime_special: Optional[str]      # "quasi_resident" (GE), "italie" (TI), None
    recommandation: str                # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class QuasiResidentResult:
    """Resultat de la verification quasi-resident (GE)."""
    eligible: bool                     # Eligible au statut quasi-resident
    revenu_ch: float                   # Revenu suisse (CHF)
    revenu_mondial: float              # Revenu mondial total (CHF)
    ratio_ch: float                    # Part du revenu suisse (%)
    seuil_requis: float                # Seuil requis (90%)
    economie_potentielle: float        # Economie estimee si quasi-resident (CHF)
    recommandation: str                # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class NinetyDayRuleResult:
    """Resultat de la simulation de la regle des 90 jours."""
    jours_teletravail: int             # Jours de teletravail a l'etranger
    jours_deplacement_ch: int          # Jours de deplacement en Suisse
    depasse_seuil: bool                # True si > 90 jours teletravail
    pays_imposition: str               # "Suisse", "pays de residence" ou "mixte"
    risque: str                        # "faible", "moyen", "eleve"
    recommandation: str                # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class SocialChargesComparison:
    """Comparaison des charges sociales CH vs pays de residence."""
    salaire_brut: float                # Salaire brut annuel (CHF)
    pays_residence: str                # Code pays (FR, DE, IT, AT)
    # Charges CH
    avs_ai_apg_employe: float          # AVS/AI/APG part salarie (CHF)
    ac_employe: float                  # AC part salarie (CHF)
    ac_solidarite: float               # AC solidarite (CHF)
    lpp_employe: float                 # LPP part salarie estimee (CHF)
    aanp_employe: float                # AANP part salarie (CHF)
    total_ch_employe: float            # Total charges CH part salarie (CHF)
    total_ch_employeur: float          # Total charges CH part employeur (CHF)
    # Charges pays de residence (si la personne y travaillait)
    total_residence_employe: float     # Total charges pays residence part salarie (CHF)
    total_residence_employeur: float   # Total charges pays residence part employeur (CHF)
    difference_employe: float          # Difference CH - residence, part salarie (CHF)
    recommandation: str                # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class LamalOptionResult:
    """Comparaison LAMal vs assurance pays de residence."""
    canton: str                        # Canton de travail
    pays_residence: str                # Pays de residence
    prime_lamal_mensuelle: float       # Prime LAMal mensuelle estimee (CHF)
    prime_lamal_annuelle: float        # Prime LAMal annuelle estimee (CHF)
    prime_residence_mensuelle: float   # Prime/cotisation pays de residence mensuelle (CHF)
    prime_residence_annuelle: float    # Prime/cotisation pays de residence annuelle (CHF)
    economie_lamal: float              # Economie si LAMal (negatif = LAMal plus cher) (CHF/an)
    recommandation: str                # Recommandation pedagogique
    sources: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class FrontalierService:
    """Simulateur fiscal et social pour les travailleurs frontaliers (permis G).

    Regles cles:
    - Permis G: autorisation de travail pour frontaliers (ALCP, OLCP)
    - Impot a la source: preleve par l'employeur (LIFD art. 83-86)
    - GE: regime quasi-resident si >=90% du revenu mondial en CH (LIPP-GE art. 6)
    - TI: frontaliers IT imposes en Italie (accord CH-IT 03.10.1974)
    - Regle 90 jours: teletravail > 90 jours => imposition pays de residence
    - Charges sociales: toujours en CH (Reglement CE 883/2004 art. 11)
    - LAMal: droit d'option (LAMal art. 3, OLCP art. 9)
    """

    def calculate_source_tax(
        self,
        salary: float,
        canton: str = "VD",
        marital_status: str = "celibataire",
        children: int = 0,
        church_tax: bool = False,
    ) -> SourceTaxResult:
        """Calcule l'impot a la source pour un frontalier.

        Args:
            salary: Salaire brut annuel (CHF).
            canton: Canton de travail (2 lettres).
            marital_status: "celibataire" ou "marie".
            children: Nombre d'enfants a charge.
            church_tax: True si affilie a une eglise reconnue.

        Returns:
            SourceTaxResult avec l'estimation de l'impot a la source.
        """
        canton_upper = canton.upper()
        canton_data = CANTON_SOURCE_TAX_RATES.get(canton_upper, _DEFAULT_SOURCE_TAX)

        # Verifier regime special
        regime_special = canton_data.get("special")

        # Deductions
        deductions = 0.0
        if marital_status == "marie":
            deductions += DEDUCTION_MARIES_SOURCE
        deductions += DEDUCTION_ENFANT_SOURCE * children

        salaire_imposable = max(0, salary - deductions)

        if regime_special == "italie":
            # TI: frontaliers IT imposes en Italie — retrocession 38.8%
            # L'employeur suisse preleve quand meme un impot a la source
            # qui est partiellement retrocede a l'Italie
            impot_source = round(salary * 0.04, 2)  # ~4% approximatif
            taux_effectif = round(impot_source / salary * 100, 2) if salary > 0 else 0.0
            recommandation = (
                "Régime spécial Tessin-Italie : les frontaliers italiens sont "
                "principalement imposés en Italie (accord CH-IT du 03.10.1974). "
                "L'employeur suisse prélève un impôt à la source réduit, "
                "rétrocédé partiellement au fisc italien."
            )
        elif regime_special == "quasi_resident":
            # GE: pas d'impot a la source standard — regime quasi-resident
            impot_source = 0.0
            taux_effectif = 0.0
            recommandation = (
                "Canton de Genève : les frontaliers français bénéficient du régime "
                "spécial de l'accord CH-FR du 11.04.1983. Vérifie si tu es éligible "
                "au statut quasi-résident (>=90% du revenu mondial en CH) pour "
                "accéder à l'imposition ordinaire, souvent plus avantageuse."
            )
        else:
            # Calcul standard : impot progressif * multiplicateur cantonal
            impot_base = _calculate_source_tax_progressive(salaire_imposable)
            multiplier = canton_data.get("multiplier", 1.40)
            impot_source = round(impot_base * multiplier, 2)

            # Supplement eglise
            if church_tax:
                impot_source = round(impot_source * (1 + SUPPLEMENT_EGLISE), 2)

            taux_effectif = round(impot_source / salary * 100, 2) if salary > 0 else 0.0
            recommandation = (
                f"Impot a la source estime dans le canton {canton_upper} : "
                f"CHF {impot_source:,.0f}/an (taux effectif ~{taux_effectif:.1f}%). "
                f"Tu peux demander une rectification si tu estimes que les deductions "
                f"ne sont pas correctement prises en compte (LIFD art. 137)."
            )

        # Comparaison avec l'imposition ordinaire (estimation)
        # Un resident suisse avec le meme salaire paierait environ:
        impot_ordinaire = round(_calculate_source_tax_progressive(salaire_imposable) * 1.35, 2)
        taux_ordinaire = round(impot_ordinaire / salary * 100, 2) if salary > 0 else 0.0
        difference = round(impot_source - impot_ordinaire, 2)

        sources = [
            "LIFD art. 83 (obligation d'impot a la source pour frontaliers)",
            "LIFD art. 84-85 (calcul et baremes impot a la source)",
            "LIFD art. 137 (demande de rectification)",
            f"Loi cantonale {canton_upper} (bareme impot a la source)",
        ]
        if regime_special == "italie":
            sources.append("Accord CH-IT du 03.10.1974 art. 3 (regime frontaliers Tessin)")
        elif regime_special == "quasi_resident":
            sources.append("Accord CH-FR du 11.04.1983 (regime frontaliers GE)")
            sources.append("LIPP-GE art. 6 al. 6 (statut quasi-resident)")

        return SourceTaxResult(
            salaire_brut=salary,
            canton=canton_upper,
            impot_source=impot_source,
            taux_effectif=taux_effectif,
            impot_ordinaire_estime=impot_ordinaire,
            taux_ordinaire_estime=taux_ordinaire,
            difference=difference,
            regime_special=regime_special,
            recommandation=recommandation,
            sources=sources,
        )

    def check_quasi_resident(
        self,
        ch_income: float,
        worldwide_income: float,
        canton: str = "GE",
    ) -> QuasiResidentResult:
        """Verifie l'eligibilite au statut quasi-resident.

        Le statut quasi-resident permet aux frontaliers dont >=90% du revenu
        mondial est gagne en Suisse de deposer une declaration ordinaire,
        ce qui donne acces a toutes les deductions.

        Principalement pertinent pour Geneve (LIPP-GE art. 6 al. 6).

        Args:
            ch_income: Revenu annuel gagne en Suisse (CHF).
            worldwide_income: Revenu mondial total (CHF).
            canton: Canton (en pratique GE, mais applicable theoriquement partout).

        Returns:
            QuasiResidentResult avec l'analyse d'eligibilite.
        """
        if worldwide_income <= 0:
            ratio = 0.0
        else:
            ratio = round(ch_income / worldwide_income, 4)

        eligible = ratio >= QUASI_RESIDENT_SEUIL

        # Estimation de l'economie potentielle
        # En imposition ordinaire, on peut deduire: 3a, frais effectifs, etc.
        # Estimation grossiere: ~5-15% d'economie sur les deductions supplementaires
        if eligible and ch_income > 0:
            # Deductions supplementaires estimees: 3a (7258) + frais effectifs (~5000)
            deductions_supplementaires = 12_000.0
            taux_marginal_estime = 0.25  # estimation
            economie = round(deductions_supplementaires * taux_marginal_estime, 2)
        else:
            economie = 0.0

        if eligible:
            recommandation = (
                f"Tu es éligible au statut quasi-résident ({ratio:.1%} de ton revenu "
                f"mondial est gagné en Suisse, seuil requis : 90%). Tu peux déposer "
                f"une déclaration ordinaire et bénéficier de toutes les déductions "
                f"(3e pilier, frais effectifs, rachat LPP, etc.). Économie estimée : "
                f"~CHF {economie:,.0f}/an."
            )
        else:
            manque = QUASI_RESIDENT_SEUIL - ratio
            recommandation = (
                f"Tu n'es pas éligible au statut quasi-résident ({ratio:.1%} de ton revenu "
                f"mondial en Suisse, seuil requis : 90%). Il te manque {manque:.1%} pour "
                f"atteindre le seuil. Si tu as des revenus à l'étranger (immobilier, "
                f"placements), cela peut réduire ta part CH."
            )

        sources = [
            "LIFD art. 99a (taxation ordinaire ultérieure pour quasi-résidents)",
            "LIPP-GE art. 6 al. 6 (statut quasi-résident Genève)",
            "ATF 140 II 167 (arrêt du TF sur le statut quasi-résident)",
        ]

        return QuasiResidentResult(
            eligible=eligible,
            revenu_ch=ch_income,
            revenu_mondial=worldwide_income,
            ratio_ch=round(ratio * 100, 2),
            seuil_requis=QUASI_RESIDENT_SEUIL * 100,
            economie_potentielle=economie,
            recommandation=recommandation,
            sources=sources,
        )

    def simulate_90_day_rule(
        self,
        home_office_days: int,
        commute_days: int,
    ) -> NinetyDayRuleResult:
        """Simule la regle des 90 jours pour le teletravail frontalier.

        Si un frontalier travaille plus de 90 jours/an depuis son domicile
        a l'etranger, le droit d'imposer bascule vers le pays de residence.

        Source: convention modele OCDE art. 15 al. 2, accords bilateraux CH-UE.

        Args:
            home_office_days: Nombre de jours de teletravail depuis le domicile etranger.
            commute_days: Nombre de jours de deplacement en Suisse.

        Returns:
            NinetyDayRuleResult avec l'evaluation du risque.
        """
        depasse = home_office_days > REGLE_90_JOURS_SEUIL

        if home_office_days <= 60:
            risque = "faible"
            pays_imposition = "Suisse"
            recommandation = (
                f"Avec {home_office_days} jours de teletravail a l'etranger, "
                f"tu es largement en dessous du seuil de 90 jours. "
                f"L'imposition reste integralement en Suisse. Marge de securite: "
                f"{REGLE_90_JOURS_SEUIL - home_office_days} jours."
            )
        elif home_office_days <= REGLE_90_JOURS_SEUIL:
            risque = "moyen"
            pays_imposition = "Suisse"
            marge = REGLE_90_JOURS_SEUIL - home_office_days
            recommandation = (
                f"Avec {home_office_days} jours de teletravail, tu es proche du seuil "
                f"de 90 jours (marge: {marge} jours). L'imposition reste en Suisse "
                f"mais sois vigilant. Tiens un registre precis de tes jours de presence."
            )
        else:
            risque = "eleve"
            depassement = home_office_days - REGLE_90_JOURS_SEUIL
            if commute_days > home_office_days:
                pays_imposition = "mixte"
                recommandation = (
                    f"Attention : avec {home_office_days} jours de teletravail (>{REGLE_90_JOURS_SEUIL}), "
                    f"une partie de ton salaire pourrait etre imposee dans ton pays de residence. "
                    f"Depassement: {depassement} jours. Cependant, comme tu as {commute_days} jours "
                    f"en Suisse, une repartition mixte s'applique."
                )
            else:
                pays_imposition = "pays de residence"
                recommandation = (
                    f"Risque eleve : avec {home_office_days} jours de teletravail "
                    f"(>{REGLE_90_JOURS_SEUIL}), l'imposition bascule majoritairement "
                    f"vers ton pays de residence. Depassement: {depassement} jours. "
                    f"Consulte un fiscaliste specialise en droit international."
                )

        sources = [
            "Convention modele OCDE art. 15 al. 2 (regle des 183/90 jours)",
            "Accords bilateraux CH-UE / ALCP (accord cadre teletravail)",
            "Accord multilateral du 01.07.2023 (teletravail frontaliers, seuil 25%)",
            "Circulaire AFC 2023 (exercice effectif de l'activite en Suisse)",
        ]

        return NinetyDayRuleResult(
            jours_teletravail=home_office_days,
            jours_deplacement_ch=commute_days,
            depasse_seuil=depasse,
            pays_imposition=pays_imposition,
            risque=risque,
            recommandation=recommandation,
            sources=sources,
        )

    def compare_social_charges(
        self,
        salary: float,
        country_of_residence: str = "FR",
    ) -> SocialChargesComparison:
        """Compare les charges sociales CH vs pays de residence.

        Les frontaliers cotisent toujours en Suisse (Reglement CE 883/2004).
        Cette methode compare ce qu'ils paient en CH vs ce qu'ils paieraient
        s'ils travaillaient dans leur pays de residence.

        Args:
            salary: Salaire brut annuel (CHF).
            country_of_residence: Code pays (FR, DE, IT, AT).

        Returns:
            SocialChargesComparison avec le detail.
        """
        country = country_of_residence.upper()

        # --- Charges CH ---
        avs_employe = round(salary * AVS_COTISATION_SALARIE, 2)
        avs_employeur = round(salary * AVS_COTISATION_SALARIE, 2)

        salaire_ac = min(salary, AC_PLAFOND_SALAIRE_ASSURE)
        ac_employe = round(salaire_ac * AC_COTISATION_SALARIE, 2)
        ac_employeur = round(salaire_ac * AC_COTISATION_SALARIE, 2)

        ac_solidarite = 0.0
        if salary > AC_PLAFOND_SALAIRE_ASSURE:
            ac_solidarite = round((salary - AC_PLAFOND_SALAIRE_ASSURE) * AC_COTISATION_SOLIDARITE_SALARIE, 2)

        # LPP
        salaire_coordonne = max(0, min(salary, LPP_SALAIRE_MAX + LPP_DEDUCTION_COORDINATION) - LPP_DEDUCTION_COORDINATION)
        lpp_total = round(salaire_coordonne * 0.10, 2)  # estimation moyenne
        lpp_employe = round(lpp_total / 2, 2)
        lpp_employeur = round(lpp_total / 2, 2)

        # AANP
        aanp_employe = round(salary * AANP_TAUX, 2)

        total_ch_employe = round(avs_employe + ac_employe + ac_solidarite + lpp_employe + aanp_employe, 2)
        total_ch_employeur = round(avs_employeur + ac_employeur + lpp_employeur, 2)

        # --- Charges pays de residence ---
        pays_data = CHARGES_SOCIALES_PAYS.get(country, CHARGES_SOCIALES_PAYS["FR"])
        total_residence_employe = round(salary * pays_data["taux_employe_total"], 2)
        total_residence_employeur = round(salary * pays_data["taux_employeur_total"], 2)

        difference = round(total_ch_employe - total_residence_employe, 2)

        if difference < 0:
            recommandation = (
                f"Tes charges sociales en Suisse sont inferieures de CHF {abs(difference):,.0f}/an "
                f"a ce que tu paierais en {pays_data['label']}. Le systeme suisse est "
                f"avantageux pour toi en tant que frontalier."
            )
        else:
            recommandation = (
                f"Tes charges sociales en Suisse sont superieures de CHF {difference:,.0f}/an "
                f"a ce que tu paierais en {pays_data['label']}. Cependant, les prestations "
                f"suisses (AVS, LPP) sont generalement plus elevees."
            )

        sources = [
            "LAVS art. 5 (cotisations AVS/AI/APG)",
            "LACI art. 3 (cotisations assurance-chomage)",
            "LPP art. 8, 16 (prevoyance professionnelle obligatoire)",
            "LAA art. 91 (assurance accidents)",
            "Reglement CE 883/2004 art. 11 (cotisations dans le pays d'emploi)",
            pays_data.get("source", ""),
        ]

        return SocialChargesComparison(
            salaire_brut=salary,
            pays_residence=country,
            avs_ai_apg_employe=avs_employe,
            ac_employe=ac_employe,
            ac_solidarite=ac_solidarite,
            lpp_employe=lpp_employe,
            aanp_employe=aanp_employe,
            total_ch_employe=total_ch_employe,
            total_ch_employeur=total_ch_employeur,
            total_residence_employe=total_residence_employe,
            total_residence_employeur=total_residence_employeur,
            difference_employe=difference,
            recommandation=recommandation,
            sources=sources,
        )

    def estimate_lamal_option(
        self,
        age: int,
        canton: str = "GE",
        family_size: int = 1,
        residence_country: str = "FR",
    ) -> LamalOptionResult:
        """Compare l'option LAMal vs assurance du pays de residence.

        Les frontaliers ont un droit d'option (LAMal art. 3, OLCP art. 9):
        ils peuvent choisir entre l'assurance maladie suisse (LAMal) et
        celle de leur pays de residence.

        Args:
            age: Age de la personne.
            canton: Canton de travail (2 lettres).
            family_size: Taille de la famille (1 = seul, 2+ = famille).
            residence_country: Code pays de residence (FR, DE, IT, AT).

        Returns:
            LamalOptionResult avec la comparaison.
        """
        canton_upper = canton.upper()
        country = residence_country.upper()

        # Prime LAMal
        prime_base = LAMAL_PRIMES_MENSUELLES.get(canton_upper, _DEFAULT_LAMAL_PRIME)
        # Ajustement age (jeune adulte 19-25 : ~25% reduction)
        if age < 26:
            prime_base = round(prime_base * 0.75, 2)

        prime_lamal_mensuelle = round(prime_base * family_size, 2)
        prime_lamal_annuelle = round(prime_lamal_mensuelle * 12, 2)

        # Prime pays de residence
        residence_data = ASSURANCE_RESIDENCE_PRIMES.get(country, ASSURANCE_RESIDENCE_PRIMES["FR"])
        if residence_data["prime_mensuelle"] > 0:
            prime_residence_mensuelle = round(residence_data["prime_mensuelle"] * family_size, 2)
        else:
            # Cotisation basee sur un salaire median estime de CHF 80'000
            salaire_ref = 80_000.0
            prime_residence_mensuelle = round(
                salaire_ref * residence_data["cotisation_pct"] / 12 * family_size, 2
            )
        prime_residence_annuelle = round(prime_residence_mensuelle * 12, 2)

        economie_lamal = round(prime_residence_annuelle - prime_lamal_annuelle, 2)

        if economie_lamal > 0:
            recommandation = (
                f"L'option LAMal est potentiellement avantageuse : tu economiserais "
                f"~CHF {economie_lamal:,.0f}/an par rapport a l'assurance {country}. "
                f"Attention : la LAMal n'est pas subventionnee pour les frontaliers "
                f"(pas de reduction de prime). Compare les prestations couvertes."
            )
        else:
            recommandation = (
                f"L'assurance dans ton pays de residence ({country}) est potentiellement "
                f"plus avantageuse : ~CHF {abs(economie_lamal):,.0f}/an moins cher que la LAMal. "
                f"Cependant, la LAMal offre un acces direct au systeme de sante suisse, "
                f"ce qui peut etre un avantage pratique si tu travailles en Suisse."
            )

        sources = [
            "LAMal art. 3 (assurance obligatoire des personnes residant en Suisse)",
            "LAMal art. 6 (exceptions et droit d'option)",
            "OLCP art. 9 (droit d'option des frontaliers)",
            "OPAS (ordonnance sur les prestations de l'assurance obligatoire)",
            residence_data.get("source", ""),
        ]

        return LamalOptionResult(
            canton=canton_upper,
            pays_residence=country,
            prime_lamal_mensuelle=prime_lamal_mensuelle,
            prime_lamal_annuelle=prime_lamal_annuelle,
            prime_residence_mensuelle=prime_residence_mensuelle,
            prime_residence_annuelle=prime_residence_annuelle,
            economie_lamal=economie_lamal,
            recommandation=recommandation,
            sources=sources,
        )
