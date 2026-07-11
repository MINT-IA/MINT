#!/bin/sh
set -e

# Strip resource forks / Finder metadata before Flutter's embed_and_thin
# codesigns generated app/framework bundles. FileProvider-backed worktrees on
# macOS can attach provenance xattrs that make ad-hoc codesign fail.
case "${SDK_NAME:-}" in
  iphoneos*|iphonesimulator*) ;;
  *) exit 0 ;;
esac

strip_bundle() {
  path="$1"
  [ -n "$path" ] || return 0
  [ -d "$path" ] || return 0

  base_name="$(basename "$path")"
  case "$base_name" in
    *.app|*.framework|*.xctest) ;;
    *) exit 1 ;;
  esac

  parent_dir="$(cd "$(dirname "$path")" && pwd -P)"
  resolved_path="$parent_dir/$base_name"
  tmp_path="$parent_dir/.${base_name}.norsrc.$$"
  backup_path="$parent_dir/.${base_name}.pre-xattr-strip.$$"

  /usr/bin/xattr -dr com.apple.provenance "$resolved_path" 2>/dev/null || true
  /usr/bin/xattr -dr com.apple.FinderInfo "$resolved_path" 2>/dev/null || true
  /usr/bin/xattr -dr com.apple.ResourceFork "$resolved_path" 2>/dev/null || true
  /usr/bin/xattr -cr "$resolved_path" 2>/dev/null || true

  rm -rf "$tmp_path" "$backup_path"
  /usr/bin/ditto --norsrc "$resolved_path" "$tmp_path"
  test -d "$tmp_path"
  mv "$resolved_path" "$backup_path"
  if mv "$tmp_path" "$resolved_path"; then
    rm -rf "$backup_path"
  else
    rm -rf "$resolved_path"
    mv "$backup_path" "$resolved_path"
    rm -rf "$tmp_path"
    exit 1
  fi
}

seen_paths=""
for path in \
  "${BUILT_PRODUCTS_DIR:-}/Flutter.framework" \
  "${BUILT_PRODUCTS_DIR:-}/App.framework" \
  "${CODESIGNING_FOLDER_PATH:-}" \
  "${BUILT_PRODUCTS_DIR:-}/${WRAPPER_NAME:-}" \
  "${TARGET_BUILD_DIR:-}/${WRAPPER_NAME:-}" \
  "${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}/Flutter.framework" \
  "${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}/App.framework"; do
  [ -n "$path" ] || continue
  [ -d "$path" ] || continue
  parent_dir="$(cd "$(dirname "$path")" && pwd -P)"
  resolved_path="$parent_dir/$(basename "$path")"
  case " $seen_paths " in
    *" $resolved_path "*) continue ;;
  esac
  seen_paths="$seen_paths $resolved_path"
  strip_bundle "$resolved_path"
done
