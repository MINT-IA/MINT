# CJT-015 Universal Links Release Gate — 2026-06-02

## Verdict

CJT-015 remains open and release-blocking.

The custom `mintapp://` scheme is configured, and the staging backend serves a
valid AASA payload. Production Universal Links are not release-ready because the
signed iOS entitlement chain is intentionally absent and the public `mint.ch`
AASA URL does not serve MINT's AASA directly.

## Mobile Configuration Proof

`apps/mobile/ios/Runner/Info.plist` and `Info-Debug.plist` contain:

```text
CFBundleURLSchemes=mintapp
FlutterDeepLinkingEnabled=true
```

`apps/mobile/ios/Runner/Runner.entitlements` does not contain:

```text
com.apple.developer.associated-domains
```

That absence is intentional. `tools/checks/ios_release_capability_drift.py`
guards against re-adding the entitlement without an `[ios-release]` provisioning
profile update. The lint passed locally on 2026-06-02:

```text
python3 tools/checks/ios_release_capability_drift.py
exit=0
```

## Backend AASA Proof

The backend AASA endpoint is implemented at:

```text
services/backend/app/main.py
/.well-known/apple-app-site-association
```

Targeted backend contract test passed with Python 3.11:

```text
cd services/backend && python3 -m pytest tests/test_aasa_endpoint.py -q
6 passed, 1 warning
```

Staging host proof:

```text
GET https://mint-staging.up.railway.app/.well-known/apple-app-site-association
HTTP/2 200
content-type: application/json
appID=7F5UDGYS5H.ch.mint.app
paths=/home,/aujourd-hui,/anonymous/chat,/coach/chat,/explorer/*
```

## Production Host Proof

Production user-facing host proof:

```text
GET https://mint.ch/.well-known/apple-app-site-association
HTTP/2 301
location=https://whey-protein.ch/.well-known/apple-app-site-association
```

Following the redirect reaches a non-MINT AASA payload:

```text
GET https://whey-protein.ch/.well-known/apple-app-site-association
HTTP/2 200
content-type=application/json
applinks.details=[]
```

This is not a valid production Universal Link setup for MINT. A release claim
that `https://mint.ch/...` opens MINT on device would be false.

## Closure Requirements

Close CJT-015 only after all of these are true:

1. Apple Developer App ID `ch.mint.app` has Associated Domains enabled.
2. App Store provisioning profile is regenerated through fastlane match and
   committed to the certificate repository.
3. `Runner.entitlements` includes the exact production domains, in an isolated
   `[ios-release]` PR.
4. `tools/checks/ios_release_capability_drift.py` allowlist is updated in the
   same PR.
5. TestFlight archive succeeds with the entitlement present.
6. `mint.ch/.well-known/apple-app-site-association` serves MINT's AASA directly,
   without redirecting to another domain and without `details: []`.
7. A real iOS device opens a signed TestFlight build from an HTTPS MINT link and
   lands inside the expected GoRouter path.
8. Durable screenshot/JUnit/log evidence is stored under this evidence tree.

## Product Decision

Until this is closed, production copy, release notes, QA reports, and investor
or beta claims must say:

```text
Custom mintapp:// deep links are available for internal QA.
Production HTTPS Universal Links are not enabled yet.
```
