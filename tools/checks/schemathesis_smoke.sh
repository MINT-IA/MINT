#!/usr/bin/env bash
# tools/checks/schemathesis_smoke.sh
#
# Phase A-USER-WALKTHROUGH (v2.13) — OpenAPI contract smoke test for
# the critical surfaces (anonymous chat, auth, onboarding,
# documents). Pulls the live OpenAPI from staging, runs a 3-example
# Schemathesis fuzz on the included path regex, fails on undocumented
# response codes or schema-compliant rejections.
#
# Catches regressions like :
#   - BUG #13 : POST /anonymous/chat returns 400 (header missing) but
#     OpenAPI only declares 200/422
#   - BUG #14 : POST /auth/register returns 409 (email exists) but
#     OpenAPI only declares 201/422
#   - BUG #15 : POST /onboarding/premier-eclairage returns 400 on
#     business-rule reject but OpenAPI only declares 200/422
#
# Usage :
#   bash tools/checks/schemathesis_smoke.sh
#
# Dependencies : pip3 install --user schemathesis (~7 deps, ~1 min).
# CI : add to ci.yml as a backend-contract gate.

set -euo pipefail

STAGING_URL="${MINT_STAGING_URL:-https://mint-staging.up.railway.app}"
SPEC_URL="${STAGING_URL}/api/v1/openapi.json"
SPEC_LOCAL="/tmp/mint_openapi_smoke.json"

# Critical surfaces — extend over time as new endpoints land.
# Each pattern is a Python regex matching the path WITHOUT the
# /api/v1 prefix. Schemathesis includes the prefix automatically.
INCLUDE_REGEX="/anonymous/chat$|/auth/(login|register|forgot-password)$|/onboarding/premier-eclairage$|/health$"

EXAMPLES="${SCHEMATHESIS_EXAMPLES:-3}"
WORKERS="${SCHEMATHESIS_WORKERS:-2}"

echo "[schemathesis-smoke] pulling OpenAPI from $SPEC_URL"
curl -fsS "$SPEC_URL" -o "$SPEC_LOCAL"

PATH="$HOME/Library/Python/3.9/bin:$PATH"
if ! command -v schemathesis >/dev/null 2>&1; then
  echo "[schemathesis-smoke] FAIL — schemathesis not on PATH ; install via 'pip3 install --user schemathesis'" >&2
  exit 1
fi

echo "[schemathesis-smoke] running fuzz : --max-examples=$EXAMPLES --workers=$WORKERS"
echo "[schemathesis-smoke] include-path-regex : $INCLUDE_REGEX"

# Schemathesis exits 1 on any failure — that's what we want for CI.
schemathesis run "$SPEC_LOCAL" \
  --url "$STAGING_URL" \
  --include-path-regex "$INCLUDE_REGEX" \
  --max-examples "$EXAMPLES" \
  --workers "$WORKERS"
