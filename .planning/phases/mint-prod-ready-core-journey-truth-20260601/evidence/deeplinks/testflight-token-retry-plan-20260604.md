---
id: CJT-015
date: 2026-06-04
status: testflight-upload-proven
area: release-testflight
release_blocker: true
---

# CJT-015 — TestFlight Token Retry Plan

## Result — 2026-06-04

The TestFlight/certificates slice is now proven for staging.

- First retry `26959484321` failed at certificate-repo preflight with
  `Invalid username or token`.
- `MATCH_GIT_BASIC_AUTHORIZATION` was rotated in the GitHub `staging`
  environment after confirming the local GitHub token could read
  `Julienbatt/mint-certificates`.
- Second retry `26959585734` passed certificate preflight and Flutter build,
  then failed inside `fastlane match` cloning the certificates repo.
- `MATCH_GIT_URL` was overridden in the GitHub `staging` environment to the
  clean repository URL:
  `https://github.com/Julienbatt/mint-certificates.git`.
- Third retry `26960098973` passed certificates, signing material, App Store
  secrets, and App Store Connect lookup, then failed because
  `apps/mobile/pubspec.yaml` build `66` was not greater than latest
  TestFlight build `66`.
- Commit `863678e64` on `staging` bumped `apps/mobile/pubspec.yaml` from
  `2.12.4+66` to `2.12.4+71`.
- Push-triggered run `26960858716` succeeded:
  `https://github.com/MINT-IA/MINT/actions/runs/26960858716`.
- Job `79550488693` completed successfully at `2026-06-04T15:31:06Z`.
- Fastlane processed and distributed build `2.12.4 - 71`:
  `Successfully finished processing the build 2.12.4 - 71 for IOS` at
  `2026-06-04T15:30:52Z`, then
  `Successfully distributed build to External testers` at
  `2026-06-04T15:30:55Z`.

Non-blocking warnings observed on the green run:

- `sentry_dart_plugin upload failed`, while the step still completed
  successfully. Track separately if crash-symbol upload must be hard-gated.
- `actions/checkout@v4` currently runs on Node.js 20, which GitHub will force
  toward Node.js 24 defaults later in 2026.

## Live Universal Link Check — 2026-06-04

The remaining CJT-015 blocker is still real after TestFlight upload success.

Current product-domain AASA request:

```bash
curl -iL --max-time 20 https://mint-ai.ch/.well-known/apple-app-site-association
```

Observed result at `2026-06-04T15:41Z`:

- `mint-ai.ch` does not resolve in DNS from the release-check environment.
- `www.mint-ai.ch`, `app.mint-ai.ch`, and `api.mint-ai.ch` also do not
  resolve.
- Therefore no public product AASA payload can currently be fetched from
  `mint-ai.ch`.

Important correction: earlier CJT evidence cited `mint.ch`. Julien clarified
that the product domain is `mint-ai.ch`; the old `mint.ch`/redirect finding is
stale and must not be used as the release decision.

Current staging AASA is valid:

```text
https://mint-staging.up.railway.app/.well-known/apple-app-site-association
content-type: application/json
appID: 7F5UDGYS5H.ch.mint.app
paths: /home, /aujourd-hui, /anonymous/chat, /coach/chat, /explorer/*
```

Current iOS repo state:

- `apps/mobile/ios/Runner/Info.plist` has `FlutterDeepLinkingEnabled=true`.
- `apps/mobile/ios/Runner/Info.plist` has custom scheme `mintapp`.
- `apps/mobile/ios/Runner/Runner.entitlements` has keychain and Apple Sign In
  entitlements, but no `com.apple.developer.associated-domains`.
- The Xcode project points all Runner configurations at
  `Runner/Runner.entitlements`.

Therefore build `2.12.4 - 71` is suitable for TestFlight install and custom
scheme QA, but it is not sufficient Universal Link release proof. A real-device
HTTPS MINT link cannot close CJT-015 until both the app entitlement/profile and
the production `mint-ai.ch` DNS/AASA path are corrected.

## Trigger

Julien reports that the TestFlight/certificates token is now available. This
unblocks the next retry of the GitHub Actions `TestFlight` workflow that failed
on 2026-06-02 at `Configure git credentials for certificates repo`.

## What The Token Must Satisfy

The GitHub secret `MATCH_GIT_BASIC_AUTHORIZATION` must be base64-encoded as:

```text
username:token
```

The token must have read access to:

```text
https://github.com/Julienbatt/mint-certificates.git
```

The workflow itself preflights this by cloning the certificates repository
before any iOS build/upload step.

## Retry Command

After the secret is updated in the GitHub environment used by staging:

```bash
gh workflow run TestFlight -f environment=staging
gh run list --workflow TestFlight --limit 5
gh run watch <run-id>
```

## Evidence To Capture

Store the run URL and logs in this evidence tree. The run must prove:

1. `Configure git credentials for certificates repo` reaches
   `Certificates repo clone preflight OK`.
2. `Backend health precheck` reaches `Backend health precheck OK`.
3. `Flutter build iOS (no codesign)` exits 0.
4. `Build & Upload to TestFlight` exits 0.
5. App Store Connect shows the uploaded build in TestFlight.

## Still Not Enough To Close CJT-015

A successful TestFlight upload closes only the certificates/upload slice.
CJT-015 stays open until Universal Link release proof is also real:

- Apple Developer App ID `ch.mint.app` has Associated Domains enabled.
- The App Store provisioning profile is regenerated with that capability.
- `Runner.entitlements` contains the exact production associated domains in an
  isolated `[ios-release]` change.
- `https://mint-ai.ch/.well-known/apple-app-site-association` serves MINT's AASA
  directly.
- A real iOS device opens a signed TestFlight build from an HTTPS MINT link and
  lands inside the expected GoRouter path.

Until those are attached, CJT-015 remains a release blocker.
