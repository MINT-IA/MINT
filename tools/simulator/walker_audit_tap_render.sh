#!/usr/bin/env bash
# tools/simulator/walker_audit_tap_render.sh
#
# Phase 54-01 — autonomous walker for STAB-17 AUDIT_TAP_RENDER scaffold.
#
# Reads the row catalog at tools/simulator/audit_tap_render_rows.tsv
# (regenerated from .planning/.../AUDIT_TAP_RENDER.md by
# regen_audit_tap_render_catalog.py) and drives an iOS simulator
# through every primary-depth interactive element.
#
# Per-row execution:
#   1. Boot/reuse simulator (ch.mint.app on iPhone 17 Pro).
#   2. Navigate to the row's tab (1..3) or open the drawer (section=ProfileDrawer).
#   3. Tap at the row's (tap_x, tap_y) coordinates via cliclick.
#   4. wait_for_ui quiescence.
#   5. Capture screenshot to screenshots/audit-tap-render/<archetype>/<id>.png.
#   6. Compare sha256 to pre-tap screenshot — distinct == PASS, identical == FAIL.
#   7. Match optional Sentry breadcrumb (TBD Plan 54-01 PR-2).
#
# PR-1 scope: --dry-run mode + row enumeration. Real tap execution
# requires sim + cliclick + idb (lands in Plan 54-01 PR-2 alongside
# the screenshot diff + breadcrumb match logic).
#
# Usage:
#   bash tools/simulator/walker_audit_tap_render.sh --help
#   bash tools/simulator/walker_audit_tap_render.sh --dry-run
#   bash tools/simulator/walker_audit_tap_render.sh --dry-run --tab 1
#   bash tools/simulator/walker_audit_tap_render.sh --dry-run --row 1.4
#   bash tools/simulator/walker_audit_tap_render.sh --archetype swiss_native --all   # PR-2: real run
#
# Required env (PR-2 real run only):
#   SENTRY_DSN_STAGING (Railway staging)
#
# Reuses helpers from tools/simulator/walker.sh when invoked in real mode.
# DRY-RUN mode is pure-shell (no sim, no flutter, no curl).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/tools/simulator/audit_tap_render_rows.tsv"
RESULTS_DIR="$REPO_ROOT/.planning/phases/54-testflight-gate-closure"
RESULTS_FILE="$RESULTS_DIR/AUDIT_TAP_RENDER_RESULTS.md"

# Defaults
ARCHETYPE=""
TAB_FILTER=""
ROW_FILTER=""
DRY_RUN=1   # default to dry-run; explicit --no-dry-run for real (Plan 54-01 PR-2)
RUN_ALL=0
SHOW_HELP=0

# ─── help text ─────────────────────────────────────────────────────────
print_help() {
  cat <<EOF
walker_audit_tap_render.sh — STAB-17 autonomous walker (Phase 54-01)

Sections covered (from audit_tap_render_rows.tsv):
  Tab1_Aujourdhui   (15 rows: 1.1 .. 1.15)
  Tab2_Coach        (10 rows: 2.1 .. 2.10)
  Tab3_Explorer     (11 rows: 3.1 .. 3.11)
  ProfileDrawer     (12 rows: 4.1 .. 4.12)

Modes:
  --dry-run               (default) print what would be tapped, no sim/build
  --no-dry-run            real tap execution (requires sim, Plan 54-01 PR-2)
  --all                   exercise every row in the catalog
  --tab <N>               filter to Tab1..Tab3 or 'drawer' (1/2/3/drawer)
  --row <X.Y>             single row by id (e.g. 1.4)
  --archetype <slug>      seed archetype (swiss_native, expat_eu, ...) — required for --no-dry-run
  --help                  this text

Outputs:
  Dry-run prints planned actions. Real run writes
  .planning/phases/54-testflight-gate-closure/AUDIT_TAP_RENDER_RESULTS.md
  with PASS/FAIL/SKIP per row + screenshot links.

Exit codes:
  0 — clean dry-run / real run with 0 unaddressed FAILs
  1 — usage error / parse error
  2 — real run completed with FAILs (triage tickets created)
EOF
}

# ─── argv parsing ──────────────────────────────────────────────────────
_args=("$@")
i=0
while [ "$i" -lt "${#_args[@]}" ]; do
  a="${_args[$i]}"
  case "$a" in
    --help|-h) SHOW_HELP=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-dry-run) DRY_RUN=0 ;;
    --all) RUN_ALL=1 ;;
    --tab)
      i=$((i+1))
      TAB_FILTER="${_args[$i]:-}"
      ;;
    --tab=*)
      TAB_FILTER="${a#--tab=}"
      ;;
    --row)
      i=$((i+1))
      ROW_FILTER="${_args[$i]:-}"
      ;;
    --row=*)
      ROW_FILTER="${a#--row=}"
      ;;
    --archetype)
      i=$((i+1))
      ARCHETYPE="${_args[$i]:-}"
      ;;
    --archetype=*)
      ARCHETYPE="${a#--archetype=}"
      ;;
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

# ─── catalog availability ──────────────────────────────────────────────
if [ ! -f "$CATALOG" ]; then
  echo "ERROR: catalog not found at $CATALOG" >&2
  echo "Run: python3 tools/simulator/regen_audit_tap_render_catalog.py" >&2
  exit 1
fi

# ─── filter resolution ─────────────────────────────────────────────────
SECTION_FILTER=""
case "$TAB_FILTER" in
  "") ;;
  1) SECTION_FILTER="Tab1_Aujourdhui" ;;
  2) SECTION_FILTER="Tab2_Coach" ;;
  3) SECTION_FILTER="Tab3_Explorer" ;;
  drawer|4) SECTION_FILTER="ProfileDrawer" ;;
  *)
    echo "ERROR: --tab must be 1|2|3|drawer (got '$TAB_FILTER')" >&2
    exit 1
    ;;
esac

# ─── real-run preflight ────────────────────────────────────────────────
if [ "$DRY_RUN" = "0" ]; then
  if [ -z "$ARCHETYPE" ]; then
    echo "ERROR: --no-dry-run requires --archetype <slug>" >&2
    exit 1
  fi
  echo "ERROR: real-run mode is implemented in Plan 54-01 PR-2" >&2
  echo "       For now, use --dry-run to preview the catalog walk." >&2
  exit 1
fi

# ─── dry-run output ────────────────────────────────────────────────────
echo "[walker] catalog: $(wc -l < "$CATALOG") lines (1 header + 48 rows expected)"
echo "[walker] mode: dry-run"
[ -n "$SECTION_FILTER" ] && echo "[walker] section filter: $SECTION_FILTER"
[ -n "$ROW_FILTER" ] && echo "[walker] row filter: $ROW_FILTER"
echo ""

# Skip header line, iterate rows.
total=0
shown=0
skipped=0
while IFS=$'\t' read -r id section surface_file surface_line element expected tap_strategy tap_x tap_y wait_max skip_reason notes; do
  [ "$id" = "id" ] && continue   # skip header
  total=$((total+1))
  if [ -n "$SECTION_FILTER" ] && [ "$section" != "$SECTION_FILTER" ]; then continue; fi
  if [ -n "$ROW_FILTER" ] && [ "$id" != "$ROW_FILTER" ]; then continue; fi
  shown=$((shown+1))
  if [ -n "$skip_reason" ]; then
    echo "[$id] SKIP $section/$surface_file:$surface_line — $skip_reason"
    skipped=$((skipped+1))
  else
    echo "[$id] WOULD-TAP $section/$surface_file:$surface_line at ($tap_x,$tap_y) wait=$wait_max"
    [ -n "$notes" ] && echo "       note: $notes"
  fi
done < "$CATALOG"

echo ""
echo "[walker] dry-run complete: $shown of $total rows enumerated ($skipped marked SKIP)"

# Filter sanity check.
if [ -n "$ROW_FILTER" ] && [ "$shown" = "0" ]; then
  echo "ERROR: --row $ROW_FILTER did not match any catalog row" >&2
  exit 1
fi

exit 0
