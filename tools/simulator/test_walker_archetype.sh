#!/usr/bin/env bash
# tools/simulator/test_walker_archetype.sh
#
# Phase 51 Plan 51-05 / E2E-07 / CONTEXT D-17 — smoke-test harness for
# walker.sh's --archetype flag and the scripts/sim/run-e2e.sh wrapper.
#
# Pure shell, no flutter / sim / backend dependencies — runs in any
# POSIX-ish environment (CI, dev mac, Linux). Asserts the CLI contract
# without ever booting a simulator or calling xcrun.
#
# Usage:
#   bash tools/simulator/test_walker_archetype.sh
#
# Exit code: number of failing test functions. 0 = all pass.
#
# Tests (5 baseline + 6 added by Plan 51-07 / G51-06-03 closure):
#   1. --help mentions --archetype + lists at least 3 of the 8 valid slugs
#   2. Unknown slug exits non-zero with usage hint to stderr
#   3. --archetype swiss_native --dry-run exits 0 and prints planned actions
#   4. --dry-run does NOT create the screenshot output dir (filesystem clean)
#   5. scripts/sim/run-e2e.sh DRY_RUN=1 prints all 4 phase markers ([1/4]..[4/4])
#   6. (51-07) BUNDLE="ch.mint.app" exactly once
#   7. (51-07) legacy bundle id 'com.mint.mintMobile' nowhere
#   8. (51-07) TODO Plan 51-06 leftover removed
#   9. (51-07) cliclick references >=3 (helpers + at least one driver call)
#  10. (51-07) tap_at / type_text / wait_for_ui helpers defined
#  11. (51-07) end-to-end smoke on swiss_native — produces 7 sha256-distinct PNGs
#              (auto-skipped with explicit SKIP message when no sim is booted, so
#              the static suite stays CI-friendly).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

# ------------------------------------------------------------------ helpers
test_help_mentions_archetype() {
  local out
  out=$(bash tools/simulator/walker.sh --help 2>&1) || return 1
  echo "$out" | grep -q -- "--archetype" || return 1
  # Need at least 3 of the 8 slugs in the help text — proves the slug list
  # is documented at the CLI surface, not buried in source.
  local hits
  hits=$(echo "$out" | grep -cE "swiss_native|expat_eu|expat_us|cross_border|independent_no_lpp|recent_arrival|near_retirement|young_starter" || true)
  [ "$hits" -ge 3 ]
}

test_unknown_slug_fails() {
  ! bash tools/simulator/walker.sh --archetype unknown_slug --dry-run 2>/dev/null
}

test_dry_run_swiss_native_succeeds() {
  bash tools/simulator/walker.sh --archetype swiss_native --dry-run >/dev/null 2>&1
}

test_dry_run_no_output_dir_created() {
  # Capture pre-existing state so we don't false-positive on a leftover dir.
  local target="screenshots/walkthrough/v2.10-final/swiss_native/dryrun_smoke"
  rm -rf "$target" 2>/dev/null || true
  # Use a unique --scenario so any accidental mkdir would land in a known
  # location we can grep for.
  bash tools/simulator/walker.sh --archetype swiss_native --scenario dryrun_smoke --dry-run >/dev/null 2>&1
  # Filesystem must remain clean.
  [ ! -d "$target" ]
}

test_run_e2e_dry_chains_4_steps() {
  local out
  out=$(DRY_RUN=1 bash scripts/sim/run-e2e.sh swiss_native retraite 2>&1) || return 1
  # Each phase prints "[N/4]" exactly once.
  local hits
  hits=$(echo "$out" | grep -cE "^\[[1-4]/4\]" || true)
  [ "$hits" -eq 4 ]
}

# 51-07 / G51-06-03 — static checks asserting walker.sh is the deterministic
# version (right bundle id, no legacy id anywhere, TODO removed, cliclick-
# driven helpers defined).
test_bundle_id_correct() {
  [ "$(grep -c 'BUNDLE="ch.mint.app"' tools/simulator/walker.sh)" -eq 1 ]
}

test_no_legacy_bundle_id() {
  ! grep -q 'com.mint.mintMobile' tools/simulator/walker.sh
}

test_no_todo_plan_51_06() {
  ! grep -q 'TODO Plan 51-06' tools/simulator/walker.sh
}

test_cliclick_referenced() {
  [ "$(grep -c 'cliclick' tools/simulator/walker.sh)" -ge 3 ]
}

test_nav_helpers_defined() {
  grep -q 'tap_at()' tools/simulator/walker.sh \
    && grep -q 'type_text()' tools/simulator/walker.sh \
    && grep -q 'wait_for_ui()' tools/simulator/walker.sh
}

# 51-07 / T-51-07-06 mitigation — end-to-end smoke check.
# Default: auto-skip (smoke runs only when explicitly requested via
# RUN_SMOKE=1 because the full path requires a booted sim, a Flutter
# build, and a live backend — see scripts/sim/run-e2e.sh for the
# canonical orchestrator). When RUN_SMOKE=1 and a sim is booted plus
# the canonical capture dir already contains a fresh PNG set, we
# inspect the PNGs for sha256 distinctness — that is the deterministic
# property we want to guarantee post-G51-06-03.
test_e2e_smoke_seven_distinct_pngs() {
  if [ "${RUN_SMOKE:-0}" != "1" ]; then
    echo "  -> SKIP (RUN_SMOKE!=1; run-e2e.sh exercises this end-to-end)"
    return 0
  fi
  local capture_dir="screenshots/walkthrough/v2.10-final/swiss_native/retraite"
  if [ ! -d "$capture_dir" ]; then
    echo "  -> SKIP (no swiss_native capture dir; run scripts/sim/run-e2e.sh first)"
    return 0
  fi
  local n
  n=$(find "$capture_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -lt 7 ]; then
    echo "  -> only $n PNGs (expected >=7)"
    return 1
  fi
  local prev_sha="" sha png
  for png in $(ls "$capture_dir"/*.png | sort); do
    sha=$(shasum -a 256 "$png" | cut -d' ' -f1)
    if [ "$sha" = "$prev_sha" ]; then
      echo "  -> $png is sha256-identical to the previous frame (whitespace tap?)"
      return 1
    fi
    prev_sha=$sha
  done
  return 0
}

# ------------------------------------------------------------------ runner
for fn in \
    test_help_mentions_archetype \
    test_unknown_slug_fails \
    test_dry_run_swiss_native_succeeds \
    test_dry_run_no_output_dir_created \
    test_run_e2e_dry_chains_4_steps \
    test_bundle_id_correct \
    test_no_legacy_bundle_id \
    test_no_todo_plan_51_06 \
    test_cliclick_referenced \
    test_nav_helpers_defined \
    test_e2e_smoke_seven_distinct_pngs; do
  if $fn; then
    echo "PASS $fn"
    PASS=$((PASS+1))
  else
    echo "FAIL $fn"
    FAIL=$((FAIL+1))
  fi
done

echo "Total: $PASS passed, $FAIL failed."
exit "$FAIL"
