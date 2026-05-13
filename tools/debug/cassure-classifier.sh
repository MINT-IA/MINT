#!/usr/bin/env bash
# tools/debug/cassure-classifier.sh — S98 Phase 4
#
# Heuristic classifier for MINT cassures (E2E failures on iOS sim).
# Given a snapshot of app state + OSLog tail + recent git activity,
# emits a structured `cassure-report.json` with:
#   - the raw inputs gathered (state, log, blast_radius)
#   - a HYPOTHESIS string naming the most-likely class of bug
#   - the file:line evidence backing the hypothesis
#
# Designed to compound with:
#   - Tier 2 `/debug/state` endpoint (provides state JSON)
#   - Tier 1 X-MINT-Req-Id correlation spine (provides trace_id for
#     Railway backend log fetch)
#   - Phase 3 maestro stall watchdog (pre-populates the artifact dir
#     with screenshot + OSLog when stall fires)
#
# NO LLM synthesis. The « hypothesis » is a deterministic regex /
# threshold match against the inputs. Per CLAUDE.md §9.4 :
# « probabilistic tool to verify probabilistic output is the same as
# no verification — ground truth must be deterministic. »
#
# Usage:
#   tools/debug/cassure-classifier.sh \
#     [--state path/to/debug-state.json] \
#     [--oslog path/to/oslog.txt] \
#     [--req-id <uuid>] \
#     [--since "2 hours ago"] \
#     [--out artifact-dir/cassure-report.json]
#
# All flags optional ; missing inputs are recorded as such in the
# report (the classifier degrades gracefully — partial inputs still
# produce a partial hypothesis).
#
# Auto-mode (no args): hunts for the most recent walker artifact dir
# under .planning/_walker/ and consumes its debug-state.json /
# oslog-mint.txt.
#
# Exit codes:
#   0 — report produced (regardless of hypothesis strength)
#   1 — fatal error (no inputs found, jq missing)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Argv parsing ───────────────────────────────────────────────────────
STATE_PATH=""
OSLOG_PATH=""
REQ_ID=""
SINCE="2 hours ago"
OUT_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --state)  STATE_PATH="$2"; shift 2 ;;
    --oslog)  OSLOG_PATH="$2"; shift 2 ;;
    --req-id) REQ_ID="$2"; shift 2 ;;
    --since)  SINCE="$2"; shift 2 ;;
    --out)    OUT_PATH="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^set -euo/p' "$0" | head -40
      exit 0
      ;;
    *) echo "[classifier] unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── Auto-mode: hunt the most-recent walker artifact dir ────────────────
if [ -z "$STATE_PATH" ] && [ -z "$OSLOG_PATH" ]; then
  if [ -d "$REPO_ROOT/.planning/_walker" ]; then
    latest=$(ls -dt "$REPO_ROOT/.planning/_walker"/*/ 2>/dev/null | head -1 || true)
    if [ -n "$latest" ]; then
      [ -f "$latest/debug-state.json" ] && STATE_PATH="$latest/debug-state.json"
      [ -f "$latest/oslog-mint.txt" ]   && OSLOG_PATH="$latest/oslog-mint.txt"
      echo "[classifier] auto-mode: consuming $latest"
    fi
  fi
fi

# ── Resolve output path (default: alongside inputs, else tmp) ──────────
if [ -z "$OUT_PATH" ]; then
  if [ -n "$STATE_PATH" ]; then
    OUT_PATH="$(dirname "$STATE_PATH")/cassure-report.json"
  elif [ -n "$OSLOG_PATH" ]; then
    OUT_PATH="$(dirname "$OSLOG_PATH")/cassure-report.json"
  else
    OUT_PATH="/tmp/cassure-report-$(date +%s).json"
  fi
fi
mkdir -p "$(dirname "$OUT_PATH")"

# ── jq is a hard dep (the report is structured JSON) ───────────────────
command -v jq >/dev/null 2>&1 || {
  echo "[classifier] jq is required (brew install jq)" >&2
  exit 1
}

# ── Heuristic library ──────────────────────────────────────────────────
# Each heuristic is a bash function `h_<name>` that takes no args, reads
# globals (STATE_JSON, OSLOG_CONTENT), and echoes ONE LINE on match :
#   "<hypothesis>|<evidence>|<suggested_file>"
# Empty output → no match. The classifier runs all heuristics, collects
# matches, picks the FIRST one (heuristics are ordered by specificity).

h_anonymous_counter_not_persisted() {
  # If state shows anonymous_message_count >= a soft cap (3) AND the
  # OSLog has the "anonymous chat" route + a parse failure, the counter
  # is being read but not persisted across rebuilds.
  [ -z "${STATE_JSON:-}" ] && return 0
  local count
  count=$(echo "$STATE_JSON" | jq -r '.prefs.anonymous_message_count // empty' 2>/dev/null)
  [ -z "$count" ] && return 0
  if [ "$count" -ge 3 ] 2>/dev/null; then
    if echo "${OSLOG_CONTENT:-}" | grep -qE "anonymous.*messagesRemaining=0|GATE.*willFire=true"; then
      echo "anonymous_counter_not_persisted|prefs.anonymous_message_count=$count + OSLog 'messagesRemaining=0'|apps/mobile/lib/screens/anonymous_chat_screen.dart"
    fi
  fi
}

h_auth_gate_route_stuck() {
  # If the router stack ends at an auth route (auth/login/onboarding)
  # AND the run was supposed to be authenticated, suspect auth gate.
  [ -z "${STATE_JSON:-}" ] && return 0
  local current
  current=$(echo "$STATE_JSON" | jq -r '.router.currentRoute // empty' 2>/dev/null)
  if [[ "$current" =~ ^/(auth|login|onboarding) ]]; then
    echo "auth_gate_blocked|router.currentRoute=$current|apps/mobile/lib/widgets/auth_gate_bottom_sheet.dart"
  fi
}

h_http_inflight_stuck() {
  # An inflight HTTP request count > 0 at snapshot time AND > 30s old
  # → network stall.
  [ -z "${STATE_JSON:-}" ] && return 0
  local inflight
  inflight=$(echo "$STATE_JSON" | jq -r '.http.inflightCount // 0' 2>/dev/null)
  if [ "$inflight" -gt 0 ] 2>/dev/null; then
    local stalest
    stalest=$(echo "$STATE_JSON" | jq -r '.http.events[0].path // empty' 2>/dev/null)
    echo "http_inflight_stuck|http.inflightCount=$inflight (oldest path: ${stalest:-?})|apps/mobile/lib/services/observability/mint_http_client.dart"
  fi
}

h_first_oslog_error() {
  # Last resort — grep the OSLog for the FIRST line that looks like an
  # error / parse failure / exception. Names the line as evidence ;
  # caller's job to find the file.
  [ -z "${OSLOG_CONTENT:-}" ] && return 0
  local first
  first=$(echo "$OSLOG_CONTENT" | grep -iE 'ERROR|EXCEPTION|FATAL|PARSE FAILED|ERR ' | head -1 | tr -d '\n' | cut -c1-200)
  if [ -n "$first" ]; then
    # Try to extract a file:line from the error line (Dart stack frame
    # shape: `package:mint_mobile/foo/bar.dart:42:7`).
    local file
    file=$(echo "$first" | grep -oE '[a-zA-Z_/]+\.dart' | head -1 || true)
    echo "oslog_first_error|$first|${file:-unknown}"
  fi
}

# ── Load inputs into globals ───────────────────────────────────────────
STATE_JSON=""
if [ -n "$STATE_PATH" ] && [ -f "$STATE_PATH" ]; then
  STATE_JSON=$(cat "$STATE_PATH")
fi

OSLOG_CONTENT=""
if [ -n "$OSLOG_PATH" ] && [ -f "$OSLOG_PATH" ]; then
  # Cap at 4 MB to keep grep fast.
  OSLOG_CONTENT=$(head -c 4194304 "$OSLOG_PATH")
fi

# ── Fetch Railway backend logs if REQ_ID provided ──────────────────────
BACKEND_LINES=""
if [ -n "$REQ_ID" ] && command -v railway >/dev/null 2>&1; then
  # Best-effort. Railway logs --json is preferred but the CLI has been
  # known to require auth — capture stderr to a tmpfile so failures
  # don't pollute the report.
  BACKEND_LINES=$(railway logs --json 2>/dev/null | \
    jq -c --arg id "$REQ_ID" 'select(.trace_id == $id)' 2>/dev/null | head -50 || true)
fi

# ── Compute git blast radius ───────────────────────────────────────────
BLAST_RADIUS=""
if [ -d "$REPO_ROOT/.git" ]; then
  BLAST_RADIUS=$(cd "$REPO_ROOT" && git log --since="$SINCE" --name-only --pretty=format: 2>/dev/null \
    | grep -v '^$' | sort -u | head -100 || true)
fi

# ── Run all heuristics ; collect matches ───────────────────────────────
HYPOTHESES=()
for h in h_anonymous_counter_not_persisted h_auth_gate_route_stuck h_http_inflight_stuck h_first_oslog_error; do
  match=$("$h" || true)
  if [ -n "$match" ]; then
    HYPOTHESES+=("$match")
  fi
done

# ── Render report JSON ─────────────────────────────────────────────────
hypotheses_json="[]"
if [ "${#HYPOTHESES[@]}" -gt 0 ]; then
  hypotheses_json=$(printf '%s\n' "${HYPOTHESES[@]}" \
    | jq -R 'split("|") | {hypothesis: .[0], evidence: .[1], suspect_file: .[2]}' \
    | jq -s '.')
fi

# Sanitize multiline content for jq via raw input.
state_b64=$(printf '%s' "${STATE_JSON:-null}" | base64)
oslog_b64=$(printf '%s' "${OSLOG_CONTENT:-}" | base64)
blast_b64=$(printf '%s' "${BLAST_RADIUS:-}" | base64)
backend_b64=$(printf '%s' "${BACKEND_LINES:-}" | base64)

jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg state_b64 "$state_b64" \
  --arg oslog_b64 "$oslog_b64" \
  --arg blast_b64 "$blast_b64" \
  --arg backend_b64 "$backend_b64" \
  --arg req_id "${REQ_ID:-}" \
  --arg since "$SINCE" \
  --arg state_path "${STATE_PATH:-}" \
  --arg oslog_path "${OSLOG_PATH:-}" \
  --argjson hypotheses "$hypotheses_json" \
  '{
    schema: "cassure-report.v1",
    generatedAt: $ts,
    inputs: {
      state_path: $state_path,
      oslog_path: $oslog_path,
      req_id: $req_id,
      since: $since
    },
    hypotheses: $hypotheses,
    primary_hypothesis: ($hypotheses[0] // null),
    raw: {
      state_b64: $state_b64,
      oslog_b64: $oslog_b64,
      blast_radius_b64: $blast_b64,
      backend_lines_b64: $backend_b64
    }
  }' > "$OUT_PATH"

# ── Human-readable summary on stdout ───────────────────────────────────
echo ""
echo "=== cassure-classifier report ==="
echo "→ $OUT_PATH"
echo ""
if [ "${#HYPOTHESES[@]}" -eq 0 ]; then
  echo "  (no heuristic matched — inspect raw inputs in the report)"
else
  echo "  Primary hypothesis: $(echo "${HYPOTHESES[0]}" | cut -d'|' -f1)"
  echo "  Evidence:           $(echo "${HYPOTHESES[0]}" | cut -d'|' -f2)"
  echo "  Suspect file:       $(echo "${HYPOTHESES[0]}" | cut -d'|' -f3)"
  if [ "${#HYPOTHESES[@]}" -gt 1 ]; then
    echo ""
    echo "  $((${#HYPOTHESES[@]} - 1)) secondary hypotheses recorded in report."
  fi
fi
echo ""
echo "  Blast radius: $(echo "$BLAST_RADIUS" | wc -l | tr -d ' ') files touched since '$SINCE'"
echo "  Backend lines: $(echo "$BACKEND_LINES" | grep -c . 2>/dev/null || echo 0)"
exit 0
