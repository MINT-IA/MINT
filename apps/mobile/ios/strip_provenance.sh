#!/bin/bash
# Fix macOS Sequoia/Tahoe com.apple.provenance issue with Flutter codesign.
#
# Phase 86 v2.12 audit B (2026-05-05): the simple `xattr -cr` strip is
# insufficient on macOS Sequoia/Tahoe — `com.apple.provenance` is a
# system-restricted xattr that survives `xattr -cr / xattr -d / cp /
# ditto / tar / Python rewrite`. codesign refuses to "replace existing
# signature" when the file carries this xattr, surfacing the
# « resource fork, Finder information, or similar detritus not allowed »
# error.
#
# Workaround: pre-remove the existing signature so the subsequent
# codesign attempt is « adding » rather than « replacing ». The
# « replacing existing signature » path is what surfaces the detritus
# check ; the « adding » path tolerates the xattr.
#
# Steps :
# 1. Strip xattrs from all .framework bundles (best-effort, no-op for
#    com.apple.provenance but cleans any other latent metadata).
# 2. Pre-remove existing signature on each framework so codesign
#    doesn't take the « replacing » path.
find "${BUILT_PRODUCTS_DIR}" -name "*.framework" -print0 2>/dev/null | \
  while IFS= read -r -d '' fwk; do
    /usr/bin/xattr -cr "$fwk" 2>/dev/null || true
    /usr/bin/codesign --remove-signature "$fwk" 2>/dev/null || true
  done
