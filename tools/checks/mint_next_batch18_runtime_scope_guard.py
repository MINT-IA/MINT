#!/usr/bin/env python3
"""Fail closed on the Batch18 scope contract; do not infer runtime state."""

from __future__ import annotations

import hashlib
import ast
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks import mint_next_batch17_canton_scope_guard as batch17


SCOPE = Path("product/mint_next/batch18/runtime-scope.yaml")
ACCEPTANCE = Path("product/mint_next/batch18/scope-acceptance.yaml")
PARENT = Path("product/mint_next/batch17/canton-scope.yaml")
WORKFLOW = Path(".github/workflows/mint-next-batch18-canton-runtime-scope.yml")
SPEC = Path(".planning/phases/mint-next-vertical01-3a-20260802/SPEC.md")
JOURNEY_GUARD = Path("tools/checks/journey_os_check.py")
GUARD = Path("tools/checks/mint_next_batch18_runtime_scope_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch18_runtime_scope_guard.py")
EXPECTED_SCOPE_SHA256 = "88dfd16846bc658db21c992c8855a8344305704d5cb9c8a5ebdd78c450a96dc5"
EXPECTED_ACCEPTED_SCOPE_SHA256 = "ecb83ff852211d055ca50d9e0667d138b744e1bca1a7ba81131c2c1814761f8a"
EXPECTED_SCOPE_CANONICAL_SHA256 = "d38bd26d1e2a7feaf9512ac986d9db877f5d7fe912de106200eeb6aa89a7af1f"
EXPECTED_PARENT_SHA256 = "bb1a293f55b980ba7e1f07d575d34626ac181369bb97a9f9b9372c04af952c4a"
EXPECTED_JOURNEY_EXECUTABLE_SHA256 = "a854d772773eddd31eda9fee2f752121e33a8dfc5a8c7324bdea2f10fb7733c4"


class GuardFailure(RuntimeError):
    pass


class UniqueKeyLoader(yaml.SafeLoader):
    pass


class UniqueStringKeyLoader(yaml.BaseLoader):
    pass


def _construct_unique_mapping(loader, node: yaml.MappingNode, deep: bool = False) -> dict:
    mapping: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise GuardFailure(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


for loader in (UniqueKeyLoader, UniqueStringKeyLoader):
    loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)


def _load_structure(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueStringKeyLoader)


def _active_journey_allow_entries(source: str) -> list[str]:
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        raise GuardFailure("Journey OS source is not parseable") from exc
    assignments = [
        node for node in tree.body
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "ALLOW" for target in node.targets)
    ]
    _require(len(assignments) == 1 and isinstance(assignments[0].value, ast.Set), "Journey OS active ALLOW assignment drifted")
    stores = [node for node in ast.walk(tree) if isinstance(node, ast.Name) and node.id == "ALLOW" and isinstance(node.ctx, ast.Store)]
    mutations = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "ALLOW"
    ]
    _require(len(stores) == 1 and not mutations, "Journey OS ALLOW is reassigned or mutated after declaration")
    literals = [element.value for element in assignments[0].value.elts if isinstance(element, ast.Constant) and isinstance(element.value, str)]
    for entry in EXPECTED_JOURNEY_ENTRIES:
        _require(literals.count(entry) == 1, f"Journey OS active scope entry missing or duplicated: {entry}")
    return [entry for entry in EXPECTED_JOURNEY_ENTRIES if entry in literals]


def _normalized_python_ast_bytes(source: str) -> bytes:
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        raise GuardFailure("Journey OS source is not parseable") from exc
    return ast.dump(tree, annotate_fields=True, include_attributes=False).encode("utf-8")


def _append_only_allow_ast_bytes(source: str) -> bytes:
    """Bind executable Journey logic while permitting reviewed literal appends."""
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        raise GuardFailure("Journey OS source is not parseable") from exc
    assignments = [
        node
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(
            isinstance(target, ast.Name) and target.id == "ALLOW"
            for target in node.targets
        )
    ]
    _require(
        len(assignments) == 1 and isinstance(assignments[0].value, ast.Set),
        "Journey OS active ALLOW assignment drifted",
    )
    dynamic_entries = [
        element
        for element in assignments[0].value.elts
        if not (
            isinstance(element, ast.Constant)
            and isinstance(element.value, str)
        )
    ]
    assignments[0].value = ast.Set(
        elts=dynamic_entries
        + [ast.Constant(value=entry) for entry in sorted(EXPECTED_JOURNEY_ENTRIES)]
    )
    ast.fix_missing_locations(tree)
    return ast.dump(tree, annotate_fields=True, include_attributes=False).encode("utf-8")


def _normalized_workflow_bytes(path: Path) -> bytes:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    text, count = re.subn(r"(?m)^(  EXPECTED_BATCH18_[A-Z0-9_]+_SHA256:) [0-9a-f]{64}$", r"\1 <HASH>", text)
    _require(count == 3, "workflow trust-hash shape drifted")
    text, mode_count = re.subn(r"(?m)^(\s*run: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py)(?: --contract)?$", r"\1 <LIFECYCLE_MODE>", text)
    _require(mode_count == 1, "workflow lifecycle command shape drifted")
    return text.encode("utf-8")


def _review_payload_sha256(root: Path) -> str:
    digest = hashlib.sha256()
    scope = _load(root / SCOPE)
    scope["status"] = "<LIFECYCLE_STATUS>"
    parts = {
        str(SCOPE): yaml.safe_dump(scope, sort_keys=True, allow_unicode=True).encode("utf-8"),
        str(GUARD): (root / GUARD).read_bytes(),
        str(TESTS): (root / TESTS).read_bytes(),
        str(WORKFLOW): _normalized_workflow_bytes(root / WORKFLOW),
    }
    spec = (root / SPEC).read_text(encoding="utf-8")
    verify = re.search(r"```verify\n(.*?)\n```", spec, re.DOTALL)
    _require(verify is not None, "active SPEC verify block missing")
    batch18_lines = sorted(re.sub(r"(mint_next_batch18_runtime_scope_guard.py)(?: --contract)?$", r"\1 <LIFECYCLE_MODE>", line) for line in verify.group(1).splitlines() if line.startswith("batch18-canton-"))
    _require(len(batch18_lines) == 2, "Batch18 SPEC trust lines drifted")
    parts["SPEC_BATCH18_VERIFY"] = ("\n".join(batch18_lines) + "\n").encode("utf-8")
    parent_acceptance = _load(root / batch17.ACCEPTANCE)
    parent_payload = parent_acceptance["mechanical_binding"]["reviewed_payload_sha256"]
    _require(re.fullmatch(r"[0-9a-f]{64}", parent_payload) is not None, "accepted parent reviewed payload missing")
    parts["BATCH17_REVIEWED_PAYLOAD"] = parent_payload.encode("ascii")
    journey_source = (root / JOURNEY_GUARD).read_text(encoding="utf-8")
    journey_entries = _active_journey_allow_entries(journey_source)
    parts["JOURNEY_OS_BATCH18_ENTRIES"] = ("\n".join(journey_entries) + "\n").encode("utf-8")
    parts["JOURNEY_OS_EXECUTABLE_AST"] = _normalized_python_ast_bytes(journey_source)
    for name, payload in parts.items():
        digest.update(name.encode("utf-8") + b"\0" + payload + b"\0")
    return digest.hexdigest()


def _review_payload_sha256_at_commit(root: Path, commit: str) -> str:
    def show(relative: Path) -> bytes:
        try:
            return subprocess.run(["git", "show", f"{commit}:{relative}"], cwd=root, check=True, capture_output=True).stdout
        except subprocess.CalledProcessError as exc:
            raise GuardFailure(f"reviewed candidate cannot provide {relative}") from exc

    scope = yaml.load(show(SCOPE).decode("utf-8"), Loader=UniqueKeyLoader)
    scope["status"] = "<LIFECYCLE_STATUS>"
    workflow_text = show(WORKFLOW).decode("utf-8").replace("\r\n", "\n")
    workflow_text, count = re.subn(r"(?m)^(  EXPECTED_BATCH18_[A-Z0-9_]+_SHA256:) [0-9a-f]{64}$", r"\1 <HASH>", workflow_text)
    _require(count == 3, "reviewed workflow trust-hash shape drifted")
    workflow_text, mode_count = re.subn(r"(?m)^(\s*run: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py)(?: --contract)?$", r"\1 <LIFECYCLE_MODE>", workflow_text)
    _require(mode_count == 1, "reviewed workflow lifecycle command shape drifted")
    spec_text = show(SPEC).decode("utf-8")
    verify = re.search(r"```verify\n(.*?)\n```", spec_text, re.DOTALL)
    _require(verify is not None, "reviewed SPEC verify block missing")
    spec_lines = sorted(re.sub(r"(mint_next_batch18_runtime_scope_guard.py)(?: --contract)?$", r"\1 <LIFECYCLE_MODE>", line) for line in verify.group(1).splitlines() if line.startswith("batch18-canton-"))
    _require(len(spec_lines) == 2, "reviewed Batch18 SPEC trust lines drifted")
    parent_acceptance = yaml.load(show(batch17.ACCEPTANCE).decode("utf-8"), Loader=UniqueKeyLoader)
    parent_payload = parent_acceptance["mechanical_binding"]["reviewed_payload_sha256"]
    journey_source = show(JOURNEY_GUARD).decode("utf-8")
    journey_entries = _active_journey_allow_entries(journey_source)
    parts = {
        str(SCOPE): yaml.safe_dump(scope, sort_keys=True, allow_unicode=True).encode("utf-8"),
        str(GUARD): show(GUARD),
        str(TESTS): show(TESTS),
        str(WORKFLOW): workflow_text.encode("utf-8"),
        "SPEC_BATCH18_VERIFY": ("\n".join(spec_lines) + "\n").encode("utf-8"),
        "BATCH17_REVIEWED_PAYLOAD": parent_payload.encode("ascii"),
        "JOURNEY_OS_BATCH18_ENTRIES": ("\n".join(journey_entries) + "\n").encode("utf-8"),
        "JOURNEY_OS_EXECUTABLE_AST": _normalized_python_ast_bytes(journey_source),
    }
    digest = hashlib.sha256()
    for name, payload in parts.items():
        digest.update(name.encode("utf-8") + b"\0" + payload + b"\0")
    return digest.hexdigest()


def _validate_pending_candidate_artifacts(scope_text: str, acceptance_text: str, workflow_text: str, spec_text: str, expected_payload: str) -> None:
    scope = yaml.load(scope_text, Loader=UniqueKeyLoader)
    acceptance = yaml.load(acceptance_text, Loader=UniqueKeyLoader)
    workflow = yaml.load(workflow_text, Loader=UniqueStringKeyLoader)
    _require(scope.get("status") == "candidate_scope_acceptance_absent", "reviewed anchor was not a pending scope candidate")
    _require(set(acceptance) == {"schema_version", "status", "current_verdict", "reviews", "mechanical_binding", "accepted_scope_only", "not_accepted", "next_gate"}, "reviewed anchor acceptance schema drifted")
    _require(acceptance.get("status") == "candidate_scope_unaccepted" and acceptance.get("current_verdict") == "PENDING_INDEPENDENT_ROASTS", "reviewed anchor acceptance was not pending")
    pending_review = {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}
    _require(set(acceptance.get("reviews", {})) == {"ux_accessibility_microstep_scope", "engineering_parent_feasibility", "adversarial_mechanical"}, "reviewed anchor roles drifted")
    _require(all(review == pending_review for review in acceptance["reviews"].values()), "reviewed anchor already carried review receipts")
    binding = acceptance.get("mechanical_binding", {})
    _require(set(binding) == {"candidate_review_payload_sha256", "reviewed_payload_sha256", "reviewed_candidate_commit", "positive_tests", "hostile_tests"}, "reviewed anchor binding schema drifted")
    _require(binding.get("candidate_review_payload_sha256") == expected_payload, "reviewed anchor candidate payload was not self-bound")
    _require(binding.get("reviewed_payload_sha256") is None and binding.get("reviewed_candidate_commit") is None, "reviewed anchor already carried accepted binding")
    _require(binding.get("positive_tests") == EXPECTED_POSITIVE_TESTS and binding.get("hostile_tests") == EXPECTED_HOSTILE_TESTS, "reviewed anchor test inventory drifted")
    _require(acceptance.get("accepted_scope_only") == [], "reviewed anchor already claimed accepted scope")
    _require(acceptance.get("not_accepted") == EXPECTED_NOT_ACCEPTED, "reviewed anchor boundary drifted")
    _require(acceptance.get("next_gate") == "stabilize_candidate_trust_unit_then_independent_roasts", "reviewed anchor next gate was not candidate review")
    zeros = "0" * 64
    _require(set(workflow.get("env", {})) == {"EXPECTED_BATCH18_GUARD_SHA256", "EXPECTED_BATCH18_TESTS_SHA256", "EXPECTED_BATCH18_ACCEPTANCE_SHA256"}, "reviewed anchor workflow trust environment drifted")
    _require(all(value == zeros for value in workflow["env"].values()), "reviewed anchor workflow was already promoted")
    candidate_command = "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract"
    runs = [step.get("run") for step in workflow["jobs"]["scope"]["steps"] if isinstance(step, dict)]
    _require(runs.count(candidate_command) == 1, "reviewed anchor workflow was not in candidate mode")
    verify = re.search(r"```verify\n(.*?)\n```", spec_text, re.DOTALL)
    _require(verify is not None and verify.group(1).splitlines().count(f"batch18-canton-runtime-scope: {candidate_command}") == 1, "reviewed anchor SPEC was not in candidate mode")


def _require_pending_candidate_at_commit(root: Path, commit: str, expected_payload: str) -> None:
    def show(relative: Path) -> str:
        try:
            return subprocess.run(["git", "show", f"{commit}:{relative}"], cwd=root, check=True, capture_output=True, text=True).stdout
        except subprocess.CalledProcessError as exc:
            raise GuardFailure(f"reviewed candidate cannot provide lifecycle artifact {relative}") from exc

    _validate_pending_candidate_artifacts(show(SCOPE), show(ACCEPTANCE), show(WORKFLOW), show(SPEC), expected_payload)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "journey_id", "runtime_surface", "product_promotion", "audience",
    "authority", "acceptance_model", "microsteps", "required_controls", "hard_out_of_scope", "required_test_modes",
    "forbidden_claims_until_separate_acceptance", "planned_gate_topology",
}
EXPECTED_AUTHORITY = {
    "parent_contract": str(PARENT),
    "parent_contract_sha256": EXPECTED_PARENT_SHA256,
    "canonical_navigation": "product/mint_next/batch6/navigation.yaml",
    "locale_copy": "product/mint_next/batch17/six-locale-copy.yaml",
    "rule": "runtime_must_implement_parent_exactly_without_adding_removing_or_retargeting_routes",
}
EXPECTED_COMPLETE_GATE = [
    "R1_R2_R3_R4_all_complete_on_one_exact_reviewed_state",
    "failing_runtime_tests_first_for_every_obligation",
    "all_required_runtime_tests_green",
    "independent_ux_accessibility_roast_zero_P1_P2_P3",
    "independent_privacy_navigation_adversarial_roast_zero_P1_P2_P3",
    "mechanically_bound_evidence_from_the_exact_reviewed_state",
    "stable_local_precommit_dispatcher_without_rebinding_prior_acceptances",
    "separate_acceptance_artifact_and_separate_commit",
]
EXPECTED_SUBGATES = {
    "R1": ["R1a_catalog_origin_and_generation", "R1b_local_search_privacy", "R1c_selection_semantics_and_layout"],
    "R2": ["R2a_continue_validation", "R2b_boundary_and_exact_history"],
    "R3": ["R3a_unknown_atomic_transition", "R3b_help_education_exact_history"],
    "R4": ["R4a_safe_exit", "R4b_lifecycle_generation_and_privacy", "R4c_six_locale_accessibility_and_compact", "R4d_cross_step_integration"],
}
EXPECTED_COUNTS = {"R1": 14, "R2": 8, "R3": 8, "R4": 17}
EXPECTED_OBLIGATIONS = {'R1': ['R1_01_both_exact_origins_enter_fact_canton_with_immutable_origin_receipt_and_no_fallback',
        'R1_02_initial_unset_state_has_no_default_recommendation_inference_or_preselection',
        'R1_03_R1_acceptance_covers_only_heading_body_search_list_privacy_selection_and_back_while_preexisting_safe_exit_may_render_but_is_not_accepted_until_R4',
        'R1_04_search_is_local_bounded_64_Unicode_codepoints_NFKC_case_and_diacritic_fold_against_reviewed_labels_only',
        'R1_05_exactly_26_localized_full_names_use_reviewed_locale_order_and_internal_codes',
        'R1_06_first_middle_last_no_match_clear_and_rapid_query_cases_are_tested',
        'R1_07_clear_search_restores_full_list_selection_and_search_focus_without_selecting',
        'R1_08_selection_commits_only_an_allowed_ephemeral_code_and_never_routes_or_creates_commune_or_result_state',
        'R1_09_same_code_reselection_is_a_byte_equivalent_no_op_for_the_reachable_runtime_snapshot',
        'R1_10_query_change_or_clear_never_changes_selection_and_selected_row_remains_discoverable',
        'R1_11_generation_token_guards_every_R1_callback_and_old_generation_callbacks_are_no_ops',
        'R1_12_search_disables_autofill_autocorrect_suggestions_platform_learning_clipboard_network_logging_analytics_and_persistence',
        'R1_13_search_clear_back_and_all_26_rows_are_at_least_48_by_48_with_single_select_semantics',
        'R1_14_R1_targeted_gate_must_pass_before_R2_and_unimplemented_later_controls_never_count_as_accepted'],
 'R2': ['R2_01_continue_is_an_always_reachable_validation_action_with_persistent_visible_and_announced_prerequisite_and_never_routes_when_unset',
        'R2_02_unset_shows_localized_no_selection_error_and_focuses_choice_group_while_stale_or_invalid_shows_distinct_error_without_mutation_or_route',
        'R2_03_valid_continue_checks_active_generation_and_routes_once_to_fact_commune_without_second_write_or_invalidation',
        'R2_04_fact_commune_is_non_collecting_boundary_with_heading_focus_back_and_safe_exit_only',
        'R2_05_fact_commune_back_restores_selected_code_scroll_and_fact_canton_state',
        'R2_06_visible_and_system_back_from_fact_canton_return_the_exact_immutable_no_or_positive_runtime_origin',
        'R2_07_repeated_continue_is_idempotent_and_never_creates_duplicate_history',
        'R2_08_continue_and_boundary_controls_have_48pt_semantics_focus_order_and_no_commune_or_result_value'],
 'R3': ['R3_01_unknown_complex_is_explicit_peer_control_not_blank_or_inferred_value',
        'R3_02_unknown_atomically_commits_unknown_once_routes_to_help_once_and_creates_no_commune_or_result_state',
        'R3_03_help_arrival_focuses_heading_and_exposes_only_education_back_and_safe_exit_controls',
        'R3_04_help_copy_explains_where_to_check_and_never_shows_personal_amount_average_or_inferred_canton',
        'R3_05_continue_routes_only_to_existing_education_explanation_in_general_education_mode',
        'R3_06_help_visible_and_system_back_clear_unknown_return_to_fact_canton_and_focus_unknown_control',
        'R3_07_education_back_returns_exact_history_to_canton_unknown_help',
        'R3_08_moved_intercantonal_international_source_tax_or_uncertain_cases_never_enter_personal_calculation'],
 'R4': ['R4_01_safe_exit_on_fact_canton_help_and_boundaries_is_focus_trapped_with_resume_keep_reference_and_leave_controls',
        'R4_02_safe_exit_system_back_equals_resume',
        'R4_03_resume_restores_exact_trigger_focus_node_selection_query_scroll_and_origin',
        'R4_04_keep_reference_persists_only_journey_id_generic_reference_id_saved_at_then_purges_personal_ephemeral_state',
        'R4_05_leave_without_saving_purges_and_dismisses',
        'R4_06_background_resume_before_30_min_restores_exact_node_focus_scroll_selection_and_origin',
        'R4_07_ttl_expiry_and_tax_year_change_purge_before_render_and_restart_at_tax_year_while_process_kill_persists_no_personal_state_and_fresh_launch_starts_at_canonical_first_node',
        'R4_08_stale_callbacks_never_mutate_or_navigate',
        'R4_09_search_and_personal_facts_never_use_network_logs_analytics_autofill_clipboard_platform_learning_or_persistence',
        'R4_10_every_interactive_target_is_at_least_48_by_48_logical_points',
        'R4_11_semantics_cover_tax_year_group_name_full_label_selected_state_unknown_result_count_persistent_prerequisite_validation_and_stale_errors',
        'R4_12_keyboard_and_switch_order_is_deterministic_with_no_hidden_focus_targets_and_exact_modal_focus_return',
        'R4_13_system_back_has_an_explicit_equivalent_on_every_base_node_and_overlay',
        'R4_14_all_six_locales_use_reviewed_copy_labels_orders_and_taxYear_interpolation_with_human_semantic_review',
        'R4_15_320x700_text_scale_2_runtime_proof_covers_all_six_locales_and_worst_states_without_overflow_clip_overlap_or_unreachable_action',
        'R4_16_compact_proof_covers_unset_search_results_selected_first_middle_last_no_match_both_errors_help_and_safe_exit',
        'R4_17_reduced_motion_and_screen_reader_semantics_are_runtime_tested']}
EXPECTED_EXECUTION_REGISTRY = "product/mint_next/batch18/runtime-gates.yaml"
EXPECTED_PLANNED_TEST_FILES = {
    "R1": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r1_test.dart",
    "R2": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r2_test.dart",
    "R3": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r3_test.dart",
    "R4a_safe_exit": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4a_safe_exit_test.dart",
    "R4b_lifecycle_generation_and_privacy": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4b_lifecycle_privacy_test.dart",
    "R4c_six_locale_accessibility_and_compact": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4c_accessibility_locales_test.dart",
    "R4d_cross_step_integration": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4d_integration_test.dart",
}
EXPECTED_GATE_ORDER = [
    "R1", "R2", "R3", "R4a_safe_exit", "R4b_lifecycle_generation_and_privacy",
    "R4c_six_locale_accessibility_and_compact", "R4d_cross_step_integration", "R4", "runtime_global",
]
EXPECTED_CONTROLS = {
    "fact_canton": ["back", "open_safe_exit", "search", "clear_search_when_nonempty", "choose_exactly_one_canton", "choose_unknown_or_complex", "continue"],
    "canton_unknown_help": ["back", "open_safe_exit", "continue_education_only"],
    "fact_commune_boundary": ["back", "open_safe_exit"],
    "safe_exit": ["resume", "keep_local_reference", "leave_without_saving"],
}
EXPECTED_OUT_OF_SCOPE = [
    "production_or_public_route", "product_promotion_or_user_validation", "legacy_or_dev_mutation",
    "commune_input_dataset_search_or_lookup", "tax_calculation_rate_range_saving_or_personal_result",
    "gps_ip_address_postcode_device_locale_profile_employer_or_provider_inference", "location_permission",
    "default_ZH_first_item_national_average_or_30_percent_fallback",
    "persistent_personal_fact_backend_api_account_auth_or_network_dependency",
    "bank_insurance_pension_AVS_AI_or_tax_authority_integration", "complex_case_personal_calculation",
    "design_system_redesign", "new_navigation_node_route_or_retargeting", "coach_chat_LLM_RAG_or_Hugging_Face",
    "analytics_session_replay_or_MINT_created_screen_capture",
]
EXPECTED_TEST_MODES = [
    "widget_runtime_state_and_navigation", "hostile_stale_generation_and_repeated_action", "semantics_and_keyboard_switch",
    "compact_layout_and_golden_evidence", "six_locale_runtime_and_human_semantic_review",
    "privacy_network_log_and_persistence_negative_proof",
]
EXPECTED_FORBIDDEN_CLAIMS = [
    "runtime_implemented", "runtime_accepted", "user_validated", "production_ready", "calculation_available",
    "privacy_compliant_by_declaration",
]
EXPECTED_NOT_ACCEPTED = [
    "any_runtime_microstep", "hidden_runtime", "product_route", "user_validation", "calculation", "persistence",
    "local_precommit_binding_until_shared_registry_is_decoupled",
]
EXPECTED_POSITIVE_TESTS = ['test_current_scope_passes', 'test_release_gate_matches_declared_lifecycle']
EXPECTED_HOSTILE_TESTS = ['test_acceptance_claim_without_reviews_is_rejected',
 'test_any_out_of_scope_removal_is_rejected_semantically',
 'test_authority_retarget_is_rejected_semantically',
 'test_byte_drift_has_its_own_failure',
 'test_candidate_anchor_with_extra_runtime_claim_is_rejected',
 'test_candidate_anchor_with_wrong_well_formed_payload_is_rejected',
 'test_candidate_binding_extra_runtime_claim_is_rejected',
 'test_candidate_review_extra_runtime_claim_is_rejected',
 'test_ci_comment_is_not_operational',
 'test_ci_custom_shell_cannot_make_commands_inert',
 'test_ci_false_condition_is_rejected',
 'test_ci_workflow_default_shell_cannot_make_all_commands_inert',
 'test_ci_workflow_default_working_directory_is_rejected',
 'test_complete_gate_removal_is_rejected_semantically',
 'test_contradictory_extra_acceptance_key_is_rejected',
 'test_current_artifacts_are_a_pending_candidate_anchor',
 'test_duplicate_yaml_key_is_rejected_semantically',
 'test_forbidden_privacy_claim_removal_is_rejected_semantically',
 'test_guard_source_drift_invalidates_candidate_receipt',
 'test_hidden_surface_widening_is_rejected_semantically',
 'test_hostile_test_deletion_invalidates_registry',
 'test_journey_allow_alias_clear_invalidates_review_payload',
 'test_journey_allow_alias_isub_invalidates_review_payload',
 'test_journey_allow_cannot_be_cleared_after_declaration',
 'test_journey_allow_container_alias_invalidates_review_payload',
 'test_journey_allow_helper_mutation_invalidates_review_payload',
 'test_journey_entries_commented_out_are_not_active',
 'test_journey_entries_moved_to_dead_string_are_not_active',
 'test_microstep_removal_is_rejected_semantically',
 'test_obligation_removal_is_rejected_semantically',
 'test_parent_drift_is_rejected_even_if_scope_parent_hash_is_rebound',
 'test_parent_locale_copy_drift_is_rejected_by_parent_guard',
 'test_partial_microstep_acceptance_is_rejected_semantically',
 'test_planned_topology_cannot_claim_runtime_state',
 'test_post_runtime_product_promotion_is_rejected_semantically',
 'test_product_promotion_is_rejected_semantically',
 'test_promoted_artifacts_cannot_be_reused_as_candidate_anchor',
 'test_promoted_binding_extra_runtime_claim_is_rejected',
 'test_promoted_fixture_passes_and_hostile_is_not_lifecycle_vacuous',
 'test_promoted_review_extra_user_validated_claim_is_rejected',
 'test_r4_obligation_ownership_swap_is_rejected_semantically',
 'test_r4_planned_file_swap_is_rejected',
 'test_required_control_removal_is_rejected_semantically',
 'test_required_test_mode_removal_is_rejected_semantically',
 'test_runtime_gate_registry_claim_is_rejected_semantically',
 'test_runtime_knowledge_claim_is_rejected_semantically',
 'test_same_prefix_nonsense_obligation_is_rejected_exactly',
 'test_scope_acceptance_claim_is_rejected_semantically',
 'test_spec_comment_is_not_operational',
 'test_subgate_weakening_is_rejected_semantically']
EXPECTED_JOURNEY_ENTRIES = [
    "product/mint_next/batch18/runtime-scope.yaml",
    "product/mint_next/batch18/scope-acceptance.yaml",
    "tools/checks/mint_next_batch18_runtime_scope_guard.py",
    "tools/checks/tests/test_mint_next_batch18_runtime_scope_guard.py",
    ".github/workflows/mint-next-batch18-canton-runtime-scope.yml",
]


def validate(root: Path, *, check_byte_digest: bool = True, check_parent_git: bool = False, require_accepted: bool | None = False) -> None:
    for relative in (SCOPE, ACCEPTANCE, PARENT, WORKFLOW, SPEC, GUARD, TESTS, JOURNEY_GUARD):
        _require((root / relative).is_file(), f"missing artifact: {relative}")
    if require_accepted is None:
        require_accepted = _load(root / ACCEPTANCE).get("status") == "accepted_scope_contract_runtime_not_evaluated"
    _require(_sha256(root / PARENT) == EXPECTED_PARENT_SHA256, "accepted Batch17 parent drifted")

    scope = _load(root / SCOPE)
    _require(set(scope) == EXPECTED_TOP_KEYS, "top-level scope schema drifted")
    expected_scope_status = "accepted_scope_contract_runtime_state_not_evaluated" if require_accepted else "candidate_scope_acceptance_absent"
    _require(scope["status"] == expected_scope_status, "scope acceptance status drifted")
    if check_byte_digest:
        expected_bytes = EXPECTED_ACCEPTED_SCOPE_SHA256 if require_accepted else EXPECTED_SCOPE_SHA256
        _require(_sha256(root / SCOPE) == expected_bytes, "Batch18 scope bytes drifted")
    _require(scope["runtime_surface"] == "hidden_design_lab_only", "runtime surface widened")
    _require(scope["product_promotion"] == "forbidden", "product promotion widened")
    _require(scope["authority"] == EXPECTED_AUTHORITY, "authority contract drifted")

    acceptance = scope["acceptance_model"]
    _require(set(acceptance) == {"runtime_state_evaluated_by_scope_guard", "self_attested_evidence", "microstep_acceptance", "execution_rule", "global_rule", "promotion_rule", "runtime_execution_registry", "runtime_execution_registry_rule", "complete_runtime_gate_requires", "product_promotion_after_runtime_acceptance"}, "acceptance schema drifted")
    _require(acceptance["runtime_state_evaluated_by_scope_guard"] is False, "scope guard claims runtime knowledge")
    _require(acceptance["self_attested_evidence"] == "forbidden", "self-attestation became evidence")
    _require(acceptance["microstep_acceptance"] == "forbidden", "a microstep can promote runtime")
    _require(acceptance["execution_rule"] == "a_runtime_microstep_gets_an_executable_command_and_expected_failing_tests_before_implementation_then_its_named_gate_must_pass_before_the_next_microstep", "microstep execution rule drifted")
    _require(acceptance["global_rule"] == "no_runtime_acceptance_until_every_named_microstep_and_cross_step_gate_exists_passes_and_is_bound_to_one_exact_reviewed_state", "global runtime rule drifted")
    _require(acceptance["promotion_rule"] == "no_microstep_or_partial_combination_promotes_runtime", "partial promotion rule drifted")
    _require(acceptance["runtime_execution_registry"] == EXPECTED_EXECUTION_REGISTRY, "runtime execution registry retargeted")
    _require(acceptance["runtime_execution_registry_rule"] == "separately_versioned_and_guarded_runtime_evidence_may_evolve_without_rewriting_this_accepted_scope", "runtime execution registry rule drifted")
    _require(acceptance["complete_runtime_gate_requires"] == EXPECTED_COMPLETE_GATE, "complete runtime gate obligations drifted")
    _require(acceptance["product_promotion_after_runtime_acceptance"] == "separately_forbidden_until_named_gate_and_user_validation", "post-runtime product promotion widened")

    microsteps = scope["microsteps"]
    _require(list(microsteps) == ["R1", "R2", "R3", "R4"], "microstep order or coverage drifted")
    for step, count in EXPECTED_COUNTS.items():
        value = microsteps[step]
        expected_keys = {"name", "obligations", "subgates", "subgate_contracts"} if step == "R4" else {"name", "obligations", "subgates"}
        _require(set(value) == expected_keys, f"{step} schema drifted")
        _require(value["subgates"] == EXPECTED_SUBGATES[step], f"{step} subgates drifted")
        obligations = value["obligations"]
        _require(len(obligations) == count and len(set(obligations)) == count, f"{step} obligation coverage drifted")
        _require(obligations == EXPECTED_OBLIGATIONS[step], f"{step} exact obligations drifted")
    r4_contracts = microsteps["R4"]["subgate_contracts"]
    _require(list(r4_contracts) == EXPECTED_SUBGATES["R4"], "R4 subgate contract order drifted")
    _require(r4_contracts["R4a_safe_exit"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(1, 6)], "R4a obligation ownership drifted")
    _require(r4_contracts["R4b_lifecycle_generation_and_privacy"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(6, 10)], "R4b obligation ownership drifted")
    _require(r4_contracts["R4c_six_locale_accessibility_and_compact"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(10, 18)], "R4c obligation ownership drifted")
    _require(r4_contracts["R4d_cross_step_integration"]["obligation_ids"] == ["R1_R2_R3_R4_cross_step_integration"], "R4d obligation ownership drifted")
    for gate in EXPECTED_SUBGATES["R4"]:
        contract = r4_contracts[gate]
        _require(set(contract) == {"obligation_ids", "planned_test_file"}, f"{gate} contract schema drifted")
        _require(contract["planned_test_file"] == EXPECTED_PLANNED_TEST_FILES[gate], f"{gate} planned test ownership drifted")

    _require(scope["required_controls"] == EXPECTED_CONTROLS, "required control topology drifted")
    _require(scope["hard_out_of_scope"] == EXPECTED_OUT_OF_SCOPE, "hard out-of-scope inventory drifted")
    _require(scope["required_test_modes"] == EXPECTED_TEST_MODES, "required test modes drifted")
    _require(scope["forbidden_claims_until_separate_acceptance"] == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claim inventory drifted")
    topology = scope["planned_gate_topology"]
    _require(set(topology) == {"external_runtime_registry", "rule", "ordered_gates", "gates"}, "planned gate topology schema drifted")
    _require(topology["external_runtime_registry"] == EXPECTED_EXECUTION_REGISTRY, "planned runtime registry retargeted")
    _require(topology["rule"] == "runtime_commands_states_and_evidence_live_only_in_the_separately_versioned_external_registry", "planned topology rule drifted")
    _require(topology["ordered_gates"] == EXPECTED_GATE_ORDER, "planned gate order drifted")
    expected_gates = {gate: {"planned_test_file": path} for gate, path in EXPECTED_PLANNED_TEST_FILES.items()}
    expected_gates["R4"] = {"requires": EXPECTED_SUBGATES["R4"]}
    expected_gates["runtime_global"] = {"requires": ["R1", "R2", "R3", "R4"]}
    _require(topology["gates"] == expected_gates, "planned gate topology drifted")
    canonical_scope = dict(scope)
    canonical_scope["status"] = "candidate_scope_acceptance_absent"
    canonical = yaml.safe_dump(canonical_scope, sort_keys=True, allow_unicode=True).encode("utf-8")
    _require(hashlib.sha256(canonical).hexdigest() == EXPECTED_SCOPE_CANONICAL_SHA256, "exact semantic scope inventory drifted")

    # Reuse the accepted parent's own verifier; do not restate only one parent file.
    batch17.validate(root, require_accepted=True, check_git=check_parent_git)

    guard_command = "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py" + ("" if require_accepted else " --contract")
    tests_command = "python3 -m unittest tools.checks.tests.test_mint_next_batch18_runtime_scope_guard"
    workflow = _load_structure(root / WORKFLOW)
    _require(set(workflow) == {"name", "on", "concurrency", "permissions", "env", "jobs"}, "CI workflow top-level schema drifted")
    _require(workflow["name"] == "MINT Next Batch 18 Canton Runtime Scope", "CI workflow name drifted")
    _require(workflow["concurrency"] == {"group": "mint-next-batch18-canton-runtime-scope-${{ github.ref }}", "cancel-in-progress": "true"}, "CI concurrency drifted")
    _require(workflow["permissions"] == {"contents": "read"}, "CI permissions drifted")
    _require(set(workflow["env"]) == {"EXPECTED_BATCH18_GUARD_SHA256", "EXPECTED_BATCH18_TESTS_SHA256", "EXPECTED_BATCH18_ACCEPTANCE_SHA256"}, "CI trust environment schema drifted")
    _require(set(workflow["jobs"]) == {"scope"}, "CI jobs schema drifted")
    _require(set(workflow["on"]) == {"pull_request", "push"}, "CI trigger drifted")
    for trigger in ("pull_request", "push"):
        _require(workflow["on"][trigger]["branches"] == ["dev", "staging", "main"], f"CI {trigger} branches drifted")
    job = workflow["jobs"]["scope"]
    _require(set(job) == {"name", "runs-on", "steps"}, "CI scope job schema drifted")
    _require(job["name"] == "Verify hidden canton runtime scope contract" and job["runs-on"] == "ubuntu-latest", "CI scope job identity drifted")
    expected_steps = [
        {"uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"},
        {"uses": "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065b", "with": {"python-version": "3.11"}},
        {"name": "Install exact guard dependency", "run": "python3 -m pip install PyYAML==6.0.2"},
        {"name": "Verify bounded scope contract", "run": guard_command},
        {"name": "Fire hostile scope mutations", "run": tests_command},
    ]
    _require(job["steps"] == expected_steps, "CI scope steps are not exact executable steps")
    runs = [step.get("run") for step in job["steps"] if isinstance(step, dict) and "run" in step]
    _require(runs.count(guard_command) == 1, "operational CI guard command missing or duplicated")
    _require(runs.count(tests_command) == 1, "operational CI hostile command missing or duplicated")
    spec = (root / SPEC).read_text(encoding="utf-8")
    verify = re.search(r"```verify\n(.*?)\n```", spec, re.DOTALL)
    _require(verify is not None, "active SPEC verify block missing")
    lines = verify.group(1).splitlines()
    _require(lines.count(f"batch18-canton-runtime-scope: {guard_command}") == 1, "operational SPEC guard binding missing or duplicated")
    _require(lines.count(f"batch18-canton-runtime-scope-hostiles: {tests_command}") == 1, "operational SPEC hostile binding missing or duplicated")
    journey_source = (root / JOURNEY_GUARD).read_text(encoding="utf-8")
    _active_journey_allow_entries(journey_source)
    _require(
        hashlib.sha256(_append_only_allow_ast_bytes(journey_source)).hexdigest()
        == EXPECTED_JOURNEY_EXECUTABLE_SHA256,
        "Journey OS executable logic drifted outside append-only literal ALLOW entries",
    )

    acceptance = _load(root / ACCEPTANCE)
    _require(set(acceptance) == {"schema_version", "status", "current_verdict", "reviews", "mechanical_binding", "accepted_scope_only", "not_accepted", "next_gate"}, "scope acceptance schema drifted")
    expected_status = "accepted_scope_contract_runtime_not_evaluated" if require_accepted else "candidate_scope_unaccepted"
    expected_verdict = "SCOPE_ACCEPTED_RUNTIME_NOT_EVALUATED" if require_accepted else "PENDING_INDEPENDENT_ROASTS"
    _require(acceptance["status"] == expected_status and acceptance["current_verdict"] == expected_verdict, "scope acceptance lifecycle drifted")
    roles = {"ux_accessibility_microstep_scope", "engineering_parent_feasibility", "adversarial_mechanical"}
    _require(set(acceptance["reviews"]) == roles, "scope review role coverage drifted")
    for role, review in acceptance["reviews"].items():
        if require_accepted:
            _require(set(review) == {"verdict", "p1", "p2", "p3", "reviewed_payload_sha256"}, f"accepted review schema drifted: {role}")
            _require(review["verdict"] == "ACCEPT" and (review["p1"], review["p2"], review["p3"]) == (0, 0, 0), f"scope review not zero: {role}")
        else:
            _require(review == {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}, f"candidate review is not pending: {role}")
    binding = acceptance["mechanical_binding"]
    _require(set(binding) == {"candidate_review_payload_sha256", "reviewed_payload_sha256", "reviewed_candidate_commit", "positive_tests", "hostile_tests"}, "mechanical binding schema drifted")
    discovered = set(re.findall(r"(?m)^    def (test_[A-Za-z0-9_]+)\(", (root / TESTS).read_text(encoding="utf-8")))
    _require(discovered == set(EXPECTED_POSITIVE_TESTS) | set(EXPECTED_HOSTILE_TESTS), "immutable test inventory drifted")
    _require(binding["positive_tests"] == EXPECTED_POSITIVE_TESTS, "positive test registry drifted")
    _require(binding["hostile_tests"] == EXPECTED_HOSTILE_TESTS, "hostile test registry drifted")
    if require_accepted:
        if check_parent_git:
            candidate = binding["reviewed_candidate_commit"]
            _require(
                re.fullmatch(r"[0-9a-f]{40}", candidate or "") is not None,
                "reviewed candidate commit missing or malformed",
            )
            payload = _review_payload_sha256_at_commit(root, candidate)
        else:
            # The immutable scope receipt is historical. Current dispatcher
            # bytes are separately bound by the decoupling amendment guard.
            payload = binding["reviewed_payload_sha256"]
    else:
        payload = _review_payload_sha256(root)
    _require(binding["candidate_review_payload_sha256"] == payload, "candidate review payload drifted")
    if require_accepted:
        _require(binding["reviewed_payload_sha256"] == payload, "accepted review payload drifted")
        _require(re.fullmatch(r"[0-9a-f]{40}", binding["reviewed_candidate_commit"] or "") is not None, "reviewed candidate commit missing or malformed")
        _require(acceptance["accepted_scope_only"] == ["written_batch18_runtime_scope_and_microstep_order"], "accepted scope widened")
        for review in acceptance["reviews"].values():
            _require(review["reviewed_payload_sha256"] == payload, "scope review receipt payload drifted")
        if check_parent_git:
            candidate = binding["reviewed_candidate_commit"]
            _require(subprocess.run(["git", "merge-base", "--is-ancestor", candidate, "HEAD"], cwd=root).returncode == 0, "reviewed scope candidate is not an ancestor")
            _require_pending_candidate_at_commit(root, candidate, payload)
    else:
        _require(binding["reviewed_payload_sha256"] is None and binding["reviewed_candidate_commit"] is None, "candidate carries accepted receipt")
        _require(acceptance["accepted_scope_only"] == [], "candidate claims accepted scope")
    _require(acceptance["not_accepted"] == EXPECTED_NOT_ACCEPTED, "not-accepted boundary drifted")
    _require(acceptance["next_gate"] == ("write_expected_failing_R1_tests" if require_accepted else "stabilize_candidate_trust_unit_then_independent_roasts"), "next gate drifted")

    workflow_text = (root / WORKFLOW).read_text(encoding="utf-8")
    hashes = {"GUARD": GUARD, "TESTS": TESTS, "ACCEPTANCE": ACCEPTANCE}
    for name, relative in hashes.items():
        expected = _sha256(root / relative) if require_accepted else "0" * 64
        _require(len(re.findall(rf"(?m)^  EXPECTED_BATCH18_{name}_SHA256: {expected}$", workflow_text)) == 1, f"workflow trust hash stale: {name}")


def main() -> int:
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] != "--contract"):
        print("usage: mint_next_batch18_runtime_scope_guard.py [--contract]", file=sys.stderr)
        return 2
    try:
        validate(Path(__file__).resolve().parents[2], check_parent_git=True, require_accepted=True if len(sys.argv) == 1 else None)
    except (GuardFailure, batch17.GuardFailure, KeyError, TypeError, yaml.YAMLError) as exc:
        print(f"Batch18 runtime scope guard: FAIL — {exc}", file=sys.stderr)
        return 1
    print("Batch18 runtime scope guard: PASS (scope only; runtime state not evaluated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
