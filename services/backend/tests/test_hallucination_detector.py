"""
Tests for the Hallucination Detector — Sprint S34.

15+ tests verifying extraction and comparison of numbers from LLM text.

Run: cd services/backend && python3 -m pytest tests/test_hallucination_detector.py -v
"""

import pytest

from app.services.coach.hallucination_detector import HallucinationDetector


@pytest.fixture
def detector():
    return HallucinationDetector()


# ═══════════════════════════════════════════════════════════════════════
# Number extraction
# ═══════════════════════════════════════════════════════════════════════


class TestNumberExtraction:
    """Test extraction of numbers from LLM text."""

    def test_extract_chf_apostrophe(self, detector):
        numbers = detector.extract_numbers("Tu économises CHF 1'820 par an.")
        assert len(numbers) >= 1
        chf_nums = [n for n in numbers if n[2] == "chf"]
        assert len(chf_nums) == 1
        assert chf_nums[0][1] == 1820.0

    def test_extract_chf_plain(self, detector):
        numbers = detector.extract_numbers("Un montant de CHF 50000.")
        chf_nums = [n for n in numbers if n[2] == "chf"]
        assert len(chf_nums) == 1
        assert chf_nums[0][1] == 50000.0

    def test_extract_chf_with_decimals(self, detector):
        numbers = detector.extract_numbers("CHF 1'820.50 d'impôt.")
        chf_nums = [n for n in numbers if n[2] == "chf"]
        assert len(chf_nums) == 1
        assert chf_nums[0][1] == 1820.50

    def test_extract_percentage(self, detector):
        numbers = detector.extract_numbers("Un taux de 4.5% par an.")
        pct_nums = [n for n in numbers if n[2] == "pct"]
        assert len(pct_nums) == 1
        assert pct_nums[0][1] == 4.5

    def test_extract_duration_mois(self, detector):
        numbers = detector.extract_numbers("Tu as 6 mois de réserve.")
        dur_nums = [n for n in numbers if n[2] == "duration"]
        assert len(dur_nums) == 1
        assert dur_nums[0][1] == 6.0

    def test_extract_duration_ans(self, detector):
        numbers = detector.extract_numbers("Dans 15 ans, à la retraite.")
        dur_nums = [n for n in numbers if n[2] == "duration"]
        assert len(dur_nums) == 1
        assert dur_nums[0][1] == 15.0

    def test_extract_score_format(self, detector):
        numbers = detector.extract_numbers("Ton score est de 62/100.")
        score_nums = [n for n in numbers if n[2] == "score"]
        assert len(score_nums) == 1
        assert score_nums[0][1] == 62.0

    def test_extract_multiple_numbers(self, detector):
        text = (
            "Ton score est de 62/100. Tu économises CHF 1'820 "
            "avec un rendement de 3.5% sur 20 ans."
        )
        numbers = detector.extract_numbers(text)
        assert len(numbers) >= 3  # score, chf, pct, duration


# ═══════════════════════════════════════════════════════════════════════
# Hallucination detection
# ═══════════════════════════════════════════════════════════════════════


class TestHallucinationDetection:
    """Test detection of hallucinated numbers."""

    def test_no_hallucination_exact_match(self, detector):
        hallucinations = detector.detect(
            "Ton score est de 62/100.",
            known_values={"score": 62.0},
        )
        assert len(hallucinations) == 0

    def test_no_hallucination_within_tolerance(self, detector):
        # CHF 1'820 vs known 1'800 → 1.1% deviation, within 5%
        hallucinations = detector.detect(
            "Tu économises environ CHF 1'820 d'impôt.",
            known_values={"3a_saving": 1800.0},
        )
        assert len(hallucinations) == 0

    def test_hallucination_chf_outside_tolerance(self, detector):
        # CHF 3'200 vs known 1'800 → 77.8% deviation, outside 5%
        # (Avoid CHF 2'500 which is within 1% of legal constant 2'520.)
        hallucinations = detector.detect(
            "Tu économises CHF 3'200 d'impôt.",
            known_values={"3a_saving": 1800.0},
        )
        assert len(hallucinations) == 1
        assert hallucinations[0].found_value == 3200.0

    def test_hallucination_percentage_outside_tolerance(self, detector):
        # 58% vs known 54 → 4 points difference, outside ±2
        hallucinations = detector.detect(
            "Ton taux de remplacement est de 58.0%.",
            known_values={"replacement_ratio": 54.0},
        )
        assert len(hallucinations) == 1

    def test_no_hallucination_pct_within_tolerance(self, detector):
        # 55% vs known 54 → 1 point difference, within ±2
        hallucinations = detector.detect(
            "Ton taux de remplacement est de 55.0%.",
            known_values={"replacement_ratio": 54.0},
        )
        assert len(hallucinations) == 0

    def test_no_numbers_no_hallucination(self, detector):
        hallucinations = detector.detect(
            "Bonjour Sophie, bienvenue sur MINT !",
            known_values={"score": 62.0},
        )
        assert len(hallucinations) == 0

    def test_no_known_values_no_hallucination(self, detector):
        hallucinations = detector.detect(
            "Ton score est de 99/100.",
            known_values={},
        )
        assert len(hallucinations) == 0

    def test_multiple_numbers_one_hallucinated(self, detector):
        text = (
            "Ton score est de 62/100. "
            "Tu pourrais économiser CHF 5'000 d'impôt."
        )
        hallucinations = detector.detect(
            text,
            known_values={"score": 62.0, "3a_saving": 1820.0},
        )
        # Score 62 is correct, CHF 5000 is hallucinated (vs 1820)
        assert len(hallucinations) == 1
        assert hallucinations[0].found_value == 5000.0

    def test_large_chf_amount_hallucinated(self, detector):
        hallucinations = detector.detect(
            "Ton capital LPP est de CHF 400'000.",
            known_values={"lpp_capital": 250000.0},
        )
        # 400k vs 250k → 60% deviation
        assert len(hallucinations) == 1
        assert hallucinations[0].deviation_pct > 50

    def test_zero_known_value(self, detector):
        hallucinations = detector.detect(
            "Tu as CHF 5'000 de dette.",
            known_values={"debt": 0.0},
        )
        assert len(hallucinations) == 1
