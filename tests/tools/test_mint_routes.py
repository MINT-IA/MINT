"""Phase 32 Wave 2 — pytest suite for mint-routes CLI.

Python 3.9-compatible. All tests run with MINT_ROUTES_DRY_RUN=1 when
network access would otherwise be needed.

Task 1 green: help, bad args, --no-color flag on help output.
Task 2 flips the remaining tests green once sentry_client + dry_run land.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI = REPO_ROOT / "tools/mint-routes"


def _run(args, env_extra=None, input_bytes=None):
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [str(CLI)] + list(args),
        capture_output=True,
        env=env,
        input=input_bytes,
        cwd=str(REPO_ROOT),
        timeout=30,
    )


# ---------- Task 1 green ----------


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
    # The real guarantee — that the health renderer honours --no-color — is covered
    # by test_no_color_env_var_suppresses_ansi in Task 2 (requires health subcommand).
    r = _run(["--no-color", "--help"])
    assert r.returncode == 0
    assert b"\x1b[" not in r.stdout


# ---------- Task 2 wires (skipped until sentry_client + dry_run land) ----------


@pytest.mark.skip(reason="Task 2 wires sentry_client: token resolution + exit 71")
def test_missing_token_returns_71():
    pass


@pytest.mark.skip(reason="Task 2 wires dry_run: fixture-join produces 147 JSON lines")
def test_health_dry_run_produces_147_json_lines():
    pass


@pytest.mark.skip(reason="Task 2 wires dry_run: --owner filter")
def test_health_dry_run_owner_filter():
    pass


@pytest.mark.skip(reason="Task 2 wires health renderer: NO_COLOR env-var path")
def test_no_color_env_var_suppresses_ansi():
    pass


@pytest.mark.skip(reason="Task 2 wires sentry_client: argv safety guarantee")
def test_keychain_fallback_token_never_in_argv():
    pass


@pytest.mark.skip(reason="Task 2 wires redaction")
def test_pii_redaction_covers_six_patterns():
    pass


@pytest.mark.skip(reason="Task 2 wires redaction")
def test_pii_redaction_walks_dict_user_keys():
    pass


@pytest.mark.skip(reason="Task 2 wires classify_status")
def test_status_classification_buckets():
    pass


@pytest.mark.skip(reason="Task 2 wires schema + dart contract test")
def test_json_output_schema_matches_dart_contract():
    pass


@pytest.mark.skip(reason="Task 2 wires _chunks helper")
def test_batch_chunking_splits_30_per_batch():
    pass


@pytest.mark.skip(reason="Task 2 wires cache TTL + purge_cache")
def test_cache_ttl_purge():
    pass
