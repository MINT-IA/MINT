#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/apps/mobile"

export PATH="$PATH:$HOME/.pub-cache/bin"

if ! dart pub global list | grep -q '^patrol_cli '; then
  cat >&2 <<'EOF'
patrol_cli is required for Mint runtime debug tooling.
Install it with:
  flutter pub global activate patrol_cli
EOF
  exit 1
fi

if ! command -v patrol >/dev/null 2>&1; then
  cat >&2 <<'EOF'
patrol executable is required but was not found on PATH.
Ensure Pub global executables are visible:
  export PATH="$PATH:$HOME/.pub-cache/bin"
EOF
  exit 1
fi

PATROL_ANALYTICS_ENABLED=false patrol test \
  -d "MINT iPhone 13 mini RvC" \
  -t test/patrol/mint_runtime_debug_gate_test.dart \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true \
  --dart-define=MINT_E2E_PROOF_ANCHORS=true \
  --dart-define=ENABLE_ADMIN=1 \
  --dart-define=ENABLE_DEBUG_TOOLS=1
