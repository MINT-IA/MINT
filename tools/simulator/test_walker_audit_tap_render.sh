#!/usr/bin/env bash
# tools/simulator/test_walker_audit_tap_render.sh
#
# Phase 54-01 — smoke-test harness for walker_audit_tap_render.sh + the
# regen_audit_tap_render_catalog.py generator.
#
# Pure shell, no flutter / sim / backend dependencies — runs in any
# POSIX-ish environment (CI, dev mac, Linux). Asserts the CLI contract +
# catalog shape without booting a simulator.
#
# Usage:
#   bash tools/simulator/test_walker_audit_tap_render.sh
#
# Exit code: number of failing test functions. 0 = all pass.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

# ─── helpers ──────────────────────────────────────────────────────────
test_help_lists_all_4_sections() {
  local out
  out=$(bash tools/simulator/walker_audit_tap_render.sh --help 2>&1)
  echo "$out" | grep -q "Tab1_Aujourdhui" || return 1
  echo "$out" | grep -q "Tab2_Coach" || return 1
  echo "$out" | grep -q "Tab3_Explorer" || return 1
  echo "$out" | grep -q "ProfileDrawer" || return 1
}

test_dry_run_enumerates_48_rows() {
  local out
  out=$(bash tools/simulator/walker_audit_tap_render.sh --dry-run 2>&1)
  # 48 rows: each prints either WOULD-TAP or SKIP
  local n
  n=$(echo "$out" | grep -cE "^\[[0-9]+\.[0-9]+\] (WOULD-TAP|SKIP) ")
  [ "$n" = "48" ] || { echo "  -> got $n rows enumerated, expected 48"; return 1; }
}

test_dry_run_tab_filter_works() {
  local out
  out=$(bash tools/simulator/walker_audit_tap_render.sh --dry-run --tab 1 2>&1)
  local n
  n=$(echo "$out" | grep -cE "^\[1\.[0-9]+\] (WOULD-TAP|SKIP) ")
  [ "$n" = "15" ] || { echo "  -> got $n rows for Tab1, expected 15"; return 1; }
  # No Tab2/Tab3/Drawer rows should appear
  ! echo "$out" | grep -qE "^\[(2|3|4)\."
}

test_dry_run_drawer_filter_works() {
  local out
  out=$(bash tools/simulator/walker_audit_tap_render.sh --dry-run --tab drawer 2>&1)
  local n
  n=$(echo "$out" | grep -cE "^\[4\.[0-9]+\] (WOULD-TAP|SKIP) ")
  [ "$n" = "12" ] || { echo "  -> got $n rows for Drawer, expected 12"; return 1; }
}

test_dry_run_row_filter_works() {
  local out
  out=$(bash tools/simulator/walker_audit_tap_render.sh --dry-run --row 1.4 2>&1)
  local n
  n=$(echo "$out" | grep -cE "^\[1\.4\] (WOULD-TAP|SKIP) ")
  [ "$n" = "1" ] || return 1
}

test_unknown_row_fails() {
  ! bash tools/simulator/walker_audit_tap_render.sh --dry-run --row 99.99 >/dev/null 2>&1
}

test_unknown_tab_fails() {
  ! bash tools/simulator/walker_audit_tap_render.sh --dry-run --tab xyz >/dev/null 2>&1
}

test_no_dry_run_without_archetype_fails() {
  ! bash tools/simulator/walker_audit_tap_render.sh --no-dry-run 2>&1 | grep -q "implemented in Plan 54-01 PR-2"
  ! bash tools/simulator/walker_audit_tap_render.sh --no-dry-run >/dev/null 2>&1
}

test_catalog_regen_idempotent() {
  python3 tools/simulator/regen_audit_tap_render_catalog.py --check >/dev/null 2>&1
}

test_catalog_has_48_rows_plus_header() {
  local n
  n=$(wc -l < tools/simulator/audit_tap_render_rows.tsv | tr -d ' ')
  [ "$n" = "49" ] || { echo "  -> got $n lines, expected 49 (1 header + 48 rows)"; return 1; }
}

test_catalog_has_correct_section_counts() {
  local tab1 tab2 tab3 drawer
  tab1=$(tail -n +2 tools/simulator/audit_tap_render_rows.tsv | cut -f2 | grep -c "Tab1_Aujourdhui")
  tab2=$(tail -n +2 tools/simulator/audit_tap_render_rows.tsv | cut -f2 | grep -c "Tab2_Coach")
  tab3=$(tail -n +2 tools/simulator/audit_tap_render_rows.tsv | cut -f2 | grep -c "Tab3_Explorer")
  drawer=$(tail -n +2 tools/simulator/audit_tap_render_rows.tsv | cut -f2 | grep -c "ProfileDrawer")
  [ "$tab1" = "15" ] && [ "$tab2" = "10" ] && [ "$tab3" = "11" ] && [ "$drawer" = "12" ]
}

test_catalog_skip_rows_have_reasons() {
  # 5 rows are pre-marked SKIP (2.5, 2.6, 2.7, 2.8, 4.9) per SPECIAL_ROWS
  # in the regen script. All must have a non-empty skip_reason cell.
  local n
  n=$(awk -F'\t' 'NR>1 && $11 != "" {print $1}' tools/simulator/audit_tap_render_rows.tsv | wc -l | tr -d ' ')
  [ "$n" = "5" ] || { echo "  -> got $n SKIP rows, expected 5"; return 1; }
}

# ─── runner ───────────────────────────────────────────────────────────
for fn in \
    test_help_lists_all_4_sections \
    test_dry_run_enumerates_48_rows \
    test_dry_run_tab_filter_works \
    test_dry_run_drawer_filter_works \
    test_dry_run_row_filter_works \
    test_unknown_row_fails \
    test_unknown_tab_fails \
    test_no_dry_run_without_archetype_fails \
    test_catalog_regen_idempotent \
    test_catalog_has_48_rows_plus_header \
    test_catalog_has_correct_section_counts \
    test_catalog_skip_rows_have_reasons; do
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
