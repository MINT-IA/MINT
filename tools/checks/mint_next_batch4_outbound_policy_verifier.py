#!/usr/bin/env python3
"""Verify synthetic Batch4 outbound classification manifests offline."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath
from types import MappingProxyType
from typing import Any, NoReturn

import yaml


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "product/mint_next/batch4/evidence/outbound-data-policy-v1.yaml"
POLICY_SHA256 = "530fd404e272b1c2de1a2fdf3061edd8c9b98ad5bb281ed14c841d75f5b8ac46"
SCHEMA_PATH = ROOT / "product/mint_next/batch4/evidence/outbound-input-classification-manifest.schema.json"
SCHEMA_SHA256 = "dc336f2cce128a272ac25085c7f02feb69cda0d5bc822cbeabc2f02e86b50b18"
CANONICALIZER_PATH = ROOT / "tools/checks/mint_next_batch4_canonical_json.py"
CANONICALIZER_SHA256 = "e2982d1ac823b6e1d795f687ab326aedd610d2e556bd1f0e4ae77c1a9c61b80a"
MAX_ENTRIES = 64
MAX_ENTRY_BYTES = 192_000
MAX_DOWNSTREAM_CONTENT_BYTES = 524_288
MAX_MANIFEST_BYTES = 131_072
MAX_DEPTH = 32
MAX_CONTAINER_ITEMS = 512
MAX_STRING_LENGTH = 349_528
MAX_SAFE_INTEGER = (2**53) - 1

ALLOWED_CLASSIFICATIONS = [
    "public_source_metadata", "project_internal_non_secret_architecture"
]
TOP_KEYS = {
    "schema_version", "kind", "trust_scope", "policy_sha256",
    "classified_input_set_sha256", "entries",
}
ENTRY_KEYS = {"path", "classification", "size_bytes", "sha256"}
SELF_MANIFEST_PATH = "outbound-input-classification-manifest.json"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
SAFE_PATH_RE = re.compile(
    r"^(?!/)(?!.*//)(?!.*\\)(?!.*(?:^|/)\.{1,2}(?:/|$))(?!.*\/$)"
    r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$"
)


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
    raise ValueError("floating-point JSON number forbidden")


def _reject_constant(value: str) -> NoReturn:
    raise ValueError(f"non-finite JSON constant forbidden: {value}")


def _safe_int(token: str) -> int:
    value = int(token)
    if abs(value) > MAX_SAFE_INTEGER:
        raise ValueError("integer outside portable safe range")
    return value


def _read_regular_pinned(path: Path, expected: str, label: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError(f"{label} must be regular file")
        chunks: list[bytes] = []
        remaining = 1_048_577
        while remaining:
            chunk = os.read(descriptor, min(65_536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
    finally:
        os.close(descriptor)
    if len(raw) > 1_048_576:
        raise ValueError(f"{label} byte limit exceeded")
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError(f"{label} byte hash mismatch")
    return raw


def _load_canonicalizer() -> MappingProxyType[str, Any]:
    source = _read_regular_pinned(
        CANONICALIZER_PATH, CANONICALIZER_SHA256, "canonicalizer"
    )
    namespace: dict[str, Any] = {
        "__name__": "_mint_pinned_outbound_canonicalizer",
        "__file__": str(CANONICALIZER_PATH),
        "__builtins__": __builtins__,
    }
    exec(compile(source, str(CANONICALIZER_PATH), "exec"), namespace, namespace)
    if not callable(namespace.get("canonicalize_bytes")):
        raise ValueError("canonicalizer entry point missing")
    return MappingProxyType(namespace)


_CANONICALIZER = _load_canonicalizer()


def canonicalize_for_test(value: Any) -> bytes:
    encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()
    return _CANONICALIZER["canonicalize_bytes"](encoded)


def _artifact_errors() -> list[str]:
    errors: list[str] = []
    try:
        policy_raw = _read_regular_pinned(POLICY_PATH, POLICY_SHA256, "outbound policy")
        policy = yaml.safe_load(policy_raw)
        expected = {
            "schema_version": 1,
            "kind": "mint_next_batch4_outbound_data_policy",
            "status": "implemented_component_unintegrated_blocking",
            "classification_subject": "outbound_semantic_inputs_excluding_this_manifest_and_transport_auth_headers",
            "manifest_self_classification": "forbidden_circular_outer_serialized_payload_scan_required_later",
            "forbidden_descriptor_paths": [SELF_MANIFEST_PATH],
            "allowed_classifications": ALLOWED_CLASSIFICATIONS,
            "forbidden_classifications": [
                "secret_or_credential", "personal_identifying_data",
                "user_financial_or_health_data", "unknown_or_unclassified",
            ],
            "budgets": {
                "max_entries": MAX_ENTRIES, "max_entry_bytes": MAX_ENTRY_BYTES,
                "max_combined_classified_inputs_and_manifest_bytes": MAX_DOWNSTREAM_CONTENT_BYTES,
                "max_manifest_bytes": MAX_MANIFEST_BYTES,
                "downstream_request_total_decoded_limit": 524_288,
            },
            "overflow_behavior": "reject_without_truncation_summarization_or_drop",
            "manifest_excludes": [
                "content_bytes_or_base64", "scanner_receipts",
                "provider_retention_or_training_assertions",
                "final_serialized_payload_digest",
            ],
            "separate_absent_blocking_evidence": [
                "secret_and_pii_scanner_execution_and_receipts",
                "provider_retention_training_authority",
                "final_serialized_payload_scan_receipt",
            ],
            "writes_manifest_or_digest": False,
            "claim_boundary": {
                "proves_input_set_complete": False,
                "proves_future_artifacts_fit": False,
                "proves_descriptor_hashes_match_repository_bytes": False,
                "proves_scanner_executed_or_authentic": False,
                "proves_content_contains_no_secret_or_pii": False,
                "proves_provider_retention_or_training_controls": False,
                "proves_export_request_review_identity_or_promotion": False,
            },
        }
        if policy != expected:
            errors.append("outbound policy semantic contract mismatch")
        schema_raw = _read_regular_pinned(SCHEMA_PATH, SCHEMA_SHA256, "outbound schema")
        schema = json.loads(schema_raw, object_pairs_hook=_unique_object)
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            errors.append("outbound schema draft mismatch")
        if schema.get("required") != [
            "schema_version", "kind", "trust_scope", "policy_sha256",
            "classified_input_set_sha256", "entries",
        ] or schema.get("additionalProperties") is not False:
            errors.append("outbound schema top-level closure mismatch")
    except Exception as exc:
        errors.append(f"pinned outbound artifact invalid: {exc}")
    return errors


def _resource_errors(value: Any) -> list[str]:
    errors: list[str] = []
    def visit(node: Any, depth: int, location: str) -> None:
        if depth > MAX_DEPTH:
            errors.append(f"resource depth exceeded at {location}")
            return
        if isinstance(node, str) and len(node) > MAX_STRING_LENGTH:
            errors.append(f"resource string length exceeded at {location}")
        elif isinstance(node, (dict, list)):
            if len(node) > MAX_CONTAINER_ITEMS:
                errors.append(f"resource container limit exceeded at {location}")
            iterator = node.items() if isinstance(node, dict) else enumerate(node)
            for key, child in iterator:
                visit(child, depth + 1, f"{location}.{key}")
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


def _sha(value: Any, location: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not SHA_RE.fullmatch(value):
        errors.append(f"{location} must be lowercase 64-hex")


def classified_input_set_sha256(entries: Any) -> str:
    encoded = json.dumps(entries, ensure_ascii=False, separators=(",", ":")).encode()
    canonical = _CANONICALIZER["canonicalize_bytes"](encoded)
    return hashlib.sha256(canonical).hexdigest()


def _semantic_errors(value: Any, manifest_size: int) -> list[str]:
    errors: list[str] = []
    if not _exact_keys(value, TOP_KEYS, "$", errors):
        return errors
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        errors.append("schema_version must be integer 1")
    if value["kind"] != "mint_next_batch4_synthetic_outbound_classification_manifest":
        errors.append("kind must identify synthetic outbound manifest")
    if value["trust_scope"] != "descriptor_shape_policy_and_internal_hashes_only_non_evidence":
        errors.append("trust_scope must remain non-evidence")
    if value["policy_sha256"] != POLICY_SHA256:
        errors.append("policy_sha256 must bind pinned policy")
    entries = value["entries"]
    if not isinstance(entries, list) or not 1 <= len(entries) <= MAX_ENTRIES:
        errors.append("entries must contain 1..64 items")
        return errors
    paths: list[str] = []
    total = 0
    for index, item in enumerate(entries):
        location = f"entries[{index}]"
        if not _exact_keys(item, ENTRY_KEYS, location, errors):
            continue
        path = item["path"]
        pure = PurePosixPath(path) if isinstance(path, str) else None
        if (
            not isinstance(path, str) or not SAFE_PATH_RE.fullmatch(path)
            or pure is None or pure.is_absolute() or str(pure) != path
        ):
            errors.append(f"{location}.path must be safe relative POSIX path")
        else:
            paths.append(path)
            if path == SELF_MANIFEST_PATH:
                errors.append(f"{location}.path must not self-classify the manifest")
        if item["classification"] not in ALLOWED_CLASSIFICATIONS:
            errors.append(f"{location}.classification forbidden or unknown")
        size = item["size_bytes"]
        if type(size) is not int or not 0 <= size <= MAX_ENTRY_BYTES:
            errors.append(f"{location} entry byte budget exceeded")
        else:
            total += size
        _sha(item["sha256"], f"{location}.sha256", errors)
    if len(paths) != len(set(paths)):
        errors.append("entry paths must be unique")
    if paths != sorted(paths):
        errors.append("entry paths must be sorted")
    if total + manifest_size > MAX_DOWNSTREAM_CONTENT_BYTES:
        errors.append("combined classified inputs and manifest byte budget exceeded")
    try:
        expected_digest = classified_input_set_sha256(entries)
        if value["classified_input_set_sha256"] != expected_digest:
            errors.append("classified_input_set_sha256 must bind canonical ordered descriptors")
    except Exception as exc:
        errors.append(f"classified input descriptor digest failed: {exc}")
    return errors


def verify_manifest_bytes(raw: bytes) -> list[str]:
    errors = _artifact_errors()
    if not isinstance(raw, bytes):
        return errors + ["manifest input must be raw bytes"]
    if len(raw) > MAX_MANIFEST_BYTES:
        return errors + ["manifest byte budget exceeded"]
    if raw.startswith(b"\xef\xbb\xbf"):
        return errors + ["UTF-8 BOM forbidden"]
    try:
        value = json.loads(
            raw.decode("utf-8", errors="strict"), object_pairs_hook=_unique_object,
            parse_float=_reject_float, parse_int=_safe_int, parse_constant=_reject_constant,
        )
    except Exception as exc:
        return errors + [f"strict JSON parse failed: {exc}"]
    errors.extend(_resource_errors(value))
    try:
        if _CANONICALIZER["canonicalize_bytes"](raw) != raw:
            errors.append("manifest bytes must be canonical RFC8785 subset")
    except Exception as exc:
        errors.append(f"canonicalization failed: {exc}")
        return errors
    errors.extend(_semantic_errors(value, len(raw)))
    return errors


def _read_manifest(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    descriptor = os.open(path, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ValueError("manifest must be regular file")
        if metadata.st_size > MAX_MANIFEST_BYTES:
            raise ValueError("manifest byte budget exceeded")
        chunks: list[bytes] = []
        remaining = MAX_MANIFEST_BYTES + 1
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
        print("usage: mint_next_batch4_outbound_policy_verifier.py MANIFEST.json", file=sys.stderr)
        return 2
    try:
        errors = verify_manifest_bytes(_read_manifest(Path(argv[1])))
    except Exception as exc:
        errors = [f"safe manifest read failed: {exc}"]
    if errors:
        for error in errors:
            print(f"INVALID_OUTBOUND_POLICY_NON_EVIDENCE: {error}", file=sys.stderr)
        return 1
    print("STRUCTURALLY_VALID_OUTBOUND_POLICY_NON_EVIDENCE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
