# Phase 03: Onboarding Pipeline - Research

**Researched:** 2026-04-05
**Domain:** Flutter onboarding wiring — intent routing, premier eclairage card, CapSequenceEngine seeding, coach opener
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `intent_router.dart` in `lib/services/coach/` — static const mapping of 7 chip keys to goalIntentTag + stressType + suggestedRoute + lifeEventFamily
- **D-02:** Intent chip → goal family mapping (verbatim from CONTEXT.md):
  - `intentChip3a` → `budget_overview` / `stress_budget` / `/pilier-3a`
  - `intentChipBilan` → `retirement_choice` / `stress_retraite` / `/bilan-retraite`
  - `intentChipPrevoyance` → `retirement_choice` / `stress_retraite` / `/prevoyance-overview`
  - `intentChipFiscalite` → `budget_overview` / `stress_impots` / `/fiscalite-overview`
  - `intentChipProjet` → `housing_purchase` / `stress_patrimoine` / `/achat-immobilier`
  - `intentChipChangement` → `budget_overview` / `stress_budget` / `/life-events`
  - `intentChipAutre` → `retirement_choice` / `stress_retraite` / `/bilan-retraite` (fallback)
- **D-03:** After chip tap: persist intent, write goalIntentTag to CapMemoryStore.declaredGoals, compute premier eclairage via ChiffreChocSelector, navigate to `/home?tab=0` (not tab=1)
- **D-04:** `PremierEclairageCard` widget as Section 0 on MintHomeScreen, first visit only. Shows ChiffreChoc value, title, subtitle, CTA "Comprendre" → suggestedRoute. Auto-dismisses after user explores ≥1 simulator.
- **D-05:** After intent mapping, call CapSequenceEngine.build() with mapped goalIntentTag, store in CapMemoryStore
- **D-06:** Replace generic `_computeKeyNumber()` silent opener in CoachChatScreen with intent-aware opener when `selectedOnboardingIntent` is non-null
- **D-07:** firstJob and housingPurchase intents must show different premier eclairage numbers and CTA destinations
- **D-08:** MinimalProfile fallback: ChiffreChocSelector already supports `confidenceMode: pedagogical` for no-salary case
- **D-09:** `hasSeenPremierEclairage` flag in SharedPreferences — card and intent-aware opener only on first session

### Claude's Discretion

- Exact wording of coach opener messages per intent
- Animation/transition style for PremierEclairageCard
- Whether to show a skeleton/loading state while ChiffreChocSelector computes
- Error handling if ChiffreChocSelector returns null (fallback to generic welcome)

### Deferred Ideas (OUT OF SCOPE)

- Cross-device intent sync (CapMemoryStore TODO at line 21) → Phase 5 or later
- Intent revision (letting users change their intent after onboarding) → Phase 7 UX
- A/B testing different premier eclairage presentations → post-launch
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ONB-01 | User completes intent selection and sees first personalized insight (premier eclairage) within 3 minutes | ChiffreChocSelector is synchronous (<100ms). All wiring is in-process. No network required. |
| ONB-02 | IntentScreen selection triggers CapSequenceEngine to generate relevant first journey | CapSequenceEngine.build() is synchronous, pure function. Needs goalIntentTag from IntentRouter. |
| ONB-03 | JourneyTrigger connects onboarding intent to appropriate calculator/insight flow | IntentRouter.suggestedRoute maps to GoRouter paths. PremierEclairageCard CTA navigates directly. |
| ONB-04 | Post-onboarding landing is contextual (based on selected intent), not generic home screen | PremierEclairageCard as Section 0 reads from CapMemoryStore.declaredGoals or SharedPreferences. |
</phase_requirements>

---

## Summary

Phase 3 is a wiring phase, not a feature-invention phase. All computation components exist and are tested. The gap is the integration layer: nothing currently bridges the IntentScreen chip tap to the MintHomeScreen content. The three missing wires are:

1. **IntentRouter** — a static mapping from the 7 ARB chip keys to goalIntentTag, stressType, suggestedRoute, and lifeEventFamily. Does not exist yet.
2. **PremierEclairageCard** — a new widget that reads the persisted premier eclairage from SharedPreferences and renders Section 0 on MintHomeScreen on first visit. Does not exist yet.
3. **Intent-aware coach opener** — modification to `_addInitialGreeting()` in CoachChatScreen to detect a pending `selectedOnboardingIntent` and produce a non-generic opener. Exists as a generic silent opener; needs intent conditioning.

The core challenge is correctly threading async state (ChiffreChocSelector.select() needs a MinimalProfileResult, but the profile may not exist at chip-tap time) and managing the one-shot display lifecycle for the PremierEclairageCard.

**Primary recommendation:** Wire in three sequential tasks: (1) create IntentRouter, (2) plumb it into IntentScreen._onChipTap() to compute and persist the premier eclairage, (3) add PremierEclairageCard to MintHomeScreen.

---

## Standard Stack

### Core (all already in pubspec — verified by codebase grep)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `shared_preferences` | project version | Persist `hasSeenPremierEclairage`, `selectedOnboardingIntent` | Already used for all onboarding flags in `ReportPersistenceService` [VERIFIED: codebase] |
| `go_router` | project version | Navigate from chip tap to `/home?tab=0` and from PremierEclairageCard CTA to `/pilier-3a` etc. | Project-standard navigation [VERIFIED: codebase] |
| `provider` | project version | Read `MintStateProvider` and `UserActivityProvider` in MintHomeScreen | Project-standard state [VERIFIED: codebase] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ChiffreChocSelector` | internal | Compute premier eclairage from MinimalProfileResult | Called at chip tap time with mapped stressType |
| `CapSequenceEngine` | internal | Build first journey sequence from goalIntentTag | Called at chip tap time; result stored in CapMemoryStore |
| `CapMemoryStore` | internal | Persist declaredGoals across sessions | Called in IntentScreen._onChipTap() after mapping |

**No new dependencies needed.** All required libraries are already in `pubspec.yaml`.

---

## Architecture Patterns

### Recommended Project Structure

```
lib/services/coach/
  intent_router.dart           # NEW — static const map (D-01)

lib/widgets/home/
  premier_eclairage_card.dart  # NEW — Section 0 widget (D-04)

lib/screens/onboarding/
  intent_screen.dart           # MODIFY — _onChipTap plumbing (D-03, D-05)

lib/screens/main_tabs/
  mint_home_screen.dart        # MODIFY — add Section 0 (D-04)

lib/screens/coach/
  coach_chat_screen.dart       # MODIFY — intent-aware opener (D-06)

lib/services/
  report_persistence_service.dart  # MODIFY — add hasSeenPremierEclairage flag (D-09)
```

### Pattern 1: IntentRouter — Static Const Map

**What:** A pure Dart class with a single static const map and a lookup method. No instantiation.
**When to use:** Called at chip-tap time to translate chip label key to goalIntentTag, stressType, and suggestedRoute.

**Key design constraint:** The ARB chip keys are localized strings (e.g., `"On m'a proposé un 3a"`), but the IntentRouter must be keyed on the ARB key identifiers (e.g., `intentChip3a`), not the resolved strings. The IntentScreen currently passes `chip.label` (the resolved string) to `ReportPersistenceService.setSelectedOnboardingIntent()`. This is the critical translation gap.

**Approach:** Add a `chipKey` field alongside `label` on `_IntentChip` in `IntentScreen`, storing the ARB key name as a constant string. IntentRouter is then keyed on these constants.

```dart
// Source: CONTEXT.md D-01 decision
// File: lib/services/coach/intent_router.dart
class IntentMapping {
  final String goalIntentTag;
  final String stressType;
  final String suggestedRoute;
  final String lifeEventFamily;
  const IntentMapping({...});
}

class IntentRouter {
  IntentRouter._();

  static const Map<String, IntentMapping> _map = {
    'intentChip3a': IntentMapping(
      goalIntentTag: 'budget_overview',
      stressType: 'stress_budget',
      suggestedRoute: '/pilier-3a',
      lifeEventFamily: 'professionnel',
    ),
    // ... 6 more entries per D-02
  };

  static IntentMapping? forChipKey(String chipKey) => _map[chipKey];
}
```

### Pattern 2: PremierEclairageCard as Section 0

**What:** Stateful widget added conditionally at position 0 in MintHomeScreen's SliverChildListDelegate, gated by a SharedPreferences flag and UserActivityProvider.
**When to use:** Only on first session after onboarding (before the user has explored ≥1 simulator).

**Display lifecycle:**
1. On first home visit after intent selection: `hasSeenPremierEclairage` is false → show card
2. When user taps "Comprendre" CTA or explores ≥1 simulator → set `hasSeenPremierEclairage = true` → card disappears
3. On subsequent sessions: flag is true → card never shown

**Data source for card:** The premier eclairage data (value, title, subtitle, colorKey, suggestedRoute) must be persisted to SharedPreferences during the chip tap (not recomputed at render time), because the card renders asynchronously and the MinimalProfileResult used during onboarding may not be available on home screen render.

**Persistence strategy:** Add a new `PremierEclairageSnapshot` serialized to SharedPreferences during `_onChipTap`. The card reads this snapshot on load.

```dart
// Added to ReportPersistenceService:
static const String _premierEclairageKey = 'premier_eclairage_snapshot_v1';
static const String _hasSeenPremierEclairageKey = 'has_seen_premier_eclairage_v1';

static Future<void> savePremierEclairageSnapshot(Map<String, dynamic> data) async {...}
static Future<Map<String, dynamic>?> loadPremierEclairageSnapshot() async {...}
static Future<bool> hasSeenPremierEclairage() async {...}
static Future<void> markPremierEclairagelSeen() async {...}
```

### Pattern 3: Intent-Aware Coach Opener

**What:** Modification to `_addInitialGreeting()` in CoachChatScreen. When `selectedOnboardingIntent` is non-null AND `hasSeenPremierEclairage` is false (first session), display an intent-specific opener text instead of the generic silent number.

**Current behavior:** `_addInitialGreeting()` sets `_showSilentOpener = true` and calls `_computeKeyNumber()` to derive a retirement-focused number. This runs regardless of how the user arrived.

**New behavior:** Load `selectedOnboardingIntent` asynchronously in `_loadOnboardingPayload()`. If present and first session, use an intent-specific opener template (from D-06 discretion area). Store the opener as local state. The silent opener widget reads this state.

**Key constraint:** `_addInitialGreeting()` is synchronous; the intent loading is async. The current pattern already handles this by loading onboarding payload in a separate async method and using setState. The same pattern applies.

### Pattern 4: CapMemoryStore.declaredGoals Seeding

**What:** At chip-tap time, load current CapMemory, add the goalIntentTag to `declaredGoals`, and save.
**When to use:** Only when chip is tapped (not on app resume). This seeds the MintStateEngine's goal detection so the lever section (Section 2) shows a sequence plan immediately.

**The async chain in _onChipTap (revised):**
```
1. IntentRouter.forChipKey(chipKey)        → IntentMapping (sync)
2. ChiffreChocSelector.select(profile, stressType: mapping.stressType)  → ChiffreChoc (sync, if profile exists)
3. ReportPersistenceService.savePremierEclairageSnapshot(snapshot)      → (async)
4. ReportPersistenceService.setSelectedOnboardingIntent(chipKey)         → (async)
5. CapMemoryStore.load()                                                 → (async)
6. CapMemoryStore.save(memory.copyWith(declaredGoals: [mapping.goalIntentTag])) → (async)
7. context.go('/home?tab=0')
```

### Anti-Patterns to Avoid

- **Keying IntentRouter on resolved strings:** The ARB chip label strings are locale-dependent and will break on other languages. Always key on the ARB identifier constant (e.g., `'intentChip3a'`).
- **Recomputing ChiffreChoc on home screen render:** ChiffreChocSelector needs MinimalProfileResult which requires a QuickStart profile. At home render time, only CoachProfile is available (different model). Compute and persist the snapshot during chip tap instead.
- **Blocking navigation on async operations:** Steps 2-6 above are async but should not block navigation. Use `unawaited()` or run async work before navigating, but keep the UI responsive. The current pattern in `_onChipTap` already does `await` then `context.go` — follow this pattern.
- **Showing PremierEclairageCard to returning users:** Must check `hasSeenPremierEclairage` flag in SharedPreferences, not just `selectedOnboardingIntent`. The intent persists across sessions; the card must not reappear.
- **Using Navigator.push instead of context.go:** Project mandate — all navigation via GoRouter.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swiss CHF number formatting | Custom formatter | `chf_formatter.dart` (already imported by ChiffreChocSelector) | Already handles apostrophe-separated thousands [VERIFIED: codebase] |
| Goal-to-journey mapping | New CapEngine variant | `CapSequenceEngine.build()` with existing goalIntentTag values | Pure function, 0 deps, 60+ tests already passing [VERIFIED: codebase] |
| First-visit detection | Custom session counter | `UserActivityProvider.exploredSimulators.isEmpty` (already used by MintHomeScreen `_shouldShowLever`) | Existing pattern for exactly this condition [VERIFIED: codebase] |
| Intent persistence | New service | `ReportPersistenceService.setSelectedOnboardingIntent()` | Already implemented and called in IntentScreen [VERIFIED: codebase] |
| Compliance disclaimer on insights | Custom text | `chiffreChocDisclaimer` ARB key | Already defined, used by existing ChiffreChoc widgets [VERIFIED: codebase] |

**Key insight:** The computation layer is complete. The value gap is entirely in the UI wiring and persistence bridge between the onboarding flow and the home screen.

---

## Common Pitfalls

### Pitfall 1: Missing MinimalProfileResult at Chip Tap Time

**What goes wrong:** `ChiffreChocSelector.select()` requires `MinimalProfileResult`, but this model is produced by the Quick Start wizard backend call. If the user has not completed Quick Start (only intent selection, no age/salary/canton), the profile is null.
**Why it happens:** IntentScreen is the first screen — no profile exists yet. The user may select an intent before completing profile data.
**How to avoid:** Per D-08, ChiffreChocSelector.select() with a minimal empty MinimalProfileResult returns a pedagogical-mode ChiffreChoc (confidence mode set to `pedagogical`). The `_withConfidence()` method handles this. Construct a zero-valued MinimalProfileResult when no real profile exists; the selector's lifecycle fallback path will produce a safe pedagogical number.
**Warning signs:** Null pointer exceptions in ChiffreChocSelector during integration test of fresh-install flow.

### Pitfall 2: ARB Key vs Resolved String Mismatch in IntentRouter

**What goes wrong:** IntentRouter stores mappings keyed by the ARB constant name (e.g., `'intentChip3a'`), but ReportPersistenceService currently stores the resolved French string (e.g., `"On m'a proposé un 3a"`).
**Why it happens:** IntentScreen._onChipTap() currently calls `setSelectedOnboardingIntent(chip.label)` — the resolved localized string. IntentRouter lookup will fail with a localized string key.
**How to avoid:** Add a `chipKey` field to `_IntentChip` data class (the ARB key identifier as a const string). Store `chipKey` (not `label`) in persistence. IntentRouter is keyed on `chipKey`.
**Warning signs:** IntentRouter.forChipKey() returning null for all chips in testing.

### Pitfall 3: PremierEclairageCard Persisting Across Sessions

**What goes wrong:** Card reappears on app relaunch even after user has explored the app.
**Why it happens:** `selectedOnboardingIntent` persists permanently (by design, for coach context). If the card is gated only on `selectedOnboardingIntent != null`, it will re-display on every cold launch.
**How to avoid:** Gate on `hasSeenPremierEclairage` (separate boolean flag). Mark as seen when user taps "Comprendre" OR when `UserActivityProvider.exploredSimulators.isNotEmpty` is detected (same condition as lever unlock in MintHomeScreen).
**Warning signs:** Card appearing for users who have already explored the app in regression testing.

### Pitfall 4: ChiffreChoc Snapshot Stale After Profile Update

**What goes wrong:** User completes onboarding intent, then immediately completes Quick Start wizard. The home screen shows the pedagogical-mode snapshot (low confidence, Swiss-average estimate) instead of the newly personalized number.
**Why it happens:** The snapshot is written once at chip-tap time. If profile data arrives seconds later via Quick Start, the snapshot is not updated.
**How to avoid:** Add logic to `PremierEclairageCard` to recompute the ChiffreChoc from fresh profile data if `MintStateProvider.confidenceScore` has improved since the snapshot was taken. OR, simpler: display the snapshot initially but show a "Mise à jour" badge if confidence has improved significantly. The CONTEXT.md specifies no explicit handling — use a recompute-on-high-confidence approach (confidence > 40 → recompute).
**Warning signs:** Users seeing "Swiss average" numbers even after completing profile setup.

### Pitfall 5: CapSequenceEngine.build() Requires `S` (l10n) Instance

**What goes wrong:** CapSequenceEngine.build() has a required `S l` parameter. Calling it from `_onChipTap()` (a non-widget async method) requires an `S` instance from context.
**Why it happens:** The `S l` parameter was added to enforce i18n contract. But async methods called after `context.go()` cannot safely access context.
**How to avoid:** Capture `S.of(context)!` before the await chain in `_onChipTap()`. The current intent screen already uses context-safe patterns (`if (!context.mounted) return`). Capture `l10n` before any await, pass it to CapSequenceEngine.build(). The engine only stores ARB key strings (not resolved labels), so the French fallback instance (`SFr()`) is also valid for non-widget callers (same pattern as MintStateEngine.compute()).
**Warning signs:** `CapSequenceEngine.build()` called with a stale context after navigation.

### Pitfall 6: Coach Opener Firing on Every Session

**What goes wrong:** Intent-aware coach opener shows on the 5th session because `selectedOnboardingIntent` is non-null.
**Why it happens:** `selectedOnboardingIntent` persists permanently for coach context. Without a separate one-shot flag, the opener fires whenever the coach is opened.
**How to avoid:** Gate the intent-aware opener on `hasSeenPremierEclairage == false` (same flag as the card). Once the card is dismissed, the opener reverts to the normal silent opener.
**Warning signs:** Returning users seeing onboarding-style messages in coach chat.

---

## Code Examples

### ChiffreChocSelector.select() Call at Chip Tap

```dart
// Source: apps/mobile/lib/services/chiffre_choc_selector.dart (verified)
// Pattern: call with stressType from IntentRouter, MinimalProfileResult from profile or empty
final choc = ChiffreChocSelector.select(
  minimalProfile,
  stressType: mapping.stressType,  // e.g. 'stress_budget'
);
// Returns ChiffreChoc with .value, .title, .subtitle, .colorKey, .confidenceMode
```

### CapMemoryStore.save() Pattern

```dart
// Source: apps/mobile/lib/services/cap_memory_store.dart (verified)
final memory = await CapMemoryStore.load();
final updated = memory.copyWith(
  declaredGoals: [mapping.goalIntentTag], // replaces existing list
);
await CapMemoryStore.save(updated);
```

### MintHomeScreen Section Insertion Pattern

```dart
// Source: apps/mobile/lib/screens/main_tabs/mint_home_screen.dart (verified)
// Pattern for conditional Section 0 insertion:
SliverChildListDelegate([
  const SizedBox(height: MintSpacing.sm),
  Align(alignment: Alignment.centerRight, child: /* profile button */),
  const SizedBox(height: MintSpacing.md),

  // ── Section 0: Premier Eclairage Card (first visit only) ──
  if (_shouldShowPremierEclairage())
    Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xl),
      child: PremierEclairageCard(
        onDismiss: _markPremierEclairaireeSeen,
        onNavigate: (route) => context.go(route),
      ),
    ),

  // ── Section 1: Chiffre Vivant GPS ──
  _ChiffreVivantCard(...)
  // ... rest unchanged
])
```

### ReportPersistenceService New Keys Pattern

```dart
// Source: apps/mobile/lib/services/report_persistence_service.dart (verified)
// Existing pattern for new keys — add at top of MINI-ONBOARDING PERSISTENCE block
static const String _hasSeenPremierEclairageKey = 'has_seen_premier_eclairage_v1';
static const String _premierEclairageSnapshotKey = 'premier_eclairage_snapshot_v1';

static Future<bool> hasSeenPremierEclairage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hasSeenPremierEclairageKey) ?? false;
}

static Future<void> markPremierEclairageSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hasSeenPremierEclairageKey, true);
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Generic silent opener (any entry) | Intent-aware opener seeded from chip selection | Phase 3 (this work) | First coach message is contextual, not generic |
| Tab 1 (Coach) as post-onboarding landing | Tab 0 (Aujourd'hui) with PremierEclairageCard | Phase 3 (this work) | User sees a concrete number before chat |
| CapSequence seeded by explicit goal picker | CapSequence seeded at onboarding | Phase 3 (this work) | Lever in Section 2 visible on first home visit |

**Deprecated/outdated:**
- `intentChipAutre` → null userMessage: the current code passes null and the coach shows a "silent opener" — the new intent-aware opener must also handle this gracefully (fall back to generic when chipKey = 'intentChipAutre')

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | MinimalProfileResult can be constructed with all-zero values to produce a valid pedagogical ChiffreChoc for users with no profile | Pitfall 1 | ChiffreChocSelector might crash on zero-salary input; needs test validation |
| A2 | `SFr()` (French fallback l10n) is valid for CapSequenceEngine.build() called from IntentScreen._onChipTap() | Pitfall 5 | If the engine uses l10n strings at build time (not just stores keys), the French fallback may produce wrong labels |
| A3 | `clearDiagnostic()` in ReportPersistenceService should also clear `hasSeenPremierEclairage` and `premierEclairageSnapshot` | Code Examples | If not cleared on reset, test user resets will leave stale card state |

**All assumptions are low-risk and resolvable with targeted unit tests.**

---

## Open Questions

1. **Zero-profile MinimalProfileResult construction**
   - What we know: ChiffreChocSelector.select() handles all cases in its lifecycle fallback path
   - What's unclear: What happens when `grossMonthlySalary == 0` and `taxSaving3a == 0` — does the lifecycle fallback produce a sensible result or panic?
   - Recommendation: Add one unit test for zero-valued MinimalProfileResult before implementing chip-tap plumbing

2. **PremierEclairageCard recompute threshold**
   - What we know: CONTEXT.md D-08 says "show generic Swiss-average with prompt to complete profile"
   - What's unclear: Should the card auto-update to a personalized number if the user completes Quick Start before dismissing the card?
   - Recommendation: At discretion — implement recompute if `confidenceScore > 40` (same threshold as `_kMinConfidenceForProjections = 30`)

3. **ARB keys for PremierEclairageCard UI copy**
   - What we know: 6 new user-facing strings needed: card title label, "Comprendre" CTA text, confidence disclaimer, dismiss gesture hint, skeleton loading text, profile-completion prompt
   - What's unclear: Whether these should reuse existing `chiffreChocDisclaimer` etc. or be new keys
   - Recommendation: Reuse `chiffreChocDisclaimer` for the legal text; create 2-3 new specific keys for the card's structural copy

---

## Environment Availability

Step 2.6: SKIPPED — phase is purely Flutter code/widget wiring with no external dependencies beyond the existing project stack.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (project standard) |
| Config file | `apps/mobile/pubspec.yaml` (flutter_test dependency) |
| Quick run command | `flutter test test/services/intent_router_test.dart -x` (in `apps/mobile/`) |
| Full suite command | `flutter test` (in `apps/mobile/`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ONB-01 | ChiffreChocSelector produces non-null result for each of 7 mapped stressTypes | unit | `flutter test test/services/intent_router_test.dart` | ❌ Wave 0 |
| ONB-01 | Premier eclairage snapshot persists and is readable | unit | `flutter test test/services/report_persistence_service_test.dart` | ❌ Wave 0 |
| ONB-02 | CapSequenceEngine.build() produces non-empty sequence for all 3 goalIntentTags | unit | `flutter test test/services/cap_sequence_engine_test.dart` | ✅ exists |
| ONB-02 | CapMemoryStore.declaredGoals is written on intent selection | unit | `flutter test test/services/intent_router_test.dart` | ❌ Wave 0 |
| ONB-03 | PremierEclairageCard CTA navigates to mapped suggestedRoute | widget | `flutter test test/widgets/premier_eclairage_card_test.dart` | ❌ Wave 0 |
| ONB-03 | All 7 chip keys map to valid GoRouter routes (non-null, non-empty) | unit | `flutter test test/services/intent_router_test.dart` | ❌ Wave 0 |
| ONB-04 | MintHomeScreen shows PremierEclairageCard when hasSeenPremierEclairage=false | widget | `flutter test test/screens/mint_home_screen_test.dart` | ❌ Wave 0 |
| ONB-04 | MintHomeScreen hides PremierEclairageCard when hasSeenPremierEclairage=true | widget | `flutter test test/screens/mint_home_screen_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/intent_router_test.dart test/widgets/premier_eclairage_card_test.dart -x`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` (0 issues) + `flutter test` (all green) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/intent_router_test.dart` — covers ONB-01 (all 7 mappings), ONB-02 (goalIntentTag values), ONB-03 (route validity)
- [ ] `test/services/report_persistence_service_test.dart` — covers `savePremierEclairageSnapshot`, `hasSeenPremierEclairage`, `markPremierEclairageSeen` (new methods)
- [ ] `test/widgets/premier_eclairage_card_test.dart` — covers ONB-03 (CTA tap), ONB-04 (visibility logic)
- [ ] `test/screens/mint_home_screen_test.dart` — covers ONB-04 (Section 0 conditional rendering)

*(Existing `test/services/cap_sequence_engine_test.dart` covers ONB-02 partially — no new tests needed there)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | yes | ChiffreChocSelector handles null/zero inputs; intent chip key validated against static map |
| V6 Cryptography | no | n/a |

### Known Threat Patterns for Flutter onboarding state

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Intent key injection (tampered SharedPreferences) | Tampering | IntentRouter returns null for unknown keys; null-safe fallback to generic welcome |
| PII in premier eclairage snapshot (e.g., salary stored in prefs) | Information Disclosure | Store only the ChiffreChoc display fields (value, title, subtitle, colorKey, route) — never raw salary or IBAN |

**Compliance note:** The PremierEclairageCard must include the `chiffreChocDisclaimer` ARB text ("Outil éducatif — ne constitue pas un conseil financier (LSFin)"). This is mandatory per CLAUDE.md §6 — "Required in Every Calculator/Service Output."

---

## Sources

### Primary (HIGH confidence)

- `apps/mobile/lib/screens/onboarding/intent_screen.dart` — current IntentScreen implementation, `_onChipTap` method, chip data structure [VERIFIED: codebase]
- `apps/mobile/lib/services/chiffre_choc_selector.dart` — full selector implementation including stressType routing and pedagogical confidence mode [VERIFIED: codebase]
- `apps/mobile/lib/services/cap_sequence_engine.dart` — CapSequenceEngine.build() API, goalIntentTag constants, S l parameter [VERIFIED: codebase]
- `apps/mobile/lib/services/cap_memory_store.dart` — CapMemory model, CapMemoryStore.save(), declaredGoals field [VERIFIED: codebase]
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — Section structure, _shouldShowLever() pattern, UserActivityProvider usage [VERIFIED: codebase]
- `apps/mobile/lib/services/report_persistence_service.dart` — existing persistence keys, `setSelectedOnboardingIntent()`, `getSelectedOnboardingIntent()`, `clearDiagnostic()` [VERIFIED: codebase]
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — `_addInitialGreeting()`, `_computeKeyNumber()`, `_loadOnboardingPayload()` [VERIFIED: codebase]
- `apps/mobile/lib/models/coach_entry_payload.dart` — CoachEntryPayload, CoachEntrySource.onboardingIntent [VERIFIED: codebase]
- `apps/mobile/lib/l10n/app_fr.arb` — intentChip* key values, chiffreChocDisclaimer key [VERIFIED: codebase]
- `.planning/phases/03-onboarding-pipeline/03-CONTEXT.md` — locked decisions D-01 through D-09 [VERIFIED: file]

### Secondary (MEDIUM confidence)

- `apps/mobile/lib/services/mint_state_engine.dart` — declaredGoals priority in goal resolution (MintStateEngine.compute() lines 117-132) confirms writing to CapMemory.declaredGoals is the correct integration point [VERIFIED: codebase]
- `apps/mobile/lib/providers/user_activity_provider.dart` — exploredSimulators.isEmpty pattern for first-visit detection [VERIFIED: codebase]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all libraries verified in codebase
- Architecture: HIGH — all integration points verified by reading actual source files
- Pitfalls: HIGH — identified from actual code gaps (localized string vs ARB key, async chain in _onChipTap, first-visit flag separation)

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable Flutter/Dart — no framework version sensitivity)
