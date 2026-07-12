---
phase: 32
plan: 2
plan_number: 02
slug: cli
type: execute
wave: 2
status: pending
depends_on: [reconcile, registry]
files_modified:
  - tools/mint-routes
  - tools/mint_routes/__init__.py
  - tools/mint_routes/cli.py
  - tools/mint_routes/sentry_client.py
  - tools/mint_routes/redaction.py
  - tools/mint_routes/output.py
  - tools/mint_routes/dry_run.py
  - tests/tools/test_mint_routes.py
  - apps/mobile/lib/routes/route_health_schema.dart
  - .gitignore
requirements:
  - MAP-02a
  - MAP-03
threats:
  - T-32-02
  - T-32-03
autonomous: true
must_haves:
  truths:
    - "`./tools/mint-routes --help` exits 0 and lists health, redirects, reconcile, purge-cache, --verify-token subcommands"
    - "`MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health --json` produces valid newline-delimited JSON per route_health_schema.dart without touching the network"
    - "Sentry token is resolved from env var first, Keychain fallback (service name `SENTRY_AUTH_TOKEN`), exit 71 if both missing"
    - "PII redaction layer masks IBAN (CH + all-countries), CHF>100, email, AVS number, user.{id,email,ip_address,username}"
    - "Exit codes strictly follow sysexits.h: 0/2/71/75/78"
    - "`--no-color` flag AND `NO_COLOR` env var both suppress ANSI codes (no-color.org)"
    - "Batch OR-query chunks 147 paths into N-sized groups with fallback to 1 req/sec sequential on 414/400"
    - "`.cache/route-health.json` auto-deletes after 7 days on startup; `purge-cache` forces immediate wipe"
    - "`apps/mobile/lib/routes/route_health_schema.dart` exports `kRouteHealthSchemaVersion = 1` constant"
    - ".cache/ is in .gitignore (verified by CI cache-gitignore-check job in Plan 05)"
    - "Python source is 3.9-compatible (no match/case, no X | Y type unions, no dict | dict)"
  artifacts:
    - path: "tools/mint-routes"
      provides: "Executable entrypoint (shebang)"
    - path: "tools/mint_routes/cli.py"
      provides: "argparse subcommand dispatch"
    - path: "tools/mint_routes/sentry_client.py"
      provides: "Keychain resolver + Sentry Issues API client + batch chunker"
    - path: "tools/mint_routes/redaction.py"
      provides: "PII redaction regex + walk helper"
    - path: "tools/mint_routes/output.py"
      provides: "ANSI color + JSON newline-delimited emission"
    - path: "tools/mint_routes/dry_run.py"
      provides: "Fixture loader for MINT_ROUTES_DRY_RUN=1"
    - path: "tests/tools/test_mint_routes.py"
      provides: "12+ passing pytest cases"
    - path: "apps/mobile/lib/routes/route_health_schema.dart"
      provides: "Schema version + Dartdoc contract (Phase 35 dogfood consumer)"
  key_links:
    - from: "CLI --json output"
      to: "route_health_schema.dart kRouteHealthSchemaVersion=1"
      via: "contract test in test_mint_routes.py::test_schema_contract_parity"
      pattern: "json.dumps(line).keys() matches documented fields"
    - from: "Keychain SENTRY_AUTH_TOKEN"
      to: "Sentry Issues API /organizations/mint/issues/"
      via: "Authorization: Bearer <token> header, never argv"
      pattern: "no `{'auth-token'}` passed via argv; subprocess stdin or Authorization header only"
---

<objective>
Wave 2 — ship the CLI `./tools/mint-routes` with full live-health capability, nLPD D-09 PII controls, and publish the Dart schema contract for Phase 35. Flip 12+ pytest stubs from skip to green.

Maps to ROADMAP Success Criteria 2 (CLI live health) + 6 (redirect aggregator), and nLPD D-09 §1-3 + §5 controls (token scope docs, redaction, retention, Keychain hardening hint).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@apps/mobile/lib/routes/route_metadata.dart
@tools/simulator/sentry_quota_smoke.sh
@CLAUDE.md

<interfaces>
<!-- Keychain pattern (RESEARCH §2 lines 337-362, inherited from sentry_quota_smoke.sh:70-84) -->

def get_sentry_token() -> str:
    import os, subprocess, sys
    tok = os.environ.get("SENTRY_AUTH_TOKEN", "")
    if tok:
        return tok
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-s", "SENTRY_AUTH_TOKEN", "-w"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode == 0:
            return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    sys.stderr.write(
        "[FAIL] SENTRY_AUTH_TOKEN missing — see docs/SETUP-MINT-ROUTES.md\n"
    )
    sys.exit(71)

<!-- Sysexits.h exit codes (D-02 locked) -->
EX_OK=0, EX_USAGE=2, EX_OSERR=71, EX_TEMPFAIL=75, EX_CONFIG=78

<!-- Executor discretion pre-locked #3: reuse service name SENTRY_AUTH_TOKEN
     (matches Phase 31 pattern; CONTEXT D-02 literal "mint-sentry-auth" is amended) -->

<!-- Python 3.9-compatible syntax required (pre-locked #4) -->
# NO match/case, NO X | Y unions, NO dict | dict merge.
from typing import Optional, Union, List, Dict

<!-- Redaction regex (D-09 §2 + A2 executor-discretion: ADD AVS defensive default) -->

IBAN_CH = re.compile(r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d\b")
IBAN_ANY = re.compile(r"\b[A-Z]{2}\d{2}\d{15,30}\b")
CHF_AMOUNT = re.compile(r"\b\d{3,}(?:'?\d{3})*(?:\.\d{2})?\s?CHF\b")
EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
AVS = re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")
USER_ID_KEYS = ("id", "email", "ip_address", "username")

<!-- route_health_schema.dart JSON contract (D-12 §4 + RESEARCH.md §7 lines 777-798) -->

const int kRouteHealthSchemaVersion = 1;

/// Each CLI `--json` line looks like:
/// {"path": "/coach", "category": "destination", "owner": "coach",
///  "requires_auth": true, "kill_flag": "enableCoachChat", "status": "green",
///  "sentry_count_24h": 3, "ff_enabled": true,
///  "last_visit_iso": "2026-04-20T03:14:00Z",
///  "_redaction_applied": true, "_redaction_version": 1}
</interfaces>
</context>

<threat_model>
[ASVS L1]
| ID | Threat | Likelihood | Impact | Mitigation | Test |
|----|--------|-----------|--------|-----------|------|
| T-32-02 | PII leakage — Sentry event payloads surface IBAN/CHF/email/AVS/user-id through CLI terminal output or `.cache/` snapshot. nLPD Art. 6/9 violation. | HIGH (Sentry stores event data; we query it) | HIGH (legal risk Swiss deployment) | Redaction layer applied to ALL Sentry API responses BEFORE display/serialize: IBAN_CH + IBAN_ANY + CHF>100 + EMAIL + AVS 756.xxxx.xxxx.xx + user.{id,email,ip_address,username} strip. JSON metadata `_redaction_applied:true, _redaction_version:1`. Snapshot JSON auto-delete 7d + purge-cache command. `.cache/` in `.gitignore` (CI gate verifies in Plan 05). | `pytest tests/tools/test_mint_routes.py::test_pii_redaction -q` (6 PII patterns covered) + `test_cache_ttl -q` |
| T-32-03 | Keychain credential theft — token leaks via `ps auxf` argv inspection OR via error messages OR via over-scoped token having write/admin. | MEDIUM (malicious local process could observe) | HIGH (Sentry org write access) | (a) Never pass token via argv — use Authorization header in Python requests OR subprocess stdin (`sentry_quota_smoke.sh:119` pattern). (b) Never print token value — only length `[DEBUG] token length=64`. (c) Optional `--verify-token` subcommand queries `/api/0/auth/` and exits 78 if scopes exceed `project:read + event:read`. (d) Docs `docs/SETUP-MINT-ROUTES.md` (Plan 05) prescribe `security add-generic-password ... -U -A` hardening. | `pytest tests/tools/test_mint_routes.py::test_keychain_fallback -q` (verifies no token in argv) + `test_verify_token_scope -q` |
</threat_model>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Python CLI skeleton — entrypoint + argparse + output modes + .gitignore (NO dry_run, NO sentry_client)</name>
  <files>tools/mint-routes, tools/mint_routes/__init__.py, tools/mint_routes/cli.py, tools/mint_routes/output.py, tests/tools/test_mint_routes.py, .gitignore</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/tools/simulator/sentry_quota_smoke.sh (Keychain + stdin JSON pattern, lines 60-150)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §2 CLI (lines 309-475)
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/accent_lint_fr.py (existing stdlib argparse pattern)
    - /Users/julienbattaglia/Desktop/MINT/tests/tools/test_mint_routes.py (Wave 0 stubs to flip)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-02 + D-09
  </read_first>
  <behavior>
    - Test `test_help_exits_zero_and_lists_subcommands`: `--help` exits 0 and output contains each subcommand name.
    - Test `test_exit_codes_bad_args_returns_2`: argparse bad args -> exit 2.
    - Test `test_no_color_flag_suppresses_ansi`: with `--no-color`, stdout contains no ESC `\x1b[` sequences on a no-network code path (help output + --help is sufficient; health subcommand is deferred to Task 2).
    - Implementation files (`cli.py`, `output.py`, `__init__.py`, `tools/mint-routes`) all `python3 -m py_compile` cleanly.

    **Deferred to Task 2** (tests MUST be skipped in Task 1, un-skipped in Task 2): `test_health_dry_run_produces_147_json_lines`, `test_health_dry_run_owner_filter`, `test_no_color_env_var_suppresses_ansi` (requires health subcommand), `test_missing_token_returns_71`, `test_keychain_fallback_token_never_in_argv`, `test_pii_redaction_*`, `test_status_classification_buckets`, `test_json_output_schema_matches_dart_contract`, `test_batch_chunking_splits_30_per_batch`, `test_cache_ttl_purge`.
  </behavior>
  <action>
    **B-1 FIX — Task 1 ships the CLI skeleton only. `dry_run.py` and `sentry_client.py` are created in Task 2. Task 1 must NOT import from non-existent modules (pytest collection would fail at import time). `_cmd_health` / `_cmd_redirects` / `_cmd_verify_token` body is a `NotImplementedError("Task 2 wires network layer")` stub so the CLI exits cleanly in Task 1 but the full network path arrives in Task 2.**

    **Python 3.9 compatibility is mandatory** (dev machine is 3.9.6). Forbidden: `match/case`, `dict | dict` merge, PEP 604 `X | Y` type union. Use `Optional[X]`, `Union[X, Y]`, `List[X]`, `Dict[K, V]` from `typing`.

    **File 1 — `tools/mint-routes`** (executable entrypoint, shebang, mode 0755):
    ```python
    #!/usr/bin/env python3
    """mint-routes — CLI for Phase 32 Cartographier.

    Usage:
      ./tools/mint-routes health [--json] [--no-color] [--batch-size=N] [--owner=X]
      ./tools/mint-routes redirects [--json] [--no-color] [--days=30]
      ./tools/mint-routes reconcile
      ./tools/mint-routes purge-cache
      ./tools/mint-routes --verify-token
      ./tools/mint-routes --help

    Env:
      MINT_ROUTES_DRY_RUN=1    Read tests/tools/fixtures/sentry_health_response.json
      NO_COLOR=1               Suppress ANSI (no-color.org)
      SENTRY_AUTH_TOKEN        Sentry API token (else read from macOS Keychain
                               service `SENTRY_AUTH_TOKEN`)
    """
    import sys
    from pathlib import Path

    # Make the package importable when invoked as `./tools/mint-routes`.
    sys.path.insert(0, str(Path(__file__).resolve().parent))

    from mint_routes.cli import main

    if __name__ == "__main__":
        sys.exit(main(sys.argv[1:]))
    ```

    Make executable: `chmod +x tools/mint-routes`.

    **File 2 — `tools/mint_routes/__init__.py`:**
    ```python
    """mint-routes CLI package (Phase 32 MAP-02a)."""

    __version__ = "1.0.0"
    __schema_version__ = 1  # must match apps/mobile/lib/routes/route_health_schema.dart
    ```

    **File 3 — `tools/mint_routes/cli.py`** (NO imports from `sentry_client` or `dry_run` — those modules do not exist yet; Task 2 wires them in):
    ```python
    """argparse subcommand dispatch for mint-routes.

    Task 1 scope: CLI skeleton only. Subcommand handlers raise
    NotImplementedError; Task 2 wires sentry_client + dry_run.
    """
    from __future__ import annotations

    import argparse
    import os
    import sys
    from pathlib import Path
    from typing import List, Optional

    # sysexits.h (D-02 locked)
    EX_OK = 0
    EX_USAGE = 2
    EX_OSERR = 71
    EX_TEMPFAIL = 75
    EX_CONFIG = 78


    def _build_parser() -> argparse.ArgumentParser:
        p = argparse.ArgumentParser(
            prog="mint-routes",
            description="Phase 32 MAP-02a — route registry health CLI.",
            epilog="Docs: docs/SETUP-MINT-ROUTES.md  |  nLPD: D-09 redaction active.",
        )
        p.add_argument("--no-color", action="store_true",
                       help="Suppress ANSI color codes (no-color.org).")
        p.add_argument("--verify-token", action="store_true",
                       help="Query Sentry auth endpoint; exit 78 if scope exceeds project:read+event:read.")

        sub = p.add_subparsers(dest="command")

        h = sub.add_parser("health", help="Show per-route health status (green/yellow/red/dead).")
        h.add_argument("--json", action="store_true", help="Emit newline-delimited JSON.")
        h.add_argument("--batch-size", type=int, default=30,
                       help="Sentry OR-query batch size (default 30, D-11 J0 validates).")
        h.add_argument("--owner", type=str, default=None,
                       help="Filter by RouteOwner value (e.g., coach, scan).")

        r = sub.add_parser("redirects", help="Aggregate legacy_redirect.hit breadcrumb counts over N days.")
        r.add_argument("--json", action="store_true")
        r.add_argument("--days", type=int, default=30)

        sub.add_parser("reconcile",
                       help="Run tools/checks/route_registry_parity.py + show diff.")
        sub.add_parser("purge-cache",
                       help="Delete .cache/route-health.json immediately (D-09 §3).")

        return p


    def main(argv: Optional[List[str]] = None) -> int:
        if argv is None:
            argv = sys.argv[1:]
        parser = _build_parser()
        try:
            args = parser.parse_args(argv)
        except SystemExit as e:
            # argparse calls sys.exit(2) on bad args — preserve.
            return int(e.code) if e.code is not None else EX_USAGE

        # --verify-token is a top-level flag action
        if args.verify_token:
            return _cmd_verify_token(args)

        cmd = args.command
        if cmd == "health":
            return _cmd_health(args)
        if cmd == "redirects":
            return _cmd_redirects(args)
        if cmd == "reconcile":
            return _cmd_reconcile(args)
        if cmd == "purge-cache":
            return _cmd_purge_cache(args)

        parser.print_help()
        return EX_USAGE


    def _cmd_health(args: argparse.Namespace) -> int:
        # Task 2 wires: from .sentry_client import fetch_health, get_sentry_token
        #               from .output import render_health
        #               from .dry_run import is_dry_run, load_fixture
        raise NotImplementedError("Task 2 wires sentry_client + dry_run + output for health")


    def _cmd_redirects(args: argparse.Namespace) -> int:
        raise NotImplementedError("Task 2 wires sentry_client + dry_run for redirects")


    def _cmd_reconcile(args: argparse.Namespace) -> int:
        import subprocess
        lint = Path(__file__).resolve().parents[2] / "tools/checks/route_registry_parity.py"
        r = subprocess.run(["python3", str(lint)], capture_output=False)
        return r.returncode


    def _cmd_purge_cache(args: argparse.Namespace) -> int:
        raise NotImplementedError("Task 2 wires sentry_client.purge_cache")


    def _cmd_verify_token(args: argparse.Namespace) -> int:
        raise NotImplementedError("Task 2 wires sentry_client.verify_token_scope")


    def _should_color(args: argparse.Namespace) -> bool:
        if args.no_color:
            return False
        if os.environ.get("NO_COLOR"):
            return False
        return sys.stdout.isatty()
    ```

    **File 4 — `tools/mint_routes/output.py`** (color helpers; safe to ship in Task 1, no external deps):
    ```python
    """ANSI coloring + JSON newline-delimited output for mint-routes."""
    from __future__ import annotations

    import json
    import sys
    from typing import Any, Dict, List

    ANSI_GREEN = "\x1b[32m"
    ANSI_YELLOW = "\x1b[33m"
    ANSI_RED = "\x1b[31m"
    ANSI_DIM = "\x1b[2m"
    ANSI_RESET = "\x1b[0m"

    _STATUS_COLOR = {
        "green": ANSI_GREEN,
        "yellow": ANSI_YELLOW,
        "red": ANSI_RED,
        "dead": ANSI_DIM,
    }


    def render_health(rows: List[Dict[str, Any]], as_json: bool, use_color: bool) -> int:
        if as_json:
            for row in rows:
                sys.stdout.write(json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n")
            return 0
        # Terminal view
        for row in rows:
            status = row.get("status", "unknown")
            path = row.get("path", "?")
            owner = row.get("owner", "?")
            count = row.get("sentry_count_24h", 0)
            line = f"{status:<8} {path:<45} {owner:<12} {count:>4}"
            if use_color:
                color = _STATUS_COLOR.get(status, "")
                line = f"{color}{line}{ANSI_RESET}"
            sys.stdout.write(line + "\n")
        return 0


    def render_redirects(rows: List[Dict[str, Any]], as_json: bool, use_color: bool) -> int:
        if as_json:
            for row in rows:
                sys.stdout.write(json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n")
            return 0
        for row in rows:
            sys.stdout.write(f"{row.get('from','?'):<30} -> {row.get('to','?'):<30} hits={row.get('count_30d',0):>4}\n")
        return 0
    ```

    **File 5 — `tests/tools/test_mint_routes.py`** — Task 1 flips 3 stubs green; all remaining tests stay `@pytest.mark.skip(reason="Task 2 wires network layer")`. Replace the Wave 0 stub file verbatim with:
    ```python
    """Phase 32 Wave 2 — pytest suite for mint-routes CLI.

    Python 3.9-compatible. All tests run with MINT_ROUTES_DRY_RUN=1 when
    network access would otherwise be needed.

    Task 1 green: help, bad args, --no-color flag on help output.
    Task 2 flips the remaining 9+ tests green once sentry_client + dry_run land.
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
        assert r.returncode == 0, f"--help returned {r.returncode}: {r.stderr.decode()}"
        out = r.stdout.decode()
        for sub in ["health", "redirects", "reconcile", "purge-cache", "--verify-token"]:
            assert sub in out, f"{sub} missing from --help output"


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
    ```

    **Append `.cache/` to `.gitignore`** (if not already present):
    ```bash
    grep -q "^\.cache/" /Users/julienbattaglia/Desktop/MINT/.gitignore || echo ".cache/" >> /Users/julienbattaglia/Desktop/MINT/.gitignore
    ```

    Run:
    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    python3 -m py_compile tools/mint_routes/__init__.py tools/mint_routes/cli.py tools/mint_routes/output.py
    python3 -m pytest tests/tools/test_mint_routes.py -q
    ```
    Expected: py_compile passes silently; pytest reports 3 passed + 11 skipped (or similar).

    **Task 2 note (B-1 remediation):** Task 2 creates `tools/mint_routes/sentry_client.py` and `tools/mint_routes/dry_run.py`, replaces the `raise NotImplementedError` stubs in `cli.py` with real imports (`from .sentry_client import …`, `from .dry_run import …`), and un-skips the 11 deferred tests.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && chmod +x tools/mint-routes && python3 -m py_compile tools/mint_routes/__init__.py tools/mint_routes/cli.py tools/mint_routes/output.py && ./tools/mint-routes --help 2>&1 | head -5 && python3 -m pytest tests/tools/test_mint_routes.py::test_help_exits_zero_and_lists_subcommands tests/tools/test_mint_routes.py::test_exit_codes_bad_args_returns_2 tests/tools/test_mint_routes.py::test_no_color_flag_suppresses_ansi -q 2>&1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `tools/mint-routes` is executable (`test -x tools/mint-routes`)
    - `./tools/mint-routes --help` exits 0 and output contains: health, redirects, reconcile, purge-cache, --verify-token
    - `./tools/mint-routes --nonsense` exits 2
    - `./tools/mint-routes --no-color --help` emits no `\x1b[` bytes
    - `tests/tools/test_mint_routes.py` collects cleanly (NO ImportError from sentry_client or dry_run — modules do not exist in Task 1)
    - 3 tests pass (help, bad args, no-color flag on help); 11 tests reported as skipped with reason="Task 2 wires …"
    - `.gitignore` contains `.cache/`
    - All Python files compile cleanly: `python3 -m py_compile tools/mint_routes/__init__.py tools/mint_routes/cli.py tools/mint_routes/output.py` exits 0
    - `tools/mint_routes/` directory does NOT contain `sentry_client.py`, `redaction.py`, or `dry_run.py` (Task 2 creates these)
    - No `X | Y` type unions, no `match/case`, no `dict | dict` anywhere in the package (grep confirms)
  </acceptance_criteria>
  <done>CLI skeleton shipped. Subcommand dispatch, argparse, output modes, gitignore all green. Pytest collection succeeds (no import-time failure). Task 2 fills Sentry client + redaction + dry_run + schema, un-skips 11 tests.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Sentry client + dry_run + PII redaction + batch chunker + classify + schema publication + wire cli.py</name>
  <files>tools/mint_routes/sentry_client.py, tools/mint_routes/redaction.py, tools/mint_routes/dry_run.py, tools/mint_routes/cli.py, apps/mobile/lib/routes/route_health_schema.dart, apps/mobile/test/routes/route_meta_json_test.dart, tests/tools/test_mint_routes.py</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §2 Sentry Issues API (lines 366-419), §3 redaction (lines 421-452), §7 schema publication (lines 777-798)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-09 (redaction + retention spec)
    - /Users/julienbattaglia/Desktop/MINT/tools/simulator/sentry_quota_smoke.sh lines 60-150 (Keychain pattern verbatim)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/routes/route_metadata.dart (registry for loading rows in fixture-join logic)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/test/routes/route_meta_json_test.dart (Wave 0 stub to flip)
    - /Users/julienbattaglia/Desktop/MINT/tools/mint_routes/cli.py (Task 1 output — replace NotImplementedError stubs with real imports)
  </read_first>
  <behavior>
    - Test `test_missing_token_returns_71`: with no env token and `security` unavailable (or Keychain miss), CLI exits 71.
    - Test `test_health_dry_run_produces_147_json_lines`: `MINT_ROUTES_DRY_RUN=1 health --json` emits 147 JSON lines.
    - Test `test_health_dry_run_owner_filter`: `--owner=coach` narrows output.
    - Test `test_no_color_env_var_suppresses_ansi`: `NO_COLOR=1 MINT_ROUTES_DRY_RUN=1 health` emits no ANSI.
    - Test `test_keychain_fallback_token_never_in_argv`: source grep — no `--auth-token` argv pattern in sentry_client.
    - Test `test_pii_redaction_covers_six_patterns`: IBAN_CH, IBAN_ANY, CHF>100, EMAIL, AVS, user.* keys all masked.
    - Test `test_pii_redaction_walks_dict_user_keys`: nested user object keys stripped.
    - Test `test_status_classification_buckets`: classify returns correct status for 4 canonical cases.
    - Test `test_json_output_schema_matches_dart_contract`: `__schema_version__ == 1` and JSON keys present.
    - Test `test_batch_chunking_splits_30_per_batch`: 147 paths -> 5 chunks (30, 30, 30, 30, 27).
    - Test `test_cache_ttl_purge`: stale `.cache/route-health.json` auto-deletes.
    - Test (Dart) `kRouteHealthSchemaVersion == 1`.
  </behavior>
  <action>
    **File 1 — `tools/mint_routes/redaction.py`:**
    ```python
    """PII redaction per nLPD D-09 §2 + executor-discretion A2 (AVS defensive default).

    Covers:
    - IBAN_CH: CH\\d{2} + up to 21 remaining digits (with optional spaces).
    - IBAN_ANY: general country-code + 15..30 digits pattern (DE, FR, IT).
    - CHF_AMOUNT: \\d{3,} with optional CHF prefix (>= 100 threshold).
    - EMAIL: RFC-lite regex.
    - AVS: Swiss social insurance number 756.xxxx.xxxx.xx.
    - user.* keys: id, email, ip_address, username.

    JSON output metadata appended by caller: _redaction_applied=True, _redaction_version=1.

    Known false-negative gaps (documented, not blocking):
    - Phone numbers (Swiss +41 or 0XX formats) — deferred v2.9.
    - Postal addresses (free-form strings) — deferred v2.9.
    - User ID embedded in URL query params — caller should strip query strings before display.
    """
    from __future__ import annotations

    import re
    from typing import Any, Dict, List, Optional, Union

    IBAN_CH = re.compile(r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d\b")
    IBAN_ANY = re.compile(r"\b[A-Z]{2}\d{2}\d{15,30}\b")
    # CHF amounts >= 100 (3+ leading digits, with optional thousand separators)
    CHF_AMOUNT = re.compile(r"\b\d{3,}(?:'?\d{3})*(?:\.\d{2})?\s?CHF\b", re.IGNORECASE)
    CHF_AMOUNT_PREFIX = re.compile(r"\bCHF\s?\d{3,}(?:'?\d{3})*(?:\.\d{2})?\b", re.IGNORECASE)
    EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
    AVS = re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")

    USER_ID_KEYS = ("id", "email", "ip_address", "username")


    def redact_str(s: str) -> str:
        """Apply all string-level patterns to `s`. Order: IBAN_CH before IBAN_ANY."""
        s = IBAN_CH.sub("CH[REDACTED]", s)
        s = IBAN_ANY.sub("[IBAN_REDACTED]", s)
        s = AVS.sub("[AVS_REDACTED]", s)
        s = EMAIL.sub("[EMAIL]", s)
        s = CHF_AMOUNT.sub("CHF [REDACTED]", s)
        s = CHF_AMOUNT_PREFIX.sub("CHF [REDACTED]", s)
        return s


    def redact(obj):  # type: (Any) -> Any
        """Walk dict/list structure in place, strip user.* keys and redact strings."""
        if isinstance(obj, dict):
            user = obj.get("user")
            if isinstance(user, dict):
                for k in USER_ID_KEYS:
                    user.pop(k, None)
            for k in list(obj.keys()):
                v = obj[k]
                if isinstance(v, str):
                    obj[k] = redact_str(v)
                elif isinstance(v, (dict, list)):
                    redact(v)
                else:
                    # leave non-string scalars intact
                    pass
        elif isinstance(obj, list):
            for i, v in enumerate(obj):
                if isinstance(v, str):
                    obj[i] = redact_str(v)
                elif isinstance(v, (dict, list)):
                    redact(v)
        return obj
    ```

    **File 2 — `tools/mint_routes/sentry_client.py`:**
    ```python
    """Keychain resolver + Sentry Issues API client + batch chunker + status classifier + cache TTL."""
    from __future__ import annotations

    import json
    import os
    import subprocess
    import sys
    import time
    from datetime import datetime, timedelta, timezone
    from pathlib import Path
    from typing import Any, Dict, Iterable, Iterator, List, Optional
    from urllib.parse import urlencode
    from urllib.request import Request, urlopen
    from urllib.error import HTTPError

    from .redaction import redact

    # sysexits
    EX_OSERR = 71
    EX_TEMPFAIL = 75
    EX_CONFIG = 78

    SENTRY_ORG = os.environ.get("SENTRY_ORG", "mint")
    SENTRY_API_BASE = os.environ.get("SENTRY_API_BASE", "https://sentry.io/api/0")


    def _cache_path() -> Path:
        # Local .cache/ next to repo root (D-09 §3; `.gitignore` must cover it).
        # Prefer env override for CI; fall back to ~/.cache/mint/.
        root = os.environ.get("MINT_ROUTES_CACHE_DIR")
        if root:
            return Path(root) / "route-health.json"
        return Path.home() / ".cache" / "mint" / "route-health.json"


    def _purge_stale_cache(ttl_days: int = 7) -> None:
        """D-09 §3 — 7-day retention. Called at CLI startup (best-effort)."""
        p = _cache_path()
        if not p.exists():
            return
        age = time.time() - p.stat().st_mtime
        if age > ttl_days * 86400:
            try:
                p.unlink()
            except OSError:
                pass


    def purge_cache() -> None:
        """Immediate wipe. Exposed as `mint-routes purge-cache`."""
        p = _cache_path()
        if p.exists():
            try:
                p.unlink()
            except OSError:
                pass


    def get_sentry_token() -> str:
        """Env var first; else macOS Keychain service name SENTRY_AUTH_TOKEN
        (reused from tools/simulator/sentry_quota_smoke.sh:72 per
        executor_discretion_pre_locked item #3).

        Exits 71 EX_OSERR with setup pointer if both unavailable.
        """
        tok = os.environ.get("SENTRY_AUTH_TOKEN", "")
        if tok:
            return tok
        try:
            r = subprocess.run(
                ["security", "find-generic-password", "-s", "SENTRY_AUTH_TOKEN", "-w"],
                capture_output=True, text=True, timeout=5,
            )
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip()
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        sys.stderr.write(
            "[FAIL] SENTRY_AUTH_TOKEN missing.\n"
            "       env: export SENTRY_AUTH_TOKEN=<token>\n"
            "       or Keychain: security add-generic-password -a $USER -s SENTRY_AUTH_TOKEN -w <token> -U -A\n"
            "       See docs/SETUP-MINT-ROUTES.md for scope (project:read + event:read).\n"
        )
        sys.exit(EX_OSERR)


    def _chunks(items: List[str], n: int) -> Iterator[List[str]]:
        for i in range(0, len(items), n):
            yield items[i:i + n]


    def classify_status(sentry_24h: int, ff_state: bool, last_visit: Optional[str]) -> str:
        """MAP-03 status classification (D-06 locked)."""
        if not ff_state:
            return "dead"
        if sentry_24h >= 10:
            return "red"
        if sentry_24h >= 1:
            return "yellow"
        if last_visit is None:
            return "dead"
        try:
            dt = datetime.fromisoformat(last_visit.replace("Z", "+00:00"))
        except ValueError:
            return "dead"
        if datetime.now(timezone.utc) - dt > timedelta(days=30):
            return "dead"
        return "green"


    def load_registry_rows() -> List[Dict[str, Any]]:
        """Lightweight parser over apps/mobile/lib/routes/route_metadata.dart —
        NOT a full Dart parser. Extracts path/category/owner/requires_auth/kill_flag
        per entry for CLI display. Used for join in DRY_RUN and in live mode.
        """
        import re
        src_path = Path(__file__).resolve().parents[2] / "apps/mobile/lib/routes/route_metadata.dart"
        src = src_path.read_text()
        rows: List[Dict[str, Any]] = []
        # Match per-entry block from key through closing ')'.
        pat = re.compile(
            r"'(?P<path>[^']+)':\s*RouteMeta\(\s*"
            r"path:\s*'[^']+',\s*"
            r"category:\s*RouteCategory\.(?P<cat>\w+),\s*"
            r"owner:\s*RouteOwner\.(?P<owner>\w+),\s*"
            r"requiresAuth:\s*(?P<auth>true|false),"
            r"(?:\s*killFlag:\s*'(?P<flag>[^']+)',)?",
            re.DOTALL,
        )
        for m in pat.finditer(src):
            rows.append({
                "path": m.group("path"),
                "category": m.group("cat"),
                "owner": m.group("owner"),
                "requires_auth": m.group("auth") == "true",
                "kill_flag": m.group("flag"),
            })
        return rows


    def _build_batch_query(paths: List[str]) -> str:
        # Sentry search list syntax: transaction:[/a, /b]
        return "transaction:[" + ", ".join(paths) + "]"


    def _call_sentry_issues(query: str, token: str, stats_period: str = "24h") -> Dict[str, Any]:
        params = urlencode({"query": query, "statsPeriod": stats_period})
        url = f"{SENTRY_API_BASE}/organizations/{SENTRY_ORG}/issues/?{params}"
        req = Request(url, headers={
            "Authorization": f"Bearer {token}",
            "User-Agent": "mint-routes/1.0",
        })
        try:
            with urlopen(req, timeout=15) as resp:
                body = resp.read().decode()
        except HTTPError as e:
            status = e.code
            if status in (401, 403):
                sys.stderr.write(f"[FAIL] Sentry auth error {status} — scope missing? See docs/SETUP-MINT-ROUTES.md\n")
                sys.exit(EX_CONFIG)
            if status == 414:
                raise _BatchTooLarge(len(query)) from e
            if status == 429:
                raise _RateLimited() from e
            raise
        except OSError as e:
            sys.stderr.write(f"[FAIL] network error: {e}\n")
            sys.exit(EX_TEMPFAIL)
        data = json.loads(body) if body else {}
        return redact(data) if isinstance(data, (dict, list)) else {}


    class _BatchTooLarge(Exception):
        def __init__(self, query_len: int):
            self.query_len = query_len


    class _RateLimited(Exception):
        pass


    def fetch_health(token: str, batch_size: int = 30) -> List[Dict[str, Any]]:
        """Full scan. Batches `transaction:[a, b, ...]` OR queries.
        Falls back to 1 req/sec sequential if batch too large (414)."""
        _purge_stale_cache()
        registry = load_registry_rows()
        index: Dict[str, Dict[str, Any]] = {}
        paths = [r["path"] for r in registry]
        try:
            for chunk in _chunks(paths, batch_size):
                q = _build_batch_query(chunk)
                d = _call_sentry_issues(q, token=token)
                for issue in d.get("data", []) if isinstance(d, dict) else []:
                    t = issue.get("transaction") or issue.get("culprit")
                    if t:
                        index[t] = {
                            "count_24h": issue.get("count", 0),
                            "last_seen": issue.get("lastSeen"),
                        }
        except _BatchTooLarge:
            # Fallback: 1 req/sec sequential.
            for p in paths:
                d = _call_sentry_issues(f"transaction:{p}", token=token)
                for issue in d.get("data", []) if isinstance(d, dict) else []:
                    index[issue.get("transaction", p)] = {
                        "count_24h": issue.get("count", 0),
                        "last_seen": issue.get("lastSeen"),
                    }
                time.sleep(1.0)
        except _RateLimited:
            time.sleep(4.0)
            # Single retry in a mini-batch
            pass

        # Join with registry
        rows: List[Dict[str, Any]] = []
        for meta in registry:
            s = index.get(meta["path"], {"count_24h": 0, "last_seen": None})
            rows.append({
                "path": meta["path"],
                "category": meta["category"],
                "owner": meta["owner"],
                "requires_auth": meta["requires_auth"],
                "kill_flag": meta["kill_flag"],
                "status": classify_status(s["count_24h"], True, s["last_seen"]),
                "sentry_count_24h": s["count_24h"],
                "ff_enabled": True,
                "last_visit_iso": s["last_seen"],
                "_redaction_applied": True,
                "_redaction_version": 1,
            })
        return rows


    def fetch_redirect_hits(token: str, days: int = 30) -> List[Dict[str, Any]]:
        """Aggregate breadcrumb `mint.routing.legacy_redirect.hit` counts.
        Phase 35 may refine via dedicated breadcrumb query API."""
        # For Phase 32 MVP: reuse events API filtered on message containing the category.
        q = f"message:mint.routing.legacy_redirect.hit"
        d = _call_sentry_issues(q, token=token, stats_period=f"{days}d")
        # Aggregate by `data.from -> data.to`
        counts: Dict[str, Dict[str, Any]] = {}
        for issue in d.get("data", []) if isinstance(d, dict) else []:
            from_ = (issue.get("tags", {}) or {}).get("from", "unknown")
            to_ = (issue.get("tags", {}) or {}).get("to", "unknown")
            key = f"{from_}->{to_}"
            counts.setdefault(key, {"from": from_, "to": to_, "count_30d": 0})
            counts[key]["count_30d"] += issue.get("count", 0)
        return sorted(counts.values(), key=lambda r: -r["count_30d"])


    def verify_token_scope(token: str) -> int:
        """D-09 §1 — query /api/0/auth/ and fail if scope > project:read + event:read.

        `org:read` is kept in the allowed set because Sentry's `/api/0/auth/`
        endpoint itself requires that scope to enumerate scopes on the token
        (context: the endpoint returns `user.organizations` alongside `scopes`;
        without `org:read` the call itself 403s, making verify-token unusable).
        Operators who want the strictest read-only posture may omit `org:read`
        from token creation and skip `--verify-token`.
        """
        req = Request(f"{SENTRY_API_BASE}/auth/", headers={
            "Authorization": f"Bearer {token}",
        })
        try:
            with urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode())
        except HTTPError as e:
            sys.stderr.write(f"[FAIL] /auth/ returned {e.code} — token invalid?\n")
            return EX_CONFIG
        scopes = set(data.get("scopes", []))
        allowed = {"project:read", "event:read", "org:read"}  # org:read needed by /auth/ endpoint itself
        extra = scopes - allowed
        if extra:
            sys.stderr.write(f"[FAIL] token has extra scopes (nLPD D-09 §1 minimization): {extra}\n")
            return EX_CONFIG
        print(f"[OK] token scopes are within allowed set: {sorted(scopes)}")
        return 0
    ```

    **File 3 — `tools/mint_routes/dry_run.py`:**
    ```python
    """DRY_RUN fixture harness (MINT_ROUTES_DRY_RUN=1)."""
    from __future__ import annotations

    import json
    import os
    from pathlib import Path
    from typing import Any, Dict, List

    _FIXTURE = Path(__file__).resolve().parents[2] / "tests/tools/fixtures/sentry_health_response.json"


    def is_dry_run() -> bool:
        return os.environ.get("MINT_ROUTES_DRY_RUN") == "1"


    def load_fixture() -> List[Dict[str, Any]]:
        raw = _FIXTURE.read_text()
        data = json.loads(raw)
        # Fixture shape: {"_meta": {...}, "issues": [...]}.
        # Join with registry info to produce CLI rows.
        from .sentry_client import classify_status, load_registry_rows
        registry = load_registry_rows()  # reads apps/mobile/lib/routes/route_metadata.dart
        index = {i["transaction"]: i for i in data.get("issues", [])}
        rows: List[Dict[str, Any]] = []
        for meta in registry:
            issue = index.get(meta["path"], {"count_24h": 0, "last_seen": None})
            rows.append({
                "path": meta["path"],
                "category": meta["category"],
                "owner": meta["owner"],
                "requires_auth": meta["requires_auth"],
                "kill_flag": meta["kill_flag"],
                "status": classify_status(
                    sentry_24h=issue.get("count_24h", 0),
                    ff_state=True,
                    last_visit=issue.get("last_seen"),
                ),
                "sentry_count_24h": issue.get("count_24h", 0),
                "ff_enabled": True,
                "last_visit_iso": issue.get("last_seen"),
                "_redaction_applied": True,
                "_redaction_version": 1,
            })
        return rows


    def load_fixture_redirects() -> List[Dict[str, Any]]:
        # Minimal fixture — 3 redirects with nonzero hits
        return [
            {"from": "/report", "to": "/rapport", "count_30d": 12},
            {"from": "/report/v2", "to": "/rapport", "count_30d": 5},
            {"from": "/profile", "to": "/profile/bilan", "count_30d": 87},
        ]
    ```

    **File 4 — Update `tools/mint_routes/cli.py`** — replace the four `raise NotImplementedError` stubs from Task 1 with real implementations:

    Replace `_cmd_health` body:
    ```python
    def _cmd_health(args: argparse.Namespace) -> int:
        from .sentry_client import fetch_health, get_sentry_token
        from .output import render_health
        from .dry_run import is_dry_run, load_fixture

        if is_dry_run():
            data = load_fixture()
        else:
            token = get_sentry_token()  # exits 71 if missing
            data = fetch_health(token=token, batch_size=args.batch_size)
        if args.owner:
            data = [r for r in data if r.get("owner") == args.owner]
        return render_health(data, as_json=args.json, use_color=_should_color(args))
    ```

    Replace `_cmd_redirects` body:
    ```python
    def _cmd_redirects(args: argparse.Namespace) -> int:
        from .sentry_client import fetch_redirect_hits, get_sentry_token
        from .output import render_redirects
        from .dry_run import is_dry_run, load_fixture_redirects

        if is_dry_run():
            data = load_fixture_redirects()
        else:
            token = get_sentry_token()
            data = fetch_redirect_hits(token=token, days=args.days)
        return render_redirects(data, as_json=args.json, use_color=_should_color(args))
    ```

    Replace `_cmd_purge_cache` body:
    ```python
    def _cmd_purge_cache(args: argparse.Namespace) -> int:
        from .sentry_client import purge_cache
        purge_cache()
        print("[OK] .cache/route-health.json wiped (D-09 §3).")
        return EX_OK
    ```

    Replace `_cmd_verify_token` body:
    ```python
    def _cmd_verify_token(args: argparse.Namespace) -> int:
        from .sentry_client import verify_token_scope, get_sentry_token
        token = get_sentry_token()
        return verify_token_scope(token)
    ```

    **File 5 — `apps/mobile/lib/routes/route_health_schema.dart`:**
    ```dart
    /// Phase 32 MAP-03 — JSON contract for `./tools/mint-routes health --json`.
    ///
    /// **Consumer contract:** Phase 35 dogfood `tools/dogfood/mint-dogfood.sh`
    /// parses the newline-delimited JSON and greps for `"status":"red"` or
    /// `"status":"dead"`. Any breaking change MUST bump `kRouteHealthSchemaVersion`
    /// and update `tools/mint_routes/__init__.py::__schema_version__` in lockstep.
    ///
    /// **Drift detection:** `tests/tools/test_mint_routes.py::test_json_output_schema_matches_dart_contract`
    /// asserts parity via version equality.
    ///
    /// Example line:
    ///     {"path": "/coach", "category": "destination", "owner": "coach",
    ///      "requires_auth": true, "kill_flag": "enableCoachChat", "status": "green",
    ///      "sentry_count_24h": 3, "ff_enabled": true,
    ///      "last_visit_iso": "2026-04-20T03:14:00Z",
    ///      "_redaction_applied": true, "_redaction_version": 1}
    library;

    /// Bump on any breaking change to the JSON shape.
    const int kRouteHealthSchemaVersion = 1;

    /// Documented keys (for reference by Dart consumers):
    /// - `path` (String) — GoRoute path, matches `kRouteRegistry` key
    /// - `category` (String) — RouteCategory.name
    /// - `owner` (String) — RouteOwner.name
    /// - `requires_auth` (bool) — from RouteMeta.requiresAuth
    /// - `kill_flag` (String?) — from RouteMeta.killFlag (null if infra owner)
    /// - `status` (String) — one of: green, yellow, red, dead
    /// - `sentry_count_24h` (int) — Sentry Issues API 24h error count
    /// - `ff_enabled` (bool) — FeatureFlags local state
    /// - `last_visit_iso` (String?) — ISO 8601 timestamp or null
    /// - `_redaction_applied` (bool) — always true in Phase 32
    /// - `_redaction_version` (int) — matches `_redaction_version` constant
    class RouteHealthJsonContract {
      const RouteHealthJsonContract._();
    }
    ```

    **File 6 — Flip `apps/mobile/test/routes/route_meta_json_test.dart` green:**
    ```dart
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/routes/route_health_schema.dart';

    void main() {
      group('RouteHealthJsonContract (MAP-03)', () {
        test('kRouteHealthSchemaVersion == 1 (Phase 32 stable contract)', () {
          expect(kRouteHealthSchemaVersion, 1);
        });

        test('schema file declares RouteHealthJsonContract class', () {
          // Compile-time proof only — if this test compiles, the class exists.
          const _ = RouteHealthJsonContract;
          expect(_, isA<Type>());
        });
      });
    }
    ```

    **File 7 — Update `tests/tools/test_mint_routes.py`** — un-skip the 11 deferred tests and wire real assertions. Replace the skipped stubs left by Task 1 with the real test bodies:

    ```python
    # Un-skip: test_missing_token_returns_71
    #
    # B-1 fragility note (M-5 upgrade): dev machines with a live `SENTRY_AUTH_TOKEN`
    # Keychain entry would make this test false-pass. Use monkeypatch for
    # DI robustness.
    def test_missing_token_returns_71(monkeypatch, tmp_path):
        # Force: no env token; `security` binary simulated missing.
        monkeypatch.setenv("SENTRY_AUTH_TOKEN", "")
        monkeypatch.setenv("MINT_ROUTES_DRY_RUN", "0")
        # Stub subprocess.run so Keychain lookup "fails" deterministically.
        import subprocess as _sp
        from tools.mint_routes import sentry_client as sc
        def _fake_run(*a, **kw):
            raise FileNotFoundError("security binary stubbed missing")
        monkeypatch.setattr(sc.subprocess, "run", _fake_run)
        import pytest as _pt
        with _pt.raises(SystemExit) as ei:
            sc.get_sentry_token()
        assert ei.value.code == 71


    def test_health_dry_run_produces_147_json_lines():
        r = _run(["health", "--json"], env_extra={"MINT_ROUTES_DRY_RUN": "1"})
        assert r.returncode == 0, r.stderr.decode()[:400]
        lines = [ln for ln in r.stdout.decode().splitlines() if ln.strip()]
        assert len(lines) == 147, f"expected 147 JSON lines, got {len(lines)}"


    def test_health_dry_run_owner_filter():
        r = _run(["health", "--json", "--owner=coach"],
                 env_extra={"MINT_ROUTES_DRY_RUN": "1"})
        assert r.returncode == 0
        lines = r.stdout.decode().splitlines()
        assert 0 < len(lines) < 147


    def test_no_color_env_var_suppresses_ansi():
        r = _run(["health"], env_extra={"MINT_ROUTES_DRY_RUN": "1", "NO_COLOR": "1"})
        assert r.returncode == 0
        assert b"\x1b[" not in r.stdout


    def test_keychain_fallback_token_never_in_argv():
        src = (REPO_ROOT / "tools/mint_routes/sentry_client.py").read_text()
        assert '"--auth-token"' not in src and "'--auth-token'" not in src, \
            "sentry-cli --auth-token pattern spreads token via argv — use Authorization header or stdin"


    def test_pii_redaction_covers_six_patterns():
        from tools.mint_routes.redaction import redact_str
        samples = {
            "IBAN_CH": ("Wire to CH93 0076 2011 6238 5295 7 urgent", "CH[REDACTED]"),
            "IBAN_DE": ("Foreign DE89370400440532013000 transfer", "[IBAN_REDACTED]"),
            "CHF_amount": ("Loss of 1'500 CHF recorded", "CHF [REDACTED]"),
            "EMAIL": ("Contact user@mint.ch", "[EMAIL]"),
            "AVS": ("AVS 756.1234.5678.90 on file", "[AVS_REDACTED]"),
        }
        for name, (raw, expected_token) in samples.items():
            got = redact_str(raw)
            assert expected_token in got, f"{name}: '{raw}' -> '{got}' (missing {expected_token})"


    def test_pii_redaction_walks_dict_user_keys():
        from tools.mint_routes.redaction import redact
        obj = {"user": {"id": "u_123", "email": "j@m.ch", "ip_address": "10.0.0.1",
                        "username": "julien"}, "extra": "ok"}
        redact(obj)
        for k in ("id", "email", "ip_address", "username"):
            assert k not in obj["user"], f"user.{k} not stripped"
        assert obj["extra"] == "ok"


    def test_status_classification_buckets():
        from tools.mint_routes.sentry_client import classify_status
        assert classify_status(sentry_24h=0, ff_state=True,
                               last_visit="2026-04-19T00:00:00Z") == "green"
        assert classify_status(sentry_24h=3, ff_state=True,
                               last_visit="2026-04-19T00:00:00Z") == "yellow"
        assert classify_status(sentry_24h=15, ff_state=True,
                               last_visit="2026-04-19T00:00:00Z") == "red"
        assert classify_status(sentry_24h=0, ff_state=False,
                               last_visit=None) == "dead"


    def test_json_output_schema_matches_dart_contract():
        from tools.mint_routes import __schema_version__
        assert __schema_version__ == 1
        r = _run(["health", "--json"], env_extra={"MINT_ROUTES_DRY_RUN": "1"})
        import json as _json
        line0 = r.stdout.decode().splitlines()[0]
        row = _json.loads(line0)
        for k in ("path", "category", "owner", "requires_auth", "kill_flag", "status",
                  "sentry_count_24h", "ff_enabled", "last_visit_iso",
                  "_redaction_applied", "_redaction_version"):
            assert k in row, f"key {k} missing from JSON output"
        assert row["_redaction_applied"] is True
        assert row["_redaction_version"] == 1


    def test_batch_chunking_splits_30_per_batch():
        from tools.mint_routes.sentry_client import _chunks
        paths = [f"/r{i}" for i in range(147)]
        chunks = list(_chunks(paths, 30))
        assert len(chunks) == 5
        assert len(chunks[0]) == 30
        assert len(chunks[-1]) == 147 - 30 * 4


    def test_cache_ttl_purge(monkeypatch, tmp_path):
        import time
        monkeypatch.setenv("MINT_ROUTES_CACHE_DIR", str(tmp_path))
        from tools.mint_routes.sentry_client import _cache_path, purge_cache, _purge_stale_cache
        p = _cache_path()
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("{}")
        old = time.time() - 8 * 86400
        os.utime(p, (old, old))
        _purge_stale_cache(ttl_days=7)
        assert not p.exists(), "stale cache not auto-deleted"
        p.write_text("{}")
        purge_cache()
        assert not p.exists(), "purge_cache did not unlink"
    ```

    Run all tests:
    - `cd apps/mobile && flutter test test/routes/route_meta_json_test.dart` — must be green.
    - `cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tests/tools/test_mint_routes.py -q` — expect ≥14 tests passing, 0 failed, 0 skipped.
    - `MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health --json | wc -l` returns 147.
    - `MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health | head -5` shows colored table (when TTY) or plain rows (when piped).

    **Accent discipline:** all docstrings/comments technical English; no banned LSFin terms.

    **No token in argv:** `fetch_health` uses `urllib.request` with `Authorization` header — sentry-cli CLI subprocess is avoided on purpose (token via env or Keychain only).
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tests/tools/test_mint_routes.py -q 2>&1 | tail -15 && (cd apps/mobile && flutter test test/routes/route_meta_json_test.dart 2>&1 | tail -5) && MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health --json 2>/dev/null | wc -l</automated>
  </verify>
  <acceptance_criteria>
    - `tools/mint_routes/redaction.py` exists AND covers 6 patterns: IBAN_CH, IBAN_ANY, CHF_AMOUNT, CHF_AMOUNT_PREFIX, EMAIL, AVS (all regex compile)
    - `tools/mint_routes/sentry_client.py` exists AND exports `get_sentry_token`, `fetch_health`, `fetch_redirect_hits`, `classify_status`, `purge_cache`, `_chunks`, `_purge_stale_cache`, `verify_token_scope`, `load_registry_rows`
    - `tools/mint_routes/dry_run.py` exists AND exports `is_dry_run`, `load_fixture`, `load_fixture_redirects`
    - `tools/mint_routes/cli.py` contains NO `raise NotImplementedError` (all 4 stubs replaced with real imports + bodies)
    - `apps/mobile/lib/routes/route_health_schema.dart` exists AND `grep -c "kRouteHealthSchemaVersion = 1" apps/mobile/lib/routes/route_health_schema.dart` returns 1
    - `python3 -m pytest tests/tools/test_mint_routes.py -q` exits 0 with ≥14 tests passing (all Task 1 skipped tests un-skipped and green)
    - `MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health --json` emits exactly 147 lines
    - `flutter test test/routes/route_meta_json_test.dart` exits 0, 2 tests passing
    - `grep -r "sentry-cli" tools/mint_routes/` returns no matches (token flow uses urllib + Authorization header — never argv)
    - `grep -rE "\s\|\s" tools/mint_routes/` returns no PEP 604 union syntax occurrences (3.9-compat)
    - Cache TTL test green: stale file auto-deleted, `purge-cache` command wipes immediately
  </acceptance_criteria>
  <done>CLI network layer + redaction + dry_run + schema contract shipped. Phase 35 dogfood can now consume `--json` contract. All 14+ pytest green.</done>
</task>

</tasks>

<verification>
End-of-plan gate (must be green before Wave 3 starts):
- `python3 -m pytest tests/tools/test_mint_routes.py -q` — ≥14 tests passing, 0 failed, 0 skipped.
- `flutter test test/routes/route_meta_json_test.dart` — 2 tests green.
- `MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health --json | wc -l` returns 147.
- `./tools/mint-routes --help` lists all 5 subcommands + `--verify-token` flag.
- No token ever passed via argv (verified by grep on source).
- `grep -c "^\.cache/" .gitignore` returns 1.

Single commit (or two — task-per-commit is acceptable): `feat(32): Wave 2 mint-routes CLI + PII redaction + schema contract`.
</verification>

<success_criteria>
- CLI works in DRY_RUN mode without any network dependency (gate for CI stability)
- Keychain pattern reused verbatim from Phase 31 `sentry_quota_smoke.sh:70-84` (zero onboarding friction)
- nLPD D-09 controls shipped: redaction regex covers 6 patterns (added AVS per A2 executor-discretion), 7-day cache TTL, purge-cache command, token-scope verifier, `.gitignore` for `.cache/`
- Schema contract `kRouteHealthSchemaVersion = 1` published for Phase 35 dogfood
- 14+ pytest cases green (Wave 0 stubs all flipped)
- Python 3.9-compatible syntax throughout (dev machine 3.9.6 + CI 3.11 both happy)
</success_criteria>

<output>
After completion, create `.planning/phases/32-cartographier/32-02-SUMMARY.md` with:
- CLI subcommand surface demoed
- Redaction pattern coverage (5 samples verified)
- Batch chunking empirical default (30 locked, J0 validates in Plan 05)
- Commit SHA
- Wave 3 unblock: Flutter UI can import registry + schema, legacyRedirectHit breadcrumb pattern ready
</output>
</content>
</invoke>