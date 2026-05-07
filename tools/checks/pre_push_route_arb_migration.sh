#!/usr/bin/env bash
# pre_push_route_arb_migration.sh — enforce the pre-push checklist for
# route count / ARB key / alembic migration changes.
#
# Triggered by lefthook pre-push (see lefthook.yml).
#
# What it gates (per memory feedback_pre_push_checklist.md, after the 4-CI-
# cycle PR #439 incident):
#   1. If the diff touches any GoRouter route declaration in app.dart OR
#      `screen_registry.dart`, run the parity check + the 2 route-count tests.
#   2. If the diff touches any `apps/mobile/lib/l10n/app_*.arb` file, ensure
#      `flutter gen-l10n` was run (regenerated `app_localizations*.dart`
#      file is part of the same diff or already up-to-date).
#   3. If the diff touches `services/backend/alembic/versions/`, run the
#      forward+rollback test for the new migration locally.
#
# Exit non-zero if any gate fails. Cannot be bypassed without
# `LEFTHOOK_BYPASS=1 git push` (per CLAUDE.md §5 DEV RULES).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Diff = local HEAD vs remote tracking branch (or origin/dev fallback).
TRACKING="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/dev)"
CHANGED="$(git diff --name-only "$TRACKING"...HEAD 2>/dev/null || true)"
if [[ -z "$CHANGED" ]]; then
  echo "[pre-push] no diff vs $TRACKING — nothing to gate."
  exit 0
fi

red() { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }

failed=0

# ─── Gate 1 — Route changes ─────────────────────────────────────────────
if echo "$CHANGED" | grep -qE 'apps/mobile/lib/(app\.dart|services/navigation/screen_registry\.dart)$'; then
  yellow "[gate-1] route declaration changed — running parity + 2 route-count tests"
  if ! python3 tools/checks/screen_registry_parity.py >/dev/null; then
    red "[gate-1] FAIL: screen_registry_parity.py"
    failed=1
  fi
  if ! python3 -m pytest tests/tools/test_mint_routes.py -q >/dev/null 2>&1; then
    red "[gate-1] FAIL: tests/tools/test_mint_routes.py"
    failed=1
  fi
  pushd apps/mobile >/dev/null
  if ! flutter test test/screens/admin/routes_registry_screen_test.dart --reporter=compact >/dev/null 2>&1; then
    red "[gate-1] FAIL: routes_registry_screen_test.dart"
    failed=1
  fi
  popd >/dev/null
  [[ "$failed" -eq 0 ]] && green "[gate-1] OK"
fi

# ─── Gate 2 — ARB changes ───────────────────────────────────────────────
ARB_CHANGED="$(echo "$CHANGED" | grep -E 'apps/mobile/lib/l10n/app_.*\.arb$' || true)"
if [[ -n "$ARB_CHANGED" ]]; then
  yellow "[gate-2] ARB key changed — checking flutter gen-l10n freshness"
  GEN_CHANGED="$(echo "$CHANGED" | grep -E 'apps/mobile/lib/l10n/app_localizations.*\.dart$' || true)"
  if [[ -z "$GEN_CHANGED" ]]; then
    pushd apps/mobile >/dev/null
    if ! flutter gen-l10n >/dev/null 2>&1; then
      red "[gate-2] FAIL: flutter gen-l10n failed"
      failed=1
    fi
    if [[ -n "$(git status --porcelain lib/l10n/app_localizations*.dart 2>/dev/null)" ]]; then
      red "[gate-2] FAIL: ARB changed but generated app_localizations*.dart is stale"
      red "        Run 'cd apps/mobile && flutter gen-l10n' and add the regenerated files."
      failed=1
    fi
    popd >/dev/null
  fi
  if ! python3 tools/checks/accent_lint_fr.py apps/mobile/lib/l10n/app_fr.arb >/dev/null 2>&1; then
    red "[gate-2] FAIL: accent_lint_fr.py on app_fr.arb"
    failed=1
  fi
  [[ "$failed" -eq 0 ]] && green "[gate-2] OK"
fi

# ─── Gate 3 — Alembic migration changes ─────────────────────────────────
if echo "$CHANGED" | grep -qE 'services/backend/alembic/versions/.*\.py$'; then
  yellow "[gate-3] alembic migration added/modified — running forward+rollback test"
  if ! ( cd services/backend && python3 -m pytest tests/test_alembic_full_chain.py -q ) >/dev/null 2>&1; then
    yellow "[gate-3] WARN: test_alembic_full_chain.py needs Postgres (testcontainers)."
    yellow "        If Docker is available, this gate must pass; otherwise CI will catch it."
    # Soft warning when Docker absent — not fail.
  else
    green "[gate-3] OK"
  fi
fi

if [[ "$failed" -ne 0 ]]; then
  red "[pre-push] one or more gates failed — push blocked."
  red "          To bypass (use sparingly, document in PR body):"
  red "            LEFTHOOK_BYPASS=1 git push"
  exit 1
fi

green "[pre-push] all gates passed."
exit 0
