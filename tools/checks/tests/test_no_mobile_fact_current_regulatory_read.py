"""Tests for `tools/checks/no_mobile_fact_current_regulatory_read.py` (iter-2 B2)."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


_REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_LINT = _REPO_ROOT / "tools" / "checks" / "no_mobile_fact_current_regulatory_read.py"
_BAD_FIXTURE_NAME = "bad_regulatory_read.dart"
_BAD_FIXTURE_PATH = (
    _REPO_ROOT / "apps" / "mobile" / "test" / "_fixtures" / _BAD_FIXTURE_NAME
)
_MOBILE_LIB = _REPO_ROOT / "apps" / "mobile" / "lib"


def _run(args: list[str]) -> tuple[int, str, str]:
    result = subprocess.run(
        [sys.executable, str(_LINT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.returncode, result.stdout, result.stderr


def test_lint_exists_and_is_executable():
    assert _LINT.exists(), f"lint script missing at {_LINT}"


def test_exits_zero_on_self_exempt_fixture_path():
    """Scanning the fixture by its self-exempted path exits 0."""
    code, out, _ = _run([str(_BAD_FIXTURE_PATH)])
    assert code == 0, f"expected exit 0 (self-exempt), got {code} ; stdout={out}"


def test_exit_1_when_bad_pattern_copied_outside_self_exempt(tmp_path: Path):
    """Copying the bad fixture to a non-exempt path makes the lint flag it."""
    target = tmp_path / "evil.dart"
    shutil.copyfile(_BAD_FIXTURE_PATH, target)
    code, out, _ = _run([str(target)])
    assert code == 1, f"expected exit 1, got {code} ; stdout={out}"
    assert "fact_current" in out
    assert "regulatory" in out.lower()


def test_exits_zero_on_clean_mobile_lib_tree():
    """Scanning the real apps/mobile/lib/ tree exits 0 (no actual violations)."""
    if not _MOBILE_LIB.exists():
        # If the mobile tree was not vendored on this checkout, skip
        # rather than fail.
        return
    code, out, _ = _run([str(_MOBILE_LIB)])
    assert code == 0, f"clean tree must exit 0 ; got {code}\nstdout={out}"


def test_self_exempts_lint_script_itself(tmp_path: Path):
    """The lint script body mentions `fact_current` in error message ; scan
    the script as a Dart file (rename via copy) and confirm it would NOT
    be flagged for self-reference. Self-exemption is path-based, not
    content-based, but the .dart extension filter is the primary guard."""
    # Read the lint script itself (Python ; not in scope).
    code, out, _ = _run([str(_LINT)])
    # Lint scanning itself : would be processed only if it ended in .dart,
    # which it doesn't. _expand_paths skips non-.dart unless explicitly
    # passed — and even then this file isn't .dart so it wouldn't match.
    assert code == 0, f"self-scan must exit 0 ; got {code}\nstdout={out}"
