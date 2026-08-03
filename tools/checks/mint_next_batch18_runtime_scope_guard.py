#!/usr/bin/env python3
"""Fail closed on the Batch18 scope contract; do not infer runtime state."""

from __future__ import annotations

import hashlib
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
EXPECTED_SCOPE_SHA256 = "292bdf985f5e74236310ed2370f5330ea4f4812b8a0aa2c7e7433f1c4b9d067b"
EXPECTED_SCOPE_CANONICAL_SHA256 = "e7bf9366a054492804430331935764bbe98f818f36de5439fa98c39df71a8fe8"
EXPECTED_PARENT_SHA256 = "bb1a293f55b980ba7e1f07d575d34626ac181369bb97a9f9b9372c04af952c4a"


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
    journey_entries = [entry for entry in EXPECTED_JOURNEY_ENTRIES if journey_source.count(f'"{entry}"') == 1]
    _require(len(journey_entries) == len(EXPECTED_JOURNEY_ENTRIES), "Journey OS review payload entries drifted")
    parts["JOURNEY_OS_BATCH18_ENTRIES"] = ("\n".join(journey_entries) + "\n").encode("utf-8")
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
    journey_entries = [entry for entry in EXPECTED_JOURNEY_ENTRIES if journey_source.count(f'"{entry}"') == 1]
    _require(len(journey_entries) == len(EXPECTED_JOURNEY_ENTRIES), "reviewed Journey OS entries drifted")
    parts = {
        str(SCOPE): yaml.safe_dump(scope, sort_keys=True, allow_unicode=True).encode("utf-8"),
        str(GUARD): show(GUARD),
        str(TESTS): show(TESTS),
        str(WORKFLOW): workflow_text.encode("utf-8"),
        "SPEC_BATCH18_VERIFY": ("\n".join(spec_lines) + "\n").encode("utf-8"),
        "BATCH17_REVIEWED_PAYLOAD": parent_payload.encode("ascii"),
        "JOURNEY_OS_BATCH18_ENTRIES": ("\n".join(journey_entries) + "\n").encode("utf-8"),
    }
    digest = hashlib.sha256()
    for name, payload in parts.items():
        digest.update(name.encode("utf-8") + b"\0" + payload + b"\0")
    return digest.hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "journey_id", "runtime_surface", "product_promotion", "audience",
    "authority", "acceptance_model", "microsteps", "required_controls", "hard_out_of_scope", "required_test_modes",
    "forbidden_claims_until_separate_acceptance", "runtime_gate_registry",
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
EXPECTED_GATE_REGISTRY = {
    "scope_contract": {"state": "EVALUATED_BY_SCOPE_ACCEPTANCE_ARTIFACT", "candidate_command": "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py --contract", "accepted_command": "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py"},
    "R1": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r1_test.dart"},
    "R2": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r2_test.dart"},
    "R3": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r3_test.dart"},
    "R4a_safe_exit": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4a_safe_exit_test.dart"},
    "R4b_lifecycle_generation_and_privacy": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4b_lifecycle_privacy_test.dart"},
    "R4c_six_locale_accessibility_and_compact": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4c_accessibility_locales_test.dart"},
    "R4d_cross_step_integration": {"state": "NOT_EVALUATED", "command": None, "planned_test_file": "product/mint_next/batch7/design_lab/test/design_lab_batch18_canton_r4d_integration_test.dart"},
    "R4": {"state": "NOT_EVALUATED", "command": None, "requires": ["R4a_safe_exit", "R4b_lifecycle_generation_and_privacy", "R4c_six_locale_accessibility_and_compact", "R4d_cross_step_integration"]},
    "runtime_global": {"state": "NOT_EVALUATED", "command": None},
}
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
    if check_byte_digest:
        _require(_sha256(root / SCOPE) == EXPECTED_SCOPE_SHA256, "Batch18 scope bytes drifted")
    _require(_sha256(root / PARENT) == EXPECTED_PARENT_SHA256, "accepted Batch17 parent drifted")

    scope = _load(root / SCOPE)
    _require(set(scope) == EXPECTED_TOP_KEYS, "top-level scope schema drifted")
    expected_scope_status = "accepted_scope_contract_runtime_state_not_evaluated" if require_accepted else "candidate_scope_acceptance_absent"
    _require(scope["status"] == expected_scope_status, "scope acceptance status drifted")
    _require(scope["runtime_surface"] == "hidden_design_lab_only", "runtime surface widened")
    _require(scope["product_promotion"] == "forbidden", "product promotion widened")
    _require(scope["authority"] == EXPECTED_AUTHORITY, "authority contract drifted")

    acceptance = scope["acceptance_model"]
    _require(set(acceptance) == {"runtime_state_evaluated_by_scope_guard", "self_attested_evidence", "microstep_acceptance", "execution_rule", "global_rule", "promotion_rule", "complete_runtime_gate_requires", "product_promotion_after_runtime_acceptance"}, "acceptance schema drifted")
    _require(acceptance["runtime_state_evaluated_by_scope_guard"] is False, "scope guard claims runtime knowledge")
    _require(acceptance["self_attested_evidence"] == "forbidden", "self-attestation became evidence")
    _require(acceptance["microstep_acceptance"] == "forbidden", "a microstep can promote runtime")
    _require(acceptance["execution_rule"] == "a_runtime_microstep_gets_an_executable_command_and_expected_failing_tests_before_implementation_then_its_named_gate_must_pass_before_the_next_microstep", "microstep execution rule drifted")
    _require(acceptance["global_rule"] == "no_runtime_acceptance_until_every_named_microstep_and_cross_step_gate_exists_passes_and_is_bound_to_one_exact_reviewed_state", "global runtime rule drifted")
    _require(acceptance["promotion_rule"] == "no_microstep_or_partial_combination_promotes_runtime", "partial promotion rule drifted")
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
        _require(all(item.startswith(f"{step}_") for item in obligations), f"{step} obligation identity drifted")
    r4_contracts = microsteps["R4"]["subgate_contracts"]
    _require(list(r4_contracts) == EXPECTED_SUBGATES["R4"], "R4 subgate contract order drifted")
    _require(r4_contracts["R4a_safe_exit"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(1, 6)], "R4a obligation ownership drifted")
    _require(r4_contracts["R4b_lifecycle_generation_and_privacy"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(6, 10)], "R4b obligation ownership drifted")
    _require(r4_contracts["R4c_six_locale_accessibility_and_compact"]["obligation_ids"] == [f"R4_{n:02d}" for n in range(10, 18)], "R4c obligation ownership drifted")
    _require(r4_contracts["R4d_cross_step_integration"]["obligation_ids"] == ["R1_R2_R3_R4_cross_step_integration"], "R4d obligation ownership drifted")

    _require(scope["required_controls"] == EXPECTED_CONTROLS, "required control topology drifted")
    _require(scope["hard_out_of_scope"] == EXPECTED_OUT_OF_SCOPE, "hard out-of-scope inventory drifted")
    _require(scope["required_test_modes"] == EXPECTED_TEST_MODES, "required test modes drifted")
    _require(scope["forbidden_claims_until_separate_acceptance"] == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claim inventory drifted")
    _require(scope["runtime_gate_registry"] == EXPECTED_GATE_REGISTRY, "runtime gate registry drifted")
    canonical_scope = dict(scope)
    canonical_scope["status"] = "candidate_scope_acceptance_absent"
    canonical = yaml.safe_dump(canonical_scope, sort_keys=True, allow_unicode=True).encode("utf-8")
    _require(hashlib.sha256(canonical).hexdigest() == EXPECTED_SCOPE_CANONICAL_SHA256, "exact semantic scope inventory drifted")

    # Reuse the accepted parent's own verifier; do not restate only one parent file.
    batch17.validate(root, require_accepted=True, check_git=check_parent_git)

    guard_command = "python3 tools/checks/mint_next_batch18_runtime_scope_guard.py" + ("" if require_accepted else " --contract")
    tests_command = "python3 -m unittest tools.checks.tests.test_mint_next_batch18_runtime_scope_guard"
    workflow = _load_structure(root / WORKFLOW)
    _require(set(workflow["on"]) == {"pull_request", "push"}, "CI trigger drifted")
    for trigger in ("pull_request", "push"):
        _require(workflow["on"][trigger]["branches"] == ["dev", "staging", "main"], f"CI {trigger} branches drifted")
    job = workflow["jobs"]["scope"]
    _require("if" not in job and "continue-on-error" not in job, "CI scope job can be disabled or softened")
    runs = [step.get("run") for step in job["steps"] if isinstance(step, dict) and "run" in step]
    _require(runs.count(guard_command) == 1, "operational CI guard command missing or duplicated")
    _require(runs.count(tests_command) == 1, "operational CI hostile command missing or duplicated")
    _require(all("if" not in step and "continue-on-error" not in step for step in job["steps"] if isinstance(step, dict)), "CI step can be disabled or softened")
    spec = (root / SPEC).read_text(encoding="utf-8")
    verify = re.search(r"```verify\n(.*?)\n```", spec, re.DOTALL)
    _require(verify is not None, "active SPEC verify block missing")
    lines = verify.group(1).splitlines()
    _require(lines.count(f"batch18-canton-runtime-scope: {guard_command}") == 1, "operational SPEC guard binding missing or duplicated")
    _require(lines.count(f"batch18-canton-runtime-scope-hostiles: {tests_command}") == 1, "operational SPEC hostile binding missing or duplicated")
    journey_source = (root / JOURNEY_GUARD).read_text(encoding="utf-8")
    for entry in EXPECTED_JOURNEY_ENTRIES:
        _require(journey_source.count(f'"{entry}"') == 1, f"Journey OS scope entry missing or duplicated: {entry}")

    acceptance = _load(root / ACCEPTANCE)
    _require(set(acceptance) == {"schema_version", "status", "current_verdict", "reviews", "mechanical_binding", "accepted_scope_only", "not_accepted", "next_gate"}, "scope acceptance schema drifted")
    expected_status = "accepted_scope_contract_runtime_not_evaluated" if require_accepted else "candidate_scope_unaccepted"
    expected_verdict = "SCOPE_ACCEPTED_RUNTIME_NOT_EVALUATED" if require_accepted else "PENDING_INDEPENDENT_ROASTS"
    _require(acceptance["status"] == expected_status and acceptance["current_verdict"] == expected_verdict, "scope acceptance lifecycle drifted")
    roles = {"ux_accessibility_microstep_scope", "engineering_parent_feasibility", "adversarial_mechanical"}
    _require(set(acceptance["reviews"]) == roles, "scope review role coverage drifted")
    for role, review in acceptance["reviews"].items():
        if require_accepted:
            _require(review.get("verdict") == "ACCEPT" and (review.get("p1"), review.get("p2"), review.get("p3")) == (0, 0, 0), f"scope review not zero: {role}")
        else:
            _require(review == {"verdict": "PENDING", "p1": None, "p2": None, "p3": None}, f"candidate review is not pending: {role}")
    binding = acceptance["mechanical_binding"]
    discovered = set(re.findall(r"(?m)^    def (test_[A-Za-z0-9_]+)\(", (root / TESTS).read_text(encoding="utf-8")))
    positive = {"test_current_scope_passes", "test_release_gate_matches_declared_lifecycle"}
    _require(binding["positive_tests"] == sorted(positive), "positive test registry drifted")
    _require(binding["hostile_tests"] == sorted(discovered - positive), "hostile test registry drifted")
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
            _require(_review_payload_sha256_at_commit(root, candidate) == payload, "reviewed scope candidate does not reproduce payload")
    else:
        _require(binding["reviewed_payload_sha256"] is None and binding["reviewed_candidate_commit"] is None, "candidate carries accepted receipt")
        _require(acceptance["accepted_scope_only"] == [], "candidate claims accepted scope")
    _require(acceptance["not_accepted"] == ["any_runtime_microstep", "hidden_runtime", "product_route", "user_validation", "calculation", "persistence", "local_precommit_binding_until_shared_registry_is_decoupled"], "not-accepted boundary drifted")
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
