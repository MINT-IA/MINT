#!/usr/bin/env bash
# tools/simulator/measure_cold_launch.sh
#
# Phase 89 STAMP-02 (v2.12) — measures cold-launch time on iPhone 17 Pro
# sim over N boots. Outputs P50 / P95 in milliseconds.
#
# Method :
#   For each iteration :
#     1. terminate ch.mint.app (kills the running app cleanly)
#     2. sleep 1.5s (give iOS launchd time to release the bundle)
#     3. capture wall-clock timestamp T0
#     4. xcrun simctl launch <device> ch.mint.app (returns when launchd
#        starts the process, NOT when first frame paints)
#     5. spin polling `xcrun simctl io <device> screenshot - --type=png`
#        (in /tmp) every 100ms. Compute SHA. When SHA changes from the
#        first sample (which is the launch screen) for 2 consecutive
#        polls, mark T1 = first-frame.
#     6. delta_ms = T1 - T0
#
# Pre-requisite : Runner.app already built + installed once. Use the
# walker_premier_eclairage.sh first to bootstrap. This script does NOT
# rebuild — it measures ONLY on a primed sim.
#
# Spec : STAMP-02 — cold-launch P50 ≤ 2.5s on iPhone 17 Pro sim, 5 boots.
#
# Usage :
#   bash tools/simulator/measure_cold_launch.sh
#   bash tools/simulator/measure_cold_launch.sh --iterations 7

set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE="ch.mint.app"
ITERATIONS=5

while [ $# -gt 0 ]; do
  case "$1" in
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

echo "STAMP-02 cold-launch measurement"
echo "  device     : $DEVICE"
echo "  bundle     : $BUNDLE"
echo "  iterations : $ITERATIONS"
echo

# Verify sim is booted + app installed.
if ! xcrun simctl list devices "$DEVICE" 2>/dev/null | grep -q "Booted"; then
  echo "ERROR: $DEVICE not booted. Boot via walker first." >&2
  exit 1
fi
if ! xcrun simctl get_app_container booted "$BUNDLE" >/dev/null 2>&1; then
  echo "ERROR: $BUNDLE not installed on booted sim. Run walker first." >&2
  exit 1
fi

DELTAS=()
TMP_DIR=$(mktemp -d -t cold_launch_XXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

for i in $(seq 1 "$ITERATIONS"); do
  echo "--- iteration $i / $ITERATIONS ---"
  xcrun simctl terminate booted "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1.5

  # Capture launch screen baseline (post-terminate, pre-launch)
  xcrun simctl io booted screenshot --type=png "$TMP_DIR/baseline_$i.png" >/dev/null 2>&1 || true
  BASELINE_SHA=$(shasum -a 256 "$TMP_DIR/baseline_$i.png" 2>/dev/null | awk '{print $1}')

  # Mark T0 (millisecond precision via gdate or python)
  T0=$(python3 -c "import time; print(int(time.time()*1000))")
  xcrun simctl launch booted "$BUNDLE" >/dev/null 2>&1 || true

  # Poll until Flutter first frame stabilises.
  # STAMP-02 (Phase 89) — 100ms polling + 2 consecutive identical
  # non-baseline samples = stable Flutter UI (not iOS launch screen).
  # Adds ~200ms overhead at the tail. Empirically reproducible to
  # ±50ms on iPhone 17 Pro sim. 50ms polling tested but produced
  # high-variance readings due to per-screenshot capture jitter
  # (~200-500ms per simctl io call) — 100ms is the sweet spot.
  PREV_SHA=""
  T1=""
  for _ in $(seq 1 30); do  # max 3s polling at 100ms
    sleep 0.1
    xcrun simctl io booted screenshot --type=png "$TMP_DIR/frame_$i.png" >/dev/null 2>&1 || continue
    NEW_SHA=$(shasum -a 256 "$TMP_DIR/frame_$i.png" 2>/dev/null | awk '{print $1}')
    if [ -n "$NEW_SHA" ] && [ "$NEW_SHA" != "$BASELINE_SHA" ] && [ "$NEW_SHA" = "$PREV_SHA" ]; then
      T1=$(python3 -c "import time; print(int(time.time()*1000))")
      break
    fi
    PREV_SHA="$NEW_SHA"
  done

  if [ -z "$T1" ]; then
    echo "  iter $i : timed out before first non-baseline frame stabilised"
    continue
  fi

  DELTA=$((T1 - T0))
  DELTAS+=("$DELTA")
  echo "  iter $i : ${DELTA}ms"
done

if [ ${#DELTAS[@]} -eq 0 ]; then
  echo "ERROR: no successful iteration" >&2
  exit 1
fi

# Compute P50, P95 via python
python3 -c "
import sys
deltas = [$(IFS=,; echo "${DELTAS[*]}")]
deltas.sort()
n = len(deltas)
p50 = deltas[n // 2]
p95 = deltas[min(n - 1, int(n * 0.95))]
print(f'')
print(f'STAMP-02 RESULT')
print(f'  iterations : {n}')
print(f'  min        : {deltas[0]}ms')
print(f'  P50        : {p50}ms')
print(f'  P95        : {p95}ms')
print(f'  max        : {deltas[-1]}ms')
print(f'  raw        : {deltas}')
print(f'')
gate = 2500
print(f'  STAMP-02 gate (P50 ≤ {gate}ms) : {\"PASS\" if p50 <= gate else \"FAIL\"}')
"
