#!/usr/bin/env bash
set -euo pipefail

# Temporary compatibility patch:
# google_fonts <= 6.3.1 declares a const map keyed by FontWeight.
# On some Flutter/Dart engine combinations this triggers a const-eval error.
# We patch the cached package to use `final` instead of `const`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$MOBILE_DIR/pubspec.lock"
PUB_CACHE_ROOT="${PUB_CACHE:-$HOME/.pub-cache}"
SEARCH_ROOT="$PUB_CACHE_ROOT/hosted/pub.dev"

if [[ ! -d "$SEARCH_ROOT" ]]; then
  echo "google_fonts patch: pub cache not found at $SEARCH_ROOT (skip)"
  exit 0
fi

variant_files=()
google_fonts_version=""

if [[ -f "$LOCK_FILE" ]]; then
  google_fonts_version="$(
    awk '
      $1=="google_fonts:" { in_pkg=1; next }
      in_pkg && $1=="version:" { gsub(/"/, "", $2); print $2; exit }
      in_pkg && /^[^[:space:]]/ { in_pkg=0 }
    ' "$LOCK_FILE"
  )"
fi

if [[ -n "$google_fonts_version" ]]; then
  candidate="$SEARCH_ROOT/google_fonts-$google_fonts_version/lib/src/google_fonts_variant.dart"
  if [[ -f "$candidate" ]]; then
    variant_files+=("$candidate")
  fi
fi

if [[ ${#variant_files[@]} -eq 0 ]]; then
  while IFS= read -r file; do
    variant_files+=("$file")
  done < <(find "$SEARCH_ROOT" -type f -path "*/google_fonts-*/lib/src/google_fonts_variant.dart")
fi

if [[ ${#variant_files[@]} -eq 0 ]]; then
  echo "google_fonts patch: no google_fonts_variant.dart found (skip)"
  exit 0
fi

patched_count=0
for file in "${variant_files[@]}"; do
  if ! grep -qE 'const (Map<FontWeight, String> )?_fontWeightToFilenameWeightParts =' "$file"; then
    echo "google_fonts patch: already compatible $file"
    continue
  fi

  perl -0pi -e 's/const Map<FontWeight, String> _fontWeightToFilenameWeightParts =/final Map<FontWeight, String> _fontWeightToFilenameWeightParts =/g' "$file"
  perl -0pi -e 's/const _fontWeightToFilenameWeightParts =/final _fontWeightToFilenameWeightParts =/g' "$file"

  if grep -qE 'final (Map<FontWeight, String> )?_fontWeightToFilenameWeightParts =' "$file"; then
    patched_count=$((patched_count + 1))
    echo "google_fonts patch: updated $file"
  fi
done

echo "google_fonts patch: done ($patched_count file(s))"
