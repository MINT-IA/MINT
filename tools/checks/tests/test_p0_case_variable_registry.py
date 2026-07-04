import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
REGISTRY = ROOT / "docs/codex/P0_CASE_VARIABLE_REGISTRY.json"
FIXTURE_DIR = ROOT / "services/backend/tests/fixtures/scenarios"
PROPERTY_TRANSMISSION_SERVICE = (
    ROOT / "services/backend/app/services/succession_property_transmission.py"
)
REGULATORY_REGISTRY = ROOT / "services/backend/app/services/regulatory/registry.py"
COACH_PROFILE_MODEL = ROOT / "apps/mobile/lib/models/coach_profile.dart"
SUCCESSION_SCREEN = (
    ROOT / "apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart"
)
WIZARD_ANSWERS_ALLOWED_FILES = {
    ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart",
    ROOT / "apps/mobile/lib/services/report_persistence_service.dart",
}


def _ledger_keys() -> set[str]:
    text = DATA_LEDGER.read_text(encoding="utf-8")
    start = text.index("## 3. Ledger")
    end = text.index("## 5.", start)
    section = text[start:end]
    keys: set[str] = set()
    for line in section.splitlines():
        match = re.match(r"\| `([^`]+)` \|", line)
        if match and match.group(1) not in {"key", "key (field path)"}:
            keys.add(match.group(1))
    return keys


def _registry() -> dict:
    return _load_json_no_duplicate_keys(REGISTRY)


def _reject_duplicate_json_keys(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _load_json_no_duplicate_keys(path: Path) -> dict:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_json_keys,
        )
    except ValueError as exc:
        raise AssertionError(
            f"{path.relative_to(ROOT)} contains duplicate or invalid JSON keys: {exc}"
        ) from exc


def test_p0_case_registry_json_has_no_duplicate_keys() -> None:
    _registry()


def _questions(case: dict) -> list[dict]:
    return (
        case["blocking_guard_questions"]
        + case.get("required_questions", [])
        + case["enrichment_questions"]
    )


def test_p0_case_registry_declares_ledger_backing_and_guard_order() -> None:
    ledger = _ledger_keys()
    registry = _registry()
    cases = registry["cases"]
    assert {"first_salary_tax", "buy_property", "transmit_property"} <= set(cases)
    assert "transmit_property" in cases

    for case_id, case in cases.items():
        variables = case["variables"]
        assert variables, f"{case_id} has no variables"
        input_keys = {item["input_key"] for item in variables}
        assert len(input_keys) == len(variables), f"{case_id} duplicates input keys"

        for item in variables:
            role = item["role"]
            if role == "ledger":
                assert item["ledger_key"] in ledger, (
                    f"{case_id}:{item['input_key']} ledger key not in DATA_LEDGER"
                )
                assert item["source_required"] is True
                assert item["confidence_required"] is True
            elif role == "composed_input":
                assert item["ledger_key"] in ledger, (
                    f"{case_id}:{item['input_key']} composed key not in DATA_LEDGER"
                )
                assert item["source_required"] is True
                assert item["confidence_required"] is True
                composition = item.get("composition")
                assert composition, f"{case_id}:{item['input_key']} lacks composition"
                assert composition["formula"]
                assert composition["ledger_source_keys"]
                for source_key in composition["ledger_source_keys"]:
                    assert source_key in ledger, (
                        f"{case_id}:{item['input_key']} source key not in "
                        f"DATA_LEDGER: {source_key}"
                    )
                mobile_sources = composition.get("mobile_runtime_sources") or [
                    composition["mobile_runtime_source"]
                ]
                assert mobile_sources
                for source in mobile_sources:
                    assert source in {
                        "estimated",
                        "userInput",
                        "crossValidated",
                        "certificate",
                        "openBanking",
                    }
                backend_sources = composition.get("backend_fixture_sources") or [
                    composition["backend_fixture_source"]
                ]
                assert backend_sources
                for source in backend_sources:
                    assert source in {
                        "estimated",
                        "userInput",
                        "crossValidated",
                        "certificate",
                        "openBanking",
                    }
                for path_key in (
                    "mobile_contract",
                    "calculator_contract",
                    "test_contract",
                ):
                    contract_path = ROOT / composition[path_key]
                    assert contract_path.exists(), (
                        f"{case_id}:{item['input_key']} missing {path_key}: "
                        f"{contract_path}"
                    )
            elif role == "scenario_assumption":
                assert item["reason"]
                assert item["missing_value_behavior"]
                assert item["source_required"] is True
                assert item["confidence_required"] is True
            elif role == "system":
                assert item["source_required"] is False
                assert item["confidence_required"] is False
            else:
                raise AssertionError(f"{case_id}:{item['input_key']} invalid role {role}")

    transmit = cases["transmit_property"]
    guard_ids = [quest["quest_id"] for quest in transmit["guard_quests"]]
    assert "retirement_affordability_before_gift" in guard_ids
    assert transmit["guard_quests"][0]["must_run_before"] == "gift_result"


def test_mortgage_stress_assumption_is_backed_by_regulatory_registry() -> None:
    stress_items = [
        item
        for case in _registry()["cases"].values()
        for item in case["variables"]
        if item["input_key"] == "stressInterestRate"
    ]
    assert len(stress_items) == 1

    stress_rate = stress_items[0]
    assert stress_rate["role"] == "scenario_assumption"
    assert stress_rate["regulatory_source_key"] == "mortgage.theoretical_rate"
    assert stress_rate["regulatory_source_category"] == "mortgage"
    assert stress_rate["regulatory_source_registry"] == (
        "services/backend/app/services/regulatory/registry.py"
    )
    assert stress_rate["unit"] == "ratio"
    assert stress_rate["effective_from"] == "2025-01-01"

    registry_text = REGULATORY_REGISTRY.read_text(encoding="utf-8")
    assert f'key="{stress_rate["regulatory_source_key"]}"' in registry_text
    assert "value=0.05" in registry_text


def test_p0_case_acceptance_statuses_prevent_declared_cases_being_treated_as_done() -> None:
    cases = _registry()["cases"]

    assert cases["transmit_property"]["acceptance_status"] == "phase1_runtime_accepted"
    assert cases["first_salary_tax"]["acceptance_status"] == "phase1_runtime_accepted"
    assert cases["buy_property"]["acceptance_status"] == "phase1_runtime_accepted"

    for case_id, case in cases.items():
        assert case["acceptance_status"] in {
            "declared_not_accepted",
            "phase2_planner_accepted",
            "phase1_runtime_accepted",
        }, f"{case_id} has unsupported acceptance_status"


def test_phase2_cases_declare_data_quest_and_dossier_contracts() -> None:
    ledger = _ledger_keys()
    cases = _registry()["cases"]

    for case_id, case in cases.items():
        assert case["target_screen"] == case["route"]
        assert case["pdf_section_id"].startswith("dossier_")
        contract_path = ROOT / case["dossier_contract"]
        assert contract_path.exists(), (
            f"{case_id} missing dossier contract: {contract_path}"
        )
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
        assert contract["x-mint-owner"] == "mint-lucidity-pdf"
        assert contract["x-mint-case-id"] == case_id
        assert contract["x-mint-pdf-section-id"] == case["pdf_section_id"]
        assert contract["properties"]["case_id"]["const"] == case_id
        assert (
            contract["properties"]["pdf_section_id"]["const"]
            == case["pdf_section_id"]
        )
        for required_payload_key in (
            "inputs",
            "outputs",
            "assumptions",
            "warnings",
            "next_questions",
        ):
            assert required_payload_key in contract["required"]
        assert case["maestro_flow_id"]
        assert case["minimum_variables"], f"{case_id} has no minimum variables"
        assert "useful_variables" in case
        assert case["blocking_guard_questions"], (
            f"{case_id} has no blocking guard questions"
        )
        assert case.get("runtime_input_gate"), f"{case_id} lacks runtime_input_gate"
        assert case.get("runtime_proof_kind"), f"{case_id} lacks runtime_proof_kind"
        assert "required_questions" in case
        assert "enrichment_questions" in case

        declared_inputs = {item["input_key"] for item in case["variables"]}
        declared_ledgers = {
            item["ledger_key"]
            for item in case["variables"]
            if item.get("ledger_key") is not None
        }
        declared_refs = declared_inputs | declared_ledgers
        missing_minimum = set(case["minimum_variables"]) - declared_refs
        missing_useful = set(case["useful_variables"]) - declared_refs
        assert not missing_minimum, (
            f"{case_id} minimum variables not declared: {sorted(missing_minimum)}"
        )
        assert not missing_useful, (
            f"{case_id} useful variables not declared: {sorted(missing_useful)}"
        )

        question_ids = set()
        ranks = []
        for question in _questions(case):
            question_ids.add(question["question_id"])
            ranks.append(question["rank"])
            assert question["ask_mode"] in {
                "collect",
                "collect_or_reconfirm",
                "scenario_assumption",
            }
            ledger_key = question.get("ledger_key")
            input_key = question.get("input_key")
            if ledger_key is not None:
                assert ledger_key in ledger or ledger_key in declared_ledgers, (
                    f"{case_id}:{question['question_id']} bad ledger "
                    f"{ledger_key}"
                )
            else:
                assert input_key in declared_inputs, (
                    f"{case_id}:{question['question_id']} lacks input_key"
                )
        assert len(question_ids) == len(_questions(case)), (
            f"{case_id} duplicates question ids"
        )
        assert ranks == sorted(ranks, reverse=True), (
            f"{case_id} question ranks must be descending"
        )


def test_scenario_assumptions_require_dossier_source_and_confidence() -> None:
    for case_id, case in _registry()["cases"].items():
        scenario_inputs = [
            item["input_key"]
            for item in case["variables"]
            if item["role"] == "scenario_assumption"
        ]
        if not scenario_inputs:
            continue

        contract_path = ROOT / case["dossier_contract"]
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
        assumptions = contract["properties"]["assumptions"]
        required = set(assumptions["items"].get("required", []))
        assert {
            "input_key",
            "value",
            "source",
            "confidence",
            "source_required",
            "confidence_required",
        } <= required, f"{case_id} dossier assumptions lack provenance contract"
        input_key_schema = assumptions["items"]["properties"]["input_key"]
        assert set(scenario_inputs) <= set(input_key_schema["enum"]), (
            f"{case_id} dossier assumptions miss scenario inputs: "
            f"{sorted(set(scenario_inputs) - set(input_key_schema['enum']))}"
        )


def test_data_quest_single_write_path_for_wizard_answers_v2() -> None:
    offenders: list[str] = []
    for path in (ROOT / "apps/mobile/lib").rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        if "wizard_answers_v2" not in text:
            continue
        if path in WIZARD_ANSWERS_ALLOWED_FILES:
            continue
        offenders.append(str(path.relative_to(ROOT)))

    assert not offenders, (
        "wizard_answers_v2 must be owned by CoachProfileProvider/"
        f"ReportPersistenceService only: {offenders}"
    )


def test_mobile_data_quest_service_mirrors_p0_case_registry() -> None:
    service_text = (
        ROOT / "apps/mobile/lib/services/data_quest/data_quest_service.dart"
    ).read_text(encoding="utf-8")

    for case_id, case in _registry()["cases"].items():
        case_start = service_text.index(f"caseId: '{case_id}'")
        next_case = service_text.find("caseId: '", case_start + 1)
        service_case = (
            service_text[case_start:next_case]
            if next_case != -1
            else service_text[case_start:]
        )
        guard_start = service_case.index("guardFields: [")
        required_start = service_case.index("requiredFields: [")
        useful_start = service_case.find("usefulFields: [")
        guard_section = service_case[guard_start:required_start]
        required_section = (
            service_case[required_start:useful_start]
            if useful_start != -1
            else service_case[required_start:]
        )
        useful_section = (
            service_case[useful_start:] if useful_start != -1 else ""
        )

        assert f"'{case_id}'" in service_text
        assert f"targetRoute: '{case['target_screen']}'" in service_text
        assert f"pdfSectionId: '{case['pdf_section_id']}'" in service_text
        assert f"maestroFlowId: '{case['maestro_flow_id']}'" in service_text
        assert f"runtimeProofId: '{case['runtime_input_gate']}'" in service_text
        tiered_questions = (
            ("guard", guard_section, case["blocking_guard_questions"]),
            ("required", required_section, case.get("required_questions", [])),
            ("useful", useful_section, case["enrichment_questions"]),
        )
        for tier_name, tier_section, questions in tiered_questions:
            if questions:
                assert tier_section, f"{case_id}:{tier_name} section missing"
            for question in questions:
                _assert_question_in_dart_section(
                    case_id=case_id,
                    case=case,
                    question=question,
                    service_text=service_text,
                    tier_name=tier_name,
                    tier_section=tier_section,
                )


def _assert_question_in_dart_section(
    *,
    case_id: str,
    case: dict,
    question: dict,
    service_text: str,
    tier_name: str,
    tier_section: str,
) -> None:
    input_key = question.get("input_key") or next(
        item["input_key"]
        for item in case["variables"]
        if item.get("ledger_key") == question.get("ledger_key")
    )
    ledger_key = question.get("ledger_key")
    ledger_fragment = "null" if ledger_key is None else f"'{re.escape(ledger_key)}'"
    field_pattern = (
        r"DataQuestFieldSpec\(\s*"
        rf"inputKey: '{re.escape(input_key)}',\s*"
        rf"ledgerKey: {ledger_fragment},\s*"
        r".*?"
        rf"questionId: '{re.escape(question['question_id'])}',\s*"
        rf"priority: {question['rank']}"
    )
    if ledger_key is not None:
        assert re.search(field_pattern, tier_section, re.S), (
            f"{case_id}:{question['question_id']} missing Dart "
            f"{tier_name} ledgerKey/rank {ledger_key}/{question['rank']}"
        )
    else:
        assert re.search(field_pattern, tier_section, re.S), (
            f"{case_id}:{question['question_id']} missing Dart "
            f"{tier_name} scenario assumption {input_key}/{question['rank']}"
        )
        assert "DataQuestAskMode.scenarioAssumption" in tier_section
    assert f"questionId: '{question['question_id']}'" in service_text, (
        f"{case_id}:{question['question_id']} missing Dart questionId"
    )


def test_runtime_accepted_cases_have_declared_runtime_flow_files() -> None:
    for case_id, case in _registry()["cases"].items():
        flow_id = case["maestro_flow_id"]
        patrol_flow_id = case.get("patrol_flow_id")
        if patrol_flow_id:
            patrol_path = ROOT / "apps/mobile/test/patrol" / f"{patrol_flow_id}.dart"
            assert patrol_path.exists(), (
                f"{case_id} runtime Patrol flow missing: {patrol_path}"
            )

        if flow_id == "pending":
            assert patrol_flow_id, (
                f"{case_id} pending maestro_flow_id requires patrol_flow_id "
                "before runtime acceptance"
            )
            pending_flow_candidates = [
                ROOT / "apps/mobile/.maestro" / f"{case_id}.yaml",
                ROOT / "apps/mobile/.maestro" / f"phase2_{case_id}.yaml",
                ROOT
                / "apps/mobile/.maestro"
                / f"phase2_data_quest_{case_id}.yaml",
            ]
            stale_files = [
                str(path.relative_to(ROOT))
                for path in pending_flow_candidates
                if path.exists()
            ]
            assert not stale_files, (
                f"{case_id} has pending maestro_flow_id but flow files exist: "
                f"{stale_files}"
            )
            continue

        flow_path = ROOT / "apps/mobile/.maestro" / f"{flow_id}.yaml"
        assert flow_path.exists(), (
            f"{case_id} status {case['acceptance_status']} requires "
            f"Maestro flow file: {flow_path}"
        )

        if case["acceptance_status"] == "phase1_runtime_accepted":
            assert patrol_flow_id or flow_id != "pending", (
                f"{case_id} runtime accepted without Patrol or Maestro proof"
            )


def test_p0_fixture_inputs_are_declared_in_case_registry() -> None:
    registry = _registry()["cases"]

    for path in sorted(FIXTURE_DIR.glob("*.json")):
        fixture = json.loads(path.read_text(encoding="utf-8"))
        case = registry[fixture["case_id"]]
        declared_inputs = {item["input_key"] for item in case["variables"]}
        undeclared = set(fixture["inputs"]) - declared_inputs
        assert not undeclared, f"{path.name} undeclared inputs: {sorted(undeclared)}"


def test_transmit_property_declares_mobile_calculator_and_fixture_authority() -> None:
    transmit = _registry()["cases"]["transmit_property"]
    calculator = ROOT / transmit["mobile_runtime_calculator"]
    fixture = ROOT / transmit["backend_fixture_authority"]

    assert calculator.exists(), f"missing mobile calculator: {calculator}"
    assert fixture.exists(), f"missing backend fixture: {fixture}"
    calculator_text = calculator.read_text(encoding="utf-8")
    assert "PropertyTransmissionCalculator" in calculator_text
    assert "retirementAffordability" in calculator_text
    assert "familyEqualization" in calculator_text


def test_transmit_property_retirement_income_composition_is_mechanically_declared() -> None:
    transmit = _registry()["cases"]["transmit_property"]
    income_item = next(
        item
        for item in transmit["variables"]
        if item["input_key"] == "parentAnnualRetirementIncome"
    )

    assert income_item["role"] == "composed_input"
    composition = income_item["composition"]
    assert composition["ledger_source_keys"] == [
        "prevoyance.renteAVSEstimeeMensuelle",
        "prevoyance.projectedRenteLpp",
    ]
    assert (
        composition["formula"]
        == "(prevoyance.renteAVSEstimeeMensuelle * 12) + prevoyance.projectedRenteLpp"
    )

    screen_text = (ROOT / composition["mobile_contract"]).read_text(encoding="utf-8")
    calculator_text = (ROOT / composition["calculator_contract"]).read_text(
        encoding="utf-8"
    )
    test_text = (ROOT / composition["test_contract"]).read_text(encoding="utf-8")

    assert "renteAVSEstimeeMensuelle" in screen_text
    assert "projectedRenteLpp" in screen_text
    assert "parentAnnualRetirementIncomeSourceKeys" in screen_text
    assert "ProfileDataSource.estimated.name" in screen_text
    assert "_composedInputs" in calculator_text
    assert "required_inputs_present_with_estimated_composition" in calculator_text
    assert "preserves estimated retirement-income provenance" in test_text
    assert (
        "parentAnnualRetirementIncome:prevoyance.renteAVSEstimeeMensuelle+"
        "prevoyance.projectedRenteLpp"
    ) in test_text


def test_transmit_property_living_costs_composition_is_mechanically_declared() -> None:
    transmit = _registry()["cases"]["transmit_property"]
    living_costs_item = next(
        item
        for item in transmit["variables"]
        if item["input_key"] == "parentAnnualLivingCosts"
    )

    assert living_costs_item["role"] == "composed_input"
    composition = living_costs_item["composition"]
    assert (
        composition["formula"]
        == "explicit parentAnnualLivingCosts OR sum(monthly living-cost components) * 12"
    )
    assert composition["mobile_runtime_sources"] == ["userInput", "openBanking"]
    assert composition["backend_fixture_sources"] == ["userInput", "openBanking"]

    screen_text = (ROOT / composition["mobile_contract"]).read_text(encoding="utf-8")
    test_text = (ROOT / composition["test_contract"]).read_text(encoding="utf-8")

    assert "DossierPayloadService.dataQuestFactsFromProfile" in screen_text
    assert "parentAnnualLivingCosts" in screen_text
    assert "does not double-count other fixed costs" in test_text
    assert "keeps period housing cost untrusted" in test_text


def test_property_transmission_service_reads_only_declared_inputs() -> None:
    text = PROPERTY_TRANSMISSION_SERVICE.read_text(encoding="utf-8")
    read_keys = set(re.findall(r"inputs\.get\(\"([^\"]+)\"", text))
    read_keys.update(re.findall(r"_num\(inputs,\s*\"([^\"]+)\"", text))
    read_keys.update(re.findall(r"_int\(inputs,\s*\"([^\"]+)\"", text))

    declared = {
        item["input_key"]
        for item in _registry()["cases"]["transmit_property"]["variables"]
    }
    public_read_keys = {key for key in read_keys if not key.startswith("_")}
    undeclared = public_read_keys - declared
    assert not undeclared, f"service reads undeclared inputs: {sorted(undeclared)}"


def test_guard_ledger_keys_resolve_to_mobile_fields() -> None:
    mobile_text = (
        COACH_PROFILE_MODEL.read_text(encoding="utf-8")
        + "\n"
        + SUCCESSION_SCREEN.read_text(encoding="utf-8")
    )

    for case_id, case in _registry()["cases"].items():
        for quest in case["guard_quests"]:
            required = set(quest["required_ledger_keys"])
            mapping = quest.get("mobile_field_paths")
            assert mapping, f"{case_id}:{quest['quest_id']} lacks mobile_field_paths"
            assert set(mapping) == required, (
                f"{case_id}:{quest['quest_id']} mobile mapping drift: "
                f"{sorted(set(mapping) ^ required)}"
            )
            for ledger_key, field_path in mapping.items():
                assert field_path in mobile_text, (
                    f"{case_id}:{quest['quest_id']} {ledger_key} -> "
                    f"{field_path} not found in mobile model/screen"
                )
