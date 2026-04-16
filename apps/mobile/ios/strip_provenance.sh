#!/bin/bash
# Fix macOS Sequoia com.apple.provenance issue with Flutter codesign
# This attribute cannot be removed with xattr -d, but codesign --force
# handles it if we strip the resource fork first.
find "${BUILT_PRODUCTS_DIR}" -name "*.framework" -exec /usr/bin/xattr -cr {} \; 2>/dev/null || true
