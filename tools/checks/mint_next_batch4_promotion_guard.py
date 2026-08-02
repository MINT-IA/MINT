#!/usr/bin/env python3
"""Fail-closed readiness guard for Batch 4 architecture promotion.

This proves only that the promotion phase is coherently blocked.  It cannot
promote Batch 4 and intentionally rejects every candidate, receipt, or gate.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


READINESS = Path("product/mint_next/batch4/evidence/promotion-readiness.yaml")
BATCH = Path("product/mint_next/batch4/batch.yaml")
FORMULAS = Path("product/mint_next/batch4/formula_contracts.yaml")
PHASE = "mint-next-batch4-architecture-promotion-20260802"
PHASE_DIR = f".planning/phases/{PHASE}"
CANONICAL: dict[str, str] = {
    "product/mint_next/batch4/batch.yaml": "1747152dbe7af810b7fd4e1116aa14295c50c146aab07670e132f46a8a631c47",
    "product/mint_next/batch4/source-inventory.yaml": "31fc42e2bc1c33be4662860485f36e76c7204e740a3d1dc993277eaec318acbe",
    "product/mint_next/batch4/architecture_conflicts.yaml": "d041d24840e85f64e0e52136a9a1f354550234d47ec99a5d41b9c91731665854",
    "product/mint_next/batch4/calculation_contracts.yaml": "4df33396c1d7303216e21253534054d9531169b427a3b8a542d98c25ea030bcc",
    "product/mint_next/batch4/formula_contracts.yaml": "d226d5651213bd81d5bcb5b82ef6df352ed1254aa817b6dedc0c4a33198868be",
    "product/mint_next/batch4/official_sources.yaml": "8372e1c3462219c98d533040d7986a454fe537d6d535ecbb28414d6c41a3bf8c",
    "product/mint_next/batch4/regulatory_boundaries.yaml": "bcb6f3b8f376558e077a8b4699717f07c0b9f4be8db469902dcad81ce46f8e89",
    "product/mint_next/batch4/domain_coverage.yaml": "8cde9c06d9c7caa93832b98a10fdd4e167fbba32661cdef3cb7c6b9fb099b571",
    "product/mint_next/batch4/audience.yaml": "e71a39364f69f9462e6924e246f2a993352efae030ae290d319f7179a557e3ca",
    "product/mint_next/batch4/concepts.yaml": "81d26df406f20624fb7f555bf3c67e1632e87e9cc3660a2a0285d900af3bd001",
    "product/mint_next/batch4/decisions.yaml": "83e04e192c4da60dccd0dafe64784e70e65ac10900865ae06ef84b19166ddb38",
    "product/mint_next/batch4/experience_graph.yaml": "c51e8d4c0fb362dfa070502784e82a23b93a9e8f3e54db782f9b4e952315d492",
    "product/mint_next/batch4/claims_and_data.yaml": "7d032e2730d8e6df0a5e8a7c625bb73bfaf7d259d59a6a1ec0a3fd42067af7a9",
    "product/mint_next/batch4/legacy_reuse.yaml": "432b6d9002edbfb2460c7184043200a1d716ddd9456c4cbe3505ef83318cfd11",
}
PROTECTED = {
    "legacy": ((".planning/phases/mint-2-0-first-experience-rente-capital/",), 24, "ee3a7ed7e64b789ff1ed29bccaf6bc187b5a2f397a2d2767015d2a293ae00b8d"),
    "product": (("apps/mobile/", "services/backend/"), 3187, "4ba2d80218fe69f1094f2d26bdf7c23313b7c74d23fcd8ab57fa83d516b4a390"),
    "journey": ((".planning/journeys/",), 64, "2ffcc877a091c3cc8025e9c74332a14524aabf02b4b91c9b6e8317602664ac54"),
    "simulator": (("tools/simulator/",), 134, "755bca7dc40adde85a77eac2e6dd12440dde73b679b11ef3cd71bc238ef56b99"),
}


class _UniqueKeyLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False):
    mapping: dict[Any, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ValueError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


_UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping
)


def _load(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = yaml.load(path.read_text(), Loader=_UniqueKeyLoader)
    except Exception as exc:
        errors.append(f"unreadable YAML {path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path} must be a mapping")
        return {}
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _tree(root: Path, prefixes: tuple[str, ...], errors: list[str]) -> tuple[int, str]:
    command = ["git", "ls-files", "--", *prefixes]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True)
    if result.returncode:
        errors.append("cannot enumerate protected tracked files")
        return 0, ""
    paths = sorted(filter(None, result.stdout.splitlines()))
    other = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "--", *prefixes],
        cwd=root, text=True, capture_output=True,
    )
    if other.returncode or other.stdout.strip():
        errors.append(f"untracked file in protected surface: {other.stdout.strip()}")
    digest = hashlib.sha256()
    for relative in paths:
        path = root / relative
        if not path.is_file() or path.is_symlink():
            errors.append(f"protected path missing or symlinked: {relative}")
            continue
        digest.update(relative.encode() + b"\0" + _sha(path).encode() + b"\n")
    return len(paths), digest.hexdigest()


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    active = _load(root / ".planning/ACTIVE_CONTEXT.json", errors)
    expected_router = {
        "active_milestone": PHASE,
        "active_phase_dir": PHASE_DIR,
        "active_phase_context": f"{PHASE_DIR}/CONTEXT.md",
        "active_spec": f"{PHASE_DIR}/SPEC.md",
    }
    for key, expected in expected_router.items():
        if active.get(key) != expected:
            errors.append(f"active promotion router mismatch: {key}")
    for name in ("CONTEXT.md", "SPEC.md", "PLAN.md", "VERIFICATION.md"):
        if not (root / PHASE_DIR / name).is_file():
            errors.append(f"missing promotion phase file: {name}")

    readiness = _load(root / READINESS, errors)
    expected_keys = {
        "schema_version", "kind", "phase", "status", "promotion_eligible",
        "selected_gate", "candidate_head", "promotion_receipt", "gates",
        "manifests", "formula_blockers", "claim_boundary",
    }
    if set(readiness) != expected_keys:
        errors.append("promotion readiness must contain exactly the blocked-readiness fields")
    expected_scalar = {
        "schema_version": 1,
        "kind": "mint_next_batch4_architecture_promotion_readiness",
        "phase": PHASE,
        "status": "blocked_waiting_cross_provider_review",
        "promotion_eligible": False,
        "selected_gate": "none",
        "candidate_head": None,
        "promotion_receipt": None,
    }
    for key, expected in expected_scalar.items():
        if readiness.get(key) != expected:
            errors.append(f"promotion readiness must keep {key}={expected!r}")
    gates = readiness.get("gates") or {}
    if gates != {"external_attestation": "absent", "cross_provider_review": "absent"}:
        errors.append("promotion readiness must keep both gates absent")
    if readiness.get("claim_boundary") != {
        "architecture_promoted": False, "product_runtime": False,
        "swiss_financial_correctness": False, "regulatory_compliance": False,
        "ux_user_validation": False,
    }:
        errors.append("promotion readiness claim boundary overclaims proof")

    batch = _load(root / BATCH, errors)
    if batch.get("status") != "draft_unproven" or batch.get("promotion_receipt") is not None:
        errors.append("Batch 4 must remain draft_unproven with null receipt")
    trust = (batch.get("promotion") or {}).get("trust_boundary") or {}
    if trust.get("external_attestation") != "absent" or trust.get("cross_provider_review") != "absent":
        errors.append("Batch 4 must keep both promotion gates absent")

    formulas = _load(root / FORMULAS, errors).get("formulas")
    blockers = [item for item in formulas or [] if isinstance(item, dict) and item.get("status") == "unimplemented_blocking"]
    if not isinstance(formulas, list) or len(formulas) != 19 or len(blockers) != 19:
        errors.append("all 19 formulas must remain unimplemented_blocking")
    if readiness.get("formula_blockers") != {"count": 19, "status": "unimplemented_blocking"}:
        errors.append("readiness must record exactly 19 unimplemented formula blockers")

    manifest = readiness.get("manifests")
    if not isinstance(manifest, dict) or set(manifest) != {"canonical_registries", *PROTECTED}:
        errors.append("readiness manifests must cover canonical, legacy, product, Journey, and simulator surfaces")
        manifest = {}
    canonical_entries = [{"path": path, "sha256": sha} for path, sha in CANONICAL.items()]
    if manifest.get("canonical_registries") != {"algorithm": "sha256", "entries": canonical_entries}:
        errors.append("canonical registry manifest mismatch")
    for name, (prefixes, expected_count, expected_digest) in PROTECTED.items():
        expected = {
            "algorithm": "sha256-tree-v1", "path_prefixes": list(prefixes),
            "tracked_file_count": expected_count, "digest": expected_digest,
        }
        if manifest.get(name) != expected:
            errors.append(f"readiness {name} manifest mismatch")
        count, digest = _tree(root, prefixes, errors)
        if (count, digest) != (expected_count, expected_digest):
            errors.append(f"protected {name} surface drift")
    for relative, expected in CANONICAL.items():
        path = root / relative
        if not path.is_file() or path.is_symlink() or _sha(path) != expected:
            errors.append(f"canonical registry drift: {relative}")
    return errors


def main() -> int:
    errors = validate(Path.cwd())
    if errors:
        print("Batch 4 promotion readiness guard: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Batch 4 promotion readiness guard: PASS (blocked; no promotion claimed)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
