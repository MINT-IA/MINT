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


def test_guard_rejects_false_deterministic_result_semantics(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "directions.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "structured_required_inputs_card", "deterministic_card"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "deterministic tax result" in proc.stderr


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


def test_guard_rejects_empty_governing_source_matrix(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "source-matrix.yaml"
    text = path.read_text(encoding="utf-8")
    start, rest = text.split("governing:\n", 1)
    _, tail = rest.split("inspiration_only:\n", 1)
    path.write_text(start + "governing: []\ninspiration_only:\n" + tail, encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "governing source" in proc.stderr


def test_guard_rejects_empty_evaluation_tasks(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "evaluation.yaml"
    text = path.read_text(encoding="utf-8")
    start, rest = text.split("moderated_tasks:\n", 1)
    _, tail = rest.split("participant_coverage:\n", 1)
    path.write_text(start + "moderated_tasks: []\nparticipant_coverage:\n" + tail, encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "moderated tasks" in proc.stderr


def test_guard_rejects_empty_discord_channels(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "coordination.yaml"
    text = path.read_text(encoding="utf-8")
    start, rest = text.split("  channels:\n", 1)
    _, tail = rest.split("  allowed_fields:", 1)
    path.write_text(start + "  channels: {}\n  allowed_fields:" + tail, encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "Discord channels" in proc.stderr


def test_guard_rejects_unsubstantiated_coordination_selection(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "coordination-evidence.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace(
            "selected: discord_notification_only", "selected: slack_free"
        ),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "coordination evidence" in proc.stderr


def test_guard_rejects_non_reproducible_coordination_total(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "coordination-evidence.yaml"
    path.write_text(
        path.read_text(encoding="utf-8").replace("score_100: 81", "score_100: 99"),
        encoding="utf-8",
    )
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "total is not reproducible" in proc.stderr


def test_guard_rejects_root_level_inventory_boilerplate(tmp_path: Path) -> None:
    _copy(tmp_path)
    path = tmp_path / ROOT / "handoff-inventory.yaml"
    text = path.read_text(encoding="utf-8")
    for decision in ("REWRITE", "RETIRE_FROM_PROMPTS", "RETAIN_AS_HISTORY"):
        text = text.replace(f"decision: {decision}", "decision: ADAPT")
    path.write_text(text, encoding="utf-8")
    proc = _run(tmp_path)
    assert proc.returncode == 1
    assert "file-specific" in proc.stderr
