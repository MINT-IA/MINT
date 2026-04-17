"""
Hallucination Detector — Sprint S34.

Extracts numbers (CHF amounts, percentages, durations) from LLM text
and compares against known values from financial_core.

Any number that deviates beyond tolerance triggers a hallucination flag.
This is Layer 3 of the ComplianceGuard validation pipeline.

References:
- FINMA circular 2008/21 (operational risk management)
- LSFin art. 8 (quality of financial information)
"""

import re
from typing import List

from app.constants.social_insurance import (
    AC_PLAFOND_SALAIRE_ASSURE,
    AVS_FRANCHISE_RETRAITE_MENSUELLE,
    AVS_COTISATION_MIN_INDEPENDANT,
    AVS_RAMD_MAX,
    AVS_RAMD_MIN,
    AVS_RENTE_MAX_ANNUELLE,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_VOLONTAIRE_COTISATION_MAX,
    AVS_VOLONTAIRE_COTISATION_MIN,
    EPL_MONTANT_MINIMUM,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_MAX,
    LPP_SEUIL_ENTREE,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)
from app.services.coach.coach_models import HallucinatedNumber


class HallucinationDetector:
    """Extracts numbers from LLM text, compares against known values."""

    # Regex patterns for Swiss financial numbers
    CHF_PATTERN = re.compile(
        r"CHF\s*([\d']+(?:[.,]\d+)?)", re.IGNORECASE
    )
    # CRIT #4 fix: capture integer percentages (85%, 100%) not just decimals.
    PCT_PATTERN = re.compile(
        r"(\d+(?:[.,]\d+)?)\s*%"
    )
    DURATION_PATTERN = re.compile(
        r"(\d+)\s*(?:mois|ans|semaines|jours)"
    )
    PLAIN_NUMBER_PATTERN = re.compile(
        r"(\d[\d']*(?:[.,]\d+)?)\s*/\s*100"
    )

    # ═══════════════════════════════════════════════════════════════
    # Legal constants whitelist (mirrors Flutter hallucination_detector.dart)
    # ═══════════════════════════════════════════════════════════════

    LEGAL_CONSTANTS_CHF: set[float] = {
        # Pilier 3a (OPP3 art. 7)
        PILIER_3A_PLAFOND_AVEC_LPP,    # Plafond 3a salarié affilié LPP
        PILIER_3A_PLAFOND_SANS_LPP,    # Plafond 3a indépendant sans LPP
        # LPP (art. 7, 8)
        LPP_SEUIL_ENTREE,              # Seuil d'entrée LPP
        LPP_DEDUCTION_COORDINATION,    # Déduction de coordination
        LPP_SALAIRE_COORDONNE_MIN,     # Salaire coordonné minimum / Rente couple max mensuelle
        LPP_SALAIRE_COORDONNE_MAX,     # Salaire coordonné maximum
        LPP_SALAIRE_MAX,               # Salaire maximum assuré LPP
        # AVS (LAVS art. 34)
        AVS_RENTE_MAX_MENSUELLE,       # Rente AVS max mensuelle
        AVS_RENTE_MIN_MENSUELLE,       # Rente AVS min mensuelle
        AVS_RENTE_MAX_ANNUELLE,        # Rente AVS max annuelle
        AVS_COTISATION_MIN_INDEPENDANT,  # Cotisation min indépendant
        # EPL (OPP2 art. 5)
        EPL_MONTANT_MINIMUM,           # EPL minimum
        # AC / AVS extended
        AC_PLAFOND_SALAIRE_ASSURE,     # AC plafond salaire assuré
        AVS_RAMD_MIN,                  # AVS RAMD min
        AVS_RAMD_MAX,                  # AVS RAMD max
        AVS_FRANCHISE_RETRAITE_MENSUELLE,  # AVS franchise retraite mensuelle
        AVS_VOLONTAIRE_COTISATION_MIN,     # AVS volontaire cotisation min
        AVS_VOLONTAIRE_COTISATION_MAX,     # AVS volontaire cotisation max
    }

    LEGAL_CONSTANTS_PCT: set[float] = {
        6.8,    # Taux de conversion LPP minimum (LPP art. 14)
        1.25,   # Taux d'intérêt minimum LPP
        5.3,    # Cotisation AVS salarié
        10.6,   # Cotisation AVS totale
        5.0,    # Taux théorique hypothécaire (FINMA/ASB)
        7.0,    # Bonification LPP 25-34
        10.0,   # Bonification LPP 35-44
        15.0,   # Bonification LPP 45-54
        18.0,   # Bonification LPP 55-65
        20.0,   # Part revenu 3a sans LPP
        70.0,   # Taux indemnité chômage standard
        80.0,   # Taux indemnité chômage avec charges
        100.0,  # Référence: "100% de ton capital"
        # AVS deferral bonuses
        5.2, 16.4, 22.7, 31.5,
        # AI/APG/AC cotisation rates
        0.7, 0.25, 1.1, 0.5, 0.2,
    }

    LEGAL_CONSTANT_TOLERANCE = 0.01  # ±1%

    @classmethod
    def _is_legal_constant(cls, value: float, number_type: str) -> bool:
        """Check if value matches a known Swiss legal constant."""
        constants = (
            cls.LEGAL_CONSTANTS_PCT
            if number_type in ("pct", "score")
            else cls.LEGAL_CONSTANTS_CHF
        )
        for c in constants:
            if c == 0:
                continue
            if abs(value - c) / abs(c) <= cls.LEGAL_CONSTANT_TOLERANCE:
                return True
        return False

    @staticmethod
    def _parse_swiss_number(text: str) -> float:
        """Parse a Swiss-formatted number (e.g., 1'820 or 1,820.50)."""
        cleaned = text.replace("'", "").replace(" ", "")
        cleaned = cleaned.replace(",", ".")
        try:
            return float(cleaned)
        except ValueError:
            return 0.0

    def extract_numbers(self, text: str) -> list:
        """Extract all numbers (CHF, %, durations, /100 scores) from text.

        Returns list of tuples: (original_text, parsed_value, number_type).
        """
        results = []

        # CHF amounts
        for match in self.CHF_PATTERN.finditer(text):
            value = self._parse_swiss_number(match.group(1))
            results.append((match.group(0), value, "chf"))

        # Percentages
        for match in self.PCT_PATTERN.finditer(text):
            value = self._parse_swiss_number(match.group(1))
            results.append((match.group(0), value, "pct"))

        # Durations (months, years, etc.)
        for match in self.DURATION_PATTERN.finditer(text):
            value = float(match.group(1))
            results.append((match.group(0), value, "duration"))

        # Score format: X/100
        for match in self.PLAIN_NUMBER_PATTERN.finditer(text):
            value = self._parse_swiss_number(match.group(1))
            results.append((match.group(0), value, "score"))

        return results

    def detect(
        self,
        llm_output: str,
        known_values: dict,
        tolerance_pct: float = 0.05,
        tolerance_abs: float = 2.0,
    ) -> List[HallucinatedNumber]:
        """Detect hallucinated numbers in LLM output.

        Args:
            llm_output: The LLM-generated text to check.
            known_values: Dict of known values {key: value} from financial_core.
            tolerance_pct: Relative tolerance for CHF amounts (default 5%).
            tolerance_abs: Absolute tolerance for percentages and scores (default 2 points).

        Returns:
            List of HallucinatedNumber instances for each hallucinated value.
        """
        if not known_values:
            return []

        # Filter out zero/None values — these indicate profile fields the user
        # hasn't declared yet. Comparing "122000 CHF" from the user's new
        # declaration against a profile value of 0 produces infinite deviation
        # and wrongly flags every legit mention of a new fact as hallucination.
        # This killed every "J'ai X CHF" declaration as a compliance violation.
        known_values = {
            k: v for k, v in known_values.items()
            if v is not None and v != 0
        }
        if not known_values:
            return []

        extracted = self.extract_numbers(llm_output)
        if not extracted:
            return []

        hallucinations = []

        for found_text, found_value, number_type in extracted:
            # Skip legal constants — LLM is allowed to cite these.
            if self._is_legal_constant(found_value, number_type):
                continue

            # Skip non-finite values.
            if not (found_value == found_value and found_value != float("inf")
                    and found_value != float("-inf")):
                continue

            # Find the closest known value
            best_match_key = None
            best_match_value = None
            best_deviation = float("inf")

            for key, known_val in known_values.items():
                # Skip non-finite known values.
                if not (known_val == known_val and known_val != float("inf")
                        and known_val != float("-inf")):
                    continue
                if known_val == 0:
                    deviation = abs(found_value)
                else:
                    deviation = abs(found_value - known_val) / abs(known_val)
                if deviation < best_deviation:
                    best_deviation = deviation
                    best_match_key = key
                    best_match_value = known_val

            if best_match_key is None:
                continue

            # Relevance check: only flag if the number is plausibly trying
            # to cite a known value.
            is_relevant = True
            if number_type in ("pct", "score"):
                if abs(found_value - best_match_value) > 30.0:
                    is_relevant = False
            else:
                if best_match_value != 0:
                    ratio = found_value / best_match_value
                    if ratio > 10.0 or ratio < 0.1:
                        is_relevant = False
            if not is_relevant:
                continue

            # Check tolerance based on number type
            is_hallucinated = False
            if number_type in ("pct", "score"):
                # Absolute tolerance for percentages and scores
                if abs(found_value - best_match_value) > tolerance_abs:
                    is_hallucinated = True
            else:
                # Relative tolerance for CHF amounts and durations
                if best_match_value == 0:
                    is_hallucinated = found_value != 0
                elif best_deviation > tolerance_pct:
                    is_hallucinated = True

            if is_hallucinated:
                hallucinations.append(
                    HallucinatedNumber(
                        found_text=found_text,
                        found_value=found_value,
                        closest_key=best_match_key,
                        closest_value=best_match_value,
                        deviation_pct=best_deviation * 100,
                    )
                )

        return hallucinations
