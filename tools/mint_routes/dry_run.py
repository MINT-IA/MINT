"""DRY_RUN fixture harness (MINT_ROUTES_DRY_RUN=1).

Python 3.9-compatible. Reads
`tests/tools/fixtures/sentry_health_response.json` and joins with the
registry rows parsed from `apps/mobile/lib/routes/route_metadata.dart`.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List

_FIXTURE = (
    Path(__file__).resolve().parents[2]
    / "tests/tools/fixtures/sentry_health_response.json"
)


def is_dry_run() -> bool:
    return os.environ.get("MINT_ROUTES_DRY_RUN") == "1"


def load_fixture() -> List[Dict[str, Any]]:
    """Load 147-entry DRY_RUN fixture + join with registry rows.

    Fixture shape: `{"_meta": {...}, "issues": [{"transaction": ..., ...}]}`.
    """
    raw = _FIXTURE.read_text()
    data = json.loads(raw)
    # Import lazily to avoid circular import with sentry_client at module load.
    from .sentry_client import classify_status, load_registry_rows

    registry = load_registry_rows()
    index = {i["transaction"]: i for i in data.get("issues", [])}
    rows: List[Dict[str, Any]] = []
    for meta in registry:
        issue = index.get(
            meta["path"], {"count_24h": 0, "last_seen": None}
        )
        rows.append(
            {
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
            }
        )
    return rows


def load_fixture_redirects() -> List[Dict[str, Any]]:
    """Minimal redirect fixture for DRY_RUN mode (3 legacy redirects)."""
    return [
        {"from": "/report", "to": "/rapport", "count_30d": 12},
        {"from": "/report/v2", "to": "/rapport", "count_30d": 5},
        {"from": "/profile", "to": "/profile/bilan", "count_30d": 87},
    ]
