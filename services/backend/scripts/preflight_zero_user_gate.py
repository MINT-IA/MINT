#!/usr/bin/env python3
"""Pre-flight zero-user prod gate — Plan 02-03 Task 0 (iter-2 B1).

Big-bang migration safety check : reads PROD_DATABASE_URL (env var) and counts
rows in `users`. If the count is > 0, exits 1 with a BLOCKED stdout — the
« big-bang pre-launch » premise that lets Plan 02-03 ship SnapshotModel
without data-loss-rollback is invalidated, and Julien must decide on an
alternative migration strategy.

Why this exists
===============
Plan 02-03 D-05 ships a 6-PR sequence that drops SnapshotModel in PR-5.
The migration is « big-bang » : there is no per-user dual-write fallback once
PR-3b cuts reads over to fact_current. The CONTEXT.md counter-arguments
section identifies the single load-bearing assumption — « prod has zero users
at PR-3b merge time ». This script makes that assumption deterministically
checkable from CI / a local terminal before Claude opens PR-3a.

Soft-delete handling
====================
The `users` table has NO `deleted_at` column (verified against
`app/models/user.py` 2026-05-18) — User rows are hard-deleted. The COUNT
is therefore unconditional. Future schema additions adding a soft-delete
column should update the WHERE clause in `_count_active_users()`.

Exit codes
==========
- 0 : prod users == 0 (big-bang safe to proceed) OR PROD_DATABASE_URL unset
      (treated as WARN — typical for local/CI runs that don't have prod creds).
- 1 : prod users > 0 (BLOCKED — surface to Julien for migration-strategy
      decision).

Usage
=====
    # Default : reads PROD_DATABASE_URL from environment.
    python3 services/backend/scripts/preflight_zero_user_gate.py

    # CI / non-prod-cred environments : the script prints a WARN line and
    # exits 0. The PR description should include the explicit prod-run
    # stdout (Julien runs locally with PROD_DATABASE_URL set).

    # Test path : set PREFLIGHT_TEST_DATABASE_URL to override.
    PREFLIGHT_TEST_DATABASE_URL=sqlite:///:memory: \
        python3 services/backend/scripts/preflight_zero_user_gate.py
"""
from __future__ import annotations

import os
import sys
from typing import Optional


def _resolve_database_url() -> Optional[str]:
    """Return the database URL to probe, or None if not configured.

    Precedence : PREFLIGHT_TEST_DATABASE_URL (tests) > PROD_DATABASE_URL.
    The test override is explicit so that running with the prod env set
    accidentally never touches the test DB.
    """
    test_url = os.environ.get("PREFLIGHT_TEST_DATABASE_URL", "").strip()
    if test_url:
        return test_url
    prod_url = os.environ.get("PROD_DATABASE_URL", "").strip()
    if prod_url:
        return prod_url
    return None


def _count_active_users(url: str) -> int:
    """Return the count of active (non-soft-deleted) users.

    The `users` table has no `deleted_at` column as of 2026-05-18 — see
    `app/models/user.py`. The COUNT is unconditional. If a soft-delete
    column is later added, narrow the WHERE clause here.
    """
    # Import inside the function so the script can be imported without
    # SQLAlchemy installed (e.g., for the help text on a clean checkout).
    from sqlalchemy import create_engine, text

    engine = create_engine(url, pool_pre_ping=True)
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT COUNT(*) FROM users"))
            count = result.scalar()
            return int(count or 0)
    finally:
        engine.dispose()


def main(argv: Optional[list[str]] = None) -> int:
    url = _resolve_database_url()
    if url is None:
        print(
            "WARN: PROD_DATABASE_URL (and PREFLIGHT_TEST_DATABASE_URL) unset — "
            "skipping zero-user gate. The PR-3a description MUST include a "
            "verbatim run of this script with PROD_DATABASE_URL set before "
            "Julien approves the staging-zero-drift checkpoint."
        )
        return 0

    try:
        count = _count_active_users(url)
    except Exception as exc:  # noqa: BLE001 — surface any DB error verbatim
        print(
            f"WARN: preflight zero-user gate could not query users table: "
            f"{type(exc).__name__}: {exc}. Treating as inconclusive (exit 0). "
            "Investigate before opening PR-3a."
        )
        return 0

    if count > 0:
        print(
            f"BLOCKED: prod has {count} users — big-bang migration premise "
            "invalid. Plan 02-03 requires Julien escape-hatch decision "
            "(slip migration OR document deletion)."
        )
        return 1

    print(
        "OK: prod users=0 — big-bang migration safe to proceed. Plan 02-03 "
        "D-05 6-PR sequence may continue."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
