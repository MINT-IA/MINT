#!/usr/bin/env bash
# lefthook_self_test.sh — CTX-01 Phase 30.5-02 Task 3
#
# Proves lefthook.yml skeleton actually runs the memory-retention-gate
# (not just present on disk). Per 30.5-RESEARCH.md Pitfall 1 (façade sans
# câblage).
#
# Strategy:
#   1. Create a 31d-mtime fixture inside memory/topics/ with a namespaced
#      prefix '__LEFTHOOK_SELF_TEST_' (gc.py + memory_retention.py skip it
#      in normal operation, but for this test we temporarily rename it so
#      the gate catches it).
#   2. Run `lefthook run pre-commit`, expect EXIT != 0 because retention
#      gate detects the stale fixture.
#   3. Cleanup via EXIT trap so the fixture is removed even if script aborts.
#
# Outcome:
#   exit 0 + stdout "self-test: OK"   → gate fires correctly
#   exit 1 + stdout "self-test: FAIL" → façade detected
set -e

MEM="$HOME/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory"
TOPICS="$MEM/topics"
# Non-dotfile, namespaced. gc.py skips this prefix by default; for the
# self-test we rename it mid-flight to 'stalenote_*' so the retention gate
# actually catches it as a non-whitelisted breach.
FIXTURE_NAMESPACED="$TOPICS/__LEFTHOOK_SELF_TEST_31d__.md"
FIXTURE_BREACH="$TOPICS/stalenote_lefthook_selftest_31d.md"

# EXIT trap: guaranteed cleanup even on early abort.
cleanup() {
  rm -f "$FIXTURE_NAMESPACED" "$FIXTURE_BREACH"
}
trap cleanup EXIT

# Setup: create fixture and set mtime to 31 days ago.
mkdir -p "$TOPICS"
echo "# lefthook self-test fixture (transient)" > "$FIXTURE_BREACH"

if stat -f '%m' "$FIXTURE_BREACH" >/dev/null 2>&1; then
  # macOS (BSD stat / touch)
  TS=$(date -v-31d +%Y%m%d%H%M)
  touch -t "$TS" "$FIXTURE_BREACH"
else
  # GNU stat / touch
  touch -d '31 days ago' "$FIXTURE_BREACH"
fi

# Run lefthook pre-commit — retention gate must fire on the stale fixture.
# lefthook 2.1.6 flag is `--file` (singular), not `--files`.
set +e
lefthook run pre-commit --file README.md
RC=$?
set -e

if [ "$RC" -eq 0 ]; then
  echo "self-test: FAIL — lefthook did NOT catch the 31d stale fixture (façade sans câblage detected)"
  exit 1
fi

echo "self-test: OK — lefthook caught the stale fixture as expected (exit $RC)"

# ─── Phase 34 Plan 01 — accent_lint_fr FAIL + PASS cases (D-25) ───
# Proves accent_lint_fr actually catches ASCII-flattened FR accents and
# does NOT false-flag properly accented content. Fires independent of the
# lefthook hook wiring (direct python3 invocation — Pitfall 1 guard).
echo "[self-test] accent_lint_fr: scanning known-bad fixture..."
if python3 tools/checks/accent_lint_fr.py --file tests/checks/fixtures/accent_bad.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — accent_lint_fr did not catch bad fixture (façade sans câblage)"
  exit 1
fi
echo "[self-test] accent_lint_fr: scanning known-good fixture..."
if ! python3 tools/checks/accent_lint_fr.py --file tests/checks/fixtures/accent_good.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — accent_lint_fr wrongly flagged good fixture"
  exit 1
fi
echo "[self-test] accent_lint_fr: OK (FAIL + PASS cases green)"

echo "self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be"
echo "  added to each new lint's lefthook 'exclude:' list (per Pitfall 7)."
echo "  Plan 01 accent-lint-fr command excludes fixtures; Plans 02-05 must follow."
exit 0
