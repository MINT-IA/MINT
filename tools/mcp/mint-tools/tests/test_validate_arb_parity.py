"""TOOL-03 unit tests.

Covers:
  (a) pre-Phase-34 fallback when arb_parity.py is absent (today's repo state);
  (b) stubbed ok exit;
  (c) stubbed drift exit (non-zero);
  (d) Pydantic v2 response schema contract;
  (e) Pitfall 5 regression gate — fallback status is DISTINCT from 'ok';
  (f) Pitfall 2 regression — subprocess uses sys.executable, not literal 'python3';
  (g) live-repo check — confirms pre-Phase-34 state in this plan's ship window.

We monkeypatch ``ARB_PARITY_SCRIPT`` on the module to simulate presence /
absence without touching ``tools/checks/``.
"""
from __future__ import annotations

from pathlib import Path

import pytest

import tools.arb_parity as arb_mod
from tools.arb_parity import ArbParityResult, TOOL_VERSION, validate_arb_parity


def test_fallback_when_script_missing(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    missing = tmp_path / "nope" / "arb_parity.py"
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", missing)

    result = validate_arb_parity()

    assert isinstance(result, ArbParityResult)
    assert result.status == "lint_not_available"
    assert "phase 34" in result.reason.lower() or "arb_parity.py" in result.reason.lower()
    assert result.exit_code is None
    assert result.script_expected_at == str(missing)
    assert result.version == TOOL_VERSION


def test_fallback_status_is_distinct_from_ok(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Pitfall 5 guard: agents must not confuse 'lint_not_available' with 'ok'."""
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", tmp_path / "absent.py")
    result = validate_arb_parity()
    assert result.status != "ok"
    assert result.status == "lint_not_available"


def test_stubbed_ok_returns_status_ok(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stub = tmp_path / "arb_parity.py"
    stub.write_text(
        "#!/usr/bin/env python3\n"
        "import sys\n"
        "print('parity OK')\n"
        "sys.exit(0)\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", stub)

    result = validate_arb_parity()

    assert result.status == "ok"
    assert result.exit_code == 0
    assert "parity OK" in result.stdout


def test_stubbed_drift_returns_drift_detected(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stub = tmp_path / "arb_parity.py"
    stub.write_text(
        "#!/usr/bin/env python3\n"
        "import sys\n"
        "print('DRIFT detected', file=sys.stderr)\n"
        "sys.exit(1)\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", stub)

    result = validate_arb_parity()

    assert result.status == "drift_detected"
    assert result.exit_code == 1
    assert "DRIFT" in result.stderr


def test_response_schema_is_pydantic_v2(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", tmp_path / "absent.py")
    dumped = validate_arb_parity().model_dump()
    assert dumped["version"] == TOOL_VERSION
    assert set(dumped.keys()) == {
        "version",
        "status",
        "exit_code",
        "reason",
        "stdout",
        "stderr",
        "script_expected_at",
    }


def test_module_uses_sys_executable_not_literal_python3() -> None:
    """Pitfall 2 regression: host default python3 is 3.9.6, which can't run
    scripts that rely on 3.10+ syntax. Subprocess must use sys.executable
    (the interpreter running the MCP venv) for portability."""
    src = Path(arb_mod.__file__).read_text(encoding="utf-8")
    assert "sys.executable" in src, "subprocess args must include sys.executable"
    # Literal "python3" or "python3.11" as subprocess command is forbidden —
    # sys.executable is the only correct choice.
    assert '"python3"' not in src
    assert "'python3'" not in src


def test_output_truncation_caps_long_stdout(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    stub = tmp_path / "arb_parity.py"
    stub.write_text(
        "#!/usr/bin/env python3\n"
        "import sys\n"
        "sys.stdout.write('x' * 50_000)\n"
        "sys.exit(0)\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(arb_mod, "ARB_PARITY_SCRIPT", stub)

    result = validate_arb_parity()

    assert result.status == "ok"
    # 4 000-char cap plus the truncation marker prefix; well under 50 000.
    assert len(result.stdout) < 5_000
    assert "truncated" in result.stdout


def test_live_script_state_pre_phase_34() -> None:
    """Integration guard against the real repo state.

    Pre-Phase-34 (today): ``tools/checks/arb_parity.py`` absent →
    status == 'lint_not_available'.
    Post-Phase-34: script ships → status == 'ok' on a clean repo.
    Never 'drift_detected' unless something is actively broken, in which case
    this test failing loud is the correct signal."""
    result = validate_arb_parity()
    assert result.status in ("lint_not_available", "ok"), (
        f"Unexpected status {result.status!r} — investigate repo state"
    )
