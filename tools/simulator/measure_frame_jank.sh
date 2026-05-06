#!/usr/bin/env bash
# tools/simulator/measure_frame_jank.sh
#
# Phase 89 STAMP-03 (v2.12) — measures % of frames > 16ms over a 5s
# window of 4-card éclairage scroll-and-tap interaction.
#
# Method :
#   1. flutter build with `MINT_FRAME_TIMING_CAPTURE=true` dart-define
#      (registers `MintFrameTimingCapture.register()` in main.dart).
#   2. Boot sim + install + launch the app.
#   3. Drive walker through to the éclairage card (steps 00→04).
#   4. Start `xcrun simctl spawn booted log stream --predicate 'process == "Runner"'`
#      in background, grepping for `[MINT_FRAME_TIMING]`.
#   5. Drive scroll-and-tap on the éclairage card surface for 5 seconds
#      (alternating swipe up/down + occasional tap to mimic real user
#      reading flow).
#   6. Stop log stream, parse `[MINT_FRAME_TIMING]` lines, aggregate
#      total + over_16ms across the captured window, compute %.
#
# Pre-requisite : sim booted, walker_premier_eclairage.sh works.
#
# Spec : STAMP-03 — < 1% > 16ms on 4-card éclairage scroll-and-tap, 5s.
#
# Usage :
#   bash tools/simulator/measure_frame_jank.sh
#   bash tools/simulator/measure_frame_jank.sh --window-secs 7 --device "iPhone 17 Pro"

set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE="ch.mint.app"
WINDOW_SECS=5
ARCHETYPE="julien_swiss"

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --window-secs) WINDOW_SECS="$2"; shift 2 ;;
    --archetype) ARCHETYPE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "STAMP-03 frame-jank measurement"
echo "  device       : $DEVICE"
echo "  archetype    : $ARCHETYPE"
echo "  window_secs  : $WINDOW_SECS"
echo

# Sanity: sim booted ?
if ! xcrun simctl list devices "$DEVICE" 2>/dev/null | grep -q "Booted"; then
  echo "ERROR: $DEVICE not booted. Boot via walker first." >&2
  exit 1
fi

# Build with frame timing capture enabled.
echo "[STAMP-03] flutter build (with MINT_FRAME_TIMING_CAPTURE=true)..."
(cd "$REPO_ROOT/apps/mobile" && \
  CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \
    --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
    --dart-define=MINT_E2E_ARCHETYPE="$ARCHETYPE" \
    --dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a \
    --dart-define=MINT_WALKTHROUGH_PHASE=89 \
    --dart-define=MINT_DISABLE_BETA_MODAL=true \
    --dart-define=APP_LOCALE=fr \
    --dart-define=MINT_FRAME_TIMING_CAPTURE=true) >/dev/null 2>&1
APP_PATH="$REPO_ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"

# Reinstall + launch.
xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall booted "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE"
sleep 6  # cold-launch settle

# Need bounds for scroll. Quick-and-dirty hardcoded sim bounds.
# (Phase 86 audit A — iPhone 17 Pro at default Sim window position).
WIN_X=732 ; WIN_Y=236 ; WIN_W=456 ; WIN_H=972
SCROLL_X=$((WIN_X + WIN_W / 2))
SCROLL_TOP=$((WIN_Y + (WIN_H * 65 / 100)))
SCROLL_BOT=$((WIN_Y + (WIN_H * 30 / 100)))

# Tap CTA → opener → input → wait for éclairage card render
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
sleep 0.4
cliclick "c:$((WIN_X + WIN_W / 2)),$((WIN_Y + (WIN_H * 78 / 100)))" >/dev/null 2>&1
sleep 1
cliclick "c:$((WIN_X + WIN_W / 2)),$((WIN_Y + (WIN_H * 90 / 100)))" >/dev/null 2>&1
sleep 1
cliclick "kp:return" >/dev/null 2>&1
sleep 6  # let éclairage card render

# Start log stream capture.
LOG_FILE=$(mktemp -t mint_frame_jank_XXXXXX.log)
echo "[STAMP-03] capturing $WINDOW_SECS s of frames into $LOG_FILE"
xcrun simctl spawn booted log stream \
  --predicate 'processImagePath CONTAINS "Runner"' \
  --style compact >"$LOG_FILE" 2>/dev/null &
LOG_PID=$!

# Drive scroll-and-tap for $WINDOW_SECS seconds.
END_TS=$(($(date +%s) + WINDOW_SECS))
ACTION_INDEX=0
while [ $(date +%s) -lt $END_TS ]; do
  if [ $((ACTION_INDEX % 3)) -eq 0 ]; then
    # swipe up (scroll content down)
    cliclick "dd:$SCROLL_X,$SCROLL_TOP" "du:$SCROLL_X,$SCROLL_BOT" >/dev/null 2>&1
  elif [ $((ACTION_INDEX % 3)) -eq 1 ]; then
    # swipe down
    cliclick "dd:$SCROLL_X,$SCROLL_BOT" "du:$SCROLL_X,$SCROLL_TOP" >/dev/null 2>&1
  else
    # tap on card (somewhere safe)
    cliclick "c:$SCROLL_X,$((WIN_Y + (WIN_H * 50 / 100)))" >/dev/null 2>&1
  fi
  ACTION_INDEX=$((ACTION_INDEX + 1))
  sleep 0.3
done

# Stop log stream.
kill "$LOG_PID" 2>/dev/null || true
wait "$LOG_PID" 2>/dev/null || true

# Parse aggregated frame timings.
python3 - "$LOG_FILE" <<'PY'
import re, sys
path = sys.argv[1]
total = 0
over = 0
windows = 0
pat = re.compile(r"\[MINT_FRAME_TIMING\] window=1s total=(\d+) over_16ms=(\d+)")
with open(path) as f:
    for line in f:
        m = pat.search(line)
        if m:
            total += int(m.group(1))
            over += int(m.group(2))
            windows += 1
if total == 0:
    print("STAMP-03 RESULT: NO FRAMES CAPTURED — check MINT_FRAME_TIMING_CAPTURE dart-define wiring.")
    sys.exit(2)
pct = (over / total) * 100.0
print()
print("STAMP-03 RESULT")
print(f"  windows captured : {windows}")
print(f"  total frames     : {total}")
print(f"  frames > 16ms    : {over}")
print(f"  jank pct         : {pct:.3f}%")
gate = 1.0
verdict = "PASS" if pct < gate else "FAIL"
print(f"  STAMP-03 gate (< {gate}% over 16ms) : {verdict}")
PY
EXIT=$?
rm -f "$LOG_FILE"
exit $EXIT
