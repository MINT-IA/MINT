from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "phase_contract_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> Path:
    phase_dir = root / ".planning/phases/mint-karpathy-rules-infra-20260614"
    phase_dir.mkdir(parents=True)
    (root / ".planning").mkdir(exist_ok=True)
    manifest = {
        "schema_version": 1,
        "active_milestone": "mint-karpathy-rules-infra-20260614",
        "active_phase_context": ".planning/phases/mint-karpathy-rules-infra-20260614/CONTEXT.md",
        "next_product_phase_context": ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md",
        "historical_not_active": [],
        "quarantine_paths": [],
    }
    (root / ".planning/ACTIVE_CONTEXT.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )
    for name in ("CONTEXT.md", "SPEC.md", "PLAN.md", "VERIFICATION.md"):
        (phase_dir / name).write_text(f"# {name}\n", encoding="utf-8")
    return phase_dir


def test_guard_passes_when_active_phase_has_required_contract_files(
    tmp_path: Path,
) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK phase_contract_guard" in proc.stderr


def test_guard_fails_when_active_phase_missing_spec(tmp_path: Path) -> None:
    phase_dir = _write_valid_fixture(tmp_path)
    (phase_dir / "SPEC.md").unlink()

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "SPEC.md" in proc.stderr


def test_guard_fails_when_manifest_context_path_is_missing(tmp_path: Path) -> None:
    phase_dir = _write_valid_fixture(tmp_path)
    (phase_dir / "CONTEXT.md").unlink()

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "active_phase_context" in proc.stderr

