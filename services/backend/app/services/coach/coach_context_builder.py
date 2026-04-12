"""
Coach Context Builder — Sprint S35 (Coach Narrative Service).

Pure function that builds a CoachContext from profile data,
populating known_values for hallucination detection.

This is the ONLY entry point for creating CoachContext from user data.
Consumers (endpoints, services) call build_coach_context() and pass
the result to CoachNarrativeService.

Sources:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
"""

from typing import List, Optional

from app.services.coach.coach_models import CoachContext


def build_coach_context(
    first_name: str = "utilisateur",
    age: int = 30,
    canton: str = "VD",
    archetype: str = "swiss_native",
    fri_total: float = 0.0,
    fri_delta: float = 0.0,
    primary_focus: str = "",
    replacement_ratio: float = 0.0,
    months_liquidity: float = 0.0,
    tax_saving_potential: float = 0.0,
    confidence_score: float = 0.0,
    days_since_last_visit: int = 0,
    fiscal_season: str = "",
    upcoming_event: str = "",
    check_in_streak: int = 0,
    last_milestone: str = "",
    planned_contributions: Optional[List[dict]] = None,
) -> CoachContext:
    """Build CoachContext with known_values populated from financial indicators.

    The known_values dict is used by HallucinationDetector to verify
    that numbers in LLM output match financial_core computations.

    Args:
        first_name: User's first name (default: "utilisateur").
        age: User's age.
        canton: Canton of fiscal residence.
        archetype: Financial archetype (swiss_native, expat_eu, etc.).
        fri_total: FRI total score (0-100).
        fri_delta: FRI change since last check-in.
        primary_focus: Current financial priority.
        replacement_ratio: Estimated retirement replacement ratio (0-1).
        months_liquidity: Months of liquidity reserve.
        tax_saving_potential: Potential tax saving from 3a (CHF).
        confidence_score: Projection confidence score (0-100).
        days_since_last_visit: Days since last app visit.
        fiscal_season: Current fiscal season ("3a_deadline", "tax_declaration", "").
        upcoming_event: Upcoming life event (if any).
        check_in_streak: Consecutive check-in count.
        last_milestone: Last achieved milestone.
        planned_contributions: List of planned monthly contributions (id, label, amount, category).

    Returns:
        CoachContext with all fields and known_values populated.
    """
    known = {
        "fri_total": fri_total,
        "replacement_ratio": replacement_ratio * 100,  # stored as percentage
        "months_liquidity": months_liquidity,
        "tax_saving": tax_saving_potential,
        "confidence_score": confidence_score,
    }

    return CoachContext(
        first_name=first_name,
        age=age,
        canton=canton,
        archetype=archetype,
        fri_total=fri_total,
        fri_delta=fri_delta,
        primary_focus=primary_focus,
        replacement_ratio=replacement_ratio,
        months_liquidity=months_liquidity,
        tax_saving_potential=tax_saving_potential,
        confidence_score=confidence_score,
        days_since_last_visit=days_since_last_visit,
        fiscal_season=fiscal_season,
        upcoming_event=upcoming_event,
        check_in_streak=check_in_streak,
        last_milestone=last_milestone,
        planned_contributions=planned_contributions or [],
        known_values=known,
    )
