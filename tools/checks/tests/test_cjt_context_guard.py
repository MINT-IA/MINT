from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "cjt_context_guard.py"
PHASE = "mint-prod-ready-core-journey-truth-20260601"
PHASE_DIR = Path(".planning/phases") / PHASE
RUNTIME_REPORTS = (
    PHASE_DIR
    / "evidence/coach-navigation/row-16-coach-route-to-screen-runtime-proof-20260604.md",
    PHASE_DIR
    / "evidence/simulator-design/row-17-rente-vs-capital-runtime-visual-proof-20260604.md",
    PHASE_DIR
    / "evidence/coach-navigation/row-20-coach-history-resume-runtime-proof-20260604.md",
    PHASE_DIR
    / "evidence/daily-return/row-21-daily-return-attention-action-proof-20260604.md",
    PHASE_DIR / "evidence/rapport-design/row-23-primary-screen-visual-audit-20260604.md",
)
VALID_GUIDANCE_REVIEW = "\n".join(
    [
        "## Runtime Guidance Quality Review",
        "- mechanical proof",
        "- user-visible outcome",
        "- guidance quality",
        "- non-absurd",
        "- inclusive",
        "- financial trust",
        "- remaining qualitative gaps",
    ]
)


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
        "\n".join(
            [
                "LIVE-PROVEN PARTIAL UNPROVEN OPEN CJT-013 CJT-015",
                "| 1 | Install | PARTIAL | CJT-015 mint-ai.ch | open |",
            ]
        ),
        encoding="utf-8",
    )
    (phase_dir / "BUG-TRACKER.md").write_text(
        "\n".join(
            [
                "| CJT-013 | P0 | x | y | z | open | yes | a | b |",
                "| CJT-015 | P0 | x | y | z | open | yes | a | mint-ai.ch |",
            ]
        ),
        encoding="utf-8",
    )
    (phase_dir / "CJT-OPS-00-CONTEXT-GUARD.md").write_text(
        "\n".join(
            [
                "# CJT-OPS-00",
                "## Session Handoff Checklist",
                "- MEMORY.md read",
                "- CLAUDE.md read",
                "- AGENTS.md read",
                "- JOURNEY-TRUTH-MATRIX.md read",
                "- BUG-TRACKER.md read",
                "- open gates named",
                "- newest commit audited",
                "## No-New-Debt Commit Review",
                "- introduced",
                "- revealed",
                "- accepted",
                "- removed",
                "- owner",
                "- next proof",
                "## Runtime Guidance Quality Review",
                "- mechanical proof",
                "- user-visible outcome",
                "- guidance quality",
                "- non-absurd",
                "- inclusive",
                "- financial trust",
                "- remaining qualitative gaps",
            ]
        ),
        encoding="utf-8",
    )
    for report in RUNTIME_REPORTS:
        report_path = root / report
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            f"# Runtime report\n\n{VALID_GUIDANCE_REVIEW}\n",
            encoding="utf-8",
        )


def test_guard_passes_for_coherent_cjt_context(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK cjt_context_guard" in proc.stderr


def test_guard_skips_when_cjt_is_historical(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / ".planning/STATE.md").write_text(
        "\n".join(
            [
                "---",
                "gsd_state_version: 1.0",
                "milestone: mint-foundation-cleanup-20260614",
                "status: executing",
                "---",
                "# GSD State: MINT Foundation Cleanup",
                "Current focus: Phase mint-foundation-cleanup-20260614.",
            ]
        ),
        encoding="utf-8",
    )
    (tmp_path / ".planning/ROADMAP.md").write_text(
        "\n".join(
            [
                "# Roadmap",
                "## Active Pointer",
                "Current operating phase is foundation cleanup.",
                "Historical GSD: Core Journey Truth / Prod Ready",
                "JOURNEY-TRUTH-MATRIX.md",
                "BUG-TRACKER.md",
            ]
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "skipped" in proc.stderr


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
            ]
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "CJT-013" in proc.stderr


def test_guard_fails_when_cjt015_uses_stale_domain(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / PHASE_DIR / "JOURNEY-TRUTH-MATRIX.md").write_text(
        "\n".join(
            [
                "LIVE-PROVEN PARTIAL UNPROVEN OPEN CJT-013 CJT-015",
                "| 1 | Install | PARTIAL | CJT-015 mint.ch | open |",
            ]
        ),
        encoding="utf-8",
    )
    (tmp_path / PHASE_DIR / "BUG-TRACKER.md").write_text(
        "\n".join(
            [
                "| CJT-013 | P0 | x | y | z | open | yes | a | b |",
                "| CJT-015 | P0 | x | y | z | open | yes | a | mint.ch |",
            ]
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "mint-ai.ch" in proc.stderr


def test_guard_fails_without_session_handoff_checklist(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / PHASE_DIR / "CJT-OPS-00-CONTEXT-GUARD.md").write_text(
        "# CJT-OPS-00\nNo checklist here.",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "Session Handoff Checklist" in proc.stderr


def test_guard_fails_without_no_new_debt_commit_review(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / PHASE_DIR / "CJT-OPS-00-CONTEXT-GUARD.md").write_text(
        "\n".join(
            [
                "# CJT-OPS-00",
                "## Session Handoff Checklist",
                "- MEMORY.md read",
                "- CLAUDE.md read",
                "- AGENTS.md read",
                "- JOURNEY-TRUTH-MATRIX.md read",
                "- BUG-TRACKER.md read",
                "- open gates named",
                "- newest commit audited",
            ]
        ),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "No-New-Debt Commit Review" in proc.stderr


def test_guard_fails_without_runtime_guidance_quality_review(
    tmp_path: Path,
) -> None:
    _write_valid_fixture(tmp_path)
    text = (tmp_path / PHASE_DIR / "CJT-OPS-00-CONTEXT-GUARD.md").read_text(
        encoding="utf-8",
    )
    text = text.split("## Runtime Guidance Quality Review", maxsplit=1)[0]
    (tmp_path / PHASE_DIR / "CJT-OPS-00-CONTEXT-GUARD.md").write_text(
        text,
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "Runtime Guidance Quality Review" in proc.stderr


def test_guard_fails_when_runtime_report_lacks_guidance_review(
    tmp_path: Path,
) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / RUNTIME_REPORTS[0]).write_text(
        "# Runtime report\n\nJUnit green only.",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "row-16-coach-route-to-screen-runtime-proof" in proc.stderr
    assert "Runtime Guidance Quality Review" in proc.stderr
