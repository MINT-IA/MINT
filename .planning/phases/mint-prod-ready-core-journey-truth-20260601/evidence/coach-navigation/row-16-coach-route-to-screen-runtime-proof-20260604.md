# Row 16 — Coach Route-To-Screen Runtime Proof — 2026-06-04

## Scope

Proves the local supported simulator path:

`CoachChatScreen -> CoachLlmService.chat -> route_to_screen tool call -> WidgetRenderer -> RouteSuggestionCard -> user tap -> /rente-vs-capital`

Also proves, by deterministic widget test, that a non-sequence `ScreenReturn`
emitted after a simulator interaction is injected into the next Coach request
as context.

Also proves the integrated local path:

`CoachChatScreen -> RouteSuggestionCard tap -> pushed simulator route -> persisted ScreenReturn -> return to Coach -> next Coach request memoryBlock`

Does not close live LLM route quality or authenticated backend/cloud continuity.

## What Changed

- Added debug-only `E2eCoachRouteFixture`.
- Fixture activates only with `kDebugMode` and `MINT_E2E_COACH_ROUTE_FIXTURE=retirement_choice`.
- `main.dart` uses the fixture orchestrator when present, otherwise `CoachOrchestrator.generateChat`.
- Added runtime locators for `coach_route_suggestion_card` and `rente_vs_capital_screen`.
- Added `flow_row16_coach_route_to_screen_runtime.yaml`.
- Added a `CoachChatScreen` regression test proving `ScreenCompletionTracker`
  returns are appended to the next `memoryBlock`.
- Fixed a route-return gap where a pushed screen could persist a
  `ScreenReturn` while the Coach route missed the realtime broadcast. The
  tracker now stores a latest full return; `CoachChatScreen` hydrates recent
  non-sequence returns before the next request; `RouteSuggestionCard` replays a
  matching recent return after `context.push` resolves.

## Evidence

- Folder: `evidence/maestro-ci/row-16-coach-route-to-screen-runtime-20260604T234705/`
- Device: iPhone 17 Pro, iOS 26.2, `B03E429D-0422-4357-B754-536637D979F9`
- JUnit: `tests=1`, `failures=0`
- Watchdog: `0`
- Duration: `25s`
- Screenshots: `01-row16-coach-route-suggestion.png`, `02-row16-rente-vs-capital-target.png`
- Deterministic ScreenReturn proof: `flutter test test/screens/coach/coach_chat_test.dart --plain-name "injects ScreenReturn context into the next coach request after a simulator return"` passed.
- Integrated local return proof: `flutter test test/screens/coach/coach_chat_test.dart --plain-name "carries context from route suggestion tap through simulator return into next coach request"` passed.

## Runtime Guidance Quality Review

- `mechanical proof`: JUnit green, watchdog `0`, suggestion and target screenshots captured; deterministic widget tests now cover direct ScreenReturn injection and route-card tap -> fake simulator -> persisted return -> next Coach request context.
- `user-visible outcome`: user asks `Rente ou capital ?`, sees a concise Coach bridge plus `Ouvrir`, then lands on canonical `Rente ou capital : ta décision`.
- `guidance quality`: coherent for Row 16 route-to-screen proof; the suggested screen matches `retirement_choice` and does not detour to a duplicate alias.
- `non-absurd`: no `Page introuvable`, no unrelated route, no dead-end CTA.
- `inclusive`: target screen uses `revenu brut annuel`, not salary-only wording.
- `financial trust`: fixture avoids live advice claims; screen remains simulator/decision support, not a personalized recommendation; the ScreenReturn tests inject context for a next response instead of auto-claiming personalized advice.
- `remaining qualitative gaps`: live LLM route selection quality and authenticated backend/cloud continuity remain unproven.

## Verification

- `flutter test test/services/coach/e2e_coach_route_fixture_test.dart test/widgets/coach/route_suggestion_card_test.dart`
- `flutter test test/screens/coach/coach_chat_test.dart --plain-name "renders structured route_to_screen response as a resolved action card"`
- `flutter test test/screens/coach/coach_chat_test.dart --plain-name "injects ScreenReturn context into the next coach request after a simulator return"`
- `flutter test test/screens/coach/coach_chat_test.dart --plain-name "carries context from route suggestion tap through simulator return into next coach request"`
- `flutter test test/services/screen_completion_tracker_test.dart`
- `flutter test test/widgets/coach/widget_renderer_test.dart --plain-name "tap navigates to resolved route and passes prefill under extra.prefill"`
- `flutter analyze`
- `python3 tools/checks/maestro_locator_audit.py`

## Decision

Row 16 remains `PARTIAL`: runtime route-to-screen, direct ScreenReturn-to-next-Coach-context injection, and integrated route-card tap -> simulator return -> next Coach context are proven locally; live LLM/backend route selection quality remains open.
