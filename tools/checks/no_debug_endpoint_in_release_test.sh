#!/usr/bin/env bash
# Self-test for tools/checks/no_debug_endpoint_in_release.sh
#
# Verifies the release-binary symbol-leak check still catches each of
# its forbidden patterns and exits with the right codes. Without this,
# weakening the FORBIDDEN_PATTERNS regex would go undetected until a
# real debug build leaked to TestFlight.
#
# Wired into testflight.yml path filter via:
#   tools/checks/no_debug_endpoint_in_release.sh
# so any edit to either file re-triggers TestFlight CI.
#
# Run manually:
#   tools/checks/no_debug_endpoint_in_release_test.sh
#
# Exit codes:
#   0 — all assertions passed
#   1 — at least one assertion failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/no_debug_endpoint_in_release.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAIL=0

assert_exit() {
  local expected="$1"; shift
  local actual="$1"; shift
  local label="$1"
  if [[ "$expected" != "$actual" ]]; then
    echo "  FAIL  $label — expected exit $expected, got $actual"
    FAIL=1
  else
    echo "  PASS  $label (exit $actual)"
  fi
}

echo "=== no_debug_endpoint_in_release_test ==="

# --- Test 1: missing path → exit 2 (config error) ----------------------------
set +e
"$LINT" "$TMP/missing-app" >/dev/null 2>&1
rc=$?
set -e
assert_exit 2 "$rc" "missing Runner.app path"

# --- Test 2: missing binary inside .app → exit 2 -----------------------------
mkdir -p "$TMP/empty.app"
set +e
"$LINT" "$TMP/empty.app" >/dev/null 2>&1
rc=$?
set -e
assert_exit 2 "$rc" "missing Runner binary inside .app"

# --- Test 3: clean binary → exit 0 -------------------------------------------
mkdir -p "$TMP/clean.app"
# Plain ASCII garbage that doesn't match any forbidden pattern. Use
# printable filler so `strings(1)` actually emits content.
printf 'this is harmless production code without any debug symbols\n' \
  > "$TMP/clean.app/Runner"
set +e
"$LINT" "$TMP/clean.app" >/dev/null 2>&1
rc=$?
set -e
assert_exit 0 "$rc" "clean binary"

# --- Test 4-N: each forbidden pattern in isolation → exit 1 ------------------
# Mirror the FORBIDDEN_PATTERNS array from the lint. Each pattern gets
# its own .app to ensure the test fails specifically if THAT pattern is
# weakened out of the regex.
FORBIDDEN=(
  "DebugServer listening"
  "/debug/state"
  "/debug/health"
  "mint_debug.token"
  "ch.mint.debug"
)
for pat in "${FORBIDDEN[@]}"; do
  slug="$(echo "$pat" | tr ' /.' '___')"
  app="$TMP/tainted-${slug}.app"
  mkdir -p "$app"
  printf 'noise before %s noise after\n' "$pat" > "$app/Runner"
  set +e
  "$LINT" "$app" >/dev/null 2>&1
  rc=$?
  set -e
  assert_exit 1 "$rc" "forbidden pattern: $pat"
done

# --- Result ------------------------------------------------------------------
if [[ $FAIL -ne 0 ]]; then
  echo ""
  echo "::error::self-test failed — release-binary lint is regressed."
  exit 1
fi

echo ""
echo "[no_debug_endpoint_in_release_test] all assertions passed"
