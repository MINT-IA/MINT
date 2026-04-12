"""FIX-162: Test disability gap for all employment statuses."""
import pytest
from app.services.rules_engine import compute_disability_gap


@pytest.mark.parametrize("status,expected_risk", [
    ("employee", "high"),      # No IJM
    ("self_employed", "critical"),
    ("retired", "low"),
    ("student", "high"),
    ("unemployed", "high"),
    ("salarie", "high"),       # FR alias
    ("independant", "critical"),  # FR alias
    ("retraite", "low"),       # FR alias
])
def test_disability_gap_all_statuses(status, expected_risk):
    result = compute_disability_gap(
        monthly_income=8000,
        employment_status=status,
        canton="ZH",
        years_of_service=5,
        has_ijm_collective=False,
    )
    assert result["risk_level"] == expected_risk
    assert isinstance(result["alerts"], list)
