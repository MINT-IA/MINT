#!/usr/bin/env bash
# Phase 12-01 — CI gate: forbid the word "curseur" in user-facing ARB strings.
#
# The Ton chooser uses "Ton" as the user-facing label. Internal contracts and
# code may continue to reference VoiceCursor*/voiceCursorPreference (developer
# vocabulary), but no rendered string in the 6 ARB files is allowed to contain
# the word "curseur" or "Curseur".
#
# Allowed: lines starting with "@" (metadata/description). Forbidden: any
# value-bearing entry.
set -e

ARB_DIR="apps/mobile/lib/l10n"
PATTERN='\bcurseur\b|\bCurseur\b'

# Collect any matches OUTSIDE @meta lines.
violations=$(grep -nE "$PATTERN" "$ARB_DIR"/app_*.arb 2>/dev/null | grep -v ':\s*"@' || true)

if [ -n "$violations" ]; then
  echo "FAIL: 'curseur' found in user-facing ARB strings (allowed only in @meta keys)"
  echo "$violations"
  exit 1
fi

echo "OK: no user-facing 'curseur' in ARB files"
