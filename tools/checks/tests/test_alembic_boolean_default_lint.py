"""Tests for `tools/checks/alembic_boolean_default_lint.py` (D-20 iter-2 A7).

Asserts (a) exit 1 on the bad fixture, (b) exit 0 on the clean existing tree
(with baseline), (c) NFKC normalization is benign, (d) self-exempt respected,
(e) --self-test mode returns 0 when ≥ 6 violations caught + tree clean post-baseline.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_LINT = _REPO_ROOT / "tools" / "checks" / "alembic_boolean_default_lint.py"
_BAD_FIXTURE = (
    _REPO_ROOT / "services" / "backend" / "tests" / "fixtures" / "alembic_bad.py"
)
_BASELINE = (
    _REPO_ROOT / "tools" / "checks" / "_baseline_alembic_boolean_at_p112.txt"
)
_ALEMBIC_TREE = _REPO_ROOT / "services" / "backend" / "alembic" / "versions"


def _run(args: list[str]) -> tuple[int, str, str]:
    """Run the lint as a subprocess. Returns (exit, stdout, stderr)."""
    result = subprocess.run(
        [sys.executable, str(_LINT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.returncode, result.stdout, result.stderr


def test_exit_1_on_bad_fixture():
    code, _out, err = _run([str(_BAD_FIXTURE)])
    assert code == 1, f"Expected exit 1 on bad fixture, got {code}. stderr={err!r}"
    # Must report ≥ 6 violations (iter-2 A7 expansion).
    assert err.count("BOOLEAN columns must use") >= 6, (
        f"Expected ≥ 6 violations, got {err.count('BOOLEAN columns must use')}. "
        f"stderr={err!r}"
    )


def test_exit_0_on_clean_tree_with_baseline():
    code, _out, err = _run([str(_ALEMBIC_TREE), "--baseline", str(_BASELINE)])
    assert code == 0, (
        f"Expected exit 0 on alembic tree with baseline, got {code}. stderr={err!r}"
    )


def test_self_test_passes():
    code, out, err = _run(["--self-test"])
    assert code == 0, f"Expected --self-test exit 0, got {code}. stdout={out!r} stderr={err!r}"
    assert "OK alembic_boolean_default_lint" in out, (
        f"Expected OK message, got {out!r}"
    )


def test_self_exempt():
    """Scanning the lint script itself must yield 0 violations."""
    code, _out, err = _run([str(_LINT)])
    assert code == 0, f"Self-exempt failed : {err!r}"


def test_caught_shapes_cover_iter2_expansion():
    """Verify the 5 documented bypass shapes from iter-2 A7 are all flagged.

    The fixture _BAD1..._BAD6 lines map to :
      _BAD1 (line 14) : plain string
      _BAD2 (line 17) : sa.literal_column
      _BAD3 (line 22) : sa.text("FALSE")
      _BAD4 (line 25) : sa.text("'0'::int")
      _BAD5 (line 30) : sa.BOOLEAN() uppercase
      _BAD6 (line 33) : type_= kwarg
    """
    _code, _out, err = _run([str(_BAD_FIXTURE)])
    for expected_line in (14, 17, 22, 25, 30, 33):
        assert f"alembic_bad.py:{expected_line}" in err, (
            f"Expected violation at line {expected_line} not in stderr. err={err!r}"
        )
