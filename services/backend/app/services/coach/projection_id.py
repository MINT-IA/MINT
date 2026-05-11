"""Phase 95 DAG-INVALIDATION — UUID7 wrapper for projection supersession chain.

Per CONTEXT D-04 + RESEARCH §D-04 correction :
- stdlib `uuid.uuid7()` is Python 3.14+ (NOT 3.12 as the architect panel
  claimed). Railway base image is `python:3.12-slim` (Dockerfile lines 6
  + 22). Use `uuid_utils.uuid7()` backport (Rust-backed, BSD-3-Clause,
  drop-in API, 16x faster than pure-Python backports).
- Migration path : when Railway upgrades to python:3.14-slim, swap
  `import uuid_utils` for stdlib `import uuid`. The `.uuid7()` API is
  identical.

UUID7 is RFC 9562 compliant : first 48 bits = ms since Unix epoch, next
12 bits = sub-ms counter, last 62 bits = random. Sortability : lexical
sort equals chronological sort, so `ORDER BY superseded_by ASC` in SQL
reconstructs the supersession chain without a separate `created_at`
column.
"""
from __future__ import annotations

import uuid_utils


def new_projection_id() -> str:
    """Return a fresh UUID7 as canonical 36-char hyphenated string.

    Use this whenever a projection is replaced by a newer one — the new
    projection's ID is what populates the OLD projection's
    `superseded_by` column.

    Returns:
        Lowercase hyphenated UUID7 string (e.g. `018f63d6-9ce0-7a3b-...`).
    """
    return str(uuid_utils.uuid7())


__all__ = ["new_projection_id"]
