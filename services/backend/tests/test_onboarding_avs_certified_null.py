"""G1-LDG-06A hard floor for minimal onboarding AVS consumers.

The three-input onboarding contract has no reviewed owner-scoped official AVS
pension envelope.  It must therefore preserve the pension and every aggregate
that depends on it as unknown, while keeping independent LPP, tax, liquidity,
and debt illustrations available.
"""

from dataclasses import replace
import json
from pathlib import Path

import pytest

from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import MinimalProfileInput
from app.services.onboarding.premier_eclairage_selector import select_premier_eclairage


RETIREMENT_CATEGORIES = {"retirement_gap", "retirement_income"}
AVS_DEPENDENT_FIELDS = (
    "projected_avs_monthly",
    "estimated_monthly_retirement",
    "estimated_replacement_ratio",
    "retirement_gap_monthly",
)


def test_three_input_profile_keeps_avs_dependent_outputs_unknown() -> None:
    result = compute_minimal_profile(
        MinimalProfileInput(
            age=45,
            gross_salary=100_000,
            canton="VD",
            current_savings=25_000,
            existing_lpp=180_000,
            monthly_debt_service=750,
        )
    )

    assert {field: getattr(result, field) for field in AVS_DEPENDENT_FIELDS} == {
        field: None for field in AVS_DEPENDENT_FIELDS
    }
    assert result.projected_lpp_capital > 0
    assert result.projected_lpp_monthly > 0
    assert result.tax_saving_3a > 0
    assert result.months_liquidity > 0
    assert result.monthly_debt_impact == 750


def test_declaration_and_arrival_hints_do_not_unlock_an_avs_pension() -> None:
    result = compute_minimal_profile(
        MinimalProfileInput(
            age=52,
            gross_salary=125_000,
            canton="GE",
            household_type="couple",
            gender="female",
            nationality_group="EU",
            nationality_country="FR",
            arrival_age=31,
            current_savings=80_000,
            existing_lpp=350_000,
            existing_3a=45_000,
            lpp_caisse_type="complementaire",
            monthly_debt_service=0,
        )
    )

    assert all(getattr(result, field) is None for field in AVS_DEPENDENT_FIELDS)
    assert result.archetype == "expat_eu"
    assert result.projected_lpp_capital > result.projected_lpp_monthly > 0


@pytest.mark.parametrize("archetype", ["expat_eu", "independent_no_lpp"])
def test_legacy_non_null_doubles_cannot_reactivate_retirement_choc(
    archetype: str,
) -> None:
    current = compute_minimal_profile(
        MinimalProfileInput(
            age=45,
            gross_salary=100_000,
            canton="ZH",
            current_savings=50_000,
            existing_3a=0,
            existing_lpp=0,
            monthly_debt_service=0,
        )
    )
    legacy = replace(
        current,
        archetype=archetype,
        projected_avs_monthly=1_200,
        estimated_monthly_retirement=2_100,
        estimated_replacement_ratio=0.25,
        retirement_gap_monthly=6_200,
    )

    choc = select_premier_eclairage(legacy, stress_type="stress_retraite")

    assert choc.category == "tax_saving"
    assert choc.category not in RETIREMENT_CATEGORIES
    rendered = " ".join(
        (choc.display_text, choc.explanation_text, choc.action_text)
    ).lower()
    assert "avs" not in rendered
    assert "retraite" not in rendered


def test_minimal_profile_api_emits_explicit_nulls(client) -> None:
    response = client.post(
        "/api/v1/onboarding/minimal-profile",
        json={"age": 45, "grossSalary": 100_000, "canton": "VD"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert {
        "projectedAvsMonthly": payload["projectedAvsMonthly"],
        "estimatedMonthlyRetirement": payload["estimatedMonthlyRetirement"],
        "estimatedReplacementRatio": payload["estimatedReplacementRatio"],
        "retirementGapMonthly": payload["retirementGapMonthly"],
    } == {
        "projectedAvsMonthly": None,
        "estimatedMonthlyRetirement": None,
        "estimatedReplacementRatio": None,
        "retirementGapMonthly": None,
    }


def test_premier_eclairage_api_quarantines_retirement_intention(client) -> None:
    response = client.post(
        "/api/v1/onboarding/premier-eclairage",
        json={
            "age": 52,
            "grossSalary": 125_000,
            "canton": "GE",
            "householdType": "couple",
            "nationalityGroup": "EU",
            "nationalityCountry": "FR",
            "arrivalAge": 31,
            "currentSavings": 80_000,
            "existing3a": 0,
            "existingLpp": 350_000,
            "lppCaisseType": "complementaire",
            "stressType": "stress_retraite",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["category"] == "tax_saving"
    rendered = " ".join(
        (
            payload["displayText"],
            payload["explanationText"],
            payload["actionText"],
        )
    ).lower()
    assert "avs" not in rendered
    assert "retraite" not in rendered


def test_canonical_openapi_marks_avs_dependent_fields_nullable() -> None:
    canonical_path = (
        Path(__file__).resolve().parents[3]
        / "tools"
        / "openapi"
        / "mint.openapi.canonical.json"
    )
    schema = json.loads(canonical_path.read_text(encoding="utf-8"))["components"][
        "schemas"
    ]["MinimalProfileResponse"]

    for field in (
        "projectedAvsMonthly",
        "estimatedMonthlyRetirement",
        "estimatedReplacementRatio",
        "retirementGapMonthly",
    ):
        variants = schema["properties"][field]["anyOf"]
        assert {variant["type"] for variant in variants} == {"number", "null"}
        assert field in schema["required"]
