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
