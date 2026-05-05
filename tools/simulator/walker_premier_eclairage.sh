#!/usr/bin/env bash
# tools/simulator/walker_premier_eclairage.sh
#
# Phase 74 — autonomous walker for Premier Éclairage flow.
# Drives an iOS simulator (iPhone 17 Pro / iOS 18.2) through the
# anonymous-chat → first éclairage → register-CTA loop and captures
# 6 deterministic screenshots per archetype.
#
# Locked spec : .planning/phases/74-walker-premier-eclairage/PANEL-VERDICT.md
#
# This file deliberately does NOT source walker.sh nor extend
# walker_audit_tap_render.sh. Reasoning :
#   - walker.sh's argv parser eats our --archetype flag (panel §1).
#   - walker_audit_tap_render.sh is shaped tab-by-tab, wrong for the
#     premier-éclairage chat flow.
# So the helper trio (_tap_at, _wait_for_ui, _snap, _sha) is copied
# inline verbatim from walker_audit_tap_render.sh:252-281, including
# the --no-codesign build flag (per memory feedback_diff_against_existing_tool).
#
# Usage :
#   bash tools/simulator/walker_premier_eclairage.sh --help
#   bash tools/simulator/walker_premier_eclairage.sh --archetype julien_swiss
#   bash tools/simulator/walker_premier_eclairage.sh \
#        --archetype couple_acheteurs_lausanne \
#        --no-dry-run \
#        --run-id 2026-05-04-141500-abcd123
#
# Required (real run only) :
#   - Booted simulator (iPhone 17 Pro, iOS 18.2 runtime preflight check)
#   - cliclick on PATH (brew install cliclick)
#   - Network reachable to mint-staging.up.railway.app (per memory
#     feedback_app_targets_staging_always)
#   - Optional env : SENTRY_DSN_STAGING (forwarded as --dart-define if set)
#
# Output structure (panel §5) :
#   .planning/walker/<run-id>/
#   ├── summary.json
#   ├── walker.log
#   └── <archetype>/
#       ├── screenshots/00-cold-launch.png ... 05-register-cta.png
#       ├── diff/01-landing_diff.png ... (when --reference-dir provided)
#       └── result.json
#
# Exit codes (panel §4) :
#   0 — success or soft-warn (diff outside hero bbox > 4% but inside ok)
#   1 — usage / preflight error
#   2 — hero-bbox SSIM < 0.96 OR missing checkpoint OR > 180s wall
#   3 — register-CTA bbox SSIM < 0.96 (TestFlight reviewer tap target)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARCHETYPE_DIR="$REPO_ROOT/tools/simulator/archetypes"
BBOXES_FILE="$REPO_ROOT/tools/simulator/hero_bboxes.json"
GOLDEN_DIR="$REPO_ROOT/tools/simulator/goldens"
WALKER_ROOT="$REPO_ROOT/.planning/walker"
IMAGE_DIFF="$REPO_ROOT/tools/simulator/image_diff.py"

ARCHETYPE=""
RUN_ID=""
DRY_RUN=1
SHOW_HELP=0
REFERENCE_DIR=""
PER_ARCHETYPE_TIMEOUT=180  # panel §1

VALID_ARCHETYPES=(
  julien_swiss
  couple_acheteurs_lausanne
  jeune_diplome_zurich
  cadre_40_55_lpp_rachat
)

print_help() {
  cat <<EOF
walker_premier_eclairage.sh — Phase 74 anonymous-chat → éclairage walker

Modes :
  --dry-run               (default) print plan, no sim/build, no taps
  --no-dry-run            real run : build + boot sim + tap + capture
  --archetype <slug>      one of : ${VALID_ARCHETYPES[*]}
                          (required for both dry-run and real)
  --run-id <id>           override run-id (default = YYYY-MM-DD-HHMMSS-<sha7>)
  --reference-dir <dir>   when set + --no-dry-run, image_diff.py runs against
                          <dir>/<archetype>/<checkpoint>.png after each capture
                          (defaults to tools/simulator/goldens/)
  --help                  this text

6 checkpoints captured per archetype (panel §1) :
  00-cold-launch.png       post-launch, ~6s sleep
  01-landing.png           landing screen, before tap
  02-anon-chat-opener.png  after CTA tap, opener bubble + 3 chips
  03-after-turn1.png       after turn 1 (chip OR type_text)
  04-eclairage-card.png    ECL-01 hero card render
  05-register-cta.png      register CTA in viewport

Per-archetype wall-clock timeout : ${PER_ARCHETYPE_TIMEOUT}s.

Exit codes : 0 ok / 1 usage / 2 SSIM-fail / 3 register-CTA-fail.
EOF
}

# ── argv ────────────────────────────────────────────────────────────────
_args=("$@")
i=0
while [ "$i" -lt "${#_args[@]}" ]; do
  a="${_args[$i]}"
  case "$a" in
    --help|-h) SHOW_HELP=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-dry-run) DRY_RUN=0 ;;
    --archetype)
      i=$((i+1))
      ARCHETYPE="${_args[$i]:-}"
      ;;
    --archetype=*) ARCHETYPE="${a#--archetype=}" ;;
    --run-id)
      i=$((i+1))
      RUN_ID="${_args[$i]:-}"
      ;;
    --run-id=*) RUN_ID="${a#--run-id=}" ;;
    --reference-dir)
      i=$((i+1))
      REFERENCE_DIR="${_args[$i]:-}"
      ;;
    --reference-dir=*) REFERENCE_DIR="${a#--reference-dir=}" ;;
    *)
      echo "ERROR: unknown flag '$a' (try --help)" >&2
      exit 1
      ;;
  esac
  i=$((i+1))
done

if [ "$SHOW_HELP" = "1" ]; then
  print_help
  exit 0
fi

if [ -z "$ARCHETYPE" ]; then
  echo "ERROR: --archetype required (try --help)" >&2
  exit 1
fi

# Validate archetype slug
_valid=0
for v in "${VALID_ARCHETYPES[@]}"; do
  if [ "$ARCHETYPE" = "$v" ]; then _valid=1; break; fi
done
if [ "$_valid" != "1" ]; then
  echo "ERROR: unknown archetype '$ARCHETYPE'" >&2
  echo "Valid : ${VALID_ARCHETYPES[*]}" >&2
  exit 1
fi

ARCHETYPE_JSON="$ARCHETYPE_DIR/$ARCHETYPE.json"
if [ ! -f "$ARCHETYPE_JSON" ]; then
  echo "ERROR: archetype seed not found at $ARCHETYPE_JSON" >&2
  exit 1
fi

# ── run-id ──────────────────────────────────────────────────────────────
if [ -z "$RUN_ID" ]; then
  _ts="$(date +%Y-%m-%d-%H%M%S)"
  _sha="$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo nogit)"
  RUN_ID="${_ts}-${_sha}"
fi

RUN_DIR="$WALKER_ROOT/$RUN_ID"
ARCH_DIR="$RUN_DIR/$ARCHETYPE"
SHOTS_DIR="$ARCH_DIR/screenshots"
DIFF_DIR="$ARCH_DIR/diff"
LOG="$RUN_DIR/walker.log"

mkdir -p "$SHOTS_DIR" "$DIFF_DIR"

log() { echo "[walker $(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

log "phase 74 walker_premier_eclairage"
log "  archetype     : $ARCHETYPE"
log "  run-id        : $RUN_ID"
log "  archetype-json: $ARCHETYPE_JSON"
log "  shots-dir     : $SHOTS_DIR"
log "  dry-run       : $DRY_RUN"

# ── dry-run path : enumerate plan + exit ────────────────────────────────
if [ "$DRY_RUN" = "1" ]; then
  log "dry-run mode — no sim, no build, no taps"
  log "would build flutter ios sim with :"
  log "  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1"
  log "  --dart-define=MINT_E2E_ARCHETYPE=$ARCHETYPE"
  log "  --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=<archetype.expected_eclairage.kind>"
  log "would capture 6 checkpoints under $SHOTS_DIR :"
  log "  00-cold-launch.png  01-landing.png  02-anon-chat-opener.png"
  log "  03-after-turn1.png  04-eclairage-card.png  05-register-cta.png"
  log "would run image_diff.py per checkpoint with bboxes from $BBOXES_FILE"
  log "dry-run plan complete"
  exit 0
fi

# ── real-run preflight ──────────────────────────────────────────────────
for cmd in xcrun cliclick shasum python3 jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required binary '$cmd' not found on PATH" >&2
    [ "$cmd" = "cliclick" ] && echo "       brew install cliclick" >&2
    [ "$cmd" = "jq" ] && echo "       brew install jq" >&2
    exit 1
  }
done

# Sim runtime preflight (panel §6 mitigation #1) — fail fast
if ! xcrun simctl runtime list 2>/dev/null | grep -q "iOS 18.2"; then
  echo "ERROR: iOS 18.2 simulator runtime missing" >&2
  echo "Install via Xcode → Settings → Components → iOS 18.2." >&2
  exit 1
fi

DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
BUNDLE="ch.mint.app"

log "preflight OK — runtime iOS 18.2 present, device='$DEVICE'"

# ── helpers (copied verbatim from walker_audit_tap_render.sh:252-281,
#     panel §1 mandate — DO NOT source walker.sh) ──────────────────────
_tap_at() {
  local x="$1" y="$2"
  cliclick "c:${x},${y}"
  sleep 0.4
}

_wait_for_ui() {
  local max="${1:-8}"
  local prev_hash="" cur_hash="" i
  for i in $(seq 1 "$max"); do
    xcrun simctl io booted screenshot /tmp/_walker_phase74_poll.png \
      >/dev/null 2>&1 || true
    cur_hash=$(shasum /tmp/_walker_phase74_poll.png 2>/dev/null | awk '{print $1}')
    if [ -n "$prev_hash" ] && [ "$prev_hash" = "$cur_hash" ]; then
      return 0
    fi
    prev_hash="$cur_hash"
    sleep 1
  done
}

_snap() {
  local out="$1"
  mkdir -p "$(dirname "$out")"
  xcrun simctl io booted screenshot "$out"
}

_sha() {
  shasum "$1" 2>/dev/null | awk '{print $1}'
}

# Phase-74-specific helper : send literal text into focused input,
# then RETURN (panel §6 mitigation #2 — avoid send-button tap).
_type_text() {
  local txt="$1"
  cliclick "t:${txt}"
  sleep 0.5
  cliclick "kp:return"
}

# Dismiss soft keyboard (panel §6 mitigation #4) — mandatory between
# turn 1 and turn 2 when chips need to be tappable.
_dismiss_keyboard() {
  cliclick "kp:esc"
  sleep 0.3
}

# ── extract éclairage kind for orchestrator pin ─────────────────────────
EXPECTED_KIND="$(jq -r '.expected_eclairage.kind' "$ARCHETYPE_JSON" 2>/dev/null || echo '')"
PROMPT_1="$(jq -r '.deterministic_prompts[0]' "$ARCHETYPE_JSON" 2>/dev/null || echo '')"
PROMPT_2="$(jq -r '.deterministic_prompts[1]' "$ARCHETYPE_JSON" 2>/dev/null || echo '')"

if [ -z "$EXPECTED_KIND" ] || [ "$EXPECTED_KIND" = "null" ]; then
  echo "ERROR: archetype JSON missing expected_eclairage.kind" >&2
  exit 1
fi
log "expected éclairage kind : $EXPECTED_KIND"

# ── boot + build + install ──────────────────────────────────────────────
_t0_total=$(date +%s)

log "shutdown all sims"
xcrun simctl shutdown all >/dev/null 2>&1 || true
log "erase + boot $DEVICE"
xcrun simctl erase "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE"
open -a Simulator || true

log "flutter build ios --simulator --no-codesign (archetype=$ARCHETYPE kind=$EXPECTED_KIND)"
# --no-codesign required when the working tree lives under an iCloud Drive
# .nosync mount (com.apple.provenance xattrs). Mirrors walker.sh:587 +
# walker_audit_tap_render.sh:233 (per memory feedback_diff_against_existing_tool).
SENTRY_FLAG=""
if [ -n "${SENTRY_DSN_STAGING:-}" ]; then
  SENTRY_FLAG="--dart-define=SENTRY_DSN=${SENTRY_DSN_STAGING}"
fi

(cd "$REPO_ROOT/apps/mobile" && flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_E2E_ARCHETYPE="$ARCHETYPE" \
  --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND="$EXPECTED_KIND" \
  --dart-define=MINT_WALKTHROUGH_PHASE=74 \
  ${SENTRY_FLAG}) 2>&1 | tee -a "$LOG"

APP_PATH="$REPO_ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
if [ ! -d "$APP_PATH" ]; then
  log "FAIL: Runner.app not found at $APP_PATH"
  exit 1
fi

log "install $APP_PATH → $DEVICE"
xcrun simctl install "$DEVICE" "$APP_PATH"
log "launch $BUNDLE"
xcrun simctl launch "$DEVICE" "$BUNDLE"
sleep 6

# Wall-clock guard helper. Returns 0 if elapsed < timeout, 1 otherwise.
_within_budget() {
  local elapsed=$(( $(date +%s) - _t0_total ))
  if [ "$elapsed" -gt "$PER_ARCHETYPE_TIMEOUT" ]; then
    log "TIMEOUT: ${elapsed}s > ${PER_ARCHETYPE_TIMEOUT}s budget"
    return 1
  fi
  return 0
}

# ── 6-checkpoint capture sequence ───────────────────────────────────────
declare -a CHECKPOINTS=(
  "00-cold-launch"
  "01-landing"
  "02-anon-chat-opener"
  "03-after-turn1"
  "04-eclairage-card"
  "05-register-cta"
)

# Coordinates calibrated against existing landing/chat goldens.
# iPhone 17 Pro logical (393×852) × scale 3 = 1179×2556 cliclick space.
# These are intentional initial values — Slice 74c calibrates against
# real captures and tightens here + in hero_bboxes.json together.
CTA_LANDING_X=590
CTA_LANDING_Y=2000
CHIP_1_X=590
CHIP_1_Y=1900
INPUT_X=590
INPUT_Y=2300
SCROLL_DOWN_X=590
SCROLL_DOWN_Y=1700

# 00 cold launch
_within_budget || exit 2
_snap "$SHOTS_DIR/00-cold-launch.png"
log "captured 00-cold-launch"

# 01 landing
_within_budget || exit 2
_wait_for_ui 8
_snap "$SHOTS_DIR/01-landing.png"
log "captured 01-landing"

# tap landing CTA → opener bubble + 3 chips
_within_budget || exit 2
_tap_at "$CTA_LANDING_X" "$CTA_LANDING_Y"
sleep 2.5
_wait_for_ui 6
_snap "$SHOTS_DIR/02-anon-chat-opener.png"
log "captured 02-anon-chat-opener"

# turn 1 — type deterministic prompt #1 + return
_within_budget || exit 2
_tap_at "$INPUT_X" "$INPUT_Y"
sleep 0.4
_type_text "$PROMPT_1"
_wait_for_ui 12   # staging Anthropic P95 (panel §1)
_snap "$SHOTS_DIR/03-after-turn1.png"
log "captured 03-after-turn1"

# turn 2 — dismiss keyboard, type prompt #2, wait for ECL-01 card
_within_budget || exit 2
_dismiss_keyboard
_tap_at "$INPUT_X" "$INPUT_Y"
sleep 0.4
_type_text "$PROMPT_2"
_wait_for_ui 12
_snap "$SHOTS_DIR/04-eclairage-card.png"
log "captured 04-eclairage-card"

# 05 register CTA — scroll up so CTA enters viewport, snap
_within_budget || exit 2
_tap_at "$SCROLL_DOWN_X" "$SCROLL_DOWN_Y"
sleep 0.6
_wait_for_ui 4
_snap "$SHOTS_DIR/05-register-cta.png"
log "captured 05-register-cta"

# ── verify capture rate ─────────────────────────────────────────────────
_captured=0
for cp in "${CHECKPOINTS[@]}"; do
  if [ -f "$SHOTS_DIR/$cp.png" ]; then
    _captured=$((_captured+1))
  else
    log "MISS: $cp.png not captured"
  fi
done
log "capture rate : $_captured / ${#CHECKPOINTS[@]}"
if [ "$_captured" -lt "${#CHECKPOINTS[@]}" ]; then
  log "FAIL: capture rate < 6/6 (panel §4 hard-fail)"
  exit 2
fi

# ── image_diff per checkpoint (when reference dir provided) ─────────────
EXIT_CODE=0
DIFF_RESULTS_JSON="$ARCH_DIR/result.json"
echo "{" > "$DIFF_RESULTS_JSON"
echo "  \"archetype\": \"$ARCHETYPE\"," >> "$DIFF_RESULTS_JSON"
echo "  \"run_id\": \"$RUN_ID\"," >> "$DIFF_RESULTS_JSON"
echo "  \"captured\": $_captured," >> "$DIFF_RESULTS_JSON"
echo "  \"checkpoints\": [" >> "$DIFF_RESULTS_JSON"

REF_BASE="${REFERENCE_DIR:-$GOLDEN_DIR}"

# Only the 4 bbox-keyed checkpoints from panel §2 are diffed against goldens.
declare -a DIFF_CHECKPOINTS=(
  "01-landing"
  "02-anon-chat-opener"
  "04-eclairage-card"
  "05-register-cta"
)

_first=1
for cp in "${DIFF_CHECKPOINTS[@]}"; do
  cand="$SHOTS_DIR/$cp.png"
  ref="$REF_BASE/$ARCHETYPE/$cp.png"
  if [ ! -f "$ref" ]; then
    log "skip diff: golden not present for $cp ($ref)"
    [ "$_first" -eq 0 ] && echo "    ," >> "$DIFF_RESULTS_JSON"
    cat >> "$DIFF_RESULTS_JSON" <<JSON
    {"checkpoint": "$cp", "skipped": true, "reason": "golden missing"}
JSON
    _first=0
    continue
  fi
  log "diff $cp : $ref vs $cand"
  set +e
  _diff_out="$(python3 "$IMAGE_DIFF" \
    --reference "$ref" \
    --candidate "$cand" \
    --bbox-key "$cp" \
    --bboxes "$BBOXES_FILE" \
    --out-dir "$DIFF_DIR" 2>&1)"
  _diff_rc=$?
  set -e
  log "diff rc=$_diff_rc"
  [ "$_first" -eq 0 ] && echo "    ," >> "$DIFF_RESULTS_JSON"
  echo "    {\"checkpoint\": \"$cp\", \"rc\": $_diff_rc, \"raw\": $(echo "$_diff_out" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))')}" >> "$DIFF_RESULTS_JSON"
  _first=0

  if [ "$_diff_rc" -ne 0 ]; then
    if [ "$cp" = "05-register-cta" ]; then
      log "FAIL: register-CTA bbox SSIM < threshold (exit 3 — TestFlight tap)"
      EXIT_CODE=3
    else
      [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=2
      log "FAIL: $cp bbox SSIM < threshold (exit 2)"
    fi
  fi
done

echo "  ]" >> "$DIFF_RESULTS_JSON"
echo "}" >> "$DIFF_RESULTS_JSON"

# ── summary.json (CI-readable, panel §5) ────────────────────────────────
SUMMARY="$RUN_DIR/summary.json"
TOTAL_ELAPSED=$(( $(date +%s) - _t0_total ))
{
  echo "{"
  echo "  \"run_id\": \"$RUN_ID\","
  echo "  \"archetypes\": [\"$ARCHETYPE\"],"
  echo "  \"per_archetype_timeout_s\": $PER_ARCHETYPE_TIMEOUT,"
  echo "  \"$ARCHETYPE\": {"
  echo "    \"captured\": $_captured,"
  echo "    \"elapsed_s\": $TOTAL_ELAPSED,"
  echo "    \"exit_code\": $EXIT_CODE"
  echo "  }"
  echo "}"
} > "$SUMMARY"

log "summary written : $SUMMARY"
log "elapsed : ${TOTAL_ELAPSED}s (budget ${PER_ARCHETYPE_TIMEOUT}s)"
if [ "$TOTAL_ELAPSED" -gt "$PER_ARCHETYPE_TIMEOUT" ]; then
  log "FAIL: wall-clock > ${PER_ARCHETYPE_TIMEOUT}s (panel §4 hard-fail)"
  [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=2
fi

log "exit $EXIT_CODE"
exit "$EXIT_CODE"
