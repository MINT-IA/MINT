#!/usr/bin/env bash
# tools/simulator/maestro_sweep.sh — S98 Phase 5.C
#
# Runs the Maestro flow inventory against a booted iOS sim,
# wraps each invocation in `maestro_with_watchdog.sh` (stall detector
# + auto-classifier), and aggregates findings into a sweep-summary.md.
#
# Per CLAUDE.md §9 0-trust : every claim about a flow's status carries
# a deterministic citation (exit code + artifact dir + classifier
# primary hypothesis).
#
# Usage:
#   tools/simulator/maestro_sweep.sh
#       — runs the curated default sweep (e2e + regression + top
#         perfect-set flows + personas).
#   tools/simulator/maestro_sweep.sh --tier <e2e|regression|perfect|personas|all>
#       — runs one tier.
#
# Env (forwarded to the watchdog) :
#   MAESTRO_STALL_THRESHOLD, MAESTRO_HARD_LIMIT, MINT_DEBUG_PORT, MINT_BUNDLE_ID
#
# Output : `.planning/_walker/sweep-<TS>/`
#   ├── <flow_slug>/
#   │   ├── maestro.log
#   │   ├── debug-state.json (if Tier 2 endpoint reachable)
#   │   ├── oslog-mint.txt
#   │   ├── last-screen.png
#   │   ├── cassure-report.json (classifier output)
#   │   ├── STALLED (if applicable)
#   │   └── EXIT_CODE
#   └── sweep-summary.md (aggregate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCHDOG="$SCRIPT_DIR/maestro_with_watchdog.sh"
CLASSIFIER="$REPO_ROOT/tools/debug/cassure-classifier.sh"

[ -x "$WATCHDOG" ]   || { echo "ERROR: watchdog at $WATCHDOG not found/executable" >&2; exit 1; }
[ -x "$CLASSIFIER" ] || { echo "ERROR: classifier at $CLASSIFIER not found/executable" >&2; exit 1; }

# ── Flow selection ────────────────────────────────────────────────────
TIER="${1:-default}"
[ "$TIER" = "--tier" ] && TIER="${2:-default}"

declare -a FLOWS

FLOWS_E2E=(
  "$REPO_ROOT/tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml"
)
FLOWS_REGRESSION=(
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S001__cap_du_jour_action_bar_reachable.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S002__maestro_cold_launch_fragment.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S003__mintapp_scheme_opens_app.yaml"
  "$REPO_ROOT/tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml"
)
FLOWS_PERFECT=(
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_landing_to_register.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_b15_concrete_facts_chips.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_empty_state_cascade.yaml"
  "$REPO_ROOT/tools/simulator/flows/maestro-perfect-set/flow_3a_calculator.yaml"
)
FLOWS_PERSONAS=(
  "$REPO_ROOT/tools/simulator/flows/julien_swiss.yaml"
  "$REPO_ROOT/tools/simulator/flows/lauren_expat_us.yaml"
)

case "$TIER" in
  e2e)        FLOWS=("${FLOWS_E2E[@]}") ;;
  regression) FLOWS=("${FLOWS_REGRESSION[@]}") ;;
  perfect)    FLOWS=("${FLOWS_PERFECT[@]}") ;;
  personas)   FLOWS=("${FLOWS_PERSONAS[@]}") ;;
  all)        FLOWS=("${FLOWS_E2E[@]}" "${FLOWS_REGRESSION[@]}" "${FLOWS_PERFECT[@]}" "${FLOWS_PERSONAS[@]}") ;;
  default)    FLOWS=("${FLOWS_E2E[@]}" "${FLOWS_REGRESSION[@]}" "${FLOWS_PERFECT[@]}") ;;
  *)          echo "Unknown tier: $TIER (use: e2e | regression | perfect | personas | all | default)" >&2; exit 1 ;;
esac

# ── Setup sweep dir + summary header ──────────────────────────────────
TS="$(date +%Y%m%dT%H%M%S)"
SWEEP_DIR="$REPO_ROOT/.planning/_walker/sweep-$TS"
mkdir -p "$SWEEP_DIR"
SUMMARY="$SWEEP_DIR/sweep-summary.md"

{
  echo "# Maestro sweep — $TS"
  echo ""
  echo "**Tier:** $TIER"
  echo "**Flow count:** ${#FLOWS[@]}"
  echo "**Watchdog stall threshold:** ${MAESTRO_STALL_THRESHOLD:-90}s"
  echo "**Watchdog hard limit:** ${MAESTRO_HARD_LIMIT:-900}s"
  echo "**Sweep dir:** \`$SWEEP_DIR\`"
  echo ""
  echo "## Per-flow results"
  echo ""
  echo "| Exit | Flow | Hypothesis | Suspect file |"
  echo "|---:|:---|:---|:---|"
} > "$SUMMARY"

# ── Run each flow ─────────────────────────────────────────────────────
total=${#FLOWS[@]}
i=0
green=0
red=0
stalled=0
hard_limit=0

for flow in "${FLOWS[@]}"; do
  i=$((i + 1))
  slug=$(basename "$flow" .yaml)
  echo ""
  echo "[$i/$total] $slug"
  echo "  → $flow"

  if [ ! -f "$flow" ]; then
    echo "  SKIP  flow file missing"
    echo "| ⚠️ skip | \`$slug\` | (missing flow file) | — |" >> "$SUMMARY"
    continue
  fi

  flow_dir="$SWEEP_DIR/$slug"
  mkdir -p "$flow_dir"

  # Run via watchdog. `set +e` so a non-zero exit doesn't kill the sweep.
  set +e
  MINT_WALKER_ARTIFACTS="$flow_dir" \
    "$WATCHDOG" test "$flow" --device booted
  rc=$?
  set -e
  echo "$rc" > "$flow_dir/EXIT_CODE"

  # Determine status emoji + counters
  case "$rc" in
    0)    icon="✅"; green=$((green + 1)) ;;
    124)  icon="⏸️ stall"; stalled=$((stalled + 1)) ;;
    137)  icon="🛑 hard-limit"; hard_limit=$((hard_limit + 1)) ;;
    *)    icon="❌ exit $rc"; red=$((red + 1)) ;;
  esac

  # Classifier already ran inside the watchdog dump path on stall.
  # For non-stall failures (rc!=0, rc!=124, rc!=137), invoke explicitly
  # so we always get a cassure-report.json.
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] && [ "$rc" -ne 137 ]; then
    if [ -f "$flow_dir/oslog-mint.txt" ] || [ -f "$flow_dir/debug-state.json" ]; then
      "$CLASSIFIER" \
        --state "$flow_dir/debug-state.json" \
        --oslog "$flow_dir/oslog-mint.txt" \
        --out   "$flow_dir/cassure-report.json" \
        2> "$flow_dir/classifier.log" || true
    fi
  fi

  # Pull primary hypothesis if a report exists
  hyp="—"
  suspect="—"
  if [ -f "$flow_dir/cassure-report.json" ]; then
    hyp=$(jq -r '.primary_hypothesis.hypothesis // "—"' "$flow_dir/cassure-report.json" 2>/dev/null || echo "—")
    suspect=$(jq -r '.primary_hypothesis.suspect_file // "—"' "$flow_dir/cassure-report.json" 2>/dev/null || echo "—")
  fi

  echo "  $icon  hypothesis=$hyp"
  echo "| $icon | \`$slug\` | $hyp | \`$suspect\` |" >> "$SUMMARY"
done

# ── Aggregate footer ──────────────────────────────────────────────────
{
  echo ""
  echo "## Totals"
  echo ""
  echo "- ✅ green: $green / $total"
  echo "- ❌ red: $red / $total"
  echo "- ⏸️ stalled: $stalled / $total"
  echo "- 🛑 hard-limit: $hard_limit / $total"
  echo ""
  echo "## Next steps"
  echo ""
  if [ "$red" -gt 0 ] || [ "$stalled" -gt 0 ] || [ "$hard_limit" -gt 0 ]; then
    echo "1. Open each non-green artifact dir under \`$SWEEP_DIR/\`."
    echo "2. Read its \`cassure-report.json\` \`primary_hypothesis\`."
    echo "3. The \`suspect_file\` is the first place to look."
    echo "4. \`oslog-mint.txt\` + \`last-screen.png\` are the second-line evidence."
  else
    echo "All green. Infrastructure validated end-to-end."
  fi
} >> "$SUMMARY"

echo ""
echo "=== Sweep complete ==="
echo "  Summary: $SUMMARY"
echo "  Green:   $green / $total"
echo "  Red:     $red / $total"
echo "  Stalled: $stalled / $total"
echo "  Hard:    $hard_limit / $total"

# Non-zero exit if any flow failed — useful for CI gating downstream.
if [ "$red" -gt 0 ] || [ "$stalled" -gt 0 ] || [ "$hard_limit" -gt 0 ]; then
  exit 1
fi
exit 0
