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
#   #6 — anonfb_ prefix variant (iOS-sim SharedPreferences fallback key).
#
#   #7 — OSLog evidence containing pipe character (regression guard for
#        prior bash-split-on-pipe corruption).
#
#   #8 — Maestro assertion-failed pattern (regular exit-1 path, NOT a
#        watchdog stall). Closes the sweep ↔ classifier loop : on a
#        normal Maestro flow failure, the heuristic must extract the
#        FAILED assertion + preceding tap + name the flow YAML as
#        suspect_file.
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
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Per code-review I2 — verify the suspect_file points at a path that
# actually exists in the repo. Without this, heuristic regressions
# (renamed files, moved subdirs) ship undetected. Skips when the value
# is the sentinel "unknown" or empty.
assert_suspect_file_exists() {
  local report="$1" label="$2"
  local f
  f=$(jq -r '.primary_hypothesis.suspect_file // empty' "$report" 2>/dev/null)
  if [[ -z "$f" || "$f" == "unknown" ]]; then
    echo "  SKIP  $label — no concrete suspect_file (unknown / null)"
    return 0
  fi
  if [[ -f "$REPO_ROOT/$f" ]]; then
    echo "  PASS  $label — suspect_file exists: $f"
  else
    echo "  FAIL  $label — suspect_file missing: $f"
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
       --out "$TMP/s1/report.json" >/dev/null 2>&1
assert_primary "$TMP/s1/report.json" "anonymous_counter_not_persisted" "scenario 1"
assert_suspect_file_exists "$TMP/s1/report.json" "scenario 1 path"

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
"$CLF" --state "$TMP/s2/debug-state.json" --out "$TMP/s2/report.json" >/dev/null 2>&1
assert_primary "$TMP/s2/report.json" "auth_gate_blocked" "scenario 2"
assert_suspect_file_exists "$TMP/s2/report.json" "scenario 2 path"

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
"$CLF" --state "$TMP/s3/debug-state.json" --out "$TMP/s3/report.json" >/dev/null 2>&1
assert_primary "$TMP/s3/report.json" "http_inflight_stuck" "scenario 3"
assert_suspect_file_exists "$TMP/s3/report.json" "scenario 3 path"

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
       --out "$TMP/s4/report.json" >/dev/null 2>&1
assert_primary "$TMP/s4/report.json" "oslog_first_error" "scenario 4"
assert_suspect_file_exists "$TMP/s4/report.json" "scenario 4 path"

# ── Scenario 5 — hermetic empty inputs (per code-review I1) ──────────
echo "=== Scenario 5 — empty inputs (hermetic, defeats auto-mode) ==="
mkdir -p "$TMP/s5"
# Explicit nonexistent paths defeat auto-mode's `.planning/_walker/`
# scan that could pick up stale artifacts on a dev machine.
"$CLF" --state "$TMP/s5/no-state.json" --oslog "$TMP/s5/no-oslog.txt" \
       --out "$TMP/s5/report.json" >/dev/null 2>&1
primary=$(jq -r '.primary_hypothesis // empty' "$TMP/s5/report.json")
if [[ -z "$primary" || "$primary" == "null" ]]; then
  echo "  PASS  scenario 5 — primary is null on empty inputs"
else
  echo "  FAIL  scenario 5 — primary should be null but is '$primary'"
  FAIL=1
fi

# ── Scenario 6 — anonfb_ prefix variant (per code-review C3) ─────────
# AnonymousSessionService writes the SharedPreferences fallback under
# `anonfb_anonymous_message_count`. The heuristic must read EITHER key.
# This scenario regression-guards the iOS-sim data path that the prior
# self-test missed.
echo "=== Scenario 6 — cassure #4 via anonfb_ fallback key ==="
mkdir -p "$TMP/s6"
cat > "$TMP/s6/debug-state.json" <<'EOF'
{
  "_meta": {"schema": "v1"},
  "router": {"currentRoute": "/anonymous/chat", "stack": [], "canPop": false},
  "http": {"inflightCount": 0, "count": 0, "events": []},
  "prefs": {"anonfb_anonymous_message_count": "3", "has_seen_landing": "true"}
}
EOF
cat > "$TMP/s6/oslog-mint.txt" <<'EOF'
[Runner] PARSE anonymous_chat_screen messagesRemaining=0
[Runner] GATE willFire=true
EOF
"$CLF" --state "$TMP/s6/debug-state.json" --oslog "$TMP/s6/oslog-mint.txt" \
       --out "$TMP/s6/report.json" >/dev/null 2>&1
assert_primary "$TMP/s6/report.json" "anonymous_counter_not_persisted" "scenario 6 (anonfb_ prefix)"
assert_suspect_file_exists "$TMP/s6/report.json" "scenario 6 path"

# ── Scenario 7 — pipe-character in OSLog evidence (per code-review C1) ─
# Real-world Maestro / OSLog lines can contain `|` (compact-style log
# emission, multi-field key=value with `|` separator). Regression guard
# against the pre-fix bash split-on-pipe corruption.
echo "=== Scenario 7 — OSLog contains pipe character ==="
mkdir -p "$TMP/s7"
cat > "$TMP/s7/debug-state.json" <<'EOF'
{"_meta": {"schema": "v1"}, "router": {"currentRoute": "/home"},
 "http": {"inflightCount": 0, "count": 0, "events": []}, "prefs": {}}
EOF
cat > "$TMP/s7/oslog.txt" <<'EOF'
[Runner] ERROR | response=500 | path=/v1/snapshots | parser.dart
EOF
"$CLF" --state "$TMP/s7/debug-state.json" --oslog "$TMP/s7/oslog.txt" \
       --out "$TMP/s7/report.json" >/dev/null 2>&1
primary=$(jq -r '.primary_hypothesis.hypothesis' "$TMP/s7/report.json")
evidence=$(jq -r '.primary_hypothesis.evidence' "$TMP/s7/report.json")
if [[ "$primary" == "oslog_first_error" && "$evidence" == *"response=500"* ]]; then
  echo "  PASS  scenario 7 — pipe-bearing evidence preserved intact"
else
  echo "  FAIL  scenario 7 — primary='$primary' evidence='$evidence'"
  FAIL=1
fi

# ── Scenario 8 — Maestro assertion-failed pattern ────────────────────
# Regression guard for h_maestro_assertion_failed (added 2026-05-13 to
# close the sweep ↔ classifier loop on regular Maestro exit-1, where
# the watchdog never fires its stall dump). The heuristic must :
#   - parse "Assert that ... is visible... FAILED" lines
#   - capture the preceding "... COMPLETED" action as PRECEDING evidence
#   - use --flow-path as suspect_file (the .yaml owns the assertion)
echo "=== Scenario 8 — Maestro assertion failed (real exit-1 path) ==="
mkdir -p "$TMP/s8"
cat > "$TMP/s8/maestro.log" <<'EOF'
Tap on "Créer un compte"... COMPLETED
Assert that "Pas encore de compte ?" is visible... FAILED

Assertion is false: "Pas encore de compte ?" is visible
EOF
"$CLF" --maestro-log "$TMP/s8/maestro.log" \
       --flow-path  "tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml" \
       --out        "$TMP/s8/report.json" >/dev/null 2>&1
assert_primary "$TMP/s8/report.json" "maestro_assertion_failed" "scenario 8"
evidence8=$(jq -r '.primary_hypothesis.evidence' "$TMP/s8/report.json")
if [[ "$evidence8" == *"Créer un compte"* && "$evidence8" == *"Pas encore de compte"* ]]; then
  echo "  PASS  scenario 8 evidence — captures both PRECEDING tap + FAILED assertion"
else
  echo "  FAIL  scenario 8 evidence — missing tap-or-assertion text: $evidence8"
  FAIL=1
fi
suspect8=$(jq -r '.primary_hypothesis.suspect_file' "$TMP/s8/report.json")
if [[ "$suspect8" == "tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml" ]]; then
  echo "  PASS  scenario 8 suspect_file — flow YAML correctly named"
else
  echo "  FAIL  scenario 8 suspect_file — expected flow YAML got '$suspect8'"
  FAIL=1
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
echo "[cassure-classifier_test] all 8 scenarios passed"
