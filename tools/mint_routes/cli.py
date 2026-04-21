"""argparse subcommand dispatch for mint-routes.

Task 1 scope: CLI skeleton only. Subcommand handlers that need the network
layer raise NotImplementedError; Task 2 wires sentry_client + dry_run.

Python 3.9-compatible — Optional/Union/List/Dict from typing, no X | Y unions,
no match/case, no dict | dict merge.
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
    p.add_argument(
        "--no-color",
        action="store_true",
        help="Suppress ANSI color codes (no-color.org).",
    )
    p.add_argument(
        "--verify-token",
        action="store_true",
        help=(
            "Query Sentry auth endpoint; exit 78 if scope exceeds "
            "project:read + event:read."
        ),
    )

    sub = p.add_subparsers(dest="command")

    h = sub.add_parser(
        "health",
        help="Show per-route health status (green/yellow/red/dead).",
    )
    h.add_argument(
        "--json",
        action="store_true",
        help="Emit newline-delimited JSON.",
    )
    h.add_argument(
        "--batch-size",
        type=int,
        default=30,
        help="Sentry OR-query batch size (default 30, D-11 J0 validates).",
    )
    h.add_argument(
        "--owner",
        type=str,
        default=None,
        help="Filter by RouteOwner value (e.g., coach, scan).",
    )

    r = sub.add_parser(
        "redirects",
        help="Aggregate legacy_redirect.hit breadcrumb counts over N days.",
    )
    r.add_argument("--json", action="store_true")
    r.add_argument("--days", type=int, default=30)

    sub.add_parser(
        "reconcile",
        help="Run tools/checks/route_registry_parity.py + show diff.",
    )
    sub.add_parser(
        "purge-cache",
        help="Delete .cache/route-health.json immediately (D-09 §3).",
    )

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

    # --verify-token is a top-level flag action.
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
    from .dry_run import is_dry_run, load_fixture
    from .output import render_health
    from .sentry_client import fetch_health, get_sentry_token

    if is_dry_run():
        data = load_fixture()
    else:
        token = get_sentry_token()  # exits 71 if missing
        data = fetch_health(token=token, batch_size=args.batch_size)
    if args.owner:
        data = [r for r in data if r.get("owner") == args.owner]
    return render_health(data, as_json=args.json, use_color=_should_color(args))


def _cmd_redirects(args: argparse.Namespace) -> int:
    from .dry_run import is_dry_run, load_fixture_redirects
    from .output import render_redirects
    from .sentry_client import fetch_redirect_hits, get_sentry_token

    if is_dry_run():
        data = load_fixture_redirects()
    else:
        token = get_sentry_token()
        data = fetch_redirect_hits(token=token, days=args.days)
    return render_redirects(
        data, as_json=args.json, use_color=_should_color(args)
    )


def _cmd_reconcile(args: argparse.Namespace) -> int:
    import subprocess

    lint = (
        Path(__file__).resolve().parents[2]
        / "tools/checks/route_registry_parity.py"
    )
    if not lint.exists():
        sys.stderr.write(
            "[WARN] tools/checks/route_registry_parity.py not yet shipped "
            "(Plan 32-04). Reconcile is a no-op until Wave 4 lands.\n"
        )
        return EX_OK
    r = subprocess.run(["python3", str(lint)], capture_output=False)
    return r.returncode


def _cmd_purge_cache(args: argparse.Namespace) -> int:
    from .sentry_client import purge_cache

    purge_cache()
    print("[OK] .cache/route-health.json wiped (D-09 §3).")
    return EX_OK


def _cmd_verify_token(args: argparse.Namespace) -> int:
    from .sentry_client import get_sentry_token, verify_token_scope

    token = get_sentry_token()
    return verify_token_scope(token)


def _should_color(args: argparse.Namespace) -> bool:
    if args.no_color:
        return False
    if os.environ.get("NO_COLOR"):
        return False
    return sys.stdout.isatty()
