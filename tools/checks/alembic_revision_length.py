#!/usr/bin/env python3
"""LINT-ALEMBIC-01 — alembic_revision_length.

Block any alembic migration whose `revision` identifier exceeds 32 chars.

Why this lint exists
====================
2026-05-12T11:14Z — Railway staging container failed to start with :

    sqlalchemy.exc.DataError: (psycopg2.errors.StringDataRightTruncation)
        value too long for type character varying(32)
    [SQL: UPDATE alembic_version
          SET version_num='p97_snapshots_fk_and_server_defaults'
          WHERE alembic_version.version_num = 'p95_dag_invalidation']

Alembic's default schema is `alembic_version (version_num VARCHAR(32)
PRIMARY KEY)`. SQLite (used by local pytest fixtures) tolerates strings
longer than 32 chars on a `VARCHAR(32)` column, so the local test suite
passed at PR time. PostgreSQL is strict — the UPDATE failed, the
migration rolled back, alembic_version stayed at the old revision,
the container failed startup, Railway healthcheck retries exhausted,
and staging served 502 to every request including
`/api/v1/health` for ~35 minutes (incident 2026-05-12T11:14Z → 11:50Z).

This lint runs at pre-commit and CI, scans every
`services/backend/alembic/versions/*.py` file for the `revision: str =`
or `revision = ` assignment, and fails on any value > 32 chars.

Behaviour
=========
- Scope : `services/backend/alembic/versions/*.py` (overridable via
  `--scope-root`).
- Exit codes :
    0 — clean (all revision ids ≤ 32 chars) OR no migration files found.
    1 — at least one revision id > 32 chars.

Single source of truth — no baseline / no grandfathering. Postgres
schema is the authority ; a long revision id can never be safe.

Per memory `feedback_ios_entitlements_block_testflight.md` + today's
incident : whenever production breaks because of a check we COULD have
done at PR time, the next perimeter is the mechanical guard. This lint
is that guard.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LINT_NAME = "alembic_revision_length"
MAX_LEN = 32  # PostgreSQL `alembic_version.version_num VARCHAR(32)`.
REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = REPO / "services" / "backend" / "alembic" / "versions"

# Matches both `revision: str = "..."` and `revision = "..."` forms.
# Captures the literal string between the quotes (single or double).
_REVISION_RE = re.compile(
    r"""^\s*revision(?:\s*:\s*str)?\s*=\s*(['"])(?P<id>[^'"]+)\1""",
    re.MULTILINE,
)


def _scan_file(path: Path) -> str | None:
    """Return the offending revision id if length > MAX_LEN, else None."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    m = _REVISION_RE.search(text)
    if m is None:
        return None  # not a revision file (env.py, __init__.py, etc.)
    rid = m.group("id")
    if len(rid) > MAX_LEN:
        return rid
    return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=(
            f"{LINT_NAME} — block alembic migrations whose revision id "
            f"exceeds {MAX_LEN} chars (PostgreSQL "
            f"alembic_version.version_num is VARCHAR({MAX_LEN}))."
        )
    )
    ap.add_argument("--scope-root", type=Path, default=DEFAULT_SCOPE)
    ap.add_argument(
        "--file",
        action="append",
        type=Path,
        default=None,
        help=(
            "Scan only these specific files (lefthook staged-files mode). "
            "When omitted, scans every .py file under --scope-root."
        ),
    )
    args = ap.parse_args(argv)

    if not args.scope_root.exists():
        print(f"INFO {LINT_NAME}: scope-root {args.scope_root} missing")
        return 0

    if args.file:
        targets = [
            f.resolve()
            for f in args.file
            if f.exists() and f.suffix == ".py"
        ]
    else:
        targets = sorted(args.scope_root.glob("*.py"))

    violations: list[tuple[str, str, int]] = []
    for path in targets:
        rid = _scan_file(path)
        if rid is not None:
            try:
                rel = path.relative_to(REPO).as_posix()
            except ValueError:
                rel = path.as_posix()
            violations.append((rel, rid, len(rid)))

    if violations:
        print(
            f"::error::{LINT_NAME}: {len(violations)} revision id(s) "
            f"longer than {MAX_LEN} chars (PostgreSQL alembic_version "
            f"VARCHAR({MAX_LEN}) limit) :"
        )
        for path, rid, length in violations:
            print(f"  {path}:")
            print(f"    revision = '{rid}' ({length} chars > {MAX_LEN})")
        print()
        print(
            "Fix: shorten the `revision` string in the affected file(s) "
            f"to {MAX_LEN} chars or fewer. Alembic resolves migrations by "
            "revision id (not filename), so the filename can stay as-is "
            "if desired."
        )
        print()
        print(
            "Why this gate : 2026-05-12 Railway staging incident — "
            "`p97_snapshots_fk_and_server_defaults` (36 chars) overflowed "
            "the Postgres column, the alembic UPDATE was rejected, the "
            "container failed to start, and staging served 502 for ~35 "
            "minutes. SQLite tolerates the overflow at pytest-time, so "
            "this defect only surfaces in production."
        )
        return 1

    print(f"OK {LINT_NAME}: scanned {len(targets)} migration(s), all ≤{MAX_LEN} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
