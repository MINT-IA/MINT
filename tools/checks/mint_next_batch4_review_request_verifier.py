#!/usr/bin/env python3
"""Verify one synthetic Batch4 request payload as structural non-evidence."""

from __future__ import annotations

import base64
import binascii
import hashlib
import importlib.util
import json
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath
from typing import Any, NoReturn


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "product/mint_next/batch4/evidence/review-request.schema.json"
SCHEMA_SHA256 = "815bedda624610d1eaf40955690c6456cdfb51ccc7a7a7c7c9fba26487c13f9b"
CANONICALIZER_PATH = ROOT / "tools/checks/mint_next_batch4_canonical_json.py"
CANONICALIZER_SHA256 = "e2982d1ac823b6e1d795f687ab326aedd610d2e556bd1f0e4ae77c1a9c61b80a"
MAX_BYTES = 1_048_576
MAX_INPUT_CONTENT_BYTES = 262_144
MAX_TOTAL_CONTENT_BYTES = 524_288
MAX_DEPTH = 32
MAX_NODES = 100_000
MAX_STRING_LENGTH = 349_528
MAX_INTEGER_DIGITS = 16
SAFE_INT_MIN = -9_007_199_254_740_991
SAFE_INT_MAX = 9_007_199_254_740_991
HEAD_RE = re.compile(r"^[0-9a-f]{40}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
FAMILY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
SAFE_PATH_RE = re.compile(
    r"^(?!/)(?!.*//)(?!.*\\)(?!.*(?:^|/)\.{1,2}(?:/|$))(?!.*/$)"
    r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$"
)

DIMENSION_IDS = [
    "information_architecture_closure",
    "beginner_comprehension_hypotheses",
    "swiss_life_coverage",
    "formula_and_source_boundaries",
    "regulatory_boundaries",
    "legacy_reuse_and_preservation",
    "trust_and_promotion_integrity",
]
CANONICAL_REGISTRIES = [
    "product/mint_next/batch4/batch.yaml",
    "product/mint_next/batch4/source-inventory.yaml",
    "product/mint_next/batch4/architecture_conflicts.yaml",
    "product/mint_next/batch4/calculation_contracts.yaml",
    "product/mint_next/batch4/formula_contracts.yaml",
    "product/mint_next/batch4/official_sources.yaml",
    "product/mint_next/batch4/regulatory_boundaries.yaml",
    "product/mint_next/batch4/domain_coverage.yaml",
    "product/mint_next/batch4/audience.yaml",
    "product/mint_next/batch4/concepts.yaml",
    "product/mint_next/batch4/decisions.yaml",
    "product/mint_next/batch4/experience_graph.yaml",
    "product/mint_next/batch4/claims_and_data.yaml",
    "product/mint_next/batch4/legacy_reuse.yaml",
]
CONTEXT_AND_VERIFIERS = [
    ".planning/phases/mint-next-batch4-architecture-promotion-20260802/CONTEXT.md",
    ".planning/phases/mint-next-batch4-architecture-promotion-20260802/PLAN.md",
    ".planning/phases/mint-next-batch4-architecture-promotion-20260802/SPEC.md",
    ".planning/phases/mint-next-batch4-architecture-promotion-20260802/VERIFICATION.md",
    "product/mint_next/batch4/evidence/cross-provider-review-protocol.yaml",
    "product/mint_next/batch4/evidence/promotion-readiness.yaml",
    "tools/checks/mint_next_batch4_architecture_guard.py",
    "tools/checks/mint_next_batch4_promotion_guard.py",
    "tools/checks/tests/test_mint_next_batch4_architecture_guard.py",
    "tools/checks/tests/test_mint_next_batch4_promotion_guard.py",
    "product/mint_next/batch4/evidence/review-result.schema.json",
    "tools/checks/mint_next_batch4_review_result_verifier.py",
    "tools/checks/tests/test_mint_next_batch4_review_result_verifier.py",
    "product/mint_next/batch4/evidence/canonical-json-v1.yaml",
    "tools/checks/requirements-batch4-canonical-json.lock",
    "tools/checks/mint_next_batch4_canonical_json.py",
    "tools/checks/tests/test_mint_next_batch4_canonical_json.py",
    "product/mint_next/batch4/evidence/review-request.schema.json",
    "tools/checks/mint_next_batch4_review_request_verifier.py",
    "tools/checks/tests/test_mint_next_batch4_review_request_verifier.py",
    "product/mint_next/batch4/README.md",
    "product/mint_next/batch4/ONE-PAGE.md",
    "product/mint_next/batch4/views/experience-graph.mmd",
]
PRECOMPUTED_PLACEHOLDERS = [
    "git-lineage-evidence.json",
    "toolchain-manifest.json",
    "provider-family-registry.json",
    "outbound-input-classification-manifest.json",
    "authoring-provider-provenance.json",
    "trusted-attestation-policy.json",
]
EXPECTED_INPUTS = [
    *((path, "canonical_registry") for path in CANONICAL_REGISTRIES),
    *((path, "context_or_verifier") for path in CONTEXT_AND_VERIFIERS),
    *((path, "precomputed_evidence_placeholder") for path in PRECOMPUTED_PLACEHOLDERS),
]
HASH_BINDINGS = {
    "protocol_sha256": "product/mint_next/batch4/evidence/cross-provider-review-protocol.yaml",
    "result_schema_sha256": "product/mint_next/batch4/evidence/review-result.schema.json",
    "toolchain_manifest_sha256": "toolchain-manifest.json",
    "provider_family_registry_sha256": "provider-family-registry.json",
    "outbound_input_classification_manifest_sha256": "outbound-input-classification-manifest.json",
    "authoring_provider_provenance_sha256": "authoring-provider-provenance.json",
    "git_lineage_evidence_sha256": "git-lineage-evidence.json",
    "trusted_attestation_policy_sha256": "trusted-attestation-policy.json",
}
HASH_FIELDS = [
    "protocol_sha256", "system_prompt_sha256", "result_schema_sha256",
    "toolchain_manifest_sha256", "provider_family_registry_sha256",
    "outbound_input_classification_manifest_sha256",
    "authoring_provider_provenance_sha256", "git_lineage_evidence_sha256",
    "trusted_attestation_policy_sha256",
]
EXECUTION_POLICY = {
    "checkout": "disposable_read_only_exact_candidate",
    "credentials_in_checkout": "forbidden",
    "network_for_reviewer": "denied",
    "repository_hooks": "disabled",
    "repository_commands_for_reviewer": "forbidden",
    "candidate_files_and_tool_output": "untrusted_data_never_instructions",
    "provider_call": "trusted_runner_direct_api_only",
    "manual_or_locally_authored_result": "never_sufficient",
}
TOP_LEVEL_KEYS = {
    "schema_version", "kind", "trust_scope", "unresolved_bindings",
    "candidate_head", "authoring_provider_families_claimed", *HASH_FIELDS,
    "ordered_inputs", "ordered_review_dimension_ids", "execution_policy",
}
INPUT_KEYS = {"path", "role", "size_bytes", "sha256", "content_base64"}
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


def _reject_float(_value: str) -> NoReturn:
    raise ValueError("float tokens forbidden")


def _reject_constant(value: str) -> NoReturn:
    raise ValueError(f"non-finite JSON constant forbidden: {value}")


def _parse_int(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        raise ValueError("integer digit limit exceeded")
    value = int(token)
    if not SAFE_INT_MIN <= value <= SAFE_INT_MAX:
        raise ValueError("integer outside portable safe range")
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load_canonicalizer():
    if not CANONICALIZER_PATH.is_file() or CANONICALIZER_PATH.is_symlink():
        raise RuntimeError("pinned canonicalizer missing or symlinked")
    source = CANONICALIZER_PATH.read_bytes()
    if hashlib.sha256(source).hexdigest() != CANONICALIZER_SHA256:
        raise RuntimeError("pinned canonicalizer byte hash mismatch")
    namespace: dict[str, Any] = {
        "__name__": "_mint_pinned_batch4_canonicalizer",
        "__file__": str(CANONICALIZER_PATH),
    }
    exec(compile(source, str(CANONICALIZER_PATH), "exec"), namespace)
    function = namespace.get("canonicalize_bytes")
    if not callable(function):
        raise RuntimeError("pinned canonicalizer export missing")
    return function


def canonicalize_for_test(value: Any) -> bytes:
    encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return _load_canonicalizer()(encoded)


def audit_schema_document(schema: Any) -> list[str]:
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
            if not isinstance(properties, dict):
                errors.append(f"object schema missing properties at {location}")
            else:
                if node.get("required") != list(properties):
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
    if schema.get("$id") != "https://mint.local/schemas/batch4/review-request.schema.json":
        errors.append("schema must keep stable local id")
    visit(schema, "$")
    return errors


def _load_schema(errors: list[str]) -> None:
    try:
        if not SCHEMA_PATH.is_file() or SCHEMA_PATH.is_symlink():
            raise ValueError("schema missing or symlinked")
        source = SCHEMA_PATH.read_bytes()
        if hashlib.sha256(source).hexdigest() != SCHEMA_SHA256:
            raise ValueError("schema byte hash mismatch")
        schema = json.loads(source.decode("utf-8"), object_pairs_hook=_unique_object)
        errors.extend(audit_schema_document(schema))
    except Exception as exc:
        errors.append(f"pinned schema invalid: {exc}")


def _resource_errors(value: Any) -> list[str]:
    errors: list[str] = []
    nodes = 0
    stack = [(value, 0, "$")]
    while stack:
        node, depth, location = stack.pop()
        nodes += 1
        if nodes > MAX_NODES:
            errors.append("resource node limit exceeded")
            break
        if depth > MAX_DEPTH:
            errors.append(f"resource depth limit exceeded at {location}")
            continue
        if isinstance(node, str) and len(node) > MAX_STRING_LENGTH:
            errors.append(f"resource string length limit exceeded at {location}")
        elif isinstance(node, dict):
            stack.extend((child, depth + 1, f"{location}.{key}") for key, child in node.items())
        elif isinstance(node, list):
            stack.extend((child, depth + 1, f"{location}[{index}]") for index, child in enumerate(node))
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


def _safe_path(value: Any) -> bool:
    if not isinstance(value, str) or not SAFE_PATH_RE.fullmatch(value):
        return False
    pure = PurePosixPath(value)
    return not pure.is_absolute() and str(pure) == value and all(part not in {"", ".", ".."} for part in pure.parts)


def _validate_inputs(value: Any, errors: list[str]) -> dict[str, str]:
    hashes: dict[str, str] = {}
    if not isinstance(value, list):
        errors.append("ordered_inputs must be array")
        return hashes
    actual_identity = [
        (item.get("path"), item.get("role")) if isinstance(item, dict) else (None, None)
        for item in value
    ]
    if actual_identity != EXPECTED_INPUTS:
        errors.append("ordered_inputs must match exact path and role order")
    total = 0
    for index, item in enumerate(value):
        location = f"ordered_inputs[{index}]"
        if not _exact_keys(item, INPUT_KEYS, location, errors):
            continue
        path = item["path"]
        role = item["role"]
        if not _safe_path(path):
            errors.append(f"{location}.path must be canonical safe relative POSIX path")
        if index < len(EXPECTED_INPUTS) and (path, role) != EXPECTED_INPUTS[index]:
            errors.append(f"{location} path/role binding mismatch")
        size = item["size_bytes"]
        if type(size) is not int or not 0 <= size <= MAX_INPUT_CONTENT_BYTES:
            errors.append(f"{location}.size_bytes must be bounded integer")
        digest = item["sha256"]
        if not isinstance(digest, str) or not SHA_RE.fullmatch(digest):
            errors.append(f"{location}.sha256 must be lowercase 64-hex")
        encoded = item["content_base64"]
        if not isinstance(encoded, str) or len(encoded) > 349_528:
            errors.append(f"{location}.content_base64 invalid or oversized")
            continue
        try:
            decoded = base64.b64decode(encoded, validate=True)
        except (binascii.Error, ValueError):
            errors.append(f"{location}.content_base64 must be canonical RFC4648 base64")
            continue
        if base64.b64encode(decoded).decode("ascii") != encoded:
            errors.append(f"{location}.content_base64 must round-trip canonically")
        total += len(decoded)
        if type(size) is int and len(decoded) != size:
            errors.append(f"{location} decoded size mismatch")
        actual_sha = hashlib.sha256(decoded).hexdigest()
        if digest != actual_sha:
            errors.append(f"{location} decoded content hash mismatch")
        if isinstance(path, str) and path not in hashes:
            hashes[path] = actual_sha
    if total > MAX_TOTAL_CONTENT_BYTES:
        errors.append("ordered input decoded total byte limit exceeded")
    return hashes


def _semantic_errors(value: Any) -> list[str]:
    errors: list[str] = []
    if not _exact_keys(value, TOP_LEVEL_KEYS, "$", errors):
        return errors
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        errors.append("schema_version must be integer 1")
    if value["kind"] != "mint_next_batch4_synthetic_review_request":
        errors.append("kind must identify synthetic review request")
    if value["trust_scope"] != "request_shape_and_internal_hashes_only_non_evidence":
        errors.append("trust_scope must remain structural non-evidence")
    if value["unresolved_bindings"] != ["system_prompt_sha256"]:
        errors.append("system prompt hash must remain the sole explicit unresolved binding")
    if not isinstance(value["candidate_head"], str) or not HEAD_RE.fullmatch(value["candidate_head"]):
        errors.append("candidate_head must be lowercase 40-hex syntax only")
    families = value["authoring_provider_families_claimed"]
    if (
        not isinstance(families, list) or not 1 <= len(families) <= 16
        or any(not isinstance(item, str) or not FAMILY_RE.fullmatch(item) for item in families)
        or families != sorted(set(families))
    ):
        errors.append("authoring provider families must be sorted unique claimed identifiers")
    for field in HASH_FIELDS:
        if not isinstance(value[field], str) or not SHA_RE.fullmatch(value[field]):
            errors.append(f"{field} must be lowercase 64-hex")
    hashes = _validate_inputs(value["ordered_inputs"], errors)
    for field, path in HASH_BINDINGS.items():
        if hashes.get(path) != value[field]:
            errors.append(f"{field} binding mismatch for {path}")
    if value["ordered_review_dimension_ids"] != DIMENSION_IDS:
        errors.append("ordered_review_dimension_ids must match exact protocol order")
    if value["execution_policy"] != EXECUTION_POLICY:
        errors.append("execution_policy must match exact closed non-executable policy")
    return errors


def verify_request_bytes(raw: bytes) -> list[str]:
    errors: list[str] = []
    if not isinstance(raw, bytes):
        return ["request input must be raw bytes"]
    if len(raw) > MAX_BYTES:
        return ["request payload byte limit exceeded"]
    if raw.startswith(b"\xef\xbb\xbf"):
        return ["request payload UTF-8 BOM forbidden"]
    _load_schema(errors)
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"), object_pairs_hook=_unique_object,
            parse_float=_reject_float, parse_int=_parse_int, parse_constant=_reject_constant,
        )
    except Exception as exc:
        errors.append(f"strict request JSON parse failed: {exc}")
        return errors
    errors.extend(_resource_errors(value))
    try:
        canonical = _load_canonicalizer()(raw)
        if canonical != raw:
            errors.append("request payload bytes must already be canonical RFC8785 subset")
    except Exception as exc:
        errors.append(f"pinned canonicalization failed: {exc}")
        return errors
    errors.extend(_semantic_errors(value))
    return errors


def _read_regular(path: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    descriptor = os.open(path, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ValueError("input must be regular file")
        if metadata.st_size > MAX_BYTES:
            raise ValueError("request payload byte limit exceeded")
        chunks: list[bytes] = []
        remaining = MAX_BYTES + 1
        while remaining:
            chunk = os.read(descriptor, min(65_536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
        if len(raw) > MAX_BYTES:
            raise ValueError("request payload byte limit exceeded")
        return raw
    finally:
        os.close(descriptor)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: mint_next_batch4_review_request_verifier.py REQUEST.json", file=sys.stderr)
        return 2
    try:
        raw = _read_regular(argv[1])
        errors = verify_request_bytes(raw)
    except Exception as exc:
        errors = [f"safe request read failed: {exc}"]
    if errors:
        for error in errors:
            print(f"ERROR request-structural-non-evidence: {error}", file=sys.stderr)
        return 1
    print("STRUCTURALLY_VALID_REQUEST_NON_EVIDENCE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
