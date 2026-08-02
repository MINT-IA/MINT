#!/usr/bin/env python3
"""Verify one pinned Batch 4 result payload's shape and semantics offline.

This is deliberately not a generic JSON Schema implementation and never
validates a review bundle, provider identity, candidate binding, provenance,
or promotion eligibility. A zero exit means only structurally valid
non-evidence.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "product/mint_next/batch4/evidence/review-result.schema.json"
SCHEMA_SHA256 = "b8d5c6be40673451208bb1039c6431b5e3af4214fff042c911a12a56735cfbda"
MAX_BYTES = 262_144
MAX_DEPTH = 32
MAX_STRING_LENGTH = 16_384
MAX_CONTAINER_ITEMS = 512

DIMENSION_IDS = [
    "information_architecture_closure",
    "beginner_comprehension_hypotheses",
    "swiss_life_coverage",
    "formula_and_source_boundaries",
    "regulatory_boundaries",
    "legacy_reuse_and_preservation",
    "trust_and_promotion_integrity",
]
BLOCKING_LIMITATION_CODES = {
    "incomplete_input_or_context",
    "tool_or_transport_error",
    "retry_or_fallback_used",
    "response_truncated",
    "undeclared_tool_or_network_access",
    "schema_or_hash_mismatch",
}
MANDATORY_NON_EVIDENCE_LIMITATIONS = {
    "candidate_binding_unverified",
    "evidence_refs_unresolved",
    "provider_identity_unverified",
}
LIMITATION_CODES = BLOCKING_LIMITATION_CODES | MANDATORY_NON_EVIDENCE_LIMITATIONS
TOP_LEVEL_KEYS = {
    "schema_version", "kind", "reviewed_candidate_head",
    "provider_family_claimed", "model_identifier_claimed", "executed_at_utc",
    "trust_scope", "verdict", "dimension_results", "findings", "limitations",
}
DIMENSION_KEYS = {"dimension_id", "status", "evidence_refs", "reasoning"}
EVIDENCE_REF_KEYS = {"input_index", "path", "locator"}
FINDING_KEYS = {
    "id", "severity", "title", "path", "locator", "evidence",
    "reproduction", "impact", "required_remediation",
}
LIMITATION_KEYS = {"code", "blocking", "detail"}
FINDING_ID_RE = re.compile(r"^P([123])-[0-9]{3,}$")
HEAD_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_PATH_PATTERN = (
    r"^(?!/)(?!.*//)(?!.*\\)(?!.*(?:^|/)\.{1,2}(?:/|$))(?!.*\/$)"
    r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$"
)
SAFE_PATH_RE = re.compile(SAFE_PATH_PATTERN)
UTC_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
    r"(?:\.[0-9]{1,6})?Z$"
)
SUPPORTED_SCHEMA_KEYWORDS = {
    "$schema", "$id", "description", "type", "required",
    "additionalProperties", "properties", "items", "minItems", "maxItems",
    "minLength", "maxLength", "pattern", "minimum", "maximum", "const", "enum",
}


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


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_schema_document(schema: Any) -> list[str]:
    """Audit only the intentionally supported declarative keyword subset."""
    errors: list[str] = []

    def visit(node: Any, location: str) -> None:
        if not isinstance(node, dict):
            errors.append(f"schema node must be object at {location}")
            return
        for key in node:
            if key not in SUPPORTED_SCHEMA_KEYWORDS:
                errors.append(f"unsupported schema keyword {key!r} at {location}")
        if node.get("type") == "object":
            properties = node.get("properties")
            required = node.get("required")
            if not isinstance(properties, dict):
                errors.append(f"object schema missing properties at {location}")
            else:
                if required != list(properties):
                    errors.append(f"object schema required/property order mismatch at {location}")
                for name, child in properties.items():
                    visit(child, f"{location}.properties.{name}")
            if node.get("additionalProperties") is not False:
                errors.append(f"object schema must close additionalProperties at {location}")
        elif node.get("type") == "array":
            visit(node.get("items"), f"{location}.items")

    if not isinstance(schema, dict):
        return ["schema root must be object"]
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        errors.append("schema must declare Draft 2020-12")
    if schema.get("$id") != "https://mint.local/schemas/batch4/review-result.schema.json":
        errors.append("schema must keep stable local id")
    visit(schema, "$")
    return errors


def _load_and_audit_pinned_schema(errors: list[str]) -> None:
    try:
        if not SCHEMA_PATH.is_file() or SCHEMA_PATH.is_symlink():
            raise ValueError("schema missing or symlinked")
        if _sha(SCHEMA_PATH) != SCHEMA_SHA256:
            raise ValueError("schema byte hash mismatch")
        schema = json.loads(
            SCHEMA_PATH.read_text(encoding="utf-8"),
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
        errors.extend(audit_schema_document(schema))
    except Exception as exc:
        errors.append(f"pinned schema invalid: {exc}")


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


def _exact_keys(value: Any, expected: set[str], location: str, errors: list[str]) -> bool:
    if not isinstance(value, dict):
        errors.append(f"{location} must be object")
        return False
    missing = sorted(expected - set(value))
    extra = sorted(set(value) - expected)
    if missing:
        errors.append(f"missing key at {location}: {', '.join(missing)}")
    if extra:
        errors.append(f"unexpected key at {location}: {', '.join(extra)}")
    return not missing and not extra


def _string(value: Any, name: str, errors: list[str], *, maximum: int = 16_384) -> bool:
    if not isinstance(value, str) or not value or len(value) > maximum:
        errors.append(f"{name} must be non-empty string within string length limit {maximum}")
        return False
    return True


def _relative_path(value: Any, name: str, errors: list[str]) -> None:
    if not _string(value, name, errors, maximum=512):
        return
    assert isinstance(value, str)
    pure = PurePosixPath(value)
    if (
        pure.is_absolute()
        or "\\" in value
        or str(pure) != value
        or not SAFE_PATH_RE.fullmatch(value)
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        errors.append(f"{name} must be a safe relative repository path")


def _timestamp(value: Any, errors: list[str]) -> None:
    if not isinstance(value, str) or not UTC_RE.fullmatch(value):
        errors.append("executed_at_utc must be an exact UTC timestamp")
        return
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
        if parsed.tzinfo != timezone.utc:
            raise ValueError("not UTC")
    except ValueError:
        errors.append("executed_at_utc timestamp is not a real calendar instant")


def _validate_dimensions(value: Any, errors: list[str]) -> list[str]:
    statuses: list[str] = []
    if not isinstance(value, list):
        errors.append("dimension_results must be array")
        return statuses
    ids = [item.get("dimension_id") if isinstance(item, dict) else None for item in value]
    if ids != DIMENSION_IDS:
        errors.append("dimension_results must contain exact ordered dimension ids")
    for index, item in enumerate(value):
        location = f"dimension_results[{index}]"
        if not _exact_keys(item, DIMENSION_KEYS, location, errors):
            continue
        status_value = item["status"]
        if not isinstance(status_value, str) or status_value not in {"pass", "fail", "unverified"}:
            errors.append(f"{location}.status must be pass, fail, or unverified")
        else:
            statuses.append(status_value)
        _string(item["reasoning"], f"{location}.reasoning", errors)
        refs = item["evidence_refs"]
        if not isinstance(refs, list) or not refs or len(refs) > 64:
            errors.append(f"{location}.evidence_refs must contain 1..64 unresolved syntax-only refs")
            continue
        for ref_index, ref in enumerate(refs):
            ref_location = f"{location}.evidence_refs[{ref_index}]"
            if not _exact_keys(ref, EVIDENCE_REF_KEYS, ref_location, errors):
                continue
            input_index = ref["input_index"]
            if type(input_index) is not int or not 0 <= input_index <= 65535:
                errors.append(f"{ref_location}.input_index must be bounded integer")
            _relative_path(ref["path"], f"{ref_location}.path", errors)
            _string(ref["locator"], f"{ref_location}.locator", errors, maximum=512)
    return statuses


def _validate_findings(value: Any, errors: list[str]) -> list[str]:
    severities: list[str] = []
    if not isinstance(value, list) or len(value) > 100:
        errors.append("findings must be array with at most 100 items")
        return severities
    ids: list[str] = []
    for index, item in enumerate(value):
        location = f"findings[{index}]"
        if not _exact_keys(item, FINDING_KEYS, location, errors):
            continue
        finding_id = item["id"]
        match = FINDING_ID_RE.fullmatch(finding_id) if isinstance(finding_id, str) else None
        severity = item["severity"]
        if not match or (isinstance(finding_id, str) and len(finding_id) > 64):
            errors.append(f"{location}.id must match P1/P2/P3 numeric finding id")
        else:
            ids.append(finding_id)
        if not isinstance(severity, str) or severity not in {"P1", "P2", "P3"}:
            errors.append(f"{location}.severity must be P1, P2, or P3")
        else:
            severities.append(severity)
            if match and severity != f"P{match.group(1)}":
                errors.append(f"{location} id prefix must match severity")
        _relative_path(item["path"], f"{location}.path", errors)
        maxima = {
            "title": 256,
            "locator": 512,
            "evidence": 16_384,
            "reproduction": 16_384,
            "impact": 4_096,
            "required_remediation": 4_096,
        }
        for name, maximum in maxima.items():
            _string(item[name], f"{location}.{name}", errors, maximum=maximum)
    if len(ids) != len(set(ids)) or ids != sorted(ids):
        errors.append("finding ids must be unique and sorted by Unicode code point")
    return severities


def _validate_limitations(value: Any, errors: list[str]) -> bool:
    if not isinstance(value, list):
        errors.append("limitations must be array with 3..32 items")
        errors.append("mandatory non-evidence limitation set cannot be established")
        return False
    if not 3 <= len(value) <= 32:
        errors.append("limitations must be array with 3..32 items")
    codes: list[str] = []
    has_blocking = False
    for index, item in enumerate(value):
        location = f"limitations[{index}]"
        if not _exact_keys(item, LIMITATION_KEYS, location, errors):
            continue
        code = item["code"]
        blocking = item["blocking"]
        if not isinstance(code, str) or code not in LIMITATION_CODES:
            errors.append(f"{location}.limitation code is unknown")
            continue
        codes.append(code)
        if type(blocking) is not bool:
            errors.append(f"{location}.blocking must be boolean")
        else:
            expected = code in BLOCKING_LIMITATION_CODES
            if blocking is not expected:
                errors.append(f"{location}.blocking must match limitation code semantics")
            has_blocking = has_blocking or blocking
        _string(item["detail"], f"{location}.detail", errors, maximum=4096)
    if len(codes) != len(set(codes)):
        errors.append("limitation codes must be unique")
    missing = sorted(MANDATORY_NON_EVIDENCE_LIMITATIONS - set(codes))
    if missing:
        errors.append(f"mandatory non-evidence limitation missing: {', '.join(missing)}")
    return has_blocking


def verify_bytes(raw: bytes) -> list[str]:
    errors: list[str] = []
    _load_and_audit_pinned_schema(errors)
    if not isinstance(raw, bytes):
        return errors + ["payload must be raw bytes"]
    if len(raw) > MAX_BYTES:
        return errors + [f"payload byte limit exceeded: {len(raw)} > {MAX_BYTES}"]
    if raw.startswith(b"\xef\xbb\xbf"):
        return errors + ["UTF-8 BOM forbidden"]
    try:
        text = raw.decode("utf-8", errors="strict")
        value = json.loads(
            text, object_pairs_hook=_unique_object, parse_constant=_reject_constant
        )
    except Exception as exc:
        return errors + [f"strict JSON parse failed: {exc}"]
    errors.extend(_resource_errors(value))
    if not _exact_keys(value, TOP_LEVEL_KEYS, "$", errors):
        return errors

    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        errors.append("schema_version must be integer 1")
    if value["kind"] != "mint_next_batch4_cross_provider_review_result":
        errors.append("kind must identify exact Batch4 review result shape")
    head = value["reviewed_candidate_head"]
    if not isinstance(head, str) or not HEAD_RE.fullmatch(head):
        errors.append("reviewed candidate head must be lowercase 40 hex syntax only")
    _string(value["provider_family_claimed"], "provider_family_claimed", errors, maximum=256)
    _string(value["model_identifier_claimed"], "model_identifier_claimed", errors, maximum=256)
    _timestamp(value["executed_at_utc"], errors)
    if value["trust_scope"] != "payload_shape_and_semantics_only_non_evidence":
        errors.append("trust_scope must remain payload_shape_and_semantics_only_non_evidence")
    if not isinstance(value["verdict"], str) or value["verdict"] not in {
        "pass_no_p1_p2", "fail_findings_present"
    }:
        errors.append("verdict is unknown")

    statuses = _validate_dimensions(value["dimension_results"], errors)
    severities = _validate_findings(value["findings"], errors)
    has_blocking = _validate_limitations(value["limitations"], errors)
    must_fail = (
        len(statuses) != len(DIMENSION_IDS)
        or any(status != "pass" for status in statuses)
        or any(severity in {"P1", "P2"} for severity in severities)
        or has_blocking
    )
    expected_verdict = "fail_findings_present" if must_fail else "pass_no_p1_p2"
    if value["verdict"] != expected_verdict:
        errors.append(f"verdict truth table requires {expected_verdict}")
    return errors


def _read_regular_no_symlink(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        mode = os.fstat(descriptor).st_mode
        if not stat.S_ISREG(mode):
            raise ValueError("result path must be a regular non-symlink file")
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
        print("usage: mint_next_batch4_review_result_verifier.py RESULT.json", file=sys.stderr)
        return 2
    path = Path(argv[1])
    try:
        errors = verify_bytes(_read_regular_no_symlink(path))
    except Exception as exc:
        errors = [f"cannot read result safely: {exc}"]
    if errors:
        for error in errors:
            print(f"INVALID_NON_EVIDENCE_PAYLOAD: {error}", file=sys.stderr)
        return 1
    print("STRUCTURALLY_VALID_NON_EVIDENCE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
