#!/usr/bin/env bash
#
# Smoke tests for MINT staging API.
# Usage:
#   scripts/smoke_staging_api.sh https://mint-staging.up.railway.app/api/v1
#   scripts/smoke_staging_api.sh https://mint-staging.up.railway.app
#
# Environment overrides:
#   MAX_RETRIES=5
#   SLEEP_SECONDS=5
#   CONNECT_TIMEOUT=5
#   MAX_TIME=20

set -Eeuo pipefail

MAX_RETRIES="${MAX_RETRIES:-5}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
MAX_TIME="${MAX_TIME:-20}"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  # shellcheck disable=SC2059
  printf "[%s] %s\n" "$(timestamp)" "$*"
}

BASE_URL="${1:-${STAGING_API_URL:-}}"
if [ -z "$BASE_URL" ]; then
  log "ERROR: Missing staging URL argument."
  log "Usage: scripts/smoke_staging_api.sh <staging_base_url>"
  exit 2
fi

BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" == */api/v1 ]]; then
  API_BASE="$BASE_URL"
else
  API_BASE="$BASE_URL/api/v1"
fi

call_endpoint() {
  local name="$1"
  local method="$2"
  local url="$3"
  local payload="$4"
  local expected_code="$5"
  local expected_pattern="$6"
  local attempt
  local response
  local code
  local body

  for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
    log "[$name] Attempt ${attempt}/${MAX_RETRIES}: ${method} ${url}"

    if [ "$method" = "GET" ]; then
      response="$(curl -sS -X "$method" \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        "$url" \
        -w $'\n%{http_code}' || true)"
    else
      response="$(curl -sS -X "$method" \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "$url" \
        -w $'\n%{http_code}' || true)"
    fi

    code="${response##*$'\n'}"
    body="${response%$'\n'*}"

    if [ "$code" = "$expected_code" ] && { [ -z "$expected_pattern" ] || grep -Eiq "$expected_pattern" <<<"$body"; }; then
      log "[$name] OK (HTTP $code)"
      return 0
    fi

    log "[$name] WARN: expected HTTP $expected_code and pattern '$expected_pattern', got HTTP $code"
    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
      sleep "$SLEEP_SECONDS"
    fi
  done

  log "[$name] ERROR after ${MAX_RETRIES} attempts"
  log "[$name] Last response (truncated):"
  echo "$body" | head -c 1200
  echo
  return 1
}

ONBOARDING_PAYLOAD="$(cat <<'JSON'
{
  "age": 35,
  "gross_salary": 95000,
  "canton": "VD",
  "household_type": "single",
  "current_savings": 25000,
  "is_property_owner": false,
  "existing_3a": 12000,
  "existing_lpp": 45000
}
JSON
)"

ARBITRAGE_PAYLOAD="$(cat <<'JSON'
{
  "capital_lpp_total": 500000,
  "capital_obligatoire": 320000,
  "capital_surobligatoire": 180000,
  "rente_annuelle_proposee": 24000,
  "canton": "VD",
  "age_retraite": 65,
  "horizon": 20
}
JSON
)"

log "Starting staging smoke tests on ${API_BASE}"

failures=0

call_endpoint \
  "health" \
  "GET" \
  "${API_BASE}/health" \
  "" \
  "200" \
  "\"status\"[[:space:]]*:[[:space:]]*\"ok\"" || failures=$((failures + 1))

call_endpoint \
  "health-ready-status" \
  "GET" \
  "${API_BASE}/health/ready" \
  "" \
  "200" \
  "\"status\"[[:space:]]*:[[:space:]]*\"ok\"" || failures=$((failures + 1))

call_endpoint \
  "health-ready-database" \
  "GET" \
  "${API_BASE}/health/ready" \
  "" \
  "200" \
  "\"database\"[[:space:]]*:[[:space:]]*\"ok\"" || failures=$((failures + 1))

call_endpoint \
  "retirement-checklist" \
  "GET" \
  "${API_BASE}/retirement/checklist" \
  "" \
  "200" \
  "\"checklist\"" || failures=$((failures + 1))

call_endpoint \
  "onboarding-minimal-profile" \
  "POST" \
  "${API_BASE}/onboarding/minimal-profile" \
  "$ONBOARDING_PAYLOAD" \
  "200" \
  "\"confidence_score\"" || failures=$((failures + 1))

call_endpoint \
  "arbitrage-rente-vs-capital" \
  "POST" \
  "${API_BASE}/arbitrage/rente-vs-capital" \
  "$ARBITRAGE_PAYLOAD" \
  "200" \
  "\"options\"" || failures=$((failures + 1))

if [ "$failures" -gt 0 ]; then
  log "Smoke tests FAILED (${failures} check(s) en echec)."
  exit 1
fi

log "Smoke tests PASSED."
