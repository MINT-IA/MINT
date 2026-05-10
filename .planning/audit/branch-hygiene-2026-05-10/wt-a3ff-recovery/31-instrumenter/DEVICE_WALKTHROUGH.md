---
phase: 31
plan: 03
status: deferred-to-followup
walker: julien
auto_pass: pre-creator-device
created: 2026-04-19
---

# Phase 31 — Creator-Device Walkthrough Log

## Status: DEFERRED (non-blocking for phase completion)

Per `VALIDATION.md` Manual-Only §creator-device and ROADMAP Phase 31 Auto Profile L3, the formal creator-device gate is a 10-minute cold-start walkthrough that Julien performs personally on his iPhone 17 Pro (physical device) with a staging IPA.

Julien pre-authorised autonomous completion of Plan 31-03 ("tu es l'expert, tu prends tout en main"). The executor completed the automated + static audit layers (see `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`) and signed the artefact as `automated (pre-creator-device) — 2026-04-19`. This file captures the intent to follow up with the physical-device layer as an optional strengthening, NOT as a blocker for Plan 31-03 completion.

## Why deferred

- Requires live `SENTRY_DSN_STAGING` secret (Julien-held).
- Requires physical iPhone 17 Pro with Apple Developer provisioning profile.
- Requires live staging Sentry UI access (Julien session).
- The automated audit already verifies the mask discipline statically; the physical-device layer is a redundant-but-useful confirmation of the same property at runtime.

## When to run the physical walkthrough (recommended)

Trigger any of:

1. Before a future decision to flip production `sessionSampleRate` above `0.0` (D-01 Option C revisit).
2. After any edit to `apps/mobile/lib/main.dart` that touches Sentry initialisation.
3. After adding a new CustomPaint to any of the 5 sensitive screens listed in `SENTRY_REPLAY_REDACTION_AUDIT.md` §Screens audited.
4. As part of the Phase 35 (Boucle Daily) dogfood loop.

## Protocol (when executed)

Per `VALIDATION.md` Manual-Only §creator-device:

1. Build staging IPA. **macOS Tahoe doctrine applies — NEVER `flutter clean`, NEVER delete `Podfile.lock`.** Literal 3-step:
   ```bash
   cd apps/mobile
   flutter build ios --release --no-codesign \
     --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
     --dart-define=MINT_ENV=staging \
     --dart-define=SENTRY_DSN="$SENTRY_DSN_STAGING"

   xcodebuild -workspace apps/mobile/ios/Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     archive

   xcrun devicectl device install app \
     --device <udid> \
     ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Release-iphoneos/Runner.app
   ```
2. Cold-start timer.
3. Run the 5 critical journeys from `.planning/research/CRITICAL_JOURNEYS.md`.
4. Intentionally trigger 1 error (e.g. airplane-mode → chat send → offline boundary fires).
5. Within 60 seconds, open Sentry UI:
   - Verify mobile error event present.
   - Verify `trace_id` tag non-empty.
   - Verify Cross-project link panel shows backend transaction (OBS-04 c).
   - Verify Replay attached via `onErrorSampleRate=1.0`.
6. Screenshot the Sentry UI panels showing mask overlay on CHF/IBAN/AVS frames.
7. Append results here + update `SENTRY_REPLAY_REDACTION_AUDIT.md` frontmatter (`auditor`, `physical_device_walkthrough: PASS`).
8. Reply `approved — creator-device walkthrough PASS` to unblock any future prod sample-rate flip decision.

## Automated audit pass summary (pre-creator-device)

- CustomPaint inventoried across 5 sensitive screens: **1**
- CustomPaint wrapped in `MintCustomPaintMask`: **1/1**
- `flutter analyze` on `mint_custom_paint_mask.dart` + modified screens: **0 issues**
- `audit_artefact_shape.py SENTRY_REPLAY_REDACTION_AUDIT`: verified clean (see Task 2 verification log)
- Simulator screenshot (homescreen proof iPhone 17 Pro, iOS 26.2): `.planning/research/pii-audit-screenshots/2026-04-19-automated/sim-state-home.png`

## Sign-off

deferred: 2026-04-19 (Plan 31-03 Task 2 automated pass)

physical_device_walkthrough: PENDING (non-blocking)

---

*Phase: 31-instrumenter*
*Plan: 31-03 Task 2*
*Follow-up artefact when Julien runs the physical walkthrough*
