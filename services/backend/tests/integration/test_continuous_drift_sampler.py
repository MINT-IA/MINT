"""continuous_drift_sampler smoke tests — Plan 02-03 iter-2 B18.

Exercises the unit-level pieces of the sampler that don't require the
Railway staging deployment :
- env-var refusal (run without STAGING_BASE_URL/STAGING_DATABASE_URL).
- argparse contract (sample-size, dry-run).
- pure run_sample_pass with fakes (mock httpx + DB-write capture).

The actual cron deployment is exercised manually by Claude via the
`pg-soak-nightly.yml` workflow after PR-3a merges.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch



_REPO_ROOT = Path(__file__).resolve().parents[4]


def _run_sampler_module(env_overrides: dict, argv_extra: list = None) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env.pop("STAGING_BASE_URL", None)
    env.pop("STAGING_DATABASE_URL", None)
    env.update(env_overrides)
    # PYTHONPATH so the cron module can import `tools.parity.projection_diff`.
    env["PYTHONPATH"] = (
        f"{_REPO_ROOT}{os.pathsep}"
        f"{_REPO_ROOT / 'services' / 'backend'}{os.pathsep}"
        + env.get("PYTHONPATH", "")
    )
    cmd = [sys.executable, "-m", "app.cron.continuous_drift_sampler"] + (argv_extra or [])
    return subprocess.run(
        cmd,
        env=env,
        capture_output=True,
        text=True,
        cwd=str(_REPO_ROOT / "services" / "backend"),
        check=False,
        timeout=30,
    )


def test_sampler_refuses_without_env_vars():
    """Missing STAGING_BASE_URL + STAGING_DATABASE_URL → exit 2."""
    result = _run_sampler_module({})
    assert result.returncode == 2, (
        f"expected exit 2, got {result.returncode}\n"
        f"stdout={result.stdout}\nstderr={result.stderr}"
    )
    assert "STAGING_BASE_URL" in result.stderr or "STAGING_BASE_URL" in result.stdout


def test_sampler_argparse_help_exits_zero():
    result = _run_sampler_module({}, argv_extra=["--help"])
    assert result.returncode == 0
    assert "--sample-size" in result.stdout
    assert "--dry-run" in result.stdout


def test_run_sample_pass_dry_run_with_in_memory_users(tmp_path, monkeypatch):
    """Library-level run_sample_pass with a SQLite users table + httpx mock.

    Proves the sampler can pull user_ids from a real DB URL, call into a
    mocked /v1/projection pair endpoint, and diff the payloads via the
    actual `projection_diff.diff_payloads` library.
    """
    # ── DB setup : create a SQLite DB with a users table + 3 rows ──────
    from sqlalchemy import create_engine, text

    db_file = tmp_path / "sampler_users.db"
    db_url = f"sqlite:///{db_file}"
    engine = create_engine(db_url)
    with engine.connect() as conn:
        conn.execute(text("CREATE TABLE users (id TEXT PRIMARY KEY)"))
        conn.execute(text("INSERT INTO users (id) VALUES ('u-a'), ('u-b'), ('u-c')"))
        conn.commit()
    engine.dispose()

    # ── Make `tools.parity.projection_diff` importable from the sampler ──
    sys.path.insert(0, str(_REPO_ROOT))
    sys.path.insert(0, str(_REPO_ROOT / "services" / "backend"))

    from app.cron.continuous_drift_sampler import run_sample_pass

    # ── httpx mock : every call returns EQUAL pair ────────────────────
    class _FakeResponse:
        def __init__(self, payload):
            self._payload = payload

        def raise_for_status(self):
            return None

        def json(self):
            return self._payload

    class _FakeClient:
        def __init__(self, *a, **kw):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def get(self, url, params=None):
            # Return same payload for both legacy and new -> EQUAL diff
            return _FakeResponse({"income": 8500.0, "lpp": None})

    with patch("app.cron.continuous_drift_sampler.httpx.Client", _FakeClient):
        summary = run_sample_pass(
            base_url="http://fake",
            db_url=db_url,
            sample_size=3,
            dry_run=True,  # dry_run skips DB write of the audit row
        )

    assert summary["samples_attempted"] == 3
    assert summary["samples_persisted"] == 3
    assert summary["samples_dirty"] == 0
    assert len(summary["sampler_run_id"]) == 36  # UUID


def test_run_sample_pass_detects_drift(tmp_path):
    """Sampler reports diff_count > 0 when legacy ≠ new."""
    from sqlalchemy import create_engine, text

    db_file = tmp_path / "sampler_users.db"
    db_url = f"sqlite:///{db_file}"
    engine = create_engine(db_url)
    with engine.connect() as conn:
        conn.execute(text("CREATE TABLE users (id TEXT PRIMARY KEY)"))
        conn.execute(text("INSERT INTO users (id) VALUES ('u-x')"))
        conn.commit()
    engine.dispose()

    sys.path.insert(0, str(_REPO_ROOT))
    sys.path.insert(0, str(_REPO_ROOT / "services" / "backend"))

    from app.cron.continuous_drift_sampler import run_sample_pass

    class _FakeResponse:
        def __init__(self, payload):
            self._payload = payload

        def raise_for_status(self):
            return None

        def json(self):
            return self._payload

    class _DriftClient:
        def __init__(self, *a, **kw):
            self._call = 0

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def get(self, url, params=None):
            # First call (legacy=true) returns 8500 ; second returns 9000.
            self._call += 1
            return _FakeResponse({"income": 8500.0 if self._call == 1 else 9000.0})

    with patch("app.cron.continuous_drift_sampler.httpx.Client", _DriftClient):
        summary = run_sample_pass(
            base_url="http://fake",
            db_url=db_url,
            sample_size=1,
            dry_run=True,
        )
    assert summary["samples_attempted"] == 1
    assert summary["samples_dirty"] == 1
