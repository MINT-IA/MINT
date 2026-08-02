#!/usr/bin/env python3
"""Fail closed when the bounded Batch 9 contribution-status contract drifts."""

from __future__ import annotations

import hashlib
import ast
import re
import sys
from datetime import datetime
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SCOPE = ROOT / "product/mint_next/batch9/contribution-status-scope.yaml"
SOURCES = ROOT / "product/mint_next/batch9/official-sources.yaml"
LEGACY = ROOT / "product/mint_next/batch9/legacy-inventory.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch9/contribution-status-acceptance.yaml"
CI_WORKFLOW = ROOT / ".github/workflows/mint-next-batch9-contract.yml"
TESTS = ROOT / "tools/checks/tests/test_mint_next_batch9_contribution_scope_guard.py"
SPEC = ROOT / ".planning/phases/mint-next-vertical01-3a-20260802/SPEC.md"
LEFTHOOK = ROOT / "lefthook.yml"
JOURNEY_GUARD = ROOT / "tools/checks/journey_os_check.py"
NAVIGATION = ROOT / "product/mint_next/batch6/navigation.yaml"
PREVIOUS_ACCEPTANCE = ROOT / "product/mint_next/batch8/design-lab-acceptance.yaml"

EXPECTED_SCOPE_SHA256 = "64d941ce3c974c76bf5f3e40cb85a5a5e323cfe9b9f4eacbc8ee234d9722f83d"
EXPECTED_SOURCES_SHA256 = "8343040e400603f5634574aa84142be4c3b6bbc351049ea2ee4584f9777eaf98"
EXPECTED_LEGACY_SHA256 = "95c5cbb0f4034f302ddd977e676b05316c0182f389d3bfa9d961040cccf15214"
EXPECTED_PREVIOUS_ACCEPTANCE_SHA256 = "108817ab4424897efc78a8e22e6928473cace44c76fb86fee7ae1f23fae48add"
EXPECTED_CI_WORKFLOW_NORMALIZED_SHA256 = "d6f2260b77d52af6d5c6aebbaa4a37e18deaaa7e4097efcec30c6322fa07c053"


class _UniqueKeyLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False) -> dict[object, object]:
    result: dict[object, object] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


_UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized_ci_digest(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    normalized = re.sub(
        r"(?m)^(  EXPECTED_BATCH9_(?:GUARD|TESTS|ACCEPTANCE)_SHA256:) .+$",
        r"\1 <BOUND>",
        text,
    )
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def ci_binding(path: Path, name: str) -> str | None:
    match = re.search(rf"(?m)^  {re.escape(name)}: ([0-9a-f]{{64}})$", path.read_text(encoding="utf-8"))
    return match.group(1) if match else None


def _spec_verify_command(path: Path, key: str) -> str | None:
    match = re.search(r"(?ms)^```verify\s*$\n(.*?)^```\s*$", path.read_text(encoding="utf-8"))
    if not match:
        return None
    commands: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line.strip():
            continue
        item = re.fullmatch(r"([a-z0-9-]+):\s+(.+)", line)
        if not item or item.group(1) in commands:
            return None
        commands[item.group(1)] = item.group(2)
    return commands.get(key)


def _journey_allow(path: Path) -> set[str] | None:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "ALLOW" for target in node.targets):
            if not isinstance(node.value, ast.Set):
                return None
            return {item.value for item in node.value.elts if isinstance(item, ast.Constant) and isinstance(item.value, str)}
    return None


def _load(path: Path) -> dict:
    value = yaml.load(path.read_text(encoding="utf-8"), Loader=_UniqueKeyLoader)
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} root is not a mapping")
    return value


def validate(
    scope_path: Path = SCOPE,
    sources_path: Path = SOURCES,
    legacy_path: Path = LEGACY,
    acceptance_path: Path = ACCEPTANCE,
    ci_workflow_path: Path = CI_WORKFLOW,
) -> list[str]:
    errors: list[str] = []
    try:
        scope = _load(scope_path)
        sources = _load(sources_path)
        legacy = _load(legacy_path)
        acceptance = _load(acceptance_path)
        navigation = _load(NAVIGATION)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        return [f"Batch9 contract unreadable: {exc}"]

    if digest(scope_path) != EXPECTED_SCOPE_SHA256:
        errors.append("Batch9 scope exact digest drift")
    if digest(sources_path) != EXPECTED_SOURCES_SHA256:
        errors.append("Batch9 official sources exact digest drift")
    if digest(legacy_path) != EXPECTED_LEGACY_SHA256:
        errors.append("Batch9 legacy inventory exact digest drift")
    if not ci_workflow_path.is_file() or normalized_ci_digest(ci_workflow_path) != EXPECTED_CI_WORKFLOW_NORMALIZED_SHA256:
        errors.append("Batch9 CI workflow exact digest drift")
    if digest(acceptance_path) != ci_binding(ci_workflow_path, "EXPECTED_BATCH9_ACCEPTANCE_SHA256"):
        errors.append("Batch9 acceptance exact digest drift")
    if (
        digest(Path(__file__)) != ci_binding(ci_workflow_path, "EXPECTED_BATCH9_GUARD_SHA256")
        or digest(TESTS) != ci_binding(ci_workflow_path, "EXPECTED_BATCH9_TESTS_SHA256")
    ):
        errors.append("Batch9 verifier trust-unit binding drift")

    expected_top = {
        "schema_version", "status", "journey_id", "authority", "slice", "audience",
        "human_outcome", "fact_contract", "node_contracts", "interaction_contract",
        "accessibility_contract", "six_locale_intent_contract", "content_boundaries",
        "legacy_decisions", "exit_gate",
    }
    if set(scope) != expected_top or scope.get("status") != "draft_written_contract_runtime_forbidden":
        errors.append("Batch9 scope schema or draft-only status drift")
    authority = scope.get("authority", {})
    if authority != {
        "navigation_contract": "product/mint_next/batch6/navigation.yaml",
        "navigation_sha256": digest(NAVIGATION),
        "previous_accepted_slice": "product/mint_next/batch8/design-lab-acceptance.yaml",
        "semantic_refinement": "fact_contribution_means_ordinary_contribution_actually_credited_for_selected_year",
        "route_change": "none",
    } or digest(PREVIOUS_ACCEPTANCE) != EXPECTED_PREVIOUS_ACCEPTANCE_SHA256 or _load(PREVIOUS_ACCEPTANCE).get("status") != "mechanically_accepted_isolated_lpp_affiliation_slice":
        errors.append("Batch9 authority or semantic-refinement binding drift")

    expected_slice = {
        "entry_from": "fact_lpp_affiliation.choose_yes",
        "nodes": ["fact_contribution", "contribution_unknown_help"],
        "boundary_nodes": ["fact_contributed_amount", "fact_canton", "education_explanation"],
        "routes": {"yes": "fact_contributed_amount", "no": "fact_canton", "unknown": "contribution_unknown_help", "unknown_education_only": "education_explanation"},
        "locales": ["fr", "en", "de", "it", "es", "pt"],
    }
    if scope.get("slice") != expected_slice:
        errors.append("Batch9 exact node slice drift")

    nav_nodes = navigation.get("nodes", {})
    nav_actions = nav_nodes.get("fact_contribution", {}).get("actions", {})
    expected_routes = {
        "choose_yes": "fact_contributed_amount", "choose_no": "fact_canton",
        "choose_unknown": "contribution_unknown_help", "back": "fact_lpp_affiliation",
    }
    for action, destination in expected_routes.items():
        if nav_actions.get(action, {}).get("to") != destination:
            errors.append(f"Batch9 canonical route drift: fact_contribution.{action}")
    if nav_nodes.get("contribution_unknown_help", {}).get("actions", {}).get("continue_education_only", {}).get("to") != "education_explanation":
        errors.append("Batch9 canonical education-only route drift")

    fact = scope.get("fact_contract", {})
    if fact.get("id") != "ordinary_3a_contribution_credited_any_provider_for_selected_year" or fact.get("tax_year_ref") != "tax_year":
        errors.append("Batch9 fact identity or tax-year binding drift")
    if fact.get("allowed_values") != ["yes", "no", "unknown"] or fact.get("default") is not None or fact.get("storage") != "ephemeral":
        errors.append("Batch9 contribution fact must remain explicit tri-state without default")
    if set(fact.get("never_derive_from", [])) != {"has_3a_account", "existing_3a_balance", "planned_contribution", "standing_order", "bank_account_debit", "missing_document", "missing_amount"}:
        errors.append("Batch9 unsafe contribution inference became allowed")
    if set(fact.get("explicit_exclusions", [])) != {"provider_to_provider_3a_transfer", "uncredited_or_pending_payment", "retroactive_buyback_for_past_year", "fully_refunded_or_reversed_amount"}:
        errors.append("Batch9 special movements are no longer excluded")
    if fact.get("invariants") != {
        "yes": "credited_ordinary_total_remains_unknown_until_next_node",
        "no": "stored_amount_remains_null_and_calculation_adapter_may_use_zero_only_after_explicit_no",
        "unknown": "stored_amount_remains_null_and_personal_calculation_is_forbidden",
    }:
        errors.append("Batch9 yes/no/unknown amount invariants drift")

    contracts = scope.get("node_contracts", {})
    question = contracts.get("fact_contribution", {})
    expected_controls = {
        "choose_yes": {"label_intent": "at_least_one_ordinary_contribution_credited", "immediate_to": "fact_contributed_amount", "mutation": "contribution_status_yes"},
        "choose_no": {"label_intent": "no_ordinary_contribution_credited", "immediate_to": "fact_canton", "mutation": "contribution_status_no", "clears": ["contributed_amount", "ephemeral_provider_rows"]},
        "choose_unknown": {"label_intent": "unknown_credit_or_classification", "immediate_to": "contribution_unknown_help", "mutation": "contribution_status_unknown", "clears": ["contributed_amount", "ephemeral_provider_rows"]},
        "toggle_edge_help": {"operation": "same_node_disclosure", "default_expanded": False},
        "back": {"to": "fact_lpp_affiliation"},
        "open_safe_exit": {"overlay": "safe_exit"},
    }
    if question.get("controls") != expected_controls:
        errors.append("Batch9 written contribution controls drift")
    copy = question.get("reference_copy_fr", {})
    if copy != {
        "eyebrow": "Tes versements 3a · {taxYear}",
        "title": "En {taxYear}, l’un de tes 3a a-t-il reçu un nouveau versement ?",
        "body": "Réponds pour tous tes 3a, y compris une assurance 3a.",
        "credited_note": "Compte seulement l’argent neuf reçu pour {taxYear}. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.",
        "amount_note": "Pas besoin de connaître le total maintenant. On te le demandera seulement si tu réponds oui.",
        "choose_yes": "Oui, un nouveau versement a été reçu",
        "choose_no": "Non, aucun nouveau versement",
        "choose_unknown": "Je ne sais pas",
        "edge_help": "Ce qui compte — et ce qui ne compte pas",
    }:
        errors.append("Batch9 exact beginner French question drift")
    if question.get("all_provider_scope") != "every_personal_3a_bank_fintech_and_insurance_contract":
        errors.append("Batch9 question no longer covers every provider")
    edge = question.get("edge_help_contract", {})
    if set(edge.get("cases", {})) != {"pending_or_scheduled", "provider_transfer", "retroactive_buyback", "full_refund_or_reversal", "partial_refund_known_net", "refund_or_correction_unclear", "mixed_transfer_and_new_money", "investment_return_or_interest", "non_contribution_adjustment"} or edge.get("pattern") != "same_node_disclosure":
        errors.append("Batch9 edge-case help is incomplete or became a route")

    unknown = contracts.get("contribution_unknown_help", {})
    if not {"convert_unknown_to_no", "infer_zero", "continue_personal_estimate", "show_remaining_room", "claim_tax_deduction"}.issubset(unknown.get("forbidden", [])):
        errors.append("Batch9 unknown path is not fail-closed")
    if unknown.get("controls") != {
        "continue_education_only": {"to": "education_explanation", "mode": "general_education_no_personal_amount"},
        "back": {"operation": "history_back", "allowed_predecessors": ["fact_contribution"]},
        "open_safe_exit": {"overlay": "safe_exit"},
    } or unknown.get("evidence_list_semantics") != "ordered_informative_list_not_interactive_controls":
        errors.append("Batch9 unknown help controls or semantics drift")
    if "N’additionne jamais un transfert" not in unknown.get("reference_copy_fr", {}).get("transfer_warning", ""):
        errors.append("Batch9 unknown help permits transfer double-counting")

    yes_boundary = contracts.get("fact_contributed_amount_boundary", {})
    no_boundary = contracts.get("fact_canton_boundary", {})
    if not {"assume_total", "include_transfer", "include_retroactive_buyback", "calculate_remaining_room"}.issubset(yes_boundary.get("forbidden", [])):
        errors.append("Batch9 yes boundary overclaims an amount or calculation")
    if not {"claim_proven_zero_without_user_answer", "show_remaining_room", "calculate_tax_saving"}.issubset(no_boundary.get("forbidden", [])):
        errors.append("Batch9 no boundary overclaims a result")

    expected_interaction = {
        "selection": "no_preselection_one_tap_routes_immediately", "repeated_tap": "idempotent",
        "back_from_question": "fact_lpp_affiliation_with_yes_visible",
        "back_from_yes_boundary": "fact_contribution_with_yes_visible",
        "back_from_no_boundary": "fact_contribution_with_no_visible",
        "back_from_unknown_help": "fact_contribution_with_unknown_visible",
        "resume": "preserve_node_scroll_disclosure_and_ephemeral_facts",
        "leave_without_saving": "clear_contribution_status_amount_provider_rows_and_all_prior_ephemeral_facts",
        "app_kill_or_ttl_expiry": "restart_and_clear",
        "tax_year_rollover": "return_to_tax_year_and_clear_year_scoped_contribution_facts",
        "no_resume_promise_without_implemented_local_reference": True,
    }
    if scope.get("interaction_contract") != expected_interaction:
        errors.append("Batch9 interaction, exit or year-rollover contract drift")

    accessibility = scope.get("accessibility_contract", {})
    expected_safe_exit = {
        "trigger_role": "button",
        "trigger_visible_copy_fr": "Quitter",
        "trigger_accessible_copy_fr": "Quitter ce parcours",
        "trigger_label_intent": "leave_this_journey",
        "overlay_initial_focus": "safe_exit_heading",
        "overlay_focus_trap": True,
        "resume_returns_focus_to_trigger": True,
        "system_back_or_escape": "dismiss_overlay_without_mutation_and_return_focus",
        "leave_action_clears_ephemeral_facts_before_dismissed_boundary": True,
    }
    if (
        accessibility.get("choice_pattern") != "selected_button_group"
        or accessibility.get("dynamic_year_in_choice_group_label") is not True
        or accessibility.get("repeat_year_in_each_choice_label") is not False
        or accessibility.get("edge_help_pattern") != "disclosure_button_with_expanded_state"
        or accessibility.get("reading_order") != ["global_header", "safe_exit", "question", "definition", "credited_note", "amount_note", "edge_help", "choices", "back"]
        or accessibility.get("safe_exit") != expected_safe_exit
    ):
        errors.append("Batch9 accessibility choice/year/disclosure contract drift")
    if question.get("required_arb_keys") != ["contributionEyebrow", "contributionTitle", "contributionBody", "contributionCreditedNote", "contributionAmountNote", "contributionChoiceYes", "contributionChoiceNo", "contributionChoiceUnknown", "contributionEdgeHelp"]:
        errors.append("Batch9 question ARB delivery contract drift")
    if (
        accessibility.get("choice_semantics") != "each_full_width_choice_is_a_button_and_exposes_selected_state_on_return"
        or accessibility.get("focus_on_route") != "first_semantic_heading"
        or accessibility.get("minimum_touch_target") != "48x48_logical_pixels"
    ):
        errors.append("Batch9 critical accessibility semantics drift")
    if accessibility.get("required_proofs") != ["320x700_text_scale_2_all_routes_and_safe_exit", "390x844_runtime", "screen_reader_labels", "keyboard_focus_order", "reduced_motion"]:
        errors.append("Batch9 accessibility proof matrix drift")
    locale_contract = scope.get("six_locale_intent_contract", {})
    required_distinctions = {"actually_credited_not_merely_sent_ordered_or_debited", "ordinary_new_contribution_not_provider_transfer", "selected_tax_year_not_habitual_annual_plan", "all_bank_fintech_and_insurance_3a_contracts", "retroactive_buyback_is_separate", "unknown_never_means_no"}
    if set(locale_contract.get("required_distinctions", [])) != required_distinctions or locale_contract.get("semantic_review_required_per_locale") is not True or locale_contract.get("key_parity_alone_is_insufficient") is not True:
        errors.append("Batch9 six-locale semantic contract drift")

    if scope.get("content_boundaries") != {
        "no_amounts_thresholds_or_percentages": True, "no_remaining_room_or_tax_saving": True,
        "no_product_or_provider_recommendation": True, "no_personal_financial_advice": True,
        "no_account_required": True, "no_persistence_claim": True,
        "no_retroactive_buyback_calculation": True,
    }:
        errors.append("Batch9 content boundary drift")
    user_copy = " ".join(str(contract.get("reference_copy_fr", {})) for contract in contracts.values())
    if re.search(r"(?:CHF|francs?|\d[’' ]?\d{3}|\d+\s*%)", user_copy, re.I):
        errors.append("Batch9 written UI leaks an amount, threshold or percentage")

    expected_source_ids = ["estv_circular_18a", "estv_form_21_edp_notice", "ofas_your_third_pillar_contribution"]
    if set(sources) != {"schema_version", "checked_at", "retrieved_at", "jurisdiction", "scope", "sources", "direct_facts", "derived_product_safety_inferences", "implementation_limits"}:
        errors.append("Batch9 official source receipt schema drift")
    if [item.get("id") for item in sources.get("sources", [])] != expected_source_ids:
        errors.append("Batch9 official source set drift")
    if any(not str(item.get("url", "")).startswith(("https://www.estv.admin.ch/", "https://www.bsv.admin.ch/")) for item in sources.get("sources", [])):
        errors.append("Batch9 non-federal source entered the authority receipt")
    required_facts = {"credit_to_the_individual_3a_account_or_policy_is_decisive_not_order_or_debit", "ordinary_contributions_share_one_annual_total_across_all_3a_banks_and_insurers", "each_provider_attestation_covers_that_provider_so_multiple_providers_require_multiple_evidence_items", "a_provider_transfer_is_not_a_new_ordinary_contribution", "retroactive_buybacks_are_attested_separately_from_ordinary_contributions", "effective_amount_may_change_after_refund_or_correction"}
    if set(sources.get("direct_facts", [])) != required_facts or sources.get("implementation_limits") != {"authorize_amount_or_personal_result": False, "authorize_remaining_room_or_tax_saving": False, "ordinary_contribution_only": True, "retroactive_buyback_calculation": "deferred"}:
        errors.append("Batch9 official facts or implementation limits drift")

    if set(legacy) != {"schema_version", "audited_at", "scope", "verdict", "required_new_fact", "candidates", "dangerous_assumptions", "legacy_code_reused_in_batch9_runtime"} or legacy.get("verdict") != "no_legacy_fact_is_safe_for_direct_reuse" or legacy.get("legacy_code_reused_in_batch9_runtime") is not False:
        errors.append("Batch9 legacy inventory verdict or schema drift")
    candidates = legacy.get("candidates", [])
    if len(candidates) != 10 or any(not isinstance(item.get("score"), int) or not 0 <= item["score"] <= 10 for item in candidates):
        errors.append("Batch9 legacy candidates are not exhaustively scored")
    if not any(item.get("score") == 9 and item.get("decision") == "harvest_later_annual_ceiling_only" for item in candidates):
        errors.append("Batch9 legacy inventory lost the bounded calculator decision")
    if not {"null_or_missing_means_zero_or_no", "ordinary_contribution_can_include_transfer_or_retroactive_buyback", "timeless_pillar3aAnnual_is_safe_personal_evidence"}.issubset(legacy.get("dangerous_assumptions", [])):
        errors.append("Batch9 legacy danger inventory drift")

    expected_command = "python3 tools/checks/mint_next_batch9_contribution_scope_guard.py"
    wiring_failures: list[Path] = []
    if not SPEC.is_file() or _spec_verify_command(SPEC, "batch9-contribution-written-scope") != expected_command:
        wiring_failures.append(SPEC)
    try:
        hook = _load(LEFTHOOK).get("pre-commit", {}).get("commands", {}).get("mint-next-batch9-contribution-scope-guard", {})
    except (OSError, ValueError, yaml.YAMLError):
        hook = {}
    if hook.get("run") != expected_command:
        wiring_failures.append(LEFTHOOK)
    try:
        allow = _journey_allow(JOURNEY_GUARD)
    except (OSError, SyntaxError, ValueError):
        allow = None
    if allow is None or "product/mint_next/batch9/contribution-status-acceptance.yaml" not in allow:
        wiring_failures.append(JOURNEY_GUARD)
    for path in wiring_failures:
        try:
            label = str(path.relative_to(ROOT))
        except ValueError:
            label = str(path)
        errors.append(f"Batch9 required wiring drift: {label}")

    expected_acceptance_top = {
        "schema_version", "status", "accepted_at", "artifacts", "mechanical_acceptance_basis",
        "advisory_roasts", "commands", "accepted_scope_only", "not_accepted", "next_gate",
    }
    if set(acceptance) != expected_acceptance_top or acceptance.get("status") != "mechanically_accepted_written_contract_runtime_unimplemented":
        errors.append("Batch9 acceptance schema or honest status drift")
    try:
        accepted_at = datetime.fromisoformat(str(acceptance.get("accepted_at")))
        if accepted_at.tzinfo is None:
            raise ValueError("timezone required")
    except (TypeError, ValueError):
        errors.append("Batch9 acceptance timestamp is absent or invalid")
    expected_artifacts = {
        "scope": {"path": "product/mint_next/batch9/contribution-status-scope.yaml", "sha256": digest(scope_path)},
        "sources": {"path": "product/mint_next/batch9/official-sources.yaml", "sha256": digest(sources_path)},
        "legacy_inventory": {"path": "product/mint_next/batch9/legacy-inventory.yaml", "sha256": digest(legacy_path)},
        "guard": {"path": "tools/checks/mint_next_batch9_contribution_scope_guard.py", "sha256": digest(Path(__file__))},
        "tests": {"path": "tools/checks/tests/test_mint_next_batch9_contribution_scope_guard.py", "sha256": digest(TESTS)},
        "ci_workflow": {"path": ".github/workflows/mint-next-batch9-contract.yml", "normalized_sha256": normalized_ci_digest(ci_workflow_path)},
        "previous_acceptance": {"path": "product/mint_next/batch8/design-lab-acceptance.yaml", "sha256": EXPECTED_PREVIOUS_ACCEPTANCE_SHA256},
    }
    if acceptance.get("artifacts") != expected_artifacts:
        errors.append("Batch9 acceptance artifact binding drift")
    if acceptance.get("mechanical_acceptance_basis") != {
        "authority": "deterministic_commands_exact_digests_normalized_ci_and_hostile_mutations",
        "advisory_roasts_authorize_acceptance": False,
        "limitation": "agent_identity_truthfulness_branch_protection_and_external_ci_execution_are_not_authenticated_here",
    }:
        errors.append("Batch9 acceptance authority or limitation drift")
    expected_roasts = [
        {"role": "ux_navigation", "verdict": "ACCEPT", "score": 9.7, "p1": 0, "p2": 0, "bound_scope_sha256": EXPECTED_SCOPE_SHA256},
        {"role": "swiss_compliance", "verdict": "ACCEPT", "p1": 0, "p2": 0, "bound_scope_sha256": EXPECTED_SCOPE_SHA256, "bound_sources_sha256": EXPECTED_SOURCES_SHA256},
        {"role": "adversarial", "verdict": "ROAST_PASS", "p1": 0, "p2": 0, "bound_scope_sha256": EXPECTED_SCOPE_SHA256},
    ]
    if acceptance.get("advisory_roasts") != expected_roasts:
        errors.append("Batch9 advisory roast receipt drift")
    if acceptance.get("accepted_scope_only") != ["written_fact_contribution_contract", "written_yes_no_unknown_routes", "written_edge_case_classification", "written_safe_exit_and_accessibility_contract", "official_source_receipt", "bounded_legacy_inventory"]:
        errors.append("Batch9 accepted written scope drift")
    required_not_accepted = {"flutter_runtime", "product_integration", "six_translations", "amount_input", "calculation_engine", "personal_tax_result", "ios_runtime", "android_runtime", "user_validation", "persistence", "external_ci_run", "branch_protection"}
    if set(acceptance.get("not_accepted", [])) != required_not_accepted or acceptance.get("next_gate") != "isolated_flutter_implementation_of_exact_accepted_contract":
        errors.append("Batch9 runtime or operational limitation drift")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch9_contribution_scope_guard: ordinary credited 3a status is bounded, source-linked and runtime-forbidden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
