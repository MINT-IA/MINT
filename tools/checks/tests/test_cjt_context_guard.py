from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "cjt_context_guard.py"
PHASE = "mint-prod-ready-core-journey-truth-20260601"
PHASE_DIR = Path(".planning/phases") / PHASE


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> None:
    phase_dir = root / PHASE_DIR
    phase_dir.mkdir(parents=True)
    (root / ".planning").mkdir(exist_ok=True)
    (root / ".planning/STATE.md").write_text(
        "\n".join(
            [
                "# GSD State",
                "Current focus: Core Journey Truth",
                PHASE,
                "JOURNEY-TRUTH-MATRIX.md",
                "BUG-TRACKER.md",
            ]
        ),
        encoding="utf-8",
    )
    (root / ".planning/ROADMAP.md").write_text(
        "\n".join(
            [
                "# Roadmap",
                "Active GSD: Core Journey Truth / Prod Ready",
                "JOURNEY-TRUTH-MATRIX.md",
                "BUG-TRACKER.md",
            ]
        ),
        encoding="utf-8",
    )
    (phase_dir / "JOURNEY-TRUTH-MATRIX.md").write_text(
        "LIVE-PROVEN PARTIAL UNPROVEN OPEN CJT-013 CJT-015 CJT-018",
        encoding="utf-8",
    )
    (phase_dir / "BUG-TRACKER.md").write_text(
        "\n".join(
            [
                "| CJT-013 | P0 | x | y | z | open | yes | a | b |",
                "| CJT-015 | P0 | x | y | z | open | yes | a | b |",
                "| CJT-018 | P1 | x | y | z | open | no | a | b |",
            ]
        ),
        encoding="utf-8",
    )


def test_guard_passes_for_coherent_cjt_context(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK cjt_context_guard" in proc.stderr


def test_guard_fails_when_state_points_elsewhere(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / ".planning/STATE.md").write_text(
        "Current focus: Phase 01.5",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "STATE.md does not point" in proc.stderr


def test_guard_fails_when_known_gate_is_not_open(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / PHASE_DIR / "BUG-TRACKER.md").write_text(
        "\n".join(
            [
                "| CJT-013 | P0 | x | y | z | verified | no | a | b |",
                "| CJT-015 | P0 | x | y | z | open | yes | a | b |",
                "| CJT-018 | P1 | x | y | z | open | no | a | b |",
            ]
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "CJT-013" in proc.stderr
