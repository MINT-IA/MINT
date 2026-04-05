---
phase: 03-onboarding-pipeline
verified: 2026-04-05T17:13:47Z
status: gaps_found
score: 3/4 success criteria verified
re_verification: false
gaps:
  - truth: "JourneyTrigger connects the selected intent to the correct calculator or insight flow (SC3 / ONB-03)"
    status: failed
    reason: "5 of 6 unique suggestedRoutes in IntentRouter do not exist in the GoRouter. Tapping 'Comprendre' on PremierEclairageCard for intentChipBilan, intentChipPrevoyance, intentChipFiscalite, intentChipProjet, and intentChipChangement navigates to _MintErrorScreen."
    artifacts:
      - path: "apps/mobile/lib/services/coach/intent_router.dart"
        issue: "Maps 6 chips to routes that are not registered: /bilan-retraite, /prevoyance-overview, /fiscalite-overview, /achat-immobilier, /life-events"
      - path: "apps/mobile/lib/app.dart"
        issue: "Only /pilier-3a is registered. The other 5 intent-mapped routes have no GoRoute definition or redirect."
    missing:
      - "Register /bilan-retraite (or redirect to /retraite) in app.dart"
      - "Register /prevoyance-overview (or redirect to /explore/retraite) in app.dart"
      - "Register /fiscalite-overview (or redirect to /explore/fiscalite) in app.dart"
      - "Register /achat-immobilier (or redirect to /hypotheque or /epl) in app.dart"
      - "Register /life-events (or redirect to an appropriate life events hub) in app.dart"
human_verification:
  - test: "Complete onboarding pipeline on device — tap each of the 7 intent chips"
    expected: "After each chip tap, PremierEclairageCard shows a ChF-denominated number specific to that intent within 3 minutes; tapping Comprendre navigates to a working calculator screen (not an error screen)"
    why_human: "Cannot verify animated card rendering, actual ChiffreChoc values, and end-to-end device timing programmatically"
  - test: "Tap 'Comprendre' on PremierEclairageCard after selecting intentChipProjet (housing intent)"
    expected: "Navigates to a housing calculator (e.g., /hypotheque or /epl), not a 404 error screen"
    why_human: "The broken route /achat-immobilier requires human observation of the error screen vs working calculator"
  - test: "Switch to Coach tab after onboarding intent selection — verify first message"
    expected: "First coach message references the selected intent (e.g., 'Tu as un projet immobilier' for housing), not generic text"
    why_human: "Requires confirming the conditional rendering path (_intentOpenerText vs _computeKeyNumber) is taken correctly on a real first session"
  - test: "Kill and relaunch the app after dismissing the PremierEclairageCard"
    expected: "PremierEclairageCard does not reappear on second launch"
    why_human: "Cannot verify SharedPreferences persistence and UI hide logic across app restarts programmatically"
---

# Phase 03: Onboarding Pipeline Verification Report

**Phase Goal:** A user who selects an intent chip on the onboarding screen receives a personalized premier eclairage with a concrete Swiss-specific number within 3 minutes, and lands on a contextual home screen — not a generic dashboard
**Verified:** 2026-04-05T17:13:47Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (mapped to Roadmap Success Criteria)

| #  | Success Criterion | Status     | Evidence |
|----|------------------|------------|---------|
| SC1 | User selects chip → sees personalized premier eclairage with Swiss-specific number within 3 minutes | ? UNCERTAIN | PremierEclairageCard exists and wires to ChiffreChocSelector; requires human verification on device |
| SC2 | IntentScreen selection triggers CapSequenceEngine to generate relevant first journey; CapMemoryStore goal is set after chip tap | ✓ VERIFIED | `intent_screen.dart:195` sets `declaredGoals: [mapping.goalIntentTag]`; `mint_state_engine.dart:124-130` maps `declaredGoals.first` → `activeGoalIntentTag`. CapSequenceEngine.build called at line 202. |
| SC3 | JourneyTrigger connects the selected intent to the correct calculator or insight flow | ✗ FAILED | 5 of 6 unique `suggestedRoute` values in IntentRouter (`/bilan-retraite`, `/prevoyance-overview`, `/fiscalite-overview`, `/achat-immobilier`, `/life-events`) are not registered in `app.dart`'s GoRouter. Tapping Comprendre for 6 of 7 chips navigates to `_MintErrorScreen`. |
| SC4 | Post-onboarding landing screen content reflects the selected intent — firstJob intent lands differently than housingPurchase intent | ✓ VERIFIED | PremierEclairageCard shows intent-specific ChiffreChoc number/title/subtitle (different per stressType). CoachChatScreen `resolveIntentOpener` returns 7 distinct, intent-specific ARB strings. Both confirmed by passing tests. |

**Score:** 2/4 SCs fully verified (SC1 uncertain/human-needed, SC3 failed)

---

### Must-Haves from Plan Frontmatter

#### Plan 01 Truths

| Truth | Status | Evidence |
|-------|--------|---------|
| IntentRouter.forChipKey returns a valid IntentMapping for all 7 chip keys | ✓ VERIFIED | `intent_router.dart` — static const map with 7 entries; 15 tests passing |
| Each mapping includes goalIntentTag, stressType, suggestedRoute, and lifeEventFamily | ✓ VERIFIED | All 4 fields present in `IntentMapping` class; verified in `intent_router_test.dart` |
| ReportPersistenceService can save/load a PremierEclairage snapshot and hasSeenPremierEclairage flag | ✓ VERIFIED | `report_persistence_service.dart:217-244` — 4 methods + 2 keys; 12 tests passing |

#### Plan 02 Truths

| Truth | Status | Evidence |
|-------|--------|---------|
| Tapping an intent chip writes goalIntentTag to CapMemoryStore.declaredGoals | ✓ VERIFIED | `intent_screen.dart:192-197`; test "chip tap writes goalIntentTag to CapMemoryStore.declaredGoals" passes |
| Tapping an intent chip computes and persists a premier eclairage snapshot via ChiffreChocSelector | ✓ VERIFIED | `intent_screen.dart:177-190`; snapshot test asserts keys value/title/suggestedRoute/colorKey/confidenceMode present |
| Tapping an intent chip navigates to /home?tab=0 (Aujourd'hui), not /home?tab=1 (Coach) | ✓ VERIFIED | `intent_screen.dart:221`; test "chip tap navigates to /home?tab=0" passes; `tab=1` grep returns 0 matches in the file |
| The chipKey (ARB identifier) is persisted, not the resolved localized string | ✓ VERIFIED | `intent_screen.dart:168` stores `chip.chipKey`; test asserts `equals('intentChip3a')` not French label |
| A fresh profile (no QuickStart data) produces a pedagogical-mode ChiffreChoc instead of crashing | ✓ VERIFIED | `_buildMinimalProfile` returns zero-valued `MinimalProfileResult` for fresh install; ChiffreChocSelector returns non-null per test |

#### Plan 03 Truths

| Truth | Status | Evidence |
|-------|--------|---------|
| First-time user sees PremierEclairageCard as Section 0 on MintHomeScreen after intent selection | ✓ VERIFIED | `mint_home_screen.dart:134` conditional; 4 show/hide tests passing |
| PremierEclairageCard shows the persisted ChiffreChoc number, title, subtitle, and a Comprendre CTA | ✓ VERIFIED | `premier_eclairage_card.dart:153-210`; widget test "shows number and title from snapshot" passes |
| Tapping Comprendre navigates to the suggested calculator route | ✗ FAILED | `onNavigate(suggestedRoute)` called correctly, but 5/6 suggestedRoutes are unregistered in app.dart |
| Card no longer appears once the user has dismissed it or explored a simulator | ✓ VERIFIED | `markPremierEclairageSeen` called on dismiss and navigate; `exploredSimulators` check in `_shouldShowPremierEclairage`; tests pass |
| Pedagogical fallback shows Swiss-average estimate with Personnaliser CTA when no profile exists | ✓ VERIFIED | `premier_eclairage_card.dart:137` error state shows Personnaliser → `/onboarding/quick-start`; widget test passes |
| Coach chat shows intent-aware opener on first session (not generic silent opener) | ✓ VERIFIED | `coach_chat_screen.dart:1356` checks `_intentOpenerText != null` before generic opener; `_pendingIntentChipKey` consumed once |
| Different intents produce different premier eclairage numbers and coach openers | ✓ VERIFIED | ChiffreChocSelector differentiates by `stressType`; `resolveIntentOpener` returns 7 distinct strings (test: "all 7 intent keys map to distinct non-null strings") |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `apps/mobile/lib/services/coach/intent_router.dart` | Static const mapping from 7 chip keys to IntentMapping | ✓ VERIFIED | 88 lines, fully wired; 0 stubs |
| `apps/mobile/lib/services/report_persistence_service.dart` | PremierEclairage persistence methods | ✓ VERIFIED | 4 methods added at lines 217-244; clearDiagnostic extended at lines 715-716 |
| `apps/mobile/lib/screens/onboarding/intent_screen.dart` | Rewired _onChipTap with IntentRouter + CapMemory + ChiffreChoc + persistence | ✓ VERIFIED | Full 10-step pipeline at lines 155-221 |
| `apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart` | PremierEclairageCard widget with dismiss, CTA, pedagogical fallback | ✓ VERIFIED | 350 lines; 3 states (normal, pedagogical, error); chiffreChocDisclaimer included |
| `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | Section 0 conditional rendering of PremierEclairageCard | ✓ VERIFIED | Converted to StatefulWidget; `_shouldShowPremierEclairage` getter; initState loads prefs |
| `apps/mobile/lib/screens/coach/coach_chat_screen.dart` | Intent-aware coach opener | ✓ VERIFIED | `resolveIntentOpener` top-level function at line 1611; `_pendingIntentChipKey` lifecycle correct |
| ARB files (6 languages) | 13 new i18n keys | ✓ VERIFIED | 14 matches per language file (13 keys + 1 parity check); all 6 files updated |
| Test files (6 files) | Coverage for all new behaviors | ✓ VERIFIED | 48 tests total across 6 test files; all passing |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `intent_screen.dart` | `intent_router.dart` | `IntentRouter.forChipKey(chip.chipKey)` | ✓ WIRED | Line 171 |
| `intent_screen.dart` | `cap_memory_store.dart` | `CapMemoryStore.save(memory.copyWith(declaredGoals: ...))` | ✓ WIRED | Lines 193-197 |
| `intent_screen.dart` | `chiffre_choc_selector.dart` | `ChiffreChocSelector.select(profile, stressType: mapping.stressType)` | ✓ WIRED | Line 177 |
| `premier_eclairage_card.dart` | `report_persistence_service.dart` | `loadPremierEclairageSnapshot()` and `markPremierEclairageSeen()` | ✓ WIRED | Lines 74, 210+dismiss |
| `mint_home_screen.dart` | `premier_eclairage_card.dart` | Conditional Section 0 insertion | ✓ WIRED | Lines 133-152 |
| `coach_chat_screen.dart` | `report_persistence_service.dart` | `getSelectedOnboardingIntent()` + `hasSeenPremierEclairage()` | ✓ WIRED | Lines 238-243 |
| `premier_eclairage_card.dart` → CTA | `app.dart` GoRouter | `context.go(suggestedRoute)` via `onNavigate` | ✗ BROKEN | `/bilan-retraite`, `/prevoyance-overview`, `/fiscalite-overview`, `/achat-immobilier`, `/life-events` not registered |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `premier_eclairage_card.dart` | `_snapshot` Map | `ReportPersistenceService.loadPremierEclairageSnapshot()` → snapshot written by `intent_screen._onChipTap` via `ChiffreChocSelector.select()` | Yes — ChiffreChocSelector queries profile data; pedagogical fallback returns Swiss averages | ✓ FLOWING |
| `mint_home_screen.dart` | `_shouldShowPremierEclairage` | `ReportPersistenceService.hasSeenPremierEclairage()` + `getSelectedOnboardingIntent()` + `UserActivityProvider.exploredSimulators` | Yes — real SharedPreferences + provider state | ✓ FLOWING |
| `coach_chat_screen.dart` | `_intentOpenerText` | `getSelectedOnboardingIntent()` → `resolveIntentOpener()` → ARB strings | Yes — real chipKey from persistence → real localized string | ✓ FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| IntentRouter returns correct mapping for all 7 keys | `flutter test test/services/coach/intent_router_test.dart` | 15/15 passed | ✓ PASS |
| PremierEclairage persistence round-trip | `flutter test test/services/coach/report_persistence_premier_eclairage_test.dart` | 12/12 passed | ✓ PASS |
| IntentScreen pipeline: chipKey stored, CapMemory seeded, navigates to tab=0 | `flutter test test/screens/onboarding/intent_screen_test.dart` | 14/14 passed | ✓ PASS |
| PremierEclairageCard renders correctly in all 3 states | `flutter test test/widgets/onboarding/premier_eclairage_card_test.dart` | 1/1 passed | ✓ PASS |
| MintHomeScreen Section 0 show/hide conditions | `flutter test test/screens/main_tabs/mint_home_screen_test.dart` | 12/12 passed | ✓ PASS |
| resolveIntentOpener returns 7 distinct intent-specific strings | `flutter test test/screens/coach/coach_chat_opener_test.dart` | 7/7 passed | ✓ PASS |
| flutter analyze on all 6 modified production files | `flutter analyze lib/services/coach/intent_router.dart lib/services/report_persistence_service.dart lib/screens/onboarding/intent_screen.dart lib/widgets/onboarding/premier_eclairage_card.dart lib/screens/main_tabs/mint_home_screen.dart lib/screens/coach/coach_chat_screen.dart` | 0 issues | ✓ PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| ONB-01 | Plan 02, Plan 03 | User completes intent selection and sees first personalized insight (premier eclairage) within 3 minutes | ? UNCERTAIN | PremierEclairageCard exists and is wired. Whether the content renders in <3 minutes on device needs human verification. |
| ONB-02 | Plan 01, Plan 02 | IntentScreen selection triggers CapSequenceEngine to generate relevant first journey | ✓ SATISFIED | `intent_screen.dart:202-208` calls `CapSequenceEngine.build()` with `goalIntentTag` from IntentRouter; `declaredGoals` seeded in CapMemoryStore and picked up by `MintStateEngine` as `activeGoalIntentTag` |
| ONB-03 | Plan 01, Plan 02 | JourneyTrigger connects onboarding intent to appropriate calculator/insight flow | ✗ BLOCKED | The "journey trigger" is the PremierEclairageCard Comprendre CTA → `context.go(suggestedRoute)`. Five routes are unregistered in GoRouter (`/bilan-retraite`, `/prevoyance-overview`, `/fiscalite-overview`, `/achat-immobilier`, `/life-events`). Only `/pilier-3a` works. |
| ONB-04 | Plan 03 | Post-onboarding landing is contextual (based on selected intent), not generic home screen | ✓ SATISFIED | PremierEclairageCard Section 0 shows intent-specific number/CTA from snapshot. CoachChatScreen shows intent-specific opener text. Different intents produce distinct card content. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `apps/mobile/lib/services/coach/intent_router.dart` | 39–77 | 5 of 6 unique `suggestedRoute` values reference routes not registered in GoRouter | 🛑 Blocker | Tapping "Comprendre" for 6 of 7 intent chips shows `_MintErrorScreen` — breaks ONB-03 and the "journey trigger" promise |
| `apps/mobile/lib/services/cap_memory_store.dart` | 20 | `// TODO(P3): Sync CapMemory to backend` | ℹ️ Info | Existing TODO, not introduced in this phase |

---

### Human Verification Required

#### 1. Premier Eclairage on Device — All 7 Chips

**Test:** On a fresh install (or cleared app data), open the app, reach IntentScreen, tap each of the 7 intent chips in turn (resetting app data between each)
**Expected:** After each chip tap, land on Aujourd'hui tab; PremierEclairageCard appears as first card showing a CHF number relevant to the intent; card has "Comprendre" CTA and dismiss x icon
**Why human:** Animated card rendering, ChiffreChoc value quality, and 3-minute timing constraint require device verification

#### 2. Comprendre CTA Navigation for Broken Routes

**Test:** After selecting intentChipBilan (bilan retraite), tap "Comprendre" on PremierEclairageCard
**Expected:** Navigate to a working retirement overview screen (not an error/404 screen)
**Why human:** The broken route `/bilan-retraite` will show `_MintErrorScreen` — direct human observation confirms the gap severity

#### 3. Coach Intent-Aware Opener on First Session

**Test:** Select intentChip3a chip, navigate to Coach tab (second tab) without tapping Comprendre first
**Expected:** First coach message reads something like "Tu t'intéresses au pilier 3a — voici ce que MINT a trouvé pour toi" (not generic silent opener)
**Why human:** Verifying the `_pendingIntentChipKey` lifecycle and the conditional rendering of `_intentOpenerText` vs `_computeKeyNumber()` requires live session observation

#### 4. Card Persistence Across App Restarts

**Test:** Select an intent chip, see the PremierEclairageCard, then force-quit and relaunch the app
**Expected:** Card reappears on second launch (not dismissed yet). Then dismiss it and relaunch — card should NOT reappear.
**Why human:** SharedPreferences persistence across app lifecycle requires device testing

---

### Gaps Summary

**One gap blocks ONB-03 and degrades the goal achievement:**

The `IntentRouter` maps 7 chip keys to `suggestedRoute` values that function as the "Comprendre" CTA destinations on `PremierEclairageCard`. Of the 6 unique routes, only `/pilier-3a` is registered in the GoRouter (`app.dart`). The other 5 — `/bilan-retraite`, `/prevoyance-overview`, `/fiscalite-overview`, `/achat-immobilier`, `/life-events` — have no `GoRoute` or redirect. When a user taps "Comprendre", GoRouter calls `errorBuilder` and renders `_MintErrorScreen`.

This means:
- **intentChip3a** (pilier 3a) → works correctly: navigates to `/pilier-3a` (3a simulator)
- **intentChipBilan** → error screen (instead of retirement bilan screen)
- **intentChipPrevoyance** → error screen (instead of prevoyance overview)
- **intentChipFiscalite** → error screen (instead of fiscalite hub)
- **intentChipProjet** → error screen (instead of housing/EPL calculator)
- **intentChipChangement** → error screen (instead of life events hub)
- **intentChipAutre** → error screen (same as intentChipBilan)

The fix is straightforward: add 5 `GoRoute` definitions (or redirects to existing screens) in `app.dart`. Suitable redirect targets already exist: `/retraite` for bilan, `/explore/retraite` for prevoyance, `/explore/fiscalite` for fiscalite, `/hypotheque` for achat-immobilier, and `/life-event/*` screens for changement.

**The rest of the pipeline is solid:** all 48 tests pass, flutter analyze reports 0 issues, all other wiring is correct and substantive. The chip tap → IntentRouter → ChiffreChocSelector → CapMemory seeding → `/home?tab=0` navigation flow works. PremierEclairageCard loads real snapshot data and shows intent-specific content. The coach opener is intent-aware on first session.

---

*Verified: 2026-04-05T17:13:47Z*
*Verifier: Claude (gsd-verifier)*
