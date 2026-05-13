#!/usr/bin/env bash
# Self-test for tools/simulator/maestro_with_watchdog.sh
#
# Verifies the stall-detector watchdog actually fires when the child
# process goes silent. Uses a deliberate-hang fake-maestro stub
# (sleep loop with no stdout) so the test runs offline without a real
# iOS sim.
#
# Three scenarios:
#   1. Fast-clean exit: stub prints lines fast → watchdog never fires →
#      exit 0.
#   2. Stall: stub silent for > MAESTRO_STALL_THRESHOLD seconds →
#      watchdog kills with exit 124, artifact dir contains STALLED.
#   3. Hard limit: stub keeps printing but exceeds hard limit →
#      exit 137 + STALLED hard_limit marker.
#
# Run:
#   tools/simulator/maestro_with_watchdog_test.sh
#
# Exit:
#   0 — all assertions passed
#   1 — at least one assertion failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WD="$SCRIPT_DIR/maestro_with_watchdog.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAIL=0

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "  FAIL  $label — expected exit $expected, got $actual"
    FAIL=1
  else
    echo "  PASS  $label (exit $actual)"
  fi
}

assert_file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS  $label — file exists"
  else
    echo "  FAIL  $label — does not exist: $path"
    FAIL=1
  fi
}

# ── Scenario 1 — fast-clean exit ───────────────────────────────────────
echo "=== Scenario 1 — fast-clean exit ==="
mkdir -p "$TMP/scenario1"
cp "$WD" "$TMP/scenario1/maestro_with_watchdog.sh"
cat > "$TMP/scenario1/maestro_env.sh" <<'EOF'
#!/usr/bin/env bash
for i in 1 2 3 4 5; do echo "[stub] line $i"; sleep 0.2; done
exit 0
EOF
chmod +x "$TMP/scenario1/maestro_with_watchdog.sh" "$TMP/scenario1/maestro_env.sh"

set +e
MAESTRO_STALL_THRESHOLD=10 \
  MAESTRO_STALL_PROBE_INTERVAL=5 \
  MAESTRO_HARD_LIMIT=20 \
  MINT_WALKER_ARTIFACTS="$TMP/scenario1/artifacts" \
  "$TMP/scenario1/maestro_with_watchdog.sh" test fake-flow.yaml >/dev/null 2>&1
rc=$?
set -e
assert_exit 0 "$rc" "scenario 1 fast-clean exit"
if [[ -f "$TMP/scenario1/artifacts/STALLED" ]]; then
  echo "  FAIL  scenario 1 — STALLED marker present on clean exit"
  FAIL=1
else
  echo "  PASS  scenario 1 — no STALLED marker on clean exit"
fi

# ── Scenario 2 — stall ─────────────────────────────────────────────────
echo "=== Scenario 2 — stall (silent stub) ==="
mkdir -p "$TMP/scenario2"
cp "$WD" "$TMP/scenario2/maestro_with_watchdog.sh"
cat > "$TMP/scenario2/maestro_env.sh" <<'EOF'
#!/usr/bin/env bash
echo "[stub] starting"
sleep 30
echo "[stub] would have completed"
EOF
chmod +x "$TMP/scenario2/maestro_with_watchdog.sh" "$TMP/scenario2/maestro_env.sh"

set +e
MAESTRO_STALL_THRESHOLD=4 \
  MAESTRO_STALL_PROBE_INTERVAL=2 \
  MAESTRO_HARD_LIMIT=60 \
  MINT_WALKER_ARTIFACTS="$TMP/scenario2/artifacts" \
  "$TMP/scenario2/maestro_with_watchdog.sh" test fake-flow.yaml >/dev/null 2>&1
rc=$?
set -e
assert_exit 124 "$rc" "scenario 2 stall detected"
assert_file_exists "$TMP/scenario2/artifacts/STALLED" "scenario 2 STALLED marker"
assert_file_exists "$TMP/scenario2/artifacts/stall-summary.txt" "scenario 2 stall-summary.txt"
if [[ -f "$TMP/scenario2/artifacts/STALLED" ]]; then
  reason=$(cat "$TMP/scenario2/artifacts/STALLED")
  if [[ "$reason" == stall_* ]]; then
    echo "  PASS  scenario 2 — STALLED reason starts with 'stall_' ($reason)"
  else
    echo "  FAIL  scenario 2 — STALLED reason is '$reason', expected stall_*"
    FAIL=1
  fi
fi

# ── Scenario 3 — hard limit ────────────────────────────────────────────
echo "=== Scenario 3 — hard limit ==="
mkdir -p "$TMP/scenario3"
cp "$WD" "$TMP/scenario3/maestro_with_watchdog.sh"
cat > "$TMP/scenario3/maestro_env.sh" <<'EOF'
#!/usr/bin/env bash
for i in $(seq 1 30); do echo "[stub] tick $i"; sleep 1; done
EOF
chmod +x "$TMP/scenario3/maestro_with_watchdog.sh" "$TMP/scenario3/maestro_env.sh"

set +e
MAESTRO_STALL_THRESHOLD=999 \
  MAESTRO_STALL_PROBE_INTERVAL=2 \
  MAESTRO_HARD_LIMIT=6 \
  MINT_WALKER_ARTIFACTS="$TMP/scenario3/artifacts" \
  "$TMP/scenario3/maestro_with_watchdog.sh" test fake-flow.yaml >/dev/null 2>&1
rc=$?
set -e
assert_exit 137 "$rc" "scenario 3 hard limit"
assert_file_exists "$TMP/scenario3/artifacts/STALLED" "scenario 3 STALLED marker"
if [[ -f "$TMP/scenario3/artifacts/STALLED" ]]; then
  reason=$(cat "$TMP/scenario3/artifacts/STALLED")
  if [[ "$reason" == hard_limit* ]]; then
    echo "  PASS  scenario 3 — STALLED reason starts with 'hard_limit' ($reason)"
  else
    echo "  FAIL  scenario 3 — STALLED reason is '$reason', expected hard_limit*"
    FAIL=1
  fi
fi

# ── Scenario 4 — maestro fails fast (non-stall failure, per code-review I3) ──
echo "=== Scenario 4 — maestro fails fast (non-zero exit, no stall) ==="
mkdir -p "$TMP/scenario4"
cp "$WD" "$TMP/scenario4/maestro_with_watchdog.sh"
cat > "$TMP/scenario4/maestro_env.sh" <<'EOF'
#!/usr/bin/env bash
# Real Maestro flow-failure shape: prints an error message and exits
# with a non-zero code BEFORE any stall threshold could possibly fire.
# Watchdog MUST propagate the exact exit code (7 here) — NOT treat as
# stall and NOT swap to 124 / 137.
echo "[stub] element not found: 'foo'"
echo "[stub] flow failed"
exit 7
EOF
chmod +x "$TMP/scenario4/maestro_with_watchdog.sh" "$TMP/scenario4/maestro_env.sh"

set +e
MAESTRO_STALL_THRESHOLD=10 \
  MAESTRO_STALL_PROBE_INTERVAL=5 \
  MAESTRO_HARD_LIMIT=60 \
  MINT_WALKER_ARTIFACTS="$TMP/scenario4/artifacts" \
  "$TMP/scenario4/maestro_with_watchdog.sh" test fake-flow.yaml >/dev/null 2>&1
rc=$?
set -e
assert_exit 7 "$rc" "scenario 4 fast non-zero exit (rc=7 propagated)"
if [[ -f "$TMP/scenario4/artifacts/STALLED" ]]; then
  echo "  FAIL  scenario 4 — STALLED marker present (should not be)"
  FAIL=1
else
  echo "  PASS  scenario 4 — no STALLED marker on non-stall failure"
fi

# ── Result ─────────────────────────────────────────────────────────────
if [[ $FAIL -ne 0 ]]; then
  echo ""
  echo "::error::Watchdog self-test failed"
  exit 1
fi
echo ""
echo "[maestro_with_watchdog_test] all 4 scenarios passed"
