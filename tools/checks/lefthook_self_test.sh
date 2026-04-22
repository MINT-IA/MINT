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

# Phase 34 Plan 02 — temp git repo for no_bare_catch diff-only smoke.
TMP_LINT=$(mktemp -d)

# EXIT trap: guaranteed cleanup even on early abort.
cleanup() {
  rm -f "$FIXTURE_NAMESPACED" "$FIXTURE_BREACH"
  rm -rf "$TMP_LINT"
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

# ─── Phase 34 Plan 02 — no_bare_catch FAIL + PASS cases (D-25) ───
# Uses a temp git repo so the diff-only lint has an actual staged diff
# to examine. Exercises process_file() end-to-end, not just chmod +x
# (façade-sans-câblage guard per Pitfall 1).
REPO_ROOT="$(pwd)"
(
  cd "$TMP_LINT"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  cat > bad.dart <<'EOF'
void f() {
  try { x(); } catch (e) {}
}
EOF
  git add bad.dart
)
echo "[self-test] no_bare_catch: scanning known-bad diff..."
if python3 "$REPO_ROOT/tools/checks/no_bare_catch.py" --repo-root "$TMP_LINT" --file bad.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — no_bare_catch did not catch bad diff (façade sans câblage)"
  exit 1
fi
(
  cd "$TMP_LINT"
  cat > good.dart <<'EOF'
void f() {
  try {
    x();
  } catch (e) {
    Sentry.captureException(e);
    rethrow;
  }
}
EOF
  git add good.dart
)
echo "[self-test] no_bare_catch: scanning known-good diff..."
if ! python3 "$REPO_ROOT/tools/checks/no_bare_catch.py" --repo-root "$TMP_LINT" --file good.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — no_bare_catch wrongly flagged good diff"
  exit 1
fi
echo "[self-test] no_bare_catch: OK (FAIL + PASS cases green)"

# ─── Phase 34 Plan 03 — no_hardcoded_fr FAIL + PASS cases (D-25) ───
# Direct --file invocation against the Wave 0 fixtures; exercises D-09
# patterns + D-10 preceding-line override + acronym whitelist end-to-end.
# Pitfall 1 (façade) guard: the lint is run, not just chmod +x.
echo "[self-test] no_hardcoded_fr: scanning known-bad fixture..."
if python3 tools/checks/no_hardcoded_fr.py --file tests/checks/fixtures/hardcoded_fr_bad_widget.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — no_hardcoded_fr did not catch bad fixture (façade sans câblage)"
  exit 1
fi
echo "[self-test] no_hardcoded_fr: scanning known-good fixture..."
if ! python3 tools/checks/no_hardcoded_fr.py --file tests/checks/fixtures/hardcoded_fr_good_widget.dart >/dev/null 2>&1; then
  echo "self-test: FAIL — no_hardcoded_fr wrongly flagged good fixture"
  exit 1
fi
echo "[self-test] no_hardcoded_fr: OK (FAIL + PASS cases green)"

# ─── Phase 34 Plan 04 — arb_parity FAIL + PASS cases (D-25) ───
# Direct --dir invocation against the Wave 0 ARB fixture corpus. Exercises
# D-13 key-parity check (missing-key fixture -> rc=1) + D-13 placeholder
# parity (clean fixture -> rc=0). Pitfall 1 (façade) guard: the lint is
# RUN, not just chmod +x. Baseline parity on apps/mobile/lib/l10n/ is
# covered by pytest `test_production_arb_files_parity` — not repeated
# here to keep self-test runtime bounded.
echo "[self-test] arb_parity: scanning drift fixture (de missing 'goodbye')..."
if python3 tools/checks/arb_parity.py --dir tests/checks/fixtures/arb_drift_missing >/dev/null 2>&1; then
  echo "self-test: FAIL — arb_parity did not catch drift fixture (façade sans câblage)"
  exit 1
fi
echo "[self-test] arb_parity: scanning parity-clean fixture (6 langs aligned)..."
if ! python3 tools/checks/arb_parity.py --dir tests/checks/fixtures/arb_parity_pass >/dev/null 2>&1; then
  echo "self-test: FAIL — arb_parity wrongly flagged clean fixture"
  exit 1
fi
echo "[self-test] arb_parity: OK (FAIL + PASS cases green)"

echo "self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be"
echo "  added to each new lint's lefthook 'exclude:' list (per Pitfall 7)."
echo "  Plans 01 + 02 + 03 + 04 exclude fixtures; Plan 05 must follow."
exit 0
