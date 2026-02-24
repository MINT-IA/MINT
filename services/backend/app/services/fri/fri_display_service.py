"""
FRI Display Service — Sprint S39 (Beta Display).

Wraps FriService with display rules for user-facing output.

Display rules (ONBOARDING_ARBITRAGE_ENGINE.md):
    - Only shown if confidenceScore >= 50%
    - Always show breakdown (never total alone)
    - Always show top improvement action with estimated delta
    - Never say "faible", "mauvais", "insuffisant"
    - Never compare to other users

References:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 14-16 (taux de conversion)
    - LIFD art. 38 (imposition du capital)
    - FINMA circ. 2008/21 (gestion des risques)
    - OPP3 art. 7 (plafond 3a)
"""

import copy
from dataclasses import dataclass, field
from typing import Dict, List, Tuple

from app.services.fri.fri_service import FriBreakdown, FriInput, FriService


DISPLAY_CONFIDENCE_THRESHOLD = 50.0

DISCLAIMER = (
    "Score de solidite financiere a titre educatif. "
    "Ne constitue pas un conseil financier (LSFin). "
    "Consulte un·e specialiste pour une analyse personnalisee."
)

SOURCES = [
    "LAVS art. 21-29 (rente AVS)",
    "LPP art. 14-16 (taux de conversion)",
    "LIFD art. 38 (imposition du capital)",
    "OPP3 art. 7 (plafond 3a)",
    "FINMA circ. 2008/21 (gestion des risques)",
]

# Actions mapped to each component — French, educational, never prescriptive.
# Never uses banned display terms.
_ACTION_TEMPLATES = {
    "liquidite": (
        "Constituer une reserve de {months} mois de depenses "
        "pourrait renforcer ta liquidite."
    ),
    "fiscalite": (
        "Un versement 3a pourrait ameliorer ton efficacite fiscale."
    ),
    "retraite": (
        "Explorer les options de prevoyance pourrait ameliorer "
        "ta preparation retraite."
    ),
    "risque": (
        "Verifier ta couverture risque pourrait renforcer ta structure."
    ),
}


@dataclass
class FriDisplayResult:
    """Result of FRI computation with display rules applied."""

    breakdown: FriBreakdown
    display_allowed: bool
    top_action: str
    top_action_delta: float
    enrichment_message: str
    disclaimer: str
    sources: List[str]


class FriDisplayService:
    """Wraps FRI computation with display rules.

    Display rules (ONBOARDING_ARBITRAGE_ENGINE.md):
    - Only shown if confidenceScore >= 50%
    - Always show breakdown (never total alone)
    - Always show top improvement action with estimated delta
    - Never say "faible", "mauvais", "insuffisant"
    - Never compare to other users
    """

    @classmethod
    def compute_for_display(
        cls,
        inp: FriInput,
        confidence_score: float,
    ) -> FriDisplayResult:
        """Compute FRI and wrap with display context.

        Args:
            inp: FriInput with all financial indicators.
            confidence_score: Profile completeness score (0-100).

        Returns:
            FriDisplayResult with breakdown, display rules, and top action.
        """
        breakdown = FriService.compute(inp, confidence_score)

        display_allowed = confidence_score >= DISPLAY_CONFIDENCE_THRESHOLD

        enrichment_message = ""
        if not display_allowed:
            enrichment_message = (
                "Complete ton profil pour obtenir ton score de solidite "
                "financiere. Il manque quelques informations pour un "
                "resultat pertinent."
            )

        top_action = ""
        top_action_delta = 0.0
        if display_allowed:
            top_action, top_action_delta = cls._find_top_action(inp, breakdown)

        return FriDisplayResult(
            breakdown=breakdown,
            display_allowed=display_allowed,
            top_action=top_action,
            top_action_delta=round(top_action_delta, 2),
            enrichment_message=enrichment_message,
            disclaimer=DISCLAIMER,
            sources=list(SOURCES),
        )

    @classmethod
    def _find_top_action(
        cls,
        inp: FriInput,
        breakdown: FriBreakdown,
    ) -> Tuple[str, float]:
        """Find the most impactful action the user could take.

        Compares each component and identifies the weakest,
        then suggests a concrete action with an estimated delta.

        Returns:
            (action_text, estimated_delta)
        """
        components = {
            "liquidite": breakdown.liquidite,
            "fiscalite": breakdown.fiscalite,
            "retraite": breakdown.retraite,
            "risque": breakdown.risque,
        }

        # Find weakest component
        weakest = min(components, key=components.get)

        # Simulate the improvement and compute delta
        action_text, delta = cls._simulate_component_improvement(
            inp, weakest, breakdown,
        )

        return action_text, delta

    @classmethod
    def _simulate_component_improvement(
        cls,
        inp: FriInput,
        component: str,
        original: FriBreakdown,
    ) -> Tuple[str, float]:
        """Simulate improving a specific component.

        Returns (action_text, delta).
        """
        improved_inp = copy.deepcopy(inp)

        if component == "liquidite":
            # Target: 6 months of expenses
            target_months = 6
            current_months = inp.liquid_assets / max(inp.monthly_fixed_costs, 1.0)
            needed = max(0, target_months - current_months)
            improved_inp.liquid_assets = inp.monthly_fixed_costs * target_months
            improved_inp.short_term_debt_ratio = min(
                inp.short_term_debt_ratio, 0.29,
            )
            action_text = _ACTION_TEMPLATES["liquidite"].format(
                months=int(needed) if needed > 0 else target_months,
            )

        elif component == "fiscalite":
            improved_inp.actual_3a = improved_inp.max_3a
            action_text = _ACTION_TEMPLATES["fiscalite"]

        elif component == "retraite":
            improved_inp.replacement_ratio = min(
                max(inp.replacement_ratio + 0.15, 0.70), 1.0,
            )
            action_text = _ACTION_TEMPLATES["retraite"]

        else:  # risque
            improved_inp.disability_gap_ratio = min(
                inp.disability_gap_ratio, 0.19,
            )
            improved_inp.death_protection_gap_ratio = min(
                inp.death_protection_gap_ratio, 0.29,
            )
            action_text = _ACTION_TEMPLATES["risque"]

        new_breakdown = FriService.compute(improved_inp, original.confidence_score)
        delta = new_breakdown.total - original.total

        return action_text, max(delta, 0.0)

    @classmethod
    def simulate_action(
        cls,
        inp: FriInput,
        action_type: str,
        confidence_score: float,
    ) -> Dict:
        """Simulate a specific action and show delta.

        Args:
            inp: Current FriInput.
            action_type: One of "add_3a", "add_liquidity", "add_rachat",
                         "reduce_mortgage".
            confidence_score: Profile completeness score (0-100).

        Returns:
            Dict with delta_fri, new_breakdown, action_description,
            disclaimer, sources.

        Raises:
            ValueError: If action_type is not recognized.
        """
        valid_actions = {"add_3a", "add_liquidity", "add_rachat", "reduce_mortgage"}
        if action_type not in valid_actions:
            raise ValueError(
                f"Action inconnue: {action_type}. "
                f"Actions valides: {', '.join(sorted(valid_actions))}"
            )

        original = FriService.compute(inp, confidence_score)
        improved_inp = copy.deepcopy(inp)

        if action_type == "add_3a":
            improved_inp.actual_3a = improved_inp.max_3a
            description = (
                "Simulation: versement 3a au maximum ({max_3a} CHF). "
                "Amelioration potentielle de l'efficacite fiscale."
            ).format(max_3a=int(improved_inp.max_3a))

        elif action_type == "add_liquidity":
            target_months = 6
            improved_inp.liquid_assets = (
                improved_inp.monthly_fixed_costs * target_months
            )
            description = (
                "Simulation: constitution d'une reserve de 6 mois de "
                "depenses. Renforcement potentiel de la liquidite."
            )

        elif action_type == "add_rachat":
            if improved_inp.potentiel_rachat_lpp > 0:
                improved_inp.rachat_effectue = improved_inp.potentiel_rachat_lpp
            description = (
                "Simulation: rachat LPP complet. "
                "Amelioration potentielle de l'efficacite fiscale."
            )

        else:  # reduce_mortgage
            improved_inp.mortgage_stress_ratio = min(
                improved_inp.mortgage_stress_ratio, 0.30,
            )
            description = (
                "Simulation: reduction de la charge hypothecaire a 30%% "
                "du revenu. Renforcement potentiel de la structure."
            )

        new_breakdown = FriService.compute(improved_inp, confidence_score)
        delta = round(new_breakdown.total - original.total, 2)

        return {
            "delta_fri": max(delta, 0.0),
            "new_breakdown": new_breakdown,
            "action_description": description,
            "disclaimer": DISCLAIMER,
            "sources": list(SOURCES),
        }
