#!/usr/bin/env bash
# tools/simulator/run_walker_all_archetypes.sh
#
# Phase 85 (v2.11) — orchestrator that runs walker_premier_eclairage.sh
# sequentially across the 4 v2.11 archetypes and aggregates per-archetype
# exit codes into a single summary.json under .planning/walker/<run-id>/.
#
# Each archetype run shares a SINGLE run-id so all evidence lands under
# one directory tree :
#
#   .planning/walker/<run-id>/
#   ├── summary.json                 # aggregate {pass: N, fail: N, archetypes: [...]}
#   ├── walker.log                   # appended across all archetypes
#   ├── julien_swiss/                # per-archetype walker artifacts
#   │   ├── screenshots/
#   │   ├── diff/
#   │   └── ... (Phase 74 layout)
#   ├── couple_acheteurs_lausanne/
#   ├── jeune_diplome_zurich/
#   └── cadre_40_55_lpp_rachat/
#
# Usage :
#   bash tools/simulator/run_walker_all_archetypes.sh             # real run, all 4 archetypes
#   bash tools/simulator/run_walker_all_archetypes.sh --dry-run   # plan-only, no sim
#   bash tools/simulator/run_walker_all_archetypes.sh --run-id <id>
#   bash tools/simulator/run_walker_all_archetypes.sh --archetypes julien_swiss,jeune_diplome_zurich
#
# Exit codes :
#   0 = all 4 archetypes PASS (exit 0 from walker)
#   1 = at least one archetype FAIL (non-zero walker exit)
#   2 = orchestrator usage error / preflight failure
#
# REQ coverage : WALKR-01, WALKR-02, WALKR-06 (run-id evidence aggregate).
# WALKR-03/04 (SSIM checks) are enforced inside walker_premier_eclairage.sh.
# WALKR-05 (TestFlight cut) is a manual / CI step driven by .github/workflows/testflight.yml.

set -uo pipefail

# ── config ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WALKER_SCRIPT="$SCRIPT_DIR/walker_premier_eclairage.sh"
WALKER_ROOT="$REPO_ROOT/.planning/walker"

DEFAULT_ARCHETYPES=("julien_swiss" "couple_acheteurs_lausanne" "jeune_diplome_zurich" "cadre_40_55_lpp_rachat")

DRY_RUN=0
RUN_ID=""
ARCHETYPES=("${DEFAULT_ARCHETYPES[@]}")

# ── argv ────────────────────────────────────────────────────────────────
_args=("$@")
i=0
while [ $i -lt ${#_args[@]} ]; do
  a="${_args[$i]}"
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --run-id)
      i=$((i+1))
      RUN_ID="${_args[$i]:-}"
      ;;
    --run-id=*) RUN_ID="${a#--run-id=}" ;;
    --archetypes)
      i=$((i+1))
      _csv="${_args[$i]:-}"
      IFS=',' read -r -a ARCHETYPES <<< "$_csv"
      ;;
    --archetypes=*)
      _csv="${a#--archetypes=}"
      IFS=',' read -r -a ARCHETYPES <<< "$_csv"
      ;;
    -h|--help)
      cat <<EOF
Usage: bash tools/simulator/run_walker_all_archetypes.sh [options]

Options:
  --dry-run                    plan-only; walker invoked with --dry-run flag
  --run-id <id>                shared run-id for all archetypes (default: auto YYYY-MM-DD-HHMMSS-<sha7>)
  --archetypes a,b,c           comma-separated subset of archetypes (default: all 4)
  -h, --help                   show this help

Default archetypes (Phase 85 / v2.11) :
  ${DEFAULT_ARCHETYPES[*]}

Exit codes :
  0 = all archetypes PASS
  1 = at least one archetype FAIL
  2 = orchestrator usage error / preflight failure
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag '$a' (use --help)" >&2
      exit 2
      ;;
  esac
  i=$((i+1))
done

# ── preflight ───────────────────────────────────────────────────────────
if [ ! -x "$WALKER_SCRIPT" ] && [ ! -f "$WALKER_SCRIPT" ]; then
  echo "ERROR: walker_premier_eclairage.sh not found at $WALKER_SCRIPT" >&2
  exit 2
fi

if [ ${#ARCHETYPES[@]} -eq 0 ]; then
  echo "ERROR: no archetypes selected" >&2
  exit 2
fi

# ── run-id (shared across archetypes) ───────────────────────────────────
if [ -z "$RUN_ID" ]; then
  _ts="$(date +%Y-%m-%d-%H%M%S)"
  _sha="$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo nogit)"
  RUN_ID="${_ts}-${_sha}-all"
fi

RUN_DIR="$WALKER_ROOT/$RUN_ID"
mkdir -p "$RUN_DIR"
ORCH_LOG="$RUN_DIR/orchestrator.log"

log() { echo "[orch $(date +%H:%M:%S)] $*" | tee -a "$ORCH_LOG"; }

log "Phase 85 walker orchestrator (v2.11)"
log "  run-id        : $RUN_ID"
log "  run-dir       : $RUN_DIR"
log "  dry-run       : $DRY_RUN"
log "  archetypes    : ${ARCHETYPES[*]}"

# ── per-archetype loop ──────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
declare -a STATUS_LINES=()
_t0=$(date +%s)

for arche in "${ARCHETYPES[@]}"; do
  log "─── starting archetype : $arche ───"
  _arche_t0=$(date +%s)

  walker_args=(--archetype "$arche" --run-id "$RUN_ID")
  if [ "$DRY_RUN" = "1" ]; then
    walker_args+=(--dry-run)
  else
    walker_args+=(--no-dry-run)
  fi

  set +e
  bash "$WALKER_SCRIPT" "${walker_args[@]}" 2>&1 | tee -a "$ORCH_LOG"
  exit_code=${PIPESTATUS[0]}
  set -e

  _arche_elapsed=$(( $(date +%s) - _arche_t0 ))

  if [ "$exit_code" -eq 0 ]; then
    status="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  STATUS_LINES+=("    {\"archetype\": \"$arche\", \"status\": \"$status\", \"exit_code\": $exit_code, \"elapsed_s\": $_arche_elapsed}")
  log "─── archetype $arche : $status (exit=$exit_code, ${_arche_elapsed}s) ───"
done

TOTAL_ELAPSED=$(( $(date +%s) - _t0 ))

# ── aggregate summary.json ──────────────────────────────────────────────
SUMMARY="$RUN_DIR/summary.json"

# Join status lines with commas
n=${#STATUS_LINES[@]}
{
  echo "{"
  echo "  \"run_id\": \"$RUN_ID\","
  echo "  \"phase\": 85,"
  echo "  \"milestone\": \"v2.11\","
  echo "  \"dry_run\": $DRY_RUN,"
  echo "  \"total_elapsed_s\": $TOTAL_ELAPSED,"
  echo "  \"pass\": $PASS_COUNT,"
  echo "  \"fail\": $FAIL_COUNT,"
  echo "  \"archetypes\": ["
  i=0
  for line in "${STATUS_LINES[@]}"; do
    i=$((i+1))
    if [ "$i" -eq "$n" ]; then
      echo "$line"
    else
      echo "$line,"
    fi
  done
  echo "  ]"
  echo "}"
} > "$SUMMARY"

log "summary written : $SUMMARY"
log "aggregate       : pass=$PASS_COUNT fail=$FAIL_COUNT total=${#ARCHETYPES[@]} elapsed=${TOTAL_ELAPSED}s"

if [ "$FAIL_COUNT" -gt 0 ]; then
  log "exit 1 — at least one archetype FAIL"
  exit 1
fi
log "exit 0 — all archetypes PASS"
exit 0
