#!/usr/bin/env bash
# Wave 1a — 5-gate close-out (G3 + G4 + G5).
#
# G1 + G2 are SEPARATE and not exercised by this script:
#   G1 = Maestro flow run on staging build
#        (tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml)
#   G2 = Julien device walkthrough on staging build
#
# This script handles only the deterministic, in-CI gates:
#   G3 = dev CI (full backend pytest, baseline ≥ 6617 per plan-08 PLAN.md)
#   G4 = regression (parity harness alone — fast sub-set re-run)
#   G5 = LSFin banned-terms lint + accent_lint_fr on every Wave-1a-touched file
#
# Exit code: 0 iff every gate passes; non-zero on the first failure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

# Wave 1a touched-file set — kept in sync with the 7 prior plans' SUMMARY.md
# `key-files.modified` blocks (plans 01-06) + plan-00 scaffolding.
WAVE_1A_BACKEND_FILES=(
  services/backend/app/services/coaching_engine.py
  services/backend/app/services/retirement/retirement_projection_service.py
  services/backend/app/services/arbitrage/cross_pillar_service.py
  services/backend/app/services/couple_optimizer/couple_optimizer.py
  services/backend/app/services/memory/bm25.py
  services/backend/app/api/v1/endpoints/coach_chat.py
  services/backend/app/core/config.py
  services/backend/app/observability/coach_breadcrumbs.py
  services/backend/app/utils/hashing.py
)
# coach_tools models package — one file per plan + the package marker.
WAVE_1A_BACKEND_FILES+=( $(ls services/backend/app/models/coach_tools/*.py) )

echo "==> G3 + G4 — backend pytest (full suite, baseline ≥ 6617)"
(
  cd services/backend
  python3 -m pytest tests/ -q
)

echo "==> G4 — parity harness alone (fast re-run)"
(
  cd services/backend
  python3 -m pytest tests/test_coach_tools_parity.py -q
)

echo "==> G5 — banned_terms_python lint on Wave 1a touched files"
python3 tools/checks/banned_terms_python.py "${WAVE_1A_BACKEND_FILES[@]}"

echo "==> G5 — accent_lint_fr on Wave 1a touched files"
for f in "${WAVE_1A_BACKEND_FILES[@]}"; do
  python3 tools/checks/accent_lint_fr.py --file "$f"
done

echo "==> wave_1a_close.sh: ALL GATES GREEN (G3+G4+G5)"
