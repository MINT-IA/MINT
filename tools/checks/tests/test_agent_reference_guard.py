from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "agent_reference_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_guard_passes_for_repo_relative_agent_references(tmp_path: Path) -> None:
    agent_dir = tmp_path / ".claude/agents"
    command_dir = tmp_path / ".claude/commands/gsd"
    agent_dir.mkdir(parents=True)
    command_dir.mkdir(parents=True)
    (agent_dir / "gsd-verifier.md").write_text(
        "@./.claude/get-shit-done/references/mandatory-initial-read.md\n",
        encoding="utf-8",
    )
    (command_dir / "verify-work.md").write_text(
        "@./.claude/get-shit-done/workflows/verify-work.md\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK agent_reference_guard" in proc.stderr


def test_guard_fails_for_quarantined_worktree_reference(tmp_path: Path) -> None:
    agent_dir = tmp_path / ".claude/agents"
    agent_dir.mkdir(parents=True)
    (agent_dir / "gsd-verifier.md").write_text(
        "@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/references/mandatory-initial-read.md\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "MINT.nosync" in proc.stderr


def test_guard_fails_for_transitive_get_shit_done_reference(tmp_path: Path) -> None:
    workflow_dir = tmp_path / ".claude/get-shit-done/workflows"
    workflow_dir.mkdir(parents=True)
    (workflow_dir / "plan-phase.md").write_text(
        'node "/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/bin/gsd-tools.cjs"\n',
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert ".claude/get-shit-done/workflows/plan-phase.md" in proc.stderr
