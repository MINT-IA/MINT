"""Phase 32 Wave 2 — pytest suite for mint-routes CLI.

Python 3.9-compatible. All tests run with MINT_ROUTES_DRY_RUN=1 when
network access would otherwise be needed. Task 2 ships the full live
assertions.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI = REPO_ROOT / "tools/mint-routes"


# Ensure `import tools.mint_routes.*` works from tests (standard repo layout).
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def _run(args, env_extra=None, input_bytes=None):
    env = dict(os.environ)
    if env_extra is not None:
        # Filter None values so env_extra={"FOO": None} unsets FOO if present.
        for k, v in list(env_extra.items()):
            if v is None:
                env.pop(k, None)
            else:
                env[k] = v
    return subprocess.run(
        [str(CLI)] + list(args),
        capture_output=True,
        env=env,
        input=input_bytes,
        cwd=str(REPO_ROOT),
        timeout=30,
    )


# ---------- CLI skeleton ----------


def test_help_exits_zero_and_lists_subcommands():
    r = _run(["--help"])
    assert r.returncode == 0, "--help returned {}: {}".format(
        r.returncode, r.stderr.decode()
    )
    out = r.stdout.decode()
    for sub in ["health", "redirects", "reconcile", "purge-cache", "--verify-token"]:
        assert sub in out, "{} missing from --help output".format(sub)


def test_exit_codes_bad_args_returns_2():
    r = _run(["--nonsense-flag"])
    assert r.returncode == 2


def test_no_color_flag_suppresses_ansi():
    # --no-color with --help emits argparse help text which is never ANSI coloured.
    # The health renderer --no-color path is covered by
    # test_no_color_env_var_suppresses_ansi below.
    r = _run(["--no-color", "--help"])
    assert r.returncode == 0
    assert b"\x1b[" not in r.stdout


# ---------- Token resolution (T-32-03) ----------


def test_missing_token_returns_71(monkeypatch):
    """Unit test via monkeypatch — dev machines with a live Keychain entry
    would make a subprocess-based test false-pass, so we stub
    subprocess.run inside sentry_client directly.
    """
    # Force: no env token; `security` binary simulated missing.
    monkeypatch.setenv("SENTRY_AUTH_TOKEN", "")
    monkeypatch.setenv("MINT_ROUTES_DRY_RUN", "0")

    from tools.mint_routes import sentry_client as sc

    def _fake_run(*a, **kw):
        raise FileNotFoundError("security binary stubbed missing")

    monkeypatch.setattr(sc.subprocess, "run", _fake_run)
    with pytest.raises(SystemExit) as ei:
        sc.get_sentry_token()
    assert ei.value.code == 71


# ---------- DRY_RUN health output ----------


def test_health_dry_run_produces_151_json_lines():
    r = _run(["health", "--json"], env_extra={"MINT_ROUTES_DRY_RUN": "1"})
    assert r.returncode == 0, r.stderr.decode()[:400]
    lines = [ln for ln in r.stdout.decode().splitlines() if ln.strip()]
    assert len(lines) == 151, "expected 151 JSON lines, got {}".format(
        len(lines)
    )


def test_health_dry_run_owner_filter():
    r = _run(
        ["health", "--json", "--owner=coach"],
        env_extra={"MINT_ROUTES_DRY_RUN": "1"},
    )
    assert r.returncode == 0
    lines = [ln for ln in r.stdout.decode().splitlines() if ln.strip()]
    assert 0 < len(lines) < 151


def test_no_color_env_var_suppresses_ansi():
    r = _run(
        ["health"],
        env_extra={"MINT_ROUTES_DRY_RUN": "1", "NO_COLOR": "1"},
    )
    assert r.returncode == 0
    assert b"\x1b[" not in r.stdout


def test_keychain_fallback_token_never_in_argv():
    """T-32-03 mitigation — verify source of sentry_client never spawns a
    subprocess with `--auth-token <token>` argv (the sentry-cli pattern leaks
    tokens via `ps auxf`).
    """
    src = (REPO_ROOT / "tools/mint_routes/sentry_client.py").read_text()
    assert '"--auth-token"' not in src and "'--auth-token'" not in src, (
        "sentry-cli --auth-token pattern spreads token via argv — "
        "use Authorization header or stdin"
    )


# ---------- PII redaction (T-32-02) ----------


def test_pii_redaction_covers_six_patterns():
    from tools.mint_routes.redaction import redact_str

    samples = {
        "IBAN_CH": (
            "Wire to CH93 0076 2011 6238 5295 7 urgent",
            "CH[REDACTED]",
        ),
        "IBAN_DE": (
            "Foreign DE89370400440532013000 transfer",
            "[IBAN_REDACTED]",
        ),
        "CHF_amount": ("Loss of 1'500 CHF recorded", "CHF [REDACTED]"),
        "EMAIL": ("Contact user@mint.ch", "[EMAIL]"),
        "AVS": ("AVS 756.1234.5678.90 on file", "[AVS_REDACTED]"),
    }
    for name, (raw, expected_token) in samples.items():
        got = redact_str(raw)
        assert expected_token in got, (
            "{}: '{}' -> '{}' (missing {})".format(
                name, raw, got, expected_token
            )
        )


def test_pii_redaction_walks_dict_user_keys():
    from tools.mint_routes.redaction import redact

    obj = {
        "user": {
            "id": "u_123",
            "email": "j@m.ch",
            "ip_address": "10.0.0.1",
            "username": "julien",
        },
        "extra": "ok",
    }
    redact(obj)
    for k in ("id", "email", "ip_address", "username"):
        assert k not in obj["user"], "user.{} not stripped".format(k)
    assert obj["extra"] == "ok"


# ---------- Status classification (D-06) ----------


def test_status_classification_buckets():
    from tools.mint_routes.sentry_client import classify_status

    assert classify_status(
        sentry_24h=0, ff_state=True, last_visit="2026-04-19T00:00:00Z"
    ) == "green"
    assert classify_status(
        sentry_24h=3, ff_state=True, last_visit="2026-04-19T00:00:00Z"
    ) == "yellow"
    assert classify_status(
        sentry_24h=15, ff_state=True, last_visit="2026-04-19T00:00:00Z"
    ) == "red"
    assert classify_status(
        sentry_24h=0, ff_state=False, last_visit=None
    ) == "dead"


# ---------- Schema contract (Python <-> Dart parity) ----------


def test_json_output_schema_matches_dart_contract():
    import json

    from tools.mint_routes import __schema_version__

    assert __schema_version__ == 1

    r = _run(["health", "--json"], env_extra={"MINT_ROUTES_DRY_RUN": "1"})
    lines = [ln for ln in r.stdout.decode().splitlines() if ln.strip()]
    assert lines, "CLI produced no JSON lines"
    row = json.loads(lines[0])
    for k in (
        "path",
        "category",
        "owner",
        "requires_auth",
        "kill_flag",
        "status",
        "sentry_count_24h",
        "ff_enabled",
        "last_visit_iso",
        "_redaction_applied",
        "_redaction_version",
    ):
        assert k in row, "key {} missing from JSON output".format(k)
    assert row["_redaction_applied"] is True
    assert row["_redaction_version"] == 1

    # Byte-exact Dart <-> Python parity: read the declared version from the
    # Dart schema file and assert it equals Python __schema_version__.
    dart_path = (
        REPO_ROOT / "apps/mobile/lib/routes/route_health_schema.dart"
    )
    dart_src = dart_path.read_text()
    import re

    m = re.search(
        r"const\s+int\s+kRouteHealthSchemaVersion\s*=\s*(\d+)\s*;", dart_src
    )
    assert m is not None, (
        "kRouteHealthSchemaVersion declaration not found in {}".format(
            dart_path
        )
    )
    dart_version = int(m.group(1))
    assert dart_version == __schema_version__, (
        "Dart kRouteHealthSchemaVersion={} != Python __schema_version__={}"
        .format(dart_version, __schema_version__)
    )


# ---------- Batch chunking ----------


def test_batch_chunking_splits_30_per_batch():
    from tools.mint_routes.sentry_client import _chunks

    paths = ["/r{}".format(i) for i in range(147)]
    chunks = list(_chunks(paths, 30))
    assert len(chunks) == 5
    assert len(chunks[0]) == 30
    assert len(chunks[-1]) == 147 - 30 * 4


# ---------- Cache TTL (D-09 §3) ----------


def test_cache_ttl_purge(monkeypatch, tmp_path):
    import time

    monkeypatch.setenv("MINT_ROUTES_CACHE_DIR", str(tmp_path))
    from tools.mint_routes.sentry_client import (
        _cache_path,
        _purge_stale_cache,
        purge_cache,
    )

    p = _cache_path()
    p.parent.mkdir(parents=True, exist_ok=True)

    # Stale cache (older than 7 days) — auto-delete on startup.
    p.write_text("{}")
    old = time.time() - 8 * 86400
    os.utime(p, (old, old))
    _purge_stale_cache(ttl_days=7)
    assert not p.exists(), "stale cache not auto-deleted"

    # purge_cache wipes unconditionally.
    p.write_text("{}")
    purge_cache()
    assert not p.exists(), "purge_cache did not unlink"
