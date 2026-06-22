#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/apps/mobile"

flutter test test/screens/admin/admin_shell_gate_test.dart
flutter test --dart-define=ENABLE_ADMIN=1 \
  test/screens/admin/admin_shell_gate_test.dart
flutter test --dart-define=ENABLE_ADMIN=1 \
  --dart-define=ENABLE_DEBUG_TOOLS=1 \
  test/screens/admin/admin_shell_gate_test.dart
flutter test --dart-define=ENABLE_ADMIN=true \
  --dart-define=ENABLE_DEBUG_TOOLS=true \
  test/screens/admin/admin_shell_gate_test.dart
