#!/usr/bin/env python3
"""Verify the hidden Batch16B classification and sibling transaction model."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "product/mint_next/batch7/design_lab"
MODEL = LAB / "lib/multi_provider_amount_draft.dart"
TESTS = LAB / "test/multi_provider_classification_test.dart"
SIBLING_TESTS = LAB / "test/multi_provider_unresolved_siblings_test.dart"
EXISTING_MODEL_TESTS = LAB / "test/multi_provider_amount_draft_test.dart"
EDITOR = LAB / "lib/multi_provider_amount_editor.dart"
DESIGN_APP = LAB / "lib/design_lab_app.dart"
ENTRYPOINT = LAB / "lib/main.dart"
RUNTIME_TESTS = LAB / "test/design_lab_multi_provider_runtime_test.dart"
RECEIPT = ROOT / "product/mint_next/batch16/model-groundwork-acceptance.yaml"
LEFTHOOK = ROOT / "lefthook.yml"
WORKFLOW = ROOT / ".github/workflows/mint-next-batch16-runtime.yml"
GUARD = ROOT / "tools/checks/mint_next_batch16_classification_model_guard.py"
GUARD_TESTS = ROOT / "tools/checks/tests/test_mint_next_batch16_classification_model_guard.py"

REQUIRED_TESTS = (
    "unresolved remains provisional but blocks review and commit",
    "global review is the only transition to confirmed ordinary",
    "amount edit resets only its row and retires the old help origin",
    "remove and undo preserve classification but retire help actions",
    "finalize and purge erase classification and make actions stale",
    "name edit and a second doubt retire every earlier resolution",
    "uncheck retires an unresolved origin without changing the amount",
    "remove and undo preserve confirmed ordinary classification",
)

REQUIRED_SIBLING_TESTS = (
    "doubt issues distinct provider refund and all-zero siblings",
    "provider total resolution consumes every sibling atomically",
    "eligible refund tombstones exact origin and preserves every other row",
    "simultaneous origins never cross-target or consume the other row",
    "provider-total on one origin leaves the other refund valid",
    "ineligible refund is a no-op and consumes nothing",
    "all-zero correction entry preserves origin siblings and amount",
    "external removal invalidates siblings and undo never revives them",
    "new doubt creates fresh siblings and every old sibling stays stale",
    "provider and amount edits retire every sibling before mutation",
    "purge makes every sibling permanently stale",
)


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def _construct_unique_mapping(loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    mapping: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.YAMLError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping)


def _load_yaml(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)


def validate_static(root: Path = ROOT) -> list[str]:
    lab = root / "product/mint_next/batch7/design_lab"
    model = lab / "lib/multi_provider_amount_draft.dart"
    tests = lab / "test/multi_provider_classification_test.dart"
    sibling_tests = lab / "test/multi_provider_unresolved_siblings_test.dart"
    editor = lab / "lib/multi_provider_amount_editor.dart"
    design_app = lab / "lib/design_lab_app.dart"
    entrypoint = lab / "lib/main.dart"
    receipt_path = root / "product/mint_next/batch16/model-groundwork-acceptance.yaml"
    lefthook_path = root / "lefthook.yml"
    workflow_path = root / ".github/workflows/mint-next-batch16-runtime.yml"
    guard_path = root / "tools/checks/mint_next_batch16_classification_model_guard.py"
    guard_tests_path = root / "tools/checks/tests/test_mint_next_batch16_classification_model_guard.py"
    errors: list[str] = []
    for path in (model, tests, sibling_tests, editor, design_app, entrypoint, receipt_path, lefthook_path, workflow_path, guard_path, guard_tests_path):
        if not path.is_file():
            errors.append(f"missing {path.relative_to(root)}")
    if errors:
        return errors

    source = model.read_text(encoding="utf-8")
    test_source = tests.read_text(encoding="utf-8")
    sibling_test_source = sibling_tests.read_text(encoding="utf-8")
    try:
        receipt = _load_yaml(receipt_path)
    except yaml.YAMLError as exc:
        return [f"invalid receipt YAML: {exc}"]

    expected_receipt_keys = {
        "schema_version",
        "batch",
        "status",
        "contract_ref",
        "runtime_surface",
        "product_promotion",
        "full_batch16_runtime_acceptance",
        "red_test_commit",
        "exact_files",
        "accepted_behavior",
        "explicitly_not_implemented",
        "roast_receipt",
        "proofs",
    }
    if set(receipt) != expected_receipt_keys:
        errors.append("model receipt top-level schema drifted")
    if receipt.get("schema_version") != 1:
        errors.append("model receipt schema version drifted")
    if receipt.get("batch") != "16B":
        errors.append("model receipt batch identity drifted")
    if receipt.get("contract_ref") != "product/mint_next/batch16/classification-doubt-scope.yaml":
        errors.append("model receipt contract linkage drifted")

    for symbol in (
        "enum MultiProviderAmountClassification",
        "confirmedOrdinary",
        "markAmountUnresolved",
        "resolveProviderReportedTotal",
        "MultiProviderUnresolvedResolveToken",
        "MultiProviderUnresolvedRefundToken",
        "MultiProviderUnresolvedAllZeroToken",
        "refundFullyProvider",
        "beginAllProvidersZeroCorrection",
    ):
        if symbol not in source:
            errors.append(f"classification model symbol missing: {symbol}")
    for name in REQUIRED_TESTS:
        if not re.search(rf"(?m)^\s*test\('{re.escape(name)}'", test_source):
            errors.append(f"required executable model test missing: {name}")
    for name in REQUIRED_SIBLING_TESTS:
        if not re.search(rf"(?m)^\s*test\(?'?\s*'{re.escape(name)}'", sibling_test_source):
            errors.append(f"required executable sibling test missing: {name}")
    if "skip:" in test_source or "skip:" in sibling_test_source:
        errors.append("classification or sibling model tests may not be skipped")
    exact_files = receipt.get("exact_files", {})
    if set(exact_files) != {
        "model",
        "model_sha256",
        "classification_tests",
        "classification_tests_sha256",
        "sibling_tests",
        "sibling_tests_sha256",
        "prior_model_tests_sha256",
        "prior_widget_runtime_tests_sha256",
        "unchanged_editor_sha256",
        "unchanged_design_app_sha256",
        "unchanged_entrypoint_sha256",
    }:
        errors.append("model receipt exact-files schema drifted")
    if exact_files.get("model") != "product/mint_next/batch7/design_lab/lib/multi_provider_amount_draft.dart":
        errors.append("model receipt path drifted")
    if exact_files.get("classification_tests") != "product/mint_next/batch7/design_lab/test/multi_provider_classification_test.dart":
        errors.append("classification test receipt path drifted")
    if exact_files.get("sibling_tests") != "product/mint_next/batch7/design_lab/test/multi_provider_unresolved_siblings_test.dart":
        errors.append("sibling test receipt path drifted")
    for path, expected_key in (
        (editor, "unchanged_editor_sha256"),
        (design_app, "unchanged_design_app_sha256"),
        (entrypoint, "unchanged_entrypoint_sha256"),
    ):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != exact_files.get(expected_key):
            errors.append(f"Batch16B UI boundary drifted: {path.relative_to(root)}")
    for path, expected_key in (
        (model, "model_sha256"),
        (tests, "classification_tests_sha256"),
        (sibling_tests, "sibling_tests_sha256"),
        (lab / "test/multi_provider_amount_draft_test.dart", "prior_model_tests_sha256"),
        (lab / "test/design_lab_multi_provider_runtime_test.dart", "prior_widget_runtime_tests_sha256"),
    ):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != exact_files.get(expected_key):
            errors.append(f"Batch16B accepted model proof drifted: {path.relative_to(root)}")
    if receipt.get("status") != "accepted_hidden_sibling_transaction_groundwork_only":
        errors.append("model receipt status drifted")
    if receipt.get("red_test_commit") != "b4345742b":
        errors.append("red-first test commit identity drifted")
    if receipt.get("runtime_surface") != "no_new_control_or_route":
        errors.append("model receipt falsely claims a runtime surface")
    if receipt.get("product_promotion") != "forbidden":
        errors.append("hidden model groundwork promoted to product prematurely")
    if receipt.get("full_batch16_runtime_acceptance") != "forbidden":
        errors.append("full Batch16 runtime accepted prematurely")
    if receipt.get("accepted_behavior") != {
        "states": ["unreviewed", "confirmedOrdinary", "unresolved"],
        "sibling_tokens": "distinct_provider_total_refund_and_all_zero_tokens_per_fresh_origin",
        "provider_total": "consumes_origin_and_all_siblings_then_returns_same_row_to_unreviewed_without_changing_amount",
        "refund_success": "validates_every_guard_before_consumption_then_uses_exact_captured_remove_token_and_tombstones_origin",
        "refund_failed_validation": "no_op_and_consume_nothing",
        "all_zero_entry": "validates_same_origin_without_mutation_consumption_zero_or_status_inference",
        "unresolved": "included_in_provisional_subtotal_but_blocks_review_and_commit",
        "confirmed_ordinary_only_by": "successful_global_review",
        "remove_undo": "preserve_exact_classification_but_never_revive_old_siblings",
        "finalize_purge": "erase_classification_origin_and_siblings",
        "stale_actions": "no_op",
    }:
        errors.append("accepted hidden-model behavior drifted")
    if receipt.get("explicitly_not_implemented") != [
        "unresolved_help_UI",
        "refund_help_UI",
        "all_zero_correction_route_and_status_choice",
        "education_navigation_binding",
        "six_locale_copy",
        "runtime_guard_or_runtime_acceptance",
        "product_route",
    ]:
        errors.append("hidden-only exclusions drifted")
    expected_roast = "accepted_p1_0_p2_0_p3_0"
    if receipt.get("roast_receipt") != {
        "ux": expected_roast,
        "swiss": expected_roast,
        "adversarial": expected_roast,
    }:
        errors.append("model roast receipt is not exact-zero for all roles")
    if receipt.get("proofs") != {
        "classification_tests": len(REQUIRED_TESTS),
        "sibling_transaction_tests": len(REQUIRED_SIBLING_TESTS),
        "combined_model_tests": 37,
        "combined_model_and_widget_runtime_tests": 70,
        "flutter_analyze": "clean",
        "guard": "tools/checks/mint_next_batch16_classification_model_guard.py",
        "guard_tests": "tools/checks/tests/test_mint_next_batch16_classification_model_guard.py",
        "lefthook_key": "mint-next-batch16-classification-model-guard",
        "ci_workflow": ".github/workflows/mint-next-batch16-runtime.yml",
    }:
        errors.append("model proof receipt drifted")

    try:
        lefthook_data = _load_yaml(lefthook_path)
    except yaml.YAMLError as exc:
        errors.append(f"invalid lefthook YAML: {exc}")
        lefthook_data = {}
    if set(lefthook_data) != {"min_version", "pre-commit", "pre-push", "skip"}:
        errors.append("lefthook top-level schema drifted")
    if lefthook_data.get("min_version") != "2.1.5":
        errors.append("lefthook minimum version drifted")
    if lefthook_data.get("skip") != ["merge", "rebase"]:
        errors.append("lefthook global skip policy drifted")
    pre_commit = lefthook_data.get("pre-commit", {})
    if not isinstance(pre_commit, dict) or set(pre_commit) != {"parallel", "commands"}:
        errors.append("pre-commit hook schema drifted or can be skipped")
    if isinstance(pre_commit, dict) and pre_commit.get("parallel") is not False:
        errors.append("pre-commit execution mode drifted")
    commands = pre_commit.get("commands", {}) if isinstance(pre_commit, dict) else {}
    hook = commands.get("mint-next-batch16-classification-model-guard")
    if (
        not isinstance(hook, dict)
        or set(hook) != {"run", "tags"}
        or hook.get("run") != "python3 tools/checks/mint_next_batch16_classification_model_guard.py"
        or hook.get("tags") != ["agents", "mint-next", "model", "flutter", "privacy"]
    ):
        errors.append("model lefthook binding missing or disabled")

    workflow = workflow_path.read_text(encoding="utf-8")
    try:
        workflow_data = _load_yaml(workflow_path)
    except yaml.YAMLError as exc:
        errors.append(f"invalid workflow YAML: {exc}")
        workflow_data = {}
    if set(workflow_data) != {"name", True, "concurrency", "permissions", "env", "jobs"}:
        errors.append("model CI top-level schema drifted")
    if workflow_data.get(True) != {
        "pull_request": {"branches": ["dev", "staging", "main"]},
        "push": {"branches": ["dev", "staging", "main"]},
    }:
        errors.append("model CI trigger drifted")
    jobs = workflow_data.get("jobs", {})
    required_job_commands = {
        "hidden-model-trust": (
            "python3 tools/checks/mint_next_batch16_classification_model_guard.py --static-only",
            "python3 -m unittest tools.checks.tests.test_mint_next_batch16_classification_model_guard",
        ),
        "hidden-model-flutter": (
            "python3 tools/checks/mint_next_batch16_classification_model_guard.py",
        ),
    }
    expected_job_identity = {
        "hidden-model-trust": ("Hidden classification model trust unit", "ubuntu-latest"),
        "hidden-model-flutter": ("Hidden classification model Flutter proof", "ubuntu-latest"),
    }
    expected_steps = {
        "hidden-model-trust": [
            {"uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"},
            {
                "uses": "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065b",
                "with": {"python-version": "3.11"},
            },
            {
                "name": "Install exact guard dependency",
                "run": "python3 -m pip install PyYAML==6.0.2",
            },
            {
                "name": "Verify hidden-model trust files",
                "run": (
                    'test "$(shasum -a 256 tools/checks/mint_next_batch16_classification_model_guard.py | cut -d \' \' -f 1)" = "$EXPECTED_BATCH16_MODEL_GUARD_SHA256"\n'
                    'test "$(shasum -a 256 tools/checks/tests/test_mint_next_batch16_classification_model_guard.py | cut -d \' \' -f 1)" = "$EXPECTED_BATCH16_MODEL_GUARD_TESTS_SHA256"\n'
                    'test "$(shasum -a 256 product/mint_next/batch16/model-groundwork-acceptance.yaml | cut -d \' \' -f 1)" = "$EXPECTED_BATCH16_MODEL_RECEIPT_SHA256"\n'
                ),
            },
            {
                "name": "Verify hidden-only model boundary",
                "run": "python3 tools/checks/mint_next_batch16_classification_model_guard.py --static-only",
            },
            {
                "name": "Fire hostile hidden-model mutations",
                "run": "python3 -m unittest tools.checks.tests.test_mint_next_batch16_classification_model_guard",
            },
        ],
        "hidden-model-flutter": [
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
                "name": "Verify hidden classification model and all prior model behavior",
                "run": "python3 tools/checks/mint_next_batch16_classification_model_guard.py",
            },
        ],
    }
    for job_name, commands in required_job_commands.items():
        job = jobs.get(job_name)
        if not isinstance(job, dict):
            errors.append(f"model CI job missing: {job_name}")
            continue
        if set(job) != {"name", "runs-on", "steps"}:
            errors.append(f"model CI job schema drifted: {job_name}")
        expected_name, expected_runner = expected_job_identity[job_name]
        if job.get("name") != expected_name or job.get("runs-on") != expected_runner:
            errors.append(f"model CI job identity or runner drifted: {job_name}")
        if "if" in job:
            errors.append(f"model CI job may not be conditional: {job_name}")
        if "continue-on-error" in job:
            errors.append(f"model CI job may not soft-fail: {job_name}")
        steps = job.get("steps", [])
        if steps != expected_steps[job_name]:
            errors.append(f"model CI step sequence or schema drifted: {job_name}")
        for command in commands:
            matches = [
                step
                for step in steps
                if isinstance(step, dict) and step.get("run") == command
            ]
            if len(matches) != 1:
                errors.append(f"model CI command missing or duplicated in {job_name}: {command}")
            elif "if" in matches[0] or "continue-on-error" in matches[0]:
                errors.append(f"model CI proof step may not be conditional or soft-fail: {command}")

    trust_job = jobs.get("hidden-model-trust", {})
    trust_steps = trust_job.get("steps", []) if isinstance(trust_job, dict) else []
    trust_matches = [
        step
        for step in trust_steps
        if isinstance(step, dict) and step.get("name") == "Verify hidden-model trust files"
    ]
    if len(trust_matches) != 1:
        errors.append("model CI trust-file verification step missing or duplicated")
    else:
        trust_step = trust_matches[0]
        trust_run = trust_step.get("run", "")
        if "if" in trust_step or "continue-on-error" in trust_step:
            errors.append("model CI trust-file verification may not be conditional or soft-fail")
        for env_key in (
            "EXPECTED_BATCH16_MODEL_GUARD_SHA256",
            "EXPECTED_BATCH16_MODEL_GUARD_TESTS_SHA256",
            "EXPECTED_BATCH16_MODEL_RECEIPT_SHA256",
        ):
            if f'"${env_key}"' not in trust_run:
                errors.append(f"model CI trust-file verification omits {env_key}")
    workflow_env = workflow_data.get("env", {})
    if set(workflow_env) != {
        "EXPECTED_BATCH16_SCOPE_GUARD_SHA256",
        "EXPECTED_BATCH16_SCOPE_TESTS_SHA256",
        "EXPECTED_BATCH16_ACCEPTANCE_SHA256",
        "EXPECTED_BATCH16_MODEL_GUARD_SHA256",
        "EXPECTED_BATCH16_MODEL_GUARD_TESTS_SHA256",
        "EXPECTED_BATCH16_MODEL_RECEIPT_SHA256",
    }:
        errors.append("model CI environment schema drifted")
    for path, env_key in (
        (guard_path, "EXPECTED_BATCH16_MODEL_GUARD_SHA256"),
        (guard_tests_path, "EXPECTED_BATCH16_MODEL_GUARD_TESTS_SHA256"),
        (receipt_path, "EXPECTED_BATCH16_MODEL_RECEIPT_SHA256"),
    ):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if workflow_env.get(env_key) != digest:
            errors.append(f"model CI trust hash stale: {path.relative_to(root)}")
    return errors


def _clean_flutter_env() -> dict[str, str]:
    env = os.environ.copy()
    for name in (
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_PREFIX",
    ):
        env.pop(name, None)
    return env


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--static-only", action="store_true")
    args = parser.parse_args()
    errors = validate_static()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    if not args.static_only:
        for command in (
            ["flutter", "analyze"],
            ["flutter", "test", "--no-pub", str(EXISTING_MODEL_TESTS), str(TESTS), str(SIBLING_TESTS), str(RUNTIME_TESTS)],
        ):
            result = subprocess.run(command, cwd=LAB, env=_clean_flutter_env(), check=False)
            if result.returncode:
                return result.returncode
    print("OK mint_next_batch16_classification_model_guard: hidden sibling transaction groundwork only.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
