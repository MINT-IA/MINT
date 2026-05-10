"""Unit tests for tools/checks/g6_path_check.py — CALC-04 / CONTEXT 92.5 D-18."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/g6_path_check.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
    )


def test_financial_core_path_triggers() -> None:
    proc = _run(
        "--files",
        "apps/mobile/lib/services/financial_core/avs_calculator.dart",
    )
    assert proc.returncode == 0
    assert "applies" in proc.stderr


def test_backend_services_path_triggers() -> None:
    proc = _run(
        "--files",
        "services/backend/app/services/arbitrage/rente_vs_capital.py",
    )
    assert proc.returncode == 0
    assert "applies" in proc.stderr


def test_social_insurance_path_triggers() -> None:
    proc = _run(
        "--files",
        "services/backend/app/constants/social_insurance.py",
    )
    assert proc.returncode == 0


def test_unrelated_path_does_not_trigger() -> None:
    proc = _run("--files", "apps/mobile/lib/screens/landing_screen.dart")
    assert proc.returncode == 1
    assert "does not apply" in proc.stderr


def test_other_constants_do_not_trigger() -> None:
    """D-18 lists `social_insurance.py` ONLY ; sibling constants files do NOT trigger."""
    proc = _run("--files", "services/backend/app/constants/__init__.py")
    assert proc.returncode == 1


def test_mixed_files_trigger_when_any_matches() -> None:
    proc = _run(
        "--files",
        "apps/mobile/lib/screens/landing_screen.dart",
        "apps/mobile/lib/services/financial_core/lpp_calculator.dart",
    )
    assert proc.returncode == 0


def test_quiet_suppresses_stderr() -> None:
    proc = _run(
        "--files",
        "apps/mobile/lib/screens/landing_screen.dart",
        "--quiet",
    )
    assert proc.returncode == 1
    assert proc.stderr.strip() == ""
