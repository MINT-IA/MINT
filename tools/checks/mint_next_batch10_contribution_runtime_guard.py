#!/usr/bin/env python3
"""Verify the exact accepted Batch 10 contribution runtime package and evidence."""

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
from tools.checks.mint_next_batch9_contribution_scope_guard import validate as validate_scope

LAB = ROOT / "product/mint_next/batch7/design_lab"
APP = LAB / "lib/design_lab_app.dart"
L10N = LAB / "lib/l10n"
MANIFEST = ROOT / "product/mint_next/batch10/design-lab-manifest.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch10/design-lab-acceptance.yaml"
RECEIPT = ROOT / "product/mint_next/batch10/evidence/runtime/receipt.yaml"
PROBE = ROOT / "tools/checks/mint_next_batch10_contribution_runtime_probe.py"
WORKFLOW = ROOT / ".github/workflows/ai-workflow-guards.yml"
TRUST_WORKFLOW = ROOT / ".github/workflows/mint-next-batch10-runtime.yml"
TESTS = ROOT / "tools/checks/tests/test_mint_next_batch10_contribution_runtime_guard.py"
BATCH8_ACCEPTANCE = ROOT / "product/mint_next/batch8/design-lab-acceptance.yaml"

EXPECTED = {
    MANIFEST: "0df9b96df97c46b250b23bcf27185b54d3045648126ef7ca13f96b9d42c69ec6",
    ACCEPTANCE: "1e68c8401fb21ad1f42e10d3d63ecb610bae375bf96a215dbf650e2678862037",
    RECEIPT: "30bfd072d365f3786b27800de47392b711143f0dd9ddcb2b26a55ecb7b6642d9",
    PROBE: "e17e58061a57fae242b26e6dc7cbd6a687c42aec87cbad65a12cda8b4e67726a",
    BATCH8_ACCEPTANCE: "108817ab4424897efc78a8e22e6928473cace44c76fb86fee7ae1f23fae48add",
}
EXPECTED_WORKFLOW_CONTRACT = "1e62a698bb551dbbd13126d484290cbf264bd317b7cc3109017775ebb40bbd6c"
EXPECTED_TRUST_WORKFLOW_NORMALIZED = "02e592723709606119902a8078937e25aae498d5ec06fd6054377664733931a8"
EXPECTED_COMMIT = "e10daa4e6f431ea4807ad30d79065fda1a777f53"
EXPECTED_TREE = "a44bfa00fe215b6da0d185f1d4a49d95158fa808"
EXPECTED_CAPTURE_HASHES = {
    "fr_contribution_question_chrome_390.png": "82821afdad75b2a08aecc75bf2a79671b261c1fcb41494c81de9fe97fa771708",
    "fr_contribution_disclosure_chrome_390.png": "ed473c5f933b44b2a7d1acb7ba48231444a3f512c2192a0b8e6091466b858836",
    "fr_contribution_unknown_chrome_390.png": "3807e1b956ca31b7ca9f718d6ee824900a20244207f8306cf8ee97c3b6e84f9c",
    "fr_contribution_no_boundary_chrome_390.png": "6c9c63ef3e9c6cea1134e75a316a9671914b43ef7d002c808d6bf4d047a84b5d",
    "fr_contribution_yes_boundary_chrome_390.png": "8178ea797b627aa1cbbecf625be4421c9fe7c2d4dc973670601dd5a072fc3826",
}
LOCALES = ("fr", "en", "de", "it", "es", "pt")


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def _normalized_trust_workflow_digest(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    normalized = re.sub(
        r"(?m)^(  EXPECTED_BATCH10_(?:GUARD|TESTS|ACCEPTANCE)_SHA256:) .+$",
        r"\1 <BOUND>",
        text,
    )
    return hashlib.sha256(normalized.encode()).hexdigest()


def _trust_binding(path: Path, name: str) -> str | None:
    match = re.search(
        rf"(?m)^  {re.escape(name)}: ([0-9a-f]{{64}})$",
        path.read_text(encoding="utf-8"),
    )
    return match.group(1) if match else None


def validate(
    *,
    app_path: Path = APP,
    l10n_path: Path = L10N,
    receipt_path: Path = RECEIPT,
    acceptance_path: Path = ACCEPTANCE,
    workflow_path: Path = WORKFLOW,
    trust_workflow_path: Path = TRUST_WORKFLOW,
    manifest_path: Path = MANIFEST,
    cas_root: Path = DEFAULT_CAS,
) -> list[str]:
    errors = validate_scope()
    supplied = {
        MANIFEST: manifest_path,
        ACCEPTANCE: acceptance_path,
        RECEIPT: receipt_path,
        PROBE: PROBE,
        BATCH8_ACCEPTANCE: BATCH8_ACCEPTANCE,
    }
    for canonical, actual in supplied.items():
        if _digest(actual) != EXPECTED[canonical]:
            errors.append(f"Batch10 exact accepted artifact drift: {canonical.relative_to(ROOT)}")
    trust_workflow_exists = trust_workflow_path.is_file()
    if (
        not trust_workflow_exists
        or _normalized_trust_workflow_digest(trust_workflow_path)
        != EXPECTED_TRUST_WORKFLOW_NORMALIZED
    ):
        errors.append("Batch10 trust workflow normalized contract drift")
    if trust_workflow_exists and (
        _trust_binding(trust_workflow_path, "EXPECTED_BATCH10_GUARD_SHA256")
        != _digest(Path(__file__))
        or _trust_binding(trust_workflow_path, "EXPECTED_BATCH10_TESTS_SHA256")
        != _digest(TESTS)
        or _trust_binding(trust_workflow_path, "EXPECTED_BATCH10_ACCEPTANCE_SHA256")
        != _digest(acceptance_path)
    ):
        errors.append("Batch10 verifier trust-unit binding drift")

    snapshot, manifest_errors = validate_manifest(manifest_path, cas_root=cas_root)
    errors.extend(f"Batch10 manifest: {error}" for error in manifest_errors)
    if snapshot is None:
        return errors
    if (snapshot.accepted_commit, snapshot.accepted_tree, snapshot.closure_count) != (
        EXPECTED_COMMIT,
        EXPECTED_TREE,
        43,
    ):
        errors.append("Batch10 manifest commit, tree or closure drift")
    entries = {entry.path: entry for entry in snapshot.entries}
    for entry in snapshot.entries:
        archived = cas_root / entry.sha256
        if _digest(archived) != entry.sha256:
            errors.append(f"Batch10 accepted CAS blob missing or drifted: {entry.path}")

    app_entry = entries.get("lib/design_lab_app.dart")
    accepted_app = resolve_entry(snapshot, app_entry, cas_root) if app_entry is not None else None
    checked_app = accepted_app if app_path == APP else app_path
    if app_entry is None or checked_app is None or _digest(checked_app) != app_entry.sha256:
        errors.append("Batch10 exact Flutter app bytes drift")

    for locale in LOCALES:
        relative = f"lib/l10n/app_{locale}.arb"
        entry = entries.get(relative)
        supplied_locale = l10n_path / f"app_{locale}.arb"
        checked = resolve_entry(snapshot, entry, cas_root) if l10n_path == L10N and entry is not None else supplied_locale
        if entry is None or checked is None or _digest(checked) != entry.sha256:
            errors.append(f"Batch10 exact {locale} ARB bytes drift")
        generated_relative = f"lib/l10n/generated/mint_next_localizations_{locale}.dart"
        generated_entry = entries.get(generated_relative)
        if generated_entry is None or resolve_entry(snapshot, generated_entry, cas_root) is None:
            errors.append(f"Batch10 exact {locale} generated localization missing")

    source = checked_app.read_text(encoding="utf-8") if checked_app is not None and checked_app.is_file() else ""
    required_bindings = {
        "fact_contribution",
        "contribution_unknown_help",
        "fact_contributed_amount",
        "fact_canton",
        "education_explanation",
        "action:fact_contribution.choose_yes",
        "action:fact_contribution.choose_no",
        "action:fact_contribution.choose_unknown",
        "action:fact_contribution.toggle_edge_help",
        "action:fact_contribution.back",
        "action:contribution_unknown_help.back",
        "action:contribution_unknown_help.continue_education_only",
        "action:fact_contributed_amount.back",
        "action:fact_canton.back",
        "action:education_explanation.back",
    }
    for binding in sorted(required_bindings):
        if binding not in source:
            errors.append(f"Batch10 Flutter binding missing: {binding}")

    try:
        receipt = yaml.safe_load(receipt_path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        errors.append(f"Batch10 runtime receipt unreadable: {exc}")
        return errors
    if receipt.get("status") != "corrected_candidate_runtime_evidence_not_promotion":
        errors.append("Batch10 runtime receipt status overclaims promotion")
    if receipt.get("captured_at") != "2026-08-03T00:01:51+02:00":
        errors.append("Batch10 runtime receipt capture provenance drift")
    if receipt.get("viewport") != {"width": 390, "height": 844, "device_scale_factor": 1}:
        errors.append("Batch10 runtime viewport receipt drift")
    if app_entry is None or receipt.get("app", {}).get("sha256") != app_entry.sha256:
        errors.append("Batch10 runtime receipt app binding drift")
    if receipt.get("probe", {}).get("sha256") != EXPECTED[PROBE]:
        errors.append("Batch10 runtime receipt probe binding drift")
    expected_limitations = {
        "corrected_candidate_not_yet_reroasted",
        "not_product_integrated",
        "ios_not_run",
        "android_not_run",
        "external_ci_not_run",
        "user_not_validated",
    }
    if set(receipt.get("limitations", [])) != expected_limitations:
        errors.append("Batch10 runtime receipt limitations drift")

    captures = receipt.get("captures", [])
    seen_names: set[str] = set()
    seen_paths: set[str] = set()
    seen_hashes: set[str] = set()
    for item in captures if isinstance(captures, list) else []:
        path_value = item.get("path")
        name = Path(path_value).name if isinstance(path_value, str) else ""
        expected_hash = EXPECTED_CAPTURE_HASHES.get(name)
        if not isinstance(path_value, str) or expected_hash is None:
            errors.append(f"Batch10 runtime capture identity drift: {path_value}")
            continue
        path = ROOT / path_value
        data = path.read_bytes() if path.is_file() else b""
        seen_names.add(name)
        seen_paths.add(path_value)
        seen_hashes.add(str(item.get("sha256")))
        if item.get("sha256") != expected_hash or hashlib.sha256(data).hexdigest() != expected_hash:
            errors.append(f"Batch10 runtime capture hash drift: {name}")
        if item.get("width") != 390 or item.get("height") != 844:
            errors.append(f"Batch10 runtime capture receipt dimensions drift: {name}")
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != (390, 844):
            errors.append(f"Batch10 runtime capture file dimensions drift: {name}")
    if seen_names != set(EXPECTED_CAPTURE_HASHES) or len(seen_paths) != 5 or len(seen_hashes) != 5:
        errors.append("Batch10 runtime capture set is incomplete or duplicated")

    try:
        workflow = yaml.safe_load(workflow_path.read_text(encoding="utf-8"))
        workflow_triggers = workflow.get("on", workflow.get(True))
        runtime_job = workflow["jobs"]["batch10-contribution-real-runtime"]
    except (OSError, KeyError, TypeError, yaml.YAMLError) as exc:
        errors.append(f"Batch10 real runtime CI job missing or unreadable: {exc}")
        runtime_job = None
        workflow = {}
        workflow_triggers = None
    guards_job = workflow.get("jobs", {}).get("guards", {}) if isinstance(workflow, dict) else {}
    guard_steps = guards_job.get("steps", []) if isinstance(guards_job, dict) else []
    named_guard_steps = {
        step.get("name"): step
        for step in guard_steps
        if isinstance(step, dict) and isinstance(step.get("name"), str)
    }
    batch10_guard_step = named_guard_steps.get(
        "MINT Next Batch 10 contribution runtime guard"
    )
    guard_tests_step = named_guard_steps.get("Guard tests")
    guard_tests_run = (
        str(guard_tests_step.get("run", ""))
        if isinstance(guard_tests_step, dict)
        else ""
    )
    workflow_contract = {
        "name": workflow.get("name") if isinstance(workflow, dict) else None,
        "triggers": workflow_triggers,
        "concurrency": workflow.get("concurrency") if isinstance(workflow, dict) else None,
        "runtime_job": runtime_job,
        "guards_job_keys": sorted(guards_job) if isinstance(guards_job, dict) else [],
        "guards_job_name": guards_job.get("name") if isinstance(guards_job, dict) else None,
        "guards_job_runs_on": guards_job.get("runs-on") if isinstance(guards_job, dict) else None,
        "batch10_guard_step": batch10_guard_step,
        "guard_tests_step_keys": (
            sorted(guard_tests_step) if isinstance(guard_tests_step, dict) else []
        ),
        "guard_tests_uses_pytest": "python3 -m pytest" in guard_tests_run,
        "guard_tests_wires_batch10": (
            "tools/checks/tests/test_mint_next_batch10_contribution_runtime_guard.py"
            in guard_tests_run
        ),
        "guard_tests_fail_closed": guard_tests_run.rstrip().endswith("-q"),
    }
    workflow_contract_digest = hashlib.sha256(
        json.dumps(
            workflow_contract,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    if workflow_contract_digest != EXPECTED_WORKFLOW_CONTRACT:
        errors.append("Batch10 normalized workflow contract drift")

    expected_job = {
        "name": "Batch 10 contribution real Flutter Web navigation",
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
                "name": "Traverse exact Batch 10 contribution routes in real Chrome",
                "run": "python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py",
            },
        ],
    }
    if runtime_job is not None and runtime_job != expected_job:
        errors.append("Batch10 real Chrome CI job permits skip, ignored failure or structural drift")
    if workflow_triggers != {
        "pull_request": {"branches": ["dev", "staging", "main"]},
        "push": {"branches": ["dev", "staging", "main"]},
    }:
        errors.append("Batch10 real Chrome CI triggers permit the runtime proof to be skipped")
    if not isinstance(workflow, dict) or set(workflow) != {"name", True, "concurrency", "jobs"}:
        errors.append("Batch10 workflow top-level defaults or environment can bypass the runtime proof")
    if workflow.get("concurrency") != {
        "group": "ai-workflow-guards-${{ github.ref }}",
        "cancel-in-progress": True,
    }:
        errors.append("Batch10 workflow concurrency can make the runtime proof invalid or non-runnable")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch10_contribution_runtime_guard: exact written routes, six-locale pipeline and runtime evidence verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
