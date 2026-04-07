"""Regression test for the pure-Python Krippendorff α implementation.

The fixture ``tools/krippendorff/fixtures/sample_ratings.json`` is a 15-rater
× 50-item synthetic dataset generated with ``random.seed(42)`` and a
truth-plus-ordinal-noise model (70% truth / 20% ±1 / 10% ±2). The expected
α values were computed once with this implementation and pinned here. Any
math drift in ``krippendorff_alpha.py`` makes this test red.
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.krippendorff import compute_alpha  # noqa: E402

FIXTURE = REPO_ROOT / "tools" / "krippendorff" / "fixtures" / "sample_ratings.json"

EXPECTED_ALPHA_OVERALL = 0.8194986338314838
EXPECTED_PER_LEVEL = {
    "N1": 0.689185,
    "N2": 0.436654,
    "N3": 0.371261,
    "N4": 0.278985,
    "N5": 0.642657,
}


def test_fixture_exists() -> None:
    assert FIXTURE.exists(), f"missing fixture: {FIXTURE}"


def test_alpha_overall_within_tolerance() -> None:
    result = compute_alpha(FIXTURE)
    assert result["n_items"] == 50
    assert result["n_raters"] == 15
    assert result["n_pairable_units"] == 50
    assert abs(result["alpha_overall"] - EXPECTED_ALPHA_OVERALL) < 0.02


def test_alpha_per_level_within_tolerance() -> None:
    result = compute_alpha(FIXTURE)
    for label, expected in EXPECTED_PER_LEVEL.items():
        actual = result["alpha_per_level"][label]
        assert abs(actual - expected) < 0.02, (
            f"{label}: expected {expected}, got {actual}"
        )


def test_alpha_meets_phase11_threshold() -> None:
    """The fixture is calibrated to land above the Phase 11 0.67 gate."""
    result = compute_alpha(FIXTURE)
    assert result["alpha_overall"] >= 0.67
