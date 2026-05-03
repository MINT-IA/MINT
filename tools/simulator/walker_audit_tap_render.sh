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
#   bash tools/simulator/walker_audit_tap_render.sh --no-dry-run --archetype swiss_native --all
#
# Required env (real run only):
#   SENTRY_DSN_STAGING (Railway staging)
#   MINT_WALKER_DEVICE (optional, defaults to 'iPhone 17 Pro')
#
# Real-run mode reuses helpers from tools/simulator/walker.sh
# (tap_at, wait_for_ui, snap, to-timeout wrapper). The build is
# triggered with --dart-define=MINT_E2E_ARCHETYPE=<slug>
# + MINT_WALKTHROUGH_PHASE=54 so the seed loader picks the right
# archetype profile + the Sentry breadcrumb tag identifies the run.
# DRY-RUN mode stays pure-shell (no sim, no flutter, no curl).
#
# Real-run output:
#   .planning/phases/54-testflight-gate-closure/AUDIT_TAP_RENDER_RESULTS.md
#     deterministic Markdown table (one row per catalog row, PASS/FAIL/SKIP).
#   .planning/phases/54-testflight-gate-closure/triage/F-XX-<surface>.md
#     one ticket per FAIL with sha evidence + git blame context.
#   .planning/phases/54-testflight-gate-closure/screenshots/<archetype>/<id>-{pre,post}.png
#     pre-tap and post-tap captures for sha256 distinctness gating.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$REPO_ROOT/tools/simulator/audit_tap_render_rows.tsv"
RESULTS_DIR="$REPO_ROOT/.planning/phases/54-testflight-gate-closure"
RESULTS_FILE="$RESULTS_DIR/AUDIT_TAP_RENDER_RESULTS.md"
TRIAGE_DIR="$RESULTS_DIR/triage"
SCREENSHOT_ROOT="$RESULTS_DIR/screenshots"

# Defaults
ARCHETYPE=""
TAB_FILTER=""
ROW_FILTER=""
DRY_RUN=1   # default to dry-run; explicit --no-dry-run for real
RUN_ALL=0
SHOW_HELP=0
PRINT_PLAN_ONLY=0   # internal: --check-real-run prints plan + exits 0 (smoke)

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
  --no-dry-run            real tap execution (requires booted sim + cliclick + xcrun)
  --check-real-run        print the planned real-run preflight WITHOUT booting
                          the sim. Used by the smoke harness to assert the
                          --no-dry-run code path is reachable + arg-validating.
  --all                   exercise every row in the catalog
  --tab <N>               filter to Tab1..Tab3 or 'drawer' (1/2/3/drawer)
  --row <X.Y>             single row by id (e.g. 1.4)
  --archetype <slug>      seed archetype (swiss_native, expat_eu, ...) — required for --no-dry-run
  --help                  this text

Outputs:
  Dry-run prints planned actions. Real run writes
  .planning/phases/54-testflight-gate-closure/AUDIT_TAP_RENDER_RESULTS.md
  with PASS/FAIL/SKIP per row, plus triage/F-XX-*.md per FAIL.

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
    --check-real-run) DRY_RUN=0; PRINT_PLAN_ONLY=1 ;;
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

  VALID_ARCHETYPES_RE='^(swiss_native|expat_eu|expat_us|cross_border|independent_no_lpp|recent_arrival|near_retirement|young_starter)$'
  if ! [[ "$ARCHETYPE" =~ $VALID_ARCHETYPES_RE ]]; then
    echo "ERROR: unknown archetype '$ARCHETYPE'" >&2
    echo "Valid: swiss_native expat_eu expat_us cross_border independent_no_lpp recent_arrival near_retirement young_starter" >&2
    exit 1
  fi

  if [ "$PRINT_PLAN_ONLY" = "1" ]; then
    echo "[walker] --check-real-run plan summary"
    echo "[walker]   archetype:      $ARCHETYPE"
    echo "[walker]   tab filter:     ${SECTION_FILTER:-<none>}"
    echo "[walker]   row filter:     ${ROW_FILTER:-<none>}"
    echo "[walker]   results file:   $RESULTS_FILE"
    echo "[walker]   triage dir:     $TRIAGE_DIR"
    echo "[walker]   screenshot dir: $SCREENSHOT_ROOT/$ARCHETYPE"
    echo "[walker] preflight OK — would invoke sim boot + build + iterate"
    exit 0
  fi

  if [ "$RUN_ALL" != "1" ] && [ -z "$TAB_FILTER" ] && [ -z "$ROW_FILTER" ]; then
    echo "ERROR: --no-dry-run requires --all or --tab <N> or --row <X.Y>" >&2
    exit 1
  fi

  : "${SENTRY_DSN_STAGING:?SENTRY_DSN_STAGING required for real-run mode (Railway staging)}"

  for cmd in xcrun cliclick shasum; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "ERROR: required binary '$cmd' not found on PATH" >&2
      [ "$cmd" = "cliclick" ] && echo "       brew install cliclick" >&2
      exit 1
    }
  done

  DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
  BUNDLE="ch.mint.app"
  ARCHETYPE_SCREENSHOT_DIR="$SCREENSHOT_ROOT/$ARCHETYPE"
  mkdir -p "$ARCHETYPE_SCREENSHOT_DIR" "$TRIAGE_DIR"

  echo "[walker] mode: real-run"
  echo "[walker] archetype: $ARCHETYPE"
  echo "[walker] device: $DEVICE"

  # Boot sim + build/install with archetype dart-define.
  echo "[walker] boot: $DEVICE"
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  xcrun simctl erase "$DEVICE" >/dev/null 2>&1 || true
  xcrun simctl boot "$DEVICE"
  open -a Simulator || true

  echo "[walker] build: flutter build ios --simulator (archetype=$ARCHETYPE phase=54)"
  (cd "$REPO_ROOT/apps/mobile" && flutter build ios --simulator \
    --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
    --dart-define=SENTRY_DSN="${SENTRY_DSN_STAGING}" \
    --dart-define=MINT_E2E_ARCHETYPE="$ARCHETYPE" \
    --dart-define=MINT_WALKTHROUGH_PHASE=54)

  APP_PATH="$REPO_ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
  if [ ! -d "$APP_PATH" ]; then
    echo "[walker] FAIL: Runner.app not found at $APP_PATH" >&2
    exit 1
  fi

  echo "[walker] install: $APP_PATH → $DEVICE"
  xcrun simctl install "$DEVICE" "$APP_PATH"
  xcrun simctl launch "$DEVICE" "$BUNDLE"
  sleep 6   # allow Flutter first frame + greeting

  # ─── helpers (in-process, do not source walker.sh — its argv parser
  #     would consume our argv) ──────────────────────────────────────
  _tap_at() {
    local x="$1" y="$2"
    cliclick "c:${x},${y}"
    sleep 0.4
  }

  _wait_for_ui() {
    local max="${1:-8}"
    local prev_hash="" cur_hash="" i
    for i in $(seq 1 "$max"); do
      xcrun simctl io booted screenshot /tmp/_walker_audit_poll.png \
        >/dev/null 2>&1 || true
      cur_hash=$(shasum /tmp/_walker_audit_poll.png 2>/dev/null | awk '{print $1}')
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

  # Tab navigation: bottom-nav coordinates on iPhone 17 Pro (logical
  # 393×852, scale 3 → 1179×2556). The sim window is 1179×2556 in cliclick
  # space when not zoomed. We tap roughly Y=2470 for the bottom nav.
  _goto_tab() {
    case "$1" in
      Tab1_Aujourdhui) _tap_at 195 2470 ;;
      Tab2_Coach)      _tap_at 590 2470 ;;
      Tab3_Explorer)   _tap_at 985 2470 ;;
      ProfileDrawer)   _tap_at 60 140 ;;   # hamburger top-left
      *) echo "[walker] WARN: unknown section '$1'" >&2 ;;
    esac
    _wait_for_ui 6
  }

  # Per-row triage emitter. One file per FAIL row.
  _emit_triage() {
    local id="$1" surface="$2" line="$3" sha_pre="$4" sha_post="$5" pre_png="$6" post_png="$7" reason="$8"
    local safe="${surface//\//_}"
    safe="${safe//./_}"
    local out="$TRIAGE_DIR/F-${id}-${safe}.md"
    {
      echo "# Walker FAIL — Row $id"
      echo ""
      echo "- **Surface:** \`$surface\`:$line"
      echo "- **Reason:** $reason"
      echo "- **Pre-tap sha256:** \`$sha_pre\`"
      echo "- **Post-tap sha256:** \`$sha_post\`"
      echo "- **Pre-tap screenshot:** [$pre_png](../$(realpath --relative-to="$RESULTS_DIR" "$pre_png" 2>/dev/null || echo "$pre_png"))"
      echo "- **Post-tap screenshot:** [$post_png](../$(realpath --relative-to="$RESULTS_DIR" "$post_png" 2>/dev/null || echo "$post_png"))"
      echo ""
      echo "## git blame on \`$surface:$line\`"
      echo ""
      echo '```'
      (cd "$REPO_ROOT" && git blame -L "$line,+5" "apps/mobile/lib/screens/$surface" 2>/dev/null \
        || git -C "$REPO_ROOT" grep -nE "^.{0,120}$" "apps/mobile/lib/**/$surface" 2>/dev/null \
        || echo "(blame unavailable — file path may not be under apps/mobile/lib/screens/)") | head -20
      echo '```'
      echo ""
      echo "## Triage classification"
      echo ""
      echo "- [ ] **CRASH** (SimulatorCrash, FlutterError, AssertionError) — P0"
      echo "- [ ] **NAV-DEAD-END** (tap fires but screen doesn't change) — P0"
      echo "- [ ] **SILENT-NO-OP** (tap returns null / SizedBox.shrink) — P1"
      echo "- [ ] **VISUAL-REGRESSION** (renders but unexpected layout) — P2"
      echo "- [ ] **DATA-DEPENDENCY** (works only with seeded profile state) — SKIP candidate"
      echo ""
      echo "Generated by walker_audit_tap_render.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
    } > "$out"
    echo "[walker] triage ticket: $out"
  }

  # Iterate the catalog and execute.
  pass_count=0
  fail_count=0
  skip_count=0
  results_rows=""
  current_section=""

  while IFS=$'\t' read -r id section surface_file surface_line element expected tap_strategy tap_x tap_y wait_max skip_reason notes; do
    [ "$id" = "id" ] && continue
    if [ -n "$SECTION_FILTER" ] && [ "$section" != "$SECTION_FILTER" ]; then continue; fi
    if [ -n "$ROW_FILTER" ] && [ "$id" != "$ROW_FILTER" ]; then continue; fi

    if [ -n "$skip_reason" ]; then
      skip_count=$((skip_count+1))
      results_rows+="| $id | $section | \`$surface_file\`:$surface_line | SKIP | — | — | $skip_reason |"$'\n'
      echo "[$id] SKIP $surface_file:$surface_line — $skip_reason"
      continue
    fi

    # New section → navigate to it.
    if [ "$section" != "$current_section" ]; then
      _goto_tab "$section"
      current_section="$section"
    fi

    pre_png="$ARCHETYPE_SCREENSHOT_DIR/${id}-pre.png"
    post_png="$ARCHETYPE_SCREENSHOT_DIR/${id}-post.png"

    _snap "$pre_png"
    sha_pre=$(_sha "$pre_png")

    _tap_at "$tap_x" "$tap_y"
    _wait_for_ui "${wait_max:-6}"

    _snap "$post_png"
    sha_post=$(_sha "$post_png")

    if [ -z "$sha_pre" ] || [ -z "$sha_post" ]; then
      verdict="FAIL"
      reason="screenshot capture failed (sha empty)"
      fail_count=$((fail_count+1))
      _emit_triage "$id" "$surface_file" "$surface_line" "$sha_pre" "$sha_post" "$pre_png" "$post_png" "$reason"
    elif [ "$sha_pre" = "$sha_post" ]; then
      verdict="FAIL"
      reason="post-tap sha256 identical to pre-tap (no UI change detected)"
      fail_count=$((fail_count+1))
      _emit_triage "$id" "$surface_file" "$surface_line" "$sha_pre" "$sha_post" "$pre_png" "$post_png" "$reason"
    else
      verdict="PASS"
      reason="ui changed"
      pass_count=$((pass_count+1))
    fi

    results_rows+="| $id | $section | \`$surface_file\`:$surface_line | $verdict | \`${sha_pre:0:10}\` | \`${sha_post:0:10}\` | $reason |"$'\n'
    echo "[$id] $verdict $surface_file:$surface_line"

    # After tapping a row that pushed a screen, pop back to section root
    # so the next row starts clean.
    xcrun simctl openurl booted "mint://" >/dev/null 2>&1 || true
    sleep 0.3
  done < "$CATALOG"

  # Write the deterministic results doc.
  mkdir -p "$RESULTS_DIR"
  {
    echo "<!-- AUTO-GENERATED by tools/simulator/walker_audit_tap_render.sh"
    echo "     Do NOT hand-edit — re-run with --no-dry-run to refresh.   -->"
    echo "# AUDIT_TAP_RENDER — Plan 54-01 walker results"
    echo ""
    echo "- **Run timestamp (UTC):** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- **Archetype:** \`$ARCHETYPE\`"
    echo "- **Device:** \`$DEVICE\`"
    echo "- **Filters:** tab=\`${SECTION_FILTER:-<all>}\`, row=\`${ROW_FILTER:-<all>}\`"
    echo "- **Counts:** PASS=$pass_count, FAIL=$fail_count, SKIP=$skip_count"
    echo ""
    echo "| id | section | surface | verdict | sha-pre | sha-post | notes |"
    echo "|---|---|---|---|---|---|---|"
    printf "%s" "$results_rows"
    echo ""
    echo "Triage tickets: see [triage/](triage/) — one \`F-<id>-<surface>.md\` per FAIL."
  } > "$RESULTS_FILE"

  echo ""
  echo "[walker] real-run complete: PASS=$pass_count FAIL=$fail_count SKIP=$skip_count"
  echo "[walker] results: $RESULTS_FILE"

  if [ "$fail_count" -gt 0 ]; then
    exit 2
  fi
  exit 0
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
