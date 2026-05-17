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
# --maestro-log <path> — Maestro CLI stdout/stderr log for the run. Used
#                        by the maestro_assertion_failed heuristic to
#                        extract the FAILED step + preceding action.
# --flow-path   <path> — Path to the .yaml flow file. Used as the
#                        suspect_file for assertion-class hypotheses
#                        (the test owns the failing assertion).
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
MAESTRO_LOG_PATH=""
FLOW_PATH=""
REQ_ID=""
SINCE="2 hours ago"
OUT_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --state)        STATE_PATH="$2"; shift 2 ;;
    --oslog)        OSLOG_PATH="$2"; shift 2 ;;
    --maestro-log)  MAESTRO_LOG_PATH="$2"; shift 2 ;;
    --flow-path)    FLOW_PATH="$2"; shift 2 ;;
    --req-id)       REQ_ID="$2"; shift 2 ;;
    --since)        SINCE="$2"; shift 2 ;;
    --out)          OUT_PATH="$2"; shift 2 ;;
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
# Each heuristic is a bash function `h_<name>` taking no args, reading
# globals (STATE_JSON, OSLOG_CONTENT), and echoing ONE JSON OBJECT on
# match (or nothing on no-match):
#   {"hypothesis": "<name>", "evidence": "<...>", "suspect_file": "<path>"}
#
# Why JSON-object emission instead of pipe-delimited (per code-review C1):
# OSLog lines using `|` as a field separator would corrupt the split.
# `jq -n` produces a JSON-safe object directly ; the collector concats
# with `jq -s '.'`.
#
# Ordering (first match wins as primary, others recorded as secondaries) :
#   1. anonymous_counter_not_persisted — cassure #4 class, highest specificity
#   2. auth_gate_route_stuck            — route-shape match
#   3. first_oslog_error                — deterministic « we have an error
#                                         message » signal beats the
#                                         speculative inflight check (I4)
#   4. http_inflight_stuck              — soft signal, single-snapshot
#                                         can't prove staleness
# Adding a heuristic: declare its priority slot in this comment block
# AND in the `for h in ...` loop below.

# Helper to emit a JSON object — keeps callers terse and JSON-safe.
emit() {
  jq -nc \
    --arg h "$1" \
    --arg e "$2" \
    --arg f "$3" \
    '{hypothesis: $h, evidence: $e, suspect_file: $f}'
}

h_anonymous_counter_not_persisted() {
  # State key resolution (per code-review C3):
  # `AnonymousSessionService` writes to SecureStorage under
  # `anonymous_message_count` AND to SharedPreferences fallback under
  # `anonfb_anonymous_message_count`. iOS sim's SecureStorage raises
  # PlatformException -34018, so ONLY the prefixed key lands in
  # SharedPreferences. The Tier 2 prefs whitelist must include both ;
  # this heuristic accepts EITHER as the source of truth.
  [ -z "${STATE_JSON:-}" ] && return 0
  local count
  count=$(echo "$STATE_JSON" | jq -r \
    '(.prefs["anonymous_message_count"] // .prefs["anonfb_anonymous_message_count"] // empty)' \
    2>/dev/null)
  [ -z "$count" ] && return 0
  if [ "$count" -ge 3 ] 2>/dev/null; then
    if echo "${OSLOG_CONTENT:-}" | grep -qE "anonymous.*messagesRemaining=0|GATE.*willFire=true"; then
      emit \
        "anonymous_counter_not_persisted" \
        "prefs.anonymous_message_count=$count + OSLog 'messagesRemaining=0' or 'GATE willFire=true'" \
        "apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart"
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
    emit \
      "auth_gate_blocked" \
      "router.currentRoute=$current" \
      "apps/mobile/lib/widgets/auth/auth_gate_bottom_sheet.dart"
  fi
}

h_http_inflight_stuck() {
  # Per code-review I4: single-snapshot can't prove staleness. Demoted
  # below `first_oslog_error` so a deterministic ERROR/FATAL line takes
  # priority over the speculative « some request is in flight » signal.
  # Kept because a real Maestro stall often coincides with inflight > 0,
  # and the suspect file is correct.
  [ -z "${STATE_JSON:-}" ] && return 0
  local inflight
  inflight=$(echo "$STATE_JSON" | jq -r '.http.inflightCount // 0' 2>/dev/null)
  if [ "$inflight" -gt 0 ] 2>/dev/null; then
    local stalest
    stalest=$(echo "$STATE_JSON" | jq -r '.http.events[0].path // empty' 2>/dev/null)
    emit \
      "http_inflight_stuck" \
      "http.inflightCount=$inflight (oldest path: ${stalest:-?})" \
      "apps/mobile/lib/services/observability/mint_http_client.dart"
  fi
}

h_maestro_assertion_failed() {
  # Parses the Maestro CLI log for the standard failure pattern :
  #   Tap on "X"... COMPLETED
  #   Assert that "Y" is visible... FAILED
  # Emits the assertion text + the action that immediately preceded it
  # (which is what actually failed to produce the expected screen state).
  # suspect_file = the .yaml flow path (the test owns the assertion) ;
  # the operator's first move is to disambiguate « tap was no-op » vs
  # « assertion text wrong » by reading flow_dir/last-screen.png.
  [ -z "${MAESTRO_LOG_CONTENT:-}" ] && return 0
  local failed_line
  failed_line=$(printf '%s\n' "$MAESTRO_LOG_CONTENT" | grep -E '\.\.\. FAILED$' | head -1 || true)
  [ -z "$failed_line" ] && return 0
  local prev_step
  prev_step=$(printf '%s\n' "$MAESTRO_LOG_CONTENT" | grep -B1 -E '\.\.\. FAILED$' | head -1 || true)
  prev_step=$(printf '%s' "$prev_step" | tr -d '\n' | cut -c1-160)
  failed_line=$(printf '%s' "$failed_line" | tr -d '\n' | cut -c1-160)
  local suspect="${FLOW_PATH:-unknown}"
  emit \
    "maestro_assertion_failed" \
    "FAILED='$failed_line' ; PRECEDING='$prev_step'" \
    "$suspect"
}

h_first_oslog_error() {
  # Last resort — grep the OSLog for the FIRST line that looks like an
  # error / parse failure / exception. Names the line as evidence ;
  # caller's job to find the file.
  [ -z "${OSLOG_CONTENT:-}" ] && return 0
  local first
  first=$(printf '%s\n' "$OSLOG_CONTENT" | grep -iE 'ERROR|EXCEPTION|FATAL|PARSE FAILED' | head -1 || true)
  first=$(printf '%s' "$first" | tr -d '\n' | cut -c1-200)
  if [ -n "$first" ]; then
    # Extract a `*.dart` filename if present (Dart stack frame shape).
    local file
    file=$(printf '%s' "$first" | grep -oE '[a-zA-Z_/]+\.dart' | head -1 || true)
    emit \
      "oslog_first_error" \
      "$first" \
      "${file:-unknown}"
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

MAESTRO_LOG_CONTENT=""
if [ -n "$MAESTRO_LOG_PATH" ] && [ -f "$MAESTRO_LOG_PATH" ]; then
  # Maestro logs cap at ~2-3 MB for typical e2e flows ; cap at 4 MB.
  MAESTRO_LOG_CONTENT=$(head -c 4194304 "$MAESTRO_LOG_PATH")
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
# Order per the heuristic-library comment block above. `first_oslog_error`
# runs BEFORE `http_inflight_stuck` (per code-review I4) so a confirmed
# error message takes priority over a single-snapshot inflight count.
HYPOTHESES=()
# Order rationale (highest specificity first) :
#   1. anonymous_counter_not_persisted — state.prefs match, very narrow
#   2. auth_gate_blocked                — state.router match, narrow
#   3. maestro_assertion_failed         — names the EXACT failed step from
#                                          the Maestro log ; deterministic
#                                          high-signal hypothesis for any
#                                          flow exit-1
#   4. first_oslog_error                — catch-all error grep
#   5. http_inflight_stuck              — single-snapshot soft signal
for h in h_anonymous_counter_not_persisted h_auth_gate_route_stuck h_maestro_assertion_failed h_first_oslog_error h_http_inflight_stuck; do
  match=$("$h" || true)
  if [ -n "$match" ]; then
    HYPOTHESES+=("$match")
  fi
done

# ── Render report JSON ─────────────────────────────────────────────────
# Each heuristic emits a JSON object directly (per C1) ; jq -s slurps
# the list. No pipe-delimited string parsing — OSLog lines with `|` no
# longer corrupt the evidence string.
hypotheses_json="[]"
if [ "${#HYPOTHESES[@]}" -gt 0 ]; then
  hypotheses_json=$(printf '%s\n' "${HYPOTHESES[@]}" | jq -s '.')
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

# ── Human-readable summary on stderr (so callers can pipe report JSON) ─
# Per code-review M1 — keep stdout reserved for clean caller piping ;
# the operator-facing summary lands on stderr.
{
  echo ""
  echo "=== cassure-classifier report ==="
  echo "→ $OUT_PATH"
  echo ""
  if [ "${#HYPOTHESES[@]}" -eq 0 ]; then
    echo "  (no heuristic matched — inspect raw inputs in the report)"
  else
    primary=$(printf '%s' "${HYPOTHESES[0]}")
    echo "  Primary hypothesis: $(printf '%s' "$primary" | jq -r '.hypothesis')"
    echo "  Evidence:           $(printf '%s' "$primary" | jq -r '.evidence')"
    echo "  Suspect file:       $(printf '%s' "$primary" | jq -r '.suspect_file')"
    if [ "${#HYPOTHESES[@]}" -gt 1 ]; then
      echo ""
      echo "  $((${#HYPOTHESES[@]} - 1)) secondary hypotheses recorded in report."
    fi
  fi
  echo ""
  blast_count=$(printf '%s' "$BLAST_RADIUS" | grep -c . 2>/dev/null || echo 0)
  echo "  Blast radius: ${blast_count} files touched since '$SINCE'"
  backend_count=$(printf '%s' "$BACKEND_LINES" | grep -c . 2>/dev/null || echo 0)
  echo "  Backend lines: ${backend_count}"
} >&2
exit 0
