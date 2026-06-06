# Row 26 Simulator Build / iPhone 16e Runtime Proof

Date: 2026-06-06
Rows: 26 primary, 22/23 support
Bug: CJT-059
Status: local runtime automation hardening, not a release-device proof

## Problem

Normal iOS simulator builds could fail at the final Xcode CodeSign step with:

```text
Command CodeSign failed with a nonzero exit code
resource fork, Finder information, or similar detritus not allowed
```

Earlier runtime proofs sometimes depended on `--no-codesign`, manual xattr
cleanup, or a premium `iPhone 17 Pro` simulator. That weakened Row 26 because
the regression stack was less repeatable than the product claims it protects.

## Fix

The Runner target now disables code signing for simulator SDKs only:

```text
"CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]" = NO;
```

Device signing remains outside this conditional setting.

## Build Proof

Command:

```bash
cd apps/mobile
flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result:

```text
Xcode build done. 6.8s
Built build/ios/iphonesimulator/Runner.app
```

Xcode build settings check:

```text
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = YES
CODE_SIGN_IDENTITY = -
SDK_NAME = iphonesimulator26.2
```

## Runtime Proof

The default simulator target was changed from `iPhone 17 Pro` to `iPhone 16e`.
The committed config keeps the portable simulator name, while this runtime proof
records the concrete local UDID used for the run:

```text
simulatorName: iPhone 16e
simulatorId: 9C9E9AAE-C3CF-49B8-B06D-625004880A9B
bundleId: ch.mint.app
```

XcodeBuild MCP install and launch both succeeded on the `iPhone 16e`.

Runtime snapshot exposed the first screen and LSFin boundary:

```text
Voir clair, décider seul.
Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin.
```

Screenshot:

- `iphone16e-launch.jpg`

Runtime log:

- `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/ch.mint.app_2026-06-06T13-19-53-517Z_helperpid6581_ownerpid14705_1ba8e263.log`

## Scope Limit

This closes the local simulator CodeSign/xattr hardening bug only. Row 26 stays
`PARTIAL`: scheduled sweeps, TestFlight/signed-device proof, and broader release
automation remain separate gates.
