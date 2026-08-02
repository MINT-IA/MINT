from __future__ import annotations

import copy
import importlib.util
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location(
    "promotion_guard", REPO / "tools/checks/mint_next_batch4_promotion_guard.py"
)
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)
ARCH_SPEC = importlib.util.spec_from_file_location(
    "architecture_guard", REPO / "tools/checks/mint_next_batch4_architecture_guard.py"
)
assert ARCH_SPEC and ARCH_SPEC.loader
architecture_guard = importlib.util.module_from_spec(ARCH_SPEC)
ARCH_SPEC.loader.exec_module(architecture_guard)


@pytest.fixture(scope="module")
def clone(tmp_path_factory: pytest.TempPathFactory) -> Path:
    root = tmp_path_factory.mktemp("promotion-guard") / "repo"
    subprocess.run(
        ["git", "clone", "--quiet", "--shared", str(REPO), str(root)], check=True
    )
    # The readiness/phase files may be deliberately uncommitted in the parent
    # batch. Copy them so tests exercise the exact working-tree contract.
    for relative in [
        guard.READINESS, guard.REVIEW_PROTOCOL, guard.RESULT_SCHEMA,
        guard.RESULT_VERIFIER, guard.RESULT_VERIFIER_TEST, Path(guard.PHASE_DIR),
    ]:
        source, target = REPO / relative, root / relative
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for relative in (
        Path(".planning/ACTIVE_CONTEXT.json"),
        Path(".planning/STATE.md"),
    ):
        shutil.copy2(REPO / relative, root / relative)
    for relative in map(Path, guard.CANONICAL):
        shutil.copy2(REPO / relative, root / relative)
    return root


@pytest.fixture(autouse=True)
def reset(clone: Path):
    subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=clone, check=True, capture_output=True)
    subprocess.run(["git", "clean", "-fd"], cwd=clone, check=True, capture_output=True)
    for relative in [
        guard.READINESS,
        guard.REVIEW_PROTOCOL,
        guard.RESULT_SCHEMA,
        guard.RESULT_VERIFIER,
        guard.RESULT_VERIFIER_TEST,
        Path(guard.PHASE_DIR),
        Path(".planning/ACTIVE_CONTEXT.json"),
        Path(".planning/STATE.md"),
    ]:
        source, target = REPO / relative, clone / relative
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for relative in map(Path, guard.CANONICAL):
        shutil.copy2(REPO / relative, clone / relative)


def _mutate_yaml(root: Path, relative: Path, mutation) -> None:
    path = root / relative
    data = yaml.safe_load(path.read_text())
    mutation(data)
    path.write_text(yaml.safe_dump(data, sort_keys=False))


def test_exact_blocked_readiness_passes(clone: Path) -> None:
    assert guard.validate(clone) == []


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("status", "executed"),
        ("selected_gate", "cross_provider_review"),
        ("candidate_head", "f" * 40),
        ("review_execution", {"verdict": "pass_no_p1_p2"}),
    ],
)
def test_rejects_fabricated_review_execution(
    clone: Path, key: str, value: object
) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL, lambda data: data.__setitem__(key, value)
    )
    assert guard.validate(clone)


def test_rejects_review_protocol_validation_claim(clone: Path) -> None:
    _mutate_yaml(
        clone,
        guard.REVIEW_PROTOCOL,
        lambda data: data["claim_boundary"].__setitem__(
            "proves_reviewer_independence", True
        ),
    )
    assert any("must not claim" in error for error in guard.validate(clone))


def test_rejects_payload_component_as_review_evidence(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["implemented_result_payload_component"].__setitem__(
            "eligible_as_gate_or_promotion_evidence", True
        ),
    )
    assert any("unintegrated, and non-evidence" in error for error in guard.validate(clone))


def test_rejects_payload_verifier_inflating_bundle_readiness(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["implementation_blockers"].__setitem__(
            "result_bundle_verifier", "implemented"
        ),
    )
    assert any("bundle-verifier readiness" in error for error in guard.validate(clone))


@pytest.mark.parametrize("relative", [guard.RESULT_SCHEMA, guard.RESULT_VERIFIER])
def test_rejects_result_component_byte_drift(clone: Path, relative: Path) -> None:
    path = clone / relative
    path.write_bytes(path.read_bytes() + b"\n")
    assert any("result payload component byte drift" in error for error in guard.validate(clone))


def test_rejects_review_protocol_identity_inflation(clone: Path) -> None:
    _mutate_yaml(
        clone,
        guard.REVIEW_PROTOCOL,
        lambda data: data["trust_boundary"].__setitem__(
            "cross_provider_value_if_future_verified", "authenticated_independence"
        ),
    )
    assert any("diversity-only" in error for error in guard.validate(clone))


def test_rejects_incomplete_review_input_manifest(clone: Path) -> None:
    _mutate_yaml(
        clone,
        guard.REVIEW_PROTOCOL,
        lambda data: data["future_request_contract"][
            "required_canonical_registries"
        ].pop(),
    )
    assert any("canonical input list" in error for error in guard.validate(clone))


def test_rejects_incomplete_detached_execution_manifest(clone: Path) -> None:
    _mutate_yaml(
        clone,
        guard.REVIEW_PROTOCOL,
        lambda data: data["future_detached_execution_manifest"][
            "must_hash_without_self_reference"
        ].remove(
            "response-body.bin"
        ),
    )
    assert any("exact raw artifacts" in error for error in guard.validate(clone))


def test_rejects_unbound_toolchain_manifest(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_request_contract"]["required_fields"].remove(
            "toolchain_manifest_sha256"
        ),
    )
    assert any("must bind toolchain_manifest_sha256" in error for error in guard.validate(clone))


def test_rejects_retry_eligible_for_pass(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_failure_policy_requirements"].__setitem__(
            "any_retry_bundle_is_ineligible_for_pass", False
        ),
    )
    assert any("failure policy" in error for error in guard.validate(clone))


def test_rejects_self_claimed_provider_family(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_family_registry_requirements"].__setitem__(
            "family_derivation", "result_self_claim"
        ),
    )
    assert any("never self-claim" in error for error in guard.validate(clone))


def test_rejects_outbound_policy_that_allows_context_overflow(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_outbound_data_policy_requirements"]["reject_if"].remove(
            "context_budget_exceeded_or_ambiguous"
        ),
    )
    assert any("outbound policy" in error for error in guard.validate(clone))


def test_rejects_candidate_without_readiness_ancestry(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["candidate_freeze_requirements"].__setitem__(
            "candidate_must_descend_from_readiness_baseline", False
        ),
    )
    assert any("must descend" in error for error in guard.validate(clone))


def test_rejects_untrusted_authoring_provider_claim(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_family_registry_requirements"].__setitem__(
            "authoring_provider_family_source", "repository_claim"
        ),
    )
    assert any("never self-claim" in error for error in guard.validate(clone))


def test_rejects_toolchain_without_scanner_provenance(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_supply_chain_requirements"][
            "signed_toolchain_manifest_must_bind"
        ].remove("secret_scanner_executable_config_rules_and_signature_db_sha256"),
    )
    assert any("runtime, scanners" in error for error in guard.validate(clone))


def test_rejects_attestation_without_bound_subject(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_supply_chain_requirements"].__setitem__(
            "attestation_subject_must_bind_together", []
        ),
    )
    assert any("attestation trust roots" in error for error in guard.validate(clone))


def test_rejects_attestation_manifest_mutual_hash_cycle(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_detached_execution_manifest"][
            "must_hash_without_self_reference"
        ].append("workflow-attestation.bundle"),
    )
    assert any("exact raw artifacts" in error for error in guard.validate(clone))


def test_rejects_git_evidence_not_delivered_to_reviewer(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_request_contract"][
            "required_precomputed_evidence_inputs"
        ].remove("git-lineage-evidence.json"),
    )
    assert any("deliver exact precomputed evidence" in error for error in guard.validate(clone))


def test_rejects_scan_scope_that_differs_from_transmitted_payload(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_outbound_data_policy_requirements"].__setitem__(
            "scanned_bytes_must_equal_transmitted_payload_bytes_by_sha256", False
        ),
    )
    assert any("outbound policy" in error for error in guard.validate(clone))


def test_rejects_unparsed_scanner_verdict(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_outbound_data_policy_requirements"][
            "scanner_result_contract"
        ].__setitem__(
            "verifier_must_parse_schema_findings_coverage_exit_code_and_payload_digest",
            False,
        ),
    )
    assert any("scanner results must be parsed" in error for error in guard.validate(clone))


def test_rejects_missing_transport_registry_mismatch_rule(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_result_verifier_requirements"]["must_reject"].remove(
            "any_non_allowlisted_transport_hop_or_ambiguous_effective_endpoint"
        ),
    )
    assert any("transport and retention" in error for error in guard.validate(clone))


def test_rejects_retention_evidence_not_bound_to_exact_run(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_outbound_data_policy_requirements"].__setitem__(
            "retention_training_evidence_must_bind", []
        ),
    )
    assert any("exact provider account" in error for error in guard.validate(clone))


def test_rejects_transmitted_manifest_with_final_payload_digest(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_outbound_data_policy_requirements"].__setitem__(
            "input_classification_manifest_is_transmitted_but_must_not_contain_final_payload_digest",
            False,
        ),
    )
    assert any("detached and acyclic" in error for error in guard.validate(clone))


def test_rejects_unbound_authoring_provider_provenance(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_family_registry_requirements"].__setitem__(
            "request_and_execution_payload_manifest_must_bind_authoring_provenance_sha256",
            False,
        ),
    )
    assert any("delivered and hash-bound" in error for error in guard.validate(clone))


def test_rejects_bundle_controlled_trust_bootstrap(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_supply_chain_requirements"].__setitem__(
            "bundled_policy_or_registry_is_descriptive_never_a_trust_root", False
        ),
    )
    assert any("external to the candidate" in error for error in guard.validate(clone))


def test_rejects_phantom_or_incomplete_review_context(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_request_contract"]["required_context_and_verifiers"].pop(),
    )
    assert any("exact existing review inputs" in error for error in guard.validate(clone))


def test_rejects_incomplete_multi_provider_authorship_coverage(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_family_registry_requirements"].__setitem__(
            "unknown_unattested_or_uncovered_material_authorship", "allowed"
        ),
    )
    assert any("authoring provider provenance" in error for error in guard.validate(clone))


def test_rejects_review_context_without_verification_claims(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_request_contract"]["required_context_and_verifiers"].remove(
            f"{guard.PHASE_DIR}/VERIFICATION.md"
        ),
    )
    assert any("exact existing review inputs" in error for error in guard.validate(clone))


def test_rejects_authorship_boundary_excluding_inherited_inputs(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.REVIEW_PROTOCOL,
        lambda data: data["future_provider_family_registry_requirements"][
            "authoring_provenance_artifact_must_bind"
        ].remove(
            "exact_authorship_boundary_every_semantic_review_input_content_lineage_through_candidate"
        ),
    )
    assert any("inherited and changed" in error for error in guard.validate(clone))


@pytest.mark.parametrize("relative", guard.SEMANTIC_ARTIFACTS)
def test_rejects_appended_semantic_contradiction(clone: Path, relative: str) -> None:
    path = clone / relative
    path.write_text(path.read_text() + "\n# promoted: true; self-attested and production-ready\n")
    assert any(
        f"promotion semantic artifact byte drift: {relative}" in error
        for error in guard.validate(clone)
    )


@pytest.mark.parametrize(
    "key", ["accepted_authority_head", "authority_rollback_proven_through"]
)
def test_rejects_stale_or_forged_final_authority_state(clone: Path, key: str) -> None:
    path = clone / ".planning/STATE.md"
    path.write_text(
        path.read_text().replace(
            f"{key}: {guard.HISTORICAL_AUTHORITY_HEAD}", f"{key}: {'f' * 40}", 1
        )
    )
    assert any(f"STATE must bind {key}" in error for error in guard.validate(clone))


def test_rejects_orphan_history_with_identical_committed_tree(clone: Path) -> None:
    original_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=clone, check=True, text=True,
        capture_output=True,
    ).stdout.strip()
    tree = subprocess.run(
        ["git", "rev-parse", "HEAD^{tree}"], cwd=clone, check=True, text=True,
        capture_output=True,
    ).stdout.strip()
    orphan = subprocess.run(
        ["git", "commit-tree", tree, "-m", "hostile orphan with identical tree"],
        cwd=clone, check=True, text=True, capture_output=True,
    ).stdout.strip()
    try:
        subprocess.run(
            ["git", "checkout", "--quiet", "--detach", orphan], cwd=clone, check=True
        )
        # Preserve the exact working-tree contract while changing only ancestry.
        for relative in [
            guard.READINESS, Path(guard.PHASE_DIR), Path(".planning/ACTIVE_CONTEXT.json"),
            Path(".planning/STATE.md"),
        ]:
            source, target = REPO / relative, clone / relative
            if source.is_dir():
                shutil.copytree(source, target, dirs_exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        errors = guard.validate(clone)
        assert any("must be an ancestor of HEAD" in error for error in errors)
        architecture_errors = architecture_guard.validate(clone)
        assert any(
            "must be an ancestor of HEAD" in error for error in architecture_errors
        )
    finally:
        subprocess.run(
            ["git", "checkout", "--quiet", "--detach", original_head], cwd=clone, check=True
        )


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("promotion_eligible", True),
        ("selected_gate", "external_attestation"),
        ("candidate_head", "f" * 40),
        ("promotion_receipt", {"head": "f" * 40}),
        ("status", "promoted"),
    ],
)
def test_rejects_fake_promotion_fields(clone: Path, key: str, value: object) -> None:
    _mutate_yaml(clone, guard.READINESS, lambda data: data.__setitem__(key, value))
    assert guard.validate(clone)


def test_rejects_present_gate(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["gates"].__setitem__("cross_provider_review", "present"),
    )
    assert guard.validate(clone)


def test_rejects_coordinated_canonical_rewrite(clone: Path) -> None:
    registry = clone / "product/mint_next/batch4/concepts.yaml"
    registry.write_text(registry.read_text() + "\n# forged\n")
    forged = guard._sha(registry)
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: next(
            item for item in data["manifests"]["canonical_registries"]["entries"]
            if item["path"].endswith("concepts.yaml")
        ).__setitem__("sha256", forged),
    )
    assert any("canonical registry" in error for error in guard.validate(clone))


@pytest.mark.parametrize(
    "relative",
    [
        "apps/mobile/lib/main.dart",
        ".planning/journeys/BOARD.md",
        ".planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md",
        "tools/simulator/README.md",
    ],
)
def test_rejects_protected_surface_mutation(clone: Path, relative: str) -> None:
    path = clone / relative
    path.write_text(path.read_text() + "\nforged\n")
    assert any("surface drift" in error for error in guard.validate(clone))


def test_rejects_untracked_file_in_protected_surface(clone: Path) -> None:
    path = clone / ".planning/journeys/forged.yaml"
    path.write_text("fake: true\n")
    assert any("untracked file" in error for error in guard.validate(clone))


def test_rejects_formula_implementation(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.FORMULAS,
        lambda data: data["formulas"][0].__setitem__("status", "implemented"),
    )
    assert any("19 formulas" in error for error in guard.validate(clone))


def test_rejects_product_or_compliance_overclaim(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["claim_boundary"].__setitem__("regulatory_compliance", True),
    )
    assert any("overclaims" in error for error in guard.validate(clone))


def test_rejects_router_split_brain(clone: Path) -> None:
    _mutate_yaml(
        clone, Path(".planning/ACTIVE_CONTEXT.json"),
        lambda data: data.__setitem__("active_milestone", "old-phase"),
    )
    assert any("router mismatch" in error for error in guard.validate(clone))


def test_architecture_guard_rejects_router_mutation_preserving_phase(clone: Path) -> None:
    path = clone / ".planning/ACTIVE_CONTEXT.md"
    path.write_text(path.read_text() + "\nforged but same active milestone\n")
    assert any(
        "source inventory hash drift: .planning/ACTIVE_CONTEXT.md" in error
        for error in architecture_guard.validate(clone)
    )


def test_rejects_duplicate_yaml_key(clone: Path) -> None:
    path = clone / guard.READINESS
    path.write_text(path.read_text() + "status: promoted\n")
    assert any("duplicate YAML key" in error for error in guard.validate(clone))


def test_rejects_manifest_path_traversal(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["manifests"]["product"]["path_prefixes"].append("../"),
    )
    assert any("product manifest mismatch" in error for error in guard.validate(clone))


def test_rejects_symlink_in_protected_surface(clone: Path) -> None:
    path = clone / ".planning/journeys/BOARD.md"
    path.unlink()
    path.symlink_to("TODAY.md")
    assert any("symlinked" in error for error in guard.validate(clone))
