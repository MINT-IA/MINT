#!/usr/bin/env bash
# Local Mint 2.0 quality gate for the current first-activation path.
#
# This gate composes committed proof flows instead of creating another product
# scenario. It targets the exact iPhone 13 mini simulator used for Mint2 RvC
# evidence and writes all runtime artifacts under .planning/runtime-evidence/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEVICE_NAME="MINT iPhone 13 mini RvC"
BUNDLE_ID="ch.mint.app"
API_BASE_URL="${MINT_API_BASE_URL:-https://mint-staging.up.railway.app/api/v1}"

LAYOUT_TEST="test/screens/onboarding/mvp_wedge/mint2_first_experience_iphone13mini_layout_test.dart"
FIRST_FLOW="tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml"
CLAIM_FLOW="tools/simulator/flows/maestro-perfect-set/flow_mint2_lpp_dossier_account_claim.yaml"
CONTENT_FLOW="tools/simulator/flows/maestro-perfect-set/flow_mint2_content_quality_surfaces.yaml"
WATCHDOG="tools/simulator/maestro_with_watchdog.sh"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT_ROOT="${MINT2_QUALITY_ARTIFACTS:-$REPO_ROOT/.planning/runtime-evidence/mint2-quality-gate-$RUN_ID}"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: bash tools/simulator/mint2_quality_gate.sh [--dry-run]

Runs the local Mint 2.0 quality gate:
  simulator: $DEVICE_NAME
  staging:   $API_BASE_URL
  evidence:  .planning/runtime-evidence/mint2-quality-gate-<timestamp>/

Checks:
  - flutter test $LAYOUT_TEST
  - $FIRST_FLOW
  - $CLAIM_FLOW
  - $CONTENT_FLOW
EOF
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

cd "$REPO_ROOT"

if [ "$DRY_RUN" -eq 1 ]; then
  usage
  cat <<EOF

Build:
  CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \\
    --dart-define=API_BASE_URL=$API_BASE_URL \\
    --dart-define=MINT_DISABLE_BETA_MODAL=true \\
    --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true \\
    --dart-define=MINT_E2E_PROOF_ANCHORS=true

Fresh-state:
  xcrun simctl shutdown all
  xcrun simctl boot <UDID for "$DEVICE_NAME">
  xcrun simctl keychain <UDID> reset
  xcrun simctl uninstall <UDID> $BUNDLE_ID
EOF
  exit 0
fi

mkdir -p "$ARTIFACT_ROOT"
exec > >(tee "$ARTIFACT_ROOT/run.log") 2>&1

log() {
  printf '\n[quality-gate] %s\n' "$*"
}

fail() {
  printf '\n[quality-gate] ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [ -e "$path" ] || fail "missing required path: $path"
}

resolve_device_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

target = sys.argv[1]
data = json.load(sys.stdin)
matches = []
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("isAvailable") and device.get("name") == target:
            matches.append(device.get("udid"))

if len(matches) != 1:
    print(
        f"expected exactly one available simulator named {target!r}, "
        f"found {len(matches)}",
        file=sys.stderr,
    )
    sys.exit(2)

print(matches[0])
' "$DEVICE_NAME"
}

run_maestro_flow() {
  local label="$1"
  local flow="$2"
  local out_dir="$ARTIFACT_ROOT/$label"
  mkdir -p "$out_dir"

  log "maestro $label: $flow"
  MINT_WALKER_ARTIFACTS="$out_dir" \
    MAESTRO_HARD_LIMIT="${MAESTRO_HARD_LIMIT:-1200}" \
    bash "$WATCHDOG" test "$flow"
}

write_summary() {
  {
    echo "run_id: $RUN_ID"
    echo "timestamp_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo: $REPO_ROOT"
    echo "branch: $(git branch --show-current)"
    echo "head: $(git rev-parse HEAD)"
    echo "status:"
    git status --short --branch | sed 's/^/  /'
    echo "simulator: $DEVICE_NAME"
    echo "device_udid: ${DEVICE_UDID:-unresolved}"
    echo "api_base_url: $API_BASE_URL"
    echo "fresh_state:"
    echo "  keychain_reset: simulator"
    echo "  app_uninstall: $BUNDLE_ID"
    echo "flows:"
    echo "  - $FIRST_FLOW"
    echo "  - $CLAIM_FLOW"
    echo "  - $CONTENT_FLOW"
  } > "$ARTIFACT_ROOT/run-summary.txt"
}

trap 'write_summary' EXIT

require_file "$WATCHDOG"
require_file "$FIRST_FLOW"
require_file "$CLAIM_FLOW"
require_file "$CONTENT_FLOW"

log "evidence: $ARTIFACT_ROOT"
log "checking staging reachability"
curl -fsS --max-time 10 "$API_BASE_URL/health" >/dev/null || \
  curl -fsS --max-time 10 "$API_BASE_URL/docs" >/dev/null || \
  fail "staging API did not answer health/docs at $API_BASE_URL"

log "running Flutter iPhone 13 mini layout anti-clipping test"
(
  cd apps/mobile
  flutter test "$LAYOUT_TEST"
)

log "resolving exact simulator"
DEVICE_UDID="$(resolve_device_udid)"
log "booting only $DEVICE_NAME ($DEVICE_UDID)"
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_UDID"
open -a Simulator
xcrun simctl bootstatus "$DEVICE_UDID" -b

log "resetting simulator keychain"
xcrun simctl keychain "$DEVICE_UDID" reset

log "building staging simulator app"
(
  cd apps/mobile
  CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=MINT_DISABLE_BETA_MODAL=true \
    --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true \
    --dart-define=MINT_E2E_PROOF_ANCHORS=true
)

APP_PATH="$REPO_ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
[ -d "$APP_PATH" ] || fail "Runner.app not found at $APP_PATH"

log "installing fresh app on exact simulator"
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

write_summary

run_maestro_flow "01-first-entry-layout-and-route" "$FIRST_FLOW"
run_maestro_flow "02-dossier-claim-relaunch-reset" "$CLAIM_FLOW"
run_maestro_flow "03-content-quality-no-financial-residue" "$CONTENT_FLOW"

log "PASS: Mint 2.0 local quality gate completed"
