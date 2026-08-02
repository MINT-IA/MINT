#!/usr/bin/env python3
"""Fail closed when the write-only Batch 11 ordinary 3a amount contract drifts."""

from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SCOPE = ROOT / "product/mint_next/batch11/ordinary-contribution-amount-scope.yaml"
SOURCES = ROOT / "product/mint_next/batch11/official-sources.yaml"
LEGACY = ROOT / "product/mint_next/batch11/legacy-inventory.yaml"
WORKFLOW = ROOT / ".github/workflows/mint-next-batch11-contract.yml"
NAVIGATION = ROOT / "product/mint_next/batch6/navigation.yaml"
PREVIOUS_SCOPE = ROOT / "product/mint_next/batch9/contribution-status-scope.yaml"
PREVIOUS_ACCEPTANCE = ROOT / "product/mint_next/batch10/design-lab-acceptance.yaml"
BASE_COMMIT = "19dd384eca2b2fdbc87510fb86cce988f646f471"
EXPECTED_AUTHORITY_DIGESTS = {
    NAVIGATION: "461d8257b79c781b0ca1b11aa6d21f67d17ee387a9de0e17932c159eac469250",
    PREVIOUS_SCOPE: "64d941ce3c974c76bf5f3e40cb85a5a5e323cfe9b9f4eacbc8ee234d9722f83d",
    PREVIOUS_ACCEPTANCE: "36c9ef128aa7b548c1df04637d9721cda2babfe330ef16ff1133f5a1288846f2",
}
EXPECTED_URLS = {
    "https://www.estv.admin.ch/dam/estv/fr/dokumente/dbst/kreisschreiben/dbst-ks-2025-1-018a-dv.pdf.download.pdf/dbst-ks-2025-1-018a-dv.pdf",
    "https://www.estv.admin.ch/dam/fr/sd-web/bwQT3vUiDRc1/dbst-mb-21edp-2025-fr.pdf",
    "https://www.estv.admin.ch/dam/de/sd-web/SGAqZmbwA2OC/21EDP-2026-de.pdf",
    "https://www.bsv.admin.ch/fr/votre-cotisation-au-3e-pilier",
}


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


def _runtime_drift() -> list[str]:
    try:
        changed = subprocess.run(
            ["git", "diff", "--name-only", BASE_COMMIT, "--", "product/mint_next/batch7/design_lab", "apps/mobile", "services/backend"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError:
        return ["git_diff_failed"]
    return [item for item in changed if item]


def validate(
    scope_path: Path = SCOPE,
    sources_path: Path = SOURCES,
    legacy_path: Path = LEGACY,
    workflow_path: Path = WORKFLOW,
    *,
    check_runtime: bool = True,
) -> list[str]:
    errors: list[str] = []
    try:
        scope = load(scope_path)
        sources = load(sources_path)
        legacy = load(legacy_path)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        return [f"Batch11 contract unreadable: {exc}"]

    if check_runtime and (drift := _runtime_drift()):
        errors.append(f"Batch11 write-only boundary violated by runtime drift: {','.join(drift)}")
    for path, expected in EXPECTED_AUTHORITY_DIGESTS.items():
        if digest(path) != expected:
            errors.append(f"Batch11 authority drift: {path.relative_to(ROOT)}")

    expected_top = {
        "schema_version", "status", "journey_id", "audience", "authority", "slice",
        "human_outcome", "fact_contract", "aggregation_contract", "node_contracts",
        "input_contract", "interaction_contract", "accessibility_contract",
        "content_boundaries", "implementation_slices_after_written_acceptance", "exit_gate",
    }
    if set(scope) != expected_top or scope.get("status") != "draft_written_contract_runtime_forbidden":
        errors.append("Batch11 schema or write-only status drift")
    authority = scope.get("authority", {})
    if authority != {
        "canonical_navigation": "product/mint_next/batch6/navigation.yaml",
        "previous_written_contract": "product/mint_next/batch9/contribution-status-scope.yaml",
        "previous_runtime_acceptance": "product/mint_next/batch10/design-lab-acceptance.yaml",
        "semantic_refinement": "collect_complete_ordinary_3a_total_actually_credited_for_selected_year",
        "route_change": "refine_fact_contributed_amount_only",
        "runtime_change": "forbidden",
    }:
        errors.append("Batch11 authority or no-runtime boundary drift")

    slice_ = scope.get("slice", {})
    if slice_.get("entry_preconditions") != {
        "tax_year": "explicitly_selected",
        "fact_lpp_affiliation": "yes",
        "ordinary_contribution_status": "yes",
    }:
        errors.append("Batch11 yes/LPP/year entry invariant drift")
    if slice_.get("nodes") != ["fact_contributed_amount", "contributed_amount_unknown_help"]:
        errors.append("Batch11 exact node slice drift")
    if slice_.get("boundary_nodes") != ["fact_canton", "education_explanation"]:
        errors.append("Batch11 boundary nodes drift")
    if slice_.get("routes") != {
        "complete_positive_total": "fact_canton",
        "missing_or_unknown_amount": "contributed_amount_unknown_help",
        "found_amount": "fact_contributed_amount",
        "education_only": "education_explanation",
        "correct_previous_answer": "fact_contribution",
    }:
        errors.append("Batch11 route table drift or dead path")
    if slice_.get("locales") != ["fr", "en", "de", "it", "es", "pt"]:
        errors.append("Batch11 six-locale boundary drift")

    fact = scope.get("fact_contract", {})
    if fact.get("id") != "ordinary_3a_credited_total_for_selected_tax_year" or fact.get("tax_year_ref") != "tax_year":
        errors.append("Batch11 canonical fact identity drift")
    if fact.get("canonical_representation") != "integer_minor_units" or fact.get("float_forbidden") is not True:
        errors.append("Batch11 exact money representation drift")
    if fact.get("storage") != "ephemeral" or fact.get("entry_requires") != "ordinary_3a_contribution_credited_any_provider_for_selected_year_yes":
        errors.append("Batch11 storage or status=yes precondition drift")
    states = fact.get("working_states", {})
    if set(states) != {"unset", "partial_known", "unknown", "conflicted", "complete"}:
        errors.append("Batch11 amount working states drift")
    complete = fact.get("canonical_value_only_when", {})
    if complete != {
        "state": "complete",
        "amount_minor_units": "positive_integer",
        "all_personal_providers_reviewed": True,
        "every_row_valid": True,
        "unresolved_movement_count": 0,
    }:
        errors.append("Batch11 incomplete subtotal could become canonical")
    if fact.get("zero_invariant") != {
        "status_yes": "zero_forbidden",
        "status_no": "downstream_zero_adapter_allowed_only_from_explicit_status_no",
        "blank_parse_error_or_unknown": "never_zero",
    }:
        errors.append("Batch11 unknown/blank/yes could become zero")
    forbidden_inferences = set(fact.get("never_derive_from", []))
    required_forbidden = {
        "current_balance_or_cash_value", "planned_scheduled_or_habitual_contribution",
        "standing_order_or_bank_debit", "previous_year_amount", "statutory_ceiling",
        "missing_document_or_missing_provider", "incomplete_subtotal",
        "uncertain_ocr_chat_or_llm_extraction", "transfer_description",
        "retroactive_buyback", "spouse_or_partner_amount",
    }
    if not required_forbidden.issubset(forbidden_inferences):
        errors.append("Batch11 unsafe amount inference became allowed")
    exclusions = set(fact.get("explicit_exclusions", []))
    if exclusions != {
        "provider_to_provider_transfer_inbound_and_outbound",
        "retroactive_buyback_for_a_past_year",
        "pending_sent_scheduled_or_debited_uncredited_payment",
        "investment_return_interest_or_portfolio_gain",
        "fee_refund_rebate_or_non_contribution_adjustment",
        "fully_refunded_or_reversed_ordinary_amount",
    }:
        errors.append("Batch11 special movements could be double-counted")

    aggregation = scope.get("aggregation_contract", {})
    required_aggregation = {
        "row_unit": "one_provider_attestation_total_for_selected_year",
        "source_rule": "use_provider_total_q_once_when_available",
        "do_not_double_count": "provider_total_q_plus_policy_or_contract_detail_p",
        "multiple_providers": "sum_each_provider_scoped_total_once",
        "duplicate_or_reissued_evidence": "latest_provider_confirmed_correction_supersedes_never_adds",
        "partial_refund": "provider_confirmed_net_ordinary_amount_only_no_mental_subtraction",
        "unclear_refund_or_correction": "conflicted_no_canonical_total",
        "over_ceiling_assertion": "do_not_clamp_or_call_deductible_route_to_verification_if_unresolved",
    }
    for key, value in required_aggregation.items():
        if aggregation.get(key) != value:
            errors.append(f"Batch11 aggregation invariant drift: {key}")
    if aggregation.get("provider_identity_required") is not False:
        errors.append("Batch11 unnecessary provider identity became required")

    nodes = scope.get("node_contracts", {})
    amount = nodes.get("fact_contributed_amount", {})
    controls = amount.get("controls", {})
    expected_destinations = {
        "missing_amount": "contributed_amount_unknown_help",
        "unknown_amount": "contributed_amount_unknown_help",
        "continue": "fact_canton",
        "correct_previous": "fact_contribution",
    }
    for action, destination in expected_destinations.items():
        if controls.get(action, {}).get("to") != destination:
            errors.append(f"Batch11 amount control route drift: {action}")
    if controls.get("continue", {}).get("guard") != "complete_positive_total_only":
        errors.append("Batch11 continue can commit incomplete or zero total")
    help_controls = nodes.get("contributed_amount_unknown_help", {}).get("controls", {})
    if help_controls.get("found_amount", {}).get("to") != "fact_contributed_amount" or help_controls.get("continue_education_only", {}).get("to") != "education_explanation":
        errors.append("Batch11 unknown-help route is dead or personal")
    if "import_or_scan_cta" not in set(nodes.get("contributed_amount_unknown_help", {}).get("forbidden", [])):
        errors.append("Batch11 premature document import became allowed")

    parser = scope.get("input_contract", {})
    if parser.get("parser_output") != "integer_minor_units" or parser.get("maximum_fraction_digits") != 2:
        errors.append("Batch11 parser precision drift")
    if parser.get("ambiguous_or_mixed_separators") != "reject_without_mutation":
        errors.append("Batch11 ambiguous amount parser drift")
    if (
        parser.get("accepted_decimal_separators_for_all_six_locales") != ["comma", "point"]
        or parser.get("comma_or_point_with_three_trailing_digits")
        != "reject_as_ambiguous_not_grouping"
        or parser.get("apostrophe_or_space_grouping_with_optional_single_decimal_separator")
        != "accepted"
    ):
        errors.append("Batch11 six-locale parser grammar drift")
    if parser.get("no_silent_rounding_truncation_clamping_or_fx") is not True or parser.get("raw_text_preserved_on_error") is not True:
        errors.append("Batch11 parser can silently alter user amount")
    if parser.get("amount_logging_analytics_and_crash_breadcrumbs") != "forbidden":
        errors.append("Batch11 private amount telemetry became allowed")
    if parser.get("explicit_continue_required") is not True or parser.get("keyboard_done_does_not_commit_or_route") is not True:
        errors.append("Batch11 typing can route without explicit confirmation")

    interaction = scope.get("interaction_contract", {})
    if interaction.get("tax_year_rollover") != "return_to_tax_year_and_clear_year_scoped_facts_before_render":
        errors.append("Batch11 selected-year stale state drift")
    if interaction.get("status_change_to_no_or_unknown") != "clear_rows_total_completeness_and_downstream_result_atomically":
        errors.append("Batch11 status correction leaves stale amount")
    if interaction.get("leave_without_saving") != "clear_status_rows_total_completeness_and_all_prior_ephemeral_facts":
        errors.append("Batch11 safe-exit purge drift")

    boundaries = scope.get("content_boundaries", {})
    if not boundaries or not all(value is True for value in boundaries.values()):
        errors.append("Batch11 forbidden calculation/runtime boundary drift")
    if scope.get("implementation_slices_after_written_acceptance") != [
        "single_provider_positive_amount_unknown_help_and_boundaries",
        "additional_provider_rows_local_exact_sum_and_completeness",
        "six_locale_copy_accessibility_and_real_runtime_proof",
    ]:
        errors.append("Batch11 future implementation is no longer split into bounded slices")
    exit_gate = scope.get("exit_gate", {})
    if exit_gate.get("runtime_required_for_this_batch") is not False or exit_gate.get("next_gate") != "isolated_single_provider_runtime_only_after_written_contract_acceptance":
        errors.append("Batch11 exit gate permits premature runtime")

    source_items = sources.get("sources", [])
    urls = {item.get("url") for item in source_items if isinstance(item, dict)}
    if urls != EXPECTED_URLS:
        errors.append("Batch11 official source set drift")
    source_by_id = {item.get("id"): item for item in source_items if isinstance(item, dict)}
    notice = source_by_id.get("estv_form_21_edp_notice", {})
    if "marginal_27_provider_total_q_is_actual_total_not_only_deductible_ceiling" not in notice.get("anchors", []):
        errors.append("Batch11 provider total q source anchor missing")
    current_form = source_by_id.get("estv_form_21_edp_2026", {})
    if not {"field_q_total_ordinary_3a_contributions", "field_x_total_3a_buybacks"}.issubset(set(current_form.get("anchors", []))):
        errors.append("Batch11 current form ordinary/buyback separation missing")
    limits = sources.get("implementation_limits", {})
    if not limits or any(value is not False for key, value in limits.items() if key.startswith("authorize_")):
        errors.append("Batch11 source receipt authorizes implementation")

    candidates = {item.get("symbol"): item for item in legacy.get("candidates", []) if isinstance(item, dict)}
    if candidates.get("q_3a_annual_contribution", {}).get("decision") != "reject_semantics":
        errors.append("Batch11 legacy habitual amount became canonical")
    if candidates.get("q_3a_annual_contribution_consumers", {}).get("decision") != "reject_semantics":
        errors.append("Batch11 legacy missing-to-zero semantics became reusable")
    if candidates.get("ChatAmountInput", {}).get("decision") != "reject_widget_harvest_parser_only_as_warning":
        errors.append("Batch11 unsafe ChatAmountInput became reusable")
    summary = legacy.get("summary", {})
    if summary.get("directly_reusable_widgets") != 0 or summary.get("canonical_fact_semantics_found") is not False:
        errors.append("Batch11 legacy inventory overclaims reusable implementation")

    try:
        workflow = load(workflow_path)
        triggers = workflow.get("on", workflow.get(True))
        contract_job = workflow.get("jobs", {}).get("contract")
    except (OSError, ValueError, yaml.YAMLError):
        workflow = {}
        triggers = None
        contract_job = None
    expected_job = {
        "name": "Ordinary 3a credited amount written contract",
        "runs-on": "ubuntu-latest",
        "steps": [
            {"uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"},
            {
                "uses": "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065b",
                "with": {"python-version": "3.11"},
            },
            {"name": "Install exact guard dependency", "run": "python3 -m pip install PyYAML==6.0.2"},
            {"name": "Verify write-only amount contract", "run": "python3 tools/checks/mint_next_batch11_amount_scope_guard.py"},
            {"name": "Fire hostile amount-contract mutations", "run": "python3 -m unittest tools.checks.tests.test_mint_next_batch11_amount_scope_guard"},
        ],
    }
    if contract_job != expected_job:
        errors.append("Batch11 CI job permits skip ignored failure or command drift")
    if triggers != {
        "pull_request": {"branches": ["dev", "staging", "main"]},
        "push": {"branches": ["dev", "staging", "main"]},
    }:
        errors.append("Batch11 CI triggers permit the written gate to be skipped")
    if not isinstance(workflow, dict) or set(workflow) != {"name", True, "concurrency", "permissions", "jobs"}:
        errors.append("Batch11 workflow top-level bypass or schema drift")
    if workflow.get("concurrency") != {
        "group": "mint-next-batch11-contract-${{ github.ref }}",
        "cancel-in-progress": True,
    } or workflow.get("permissions") != {"contents": "read"}:
        errors.append("Batch11 workflow concurrency or least-privilege drift")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch11_amount_scope_guard: complete provider-scoped ordinary 3a amount remains written-only, exact and non-zero-by-default.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
