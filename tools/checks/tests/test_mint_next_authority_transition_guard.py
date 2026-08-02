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
    AUTHORITY_MARKER,
    TransitionPolicy,
    run_guard,
)


OLD = "mint-2-0-first-experience-rente-capital"
NEW = "mint-next-architecture-authority-20260802"
NEW_DIR = f".planning/phases/{NEW}"
OLD_DIR = f".planning/phases/{OLD}"


def _write(root: Path, relative: str, content: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


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
        _write(root, path, f"{marker}\nGovernance-only authority; no successor product phase queued.\n")
    _write(root, f"{NEW_DIR}/CONTEXT.md", "governance-only transition\n")
    _write(root, f"{NEW_DIR}/SPEC.md", "governance-only spec\n")
    _write(
        root,
        "product/mint_next/batch4/batch.yaml",
        yaml.safe_dump({"schema_version": 1, "status": "draft_unproven", "promotion_receipt": None}),
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
                        },
                    }
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
    assert any("retirement-first conflict is not resolved" in error for error in run_guard(root, policy))


def test_draft_requires_null_receipt(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    path = root / "product/mint_next/batch4/batch.yaml"
    data = yaml.safe_load(path.read_text())
    data["promotion_receipt"] = "product/mint_next/batch4/evidence/promotion.yaml"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert any("draft batch must not claim a promotion receipt" in error for error in run_guard(root, policy))


def test_future_promotion_receipt_is_fail_closed(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    batch_path = root / "product/mint_next/batch4/batch.yaml"
    batch = yaml.safe_load(batch_path.read_text())
    batch["status"] = "promoted_architecture"
    batch["promotion_receipt"] = "product/mint_next/batch4/evidence/promotion.yaml"
    batch_path.write_text(yaml.safe_dump(batch), encoding="utf-8")
    _write(
        root,
        "product/mint_next/batch4/evidence/promotion.yaml",
        yaml.safe_dump(
            {
                "audited_architecture_head": "f" * 40,
                "authority_transition_head": "e" * 40,
                "registry_manifest": "product/mint_next/batch4/evidence/registry-manifest.yaml",
                "roasts": [],
                "allowed_post_audit_changes": [],
            }
        ),
    )
    errors = run_guard(root, policy)
    assert any("does not resolve to a git object" in error for error in errors)
    assert any("promotion receipt roasts must be non-empty" in error for error in errors)
    assert any("registry manifest does not exist" in error for error in errors)


def test_rejects_untracked_file_in_protected_surface(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, "apps/mobile/lib/surprise.dart", "oops\n")
    errors = run_guard(root, policy)
    assert any("product/runtime path changed" in error and "surprise.dart" in error for error in errors)


def test_rejects_unmanifested_file_in_legacy_vertical(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    _write(root, f"{OLD_DIR}/invented-receipt.md", "not audited\n")
    errors = run_guard(root, policy)
    assert any("unexpected file" in error and "invented-receipt.md" in error for error in errors)


def test_valid_future_promotion_receipt_passes(tmp_path: Path) -> None:
    root, policy = _fixture(tmp_path)
    batch_path = root / "product/mint_next/batch4/batch.yaml"
    batch = yaml.safe_load(batch_path.read_text())
    batch["status"] = "promoted_architecture"
    batch["promotion_receipt"] = "product/mint_next/batch4/evidence/promotion.yaml"
    batch_path.write_text(yaml.safe_dump(batch), encoding="utf-8")
    batch_digest = hashlib.sha256(batch_path.read_bytes()).hexdigest()
    manifest_path = "product/mint_next/batch4/evidence/registry-manifest.yaml"
    _write(
        root,
        manifest_path,
        yaml.safe_dump({"files": {"product/mint_next/batch4/batch.yaml": batch_digest}}),
    )
    roast_evidence = "product/mint_next/batch4/evidence/roast.md"
    _write(root, roast_evidence, "independent review\n")
    receipt_path = "product/mint_next/batch4/evidence/promotion.yaml"
    changed = {
        line
        for line in (
            _git(root, "diff", "--name-only", policy.baseline_ref, "--")
            + "\n"
            + _git(root, "ls-files", "--others", "--exclude-standard")
        ).splitlines()
        if line
    }
    changed.add(receipt_path)
    _write(
        root,
        receipt_path,
        yaml.safe_dump(
            {
                "audited_architecture_head": policy.baseline_ref,
                "authority_transition_head": policy.baseline_ref,
                "registry_manifest": manifest_path,
                "roasts": [
                    {
                        "reviewer": "independent-roaster",
                        "verdict": "ROAST_PASS",
                        "audited_head": policy.baseline_ref,
                        "evidence": roast_evidence,
                    }
                ],
                "allowed_post_audit_changes": sorted(changed),
            }
        ),
    )
    assert run_guard(root, policy) == []
