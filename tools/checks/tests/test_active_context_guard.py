from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "active_context_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> None:
    (root / ".planning").mkdir(parents=True)
    (root / ".planning/phases/mint-foundation-cleanup-20260614").mkdir(
        parents=True
    )
    (
        root
        / ".planning/phases/mint-2-0-first-experience-rente-capital"
    ).mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "tools/checks").mkdir(parents=True)

    manifest = {
        "schema_version": 2,
        "active_milestone": "mint-foundation-cleanup-20260614",
        "active_phase_dir": ".planning/phases/mint-foundation-cleanup-20260614",
        "active_phase_context": ".planning/phases/mint-foundation-cleanup-20260614/CONTEXT.md",
        "active_spec": ".planning/phases/mint-foundation-cleanup-20260614/SPEC.md",
        "next_product_phase_context": ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md",
        "allowed_branches": ["dev", "codex/mint-foundation-cleanup-20260614"],
        "allowed_branch_patterns": [],
        "base_ref": "origin/dev",
        "required_phase_files": [
            "CONTEXT.md",
            "SPEC.md",
            "PLAN.md",
            "VERIFICATION.md",
        ],
        "forbidden_active_paths": ["/Users/julienbattaglia/Desktop/MINT.nosync"],
        "agent_routes": {"environment": {"agents": ["context-manager"]}},
        "memory_policy": {"engram_project": "mint", "repo_wins_over_memory": True},
        "phase_acceptance_verifier": "tools/checks/verify_phase_acceptance.py",
        "historical_not_active": [
            "mint-prod-ready-core-journey-truth-20260601",
            "mint-illogism-fixes",
        ],
        "quarantine_paths": ["/Users/julienbattaglia/Desktop/MINT.nosync"],
    }
    (root / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )
    (root / ".planning/ACTIVE_CONTEXT.md").write_text(
        "# Active Context\n\nmint-foundation-cleanup-20260614\n",
        encoding="utf-8",
    )
    (root / ".planning/STATE.md").write_text(
        "\n".join(
            [
                "---",
                "milestone: mint-foundation-cleanup-20260614",
                "---",
                "Active operating map:",
                ".planning/phases/mint-foundation-cleanup-20260614/CONTEXT.md",
                ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md",
                "## Historical Receipts",
                "mint-prod-ready-core-journey-truth-20260601",
            ]
        ),
        encoding="utf-8",
    )
    (root / ".planning/ROADMAP.md").write_text(
        "\n".join(
            [
                "# Roadmap",
                "## Active Pointer",
                ".planning/phases/mint-foundation-cleanup-20260614/CONTEXT.md",
                ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md",
                "## Milestones",
                "Historical GSD: Core Journey Truth / Prod Ready",
            ]
        ),
        encoding="utf-8",
    )
    (root / ".planning/INDEX.md").write_text(
        "\n".join(
            [
                "# `.planning/` INDEX",
                "## Active Context",
                "ACTIVE_CONTEXT.md",
                "phases/mint-foundation-cleanup-20260614/CONTEXT.md",
                "phases/mint-foundation-cleanup-20260614/SPEC.md",
                "phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md",
            ]
        ),
        encoding="utf-8",
    )
    (root / "AGENTS.md").write_text(
        "Read `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.",
        encoding="utf-8",
    )
    (root / "docs/MINT_AGENT_WORKFLOW.md").write_text(
        "Current session router: `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.",
        encoding="utf-8",
    )
    (root / "tools/checks/verify_phase_acceptance.py").write_text(
        "#!/usr/bin/env python3\n",
        encoding="utf-8",
    )
    (root / ".planning/phases/mint-foundation-cleanup-20260614/CONTEXT.md").write_text(
        "# Foundation\n",
        encoding="utf-8",
    )
    (root / ".planning/phases/mint-foundation-cleanup-20260614/SPEC.md").write_text(
        "# Foundation Spec\n",
        encoding="utf-8",
    )
    (root / ".planning/phases/mint-foundation-cleanup-20260614/PLAN.md").write_text(
        "# Foundation Plan\n",
        encoding="utf-8",
    )
    (
        root / ".planning/phases/mint-foundation-cleanup-20260614/VERIFICATION.md"
    ).write_text("# Foundation Verification\n", encoding="utf-8")
    (
        root
        / ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md"
    ).write_text("# Mint 2.0\n", encoding="utf-8")


def test_guard_passes_for_consistent_active_context(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK active_context_guard" in proc.stderr


def test_guard_fails_when_state_milestone_drifted(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / ".planning/STATE.md").write_text(
        "---\nmilestone: mint-illogism-fixes\n---\n",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "STATE milestone" in proc.stderr


def test_guard_fails_when_historical_phase_is_active(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    manifest = json.loads(
        (tmp_path / ".planning/ACTIVE_CONTEXT.json").read_text(encoding="utf-8")
    )
    manifest["active_milestone"] = "mint-prod-ready-core-journey-truth-20260601"
    (tmp_path / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "historical_not_active" in proc.stderr


def test_guard_fails_when_agents_skip_router(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / "AGENTS.md").write_text(
        "Read CLAUDE.md only.",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "AGENTS.md" in proc.stderr


def test_guard_fails_when_index_skips_active_context(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    (tmp_path / ".planning/INDEX.md").write_text(
        "# `.planning/` INDEX\n\nOld pages only.",
        encoding="utf-8",
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "INDEX.md" in proc.stderr


def test_guard_fails_when_local_branch_is_not_allowed(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    subprocess.run(
        ["git", "checkout", "-b", "codex/unrelated"],
        cwd=tmp_path,
        check=True,
        capture_output=True,
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "not in allowed_branches" in proc.stderr


def test_guard_allows_local_branch_pattern(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    manifest = json.loads(
        (tmp_path / ".planning/ACTIVE_CONTEXT.json").read_text(encoding="utf-8")
    )
    manifest["allowed_branch_patterns"] = ["codex/journey-os-*"]
    (tmp_path / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    subprocess.run(
        ["git", "checkout", "-b", "codex/journey-os-system-closeout-20260627"],
        cwd=tmp_path,
        check=True,
        capture_output=True,
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK active_context_guard" in proc.stderr


def test_guard_reports_patterns_when_local_branch_matches_none(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    manifest = json.loads(
        (tmp_path / ".planning/ACTIVE_CONTEXT.json").read_text(encoding="utf-8")
    )
    manifest["allowed_branch_patterns"] = ["codex/journey-os-*"]
    (tmp_path / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    subprocess.run(
        ["git", "checkout", "-b", "codex/unrelated"],
        cwd=tmp_path,
        check=True,
        capture_output=True,
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "not in allowed_branches" in proc.stderr
    assert "patterns: codex/journey-os-*" in proc.stderr


def test_guard_allows_integration_branch_inside_ci(
    tmp_path: Path, monkeypatch
) -> None:
    _write_valid_fixture(tmp_path)
    subprocess.run(["git", "init"], cwd=tmp_path, check=True, capture_output=True)
    subprocess.run(
        ["git", "checkout", "-b", "dev"],
        cwd=tmp_path,
        check=True,
        capture_output=True,
    )
    monkeypatch.setenv("GITHUB_ACTIONS", "true")

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK active_context_guard" in proc.stderr
