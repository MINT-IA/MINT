from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
TOOL = REPO / "tools/checks/mint_next_batch4_outbound_policy_verifier.py"
POLICY = REPO / "product/mint_next/batch4/evidence/outbound-data-policy-v1.yaml"
SCHEMA = REPO / "product/mint_next/batch4/evidence/outbound-input-classification-manifest.schema.json"
SPEC = importlib.util.spec_from_file_location("outbound_policy_verifier", TOOL)
assert SPEC and SPEC.loader
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)

REQUEST_TOOL = REPO / "tools/checks/mint_next_batch4_review_request_verifier.py"
REQUEST_SPEC = importlib.util.spec_from_file_location("review_request_verifier", REQUEST_TOOL)
assert REQUEST_SPEC and REQUEST_SPEC.loader
request_verifier = importlib.util.module_from_spec(REQUEST_SPEC)
REQUEST_SPEC.loader.exec_module(request_verifier)

R5_R6_REQUIRED_ADDITIONS = [
    "product/mint_next/batch4/evidence/cross-provider-review-system-prompt-v1.txt",
    "tools/checks/mint_next_batch4_review_prompt_linter.py",
    "tools/checks/tests/test_mint_next_batch4_review_prompt_linter.py",
    "product/mint_next/batch4/evidence/model-review-content.schema.json",
    "tools/checks/mint_next_batch4_model_review_content_verifier.py",
    "tools/checks/tests/test_mint_next_batch4_model_review_content_verifier.py",
]
R7_REQUIRED_ADDITIONS = [
    "product/mint_next/batch4/evidence/outbound-data-policy-v1.yaml",
    "product/mint_next/batch4/evidence/outbound-input-classification-manifest.schema.json",
    "tools/checks/mint_next_batch4_outbound_policy_verifier.py",
    "tools/checks/tests/test_mint_next_batch4_outbound_policy_verifier.py",
]
UNRESOLVED_PLACEHOLDERS = {
    "git-lineage-evidence.json",
    "toolchain-manifest.json",
    "provider-family-registry.json",
    "authoring-provider-provenance.json",
    "trusted-attestation-policy.json",
}


def manifest() -> dict:
    value = {
        "schema_version": 1,
        "kind": "mint_next_batch4_synthetic_outbound_classification_manifest",
        "trust_scope": "descriptor_shape_policy_and_internal_hashes_only_non_evidence",
        "policy_sha256": verifier.POLICY_SHA256,
        "classified_input_set_sha256": "",
        "entries": [{
            "path": "product/mint_next/batch4/batch.yaml",
            "classification": "project_internal_non_secret_architecture",
            "size_bytes": 28,
            "sha256": "8" * 64,
        }],
    }
    value["classified_input_set_sha256"] = verifier.classified_input_set_sha256(
        value["entries"]
    )
    return value


def raw(value: dict) -> bytes:
    return verifier.canonicalize_for_test(value)


def rejected(value: dict, needle: str) -> None:
    assert any(needle in error for error in verifier.verify_manifest_bytes(raw(value)))


def test_exact_synthetic_manifest_passes_as_non_evidence() -> None:
    assert verifier.verify_manifest_bytes(raw(manifest())) == []


def test_policy_is_fail_closed_and_non_evidence() -> None:
    policy = yaml.safe_load(POLICY.read_text())
    assert policy["status"] == "implemented_component_unintegrated_blocking"
    assert policy["allowed_classifications"] == [
        "public_source_metadata", "project_internal_non_secret_architecture"
    ]
    assert set(policy["forbidden_classifications"]) == {
        "secret_or_credential", "personal_identifying_data",
        "user_financial_or_health_data", "unknown_or_unclassified",
    }
    assert policy["overflow_behavior"] == "reject_without_truncation_summarization_or_drop"
    assert policy["classification_subject"] == (
        "outbound_semantic_inputs_excluding_this_manifest_and_transport_auth_headers"
    )
    assert policy["manifest_self_classification"] == (
        "forbidden_circular_outer_serialized_payload_scan_required_later"
    )
    assert policy["writes_manifest_or_digest"] is False
    assert all(value is False for key, value in policy["claim_boundary"].items() if key.startswith("proves_"))


def test_schema_matches_policy_vocab_and_budgets() -> None:
    schema = json.loads(SCHEMA.read_text())
    assert schema["required"] == [
        "schema_version", "kind", "trust_scope", "policy_sha256",
        "classified_input_set_sha256", "entries",
    ]
    assert list(schema["properties"]) == schema["required"]
    assert schema["additionalProperties"] is False
    entries = schema["properties"]["entries"]
    assert entries["maxItems"] == verifier.MAX_ENTRIES
    assert entries["items"]["properties"]["classification"]["enum"] == verifier.ALLOWED_CLASSIFICATIONS
    assert entries["items"]["properties"]["size_bytes"]["maximum"] == verifier.MAX_ENTRY_BYTES


@pytest.mark.parametrize("key", sorted([
    "schema_version", "kind", "trust_scope", "policy_sha256",
    "classified_input_set_sha256", "entries",
]))
def test_rejects_missing_top_level_fields(key: str) -> None:
    value = manifest()
    value.pop(key)
    rejected(value, "missing key")


@pytest.mark.parametrize("classification", [
    "secret_or_credential", "personal_identifying_data",
    "user_financial_or_health_data", "unknown_or_unclassified", "other",
])
def test_rejects_forbidden_or_unknown_classification(classification: str) -> None:
    value = manifest()
    value["entries"][0]["classification"] = classification
    rejected(value, "classification")


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (lambda d: d["entries"][0].__setitem__("path", "../secret"), "safe relative"),
        (lambda d: d["entries"][0].__setitem__("size_bytes", verifier.MAX_ENTRY_BYTES + 1), "entry byte budget"),
        (lambda d: d["entries"][0].__setitem__("sha256", "bad"), "lowercase 64-hex"),
        (lambda d: d["entries"].append(dict(d["entries"][0])), "paths must be unique"),
        (lambda d: d["entries"][0].__setitem__("extra", True), "unexpected key"),
        (lambda d: d.__setitem__("policy_sha256", "0" * 64), "policy_sha256"),
    ],
)
def test_rejects_entry_and_policy_mutations(mutation, needle: str) -> None:
    value = manifest()
    mutation(value)
    rejected(value, needle)


def test_rejects_manifest_self_classification() -> None:
    value = manifest()
    value["entries"][0]["path"] = verifier.SELF_MANIFEST_PATH
    value["classified_input_set_sha256"] = verifier.classified_input_set_sha256(value["entries"])
    rejected(value, "must not self-classify")


@pytest.mark.parametrize("forbidden", ["scanner_receipts", "provider_policy_state", "content_base64"])
def test_rejects_fields_reserved_for_later_evidence_components(forbidden: str) -> None:
    value = manifest()
    if forbidden == "content_base64":
        value["entries"][0][forbidden] = ""
    else:
        value[forbidden] = {}
    rejected(value, "unexpected key")


def test_descriptor_digest_binds_every_entry_field() -> None:
    value = manifest()
    value["entries"][0]["size_bytes"] += 1
    rejected(value, "classified_input_set_sha256")


@pytest.mark.parametrize("bad", [
    b'{"schema_version":1,"schema_version":1}',
    b'{"x":NaN}',
    b'{"x":1.0}',
    b"\xef\xbb\xbf{}",
    b"{} trailing",
])
def test_rejects_noncanonical_or_unsafe_json(bad: bytes) -> None:
    assert verifier.verify_manifest_bytes(bad)


def test_rejects_total_and_file_budget_overflow_without_truncation() -> None:
    value = manifest()
    value["entries"] = [
        {
            "path": f"product/mint_next/batch4/f{i}.yaml",
            "classification": "project_internal_non_secret_architecture",
            "size_bytes": verifier.MAX_ENTRY_BYTES,
            "sha256": f"{i + 1:x}" * 64,
        }
        for i in range(3)
    ]
    value["classified_input_set_sha256"] = verifier.classified_input_set_sha256(
        value["entries"]
    )
    rejected(value, "combined classified inputs and manifest byte budget exceeded")


def test_known_partial_52_descriptor_inventory_fits_with_unresolved_sizes_blocking() -> None:
    paths = [
        path for path, _role in request_verifier.EXPECTED_INPUTS
        if path != verifier.SELF_MANIFEST_PATH
    ]
    paths.extend(R5_R6_REQUIRED_ADDITIONS)
    paths.extend(R7_REQUIRED_ADDITIONS)
    assert len(paths) == 52
    missing = {path for path in paths if not (REPO / path).exists()}
    assert missing == UNRESOLVED_PLACEHOLDERS
    entries = []
    for path in sorted(paths):
        source = REPO / path
        if path in UNRESOLVED_PLACEHOLDERS:
            content = b""
        else:
            assert source.is_file() and not source.is_symlink()
            content = source.read_bytes()
        entries.append({
            "path": path,
            "classification": "project_internal_non_secret_architecture",
            "size_bytes": len(content),
            "sha256": __import__("hashlib").sha256(content).hexdigest(),
        })
    assert sum(entry["size_bytes"] for entry in entries) > 450_000
    value = manifest()
    value["entries"] = entries
    value["classified_input_set_sha256"] = verifier.classified_input_set_sha256(entries)
    encoded = raw(value)
    assert sum(entry["size_bytes"] for entry in entries) + len(encoded) <= verifier.MAX_DOWNSTREAM_CONTENT_BYTES
    assert verifier.verify_manifest_bytes(encoded) == []
    assert manifest()["trust_scope"].endswith("non_evidence")


def test_rejects_combined_entries_plus_manifest_downstream_overflow() -> None:
    value = manifest()
    value["entries"] = [
        {
            "path": f"product/mint_next/batch4/overflow-{index}.json",
            "classification": "project_internal_non_secret_architecture",
            "size_bytes": 180_000,
            "sha256": f"{index + 1:x}" * 64,
        }
        for index in range(3)
    ]
    value["classified_input_set_sha256"] = verifier.classified_input_set_sha256(value["entries"])
    rejected(value, "combined classified inputs and manifest byte budget exceeded")


@pytest.mark.parametrize(
    ("attribute", "source", "needle"),
    [
        ("POLICY_PATH", POLICY, "policy"),
        ("SCHEMA_PATH", SCHEMA, "schema"),
        (
            "CANONICALIZER_PATH",
            REPO / "tools/checks/mint_next_batch4_canonical_json.py",
            "canonicalizer",
        ),
    ],
)
def test_rejects_pinned_dependency_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
    attribute: str, source: Path, needle: str,
) -> None:
    drift = tmp_path / source.name
    drift.write_bytes(source.read_bytes() + b"\n")
    monkeypatch.setattr(verifier, attribute, drift)
    if attribute == "CANONICALIZER_PATH":
        with pytest.raises(ValueError, match="hash mismatch"):
            verifier._load_canonicalizer()
    else:
        assert any(needle in error and "hash mismatch" in error for error in verifier.verify_manifest_bytes(raw(manifest())))


def test_cli_rejects_symlink_fifo_and_oversize(tmp_path: Path) -> None:
    source = tmp_path / "manifest.json"
    source.write_bytes(raw(manifest()))
    link = tmp_path / "link.json"
    link.symlink_to(source)
    fifo = tmp_path / "fifo"
    os.mkfifo(fifo)
    oversized = tmp_path / "oversized.json"
    oversized.write_bytes(b"x" * (verifier.MAX_MANIFEST_BYTES + 1))
    for path in (link, fifo, oversized):
        result = subprocess.run(
            [sys.executable, str(TOOL), str(path)],
            text=True, capture_output=True, timeout=5,
        )
        assert result.returncode != 0
        assert "STRUCTURALLY_VALID_OUTBOUND_POLICY_NON_EVIDENCE" not in result.stdout


def test_cli_success_wording_only(tmp_path: Path) -> None:
    path = tmp_path / "manifest.json"
    path.write_bytes(raw(manifest()))
    result = subprocess.run(
        [sys.executable, str(TOOL), str(path)], text=True, capture_output=True
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "STRUCTURALLY_VALID_OUTBOUND_POLICY_NON_EVIDENCE"
    assert result.stderr == ""
