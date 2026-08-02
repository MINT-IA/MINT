from __future__ import annotations

import hashlib
import json
import subprocess
import sys
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
        f"accepted_transition_head: {AUDITED_TRANSITION_HEAD}\n---\n"
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
        f"Audited transition head: `{AUDITED_TRANSITION_HEAD}`\n"
        "Accepted scope: `governance_authority_only`\n"
        "Batch 4 promotion: **false**\n",
    )
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
                        "status": "resolved",
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
                                "audited_head": AUDITED_TRANSITION_HEAD,
                                "accepted_scope": "governance_authority_only",
                                "batch4_promotion": False,
                                "successor_product_phase_queued": False,
                                "roasts": [
                                    {
                                        "name": name,
                                        "reviewer": reviewer,
                                        "verdict": "PASS",
                                        "p1": 0,
                                        "p2": 0,
                                        "audited_head": AUDITED_TRANSITION_HEAD,
                                        "evidence_id": evidence_id,
                                    }
                                    for name, reviewer, evidence_id in (
                                        (
                                            "authority_coherence",
                                            "authority_roast_coherence",
                                            "roast:authority-coherence:b88a42557",
                                        ),
                                        (
                                            "legacy_evidence_preservation",
                                            "authority_roast_preservation",
                                            "roast:legacy-preservation:b88a42557",
                                        ),
                                        (
                                            "guard_hostile_mutation_quality",
                                            "authority_roast_guard",
                                            "roast:guard-hostile-mutations:b88a42557",
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
    policy = TransitionPolicy(baseline_ref=baseline, legacy_manifest=manifest)
    return root, policy


def test_valid_governance_only_transition_passes(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    assert run_guard(root, policy) == []


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
    assert any("expected 'resolved'" in error for error in run_guard(root, policy))


def test_rejects_pending_conflict_after_acceptance(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    data = yaml.safe_load(path.read_text())
    data["conflicts"][0]["status"] = "resolution_applied_pending_verification"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("expected 'resolved'" in error for error in run_guard(root, policy))


@pytest.mark.parametrize(
    ("mutation", "needle"),
    [
        ("wrong_head", "audited_head"),
        ("missing_roast", "exactly the three named"),
        ("failed_roast", "verdict must be PASS"),
        ("nonzero_p1", "p1=0 and p2=0"),
        ("missing_evidence", "evidence_id mismatch"),
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
        verification["roasts"].pop()
    elif mutation == "failed_roast":
        verification["roasts"][0]["verdict"] = "FAIL"
    elif mutation == "nonzero_p1":
        verification["roasts"][0]["p1"] = 1
    elif mutation == "missing_evidence":
        verification["roasts"][0]["evidence_id"] = ""
    elif mutation == "wrong_roast_head":
        verification["roasts"][0]["audited_head"] = "0" * 40
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any(needle in error for error in run_guard(root, policy))


@pytest.mark.parametrize(
    ("relative", "old", "new", "needle"),
    [
        (
            f"{NEW_DIR}/VERIFICATION.md",
            f"Audited transition head: `{AUDITED_TRANSITION_HEAD}`",
            "Audited transition head: `0000000000000000000000000000000000000000`",
            "accepted phase VERIFICATION missing exact receipt",
        ),
        (
            ".planning/STATE.md",
            "status: governance-authority-accepted",
            "status: governance-only-authority-transition",
            "STATE must record status",
        ),
    ],
)
def test_rejects_fake_accepted_phase_or_state(
    tmp_path: Path, relative: str, old: str, new: str, needle: str
) -> None:
    root, policy = _fixture(tmp_path)
    path = root / relative
    path.write_text(path.read_text().replace(old, new), encoding="utf-8")
    errors = run_guard(root, policy)
    assert any(needle in error for error in errors)


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
