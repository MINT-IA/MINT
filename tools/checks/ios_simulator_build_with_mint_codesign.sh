#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
codesign_dir="$ROOT/apps/mobile/ios/mint_xcode_tools"
codesign_wrapper="$codesign_dir/codesign"

if [[ ! -x "$codesign_wrapper" ]]; then
  echo "ERROR: missing executable MINT iOS codesign wrapper: $codesign_wrapper" >&2
  exit 1
fi

export PATH="$codesign_dir:$PATH"

cd "$ROOT/apps/mobile"
flutter build ios --simulator "$@"
