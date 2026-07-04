import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FIXTURE_DIR = ROOT / "services/backend/tests/fixtures/scenarios"
REGISTRY = ROOT / "docs/codex/P0_CASE_VARIABLE_REGISTRY.json"
REQUIRED_TOP_LEVEL = {
    "fixture_id",
    "case_id",
    "profile_owner_id",
    "scenario_id",
    "inputs",
    "input_provenance",
    "expected",
    "authority",
    "stack_paths",
}


def _fixtures() -> list[Path]:
    return sorted(FIXTURE_DIR.glob("*.json"))


def _registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def test_every_scenario_fixture_uses_cross_stack_schema() -> None:
    fixtures = _fixtures()
    assert fixtures, "no scenario fixtures found"
    registry = _registry()["cases"]

    for path in fixtures:
        fixture = json.loads(path.read_text(encoding="utf-8"))
        case = registry[fixture["case_id"]]
        missing = REQUIRED_TOP_LEVEL - set(fixture)
        assert not missing, f"{path.name} missing top-level keys: {sorted(missing)}"

        assert fixture["fixture_id"].startswith(f"p0_{fixture['case_id']}_")
        assert fixture["profile_owner_id"]
        assert fixture["scenario_id"]
        assert isinstance(fixture["inputs"], dict) and fixture["inputs"]

        provenance = fixture["input_provenance"]
        assert set(provenance) == set(fixture["inputs"])
        for input_key, meta in provenance.items():
            assert meta["source"] in {
                "system",
                "estimated",
                "userInput",
                "crossValidated",
                "certificate",
                "openBanking",
            }, f"{path.name}:{input_key} has invalid source"
            assert meta["confidence"] in {"none", "low", "medium", "high"}

        expected = fixture["expected"]
        assert isinstance(expected, dict) and expected
        for output_path, contract in expected.items():
            assert output_path, f"{path.name} has empty expected output path"
            assert isinstance(contract, dict), f"{path.name}:{output_path} must be an object"
            for key in ("value", "unit", "tolerance"):
                assert key in contract, f"{path.name}:{output_path} missing {key}"

        authority = fixture["authority"]
        assert authority["agent"] == "mint-swiss-brain"
        assert authority["source_refs"], f"{path.name} lacks source refs"
        assert (
            authority["calculation_notes"][
                "familyEqualization.immediateEqualizationNeedPerOtherHeir"
            ]
            .lower()
            .startswith("phase 1 api-compatible name")
        ), f"{path.name} lacks equalization label guardrail"
        for ref in authority["source_refs"]:
            assert (ROOT / ref).exists(), f"{path.name} source ref does not exist: {ref}"

        stack_paths = fixture["stack_paths"]
        assert stack_paths, f"{path.name} lacks stack paths"
        for stack_name, rel_path in stack_paths.items():
            assert stack_name
            assert (ROOT / rel_path).exists(), (
                f"{path.name} stack path does not exist: {rel_path}"
            )

        composed_inputs = {
            item["input_key"]: item
            for item in case["variables"]
            if item["role"] == "composed_input"
        }
        for input_key, item in composed_inputs.items():
            if input_key not in fixture["inputs"]:
                continue
            composition = item["composition"]
            meta = provenance[input_key]
            accepted_sources = composition.get("backend_fixture_sources") or [
                composition["backend_fixture_source"]
            ]
            assert meta["source"] in accepted_sources, (
                f"{path.name}:{input_key} source must match registry composition"
            )
            assert meta.get("derived_from") == composition["ledger_source_keys"], (
                f"{path.name}:{input_key} must declare derived_from source keys"
            )
            assert meta.get("formula") == composition["formula"], (
                f"{path.name}:{input_key} must declare composition formula"
            )
