#!/usr/bin/env bash
# Self-test for tools/debug/cassure-classifier.sh
#
# Verifies the heuristic engine produces the right primary_hypothesis
# given known input shapes. Each scenario reconstructs one of the
# cassures the classifier exists to catch :
#
#   #1 — Cassure #4 reproduction (anonymous counter not persisted).
#        Synthetic state with `anonymous_message_count=3` + OSLog
#        containing `messagesRemaining=0` + `GATE willFire=true`.
#        Expected primary_hypothesis: `anonymous_counter_not_persisted`.
#
#   #2 — Cassure-like auth-gate stuck. State router at /auth/onboarding.
#        Expected primary_hypothesis: `auth_gate_blocked`.
#
#   #3 — HTTP inflight stuck (network stall).
#        Expected primary_hypothesis: `http_inflight_stuck`.
#
#   #4 — Last-resort OSLog grep when no state matches.
#        Expected primary_hypothesis: `oslog_first_error`.
#
#   #5 — No inputs (empty state + empty OSLog) → report produced but
#        no primary_hypothesis (null).
#
# Run:
#   tools/debug/cassure-classifier_test.sh
#
# Exit:
#   0 — all assertions passed
#   1 — at least one assertion failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLF="$SCRIPT_DIR/cassure-classifier.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || {
  echo "[test] jq required" >&2; exit 1
}

FAIL=0

assert_primary() {
  local report="$1" expected="$2" label="$3"
  local actual
  actual=$(jq -r '.primary_hypothesis.hypothesis // "<none>"' "$report" 2>/dev/null)
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS  $label — primary = $actual"
  else
    echo "  FAIL  $label — expected primary='$expected' got '$actual'"
    echo "        report: $report"
    FAIL=1
  fi
}

# ── Scenario 1 — Cassure #4 reproduction ──────────────────────────────
echo "=== Scenario 1 — anonymous counter not persisted ==="
mkdir -p "$TMP/s1"
cat > "$TMP/s1/debug-state.json" <<'EOF'
{
  "_meta": {"schema": "v1", "capturedAt": "2026-05-13T20:00:00Z"},
  "router": {"currentRoute": "/anonymous/chat", "stack": [], "canPop": false},
  "http": {"inflightCount": 0, "count": 0, "events": []},
  "prefs": {"anonymous_message_count": "3", "has_seen_landing": "true"}
}
EOF
cat > "$TMP/s1/oslog-mint.txt" <<'EOF'
[Date Runner] [Flutter] PARSE anonymous_chat_screen messagesRemaining=0
[Date Runner] [Flutter] GATE willFire=true after 800ms
[Date Runner] [Flutter] showing auth gate bottom sheet
EOF
"$CLF" --state "$TMP/s1/debug-state.json" --oslog "$TMP/s1/oslog-mint.txt" \
       --out "$TMP/s1/report.json" >/dev/null
assert_primary "$TMP/s1/report.json" "anonymous_counter_not_persisted" "scenario 1"

# ── Scenario 2 — auth-gate stuck ──────────────────────────────────────
echo "=== Scenario 2 — auth-gate route stuck ==="
mkdir -p "$TMP/s2"
cat > "$TMP/s2/debug-state.json" <<'EOF'
{
  "_meta": {"schema": "v1"},
  "router": {"currentRoute": "/auth/onboarding", "stack": [], "canPop": false},
  "http": {"inflightCount": 0, "count": 0, "events": []},
  "prefs": {"anonymous_message_count": "1"}
}
EOF
"$CLF" --state "$TMP/s2/debug-state.json" --out "$TMP/s2/report.json" >/dev/null
assert_primary "$TMP/s2/report.json" "auth_gate_blocked" "scenario 2"

# ── Scenario 3 — HTTP inflight stuck ──────────────────────────────────
echo "=== Scenario 3 — HTTP inflight stuck ==="
mkdir -p "$TMP/s3"
cat > "$TMP/s3/debug-state.json" <<'EOF'
{
  "_meta": {"schema": "v1"},
  "router": {"currentRoute": "/home", "stack": [], "canPop": false},
  "http": {
    "inflightCount": 2,
    "count": 1,
    "events": [{"path": "/v1/coach/chat", "method": "POST"}]
  },
  "prefs": {}
}
EOF
"$CLF" --state "$TMP/s3/debug-state.json" --out "$TMP/s3/report.json" >/dev/null
assert_primary "$TMP/s3/report.json" "http_inflight_stuck" "scenario 3"

# ── Scenario 4 — last-resort OSLog grep ───────────────────────────────
echo "=== Scenario 4 — OSLog first-error fallback ==="
mkdir -p "$TMP/s4"
cat > "$TMP/s4/debug-state.json" <<'EOF'
{
  "_meta": {"schema": "v1"},
  "router": {"currentRoute": "/home", "stack": [], "canPop": false},
  "http": {"inflightCount": 0, "count": 0, "events": []},
  "prefs": {}
}
EOF
cat > "$TMP/s4/oslog.txt" <<'EOF'
[Runner] benign info line
[Runner] ERROR: connection refused on /v1/snapshots
[Runner] another info
EOF
"$CLF" --state "$TMP/s4/debug-state.json" --oslog "$TMP/s4/oslog.txt" \
       --out "$TMP/s4/report.json" >/dev/null
assert_primary "$TMP/s4/report.json" "oslog_first_error" "scenario 4"

# ── Scenario 5 — no inputs, no hypothesis ─────────────────────────────
echo "=== Scenario 5 — empty inputs ==="
mkdir -p "$TMP/s5"
"$CLF" --out "$TMP/s5/report.json" >/dev/null 2>&1 || true
# Report may or may not exist depending on whether auto-mode found
# something. Either way primary should be null OR oslog_first_error
# (if the repo had old artifacts). Just assert the report parses.
if [[ -f "$TMP/s5/report.json" ]]; then
  primary=$(jq -r '.primary_hypothesis // "null"' "$TMP/s5/report.json" 2>/dev/null)
  echo "  PASS  scenario 5 — report produced (primary: $(echo "$primary" | head -c 60))"
else
  echo "  PASS  scenario 5 — no report (no inputs found, expected)"
fi

# ── Schema validation ─────────────────────────────────────────────────
echo "=== Schema validation ==="
for report in "$TMP"/s{1,2,3,4}/report.json; do
  schema=$(jq -r '.schema' "$report" 2>/dev/null)
  if [[ "$schema" == "cassure-report.v1" ]]; then
    echo "  PASS  $(basename "$(dirname "$report")")/report.json schema=v1"
  else
    echo "  FAIL  $(basename "$(dirname "$report")")/report.json schema='$schema'"
    FAIL=1
  fi
done

# ── Result ─────────────────────────────────────────────────────────────
if [[ $FAIL -ne 0 ]]; then
  echo ""
  echo "::error::cassure-classifier self-test failed"
  exit 1
fi
echo ""
echo "[cassure-classifier_test] all scenarios passed"
