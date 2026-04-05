# Phase 4: Plan Generation — Research

**Researched:** 2026-04-05
**Domain:** Flutter persistent financial plan model, coach tool integration, SharedPreferences persistence, ChangeNotifier providers
**Confidence:** HIGH

---

## Summary

Phase 4 builds a `FinancialPlan` artifact that a user receives after declaring a goal to the coach. The plan is calculator-backed (not LLM-hallucinated), persisted locally, and surfaced as a card on the Aujourd'hui tab. The key integration points are: the existing coach tool-calling pipeline (`ToolCallParser` → `ChatToolDispatcher` → `WidgetRenderer`), the `CoachProfileProvider` for profile-change detection, and `SharedPreferences` for persistence (following established patterns in `ReportPersistenceService` and `GoalTrackerService`).

All required infrastructure already exists. This phase is an **assembly** phase — ~5 new files and targeted insertions into 3 existing files. No new dependencies are required. The heaviest work is in `PlanGenerationService` (the computation logic using `ArbitrageEngine` / `MonteCarloProjectionService`) and `FinancialPlanProvider` (the staleness detection via profile hash).

**Primary recommendation:** Follow the established `GoalTrackerService` persistence pattern exactly. Use `uuid` (already in pubspec) for plan IDs. Register `GENERATE_FINANCIAL_PLAN` in `ToolCallParser.validRoutes` is not needed — tool names are not routes; register it in `WidgetRenderer`'s switch and in the backend system prompt.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: FinancialPlan Model**
Create `lib/models/financial_plan.dart` with: `id`, `goalDescription`, `goalCategory` (from GoalTemplate enum), `monthlyTarget` (CHF), `milestones` (List of dated intermediate targets), `projectedOutcome` (CHF at target date), `targetDate`, `generatedAt`, `profileHashAtGeneration`, `coachNarrative` (human-readable explanation), `confidenceLevel`, `sources` (legal refs). JSON serializable for SharedPreferences.

**D-02: generate_financial_plan Tool**
Add a new tool name `GENERATE_FINANCIAL_PLAN` to the coach tool calling system. The LLM produces a JSON payload with: `goal`, `monthly_amount`, `milestones` (array of {date, target, description}), `projected_outcome`, `narrative`. `ChatToolDispatcher` normalizes it. `WidgetRenderer` displays an inline `PlanPreviewCard` in chat. The plan is simultaneously persisted.

**D-03: Plan Computation Approach**
Numbers come from EXISTING calculators:
- Monthly savings target → goal amount ÷ months remaining, adjusted by `ArbitrageEngine.compareLumpSumVsAnnuity` for retirement goals
- Milestones → quarterly checkpoints (25%/50%/75%/100% of target)
- Projected outcome → `MonteCarloService.runSimulation()` for confidence bands (low/mid/high)
The LLM provides the narrative and goal extraction; numbers are calculator-backed.

**D-04: Plan Persistence**
Store in SharedPreferences under key `financial_plan_v1` as JSON. Use `SecureWizardStore` pattern if plan contains sensitive amounts. Max 3 active plans (oldest auto-archived). `FinancialPlanService` handles CRUD.

**D-05: FinancialPlanProvider**
A `ChangeNotifier` provider that:
- Loads plan from persistence on init
- Exposes `currentPlan`, `hasPlan`, `isPlanStale`
- Listens to `CoachProfileProvider` — when salary/savings change, marks plan as stale via `profileHashAtGeneration` comparison
- Stale plan shows a "recalculer" prompt, doesn't auto-regenerate

**D-06: FinancialPlanCard on MintHomeScreen**
Add as a conditional section after ChiffreVivantCard (Section 1). Shows:
- Goal description + target date
- Monthly target amount (prominent number)
- Progress bar (0% initially)
- "Voir le détail" CTA
- If stale: amber badge "Profil modifié — recalculer"
- If no plan: section hidden (not an empty state card)

**D-07: Plan Generation Flow**
1. User tells coach goal → Coach extracts → calls `GENERATE_FINANCIAL_PLAN`
2. `PlanGenerationService.generate()` computes numbers from financial_core
3. Plan persisted + inline `PlanPreviewCard` in chat
4. Plan accessible from MintHomeScreen `FinancialPlanCard`

**D-08: Plan-Profile Linkage**
`profileHashAtGeneration` = hash of (salary, lppAvoir, 3aCapital, canton, birthDate). When any of these change in `CoachProfile`, hash mismatches → plan marked stale.

**D-09: Integration**
- `GoalTrackerService` → create/update `UserGoal` when plan generated
- `PlannedMonthlyContribution` → when plan accepted, optionally add to wizard's `plannedContributions`
- `CapSequenceEngine` → plan generation triggers `CapMemory` update (goal declared)

### Claude's Discretion
- Exact LLM prompt for goal extraction and narrative generation
- Whether the plan detail view is a new screen or an expandable section
- Animation style for PlanPreviewCard in chat
- Whether to show Monte Carlo confidence bands or simplified low/mid/high
- Milestone naming conventions

### Deferred Ideas (OUT OF SCOPE)
- Plan sharing/export as PDF → Phase 8 or later
- Multiple concurrent plans → v2 (max 3 for now, but UI shows only the active one)
- Plan comparison ("what if I save 500 more per month?") → Phase 5 check-in context
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PLN-01 | Coach generates a personalized financial plan from user's declared goal (e.g., "acheter un appartement dans 3 ans" → monthly savings target, timeline, milestones) | `PlanGenerationService` uses `ArbitrageEngine` + simple division; `GENERATE_FINANCIAL_PLAN` tool in `WidgetRenderer` dispatch pipeline |
| PLN-02 | Generated plan includes chiffered milestones (monthly amount, intermediate targets, projected outcome) | `MonteCarloProjectionService.simulate()` provides low/mid/high bands; quarterly milestone formula is arithmetic on `goalAmount` |
| PLN-03 | Plan is visible as a persistent artifact (not buried in chat history) — accessible from profile or Aujourd'hui tab | `SharedPreferences` under `financial_plan_v1`, `FinancialPlanCard` injected between Section 1 and Section 2 of `MintHomeScreen` |
| PLN-04 | Plan adapts when user profile changes (salary increase, new goal, life event) | `FinancialPlanProvider` hashes (salary, lppAvoir, 3aCapital, canton, birthDate) and marks plan stale on mismatch; explicit recalculation only |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `shared_preferences` | ^2.3.2 | Plan persistence as JSON | [VERIFIED: pubspec.yaml] Already used by `GoalTrackerService`, `ReportPersistenceService` |
| `flutter_secure_storage` | ^9.0.0 | Sensitive amount protection | [VERIFIED: pubspec.yaml] Already used by `SecureWizardStore` (FINMA/nLPD compliance) |
| `uuid` | ^4.0.0 | Plan ID generation | [VERIFIED: pubspec.yaml] Already used by `CoachProfileProvider` |
| `provider` | ^6.1.1 | `FinancialPlanProvider` ChangeNotifier | [VERIFIED: pubspec.yaml] All MINT providers use this |
| `dart:convert` | SDK | JSON encode/decode | [VERIFIED: codebase] Used across all persistence services |

### Financial Core (existing — no new deps)
| Calculator | Method | Role in Phase |
|-----------|--------|---------------|
| `ArbitrageEngine` | `compareLumpSumVsAnnuity()` | Retirement goal monthly target |
| `MonteCarloProjectionService` | `simulate()` | Projected outcome confidence bands |
| `TaxCalculator` | `capitalWithdrawalTax()` | Tax-adjusted projections for 2e/3a pilier goals |

**No new dependencies required.** [VERIFIED: pubspec.yaml audit]

**Installation:** None needed. All libraries already in pubspec.yaml.

---

## Architecture Patterns

### Recommended File Structure
```
apps/mobile/lib/
  models/
    financial_plan.dart          # NEW — FinancialPlan + PlanMilestone models
  services/
    financial_plan_service.dart  # NEW — CRUD for SharedPreferences persistence
    plan_generation_service.dart # NEW — compute numbers from financial_core
  providers/
    financial_plan_provider.dart # NEW — ChangeNotifier, staleness detection
  widgets/
    home/
      financial_plan_card.dart   # NEW — card for MintHomeScreen
    coach/
      plan_preview_card.dart     # NEW — inline chat widget after tool call
```

### Pattern 1: Persistence following GoalTrackerService
**What:** Static service class with `SharedPreferences` CRUD, JSON encode/decode, max-N eviction, and no side effects.
**When to use:** For all plan persistence in `FinancialPlanService`.

```dart
// Source: [VERIFIED: apps/mobile/lib/services/coach/goal_tracker_service.dart]
// Pattern: static async methods, single key, JSON list, evict oldest
static const String _plansKey = 'financial_plan_v1';
static const int _maxPlans = 3;

static Future<List<FinancialPlan>> loadAll() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_plansKey);
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list.map((j) => FinancialPlan.fromJson(j)).toList();
  } catch (_) {
    return [];
  }
}

static Future<void> save(FinancialPlan plan) async {
  final plans = await loadAll();
  plans.removeWhere((p) => p.id == plan.id); // upsert
  plans.insert(0, plan); // newest first
  if (plans.length > _maxPlans) {
    plans.removeRange(_maxPlans, plans.length); // evict oldest
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
}
```

### Pattern 2: ChangeNotifier with cross-provider staleness detection
**What:** Provider listens to another provider via `addListener` in a deferred post-frame callback (prevents build-time mutations).
**When to use:** `FinancialPlanProvider` watching `CoachProfileProvider`.

```dart
// Source: [VERIFIED: apps/mobile/lib/providers/coach_profile_provider.dart — pattern]
// Anti-pattern: calling notifyListeners() inside another provider's listener
// during a build. Use SchedulerBinding.instance.addPostFrameCallback.

class FinancialPlanProvider extends ChangeNotifier {
  FinancialPlan? _currentPlan;
  bool _isStale = false;

  FinancialPlan? get currentPlan => _currentPlan;
  bool get hasPlan => _currentPlan != null;
  bool get isPlanStale => _isStale;

  void attachProfileProvider(CoachProfileProvider profileProvider) {
    profileProvider.addListener(() {
      _checkStaleness(profileProvider.profile);
    });
  }

  void _checkStaleness(CoachProfile? profile) {
    if (_currentPlan == null || profile == null) return;
    final currentHash = _computeProfileHash(profile);
    if (currentHash != _currentPlan!.profileHashAtGeneration) {
      _isStale = true;
      notifyListeners();
    }
  }
}
```

### Pattern 3: Tool registration in WidgetRenderer
**What:** Add `case 'generate_financial_plan':` to `WidgetRenderer.build()` switch. The tool name in the switch is snake_case (ChatToolDispatcher lowercases SCREAMING_SNAKE_CASE).
**When to use:** All new coach tools that render inline widgets.

```dart
// Source: [VERIFIED: apps/mobile/lib/widgets/coach/widget_renderer.dart]
case 'generate_financial_plan':
  return _buildPlanPreviewCard(context, call.input);
```

### Pattern 4: Profile hash computation
**What:** Deterministic string hash of key profile fields. Use `dart:convert` `utf8.encode` + manual XOR or simply `Object.hash()` cast to string. Must be stable across sessions.
**When to use:** `profileHashAtGeneration` computation in `PlanGenerationService` and `FinancialPlanProvider._checkStaleness()`.

```dart
// Source: [ASSUMED — standard Dart pattern; Object.hash is runtime-stable within a session
// but NOT across sessions since it uses random salt in release mode]
// CRITICAL: DO NOT use Object.hash() for cross-session persistence.
// Use a deterministic hash: combine fields into a string and use a stable hash.
String computeProfileHash(CoachProfile profile) {
  final raw = '${profile.salaireBrutAnnuel}'
      '${profile.prevoyance?.avoirLppTotal}'
      '${profile.prevoyance?.totalEpargne3a}'
      '${profile.canton}'
      '${profile.dateOfBirth?.toIso8601String()}';
  // Simple stable hash: sum of char codes mod 1e9 (no dart:crypto needed)
  int hash = 0;
  for (final c in raw.runes) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return hash.toString();
}
```

### Anti-Patterns to Avoid
- **Letting the LLM produce the numbers:** Decision D-03 is locked. LLM only produces `narrative` and `goal` string. All CHF values come from `PlanGenerationService` calling financial_core calculators. Violations break the no-hallucination guarantee.
- **Using `Object.hash()` for `profileHashAtGeneration`:** Flutter's `Object.hash()` uses a random salt in release mode — not stable across app restarts. Build a deterministic string hash instead.
- **Storing raw salary amounts in SharedPreferences plain JSON:** `monthlyTarget` is a financial amount. Follow `SecureWizardStore` pattern for amounts > 0 — store in `flutter_secure_storage` if it qualifies as PII. At minimum, store amounts as numbers (not strings with currency formatting).
- **Auto-regenerating the plan on profile change:** Decision D-05 is explicit: stale plan shows a prompt, user must confirm recalculation. Never auto-regenerate silently.
- **Adding the plan card as an empty state:** Decision D-06 is explicit: if no plan, the section is hidden entirely. No empty state card.
- **Registering `GENERATE_FINANCIAL_PLAN` in `ToolCallParser.validRoutes`:** That whitelist is for `route_to_screen` tool's route parameter — not for tool names. Tool names are dispatched via `WidgetRenderer`'s switch.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Monthly savings math with compound interest | Custom FV formula | `ArbitrageEngine.compareLumpSumVsAnnuity()` | Already handles LPP taux, inflation, tax; edge cases covered |
| Confidence bands for projected outcome | Custom Monte Carlo | `MonteCarloProjectionService.simulate()` | 1000-simulation isolate runner, P10/P25/P50/P75/P90, legal disclaimers baked in |
| UUID generation | `DateTime.now().millisecondsSinceEpoch` | `uuid` package `const Uuid().v4()` | Collision-free, already in pubspec |
| Persistence serialization | Custom binary encoding | `dart:convert` `jsonEncode/jsonDecode` | Pattern used by all 6 existing persistence services |
| Profile data quality weighting | Custom confidence logic | `EnhancedConfidence` / `confidence_scorer.dart` | 4-axis geometric mean, `ProfileDataSource` weights |

**Key insight:** Every complex financial computation in this phase has an existing calculator. The planner must not schedule tasks to build new math — only to wire existing services.

---

## Runtime State Inventory

Phase 4 is a greenfield feature addition (no rename or migration). No runtime state inventory required.

---

## Common Pitfalls

### Pitfall 1: MonteCarloProjectionService requires a full CoachProfile
**What goes wrong:** `MonteCarloProjectionService.simulate()` takes a `CoachProfile` — not individual fields. If `PlanGenerationService` tries to call it with a partial/mock profile, it will produce nonsense or null-reference errors.
**Why it happens:** The service uses `profile.prevoyance`, `profile.salaireBrutAnnuel`, `profile.dateOfBirth` etc. internally. A housing goal doesn't have a "retirement age" but the service still expects one.
**How to avoid:** For non-retirement goals (housing, 3a), use the simpler arithmetic formula only (goalAmount ÷ monthsRemaining × (1 + assumed rendement factor)). Reserve Monte Carlo for retirement-type goals or when the profile is known-complete. Check `profile.confidenceScore` before calling Monte Carlo — if < 40%, skip Monte Carlo and use deterministic projection.
**Warning signs:** `NullPointerException` inside isolate, or wildly high/low projected outcomes.

### Pitfall 2: Tool name case sensitivity in WidgetRenderer dispatch
**What goes wrong:** The tool name `GENERATE_FINANCIAL_PLAN` in the LLM output is lowercased by `ChatToolDispatcher.normalize()` before reaching `WidgetRenderer.build()`. If `WidgetRenderer` registers the case as `'GENERATE_FINANCIAL_PLAN'` or `'generateFinancialPlan'`, the case is never handled and `build()` returns null silently.
**Why it happens:** `ChatToolDispatcher.normalize()` calls `.toLowerCase()` on all tool names before dispatch. [VERIFIED: apps/mobile/lib/services/coach/chat_tool_dispatcher.dart line 52]
**How to avoid:** Register in `WidgetRenderer` switch as `'generate_financial_plan'` (all lowercase snake_case).

### Pitfall 3: FinancialPlanProvider notify during build
**What goes wrong:** If `FinancialPlanProvider` calls `notifyListeners()` synchronously inside a `CoachProfileProvider` listener, and that listener fires during a build frame, Flutter throws `setState() called during build`.
**Why it happens:** Provider notifications can fire synchronously during the widget rebuild triggered by CoachProfileProvider's own change.
**How to avoid:** Wrap `notifyListeners()` calls in `SchedulerBinding.instance.addPostFrameCallback((_) { notifyListeners(); })` when responding to external provider events.

### Pitfall 4: JSON parse failure corrupts persisted plans
**What goes wrong:** A crash during plan generation may write a partial JSON string to SharedPreferences. On next load, `jsonDecode` throws, and the entire plans list is lost.
**Why it happens:** SharedPreferences writes are not transactional.
**How to avoid:** Wrap `jsonDecode` in try/catch (as `GoalTrackerService` does). On decode failure, return empty list and optionally clear the corrupted key. Never propagate the exception to the UI.

### Pitfall 5: i18n for all plan card strings
**What goes wrong:** Hardcoding strings like "Profil modifié — recalculer" or "Voir le détail" in widget code.
**Why it happens:** Widget code is written quickly without checking CLAUDE.md i18n rule.
**How to avoid:** All user-facing strings must be in all 6 ARB files before any widget code. Add keys to `app_fr.arb` first (template), then propagate to en, de, es, it, pt. Run `flutter gen-l10n` after each ARB change.

### Pitfall 6: Monthly target ignores goal category
**What goes wrong:** Applying the same simple division formula (`goalAmount ÷ months`) to ALL goal categories. A retirement goal needs compounding; a housing EPL goal needs EPL eligibility check (min 20k OPP2).
**Why it happens:** `PlanGenerationService` is written generically without branching on `goalCategory`.
**How to avoid:** Branch on `goalCategory` in `PlanGenerationService.generate()`: housing goals → check EPL eligibility constraint (min 20k from `CoachProfile.prevoyance?.avoirLppTotal`, min 3 year lock), retirement goals → use `ArbitrageEngine`, generic goals → arithmetic.

---

## Code Examples

### FinancialPlan model skeleton
```dart
// Source: [VERIFIED: pattern from apps/mobile/lib/services/coach/goal_tracker_service.dart]
// + decisions D-01 from 04-CONTEXT.md

class PlanMilestone {
  final DateTime targetDate;    // quarterly checkpoint
  final double targetAmount;    // CHF at this milestone
  final String description;     // e.g. "25% atteint"

  const PlanMilestone({
    required this.targetDate,
    required this.targetAmount,
    required this.description,
  });

  factory PlanMilestone.fromJson(Map<String, dynamic> json) => PlanMilestone(
    targetDate: DateTime.parse(json['targetDate'] as String),
    targetAmount: (json['targetAmount'] as num).toDouble(),
    description: json['description'] as String,
  );

  Map<String, dynamic> toJson() => {
    'targetDate': targetDate.toIso8601String(),
    'targetAmount': targetAmount,
    'description': description,
  };
}

class FinancialPlan {
  final String id;
  final String goalDescription;
  final String goalCategory;       // GoalTemplate.id
  final double monthlyTarget;      // CHF — hero number
  final List<PlanMilestone> milestones;
  final double projectedOutcome;   // CHF at targetDate (mid scenario)
  final double? projectedLow;      // Monte Carlo P25
  final double? projectedHigh;     // Monte Carlo P75
  final DateTime targetDate;
  final DateTime generatedAt;
  final String profileHashAtGeneration;
  final String coachNarrative;
  final double confidenceLevel;    // 0-100
  final List<String> sources;      // legal refs
  final String disclaimer;         // always present (LSFin)

  // ... toJson / fromJson / copyWith
}
```

### Quarterly milestone generation
```dart
// Source: [ASSUMED — arithmetic on goalAmount; pattern matches D-03 quarterly spec]
static List<PlanMilestone> _generateMilestones(
  double goalAmount,
  DateTime targetDate,
) {
  final now = DateTime.now();
  final totalMonths = (targetDate.year - now.year) * 12 +
      (targetDate.month - now.month);
  final milestones = <PlanMilestone>[];
  for (int pct in [25, 50, 75, 100]) {
    final monthsOut = (totalMonths * pct / 100).round();
    final date = DateTime(now.year, now.month + monthsOut);
    milestones.add(PlanMilestone(
      targetDate: date,
      targetAmount: goalAmount * pct / 100,
      description: '$pct\u00a0% atteint',
    ));
  }
  return milestones;
}
```

### WidgetRenderer case registration
```dart
// Source: [VERIFIED: apps/mobile/lib/widgets/coach/widget_renderer.dart — switch pattern]
case 'generate_financial_plan':
  return _buildPlanPreviewCard(context, call.input);

static Widget _buildPlanPreviewCard(
    BuildContext context, Map<String, dynamic> p) {
  // p comes from LLM tool call: goal, monthly_amount, narrative, projected_outcome
  // Numbers are IGNORED from LLM — only narrative is used
  // The real FinancialPlan is persisted separately by PlanGenerationService
  return PlanPreviewCard(
    goalDescription: p['goal'] as String? ?? '',
    // monthlyTarget is read from the persisted plan, not from p
  );
}
```

### MintHomeScreen insertion point
```dart
// Source: [VERIFIED: apps/mobile/lib/screens/main_tabs/mint_home_screen.dart lines 154-172]
// Section 1 is _ChiffreVivantCard. New section goes between Section 1 and Section 2.
// Pattern: conditional Padding widget, same as Section 2 (_ItineraireAlternatifCard).

// ── Section 1b: Financial Plan Card ──
if (context.watch<FinancialPlanProvider>().hasPlan)
  Padding(
    padding: const EdgeInsets.only(bottom: MintSpacing.xl),
    child: FinancialPlanCard(
      plan: context.watch<FinancialPlanProvider>().currentPlan!,
      isStale: context.watch<FinancialPlanProvider>().isPlanStale,
      onRecalculate: () => widget.onSwitchToCoach?.call(
        CoachEntryPayload(source: CoachEntrySource.planRecalculate),
      ),
    ),
  ),
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LLM produces CHF numbers directly | Calculator-backed numbers, LLM only narrates | D-03 (locked) | Eliminates hallucinated financial advice |
| Plan buried in chat history | Persistent card on Aujourd'hui tab | D-06 (locked) | Addresses PLN-03 directly |
| Manual adherence tracking | `PlanTrackingService.evaluate()` already exists | Post-S53 | Phase 4 must integrate; Phase 5 adds the check-in flow |

**Deprecated/outdated:**
- Legacy `GoalA`/`GoalB` types in `CoachProfile`: still used but the new `FinancialPlan` is separate and more structured. Do NOT replace GoalA — they serve different purposes (GoalA = profile metadata, FinancialPlan = generated artifact).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Object.hash()` uses random salt in release mode, making it unsuitable for cross-session persistence | Architecture Patterns | If wrong: code still works but is overly cautious; the manual hash is always safe regardless |
| A2 | Backend system prompt can be updated to include `GENERATE_FINANCIAL_PLAN` tool definition without changes to backend service files | Standard Stack | If wrong: backend changes needed before the tool fires; add backend task to plan |
| A3 | `MonteCarloProjectionService.simulate()` returns meaningful results for non-retirement goals (housing, 3a) when profile has partial data | Common Pitfalls | If wrong: housing goals should use deterministic formula only — planner should make this explicit per goal category |

---

## Open Questions

1. **Backend tool definition: where does `GENERATE_FINANCIAL_PLAN` get declared?**
   - What we know: Existing tools are registered in `ToolCallParser` (SLM text-marker path) and in the backend system prompt (BYOK path via `claude_coach_service.py`)
   - What's unclear: The CONTEXT.md says "Add a new tool name `GENERATE_FINANCIAL_PLAN` to the coach tool calling system" but doesn't specify if this requires a backend system-prompt update or only a frontend parser change. `ToolCallParser._pattern` matches `[TOOL_NAME:{json}]` in text — so the SLM path requires no backend change, just frontend parsing + WidgetRenderer case. The BYOK Claude path requires the tool be defined in the system prompt on the backend.
   - Recommendation: Plan tasks for BOTH paths: (1) add `'generate_financial_plan'` to `WidgetRenderer` switch (Flutter); (2) add tool definition to backend system prompt in `claude_coach_service.py`.

2. **SecureWizardStore for monthlyTarget: threshold?**
   - What we know: `SecureWizardStore` protects `q_gross_salary`, `q_lpp_avoir`, etc. The `FinancialPlan.monthlyTarget` is a derived amount, not raw PII.
   - What's unclear: Whether a derived CHF amount (e.g., "épargne 850 CHF/mois") is considered PII under nLPD.
   - Recommendation: Store the plan JSON in plain SharedPreferences (consistent with `GoalTrackerService`). The plan's `goalDescription` string must NOT contain the user's name, employer, or IBAN (anonymization like GoalTrackerService).

---

## Environment Availability

Step 2.6: SKIPPED — Phase 4 is a pure Flutter code/widget change. No new external services, CLI tools, or databases. All dependencies already installed in `pubspec.yaml`. [VERIFIED: pubspec.yaml audit]

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK built-in) |
| Config file | none — standard flutter test runner |
| Quick run command | `cd apps/mobile && flutter test test/services/plan_generation_service_test.dart test/models/financial_plan_test.dart test/providers/financial_plan_provider_test.dart -x` |
| Full suite command | `cd apps/mobile && flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLN-01 | `PlanGenerationService.generate()` produces a plan from a goal string + profile | unit | `flutter test test/services/plan_generation_service_test.dart` | Wave 0 |
| PLN-01 | `WidgetRenderer` handles `generate_financial_plan` tool call without returning null | unit | `flutter test test/widgets/coach/widget_renderer_test.dart` | Wave 0 (extend existing pattern) |
| PLN-02 | Plan milestones are 4 quarterly checkpoints at 25/50/75/100% of goalAmount | unit | `flutter test test/models/financial_plan_test.dart` | Wave 0 |
| PLN-02 | `monthlyTarget` equals goalAmount ÷ monthsRemaining (base case, no compounding) | unit | `flutter test test/services/plan_generation_service_test.dart` | Wave 0 |
| PLN-03 | `FinancialPlanService.save()` and `loadCurrent()` round-trip through JSON | unit | `flutter test test/services/financial_plan_service_test.dart` | Wave 0 |
| PLN-03 | `FinancialPlanProvider.hasPlan` is true after save, false after clear | unit | `flutter test test/providers/financial_plan_provider_test.dart` | Wave 0 |
| PLN-04 | Profile hash changes when salary changes → `isPlanStale` becomes true | unit | `flutter test test/providers/financial_plan_provider_test.dart` | Wave 0 |
| PLN-04 | Profile hash unchanged when unrelated field changes | unit | `flutter test test/providers/financial_plan_provider_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/plan_generation_service_test.dart test/models/financial_plan_test.dart -x`
- **Per wave merge:** `flutter test && flutter analyze`
- **Phase gate:** Full suite green + 0 flutter analyze issues before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/models/financial_plan_test.dart` — covers FinancialPlan JSON round-trip, milestone generation, PLN-02
- [ ] `test/services/plan_generation_service_test.dart` — covers PLN-01, PLN-02 computation
- [ ] `test/services/financial_plan_service_test.dart` — covers PLN-03 persistence CRUD, max-3 eviction
- [ ] `test/providers/financial_plan_provider_test.dart` — covers PLN-04 staleness detection, hash stability

*(Existing `test/widgets/coach/widget_renderer_test.dart` pattern can be extended for the new tool case — no new file needed there.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | `goalDescription` from LLM tool call must be length-capped; `monthlyTarget` must be positive finite double; `milestones` list capped at 4 |
| V6 Cryptography | no | Using `flutter_secure_storage` (platform crypto, not hand-rolled) |

### Known Threat Patterns for Coach Tool Pipeline

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| LLM injects malformed JSON in tool call payload | Tampering | `ChatToolDispatcher.normalize()` already caps at 5 tool calls; `WidgetRenderer` must null-check all `p['field']` accesses |
| Persisted plan with negative or infinite `monthlyTarget` | Tampering | Validate all numeric fields in `FinancialPlan.fromJson()` — clamp to `[0, 1e7]` range |
| `goalDescription` containing PII (name, IBAN, employer) | Information Disclosure | Apply same anonymization as `GoalTrackerService` — coach should extract goal text, not verbatim user message |

**Existing mitigation already in place:** `ChatToolDispatcher` caps tool calls at 5 per response (T-02-07). `ToolCallParser` ignores malformed JSON silently. `WidgetRenderer` returns null for unknown tool names. [VERIFIED: source files]

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: apps/mobile/lib/services/coach/chat_tool_dispatcher.dart] — Tool dispatch pipeline, lowercasing, cap behavior
- [VERIFIED: apps/mobile/lib/services/coach/tool_call_parser.dart] — Parser pattern, route whitelist (not tool name whitelist)
- [VERIFIED: apps/mobile/lib/widgets/coach/widget_renderer.dart] — Switch dispatch pattern, existing tool cases
- [VERIFIED: apps/mobile/lib/services/coach/goal_tracker_service.dart] — Persistence pattern: SharedPreferences, JSON, max eviction
- [VERIFIED: apps/mobile/lib/services/report_persistence_service.dart] — SecureWizardStore integration pattern
- [VERIFIED: apps/mobile/lib/services/financial_core/monte_carlo_service.dart] — `simulate()` signature, CoachProfile requirement, isolate usage
- [VERIFIED: apps/mobile/lib/services/financial_core/arbitrage_engine.dart] — `compareLumpSumVsAnnuity()` signature, pure static
- [VERIFIED: apps/mobile/lib/screens/main_tabs/mint_home_screen.dart] — Section structure, insertion point between Section 1 and 2
- [VERIFIED: apps/mobile/lib/models/coach_profile.dart] — `PlannedMonthlyContribution`, `MonthlyCheckIn`, `GoalA`, profile hash fields
- [VERIFIED: apps/mobile/lib/models/goal_template.dart] — `GoalTemplate` canonical IDs (7 templates)
- [VERIFIED: apps/mobile/pubspec.yaml] — All required dependencies present, no new deps needed
- [VERIFIED: .planning/config.json] — `nyquist_validation: true`

### Secondary (MEDIUM confidence)
- [VERIFIED: apps/mobile/lib/services/secure_wizard_store.dart] — Sensitive keys set; derived amounts not included
- [VERIFIED: apps/mobile/lib/providers/coach_profile_provider.dart] — ChangeNotifier pattern, `addListener` usage

### Tertiary (LOW confidence — assumptions)
- A1: `Object.hash()` random salt in release mode → flagged in Assumptions Log
- A2: Backend system prompt update required for BYOK path
- A3: Monte Carlo behavior with partial profile for non-retirement goals

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all verified against pubspec.yaml and existing service files
- Architecture: HIGH — all patterns verified against existing codebase; insertion points confirmed
- Pitfalls: HIGH for tool dispatch and persistence patterns (verified); MEDIUM for Monte Carlo partial-profile behavior (A3 assumed)

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable stack)
