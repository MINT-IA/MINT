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
# S98 Phase 3 — Maestro is wrapped in a stall-detector watchdog. The
# wrapper teelog stdout, probes log mtime every MAESTRO_STALL_PROBE_INTERVAL
# seconds, and SIGTERMs the run on stall (default: 90s silence) or
# hard limit (default: 15 min). Exit 124 = stall, 137 = hard limit.
# Last session lost 30 min to a silent Maestro hang (bo1o442ww) ; the
# wrapper recovers that time and dumps `/debug/state` + OSLog as
# artifacts on stall.
MAESTRO_WATCHDOG="$REPO_ROOT/tools/simulator/maestro_with_watchdog.sh"
if [ ! -x "$MAESTRO_WATCHDOG" ]; then
  echo "ERROR: Maestro watchdog wrapper not found at $MAESTRO_WATCHDOG" >&2; exit 1
fi

echo "[L1] maestro test $FLOW --device booted (watchdog-wrapped)"
"$MAESTRO_WATCHDOG" test "$FLOW" --device booted
rc=$?
if [ "$rc" -ne 0 ]; then
  case "$rc" in
    124) echo "ERROR: L1 Maestro STALLED — artifacts in \$MINT_WALKER_ARTIFACTS." >&2 ;;
    137) echo "ERROR: L1 Maestro exceeded hard limit." >&2 ;;
    *)   echo "ERROR: L1 Maestro flow failed ($rc). See ~/.maestro/tests/ for trace." >&2 ;;
  esac
  exit 3
fi

# ── L2 Dart assertions — post-run validation ────────────────────────
ASSERT_FILE="$REPO_ROOT/apps/mobile/test/personas/${PERSONA}_test.dart"
if [ ! -f "$ASSERT_FILE" ]; then
  echo "WARN: no Dart assertion suite at $ASSERT_FILE — skipping L2"
else
  echo "[L2] flutter test $ASSERT_FILE (MINT_WALKER_RUN_ID=$RUN_ID)"
  (cd "$REPO_ROOT/apps/mobile" && \
    MINT_WALKER_RUN_ID="$RUN_ID" \
    flutter test "$ASSERT_FILE") || {
      echo "ERROR: L2 Dart assertions failed" >&2; exit 4
    }
fi

echo
echo "[OK] walker_persona — all 3 layers green for $PERSONA × $LOCALE (run $RUN_ID)"
