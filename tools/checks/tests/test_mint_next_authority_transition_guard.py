from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from dataclasses import replace
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from tools.checks.mint_next_authority_transition_guard import (
    AUDITED_TRANSITION_HEAD,
    AUTHORITY_MARKER,
    TransitionPolicy,
    run_guard,
)


OLD = "mint-2-0-first-experience-rente-capital"
NEW = "mint-next-architecture-authority-20260802"
NEW_DIR = f".planning/phases/{NEW}"
OLD_DIR = f".planning/phases/{OLD}"
ACTIVE_BOUNDARIES = {
    ".planning/ACTIVE_CONTEXT.md": "## Not Active",
    ".planning/STATE.md": "## Historical Receipts",
    ".planning/ROADMAP.md": "## Soldage des gates legacy",
    ".planning/INDEX.md": "## `_archive/`",
}


def _write(root: Path, relative: str, content: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _insert_into_active_section(root: Path, relative: str, content: str) -> None:
    path = root / relative
    boundary = ACTIVE_BOUNDARIES[relative]
    current = path.read_text(encoding="utf-8")
    assert boundary in current
    path.write_text(current.replace(boundary, content + boundary, 1), encoding="utf-8")


def _git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    ).stdout.strip()


def _fixture(tmp_path: Path) -> tuple[Path, TransitionPolicy]:
    root = tmp_path / "repo"
    root.mkdir()
    _git(root, "init")
    _git(root, "config", "user.email", "guard@example.invalid")
    _git(root, "config", "user.name", "Guard Test")

    protected = {
        f"{OLD_DIR}/CONTEXT.md": "legacy context\n",
        f"{OLD_DIR}/SPEC.md": "legacy spec\n",
        "apps/mobile/lib/app.dart": "legacy mobile\n",
        "services/backend/app/main.py": "legacy backend\n",
        ".planning/journeys/records/JOS-001.json": "{}\n",
        ".planning/journeys/issues/JOS-001.json": "{}\n",
        ".planning/journeys/evidence/JOS-001.json": "{}\n",
        "tools/simulator/flows/existing.yaml": "appId: ch.mint\n",
        "product/mint_next/batch4/batch.yaml": yaml.safe_dump(
            {"schema_version": 1, "status": "draft_unproven", "promotion_receipt": None}
        ),
        "product/mint_next/batch4/architecture_conflicts.yaml": yaml.safe_dump(
            {
                "schema_version": 1,
                "conflicts": [
                    {
                        "id": "retirement_first_active_context",
                        "severity": "blocker",
                        "status": "unresolved",
                    }
                ],
            }
        ),
    }
    for path, content in protected.items():
        _write(root, path, content)
    _git(root, "add", ".")
    _git(root, "commit", "-m", "baseline")
    baseline = _git(root, "rev-parse", "HEAD")
    audited_head = baseline

    marker = AUTHORITY_MARKER.format(
        milestone=NEW,
        phase_dir=NEW_DIR,
        context=f"{NEW_DIR}/CONTEXT.md",
        spec=f"{NEW_DIR}/SPEC.md",
    )
    active = {
        "schema_version": 3,
        "active_milestone": NEW,
        "active_phase_dir": NEW_DIR,
        "active_phase_context": f"{NEW_DIR}/CONTEXT.md",
        "active_spec": f"{NEW_DIR}/SPEC.md",
        "next_product_phase_context": f"{NEW_DIR}/CONTEXT.md",
        "authority_mode": "governance-only",
        "successor_product_phase_queued": False,
        "historical_not_active": [OLD],
        "preserved_runtime_vertical_not_global_authority": [OLD],
    }
    _write(root, ".planning/ACTIVE_CONTEXT.json", json.dumps(active))
    for path in (
        ".planning/ACTIVE_CONTEXT.md",
        ".planning/STATE.md",
        ".planning/ROADMAP.md",
        ".planning/INDEX.md",
    ):
        _write(
            root,
            path,
            f"{marker}\nGovernance-only authority; no successor product phase queued.\n"
            f"{ACTIVE_BOUNDARIES[path]}\nHistorical receipts remain unchanged.\n",
        )
    _write(
        root,
        ".planning/STATE.md",
        "---\nstatus: governance-authority-accepted\n"
        f"accepted_transition_head: {audited_head}\n---\n"
        f"{marker}\nGovernance-only authority accepted.\n"
        f"{ACTIVE_BOUNDARIES['.planning/STATE.md']}\nHistorical receipts remain unchanged.\n",
    )
    _write(root, f"{NEW_DIR}/CONTEXT.md", "governance-only transition\n")
    _write(root, f"{NEW_DIR}/SPEC.md", "governance-only spec\n")
    _write(root, f"{NEW_DIR}/PLAN.md", "governance-only plan\n")
    _write(
        root,
        f"{NEW_DIR}/VERIFICATION.md",
        "Status: **ACCEPTED — GOVERNANCE AUTHORITY ONLY**\n"
        f"Audited transition head: `{audited_head}`\n"
        "Accepted scope: `governance_authority_only`\n"
        "Batch 4 promotion: **false**\n",
    )
    artifact_specs = {
        name: {
            "path": f"{NEW_DIR}/evidence/{filename}",
            "data": {
                "schema_version": 1,
                "advisory_id": evidence_id,
                "review": name,
                "claimed_context_label": reviewer,
                "audited_head": audited_head,
                "advisory_outcome": "REPORTED_PASS",
                "reported_p1": 0,
                "reported_p2": 0,
                "limitation": f"{name} scope only",
                "source": "untrusted_separate_context_review_report",
                "captured_at": "2026-08-02T07:28:44Z",
                "checks": [
                    {"command": "test command", "exit": 0, "evidence": "PASS"}
                ],
            },
        }
        for name, reviewer, evidence_id, filename in (
            (
                "authority_coherence",
                "authority_roast_coherence",
                "advisory:authority-coherence:b88a42557",
                "authority-coherence-b88a42557.yaml",
            ),
            (
                "legacy_evidence_preservation",
                "authority_roast_preservation",
                "advisory:legacy-preservation:b88a42557",
                "legacy-preservation-b88a42557.yaml",
            ),
            (
                "guard_hostile_mutation_quality",
                "authority_roast_guard",
                "advisory:guard-hostile-mutations:b88a42557",
                "guard-hostile-mutations-b88a42557.yaml",
            ),
        )
    }
    for spec in artifact_specs.values():
        _write(root, spec["path"], yaml.safe_dump(spec["data"], sort_keys=False))
        spec["sha256"] = hashlib.sha256((root / spec["path"]).read_bytes()).hexdigest()
    _write(
        root,
        "product/mint_next/batch4/architecture_conflicts.yaml",
        yaml.safe_dump(
            {
                "schema_version": 1,
                "conflicts": [
                    {
                        "id": "retirement_first_active_context",
                        "severity": "blocker",
                        "status": "resolved_for_governance_routing_only",
                        "resolution_required": (
                            "Satisfied for governance routing only from reproducible deterministic "
                            "evidence; Batch 4 promotion remains blocked pending external "
                            "attestation or cross-provider review."
                        ),
                        "resolution": {
                            "kind": "governance_authority_transition",
                            "authority_milestone": NEW,
                            "legacy_disposition": "preserved_runtime_vertical_not_global_authority",
                            "evidence": [
                                ".planning/ACTIVE_CONTEXT.json",
                                ".planning/ACTIVE_CONTEXT.md",
                                ".planning/STATE.md",
                                ".planning/ROADMAP.md",
                                ".planning/INDEX.md",
                            ],
                            "verification": {
                                "audited_head": audited_head,
                                "accepted_scope": "governance_authority_only",
                                "batch4_promotion": False,
                                "successor_product_phase_queued": False,
                                "trust_basis": "reproducible_deterministic_git_evidence_only",
                                "external_attestation": "absent",
                                "cross_provider_review": "absent",
                                "cross_provider_review_scope": (
                                    "diversity_only_not_authenticated_or_cryptographic_identity"
                                ),
                                "batch4_promotion_gate": (
                                    "blocked_pending_external_attestation_or_cross_provider_review"
                                ),
                                "advisory_reports": [
                                    {
                                        "name": name,
                                        "claimed_context_label": reviewer,
                                        "advisory_outcome": "REPORTED_PASS",
                                        "reported_p1": 0,
                                        "reported_p2": 0,
                                        "audited_head": audited_head,
                                        "advisory_id": evidence_id,
                                        "artifact_path": artifact_specs[name]["path"],
                                        "artifact_sha256": artifact_specs[name]["sha256"],
                                        "limitation": artifact_specs[name]["data"]["limitation"],
                                        "trust": "untrusted_advisory_only",
                                    }
                                    for name, reviewer, evidence_id in (
                                        (
                                            "authority_coherence",
                                            "authority_roast_coherence",
                                            "advisory:authority-coherence:b88a42557",
                                        ),
                                        (
                                            "legacy_evidence_preservation",
                                            "authority_roast_preservation",
                                            "advisory:legacy-preservation:b88a42557",
                                        ),
                                        (
                                            "guard_hostile_mutation_quality",
                                            "authority_roast_guard",
                                            "advisory:guard-hostile-mutations:b88a42557",
                                        ),
                                    )
                                ],
                            },
                        },
                    }
                ],
            }
        ),
    )
    inventory_roles = {
        ".planning/ACTIVE_CONTEXT.json": "governance_authority_verified",
        ".planning/ACTIVE_CONTEXT.md": "governance_authority_verified",
        ".planning/STATE.md": "governance_authority_verified",
        ".planning/ROADMAP.md": "governance_authority_verified",
        ".planning/INDEX.md": "governance_authority_verified",
    }
    _write(
        root,
        "product/mint_next/batch4/source-inventory.yaml",
        yaml.safe_dump(
            {
                "schema_version": 1,
                "sources": [
                    {
                        "path": path,
                        "sha256": hashlib.sha256((root / path).read_bytes()).hexdigest(),
                        "role": role,
                    }
                    for path, role in inventory_roles.items()
                ],
            }
        ),
    )
    manifest = {
        path: hashlib.sha256(content.encode()).hexdigest()
        for path, content in protected.items()
        if path.startswith(f"{OLD_DIR}/")
    }
    policy = TransitionPolicy(
        baseline_ref=baseline,
        audited_transition_head=audited_head,
        audited_transition_manifest={},
        roast_artifacts={
            name: {"path": spec["path"], "sha256": spec["sha256"]}
            for name, spec in artifact_specs.items()
        },
        verify_rollback=False,
        legacy_manifest=manifest,
    )
    return root, policy


def test_valid_governance_only_transition_passes(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    assert run_guard(root, policy) == []


def test_committed_governance_range_has_exact_rollback_proof(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _git(root, "add", ".")
    _git(root, "commit", "-m", "accepted governance metadata")
    assert run_guard(root, replace(policy, verify_rollback=True)) == []


def test_rejects_synthetic_accepted_tree_without_audited_ancestor(
    tmp_path: Path,
) -> None:
    root, policy = _fixture(tmp_path)
    _git(root, "add", ".")
    _git(root, "commit", "-m", "synthetic accepted tree")
    baseline_tree = _git(root, "rev-parse", f"{policy.baseline_ref}^{{tree}}")
    sibling = _git(
        root,
        "commit-tree",
        baseline_tree,
        "-p",
        policy.baseline_ref,
        "-m",
        "synthetic audited sibling",
    )
    hostile_policy = replace(
        policy,
        audited_transition_head=sibling,
        audited_transition_manifest={},
    )
    errors = run_guard(root, hostile_policy)
    assert any("audited transition must be an ancestor" in error for error in errors)


def test_rejects_missing_audited_transition_object(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    hostile_policy = replace(policy, audited_transition_head="0" * 40)
    assert any(
        "audited transition head does not resolve" in error
        for error in run_guard(root, hostile_policy)
    )


def test_rejects_audited_transition_diff_manifest_mismatch(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    hostile_policy = replace(
        policy,
        audited_transition_manifest={"invented/path": "0" * 64},
    )
    errors = run_guard(root, hostile_policy)
    assert any("audited transition diff surface mismatch" in error for error in errors)


@pytest.mark.parametrize(
    ("path", "replacement", "needle"),
    [
        ("apps/mobile/lib/app.dart", "changed\n", "product/runtime path changed"),
        ("services/backend/app/main.py", "changed\n", "product/runtime path changed"),
        (".planning/journeys/records/JOS-001.json", "changed\n", "Journey OS/runtime evidence changed"),
        ("tools/simulator/flows/existing.yaml", "changed\n", "Journey OS/runtime evidence changed"),
        (f"{OLD_DIR}/SPEC.md", "changed\n", "legacy retirement baseline mismatch"),
    ],
)
def test_rejects_destructive_or_runtime_change(
    tmp_path: Path, path: str, replacement: str, needle: str
) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, path, replacement)
    errors = run_guard(root, policy)
    assert any(needle in error and path in error for error in errors)


def test_rejects_router_disagreement_and_old_authority(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    state = root / ".planning/STATE.md"
    state.write_text(f"Active milestone: {OLD}\n", encoding="utf-8")
    errors = run_guard(root, policy)
    assert any("router authority marker missing or inconsistent" in error for error in errors)
    assert any("old retirement authority remains active" in error for error in errors)


def test_rejects_unresolved_conflict(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    data["conflicts"][0]["status"] = "unresolved"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("expected 'resolved_for_governance_routing_only'" in error for error in run_guard(root, policy))


def test_rejects_pending_conflict_after_acceptance(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    data["conflicts"][0]["status"] = "resolved"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("expected 'resolved_for_governance_routing_only'" in error for error in run_guard(root, policy))


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        ("wrong_head", "audited_head"),
        ("missing_roast", "exactly the three named"),
        ("failed_roast", "outcome must be REPORTED_PASS"),
        ("nonzero_p1", "report p1=0 and p2=0"),
        ("missing_evidence", "advisory_id mismatch"),
        ("wrong_roast_head", "audited_head mismatch"),
    ],
)
def test_rejects_fake_or_incomplete_acceptance_roasts(
    tmp_path: Path, mutation: str, needle: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    verification = data["conflicts"][0]["resolution"]["verification"]
    if mutation == "wrong_head":
        verification["audited_head"] = "0" * 40
    elif mutation == "missing_roast":
        verification["advisory_reports"].pop()
    elif mutation == "failed_roast":
        verification["advisory_reports"][0]["advisory_outcome"] = "PASS"
    elif mutation == "nonzero_p1":
        verification["advisory_reports"][0]["reported_p1"] = 1
    elif mutation == "missing_evidence":
        verification["advisory_reports"][0]["advisory_id"] = ""
    elif mutation == "wrong_roast_head":
        verification["advisory_reports"][0]["audited_head"] = "0" * 40
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any(needle in error for error in run_guard(root, policy))


@pytest.mark.parametrize(
    "overclaim",
    [
        "The transition was independently verified.\n",
        "Reviewer independence is established.\n",
        "This has authenticated reviewer identity.\n",
        "Authentication has been verified.\n",
        "The signed attestation proves acceptance.\n",
        "The signature is valid.\n",
        "The receipt is tamper-proof.\n",
        "The review is cryptographically authenticated.\n",
        "External attestation exists.\n",
        "## Independent Audit\n",
        "The advisory reports form the acceptance basis.\n",
    ],
)
def test_rejects_acceptance_trust_overclaims(
    tmp_path: Path, overclaim: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / NEW_DIR / "VERIFICATION.md"
    path.write_text(path.read_text() + "\n" + overclaim, encoding="utf-8")
    assert any(
        "forbidden acceptance trust overclaim" in error
        for error in run_guard(root, policy)
    )


def test_allows_explicit_negation_of_external_attestation(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / NEW_DIR / "VERIFICATION.md"
    path.write_text(
        path.read_text()
        + "\nTrust boundary: no external signature, authenticated identity, "
        + "or external attestation exists.\n",
        encoding="utf-8",
    )
    assert run_guard(root, policy) == []


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("trust_basis", "untrusted_advisory_reports"),
        ("external_attestation", "present"),
        ("cross_provider_review", "complete"),
        ("cross_provider_review_scope", "authenticated_identity"),
        ("batch4_promotion_gate", "open"),
    ],
)
def test_rejects_non_deterministic_or_completed_attestation_basis(
    tmp_path: Path, field: str, value: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    data["conflicts"][0]["resolution"]["verification"][field] = value
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any(
        f"transition verification {field!r}" in error
        for error in run_guard(root, policy)
    )


def test_rejects_advisory_report_promoted_to_trusted_evidence(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    advisory = data["conflicts"][0]["resolution"]["verification"]["advisory_reports"][0]
    advisory["trust"] = "trusted_acceptance_evidence"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any(
        "must be untrusted_advisory_only" in error for error in run_guard(root, policy)
    )


@pytest.mark.parametrize("target", ["verification", "advisory"])
def test_rejects_hidden_advisory_acceptance_proof_field(
    tmp_path: Path, target: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    verification = data["conflicts"][0]["resolution"]["verification"]
    if target == "verification":
        verification["advisory_reports_are_acceptance_proof"] = True
    else:
        verification["advisory_reports"][0]["acceptance_proof"] = True
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("schema" in error for error in run_guard(root, policy))


def test_rejects_roast_artifact_byte_tampering(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    artifact = policy.roast_artifacts["authority_coherence"]
    path = root / artifact["path"]
    path.write_text(path.read_text() + "# tampered\n", encoding="utf-8")
    assert any(
        "artifact hash mismatch" in error for error in run_guard(root, policy)
    )


def test_rejects_coordinated_roast_artifact_receipt_rewrite(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    conflict_path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    conflict = yaml.safe_load(conflict_path.read_text())
    roast = conflict["conflicts"][0]["resolution"]["verification"]["advisory_reports"][0]
    roast["artifact_path"] = policy.roast_artifacts["legacy_evidence_preservation"]["path"]
    roast["artifact_sha256"] = policy.roast_artifacts["legacy_evidence_preservation"]["sha256"]
    conflict_path.write_text(yaml.safe_dump(conflict), encoding="utf-8")
    assert any(
        "artifact receipt mismatch" in error for error in run_guard(root, policy)
    )


def test_rejects_roast_artifact_with_empty_checks_even_if_rehashed(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    contracts = {name: dict(contract) for name, contract in policy.roast_artifacts.items()}
    contract = contracts["authority_coherence"]
    path = root / contract["path"]
    artifact = yaml.safe_load(path.read_text())
    artifact["checks"] = []
    path.write_text(yaml.safe_dump(artifact, sort_keys=False), encoding="utf-8")
    contract["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    conflict_path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    conflict = yaml.safe_load(conflict_path.read_text())
    roast = conflict["conflicts"][0]["resolution"]["verification"]["advisory_reports"][0]
    roast["artifact_sha256"] = contract["sha256"]
    conflict_path.write_text(yaml.safe_dump(conflict), encoding="utf-8")
    hostile_policy = replace(policy, roast_artifacts=contracts)
    assert any(
        "artifact checks must be nonempty" in error
        for error in run_guard(root, hostile_policy)
    )


@pytest.mark.parametrize(
    ("relative", "old", "new", "needle"),
    [
        (
            f"{NEW_DIR}/VERIFICATION.md",
            "Audited transition head:",
            "Audited transition head: `0000000000000000000000000000000000000000`",
            "exactly one audited head",
        ),
        (
            ".planning/STATE.md",
            "status: governance-authority-accepted",
            "status: governance-only-authority-transition",
            "STATE must record exactly one status",
        ),
    ],
)
def test_rejects_fake_accepted_phase_or_state(
    tmp_path: Path, relative: str, old: str, new: str, needle: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / relative
    if relative.endswith("VERIFICATION.md"):
        current = path.read_text()
        old = next(line for line in current.splitlines() if line.startswith(old))
    path.write_text(path.read_text().replace(old, new), encoding="utf-8")
    errors = run_guard(root, policy)
    assert any(needle in error for error in errors)


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        (
            "Batch 4 promotion: **true**\nBatch 4 promotion: **false**\n",
            "exactly one Batch 4 promotion",
        ),
        (
            "Batch 4 promotion: **false**\nBatch 4 promotion: **false**\n",
            "exactly one Batch 4 promotion",
        ),
    ],
)
def test_rejects_duplicate_or_conflicting_batch4_promotion_receipt(
    tmp_path: Path, mutation: str, needle: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / NEW_DIR / "VERIFICATION.md"
    current = path.read_text()
    path.write_text(
        current.replace("Batch 4 promotion: **false**\n", mutation),
        encoding="utf-8",
    )
    assert any(needle in error for error in run_guard(root, policy))


def test_rejects_conflict_satisfaction_denial(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    data["conflicts"][0]["resolution_required"] = (
        "NOT satisfied; independent verification is fabricated."
    )
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any(
        "exactly one canonical governance-only satisfaction claim" in error
        for error in run_guard(root, policy)
    )


@pytest.mark.parametrize("key", ["resolution_required", "batch4_promotion"])
def test_rejects_duplicate_high_risk_conflict_keys(tmp_path: Path, key: str) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    current = path.read_text()
    path.write_text(f"{key}: malicious-duplicate\n" + current, encoding="utf-8")
    assert any(
        f"exactly one {key!r} field" in error for error in run_guard(root, policy)
    )


def test_draft_requires_null_receipt(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/batch.yaml"
    data = yaml.safe_load(path.read_text())
    data["promotion_receipt"] = "product/mint_next/batch4/evidence/promotion.yaml"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("draft batch must not claim a promotion receipt" in error for error in run_guard(root, policy))


def test_rejects_any_promotion_during_transition(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    batch_path = root / "product/mint_next/batch4/batch.yaml"
    batch = yaml.safe_load(batch_path.read_text())
    batch["status"] = "promoted_architecture"
    batch["promotion_receipt"] = "product/mint_next/batch4/evidence/promotion.yaml"
    batch_path.write_text(yaml.safe_dump(batch), encoding="utf-8")
    errors = run_guard(root, policy)
    assert any("must remain draft_unproven" in error for error in errors)


def test_rejects_untracked_file_in_protected_surface(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, "apps/mobile/lib/surprise.dart", "oops\n")
    errors = run_guard(root, policy)
    assert any("product/runtime path changed" in error and "surprise.dart" in error for error in errors)


def test_rejects_batch4_registry_content_mutation(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/concepts.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("concepts: []\n", encoding="utf-8")
    errors = run_guard(root, policy)
    assert any("outside governance transition allowlist" in error and "concepts.yaml" in error for error in errors)


def test_rejects_arbitrary_batch4_file_and_unrelated_repo_file(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, "product/mint_next/batch4/surprise.yaml", "claim: fake\n")
    _write(root, "docs/unrelated.md", "scope drift\n")
    errors = run_guard(root, policy)
    assert any("outside governance transition allowlist" in error and "surprise.yaml" in error for error in errors)
    assert any("outside governance transition allowlist" in error and "docs/unrelated.md" in error for error in errors)


def test_rejects_unmanifested_file_in_legacy_vertical(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, f"{OLD_DIR}/invented-receipt.md", "not audited\n")
    errors = run_guard(root, policy)
    assert any("unexpected file" in error and "invented-receipt.md" in error for error in errors)


@pytest.mark.parametrize("filename", ["PLAN.md", "VERIFICATION.md"])
def test_requires_all_four_canonical_phase_files(tmp_path: Path, filename: str) -> None:
    root, policy = _fixture(tmp_path)
    (root / NEW_DIR / filename).unlink()
    assert any("canonical phase file missing" in error for error in run_guard(root, policy))


def test_rejects_coordinated_semantic_override_and_false_claims(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    for relative in (".planning/ROADMAP.md", ".planning/INDEX.md"):
        _insert_into_active_section(
            root,
            relative,
            "\n## Binding Override\n"
            + "The active product authority is `malicious-reboot`; it supersedes the governance phase. "
            + "MINT Next is built, shipped, compliant, and user validated.\n",
        )
    errors = run_guard(root, policy)
    assert any("conflicting authority claim" in error for error in errors)
    assert any("forbidden completion claim" in error for error in errors)


def test_rejects_structured_override_even_when_inventory_hashes_are_updated(
    tmp_path: Path,
) -> None:
    root, policy = _fixture(tmp_path)
    targets = (".planning/ROADMAP.md", ".planning/INDEX.md")
    for relative in targets:
        _insert_into_active_section(
            root,
            relative,
            "\n## Active Override\n"
            + "Active phase_dir: `.planning/phases/evil`\n"
            + "Active context: [`.planning/phases/evil/CONTEXT.md`](evil-context)\n"
            + "Active spec: `.planning/phases/evil/SPEC.md`\n",
        )
    inventory_path = root / "product/mint_next/batch4/source-inventory.yaml"
    inventory = yaml.safe_load(inventory_path.read_text())
    for item in inventory["sources"]:
        if item["path"] in targets:
            item["sha256"] = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
    inventory_path.write_text(yaml.safe_dump(inventory), encoding="utf-8")

    errors = run_guard(root, policy)
    assert any("conflicting explicit phase_dir authority" in error for error in errors)
    assert any("conflicting explicit context authority" in error for error in errors)
    assert any("conflicting explicit spec authority" in error for error in errors)


@pytest.mark.parametrize(
    ("missing_path", "bad_role"),
    [
        (".planning/ROADMAP.md", None),
        (None, ".planning/INDEX.md"),
    ],
)
def test_rejects_incomplete_or_wrong_router_source_inventory(
    tmp_path: Path, missing_path: str | None, bad_role: str | None
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/source-inventory.yaml"
    data = yaml.safe_load(path.read_text())
    if missing_path:
        data["sources"] = [item for item in data["sources"] if item["path"] != missing_path]
    if bad_role:
        next(item for item in data["sources"] if item["path"] == bad_role)["role"] = "input_evidence"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("router source inventory" in error for error in run_guard(root, policy))


def test_rejects_router_source_inventory_hash_drift(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/source-inventory.yaml"
    data = yaml.safe_load(path.read_text())
    data["sources"][0]["sha256"] = "0" * 64
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("router source inventory hash mismatch" in error for error in run_guard(root, policy))
