"""Phase mint-data-architecture-v1-01 Plan 01 Task 1 — D-14 bundle-size measurement test.

Validates that ``tools/measurement/regulatory_snapshot_bundle_size.py`` runs
end-to-end against the live RegulatoryRegistry and reports the gzip-compressed
snapshot byte count under the 100 KB ceiling locked in CONTEXT.md §Decisions
D-14.

The script is the data anchor cited by Plan 02 doctrine and gates the locked
26-canton bake-into-bundle posture. Threshold breach → D-14 re-litigation
trigger fires (PASS verdict turns into FAIL with explicit "switch to lazy
per-canton fetch" recommendation).

Tests use ``subprocess.run`` so the measurement script behaviour stays the same
whether invoked by CI, lefthook, or a human at the shell. Live-registry calls
are intentional — the whole point is to measure the actual shipped snapshot.

Test brittleness mitigations (per Codex MEDIUM finding 2026-05-17) :
    - No hard ``param_count >= 100`` assertion. Asserts non-empty + presence of
      the 27 mandatory jurisdictions (CH + 26 cantons) which are the doctrinal
      coverage invariant, not the count.
    - Aligned with ``RegulatoryRegistry.version_hash(today)`` filter semantics
      (both use ``is_active(today)``) so there is no payload-vs-hash drift.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_SCRIPT_PATH = _REPO_ROOT / "tools" / "measurement" / "regulatory_snapshot_bundle_size.py"
_REPORT_PATH = (
    _REPO_ROOT
    / ".planning"
    / "phases"
    / "mint-data-architecture-v1-01-calc-engine-canonical"
    / "01-01-BUNDLE-SIZE-REPORT.md"
)

_EXPECTED_JURISDICTIONS = {
    "CH", "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG",
    "FR", "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG",
    "TG", "TI", "VD", "VS", "NE", "GE", "JU",
}


def _run_script(*extra_args: str) -> subprocess.CompletedProcess:
    """Invoke the measurement script from repo root with stable PYTHONPATH + DATABASE_URL.

    The measurement script transitively imports ``app.models`` which triggers
    ``app.core.database`` import-time ``create_engine()``. If the surrounding
    pytest session mutated ``DATABASE_URL`` to an unparseable value, the
    subprocess inherits the broken env and ``sqlalchemy.exc.ArgumentError``
    fires before our code runs. Pin a known-good in-memory sqlite URL so the
    subprocess is isolated from full-suite env pollution.
    """
    env = dict(os.environ)
    # Ensure services/backend is importable so `from app.services...` resolves
    # regardless of caller cwd. The script also self-injects this but belt+suspenders.
    backend_path = str(_REPO_ROOT / "services" / "backend")
    existing_path = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = (
        f"{backend_path}:{existing_path}" if existing_path else backend_path
    )
    # Override any pytest-session-polluted DATABASE_URL with a parseable
    # in-memory sqlite so SQLAlchemy.create_engine doesn't crash on import.
    # The measurement script never touches the DB ; the URL only needs to parse.
    env["DATABASE_URL"] = "sqlite:///:memory:"
    return subprocess.run(
        [sys.executable, str(_SCRIPT_PATH), *extra_args],
        capture_output=True,
        text=True,
        cwd=_REPO_ROOT,
        env=env,
        timeout=60,
    )


def test_script_runs_and_reports_under_100kb() -> None:
    """T1.1: --ci stdout JSON has the documented keys and gzip_bytes < 102_400."""
    result = _run_script("--ci")
    assert result.returncode == 0, (
        f"script exited {result.returncode}; stderr:\n{result.stderr}\nstdout:\n{result.stdout}"
    )
    payload = json.loads(result.stdout)
    assert "raw_bytes" in payload, payload
    assert "gzip_bytes" in payload, payload
    assert payload["threshold_bytes"] == 102_400, payload
    assert payload["verdict"] == "PASS", (
        f"D-14 ceiling breached — re-litigation trigger fired. Payload: {payload}"
    )
    assert payload["gzip_bytes"] < 102_400, payload


def test_script_reports_all_26_cantons_present() -> None:
    """T1.2: All 27 jurisdictions (CH + 26 cantons) covered + param_count non-empty.

    No hard count threshold — registry content is mutable. Coverage is the
    doctrinal invariant per D-14 (all 26 cantons baked into the bundle).
    """
    result = _run_script("--ci")
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert isinstance(payload["param_count"], int), payload
    assert payload["param_count"] > 0, payload
    covered = set(payload["cantons_covered"])
    assert covered == _EXPECTED_JURISDICTIONS, (
        f"jurisdiction coverage drift\nexpected: {sorted(_EXPECTED_JURISDICTIONS)}\n"
        f"got     : {sorted(covered)}\nmissing : {sorted(_EXPECTED_JURISDICTIONS - covered)}\n"
        f"extra   : {sorted(covered - _EXPECTED_JURISDICTIONS)}"
    )


def test_script_writes_report_md_with_methodology_section(tmp_path: Path) -> None:
    """T1.3: --write-report <path> writes a markdown report with 4 named sections.

    Uses a tmp path so the test does not race with the committed report file.
    """
    report_path = tmp_path / "BUNDLE-SIZE-REPORT.md"
    result = _run_script("--write-report", str(report_path))
    assert result.returncode == 0, result.stderr
    assert report_path.exists(), f"report not written at {report_path}"
    body = report_path.read_text(encoding="utf-8")
    for heading in ("## Methodology", "## Results", "## Verdict", "## Re-litigation trigger"):
        assert heading in body, (
            f"missing heading {heading!r} in report. Body head:\n{body[:500]}"
        )
    # Provenance the report must carry so Plan 02 can cite it.
    assert "gzip_bytes" in body, body[:500]
    assert "cantons_covered" in body, body[:500]
