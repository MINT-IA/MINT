#!/usr/bin/env python3
"""Fail closed when the bounded Batch 8 LPP navigation contract drifts."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SCOPE = ROOT / "product/mint_next/batch8/lpp-affiliation-scope.yaml"
SOURCES = ROOT / "product/mint_next/batch8/official-sources.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch8/lpp-affiliation-acceptance.yaml"
NAVIGATION = ROOT / "product/mint_next/batch6/navigation.yaml"
EXPECTED_SCOPE_SHA256 = "5a8cbbbaf70ae36b6b49add173ef5d36205bfcfa93d67ee0bac0980ef608ebfc"
EXPECTED_SOURCES_SHA256 = "7014446847361acf6a24921ce3397d32d7981e425ef413cdb3378bbffab0c07b"
EXPECTED_ACCEPTANCE_SHA256 = "bb69f883de45f79af7ff430749857a406a3490ef29059597cfd6501941616727"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(scope_path: Path = SCOPE, sources_path: Path = SOURCES, acceptance_path: Path = ACCEPTANCE) -> list[str]:
    errors: list[str] = []
    scope = yaml.safe_load(scope_path.read_text(encoding="utf-8"))
    sources = yaml.safe_load(sources_path.read_text(encoding="utf-8"))
    navigation = yaml.safe_load(NAVIGATION.read_text(encoding="utf-8"))
    acceptance = yaml.safe_load(acceptance_path.read_text(encoding="utf-8"))
    expected_nodes = ["fact_lpp_affiliation", "lpp_unknown_help", "without_lpp_boundary"]

    if digest(scope_path) != EXPECTED_SCOPE_SHA256:
        errors.append("Batch8 exact written scope digest drift")
    if digest(sources_path) != EXPECTED_SOURCES_SHA256:
        errors.append("Batch8 exact official sources digest drift")
    if digest(acceptance_path) != EXPECTED_ACCEPTANCE_SHA256:
        errors.append("Batch8 exact acceptance receipt digest drift")
    if acceptance.get("status") != "mechanically_accepted_written_contract_runtime_unimplemented" or acceptance.get("scope", {}).get("sha256") != EXPECTED_SCOPE_SHA256 or acceptance.get("sources", {}).get("sha256") != EXPECTED_SOURCES_SHA256:
        errors.append("Batch8 acceptance receipt binding drift")
    if acceptance.get("mechanical_acceptance_basis") != {
        "authority": "exact_hash_bound_contract_and_deterministic_mutation_tests",
        "advisory_roasts_authorize_acceptance": False,
        "limitation": "agent_identity_independence_and_truthfulness_are_not_authenticated",
    }:
        errors.append("Batch8 mechanical acceptance basis drift")

    if set(scope) != {
        "schema_version", "status", "journey_id", "authority", "slice", "audience",
        "human_outcome", "fact_contract", "node_contracts", "interaction_contract",
        "accessibility_contract", "content_boundaries", "legacy_decisions", "exit_gate",
    }:
        errors.append("Batch8 scope top-level schema drift")
    if scope.get("authority", {}).get("navigation_sha256") != digest(NAVIGATION):
        errors.append("Batch8 scope is not bound to the accepted navigation")
    if scope.get("slice") != {
        "entry_from": "fact_tax_year.continue", "nodes": expected_nodes,
        "successful_continuation": "fact_contribution", "locales": ["fr", "en", "de", "it", "es", "pt"],
    }:
        errors.append("Batch8 node slice drift")

    nav_nodes = navigation.get("nodes", {})
    expected_routes = {"choose_yes": "fact_contribution", "choose_no": "without_lpp_boundary", "choose_unknown": "lpp_unknown_help", "back": "fact_tax_year"}
    nav_actions = nav_nodes.get("fact_lpp_affiliation", {}).get("actions", {})
    for node_id in expected_nodes:
        if node_id not in nav_nodes:
            errors.append(f"Batch8 node absent from canonical navigation: {node_id}")
    for action, destination in expected_routes.items():
        if nav_actions.get(action, {}).get("to") != destination:
            errors.append(f"Batch8 canonical route drift: fact_lpp_affiliation.{action}")

    expected_controls = {
        "choose_yes": {"label_intent": "Yes", "immediate_to": "fact_contribution", "mutation": "lpp_affiliation_yes"},
        "choose_no": {"label_intent": "No", "immediate_to": "without_lpp_boundary", "mutation": "lpp_affiliation_no"},
        "choose_unknown": {"label_intent": "I do not know", "immediate_to": "lpp_unknown_help", "mutation": "lpp_affiliation_unknown"},
        "back": {"to": "fact_tax_year"}, "open_safe_exit": {"overlay": "safe_exit"},
    }
    if scope.get("node_contracts", {}).get("fact_lpp_affiliation", {}).get("controls") != expected_controls:
        errors.append("Batch8 written affiliation controls drift")

    fact = scope.get("fact_contract", {})
    if fact.get("allowed_values") != ["yes", "no", "unknown"] or fact.get("default") is not None:
        errors.append("Batch8 affiliation fact must remain tri-state without a default")
    if set(fact.get("forbidden_inferences", [])) != {"salary", "age", "employment_status", "profession", "existing_lpp_balance"}:
        errors.append("Batch8 forbidden affiliation inferences drift")

    contracts = scope.get("node_contracts", {})
    unknown = contracts.get("lpp_unknown_help", {})
    boundary = contracts.get("without_lpp_boundary", {})
    if not {"guess_affiliation", "convert_unknown_to_no", "show_personal_ceiling", "continue_personal_estimate"}.issubset(unknown.get("forbidden", [])):
        errors.append("Batch8 unknown path is not fail-closed")
    if not {"claim_pillar3a_ineligibility", "show_with_lpp_ceiling", "show_without_lpp_ceiling", "calculate_personal_result"}.issubset(boundary.get("forbidden", [])):
        errors.append("Batch8 no-LPP boundary is not honest and calculation-free")

    reference_actions = {"lpp_unknown_help": "keep_checklist_local", "without_lpp_boundary": "keep_explanation_local"}
    for node_id, action_id in reference_actions.items():
        controls = contracts[node_id]["controls"]
        if set(controls) != {"back", action_id, "open_safe_exit"}:
            errors.append(f"Batch8 {node_id} control set is not closed")
        if controls.get(action_id) != {"enabled": False, "canonical_destination": "reference_saved", "reason": "persistence_not_implemented", "visual_state": "disabled_with_unavailable_label"}:
            errors.append(f"Batch8 {node_id} falsely claims local persistence")
        if controls.get("back") != {"operation": "history_back", "allowed_predecessors": ["fact_lpp_affiliation"]} or controls.get("open_safe_exit") != {"overlay": "safe_exit"}:
            errors.append(f"Batch8 {node_id} controls drift from bounded canonical path")
        if nav_nodes.get(node_id, {}).get("actions", {}).get(action_id, {}).get("to") != "reference_saved":
            errors.append(f"Batch8 canonical reference action drift: {node_id}.{action_id}")

    question = contracts.get("fact_lpp_affiliation", {}).get("reference_copy_fr", {})
    if question.get("title") != "As-tu actuellement une caisse de pension ?" or "volontaire" not in question.get("body", "") or "pas combien tu verses" not in question.get("body", ""):
        errors.append("Batch8 exact French question confuses contribution with affiliation")
    if unknown.get("evidence_list_semantics") != "ordered_informative_list_not_interactive_controls" or "reprends ce parcours" not in unknown.get("reference_copy_fr", {}).get("body", ""):
        errors.append("Batch8 unknown help promises unsupported resume or fake controls")
    for node_id in expected_nodes:
        if not contracts[node_id].get("reference_copy_fr") or not contracts[node_id].get("required_arb_keys"):
            errors.append(f"Batch8 exact reference copy is missing: {node_id}")

    accessibility = scope.get("accessibility_contract", {})
    if accessibility.get("choice_pattern") != "selected_button_group" or accessibility.get("activation") != "tap_commits_then_routes_immediately_without_continue_cta":
        errors.append("Batch8 choice accessibility pattern is ambiguous")
    if accessibility.get("required_proofs") != ["320x700_text_scale_2_no_loss", "390x844_runtime", "screen_reader_labels", "keyboard_focus_order"]:
        errors.append("Batch8 accessibility proof set drift")
    if scope.get("interaction_contract") != {
        "selection": "no_preselection_one_tap_routes_immediately", "repeated_tap": "idempotent",
        "back_from_yes_destination": "fact_lpp_affiliation_with_yes_visible",
        "back_from_boundaries_destination": "fact_lpp_affiliation_with_previous_choice_visible",
        "safe_exit": "reuse_batch7_overlay_and_purge_ephemeral_on_leave_without_saving",
        "app_kill": "reuse_navigation_lifecycle_restart_and_clear",
    }:
        errors.append("Batch8 interaction and recovery contract drift")
    if scope.get("content_boundaries") != {
        "no_amounts_or_percentages": True, "no_product_or_provider_recommendation": True,
        "no_personal_financial_advice": True, "no_account_required": True, "no_persistence_claim": True,
    }:
        errors.append("Batch8 content boundary drift")
    if scope.get("exit_gate") != {
        "required": ["contract_guard", "navigation_tests", "six_locale_parity", "accessibility_tests", "real_runtime_capture", "ux_roast", "accessibility_roast", "swiss_compliance_roast"],
        "accepted_only_if": "deterministic_proofs_pass_and_p1_zero_and_p2_zero", "user_test_required_for_this_batch": False,
    }:
        errors.append("Batch8 exit gate drift")

    expected_sources = [
        {"id": "ofas_third_pillar", "authority": "Office fédéral des assurances sociales", "url": "https://www.bsv.admin.ch/fr/le-troisieme-pilier", "published_at": "2026-02-10", "supports": ["pillar_3a_requires_earned_income_subject_to_avs", "contribution_rule_differs_by_actual_second_pillar_affiliation", "no_lpp_rule_is_not_synonymous_with_self_employment"]},
        {"id": "ofas_occupational_pension", "authority": "Office fédéral des assurances sociales", "url": "https://www.bsv.admin.ch/fr/prevoyance-vieillesse-prevoyance-professionnelle", "published_at": "2026-01-05", "supports": ["occupational_pension_is_second_pillar", "compulsory_affiliation_has_exceptions_and_voluntary_cases"]},
    ]
    expected_inference = [{"id": "do_not_infer_actual_affiliation_from_demographics_or_job_status", "statement": "Age, salary or job status alone is not sufficient UI evidence of a person's actual current affiliation.", "reasoning": "The official rules describe thresholds and start dates, but also exceptions and voluntary affiliation; MINT therefore asks the person instead of inferring the fact.", "source_ids": ["ofas_occupational_pension"], "source_anchors": ["Qui est assuré", "compulsory exceptions", "voluntary minimum insurance"], "classification": "product_safety_inference_not_direct_official_quote"}]
    if set(sources) != {"schema_version", "checked_at", "retrieved_at", "jurisdiction", "scope", "sources", "derived_inferences", "implementation_limit"} or sources.get("sources") != expected_sources or sources.get("derived_inferences") != expected_inference:
        errors.append("Batch8 official source receipt drift")
    if sources.get("implementation_limit", {}).get("amounts_or_thresholds_authorized_in_batch8_ui") is not False:
        errors.append("Batch8 sources receipt authorizes premature numbers")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch8_lpp_scope_guard: written tri-state LPP slice is bounded and source-linked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
