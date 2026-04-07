"""
AVS retirement pension estimation (LAVS art. 21-29).

Simulates the AVS first-pillar pension under three scenarios:
    - Anticipation (early retirement from age 63): penalty of -6.8% per year
    - Normal retirement at age 65
    - Ajournement (deferral up to age 70): bonus of +5.2% to +31.5%

Also handles contribution gaps and couple plafonnement.

Sources:
    - LAVS art. 21bis (anticipation de la rente)
    - LAVS art. 21ter (ajournement de la rente)
    - LAVS art. 29 (rente maximale)
    - LAVS art. 24 (rente de survivant)

Sprint S21 — Retraite complete.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from app.constants.social_insurance import (
    AVS_13EME_RENTE_ACTIVE,
    AVS_NOMBRE_RENTES_PAR_AN,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_RENTE_COUPLE_MAX_MENSUELLE,
    AVS_DUREE_COTISATION_COMPLETE,
    AVS_REDUCTION_ANTICIPATION,
    AVS_SUPPLEMENT_AJOURNEMENT,
    AVS_RAMD_MIN,
    AVS_RAMD_MAX,
)


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de ton "
    "historique de cotisations, de ton canton et de ta situation personnelle. "
    "Ne constitue pas un conseil en prevoyance (LSFin). Consulte un ou une specialiste."
)

# Derived constants
AVS_MAX_RENTE_ANNUELLE = AVS_RENTE_MAX_MENSUELLE * 12
AVS_MAX_RENTE_COUPLE_FACTOR = AVS_RENTE_COUPLE_MAX_MENSUELLE / AVS_RENTE_MAX_MENSUELLE
AVS_RETIREMENT_AGE = 65
AVS_MIN_ANTICIPATION_AGE = 63      # can start at 63 (1 or 2 years early)
AVS_MAX_DEFERRAL_YEARS = 5         # can defer up to 5 years (to age 70)


@dataclass
class AvsEstimation:
    """Complete result of AVS pension estimation."""
    scenario: str                     # "anticipation", "normal", "ajournement"
    age_depart: int                   # Retirement age chosen
    rente_mensuelle: float            # Monthly pension (CHF)
    rente_annuelle: float             # Annual pension (CHF) — includes 13th rente if active
    nombre_rentes_par_an: int         # 13 (with 13th rente) or 12 (without)
    facteur_ajustement: float         # 1.0, <1.0 (penalty), >1.0 (bonus)
    penalite_ou_bonus_pct: float      # % adjustment (negative = penalty)
    rente_couple_mensuelle: Optional[float]  # Couple pension if applicable
    duree_estimee_ans: int            # Years from retirement to life expectancy
    total_cumule: float               # Total pension over estimated duration
    breakeven_vs_normal: Optional[int]  # Age at which total exceeds normal scenario
    premier_eclairage: str                 # Educational shock figure
    sources: List[str] = field(default_factory=list)


class AvsEstimationService:
    """Estimate AVS retirement pension under different scenarios.

    Key rules:
    - Normal retirement at age 65 (LAVS art. 21)
    - Anticipation: 1 or 2 years early, -6.8% per year (LAVS art. 21bis)
    - Deferral: 1 to 5 years late, +5.2% to +31.5% (LAVS art. 21ter)
    - Maximum individual rente: CHF 2'520/month (2025)
    - Couple cap: 150% of single rente (LAVS art. 35)
    - Gaps in contributions reduce rente proportionally (LAVS art. 29)
    """

    @staticmethod
    def _rente_from_ramd(gross_salary: float) -> float:
        """Compute full AVS rente from RAMD using linear interpolation.

        LAVS art. 34: rente is linearly interpolated between min and max
        based on Revenu Annuel Moyen Déterminant (RAMD).

        - RAMD <= 14'700 CHF → minimum rente (1'260 CHF/month)
        - RAMD >= 88'200 CHF → maximum rente (2'520 CHF/month)
        - Between: linear interpolation

        Args:
            gross_salary: Annual gross salary used as proxy for RAMD.

        Returns:
            Full monthly rente before gap reduction (CHF).
        """
        if gross_salary <= 0:
            return 0.0
        if gross_salary <= AVS_RAMD_MIN:
            return AVS_RENTE_MIN_MENSUELLE
        if gross_salary >= AVS_RAMD_MAX:
            return AVS_RENTE_MAX_MENSUELLE
        ratio = (gross_salary - AVS_RAMD_MIN) / (AVS_RAMD_MAX - AVS_RAMD_MIN)
        return AVS_RENTE_MIN_MENSUELLE + ratio * (
            AVS_RENTE_MAX_MENSUELLE - AVS_RENTE_MIN_MENSUELLE
        )

    def estimate(
        self,
        current_age: int,
        retirement_age: int = 65,
        is_couple: bool = False,
        annees_lacunes: int = 0,
        life_expectancy: int = 87,
        gross_salary: float = 0.0,
    ) -> AvsEstimation:
        """Estimate AVS pension for the given parameters.

        Args:
            current_age: Person's current age.
            retirement_age: Desired retirement age (63-70).
            is_couple: Whether both spouses receive AVS (couple plafonnement).
            annees_lacunes: Number of years with missing contributions.
            life_expectancy: Assumed life expectancy for cumulative calculation.
            gross_salary: Annual gross salary (proxy for RAMD). If 0, uses max rente.

        Returns:
            AvsEstimation with complete projection.
        """
        # 1. Determine scenario and adjustment factor
        if retirement_age < AVS_RETIREMENT_AGE:
            scenario = "anticipation"
            years_early = AVS_RETIREMENT_AGE - retirement_age
            factor = 1.0 - (AVS_REDUCTION_ANTICIPATION * years_early)
            penalty_pct = -(AVS_REDUCTION_ANTICIPATION * years_early * 100)
        elif retirement_age > AVS_RETIREMENT_AGE:
            scenario = "ajournement"
            years_late = min(retirement_age - AVS_RETIREMENT_AGE, AVS_MAX_DEFERRAL_YEARS)
            factor = 1.0 + AVS_SUPPLEMENT_AJOURNEMENT.get(years_late, AVS_SUPPLEMENT_AJOURNEMENT[5])
            penalty_pct = AVS_SUPPLEMENT_AJOURNEMENT.get(years_late, AVS_SUPPLEMENT_AJOURNEMENT[5]) * 100
        else:
            scenario = "normal"
            factor = 1.0
            penalty_pct = 0.0

        # 2. Apply contribution gaps reduction
        effective_years = AVS_DUREE_COTISATION_COMPLETE - annees_lacunes
        effective_years = max(0, effective_years)
        gap_factor = effective_years / AVS_DUREE_COTISATION_COMPLETE if effective_years > 0 else 0

        # 3. Calculate rente using RAMD-based interpolation (LAVS art. 34)
        # If gross_salary is provided and > 0, use RAMD lookup; otherwise max rente
        if gross_salary > 0:
            full_rente = self._rente_from_ramd(gross_salary)
        else:
            full_rente = AVS_RENTE_MAX_MENSUELLE
        base_rente = full_rente * gap_factor
        rente_mensuelle = round(base_rente * factor, 2)
        # Annual rente includes 13th rente if active (13 × monthly instead of 12)
        nb_rentes = AVS_NOMBRE_RENTES_PAR_AN if AVS_13EME_RENTE_ACTIVE else 12
        rente_annuelle = round(rente_mensuelle * nb_rentes, 2)

        # 4. Couple plafonnement
        # TODO(P1-3): LAVS art. 29quinquies — income splitting during marriage not yet modeled.
        # Current: applies 150% couple cap only. For asymmetric couples (e.g. 200k + 0),
        # individual rentes before cap may be inaccurate. Full splitting requires marriage date.
        rente_couple = None
        if is_couple:
            rente_couple = round(
                min(
                    rente_mensuelle * 2,
                    AVS_RENTE_MAX_MENSUELLE * AVS_MAX_RENTE_COUPLE_FACTOR,
                ),
                2,
            )

        # 5. Cumulative projection
        duree = max(0, life_expectancy - retirement_age)
        total_cumule = round(rente_annuelle * duree, 2)

        # 6. Breakeven (only for anticipation/deferral)
        breakeven = self._calculate_breakeven(
            scenario, retirement_age, rente_mensuelle, gap_factor, life_expectancy,
            gross_salary=gross_salary,
        )

        # 7. Chiffre choc
        normal_rente = full_rente * gap_factor  # rente without anticipation/deferral
        if scenario == "anticipation":
            perte_totale = round(
                (normal_rente - rente_mensuelle) * nb_rentes * duree, 0
            )
            premier_eclairage = (
                f"Anticiper de {AVS_RETIREMENT_AGE - retirement_age} an(s) = "
                f"-{abs(penalty_pct):.1f}% a vie, soit ~CHF {perte_totale:,.0f} "
                f"de moins sur {duree} ans"
            )
        elif scenario == "ajournement":
            gain_total = round(
                (rente_mensuelle - normal_rente) * nb_rentes * duree, 0
            )
            premier_eclairage = (
                f"Ajourner de {retirement_age - AVS_RETIREMENT_AGE} an(s) = "
                f"+{penalty_pct:.1f}% a vie, soit ~CHF {gain_total:,.0f} "
                f"de plus sur {duree} ans"
            )
        else:
            premier_eclairage = (
                f"Ta rente AVS estimee : CHF {rente_mensuelle:,.0f}/mois "
                f"soit CHF {rente_annuelle:,.0f}/an (13 rentes)"
            )

        sources = [
            "LAVS art. 21bis (anticipation de la rente)",
            "LAVS art. 21ter (ajournement de la rente)",
            "LAVS art. 29 (rente maximale, echelle 44)",
            "LAVS art. 34 nouveau (13eme rente, des decembre 2026)",
        ]

        return AvsEstimation(
            scenario=scenario,
            age_depart=retirement_age,
            rente_mensuelle=rente_mensuelle,
            rente_annuelle=rente_annuelle,
            nombre_rentes_par_an=nb_rentes,
            facteur_ajustement=round(factor, 4),
            penalite_ou_bonus_pct=round(penalty_pct, 1),
            rente_couple_mensuelle=rente_couple,
            duree_estimee_ans=duree,
            total_cumule=total_cumule,
            breakeven_vs_normal=breakeven,
            premier_eclairage=premier_eclairage,
            sources=sources,
        )

    def _calculate_breakeven(
        self,
        scenario: str,
        retirement_age: int,
        rente_mensuelle: float,
        gap_factor: float,
        life_expectancy: int,
        gross_salary: float = 0.0,
    ) -> Optional[int]:
        """Calculate the breakeven age where cumulative amounts cross.

        For anticipation: the age at which the normal scenario total
        catches up (anticipation gets a head start but lower amount).
        For deferral: the age at which the deferral scenario total
        surpasses the normal scenario total.

        Args:
            scenario: "anticipation", "normal", or "ajournement".
            retirement_age: Chosen retirement age.
            rente_mensuelle: Monthly pension with adjustments.
            gap_factor: Contribution gap reduction factor.
            life_expectancy: Assumed life expectancy.
            gross_salary: Annual gross salary for RAMD lookup.

        Returns:
            Breakeven age or None.
        """
        if scenario == "normal":
            return None

        # Use RAMD-based rente for the normal scenario baseline
        if gross_salary > 0:
            full_rente = self._rente_from_ramd(gross_salary)
        else:
            full_rente = AVS_RENTE_MAX_MENSUELLE
        normal_rente_mensuelle = full_rente * gap_factor

        # Annual rente uses 13 payments (13e rente) when active, not 12.
        nb_rentes = AVS_NOMBRE_RENTES_PAR_AN if AVS_13EME_RENTE_ACTIVE else 12

        # Compare cumulative amounts year by year
        cumul_scenario = 0.0
        cumul_normal = 0.0
        start_age = min(retirement_age, AVS_RETIREMENT_AGE)

        for age in range(start_age, life_expectancy + 1):
            if age >= retirement_age:
                cumul_scenario += rente_mensuelle * nb_rentes
            if age >= AVS_RETIREMENT_AGE:
                cumul_normal += normal_rente_mensuelle * nb_rentes

            if scenario == "ajournement" and cumul_scenario > cumul_normal and cumul_normal > 0:
                return age

        # For anticipation: find where normal catches up
        if scenario == "anticipation":
            cumul_scenario = 0.0
            cumul_normal = 0.0
            for age in range(start_age, life_expectancy + 1):
                if age >= retirement_age:
                    cumul_scenario += rente_mensuelle * nb_rentes
                if age >= AVS_RETIREMENT_AGE:
                    cumul_normal += normal_rente_mensuelle * nb_rentes
                if cumul_normal > cumul_scenario and cumul_scenario > 0:
                    return age

        return None
