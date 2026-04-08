# Plan: Onboarding Intent Screen

## Context
Replace the old form-based onboarding (Quick Start / Smart Onboarding) with an intent-based entry screen. User taps a situation chip → opens coach chat with `CoachEntryPayload` → coach responds via 4-layer engine. No data collection before first conversation turn.

## Architecture
```
Landing (existing) → CTA "Commencer" → /onboarding/intent (NEW)
IntentScreen → tap chip → /home?tab=1 via CoachEntryPayload
```

Payload flow (existing, no changes needed):
```
CoachEntryPayload → MainNavigationShell._switchToCoachWithPayload()
→ CoachEntryPayloadProvider → MintCoachTab → CoachChatScreen
→ append to memoryBlock (one-shot) → backend coach prompt
```

## Steps

### Step 1: Add i18n keys to all 6 ARB files
Add 10 new keys to each of the 6 ARB files (`app_fr.arb`, `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb`):
- `intentScreenTitle`: "Qu'est-ce qui t'amène ?"
- `intentScreenSubtitle`: "Choisis ce qui ressemble le plus à ta situation. On commence là."
- `intentScreenMicrocopy`: "Tu pourras reformuler ensuite avec tes mots."
- `intentChip3a`: "On m'a proposé un 3a"
- `intentChipBilan`: "Je veux voir où j'en suis"
- `intentChipPrevoyance`: "Je comprends mal ma prévoyance"
- `intentChipFiscalite`: "Je veux payer moins bêtement"
- `intentChipProjet`: "J'ai un projet"
- `intentChipChangement`: "Ma situation change"
- `intentChipAutre`: "Autre…"

Run `flutter gen-l10n` after.

### Step 2: Add `onboardingIntent` source to CoachEntrySource enum
File: `apps/mobile/lib/models/coach_entry_payload.dart`

Add a new enum value:
```dart
/// User selected an intent chip on the onboarding intent screen.
onboardingIntent,
```

### Step 3: Create IntentScreen widget
File: `apps/mobile/lib/screens/onboarding/intent_screen.dart` (NEW)

Design:
- `StatelessWidget` (no state needed — just 7 taps)
- Background: `MintColors.porcelaine` (warm off-white, matches landing)
- Hero section: title (headlineLarge) + subtitle (bodyLarge, textSecondary)
- 7 chips as `MintSurface` cards in a `Column`, each with:
  - Text in `bodyLarge` style
  - Ink ripple on tap
  - Full width, generous padding (MintSpacing.md vertical, MintSpacing.lg horizontal)
- Microcopy at bottom (bodySmall, textMuted)
- Wrapped in `SafeArea` + `SingleChildScrollView` + `ConstrainedBox(maxWidth: 480)`
- All strings via `AppLocalizations`

On chip tap:
- Create `CoachEntryPayload(source: CoachEntrySource.onboardingIntent, topic: chipTopic)`
- Topics: `'pillar3a'`, `'financialBilan'`, `'prevoyance'`, `'fiscalite'`, `'projet'`, `'changement'`, `null` (for Autre)
- For "Autre…": `CoachEntryPayload(source: onboardingIntent, userMessage: '')` — coach sees empty message, responds with "Vas-y avec tes mots."
- Navigate: `context.read<CoachEntryPayloadProvider>().setPayload(payload)` then `context.go('/home?tab=1')`
- Mark mini onboarding as completed via `ReportPersistenceService` so user doesn't loop back

### Step 4: Add `/onboarding/intent` route
File: `apps/mobile/lib/app.dart`

Add route between existing onboarding routes (after line 869):
```dart
GoRoute(
  path: '/onboarding/intent',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) => const IntentScreen(),
),
```

### Step 5: Redirect Landing CTA to IntentScreen
File: `apps/mobile/lib/screens/landing_screen.dart`

In `_onCtaTap()` (line 85-101): change the fallback navigation from `/onboarding/quick` to `/onboarding/intent`.

### Step 6: Redirect legacy routes
File: `apps/mobile/lib/app.dart`

Update redirects (lines 958-966):
- `/onboarding/smart` → `/onboarding/intent` (was `/onboarding/quick`)
- `/onboarding/minimal` → `/onboarding/intent` (was `/onboarding/quick`)
- `/advisor/wizard` → `/onboarding/intent` (was `/onboarding/quick`)

Keep `/onboarding/quick` as a direct route (legacy fallback, not deleted).

### Step 7: Update secondary CTAs pointing to /onboarding/quick
Files to update (change `/onboarding/quick` to `/onboarding/intent`):
- `apps/mobile/lib/screens/pulse/pulse_screen.dart` (~line 979)
- `apps/mobile/lib/screens/profile/financial_summary_screen.dart` (~line 326)
- `apps/mobile/lib/screens/budget/budget_screen.dart` (~line 241)
- `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart` (~line 905)
- `apps/mobile/lib/widgets/coach/coach_empty_state.dart` (~line 63)
- `apps/mobile/lib/screens/explore/retraite_hub_screen.dart` (~line 73)
- Any others found via grep for `/onboarding/quick`

Note: Some of these are "complete your profile" CTAs where `/onboarding/quick` (with its form fields) is the right destination. These should be evaluated case-by-case — profile completion CTAs may stay pointing to `/onboarding/quick`.

### Step 8: Update coach system prompt for intent topics
File: `services/backend/app/services/claude_coach_service.py`

No changes needed to the prompt builder — the `CoachEntryPayload.toContextInjection()` already produces a `--- CONTEXTE D'ENTRÉE ---` block with the topic. The coach LLM will handle the topic naturally with its existing system prompt + MINT_IDENTITY principles.

However, verify that the `toContextInjection()` output for new topics like `'financialBilan'` and `'prevoyance'` produces good coach responses by testing manually.

### Step 9: Write tests
File: `apps/mobile/test/screens/onboarding/intent_screen_test.dart` (NEW)

Test cases:
1. All 7 chips render with correct i18n text
2. Tapping each chip creates correct `CoachEntryPayload` (source + topic)
3. Tapping "Autre…" creates payload with null topic
4. Navigation fires to `/home?tab=1` after tap
5. Screen renders within `ConstrainedBox(maxWidth: 480)`
6. All text comes from `AppLocalizations` (no hardcoded strings)

### Step 10: Run flutter analyze + flutter test
- `flutter analyze` must show 0 issues
- `flutter test` must pass all existing + new tests
- Zero regressions

## Files touched (estimated: 10-12)
- NEW: `apps/mobile/lib/screens/onboarding/intent_screen.dart`
- NEW: `apps/mobile/test/screens/onboarding/intent_screen_test.dart`
- EDIT: `apps/mobile/lib/models/coach_entry_payload.dart` (1 enum value)
- EDIT: `apps/mobile/lib/app.dart` (1 route + 3 redirects)
- EDIT: `apps/mobile/lib/screens/landing_screen.dart` (1 CTA redirect)
- EDIT: 6 ARB files (10 keys each)
- EDIT: 3-5 secondary screens (CTA redirects, case-by-case)

## What is NOT in this plan
- Landing screen redesign (stays as-is)
- Deleting Quick Start / Smart Onboarding (kept as legacy)
- Custom animations / transitions
- Dynamic chips (primo vs returning user)
- Structured premier éclairage visual blocks (coach handles via text)
- Backend changes (existing pipeline handles new topics)
