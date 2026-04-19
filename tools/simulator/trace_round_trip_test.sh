#!/usr/bin/env bash
# tools/simulator/trace_round_trip_test.sh — Phase 31 OBS-04 (b) + OBS-03
# end-to-end integration: inbound sentry-trace -> backend X-Trace-Id match.
#
# Wave 2 Plan 31-02 upgrade of the Wave 0 baseline. Asserts full
# round-trip of trace_id from mobile-side sentry-trace header to backend
# JSON body + X-Trace-Id response header on a 500 path, OR a documented
# PASS-PARTIAL when the hit endpoint only exposes the 4xx LoggingMiddleware
# path (acceptable per revision Info 7 — /_test/raise_500 endpoint is
# deferred to Phase 32+ or Phase 35).
#
# Staging target — feedback_app_targets_staging_always.md (API_BASE_URL
# non-negotiable, prod is stale).
#
# Requires: curl, openssl, python3 (stdlib json only — no jq dependency).
#
# Usage:
#   bash tools/simulator/trace_round_trip_test.sh
#
# Exit codes:
#   0  PASS or PASS-PARTIAL (see stdout)
#   1  FAIL (missing header, mismatch, or unexpected status)
#
set -euo pipefail

STAGING="https://mint-staging.up.railway.app"

# Generate a well-formed sentry-trace header
#   <32-hex trace_id>-<16-hex span_id>-<sampled flag>
TRACE_ID="$(openssl rand -hex 16)"
SPAN_ID="$(openssl rand -hex 8)"
SENTRY_TRACE_HEADER="sentry-trace: ${TRACE_ID}-${SPAN_ID}-1"

echo "[trace_round_trip] injecting trace_id=${TRACE_ID}"
echo "[trace_round_trip] targeting ${STAGING}"

# ---------------------------------------------------------------------------
# Step 1 — /health 2xx path (LoggingMiddleware baseline — Wave 0 contract).
# On the 2xx path we assert X-Trace-Id is non-empty but DO NOT require
# equality: LoggingMiddleware generates a fresh uuid4 per request and
# does NOT inherit inbound sentry-trace (that's OBS-03 handler scope).
# ---------------------------------------------------------------------------
URL_HEALTH="${STAGING}/api/v1/health"
echo "[trace_round_trip] /health GET ${URL_HEALTH}"

RESP_HEALTH="$(
  curl -sS -i --max-time 15 \
    -H "${SENTRY_TRACE_HEADER}" \
    "${URL_HEALTH}" || true
)"

HEALTH_TRACE_LINE="$(
  printf '%s\n' "$RESP_HEALTH" \
    | awk 'BEGIN{IGNORECASE=1} /^x-trace-id:/{print; exit}'
)"

if [ -z "$HEALTH_TRACE_LINE" ]; then
  echo "[FAIL] X-Trace-Id header absent from /health response" >&2
  echo "--- response head ---" >&2
  printf '%s\n' "$RESP_HEALTH" | head -n 20 >&2
  exit 1
fi

HEALTH_TRACE_VALUE="$(
  printf '%s\n' "$HEALTH_TRACE_LINE" \
    | sed -E 's/^[Xx]-[Tt]race-[Ii]d:[[:space:]]*//' \
    | tr -d '\r\n '
)"

if [ -z "$HEALTH_TRACE_VALUE" ]; then
  echo "[FAIL] /health X-Trace-Id header empty" >&2
  exit 1
fi

echo "[trace_round_trip] /health X-Trace-Id=${HEALTH_TRACE_VALUE}"
echo "[trace_round_trip] (non-equality assertion: LoggingMiddleware generates uuid4)"

# ---------------------------------------------------------------------------
# Step 2 — OBS-03 handler path via /auth/login with malformed payload.
# POST a clearly invalid JSON; depending on staging config this yields
# either:
#   (a) 500 — the OBS-03 handler runs, body MUST contain trace_id equal
#       to TRACE_ID and X-Trace-Id header MUST equal TRACE_ID. Full PASS.
#   (b) 4xx (400/422) — FastAPI validator rejects before handler runs,
#       LoggingMiddleware emits its own uuid4 X-Trace-Id. PASS-PARTIAL.
#       Accepted per revision Info 7 (DEFERRED: test-only raise_500).
# ---------------------------------------------------------------------------
URL_500="${STAGING}/api/v1/auth/login"
echo "[trace_round_trip] /auth/login POST ${URL_500} (malformed payload)"

RESP_500="$(
  curl -sS -i --max-time 15 -X POST "${URL_500}" \
    -H "Content-Type: application/json" \
    -H "${SENTRY_TRACE_HEADER}" \
    --data '{"not":"valid","intentionally":"malformed_for_trace_test"}' \
  || true
)"

# Extract HTTP status (first status line after any Continue responses).
STATUS="$(
  printf '%s\n' "$RESP_500" \
    | awk '/^HTTP\// {status=$2} END {print status}'
)"

TRACE_500_LINE="$(
  printf '%s\n' "$RESP_500" \
    | awk 'BEGIN{IGNORECASE=1} /^x-trace-id:/{print; exit}'
)"

TRACE_500_VALUE="$(
  printf '%s\n' "$TRACE_500_LINE" \
    | sed -E 's/^[Xx]-[Tt]race-[Ii]d:[[:space:]]*//' \
    | tr -d '\r\n '
)"

# Extract body (everything after the blank header-terminator line).
BODY_500="$(
  printf '%s' "$RESP_500" \
    | awk 'BEGIN{in_body=0} /^\r?$/{in_body=1; next} in_body==1{print}'
)"

BODY_TRACE="$(
  printf '%s' "$BODY_500" \
    | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read() or '{}')
    print(data.get('trace_id', ''))
except Exception:
    print('')
" 2>/dev/null || echo ""
)"

echo "[trace_round_trip] /auth/login status=${STATUS}"
echo "[trace_round_trip] /auth/login X-Trace-Id=${TRACE_500_VALUE}"
echo "[trace_round_trip] /auth/login body.trace_id=${BODY_TRACE}"

if [ "$STATUS" = "500" ]; then
  if [ "$BODY_TRACE" = "$TRACE_ID" ] && [ "$TRACE_500_VALUE" = "$TRACE_ID" ]; then
    echo "[PASS] OBS-03 end-to-end: inbound trace_id preserved in body + header"
    exit 0
  fi
  echo "[FAIL] OBS-03 trace_id mismatch on 500 path" >&2
  echo "  expected trace_id: ${TRACE_ID}" >&2
  echo "  body.trace_id:     ${BODY_TRACE}" >&2
  echo "  X-Trace-Id header: ${TRACE_500_VALUE}" >&2
  exit 1
fi

if [ "$STATUS" = "400" ] || [ "$STATUS" = "401" ] || [ "$STATUS" = "403" ] \
   || [ "$STATUS" = "422" ]; then
  if [ -n "$TRACE_500_VALUE" ]; then
    echo "[PASS-PARTIAL] ${STATUS} path hit LoggingMiddleware only (X-Trace-Id present)."
    echo "[PASS-PARTIAL] OBS-03 500 path not exercised (staging lacks /_test/raise_500)."
    echo "[PASS-PARTIAL] DEFERRED: test-only raise_500 endpoint (accepted limitation per revision Info 7)"
    exit 0
  fi
  echo "[FAIL] ${STATUS} path returned empty X-Trace-Id (LoggingMiddleware regression?)" >&2
  exit 1
fi

echo "[FAIL] unexpected status=${STATUS} on /auth/login" >&2
printf '%s\n' "$RESP_500" | head -n 20 >&2
exit 1
