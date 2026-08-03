#!/usr/bin/env python3
"""Fail closed on the accepted written-only Batch17 canton contract."""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import yaml


SCOPE = Path("product/mint_next/batch17/canton-scope.yaml")
SOURCES = Path("product/mint_next/batch17/official-sources.yaml")
LEGACY = Path("product/mint_next/batch17/legacy-inventory.yaml")
ACCEPTANCE = Path("product/mint_next/batch17/canton-acceptance.yaml")
PARENT_NAV = Path("product/mint_next/batch6/navigation.yaml")
LEFTHOOK = Path("lefthook.yml")
WORKFLOW = Path(".github/workflows/mint-next-batch17-canton-contract.yml")
GUARD = Path("tools/checks/mint_next_batch17_canton_scope_guard.py")
TESTS = Path("tools/checks/tests/test_mint_next_batch17_canton_scope_guard.py")
COPY = Path("product/mint_next/batch17/six-locale-copy.yaml")
SOURCE_RECEIPT = Path("product/mint_next/batch17/source-receipt.txt")


class GuardFailure(RuntimeError):
    pass


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def _construct_unique_mapping(loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    mapping: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise GuardFailure(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping)


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _normalized_workflow_sha256(path: Path) -> str:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    text, replacements = re.subn(r"(?m)^(\s*EXPECTED_BATCH17_[A-Z0-9_]+:\s*)[0-9a-f]{64}\s*$", r"\1<HASH>", text)
    _require(replacements == 3, "workflow must contain exactly three normalized trust hashes")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _review_payload_sha256(root: Path) -> str:
    digest = hashlib.sha256()
    for relative in (SCOPE, SOURCES, LEGACY, COPY, SOURCE_RECEIPT, PARENT_NAV, GUARD, TESTS, LEFTHOOK):
        digest.update(str(relative).encode("utf-8") + b"\0")
        if relative == SCOPE:
            canonical_scope = _load(root / relative)
            canonical_scope["status"] = "<LIFECYCLE_STATUS>"
            payload = yaml.safe_dump(canonical_scope, sort_keys=True, allow_unicode=True).encode("utf-8")
        else:
            payload = (root / relative).read_bytes()
        digest.update(payload + b"\0")
    digest.update(b"normalized-workflow\0" + _normalized_workflow_sha256(root / WORKFLOW).encode("ascii"))
    return digest.hexdigest()


def _review_payload_sha256_at_commit(root: Path, commit: str) -> str:
    def git_show(relative: Path, *, text: bool = False):
        try:
            return subprocess.run(
                ["git", "show", f"{commit}:{relative}"], cwd=root, check=True, capture_output=True, text=text
            ).stdout
        except subprocess.CalledProcessError as exc:
            raise GuardFailure(f"reviewed candidate cannot provide {relative}") from exc

    digest = hashlib.sha256()
    for relative in (SCOPE, SOURCES, LEGACY, COPY, SOURCE_RECEIPT, PARENT_NAV, GUARD, TESTS, LEFTHOOK):
        payload = git_show(relative)
        digest.update(str(relative).encode("utf-8") + b"\0")
        if relative == SCOPE:
            canonical_scope = yaml.load(payload.decode("utf-8"), Loader=UniqueKeyLoader)
            canonical_scope["status"] = "<LIFECYCLE_STATUS>"
            payload = yaml.safe_dump(canonical_scope, sort_keys=True, allow_unicode=True).encode("utf-8")
        digest.update(payload + b"\0")
    workflow = git_show(WORKFLOW, text=True).replace("\r\n", "\n")
    workflow, replacements = re.subn(
        r"(?m)^(\s*EXPECTED_BATCH17_[A-Z0-9_]+:\s*)[0-9a-f]{64}\s*$", r"\1<HASH>", workflow
    )
    _require(replacements == 3, "reviewed commit workflow trust shape drifted")
    digest.update(b"normalized-workflow\0" + hashlib.sha256(workflow.encode("utf-8")).hexdigest().encode("ascii"))
    return digest.hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def validate(root: Path, *, check_digests: bool = True, require_accepted: bool | None = True, check_git: bool = False) -> None:
    paths = [SCOPE, SOURCES, LEGACY, ACCEPTANCE, COPY, SOURCE_RECEIPT, PARENT_NAV, LEFTHOOK, WORKFLOW, GUARD, TESTS]
    for relative in paths:
        _require((root / relative).is_file(), f"missing artifact: {relative}")

    scope = _load(root / SCOPE)
    sources = _load(root / SOURCES)
    legacy = _load(root / LEGACY)
    acceptance = _load(root / ACCEPTANCE)
    copy = _load(root / COPY)
    parent = _load(root / PARENT_NAV)

    if require_accepted is None:
        require_accepted = acceptance.get("status") == "accepted_written_contract_runtime_unimplemented"

    expected_scope_status = "accepted_written_contract_runtime_forbidden" if require_accepted else "candidate_written_contract_runtime_forbidden"
    _require(scope["status"] == expected_scope_status, "written-only lifecycle drifted")
    authority = scope["authority"]
    _require(authority["runtime_change"] == "forbidden", "runtime was promoted")
    _require(authority["product_promotion"] == "forbidden", "product route was promoted")
    _require(authority["canonical_navigation"] == str(PARENT_NAV), "canonical navigation authority drifted")

    _require(_sha256(root / PARENT_NAV) == authority["parent_navigation_sha256"], "parent navigation authority digest drifted")
    parent_node = parent["nodes"]["fact_canton"]
    expected_parent_actions = {
        "choose_canton": {"mutation": "canton", "value": "selected", "replaces": "canton", "clears": ["commune"], "storage": "ephemeral", "invalidates": "result"},
        "choose_unknown": {"to": "canton_unknown_help", "mutation": "canton", "value": "unknown", "replaces": "canton", "clears": ["commune"], "storage": "ephemeral", "invalidates": "result"},
        "continue": {"to": "fact_commune", "guard": "canton_answered"},
        "back": {"operation": "history_back", "allowed_predecessors": ["fact_contribution", "fact_contributed_amount"]},
        "open_safe_exit": {"overlay": "safe_exit"},
    }
    _require(parent_node["actions"] == expected_parent_actions, "canonical fact_canton action set drifted")
    _require(parent["overlays"]["safe_exit"]["actions"] == {"resume": {"operation": "close"}, "keep_local_reference": {"to": "reference_saved", "persistence": "local_non_sensitive"}, "leave_without_saving": {"to": "dismissed", "persistence": "clear_ephemeral_and_session_result"}}, "canonical safe-exit action set drifted")

    _require(scope["slice"]["implemented_nodes"] == ["fact_canton"], "commune or another node entered the slice")
    _require(set(scope["slice"]["boundary_nodes"]) == {"fact_commune", "education_explanation"}, "slice boundaries drifted")
    _require(scope["slice"]["routes"] == {"selected": "fact_commune", "unknown": "canton_unknown_help", "unknown_education_only": "education_explanation"}, "route set drifted")
    entries = scope["slice"]["entry_preconditions"]
    _require(entries["discriminated_origins"] == {"fact_contribution": {"contribution_status": "no", "contributed_amount": "absent_or_cleared"}, "fact_contributed_amount": {"contribution_status": "yes", "ordinary_contribution_total": "atomically_committed_complete_positive"}}, "canonical no/yes entry union drifted")
    _require(entries["crossed_origin_states"] == "forbidden", "crossed origin states allowed")

    fact = scope["fact_contract"]
    expected_codes = {"AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR", "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG", "TI", "UR", "VD", "VS", "ZG", "ZH"}
    _require(fact["initial_state"] == "unset", "canton may not be preselected")
    _require(fact["storage"] == "ephemeral", "canton fact storage must remain ephemeral")
    _require(fact["supported_case"] == "one_ordinary_swiss_tax_domicile_for_the_selected_year_without_intercantonal_or_international_allocation", "supported Swiss tax case widened")
    _require(fact.get("complex_or_uncertain_case") == "use_explicit_unknown_control_then_education_only_never_force_a_code", "complex-case safety gate drifted")
    _require(fact["unknown_state_semantics"] == "does_not_assert_ignorance_also_safe_unsupported_or_complex_escape_never_persisted_or_analysed_as_user_knowledge_deficit", "unknown became a knowledge-deficit claim")
    _require(fact["states"] == ["unset", "selected", "unknown"], "invented or missing canton state")
    _require(len(fact["allowed_codes"]) == 26 and set(fact["allowed_codes"]) == expected_codes, "26-canton code set drifted")
    required_no_inference = {"gps_or_device_location", "ip_address", "postal_address_or_postcode", "commune", "app_language_or_locale", "profile_or_previous_answer", "employer_or_provider_location", "device_region_or_timezone"}
    _require(set(fact["never_derive_from"]) == required_no_inference, "inference prohibition narrowed")
    _require({"ZH", "national_average", "marginal_rate_30_percent"} <= set(fact["forbidden_fallbacks"]), "dangerous fallback prohibition narrowed")

    inputs = scope["input_contract"]
    _require(inputs["free_text"] is False and inputs["no_preselection"] is True, "input can guess or accept arbitrary canton")
    _require(inputs["selection_commits_ephemeral_fact_but_does_not_route"] is True, "selection commit/route semantics drifted")
    _require(inputs["pattern"] == "scrollable_localized_alphabetical_list_with_accessible_search", "26-choice interaction pattern drifted")
    _require(inputs["search_required_for_runtime"] is True, "visible search became optional")
    expected_search = {"query_storage": "ephemeral_potentially_personal_uncommitted_ui_input", "clear_behavior": "restores_full_list_and_selection", "no_match": "named_empty_state_with_clear_search_action", "selection_remains_visible_after_query_clear": True, "maximum_code_points": 64, "unicode_normalization": "NFKC", "matching": "local_casefold_plus_diacritic_fold_prefix_or_substring_against_26_reviewed_labels_only_raw_query_preserved", "network_logging_analytics_platform_learning_autofill_clipboard": "forbidden", "purge": "same_30_min_leave_kill_and_restart_contract_as_personal_facts"}
    _require(inputs["search_behavior"] == expected_search, "search privacy or matching contract drifted")
    _require(scope["navigation_contract"]["explicit_continue_required"] is True, "explicit Continue removed")
    _require(scope["navigation_contract"]["back"]["fact_canton"] == "exact_runtime_origin_fact_contribution_or_fact_contributed_amount", "origin-aware back collapsed")
    scoped_safe_exit = scope["navigation_contract"]["safe_exit"]
    _require(set(scoped_safe_exit) == {"resume", "keep_local_reference", "leave_without_saving"}, "scoped safe-exit action inventory drifted")
    _require(scoped_safe_exit["keep_local_reference"]["generic_reference_allowlist"] == ["journey_id", "generic_reference_id", "saved_at"], "safe reference allowlist drifted")
    _require(scoped_safe_exit["keep_local_reference"]["personal_canton_commune_result_or_search_query"] == "forbidden", "personal data entered safe reference")

    select_order = scope["mutation_contract"]["select_or_change_canton"]["atomic_order"]
    _require(select_order[:4] == ["validate_active_generation_and_allowed_code", "if_same_code_stop_without_mutation", "invalidate_downstream_result", "clear_commune"], "canton correction atomic invalidation drifted")
    _require(scope["mutation_contract"]["select_or_change_canton"]["same_selected_code"] == "idempotent_no_op_preserve_commune_and_result", "same-code no-op drifted")
    _require(scope["node_contracts"]["fact_canton"]["controls"]["continue"]["operation"] == "validate_active_generation_and_selected_allowed_code_then_route_only", "Continue writes an already committed canton")
    _require({"update_search_query", "clear_search"} <= scope["node_contracts"]["fact_canton"]["controls"].keys(), "visible search control is uncabled")
    _require(scope["lifecycle_contract"]["stale_callback"] == "ignored_without_mutation_or_navigation", "stale callback may mutate")

    privacy = scope["privacy_contract"]
    _require(privacy["storage"] == "ephemeral_local_only" and privacy["personal_fact_persistence"] == "forbidden" and privacy["personal_fact_and_search_query_persistence"] == "forbidden", "personal storage boundary contradicted")
    _require("persistence" not in privacy, "absolute persistence key contradicts generic reference allowlist")
    for key in ("network", "logs", "analytics", "crash_breadcrumb_values", "platform_keyboard_learning", "autofill", "clipboard", "session_replay", "crash_breadcrumbs"):
        _require(privacy[key] == "forbidden", f"privacy boundary widened: {key}")
    _require(scope["lifecycle_contract"]["ttl_minutes_sliding"] == 30, "retention TTL drifted")
    _require(scope["lifecycle_contract"]["exact_purge_events"] == ["safe_exit.leave_without_saving", "reference_saved.on_enter_after_non_sensitive_allowlist_copy", "ttl_expiry", "app_kill", "tax_year_change"], "exact purge event set drifted")
    _require(scope["lifecycle_contract"]["education_subgraph_reversible_return"] == "preserve_unknown_origin_and_history_until_irreversible_exit", "reversible education state is purged too early")
    _require(privacy["regulatory_boundary_ref"] == "product/mint_next/batch4/regulatory_boundaries.yaml", "regulatory boundary reference drifted")
    _require(privacy.get("controller_privacy_notice_ref") == "required_before_runtime_not_claimed_by_written_contract", "runtime controller notice gate removed")

    locales = ["fr", "en", "de", "it", "es", "pt"]
    _require(scope["six_locale_semantic_contract"]["locales"] == locales, "six-locale contract narrowed")
    _require(scope["slice"]["locales"] == locales, "slice locales drifted")
    _require(scope["accessibility_contract"]["minimum_target_size_points"] == 48, "tap target reduced")
    _require(scope["accessibility_contract"]["compact_proof"] == "320x700_logical_px_at_text_scale_2_no_overflow_clip_or_unreachable_action", "compact proof requirement narrowed")
    required_copy_keys = {"question", "body", "search_label", "search_empty", "clear_search", "unknown", "continue", "fact_back", "help_back", "fact_eyebrow", "help_eyebrow", "privacy", "error_no_selection", "error_stale", "help_title", "help_body", "education_only"}
    _require(copy["locales"] == locales and set(copy["copy"]) == set(locales), "locale payload coverage drifted")
    for locale in locales:
        payload = copy["copy"][locale]
        _require(set(payload) == required_copy_keys, f"visible copy key drifted: {locale}")
        _require("{taxYear}" in payload["question"], f"taxYear placeholder missing: {locale}")
        labels = copy["canton_labels"][locale]
        _require(set(labels) == expected_codes and len(set(labels.values())) == 26, f"canton labels incomplete or duplicated: {locale}")
        def folded_label(code: str) -> tuple[str, str]:
            folded = "".join(char for char in unicodedata.normalize("NFKD", labels[code]).casefold() if not unicodedata.combining(char))
            return folded, code
        _require(copy["ordered_codes"][locale] == sorted(expected_codes, key=folded_label), f"localized order drifted: {locale}")
    _require(len({tuple(sorted(payload.items())) for payload in copy["copy"].values()}) == 6, "locale payload was copied or collapsed")
    _require(copy["semantic_receipt"]["semantic_assertions_per_locale"] == ["tax_applicable_canton_for_selected_year", "complex_or_moved_uses_unknown_education_only", "choice_not_sent", "ttl_30_minutes", "no_personal_estimate_when_unknown_or_complex", "canton_and_commune_are_distinct"], "locale semantic assertions drifted")
    _require(copy["semantic_receipt"]["human_review_receipts"] == "required_in_acceptance_and_bound_to_review_payload", "locale review authority drifted")

    exclusions = set(scope["scope_exclusions"])
    required_exclusions = {"flutter_runtime", "commune_collection_or_dataset", "tax_calculation_or_personal_result", "persistence_backend_or_api", "public_product_route", "user_validation"}
    _require(required_exclusions <= exclusions, "scope exclusions narrowed")
    _require(scope["node_contracts"]["canton_unknown_help"]["controls"]["continue_education_only"]["to"] == "education_explanation", "unknown can reach personal output")

    _require(sources["implementation_limits"] == {"authorize_written_copy_only": True, "authorize_runtime": False, "authorize_personal_tax_result": False, "authorize_rate_or_saving": False, "authorize_legal_or_investment_advice": False, "authorize_commune_collection": False, "authorize_network_lookup_or_persistence": False}, "official source receipt over-authorizes implementation")
    expected_sources = {
        "estv_swiss_tax_statistics": ("https://www.estv.admin.ch/fr/statistiques-fiscales-suisses", ["swiss_tax_burden_varies_by_canton_and_commune"], "La charge fiscale en Suisse varie selon le canton et la commune; le simulateur calcule les impôts cantonal, communal, ecclésiastique et fédéral."),
        "estv_tax_calculator": ("https://www.estv.admin.ch/fr/simulateur-fiscal-calculer-vos-impots", ["official_simulator_provides_individual_calculations_and_cantonal_tax_data"], "Le simulateur officiel fournit des calculs individuels et des données fiscales cantonales."),
    }
    _require({source["id"] for source in sources["sources"]} == set(expected_sources), "official source IDs drifted")
    for source in sources["sources"]:
        url, supports, page_claim = expected_sources[source["id"]]
        _require(source["authority"] == "Administration fédérale des contributions", "non-primary tax source introduced")
        _require(source["url"] == url and source["retrieved_url"] == url and source["final_url"] == url, "official ESTV URL drifted")
        _require(source["supports"] == supports, "official direct support drifted")
        _require(source["page_claim"] == page_claim, "reviewed official claim drifted")
        _require(source["review_horizon"] == "recheck_before_runtime_calculation_or_user_facing_claim", "source recheck horizon removed")
    _require(sources["receipt"]["kind"] == "claim_review_receipt_not_retrieved_source_blob" and sources["receipt"]["source_content"] == "unpinned_dynamic_official_html", "claim receipt overstates source-content provenance")
    _require(sources["receipt"]["sha256"] == _sha256(root / SOURCE_RECEIPT), "source receipt digest drifted")
    _require(legacy["summary"]["silent_default_or_rate_fallback_reusable"] is False, "legacy fallback became reusable")
    _require(legacy["summary"]["commune_dataset_reusable_in_batch17"] is False, "commune dataset entered Batch17")

    expected_acceptance_status = "accepted_written_contract_runtime_unimplemented" if require_accepted else "candidate_unaccepted_written_contract_runtime_unimplemented"
    expected_verdict = "CONTRACT_ACCEPTED_RUNTIME_UNIMPLEMENTED" if require_accepted else "PENDING_INDEPENDENT_ROASTS"
    _require(acceptance["status"] == expected_acceptance_status, "contract lifecycle status drifted")
    _require(acceptance["current_verdict"] == expected_verdict, "verdict drifted")
    evidence = acceptance["current_evidence"]
    expected_evidence = {"written_contract_complete": True, "scope_guard_complete": require_accepted, "runtime_implemented": False, "runtime_tests_complete": False, "user_validation_complete": False, "product_promotion": "forbidden", "six_locale_semantic_review_complete": require_accepted, "official_source_content_pinned": False}
    _require(evidence == expected_evidence, "evidence overclaim or omission")
    for role in ("ux_navigation_accessibility", "swiss_privacy_provenance", "adversarial_mechanical"):
        review = acceptance["reviews"][role]
        if require_accepted:
            _require(review["verdict"] == "ACCEPT" and (review["p1"], review["p2"], review["p3"]) == (0, 0, 0), f"nonzero or missing roast: {role}")
        else:
            _require(review == {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}, f"candidate roast is not honestly pending: {role}")

    binding = acceptance["mechanical_binding"]
    _require(binding["scope_guard"] == str(GUARD) and binding["scope_guard_tests"] == str(TESTS), "guard trust unit drifted")
    tests_text = (root / TESTS).read_text(encoding="utf-8")
    discovered = set(re.findall(r"(?m)^    def (test_[a-zA-Z0-9_]+)\(", tests_text))
    positive = {"test_current_candidate_contract_passes_before_release_acceptance", "test_release_gate_rejects_unaccepted_candidate", "test_accepted_git_anchor_reproduces_candidate_payload"}
    _require(binding["positive_tests"] == sorted(positive), "positive test registry drifted")
    _require(binding["hostile_tests"] == sorted(discovered - positive), "hostile test registry is not exact")
    review_payload = _review_payload_sha256(root)
    _require(binding["candidate_review_payload_sha256"] == review_payload, "candidate review payload drifted")
    if require_accepted:
        _require(binding["reviewed_payload_sha256"] == review_payload, "accepted review payload drifted")
        locale_reviews = acceptance["locale_reviews"]
        _require(set(locale_reviews) == set(locales), "locale review receipt coverage drifted")
        for locale, review in locale_reviews.items():
            _require(review == {"reviewer": "batch17_round5_ux_locale_roast", "status": "ACCEPT", "reviewed_at": "2026-08-03", "assertions_validated": copy["semantic_receipt"]["semantic_assertions_per_locale"], "reviewed_payload_sha256": review_payload}, f"locale semantic receipt drifted: {locale}")
        for role in ("ux_navigation_accessibility", "swiss_privacy_provenance", "adversarial_mechanical"):
            _require(acceptance["reviews"][role]["reviewed_payload_sha256"] == review_payload, f"global roast is not bound to reviewed payload: {role}")
        if check_git:
            candidate_commit = binding["reviewed_candidate_commit"]
            _require(re.fullmatch(r"[0-9a-f]{40}", candidate_commit) is not None, "reviewed candidate commit is not full SHA")
            ancestor = subprocess.run(["git", "merge-base", "--is-ancestor", candidate_commit, "HEAD"], cwd=root)
            _require(ancestor.returncode == 0, "reviewed candidate commit is not an ancestor of HEAD")
            _require(_review_payload_sha256_at_commit(root, candidate_commit) == review_payload, "reviewed Git candidate does not reproduce review payload")

    lefthook = (root / LEFTHOOK).read_text(encoding="utf-8")
    _require("mint-next-batch17-canton-scope-guard:" in lefthook, "Lefthook binding missing")
    _require(f"run: python3 {GUARD}" in lefthook, "Lefthook guard command missing")
    workflow = (root / WORKFLOW).read_text(encoding="utf-8")
    for command in (f"python3 {GUARD}", "python3 -m unittest tools.checks.tests.test_mint_next_batch17_canton_scope_guard"):
        _require(command in workflow, f"CI command missing: {command}")
    trust = {"GUARD": GUARD, "TESTS": TESTS, "ACCEPTANCE": ACCEPTANCE}
    for name, relative in trust.items():
        digest = _sha256(root / relative) if require_accepted else "0" * 64
        _require(len(re.findall(rf"(?m)^  EXPECTED_BATCH17_{name}_SHA256: {digest}$", workflow)) == 1, f"CI trust variable stale or duplicated: {relative}")
        command = f'test "$(sha256sum {relative} | cut -d \' \' -f 1)" = "$EXPECTED_BATCH17_{name}_SHA256"'
        _require(len(re.findall(rf"(?m)^\s+{re.escape(command)}$", workflow)) == 1, f"CI trust command missing or duplicated: {relative}")
    _require(_normalized_workflow_sha256(root / WORKFLOW) == binding["normalized_workflow_sha256"], "normalized workflow digest drifted")

    if check_digests:
        digests = binding["artifact_sha256"]
        for key, relative in (("scope", SCOPE), ("sources", SOURCES), ("legacy", LEGACY), ("copy", COPY), ("source_receipt", SOURCE_RECEIPT), ("parent_navigation", PARENT_NAV)):
            _require(_sha256(root / relative) == digests[key], f"{key} digest drifted")


def main() -> int:
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] != "--contract"):
        print("usage: mint_next_batch17_canton_scope_guard.py [--contract]", file=sys.stderr)
        return 2
    require_accepted = None if len(sys.argv) == 2 else True
    try:
        validate(Path(__file__).resolve().parents[2], require_accepted=require_accepted, check_git=True)
    except (GuardFailure, KeyError, TypeError, yaml.YAMLError) as exc:
        print(f"Batch17 canton contract guard: FAIL — {exc}", file=sys.stderr)
        return 1
    print("Batch17 canton contract guard: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
