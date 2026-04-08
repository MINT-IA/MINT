#!/usr/bin/env bash
# MINT v2.2 — Ship Gate Runner (Plan 12-05)
#
# Runs every CI gate that guards "La Beauté de Mint" (v2.2) shipping criteria.
# Each gate runs even if a previous gate failed — we want the full picture.
# Exits non-zero if ANY gate failed.
#
# Output:
#   - Human-readable progress to stdout
#   - Machine-parseable markdown table appended to $SHIP_GATE_OUT
#     (defaults to a tempfile; consumed by tools/ship_gate/gate_matrix.py)
#
# Owner: Phase 12 Plan 12-05

set -u  # NB: NOT -e — we want every gate to run regardless of failures

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SHIP_GATE_OUT="${SHIP_GATE_OUT:-$(mktemp -t mint_ship_gate.XXXXXX.md)}"
export SHIP_GATE_OUT

echo "MINT v2.2 Ship Gate Runner"
echo "Repo:   $REPO_ROOT"
echo "Output: $SHIP_GATE_OUT"
echo "HEAD:   $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

{
  echo "| # | Gate | Owner Phase | Status | Duration (s) | Command |"
  echo "|---|------|-------------|--------|--------------|---------|"
} > "$SHIP_GATE_OUT"

TOTAL=0
PASSED=0
FAILED=0
FAILED_NAMES=()

run_gate () {
  local num="$1"
  local name="$2"
  local owner="$3"
  local cmd="$4"

  TOTAL=$((TOTAL + 1))
  echo "[$num/18] $name"
  echo "         $cmd"

  local start end dur status
  start=$(date +%s)
  # shellcheck disable=SC2086
  bash -c "$cmd" >/tmp/mint_gate_$num.log 2>&1
  local rc=$?
  end=$(date +%s)
  dur=$((end - start))

  if [[ $rc -eq 0 ]]; then
    status="PASS"
    PASSED=$((PASSED + 1))
    echo "         -> PASS (${dur}s)"
  else
    status="FAIL"
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$num: $name")
    echo "         -> FAIL (${dur}s, rc=$rc)"
    echo "         --- last 20 log lines ---"
    tail -n 20 "/tmp/mint_gate_$num.log" | sed 's/^/         | /'
    echo "         -------------------------"
  fi

  # Escape pipe chars in cmd for markdown
  local cmd_md="${cmd//|/\\|}"
  printf '| %s | %s | %s | %s | %s | `%s` |\n' \
    "$num" "$name" "$owner" "$status" "$dur" "$cmd_md" >> "$SHIP_GATE_OUT"
}

# ─── 18 gates ─────────────────────────────────────────────────────────────

run_gate 1  "flutter analyze" "always" \
  "cd apps/mobile && flutter analyze lib/ --no-fatal-infos --no-fatal-warnings"

run_gate 2  "flutter test (full suite)" "always" \
  "cd apps/mobile && flutter test"

run_gate 3  "pytest backend" "always" \
  "cd services/backend && python3 -m pytest tests/ -q"

run_gate 4  "ruff (backend lint)" "Phase 1.5" \
  "if command -v ruff >/dev/null 2>&1; then cd services/backend && ruff check .; else echo 'WARN: ruff not installed locally; CI installs via pip — gate skipped locally' >&2; exit 0; fi"

run_gate 5  "OpenAPI codegen drift" "Phase 1.5" \
  "TESTING=1 DATABASE_URL='sqlite:///./test.db' python3 tools/openapi/generate_canonical.py && git diff --exit-code tools/openapi/mint.openapi.canonical.json"

run_gate 6  "VoiceCursorContract drift" "Phase 2" \
  "bash tools/contracts/regenerate.sh && git diff --exit-code tools/contracts/ apps/mobile/lib/services/voice/voice_cursor_contract.g.dart services/backend/app/schemas/voice_cursor.py"

run_gate 7  "Regional microcopy drift" "Phase 6" \
  "python3 tools/checks/regional_microcopy_drift.py"

run_gate 8  "Contrast matrix (AAA + AA)" "Phase 2 + 12-02" \
  "cd apps/mobile && flutter test test/theme/aaa_tokens_contrast_test.dart test/accessibility/wcag_aa_all_touched_test.dart"

run_gate 9  "Flesch-Kincaid French" "Phase 10" \
  "cd apps/mobile && dart run ../../tools/checks/flesch_kincaid_fr.dart lib/l10n/app_fr.arb --keys-prefix=intentScreen,intentChip,landingV2 --min=50 --min-words=8"

run_gate 10 "no_chiffre_choc grep" "Phase 1.5" \
  "python3 tools/checks/no_chiffre_choc.py"

run_gate 11 "no_legacy_confidence_render" "Phase 8a" \
  "python3 tools/checks/no_legacy_confidence_render.py"

run_gate 12 "no_llm_alert" "Phase 9" \
  "python3 tools/checks/no_llm_alert.py"

run_gate 13 "sentence_subject ARB lint + no user-facing curseur" "Phase 8a + 11 + 12-01" \
  "python3 tools/checks/sentence_subject_arb_lint.py && bash tools/ci/grep_no_user_facing_curseur.sh"

run_gate 14 "Landing v2 — no numbers + no financial_core" "Phase 7" \
  "python3 tools/checks/landing_no_numbers.py && python3 tools/checks/landing_no_financial_core.py"

run_gate 15 "S0–S5 AAA-only token gate" "Phase 8b" \
  "python3 tools/checks/s0_s5_aaa_only.py"

run_gate 16 "no_implicit_bloom_strategy" "Plan 12-03" \
  "python3 tools/checks/no_implicit_bloom_strategy.py"

run_gate 17 "REGIONAL_MAP / _REGIONAL_IDENTITY grep" "Phase 6 cleanup" \
  "if git grep -nE '^[[:space:]]*REGIONAL_MAP[[:space:]]*=' services/backend/app/; then exit 1; fi; if git grep -nE '^[[:space:]]*_REGIONAL_IDENTITY[[:space:]]*=' services/backend/app/; then exit 1; fi; exit 0"

run_gate 18 "Banned-terms grep (garanti/optimal/meilleur)" "always" \
  "if git grep -nE '\\b(garanti|optimal|meilleur)' apps/mobile/lib/ services/backend/app/ -- ':!*.g.dart' ':!*test*' ':!*l10n*' ':!*.arb'; then exit 1; fi; exit 0"

# ─── Summary ──────────────────────────────────────────────────────────────

echo
echo "============================================================"
echo "MINT v2.2 Ship Gate Summary"
echo "============================================================"
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
if [[ $FAILED -gt 0 ]]; then
  echo
  echo "FAILED gates:"
  for f in "${FAILED_NAMES[@]}"; do
    echo "  - $f"
  done
  echo
  echo "Verdict: SHIP BLOCKED"
  echo "Matrix:  $SHIP_GATE_OUT"
  exit 1
fi

echo
echo "Verdict: SHIP READY (code side)"
echo "Matrix:  $SHIP_GATE_OUT"
exit 0
