"""Phase mint-data-architecture-v1-01 Plan 04 Task 1 — codegen script tests.

Tests the `tools/codegen/regulatory_constants_to_dart.py` script :
  - `--source local|staging` resolution + serialisation parity with Plan 01
  - `--check / --write` mutual exclusivity + drift detection
  - SHA-256 _payloadIntegrityHash separately from version_hash
  - staging fallback to local on network error
  - aging-state machine (`compute_escalation_level`) thresholds 7/14/28
  - aging-state JSON file round-trip
  - generated Dart file header tagging

Subprocess-driven so the script's argparse / I/O / exit-code contract is
exercised end-to-end. DATABASE_URL pinned to sqlite:///:memory: (same
isolation pattern as Plan 01's measurement test) to immunise against
full-suite env pollution.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_SCRIPT = _REPO_ROOT / "tools" / "codegen" / "regulatory_constants_to_dart.py"


def _run_script(*args: str, env_extra: dict | None = None) -> subprocess.CompletedProcess:
    """Run the codegen script with a pinned DATABASE_URL (full-suite env isolation)."""
    env = os.environ.copy()
    env["DATABASE_URL"] = "sqlite:///:memory:"
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(_SCRIPT), *args],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(_REPO_ROOT),
    )


def _expected_local_version_hash() -> str:
    """Compute what the registry's version_hash for today is, for assertion."""
    env = os.environ.copy()
    env["DATABASE_URL"] = "sqlite:///:memory:"
    out = subprocess.run(
        [
            sys.executable,
            "-c",
            "import sys; sys.path.insert(0, 'services/backend');"
            "from app.services.regulatory.registry import RegulatoryRegistry;"
            "from datetime import date;"
            "print(RegulatoryRegistry.instance().version_hash(date.today()))",
        ],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(_REPO_ROOT),
    )
    return out.stdout.strip()


# ── Test 1 ──
def test_codegen_local_source_writes_dart_file(tmp_path: Path) -> None:
    """--source local --write produces a Dart file with the registry's version_hash."""
    output = tmp_path / "regulatory_constants.g.dart"
    result = _run_script(
        "--source", "local",
        "--write",
        "--output", str(output),
    )
    assert result.returncode == 0, (
        f"exit {result.returncode}\nstdout:{result.stdout}\nstderr:{result.stderr}"
    )
    assert output.exists(), f"file not written, stderr:{result.stderr}"

    content = output.read_text(encoding="utf-8")
    assert "const String regulatoryConstantsVersionHash" in content
    expected_hash = _expected_local_version_hash()
    assert expected_hash and len(expected_hash) == 64, "registry hash expected sha256 hex"
    assert expected_hash in content, (
        f"expected hash {expected_hash} not found in generated file"
    )


# ── Test 2 ──
def test_codegen_check_mode_exits_0_when_committed_matches_source(tmp_path: Path) -> None:
    """After --write, immediate --check exits 0 (no drift)."""
    output = tmp_path / "regulatory_constants.g.dart"
    write_res = _run_script("--source", "local", "--write", "--output", str(output))
    assert write_res.returncode == 0, write_res.stderr

    check_res = _run_script("--check", "--source", "local", "--output", str(output))
    assert check_res.returncode == 0, (
        f"check exited {check_res.returncode}\nstderr:{check_res.stderr}"
    )


# ── Test 3 ──
def test_codegen_check_mode_exits_1_when_baked_hash_diverges(tmp_path: Path) -> None:
    """Mutating the baked version_hash literal triggers exit 1 with helpful stderr."""
    output = tmp_path / "regulatory_constants.g.dart"
    write_res = _run_script("--source", "local", "--write", "--output", str(output))
    assert write_res.returncode == 0

    content = output.read_text(encoding="utf-8")
    # Flip the version_hash literal to a different valid 64-hex string.
    bogus_hash = "0" * 64
    mutated = re.sub(
        r"const String regulatoryConstantsVersionHash = '[0-9a-f]{64}';",
        f"const String regulatoryConstantsVersionHash = '{bogus_hash}';",
        content,
    )
    assert mutated != content, "regex did not match — generator output shape unexpected"
    output.write_text(mutated, encoding="utf-8")

    check_res = _run_script("--check", "--source", "local", "--output", str(output))
    assert check_res.returncode == 1, (
        f"expected exit 1 on drift, got {check_res.returncode}"
    )
    # stderr names the file + suggests --write to regenerate.
    combined = check_res.stderr + check_res.stdout
    assert "--write" in combined, f"expected --write hint in output: {combined}"


# ── Test 4 ──
def test_codegen_integrity_hash_detects_payload_tampering(tmp_path: Path) -> None:
    """Tampering with the embedded JSON body (without touching version_hash) trips integrity check."""
    output = tmp_path / "regulatory_constants.g.dart"
    write_res = _run_script("--source", "local", "--write", "--output", str(output))
    assert write_res.returncode == 0

    content = output.read_text(encoding="utf-8")
    # Mutate one byte of the embedded JSON body. The raw string uses triple-quotes
    # so we target a known-safe substring inside the JSON (a key name like "parameters").
    assert '"parameters"' in content, "expected 'parameters' key in baked JSON body"
    tampered = content.replace('"parameters"', '"parametels"', 1)
    output.write_text(tampered, encoding="utf-8")

    check_res = _run_script("--check", "--source", "local", "--output", str(output))
    assert check_res.returncode == 1, (
        f"integrity check should fail on JSON tamper. stdout:{check_res.stdout}\nstderr:{check_res.stderr}"
    )


# ── Test 5 ──
def test_codegen_staging_source_falls_back_to_local_on_connection_error(tmp_path: Path) -> None:
    """When staging is unreachable, --source staging falls back to local + writes file + exits 0."""
    output = tmp_path / "regulatory_constants.g.dart"
    aging_state = tmp_path / "aging.json"
    # Use a guaranteed-unroutable URL to trigger urllib URLError.
    result = _run_script(
        "--source", "staging",
        "--staging-url", "http://127.0.0.1:1",  # port 1 = unbound → connection refused
        "--write",
        "--output", str(output),
        "--aging-state-file", str(aging_state),
    )
    assert result.returncode == 0, (
        f"expected fallback success exit 0, got {result.returncode}\nstderr:{result.stderr}"
    )
    assert output.exists(), "fallback did not write the Dart file"
    # Stderr should warn about staging-down (humans see this in CI logs).
    combined = (result.stderr + result.stdout).lower()
    assert "staging" in combined and ("fallback" in combined or "down" in combined or "unreachable" in combined), (
        f"expected fallback warning in output:\n{result.stderr}"
    )


# ── Test 6 ──
def test_aging_state_machine_thresholds() -> None:
    """compute_escalation_level: 0/1/6→0, 7/13→1, 14/27→2, 28/100→3."""
    # Import the script as a module to exercise the pure function directly.
    sys.path.insert(0, str(_REPO_ROOT / "tools" / "codegen"))
    try:
        import regulatory_constants_to_dart as mod  # noqa: E402
    finally:
        sys.path.pop(0)

    f = mod.compute_escalation_level
    assert f(0) == 0
    assert f(1) == 0
    assert f(6) == 0
    assert f(7) == 1
    assert f(13) == 1
    assert f(14) == 2
    assert f(27) == 2
    assert f(28) == 3
    assert f(100) == 3


# ── Test 7 ──
def test_aging_state_file_round_trip(tmp_path: Path) -> None:
    """load → mutate → save → load returns the mutated state."""
    sys.path.insert(0, str(_REPO_ROOT / "tools" / "codegen"))
    try:
        import regulatory_constants_to_dart as mod  # noqa: E402
    finally:
        sys.path.pop(0)

    state_path = tmp_path / "aging.json"
    # Missing-file → returns default state (no crash).
    state = mod.load_aging_state(state_path)
    assert isinstance(state, dict)
    assert state.get("escalation_level") == 0
    assert state.get("consecutive_down_days") == 0

    state["consecutive_down_days"] = 9
    state["escalation_level"] = 1
    state["first_staging_down_at"] = "2026-05-17T14:00:00Z"
    mod.save_aging_state(state_path, state)
    assert state_path.exists()

    reloaded = mod.load_aging_state(state_path)
    assert reloaded["consecutive_down_days"] == 9
    assert reloaded["escalation_level"] == 1
    assert reloaded["first_staging_down_at"] == "2026-05-17T14:00:00Z"


# ── Test 8 ──
def test_codegen_dart_file_has_phase_tagged_header(tmp_path: Path) -> None:
    """Generated file leads with AUTO-GENERATED phase-tagged header naming script + effective_on + version_hash."""
    output = tmp_path / "regulatory_constants.g.dart"
    res = _run_script("--source", "local", "--write", "--output", str(output))
    assert res.returncode == 0, res.stderr

    content = output.read_text(encoding="utf-8")
    head = "\n".join(content.splitlines()[:8])
    assert "AUTO-GENERATED" in head
    assert "regulatory_constants_to_dart.py" in head
    assert "DO NOT EDIT MANUALLY" in head
    assert "Phase mint-data-architecture-v1-01 Plan 04" in head
    assert "Source snapshot effective_on" in head
    assert "Version hash" in head


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
