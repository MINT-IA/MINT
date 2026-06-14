from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "verify_phase_acceptance.py"


def _run(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        capture_output=True,
        text=True,
    )


def _write_fixture(root: Path, verify_block: str) -> None:
    phase_dir = root / ".planning/phases/mint-test-phase"
    phase_dir.mkdir(parents=True)
    manifest = {
        "schema_version": 2,
        "active_milestone": "mint-test-phase",
        "active_phase_dir": ".planning/phases/mint-test-phase",
        "active_phase_context": ".planning/phases/mint-test-phase/CONTEXT.md",
        "active_spec": ".planning/phases/mint-test-phase/SPEC.md",
        "next_product_phase_context": ".planning/phases/mint-next/CONTEXT.md",
        "allowed_branches": [],
        "base_ref": "origin/dev",
        "required_phase_files": ["CONTEXT.md", "SPEC.md"],
        "forbidden_active_paths": [],
        "agent_routes": {},
        "memory_policy": {"engram_project": "mint"},
        "historical_not_active": [],
        "quarantine_paths": [],
    }
    (root / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )
    (phase_dir / "CONTEXT.md").write_text("# Context\n", encoding="utf-8")
    (phase_dir / "SPEC.md").write_text(
        f"# Spec\n\n```verify\n{verify_block}\n```\n",
        encoding="utf-8",
    )


def test_all_deterministic_criteria_pass(tmp_path: Path) -> None:
    _write_fixture(
        tmp_path,
        "\n".join(
            [
                "# tier: deterministic",
                "first: true",
                "second: true",
            ]
        ),
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "first" in proc.stdout
    assert "PASS" in proc.stdout


def test_failing_deterministic_criterion_sets_exit_code(tmp_path: Path) -> None:
    _write_fixture(
        tmp_path,
        "\n".join(
            [
                "# tier: deterministic",
                "first: true",
                "broken: false",
            ]
        ),
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "broken" in proc.stdout
    assert "FAIL" in proc.stdout


def test_device_tier_does_not_control_default_exit_code(tmp_path: Path) -> None:
    _write_fixture(
        tmp_path,
        "\n".join(
            [
                "# tier: deterministic",
                "first: true",
                "# tier: device",
                "simulator: false",
            ]
        ),
    )

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "simulator" not in proc.stdout


def test_device_tier_is_reported_with_device_flag(tmp_path: Path) -> None:
    _write_fixture(
        tmp_path,
        "\n".join(
            [
                "# tier: deterministic",
                "first: true",
                "# tier: device",
                "simulator: false",
            ]
        ),
    )

    proc = _run(tmp_path, "--device")

    assert proc.returncode == 0
    assert "simulator" in proc.stdout
    assert "DEVICE-FAIL" in proc.stdout

