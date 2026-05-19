"""Tests for `tools/checks/hmac_pepper_audit.py` (D-24)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_LINT = _REPO_ROOT / "tools" / "checks" / "hmac_pepper_audit.py"
_BAD_FIXTURE = (
    _REPO_ROOT / "services" / "backend" / "tests" / "fixtures" / "bad_audit_writer.py"
)
_BASELINE = _REPO_ROOT / "tools" / "checks" / "_baseline_hmac_sites_at_p112.txt"
_APP_TREE = _REPO_ROOT / "services" / "backend" / "app"
_CANONICAL = (
    _REPO_ROOT
    / "services"
    / "backend"
    / "app"
    / "services"
    / "audit"
    / "hmac_pepper.py"
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
    """The plan's bad fixture is self-exempted by path. To assert the lint
    flags the pattern, we copy the fixture content to a temp file (which is
    NOT on the self-exempt list) and scan that.
    """
    bad_text = _BAD_FIXTURE.read_text()
    tmp = tmp_path / "fake_bad.py"
    tmp.write_text(bad_text)
    code, _out, err = _run([str(tmp)])
    assert code == 1, f"Expected exit 1, got {code}. stderr={err!r}"
    assert "hmac_pepper" in err, f"Expected hmac_pepper guidance, got {err!r}"


def test_exit_0_on_app_tree_with_baseline():
    code, _out, err = _run([str(_APP_TREE), "--baseline", str(_BASELINE)])
    assert code == 0, (
        f"Expected exit 0 with baseline, got {code}. stderr={err!r}"
    )


def test_self_test_passes():
    code, out, err = _run(["--self-test"])
    assert code == 0, f"Expected exit 0, got {code}. stdout={out!r} stderr={err!r}"
    assert "OK hmac_pepper_audit" in out, f"Expected OK message, got {out!r}"


def test_canonical_entry_self_exempt():
    """The canonical hmac_pepper.py path must be self-exempted (zero violations)."""
    code, _out, _err = _run([str(_CANONICAL)])
    assert code == 0, "Canonical entry should be self-exempt."


def test_self_exempt():
    code, _out, err = _run([str(_LINT)])
    assert code == 0, f"Self-exempt failed : {err!r}"


def test_baseline_blocks_new_violations(tmp_path: Path):
    """Adding a NEW violation outside baseline must trigger exit 1."""
    new_bad = tmp_path / "new_bad.py"
    new_bad.write_text(
        "import hashlib\n"
        "def foo(user_id):\n"
        "    return hashlib.sha256(user_id.encode()).hexdigest()\n"
    )
    code, _out, err = _run([str(new_bad), "--baseline", str(_BASELINE)])
    assert code == 1, (
        f"Expected exit 1 on new violation outside baseline, got {code}. err={err!r}"
    )
