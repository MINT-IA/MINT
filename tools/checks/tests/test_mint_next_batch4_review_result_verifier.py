from __future__ import annotations

import copy
import importlib.util
import json
import socket
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
VERIFIER_PATH = REPO / "tools/checks/mint_next_batch4_review_result_verifier.py"
SCHEMA_PATH = REPO / "product/mint_next/batch4/evidence/review-result.schema.json"
SPEC = importlib.util.spec_from_file_location("review_result_verifier", VERIFIER_PATH)
assert SPEC and SPEC.loader
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


DIMENSIONS = [
    "information_architecture_closure",
    "beginner_comprehension_hypotheses",
    "swiss_life_coverage",
    "formula_and_source_boundaries",
    "regulatory_boundaries",
    "legacy_reuse_and_preservation",
    "trust_and_promotion_integrity",
]
MANDATORY_LIMITATIONS = [
    "candidate_binding_unverified",
    "evidence_refs_unresolved",
    "provider_identity_unverified",
]


def payload() -> dict:
    return {
        "schema_version": 1,
        "kind": "mint_next_batch4_cross_provider_review_result",
        "reviewed_candidate_head": "a" * 40,
        "provider_family_claimed": "synthetic-provider-family",
        "model_identifier_claimed": "synthetic-model",
        "executed_at_utc": "2026-08-02T12:00:00Z",
        "trust_scope": "payload_shape_and_semantics_only_non_evidence",
        "verdict": "pass_no_p1_p2",
        "dimension_results": [
            {
                "dimension_id": dimension,
                "status": "pass",
                "evidence_refs": [
                    {
                        "input_index": 0,
                        "path": "product/mint_next/batch4/batch.yaml",
                        "locator": "$.status",
                    }
                ],
                "reasoning": "Synthetic structural fixture; not review evidence.",
            }
            for dimension in DIMENSIONS
        ],
        "findings": [
            {
                "id": "P3-001",
                "severity": "P3",
                "title": "Synthetic bounded improvement",
                "path": "product/mint_next/batch4/batch.yaml",
                "locator": "$.status",
                "evidence": "Synthetic evidence text.",
                "reproduction": "Inspect the synthetic fixture only.",
                "impact": "No product impact; fixture only.",
                "required_remediation": "None; structural test fixture.",
            }
        ],
        "limitations": [
            {"code": code, "blocking": False, "detail": "Required non-evidence boundary."}
            for code in MANDATORY_LIMITATIONS
        ],
    }


def raw(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def assert_rejected(value: dict, needle: str) -> None:
    assert any(needle in error for error in verifier.verify_bytes(raw(value)))


def test_exact_synthetic_payload_is_structurally_valid_non_evidence() -> None:
    assert verifier.verify_bytes(raw(payload())) == []


def test_valid_fail_variants() -> None:
    unverified = payload()
    unverified["dimension_results"][0]["status"] = "unverified"
    unverified["verdict"] = "fail_findings_present"
    assert verifier.verify_bytes(raw(unverified)) == []

    p1 = payload()
    p1["findings"][0]["severity"] = "P1"
    p1["findings"][0]["id"] = "P1-001"
    p1["verdict"] = "fail_findings_present"
    assert verifier.verify_bytes(raw(p1)) == []


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (lambda d: d.__setitem__("extra", True), "unexpected key"),
        (lambda d: d.pop("kind"), "missing key"),
        (lambda d: d.__setitem__("schema_version", True), "schema_version"),
        (lambda d: d.__setitem__("schema_version", 2), "schema_version"),
        (lambda d: d.__setitem__("kind", "review"), "kind"),
        (lambda d: d.__setitem__("reviewed_candidate_head", "A" * 40), "candidate head"),
        (lambda d: d.__setitem__("executed_at_utc", "2026-08-02 12:00:00"), "timestamp"),
        (lambda d: d.__setitem__("trust_scope", "review_evidence"), "trust_scope"),
        (lambda d: d.__setitem__("provider_family_claimed", ""), "provider_family_claimed"),
        (lambda d: d.__setitem__("model_identifier_claimed", 3), "model_identifier_claimed"),
        (lambda d: d.__setitem__("limitations", []), "mandatory non-evidence limitation"),
    ],
)
def test_rejects_top_level_contract_mutations(mutation, needle: str) -> None:
    value = payload()
    mutation(value)
    assert_rejected(value, needle)


@pytest.mark.parametrize("key", sorted(verifier.TOP_LEVEL_KEYS))
def test_rejects_every_missing_top_level_key(key: str) -> None:
    value = payload()
    value.pop(key)
    assert_rejected(value, "missing key")


@pytest.mark.parametrize(
    ("key", "wrong"),
    [
        ("verdict", {}),
        ("dimension_results", {}),
        ("findings", {}),
        ("limitations", {}),
    ],
)
def test_rejects_top_level_container_type_confusion(key: str, wrong) -> None:
    value = payload()
    value[key] = wrong
    assert verifier.verify_bytes(raw(value))


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (lambda d: d["dimension_results"].pop(), "exact ordered dimension ids"),
        (lambda d: d["dimension_results"].reverse(), "exact ordered dimension ids"),
        (
            lambda d: d["dimension_results"][1].__setitem__(
                "dimension_id", d["dimension_results"][0]["dimension_id"]
            ),
            "exact ordered dimension ids",
        ),
        (lambda d: d["dimension_results"][0].__setitem__("status", "unknown"), "status"),
        (lambda d: d["dimension_results"][0].__setitem__("extra", 1), "unexpected key"),
        (lambda d: d["dimension_results"][0].__setitem__("evidence_refs", []), "evidence_refs"),
        (
            lambda d: d["dimension_results"][0]["evidence_refs"][0].__setitem__(
                "path", "../secret"
            ),
            "relative repository path",
        ),
        (
            lambda d: d["dimension_results"][0]["evidence_refs"][0].__setitem__(
                "path", "product//batch.yaml"
            ),
            "relative repository path",
        ),
    ],
)
def test_rejects_dimension_and_reference_mutations(mutation, needle: str) -> None:
    value = payload()
    mutation(value)
    assert_rejected(value, needle)


@pytest.mark.parametrize(
    "unsafe",
    [
        ".", "..", "./a", "../a", "a//b", "a/", "a/./b", "a/../b",
        "foo:bar", "foo bar", "foo\nbar", "é.yaml", "/absolute", r"a\b",
    ],
)
def test_schema_and_verifier_reject_same_unsafe_path_characters(unsafe: str) -> None:
    value = payload()
    value["dimension_results"][0]["evidence_refs"][0]["path"] = unsafe
    assert_rejected(value, "relative repository path")


@pytest.mark.parametrize(
    "safe", ["a", "a-b_c.1", ".planning/ACTIVE_CONTEXT.md", "product/batch.yaml"]
)
def test_schema_and_verifier_accept_same_canonical_path_characters(safe: str) -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    schema_pattern = schema["properties"]["dimension_results"]["items"][
        "properties"
    ]["evidence_refs"]["items"]["properties"]["path"]["pattern"]
    assert schema_pattern == verifier.SAFE_PATH_PATTERN
    assert schema["properties"]["findings"]["items"]["properties"]["path"][
        "pattern"
    ] == verifier.SAFE_PATH_PATTERN
    value = payload()
    value["dimension_results"][0]["evidence_refs"][0]["path"] = safe
    assert verifier.verify_bytes(raw(value)) == []


@pytest.mark.parametrize("key", sorted(verifier.DIMENSION_KEYS))
def test_rejects_every_missing_dimension_key(key: str) -> None:
    value = payload()
    value["dimension_results"][0].pop(key)
    assert_rejected(value, "missing key")


@pytest.mark.parametrize("key", sorted(verifier.FINDING_KEYS))
def test_rejects_every_missing_finding_key(key: str) -> None:
    value = payload()
    value["findings"][0].pop(key)
    assert_rejected(value, "missing key")


@pytest.mark.parametrize("key", sorted(verifier.LIMITATION_KEYS))
def test_rejects_every_missing_limitation_key(key: str) -> None:
    value = payload()
    value["limitations"][0].pop(key)
    assert_rejected(value, "missing key")


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (lambda d: d["findings"].append(copy.deepcopy(d["findings"][0])), "finding ids"),
        (
            lambda d: d["findings"].extend(
                [{**copy.deepcopy(d["findings"][0]), "id": "P3-000"}]
            ),
            "finding ids",
        ),
        (lambda d: d["findings"][0].__setitem__("severity", "P0"), "severity"),
        (lambda d: d["findings"][0].__setitem__("path", "/tmp/x"), "relative repository path"),
        (lambda d: d["findings"][0].__setitem__("title", "x" * 257), "string length limit 256"),
        (lambda d: d["findings"][0].__setitem__("impact", "x" * 4097), "string length limit 4096"),
        (lambda d: d["limitations"][0].__setitem__("blocking", True), "verdict truth table"),
        (lambda d: d["limitations"][0].__setitem__("code", "unknown"), "limitation code"),
    ],
)
def test_rejects_finding_and_limitation_mutations(mutation, needle: str) -> None:
    value = payload()
    mutation(value)
    assert_rejected(value, needle)


def test_rejects_inverse_verdict_truth_table_cases() -> None:
    value = payload()
    value["dimension_results"][0]["status"] = "fail"
    assert_rejected(value, "verdict truth table")

    value = payload()
    value["verdict"] = "fail_findings_present"
    assert_rejected(value, "verdict truth table")

    value = payload()
    value["findings"][0]["severity"] = "P2"
    value["findings"][0]["id"] = "P2-001"
    assert_rejected(value, "verdict truth table")


@pytest.mark.parametrize(
    "invalid",
    [
        b'{"schema_version":1,"schema_version":1}',
        b'{"schema_version":NaN}',
        b'{"schema_version":Infinity}',
        b"\xef\xbb\xbf{}",
        b"{} trailing",
        b"\xff",
        b"[]",
    ],
)
def test_rejects_strict_json_ingestion_failures(invalid: bytes) -> None:
    assert verifier.verify_bytes(invalid)


def test_rejects_resource_limit_failures() -> None:
    assert any("byte limit" in error for error in verifier.verify_bytes(b" " * (verifier.MAX_BYTES + 1)))
    too_deep = ("[" * (verifier.MAX_DEPTH + 2) + "]" * (verifier.MAX_DEPTH + 2)).encode()
    assert verifier.verify_bytes(too_deep)
    value = payload()
    value["dimension_results"][0]["reasoning"] = "x" * (verifier.MAX_STRING_LENGTH + 1)
    assert_rejected(value, "string length")


def test_schema_is_exact_closed_declarative_contract() -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    assert verifier.audit_schema_document(schema) == []
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["$id"] == "https://mint.local/schemas/batch4/review-result.schema.json"
    assert schema["additionalProperties"] is False


def test_schema_audit_rejects_remote_ref_and_unsupported_keyword() -> None:
    schema = json.loads(SCHEMA_PATH.read_text())
    schema["$ref"] = "https://attacker.invalid/schema"
    errors = verifier.audit_schema_document(schema)
    assert any("unsupported schema keyword" in error for error in errors)
    schema.pop("$ref")
    schema["format"] = "date-time"
    assert any("unsupported schema keyword" in error for error in verifier.audit_schema_document(schema))


def test_verifier_does_not_use_network(monkeypatch: pytest.MonkeyPatch) -> None:
    def denied(*_args, **_kwargs):
        raise AssertionError("network access attempted")

    monkeypatch.setattr(socket, "socket", denied)
    assert verifier.verify_bytes(raw(payload())) == []


def test_cli_wording_and_exit_codes(tmp_path: Path) -> None:
    good = tmp_path / "synthetic_non_evidence.json"
    good.write_bytes(raw(payload()))
    result = subprocess.run(
        [sys.executable, str(VERIFIER_PATH), str(good)], text=True, capture_output=True
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "STRUCTURALLY_VALID_NON_EVIDENCE"
    assert "review pass" not in result.stdout.lower()

    bad = tmp_path / "bad.json"
    bad.write_text("{}")
    result = subprocess.run(
        [sys.executable, str(VERIFIER_PATH), str(bad)], text=True, capture_output=True
    )
    assert result.returncode != 0
    assert "STRUCTURALLY_VALID_NON_EVIDENCE" not in result.stdout


def test_cli_rejects_symlink(tmp_path: Path) -> None:
    target = tmp_path / "synthetic_non_evidence.json"
    target.write_bytes(raw(payload()))
    link = tmp_path / "link.json"
    link.symlink_to(target)
    result = subprocess.run(
        [sys.executable, str(VERIFIER_PATH), str(link)], text=True, capture_output=True
    )
    assert result.returncode != 0


def test_cli_reads_only_bounded_bytes(tmp_path: Path) -> None:
    oversized = tmp_path / "oversized.json"
    oversized.write_bytes(b" " * (verifier.MAX_BYTES + 100_000))
    result = subprocess.run(
        [sys.executable, str(VERIFIER_PATH), str(oversized)], text=True, capture_output=True
    )
    assert result.returncode != 0
    assert "byte limit" in result.stderr
