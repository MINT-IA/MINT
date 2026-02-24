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

from app.services.coach.coach_models import HallucinatedNumber


class HallucinationDetector:
    """Extracts numbers from LLM text, compares against known values."""

    # Regex patterns for Swiss financial numbers
    CHF_PATTERN = re.compile(
        r"CHF\s*([\d']+(?:[.,]\d+)?)", re.IGNORECASE
    )
    PCT_PATTERN = re.compile(
        r"(\d+[.,]\d+)\s*%"
    )
    DURATION_PATTERN = re.compile(
        r"(\d+)\s*(?:mois|ans|semaines|jours)"
    )
    PLAIN_NUMBER_PATTERN = re.compile(
        r"(\d[\d']*(?:[.,]\d+)?)\s*/\s*100"
    )

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

        extracted = self.extract_numbers(llm_output)
        if not extracted:
            return []

        hallucinations = []

        for found_text, found_value, number_type in extracted:
            # Find the closest known value
            best_match_key = None
            best_match_value = None
            best_deviation = float("inf")

            for key, known_val in known_values.items():
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
