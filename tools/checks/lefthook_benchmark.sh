#!/usr/bin/env bash
# lefthook_benchmark.sh — Phase 34 D-26 P95 regression guard.
#
# Measures `lefthook run pre-commit` wall-clock over 10 iterations, discards
# the first 2 (Pitfall 10 — cold cache + Python import warmup), reports the
# P95 of the remaining 8. Exits 1 if --assert-p95=<N> is passed and P95 > N.
#
# Usage:
#   bash tools/checks/lefthook_benchmark.sh                 # report only
#   bash tools/checks/lefthook_benchmark.sh --assert-p95=5  # fail if P95 >5s
#
# Technical English only — dev-facing. Per RESEARCH Anti-Patterns (no FR).
set -e

ITERATIONS=10
WARMUP=2
ASSERT_P95=""

for arg in "$@"; do
  case "$arg" in
    --assert-p95=*) ASSERT_P95="${arg#--assert-p95=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

BENCH_LOG=$(mktemp)
trap 'rm -f "$BENCH_LOG"' EXIT

echo "[benchmark] Running $ITERATIONS iterations of lefthook run pre-commit (discarding first $WARMUP as warmup)..."
for i in $(seq 1 $ITERATIONS); do
  # /usr/bin/time -p prints `real X.XX` to stderr — portable macOS + Linux.
  { /usr/bin/time -p lefthook run pre-commit 2>>"$BENCH_LOG" ; } >/dev/null 2>&1 || true
done

# Parse real seconds, discard first $WARMUP, compute P95 (stdlib Python 3.9).
P95=$(python3 - <<EOF
import statistics
nums = []
with open("$BENCH_LOG") as f:
    for line in f:
        parts = line.split()
        if len(parts) == 2 and parts[0] == "real":
            nums.append(float(parts[1]))
kept = nums[$WARMUP:]
if not kept:
    print("NaN")
else:
    ordered = sorted(kept)
    # P95 index for 8 samples: int(8*0.95)=7 -> last element (worst of 8).
    idx = min(int(len(ordered) * 0.95), len(ordered) - 1)
    print(f"{ordered[idx]:.3f}")
EOF
)

echo "[benchmark] P95 (over last $((ITERATIONS - WARMUP)) runs): ${P95}s"

if [ -n "$ASSERT_P95" ]; then
  # Compare with awk — bash can't do float compare natively.
  FAIL=$(awk -v p95="$P95" -v t="$ASSERT_P95" 'BEGIN { print (p95+0 > t+0) ? "1" : "0" }')
  if [ "$FAIL" = "1" ]; then
    echo "[benchmark] FAIL — P95 ${P95}s exceeds threshold ${ASSERT_P95}s" >&2
    exit 1
  fi
  echo "[benchmark] OK — P95 under threshold"
fi

exit 0
