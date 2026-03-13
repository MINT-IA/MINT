"""
Disability Gap Service — Simulation du gap financier en cas d'invalidite.

Calcule le deficit financier si l'utilisateur ne peut plus travailler,
en 3 phases successives:
- Phase 1: Couverture employeur (CO art. 324a) — salaire maintenu X semaines
  selon echelle cantonale + annees d'anciennete
- Phase 2: IJM (indemnites journalieres maladie) — 80% du salaire, max 720 jours
  (24 mois) si assure
- Phase 3: AI (assurance invalidite) + rente LPP invalidite — long terme

Sources:
    - CO art. 324a (obligation de l'employeur de maintenir le salaire)
    - LAI art. 28 al. 1 (rente AI selon degre d'invalidite)
    - LPP art. 23-26 (prestations d'invalidite LPP)
    - LACI art. 27 (indemnites journalieres AC)

Regles ethiques:
    - JAMAIS utiliser "garanti", "assure" (sens garantie), "certain",
      "sans risque", "optimal", "meilleur", "parfait"
    - Ton educatif, jamais prescriptif
    - Disclaimer obligatoire sur chaque resultat
"""

from dataclasses import dataclass
from enum import Enum
from typing import Dict, List

from app.constants.social_insurance import (
    get_ai_rente_monthly,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Constants — Employer coverage scales (CO art. 324a)
# ═══════════════════════════════════════════════════════════════════════════════

# Echelle bernoise (majority of cantons)
# Year 1: 3 weeks, Year 2: 4, Years 3-4: 8, 5-9: 13, 10-14: 17, 15-19: 21, 20+: 26
ECHELLE_BERNOISE: Dict[int, int] = {1: 3, 2: 4, 3: 8, 5: 13, 10: 17, 15: 21, 20: 26}

# Echelle zurichoise (ZH)
# Year 1: 3, Year 2: 8, 3-4: 8, 5-9: 13, 10-14: 17, 15-19: 21, 20+: 26
ECHELLE_ZURICHOISE: Dict[int, int] = {1: 3, 2: 8, 3: 8, 5: 13, 10: 17, 15: 21, 20: 26}

# Echelle baloise (BS, BL)
# Year 1: 3, Year 2: 9, 3-5: 9, 6-10: 13, 11-15: 17, 16-20: 21, 21+: 26
ECHELLE_BALOISE: Dict[int, int] = {1: 3, 2: 9, 3: 9, 6: 13, 11: 17, 16: 21, 21: 26}

# Canton -> scale mapping
CANTON_SCALE_MAP: Dict[str, Dict[int, int]] = {
    # Echelle bernoise (majority of cantons)
    "BE": ECHELLE_BERNOISE,
    "VD": ECHELLE_BERNOISE,
    "GE": ECHELLE_BERNOISE,
    "LU": ECHELLE_BERNOISE,
    "FR": ECHELLE_BERNOISE,
    "NE": ECHELLE_BERNOISE,
    "JU": ECHELLE_BERNOISE,
    "VS": ECHELLE_BERNOISE,
    "TI": ECHELLE_BERNOISE,
    "SO": ECHELLE_BERNOISE,
    "AG": ECHELLE_BERNOISE,
    "SG": ECHELLE_BERNOISE,
    "TG": ECHELLE_BERNOISE,
    "SH": ECHELLE_BERNOISE,
    "AR": ECHELLE_BERNOISE,
    "AI": ECHELLE_BERNOISE,
    "GL": ECHELLE_BERNOISE,
    "OW": ECHELLE_BERNOISE,
    "NW": ECHELLE_BERNOISE,
    "UR": ECHELLE_BERNOISE,
    "SZ": ECHELLE_BERNOISE,
    "ZG": ECHELLE_BERNOISE,
    "GR": ECHELLE_BERNOISE,
    # Echelle zurichoise
    "ZH": ECHELLE_ZURICHOISE,
    # Echelle baloise
    "BS": ECHELLE_BALOISE,
    "BL": ECHELLE_BALOISE,
}

# All supported cantons (all 26)
SUPPORTED_CANTONS: List[str] = sorted(CANTON_SCALE_MAP.keys())

# IJM coverage rate
IJM_COVERAGE_RATE: float = 0.80
"""Taux de couverture IJM: 80% du salaire."""

# IJM maximum duration in months
IJM_MAX_DURATION_MONTHS: float = 24.0
"""Duree maximale IJM: 720 jours = 24 mois."""


# ═══════════════════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════════════════

class EmploymentStatus(str, Enum):
    """Statut professionnel de l'utilisateur."""
    EMPLOYEE = "employee"
    SELF_EMPLOYED = "self_employed"
    MIXED = "mixed"
    UNEMPLOYED = "unemployed"
    STUDENT = "student"


# ═══════════════════════════════════════════════════════════════════════════════
# Data classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class DisabilityGapResult:
    """Resultat de la simulation du gap d'invalidite."""

    # Current income
    revenu_actuel: float

    # Phase 1: Employer coverage (CO art. 324a)
    phase1_duration_weeks: float
    phase1_monthly_benefit: float
    phase1_gap: float

    # Phase 2: IJM (daily indemnity insurance)
    phase2_duration_months: float
    phase2_monthly_benefit: float
    phase2_gap: float

    # Phase 3: AI + LPP (long term)
    phase3_monthly_benefit: float
    phase3_gap: float

    # Summary
    risk_level: str  # "critical", "high", "medium", "low"
    alerts: List[str]
    ai_rente_mensuelle: float
    lpp_disability_benefit: float

    # Compliance
    chiffre_choc: str
    disclaimer: str
    sources: List[str]


# ═══════════════════════════════════════════════════════════════════════════════
# Disclaimer & sources
# ═══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Outil educatif — ne constitue pas un conseil en assurance. "
    "Consulte un\u00b7e specialiste en prevoyance pour un bilan personnalise."
)

SOURCES: List[str] = [
    "CO art. 324a (Obligation de l'employeur)",
    "LAI art. 28 (Rente AI)",
    "LPP art. 23-26 (Prestations d'invalidite LPP)",
    "LACI art. 27 (Indemnites journalieres AC)",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Helper functions
# ═══════════════════════════════════════════════════════════════════════════════

def get_employer_coverage_weeks(canton: str, annees_anciennete: int) -> int:
    """Retourne la duree de couverture employeur en semaines.

    Basee sur l'echelle cantonale (bernoise, zurichoise ou baloise)
    et le nombre d'annees d'anciennete (CO art. 324a).

    Args:
        canton: Code canton (2 lettres majuscules).
        annees_anciennete: Nombre d'annees d'anciennete chez l'employeur.

    Returns:
        Nombre de semaines de couverture.

    Raises:
        ValueError: Si le canton n'est pas supporte.
    """
    scale = CANTON_SCALE_MAP.get(canton)
    if scale is None:
        raise ValueError(f"Canton non supporte: {canton}")

    # The scale dict uses "minimum years of service" -> "weeks"
    # We find the highest threshold that the employee meets
    weeks = 3  # Default: 1st year minimum
    for threshold_years, coverage_weeks in sorted(scale.items()):
        if annees_anciennete >= threshold_years:
            weeks = coverage_weeks
    return weeks


def get_ai_rente_mensuelle(degre_invalidite: int) -> float:
    """Delegates to centralized get_ai_rente_monthly() from social_insurance."""
    return get_ai_rente_monthly(degre_invalidite)


def _format_chf(amount: float) -> str:
    """Formate un montant en CHF avec separateur de milliers (style suisse)."""
    if amount >= 1000:
        return f"{amount:,.0f}".replace(",", "'")
    return f"{amount:.0f}"


# ═══════════════════════════════════════════════════════════════════════════════
# Main computation
# ═══════════════════════════════════════════════════════════════════════════════

def compute_disability_gap(
    revenu_mensuel_net: float,
    statut_professionnel: EmploymentStatus,
    canton: str,
    annees_anciennete: int,
    has_ijm_collective: bool,
    degre_invalidite: int,
    lpp_disability_benefit: float = 0.0,
) -> DisabilityGapResult:
    """Calcule le gap financier en cas d'invalidite sur 3 phases.

    Phase 1: Couverture employeur (CO art. 324a)
        - 100% du salaire pendant X semaines (echelle cantonale)
        - Ne s'applique qu'aux salaries

    Phase 2: IJM (indemnites journalieres maladie)
        - 80% du salaire, max 720 jours (24 mois)
        - Necessite une assurance IJM (collective ou individuelle)

    Phase 3: AI + LPP invalidite
        - Rente AI selon degre (LAI art. 28)
        - Rente d'invalidite LPP (LPP art. 23-26)

    Args:
        revenu_mensuel_net: Revenu mensuel net actuel en CHF.
        statut_professionnel: Statut professionnel (employee, self_employed, etc.).
        canton: Code canton (2 lettres).
        annees_anciennete: Annees d'anciennete chez l'employeur actuel.
        has_ijm_collective: True si couvert par une IJM collective ou individuelle.
        degre_invalidite: Degre d'invalidite estime (0-100%).
        lpp_disability_benefit: Rente d'invalidite LPP mensuelle (si connue).

    Returns:
        DisabilityGapResult avec le detail des 3 phases.

    Raises:
        ValueError: Si le canton n'est pas supporte.
    """
    if canton not in CANTON_SCALE_MAP:
        raise ValueError(f"Canton non supporte: {canton}")

    alerts: List[str] = []

    # ── Phase 1: Employer coverage (CO art. 324a) ──────────────────────────
    phase1_duration_weeks: float = 0.0
    phase1_monthly_benefit: float = 0.0

    if statut_professionnel == EmploymentStatus.EMPLOYEE:
        phase1_duration_weeks = float(
            get_employer_coverage_weeks(canton, annees_anciennete)
        )
        phase1_monthly_benefit = revenu_mensuel_net  # 100% salary maintained
    else:
        alerts.append(
            "Independant: aucune couverture employeur (CO art. 324a non applicable)"
        )

    phase1_gap = revenu_mensuel_net - phase1_monthly_benefit

    # ── Phase 2: IJM (daily indemnity insurance) ───────────────────────────
    phase2_duration_months: float = IJM_MAX_DURATION_MONTHS
    phase2_monthly_benefit: float = 0.0

    if statut_professionnel == EmploymentStatus.EMPLOYEE and has_ijm_collective:
        phase2_monthly_benefit = revenu_mensuel_net * IJM_COVERAGE_RATE
    elif statut_professionnel == EmploymentStatus.SELF_EMPLOYED and has_ijm_collective:
        # Self-employed can subscribe to an individual IJM
        phase2_monthly_benefit = revenu_mensuel_net * IJM_COVERAGE_RATE
    else:
        alerts.append(
            "Aucune IJM: apres la periode employeur, tu ne recois plus rien jusqu'a l'AI"
        )

    phase2_gap = revenu_mensuel_net - phase2_monthly_benefit

    # ── Phase 3: AI + LPP ─────────────────────────────────────────────────
    ai_rente_mensuelle = get_ai_rente_mensuelle(degre_invalidite)
    phase3_monthly_benefit = ai_rente_mensuelle + lpp_disability_benefit
    phase3_gap = revenu_mensuel_net - phase3_monthly_benefit

    # ── Risk level ─────────────────────────────────────────────────────────
    risk_level = "low"

    if statut_professionnel == EmploymentStatus.SELF_EMPLOYED and not has_ijm_collective:
        risk_level = "critical"
        alerts.append(
            "CRITIQUE: Independant sans IJM = aucune couverture pendant 24 mois"
        )
    elif statut_professionnel == EmploymentStatus.EMPLOYEE and not has_ijm_collective:
        risk_level = "high"
        alerts.append(
            f"HAUT RISQUE: Apres {int(phase1_duration_weeks)} semaines, "
            f"tu n'as plus rien"
        )
    elif phase3_gap > 3000:
        risk_level = "medium"
        alerts.append("Gap important a long terme (AI + LPP insuffisants)")
    else:
        risk_level = "low"

    # ── Chiffre choc ───────────────────────────────────────────────────────
    # Use the worst gap (phase with highest deficit)
    worst_gap = max(phase1_gap, phase2_gap, phase3_gap)
    if revenu_mensuel_net > 0:
        pct = worst_gap / revenu_mensuel_net * 100
        chiffre_choc = (
            f"Ton gap mensuel serait de {_format_chf(worst_gap)} CHF "
            f"— soit {pct:.0f}% de ton revenu actuel"
        )
    else:
        chiffre_choc = "Aucun revenu declare — le gap est nul"

    return DisabilityGapResult(
        revenu_actuel=revenu_mensuel_net,
        phase1_duration_weeks=phase1_duration_weeks,
        phase1_monthly_benefit=phase1_monthly_benefit,
        phase1_gap=phase1_gap,
        phase2_duration_months=phase2_duration_months,
        phase2_monthly_benefit=phase2_monthly_benefit,
        phase2_gap=phase2_gap,
        phase3_monthly_benefit=phase3_monthly_benefit,
        phase3_gap=phase3_gap,
        risk_level=risk_level,
        alerts=alerts,
        ai_rente_mensuelle=ai_rente_mensuelle,
        lpp_disability_benefit=lpp_disability_benefit,
        chiffre_choc=chiffre_choc,
        disclaimer=DISCLAIMER,
        sources=SOURCES,
    )
