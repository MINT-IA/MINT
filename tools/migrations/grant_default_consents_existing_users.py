#!/usr/bin/env python3
"""Phase 97.5 W2-T6 — backfill default consents for pre-granular-T&C users.

For every user with `email_verified=True` (the v2.9 proxy for « accepted T&C
implicitly at registration » — see julien-go 2026-05-12 + 97.5-PLAN.md §D.7
+ the consent perimeter receipt « Data gaps surfaced » section) who lacks a
grant for TRANSFER_US_ANTHROPIC or PERSISTENCE_365D, insert a nominative
grant with `basis="legal-continuity-pre-granular-T&C"`.

Cohort proxy rationale (W2-CONSENT-RECEIPT §Data-gaps) :
    The `users` table has NO `accepted_terms_at` column (verified via
    `grep -rn "accepted_terms_at" services/backend/app/` → 0 hits). The
    Phase 29.02 T&C-acceptance UX requires email verification as a
    prerequisite, so `email_verified=True` is the principled empirical
    proxy for « real registered users who reached T&C acceptance ».
    The `basis="legal-continuity-pre-granular-T&C"` field on each new
    receipt makes it auditable that these grants are admin-backfilled,
    not user-initiated, per LSFin Art 8 traceability.

Idempotent : re-runs are no-op. `ConsentService.grant_with_basis(...)` calls
`has_active_grant(...)` first and short-circuits to None if already granted.

Usage :
    # dry-run (no DB writes ; prints what WOULD be granted)
    python3 tools/migrations/grant_default_consents_existing_users.py --dry-run

    # live run against staging (REQUIRED guard rail per 97.5-PLAN.md §D.7)
    DATABASE_URL=<staging> \\
      python3 tools/migrations/grant_default_consents_existing_users.py \\
      --confirm staging

Exit codes :
    0 — success (dry-run or live)
    2 — refused : non-dry-run without `--confirm staging`
"""
from __future__ import annotations

import argparse
import logging
import sys
from typing import Iterable

# Make `app.*` importable when running from repo root (the standard usage
# per the README). Equivalent to `cd services/backend && python3 -m tools...`
# but simpler for operators who clone + run from repo root.
import os
_BACKEND_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "services",
    "backend",
)
if os.path.isdir(_BACKEND_DIR) and _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)

from app.core.database import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402
from app.schemas.consent_receipt import ConsentPurpose  # noqa: E402
from app.services.consent.consent_service import consent_service  # noqa: E402

logger = logging.getLogger("mint.consent.backfill")

# Purposes to backfill per julien-go scope cut + 97.5-PLAN.md §D.7.
# couple_projection + vision_extraction stay opt-in (no legal-continuity
# basis for them — they're per-feature, not always-on).
_BACKFILL_PURPOSES = (
    ConsentPurpose.TRANSFER_US_ANTHROPIC,
    ConsentPurpose.PERSISTENCE_365D,
)

# Default policy version applied to backfilled receipts. Matches the
# default in `ConsentService.grant_nominative` and `receipt_builder.py`
# header — kept consistent so audit-tooling can distinguish v2.9-shipped
# backfills from manual operator grants by inspecting `policy_version` ×
# `receipt_json.basis`.
_DEFAULT_POLICY_VERSION = "v2.3.0"

# Basis string written into `receipt_json.basis` on every backfilled row.
# Audit queries can grep for this exact string to enumerate the cohort.
_BACKFILL_BASIS = "legal-continuity-pre-granular-T&C"


def _iter_users_to_backfill(db) -> Iterable[User]:
    """Yield users in the backfill cohort.

    Cohort = `email_verified=True`. Matches the existing pattern in
    `app/services/auth_admin_service.py:35` + line 195
    (`User.email_verified.is_(True)`).
    """
    return db.query(User).filter(User.email_verified.is_(True)).yield_per(500)


def run_backfill(*, dry_run: bool) -> tuple[int, int]:
    """Execute the backfill. Returns (granted, skipped).

    Opens a single DB session ; closes it before returning. Caller handles
    the CLI guard (`--confirm staging`).
    """
    granted = 0
    skipped = 0
    db = SessionLocal()
    try:
        for user in _iter_users_to_backfill(db):
            for purpose in _BACKFILL_PURPOSES:
                if consent_service.has_active_grant(
                    db, user_id=str(user.id), purpose=purpose
                ):
                    skipped += 1
                    continue
                if dry_run:
                    print(
                        f"WOULD GRANT user={user.id} "
                        f"purpose={purpose.value} basis={_BACKFILL_BASIS}"
                    )
                else:
                    consent_service.grant_with_basis(
                        db,
                        user_id=str(user.id),
                        purpose=purpose,
                        policy_version=_DEFAULT_POLICY_VERSION,
                        basis=_BACKFILL_BASIS,
                    )
                granted += 1
    finally:
        db.close()
    return granted, skipped


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Backfill default consent grants for pre-granular-T&C users. "
            "See 97.5-PLAN.md §D.7 + W2-CONSENT-RECEIPT."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print WOULD GRANT lines without touching the DB.",
    )
    parser.add_argument(
        "--confirm",
        default="",
        help=(
            "Required for non-dry-run execution. Must equal 'staging' "
            "(refuses to run against prod URL implicitly — operator must "
            "set DATABASE_URL to staging in their env)."
        ),
    )
    args = parser.parse_args(argv)

    if not args.dry_run and args.confirm != "staging":
        sys.stderr.write(
            "ERROR: live run requires `--confirm staging` "
            "(use `--dry-run` to preview without writes).\n"
        )
        return 2

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    granted, skipped = run_backfill(dry_run=args.dry_run)
    print(
        f"summary: granted={granted} skipped={skipped} dry_run={args.dry_run}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
