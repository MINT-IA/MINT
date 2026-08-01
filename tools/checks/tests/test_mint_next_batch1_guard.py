from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint_next_batch1_guard.py"
ROOT = Path("product/mint_next/batch1")


def _copy(tmp_path: Path) -> None:
    shutil.copytree(REPO_ROOT / ROOT, tmp_path / ROOT)


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_guard_passes_current_batch1_contract() -> None:
    proc = _run(REPO_ROOT)
    assert proc.returncode == 0, proc.stderr


def test_guard_rejects_cosmetic_direction_duplicates(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "directions.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "mechanism: event_decision_first", "mechanism: calculator_first"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "mechanism" in proc.stderr


def test_guard_rejects_user_validation_claim(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "evaluation.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "user_testing_completed: false", "user_testing_completed: true"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "user testing" in proc.stderr


def test_guard_rejects_discord_as_source_of_truth(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "coordination.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "source_of_truth: false", "source_of_truth: true"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "Discord" in proc.stderr


def test_guard_rejects_account_before_first_value(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "first-value.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "account_required: false", "account_required: true"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "account" in proc.stderr


def test_guard_rejects_incomplete_prototype(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "prototype/index.html"
    path.write_text(path.read_text(encoding="utf-8").replace("()=>`", "REMOVED", 1), encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "18 prototype states" in proc.stderr


def test_guard_rejects_stale_render_evidence(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "evidence/direction-a-result.png"
    path.write_bytes(path.read_bytes() + b"stale")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "render evidence hash mismatch" in proc.stderr
