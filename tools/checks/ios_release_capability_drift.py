#!/usr/bin/env python3
"""LINT-IOS-RELEASE-01 — ios_release_capability_drift.

Block commits/PRs that add a NEW iOS capability key to
`apps/mobile/ios/Runner/Runner.entitlements` without an explicit
`[ios-release]` tag in the commit message (or PR title via CI).

Why this lint exists
====================
Incident 2026-05-11 (W7 iter#6 commit 009149c7) added
`com.apple.developer.associated-domains` to Runner.entitlements as part
of an 18-cycle PR stack. The App Store provisioning profile in the
`mint-certificates` repo (managed by fastlane match) does NOT include
the Associated Domains capability because it was not enabled on App ID
`ch.mint.app` at Apple Developer portal. Result: TestFlight build failed
at the `xcodebuild archive` step with :

    Provisioning profile "match AppStore ch.mint.app" doesn't include
    the com.apple.developer.associated-domains entitlement.
    ** ARCHIVE FAILED **

Cost : 1 emergency revert PR + 1 dev→staging follow-up PR + Julien
frustration. Local gates (pytest, flutter analyze, flutter test, Maestro
sim, dart-define walker) all passed because none of them invoke
`xcodebuild archive`. The first failure signal came from testflight.yml
on staging push, by which point the change was already merged twice.

How this lint protects
======================
The set of iOS capabilities currently provisioned on App ID `ch.mint.app`
is enumerated below as `_PROVISIONED_CAPABILITIES`. The lint scans the
checked-in `Runner.entitlements` plist for `com.apple.developer.*` keys
and fails if any key appears that is NOT in the allowlist.

Adding a new capability requires three coordinated steps :
  1. Apple Developer portal — enable the capability on App ID
     `ch.mint.app`.
  2. `fastlane match appstore` — regenerate the App Store provisioning
     profile with the new capability + push to `mint-certificates`.
  3. Update `_PROVISIONED_CAPABILITIES` in this file AND add the key to
     `Runner.entitlements`, in the same PR, with `[ios-release]` in the
     commit message (and/or PR title).

The `[ios-release]` tag is the explicit ack that step 2 has been
completed. Without it the lint fails loudly with a remediation guide.

Behaviour
=========
- Scope : `apps/mobile/ios/Runner/Runner.entitlements`.
- Modes :
    * Default — scan the checked-in entitlements file vs the allowlist.
    * `--commit-msg <path>` — additionally check that the candidate
      commit message contains `[ios-release]` when a new capability key
      is detected. Used by the lefthook `commit-msg` hook.
- Bypass via `LEFTHOOK_BYPASS=1 git commit` (grep-able per CLAUDE.md §5).

Exit codes
==========
0 — clean (all keys in allowlist) OR `[ios-release]` tag present in
    commit message AND --commit-msg mode.
1 — net-new capability without `[ios-release]` ack.

Memory link
===========
`feedback_ios_entitlements_block_testflight.md` (2026-05-12).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LINT_NAME = "ios_release_capability_drift"
REPO = Path(__file__).resolve().parents[2]
ENTITLEMENTS_PATH = (
    REPO / "apps" / "mobile" / "ios" / "Runner" / "Runner.entitlements"
)

# ── Allowlist : capabilities currently provisioned on App ID ch.mint.app ──
# Maintained 2026-05-12. Each entry corresponds to a capability enabled in
# Apple Developer portal AND covered by the App Store provisioning profile
# stored in the `mint-certificates` repo (managed by fastlane match).
#
# Adding a new entry here REQUIRES first :
#   1. Apple Developer portal : enable the capability on App ID ch.mint.app.
#   2. Run `fastlane match appstore` to regenerate + push the profile.
#   3. Verify TestFlight build succeeds end-to-end before merging this lint
#      update.
#
# Removing an entry requires confirming no production builds depend on it
# (the entitlement is dropped from Runner.entitlements in the same PR).
_PROVISIONED_CAPABILITIES: set[str] = {
    # Memory limits — granted automatically to apps with large in-memory
    # data (financial calc cache, SLM token windows).
    "com.apple.developer.kernel.increased-memory-limit",
    "com.apple.developer.kernel.extended-virtual-addressing",
    # Apple Sign-In — added in commit f4955541 (phase-01-05).
    "com.apple.developer.applesignin",
}

# Regex captures `<key>com.apple.developer.<name></key>` blocks. The key
# name is what we compare against the allowlist. We deliberately exclude
# non-capability keys like `keychain-access-groups` (those don't require
# provisioning portal updates) by anchoring on the `com.apple.developer.`
# prefix.
_CAPABILITY_KEY_RE = re.compile(
    r"<key>(com\.apple\.developer\.[a-zA-Z0-9._-]+)</key>"
)


def _extract_capabilities(entitlements_text: str) -> set[str]:
    """Return the set of `com.apple.developer.*` keys declared in the plist."""
    return set(_CAPABILITY_KEY_RE.findall(entitlements_text))


def _commit_msg_has_release_tag(commit_msg_path: Path) -> bool:
    """Check whether the candidate commit message contains `[ios-release]`."""
    try:
        text = commit_msg_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    return "[ios-release]" in text.lower()


def _build_remediation_guide(unknown_keys: set[str]) -> str:
    """Format the human-readable error message printed on failure."""
    keys_list = "\n".join(f"      {k}" for k in sorted(unknown_keys))
    return (
        f"::error::{LINT_NAME}: {len(unknown_keys)} unprovisioned "
        f"capability key(s) in Runner.entitlements:\n"
        f"{keys_list}\n\n"
        f"  This commit adds an iOS capability that is NOT covered by the\n"
        f"  current App Store provisioning profile in the mint-certificates\n"
        f"  repo. Pushing it to staging WILL break `testflight.yml` at the\n"
        f"  xcodebuild archive step :\n\n"
        f"      Provisioning profile \"match AppStore ch.mint.app\" doesn't\n"
        f"      include the <capability> entitlement.\n"
        f"      ** ARCHIVE FAILED **\n\n"
        f"  Three steps to unblock :\n"
        f"    1. Apple Developer portal — enable the capability on App ID\n"
        f"       ch.mint.app.\n"
        f"    2. Run `fastlane match appstore` to regenerate the App Store\n"
        f"       provisioning profile. Push the updated profile to the\n"
        f"       `mint-certificates` repo.\n"
        f"    3. Add the new capability key to `_PROVISIONED_CAPABILITIES`\n"
        f"       in `tools/checks/ios_release_capability_drift.py` AND tag\n"
        f"       this commit with `[ios-release]` in the message.\n\n"
        f"  Bypass (emergency only) : `LEFTHOOK_BYPASS=1 git commit ...`.\n"
        f"  See memory `feedback_ios_entitlements_block_testflight.md`.\n"
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=(
            f"{LINT_NAME} — block iOS capability drift between "
            "Runner.entitlements and the App Store provisioning profile."
        )
    )
    ap.add_argument(
        "--commit-msg",
        type=Path,
        default=None,
        help=(
            "Path to candidate commit message (lefthook commit-msg hook). "
            "When provided, `[ios-release]` tag in the message ack's the "
            "out-of-band provisioning update and lets the lint pass."
        ),
    )
    args = ap.parse_args(argv)

    if not ENTITLEMENTS_PATH.exists():
        print(
            f"INFO {LINT_NAME}: {ENTITLEMENTS_PATH} not found — skipping.",
            file=sys.stderr,
        )
        return 0

    text = ENTITLEMENTS_PATH.read_text(encoding="utf-8", errors="ignore")
    found = _extract_capabilities(text)
    unknown = found - _PROVISIONED_CAPABILITIES

    if not unknown:
        # All capability keys are provisioned. Clean.
        # (No baseline-shrink notice — we want the allowlist to be
        # maintained by hand, not auto-grown.)
        return 0

    # Net-new capability detected. Check for explicit ack via commit-msg.
    if args.commit_msg and _commit_msg_has_release_tag(args.commit_msg):
        print(
            f"OK {LINT_NAME}: [ios-release] ack present in commit message "
            f"for {len(unknown)} new capability key(s) — assuming match "
            f"profile has been refreshed. Verify TestFlight build before "
            f"merging to staging.",
            file=sys.stderr,
        )
        return 0

    sys.stderr.write(_build_remediation_guide(unknown))
    return 1


if __name__ == "__main__":
    sys.exit(main())
