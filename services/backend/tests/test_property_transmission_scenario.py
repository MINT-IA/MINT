import json
import unicodedata
from copy import deepcopy
from pathlib import Path

from app.services.succession_property_transmission import (
    compute_property_transmission_scenario,
)


FIXTURE = (
    Path(__file__).parent
    / "fixtures"
    / "scenarios"
    / "property_transmission_raiffeisen.json"
)
SOURCE_DATE_FIXTURE = (
    Path(__file__).parent
    / "fixtures"
    / "scenarios"
    / "property_transmission_raiffeisen_source_dates.json"
)


def _load_fixture(path: Path = FIXTURE) -> dict:
    return json.loads(path.read_text())


def _resolve_path(value: dict, path: str):
    current = value
    for part in path.split("."):
        current = current[part]
    return current


def _assert_expected_contract(result: dict, expected: dict) -> None:
    for path, contract in expected.items():
        actual = _resolve_path(result, path)
        expected_value = contract["value"]
        tolerance = contract["tolerance"]
        if isinstance(expected_value, (int, float)):
            assert abs(actual - expected_value) <= tolerance, path
        else:
            assert actual == expected_value, path


def _collect_strings(value) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        strings: list[str] = []
        for nested in value.values():
            strings.extend(_collect_strings(nested))
        return strings
    if isinstance(value, list):
        strings: list[str] = []
        for nested in value:
            strings.extend(_collect_strings(nested))
        return strings
    return []


def test_raiffeisen_property_transmission_fixture_outputs_guardrails():
    fixture = _load_fixture()

    result = compute_property_transmission_scenario(fixture["inputs"])

    _assert_expected_contract(result, fixture["expected"])
    assert result["retirementAffordability"]["rank"] == 1
    assert result["familyEqualization"]["rank"] == 2
    assert result["cantonalTax"]["rank"] == 3
    assert result["modelScope"]["classification"] == "educational_triage"
    assert result["scenarioConfidence"] == "medium"
    assert result["scenarioConfidenceRationale"]["basis"] == "required_inputs_present"
    assert (
        result["scenarioConfidenceRationale"]["axes"]["understanding"]
        == "educational_triage"
    )
    assert result["modelScope"]["notLegalPartition"] is True
    assert result["modelScope"]["requiresSpecialistReview"] is True
    assert any(
        "régime matrimonial" in factor
        for factor in result["modelScope"]["unmodelledLegalFactors"]
    )
    assert "notaire" in " ".join(result["formalities"]).lower()
    assert "registre foncier" in " ".join(result["formalities"]).lower()
    assert "droit d'habitation" in result["retainedRight"]["label"].lower()
    assert result["cantonalTax"]["requiresCantonalReview"] is True
    assert (
        result["scenarioConfidenceRationale"]["axes"]["freshness"]
        == "missing_source_dates"
    )


def test_property_transmission_source_dates_mark_freshness_current():
    fixture = _load_fixture(SOURCE_DATE_FIXTURE)

    result = compute_property_transmission_scenario({
        **fixture["inputs"],
        "_inputProvenance": fixture["input_provenance"],
        "_freshnessAsOf": fixture["freshness_as_of"],
    })

    rationale = result["scenarioConfidenceRationale"]
    assert rationale["axes"]["freshness"] == "current_source_dates"
    assert rationale["sourceDateSummary"]["missingSourceDates"] == []
    assert rationale["sourceDateSummary"]["staleInputs"] == []


def test_property_transmission_source_dates_mark_freshness_stale():
    fixture = _load_fixture(SOURCE_DATE_FIXTURE)
    provenance = deepcopy(fixture["input_provenance"])
    provenance["mortgageBalance"]["source_date"] = "2024-01-01"

    result = compute_property_transmission_scenario({
        **fixture["inputs"],
        "_inputProvenance": provenance,
        "_freshnessAsOf": fixture["freshness_as_of"],
    })

    rationale = result["scenarioConfidenceRationale"]
    assert rationale["axes"]["freshness"] == "stale_source_dates"
    assert "mortgageBalance" in rationale["sourceDateSummary"]["staleInputs"]
    assert result["requiresInputCompletion"] is True
    assert result["scenarioConfidence"] == "low"
    assert result["scenarioConfidenceRationale"]["basis"] == "stale_source_dates"
    assert "mortgageBalance" in result["inputsNeedingReconfirmation"]


def test_property_transmission_missing_canton_stays_unknown_not_vd():
    fixture = _load_fixture()
    inputs = deepcopy(fixture["inputs"])
    inputs.pop("canton")

    result = compute_property_transmission_scenario(inputs)

    assert result["requiresInputCompletion"] is True
    assert result["scenarioConfidence"] == "none"
    assert "canton" in result["missingInputs"]
    assert result["cantonalTax"]["canton"] == "unknown"
    assert result["cantonalTax"]["requiresCantonalReview"] is True


def test_property_transmission_missing_inputs_degrades_before_computing():
    result = compute_property_transmission_scenario({
        "scenarioKey": "missing_inputs_probe",
        "canton": "VD",
    })

    assert result["requiresInputCompletion"] is True
    assert result["scenarioConfidence"] == "none"
    assert result["scenarioConfidenceRationale"]["basis"] == "missing_required_inputs"
    assert result["scenarioConfidenceRationale"]["axes"]["completeness"] == "none"
    assert "propertyMarketValue" in result["missingInputs"]
    assert "parentAnnualRetirementIncome" in result["missingInputs"]
    assert result["retirementAffordability"]["status"] == "missing_data"
    assert result["familyEqualization"]["status"] == "missing_data"
    assert result["computed"]["propertyMarketValue"] == 0


def test_property_transmission_missing_critical_assumptions_are_explicit():
    fixture = _load_fixture()
    inputs = {
        key: value
        for key, value in fixture["inputs"].items()
        if key
        not in {
            "cashPaidByRecipient",
            "mortgageAssumedByRecipient",
            "recipientRelationship",
            "retainedRight",
            "avancementHoirie",
        }
    }

    result = compute_property_transmission_scenario(inputs)

    assert result["requiresInputCompletion"] is True
    assert result["scenarioConfidence"] == "low"
    assert (
        result["scenarioConfidenceRationale"]["basis"]
        == "missing_critical_assumptions"
    )
    for key in (
        "cashPaidByRecipient",
        "mortgageAssumedByRecipient",
        "recipientRelationship",
        "retainedRight",
        "avancementHoirie",
    ):
        assert key in result["missingInputs"]
        assert key in result["missingAssumptions"]
        assert result["assumptions"][key]["status"] == "missing"
        assert result["assumptions"][key]["value"] is None
    assert result["computed"]["cashPaidByRecipient"] is None
    assert result["computed"]["mortgageAssumedByRecipient"] is None
    assert result["retainedRight"]["type"] == "unknown"


def test_property_transmission_warns_when_mortgage_assumption_exceeds_balance():
    fixture = _load_fixture()
    inputs = {
        **fixture["inputs"],
        "mortgageBalance": 420000,
        "mortgageAssumedByRecipient": 430000,
    }

    result = compute_property_transmission_scenario(inputs)

    assert result["scenarioConfidence"] == "low"
    assert any(
        warning["field"] == "mortgageAssumedByRecipient"
        and warning["code"] == "mortgage_assumption_out_of_range"
        for warning in result["validationWarnings"]
    )
    assert (
        result["scenarioConfidenceRationale"]["axes"]["accuracy"]
        == "needs_bank_or_notary_confirmation"
    )


def test_family_equalization_uses_total_need_for_multiple_other_heirs():
    result = compute_property_transmission_scenario({
        "scenarioKey": "three_heirs_probe",
        "canton": "VD",
        "propertyMarketValue": 1000000,
        "mortgageBalance": 0,
        "cashPaidByRecipient": 0,
        "mortgageAssumedByRecipient": 0,
        "parentLiquidAssets": 400000,
        "parentAnnualRetirementIncome": 90000,
        "parentAnnualLivingCosts": 60000,
        "heirsCount": 3,
        "recipientRelationship": "descendant",
        "retainedRight": "none",
        "avancementHoirie": True,
    })

    equalization = result["familyEqualization"]
    assert equalization["immediateEqualizationNeedPerOtherHeir"] == 333333
    assert equalization["immediateEqualizationNeedTotal"] == 666667
    assert equalization["immediateEqualizationGap"] == 266667
    assert equalization["status"] == "at_risk"


def test_missing_heirs_count_requires_completion_not_not_applicable():
    fixture = _load_fixture()
    inputs = deepcopy(fixture["inputs"])
    inputs.pop("heirsCount")

    result = compute_property_transmission_scenario(inputs)

    assert result["requiresInputCompletion"] is True
    assert "heirsCount" in result["missingInputs"]
    assert result["familyEqualization"]["status"] == "missing_data"
    assert result["familyEqualization"]["status"] != "not_applicable"


def test_raiffeisen_property_transmission_text_avoids_banned_terms():
    result = compute_property_transmission_scenario(_load_fixture()["inputs"])
    text = unicodedata.normalize(
        "NFD",
        " ".join(_collect_strings(result)).lower(),
    ).encode("ascii", "ignore").decode("ascii")

    banned_terms = [
        "garanti",
        "optimal",
        "meilleur",
        "sans risque",
        "parfait",
        "assure",
        "certain",
        "conseil financier",
        "recommandation personnalisee",
        "vous devriez",
    ]
    for term in banned_terms:
        assert term not in text


def test_succession_endpoint_computes_property_transmission(client):
    fixture = _load_fixture()
    profile_resp = client.post(
        "/api/v1/profiles",
        json={"householdType": "family", "goal": "retire"},
    )
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "succession",
            "inputs": fixture["inputs"],
            "inputProvenance": fixture["input_provenance"],
            "scenarioId": fixture["scenario_id"],
            "profileOwnerId": fixture["profile_owner_id"],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["inputProvenance"]["propertyMarketValue"]["source"] == "estimated"
    assert data["scenarioId"] == fixture["scenario_id"]
    outputs = data["outputs"]
    assert data["confidenceMode"] == "educational"
    assert data["enhancedConfidence"]["label"] == "à confirmer"
    assert (
        data["enhancedConfidence"]["scenarioConfidence"]
        == outputs["scenarioConfidence"]
    )
    assert (
        data["enhancedConfidence"]["rationale"]
        == outputs["scenarioConfidenceRationale"]
    )
    assert "éducatif" in data["disclaimer"].lower()
    assert "conseil financier" not in data["disclaimer"].lower()
    assert data["sources"]
    assert any("Raiffeisen" in source for source in data["sources"])
    assert any("CC art. 626" in source for source in data["sources"])
    assert all("LPP/LAVS/OPP3" not in source for source in data["sources"])
    assert outputs["scenarioKey"] == fixture["expected"]["scenarioKey"]["value"]
    assert "Scenario type not yet implemented" not in json.dumps(outputs)
    assert (
        outputs["computed"]["economicTransferValue"]
        == fixture["expected"]["computed.economicTransferValue"]["value"]
    )
    assert (
        outputs["retirementAffordability"]["status"]
        == fixture["expected"]["retirementAffordability.status"]["value"]
    )


def test_succession_endpoint_rejects_required_inputs_without_provenance(client):
    fixture = _load_fixture()
    profile_resp = client.post(
        "/api/v1/profiles",
        json={"householdType": "family", "goal": "retire"},
    )
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "succession",
            "inputs": fixture["inputs"],
            "inputProvenance": {
                key: value
                for key, value in fixture["input_provenance"].items()
                if key != "propertyMarketValue"
            },
        },
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "missing_input_provenance"
    assert "propertyMarketValue" in response.json()["detail"]["fields"]


def test_succession_endpoint_rejects_scenario_assumptions_without_provenance(client):
    fixture = _load_fixture()
    profile_resp = client.post(
        "/api/v1/profiles",
        json={"householdType": "family", "goal": "retire"},
    )
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "succession",
            "inputs": fixture["inputs"],
            "inputProvenance": {
                key: value
                for key, value in fixture["input_provenance"].items()
                if key != "retainedRight"
            },
        },
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "missing_input_provenance"
    assert "retainedRight" in response.json()["detail"]["fields"]


def test_succession_endpoint_rejects_malformed_input_provenance(client):
    fixture = _load_fixture()
    profile_resp = client.post(
        "/api/v1/profiles",
        json={"householdType": "family", "goal": "retire"},
    )
    profile_id = profile_resp.json()["id"]
    provenance = deepcopy(fixture["input_provenance"])
    provenance["propertyMarketValue"] = {}
    provenance["mortgageBalance"] = {
        "source": "spreadsheetImport",
        "confidence": "medium",
        "source_date": None,
    }
    provenance["parentLiquidAssets"] = {
        "source": "userInput",
        "source_date": None,
    }
    provenance["parentAnnualLivingCosts"] = {
        "source": "userInput",
        "confidence": "medium",
        "source_date": None,
    }

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "succession",
            "inputs": fixture["inputs"],
            "inputProvenance": provenance,
        },
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "invalid_input_provenance"
    assert "propertyMarketValue" in detail["fields"]["missing_source"]
    assert "mortgageBalance" in detail["fields"]["invalid_source"]
    assert "parentLiquidAssets" in detail["fields"]["missing_confidence"]
    assert "parentAnnualLivingCosts" in detail["fields"]["missing_derived_from"]
