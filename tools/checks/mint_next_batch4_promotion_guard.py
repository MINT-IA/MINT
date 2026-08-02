#!/usr/bin/env python3
"""Fail-closed readiness guard for Batch 4 architecture promotion.

This proves only that the promotion phase is coherently blocked.  It cannot
promote Batch 4 and intentionally rejects every candidate, receipt, or gate.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


READINESS = Path("product/mint_next/batch4/evidence/promotion-readiness.yaml")
REVIEW_PROTOCOL = Path(
    "product/mint_next/batch4/evidence/cross-provider-review-protocol.yaml"
)
RESULT_SCHEMA = Path("product/mint_next/batch4/evidence/review-result.schema.json")
RESULT_VERIFIER = Path("tools/checks/mint_next_batch4_review_result_verifier.py")
RESULT_VERIFIER_TEST = Path(
    "tools/checks/tests/test_mint_next_batch4_review_result_verifier.py"
)
CANONICAL_SPEC = Path("product/mint_next/batch4/evidence/canonical-json-v1.yaml")
CANONICAL_LOCK = Path("tools/checks/requirements-batch4-canonical-json.lock")
CANONICAL_TOOL = Path("tools/checks/mint_next_batch4_canonical_json.py")
CANONICAL_TEST = Path("tools/checks/tests/test_mint_next_batch4_canonical_json.py")
BATCH = Path("product/mint_next/batch4/batch.yaml")
FORMULAS = Path("product/mint_next/batch4/formula_contracts.yaml")
PHASE = "mint-next-batch4-architecture-promotion-20260802"
PHASE_DIR = f".planning/phases/{PHASE}"
HISTORICAL_AUTHORITY_HEAD = "ff310fca76f78272ea31c5a796ffc149a8fe3b49"
SEMANTIC_ARTIFACTS: dict[str, str] = {
    f"{PHASE_DIR}/CONTEXT.md": "6d83f0c1dd1e704c2e28b0bf3482778100fbaf2db33ae47cda1a3ce6b54f9598",
    f"{PHASE_DIR}/SPEC.md": "4ab8b198160b799032c451f7144118d206784a36e86dac0853c52aca13278de9",
    f"{PHASE_DIR}/PLAN.md": "bf14cf9112813d9543f7b5d36e666df98f45355eaa761595282b8d70c0b72610",
    f"{PHASE_DIR}/VERIFICATION.md": "38802d664123f11de15df2e26bde8018149c83a825e53d2ab2ad12dc9c1cb9aa",
    str(READINESS): "fb3ab9a26cd71b3ae4d9962dbd2d9a3bbd3bef812a3dae4a6916a27b35b038eb",
    str(REVIEW_PROTOCOL): "b44af75b460fd64f7e23c902f1c2d4513fa3744638514d474638f82891a18577",
    str(RESULT_SCHEMA): "b8d5c6be40673451208bb1039c6431b5e3af4214fff042c911a12a56735cfbda",
    str(RESULT_VERIFIER): "7f32a0e62c512dc6e3d5c96d943ecbdbbbd12a4d650f89cc85a44d139b77873f",
    str(RESULT_VERIFIER_TEST): "d9a63c21de33bf7b8da8aabc61b87de75d8a9d8297919b2ec9492e48f3a9ef35",
    str(CANONICAL_SPEC): "838b92e5ebd42800bbb637aec43bd6be10f3186ec0bb5cafeb2ac4302bbd04ce",
    str(CANONICAL_LOCK): "50c36aa891319223be9988eef490c291b8bb107d6b37498262767b4fd25406e1",
    str(CANONICAL_TOOL): "e2982d1ac823b6e1d795f687ab326aedd610d2e556bd1f0e4ae77c1a9c61b80a",
    str(CANONICAL_TEST): "944d4c036c86ab6482ccf8849790a301f86016a2d05a4dd0cb20ae9e4917a71d",
}
CANONICAL: dict[str, str] = {
    "product/mint_next/batch4/batch.yaml": "1747152dbe7af810b7fd4e1116aa14295c50c146aab07670e132f46a8a631c47",
    "product/mint_next/batch4/source-inventory.yaml": "31fc42e2bc1c33be4662860485f36e76c7204e740a3d1dc993277eaec318acbe",
    "product/mint_next/batch4/architecture_conflicts.yaml": "d041d24840e85f64e0e52136a9a1f354550234d47ec99a5d41b9c91731665854",
    "product/mint_next/batch4/calculation_contracts.yaml": "4df33396c1d7303216e21253534054d9531169b427a3b8a542d98c25ea030bcc",
    "product/mint_next/batch4/formula_contracts.yaml": "d226d5651213bd81d5bcb5b82ef6df352ed1254aa817b6dedc0c4a33198868be",
    "product/mint_next/batch4/official_sources.yaml": "8372e1c3462219c98d533040d7986a454fe537d6d535ecbb28414d6c41a3bf8c",
    "product/mint_next/batch4/regulatory_boundaries.yaml": "bcb6f3b8f376558e077a8b4699717f07c0b9f4be8db469902dcad81ce46f8e89",
    "product/mint_next/batch4/domain_coverage.yaml": "8cde9c06d9c7caa93832b98a10fdd4e167fbba32661cdef3cb7c6b9fb099b571",
    "product/mint_next/batch4/audience.yaml": "e71a39364f69f9462e6924e246f2a993352efae030ae290d319f7179a557e3ca",
    "product/mint_next/batch4/concepts.yaml": "81d26df406f20624fb7f555bf3c67e1632e87e9cc3660a2a0285d900af3bd001",
    "product/mint_next/batch4/decisions.yaml": "83e04e192c4da60dccd0dafe64784e70e65ac10900865ae06ef84b19166ddb38",
    "product/mint_next/batch4/experience_graph.yaml": "c51e8d4c0fb362dfa070502784e82a23b93a9e8f3e54db782f9b4e952315d492",
    "product/mint_next/batch4/claims_and_data.yaml": "7d032e2730d8e6df0a5e8a7c625bb73bfaf7d259d59a6a1ec0a3fd42067af7a9",
    "product/mint_next/batch4/legacy_reuse.yaml": "432b6d9002edbfb2460c7184043200a1d716ddd9456c4cbe3505ef83318cfd11",
}
PROTECTED = {
    "legacy": ((".planning/phases/mint-2-0-first-experience-rente-capital/",), 24, "ee3a7ed7e64b789ff1ed29bccaf6bc187b5a2f397a2d2767015d2a293ae00b8d"),
    "product": (("apps/mobile/", "services/backend/"), 3187, "4ba2d80218fe69f1094f2d26bdf7c23313b7c74d23fcd8ab57fa83d516b4a390"),
    "journey": ((".planning/journeys/",), 64, "2ffcc877a091c3cc8025e9c74332a14524aabf02b4b91c9b6e8317602664ac54"),
    "simulator": (("tools/simulator/",), 134, "755bca7dc40adde85a77eac2e6dd12440dde73b679b11ef3cd71bc238ef56b99"),
}


class _UniqueKeyLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False):
    mapping: dict[Any, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ValueError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


_UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping
)


def _load(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = yaml.load(path.read_text(), Loader=_UniqueKeyLoader)
    except Exception as exc:
        errors.append(f"unreadable YAML {path}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path} must be a mapping")
        return {}
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _state_frontmatter(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        parts = path.read_text().split("---", 2)
        if len(parts) != 3 or parts[0].strip():
            raise ValueError("missing YAML frontmatter")
        value = yaml.load(parts[1], Loader=_UniqueKeyLoader)
    except Exception as exc:
        errors.append(f"unreadable STATE frontmatter: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append("STATE frontmatter must be a mapping")
        return {}
    return value


def _tree(root: Path, prefixes: tuple[str, ...], errors: list[str]) -> tuple[int, str]:
    command = ["git", "ls-files", "--", *prefixes]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True)
    if result.returncode:
        errors.append("cannot enumerate protected tracked files")
        return 0, ""
    paths = sorted(filter(None, result.stdout.splitlines()))
    other = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard", "--", *prefixes],
        cwd=root, text=True, capture_output=True,
    )
    if other.returncode or other.stdout.strip():
        errors.append(f"untracked file in protected surface: {other.stdout.strip()}")
    digest = hashlib.sha256()
    for relative in paths:
        path = root / relative
        if not path.is_file() or path.is_symlink():
            errors.append(f"protected path missing or symlinked: {relative}")
            continue
        digest.update(relative.encode() + b"\0" + _sha(path).encode() + b"\n")
    return len(paths), digest.hexdigest()


def _require_authority_ancestry(root: Path, errors: list[str]) -> None:
    """Require lineage, not merely local availability of the authority object."""
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", HISTORICAL_AUTHORITY_HEAD, "HEAD"],
        cwd=root, text=True, capture_output=True,
    )
    if result.returncode != 0:
        errors.append(
            f"historical authority head {HISTORICAL_AUTHORITY_HEAD} must be an ancestor of HEAD"
        )


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    _require_authority_ancestry(root, errors)
    active = _load(root / ".planning/ACTIVE_CONTEXT.json", errors)
    expected_router = {
        "active_milestone": PHASE,
        "active_phase_dir": PHASE_DIR,
        "active_phase_context": f"{PHASE_DIR}/CONTEXT.md",
        "active_spec": f"{PHASE_DIR}/SPEC.md",
    }
    for key, expected in expected_router.items():
        if active.get(key) != expected:
            errors.append(f"active promotion router mismatch: {key}")
    for relative, expected_sha in SEMANTIC_ARTIFACTS.items():
        path = root / relative
        if not path.is_file() or path.is_symlink():
            errors.append(f"missing or symlinked promotion semantic artifact: {relative}")
        elif _sha(path) != expected_sha:
            errors.append(f"promotion semantic artifact byte drift: {relative}")

    readiness = _load(root / READINESS, errors)
    protocol = _load(root / REVIEW_PROTOCOL, errors)
    protocol_keys = {
        "schema_version", "kind", "status", "protocol_eligible",
        "selected_gate", "candidate_head", "review_execution", "current_effect",
        "claim_boundary", "trust_boundary", "implementation_blockers",
        "candidate_freeze_requirements", "future_request_contract",
        "future_supply_chain_requirements",
        "execution_policy_requirements", "review_dimensions",
        "future_provider_failure_policy_requirements",
        "future_provider_family_registry_requirements",
        "future_outbound_data_policy_requirements",
        "future_prompt_requirements", "future_result_contract",
        "implemented_result_payload_component",
        "implemented_canonical_json_component",
        "future_detached_execution_manifest", "future_result_verifier_requirements",
        "finding_remediation_lifecycle", "forbidden_current_claims",
    }
    if set(protocol) != protocol_keys:
        errors.append("cross-provider review protocol must use the exact template schema")
    expected_protocol_scalars = {
        "schema_version": 1,
        "kind": "mint_next_batch4_cross_provider_review_protocol",
        "status": "draft_unproven_blocked",
        "protocol_eligible": False,
        "selected_gate": "none",
        "candidate_head": None,
        "review_execution": None,
        "current_effect": "cannot_select_gate_or_promote",
    }
    for key, expected in expected_protocol_scalars.items():
        if protocol.get(key) != expected:
            errors.append(f"review protocol must keep {key}={expected!r}")
    protocol_claims = protocol.get("claim_boundary") or {}
    if any(value is not False for key, value in protocol_claims.items() if key.startswith("proves_")):
        errors.append("review protocol must not claim an executed or validated review")
    freeze = protocol.get("candidate_freeze_requirements") or {}
    if freeze.get("authority_ancestor") != HISTORICAL_AUTHORITY_HEAD:
        errors.append("review protocol must bind the final accepted authority ancestor")
    if freeze.get("readiness_baseline") != "b6744f3002e0aefd96a759fd02d24891c4d6e3db":
        errors.append("review protocol must bind the accepted readiness baseline")
    if freeze.get("candidate_must_descend_from_readiness_baseline") is not True:
        errors.append("review candidate must descend from the accepted readiness baseline")
    request_contract = protocol.get("future_request_contract") or {}
    protocol_inputs = request_contract.get("required_canonical_registries")
    if protocol_inputs != list(CANONICAL):
        errors.append("review protocol canonical input list must match the exact manifest order")
    expected_context_inputs = [
        f"{PHASE_DIR}/CONTEXT.md", f"{PHASE_DIR}/PLAN.md", f"{PHASE_DIR}/SPEC.md",
        f"{PHASE_DIR}/VERIFICATION.md",
        str(REVIEW_PROTOCOL), str(READINESS),
        "tools/checks/mint_next_batch4_architecture_guard.py",
        "tools/checks/mint_next_batch4_promotion_guard.py",
        "tools/checks/tests/test_mint_next_batch4_architecture_guard.py",
        "tools/checks/tests/test_mint_next_batch4_promotion_guard.py",
        str(RESULT_SCHEMA), str(RESULT_VERIFIER), str(RESULT_VERIFIER_TEST),
        str(CANONICAL_SPEC), str(CANONICAL_LOCK), str(CANONICAL_TOOL), str(CANONICAL_TEST),
        "product/mint_next/batch4/README.md",
        "product/mint_next/batch4/ONE-PAGE.md",
        "product/mint_next/batch4/views/experience-graph.mmd",
    ]
    if request_contract.get("required_context_and_verifiers") != expected_context_inputs:
        errors.append("review protocol context list must match the exact existing review inputs")
    for relative in expected_context_inputs:
        path = root / relative
        if not path.is_file() or path.is_symlink():
            errors.append(f"review protocol input missing or symlinked: {relative}")
    expected_evidence_inputs = [
        "git-lineage-evidence.json", "toolchain-manifest.json",
        "provider-family-registry.json", "outbound-input-classification-manifest.json",
        "authoring-provider-provenance.json", "trusted-attestation-policy.json",
    ]
    if request_contract.get("required_precomputed_evidence_inputs") != expected_evidence_inputs or request_contract.get(
        "every_precomputed_evidence_input_uses_ordered_input_entry_fields"
    ) is not True:
        errors.append("review request must deliver exact precomputed evidence to the no-command reviewer")
    if (protocol.get("trust_boundary") or {}).get("cross_provider_value_if_future_verified") != "diversity_only":
        errors.append("review protocol must keep cross-provider value diversity-only")
    blocker_values = (protocol.get("implementation_blockers") or {}).values()
    if not blocker_values or any(
        not isinstance(value, str)
        or not (value.endswith("_blocking") or value.endswith("_not_implemented"))
        for value in blocker_values
    ):
        errors.append("every review protocol implementation gap must remain blocking")
    expected_blocked_sections = {
        "future_supply_chain_requirements": "absent_unimplemented_blocking",
        "execution_policy_requirements": "unimplemented_blocking",
        "future_provider_failure_policy_requirements": "absent_unimplemented_blocking",
        "future_provider_family_registry_requirements": "absent_unimplemented_blocking",
        "future_outbound_data_policy_requirements": "absent_unimplemented_blocking",
        "future_prompt_requirements": "absent_unimplemented_blocking",
        "future_detached_execution_manifest": "absent_unimplemented_blocking",
        "future_result_verifier_requirements": "absent_unimplemented_blocking",
        "finding_remediation_lifecycle": "absent_unimplemented_blocking",
    }
    for section, expected_status in expected_blocked_sections.items():
        if (protocol.get(section) or {}).get("status") != expected_status:
            errors.append(f"review protocol must keep {section} blocked")
    if request_contract.get("status") != "draft_non_executable":
        errors.append("review request contract must remain non-executable")
    required_request_fields = request_contract.get("required_fields") or []
    for field in (
        "toolchain_manifest_sha256",
        "provider_family_registry_sha256",
        "outbound_input_classification_manifest_sha256",
        "authoring_provider_provenance_sha256",
        "git_lineage_evidence_sha256",
        "trusted_attestation_policy_sha256",
    ):
        if field not in required_request_fields:
            errors.append(f"review request must bind {field}")
    supply_chain = protocol.get("future_supply_chain_requirements") or {}
    if supply_chain.get("request_must_bind") != "toolchain_manifest_sha256" or supply_chain.get(
        "attested_workflow_must_match_every_toolchain_hash"
    ) is not True:
        errors.append("review supply-chain contract must bind and attest every tool hash")
    required_toolchain_bindings = {
        "runtime_interpreter_or_container_image_digest",
        "dependency_lockfiles_and_sha256",
        "secret_scanner_executable_config_rules_and_signature_db_sha256",
        "PII_scanner_executable_config_rules_and_signature_db_sha256",
    }
    if not required_toolchain_bindings.issubset(
        set(supply_chain.get("signed_toolchain_manifest_must_bind") or [])
    ) or not supply_chain.get("trusted_attestation_policy_must_bind") or not supply_chain.get(
        "attestation_subject_must_bind_together"
    ):
        errors.append("review supply-chain contract must bind runtime, scanners, and attestation trust roots")
    if not supply_chain.get("verifier_trust_bootstrap_external_to_candidate_request_and_bundle") or supply_chain.get(
        "bundled_policy_or_registry_is_descriptive_never_a_trust_root"
    ) is not True:
        errors.append("review verifier trust roots must be external to the candidate and bundle")
    failure_policy = protocol.get("future_provider_failure_policy_requirements") or {}
    exact_failure_rules = {
        "one_execution_bundle_contains_exactly_one_provider_attempt": True,
        "retry_requires_new_execution_id_and_new_bundle": True,
        "any_retry_bundle_is_ineligible_for_pass": True,
        "provider_error_rate_limit_or_transport_failure": "reject_bundle",
        "malformed_or_schema_invalid_response": "reject_bundle",
        "fallback_provider_or_model": "reject_bundle",
        "ambiguous_truncation_state": "reject_bundle",
    }
    if any(failure_policy.get(key) != value for key, value in exact_failure_rules.items()):
        errors.append("review provider failure policy must reject retries, fallback, errors, and ambiguity")
    provider_registry = protocol.get("future_provider_family_registry_requirements") or {}
    if provider_registry.get("family_derivation") != (
        "attested_runner_configuration_plus_allowlisted_endpoint_not_result_self_claim"
    ) or provider_registry.get("authoring_provider_family_source") != (
        "trusted_attested_session_or_tool_invocation_record"
    ) or provider_registry.get("unknown_or_unattested_authoring_provider_family") != (
        "diversity_gate_ineligible"
    ):
        errors.append("review provider family must derive from attested configuration, never self-claim")
    if not provider_registry.get("authoring_provenance_artifact_must_bind") or provider_registry.get(
        "request_and_execution_payload_manifest_must_bind_authoring_provenance_sha256"
    ) is not True or provider_registry.get(
        "unknown_unattested_or_uncovered_material_authorship"
    ) != "diversity_gate_ineligible" or provider_registry.get("diversity_check") != (
        "derived_review_provider_family_must_be_outside_complete_authoring_provider_family_set"
    ):
        errors.append("review authoring provider provenance must be delivered and hash-bound")
    required_authorship_bindings = {
        "exact_authorship_boundary_every_semantic_review_input_content_lineage_through_candidate",
        "coverage_mapping_from_every_semantic_input_digest_including_inherited_content_to_all_material_invocation_records",
        "complete_authoring_provider_family_set",
    }
    if not required_authorship_bindings.issubset(
        set(provider_registry.get("authoring_provenance_artifact_must_bind") or [])
    ):
        errors.append("review authorship provenance must cover inherited and changed semantic inputs")
    transport_evidence = (protocol.get("execution_policy_requirements") or {}).get(
        "transport_evidence_required"
    ) or []
    for field in (
        "provider_finish_reason", "declared_response_byte_length",
        "observed_response_body_byte_length",
    ):
        if field not in transport_evidence:
            errors.append(f"review transport evidence must retain {field}")
    outbound = protocol.get("future_outbound_data_policy_requirements") or {}
    required_rejections = {
        "any_secret_or_PII_match",
        "any_unclassified_or_non_allowlisted_file",
        "any_user_financial_or_personal_data",
        "context_budget_exceeded_or_ambiguous",
        "provider_retention_or_training_setting_unknown_or_not_accepted",
    }
    if set(outbound.get("reject_if") or []) != required_rejections or outbound.get(
        "overflow_behavior"
    ) != "reject_never_truncate_summarize_or_drop_inputs" or outbound.get(
        "secret_and_PII_scanners_must_be_bound_by_signed_toolchain_manifest"
    ) is not True or outbound.get("unsupported_binary_scan_error_or_incomplete_coverage") != (
        "reject_bundle"
    ) or outbound.get("scan_scope") != (
        "every_outbound_semantic_artifact_plus_exact_final_serialized_provider_payload_excluding_only_transport_auth_headers"
    ) or outbound.get("scanned_bytes_must_equal_transmitted_payload_bytes_by_sha256") is not True:
        errors.append("review outbound policy must reject secrets, PII, unknown data, and overflow")
    scanner_contract = outbound.get("scanner_result_contract") or {}
    if scanner_contract.get("zero_match_pass_predicate") != (
        "exit_code_zero_and_findings_empty_and_coverage_complete_true"
    ) or scanner_contract.get("verifier_must_parse_schema_findings_coverage_exit_code_and_payload_digest") is not True:
        errors.append("review scanner results must be parsed with zero-match and complete-coverage semantics")
    if not outbound.get("retention_training_evidence_must_bind"):
        errors.append("review retention evidence must bind the exact provider account and attested run")
    if outbound.get("input_classification_manifest_is_transmitted_but_must_not_contain_final_payload_digest") is not True or outbound.get(
        "detached_final_payload_scan_receipt_created_after_serialization_and_never_transmitted"
    ) is not True or not outbound.get("final_payload_scan_receipt_must_bind"):
        errors.append("review outbound scan receipt must remain detached and acyclic")
    result_contract = protocol.get("future_result_contract") or {}
    if result_contract.get("status") != "schema_defined_component_only_non_executable":
        errors.append("review result contract must remain component-only and non-executable")
    if result_contract.get("result_payload_excludes_its_own_hash") is not True:
        errors.append("review result must use a detached non-self-referential hash")
    if result_contract.get("execution_payload_manifest_excludes_attestation_bytes") is not True or result_contract.get(
        "outer_unsigned_bundle_index_holds_payload_manifest_and_attestation_hashes"
    ) is not True:
        errors.append("review result contract must preserve the acyclic two-layer bundle")
    component = protocol.get("implemented_result_payload_component") or {}
    expected_component = {
        "status": "implemented_component_unintegrated_blocking",
        "schema_path": str(RESULT_SCHEMA),
        "schema_sha256": "b8d5c6be40673451208bb1039c6431b5e3af4214fff042c911a12a56735cfbda",
        "verifier_path": str(RESULT_VERIFIER),
        "verifier_sha256": "7f32a0e62c512dc6e3d5c96d943ecbdbbbd12a4d650f89cc85a44d139b77873f",
        "verifier_type": "mint_pinned_result_semantic_verifier_not_generic_JSON_Schema_validator",
        "schema_authority": "declarative_payload_shape_only",
        "verifier_authority": "strict_ingestion_resource_bounds_and_cross_field_semantics_only",
        "success_output": "STRUCTURALLY_VALID_NON_EVIDENCE",
        "proves_review_or_bundle_valid": False,
        "proves_candidate_provider_identity_provenance_or_diversity": False,
        "eligible_as_gate_or_promotion_evidence": False,
    }
    if component != expected_component:
        errors.append("result payload component must remain exact, unintegrated, and non-evidence")
    for relative, expected_sha in {
        RESULT_SCHEMA: expected_component["schema_sha256"],
        RESULT_VERIFIER: expected_component["verifier_sha256"],
    }.items():
        path = root / relative
        if not path.is_file() or path.is_symlink() or _sha(path) != expected_sha:
            errors.append(f"result payload component byte drift: {relative}")
    blockers = protocol.get("implementation_blockers") or {}
    if blockers.get("exact_result_json_schema") != "implemented_component_unintegrated_blocking" or blockers.get(
        "result_payload_semantic_verifier"
    ) != "implemented_component_unintegrated_blocking" or blockers.get(
        "result_bundle_verifier"
    ) != "absent_unimplemented_blocking":
        errors.append("payload components must not inflate bundle-verifier readiness")
    canonical_component = protocol.get("implemented_canonical_json_component") or {}
    expected_canonical_component = {
        "status": "implemented_component_unintegrated_blocking",
        "specification_path": str(CANONICAL_SPEC),
        "specification_sha256": SEMANTIC_ARTIFACTS[str(CANONICAL_SPEC)],
        "dependency_lock_path": str(CANONICAL_LOCK),
        "dependency_lock_sha256": SEMANTIC_ARTIFACTS[str(CANONICAL_LOCK)],
        "implementation_path": str(CANONICAL_TOOL),
        "implementation_sha256": SEMANTIC_ARTIFACTS[str(CANONICAL_TOOL)],
        "test_path": str(CANONICAL_TEST),
        "test_sha256": SEMANTIC_ARTIFACTS[str(CANONICAL_TEST)],
        "algorithm": "RFC_8785_JCS_strict_no_float_I_JSON_subset",
        "dependency": "rfc8785==0.1.4",
        "success_output": "CANONICAL_DIGEST_NON_EVIDENCE",
        "proves_cross_runtime_equivalence": False,
        "proves_request_or_manifest_valid": False,
        "proves_review_or_promotion_evidence": False,
        "eligible_as_gate_or_promotion_evidence": False,
    }
    if canonical_component != expected_canonical_component:
        errors.append("canonical JSON component must remain exact, unintegrated, and non-evidence")
    if blockers.get("canonical_json_primitive") != "implemented_component_unintegrated_blocking" or blockers.get(
        "canonical_request_builder"
    ) != "absent_unimplemented_blocking" or blockers.get(
        "frozen_input_manifest_builder"
    ) != "absent_unimplemented_blocking":
        errors.append("canonical primitive must not inflate request or manifest readiness")
    expected_detached_artifacts = [
        "request.json", "response-body.bin", "response-headers.json",
        "review-result.json", "command-evidence.json",
        "toolchain-manifest.json", "provider-family-registry.json",
        "outbound-input-classification-manifest.json",
        "final-payload-scan-receipt.json", "authoring-provider-provenance.json",
        "git-lineage-evidence.json", "trusted-attestation-policy.json",
    ]
    detached = protocol.get("future_detached_execution_manifest") or {}
    if request_contract.get("canonicalization") != "RFC_8785_JCS_strict_no_float_I_JSON_subset" or detached.get(
        "canonicalization"
    ) != request_contract.get("canonicalization"):
        errors.append("request and detached manifest must share the exact pinned canonicalization")
    if detached.get("must_hash_without_self_reference") != expected_detached_artifacts:
        errors.append("detached execution manifest must preserve exact raw artifacts")
    if detached.get("must_not_hash") != ["workflow-attestation.bundle"] or (
        detached.get("outer_bundle_index") or {}
    ).get("hashes") != [
        "execution-payload-manifest.json", "workflow-attestation.bundle"
    ]:
        errors.append("attestation must bind the payload manifest without a mutual hash cycle")
    verifier_rejections = set(
        (protocol.get("future_result_verifier_requirements") or {}).get("must_reject") or []
    )
    required_transport_rejections = {
        "transport_origin_TLS_peer_redirect_proxy_or_request_ID_header_mismatch_against_provider_registry",
        "any_non_allowlisted_transport_hop_or_ambiguous_effective_endpoint",
        "retention_training_evidence_not_effective_for_exact_provider_account_configuration_and_run",
    }
    if not required_transport_rejections.issubset(verifier_rejections):
        errors.append("review verifier must reject transport and retention evidence mismatch")
    expected_keys = {
        "schema_version", "kind", "phase", "status", "promotion_eligible",
        "selected_gate", "candidate_head", "promotion_receipt", "gates",
        "manifests", "formula_blockers", "claim_boundary",
    }
    if set(readiness) != expected_keys:
        errors.append("promotion readiness must contain exactly the blocked-readiness fields")
    expected_scalar = {
        "schema_version": 1,
        "kind": "mint_next_batch4_architecture_promotion_readiness",
        "phase": PHASE,
        "status": "blocked_waiting_cross_provider_review",
        "promotion_eligible": False,
        "selected_gate": "none",
        "candidate_head": None,
        "promotion_receipt": None,
    }
    for key, expected in expected_scalar.items():
        if readiness.get(key) != expected:
            errors.append(f"promotion readiness must keep {key}={expected!r}")
    state = _state_frontmatter(root / ".planning/STATE.md", errors)
    for key in ("accepted_authority_head", "authority_rollback_proven_through"):
        if state.get(key) != HISTORICAL_AUTHORITY_HEAD:
            errors.append(f"STATE must bind {key} to the final accepted authority head")
    gates = readiness.get("gates") or {}
    if gates != {"external_attestation": "absent", "cross_provider_review": "absent"}:
        errors.append("promotion readiness must keep both gates absent")
    if readiness.get("claim_boundary") != {
        "architecture_promoted": False, "product_runtime": False,
        "swiss_financial_correctness": False, "regulatory_compliance": False,
        "ux_user_validation": False,
    }:
        errors.append("promotion readiness claim boundary overclaims proof")

    batch = _load(root / BATCH, errors)
    if batch.get("status") != "draft_unproven" or batch.get("promotion_receipt") is not None:
        errors.append("Batch 4 must remain draft_unproven with null receipt")
    trust = (batch.get("promotion") or {}).get("trust_boundary") or {}
    if trust.get("external_attestation") != "absent" or trust.get("cross_provider_review") != "absent":
        errors.append("Batch 4 must keep both promotion gates absent")

    formulas = _load(root / FORMULAS, errors).get("formulas")
    blockers = [item for item in formulas or [] if isinstance(item, dict) and item.get("status") == "unimplemented_blocking"]
    if not isinstance(formulas, list) or len(formulas) != 19 or len(blockers) != 19:
        errors.append("all 19 formulas must remain unimplemented_blocking")
    if readiness.get("formula_blockers") != {"count": 19, "status": "unimplemented_blocking"}:
        errors.append("readiness must record exactly 19 unimplemented formula blockers")

    manifest = readiness.get("manifests")
    if not isinstance(manifest, dict) or set(manifest) != {"canonical_registries", *PROTECTED}:
        errors.append("readiness manifests must cover canonical, legacy, product, Journey, and simulator surfaces")
        manifest = {}
    canonical_entries = [{"path": path, "sha256": sha} for path, sha in CANONICAL.items()]
    if manifest.get("canonical_registries") != {"algorithm": "sha256", "entries": canonical_entries}:
        errors.append("canonical registry manifest mismatch")
    for name, (prefixes, expected_count, expected_digest) in PROTECTED.items():
        expected = {
            "algorithm": "sha256-tree-v1", "path_prefixes": list(prefixes),
            "tracked_file_count": expected_count, "digest": expected_digest,
        }
        if manifest.get(name) != expected:
            errors.append(f"readiness {name} manifest mismatch")
        count, digest = _tree(root, prefixes, errors)
        if (count, digest) != (expected_count, expected_digest):
            errors.append(f"protected {name} surface drift")
    for relative, expected in CANONICAL.items():
        path = root / relative
        if not path.is_file() or path.is_symlink() or _sha(path) != expected:
            errors.append(f"canonical registry drift: {relative}")
    return errors


def main() -> int:
    errors = validate(Path.cwd())
    if errors:
        print("Batch 4 promotion readiness guard: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Batch 4 promotion readiness guard: PASS (blocked; no promotion claimed)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
