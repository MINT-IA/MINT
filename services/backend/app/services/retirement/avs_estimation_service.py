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


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de ton "
    "historique de cotisations, de ton canton et de ta situation personnelle. "
    "Ne constitue pas un conseil en prevoyance (LSFin). Consulte un ou une specialiste."
)

# AVS Constants (2025/2026)
AVS_MAX_RENTE_MENSUELLE = 2520.0   # CHF/month (individual)
AVS_MAX_RENTE_ANNUELLE = 30240.0   # CHF/year
AVS_MAX_RENTE_COUPLE_FACTOR = 1.50  # couple capped at 150%
AVS_RETIREMENT_AGE = 65
AVS_MIN_ANTICIPATION_AGE = 63      # can start at 63 (1 or 2 years early)
AVS_MAX_DEFERRAL_YEARS = 5         # can defer up to 5 years (to age 70)

# Full contribution period: 44 years (age 21 to 64 inclusive)
AVS_FULL_CONTRIBUTION_YEARS = 44

# Anticipation penalty (LAVS art. 21bis): -6.8% per year
AVS_ANTICIPATION_PENALTY_PER_YEAR = 0.068

# Deferral bonus (LAVS art. 21ter): cumulative rates
AVS_DEFERRAL_BONUS = {
    1: 0.052,   # +5.2% for 1 year deferral
    2: 0.108,   # +10.8% for 2 years
    3: 0.171,   # +17.1% for 3 years
    4: 0.240,   # +24.0% for 4 years
    5: 0.315,   # +31.5% for 5 years
}

# Survivor rente (LAVS art. 24)
AVS_SURVIVOR_RENTE_FACTOR = 0.80   # 80% of deceased's rente


@dataclass
class AvsEstimation:
    """Complete result of AVS pension estimation."""
    scenario: str                     # "anticipation", "normal", "ajournement"
    age_depart: int                   # Retirement age chosen
    rente_mensuelle: float            # Monthly pension (CHF)
    rente_annuelle: float             # Annual pension (CHF)
    facteur_ajustement: float         # 1.0, <1.0 (penalty), >1.0 (bonus)
    penalite_ou_bonus_pct: float      # % adjustment (negative = penalty)
    rente_couple_mensuelle: Optional[float]  # Couple pension if applicable
    duree_estimee_ans: int            # Years from retirement to life expectancy
    total_cumule: float               # Total pension over estimated duration
    breakeven_vs_normal: Optional[int]  # Age at which total exceeds normal scenario
    chiffre_choc: str                 # Educational shock figure
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

    def estimate(
        self,
        current_age: int,
        retirement_age: int = 65,
        is_couple: bool = False,
        annees_lacunes: int = 0,
        life_expectancy: int = 87,
    ) -> AvsEstimation:
        """Estimate AVS pension for the given parameters.

        Args:
            current_age: Person's current age.
            retirement_age: Desired retirement age (63-70).
            is_couple: Whether both spouses receive AVS (couple plafonnement).
            annees_lacunes: Number of years with missing contributions.
            life_expectancy: Assumed life expectancy for cumulative calculation.

        Returns:
            AvsEstimation with complete projection.
        """
        # 1. Determine scenario and adjustment factor
        if retirement_age < AVS_RETIREMENT_AGE:
            scenario = "anticipation"
            years_early = AVS_RETIREMENT_AGE - retirement_age
            factor = 1.0 - (AVS_ANTICIPATION_PENALTY_PER_YEAR * years_early)
            penalty_pct = -(AVS_ANTICIPATION_PENALTY_PER_YEAR * years_early * 100)
        elif retirement_age > AVS_RETIREMENT_AGE:
            scenario = "ajournement"
            years_late = min(retirement_age - AVS_RETIREMENT_AGE, AVS_MAX_DEFERRAL_YEARS)
            factor = 1.0 + AVS_DEFERRAL_BONUS.get(years_late, AVS_DEFERRAL_BONUS[5])
            penalty_pct = AVS_DEFERRAL_BONUS.get(years_late, AVS_DEFERRAL_BONUS[5]) * 100
        else:
            scenario = "normal"
            factor = 1.0
            penalty_pct = 0.0

        # 2. Apply contribution gaps reduction
        effective_years = AVS_FULL_CONTRIBUTION_YEARS - annees_lacunes
        effective_years = max(0, effective_years)
        gap_factor = effective_years / AVS_FULL_CONTRIBUTION_YEARS if effective_years > 0 else 0

        # 3. Calculate rente
        base_rente = AVS_MAX_RENTE_MENSUELLE * gap_factor
        rente_mensuelle = round(base_rente * factor, 2)
        rente_annuelle = round(rente_mensuelle * 12, 2)

        # 4. Couple plafonnement
        rente_couple = None
        if is_couple:
            rente_couple = round(
                min(
                    rente_mensuelle * 2,
                    AVS_MAX_RENTE_MENSUELLE * AVS_MAX_RENTE_COUPLE_FACTOR,
                ),
                2,
            )

        # 5. Cumulative projection
        duree = max(0, life_expectancy - retirement_age)
        total_cumule = round(rente_annuelle * duree, 2)

        # 6. Breakeven (only for anticipation/deferral)
        breakeven = self._calculate_breakeven(
            scenario, retirement_age, rente_mensuelle, gap_factor, life_expectancy
        )

        # 7. Chiffre choc
        if scenario == "anticipation":
            perte_totale = round(
                (AVS_MAX_RENTE_MENSUELLE * gap_factor - rente_mensuelle) * 12 * duree, 0
            )
            chiffre_choc = (
                f"Anticiper de {AVS_RETIREMENT_AGE - retirement_age} an(s) = "
                f"-{abs(penalty_pct):.1f}% a vie, soit ~CHF {perte_totale:,.0f} "
                f"de moins sur {duree} ans"
            )
        elif scenario == "ajournement":
            gain_total = round(
                (rente_mensuelle - AVS_MAX_RENTE_MENSUELLE * gap_factor) * 12 * duree, 0
            )
            chiffre_choc = (
                f"Ajourner de {retirement_age - AVS_RETIREMENT_AGE} an(s) = "
                f"+{penalty_pct:.1f}% a vie, soit ~CHF {gain_total:,.0f} "
                f"de plus sur {duree} ans"
            )
        else:
            chiffre_choc = (
                f"Ta rente AVS estimee : CHF {rente_mensuelle:,.0f}/mois "
                f"soit CHF {rente_annuelle:,.0f}/an"
            )

        sources = [
            "LAVS art. 21bis (anticipation de la rente)",
            "LAVS art. 21ter (ajournement de la rente)",
            "LAVS art. 29 (rente maximale, echelle 44)",
        ]

        return AvsEstimation(
            scenario=scenario,
            age_depart=retirement_age,
            rente_mensuelle=rente_mensuelle,
            rente_annuelle=rente_annuelle,
            facteur_ajustement=round(factor, 4),
            penalite_ou_bonus_pct=round(penalty_pct, 1),
            rente_couple_mensuelle=rente_couple,
            duree_estimee_ans=duree,
            total_cumule=total_cumule,
            breakeven_vs_normal=breakeven,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def _calculate_breakeven(
        self,
        scenario: str,
        retirement_age: int,
        rente_mensuelle: float,
        gap_factor: float,
        life_expectancy: int,
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

        Returns:
            Breakeven age or None.
        """
        if scenario == "normal":
            return None

        normal_rente_mensuelle = AVS_MAX_RENTE_MENSUELLE * gap_factor

        # Compare cumulative amounts year by year
        cumul_scenario = 0.0
        cumul_normal = 0.0
        start_age = min(retirement_age, AVS_RETIREMENT_AGE)

        for age in range(start_age, life_expectancy + 1):
            if age >= retirement_age:
                cumul_scenario += rente_mensuelle * 12
            if age >= AVS_RETIREMENT_AGE:
                cumul_normal += normal_rente_mensuelle * 12

            if scenario == "ajournement" and cumul_scenario > cumul_normal and cumul_normal > 0:
                return age

        # For anticipation: find where normal catches up
        if scenario == "anticipation":
            cumul_scenario = 0.0
            cumul_normal = 0.0
            for age in range(start_age, life_expectancy + 1):
                if age >= retirement_age:
                    cumul_scenario += rente_mensuelle * 12
                if age >= AVS_RETIREMENT_AGE:
                    cumul_normal += normal_rente_mensuelle * 12
                if cumul_normal > cumul_scenario and cumul_scenario > 0:
                    return age

        return None
