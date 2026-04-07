#!/usr/bin/env bash
# Regenerate VoiceCursorContract consumers from tools/contracts/voice_cursor.json.
# Usage: bash tools/contracts/regenerate.sh
# CI: see .github/workflows/ci.yml job `contracts-drift`.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

cd "$ROOT"

python3 tools/contracts/generate_dart.py
python3 tools/contracts/generate_python.py

echo "OK"
