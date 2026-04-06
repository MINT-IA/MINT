# Phase 6: Calculator Wiring - Research

**Researched:** 2026-04-06
**Domain:** Flutter GoRouter prefill flow, CoachProfile write-back, RoutePlanner prefill dispatch
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Prefill Data Flow**
- Backend tool enriches prefill — `route_to_screen` tool reads CoachProfile context and populates prefill map with relevant fields (avoirLppTotal, salaireBrutMensuel, etc.)
- All whitelisted calculator routes in `validRoutes` that have matching CoachProfile fields get prefilled
- Prefill keys match CoachProfile field names directly — `avoirLppTotal`, `salaireBrutMensuel`, `tauxConversion`, etc.
- Pass what's available, screen shows partial warning — `isPartial: true` on RouteSuggestionCard (already exists), screen pre-fills known fields, leaves others empty

**Calculator Screen Updates**
- Screens consume prefill by reading `GoRouterState.extra` in `initState()` — existing pattern from `simulator_3a_screen.dart:71-79`, apply to all calculator screens
- Direct field mapping per screen:
  - `/rente-vs-capital`: avoirLppTotal, tauxConversion, salaireBrutMensuel, ageRetraite
  - `/pilier-3a`: salaireBrutMensuel, canton
  - `/hypotheque`: salaireBrutMensuel, epargneLiquide, avoirLppTotal
  - `/rachat-lpp`: salaireBrutMensuel, rachatMaximum, avoirLppTotal
  - `/3a-retroactif`: salaireBrutMensuel, canton
  - `/epl`: avoirLppTotal, salaireBrutMensuel
- Fields are editable defaults — prefilled values populate TextControllers but user can change any field freely
- Subtle "MINT" badge or filled state indicator — differentiates auto-filled from user-entered, matching MintColors.primary

**Result Write-Back**
- Write-back happens on simulation completion — when user taps "Calculer" / "Simuler" and result is displayed, key outputs auto-saved to CoachProfile
- Primary computed outputs written back per calculator:
  - `/rente-vs-capital`: projected LPP capital at retirement, monthly rente amount
  - `/pilier-3a`: optimal 3a contribution, tax savings estimate
  - `/hypotheque`: mortgage capacity, monthly payments
  - `/rachat-lpp`: buyback impact on rente
- Silent write-back with subtle "Profil mis a jour" snackbar — no modal, appears briefly
- FinancialPlanProvider detects stale plan via existing profileHashAtGeneration mechanism

### Claude's Discretion
- Exact snackbar duration and animation
- Additional calculator field mappings beyond the 6 screens listed
- Error handling for write-back failures (silent retry vs user notification)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAL-01 | Calculator screens pre-fill all known fields from CoachProfile (never ask what MINT already knows) | RoutePlanner._buildPrefill() already computes prefill from profile; screens need to consume `GoRouterState.extra['prefill']` in initState — pattern already established in epl_screen.dart:82-103 |
| CAL-02 | RoutePlanner.prefill decisions passed through GoRouter extras to calculator constructors | RouteSuggestionCard passes `extra: prefill` on context.push; screen reads via `GoRouterState.of(context).extra` — both halves exist, gap is screens not reading `extra['prefill']` key |
| CAL-03 | Calculator results feed back into CoachProfile (bidirectional data flow) | CoachProfileProvider.updateProfile() exists and triggers hash invalidation; write-back needs to be called from result display callbacks in each calculator screen |
</phase_requirements>

---

## Summary

Phase 6 closes the data loop between the MINT coach and the calculator screens. The full prefill infrastructure already exists: `RoutePlanner._buildPrefill()` extracts CoachProfile fields into a map, `RouteSuggestionCard` passes that map as GoRouter extra, and multiple screens already read `GoRouterState.extra` in `initState`. The gap is that most calculator screens do not yet read the `extra['prefill']` key specifically — they only read `runId`/`stepId` sequence context. The write-back direction (results back to CoachProfile) is entirely absent from calculator screens; it is only implemented in `record_check_in` (check-in card). Both halves are mechanical additions following established patterns.

The critical architectural insight: `rente_vs_capital_screen.dart` already has `_autoFillFromProfile()` which reads CoachProfile directly in `didChangeDependencies`. This is a partial implementation — it fills from the provider but ignores GoRouter extra prefill. The fix is to merge the two paths: if GoRouter extra has a `prefill` key, use those values instead of (or on top of) the provider auto-fill. For `affordability_screen.dart` and `simulator_3a_screen.dart`, there is no prefill consumption at all — these need the full `_applyPrefill()` pattern from `epl_screen.dart`.

The write-back chain is: calculator computes result → user sees result → `CoachProfileProvider.updateProfile()` called with enriched fields → `computeProfileHash()` detects change → `FinancialPlanProvider._checkStaleness()` sets `_isStale = true` → UI surfaces the stale plan indicator. This chain is already wired; calculator screens just need to call `updateProfile()` after result display.

**Primary recommendation:** Add `_applyPrefill(Map<String, dynamic>)` to each of the 6 target calculator screens following the `epl_screen.dart` pattern, then add `_writeBackResult()` after calculation completes, calling `CoachProfileProvider.updateProfile()` with the enriched profile.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `go_router` | Already in pubspec | GoRouter extras: `context.push(route, extra: prefill)` | Project standard for all navigation |
| `provider` | Already in pubspec | `context.read<CoachProfileProvider>().updateProfile()` | Project standard state management |

No new dependencies required. [VERIFIED: codebase grep]

**Installation:**
```bash
# No new packages required — all dependencies already in pubspec.yaml
```

---

## Architecture Patterns

### How Prefill Flows (Full Chain)

```
Backend route_to_screen tool
  → includes prefill map in tool response
  → WidgetRenderer._buildRouteSuggestion() reads p['prefill']
  → RouteSuggestionCard rendered with prefill: Map<String, dynamic>
  → User taps CTA → context.push(route, extra: prefill)
  → Calculator screen initState → GoRouterState.of(context).extra
  → extra is Map<String, dynamic> → extra['prefill'] as Map
  → _applyPrefill(prefill) populates TextControllers
```

**Key insight:** `WidgetRenderer._buildRouteSuggestion()` at line 91 already reads `p['prefill'] as Map<String, dynamic>?` from the tool call. `RouteSuggestionCard` already passes it as GoRouter extra (line 89). The screens just need to read it.

### Pattern 1: Prefill Consumption in initState (established in epl_screen.dart)

```dart
// Source: apps/mobile/lib/screens/lpp_deep/epl_screen.dart:77-102
void _readSequenceContext() {
  try {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _seqRunId = extra['runId'] as String?;
      _seqStepId = extra['stepId'] as String?;
      final prefill = extra['prefill'] as Map<String, dynamic>?;
      if (prefill != null) _applyPrefill(prefill);
    }
  } catch (_) {}
}

void _applyPrefill(Map<String, dynamic> prefill) {
  final fonds = prefill['montant_necessaire'];
  if (fonds is num && fonds > 0) {
    setState(() {
      _montantSouhaite = fonds.toDouble().clamp(20000, 500000);
    });
  }
}
```

**Note:** `epl_screen.dart` already correctly reads `extra['prefill']`. This is the reference implementation. All other screens should match this pattern.

### Pattern 2: Profile Auto-Fill (established in rente_vs_capital_screen.dart)

```dart
// Source: apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:165-258
// Called in didChangeDependencies() when _didAutoFill == false
void _autoFillFromProfile() {
  final provider = context.read<CoachProfileProvider>();
  final profile = provider.profile;
  if (profile == null) return;
  // ... apply profile fields to TextControllers
  // Sets _dataSources, _hasEstimatedValues, triggers _recalculate()
}
```

**Key insight:** `rente_vs_capital_screen.dart` uses `didChangeDependencies` for auto-fill. The prefill from GoRouter extra should be applied in `initState` (via `addPostFrameCallback`) AFTER the auto-fill runs, so explicit coach-provided values override profile estimates.

### Pattern 3: Write-Back via CoachProfileProvider.updateProfile()

```dart
// Source: apps/mobile/lib/providers/coach_profile_provider.dart:707-738
void updateProfile(CoachProfile updated) {
  _profile = updated;
  _profileUpdatedSinceBudget = true;
  notifyListeners();
  _persistFullProfile(updated);
  CoachCacheService.invalidate(InvalidationTrigger.profileUpdate);
  // Also invalidates CapMemory and handles divorce cleanup
}
```

**Write-back call site pattern** (to be added to calculator screens):

```dart
void _writeBackResult(CalculationResult result) {
  final provider = context.read<CoachProfileProvider>();
  final profile = provider.profile;
  if (profile == null) return;

  // Build updated prevoyance with computed values
  final updatedPrevoyance = profile.prevoyance.copyWith(
    avoirLppTotal: result.capitalAtRetirement,
    // add other fields per calculator
  );
  provider.updateProfile(profile.copyWith(prevoyance: updatedPrevoyance));

  // Show brief snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Profil mis\u00a0\u00e0 jour'),
      duration: Duration(seconds: 2),
    ),
  );
}
```

**Call site:** Inside the result display callback — after the calculator fires (e.g., after `_recalculate()` or the API response returns), check `_hasUserInteracted` and call `_writeBackResult()`.

### Pattern 4: Plan Staleness Chain (automatic — no work required)

```dart
// Source: apps/mobile/lib/providers/financial_plan_provider.dart:82-96
// Triggered automatically by updateProfile() → notifyListeners()
void _checkStaleness(CoachProfile? profile) {
  if (_currentPlan == null || profile == null) return;
  final currentHash = computeProfileHash(profile);
  if (currentHash != _currentPlan!.profileHashAtGeneration && !_isStale) {
    _isStale = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}
```

The staleness chain fires automatically whenever `updateProfile()` is called. No additional wiring needed.

### Pattern 5: Backend Prefill Population (route_to_screen tool)

The `route_to_screen` tool in `coach_tools.py` currently does NOT accept a `prefill` field — the input schema only has `intent`, `confidence`, `context_message`. The CONTEXT.md decision says "Backend tool enriches prefill". This means the `route_to_screen` tool schema needs a `prefill` field added.

However, looking at `WidgetRenderer._buildRouteSuggestion()`, it already reads `p['prefill']` from the tool call input. The tool schema just needs to declare the field so Claude can populate it.

**Alternative path already working:** `RoutePlanner._buildPrefill()` computes the prefill from profile on the Flutter side. `ChatToolDispatcher` does not currently invoke `RoutePlanner` for `route_to_screen` calls — it passes raw tool output directly to `WidgetRenderer`. The question is: does prefill come from the backend LLM (via tool schema), or from the Flutter `RoutePlanner`?

**Current reality:** `RoutePlanner` is instantiated in `ChatToolDispatcher.resolveRoute()` context but the comment on line 83 says "intent-to-route resolution is deferred to Phase 6 (Open Question #1 in RESEARCH.md)". This means `RoutePlanner._buildPrefill()` is NOT currently called in the coach chat path — it is only used in tests.

**The wiring gap for CAL-02:** The `route_to_screen` tool sends intent + context_message. Flutter receives it, validates the route from `ToolCallParser.validRoutes`. But Flutter never calls `RoutePlanner.plan(intent)` to get the `prefill` map from the profile. The two options are:

1. **Backend populates prefill** — add `prefill` to tool schema, backend LLM includes profile values
2. **Flutter-side prefill injection** — Flutter intercepts `route_to_screen`, runs `RoutePlanner.plan(intent)`, extracts the `RouteDecision.prefill`, and passes it to `RouteSuggestionCard`

The CONTEXT.md locked decision says "Backend tool enriches prefill". But the clean implementation path uses `RoutePlanner._buildPrefill()` on the Flutter side (already built, tested, does the field resolution). The planner should be aware of this tension.

**Recommended resolution (matching CONTEXT.md intent):** Add `prefill` field to the `route_to_screen` tool schema so the backend LLM can include it. AND also wire Flutter `RoutePlanner.plan(intent)` in `WidgetRenderer._buildRouteSuggestion()` as a fallback when the backend prefill is absent. This covers both the backend-enrichment case and the safety net case.

### Recommended Project Structure for Phase Changes

```
apps/mobile/lib/
  screens/
    arbitrage/rente_vs_capital_screen.dart  # Add _applyPrefill() + _writeBackResult()
    mortgage/affordability_screen.dart       # Add _applyPrefill() + _initFromProfile() + _writeBackResult()
    simulator_3a_screen.dart                 # Add _applyPrefill() for GoRouter extra path
    screens/lpp_deep/rachat_echelonne_screen.dart  # Already prefills; add _writeBackResult()
    screens/lpp_deep/epl_screen.dart         # Already has _applyPrefill(); add _writeBackResult()
    screens/pillar_3a_deep/retroactive_3a_screen.dart  # Add _applyPrefill() + _writeBackResult()
  services/coach/
    chat_tool_dispatcher.dart  # Wire RoutePlanner.plan(intent) for prefill injection
  services/navigation/
    route_planner.dart         # No changes needed — _buildPrefill() is already complete
services/backend/app/services/coach/
  coach_tools.py               # Add prefill field to route_to_screen schema
```

### Anti-Patterns to Avoid

- **Do not read `extra` directly in `build()`** — always in `initState` + `addPostFrameCallback` or `didChangeDependencies`. Reading GoRouterState outside of widget tree context throws.
- **Do not write back on every recalculate** — only on explicit user action (tap "Calculer"). Write-back on input change would thrash the profile hash and trigger false plan staleness.
- **Do not skip the `_hasUserInteracted` guard** — write-back should not fire if the user never touched the screen (sequence coordinator already handles this for ScreenReturn; same guard applies to write-back).
- **Do not use `context.read<>()` inside `build()`** — use `WidgetsBinding.instance.addPostFrameCallback` for profile reads that mutate state.
- **Do not call `updateProfile()` with stale profile** — always re-read from provider immediately before building the updated copy: `final profile = context.read<CoachProfileProvider>().profile`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Field resolution from CoachProfile | Custom field extractor | `RoutePlanner._resolveProfileValue(key)` | Already handles all canonical field keys; tested |
| Prefill map construction | Custom builder | `RoutePlanner._buildPrefill(entry)` | Iterates required + optional fields from ScreenEntry; null-safe |
| Profile hash comparison | Custom hash | `computeProfileHash(profile)` in `financial_plan.dart:245` | Used by FinancialPlanProvider staleness; must be same function |
| Profile persistence after write-back | Direct SharedPreferences | `CoachProfileProvider.updateProfile()` | Triggers full persist chain, cache invalidation, CapMemory reset |
| Route validation | Custom whitelist check | `ToolCallParser.isValidRoute(route)` | Security gate; existing set of 40+ routes |
| Visual indicator for auto-filled values | Custom badge widget | `SmartDefaultIndicator` in `widgets/precision/smart_default_indicator.dart` | Existing component with confidence bar and "Preciser" tooltip |

---

## Common Pitfalls

### Pitfall 1: GoRouterState Outside Build Context
**What goes wrong:** `GoRouterState.of(context)` throws `ProviderNotFoundException` when called in `initState()` directly (before the widget is fully mounted).
**Why it happens:** GoRouter's `InheritedWidget` is not available until after the first frame.
**How to avoid:** Always wrap in `WidgetsBinding.instance.addPostFrameCallback((_) { ... })` — exactly as `epl_screen.dart:71` and `affordability_screen.dart:44` do.
**Warning signs:** `FlutterError: No GoRouter found` in debug console on screen open from coach.

### Pitfall 2: Prefill Key Naming Mismatch
**What goes wrong:** `RoutePlanner._resolveProfileValue()` uses the key `'avoirLpp'` to access `profile.prevoyance.avoirLppTotal`. The CONTEXT.md decisions reference `avoirLppTotal` as the key name. These are different.
**Why it happens:** The RoutePlanner uses shortened keys (`avoirLpp`, `salaireBrut`, `rachatMaximum`) while the CoachProfile model uses longer paths (`prevoyance.avoirLppTotal`). The `_applyPrefill()` implementation in each screen must match whatever key the prefill map actually contains.
**How to avoid:** Always trace from `RoutePlanner._resolveProfileValue()` to know the exact key name that will appear in the prefill map. Key `'avoirLpp'` → value is `avoirLppTotal`. Key `'salaireBrut'` → monthly value (not annual). Key `'epargne'` → `epargneLiquide`.
**Warning signs:** Julien's LPP value not appearing in /rente-vs-capital despite profile having 70,377 CHF.

### Pitfall 3: Writing Back Annual vs Monthly Salary
**What goes wrong:** `RoutePlanner._resolveProfileValue('salaireBrut')` returns `profile.salaireBrutMensuel` (monthly). Some calculator screens expect annual salary in their inputs.
**Why it happens:** The screen `rente_vs_capital_screen.dart` converts to annual: `profile.salaireBrutMensuel * profile.nombreDeMois`. A generic prefill of `salaireBrutMensuel` would need the same conversion.
**How to avoid:** When reading `prefill['salaireBrutMensuel']`, apply the same `× nombreDeMois` multiplication that the auto-fill does. Or use the same annual conversion in the `_applyPrefill()` implementation.
**Warning signs:** Rente-vs-capital shows monthly value where annual is expected, producing absurdly small projections.

### Pitfall 4: Write-Back Triggers Infinite Recalculation
**What goes wrong:** Write-back calls `updateProfile()` → `notifyListeners()` → `_autoFillFromProfile()` refires in `didChangeDependencies()` → sets TextController → triggers `_recalculate()` → triggers another write-back.
**Why it happens:** `didChangeDependencies()` fires on any Provider change if the widget is listening.
**How to avoid:** Guard the auto-fill with `_didAutoFill` (already present in rente_vs_capital). Guard write-back with `_hasUserInteracted` so it only fires on explicit user action. Never set `_didAutoFill = false` after write-back.
**Warning signs:** Multiple rapid `updateProfile()` calls visible in debug logs, plan flashing stale repeatedly.

### Pitfall 5: rente_vs_capital Already Has Profile Auto-Fill — Don't Duplicate
**What goes wrong:** Implementing GoRouter extra prefill independently of the existing `_autoFillFromProfile()` results in double-application or field override in wrong order.
**Why it happens:** `rente_vs_capital_screen.dart` already auto-fills from profile in `didChangeDependencies()`. Adding GoRouter extra prefill in `initState` could run first and then get overwritten.
**How to avoid:** In `rente_vs_capital_screen.dart`, apply GoRouter extra prefill AFTER `_autoFillFromProfile()`. Call `_applyPrefill()` at the end of `_autoFillFromProfile()`, seeded from `GoRouterState.extra`. This way auto-fill runs first, then explicit coach prefill overrides specific fields.
**Warning signs:** Coach says "j'ai mis tes 70'377 CHF" but screen shows the old generic 350,000 estimate.

### Pitfall 6: affordability_screen.dart Has No Profile Integration
**What goes wrong:** `AffordabilityScreen` initializes with hardcoded values (`_revenuBrut = 120000`, `_avoirLpp = 200000`) and has no `_initializeFromProfile()` call. Adding GoRouter extra prefill without also adding profile auto-fill means only coach-suggested values are applied — if the coach does not provide a value, user still sees generic defaults.
**Why it happens:** The screen predates the unified prefill pattern.
**How to avoid:** Add both `_initializeFromProfile()` (from CoachProfileProvider) AND `_applyPrefill()` (from GoRouter extra). Apply in order: (1) profile auto-fill, (2) GoRouter override.
**Warning signs:** `/hypotheque` opened with 120,000 CHF salary when Julien's profile has 122,207 CHF.

---

## Code Examples

### GoRouter Extra Prefill Consumption (reference — epl_screen.dart)
```dart
// Source: apps/mobile/lib/screens/lpp_deep/epl_screen.dart:77-103
void _readSequenceContext() {
  try {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _seqRunId = extra['runId'] as String?;
      _seqStepId = extra['stepId'] as String?;
      final prefill = extra['prefill'] as Map<String, dynamic>?;
      if (prefill != null) _applyPrefill(prefill);
    }
  } catch (_) {}
}
```

### Write-Back Pattern (to implement per screen)
```dart
// Pattern to add to each calculator screen after result display
void _writeBackResult() {
  if (!_hasUserInteracted) return;
  final provider = context.read<CoachProfileProvider>();
  final profile = provider.profile;
  if (profile == null) return;

  // Example for rente_vs_capital — adapt per screen
  final updatedPrevoyance = profile.prevoyance.copyWith(
    avoirLppTotal: _computedCapitalAtRetirement,
  );
  provider.updateProfile(profile.copyWith(prevoyance: updatedPrevoyance));

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Profil mis\u00a0\u00e0 jour'),
      duration: Duration(seconds: 2),
    ),
  );
}
```

### RoutePlanner.plan() Call for Flutter-Side Prefill
```dart
// For ChatToolDispatcher or WidgetRenderer to inject Flutter-side prefill
// when backend does not include one:
final profile = context.read<CoachProfileProvider>().profile;
if (profile != null) {
  final planner = RoutePlanner(
    registry: MintScreenRegistry(),
    profile: profile,
  );
  final decision = planner.plan(intent);  // intent from tool call input
  if (decision.prefill != null) {
    prefillMap = decision.prefill;
  }
}
```

### SmartDefaultIndicator for MINT-filled fields
```dart
// Source: apps/mobile/lib/widgets/precision/smart_default_indicator.dart
// Use next to pre-filled TextFormField labels to indicate auto-fill origin:
SmartDefaultIndicator(
  source: 'Depuis ton certificat LPP',
  confidence: 0.60,  // userInput confidence level
)
```

### Backend: route_to_screen prefill field (to add)
```python
# In services/backend/app/services/coach/coach_tools.py
# Add to route_to_screen input_schema properties:
"prefill": {
    "type": "object",
    "description": (
        "Optional key-value map of profile fields to pre-populate the screen. "
        "Keys: avoirLppTotal, salaireBrutMensuel, tauxConversion, ageRetraite, "
        "canton, epargneLiquide, rachatMaximum. "
        "Only include fields you have confirmed values for from CoachProfile context. "
        "Omit the field entirely if values are unknown."
    ),
    "additionalProperties": True,
}
# "prefill" is optional — NOT added to "required"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Each screen with hardcoded defaults | Profile auto-fill in `didChangeDependencies` | S55-S56 sprint | `rente_vs_capital`, `rachat_echelonne`, `epl` already do this |
| No GoRouter extra prefill on most screens | `epl_screen.dart` fully wires GoRouter extra → `_applyPrefill()` | S56 | Reference implementation for Phase 6 |
| No write-back from calculators | record_check_in tool calls `CoachProfileProvider.addCheckIn()` | Phase 5 | Pattern exists; calculators need same approach |

**What already works (no changes needed):**
- `epl_screen.dart`: reads GoRouter extra prefill + profile auto-fill — COMPLETE
- `rachat_echelonne_screen.dart`: reads profile in `_prefillFromProfile()` — partial (no GoRouter extra path)
- `rente_vs_capital_screen.dart`: reads profile in `_autoFillFromProfile()` — partial (no GoRouter extra path, no write-back)
- `RoutePlanner._buildPrefill()` and `_resolveProfileValue()`: fully implemented and tested
- `RouteSuggestionCard` → `context.push(route, extra: prefill)`: works
- `FinancialPlanProvider` staleness chain: fully wired

**What is missing (Phase 6 work):**
- `affordability_screen.dart` (`/hypotheque`): no profile auto-fill, no GoRouter extra prefill, no write-back
- `simulator_3a_screen.dart` (`/pilier-3a`): reads profile but no GoRouter extra prefill path, no write-back  
- `rente_vs_capital_screen.dart`: no GoRouter extra prefill path, no write-back
- `rachat_echelonne_screen.dart`: no GoRouter extra path, no write-back (has `ScreenReturn` with `updatedFields` but does not call `updateProfile()`)
- `retroactive_3a_screen.dart` (`/3a-retroactif`): needs full audit
- Backend `route_to_screen` tool: `prefill` field not in schema
- `ChatToolDispatcher`/`WidgetRenderer`: does not call `RoutePlanner.plan(intent)` to inject Flutter-side prefill

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `retroactive_3a_screen.dart` does not currently read GoRouter extra prefill | Architecture Patterns | Low — even if it does, adding idempotent prefill is safe |
| A2 | `simulator_3a_screen.dart` does not write back results to CoachProfile | State of the Art | Low — if it does, write-back would be a no-op addition |
| A3 | Backend Claude LLM sees CoachProfile fields in its context and can populate the `prefill` map in tool calls | Architecture Patterns | MEDIUM — if the context window does not include the relevant fields, Claude will not emit prefill values; Flutter-side fallback via RoutePlanner is therefore essential |

---

## Open Questions (RESOLVED)

1. **Intent-to-route resolution in ChatToolDispatcher** (RESOLVED)
   - What we know: `ChatToolDispatcher.resolveRoute()` reads `input['route']` directly — not `input['intent']`. The comment says "intent-to-route resolution is deferred to Phase 6 (Open Question #1 in RESEARCH.md)".
   - Resolution: WidgetRenderer._buildRouteSuggestion() calls RoutePlanner.plan(intent) as fallback when backend prefill is absent. Backend prefill wins on conflict. Implemented in Plan 06-01 Task 1.
   - Recommendation: Add Flutter-side prefill injection: when `WidgetRenderer._buildRouteSuggestion()` has an intent from the tool call and a CoachProfile is available, call `RoutePlanner.plan(intent)` to get the `RouteDecision.prefill` map as fallback. Merge with any backend-provided prefill (backend wins on conflict).

2. **Write-back: CoachProfile field availability** (RESOLVED)
   - What we know: `CoachProfile` has `prevoyance.copyWith()` for LPP fields. But not all calculator outputs map cleanly to CoachProfile fields — e.g., `/pilier-3a` outputs "optimal 3a contribution" which is a computed recommendation, not a profile field.
   - Resolution: Only write back fields that exist in CoachProfile model. For mortgage, add mortgageCapacity + estimatedMonthlyPayment to PatrimoineProfile. For 3a, skip recommendations (display-only). Implemented in Plan 06-02 Task 2.
   - Recommendation: Only write back values that enrich the user's actual financial picture (e.g., projected LPP capital updates `prevoyance.avoirLppTotal` if more accurate than current estimate). Do not store calculator recommendations — those are display-only.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — all changes are Flutter/Dart code modifications to existing screens and backend Python schema additions)

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (flutter_test) + pytest |
| Config file | apps/mobile/pubspec.yaml (test dependencies) |
| Quick run command | `cd apps/mobile && flutter test test/services/navigation/ test/widgets/coach/ -q` |
| Full suite command | `cd apps/mobile && flutter test -q` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | Calculator screens pre-fill known CoachProfile fields | unit | `flutter test test/services/navigation/route_planner_test.dart -q` | Yes (existing tests cover _buildPrefill; need Julien 70,377 test) |
| CAL-02 | RoutePlanner.prefill passes through GoRouter extras to constructor | integration (widget test) | `flutter test test/widgets/coach/widget_renderer_test.dart -q` | Partial (widget_renderer_test.dart exists; needs route_to_screen + prefill test) |
| CAL-03 | Calculator results feed back to CoachProfile | unit | `flutter test test/screens/ -q` (new test files) | No — Wave 0 gap |

### Sampling Rate
- **Per task commit:** `cd apps/mobile && flutter test test/services/navigation/ test/widgets/coach/ -q`
- **Per wave merge:** `cd apps/mobile && flutter analyze && flutter test -q`
- **Phase gate:** `cd apps/mobile && flutter analyze && flutter test -q` + `cd services/backend && python3 -m pytest tests/ -q` before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/screens/arbitrage/rente_vs_capital_prefill_test.dart` — covers CAL-01 (Julien 70,377 pre-filled) and CAL-03 (write-back fires after _recalculate)
- [ ] `test/screens/mortgage/affordability_prefill_test.dart` — covers CAL-01 + CAL-03 for /hypotheque
- [ ] `test/screens/simulator_3a_prefill_test.dart` — covers CAL-01 + CAL-03 for /pilier-3a

---

## Security Domain

Phase 6 involves no new authentication, session management, or cryptography. The primary security consideration is the existing route whitelist in `ToolCallParser.validRoutes` — no changes needed. Write-back to CoachProfile uses the existing `updateProfile()` path which does not log PII (CLAUDE.md §6 rule 7 compliance). The `prefill` field added to the backend tool schema must only contain numeric/string financial values — never names, IBANs, SSN, or employer names.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no (existing whitelist unchanged) | ToolCallParser.isValidRoute() |
| V5 Input Validation | yes | Prefill values clamped in _applyPrefill(); type-checked with `as num?` pattern |
| V6 Cryptography | no | — |

---

## Sources

### Primary (HIGH confidence)
- `apps/mobile/lib/screens/lpp_deep/epl_screen.dart` — reference prefill implementation [VERIFIED: codebase read]
- `apps/mobile/lib/services/navigation/route_planner.dart` — `_buildPrefill()` and `_resolveProfileValue()` [VERIFIED: codebase read]
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — route_to_screen handling, reads `p['prefill']` at line 91 [VERIFIED: codebase read]
- `apps/mobile/lib/providers/coach_profile_provider.dart` — `updateProfile()` at line 707 [VERIFIED: codebase read]
- `apps/mobile/lib/providers/financial_plan_provider.dart` — `_checkStaleness()` at line 86 [VERIFIED: codebase read]
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` — existing `_autoFillFromProfile()` [VERIFIED: codebase read]
- `apps/mobile/lib/screens/mortgage/affordability_screen.dart` — no profile integration confirmed [VERIFIED: codebase read]
- `services/backend/app/services/coach/coach_tools.py` — `route_to_screen` schema missing `prefill` field [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` line 83 comment confirms intent-to-route resolution is deferred to Phase 6 [VERIFIED: codebase read]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project, no new dependencies
- Architecture: HIGH — all patterns verified by reading existing production code
- Pitfalls: HIGH — identified by tracing actual code paths in the 6 target screens
- Write-back pattern: MEDIUM — CoachProfile.copyWith() usage confirmed; exact fields to write back per screen need per-screen verification of what `copyWith()` accepts

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable codebase; only invalidated by Phase 2 completion changing tool dispatch architecture)
