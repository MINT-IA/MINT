#!/usr/bin/env bash
# Phase 32 MAP-04 — lefthook pre-commit wrapper for route registry parity lint.
#
# SCOPE: This Phase 32 plan (32-04) ships the wrapper STANDALONE.
# Phase 34 (GUARD-01) wires it into lefthook.yml with:
#
#     pre-commit:
#       parallel: true
#       commands:
#         route-registry-parity:
#           run: .lefthook/route_registry_parity.sh
#           tags: [routes, phase-32]
#
# Contract (audited by tests/checks/test_route_registry_parity.py):
#   - exits 0 when route_registry_parity.py exits 0 (parity OK).
#   - propagates non-zero exit code on drift or argument error.
#   - stdout + stderr from the lint reach the terminal unchanged.
#   - fails fast with exit 2 if python3 is not on PATH.

set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf '[FAIL] python3 not found on PATH — lefthook cannot run route_registry_parity\n' >&2
  exit 2
fi

# Run from the repo root so relative paths inside the lint resolve identically
# whether invoked by lefthook, CI, or manually.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

exec python3 tools/checks/route_registry_parity.py "$@"
