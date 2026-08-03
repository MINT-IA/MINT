#!/usr/bin/env python3
"""Fail closed on the accepted written Batch16 classification contract."""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

import yaml


SCOPE = Path("product/mint_next/batch16/classification-doubt-scope.yaml")
NAV = Path("product/mint_next/batch16/navigation.mmd")
ACCEPTANCE = Path("product/mint_next/batch16/acceptance.yaml")
PARENT = Path("product/mint_next/batch13/multi-provider-navigation-contract.yaml")
LEFTHOOK = Path("lefthook.yml")
WORKFLOW = Path(".github/workflows/mint-next-batch16-runtime.yml")
GUARD = Path("tools/checks/mint_next_batch16_classification_scope_guard.py")
GUARD_TESTS = Path("tools/checks/tests/test_mint_next_batch16_classification_scope_guard.py")


class GuardFailure(RuntimeError):
    pass


class UniqueKeyLoader(yaml.SafeLoader):
    """SafeLoader that rejects duplicate mapping keys instead of overwriting."""


def _construct_unique_mapping(loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    mapping: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise GuardFailure(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_unique_mapping,
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load_yaml(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)


def _normalized_workflow_sha256(path: Path) -> str:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    normalized = re.sub(
        r"(?m)^(\s*EXPECTED_BATCH16_[A-Z0-9_]+:\s*)[0-9a-f]{64}\s*$",
        r"\1<HASH>",
        text,
    )
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def validate(root: Path, *, check_digests: bool = True, check_git: bool = True) -> None:
    scope_path, nav_path = root / SCOPE, root / NAV
    acceptance_path, parent_path = root / ACCEPTANCE, root / PARENT
    for path in (scope_path, nav_path, acceptance_path, parent_path, root / LEFTHOOK, root / WORKFLOW, root / GUARD, root / GUARD_TESTS):
        _require(path.is_file(), f"missing required artifact: {path.relative_to(root)}")

    scope = _load_yaml(scope_path)
    acceptance = _load_yaml(acceptance_path)
    _load_yaml(parent_path)
    nav = nav_path.read_text(encoding="utf-8")

    _require(
        scope["status"] == "contract_accepted_runtime_unimplemented_product_forbidden",
        "contract lifecycle drifted or runtime/product was accepted prematurely",
    )
    _require(scope["authority"]["runtime_surface"] == "hidden_design_lab_harness_only", "hidden harness limit drifted")
    _require(scope["authority"]["product_promotion"] == "forbidden", "product promotion must remain forbidden")
    _require(_sha256(parent_path) == scope["authority"]["parent_contract_sha256"], "parent contract digest drifted")

    states = scope["row_state_machine"]["states"]
    _require(states == ["unreviewed", "confirmed_ordinary", "unresolved"], "classification states or order drifted")
    unresolved = scope["row_state_machine"]["unresolved_amount"]
    for key in ("canonical_total", "global_review", "continue", "canton_route"):
        _require(key in unresolved, f"unresolved blocker missing: {key}")
    _require(unresolved["canonical_total"] is None, "unresolved canonical total must be null")

    origin = scope["origin_contract"]
    required_origin_keys = {
        "successful_doubt_activation",
        "refunded_origin_transaction",
        "successful_terminal_action_consumes_atomically",
        "invalidation_before_mutation",
        "stale_wrong_repeated_or_retired_activation",
    }
    _require(required_origin_keys <= origin.keys(), "origin/token lifecycle was narrowed")
    refund_order = origin["refunded_origin_transaction"]["atomic_order"]
    _require(refund_order[0].startswith("validate_origin"), "refund must validate before consuming")
    _require("consume_exact_R_g_via_batch15_contentful_remove" in refund_order, "refund no longer consumes exact R_g")

    purge = scope["privacy_and_lifecycle"]["purged_fields"]
    _require(purge["inherit_exactly"] == "parent_contract.state_contract.personal_state_purge_fields", "parent purge inheritance narrowed")
    _require(purge["duplicate_with_inherited_list"] == "forbidden", "duplicate purge fields allowed")
    _require("classification_states" not in purge["additions"], "classification_states already belongs to parent purge")

    manifest = scope["runtime_manifest_at_head_1c7c18ccd"]
    _require(manifest["bound_head"] == "1c7c18ccd850ce8718b9559c0eed0a9415687498", "baseline head drifted")
    _require(len(manifest["evidence_sources"]) == 2, "baseline evidence sources drifted")
    _require("full_education_teach_back_correction_next_action_reference_subgraph" in manifest["not_implemented_outside_batch16_and_not_claimed_as_inherited"], "phantom education subgraph reintroduced")

    semantic_intents = scope["six_locale_semantic_contract"]["every_locale_must_distinguish"]
    _require(scope["six_locale_semantic_contract"]["locales"] == ["fr", "en", "de", "it", "es", "pt"], "six-locale order or coverage drifted")
    required_semantic_intents = {
        "one_provider_annual_ordinary_or_Q_total_counted_once",
        "actually_credited_for_selected_year_not_merely_planned_sent_or_debited",
        "exclude_transfer_retroactive_buyback_pending_movement_return_and_investment_gain",
        "after_correction_or_refund_obtain_provider_confirmed_net_ordinary_total_never_subtract_mentally",
        "insurance_uses_annual_certificate_never_surrender_value_or_risk_savings_split",
        "one_provider_fully_refunded_is_not_all_providers_zero",
        "mint_has_not_verified_the_entered_amount",
        "no_tax_result_or_recommendation_is_produced_here",
    }
    _require(set(semantic_intents) == required_semantic_intents, "six-locale financial intent matrix drifted")

    required_nav = (
        "Help_Unresolved --> Editor_Tombstone",
        "Editor_Tombstone --> Editor_RowsMixed: Annuler la suppression",
        "Editor_Tombstone --> Editor_RowsMixed: Finaliser la suppression",
        "Editor_AllConfirmed_Safe_Exit --> Editor_AllConfirmed",
        "Contribution_Correction --> Help_Unresolved: Retour / retour système",
        "Existing_Education_Boundary --> Help_Unresolved: Retour / retour système",
        "classification exacte restaurée selon l'origine",
    )
    for edge in required_nav:
        _require(edge in nav, f"critical navigation edge missing: {edge}")
    forbidden_nav = (
        "Modifier / ajouter / supprimer / décocher",
        "Toute sortie réversible",
        "Editor_AllConfirmed --> Editor_RowsMixed: Supprimer une ligne vide",
    )
    for edge in forbidden_nav:
        _require(edge not in nav, f"forbidden aggregate or impossible edge present: {edge}")

    reviews = acceptance["review_required"]
    expected_review = "accepted_contract_only_p1_0_p2_0_p3_0"
    _require(
        reviews
        == {
            "ux_navigation": expected_review,
            "swiss_finance_copy": expected_review,
            "adversarial_state_machine": expected_review,
        },
        "contract roast roles or exact zero verdicts drifted",
    )
    _require(acceptance["contract_roast_receipt"]["rounds"] == 6, "roast receipt drifted")
    _require(
        acceptance["full_runtime_acceptance_requires"]
        == {
            "severity_counts": {"p1": 0, "p2": 0, "p3": 0},
            "no_dead_end": True,
            "no_uncabled_control": True,
            "no_automatic_financial_inference": True,
            "runtime_proofs_complete": True,
            "hidden_harness_only": True,
        },
        "future runtime acceptance conditions drifted or became ambiguous",
    )
    _require(
        acceptance["status"] == "contract_accepted_runtime_unimplemented",
        "written-contract status drifted or runtime was accepted prematurely",
    )
    current_evidence = acceptance["current_evidence"]
    _require(
        current_evidence
        == {
            "written_contract_roasts_complete": True,
            "scope_guard_complete": True,
            "hidden_model_groundwork_complete": True,
            "runtime_proofs_complete": False,
            "runtime_guard_complete": False,
            "product_promotion": "forbidden",
        },
        "current evidence overclaims or omits the runtime boundary",
    )
    _require(
        acceptance["current_verdict"] == "CONTRACT_ACCEPTED_RUNTIME_UNIMPLEMENTED",
        "runtime was accepted prematurely or contract acceptance was erased",
    )
    binding = acceptance["mechanical_binding"]
    _require(binding["scope_guard"] == str(GUARD), "current scope guard path drifted")
    _require(binding["scope_guard_tests"] == str(GUARD_TESTS), "current scope guard tests path drifted")
    _require(binding["scope_lefthook_key"] == "mint-next-batch16-classification-scope-guard", "current scope lefthook key drifted")
    _require(binding["runtime_guard_planned"] == "tools/checks/mint_next_batch16_classification_runtime_guard.py", "planned runtime guard path drifted")
    expected_scope_mutations = {
        "runtime_promotion": "test_runtime_promotion_is_rejected",
        "unresolved_blocker_removed": "test_unresolved_commit_blocker_removal_is_rejected",
        "parent_purge_narrowed": "test_parent_purge_narrowing_is_rejected",
        "refund_R_g_step_removed": "test_refund_atomic_R_g_step_removal_is_rejected",
        "swiss_semantic_intent_replaced": "test_swiss_semantic_intent_replacement_is_rejected",
        "hidden_harness_limit_changed": "test_hidden_harness_limit_change_is_rejected",
        "finalize_navigation_removed": "test_finalize_navigation_removal_is_rejected",
        "destructive_aggregate_edge_added": "test_destructive_aggregate_edge_is_rejected",
        "mutation_registry_entry_removed": "test_missing_hostile_mutation_id_is_rejected",
        "nonzero_roast_inserted": "test_nonzero_roast_is_rejected",
        "runtime_evidence_overclaimed": "test_runtime_evidence_overclaim_is_rejected",
        "runtime_guard_overclaimed": "test_runtime_guard_overclaim_is_rejected",
        "contract_acceptance_erased": "test_contract_acceptance_erasure_is_rejected",
        "lefthook_binding_removed": "test_removed_lefthook_binding_is_rejected",
        "ci_binding_removed": "test_removed_ci_binding_is_rejected",
        "duplicate_yaml_key_added": "test_duplicate_yaml_key_is_rejected",
    }
    _require(binding["scope_hostile_mutations_executed"] == expected_scope_mutations, "executed scope mutation registry drifted")
    tests_text = (root / GUARD_TESTS).read_text(encoding="utf-8")
    for test_name in expected_scope_mutations.values():
        _require(f"def {test_name}(" in tests_text, f"declared hostile test is not executable: {test_name}")

    lefthook = (root / LEFTHOOK).read_text(encoding="utf-8")
    _require("mint-next-batch16-classification-scope-guard:" in lefthook, "Batch16 scope lefthook key missing")
    _require("run: python3 tools/checks/mint_next_batch16_classification_scope_guard.py" in lefthook, "Batch16 scope lefthook command missing")

    workflow = (root / WORKFLOW).read_text(encoding="utf-8")
    for command in binding["required_scope_commands"]:
        _require(command in workflow, f"Batch16 CI command missing: {command}")
    _require("Verify accepted written contract remains runtime-forbidden" in workflow, "CI runtime-forbidden step missing")
    _require(_sha256(root / GUARD) in workflow, "CI guard trust hash stale")
    _require(_sha256(root / GUARD_TESTS) in workflow, "CI guard-tests trust hash stale")
    _require(_sha256(acceptance_path) in workflow, "CI acceptance trust hash stale")
    _require("fetch-depth: 0" in workflow, "CI checkout cannot resolve the pinned baseline commit")
    _require(
        _normalized_workflow_sha256(root / WORKFLOW)
        == binding["digest_binding"]["normalized_workflow_sha256"],
        "normalized CI workflow digest drifted",
    )

    if check_digests:
        digests = binding["digest_binding"]
        _require(_sha256(scope_path) == digests["contract_sha256"], "Batch16 contract digest drifted")
        _require(_sha256(nav_path) == digests["navigation_sha256"], "Batch16 navigation digest drifted")

    if check_git:
        for source in manifest["evidence_sources"]:
            actual = subprocess.run(
                ["git", "rev-parse", f"{manifest['bound_head']}:{source['path']}"],
                cwd=root,
                check=True,
                text=True,
                capture_output=True,
            ).stdout.strip()
            _require(actual == source["git_blob_sha1"], f"baseline blob mismatch: {source['path']}")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    try:
        validate(root)
    except (GuardFailure, KeyError, TypeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        print(f"FAIL mint_next_batch16_classification_scope_guard: {exc}", file=sys.stderr)
        return 1
    print("OK mint_next_batch16_classification_scope_guard")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
