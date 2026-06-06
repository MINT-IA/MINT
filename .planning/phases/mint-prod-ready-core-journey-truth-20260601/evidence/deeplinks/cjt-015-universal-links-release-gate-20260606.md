---
id: CJT-015
date: 2026-06-06
status: open-release-gate
area: release-universal-links
release_blocker: true
---

# CJT-015 Universal Links Release Gate — 2026-06-06

## Verdict

CJT-015 remains open and release-blocking.

This pass adds a deterministic local gate:

```bash
python3 tools/checks/ios_universal_links_release_gate.py
python3 tools/checks/ios_universal_links_release_gate.py --live --timeout 5
```

The gate is intentionally stricter than Maestro simulator deeplink flows. A
simulator can prove route handling, but CJT-015 closes only when a signed iOS
build has Associated Domains and the production host serves MINT's AASA payload.

## Local iOS State

Current `Info.plist` is ready for custom scheme and Flutter deep link handling:

```text
CFBundleURLSchemes includes mintapp
FlutterDeepLinkingEnabled=true
```

Current `Runner.entitlements` is not Universal-Link-ready:

```text
com.apple.developer.associated-domains is absent
```

Observed gate result:

```text
python3 tools/checks/ios_universal_links_release_gate.py
exit=1
::error::ios_universal_links_release_gate: Runner.entitlements must declare com.apple.developer.associated-domains
```

That failure is expected until Apple Developer App ID `ch.mint.app` has
Associated Domains enabled and the App Store provisioning profile has been
regenerated through fastlane match. Adding the entitlement before that would
repeat the 2026-05-11 TestFlight archive failure guarded by
`tools/checks/ios_release_capability_drift.py`.

## Live Product Host State

Observed live gate result:

```text
python3 tools/checks/ios_universal_links_release_gate.py --live --timeout 5
exit=1
::error::ios_universal_links_release_gate: Runner.entitlements must declare com.apple.developer.associated-domains
::error::ios_universal_links_release_gate: https://mint-ai.ch/.well-known/apple-app-site-association is not reachable: <urlopen error [Errno 8] nodename nor servname provided, or not known>
::error::ios_universal_links_release_gate: https://www.mint-ai.ch/.well-known/apple-app-site-association is not reachable: <urlopen error [Errno 8] nodename nor servname provided, or not known>
```

Therefore the production product-domain AASA path is still absent. `mint-ai.ch`
and `www.mint-ai.ch` must resolve publicly and serve the MINT AASA payload
directly before real-device Universal Link proof can pass.

## Added Guard

New files:

- `tools/checks/ios_universal_links_release_gate.py`
- `tools/checks/tests/test_ios_universal_links_release_gate.py`

The guard rejects:

- missing `FlutterDeepLinkingEnabled` or missing `mintapp://` scheme,
- missing `com.apple.developer.associated-domains`,
- missing production associated domains for `mint-ai.ch` and `www.mint-ai.ch`,
- redirected AASA fetches,
- AASA payloads without `appID=7F5UDGYS5H.ch.mint.app`,
- AASA paths that are missing or not part of the current release route set.

## Backend AASA Route Correction

Claude CLI review found that the historical backend AASA payload included stale
paths:

```text
/aujourd-hui
/explorer/*
```

Those paths do not match the current Flutter route registry. This pass corrected
the backend payload to the current release route set:

```text
/home
/anonymous/chat
/coach/chat
/explore
/explore/*
```

Backend AASA tests now assert that exact route set and reject the stale slugs.

Targeted tests passed:

```text
python3 -m pytest tools/checks/tests/test_ios_universal_links_release_gate.py tools/checks/tests/test_ios_release_info_plist_drift.py -q
10 passed in 0.14s

cd services/backend
python3 -m pytest tests/test_aasa_endpoint.py -q
7 passed in 0.34s
```

## Closure Requirements

Do not close CJT-015 until all of these are true:

1. Apple Developer App ID `ch.mint.app` has Associated Domains enabled.
2. The App Store provisioning profile is regenerated through fastlane match and
   committed to the certificate repository.
3. `Runner.entitlements` includes `applinks:mint-ai.ch` and
   `applinks:www.mint-ai.ch` in an isolated `[ios-release]` change.
4. `tools/checks/ios_release_capability_drift.py` allowlist is updated in that
   same `[ios-release]` change.
5. TestFlight archive succeeds with the Associated Domains entitlement present.
6. `https://mint-ai.ch/.well-known/apple-app-site-association` and
   `https://www.mint-ai.ch/.well-known/apple-app-site-association` serve MINT's
   AASA payload directly. The `www` host is treated as a required public entry
   host because users and marketing links will naturally use both forms.
7. A real iOS device opens a signed TestFlight build from an HTTPS MINT link and
   lands inside the expected GoRouter path.
8. The passing `ios_universal_links_release_gate.py --live` output and
   real-device screenshots/logs are stored in this evidence tree.
9. The live gate is wired into the release/TestFlight workflow once it can pass,
   so Universal Link regressions block release instead of depending on a manual
   command.
