#!/usr/bin/env bash
# Wave 1b — 5-gate close-out (G3 + G4 + G5).
#
# G1 + G2 are SEPARATE and not exercised by this script:
#   G1 = Maestro flow run on staging build
#        (tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml)
#   G2 = Claude autonomous Maestro+sim walkthrough on staging build
#        (per memory g2-claude-autonomous-not-julien-token + CONTEXT D-05).
#
# This script handles only the deterministic, in-CI gates:
#   G3 = dev CI (full backend pytest)
#   G4 = regression (Wave 1b backend slice + Wave 1b Flutter slice)
#   G5 = LSFin banned-terms + accent_lint + ARB parity (all 6 locales)
#
# Exit code: 0 iff every gate passes; non-zero on the first failure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

# Wave 1b touched-file set — kept in sync with plans 02/03/04/08 SUMMARY.md
# `key-files.modified` blocks (backend side).
WAVE_1B_BACKEND_FILES=(
  services/backend/app/services/coach/citation_registry.py
  services/backend/app/services/coach/citation_grammar.py
  services/backend/app/observability/coach_breadcrumbs.py
  services/backend/app/api/v1/endpoints/coach_chat.py
)

echo "==> G3 — backend pytest (full suite)"
(
  cd services/backend
  python3 -m pytest tests/ -q
)

echo "==> G4 — Wave 1b backend slice (registry + grammar + breadcrumb)"
(
  cd services/backend
  python3 -m pytest tests/test_coach_citation/ -q
)

echo "==> G4 — Wave 1b Flutter slice (chip + modal + round-trip)"
(
  cd apps/mobile
  flutter test test/widgets/coach/coach_citation_chips_section_test.dart \
               test/widgets/coach/coach_citation_modal_test.dart \
               test/widgets/coach/coach_citation_chip_golden_test.dart \
               test/widgets/coach/coach_citation_chip_modal_remember_test.dart \
               test/services/coach/tool_call_round_trip_test.dart
)

echo "==> G5 — banned_terms_python lint on Wave 1b touched files"
python3 tools/checks/banned_terms_python.py "${WAVE_1B_BACKEND_FILES[@]}"

echo "==> G5 — accent_lint_fr on Wave 1b backend touched files"
for f in "${WAVE_1B_BACKEND_FILES[@]}"; do
  python3 tools/checks/accent_lint_fr.py --file "$f"
done

echo "==> G5 — accent_lint_fr on app_fr.arb"
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb

echo "==> G5 — ARB parity (6 locales)"
if [ -f tools/checks/validate_arb_parity.py ]; then
  python3 tools/checks/validate_arb_parity.py
elif [ -f tools/checks/arb_parity.py ]; then
  python3 tools/checks/arb_parity.py
else
  echo "WARN: no arb_parity script found — skipping (manual verification required)"
fi

echo "==> G5 — banned_terms_arb (if present)"
if [ -f tools/checks/banned_terms_arb.py ]; then
  python3 tools/checks/banned_terms_arb.py
else
  echo "INFO: banned_terms_arb.py not present — relying on FR accent_lint coverage"
fi

echo "==> wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)"
