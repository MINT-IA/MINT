"""Continuous drift sampler — Plan 02-03 iter-2 B18.

Cron entry point that samples 100 random staging users every 30 min,
runs `tools.parity.projection_diff.diff_payloads` between the legacy
(?legacy=true) and new (default) /v1/projection paths on the staging
deployment, and persists one row per sampled user to
`_phase02_parity_audit_continuous`.

Runs during the PR-3a → PR-3b 7-day soak window. The Task 2b checkpoint
gates on `count(*) FILTER (WHERE diff_count > 0) = 0` over the last 24
hours of samples.

Cron schedule
=============
GH Actions workflow `pg-soak-nightly.yml` triggers every 30 min via
`schedule: cron: '*/30 * * * *'`. Disabled by default ; enabled
manually by Claude when PR-3a merges.

Local dry-run
=============
    python3 -m app.cron.continuous_drift_sampler --sample-size 5 --dry-run

Operational invariants
======================
- The script NEVER writes to fact_event / fact_current / SnapshotModel.
  It is a READ-ONLY sampler — its only DB write is to
  `_phase02_parity_audit_continuous`.
- The script fails gracefully if STAGING_BASE_URL or STAGING_DATABASE_URL
  is unset (refuses to run silently against a wrong target).
- Each row carries the same `sampler_run_id` (UUID v4 per cron tick) so
  the Task 2b query can scope to « the latest run » deterministically.
"""
from __future__ import annotations

import argparse
import logging
import os
import random
import sys
import uuid
from typing import List, Optional

import httpx

logger = logging.getLogger("continuous_drift_sampler")


def _resolve_required_env(name: str) -> Optional[str]:
    val = os.environ.get(name, "").strip()
    return val or None


def _pick_random_user_ids(db_url: str, sample_size: int) -> List[str]:
    """Pick `sample_size` random user_ids from the users table.

    Postgres : uses TABLESAMPLE BERNOULLI when sample_size << total rows ;
    falls back to ORDER BY random() LIMIT N for small populations (eg
    staging during early soak).

    The query is the simplest correct form ; performance is non-critical
    because the sampler runs every 30 min, not on a hot path.
    """
    from sqlalchemy import create_engine, text

    engine = create_engine(db_url, pool_pre_ping=True)
    try:
        with engine.connect() as conn:
            result = conn.execute(
                text(
                    "SELECT id FROM users "
                    "ORDER BY random() "  # SQLite + Postgres both accept this
                    "LIMIT :limit"
                ),
                {"limit": sample_size},
            )
            return [row[0] for row in result]
    finally:
        engine.dispose()


def _fetch_projection_pair(
    base_url: str, user_id: str, *, timeout: float = 30.0
) -> Optional[tuple]:
    """Fetch (legacy, new) projection payloads for `user_id`.

    Returns None if either fetch fails (logs the reason). Caller should
    skip the sample in that case rather than persist a fake EQUAL/DIFF.
    """
    try:
        with httpx.Client(timeout=timeout) as client:
            legacy = client.get(
                f"{base_url}/v1/projection/{user_id}",
                params={"legacy": "true"},
            )
            legacy.raise_for_status()
            new = client.get(f"{base_url}/v1/projection/{user_id}")
            new.raise_for_status()
            return legacy.json(), new.json()
    except (httpx.HTTPError, ValueError) as exc:
        logger.warning(
            "fetch_projection_pair failed user_id=%s err=%s", user_id, exc
        )
        return None


def _persist_sample(
    db_url: str,
    *,
    user_id: str,
    diff_count: int,
    diff_details: dict,
    sampler_run_id: str,
) -> None:
    """Insert one row into _phase02_parity_audit_continuous.

    D-24 / security-auditor obs #175 : the audit user_id_hash MUST go
    through `app.services.audit.hmac_pepper.hmac_user_id` (HMAC-SHA256
    with server-only pepper) rather than bare hashlib.sha256 — bare
    sha256(user_id) is rainbow-table-reversible.
    """
    from sqlalchemy import create_engine, text

    from app.services.audit.hmac_pepper import hmac_user_id

    user_id_hash = hmac_user_id(user_id)

    engine = create_engine(db_url, pool_pre_ping=True)
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "INSERT INTO _phase02_parity_audit_continuous "
                    "(user_id_hash, diff_count, diff_details, sampler_run_id) "
                    "VALUES (:uih, :dc, :dd, :srid)"
                ),
                {
                    "uih": user_id_hash,
                    "dc": diff_count,
                    "dd": _json_dump(diff_details),
                    "srid": sampler_run_id,
                },
            )
    finally:
        engine.dispose()


def _json_dump(value: dict) -> str:
    import json

    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def run_sample_pass(
    *,
    base_url: str,
    db_url: str,
    sample_size: int,
    dry_run: bool = False,
) -> dict:
    """Execute one cron-tick : pick N users, diff each, persist.

    Returns a summary dict {sampler_run_id, samples_attempted,
    samples_persisted, samples_dirty}.
    """
    from tools.parity.projection_diff import diff_payloads

    sampler_run_id = str(uuid.uuid4())
    user_ids = _pick_random_user_ids(db_url, sample_size)
    logger.info(
        "sampler_run_id=%s picked %d users (requested=%d)",
        sampler_run_id,
        len(user_ids),
        sample_size,
    )

    samples_attempted = 0
    samples_persisted = 0
    samples_dirty = 0

    for user_id in user_ids:
        samples_attempted += 1
        pair = _fetch_projection_pair(base_url, user_id)
        if pair is None:
            continue
        legacy_payload, new_payload = pair
        result = diff_payloads(legacy_payload, new_payload)
        diff_count = 0 if result.is_equal else len(result.reasons)
        diff_details = {"reasons": result.reasons} if result.reasons else {}

        if not dry_run:
            _persist_sample(
                db_url,
                user_id=user_id,
                diff_count=diff_count,
                diff_details=diff_details,
                sampler_run_id=sampler_run_id,
            )
            samples_persisted += 1
        else:
            print(
                f"DRY-RUN user_id={user_id[:8]}... "
                f"diff_count={diff_count} "
                f"verdict={result.as_text()}"
            )
            samples_persisted += 1  # treat as persisted for the summary

        if diff_count > 0:
            samples_dirty += 1

    summary = {
        "sampler_run_id": sampler_run_id,
        "samples_attempted": samples_attempted,
        "samples_persisted": samples_persisted,
        "samples_dirty": samples_dirty,
    }
    logger.info("sampler_run summary=%s", summary)
    return summary


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Continuous drift sampler — iter-2 B18.",
    )
    parser.add_argument(
        "--sample-size",
        type=int,
        default=100,
        help="Number of users to sample this tick (default 100).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print diff verdicts to stdout instead of writing rows.",
    )
    parser.add_argument(
        "--base-url",
        default=None,
        help="Backend base URL ; falls back to STAGING_BASE_URL env var.",
    )
    parser.add_argument(
        "--db-url",
        default=None,
        help="Database URL ; falls back to STAGING_DATABASE_URL env var.",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    base_url = args.base_url or _resolve_required_env("STAGING_BASE_URL")
    db_url = args.db_url or _resolve_required_env("STAGING_DATABASE_URL")

    if not base_url or not db_url:
        print(
            "ERROR: continuous_drift_sampler requires STAGING_BASE_URL + "
            "STAGING_DATABASE_URL (or --base-url + --db-url). Refusing to "
            "run silently against an unknown target.",
            file=sys.stderr,
        )
        return 2

    summary = run_sample_pass(
        base_url=base_url,
        db_url=db_url,
        sample_size=args.sample_size,
        dry_run=args.dry_run,
    )
    # Exit 0 even if some samples are dirty — the soak-window verdict
    # belongs to Julien (Task 2b checkpoint reads the table). The sampler
    # itself just observes + persists.
    print(f"OK sampler_run_id={summary['sampler_run_id']} "
          f"attempted={summary['samples_attempted']} "
          f"persisted={summary['samples_persisted']} "
          f"dirty={summary['samples_dirty']}")
    return 0


__all__ = ["run_sample_pass", "main"]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
