#!/usr/bin/env python3
"""Fail closed around the exact Batch 12 single-provider amount candidate."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.checks.mint_next_artifact_manifest import (  # noqa: E402
    DEFAULT_CAS,
    resolve_entry,
    validate_manifest,
)
from tools.checks.mint_next_batch11_amount_scope_guard import validate as validate_scope  # noqa: E402

LAB = ROOT / "product/mint_next/batch7/design_lab"
MANIFEST = ROOT / "product/mint_next/batch12/design-lab-manifest.yaml"
RECEIPT = ROOT / "product/mint_next/batch12/evidence/runtime/receipt.yaml"
PROBE = ROOT / "tools/checks/mint_next_batch12_amount_runtime_probe.py"
NAVIGATION = ROOT / "product/mint_next/batch12/navigation-runtime.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch12/design-lab-acceptance.yaml"
TESTS = ROOT / "tools/checks/tests/test_mint_next_batch12_amount_runtime_guard.py"
WORKFLOW = ROOT / ".github/workflows/mint-next-batch12-runtime.yml"

EXPECTED_COMMIT = "44f7ee6f2d503ccc16b8e9bbff161566611502c3"
EXPECTED_TREE = "e837dcad6b2dbb9b079a3a2d05c460710c9a6889"
EXPECTED_CLOSURE = 48
EXPECTED_MANIFEST_SHA256 = "13f4dfe91d70af8fee000878ab72e7824121310118fc6bd0c7dbdcb52d1f71be"
EXPECTED_RECEIPT_SHA256 = "aa25a2fcda59a6894a59aa99d779260042d698a5a161c1a2a61bc5b0e1b93def"
EXPECTED_PROBE_SHA256 = "de632b95cfe6d87816024e1cdb43b558abdc290c823617ed3ac553c66db459a3"
EXPECTED_NAVIGATION_SHA256 = "6db1521aa753a02e51529505956cde23e7e32c45f3a49de54ebe9777018781d7"
EXPECTED_ACCEPTANCE_NORMALIZED = "b225830314b4df84bed2736b2a9d3ea536c772f4773568ba7e70ffb9744d3faf"
EXPECTED_WORKFLOW_NORMALIZED = "98f02897428bf281f85377131fa75cea18c82375fe2afbc5b87501e626a4cfb9"
EXPECTED_CAPTURE_HASHES = {
    "fr_amount_complete_boundary_chrome_390.png": "23f302c46407400df15e343ef050d39c61a37e5a8daa77c8133c9763e1729e12",
    "fr_amount_disclosure_chrome_390.png": "183760e9782d8776e4e943dc9f4ec2fb14ff2366ea73ddd1b2e8496edb55f4bc",
    "fr_amount_empty_chrome_390.png": "5ad2aa3d7884d246bf7399d04ba2cd7df2ab82bdf7d499fa40576fae901af299",
    "fr_amount_partial_help_chrome_390.png": "596da3fe4925f4e4044c8010cec9104eff05875fd61035e307dee54fb1d8d3be",
}
LOCALES = ("fr", "en", "de", "it", "es", "pt")


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def _normalized_acceptance_digest(acceptance: object) -> str:
    """Bind every acceptance claim while excluding only verifier self-hashes."""
    clone = json.loads(json.dumps(acceptance, ensure_ascii=False))
    if isinstance(clone, dict):
        trust = clone.get("verifier_trust_unit")
        if isinstance(trust, dict):
            for item in trust.values():
                if isinstance(item, dict) and "sha256" in item:
                    item["sha256"] = "<BOUND>"
    canonical = json.dumps(
        clone,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


_WORKFLOW_TRUST_NAMES = (
    "EXPECTED_BATCH12_GUARD_SHA256",
    "EXPECTED_BATCH12_TESTS_SHA256",
    "EXPECTED_BATCH12_ACCEPTANCE_SHA256",
)


def _normalized_workflow_digest(path: Path) -> str:
    """Bind workflow semantics while excluding only its three exact trust hashes."""
    try:
        source = path.read_text(encoding="utf-8")
    except OSError:
        return "missing"
    for name in _WORKFLOW_TRUST_NAMES:
        source = re.sub(
            rf"(?m)^(\s*{re.escape(name)}:\s*)[0-9a-f]{{64}}\s*$",
            rf"\g<1><BOUND>",
            source,
        )
    return hashlib.sha256(source.encode("utf-8")).hexdigest()


def _workflow_trust_binding(path: Path, name: str) -> str | None:
    try:
        source = path.read_text(encoding="utf-8")
    except OSError:
        return None
    matches = re.findall(
        rf"(?m)^\s*{re.escape(name)}:\s*([0-9a-f]{{64}})\s*$",
        source,
    )
    return matches[0] if len(matches) == 1 else None


def validate(
    *,
    manifest_path: Path = MANIFEST,
    receipt_path: Path = RECEIPT,
    probe_path: Path = PROBE,
    acceptance_path: Path = ACCEPTANCE,
    workflow_path: Path = WORKFLOW,
    cas_root: Path = DEFAULT_CAS,
) -> list[str]:
    errors = validate_scope()
    if _digest(manifest_path) != EXPECTED_MANIFEST_SHA256:
        errors.append("Batch12 exact manifest drift")
    if _digest(receipt_path) != EXPECTED_RECEIPT_SHA256:
        errors.append("Batch12 exact runtime receipt drift")
    if _digest(probe_path) != EXPECTED_PROBE_SHA256:
        errors.append("Batch12 exact real-Chrome probe drift")
    if _digest(NAVIGATION) != EXPECTED_NAVIGATION_SHA256:
        errors.append("Batch12 exact written navigation map drift")

    try:
        acceptance = yaml.safe_load(acceptance_path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"Batch12 acceptance unreadable: {exc}")
        acceptance = {}
    if not isinstance(acceptance, dict):
        errors.append("Batch12 acceptance must be a mapping")
    else:
        if _normalized_acceptance_digest(acceptance) != EXPECTED_ACCEPTANCE_NORMALIZED:
            errors.append("Batch12 normalized acceptance semantics drift")
        if acceptance.get("status") != "mechanically_accepted_isolated_single_provider_amount_slice":
            errors.append("Batch12 acceptance status drift")
        snapshot_binding = acceptance.get("implementation_snapshot", {})
        if (
            snapshot_binding.get("accepted_commit") != EXPECTED_COMMIT
            or snapshot_binding.get("accepted_tree") != EXPECTED_TREE
            or snapshot_binding.get("manifest", {}).get("sha256")
            != EXPECTED_MANIFEST_SHA256
        ):
            errors.append("Batch12 acceptance snapshot binding drift")
        if acceptance.get("written_navigation", {}).get("sha256") != EXPECTED_NAVIGATION_SHA256:
            errors.append("Batch12 acceptance navigation binding drift")
        if acceptance.get("runtime_evidence", {}).get("receipt", {}).get("sha256") != EXPECTED_RECEIPT_SHA256:
            errors.append("Batch12 acceptance receipt binding drift")
        expected_trust = {
            "guard": {
                "path": "tools/checks/mint_next_batch12_amount_runtime_guard.py",
                "sha256": _digest(Path(__file__)),
            },
            "tests": {
                "path": "tools/checks/tests/test_mint_next_batch12_amount_runtime_guard.py",
                "sha256": _digest(TESTS),
            },
        }
        if acceptance.get("verifier_trust_unit") != expected_trust:
            errors.append("Batch12 acceptance verifier trust-unit drift")
        roasts = acceptance.get("advisory_roasts", [])
        if (
            not isinstance(roasts, list)
            or {item.get("role") for item in roasts if isinstance(item, dict)}
            != {"ux_accessibility", "adversarial", "swiss_locale"}
            or any(
                item.get("p1") != 0 or item.get("p2") != 0
                for item in roasts
                if isinstance(item, dict)
            )
        ):
            errors.append("Batch12 acceptance roast gate drift")
        not_accepted = set(acceptance.get("not_accepted", []))
        if not {
            "multi_provider_collection",
            "product_integration",
            "ios_runtime",
            "android_runtime",
            "user_validation",
            "personal_tax_result",
        }.issubset(not_accepted):
            errors.append("Batch12 acceptance limitations overclaim")

    if _normalized_workflow_digest(workflow_path) != EXPECTED_WORKFLOW_NORMALIZED:
        errors.append("Batch12 normalized workflow semantics drift")
    expected_workflow_bindings = {
        "EXPECTED_BATCH12_GUARD_SHA256": _digest(Path(__file__)),
        "EXPECTED_BATCH12_TESTS_SHA256": _digest(TESTS),
        "EXPECTED_BATCH12_ACCEPTANCE_SHA256": _digest(acceptance_path),
    }
    for name, expected in expected_workflow_bindings.items():
        if _workflow_trust_binding(workflow_path, name) != expected:
            errors.append(f"Batch12 workflow trust binding drift: {name}")

    snapshot, manifest_errors = validate_manifest(manifest_path, cas_root=cas_root)
    errors.extend(f"Batch12 manifest: {error}" for error in manifest_errors)
    if snapshot is None:
        return errors
    if (snapshot.accepted_commit, snapshot.accepted_tree, snapshot.closure_count) != (
        EXPECTED_COMMIT,
        EXPECTED_TREE,
        EXPECTED_CLOSURE,
    ):
        errors.append("Batch12 manifest commit, tree or closure drift")
    entries = {entry.path: entry for entry in snapshot.entries}
    for entry in snapshot.entries:
        archived = cas_root / entry.sha256
        if _digest(archived) != entry.sha256:
            errors.append(f"Batch12 accepted CAS blob missing or drifted: {entry.path}")

    for locale in LOCALES:
        for relative in (
            f"lib/l10n/app_{locale}.arb",
            f"lib/l10n/generated/mint_next_localizations_{locale}.dart",
        ):
            entry = entries.get(relative)
            if entry is None or resolve_entry(snapshot, entry, cas_root) is None:
                errors.append(f"Batch12 accepted locale artifact missing: {relative}")

    required_files = {
        "lib/design_lab_app.dart",
        "lib/ordinary_chf_amount.dart",
        "lib/provider_label.dart",
        "test/design_lab_contributed_amount_navigation_test.dart",
        "test/ordinary_chf_amount_test.dart",
        "test/provider_label_test.dart",
    }
    if not required_files.issubset(entries):
        errors.append("Batch12 runtime or hostile-test closure incomplete")

    app_entry = entries.get("lib/design_lab_app.dart")
    app = resolve_entry(snapshot, app_entry, cas_root) if app_entry else None
    source = app.read_text(encoding="utf-8") if app else ""
    required_bindings = {
        "fact_contributed_amount",
        "action:fact_contributed_amount.continue",
        "action:fact_contributed_amount.toggle_where_to_find",
        "action:fact_contributed_amount.unknown_amount",
        "action:fact_contributed_amount.missing_amount",
        "action:fact_contributed_amount.correct_previous",
        "action:contributed_amount_unknown_help.back",
        "action:fact_canton.back",
        "batch12PositiveCantonTitle",
        "providerLabelIsSafe",
        "parseOrdinaryChfAmount",
        "_multipleProvidersDeclared",
    }
    for binding in sorted(required_bindings):
        if binding not in source:
            errors.append(f"Batch12 Flutter binding missing: {binding}")
    forbidden_claims = {
        "Ajouter un prestataire",
        "Supprimer un prestataire",
        "MINT additionne les montants",
    }
    for claim in forbidden_claims:
        if claim in source:
            errors.append(f"Batch12 forbidden multi-provider claim/control: {claim}")

    try:
        receipt = yaml.safe_load(receipt_path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"Batch12 runtime receipt unreadable: {exc}")
        return errors
    if not isinstance(receipt, dict) or receipt.get("status") != "candidate_runtime_evidence_not_promotion":
        errors.append("Batch12 receipt overclaims promotion")
        return errors
    if receipt.get("viewport") != {"width": 390, "height": 844, "device_scale_factor": 1}:
        errors.append("Batch12 runtime viewport drift")
    if app_entry is None or receipt.get("app", {}).get("sha256") != app_entry.sha256:
        errors.append("Batch12 receipt/app binding drift")
    if receipt.get("probe", {}).get("sha256") != EXPECTED_PROBE_SHA256:
        errors.append("Batch12 receipt/probe binding drift")
    if receipt.get("navigation", {}).get("sha256") != EXPECTED_NAVIGATION_SHA256:
        errors.append("Batch12 receipt/navigation binding drift")
    required_limitations = {
        "single_provider_only",
        "multi_provider_collection_not_accepted",
        "not_product_integrated",
        "ios_not_run",
        "android_not_run",
        "external_ci_not_run",
        "user_not_validated",
        "no_personal_tax_result",
        "no_persisted_user_fact",
        "chrome_probe_narrower_than_hostile_widget_suite",
        "provider_identifier_screening_is_heuristic",
    }
    if set(receipt.get("limitations", [])) != required_limitations:
        errors.append("Batch12 runtime limitations drift")

    captures = receipt.get("captures")
    seen: set[str] = set()
    for item in captures if isinstance(captures, list) else []:
        path_value = item.get("path") if isinstance(item, dict) else None
        name = Path(path_value).name if isinstance(path_value, str) else ""
        expected = EXPECTED_CAPTURE_HASHES.get(name)
        path = ROOT / path_value if isinstance(path_value, str) else ROOT / "missing"
        data = path.read_bytes() if path.is_file() else b""
        seen.add(name)
        if expected is None or item.get("sha256") != expected or hashlib.sha256(data).hexdigest() != expected:
            errors.append(f"Batch12 runtime capture hash drift: {name}")
        if item.get("width") != 390 or item.get("height") != 844:
            errors.append(f"Batch12 runtime capture receipt dimensions drift: {name}")
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (390, 844):
            errors.append(f"Batch12 runtime capture file dimensions drift: {name}")
    if seen != set(EXPECTED_CAPTURE_HASHES):
        errors.append("Batch12 runtime capture set incomplete or duplicated")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("FAIL mint_next_batch12_amount_runtime_guard:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("OK mint_next_batch12_amount_runtime_guard: exact single-provider amount candidate, offline snapshot and Chrome evidence verified; multi-provider remains unaccepted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
