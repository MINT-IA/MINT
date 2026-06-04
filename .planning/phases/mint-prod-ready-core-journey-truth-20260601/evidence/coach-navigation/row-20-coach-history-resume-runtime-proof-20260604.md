---
date: 2026-06-04
row: 20
status: live-proven
scope: supported debug simulator, local ConversationStore continuity
---

# Row 20 Coach History Resume Runtime Proof

## Claim

Coach history lets a supported user return to a prior conversation after an app
restart and continue on the resumed conversation surface.

## Runtime Evidence

Flow:
`tools/simulator/flows/maestro-perfect-set/flow_row20_coach_history_resume.yaml`

Evidence folder:
`evidence/maestro-ci/row-20-coach-history-resume-20260604T224120/`

Device:
`iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`

Build:

```bash
cd apps/mobile
BUILT_PRODUCTS_DIR="$PWD/build/ios/Debug-iphonesimulator" bash ios/strip_provenance.sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Maestro:

```bash
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=120 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-20-coach-history-resume-20260604T224120 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --format junit \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-20-coach-history-resume-20260604T224120/debug \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-20-coach-history-resume-20260604T224120/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row20_coach_history_resume.yaml
```

Result:

- Exit: `0`
- JUnit: `tests=1`, `failures=0`
- Runtime: `49s`
- Watchdog: `EXIT - maestro returned 0`

Screenshots:

- `screenshots/01-row20-created-conversation.png`
- `screenshots/02-row20-history-before-restart.png`
- `screenshots/03-row20-history-after-restart.png`
- `screenshots/04-row20-resumed-follow-up.png`

## What The Flow Proves

- Fresh app launch opens `/coach/chat`.
- A user message creates a local conversation.
- The real Coach history button opens `/coach/history`.
- The history row is visible before restart.
- Restart without clearing state preserves the history row.
- Tapping the history row resumes `/coach/chat`.
- The resumed chat shows the previous message and accepts a follow-up message.

## Deterministic Context Transport Proof

Runtime intentionally does not assert a live LLM answer. The deterministic
Flutter test proves the context transport part:

```bash
cd apps/mobile
flutter test test/screens/coach/coach_chat_test.dart \
  --plain-name "sends resumed conversation history with the next message"
```

The test seeds a persisted conversation, opens
`CoachChatScreen(conversationId: ...)`, sends `Et maintenant ?`, captures the
history passed into the Coach orchestrator, and asserts the old user message,
old assistant message, and new follow-up are all sent in order.

## Supporting Static/Widget Proof

```bash
cd apps/mobile
flutter test test/screens/coach/conversation_history_screen_test.dart test/screens/coach/coach_chat_test.dart
flutter test test/screens/coach/conversation_history_screen_test.dart test/screens/coach/coach_chat_test.dart test/services/coach/ test/widgets/coach/
cd ../..
python3 tools/checks/maestro_locator_audit.py
```

Observed:

- Focused Coach screen tests: passed.
- Broader Coach suite: `1158` passed, `5` skipped.
- Locator audit: `40` flows scanned, `1` skipped, `444` locators, all resolve.

## Scope Limits

This closes Row 20 for supported local runtime continuity. It does not prove:

- authenticated cloud sync or cross-device conversation continuity;
- production backend conversation persistence;
- live LLM semantic quality after the resumed follow-up.

Those belong to account continuity, backend fact substrate, and Coach trust
rows rather than Row 20 local history/resume.

## Learning

Anonymous/empty-profile runtime attempts can correctly hit the supported-user
hard gate before chat persistence. Row 20 runtime proof therefore uses the
supported Swiss debug archetype `julien_swiss`; otherwise the run tests Row 2
eligibility, not history continuity.
