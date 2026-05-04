#!/usr/bin/env python3
"""Phase 31 J0 walker.sh helper — assert Sentry event round-trip.

Reads a JSON dump of `sentry-cli api /projects/mint/mint-backend/events/`
output and checks that at least one event contains the expected 32-hex
trace_id we injected via the sentry-trace header.

Match rules (ordered by specificity):
  1. event['contexts']['trace']['trace_id'] == expected_trace_id
  2. expected_trace_id substring anywhere in the event's JSON serialisation
     (catches tag/context field shifts across Sentry API versions).

Exit codes:
  0  at least 1 event matched
  1  no event matched, or input JSON unreadable, or empty events array

Usage:
    python3 tools/simulator/assert_event_round_trip.py <events.json> <trace_id>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            "usage: assert_event_round_trip.py <events.json> <trace_id>",
            file=sys.stderr,
        )
        return 1

    path = Path(argv[1])
    expected = argv[2].strip()
    if not expected:
        print("[FAIL] empty expected trace_id", file=sys.stderr)
        return 1

    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"[FAIL] cannot read {path}: {e}", file=sys.stderr)
        return 1

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[FAIL] {path} is not valid JSON: {e}", file=sys.stderr)
        return 1

    if not isinstance(data, list):
        print(
            f"[FAIL] {path} does not contain a top-level JSON list "
            f"(got {type(data).__name__})",
            file=sys.stderr,
        )
        return 1

    if not data:
        print(f"[FAIL] no Sentry events in {path}", file=sys.stderr)
        return 1

    for event in data:
        # Rule 1 — explicit trace context.
        ctx_trace = (
            event.get("contexts", {}).get("trace", {}).get("trace_id")
            if isinstance(event, dict)
            else None
        )
        if isinstance(ctx_trace, str) and ctx_trace == expected:
            print(
                f"[PASS] event {event.get('eventID', '?')} "
                f"contexts.trace.trace_id = {expected}"
            )
            return 0

        # Rule 2 — substring fallback.
        if expected in json.dumps(event, separators=(",", ":")):
            print(
                f"[PASS] event {event.get('eventID', '?') if isinstance(event, dict) else '?'} "
                f"contains trace_id {expected} in payload"
            )
            return 0

    print(
        f"[FAIL] no Sentry event matched trace_id {expected} "
        f"({len(data)} event(s) inspected)",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
