#!/usr/bin/env bash
# mint-trace.sh — fetch backend logs for a given client-supplied request ID.
#
# Pairs with the X-MINT-Req-Id header that MintHttpClient stamps on every
# outbound call. The backend LoggingMiddleware reuses that ID as its
# trace_id_var, so this script can pull the matching server-side lines.
#
# Usage:
#   tools/debug/mint-trace.sh <req_id>
#   tools/debug/mint-trace.sh <req_id> 30m
#
# Defaults: --since=10m.
#
# Prerequisites:
#   - railway CLI:  https://docs.railway.app/develop/cli
#   - jq:           brew install jq
#   - Authenticated + linked to the staging service:
#       railway login
#       railway link    # pick mint-staging
#
# Example end-to-end loop:
#   1) Run a Maestro flow that exercises the bug.
#   2) Grep the sim for the client-side request IDs:
#        xcrun simctl spawn booted log show --last 5m \
#          --predicate 'category == "ch.mint.http"' --style compact \
#          | grep req_id=
#   3) Pull the matching backend lines:
#        tools/debug/mint-trace.sh <req_id_from_step_2>
set -euo pipefail

req_id="${1:-}"
since="${2:-10m}"

if [[ -z "$req_id" ]]; then
  echo "Usage: $0 <req_id> [since=10m]" >&2
  exit 1
fi

if ! command -v railway >/dev/null 2>&1; then
  echo "ERR: railway CLI not installed." >&2
  echo "     See https://docs.railway.app/develop/cli" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERR: jq not installed. Run: brew install jq" >&2
  exit 3
fi

# `railway logs` streams; we cap output with --since so it terminates.
# --json yields one NDJSON record per log line.
railway logs --json --since "$since" \
  | jq -r --arg id "$req_id" '
      select(.trace_id == $id) |
      "\(.timestamp // .ts // "") [\(.level // "INFO")] \(.message // .msg // "")"
    '
