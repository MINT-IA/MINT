#!/usr/bin/env python3
"""Fail closed when the write-only Batch 13 multi-provider contract drifts."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "product/mint_next/batch13/multi-provider-navigation-contract.yaml"
LEGACY = ROOT / "product/mint_next/batch13/legacy-inventory.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch13/multi-provider-navigation-acceptance.yaml"
WORKFLOW = ROOT / ".github/workflows/mint-next-batch13-contract.yml"
TESTS = ROOT / "tools/checks/tests/test_mint_next_batch13_multi_provider_contract_guard.py"
BASE_COMMIT = "ab810646fd6b70b280e517f2d163c8849f1c9c48"
ACCEPTED_CANDIDATE_COMMIT = "59b00b36aff8c13767d9b5c1f1b648cf353fe7f1"
ACCEPTED_CANDIDATE_TREE = "72c455c21a7777120785117516410d230e35fdaa"
EXPECTED_ARTIFACT_DIGESTS = {
    CONTRACT: "c609f4038842fdc51173e3009f95f8fa1fbd6351a87a24241aa2b3997ac6b282",
    LEGACY: "d0ef90cf1b973d48e202de87a88ad507bbd70381fe7cd7f9194051112a5dae85",
}
EXPECTED_AUTHORITY_DIGESTS = {
    ROOT / "product/mint_next/batch6/navigation.yaml": "461d8257b79c781b0ca1b11aa6d21f67d17ee387a9de0e17932c159eac469250",
    ROOT / "product/mint_next/batch11/ordinary-contribution-amount-scope.yaml": "1310c2d0192e2d1ded2e8555ccaa9b0624e0f1d1b3d206a95dfc47e83799f23c",
    ROOT / "product/mint_next/batch11/official-sources.yaml": "6ebc04d5edb92d8f437db1b6ce60ebae5daa187f294cdc3cdffbe2d934ce3741",
    ROOT / "product/mint_next/batch12/design-lab-acceptance.yaml": "542b1c223ac78ce2202a8981cc1f0f4223dc74e9947f5294b1cbf8693f943dc0",
}
EXPECTED_WORKFLOW_NORMALIZED_SHA256 = "558f4599b71f2e0c17f5e24c4fd5f84db43a510155267736dd67ceb7273de5d1"
EXPECTED_ACCEPTANCE_NORMALIZED_SHA256 = "529952879d545b9525bcbd1cd3f6e38fb77e2b904bc3b442cc44abf454c07f1b"

EXPECTED_PROOF_OBLIGATIONS = [
    "runtime_authorization",
    "any_dead_or_missing_back_route",
    "partial_or_unconfirmed_commit",
    "add_while_a_completely_empty_row_exists",
    "removing_the_only_row",
    "silent_destructive_remove_without_undo",
    "subtotal_as_tax_result_or_continue_enabler",
    "duplicate_provider_canonicalization",
    "unchecked_or_float_aggregate_overflow",
    "overflow_confirmation_or_ready_label",
    "duplicate_yaml_mapping_key",
    "identity_grade_deduplication_claim",
    "sensitive_identifier_collection_or_telemetry",
    "stale_confirmation_after_any_mutation",
    "stale_commit_after_unchecking_confirmation_or_declaring_missing_provider",
    "stale_remove_or_undo_callback_and_row_id_reuse",
    "remove_undo_remove_requires_fresh_generation_tokens_and_rejects_prior_callbacks",
    "remove_finalize_requires_distinct_preexposed_sibling_tokens_atomic_consumption_and_stale_sibling_no_op",
    "ordinary_or_bound_missing_empty_immediate_remove_leaves_tombstone_or_live_token_or_accepts_delayed_callback",
    "bound_missing_empty_immediate_remove_implicitly_reallocates_or_binds_before_explicit_recovery_activation",
    "retract_synthetic_missing_row_leaves_remove_token_row_id_or_delayed_callback_live",
    "bound_missing_empty_row_dispatches_through_ordinary_unbound_remove_branch",
    "active_row_count_confused_with_tombstone_count",
    "tombstone_lost_across_reversible_help_overlay_correction_or_education_route",
    "rendered_row_capacity_allocation_or_undo_bypass",
    "one_provider_full_refund_must_preserve_other_positive_provider_rows",
    "status_correction_requires_explicit_all_provider_zero_declaration",
    "unresolved_resolution_requires_fake_amount_edit_or_targets_wrong_row_id",
    "missing_provider_flag_survives_global_reconfirmation",
    "missing_request_double_bind_rebind_or_wrong_row_resolution",
    "repeated_pending_missing_activation_or_second_request_after_terminal_state",
    "deleting_the_missing_placeholder_silently_clears_missing_state",
    "tombstone_confirmation_or_continue_bypass",
    "finalize_remove_missing_copy_semantics_or_announcement",
    "capacity_freed_without_binding_pending_missing_request",
    "full_refund_route_missing_correction_entry_mode_or_ambiguously_mutating_row",
    "education_subgraph_loses_or_leaks_tombstone_and_personal_state",
    "stale_edit_or_focus_callback_recreates_finalized_row",
    "delayed_callback_after_status_tax_year_leave_app_kill_or_ttl_purge_recreates_or_mutates_state",
    "runtime_proof_omits_missing_request_finalize_capacity_or_exact_purge_paths",
    "pending_missing_recovery_label_accessible_name_or_state_focus_missing",
    "unallocated_under_capacity_recovery_focus_does_not_use_exact_bound_row_error_order",
    "at_capacity_recovery_with_tombstone_skips_first_finalize_for_education_escape",
    "missing_request_binding_nondeterministic_or_targets_unresolved_or_duplicate_row",
    "at_capacity_with_eligible_existing_row_fails_to_bind_without_allocation",
    "missing_control_bypasses_canonical_declaration_transition_order",
    "bound_row_becomes_filled_duplicate_unsafe_invalid_or_unresolved_and_recovery_focus_misses_exact_error",
    "full_refund_tombstone_fails_to_recompute_and_announce_exact_subtotal",
    "missing_retraction_drops_preexisting_row_or_keeps_synthetic_empty_placeholder",
    "missing_bound_tombstone_undo_or_finalize_strands_request",
    "bound_empty_missing_row_immediate_remove_strands_request",
    "missing_request_token_or_provenance_omitted_from_any_purge",
    "full_refund_callback_targets_retired_or_different_row_id",
    "repeated_full_refund_action_duplicates_or_retargets_tombstone",
    "unicode_equivalent_or_invisible_duplicate_bypass",
    "unknown_or_invalid_to_zero",
    "missing_status_tax_year_leave_or_app_kill_purge",
    "any_single_personal_state_purge_field_removed",
    "narrow_safe_exit_or_status_correction_purge_alias",
    "missing_safe_exit_education_or_correction_boundary_back_edge",
    "missing_six_locale_intent",
]


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def load(path: Path) -> dict:
    value = yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} root is not a mapping")
    return value


def normalized_workflow_digest(path: Path) -> str:
    normalized = re.sub(
        r"(?m)^(  EXPECTED_BATCH13_(?:GUARD|TESTS|ACCEPTANCE)_SHA256:) .+$",
        r"\1 <BOUND>",
        path.read_text(encoding="utf-8"),
    )
    return hashlib.sha256(normalized.encode()).hexdigest()


def workflow_binding(path: Path, name: str) -> str | None:
    match = re.search(rf"(?m)^  {re.escape(name)}: ([0-9a-f]{{64}})$", path.read_text(encoding="utf-8"))
    return match.group(1) if match else None


def normalized_acceptance_digest(acceptance: object) -> str:
    if not isinstance(acceptance, dict):
        return "invalid"
    normalized = json.loads(json.dumps(acceptance))
    for binding in normalized.get("verifier_trust_unit", {}).values():
        if isinstance(binding, dict) and "sha256" in binding:
            binding["sha256"] = "<BOUND>"
    workflow = normalized.get("ci_workflow")
    if isinstance(workflow, dict) and "normalized_sha256" in workflow:
        workflow["normalized_sha256"] = "<BOUND>"
    return hashlib.sha256(json.dumps(normalized, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _runtime_drift() -> list[str]:
    try:
        output = subprocess.run(
            ["git", "diff", "--name-only", BASE_COMMIT, ACCEPTED_CANDIDATE_COMMIT, "--", "product/mint_next/batch7/design_lab", "apps/mobile", "services/backend"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError:
        return ["git_diff_failed"]
    return [path for path in output if path]


def _candidate_tree() -> str:
    try:
        return subprocess.run(
            ["git", "show", "-s", "--format=%T", ACCEPTED_CANDIDATE_COMMIT],
            cwd=ROOT, check=True, capture_output=True, text=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        return "missing"


def validate(
    contract_path: Path = CONTRACT,
    legacy_path: Path = LEGACY,
    acceptance_path: Path = ACCEPTANCE,
    workflow_path: Path = WORKFLOW,
    *,
    check_runtime: bool = True,
) -> list[str]:
    errors: list[str] = []
    try:
        contract = load(contract_path)
        legacy = load(legacy_path)
        acceptance = load(acceptance_path)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        return [f"Batch13 contract unreadable: {exc}"]

    if digest(contract_path) != EXPECTED_ARTIFACT_DIGESTS[CONTRACT]:
        errors.append("Batch13 exact navigation contract drift")
    if digest(legacy_path) != EXPECTED_ARTIFACT_DIGESTS[LEGACY]:
        errors.append("Batch13 exact legacy inventory drift")
    for path, expected in EXPECTED_AUTHORITY_DIGESTS.items():
        if digest(path) != expected:
            errors.append(f"Batch13 authority drift: {path.relative_to(ROOT)}")
    if _candidate_tree() != ACCEPTED_CANDIDATE_TREE:
        errors.append("Batch13 accepted candidate tree drift or commit missing")
    if check_runtime and (drift := _runtime_drift()):
        errors.append(f"Batch13 write-only boundary violated by runtime drift: {','.join(drift)}")

    if contract.get("status") != "draft_written_runtime_contract_runtime_forbidden":
        errors.append("Batch13 write-only status drift")
    if contract.get("authority", {}).get("runtime_change") != "forbidden_until_this_contract_is_mechanically_accepted":
        errors.append("Batch13 runtime authorization drift")
    if contract.get("scope", {}).get("locales") != ["fr", "en", "de", "it", "es", "pt"]:
        errors.append("Batch13 exact six-locale scope drift")
    boundaries = contract.get("content_boundaries", {})
    if set(boundaries.values()) != {"forbidden"} or len(boundaries) != 8:
        errors.append("Batch13 forbidden implementation boundary drift")
    proof = contract.get("proof_contract", {})
    if proof.get("written_guard_must_reject") != EXPECTED_PROOF_OBLIGATIONS:
        errors.append("Batch13 hostile written-proof obligations drift")
    if proof.get("advisory_roasts") != ["ux_navigation_accessibility", "swiss_compliance_locale", "adversarial"] or proof.get("acceptance_threshold") != {"p1": 0, "p2": 0}:
        errors.append("Batch13 roast threshold drift")
    if proof.get("next_gate") != "isolated_multi_provider_runtime_only_after_written_acceptance" or proof.get("user_test_required") is not False:
        errors.append("Batch13 next-gate or user-test boundary drift")
    if legacy.get("capability_result") != {
        "dynamic_provider_rows": "absent",
        "add_remove": "absent",
        "checked_exact_aggregation": "absent",
        "duplicate_provider_rejection": "absent",
        "reusable_exact_per_row_parser": "present",
        "reusable_heuristic_identifier_screening": "present",
        "reusable_fixed_form_accessibility_patterns": "present_but_requires_dynamic_redesign",
    }:
        errors.append("Batch13 legacy capability conclusion drift")

    expected_artifacts = {
        "navigation_contract": {"path": "product/mint_next/batch13/multi-provider-navigation-contract.yaml", "sha256": EXPECTED_ARTIFACT_DIGESTS[CONTRACT]},
        "legacy_inventory": {"path": "product/mint_next/batch13/legacy-inventory.yaml", "sha256": EXPECTED_ARTIFACT_DIGESTS[LEGACY]},
    }
    if acceptance.get("accepted_candidate") != {"commit": ACCEPTED_CANDIDATE_COMMIT, "tree": ACCEPTED_CANDIDATE_TREE} or acceptance.get("artifacts") != expected_artifacts:
        errors.append("Batch13 acceptance artifact or candidate binding drift")
    expected_trust = {
        "guard": {"path": "tools/checks/mint_next_batch13_multi_provider_contract_guard.py", "sha256": digest(Path(__file__))},
        "tests": {"path": "tools/checks/tests/test_mint_next_batch13_multi_provider_contract_guard.py", "sha256": digest(TESTS)},
    }
    if acceptance.get("verifier_trust_unit") != expected_trust:
        errors.append("Batch13 acceptance verifier trust-unit drift")
    if normalized_acceptance_digest(acceptance) != EXPECTED_ACCEPTANCE_NORMALIZED_SHA256:
        errors.append("Batch13 normalized acceptance contract drift")
    if normalized_workflow_digest(workflow_path) != EXPECTED_WORKFLOW_NORMALIZED_SHA256:
        errors.append("Batch13 normalized workflow drift")
    if workflow_binding(workflow_path, "EXPECTED_BATCH13_GUARD_SHA256") != digest(Path(__file__)) or workflow_binding(workflow_path, "EXPECTED_BATCH13_TESTS_SHA256") != digest(TESTS) or workflow_binding(workflow_path, "EXPECTED_BATCH13_ACCEPTANCE_SHA256") != digest(acceptance_path):
        errors.append("Batch13 workflow verifier hash binding drift")
    if acceptance.get("ci_workflow") != {"path": ".github/workflows/mint-next-batch13-contract.yml", "normalized_sha256": EXPECTED_WORKFLOW_NORMALIZED_SHA256, "verification": "exact_job_triggers_permissions_commands_and_verifier_hashes"}:
        errors.append("Batch13 acceptance workflow binding drift")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_batch13_multi_provider_contract_guard: exact written navigation candidate and hostile proof obligations verified; runtime remains forbidden.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
