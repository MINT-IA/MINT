"""
Scenario Narrator Service — Sprint S37.

Narrates 3 retirement scenarios (prudent / base / optimiste) as educational text.

Without BYOK: structured deterministic text with numbers.
With BYOK: LLM narrates (future — ComplianceGuard validates).

Rules:
    - Each scenario: max 150 words
    - Each MUST mention the return assumption
    - Each MUST mention uncertainty
    - No prescriptive language
    - No banned terms (garanti, certain, assure, sans risque, optimal, meilleur,
      parfait, conseiller, tu devrais, tu dois, il faut que tu)
    - CHF formatted with Swiss apostrophe (e.g. 123'456)
    - All French, informal "tu"

Sources:
    - LPP art. 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
    - LSFin art. 3 (information financiere)
"""

from typing import List

from app.services.scenario.scenario_models import (
    NarratedScenario,
    ScenarioInput,
    ScenarioNarrationResult,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

STANDARD_DISCLAIMER = (
    "Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin). "
    "Les projections reposent sur des hypotheses et ne representent pas "
    "des rendements futurs."
)

STANDARD_SOURCES = [
    "LSFin art. 3",
    "LPP art. 14-16",
    "LAVS art. 21-40",
]

# Banned terms — must NEVER appear in any narrative output
BANNED_TERMS = [
    "garanti",
    "certain",
    "assuré",
    "sans risque",
    "optimal",
    "meilleur",
    "parfait",
    "conseiller",
    "tu devrais",
    "tu dois",
    "il faut que tu",
]

# Narrative templates per scenario label
_TEMPLATES = {
    "prudent": (
        "Scenario prudent (rendement {pct}%/an) : avec un capital estime "
        "a CHF {capital} a la retraite, ta rente mensuelle pourrait avoisiner "
        "CHF {monthly}. Ce scenario suppose une croissance modeste. "
        "L'incertitude reste presente — les marches peuvent evoluer differemment."
    ),
    "base": (
        "Scenario de reference (rendement {pct}%/an) : le capital estime "
        "atteindrait CHF {capital}, soit environ CHF {monthly}/mois. "
        "Ce scenario repose sur des hypotheses medianes. "
        "Les resultats reels dependront de nombreux facteurs."
    ),
    "optimiste": (
        "Scenario favorable (rendement {pct}%/an) : CHF {capital} en capital, "
        "soit environ CHF {monthly}/mois. Ce scenario suppose des conditions "
        "de marche favorables. Aucun rendement n'est acquis au sens strict "
        "— les projections restent des estimations."
    ),
}

# Fallback for unknown labels
_FALLBACK_TEMPLATE = (
    "Scenario {label} (rendement {pct}%/an) : capital estime a "
    "CHF {capital}, revenu mensuel estime a CHF {monthly}. "
    "Les projections sont indicatives et soumises a l'incertitude des marches."
)


def _format_chf(amount: float) -> str:
    """Format a CHF amount with Swiss apostrophe separators.

    Examples:
        1234.56   -> "1'235"
        123456.78 -> "123'456"
        1000000   -> "1'000'000"
    """
    rounded = round(amount)
    if rounded < 0:
        return "-" + _format_chf(-rounded)
    s = str(rounded)
    # Insert apostrophes from the right every 3 digits
    parts = []
    while len(s) > 3:
        parts.append(s[-3:])
        s = s[:-3]
    parts.append(s)
    return "'".join(reversed(parts))


class ScenarioNarratorService:
    """Narrates 3 retirement scenarios as educational text.

    Deterministic fallback mode — no LLM required.
    """

    def narrate_scenarios(
        self,
        scenarios: List[ScenarioInput],
        first_name: str = "utilisateur",
        age: int = 30,
    ) -> ScenarioNarrationResult:
        """Generate narratives for the given scenarios.

        Args:
            scenarios: List of ScenarioInput (typically 3: prudent/base/optimiste).
            first_name: User's first name for personalisation (future LLM use).
            age: User's current age (future LLM use).

        Returns:
            ScenarioNarrationResult with narrated scenarios, disclaimer, sources.
        """
        narrated: List[NarratedScenario] = []

        for sc in scenarios:
            pct = round(sc.annual_return * 100, 1)
            capital_str = _format_chf(sc.capital_final)
            monthly_str = _format_chf(sc.monthly_income)

            template = _TEMPLATES.get(sc.label, _FALLBACK_TEMPLATE)
            narrative = template.format(
                pct=pct,
                capital=capital_str,
                monthly=monthly_str,
                label=sc.label,
            )

            # Safety: strip any accidental banned terms
            narrative = self._sanitize(narrative)

            narrated.append(
                NarratedScenario(
                    label=sc.label,
                    narrative=narrative,
                    annual_return_pct=pct,
                    capital_final=sc.capital_final,
                    monthly_income=sc.monthly_income,
                )
            )

        return ScenarioNarrationResult(
            scenarios=narrated,
            disclaimer=STANDARD_DISCLAIMER,
            sources=list(STANDARD_SOURCES),
            uncertainty_mentioned=True,
        )

    @staticmethod
    def _sanitize(text: str) -> str:
        """Remove banned terms from generated text.

        This is a safety net — templates should already be clean.
        Replaces banned terms with safe alternatives.
        """
        replacements = {
            "garanti au sens strict": "acquis",
            "garanti": "acquis",
            "certain": "probable",
            "assuré": "estime",
            "sans risque": "a faible risque",
            "optimal": "adapte",
            "meilleur": "favorable",
            "parfait": "adequat",
            "conseiller": "specialiste",
            "tu devrais": "tu pourrais",
            "tu dois": "tu peux",
            "il faut que tu": "tu peux envisager de",
        }
        lower = text.lower()
        for banned, safe in replacements.items():
            if banned in lower:
                # Case-insensitive replacement
                import re

                text = re.sub(re.escape(banned), safe, text, flags=re.IGNORECASE)
        return text
