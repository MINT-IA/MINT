#!/usr/bin/env bash
# tools/simulator/trace_round_trip_test.sh — Phase 31 OBS-04 (b) integration.
#
# WAVE 0: asserts the staging backend emits X-Trace-Id on responses
# (baseline — LoggingMiddleware existing behaviour at
# services/backend/app/core/logging_config.py:85-103).
#
# WAVE 2 Plan 31-02 extends this to assert equality with the inbound
# sentry-trace header (OBS-03 c). Do not tighten the assertion until
# the backend handler actually reads inbound sentry-trace.
#
# Usage:
#   bash tools/simulator/trace_round_trip_test.sh
#
# Exit codes:
#   0  X-Trace-Id header present and non-empty on the staging response
#   1  header missing / empty / curl failed
#
set -euo pipefail

TRACE_ID="$(openssl rand -hex 16)"
SPAN_ID="$(openssl rand -hex 8)"
SENTRY_TRACE="${TRACE_ID}-${SPAN_ID}-1"

URL="https://mint-staging.up.railway.app/api/v1/health"

echo "[trace_round_trip] curl ${URL} sentry-trace=${SENTRY_TRACE}"

# -s silent, -i include headers, -S show errors; timeout-bounded.
RESPONSE="$(curl -sS -i --max-time 15 \
  -H "sentry-trace: ${SENTRY_TRACE}" \
  "${URL}" || true)"

# Case-insensitive header grep.
TRACE_LINE="$(printf '%s\n' "$RESPONSE" | awk 'BEGIN{IGNORECASE=1} /^x-trace-id:/{print; exit}')"

if [ -z "$TRACE_LINE" ]; then
  echo "[FAIL] X-Trace-Id header absent from response" >&2
  echo "--- response head ---" >&2
  printf '%s\n' "$RESPONSE" | head -n 20 >&2
  exit 1
fi

# Strip "X-Trace-Id: " prefix + CR.
VALUE="$(printf '%s\n' "$TRACE_LINE" | sed -E 's/^[Xx]-[Tt]race-[Ii]d:\s*//' | tr -d '\r\n ')"

if [ -z "$VALUE" ]; then
  echo "[FAIL] X-Trace-Id header present but empty" >&2
  exit 1
fi

echo "[PASS] X-Trace-Id=${VALUE} (inbound sentry-trace_id=${TRACE_ID})"
# WAVE 2 will add: [ "$VALUE" = "$TRACE_ID" ] || fail
exit 0
