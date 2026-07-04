"""Tests for `tools/checks/s23_class_name_lint.py` (D-09 iter-2 B4).

NOTE : `test_self_test_passes` only passes AFTER Task 3 renames the S23
`class FrontalierService:` → `class FrontalierSegmentService:`. Until then,
the existing tree has 1 declaration outside the allowlist.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_LINT = _REPO_ROOT / "tools" / "checks" / "s23_class_name_lint.py"
_BAD_FIXTURE = (
    _REPO_ROOT
    / "services"
    / "backend"
    / "tests"
    / "fixtures"
    / "bad_s23_redeclaration.py"
)
_S12_FACADE = (
    _REPO_ROOT / "services" / "backend" / "app" / "services" / "frontalier_service.py"
)


def _run(args: list[str]) -> tuple[int, str, str]:
    result = subprocess.run(
        [sys.executable, str(_LINT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.returncode, result.stdout, result.stderr


def test_exit_1_on_bad_fixture_via_temp_copy(tmp_path: Path):
    """Bad fixture is self-exempted ; use a temp copy to assert lint flags it."""
    bad_text = _BAD_FIXTURE.read_text()
    tmp = tmp_path / "redeclare.py"
    tmp.write_text(bad_text)
    code, _out, err = _run([str(tmp)])
    assert code == 1, f"Expected exit 1, got {code}. stderr={err!r}"
    assert "FrontalierService" in err, f"Expected guidance, got {err!r}"


def test_s12_facade_allowlisted():
    """Scanning the S12 façade file alone must exit 0 (allowlisted)."""
    code, _out, _err = _run([str(_S12_FACADE)])
    assert code == 0, f"S12 façade should be allowlisted (exit 0), got {code}"


def test_self_exempt():
    code, _out, _err = _run([str(_LINT)])
    assert code == 0, "Self-exempt failed."
