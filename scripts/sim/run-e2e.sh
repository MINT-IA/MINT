#!/usr/bin/env bash
# scripts/sim/run-e2e.sh — Phase 51 E2E-07 wrapper (CONTEXT D-15).
#
# Orchestrates the four phases of an end-to-end sim walkthrough:
#
#   [1/4] Backend — uvicorn on :8888 with MINT_DEV_AUTH=1 +
#                   MINT_DEV_TOKEN_ENABLED=1 + ENVIRONMENT=development.
#   [2/4] Token   — POST /dev/token, capture access_token.
#   [3/4] Sim     — apps/mobile/scripts/run-sim.sh launches the iPhone
#                   simulator with --dart-define=MINT_DEV_AUTH_TOKEN=<jwt>.
#   [4/4] Walker  — tools/simulator/walker.sh --archetype <slug>
#                   --scenario <name> drives the scripted walkthrough.
#
# Usage:
#   scripts/sim/run-e2e.sh <archetype-slug> [scenario]
#   DRY_RUN=1 scripts/sim/run-e2e.sh swiss_native retraite
#
# Valid archetype slugs (CONTEXT D-02): swiss_native, expat_eu, expat_us,
# cross_border, independent_no_lpp, recent_arrival, near_retirement,
# young_starter.
#
# Valid scenarios (CONTEXT D-17): retraite, fiscalite, housing, career,
# fatca, family, business, integration, lpp_choice. Default: retraite.
#
# DRY_RUN=1 prints the planned commands for each of the 4 phases without
# launching anything. The exit code mirrors walker's exit code in real
# runs; in DRY_RUN it is 0 if walker --dry-run succeeds.
#
# T-51-05-02 prevention: the env vars set here (MINT_DEV_AUTH=1,
# MINT_DEV_TOKEN_ENABLED=1) live ONLY in this dev script. The CI prod-leak
# guard greps prod manifests for these literals — this file lives under
# scripts/sim/ which is excluded from that grep (local-dev tooling).
set -euo pipefail

ARCHETYPE="${1:-}"
SCENARIO="${2:-retraite}"
DRY_RUN="${DRY_RUN:-0}"

VALID_ARCHETYPES=(
  swiss_native
  expat_eu
  expat_us
  cross_border
  independent_no_lpp
  recent_arrival
  near_retirement
  young_starter
)

if [ -z "$ARCHETYPE" ]; then
  echo "Usage: $0 <archetype-slug> [scenario]" >&2
  echo "Valid archetypes: ${VALID_ARCHETYPES[*]}" >&2
  exit 2
fi

# Slug allowlist — T-51-05-04 shell injection mitigation. The slug is
# interpolated into shell commands later; restricting to the hardcoded
# list neutralizes injection attempts.
_ok=0
for s in "${VALID_ARCHETYPES[@]}"; do
  [ "$s" = "$ARCHETYPE" ] && _ok=1
done
if [ "$_ok" -ne 1 ]; then
  echo "ERROR: unknown archetype '$ARCHETYPE'" >&2
  echo "Valid: ${VALID_ARCHETYPES[*]}" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# [1/4] Launch backend with the 3 dev-token gate env vars set.
# ---------------------------------------------------------------------------
echo "[1/4] Backend — uvicorn :8888 with MINT_DEV_AUTH=1 + MINT_DEV_TOKEN_ENABLED=1"
if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY-RUN] would: cd services/backend && \\"
  echo "[DRY-RUN]   ENVIRONMENT=development MINT_DEV_AUTH=1 MINT_DEV_TOKEN_ENABLED=1 \\"
  echo "[DRY-RUN]   MINT_DEV_JWT_SECRET=local-e2e-secret \\"
  echo "[DRY-RUN]   uvicorn app.main:app --reload --port 8888 &"
else
  (
    cd services/backend
    ENVIRONMENT=development \
    MINT_DEV_AUTH=1 \
    MINT_DEV_TOKEN_ENABLED=1 \
    MINT_DEV_JWT_SECRET="${MINT_DEV_JWT_SECRET:-local-e2e-secret}" \
      uvicorn app.main:app --reload --port 8888 &
  )
  # Give uvicorn time to bind the port.
  sleep 3
fi

# ---------------------------------------------------------------------------
# [2/4] Fetch a dev token from the running backend.
# ---------------------------------------------------------------------------
echo "[2/4] Token — POST http://localhost:8888/dev/token"
if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY-RUN] would: curl -s -X POST http://localhost:8888/dev/token | jq -r .access_token"
  DEV_TOKEN="DRY_RUN_TOKEN_PLACEHOLDER"
else
  DEV_TOKEN=$(curl -s -X POST http://localhost:8888/dev/token \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['access_token'])" 2>/dev/null || true)
  if [ -z "$DEV_TOKEN" ]; then
    echo "ERROR: token fetch failed — is the backend running on :8888 with all 3 gates open?" >&2
    exit 1
  fi
  echo "Token acquired (length=${#DEV_TOKEN})."
fi

# ---------------------------------------------------------------------------
# [3/4] Build & launch the iOS simulator with the dev token + archetype.
# ---------------------------------------------------------------------------
echo "[3/4] Sim — apps/mobile/scripts/run-sim.sh + dart-defines"
if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY-RUN] would: bash apps/mobile/scripts/run-sim.sh"
  echo "[DRY-RUN]   (note: run-sim.sh does not currently accept --dart-define;"
  echo "[DRY-RUN]    Plan 51-06 will adapt it OR walker.sh will handle the"
  echo "[DRY-RUN]    archetype build directly with the 3 dart-defines)"
else
  # Plan 51-05 scope: walker.sh does the build with all 3 dart-defines
  # itself in --archetype-walkthrough mode (it consumes MINT_DEV_AUTH_TOKEN
  # from this env and passes it via --dart-define). We do NOT call
  # run-sim.sh here because walker rebuilds with the archetype dart-define.
  export MINT_DEV_AUTH_TOKEN="$DEV_TOKEN"
  echo "MINT_DEV_AUTH_TOKEN exported (walker will pass it via --dart-define)"
fi

# ---------------------------------------------------------------------------
# [4/4] Walker — drive the scripted walkthrough.
# ---------------------------------------------------------------------------
echo "[4/4] Walker — tools/simulator/walker.sh --archetype ${ARCHETYPE} --scenario ${SCENARIO}"
if [ "$DRY_RUN" = "1" ]; then
  bash tools/simulator/walker.sh --archetype "$ARCHETYPE" --scenario "$SCENARIO" --dry-run
else
  bash tools/simulator/walker.sh --archetype "$ARCHETYPE" --scenario "$SCENARIO"
fi

echo "Done. Screenshots: screenshots/walkthrough/v2.10-final/${ARCHETYPE}/${SCENARIO}/"
