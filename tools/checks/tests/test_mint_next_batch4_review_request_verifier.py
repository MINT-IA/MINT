from __future__ import annotations

import base64
import copy
import hashlib
import importlib.util
import json
import os
import socket
import subprocess
import sys
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator


REPO = Path(__file__).resolve().parents[3]
TOOL = REPO / "tools/checks/mint_next_batch4_review_request_verifier.py"
SCHEMA = REPO / "product/mint_next/batch4/evidence/review-request.schema.json"
MODULE_SPEC = importlib.util.spec_from_file_location("request_verifier", TOOL)
assert MODULE_SPEC and MODULE_SPEC.loader
verifier = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(verifier)


def _entry(path: str, role: str, content: bytes) -> dict[str, object]:
    return {
        "path": path,
        "role": role,
        "size_bytes": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
        "content_base64": base64.b64encode(content).decode("ascii"),
    }


def payload() -> dict[str, object]:
    entries = []
    for path, role in verifier.EXPECTED_INPUTS:
        entries.append(_entry(path, role, f"synthetic:{path}".encode()))
    by_path = {entry["path"]: entry for entry in entries}
    hashes = {
        field: by_path[path]["sha256"]
        for field, path in verifier.HASH_BINDINGS.items()
    }
    return {
        "schema_version": 1,
        "kind": "mint_next_batch4_synthetic_review_request",
        "trust_scope": "request_shape_and_internal_hashes_only_non_evidence",
        "unresolved_bindings": ["system_prompt_sha256"],
        "candidate_head": "a" * 40,
        "authoring_provider_families_claimed": ["synthetic-authoring-family"],
        "protocol_sha256": hashes["protocol_sha256"],
        "system_prompt_sha256": "0" * 64,
        "result_schema_sha256": hashes["result_schema_sha256"],
        "toolchain_manifest_sha256": hashes["toolchain_manifest_sha256"],
        "provider_family_registry_sha256": hashes["provider_family_registry_sha256"],
        "outbound_input_classification_manifest_sha256": hashes[
            "outbound_input_classification_manifest_sha256"
        ],
        "authoring_provider_provenance_sha256": hashes[
            "authoring_provider_provenance_sha256"
        ],
        "git_lineage_evidence_sha256": hashes["git_lineage_evidence_sha256"],
        "trusted_attestation_policy_sha256": hashes[
            "trusted_attestation_policy_sha256"
        ],
        "ordered_inputs": entries,
        "ordered_review_dimension_ids": list(verifier.DIMENSION_IDS),
        "execution_policy": dict(verifier.EXECUTION_POLICY),
    }


def raw(value: dict[str, object]) -> bytes:
    return verifier.canonicalize_for_test(value)


def errors(value: dict[str, object]) -> list[str]:
    return verifier.verify_request_bytes(raw(value))


def test_exact_synthetic_payload_passes_as_non_evidence() -> None:
    value = payload()
    canonical = raw(value)
    assert verifier.verify_request_bytes(canonical) == []
    assert verifier.verify_request_bytes(canonical) == []
    assert canonical == verifier.canonicalize_for_test(json.loads(canonical))


@pytest.mark.parametrize("key", verifier.TOP_LEVEL_KEYS)
def test_rejects_every_missing_top_level_key(key: str) -> None:
    value = payload()
    value.pop(key)
    assert errors(value)


def test_rejects_extra_and_self_hash_fields() -> None:
    for key in ("extra", "request_sha256", "promotion_receipt"):
        value = payload()
        value[key] = "x"
        assert errors(value)


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("schema_version", True),
        ("schema_version", 2),
        ("kind", "review_request"),
        ("trust_scope", "trusted"),
        ("candidate_head", "A" * 40),
        ("candidate_head", "a" * 39),
        ("unresolved_bindings", []),
        ("unresolved_bindings", ["system_prompt_sha256", "other"]),
    ],
)
def test_rejects_wrong_constants_and_candidate_syntax(key: str, value: object) -> None:
    candidate = payload()
    candidate[key] = value
    assert errors(candidate)


def test_rejects_family_duplicates_unsorted_and_unsafe() -> None:
    for families in (
        ["z", "a"], ["a", "a"], [], ["Claude Family"], ["a" * 65],
    ):
        value = payload()
        value["authoring_provider_families_claimed"] = families
        assert errors(value)


@pytest.mark.parametrize("field", verifier.HASH_FIELDS)
def test_rejects_hash_case_length_and_mismatch(field: str) -> None:
    for replacement in ("A" * 64, "a" * 63, "f" * 64):
        value = payload()
        value[field] = replacement
        found = errors(value)
        if field == "system_prompt_sha256" and replacement == "f" * 64:
            assert found == []
        else:
            assert found
        if field != "system_prompt_sha256" and replacement == "f" * 64:
            assert any("binding" in error for error in found)


def test_system_prompt_hash_is_explicitly_unresolved_not_bound() -> None:
    value = payload()
    assert errors(value) == []
    value["unresolved_bindings"] = []
    assert errors(value)
    assert all(path != "system-prompt.txt" for path, _role in verifier.EXPECTED_INPUTS)


@pytest.mark.parametrize("operation", ["missing", "extra", "duplicate", "reverse"])
def test_rejects_input_set_or_order_drift(operation: str) -> None:
    value = payload()
    inputs = value["ordered_inputs"]
    assert isinstance(inputs, list)
    if operation == "missing":
        inputs.pop()
    elif operation == "extra":
        inputs.append(_entry("extra.txt", "context_or_verifier", b"x"))
    elif operation == "duplicate":
        inputs[1] = copy.deepcopy(inputs[0])
    else:
        inputs.reverse()
    assert errors(value)


@pytest.mark.parametrize("field", ["path", "role", "size_bytes", "sha256", "content_base64"])
def test_rejects_every_missing_input_field(field: str) -> None:
    value = payload()
    value["ordered_inputs"][0].pop(field)  # type: ignore[index]
    assert errors(value)


@pytest.mark.parametrize(
    ("field", "replacement"),
    [
        ("path", "../escape"),
        ("path", "a//b"),
        ("path", "a\\b"),
        ("role", "caller_selected"),
        ("size_bytes", True),
        ("size_bytes", -1),
        ("sha256", "0" * 64),
        ("content_base64", " eA=="),
        ("content_base64", "eA"),
        ("content_base64", "eA=== "),
    ],
)
def test_rejects_input_alias_hash_size_role_and_base64(
    field: str, replacement: object
) -> None:
    value = payload()
    value["ordered_inputs"][0][field] = replacement  # type: ignore[index]
    assert errors(value)


def test_rejects_decoded_size_mismatch() -> None:
    value = payload()
    value["ordered_inputs"][0]["size_bytes"] += 1  # type: ignore[index,operator]
    assert errors(value)


def test_rejects_dimensions_missing_duplicate_reordered_or_unknown() -> None:
    for ids in (
        verifier.DIMENSION_IDS[:-1],
        [verifier.DIMENSION_IDS[0], *verifier.DIMENSION_IDS[:-1]],
        list(reversed(verifier.DIMENSION_IDS)),
        [*verifier.DIMENSION_IDS[:-1], "unknown"],
    ):
        value = payload()
        value["ordered_review_dimension_ids"] = ids
        assert errors(value)


def test_rejects_execution_policy_mutation_and_extras() -> None:
    for mutation in ("value", "extra", "missing"):
        value = payload()
        policy = value["execution_policy"]
        assert isinstance(policy, dict)
        if mutation == "value":
            policy["network_for_reviewer"] = "allowed"
        elif mutation == "extra":
            policy["shell"] = "allowed"
        else:
            policy.pop("repository_commands_for_reviewer")
        assert errors(value)


@pytest.mark.parametrize(
    "bad_raw",
    [
        b'{"a":1,"a":2}', b"NaN", b"1.0", b"\xef\xbb\xbf{}",
        b"{} trailing", b"\xff",
    ],
)
def test_rejects_strict_json_failures(bad_raw: bytes) -> None:
    assert verifier.verify_request_bytes(bad_raw)


def test_requires_canonical_request_bytes() -> None:
    value = payload()
    noncanonical = json.dumps(value, indent=2).encode()
    found = verifier.verify_request_bytes(noncanonical)
    assert any("canonical" in error for error in found)


def test_schema_is_closed_pinned_and_non_evidence() -> None:
    schema = json.loads(SCHEMA.read_text())
    assert schema["additionalProperties"] is False
    assert schema["properties"]["trust_scope"]["const"].endswith("non_evidence")
    assert schema["properties"]["unresolved_bindings"]["const"] == [
        "system_prompt_sha256"
    ]
    assert verifier.audit_schema_document(schema) == []


def test_schema_is_declarative_shape_and_verifier_owns_semantics() -> None:
    schema = json.loads(SCHEMA.read_text())
    validator = Draft202012Validator(schema)
    valid = payload()
    assert list(validator.iter_errors(valid)) == []
    assert errors(valid) == []

    unsorted_families = payload()
    unsorted_families["authoring_provider_families_claimed"] = ["z", "a"]
    assert list(validator.iter_errors(unsorted_families)) == []
    assert any("sorted unique" in error for error in errors(unsorted_families))

    reordered_dimensions = payload()
    reordered_dimensions["ordered_review_dimension_ids"] = list(
        reversed(verifier.DIMENSION_IDS)
    )
    assert list(validator.iter_errors(reordered_dimensions)) == []
    assert any("exact protocol order" in error for error in errors(reordered_dimensions))


def test_schema_verified_bytes_are_read_exactly_once(monkeypatch: pytest.MonkeyPatch) -> None:
    original = verifier.Path.read_bytes
    reads = 0

    def counted(path: Path) -> bytes:
        nonlocal reads
        if path == verifier.SCHEMA_PATH:
            reads += 1
            if reads > 1:
                raise AssertionError("verified schema was read twice")
        return original(path)

    monkeypatch.setattr(verifier.Path, "read_bytes", counted)
    assert errors(payload()) == []
    assert reads == 1


def test_no_network_or_repo_command(monkeypatch: pytest.MonkeyPatch) -> None:
    def denied(*_args, **_kwargs):
        raise AssertionError("external access attempted")

    monkeypatch.setattr(socket, "socket", denied)
    monkeypatch.setattr(subprocess, "run", denied)
    assert errors(payload()) == []


def test_cli_success_wording_only(tmp_path: Path) -> None:
    source = tmp_path / "request.json"
    source.write_bytes(raw(payload()))
    result = subprocess.run([sys.executable, str(TOOL), str(source)], text=True, capture_output=True)
    assert result.returncode == 0
    assert result.stdout.strip() == "STRUCTURALLY_VALID_REQUEST_NON_EVIDENCE"
    assert result.stderr == ""
    assert "sha256" not in result.stdout.lower()


def test_cli_rejects_symlink_fifo_and_oversize(tmp_path: Path) -> None:
    source = tmp_path / "request.json"
    source.write_bytes(raw(payload()))
    link = tmp_path / "link.json"
    link.symlink_to(source)
    fifo = tmp_path / "fifo"
    os.mkfifo(fifo)
    oversized = tmp_path / "oversized.json"
    oversized.write_bytes(b" " * (verifier.MAX_BYTES + 1))
    for path in (link, fifo, oversized):
        result = subprocess.run(
            [sys.executable, str(TOOL), str(path)], text=True, capture_output=True,
            timeout=5,
        )
        assert result.returncode != 0
        assert "STRUCTURALLY_VALID_REQUEST_NON_EVIDENCE" not in result.stdout
