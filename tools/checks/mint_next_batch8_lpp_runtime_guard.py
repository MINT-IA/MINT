#!/usr/bin/env python3
"""Verify the exact accepted Batch 8 LPP runtime package and evidence."""

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

from tools.checks.mint_next_artifact_manifest import DEFAULT_CAS, resolve_entry, validate_manifest
from tools.checks.mint_next_batch8_lpp_scope_guard import SCOPE, validate as validate_scope

LAB = ROOT / "product/mint_next/batch7/design_lab"
APP = LAB / "lib/design_lab_app.dart"
L10N = LAB / "lib/l10n"
MANIFEST = ROOT / "product/mint_next/batch8/design-lab-manifest.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch8/design-lab-acceptance.yaml"
RECEIPT = ROOT / "product/mint_next/batch8/evidence/runtime/receipt.yaml"
PROBE = ROOT / "tools/checks/mint_next_batch8_lpp_runtime_probe.py"
WORKFLOW = ROOT / ".github/workflows/ai-workflow-guards.yml"

EXPECTED = {
    MANIFEST: "b19348e8fd76a6ec77ce2864d097290300c31b77c23cff80a32b33279388413c",
    ACCEPTANCE: "108817ab4424897efc78a8e22e6928473cace44c76fb86fee7ae1f23fae48add",
    RECEIPT: "b374fbc551e8287ec66ba4daedd4de2c85c4ef6bc47ce106228a66aeb75fcfc8",
    PROBE: "a562a7daf3e0200c3560f2ba2b4aa2507cb55d71bbc1abf34e44f3bbbfd4389e",
    WORKFLOW: "4fb19568bf5d9b83a8f4251151de24c7e4aae08e14b559fac1a1c6158e40d20b",
}
EXPECTED_COMMIT = "d265dfdf46c1c3c8b1745a7d814d4e1b853521fc"
EXPECTED_TREE = "a18ff1a156cf83c47e3b94b913c0a8b5f0b95b74"
EXPECTED_CAPTURE_HASHES = {
    "fact_lpp_affiliation": "b857a8f604c343e33bff3a51299ee85273207d9b67f3a8a3ae465cc6b63e793b",
    "lpp_unknown_help": "bef5500492e2f0601ed20fb744a13229f6c43f565d81f6f62d3281918548259b",
    "without_lpp_boundary": "3ab85ee619f2cabea73342a8194b5a9b5d0e96e74c21acf0c8181bca0fa769ac",
}


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def validate(
    app_path: Path = APP,
    l10n_path: Path = L10N,
    receipt_path: Path = RECEIPT,
    acceptance_path: Path = ACCEPTANCE,
    workflow_path: Path = WORKFLOW,
) -> list[str]:
    errors = validate_scope()

    supplied = {
        MANIFEST: MANIFEST,
        ACCEPTANCE: acceptance_path,
        RECEIPT: receipt_path,
        PROBE: PROBE,
        WORKFLOW: workflow_path,
    }
    for canonical, actual in supplied.items():
        if _digest(actual) != EXPECTED[canonical]:
            errors.append(f"Batch8 exact accepted artifact drift: {canonical.relative_to(ROOT)}")

    snapshot, manifest_errors = validate_manifest(MANIFEST)
    errors.extend(f"Batch8 manifest: {error}" for error in manifest_errors)
    if snapshot is None:
        return errors
    if (snapshot.accepted_commit, snapshot.accepted_tree, snapshot.closure_count) != (
        EXPECTED_COMMIT,
        EXPECTED_TREE,
        42,
    ):
        errors.append("Batch8 manifest commit, tree or closure drift")
    entries = {entry.path: entry for entry in snapshot.entries}
    for entry in snapshot.entries:
        archived = DEFAULT_CAS / entry.sha256
        if _digest(archived) != entry.sha256:
            errors.append(f"Batch8 accepted CAS blob missing or drifted: {entry.path}")

    app_entry = entries.get("lib/design_lab_app.dart")
    accepted_app = resolve_entry(snapshot, app_entry) if app_entry is not None else None
    checked_app = accepted_app if app_path == APP else app_path
    if app_entry is None or checked_app is None or _digest(checked_app) != app_entry.sha256:
        errors.append("Batch8 exact Flutter app bytes drift")
    locales = yaml.safe_load(SCOPE.read_text(encoding="utf-8"))["slice"]["locales"]
    for locale in locales:
        relative = f"lib/l10n/app_{locale}.arb"
        entry = entries.get(relative)
        supplied_locale = l10n_path / f"app_{locale}.arb"
        checked_locale = resolve_entry(snapshot, entry) if l10n_path == L10N and entry is not None else supplied_locale
        if entry is None or checked_locale is None or _digest(checked_locale) != entry.sha256:
            errors.append(f"Batch8 exact {locale} ARB bytes drift")

    # Structural assertions remain useful diagnostics; exact digests are the authority.
    source = checked_app.read_text(encoding="utf-8") if checked_app is not None and checked_app.is_file() else ""
    required_bindings = {
        "fact_lpp_affiliation", "lpp_unknown_help", "without_lpp_boundary", "fact_contribution",
        "action:fact_tax_year.continue", "action:fact_lpp_affiliation.choose_yes",
        "action:fact_lpp_affiliation.choose_no", "action:fact_lpp_affiliation.choose_unknown",
        "action:fact_lpp_affiliation.back", "action:lpp_unknown_help.back",
        "action:lpp_unknown_help.keep_checklist_local", "action:without_lpp_boundary.back",
        "action:without_lpp_boundary.keep_explanation_local", "action:fact_contribution.back",
    }
    for binding in sorted(required_bindings):
        if binding not in source:
            errors.append(f"Batch8 Flutter binding missing: {binding}")

    try:
        data_by_locale = {
            locale: json.loads(
                (
                    resolve_entry(snapshot, entries[f"lib/l10n/app_{locale}.arb"])
                    if l10n_path == L10N
                    else l10n_path / f"app_{locale}.arb"
                ).read_text(encoding="utf-8")
            )
            for locale in locales
        }
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"Batch8 locale input unreadable: {exc}")
        data_by_locale = {}
    if data_by_locale:
        key_sets = [{key for key in data if not key.startswith("@")} for data in data_by_locale.values()]
        if any(keys != key_sets[0] for keys in key_sets[1:]):
            errors.append("Batch8 ARB keys differ across six locales")
        if re.search(r"(?:CHF|Fr\.|francs?|\d[’' ]?\d{3}|\d+\s*%)", " ".join(map(str, data_by_locale.values())), re.I):
            errors.append("Batch8 LPP slice leaks an amount, threshold or percentage")

    try:
        receipt = yaml.safe_load(receipt_path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"Batch8 runtime receipt unreadable: {exc}")
        return errors
    if receipt.get("viewport") != {"width": 390, "height": 844, "device_scale_factor": 1}:
        errors.append("Batch8 runtime viewport receipt drift")
    captures = receipt.get("captures", [])
    paths: list[str] = []
    hashes: list[str] = []
    for item in captures if isinstance(captures, list) else []:
        node = item.get("node")
        path_value = item.get("path")
        expected_hash = EXPECTED_CAPTURE_HASHES.get(node)
        if not isinstance(path_value, str) or expected_hash is None:
            errors.append(f"Batch8 runtime capture identity drift: {node}")
            continue
        paths.append(path_value)
        hashes.append(item.get("sha256"))
        path = ROOT / path_value
        data = path.read_bytes() if path.is_file() else b""
        if item.get("sha256") != expected_hash or hashlib.sha256(data).hexdigest() != expected_hash:
            errors.append(f"Batch8 runtime capture hash drift: {node}")
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (390, 844):
            errors.append(f"Batch8 runtime capture dimensions drift: {node}")
    if set(EXPECTED_CAPTURE_HASHES) != {item.get("node") for item in captures if isinstance(item, dict)}:
        errors.append("Batch8 runtime capture node set drift")
    if len(paths) != len(set(paths)) or len(hashes) != len(set(hashes)):
        errors.append("Batch8 runtime captures are not distinct")

    try:
        workflow = yaml.safe_load(workflow_path.read_text(encoding="utf-8"))
        workflow_triggers = workflow.get("on", workflow.get(True))
        runtime_job = workflow["jobs"]["batch8-lpp-real-runtime"]
        runtime_steps = runtime_job["steps"]
    except (OSError, KeyError, TypeError, yaml.YAMLError) as exc:
        errors.append(f"Batch8 real runtime CI job missing or unreadable: {exc}")
        runtime_steps = []
    expected_ci = {
        "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
        "subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2",
        "flutter pub get",
        "python3 tools/checks/mint_next_batch8_lpp_runtime_probe.py",
    }
    actual_ci = {
        str(step.get("uses") or step.get("run", "")).strip()
        for step in runtime_steps
        if isinstance(step, dict)
    }
    if not expected_ci.issubset(actual_ci):
        errors.append("Batch8 real Chrome probe is not mechanically enforced in CI")
    expected_job = {
        "name": "Batch 8 LPP real Flutter Web navigation",
        "runs-on": "ubuntu-latest",
        "steps": [
            {"uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"},
            {
                "uses": "subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2",
                "with": {"flutter-version": "3.44.8", "channel": "stable", "cache": True},
            },
            {
                "name": "Resolve isolated Design Lab dependencies",
                "working-directory": "product/mint_next/batch7/design_lab",
                "run": "flutter pub get",
            },
            {
                "name": "Traverse exact Batch 8 LPP routes in real Chrome",
                "run": "python3 tools/checks/mint_next_batch8_lpp_runtime_probe.py",
            },
        ],
    }
    if runtime_steps and runtime_job != expected_job:
        errors.append("Batch8 real Chrome CI job permits skip, ignored failure or structural drift")
    if workflow_triggers != {
        "pull_request": {"branches": ["dev", "staging", "main"]},
        "push": {"branches": ["dev", "staging", "main"]},
    }:
        errors.append("Batch8 real Chrome CI triggers permit the runtime proof to be skipped")
    if not isinstance(workflow, dict) or set(workflow) != {"name", True, "concurrency", "jobs"}:
        errors.append("Batch8 workflow top-level defaults or environment can bypass the runtime proof")
    if workflow.get("concurrency") != {
        "group": "ai-workflow-guards-${{ github.ref }}",
        "cancel-in-progress": True,
    }:
        errors.append("Batch8 workflow concurrency can make the runtime proof invalid or non-runnable")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch8_lpp_runtime_guard: exact written routes, six-locale package and runtime evidence verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
