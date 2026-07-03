import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
JSON_REGISTRY = ROOT / "docs/codex/P0_CASE_VARIABLE_REGISTRY.json"
DART_REGISTRY = ROOT / "apps/mobile/lib/services/data_quest/data_quest_service.dart"


def _matching_span(text: str, open_index: int, opener: str, closer: str) -> str:
    depth = 0
    for index in range(open_index, len(text)):
        char = text[index]
        if char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return text[open_index + 1 : index]
    raise AssertionError(f"unclosed {opener}{closer} span")


def _extract_named_call(text: str, marker: str) -> str:
    marker_index = text.index(marker)
    open_index = text.index("(", marker_index)
    return _matching_span(text, open_index, "(", ")")


def _extract_named_list(text: str, label: str) -> str:
    label_index = text.index(f"{label}:")
    open_index = text.index("[", label_index)
    return _matching_span(text, open_index, "[", "]")


def _string_value(text: str, key: str) -> str:
    match = re.search(rf"{key}:\s*'([^']*)'", text)
    assert match, f"missing string value for {key}"
    return match.group(1)


def _bool_present(text: str, key: str) -> bool:
    return re.search(rf"{key}:\s*true\b", text) is not None


def _field_specs(list_body: str) -> list[dict]:
    fields: list[dict] = []
    cursor = 0
    while True:
        try:
            start = list_body.index("DataQuestFieldSpec(", cursor)
        except ValueError:
            break
        open_index = list_body.index("(", start)
        body = _matching_span(list_body, open_index, "(", ")")
        ledger_match = re.search(r"ledgerKey:\s*(null|'([^']*)')", body)
        assert ledger_match, f"missing ledgerKey in field: {body}"
        priority_match = re.search(r"priority:\s*(\d+)", body)
        assert priority_match, f"missing priority in field: {body}"
        fields.append(
            {
                "input_key": _string_value(body, "inputKey"),
                "ledger_key": ledger_match.group(2),
                "question_id": _string_value(body, "questionId"),
                "rank": int(priority_match.group(1)),
            }
        )
        cursor = open_index + len(body) + 2
    return fields


def _dart_cases() -> dict[str, dict]:
    text = DART_REGISTRY.read_text(encoding="utf-8")
    cases: dict[str, dict] = {}
    for case_id in ("first_salary_tax", "buy_property", "transmit_property"):
        body = _extract_named_call(text, f"'{case_id}': DataQuestCaseSpec")
        cases[case_id] = {
            "targetRoute": _string_value(body, "targetRoute"),
            "pdfSectionId": _string_value(body, "pdfSectionId"),
            "maestroFlowId": _string_value(body, "maestroFlowId"),
            "heavyEvent": _bool_present(body, "heavyEvent"),
            "guardFields": _field_specs(_extract_named_list(body, "guardFields")),
            "requiredFields": _field_specs(
                _extract_named_list(body, "requiredFields")
            ),
            "usefulFields": _field_specs(_extract_named_list(body, "usefulFields"))
            if "usefulFields:" in body
            else [],
        }
    return cases


def _json_cases() -> dict:
    return json.loads(JSON_REGISTRY.read_text(encoding="utf-8"))["cases"]


def _json_questions(case: dict, key: str) -> list[dict]:
    return [
        {
            "ledger_key": question.get("ledger_key"),
            "question_id": question["question_id"],
            "rank": question["rank"],
        }
        for question in case[key]
    ]


def _dart_questions(case: dict, key: str) -> list[dict]:
    return [
        {
            "ledger_key": field["ledger_key"],
            "question_id": field["question_id"],
            "rank": field["rank"],
        }
        for field in case[key]
    ]


def test_p0_dart_case_registry_matches_json_contract() -> None:
    json_cases = _json_cases()
    dart_cases = _dart_cases()

    assert set(dart_cases) == {"first_salary_tax", "buy_property", "transmit_property"}
    for case_id, json_case in json_cases.items():
        dart_case = dart_cases[case_id]
        assert dart_case["targetRoute"] == json_case["target_screen"]
        assert dart_case["pdfSectionId"] == json_case["pdf_section_id"]
        assert dart_case["maestroFlowId"] == json_case["maestro_flow_id"]
        assert dart_case["heavyEvent"] is (case_id == "transmit_property")
        assert _dart_questions(dart_case, "guardFields") == _json_questions(
            json_case, "blocking_guard_questions"
        )
        assert _dart_questions(dart_case, "requiredFields") == _json_questions(
            json_case, "required_questions"
        )
        assert _dart_questions(dart_case, "usefulFields") == _json_questions(
            json_case, "enrichment_questions"
        )
