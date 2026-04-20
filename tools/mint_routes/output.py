"""ANSI coloring + JSON newline-delimited output for mint-routes.

Python 3.9-compatible. No external dependencies (stdlib only).
"""
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


def render_health(
    rows: List[Dict[str, Any]],
    as_json: bool,
    use_color: bool,
) -> int:
    if as_json:
        for row in rows:
            sys.stdout.write(
                json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n"
            )
        return 0
    # Terminal view
    for row in rows:
        status = row.get("status", "unknown")
        path = row.get("path", "?")
        owner = row.get("owner", "?")
        count = row.get("sentry_count_24h", 0)
        line = "{:<8} {:<45} {:<12} {:>4}".format(status, path, owner, count)
        if use_color:
            color = _STATUS_COLOR.get(status, "")
            line = "{}{}{}".format(color, line, ANSI_RESET)
        sys.stdout.write(line + "\n")
    return 0


def render_redirects(
    rows: List[Dict[str, Any]],
    as_json: bool,
    use_color: bool,
) -> int:
    if as_json:
        for row in rows:
            sys.stdout.write(
                json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n"
            )
        return 0
    for row in rows:
        sys.stdout.write(
            "{:<30} -> {:<30} hits={:>4}\n".format(
                row.get("from", "?"),
                row.get("to", "?"),
                row.get("count_30d", 0),
            )
        )
    return 0
