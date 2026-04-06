# Phase 4: Moteur d'Anticipation - Research

**Researched:** 2026-04-06
**Domain:** Rule-based financial anticipation engine (Flutter/Dart, local-only)
**Confidence:** HIGH

## Summary

Phase 4 builds a deterministic, rule-based anticipation engine that surfaces timely Swiss financial signals on the Aujourd'hui tab. The engine evaluates triggers at session start (zero LLM cost), validates alerts through ComplianceGuard, and enforces a 2/week frequency cap with dismiss/snooze persistence.

The codebase already contains significant infrastructure that this phase can build upon: `NudgeEngine` (pure stateless trigger evaluator with 10 trigger types), `NudgePersistence` (SharedPreferences-based dismiss/cooldown), `ProactiveTriggerService` (session-level coach triggers with 8 types), `BiographyProvider` (cached facts with freshness decay), and `ComplianceGuard` (5-layer validation pipeline). The main work is: (1) creating an `AnticipationEngine` that combines calendar + profile triggers, (2) adding `ComplianceGuard.validateAlert()` for non-LLM alert text, (3) building the card ranking system with frequency capping, and (4) wiring anticipation cards into `MintHomeScreen`.

**Primary recommendation:** Build the AnticipationEngine as a pure stateless service following the NudgeEngine pattern (static methods, injectable DateTime, no Flutter dependencies). Reuse NudgePersistence for dismiss/snooze state. Add a dedicated `validateAlert()` path to ComplianceGuard that checks banned terms and prescriptive language but skips hallucination detection (alerts are template-based, not LLM-generated).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Rule-based triggers: deterministic, zero LLM cost -- per ANT-08
- Swiss fiscal calendar triggers: 3a deadline (Dec 31), cantonal tax declaration deadlines, LPP rachat windows -- per ANT-01
- Profile-driven triggers: salary increase -> 3a max recalculation, age milestone -> LPP bonification rate change -- per ANT-02
- LLM used only for optional narrative enrichment of alert text (not for trigger logic)
- AlertTemplate enum: Educational format (title + fact + source + simulatorLink) -- per ANT-03
- ComplianceGuard.validateAlert() validates every alert before display -- per ANT-04
- Zero banned terms, zero personalized imperatives ("tu devrais" = blocked)
- Every alert links to relevant simulator or educational content
- Frequency cap: max 2 anticipation signals per user per week on Aujourd'hui -- per ANT-05
- Card ranking: priority_score = timeliness x user_relevance x confidence -- top 2 as cards, rest in expandable section -- per ANT-06
- Dismissal UX: each signal card has "Got it" or "Remind me later" -- snooze logic per trigger type -- per ANT-07

### Claude's Discretion
- Trigger evaluation timing (app launch, session start, background check)
- Specific cantonal tax deadline data source
- Snooze duration per trigger type
- Card ranking weight formula details
- Expandable "See more" section implementation

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ANT-01 | Swiss fiscal calendar triggers: 3a deadline, cantonal tax deadlines, LPP rachat windows | NudgeEngine already has `pillar3aDeadline` and `lppBuybackWindow` triggers; cantonal deadlines need new data map |
| ANT-02 | Profile-driven triggers: salary increase -> 3a recalc, age milestone -> LPP bonification change | BiographyProvider exposes fact history; `lppBonificationsVieillesse` map in social_insurance.dart defines age brackets |
| ANT-03 | AlertTemplate enum with educational format (title + fact + source + simulatorLink) | New model following Nudge pattern (title/body ARB keys + intentTag for deep-link) |
| ANT-04 | ComplianceGuard.validateAlert() validates every alert before display | ComplianceGuard exists with 5-layer pipeline; needs new `validateAlert()` static method |
| ANT-05 | Frequency cap: max 2 anticipation signals per user per week | NudgePersistence pattern available; need weekly counter in SharedPreferences |
| ANT-06 | Card ranking: priority_score = timeliness x user_relevance x confidence | New scoring function; DashboardCuratorService/TemporalPriorityService show existing ranking patterns |
| ANT-07 | Dismissal UX: "Got it" + "Remind me later" with snooze logic | NudgePersistence.dismiss() pattern; needs snooze variant with configurable duration |
| ANT-08 | Triggers are rule-based (zero LLM cost, deterministic) | NudgeEngine is fully pure/deterministic; follow same pattern |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.x | UI framework | Project standard |
| shared_preferences | latest | Dismiss/snooze/frequency persistence | Already used by NudgePersistence, ProactiveTriggerService |
| provider | latest | State management for anticipation cards | Project standard (ChangeNotifier pattern) |
| go_router | latest | Deep-link from alert cards to simulators | Project standard |
| sqflite_sqlcipher | latest | Biography fact storage (read-only for triggers) | Already used by BiographyRepository |

[VERIFIED: codebase grep -- all packages already in pubspec.yaml]

### No New Dependencies Required
This phase requires zero new packages. All infrastructure exists:
- **Trigger evaluation:** Follow NudgeEngine pure static pattern
- **Persistence:** SharedPreferences via NudgePersistence pattern
- **Profile data:** CoachProfile via CoachProfileProvider
- **Biography data:** BiographyFact via BiographyProvider
- **Compliance:** ComplianceGuard (extend with validateAlert)
- **Constants:** social_insurance.dart for LPP bonification brackets, 3a limits
- **Display:** MintSurface, MintEntrance widget patterns on MintHomeScreen

## Architecture Patterns

### Recommended Project Structure
```
lib/
  services/
    anticipation/
      anticipation_engine.dart         # Pure stateless trigger evaluator
      anticipation_trigger.dart        # Enum of all trigger types
      anticipation_signal.dart         # Signal model (title, fact, source, link)
      anticipation_persistence.dart    # Dismiss/snooze/weekly-cap via SharedPreferences
      anticipation_ranking.dart        # priority_score computation
      cantonal_deadlines.dart          # Static map of cantonal tax deadlines
  widgets/
    home/
      anticipation_signal_card.dart    # Card widget for Aujourd'hui tab
      anticipation_expandable.dart     # "See more" section for overflow signals
  providers/
    anticipation_provider.dart         # ChangeNotifier wiring engine + persistence
```
[ASSUMED]

### Pattern 1: Pure Stateless Engine (follow NudgeEngine)
**What:** All trigger evaluation logic in static methods, zero side effects, injectable DateTime for deterministic testing.
**When to use:** Always for the core engine.
**Example:**
```dart
// Source: Existing NudgeEngine pattern in lib/services/nudge/nudge_engine.dart
class AnticipationEngine {
  AnticipationEngine._();

  static List<AnticipationSignal> evaluate({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    required DateTime now,
    required List<String> dismissedIds,
    required int signalsThisWeek,
  }) {
    if (signalsThisWeek >= 2) return []; // ANT-05: weekly cap
    final candidates = <AnticipationSignal>[];
    _check3aDeadline(candidates, now, profile);
    _checkCantonalTaxDeadline(candidates, now, profile);
    _checkLppRachatWindow(candidates, now, profile);
    _checkSalaryIncrease(candidates, now, profile, facts);
    _checkAgeMilestone(candidates, now, profile);
    // ... more triggers
    return _rankAndCap(candidates, dismissedIds, 2 - signalsThisWeek);
  }
}
```
[VERIFIED: matches existing NudgeEngine.evaluate() signature pattern]

### Pattern 2: AlertTemplate Enum with Compliance Validation
**What:** Each alert type is an enum value with associated educational content template. ComplianceGuard validates before display.
**When to use:** For all alert rendering.
**Example:**
```dart
enum AlertTemplate {
  fiscal3aDeadline,
  cantonalTaxDeadline,
  lppRachatWindow,
  salaryIncrease3aRecalc,
  ageMilestoneLppBonification,
}

class AnticipationSignal {
  final String id;
  final AlertTemplate template;
  final String titleKey;    // ARB key
  final String factKey;     // ARB key for the educational fact
  final String sourceRef;   // Legal reference (e.g., "OPP3 art. 7")
  final String simulatorLink; // GoRouter path (e.g., "/pilier-3a")
  final double priorityScore;
  final DateTime expiresAt;
  final Map<String, String>? params; // i18n interpolation
}
```
[ASSUMED -- modeled after existing Nudge class structure]

### Pattern 3: Frequency Cap via SharedPreferences
**What:** Track displayed signals per ISO week. Reset weekly. Cap at 2.
**When to use:** Before rendering any signal on Aujourd'hui.
**Example:**
```dart
class AnticipationPersistence {
  static const _weekCountKey = '_anticipation_week_count';
  static const _weekIdKey = '_anticipation_week_id';
  
  static Future<int> signalsShownThisWeek(SharedPreferences prefs, {DateTime? now}) async {
    final currentWeek = _isoWeekId(now ?? DateTime.now());
    final storedWeek = prefs.getString(_weekIdKey);
    if (storedWeek != currentWeek) return 0; // New week, reset
    return prefs.getInt(_weekCountKey) ?? 0;
  }
  
  static Future<void> recordSignalShown(SharedPreferences prefs, {DateTime? now}) async {
    final currentWeek = _isoWeekId(now ?? DateTime.now());
    final storedWeek = prefs.getString(_weekIdKey);
    if (storedWeek != currentWeek) {
      await prefs.setString(_weekIdKey, currentWeek);
      await prefs.setInt(_weekCountKey, 1);
    } else {
      final count = prefs.getInt(_weekCountKey) ?? 0;
      await prefs.setInt(_weekCountKey, count + 1);
    }
  }
}
```
[ASSUMED -- follows NudgePersistence pattern]

### Pattern 4: Card Ranking Formula
**What:** `priority_score = timeliness * user_relevance * confidence` -- deterministic, pure function.
**When to use:** After trigger evaluation, before display.

**Recommended weights:**
- **timeliness** (0.0-1.0): Inversely proportional to days until deadline. `1.0 - (daysRemaining / maxWindow).clamp(0, 1)`. Signals with no deadline get 0.5 (moderate).
- **user_relevance** (0.0-1.0): Based on profile match. E.g., 3a deadline = 1.0 for salaried, 0.8 for independent (different plafond). Salary increase = 1.0 if salary fact changed in last 30 days.
- **confidence** (0.0-1.0): Data freshness weight from `FreshnessDecayService.weight()`. Stale data = lower confidence in the signal's relevance.

Top 2 by score become visible cards; remaining go into expandable "See more" section.
[ASSUMED -- formula from CONTEXT.md decisions]

### Anti-Patterns to Avoid
- **LLM in trigger evaluation:** Triggers MUST be deterministic. LLM is only for optional narrative enrichment after the trigger fires. [VERIFIED: ANT-08 locked decision]
- **Hardcoded French strings:** ALL card text via ARB keys. [VERIFIED: CLAUDE.md anti-pattern #14]
- **Global frequency cap in engine:** The engine should return ALL matching signals; the provider/UI layer enforces the 2/week cap. This keeps the engine pure and testable.
- **Duplicating NudgeEngine triggers:** Some NudgeEngine triggers overlap (pillar3aDeadline, lppBuybackWindow, taxDeadlineApproach). The AnticipationEngine should either subsume these or explicitly defer to NudgeEngine. Recommend: AnticipationEngine owns Swiss fiscal calendar + profile-driven triggers; NudgeEngine keeps behavioral triggers (inactivity, profile incomplete, etc.). Document the boundary clearly. [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Compliance validation | Custom alert text checker | `ComplianceGuard.validateAlert()` (extend existing) | Already handles banned terms, prescriptive patterns, homoglyph normalization in 4 languages |
| Dismiss/snooze persistence | Custom storage layer | Extend `NudgePersistence` pattern (SharedPreferences) | Proven cooldown-per-trigger-type pattern |
| Freshness weighting | Custom staleness check | `FreshnessDecayService.weight()` + `BiographyRefreshDetector` | Already computes months-old, threshold checks |
| LPP bonification brackets | Hardcoded age ranges | `lppBonificationsVieillesse` map in `social_insurance.dart` | Source of truth for 25-34/35-44/45-54/55-65 rates |
| 3a plafond by archetype | Hardcoded values | `social_insurance.dart` constants + archetype check | Already used by NudgeEngine._checkPillar3aDeadline |
| Profile data access | Direct SharedPreferences reads | `CoachProfileProvider` + `BiographyProvider` | Cached, reactive, already wired into widget tree |

**Key insight:** The codebase has ~80% of the infrastructure. The AnticipationEngine is essentially a new "lens" over existing data (CoachProfile, Biography facts, calendar) with a new output format (AnticipationSignal cards on Aujourd'hui).

## Common Pitfalls

### Pitfall 1: NudgeEngine Overlap
**What goes wrong:** AnticipationEngine and NudgeEngine both fire 3a deadline signals, causing duplicate cards.
**Why it happens:** NudgeEngine already has `pillar3aDeadline`, `lppBuybackWindow`, `taxDeadlineApproach` triggers.
**How to avoid:** Define clear ownership. Option A: AnticipationEngine replaces these 3 triggers in NudgeEngine (deprecated). Option B: AnticipationEngine checks NudgeEngine dismissed IDs to avoid duplicates. Recommend Option A for clarity.
**Warning signs:** User sees "3a deadline" card twice on Aujourd'hui.

### Pitfall 2: Weekly Cap Race Condition
**What goes wrong:** Multiple signals displayed in same session exceed the 2/week cap.
**Why it happens:** Cap checked at evaluate() time but signals rendered asynchronously.
**How to avoid:** Evaluate returns ranked list; provider takes top 2 and persists count atomically before rendering.
**Warning signs:** User sees 3+ anticipation cards in one week.

### Pitfall 3: Cantonal Tax Deadline Data Staleness
**What goes wrong:** Cantonal deadlines change year-to-year; hardcoded map becomes incorrect.
**Why it happens:** Each of 26 cantons sets its own declaration deadline (March 31 is most common but not universal; extensions vary widely).
**How to avoid:** Use March 31 as default fallback with known exceptions (GE: end of March, TI: April 30, etc.). Document that this is educational ("Verifie le delai dans ton canton"). Include the year in the data map so it's obvious when it needs updating.
**Warning signs:** User in TI gets March 31 deadline when actual is April 30.

### Pitfall 4: Salary Increase Detection False Positives
**What goes wrong:** User corrects a typo in salary (90'000 -> 91'000), triggers "salary increase" alert.
**Why it happens:** BiographyFact doesn't distinguish correction from real change.
**How to avoid:** Require salary change > threshold (e.g., 5% or 2000 CHF minimum delta) AND new fact source is `document` or `userInput` (not `userEdit`). Check `FactSource` on the new fact.
**Warning signs:** Alert fires after minor profile edits.

### Pitfall 5: Age Milestone Firing Repeatedly
**What goes wrong:** User opens app multiple times in January, gets age milestone alert each time.
**Why it happens:** No persistence of "already shown this milestone" state.
**How to avoid:** Dismiss persistence keyed by `ageMilestone_{age}_{year}` -- once shown for age 35 in 2026, never fires again for that milestone.
**Warning signs:** Same "Tu passes a 35 ans" alert appearing every session.

### Pitfall 6: ComplianceGuard.validateAlert() Over-Filtering
**What goes wrong:** Alert template text gets flagged by ComplianceGuard because it contains projection keywords, triggering unnecessary disclaimer injection.
**Why it happens:** Existing `validate()` injects disclaimers when it sees "rente", "capital", "estimation" -- common in financial alerts.
**How to avoid:** `validateAlert()` should run layers 1-2 (banned terms + prescriptive) but skip layers 3-4 (hallucination + disclaimer injection). Alerts already include source refs per ANT-03, making auto-disclaimer redundant.
**Warning signs:** Every alert card has a disclaimer footer cluttering the UI.

## Code Examples

### Existing NudgeEngine Evaluate Pattern (to follow)
```dart
// Source: apps/mobile/lib/services/nudge/nudge_engine.dart L130-163
static List<Nudge> evaluate({
  required CoachProfile profile,
  required DateTime now,
  required List<String> dismissedNudgeIds,
  DateTime? lastActivityTime,
  double? confidenceScore,
  int? goalProgressPct,
  DateTime? lifeEventDate,
}) {
  final candidates = <Nudge>[];
  _checkSalaryReceived(candidates, now);
  _checkTaxDeadlineApproach(candidates, now);
  _checkPillar3aDeadline(candidates, now, profile);
  // ... more checks
  final active = candidates.where((n) {
    if (dismissedNudgeIds.contains(n.id)) return false;
    if (n.expiresAt.isBefore(now)) return false;
    return true;
  }).toList();
  active.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  return active;
}
```
[VERIFIED: direct code reading]

### Existing ComplianceGuard Banned Terms Check (to extend)
```dart
// Source: apps/mobile/lib/services/coach/compliance_guard.dart L209-306
static ComplianceResult validate(
  String llmOutput, {
  CoachContext? context,
  ComponentType componentType = ComponentType.general,
}) {
  // Layer 1: Banned terms
  // Layer 2: Prescriptive language
  // Layer 3: Hallucination detection
  // Layer 4: Disclaimer injection
  // Layer 5: Length check
}
```
New `validateAlert()` should reuse layers 1-2 only:
```dart
/// Validate alert template text (non-LLM, deterministic).
/// Runs banned-term + prescriptive checks only.
/// Skips hallucination detection (no LLM output) and disclaimer
/// injection (alerts include source refs per ANT-03).
static ComplianceResult validateAlert(String alertText) {
  final violations = <String>[];
  var text = alertText;
  if (text.trim().isEmpty) {
    return const ComplianceResult(
      isCompliant: false, sanitizedText: '', 
      violations: ['Alerte vide'], useFallback: true,
    );
  }
  final bannedFound = _checkBannedTerms(text);
  if (bannedFound.isNotEmpty) {
    violations.addAll(bannedFound.map((t) => "Terme interdit: '$t'"));
    text = _sanitizeBannedTerms(text);
  }
  final prescriptiveFound = _checkPrescriptive(text);
  if (prescriptiveFound.isNotEmpty) {
    violations.addAll(prescriptiveFound.map((p) => "Langage prescriptif: '$p'"));
    return ComplianceResult(
      isCompliant: false, sanitizedText: '', 
      violations: violations, useFallback: true,
    );
  }
  return ComplianceResult(
    isCompliant: violations.isEmpty, sanitizedText: text,
    violations: violations, useFallback: false,
  );
}
```
[ASSUMED -- based on existing ComplianceGuard structure]

### Existing LPP Bonification Constants (to use for ANT-02)
```dart
// Source: apps/mobile/lib/constants/social_insurance.dart L77-82
const Map<String, double> lppBonificationsVieillesse = {
  '25-34': 0.07,
  '35-44': 0.10,
  '45-54': 0.15,
  '55-65': 0.18,
};
```
Age milestone trigger detects when user crosses bracket boundary (34->35, 44->45, 54->55).
[VERIFIED: direct code reading]

### Existing BiographyFact Model (salary increase detection source)
```dart
// Source: apps/mobile/lib/services/biography/biography_fact.dart
// FactType.salary + FactSource.document/userInput
// Compare value of latest salary fact vs previous to detect increase
```
[VERIFIED: direct code reading]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JitaiNudgeService (S61, older) | NudgeEngine + NudgePersistence (S61 refactored) | S61 | Separated pure logic from persistence |
| Dashboard monolith curation | DashboardCuratorService + TemporalPriorityService | P3 | Extracted ranking into testable services |
| Coach-only proactive signals | ProactiveTriggerService (S62) | S62 | Session-level triggers for Coach tab opening |

**Key evolution:** The codebase has evolved from monolithic "show everything" dashboards toward prioritized, capped, testable signal systems. Phase 4 continues this trajectory by creating the dedicated AnticipationEngine for the Aujourd'hui tab.

## Recommendations for Claude's Discretion Areas

### Trigger evaluation timing
**Recommendation:** Evaluate at session start (first `MintHomeScreen` build), cache results for the session. Do NOT re-evaluate on scroll or tab switch. This matches CTX-02 (Phase 5: "Card ranking updates once per session").
[VERIFIED: CTX-02 in REQUIREMENTS.md]

### Cantonal tax deadline data source
**Recommendation:** Static Dart map in `cantonal_deadlines.dart` with year-keyed entries. Default March 31 for most cantons. Known exceptions: GE (March 31 but specific extensions), TI (April 30), some cantons allow September extensions. Mark all deadlines as educational ("Verifie aupres de ton administration fiscale cantonale"). This avoids external API dependency (out of scope per v2.0) while covering the 26 cantons.
[ASSUMED -- cantonal deadlines vary; no single authoritative API exists]

### Snooze duration per trigger type
**Recommendation:** Follow NudgePersistence cooldown pattern:

| Trigger Type | "Got it" cooldown | "Remind me later" snooze |
|-------------|-------------------|--------------------------|
| 3a deadline (Dec) | Rest of year (365 days) | 7 days |
| Cantonal tax deadline | 30 days | 7 days |
| LPP rachat window | 60 days | 14 days |
| Salary increase -> 3a recalc | 90 days | 14 days |
| Age milestone -> LPP bonif | 365 days (once per milestone) | 30 days |

[ASSUMED -- modeled after NudgePersistence cooldown patterns]

### Card ranking weight formula
**Recommendation:**
```
priority_score = (timeliness * 0.5) + (user_relevance * 0.3) + (confidence * 0.2)
```
Timeliness weighted highest because anticipation signals are time-sensitive by nature. User relevance second (archetype match, profile completeness). Confidence third (data freshness).
[ASSUMED]

### Expandable "See more" section
**Recommendation:** Use a simple `ExpansionTile` or custom `AnimatedCrossFade` below the top 2 cards. Header shows count ("2 autres signaux"). Collapsed by default. This is lightweight and avoids over-engineering for what may be 0-3 overflow signals.
[ASSUMED]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AnticipationEngine should be a new service in `services/anticipation/` rather than extending NudgeEngine | Architecture Patterns | Medium -- could be a refactor if we decide to merge |
| A2 | Cantonal tax deadlines can be a static Dart map (no external API) | Recommendations | Low -- educational framing covers imprecision |
| A3 | Snooze durations (7/14/30/90/365 days per trigger) | Recommendations | Low -- easily tunable constants |
| A4 | Card ranking weights (0.5/0.3/0.2 for timeliness/relevance/confidence) | Recommendations | Low -- formula is tunable |
| A5 | validateAlert() should skip ComplianceGuard layers 3-4 | Code Examples | Medium -- if someone wants disclaimers on alerts |
| A6 | NudgeEngine fiscal triggers should be deprecated in favor of AnticipationEngine | Pitfall 1 | Medium -- coordination required |
| A7 | Salary increase threshold of 5% or 2000 CHF minimum | Pitfall 4 | Low -- tunable constant |

## Open Questions

1. **NudgeEngine trigger migration**
   - What we know: NudgeEngine already has `pillar3aDeadline`, `lppBuybackWindow`, `taxDeadlineApproach` triggers that overlap with ANT-01 requirements.
   - What's unclear: Should these be migrated to AnticipationEngine and removed from NudgeEngine, or should both coexist with deduplication?
   - Recommendation: Migrate fiscal triggers to AnticipationEngine, deprecate in NudgeEngine. Phase 4 owns all Swiss fiscal calendar signals.

2. **MintHomeScreen integration point**
   - What we know: MintHomeScreen currently shows PremierEclairageCard, ConfidenceScoreCard, FinancialPlanCard, StreakBadge, PlanRealityCard, FirstCheckInCtaCard.
   - What's unclear: Where in the vertical scroll should anticipation cards appear? Before or after existing cards?
   - Recommendation: After hero stat card (position 2), before other cards. This matches CTX-01 Phase 5 spec ("hero stat + narrative, anticipation signal, ...").

3. **Interaction with Phase 5 (Interface Contextuelle)**
   - What we know: Phase 5 (CTX-01 through CTX-06) defines the full Aujourd'hui card layout including anticipation signals.
   - What's unclear: Should Phase 4 build the full card UI or just the engine + a minimal card?
   - Recommendation: Phase 4 builds engine + model + minimal card widget. Phase 5 handles final card layout, positioning, and session-level curation.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | `apps/mobile/pubspec.yaml` (test dependencies) |
| Quick run command | `cd apps/mobile && flutter test test/services/anticipation/` |
| Full suite command | `cd apps/mobile && flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANT-01 | Calendar triggers fire for 3a/cantonal/LPP dates | unit | `flutter test test/services/anticipation/anticipation_engine_test.dart -x` | Wave 0 |
| ANT-02 | Profile-driven triggers detect salary increase + age milestone | unit | `flutter test test/services/anticipation/anticipation_engine_test.dart -x` | Wave 0 |
| ANT-03 | AlertTemplate enum with educational format | unit | `flutter test test/services/anticipation/anticipation_signal_test.dart -x` | Wave 0 |
| ANT-04 | ComplianceGuard.validateAlert() blocks banned terms | unit | `flutter test test/services/coach/compliance_guard_test.dart -x` | Existing (extend) |
| ANT-05 | Frequency cap: max 2 signals per week | unit | `flutter test test/services/anticipation/anticipation_persistence_test.dart -x` | Wave 0 |
| ANT-06 | Card ranking by priority_score formula | unit | `flutter test test/services/anticipation/anticipation_ranking_test.dart -x` | Wave 0 |
| ANT-07 | Dismiss "Got it" + snooze "Remind me later" | unit | `flutter test test/services/anticipation/anticipation_persistence_test.dart -x` | Wave 0 |
| ANT-08 | All triggers deterministic (no LLM calls) | unit | Verify no async HTTP in engine tests | Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/mobile && flutter test test/services/anticipation/`
- **Per wave merge:** `cd apps/mobile && flutter test && flutter analyze`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/anticipation/anticipation_engine_test.dart` -- covers ANT-01, ANT-02, ANT-08
- [ ] `test/services/anticipation/anticipation_persistence_test.dart` -- covers ANT-05, ANT-07
- [ ] `test/services/anticipation/anticipation_ranking_test.dart` -- covers ANT-06
- [ ] `test/services/anticipation/anticipation_signal_test.dart` -- covers ANT-03
- [ ] Extend `test/services/coach/compliance_guard_test.dart` -- covers ANT-04

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A -- local-only feature |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A -- user's own data only |
| V5 Input Validation | yes | ComplianceGuard.validateAlert() for all text; template-based (no user input in alert text) |
| V6 Cryptography | no | Biography data already encrypted (Phase 3); anticipation reads but doesn't write |

### Known Threat Patterns for Anticipation Engine

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prescriptive language in alert text | Tampering (compliance) | ComplianceGuard.validateAlert() -- layers 1-2 |
| PII leakage in alert params | Information Disclosure | Alert params use rounded values only (e.g., "environ 7'200 CHF" not "7'258 CHF") |
| Alert fatigue (user ignores real signals) | Denial of Service (UX) | 2/week frequency cap (ANT-05) + priority ranking (ANT-06) |

## Sources

### Primary (HIGH confidence)
- Codebase: `apps/mobile/lib/services/nudge/nudge_engine.dart` -- existing pure trigger engine pattern
- Codebase: `apps/mobile/lib/services/nudge/nudge_persistence.dart` -- dismiss/cooldown persistence pattern
- Codebase: `apps/mobile/lib/services/coach/proactive_trigger_service.dart` -- session-level trigger pattern
- Codebase: `apps/mobile/lib/services/coach/compliance_guard.dart` -- 5-layer validation pipeline
- Codebase: `apps/mobile/lib/services/biography/biography_fact.dart` -- fact model with FactType/FactSource
- Codebase: `apps/mobile/lib/services/biography/biography_refresh_detector.dart` -- freshness detection pattern
- Codebase: `apps/mobile/lib/constants/social_insurance.dart` -- LPP bonification brackets, 3a limits
- Codebase: `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` -- Aujourd'hui tab structure

### Secondary (MEDIUM confidence)
- `.planning/phases/04-moteur-danticipation/04-CONTEXT.md` -- locked decisions from user discussion
- `.planning/REQUIREMENTS.md` -- ANT-01 through ANT-08 specifications

### Tertiary (LOW confidence)
- Cantonal tax deadlines (varies by year, no single authoritative source verified) -- marked as educational

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies, all patterns exist in codebase
- Architecture: HIGH -- follows proven NudgeEngine/NudgePersistence pattern
- Pitfalls: HIGH -- identified from direct codebase analysis (overlap with NudgeEngine, ComplianceGuard layers)
- Cantonal deadlines: MEDIUM -- static data requires annual maintenance

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable domain; Swiss constants change annually in January)
