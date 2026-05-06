#!/usr/bin/env bash
# tools/simulator/walker_persona.sh
#
# Phase 90 PERS-02 (v2.13) — persona-narrative walker orchestrator.
#
# Panel-locked architecture (`.planning/decisions/2026-05-05-persona-
# narrative-scenario-coverage-panel.md`) :
#   L0  walker.sh (existing)            → build, sim boot, install, launch,
#                                          dart-defines (archetype, locale,
#                                          forced eclairage kind, beta-
#                                          modal disable), Sentry pull,
#                                          artifact bundle.
#   L1  Maestro YAML flow                → in-app tap choreography via
#                                          semantic locators. Driven via
#                                          `tools/simulator/maestro_env.sh`.
#   L2  Dart post-run assertion suite    → `apps/mobile/test/personas/
#                                          <persona>_test.dart`. Reads
#                                          walker artefacts, runs LSFin
#                                          regex + financial_core numeric
#                                          + archetype + narrative
#                                          invariant assertions.
#
# This script is the SEAM. It is intentionally small (~120 lines) and
# delegates to the three layer-owning tools instead of re-implementing
# their concerns.
#
# Usage :
#   bash tools/simulator/walker_persona.sh \
#     --persona julien_swiss \
#     --flow tools/simulator/flows/julien_swiss.yaml \
#     --locale fr
#
# Pre-requisites :
#   - walker.sh + walker_premier_eclairage.sh present (Phase 86 chain
#     merged — until then, Phase 90 deferred mode logs and exits 0).
#   - Maestro CLI installed via `tools/simulator/maestro_env.sh`.
#   - Sim booted (run `walker.sh` once first OR pass `--boot-sim`).
#
# Status : Phase 90 scaffolding. Real wiring lands when PR #500
# (walker_premier_eclairage.sh + WALKC-08 codesign bypass + APP_LOCALE)
# merges to dev and this branch rebases.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PERSONA=""
FLOW=""
LOCALE="fr"
RUN_ID=""
DRY_RUN=0

usage() {
  cat <<EOF
walker_persona.sh — Phase 90 PERS-02 persona-narrative orchestrator (v2.13).

Required :
  --persona <slug>     archetype slug (julien_swiss, lauren_expat_us, ...)
  --flow <path>        Maestro YAML flow path (e.g. tools/simulator/flows/<slug>.yaml)

Optional :
  --locale <fr|de|en>  cold-start locale via APP_LOCALE dart-define (default fr)
  --run-id <id>        override generated YYYY-MM-DD-HHMMSS-<sha7>
  --dry-run            print the orchestration plan, don't execute
  --help               this text

Exit codes :
  0   all 3 layers green
  1   usage error
  2   L0 walker build/launch failed
  3   L1 Maestro flow failed (see ~/.maestro/tests/<runId>/ for trace)
  4   L2 Dart assertion suite failed
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --persona) PERSONA="$2"; shift 2 ;;
    --flow) FLOW="$2"; shift 2 ;;
    --locale) LOCALE="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -z "$PERSONA" ]; then
  echo "ERROR: --persona required" >&2; exit 1
fi
if [ -z "$FLOW" ] || [ ! -f "$FLOW" ]; then
  echo "ERROR: --flow path missing or not a file: $FLOW" >&2; exit 1
fi

if [ -z "$RUN_ID" ]; then
  RUN_ID="$(date '+%Y-%m-%d-%H%M%S')-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo dev0000)"
fi

echo "walker_persona orchestration plan"
echo "  persona  : $PERSONA"
echo "  flow     : $FLOW"
echo "  locale   : $LOCALE"
echo "  run-id   : $RUN_ID"
echo

if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY-RUN] would execute :"
  echo "  L0 → walker_premier_eclairage.sh --archetype $PERSONA --no-dry-run --locale $LOCALE --run-id $RUN_ID"
  echo "  L1 → maestro_env.sh test $FLOW --device booted"
  echo "  L2 → flutter test apps/mobile/test/personas/${PERSONA}_test.dart"
  echo "       (env MINT_WALKER_RUN_ID=$RUN_ID)"
  echo "  bundle → .planning/walker/$RUN_ID/persona-bundle.json (PR #500 chain)"
  exit 0
fi

# ── L0 walker — build + sim boot + install + launch + Sentry ────────
WALKER_SCRIPT="$REPO_ROOT/tools/simulator/walker_premier_eclairage.sh"
if [ ! -x "$WALKER_SCRIPT" ]; then
  echo "[Phase 90 deferred] $WALKER_SCRIPT not present on this branch."
  echo "  walker_persona.sh requires the Phase 86 walker_premier_eclairage.sh"
  echo "  chain (PR #500). Phase 90 scaffolding ships the orchestrator + L1 + L2"
  echo "  contracts ; full L0 integration lands on rebase post-PR-#500 merge."
  echo "  Returning exit 0 (scaffolding mode). Re-run after rebase."
  exit 0
fi

echo "[L0] walker_premier_eclairage.sh build + launch"
"$WALKER_SCRIPT" \
  --archetype "$PERSONA" \
  --no-dry-run \
  --locale "$LOCALE" \
  --run-id "$RUN_ID" || {
    echo "ERROR: L0 walker exited non-zero" >&2
    exit 2
  }

# ── L1 Maestro flow — in-app choreography ───────────────────────────
MAESTRO_ENV="$REPO_ROOT/tools/simulator/maestro_env.sh"
if [ ! -x "$MAESTRO_ENV" ]; then
  echo "ERROR: Maestro env wrapper not found at $MAESTRO_ENV" >&2; exit 1
fi

# Phase A5 (v2.13) — Maestro 0.15.x on macOS Tahoe : `--device booted`
# fails with « Device booted was requested, but it is not connected »
# even when xcrun simctl + idb both see the booted iPhone 17 Pro and the
# idb_companion socket is alive. Auto-detection (no --device flag) picks
# the booted simulator correctly. Maestro then prints
# « Running on iPhone 17 Pro - iOS 26.2 - <udid> » and proceeds with the
# flow.
echo "[L1] maestro test $FLOW (auto-detect booted device)"
"$MAESTRO_ENV" test "$FLOW" || {
  echo "ERROR: L1 Maestro flow failed. See ~/.maestro/tests/ for trace." >&2
  exit 3
}

# ── L2 Dart assertions — post-run validation ────────────────────────
ASSERT_FILE="$REPO_ROOT/apps/mobile/test/personas/${PERSONA}_test.dart"
if [ ! -f "$ASSERT_FILE" ]; then
  echo "WARN: no Dart assertion suite at $ASSERT_FILE — skipping L2"
else
  echo "[L2] flutter test $ASSERT_FILE (MINT_WALKER_RUN_ID=$RUN_ID, REQUIRED=true)"
  # Phase A5 panel hardening (iOS QA finding 2026-05-06) — set
  # MINT_WALKER_REQUIRED=true so the L2 suite FAILS loudly if RUN_ID
  # is missing. Without this flag, the test would skip silently and
  # walker_persona's exit-0 would falsely report « L2 green » even
  # when none of the assertions actually ran.
  (cd "$REPO_ROOT/apps/mobile" && \
    MINT_WALKER_RUN_ID="$RUN_ID" \
    MINT_WALKER_REQUIRED=true \
    flutter test "$ASSERT_FILE") || {
      echo "ERROR: L2 Dart assertions failed" >&2; exit 4
    }
fi

echo
echo "[OK] walker_persona — all 3 layers green for $PERSONA × $LOCALE (run $RUN_ID)"
