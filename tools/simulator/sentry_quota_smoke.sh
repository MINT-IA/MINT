#!/usr/bin/env bash
# tools/simulator/sentry_quota_smoke.sh — Phase 31 OBS-07 (b) integration.
#
# Calls sentry-cli api stats_v2 and asserts a usable JSON response.
# Wave 4 Plan 31-04 consumes this to build the observability budget
# artefact. Wave 0 ships the probe so we fail fast if Sentry auth is
# broken or the API shape shifts.
#
# Usage:
#   bash tools/simulator/sentry_quota_smoke.sh
#
# Exit codes:
#   0  valid stats_v2 JSON returned (contains 'groups' OR 'intervals')
#   1  auth failed / schema mismatch / empty body / sentry-cli missing
#
set -euo pipefail

if ! command -v sentry-cli >/dev/null 2>&1; then
  echo "[FAIL] sentry-cli not installed — run: brew install sentry-cli" >&2
  exit 1
fi

# Auth token — env var wins, Keychain fallback (matches walker.sh).
if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  if command -v security >/dev/null 2>&1; then
    SENTRY_AUTH_TOKEN="$(security find-generic-password -s SENTRY_AUTH_TOKEN -w 2>/dev/null || true)"
    export SENTRY_AUTH_TOKEN
  fi
fi

if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo "[FAIL] SENTRY_AUTH_TOKEN not set (env nor Keychain)" >&2
  echo "       create via Sentry UI → User Settings → Auth Tokens" >&2
  echo "       scopes: org:read project:read event:read (NO write)" >&2
  exit 1
fi

echo "[quota_smoke] sentry-cli api /organizations/mint/stats_v2/ (24h)"

BODY="$(sentry-cli api \
  "/organizations/mint/stats_v2/?field=sum(quantity)&statsPeriod=24h" \
  --auth-token "${SENTRY_AUTH_TOKEN}" 2>&1 || true)"

if [ -z "$BODY" ]; then
  echo "[FAIL] empty response body from sentry-cli api" >&2
  exit 1
fi

# Validate shape via python stdlib (don't depend on jq).
python3 - <<PY || exit 1
import json, sys
raw = """$BODY"""
try:
    d = json.loads(raw)
except json.JSONDecodeError as e:
    sys.stderr.write(f"[FAIL] response not JSON: {e}\n")
    sys.stderr.write(raw[:400] + "\n")
    sys.exit(1)

if "groups" in d or "intervals" in d:
    print("[PASS] stats_v2 JSON has groups/intervals key")
    sys.exit(0)

sys.stderr.write("[FAIL] stats_v2 JSON missing both 'groups' and 'intervals'\n")
sys.stderr.write(json.dumps(d, indent=2)[:400] + "\n")
sys.exit(1)
PY
