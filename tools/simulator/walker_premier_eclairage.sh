#!/usr/bin/env bash
# tools/simulator/walker_premier_eclairage.sh
#
# Phase 74 + Phase 82 (v2.11) — autonomous walker for Premier Éclairage flow.
# Drives an iOS simulator (iPhone 17 Pro) through the anonymous-chat →
# first éclairage → register-CTA loop and captures 6 deterministic
# screenshots per archetype.
#
# Phase 82 coord-system overhaul (audit A 2026-05-05) :
#   - Tap coords derived at runtime from the Simulator window bounds via
#     osascript (WALKC-01) — no hardcoded `cliclick c:NNN,NNN` desktop px.
#   - hero_bboxes.json calibrated for iPhone 17 Pro 1206×2622 native
#     resolution, Dynamic Island excluded (WALKC-02).
#   - _wait_for_ui requires ≥ 2 consecutive stable hashes, dumps hash
#     sequence to walker.log when retry > 3 (WALKC-03).
#   - Simulator window activated via osascript before each tap so cliclick
#     events route to sim and not to Terminal/IDE (WALKC-04).
#   - Beta-disclosure dismiss step explicit before funnel start (WALKC-05).
#   - Scroll-to-register-CTA uses cliclick swipe gesture (dd → du), not
#     tap-as-scroll (WALKC-06).
#
# Locked spec : .planning/phases/74-walker-premier-eclairage/PANEL-VERDICT.md
#               .planning/REQUIREMENTS.md WALKC-01..06 (v2.11)
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
if [ "${MINT_PRUNE_RUNTIME_ARTIFACTS:-0}" = "1" ]; then
  python3 "$REPO_ROOT/tools/simulator/prune_runtime_artifacts.py" \
    --days "${MINT_ARTIFACT_RETENTION_DAYS:-14}" --apply
fi
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

# SIMQ-08 (Phase 86) — timing constants extracted to one block, no
# magic numbers inline. Values sourced from Phase 82 audit A 2026-05-05.
BOOT_WAIT=4         # seconds, post-`xcrun simctl boot` settle
FRAME_SETTLE=800    # milliseconds, post-tap UI settle (used by _wait_for_ui)
TAP_SETTLE=400      # milliseconds, between tap and screenshot

# SIMQ-05 (Phase 86) — single-retry contract for the WHOLE walker run.
# When 1, on first non-zero exit the walker re-runs ONCE end-to-end.
# Default 0 (Phase 88 contract is « 0 retries policy » per XLOC-01..03).
RETRY_ONCE=0

# SIMQ-06 (Phase 86) — emit `walker-trace-<archetype>-<lang>-<timestamp>.json`
# manifest with Sentry event_id per step. When 0, no trace emitted.
RECORD_TRACE=0

# SIMQ-07 (Phase 86) — locale forwarded as `--dart-define=APP_LOCALE=<lang>`
# to flutter build for cold-restart locale (per ADR ; not toggle-via-Settings).
LOCALE="fr"
VALID_LOCALES=(fr de en)

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
    # SIMQ-05/06/07 (Phase 86) — wired flags
    --retry-once) RETRY_ONCE=1 ;;
    --record-trace) RECORD_TRACE=1 ;;
    --locale)
      i=$((i+1))
      LOCALE="${_args[$i]:-fr}"
      ;;
    --locale=*) LOCALE="${a#--locale=}" ;;
    *)
      echo "ERROR: unknown flag '$a' (try --help)" >&2
      exit 1
      ;;
  esac
  i=$((i+1))
done

# SIMQ-07 — validate locale slug
_locale_valid=0
for v in "${VALID_LOCALES[@]}"; do
  if [ "$LOCALE" = "$v" ]; then _locale_valid=1; break; fi
done
if [ "$_locale_valid" = "0" ]; then
  echo "ERROR: unknown locale '$LOCALE' (valid : ${VALID_LOCALES[*]})" >&2
  exit 1
fi

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

log "phase 74+82 walker_premier_eclairage (v2.11 coord overhaul)"
log "  archetype     : $ARCHETYPE"
log "  run-id        : $RUN_ID"
log "  archetype-json: $ARCHETYPE_JSON"
log "  shots-dir     : $SHOTS_DIR"
log "  dry-run       : $DRY_RUN"

# ── dry-run path : enumerate plan + exit ────────────────────────────────
if [ "$DRY_RUN" = "1" ]; then
  log "dry-run mode — no sim, no build, no taps"
  log "would run sim hygiene before build (Phase 83 SIMH-01..02) :"
  log "  xcrun simctl shutdown all || xcrun simctl shutdown <DEVICE>"
  log "  xcrun simctl erase <DEVICE>   (kills SharedPrefs + beta-disclosure flag)"
  log "  xcrun simctl boot <DEVICE>"
  log "  xcrun simctl uninstall <DEVICE> ch.mint.app  (defensive idempotence)"
  log "would build flutter ios sim with :"
  log "  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1"
  log "  --dart-define=MINT_E2E_ARCHETYPE=$ARCHETYPE"
  log "  --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=<archetype.expected_eclairage.kind>"
  log "  --dart-define=MINT_DISABLE_BETA_MODAL=true   (SIMH-03 short-circuit)"
  log "would capture 6 checkpoints under $SHOTS_DIR :"
  log "  00-cold-launch.png  01-landing.png  02-anon-chat-opener.png"
  log "  03-after-turn1.png  04-eclairage-card.png  05-register-cta.png"
  log "would run image_diff.py per checkpoint with bboxes from $BBOXES_FILE"
  log "phase-82 helpers wired :"
  log "  _get_sim_window_bounds  (osascript bounds of window 1, WALKC-01)"
  log "  _activate_simulator     (osascript activate before each tap, WALKC-04)"
  log "  _anchor_to_desktop      (anchor% → desktop px, WALKC-01)"
  log "  _tap_at_anchor          (anchor lookup → desktop tap, WALKC-01)"
  log "  _swipe                  (cliclick dd:X,Y du:X,Y2 swipe gesture, WALKC-06)"
  log "  _dismiss_beta_modal     (CTA at 50%vw × 80%vh, WALKC-05)"
  log "  _wait_for_ui            (≥ 2 consecutive stable hashes, WALKC-03)"
  log "anchor table (logical % of sim screen) :"
  log "  cta_landing  = (50%, 78%)   chip_1   = (50%, 74%)"
  log "  input_field  = (50%, 90%)   scroll_a = (50%, 65%)  scroll_b = (50%, 30%)"
  log "  beta_dismiss = (50%, 80%)"
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

# Sim runtime preflight (panel §6 mitigation #1) — fail fast on absence ;
# accept any iOS version present on the box. Pin to the booted device's
# runtime by default ; allow override via $MINT_WALKER_REQUIRED_RUNTIME for
# CI parity. Pass the empty string to opt out entirely.
REQUIRED_RUNTIME="${MINT_WALKER_REQUIRED_RUNTIME-}"
if [ -z "${REQUIRED_RUNTIME+__set__}" ]; then
  REQUIRED_RUNTIME=$(xcrun simctl list devices booted 2>/dev/null \
    | awk '/^-- iOS / { for (i=2; i<=NF; i++) printf "%s ", $i; print "" }' \
    | tr -d -- '-' | sed -e 's/^ *//' -e 's/ *$//' | head -n 1)
fi
if [ -n "$REQUIRED_RUNTIME" ]; then
  if ! xcrun simctl list runtimes 2>/dev/null | grep -q "$REQUIRED_RUNTIME"; then
    echo "ERROR: simulator runtime '$REQUIRED_RUNTIME' missing" >&2
    echo "Install via Xcode → Settings → Components, or set" >&2
    echo "MINT_WALKER_REQUIRED_RUNTIME='' to skip the preflight." >&2
    exit 1
  fi
fi

DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
BUNDLE="ch.mint.app"

log "preflight OK — runtime '${REQUIRED_RUNTIME:-skipped}' present, device='$DEVICE'"

# ── helpers (copied verbatim from walker_audit_tap_render.sh:252-281,
#     panel §1 mandate — DO NOT source walker.sh) ──────────────────────
#     Phase 82 (v2.11) overhauls the coord system : taps are now derived
#     from runtime sim-window bounds (osascript) rather than hardcoded
#     desktop pixels. The cache + anchor table are below.

_snap() {
  local out="$1"
  mkdir -p "$(dirname "$out")"
  xcrun simctl io booted screenshot "$out"
}

_sha() {
  shasum "$1" 2>/dev/null | awk '{print $1}'
}

# WALKC-01 — read Simulator window bounds at runtime. Output format :
#   "X Y W H"  (desktop logical px, content area, no chrome).
# Cached per run to avoid spamming osascript. Populated by
# _refresh_sim_window_bounds(). Bound names mirror AppleScript bounds
# tuple (x1, y1, x2, y2) ; we convert to (X, Y, W, H) for arithmetic.
_SIM_WIN_X=""
_SIM_WIN_Y=""
_SIM_WIN_W=""
_SIM_WIN_H=""

_get_sim_window_bounds() {
  # Returns "X Y W H" on stdout (single line, space-separated).
  # Side-effect : populates _SIM_WIN_X/Y/W/H for downstream callers.
  # v2.12 Phase 86 — direct `tell application "Simulator"` errors with
  # -1728 (« Can't get window 1 ») on iOS 26.2 sim runtime even when the
  # Simulator app is alive. Fallback to `tell process "Simulator"` via
  # System Events which exposes position + size of window 1 reliably.
  # Last-resort hardcoded fallback uses audit-A measured bounds (window
  # at 732,236 size 456×972 for iPhone 17 Pro at default position) so
  # the walker is robust to Simulator AppleScript flakiness.
  local raw x1 y1 x2 y2 pos size
  # Activate first so window 1 is queryable.
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  sleep 0.3
  pos=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get position of window 1' 2>/dev/null)
  size=$(osascript -e 'tell application "System Events" to tell process "Simulator" to get size of window 1' 2>/dev/null)
  if [ -n "$pos" ] && [ -n "$size" ]; then
    # pos like "732, 236" ; size like "456, 972"
    x1=$(echo "$pos"  | awk -F, '{gsub(/ /,"",$1); print $1}')
    y1=$(echo "$pos"  | awk -F, '{gsub(/ /,"",$2); print $2}')
    _SIM_WIN_X="$x1"
    _SIM_WIN_Y="$y1"
    _SIM_WIN_W=$(echo "$size" | awk -F, '{gsub(/ /,"",$1); print $1}')
    _SIM_WIN_H=$(echo "$size" | awk -F, '{gsub(/ /,"",$2); print $2}')
    echo "$_SIM_WIN_X $_SIM_WIN_Y $_SIM_WIN_W $_SIM_WIN_H"
    return 0
  fi
  # Fallback to legacy direct query (works on older Sim runtimes)
  raw=$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Simulator"
  if (count of windows) is 0 then return "0,0,0,0"
  set b to bounds of window 1
  return (item 1 of b as text) & "," & (item 2 of b as text) & "," & (item 3 of b as text) & "," & (item 4 of b as text)
end tell
APPLESCRIPT
)
  if [ -z "$raw" ] || [ "$raw" = "0,0,0,0" ]; then
    # Last-resort hardcoded fallback (audit A measured bounds).
    # iPhone 17 Pro at default Simulator window position on Mac mini :
    # X=732 Y=236 W=456 H=972. Override via env if needed.
    _SIM_WIN_X="${MINT_WALKER_SIM_X:-732}"
    _SIM_WIN_Y="${MINT_WALKER_SIM_Y:-236}"
    _SIM_WIN_W="${MINT_WALKER_SIM_W:-456}"
    _SIM_WIN_H="${MINT_WALKER_SIM_H:-972}"
    echo "$_SIM_WIN_X $_SIM_WIN_Y $_SIM_WIN_W $_SIM_WIN_H"
    return 0
  fi
  x1=$(echo "$raw" | awk -F, '{print $1}')
  y1=$(echo "$raw" | awk -F, '{print $2}')
  x2=$(echo "$raw" | awk -F, '{print $3}')
  y2=$(echo "$raw" | awk -F, '{print $4}')
  _SIM_WIN_X="$x1"
  _SIM_WIN_Y="$y1"
  _SIM_WIN_W=$(( x2 - x1 ))
  _SIM_WIN_H=$(( y2 - y1 ))
  echo "$_SIM_WIN_X $_SIM_WIN_Y $_SIM_WIN_W $_SIM_WIN_H"
}

_refresh_sim_window_bounds() {
  # _get_sim_window_bounds runs in a subshell so its global side-effects
  # are lost — parse stdout ("X Y W H") into the parent shell vars here.
  local raw
  raw=$(_get_sim_window_bounds) || return 1
  _SIM_WIN_X=$(echo "$raw" | awk '{print $1}')
  _SIM_WIN_Y=$(echo "$raw" | awk '{print $2}')
  _SIM_WIN_W=$(echo "$raw" | awk '{print $3}')
  _SIM_WIN_H=$(echo "$raw" | awk '{print $4}')
  log "osascript bounds: X=$_SIM_WIN_X Y=$_SIM_WIN_Y W=$_SIM_WIN_W H=$_SIM_WIN_H"
}

# WALKC-04 — bring the Simulator window to the front so cliclick events
# route to the sim, not Terminal/IDE. Called before each tap helper.
_activate_simulator() {
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
}

# WALKC-01 — convert (anchor_x_pct, anchor_y_pct) ∈ [0,1] within the sim
# screen content into desktop logical px. Echoes "X Y" on stdout.
_anchor_to_desktop() {
  local pct_x="$1" pct_y="$2"
  if [ -z "$_SIM_WIN_W" ] || [ "$_SIM_WIN_W" -eq 0 ]; then
    _refresh_sim_window_bounds || return 1
  fi
  # awk handles float % values without bash float-math limitation.
  awk -v wx="$_SIM_WIN_X" -v wy="$_SIM_WIN_Y" \
      -v ww="$_SIM_WIN_W" -v wh="$_SIM_WIN_H" \
      -v px="$pct_x"     -v py="$pct_y" \
      'BEGIN { printf "%d %d\n", wx + (ww * px), wy + (wh * py) }'
}

# WALKC-01 + WALKC-04 — anchor name → activate sim → tap. The anchor
# table is declared once (below) and referenced by name everywhere in
# the script ; this is the single point of truth for coords (zero
# `cliclick c:NNN,NNN` desktop literals in the script body).
# bash-3.2 compat (macOS default 3.2.57) — no `declare -A`. Use `case`
# for the anchor lookup. This is the single point of truth ; zero
# `cliclick c:NNN,NNN` desktop literals in the script body.
_anchor_lookup() {
  # Echoes "$x_pct $y_pct" for the named anchor, returns 1 if unknown.
  case "$1" in
    cta_landing)   echo "0.50 0.78" ;;
    chip_1)        echo "0.50 0.74" ;;
    input_field)   echo "0.50 0.90" ;;
    beta_dismiss)  echo "0.50 0.80" ;;
    # Swipe endpoints for scroll-to-register-CTA (WALKC-06).
    swipe_start)   echo "0.50 0.65" ;;
    swipe_end)     echo "0.50 0.30" ;;
    *)             return 1 ;;
  esac
}

_tap_at_anchor() {
  local name="$1"
  local pair
  pair=$(_anchor_lookup "$name") || {
    echo "ERROR: unknown anchor '$name'" >&2
    return 1
  }
  local px="${pair%% *}"
  local py="${pair##* }"
  if [ -z "$px" ] || [ -z "$py" ]; then
    echo "ERROR: unknown anchor '$name'" >&2
    return 1
  fi
  _activate_simulator
  local xy
  xy=$(_anchor_to_desktop "$px" "$py") || return 1
  local x="${xy%% *}"
  local y="${xy##* }"
  log "tap_at_anchor $name → ($x, $y) [pct ${px}, ${py}]"
  cliclick "c:${x},${y}"
  sleep 0.4
}

# Backwards-compat shim — Phase-82 deprecates raw _tap_at desktop px.
# Kept ONLY for the rare case a tap target is computed dynamically from
# image-recognition (none today). New callsites MUST use _tap_at_anchor.
_tap_at() {
  local x="$1" y="$2"
  echo "WARN: _tap_at($x,$y) — deprecated by WALKC-01, prefer _tap_at_anchor" >&2
  _activate_simulator
  cliclick "c:${x},${y}"
  sleep 0.4
}

# WALKC-06 — swipe from (x1,y1) to (x2,y2) using cliclick drag-down /
# drag-up. Replaces the no-op « tap-as-scroll » that Phase 74 used.
# Inputs are desktop px (resolved by callers via _anchor_to_desktop or
# _swipe_anchor wrapper below).
_swipe() {
  local x1="$1" y1="$2" x2="$3" y2="$4"
  log "swipe ($x1,$y1) → ($x2,$y2)"
  _activate_simulator
  cliclick "dd:${x1},${y1}" "du:${x2},${y2}"
  sleep 0.5
}

_swipe_anchor() {
  local name_a="$1" name_b="$2"
  local pair_a pair_b
  pair_a=$(_anchor_lookup "$name_a") || {
    echo "ERROR: swipe anchor '$name_a' not declared" >&2
    return 1
  }
  pair_b=$(_anchor_lookup "$name_b") || {
    echo "ERROR: swipe anchor '$name_b' not declared" >&2
    return 1
  }
  local pax="${pair_a%% *}" pay="${pair_a##* }"
  local pbx="${pair_b%% *}" pby="${pair_b##* }"
  local xy_a xy_b
  xy_a=$(_anchor_to_desktop "$pax" "$pay") || return 1
  xy_b=$(_anchor_to_desktop "$pbx" "$pby") || return 1
  _swipe "${xy_a%% *}" "${xy_a##* }" "${xy_b%% *}" "${xy_b##* }"
}

# WALKC-03 — quiescence detector. Requires ≥ 2 consecutive identical
# SHA hashes before returning, NOT 1 like Phase 74. When retry > 3, the
# full hash sequence is dumped to walker.log so a stuck-UI false-positive
# is auditable.
_wait_for_ui() {
  local max="${1:-8}"
  local h0="" h1="" cur="" i=0
  local -a seq=()
  while [ "$i" -lt "$max" ]; do
    i=$((i+1))
    xcrun simctl io booted screenshot /tmp/_walker_phase82_poll.png \
      >/dev/null 2>&1 || true
    cur=$(shasum /tmp/_walker_phase82_poll.png 2>/dev/null | awk '{print $1}')
    seq+=("$cur")
    # Need 3 samples : two identical at the end → ≥ 2 consecutive stable.
    if [ -n "$h0" ] && [ -n "$h1" ] && [ "$h0" = "$h1" ] && [ "$h1" = "$cur" ]; then
      return 0
    fi
    h0="$h1"
    h1="$cur"
    if [ "$i" -gt 3 ]; then
      log "wait_for_ui retry=$i hash_seq=${seq[*]}"
    fi
    sleep 1
  done
  log "wait_for_ui exhausted after $max retries — hash_seq=${seq[*]}"
  return 1
}

# Phase-74 helper : send literal text into focused input, then RETURN
# (panel §6 mitigation #2 — avoid send-button tap).
_type_text() {
  local txt="$1"
  _activate_simulator
  cliclick "t:${txt}"
  sleep 0.5
  cliclick "kp:return"
}

# Dismiss soft keyboard (panel §6 mitigation #4) — mandatory between
# turn 1 and turn 2 when chips need to be tappable.
_dismiss_keyboard() {
  _activate_simulator
  cliclick "kp:esc"
  sleep 0.3
}

# WALKC-05 + SIMH-03 — explicit beta-disclosure dismiss step. Phase 83
# wires `--dart-define=MINT_DISABLE_BETA_MODAL=true` into the flutter
# build invocation, which short-circuits `maybeShow()` so the modal is
# never rendered in walker runs. This step is therefore a defensive
# warm-up (belt+suspenders) in case the dart-define is ever stripped or
# the build flag drifts. The CTA tap at (50% vw × 80% vh) lands on dead
# pixels under the landing CTA when the modal is suppressed, harmless.
_dismiss_beta_modal() {
  log "step_beta_disclosure_dismiss (anchor=beta_dismiss)"
  log "  note: MINT_DISABLE_BETA_MODAL=true via dart-define (SIMH-03);"
  log "        modal expected absent → tap is a defensive no-op."
  _tap_at_anchor beta_dismiss
  sleep 0.6
  _wait_for_ui 4 || true
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

# SIMH-01 (Phase 83) — fresh sim state per archetype run :
# shutdown the target device, erase, then boot. Eliminates SharedPrefs
# pollution + beta-disclosure flag carry-over between consecutive archetype
# runs (audit D 2026-05-05). `shutdown all` is kept as a defensive sweep
# in case a stale sim from another runtime is still booted (CI parity).
log "sim hygiene (SIMH-01) — shutdown all → shutdown $DEVICE → erase → boot"
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl erase "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE"
open -a Simulator || true

log "flutter build ios --simulator --no-codesign (archetype=$ARCHETYPE kind=$EXPECTED_KIND)"
# --no-codesign required when the working tree lives under an iCloud Drive
# .nosync mount (com.apple.provenance xattrs). Mirrors walker.sh:587 +
# walker_audit_tap_render.sh:233 (per memory feedback_diff_against_existing_tool).
#
# WALKC-07 REVERTED 2026-05-05 audit C — `flutter clean` between
# archetypes was found to ALSO trigger codesign failures on subsequent
# runs (because every clean rebuild has to re-codesign Flutter.framework
# which has the system-immutable `com.apple.provenance` xattr from SDK).
# Empirically, the SDK xattr is the constant ; flutter clean made the
# problem worse by forcing fresh codesign each time. Keep build/ between
# archetype runs so Flutter's debug_unpack_ios sees an already-codesigned
# Flutter.framework and skips re-signing. The dart-define values that
# differ per archetype don't require a clean rebuild — kernel snapshot
# regeneration is sufficient.
log "WALKC-07 (reverted) — keep build/ between archetypes (skip re-codesign)"
SENTRY_FLAG=""
if [ -n "${SENTRY_DSN_STAGING:-}" ]; then
  SENTRY_FLAG="--dart-define=SENTRY_DSN=${SENTRY_DSN_STAGING}"
fi

# SIMH-03 (Phase 83) — `MINT_DISABLE_BETA_MODAL=true` short-circuits
# `BetaProgramDisclosureSheet.maybeShow()` so the modal never appears in
# walker builds. This is belt-and-suspenders alongside Phase 82's explicit
# `_dismiss_beta_modal` step (WALKC-05). Production builds never set this.
#
# WALKC-08 (Phase 86 audit B 2026-05-05) — `CODE_SIGNING_ALLOWED=NO` env
# var disables ad-hoc codesign of Flutter.framework on simulator builds.
# macOS Sequoia/Tahoe tags Flutter SDK Flutter.framework/Flutter binary
# with `com.apple.provenance` xattr (system-immutable, survives
# xattr -cr / xattr -d / cp / ditto / tar / Python rewrite). codesign
# refuses to sign files with this xattr (treats it as "resource fork
# detritus"). `--no-codesign` is insufficient because Xcode still
# attempts ad-hoc signing of embedded frameworks. CODE_SIGNING_ALLOWED=NO
# tells Xcode to skip that step entirely. Sim builds don't need a
# real signature anyway. Verified on iPhone 17 Pro sim 2026-05-05.
(cd "$REPO_ROOT/apps/mobile" && \
  CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_E2E_ARCHETYPE="$ARCHETYPE" \
  --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND="$EXPECTED_KIND" \
  --dart-define=MINT_WALKTHROUGH_PHASE=74 \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=APP_LOCALE="$LOCALE" \
  ${SENTRY_FLAG}) 2>&1 | tee -a "$LOG"

APP_PATH="$REPO_ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
if [ ! -d "$APP_PATH" ]; then
  log "FAIL: Runner.app not found at $APP_PATH"
  exit 1
fi

# SIMH-02 (Phase 83) — defensive idempotence guard. If a prior run left
# the bundle installed and the erase above missed it (rare, but happens
# when erase races with a SpringBoard reload), uninstall first so the
# subsequent install is clean. Safe no-op when bundle isn't present.
log "sim hygiene (SIMH-02) — uninstall $BUNDLE before install (defensive)"
xcrun simctl uninstall "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true

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

# WALKC-01 — derive sim window bounds at runtime, log them so anchor
# math is auditable in walker.log.
_refresh_sim_window_bounds || {
  log "FAIL: cannot read Simulator window bounds (osascript empty)"
  exit 1
}

# 00 cold launch
_within_budget || exit 2
_snap "$SHOTS_DIR/00-cold-launch.png"
log "captured 00-cold-launch"

# WALKC-05 — beta-disclosure dismiss BEFORE landing capture so the
# landing screenshot isn't polluted by the modal.
_within_budget || exit 2
_dismiss_beta_modal

# 01 landing
_within_budget || exit 2
_wait_for_ui 8 || log "wait_for_ui timeout pre-01-landing — proceeding"
_snap "$SHOTS_DIR/01-landing.png"
log "captured 01-landing"

# tap landing CTA → opener bubble + 3 chips
_within_budget || exit 2
_tap_at_anchor cta_landing
sleep 2.5
_wait_for_ui 6 || log "wait_for_ui timeout pre-02-opener — proceeding"
_snap "$SHOTS_DIR/02-anon-chat-opener.png"
log "captured 02-anon-chat-opener"

# turn 1 — type deterministic prompt #1 + return
_within_budget || exit 2
_tap_at_anchor input_field
sleep 0.4
_type_text "$PROMPT_1"
_wait_for_ui 12 || log "wait_for_ui timeout post-turn1 — proceeding"  # staging Anthropic P95 (panel §1)
_snap "$SHOTS_DIR/03-after-turn1.png"
log "captured 03-after-turn1"

# turn 2 — dismiss keyboard, type prompt #2, wait for ECL-01 card
_within_budget || exit 2
_dismiss_keyboard
_tap_at_anchor input_field
sleep 0.4
_type_text "$PROMPT_2"
_wait_for_ui 12 || log "wait_for_ui timeout post-turn2 — proceeding"
_snap "$SHOTS_DIR/04-eclairage-card.png"
log "captured 04-eclairage-card"

# 05 register CTA — WALKC-06 swipe-up gesture (NOT tap-as-scroll which
# was a no-op in Phase 74). Drag from swipe_start (65% vh) up to
# swipe_end (30% vh) brings the register CTA into viewport.
_within_budget || exit 2
_swipe_anchor swipe_start swipe_end
sleep 0.6
_wait_for_ui 4 || log "wait_for_ui timeout post-scroll — proceeding"
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
