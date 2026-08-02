#!/usr/bin/env python3
"""Validate the canonical 3a navigation graph before UI implementation."""

from __future__ import annotations

import sys
import hashlib
import subprocess
from collections import deque
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "product/mint_next/batch6/navigation.yaml"


def validate(path: Path = CONTRACT) -> list[str]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    nodes = data.get("nodes", {})
    overlays = data.get("overlays", {})
    entry = data.get("entry_node")
    if entry not in nodes:
        return ["entry node is missing"]
    if data.get("status") != "written_contract_accepted_runtime_unimplemented":
        errors.append("written navigation contract status is not accepted")
    if data.get("flutter_allowed") is not False or data.get("design_lab_allowed") is not True or data.get("next_gate") != "executable_flutter_design_lab_only":
        errors.append("accepted contract must allow only the executable design-lab gate")

    edges: dict[str, set[str]] = {node: set() for node in nodes}
    for node_id, node in nodes.items():
        actions = node.get("actions", {})
        if not actions:
            errors.append(f"{node_id}: no actions")
        if node.get("requires_account") is not False:
            errors.append(f"{node_id}: bounded path must not require an account")
        if not node.get("terminal"):
            if node_id != entry and "back" not in actions:
                errors.append(f"{node_id}: missing back action")
            if "open_safe_exit" not in actions:
                errors.append(f"{node_id}: missing safe exit")
        for action_id, action in actions.items():
            target = action.get("to")
            overlay = action.get("overlay")
            outcomes = action.get("outcomes", {})
            if outcomes:
                for outcome, outcome_target in outcomes.items():
                    if outcome_target not in nodes:
                        errors.append(f"{node_id}.{action_id}.{outcome}: unknown target {outcome_target}")
                    else:
                        edges[node_id].add(outcome_target)
            if target:
                if target not in nodes:
                    errors.append(f"{node_id}.{action_id}: unknown target {target}")
                else:
                    edges[node_id].add(target)
            if overlay:
                if overlay not in overlays:
                    errors.append(f"{node_id}.{action_id}: unknown overlay {overlay}")
            if not target and not overlay and not action.get("mutation") and not outcomes and not action.get("operation"):
                errors.append(f"{node_id}.{action_id}: no destination or mutation")
            if action.get("guard") and action["guard"] not in data.get("guards", {}):
                errors.append(f"{node_id}.{action_id}: undefined guard {action['guard']}")
            if action.get("mutation") in {"tax_year", "lpp_affiliation", "contribution_status", "contributed_amount", "canton", "commune", "household", "current_year_expected_assessment_taxable_income_band", "additional_planned_amount"}:
                if action.get("invalidates") != "result":
                    errors.append(f"{node_id}.{action_id}: fact mutation must invalidate result")
                if action.get("replaces") != action.get("mutation"):
                    errors.append(f"{node_id}.{action_id}: fact mutation must replace its canonical field")
            if action_id == "leave_without_saving" and action.get("persistence") != "clear_ephemeral_and_session_result":
                errors.append(f"{node_id}.{action_id}: exit must clear ephemeral and session result")
            if action.get("mutation") == "contribution_status" and action.get("value") in {"no", "unknown"}:
                if action.get("clears") != ["contributed_amount", "ephemeral_provider_rows"]:
                    errors.append(f"{node_id}.{action_id}: dependent contributed amount and provider rows must be cleared")

    for overlay_id, overlay in overlays.items():
        for action_id, action in overlay.get("actions", {}).items():
            target = action.get("to")
            if target and target not in nodes:
                errors.append(f"overlay {overlay_id}.{action_id}: unknown target {target}")
            if not target and not action.get("operation"):
                errors.append(f"overlay {overlay_id}.{action_id}: no operation or target")
            if action_id == "leave_without_saving" and action.get("persistence") != "clear_ephemeral_and_session_result":
                errors.append(f"overlay {overlay_id}.{action_id}: exit must clear ephemeral and session result")

    reachable: set[str] = set()
    queue = deque([entry])
    while queue:
        current = queue.popleft()
        if current in reachable:
            continue
        reachable.add(current)
        queue.extend(edges[current] - reachable)
    missing = sorted(set(nodes) - reachable)
    if missing:
        errors.append(f"unreachable nodes: {', '.join(missing)}")

    terminals = {node_id for node_id, node in nodes.items() if node.get("terminal")}
    reverse = {node: set() for node in nodes}
    for source, targets in edges.items():
        for target in targets:
            reverse[target].add(source)
    can_finish = set(terminals)
    queue = deque(terminals)
    while queue:
        current = queue.popleft()
        for parent in reverse[current]:
            if parent not in can_finish:
                can_finish.add(parent)
                queue.append(parent)
    trapped = sorted(set(nodes) - can_finish)
    if trapped:
        errors.append(f"nodes without terminal path: {', '.join(trapped)}")

    incoming = {node: set() for node in nodes}
    for source, source_node in nodes.items():
        for action_id, action in source_node.get("actions", {}).items():
            if action_id in {"back", "restart"}:
                continue
            target = action.get("to")
            if target in incoming:
                incoming[target].add(source)
    for node_id, node in nodes.items():
        back = node.get("actions", {}).get("back", {})
        if back.get("operation") == "history_back":
            if set(back.get("allowed_predecessors", [])) != incoming[node_id]:
                errors.append(f"{node_id}.back: allowed predecessors diverge from actual incoming routes")

    required = {
        "one_canonical_graph_for_routes_and_controls",
        "every_visible_control_has_one_declared_destination",
        "changed_fact_invalidates_and_hides_previous_result",
        "no_dead_node_no_orphan_renderer_no_hidden_route",
    }
    missing_invariants = required - set(data.get("invariants", []))
    if missing_invariants:
        errors.append("missing navigation invariants: " + ", ".join(sorted(missing_invariants)))
    contract = data.get("calculation_contract", {})
    expected_inputs = ["tax_year", "lpp_affiliation", "contribution_status", "contributed_amount", "canton", "commune", "household", "current_year_expected_assessment_taxable_income_band", "additional_planned_amount"]
    if contract.get("inputs") != expected_inputs:
        errors.append("calculation inputs are incomplete or reordered")
    if contract.get("stale_policy") != "hide_result_immediately_after_any_input_change":
        errors.append("stale result policy is not fail-closed")
    if data.get("lifecycle", {}).get("app_kill") != "restart_entry_and_clear_ephemeral_and_session_result":
        errors.append("app-kill recovery is not deterministic")
    if data.get("lifecycle", {}).get("background_resume_ttl_minutes") != 30:
        errors.append("background resume TTL must be explicit and bounded")
    if data.get("lifecycle", {}).get("background_resume_after_ttl") != "restart_entry_and_clear_ephemeral_and_session_result":
        errors.append("post-TTL recovery is not fail-closed")
    precedence = data.get("lifecycle", {}).get("resume_precedence", {})
    if precedence != {
        "allowlisted_reference_exists": "resume_reference_saved_with_allowlisted_payload_only",
        "otherwise": "restart_entry_and_clear_ephemeral_and_session_result",
    }:
        errors.append("resume precedence is ambiguous")
    required_outcomes = {"success", "insufficient_facts", "unsupported_case", "calculation_failed", "tax_year_rolled_over"}
    if set(contract.get("outcomes", [])) != required_outcomes:
        errors.append("calculation outcomes are incomplete")
    calculate_outcomes = nodes.get("confirm_facts", {}).get("actions", {}).get("calculate", {}).get("outcomes", {})
    exact_outcomes = {
        "success": "result",
        "insufficient_facts": "insufficient_facts",
        "unsupported_case": "unsupported_case",
        "calculation_failed": "calculation_failed",
        "tax_year_rolled_over": "tax_year_rolled_over",
    }
    if calculate_outcomes != exact_outcomes:
        errors.append("calculate action outcomes diverge from calculation contract")
    predicates = contract.get("outcome_predicates", {})
    exact_predicates = {
        "tax_year_rolled_over": "tax_year_differs_from_current_calendar_year_in_europe_zurich_at_calculation_time",
        "unsupported_case": "lpp_affiliation_is_not_yes",
        "insufficient_facts": "any_critical_input_is_unknown_or_missing",
        "success": "critical_inputs_complete_and_engine_succeeds",
        "calculation_failed": "critical_inputs_complete_and_engine_errors",
    }
    if predicates != exact_predicates:
        errors.append("calculation outcome predicates are incomplete")
    if contract.get("preconditions", {}).get("tax_year_current_at_calculation") != "tax_year_equals_current_calendar_year_in_europe_zurich_at_calculation_time":
        errors.append("calculation does not revalidate tax year at execution time")
    if contract.get("outcome_precedence", [])[0:1] != ["tax_year_rolled_over"]:
        errors.append("tax-year rollover is not evaluated before calculation outcomes")
    if nodes.get("confirm_facts", {}).get("actions", {}).get("calculate", {}).get("precondition") != "tax_year_current_at_calculation":
        errors.append("calculate action bypasses tax-year execution precondition")
    if contract.get("conditional_requiredness", {}).get("contributed_amount") != "required_only_when_contribution_status_is_yes":
        errors.append("contributed amount conditional requiredness is missing")
    input_policy = contract.get("input_policy", {})
    if input_policy.get("critical") != ["tax_year", "lpp_affiliation", "contribution_status", "contributed_amount_when_yes", "canton", "current_year_expected_assessment_taxable_income_band", "additional_planned_amount"]:
        errors.append("critical input policy is incomplete")
    if input_policy.get("optional_unknown_low_confidence_range") != ["commune", "household"]:
        errors.append("optional unknown range policy is incomplete")
    formulas = contract.get("formulas", {})
    if contract.get("normalization") != {
        "contribution_status_yes": "effective_contributed_amount_equals_contributed_amount",
        "contribution_status_no": "effective_contributed_amount_equals_zero",
        "contribution_status_unknown": "stop_with_insufficient_facts_without_personal_amount",
        "precedence": "unknown_stops_before_any_amount_formula",
    }:
        errors.append("contributed amount normalization is incomplete")
    exact_formulas = {
        "remaining_3a_room": "max(0, annual_cap - effective_contributed_amount)",
        "existing_excess_contribution": "max(0, effective_contributed_amount - annual_cap)",
        "deductible_amount": "min(additional_planned_amount, remaining_3a_room)",
        "planned_excess_contribution": "max(0, additional_planned_amount - deductible_amount)",
        "tax_base": "deductible_amount_only",
    }
    if formulas != exact_formulas:
        errors.append("deductible amount and excess formulas are incomplete")
    annual_cap = contract.get("official_constants", {}).get("annual_cap", {})
    if annual_cap.get("key") != "pillar3a_with_lpp_annual_cap" or annual_cap.get("provider") != "verified_swiss_constants_registry":
        errors.append("annual cap is not bound to the verified Swiss constants registry")
    if annual_cap.get("required_receipt_fields") != ["value_chf", "effective_tax_year", "official_source_url", "source_checked_at"]:
        errors.append("annual cap receipt fields are incomplete")
    provenance = data.get("provenance_contract", {})
    if set(provenance.get("result_actions", [])) != {"open_assumptions", "open_sources"}:
        errors.append("result provenance controls are incomplete")
    persistence = data.get("persistence_contract", {})
    allowed = set(persistence.get("local_reference_allowlist", []))
    if allowed != {"journey_id", "generic_reference_id", "saved_at"}:
        errors.append("local reference allowlist is not exact")
    if "result" not in set(persistence.get("forbidden_local_fields", [])):
        errors.append("result must be forbidden from local reference persistence")
    edit_amount_action = nodes.get("confirm_facts", {}).get("actions", {}).get("edit_contributed_amount", {})
    if edit_amount_action.get("visible_when") != "contribution_status_is_yes":
        errors.append("contributed amount edit must be conditional on contribution status yes")
    if nodes.get("reference_saved", {}).get("on_enter") != "clear_ephemeral_and_session_result_keep_local_reference":
        errors.append("reference-saved entry must purge sensitive session state")
    for node_id in ("fact_canton", "edit_canton"):
        for action_id in ("choose_canton", "choose_unknown"):
            if nodes.get(node_id, {}).get("actions", {}).get(action_id, {}).get("clears") != ["commune"]:
                errors.append(f"{node_id}.{action_id}: canton mutation must clear dependent commune")
    display = data.get("result_display_contract", {})
    if display.get("tax_range_uses") != "deductible_amount_only":
        errors.append("result display may overstate tax base")
    excess = display.get("planned_excess_when_positive", {})
    if excess.get("show_adjacent") != ["deductible_amount", "planned_excess_contribution", "no_tax_benefit_on_planned_excess"]:
        errors.append("excess contribution warning is incomplete")
    result_action = nodes.get("result", {}).get("actions", {}).get("correct_additional_planned_amount", {})
    if result_action.get("visible_when") != "planned_excess_contribution_is_positive":
        errors.append("excess correction action is not conditionally visible")
    existing_excess = display.get("existing_excess_when_positive", {})
    if existing_excess.get("show_adjacent") != ["annual_cap", "effective_contributed_amount", "existing_excess_contribution", "verify_or_request_correction"]:
        errors.append("existing over-contribution warning is incomplete")
    existing_action = nodes.get("result", {}).get("actions", {}).get("review_existing_overcontribution", {})
    if existing_action.get("visible_when") != "existing_excess_contribution_is_positive":
        errors.append("existing over-contribution help action is missing")
    year_contract = data.get("tax_year_contract", {})
    if year_contract != {
        "initialization": "current_calendar_year_in_europe_zurich_frozen_at_journey_start",
        "ordinary_estimate_allowed_value": "current_calendar_year_only",
        "past_year_selection": "route_to_retroactive_3a_boundary_without_ordinary_calculation",
        "confirmation_visibility": "always_show_tax_year_and_official_cap_year",
        "correction_action": "edit_tax_year",
    }:
        errors.append("tax year initialization, visibility, or correction contract is incomplete")
    if nodes.get("edit_canton", {}).get("actions", {}).get("confirm_edit", {}).get("to") != "edit_commune_after_canton":
        errors.append("canton edit must require commune reconfirmation")
    if nodes.get("edit_commune_after_canton", {}).get("actions", {}).get("back", {}).get("to") != "edit_canton":
        errors.append("canton-dependent commune edit cannot bypass reconfirmation on Back")
    if nodes.get("education_next_action", {}).get("actions", {}).get("restart_fact_collection", {}).get("to") != "fact_tax_year":
        errors.append("fact-collection restart skips tax year")
    annual_clears = ["lpp_affiliation", "contribution_status", "contributed_amount", "ephemeral_provider_rows", "additional_planned_amount"]
    if nodes.get("edit_tax_year", {}).get("actions", {}).get("choose_past_year", {}).get("clears") != annual_clears:
        errors.append("edit_tax_year.choose_past_year: year change must clear annual facts")
    if nodes.get("fact_tax_year", {}).get("actions", {}).get("choose_past_year", {}).get("to") != "retroactive_3a_boundary":
        errors.append("past tax year can enter the ordinary estimate")
    if data.get("guards", {}).get("tax_year_answered") != "tax_year_is_current_calendar_year_for_ordinary_estimate":
        errors.append("ordinary estimate does not require the current tax year")
    retro_back = nodes.get("retroactive_3a_boundary", {}).get("actions", {}).get("back", {})
    if retro_back != {
        "operation": "contextual_transaction_back",
        "outcomes": {"initial_collection": "fact_tax_year", "edit_review": "edit_tax_year"},
        "outcome_effects": {
            "initial_collection": "clear_selected_past_year",
            "edit_review": "rollback_entire_past_year_draft_restore_all_annual_facts_and_valid_result_keep_review_context",
        },
    }:
        errors.append("retroactive boundary Back can retain a past year")
    if data.get("contributed_amount_contract") != {
        "meaning": "total_paid_this_tax_year_across_all_3a_bank_accounts_fintech_accounts_and_insurance_policies",
        "collection_help": "add_all_provider_receipts_or_statements_before_confirming",
        "canonical_storage": "one_aggregated_chf_amount",
        "helper_output": "sum_of_ephemeral_provider_rows_replaces_canonical_contributed_amount",
        "dependent_annual_facts": ["contributed_amount", "ephemeral_provider_rows"],
        "empty_or_zero_total": "cannot_confirm_as_already_contributed_offer_change_status_to_no",
    }:
        errors.append("contributed amount is not an explicit all-provider annual total")
    helper = nodes.get("contributed_amount_total_helper", {}).get("actions", {})
    if helper.get("use_automatic_total", {}).get("value") != "sum_of_ephemeral_provider_rows":
        errors.append("multi-provider helper does not produce the canonical automatic total")
    if helper.get("use_automatic_total", {}).get("guard") != "provider_total_usable":
        errors.append("multi-provider helper can accept an empty or incomplete total")
    if helper.get("remove_provider_row", {}).get("guard") != "provider_row_selected":
        errors.append("multi-provider helper can remove without a selected row")
    if nodes.get("fact_contributed_amount", {}).get("actions", {}).get("open_total_helper", {}).get("to") != "contributed_amount_total_helper":
        errors.append("multi-provider total helper is not reachable from amount collection")
    edit_helper = nodes.get("edit_contributed_amount_total_helper", {}).get("actions", {})
    if nodes.get("edit_contributed_amount", {}).get("actions", {}).get("open_total_helper", {}).get("to") != "edit_contributed_amount_total_helper":
        errors.append("multi-provider total helper is not reachable during correction")
    if edit_helper.get("use_automatic_total", {}).get("to") != "edit_contributed_amount":
        errors.append("correction total helper does not return to its edit context")
    if data.get("income_estimate_contract") != {
        "meaning": "expected_taxable_income_band_for_current_year_and_current_tax_assessment_unit",
        "latest_assessment_use": "starting_point_only_then_adjust_for_income_or_household_changes",
        "value_metadata": ["basis_latest_assessment_or_current_estimate", "source_year_or_current_estimate"],
        "confirmation_visibility": ["current_year_expected_band", "basis", "source_year_or_current_estimate", "adjustment_assumption"],
    }:
        errors.append("current-year expected taxable-income semantics are incomplete")
    for income_node in ("fact_income", "edit_income", "edit_income_after_household"):
        if nodes.get(income_node, {}).get("actions", {}).get("choose_band", {}).get("value") != "selected_with_basis_and_source_year":
            errors.append(f"{income_node}.choose_band: income basis and source year are missing")
    for help_node, expected_mutation in (
        ("canton_unknown_help", "clear_unknown_canton_and_commune"),
        ("income_unknown_help", "clear_unknown_current_year_expected_income"),
        ("amount_unknown_help", "clear_unknown_additional_planned_amount"),
    ):
        if nodes.get(help_node, {}).get("actions", {}).get("back", {}).get("mutation") != expected_mutation:
            errors.append(f"{help_node}.back can retain a bypassable unknown value")
    for node_id in ("fact_household", "edit_household"):
        for action_id in ("choose_category", "choose_unknown"):
            if nodes.get(node_id, {}).get("actions", {}).get(action_id, {}).get("clears") != ["current_year_expected_assessment_taxable_income_band"]:
                errors.append(f"{node_id}.{action_id}: household change must clear assessment income")
    if nodes.get("edit_household", {}).get("actions", {}).get("confirm_edit", {}).get("to") != "edit_income_after_household":
        errors.append("household edit must require income reconfirmation")
    if nodes.get("edit_income_after_household", {}).get("actions", {}).get("back", {}).get("to") != "edit_household":
        errors.append("household-dependent income edit cannot bypass reconfirmation on Back")
    if data.get("teach_back_contract") != {
        "learning_objective": "understand_tax_deduction_locked_liquidity_and_no_tax_benefit_above_remaining_room",
        "proposition": "a_3a_payment_can_reduce_taxable_income_but_locks_liquidity_and_only_the_amount_within_remaining_room_is_used_for_this_estimate",
        "correct_answer_id": "choose_correct",
        "incorrect_answer_ids": ["choose_incorrect", "choose_unknown"],
        "renderer_requirement": "visible_answer_meanings_must_match_these_ids_in_runtime_inventory",
        "modes": ["teach_back", "insufficient_education_teach_back", "education_teach_back"],
        "locales": ["fr", "en", "de", "it", "es", "pt"],
    }:
        errors.append("teach-back meaning and answer mapping are incomplete")
    temporal = data.get("temporal_validity_contract", {})
    expected_temporal = {
        "revalidate_at": ["foreground_or_resume", "before_result_render", "before_every_result_derived_action"],
        "valid_when": "tax_year_equals_current_calendar_year_in_europe_zurich_at_check_time",
        "on_mismatch": "hide_and_purge_result_then_route_tax_year_rolled_over",
        "scoped_nodes": ["result", "existing_overcontribution_help", "teach_back", "teach_back_correction", "next_action", "personal_setup_boundary"],
        "scoped_overlays": ["assumptions", "sources"],
    }
    if temporal != expected_temporal:
        errors.append("result temporal validity contract is incomplete")
    for scoped_node in expected_temporal["scoped_nodes"]:
        if nodes.get(scoped_node, {}).get("temporal_guard") != "current_tax_year_or_route_rollover":
            errors.append(f"{scoped_node}: missing tax-year rollover guard")
    for scoped_overlay in expected_temporal["scoped_overlays"]:
        if overlays.get(scoped_overlay, {}).get("temporal_guard") != "current_tax_year_or_route_rollover":
            errors.append(f"overlay {scoped_overlay}: missing tax-year rollover guard")
    if data.get("guards", {}).get("contributed_amount_answered") != "contributed_amount_is_strictly_positive_chf_when_contribution_status_yes":
        errors.append("direct contributed amount can accept zero when status is yes")
    expected_edit_contract = {
        "scope": "every_node_whose_id_starts_with_edit",
        "draft_semantics": "fact_mutations_and_result_invalidation_are_staged_until_commit",
        "rollback_semantics": "Back_leaving_edit_discards_draft_and_restores_all_canonical_facts_and_valid_result",
        "commit_semantics": "commit_atomically_replaces_canonical_facts_clears_declared_dependencies_and_invalidates_result_only_when_canonical_state_changes",
        "no_op_commit": "preserve_valid_result_when_canonical_value_and_dependencies_are_unchanged",
        "no_op_effect_order": "compare_canonical_state_before_clears_invalidation_or_navigation_effects",
        "transaction_context_propagation": "follows_navigation_through_help_and_boundary_nodes_until_commit_rollback_or_purge",
        "continue_draft_actions": {
            "edit_contribution": ["choose_yes"],
            "edit_contributed_amount": ["enter_amount", "open_total_helper"],
            "edit_contributed_amount_total_helper": ["add_provider_row", "remove_provider_row", "use_automatic_total", "review_contribution_status", "back"],
            "edit_lpp_affiliation": ["choose_no", "choose_unknown"],
            "edit_tax_year": ["choose_past_year"],
            "edit_canton": ["choose_canton", "choose_unknown", "confirm_edit"],
            "edit_commune": ["choose_commune", "choose_unknown"],
            "edit_commune_after_canton": ["choose_commune", "choose_unknown", "back"],
            "edit_household": ["choose_category", "choose_unknown", "confirm_edit"],
            "edit_income_after_household": ["choose_band", "choose_unknown"],
            "edit_income": ["choose_band", "choose_unknown"],
            "edit_amount": ["enter_amount", "choose_unknown"],
        },
        "commit_actions": {
            "edit_lpp_affiliation": ["choose_yes"],
            "edit_tax_year": [],
            "edit_contribution": ["choose_no", "choose_unknown"],
            "edit_contributed_amount": ["confirm_edit"],
            "edit_canton": [],
            "edit_commune": ["confirm_edit"],
            "edit_commune_after_canton": ["confirm_edit"],
            "edit_household": [],
            "edit_income": ["confirm_edit"],
            "edit_income_after_household": ["confirm_edit"],
            "edit_amount": ["confirm_edit"],
        },
        "rollback_actions": {
            "edit_lpp_affiliation": "back", "edit_tax_year": "back", "edit_contribution": "back",
            "edit_contributed_amount": "back", "edit_canton": "back", "edit_commune": "back",
            "edit_household": "back", "edit_income": "back", "edit_amount": "back",
        },
        "no_op_actions": {
            "edit_tax_year": {
                "confirm_current_year": "close_edit_transaction_and_return_to_confirmation_without_clears_invalidation_or_recollection",
            },
        },
        "result_review_entry_actions": ["edit_facts", "back", "correct_additional_planned_amount", "review_existing_overcontribution"],
        "result_review_entry": "preserve_valid_result_until_first_changed_atomic_commit",
    }
    if data.get("edit_transaction_contract") != expected_edit_contract:
        errors.append("edit transaction, rollback, and atomic commit contract is incomplete")
    edit_contract = data.get("edit_transaction_contract", {})
    continued = edit_contract.get("continue_draft_actions", {})
    committed = edit_contract.get("commit_actions", {})
    for node_id, node in nodes.items():
        if not node_id.startswith("edit_"):
            continue
        classified = set(continued.get(node_id, [])) | set(committed.get(node_id, [])) | set(edit_contract.get("no_op_actions", {}).get(node_id, {}))
        for action_id, action in node.get("actions", {}).items():
            if action.get("mutation") and action_id not in classified:
                errors.append(f"{node_id}.{action_id}: edit mutation lacks draft-or-commit classification")
    result_edit = nodes.get("result", {}).get("actions", {}).get("edit_facts", {})
    if result_edit.get("invalidates") or result_edit.get("operation") != "enter_fact_review_preserve_result_until_first_atomic_commit":
        errors.append("opening fact review invalidates the result before a fact changes")
    for action_id in expected_edit_contract["result_review_entry_actions"]:
        if nodes.get("result", {}).get("actions", {}).get(action_id, {}).get("operation") != "enter_fact_review_preserve_result_until_first_atomic_commit":
            errors.append(f"result.{action_id}: result-review context is not established")
    fact_back = nodes.get("confirm_facts", {}).get("actions", {}).get("back", {})
    if fact_back.get("outcomes") != {"valid_result_review": "result", "initial_collection": "fact_amount"}:
        errors.append("fact-review Back cannot return to an unchanged valid result")
    year_noop = nodes.get("edit_tax_year", {}).get("actions", {}).get("confirm_current_year", {})
    if year_noop != {"to": "confirm_facts", "operation": "no_op_close_edit_transaction_and_return_to_review_context_without_effects"}:
        errors.append("same-current-year edit can clear facts or force recollection")
    help_back = nodes.get("existing_overcontribution_help", {}).get("actions", {}).get("back", {})
    if help_back.get("operation") != "cancel_result_review_and_restore_valid_result":
        errors.append("overcontribution help Back leaves dangling result-review context")
    for correction, retry, next_node in (
        ("teach_back_correction", "teach_back", "next_action"),
        ("insufficient_education_correction", "insufficient_education_teach_back", "insufficient_next_action"),
        ("education_teach_back_correction", "education_teach_back", "education_next_action"),
    ):
        actions = nodes.get(correction, {}).get("actions", {})
        if actions.get("retry_simplified", {}).get("to") != retry:
            errors.append(f"{correction}: correction must recheck comprehension")
        anyway = actions.get("continue_anyway", {})
        if anyway.get("to") != next_node or anyway.get("meaning") != "proceed_without_confirmed_comprehension":
            errors.append(f"{correction}: honest continue-anyway escape is missing")
    restart = nodes.get("reference_saved", {}).get("actions", {}).get("restart", {})
    if restart.get("persistence") != "clear_local_reference_and_ephemeral_and_session_result":
        errors.append("reference restart must clear the old local reference")
    binding = data.get("renderer_binding", {})
    if binding.get("status") not in {"not_implemented", "verified"}:
        errors.append("renderer binding status is invalid")
    if binding.get("status") == "not_implemented" and data.get("flutter_allowed") is not False:
        errors.append("Flutter cannot be allowed before renderer binding exists")
    if binding.get("status") == "verified" and not binding.get("verified_manifest"):
        errors.append("verified renderer binding requires a manifest")
    if binding.get("verified_manifest_storage") != "ignored_runtime_evidence_generated_after_checkout_not_committed":
        errors.append("renderer manifest storage must avoid a self-referential commit")
    if binding.get("source_binding") != "manifest_source_commit_equals_checked_out_head_and_navigation_sha256_matches_this_file":
        errors.append("renderer source binding is incomplete")
    if binding.get("status") == "verified" and binding.get("verified_manifest"):
        manifest_path = ROOT / binding["verified_manifest"]
        if not manifest_path.is_file():
            errors.append("verified renderer manifest is missing")
        else:
            manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
            expected = {node_id: sorted(node.get("actions", {})) for node_id, node in nodes.items()}
            if manifest.get("generated_by") != "flutter_design_lab_runtime_probe":
                errors.append("renderer manifest is not runtime-generated")
            required_evidence = {"source_commit", "runtime_probe", "node_actions", "overlay_actions", "render_receipts"}
            required_evidence.update({"teach_back_semantics", "localized_semantic_receipts"})
            if not required_evidence.issubset(manifest):
                errors.append("renderer manifest lacks runtime evidence")
            if manifest.get("node_actions") != expected:
                errors.append("renderer manifest is not bidirectionally equal to navigation graph")
            expected_overlays = {overlay_id: sorted(overlay.get("actions", {})) for overlay_id, overlay in overlays.items()}
            if manifest.get("overlay_actions") != expected_overlays:
                errors.append("renderer manifest overlays diverge from navigation graph")
            semantic_expected = {
                mode: {"choose_correct": "correct", "choose_incorrect": "incorrect", "choose_unknown": "unknown"}
                for mode in data.get("teach_back_contract", {}).get("modes", [])
            }
            if manifest.get("teach_back_semantics") != semantic_expected:
                errors.append("renderer teach-back semantics diverge from the written answer mapping")
            semantic_receipts = manifest.get("localized_semantic_receipts", {})
            if set(semantic_receipts) != set(data.get("teach_back_contract", {}).get("locales", [])):
                errors.append("renderer localized teach-back semantic receipts are incomplete")
            else:
                for locale, receipt in semantic_receipts.items():
                    if not isinstance(receipt, dict) or not receipt.get("path") or not receipt.get("sha256"):
                        errors.append(f"renderer localized teach-back receipt is malformed: {locale}")
                        continue
                    receipt_path = ROOT / receipt["path"]
                    if not receipt_path.is_file() or hashlib.sha256(receipt_path.read_bytes()).hexdigest() != receipt["sha256"]:
                        errors.append(f"renderer localized teach-back receipt hash is invalid: {locale}")
            try:
                current_head = subprocess.run(
                    ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
                    capture_output=True, text=True,
                ).stdout.strip()
            except (OSError, subprocess.CalledProcessError):
                current_head = ""
            if manifest.get("source_commit") != current_head:
                errors.append("renderer manifest source commit is not current HEAD")
            if manifest.get("navigation_sha256") != hashlib.sha256(path.read_bytes()).hexdigest():
                errors.append("renderer manifest navigation hash is invalid")
            try:
                ignored = subprocess.run(
                    ["git", "check-ignore", "-q", str(manifest_path)], cwd=ROOT,
                    check=False,
                ).returncode == 0
            except OSError:
                ignored = False
            if not ignored:
                errors.append("renderer manifest must be generated in a git-ignored runtime-evidence path")
            probe = manifest.get("runtime_probe", {})
            if not isinstance(probe, dict) or probe.get("status") != "passed" or not probe.get("evidence_path") or not probe.get("sha256"):
                errors.append("renderer runtime probe evidence is not verifiable")
            else:
                evidence_path = ROOT / probe["evidence_path"]
                if not evidence_path.is_file() or hashlib.sha256(evidence_path.read_bytes()).hexdigest() != probe["sha256"]:
                    errors.append("renderer runtime probe evidence hash is invalid")
            receipts = manifest.get("render_receipts", [])
            if not isinstance(receipts, list) or not receipts:
                errors.append("renderer render receipts are missing")
            else:
                for receipt in receipts:
                    if not isinstance(receipt, dict) or not receipt.get("path") or not receipt.get("sha256"):
                        errors.append("renderer render receipt is malformed")
                        continue
                    receipt_path = ROOT / receipt["path"]
                    if not receipt_path.is_file() or hashlib.sha256(receipt_path.read_bytes()).hexdigest() != receipt["sha256"]:
                        errors.append(f"renderer render receipt hash is invalid: {receipt.get('path')}")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch6_navigation_guard: graph is reachable, escapable, and destination-complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
