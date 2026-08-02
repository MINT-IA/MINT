from __future__ import annotations

import copy
import importlib.util
import json
import os
import socket
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
VERIFIER_PATH = REPO / "tools/checks/mint_next_batch4_model_review_content_verifier.py"
SCHEMA_PATH = REPO / "product/mint_next/batch4/evidence/model-review-content.schema.json"
RESULT_SCHEMA_PATH = REPO / "product/mint_next/batch4/evidence/review-result.schema.json"
RESULT_VERIFIER_PATH = REPO / "tools/checks/mint_next_batch4_review_result_verifier.py"
SPEC = importlib.util.spec_from_file_location("model_review_content_verifier", VERIFIER_PATH)
assert SPEC and SPEC.loader
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


def content() -> dict:
    return {
        "dimension_results": [
            {
                "dimension_id": dimension,
                "status": "pass",
                "evidence_refs": [{
                    "input_index": 0,
                    "path": "product/mint_next/batch4/batch.yaml",
                    "locator": "$.status",
                }],
                "reasoning": "Synthetic model content; not review evidence.",
            }
            for dimension in verifier.DIMENSION_IDS
        ],
        "findings": [{
            "id": "P3-001",
            "severity": "P3",
            "title": "Synthetic bounded improvement",
            "path": "product/mint_next/batch4/batch.yaml",
            "locator": "$.status",
            "evidence": "Synthetic evidence text.",
            "reproduction": "Inspect the synthetic fixture only.",
            "impact": "No product impact; fixture only.",
            "required_remediation": "None; structural fixture.",
        }],
        "limitations": [
            {"code": code, "blocking": False, "detail": "Required non-evidence boundary."}
            for code in verifier.MANDATORY_MODEL_LIMITATION_CODES
        ],
    }


def raw(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def rejected(value: dict, needle: str) -> None:
    assert any(needle in error for error in verifier.verify_bytes(raw(value)))


def test_exact_content_is_structurally_valid_non_evidence() -> None:
    assert verifier.verify_bytes(raw(content())) == []


def test_schema_is_exact_projection_of_full_result_content() -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    result = json.loads(RESULT_SCHEMA_PATH.read_text())
    assert schema["required"] == ["dimension_results", "findings", "limitations"]
    assert list(schema["properties"]) == schema["required"]
    for field in ("dimension_results", "findings"):
        assert schema["properties"][field] == result["properties"][field]
    model_limitation = schema["properties"]["limitations"]
    result_limitation = result["properties"]["limitations"]
    assert {
        key: value for key, value in model_limitation.items() if key != "items"
    } == {
        key: value for key, value in result_limitation.items() if key != "items"
    }
    model_item = copy.deepcopy(model_limitation["items"])
    result_item = copy.deepcopy(result_limitation["items"])
    model_codes = model_item["properties"]["code"].pop("enum")
    result_codes = result_item["properties"]["code"].pop("enum")
    assert model_item == result_item
    assert model_codes == verifier.MODEL_LIMITATION_CODES
    assert result_codes == verifier.MODEL_LIMITATION_CODES[:1] + (
        verifier.RUNNER_ONLY_LIMITATION_CODES + verifier.MANDATORY_MODEL_LIMITATION_CODES
    )
    assert set(model_codes).isdisjoint(verifier.RUNNER_ONLY_LIMITATION_CODES)


@pytest.mark.parametrize(
    "runner_field",
    [
        "schema_version", "kind", "reviewed_candidate_head",
        "provider_family_claimed", "model_identifier_claimed", "executed_at_utc",
        "trust_scope", "verdict",
    ],
)
def test_rejects_every_runner_owned_top_level_field(runner_field: str) -> None:
    value = content()
    value[runner_field] = "model-authored"
    rejected(value, "unexpected key")


@pytest.mark.parametrize("code", [
    "tool_or_transport_error", "retry_or_fallback_used", "response_truncated",
    "undeclared_tool_or_network_access", "schema_or_hash_mismatch",
])
def test_rejects_every_runner_only_limitation(code: str) -> None:
    value = content()
    value["limitations"].append({"code": code, "blocking": True, "detail": "forbidden"})
    rejected(value, "runner-only limitation")


@pytest.mark.parametrize("code", [
    "candidate_binding_unverified", "evidence_refs_unresolved", "provider_identity_unverified",
])
def test_requires_each_mandatory_non_evidence_limitation(code: str) -> None:
    value = content()
    value["limitations"] = [item for item in value["limitations"] if item["code"] != code]
    rejected(value, "mandatory model limitation missing")


def test_incomplete_context_is_optional_blocking_and_enum_ordered() -> None:
    value = content()
    value["limitations"].insert(0, {
        "code": "incomplete_input_or_context",
        "blocking": True,
        "detail": "Synthetic missing context.",
    })
    assert verifier.verify_bytes(raw(value)) == []
    value["limitations"][0]["blocking"] = False
    rejected(value, "blocking must match")


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (lambda d: d["dimension_results"].pop(), "exact ordered dimension ids"),
        (lambda d: d["dimension_results"].reverse(), "exact ordered dimension ids"),
        (lambda d: d["dimension_results"][0].__setitem__("status", "unknown"), "status"),
        (lambda d: d["dimension_results"][0].__setitem__("evidence_refs", []), "evidence_refs"),
        (lambda d: d["dimension_results"][0]["evidence_refs"][0].__setitem__("path", "../x"), "relative repository path"),
        (lambda d: d["findings"].append(copy.deepcopy(d["findings"][0])), "finding ids"),
        (lambda d: d["findings"][0].__setitem__("severity", "P1"), "prefix must match"),
        (lambda d: d["limitations"].append(copy.deepcopy(d["limitations"][0])), "limitation codes must be unique"),
        (lambda d: d["limitations"].reverse(), "schema enum order"),
    ],
)
def test_rejects_shared_semantic_mutations(mutation, needle: str) -> None:
    value = content()
    mutation(value)
    rejected(value, needle)


@pytest.mark.parametrize("bad", [
    b'{"dimension_results":[],"dimension_results":[],"findings":[],"limitations":[]}',
    b'{"dimension_results":NaN,"findings":[],"limitations":[]}',
    b"\xef\xbb\xbf{}",
    b"{} trailing",
])
def test_rejects_strict_json_failures(bad: bytes) -> None:
    assert verifier.verify_bytes(bad)


def test_rejects_float_and_unsafe_integer_anywhere() -> None:
    value = content()
    value["dimension_results"][0]["evidence_refs"][0]["input_index"] = 1.0
    rejected(value, "floating-point")
    value = content()
    value["dimension_results"][0]["evidence_refs"][0]["input_index"] = 2**53
    rejected(value, "safe integer")


def test_differential_projection_is_accepted_by_pinned_full_verifier() -> None:
    full_raw, errors = verifier.synthetic_full_result_bytes(raw(content()))
    assert errors == []
    assert full_raw is not None
    assert verifier.verify_with_pinned_full_result(full_raw) == []


def test_verifier_has_no_network_or_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:
    def denied(*_args, **_kwargs):
        raise AssertionError("external capability attempted")
    monkeypatch.setattr(socket, "create_connection", denied)
    monkeypatch.setattr(subprocess, "run", denied)
    assert verifier.verify_bytes(raw(content())) == []


def test_rejects_pinned_schema_drift_and_symlink(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    drift = tmp_path / "schema.json"
    drift.write_bytes(SCHEMA_PATH.read_bytes() + b"\n")
    monkeypatch.setattr(verifier, "SCHEMA_PATH", drift)
    assert any("schema" in error and "hash" in error for error in verifier.verify_bytes(raw(content())))
    target = tmp_path / "target.json"
    target.write_bytes(SCHEMA_PATH.read_bytes())
    link = tmp_path / "schema-link.json"
    link.symlink_to(target)
    monkeypatch.setattr(verifier, "SCHEMA_PATH", link)
    assert any("schema" in error for error in verifier.verify_bytes(raw(content())))


def test_rejects_pinned_full_verifier_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    drift = tmp_path / "full-verifier.py"
    drift.write_bytes(RESULT_VERIFIER_PATH.read_bytes() + b"\n")
    monkeypatch.setattr(verifier, "FULL_VERIFIER_PATH", drift)
    with pytest.raises(ValueError, match="hash mismatch"):
        verifier._load_full_verifier()


def test_cli_rejects_symlink_fifo_and_oversize(tmp_path: Path) -> None:
    source = tmp_path / "content.json"
    source.write_bytes(raw(content()))
    link = tmp_path / "link.json"
    link.symlink_to(source)
    fifo = tmp_path / "fifo"
    os.mkfifo(fifo)
    oversized = tmp_path / "oversized.json"
    oversized.write_bytes(b"x" * (verifier.MAX_BYTES + 1))
    for path in (link, fifo, oversized):
        result = subprocess.run(
            [sys.executable, str(VERIFIER_PATH), str(path)],
            text=True, capture_output=True, timeout=5,
        )
        assert result.returncode != 0
        assert "STRUCTURALLY_VALID_MODEL_CONTENT_NON_EVIDENCE" not in result.stdout


def test_cli_success_wording_only(tmp_path: Path) -> None:
    path = tmp_path / "content.json"
    path.write_bytes(raw(content()))
    result = subprocess.run(
        [sys.executable, str(VERIFIER_PATH), str(path)], text=True, capture_output=True
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "STRUCTURALLY_VALID_MODEL_CONTENT_NON_EVIDENCE"
    assert result.stderr == ""
