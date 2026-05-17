"""Tests for the constants-drift mode of `tools/checks/profile_safe_fields_parity.py`.

Phase mint-data-architecture-v1-01-calc-engine-canonical Plan 05 — D-12
parity-lint extension. The script ships a NEW `--mode constants-drift`
flag that reads the baked Dart version_hash from
`apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`
(Plan 04 artifact, may be absent during Plan 05 wave-3 execution) and
compares it against
`RegulatoryRegistry.instance().version_hash(date.today())`.

Mode is SOFT-WARN in Phase 01 per D-12 (exit 0 on drift unless `--hard`
is set ; Phase 02 first-migration PR adds `--hard` to the lefthook +
CI invocations to promote the gate). Missing Dart file is GRACEFUL
(exit 0 with status MISSING-GENERATED-FILE) so wave 3 can ship Plan 05
before wave 4 Plan 04. ImportError is LOUD (exit 2 with status
IMPORT-FAILURE) per codex MEDIUM #2 — silent degradation on env
issues was explicitly rejected.

Tests load `profile_safe_fields_parity` via importlib so they are
independent of the package path of the test runner ; matches the
existing `test_profile_safe_fields_parity.py` convention.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_LINT_PATH = _REPO_ROOT / "tools" / "checks" / "profile_safe_fields_parity.py"
_LEFTHOOK_PATH = _REPO_ROOT / "lefthook.yml"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run_lint(*args: str, env_extra: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    """Invoke the lint via subprocess + return CompletedProcess.

    DATABASE_URL is pinned per the Plan 01 SUMMARY pattern to avoid
    full-suite env pollution breaking imports the lint transitively pulls
    (the registry module loads via SQLAlchemy ORM mappings).
    """
    import os

    env = os.environ.copy()
    env.setdefault("DATABASE_URL", "sqlite:///:memory:")
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(_LINT_PATH), *args],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(_REPO_ROOT),
    )


def _fake_dart(path: Path, version_hash: str) -> None:
    """Write a synthetic regulatory_constants.g.dart with the given hash.

    The lint's regex matches `const String regulatoryConstantsVersionHash = '<64hex>';`.
    Body content around the hash is irrelevant for Plan 05 ; Plan 04
    bakes the full parameter set.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "// AUTO-GENERATED — Plan 04 codegen output (synthetic for Plan 05 tests).\n"
        f"const String regulatoryConstantsVersionHash = '{version_hash}';\n"
        "const Map<String, Object> regulatoryConstantsPayload = <String, Object>{};\n"
    )


# ---------------------------------------------------------------------------
# Test 1 — Happy path : Dart present, hashes match → OK + exit 0.
# ---------------------------------------------------------------------------


def test_constants_drift_mode_happy_path(tmp_path):
    """When the baked Dart hash equals backend version_hash(today), status OK + exit 0."""
    # Import the backend registry to get the real current hash. The lint will
    # compute the same value in-process — equality is the contract.
    backend_root = _REPO_ROOT / "services" / "backend"
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))
    from datetime import date
    from app.services.regulatory.registry import RegulatoryRegistry  # noqa: WPS433

    real_hash = RegulatoryRegistry.instance().version_hash(date.today())

    dart = tmp_path / "regulatory_constants.g.dart"
    _fake_dart(dart, real_hash)

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(dart),
        "--json-status",
    )
    assert result.returncode == 0, (
        f"Expected exit 0 on hash match ; got {result.returncode}. "
        f"stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    # Parse the JSON status line on stderr.
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    assert json_lines, f"No JSON status line found on stderr: {result.stderr!r}"
    status = json.loads(json_lines[-1])
    assert status == {"mode": "constants-drift", "status": "OK", "exit_code": 0}


# ---------------------------------------------------------------------------
# Test 2 — Drift detected, no --hard → SOFT-WARN, exit 0, DRIFT-CONSTANTS status.
# ---------------------------------------------------------------------------


def test_constants_drift_mode_drift_detected_soft_warn(tmp_path):
    """Drift between Dart hash and backend hash exits 0 in SOFT mode + names both hashes."""
    dart = tmp_path / "regulatory_constants.g.dart"
    fake_hash = "0" * 64  # Definitely won't match backend.
    _fake_dart(dart, fake_hash)

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(dart),
        "--json-status",
    )
    assert result.returncode == 0, (
        f"SOFT-WARN must exit 0 on drift ; got {result.returncode}. "
        f"stderr={result.stderr!r}"
    )
    # Status line must name the drift + suggest the codegen fix.
    assert "DRIFT-CONSTANTS" in result.stderr
    assert fake_hash in result.stderr  # Dart-side hash.
    assert "regulatory_constants_to_dart.py" in result.stderr  # Fix hint.
    # JSON status: SOFT exit_code = 0.
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    assert json_lines
    status = json.loads(json_lines[-1])
    assert status["status"] == "DRIFT-CONSTANTS"
    assert status["exit_code"] == 0


# ---------------------------------------------------------------------------
# Test 3 — Drift + --hard → exit 1 (HARD), proves Phase 02 promotion path.
# ---------------------------------------------------------------------------


def test_constants_drift_mode_drift_with_hard_flag_exits_1(tmp_path):
    """Same drift as Test 2 but `--hard` promotes to HARD failure (exit 1)."""
    dart = tmp_path / "regulatory_constants.g.dart"
    _fake_dart(dart, "0" * 64)

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(dart),
        "--hard",
        "--json-status",
    )
    assert result.returncode == 1, (
        f"HARD mode must exit 1 on drift ; got {result.returncode}. "
        f"stderr={result.stderr!r}"
    )
    assert "DRIFT-CONSTANTS" in result.stderr
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    status = json.loads(json_lines[-1])
    assert status["exit_code"] == 1


# ---------------------------------------------------------------------------
# Test 4 — Missing Dart file (Plan 04 not yet merged) → graceful exit 0.
# ---------------------------------------------------------------------------


def test_constants_drift_mode_missing_generated_file_graceful(tmp_path):
    """Plan 04 may not have shipped yet ; missing Dart file exits 0 + MISSING-GENERATED-FILE."""
    missing = tmp_path / "does_not_exist" / "regulatory_constants.g.dart"
    assert not missing.exists()

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(missing),
        "--json-status",
    )
    assert result.returncode == 0, (
        f"Missing file must be graceful ; got {result.returncode}. "
        f"stderr={result.stderr!r}"
    )
    assert "MISSING-GENERATED-FILE" in result.stderr
    # Stderr message must point at Plan 04.
    assert "Plan 04" in result.stderr
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    status = json.loads(json_lines[-1])
    assert status == {
        "mode": "constants-drift",
        "status": "MISSING-GENERATED-FILE",
        "exit_code": 0,
    }


# ---------------------------------------------------------------------------
# Test 5 — Import failure LOUD : exit 2 + IMPORT-FAILURE (codex MEDIUM #2).
# ---------------------------------------------------------------------------


def test_constants_drift_mode_import_failure_loud(tmp_path):
    """ImportError on RegulatoryRegistry must exit 2 (LOUD), not 0 (silent warn).

    Simulated by setting a `MINT_LINT_FORCE_IMPORT_FAILURE=1` env var that the
    lint honours (test-only seam) so we don't have to corrupt the repo's
    sys.path globally. Without a seam the only alternative is to mutate
    PYTHONPATH to a poison-pill directory and hope nothing else loads first ;
    the seam is honest and the contract (exit 2 + IMPORT-FAILURE + named
    import target) is what we actually want to lock down.
    """
    dart = tmp_path / "regulatory_constants.g.dart"
    _fake_dart(dart, "0" * 64)

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(dart),
        "--json-status",
        env_extra={"MINT_LINT_FORCE_IMPORT_FAILURE": "1"},
    )
    assert result.returncode == 2, (
        f"ImportError must exit 2 ; got {result.returncode}. "
        f"stderr={result.stderr!r}"
    )
    assert "IMPORT-FAILURE" in result.stderr
    # Must name the import target so the operator knows what to fix.
    assert "RegulatoryRegistry" in result.stderr
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    status = json.loads(json_lines[-1])
    assert status["status"] == "IMPORT-FAILURE"
    assert status["exit_code"] == 2


# ---------------------------------------------------------------------------
# Test 6 — `--json-status` emits machine-readable line on stderr.
# ---------------------------------------------------------------------------


def test_json_status_flag_emits_machine_readable_line(tmp_path):
    """`--json-status` adds exactly one JSON-parseable line per mode invoked."""
    dart = tmp_path / "regulatory_constants.g.dart"
    backend_root = _REPO_ROOT / "services" / "backend"
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))
    from datetime import date
    from app.services.regulatory.registry import RegulatoryRegistry  # noqa: WPS433

    _fake_dart(dart, RegulatoryRegistry.instance().version_hash(date.today()))

    result = _run_lint(
        "--mode", "constants-drift",
        "--generated-dart", str(dart),
        "--json-status",
    )
    assert result.returncode == 0

    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{") and "constants-drift" in line
    ]
    assert len(json_lines) == 1, (
        f"Expected exactly 1 JSON status line, got {len(json_lines)}: "
        f"{json_lines!r}"
    )
    parsed = json.loads(json_lines[0])
    assert set(parsed.keys()) == {"mode", "status", "exit_code"}
    assert parsed["mode"] == "constants-drift"
    assert isinstance(parsed["exit_code"], int)


# ---------------------------------------------------------------------------
# Test 7 — `--mode all` runs both checks ; exit code is the WORST of the two.
# ---------------------------------------------------------------------------


def test_default_mode_all_runs_both_checks(tmp_path):
    """`--mode all` (the default) invokes profile-safe-fields THEN constants-drift.

    The exit code is `max(psf_exit, cd_exit)` so a HARD failure on either
    mode wins. Each mode emits its own JSON status line so CI can triage
    them independently.
    """
    # Use the live profile-safe-fields baseline (server + 4 default Flutter
    # files). It MAY return 0 or 1 depending on current repo state ; we only
    # assert that BOTH modes ran and BOTH emitted a JSON status line.
    dart = tmp_path / "regulatory_constants.g.dart"
    backend_root = _REPO_ROOT / "services" / "backend"
    if str(backend_root) not in sys.path:
        sys.path.insert(0, str(backend_root))
    from datetime import date
    from app.services.regulatory.registry import RegulatoryRegistry  # noqa: WPS433

    _fake_dart(dart, RegulatoryRegistry.instance().version_hash(date.today()))

    result = _run_lint(
        "--mode", "all",
        "--generated-dart", str(dart),
        "--json-status",
    )
    # Exit code reflects the worst of the two — we don't pin its value
    # because the profile-safe-fields baseline may have drift today (Plan 19
    # SOFT mode in lefthook.yml because of an existing 40 / 5 baseline diff).
    # We DO pin that both JSON lines appear so the dispatcher is exercised.
    json_lines = [
        line for line in result.stderr.splitlines()
        if line.strip().startswith("{")
    ]
    parsed = [json.loads(line) for line in json_lines]
    modes_seen = {entry["mode"] for entry in parsed}
    assert "profile-safe-fields" in modes_seen, (
        f"--mode all must invoke profile-safe-fields ; saw {modes_seen!r}. "
        f"stderr={result.stderr!r}"
    )
    assert "constants-drift" in modes_seen, (
        f"--mode all must invoke constants-drift ; saw {modes_seen!r}. "
        f"stderr={result.stderr!r}"
    )


# ---------------------------------------------------------------------------
# Test 8 — Regression : `--mode profile-safe-fields` unchanged from W4 Plan 19.
# ---------------------------------------------------------------------------


def test_profile_safe_fields_mode_unchanged_from_w4(tmp_path):
    """`--mode profile-safe-fields` reproduces the pre-Plan-05 behaviour.

    The W4 Plan 19 contract : in-sync server + flutter fixtures → exit 0
    with "parity ... ok" on stdout. The new mode flag must NOT break the
    existing happy path.
    """
    server_file = tmp_path / "server.py"
    server_file.write_text('_PROFILE_SAFE_FIELDS = {"canton", "age"}\n')
    dart_file = tmp_path / "client.dart"
    dart_file.write_text(
        "profileContext: {\n"
        "  'canton': c,\n"
        "  'age': a,\n"
        "}\n"
    )

    result = _run_lint(
        "--mode", "profile-safe-fields",
        "--server", str(server_file),
        "--flutter", str(dart_file),
    )
    assert result.returncode == 0, (
        f"profile-safe-fields regression : stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    combined = (result.stdout + result.stderr).lower()
    assert "parity" in combined and "ok" in combined


# ---------------------------------------------------------------------------
# Test 9 — lefthook.yml carries the narrow-glob entry for constants-drift.
# ---------------------------------------------------------------------------


def test_lefthook_entry_present_narrow_glob():
    """lefthook.yml must wire `--mode constants-drift` with a narrow glob.

    The glob mentions only the 3 relevant files (registry.py upstream, the
    generated Dart file, the lint script itself). A broader glob would
    desensitise developers per codex LOW #2 — the SOFT-WARN noise floor
    matters.
    """
    text = _LEFTHOOK_PATH.read_text(encoding="utf-8")
    assert "constants-drift" in text, (
        "lefthook.yml missing constants-drift entry."
    )
    assert "--mode constants-drift" in text, (
        "lefthook.yml constants-drift entry must invoke `--mode constants-drift`."
    )
    # Narrow glob check : the 3 file pointers must all appear in the file.
    # We don't pin the exact lefthook block syntax — we check for the 3
    # path fragments that the glob MUST reference per the plan.
    assert "regulatory_constants.g.dart" in text, (
        "lefthook glob missing generated Dart artifact pointer."
    )
    assert "app/services/regulatory" in text, (
        "lefthook glob missing backend registry pointer."
    )
    assert "profile_safe_fields_parity.py" in text, (
        "lefthook glob missing lint script self-pointer."
    )
