#!/usr/bin/env python3
"""Verify untrusted Batch4 model review content without executing a model."""

from __future__ import annotations

import hashlib
import json
import os
import stat
import sys
from pathlib import Path
from types import MappingProxyType
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "product/mint_next/batch4/evidence/model-review-content.schema.json"
SCHEMA_SHA256 = "55ec47f199a0bba592ac05a4ee1bf879f03eaa158433800307f567996ebde634"
FULL_VERIFIER_PATH = ROOT / "tools/checks/mint_next_batch4_review_result_verifier.py"
FULL_VERIFIER_SHA256 = "7f32a0e62c512dc6e3d5c96d943ecbdbbbd12a4d650f89cc85a44d139b77873f"
MAX_BYTES = 262_144
MAX_DEPTH = 32
MAX_CONTAINER_ITEMS = 512
MAX_STRING_LENGTH = 16_384
MAX_SAFE_INTEGER = (2**53) - 1

DIMENSION_IDS = [
    "information_architecture_closure",
    "beginner_comprehension_hypotheses",
    "swiss_life_coverage",
    "formula_and_source_boundaries",
    "regulatory_boundaries",
    "legacy_reuse_and_preservation",
    "trust_and_promotion_integrity",
]
MANDATORY_MODEL_LIMITATION_CODES = [
    "candidate_binding_unverified",
    "evidence_refs_unresolved",
    "provider_identity_unverified",
]
MODEL_LIMITATION_CODES = [
    "incomplete_input_or_context",
    *MANDATORY_MODEL_LIMITATION_CODES,
]
RUNNER_ONLY_LIMITATION_CODES = [
    "tool_or_transport_error",
    "retry_or_fallback_used",
    "response_truncated",
    "undeclared_tool_or_network_access",
    "schema_or_hash_mismatch",
]
TOP_LEVEL_KEYS = {"dimension_results", "findings", "limitations"}


class _DuplicateKey(ValueError):
    pass


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateKey(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON constant: {value}")


def _reject_float(value: str) -> None:
    raise ValueError(f"floating-point JSON number forbidden: {value}")


def _safe_integer(value: str) -> int:
    parsed = int(value)
    if abs(parsed) > MAX_SAFE_INTEGER:
        raise ValueError(f"JSON integer exceeds safe integer range: {value}")
    return parsed


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _read_pinned(path: Path, expected_sha256: str, label: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError(f"{label} must be a regular non-symlink file")
        chunks: list[bytes] = []
        remaining = 1_048_577
        while remaining:
            chunk = os.read(descriptor, min(65_536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
        if len(raw) > 1_048_576:
            raise ValueError(f"{label} byte limit exceeded")
    finally:
        os.close(descriptor)
    if _sha(raw) != expected_sha256:
        raise ValueError(f"{label} byte hash mismatch")
    return raw


def _load_full_verifier() -> MappingProxyType[str, Any]:
    source = _read_pinned(FULL_VERIFIER_PATH, FULL_VERIFIER_SHA256, "full result verifier")
    namespace: dict[str, Any] = {
        "__name__": "_mint_pinned_full_result_verifier",
        "__file__": str(FULL_VERIFIER_PATH),
        "__builtins__": __builtins__,
    }
    exec(compile(source, str(FULL_VERIFIER_PATH), "exec"), namespace, namespace)
    if not callable(namespace.get("verify_bytes")):
        raise ValueError("full result verifier entry point missing")
    return MappingProxyType(namespace)


_FULL_VERIFIER = _load_full_verifier()


def _schema_errors() -> list[str]:
    errors: list[str] = []
    try:
        raw = _read_pinned(SCHEMA_PATH, SCHEMA_SHA256, "model content schema")
        schema = json.loads(raw, object_pairs_hook=_unique_object, parse_constant=_reject_constant)
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            errors.append("model content schema must declare Draft 2020-12")
        if schema.get("$id") != "https://mint.local/schemas/batch4/model-review-content.schema.json":
            errors.append("model content schema id mismatch")
        if schema.get("required") != ["dimension_results", "findings", "limitations"]:
            errors.append("model content schema required fields mismatch")
        if schema.get("additionalProperties") is not False:
            errors.append("model content schema must reject additional properties")
        if list((schema.get("properties") or {})) != schema.get("required"):
            errors.append("model content schema property order mismatch")
        codes = schema["properties"]["limitations"]["items"]["properties"]["code"]["enum"]
        if codes != MODEL_LIMITATION_CODES:
            errors.append("model content schema limitation ownership mismatch")
    except Exception as exc:
        errors.append(f"pinned model content schema invalid: {exc}")
    return errors


def _resource_errors(value: Any) -> list[str]:
    errors: list[str] = []

    def visit(node: Any, depth: int, location: str) -> None:
        if depth > MAX_DEPTH:
            errors.append(f"resource depth limit exceeded at {location}")
            return
        if isinstance(node, str) and len(node) > MAX_STRING_LENGTH:
            errors.append(f"resource string length limit exceeded at {location}")
        elif isinstance(node, dict):
            if len(node) > MAX_CONTAINER_ITEMS:
                errors.append(f"resource object item limit exceeded at {location}")
            for key, child in node.items():
                visit(key, depth + 1, f"{location}.<key>")
                visit(child, depth + 1, f"{location}.{key}")
        elif isinstance(node, list):
            if len(node) > MAX_CONTAINER_ITEMS:
                errors.append(f"resource array item limit exceeded at {location}")
            for index, child in enumerate(node):
                visit(child, depth + 1, f"{location}[{index}]")

    visit(value, 0, "$")
    return errors


def _content_specific_errors(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["$ must be object"]
    missing = sorted(TOP_LEVEL_KEYS - set(value))
    extra = sorted(set(value) - TOP_LEVEL_KEYS)
    if missing:
        errors.append(f"missing key at $: {', '.join(missing)}")
    if extra:
        errors.append(f"unexpected key at $: {', '.join(extra)}")
    if missing or extra:
        return errors
    limitations = value["limitations"]
    if not isinstance(limitations, list):
        return errors + ["limitations must be array"]
    codes: list[str] = []
    for index, item in enumerate(limitations):
        if not isinstance(item, dict):
            errors.append(f"limitations[{index}] must be object")
            continue
        code = item.get("code")
        if code in RUNNER_ONLY_LIMITATION_CODES:
            errors.append(f"limitations[{index}] runner-only limitation forbidden in model content")
        if isinstance(code, str):
            codes.append(code)
    if len(codes) != len(set(codes)):
        errors.append("limitation codes must be unique")
    missing_codes = [code for code in MANDATORY_MODEL_LIMITATION_CODES if code not in codes]
    if missing_codes:
        errors.append(f"mandatory model limitation missing: {', '.join(missing_codes)}")
    known_model_codes = [code for code in codes if code in MODEL_LIMITATION_CODES]
    if known_model_codes != [code for code in MODEL_LIMITATION_CODES if code in known_model_codes]:
        errors.append("model limitation codes must follow result schema enum order")
    return errors


def _derived_verdict(value: dict[str, Any]) -> str:
    statuses = [
        item.get("status") for item in value.get("dimension_results", [])
        if isinstance(item, dict)
    ]
    severities = [
        item.get("severity") for item in value.get("findings", [])
        if isinstance(item, dict)
    ]
    blocking = any(
        isinstance(item, dict) and item.get("blocking") is True
        for item in value.get("limitations", [])
        if isinstance(value.get("limitations"), list)
    )
    must_fail = (
        len(statuses) != len(DIMENSION_IDS)
        or any(status != "pass" for status in statuses)
        or any(severity in {"P1", "P2"} for severity in severities)
        or blocking
    )
    return "fail_findings_present" if must_fail else "pass_no_p1_p2"


def _synthetic_full_value(value: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "kind": "mint_next_batch4_cross_provider_review_result",
        "reviewed_candidate_head": "0" * 40,
        "provider_family_claimed": "synthetic-differential-non-evidence",
        "model_identifier_claimed": "synthetic-differential-non-evidence",
        "executed_at_utc": "2000-01-01T00:00:00Z",
        "trust_scope": "payload_shape_and_semantics_only_non_evidence",
        "verdict": _derived_verdict(value),
        "dimension_results": value["dimension_results"],
        "findings": value["findings"],
        "limitations": value["limitations"],
    }


def verify_with_pinned_full_result(raw: bytes) -> list[str]:
    return list(_FULL_VERIFIER["verify_bytes"](raw))


def synthetic_full_result_bytes(raw: bytes) -> tuple[bytes | None, list[str]]:
    errors, value = _parse_and_check_content(raw)
    if errors or value is None:
        return None, errors
    full_raw = json.dumps(
        _synthetic_full_value(value), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    return full_raw, []


def _parse_and_check_content(raw: bytes) -> tuple[list[str], dict[str, Any] | None]:
    errors = _schema_errors()
    if not isinstance(raw, bytes):
        return errors + ["payload must be raw bytes"], None
    if len(raw) > MAX_BYTES:
        return errors + [f"payload byte limit exceeded: {len(raw)} > {MAX_BYTES}"], None
    if raw.startswith(b"\xef\xbb\xbf"):
        return errors + ["UTF-8 BOM forbidden"], None
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"),
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
            parse_float=_reject_float,
            parse_int=_safe_integer,
        )
    except Exception as exc:
        return errors + [f"strict JSON parse failed: {exc}"], None
    errors.extend(_resource_errors(value))
    errors.extend(_content_specific_errors(value))
    return errors, value if isinstance(value, dict) else None


def verify_bytes(raw: bytes) -> list[str]:
    errors, value = _parse_and_check_content(raw)
    if errors or value is None:
        return errors
    full_raw = json.dumps(
        _synthetic_full_value(value), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    errors.extend(verify_with_pinned_full_result(full_raw))
    return errors


def _read_regular_no_symlink(path: Path) -> bytes:
    flags = (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0)
    )
    descriptor = os.open(path, flags)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError("model content path must be a regular non-symlink file")
        chunks: list[bytes] = []
        remaining = MAX_BYTES + 1
        while remaining:
            chunk = os.read(descriptor, min(65_536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: mint_next_batch4_model_review_content_verifier.py CONTENT.json", file=sys.stderr)
        return 2
    try:
        errors = verify_bytes(_read_regular_no_symlink(Path(argv[1])))
    except Exception as exc:
        errors = [f"cannot read model content safely: {exc}"]
    if errors:
        for error in errors:
            print(f"INVALID_MODEL_CONTENT_NON_EVIDENCE: {error}", file=sys.stderr)
        return 1
    print("STRUCTURALLY_VALID_MODEL_CONTENT_NON_EVIDENCE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
