from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint_next_foundation_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_guard_passes_for_repository_contract() -> None:
    proc = _run(REPO_ROOT)

    assert proc.returncode == 0, proc.stderr
    assert "OK mint_next_foundation_guard" in proc.stderr


def test_guard_rejects_self_report_as_completion_evidence(tmp_path: Path) -> None:
    contract = tmp_path / "product/mint_next/foundation.yaml"
    contract.parent.mkdir(parents=True)
    contract.write_text(
        "schema_version: 1\ncompletion_evidence:\n  allowed: [agent_summary]\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "agent_summary" in proc.stderr


def test_guard_rejects_unowned_required_capability(tmp_path: Path) -> None:
    contract = tmp_path / "product/mint_next/foundation.yaml"
    contract.parent.mkdir(parents=True)
    contract.write_text(
        "schema_version: 1\nrequired_capabilities:\n  experience: null\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "experience" in proc.stderr


def _copy_contract(tmp_path: Path) -> Path:
    target = tmp_path / "product/mint_next/foundation.yaml"
    target.parent.mkdir(parents=True)
    target.write_text(
        (REPO_ROOT / "product/mint_next/foundation.yaml").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    for rel in (
        "product/mint_next/runbooks/engram-fun2.md",
        "product/mint_next/evidence/engram-fun2-20260801.yaml",
        "product/mint_next/evidence/bead-MINT_nosync-9kv.yaml",
    ):
        source = REPO_ROOT / rel
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    for rel in (
        ".claude/agents/mint-lead.md",
        ".claude/agents/mint-experience.md",
        ".claude/agents/mint-mobile.md",
        ".claude/agents/mint-backend.md",
        ".claude/agents/mint-swiss-brain.md",
        ".claude/agents/mint-quality-gate.md",
        ".claude/agents/mint-integrations-security.md",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("agent", encoding="utf-8")
    for rel in (
        ".agents/skills/mint-operating-gates/SKILL.md",
        ".agents/skills/mint-flutter-dev/SKILL.md",
        ".agents/skills/mint-backend-dev/SKILL.md",
        ".agents/skills/mint-swiss-compliance/SKILL.md",
        ".agents/skills/mint-journey-design/SKILL.md",
        ".agents/skills/mint-runtime-walkthrough/SKILL.md",
        ".agents/skills/mint-financial-calculation-contract/SKILL.md",
        ".agents/skills/mint-consent-and-provenance/SKILL.md",
        ".agents/skills/mint-experience-critique/SKILL.md",
        ".agents/skills/mint-regulatory-boundary/SKILL.md",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("skill", encoding="utf-8")
    return target


def test_guard_rejects_premature_complete_status(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("status: draft_unproven", "status: complete"),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "status" in proc.stderr


def test_guard_rejects_missing_cutover_gate(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("    - rollback_proof\n", ""),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "rollback_proof" in proc.stderr


def test_guard_rejects_missing_never_sufficient_evidence(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    contract.write_text(
        contract.read_text(encoding="utf-8").replace("    - author_claim\n", ""),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "author_claim" in proc.stderr


def test_guard_rejects_nonexistent_agent(tmp_path: Path) -> None:
    contract = _copy_contract(tmp_path)
    (tmp_path / ".claude/agents/mint-experience.md").unlink()
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "mint-experience" in proc.stderr


def test_guard_rejects_missing_engram_receipt(tmp_path: Path) -> None:
    _copy_contract(tmp_path)
    (tmp_path / "product/mint_next/evidence/engram-fun2-20260801.yaml").unlink()
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "latest_evidence" in proc.stderr
