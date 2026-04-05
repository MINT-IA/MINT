# Phase 5: Suivi & Check-in - Research

**Researched:** 2026-04-05
**Domain:** Flutter wiring — conversational check-in, local notifications, home screen integration, cross-session memory injection
**Confidence:** HIGH

## Summary

Phase 5 is a pure wiring phase. Every component already exists and is individually tested. The work is to connect them: (1) route notification taps to open the coach with a check-in payload, (2) implement the conversational multi-step check-in as a coach tool flow, (3) surface PlanRealityCard + StreakBadgeWidget on MintHomeScreen, and (4) inject past check-in data into ConversationMemoryService so the LLM references it naturally.

The main risk is not missing components but unconnected joints: the `generate_financial_plan` tool is the only existing coach tool with a Flutter-side handler in WidgetRenderer — `INITIATE_CHECK_IN` and `RECORD_CHECK_IN` do not yet exist anywhere in the backend tool list (`coach_tools.py`) or the Flutter dispatcher (`widget_renderer.dart`). That end-to-end pipe must be built fresh, following the exact same pattern established by `generate_financial_plan`.

A secondary risk is the notification scheduling bug: `_scheduleMonthlyCheckin()` has dead logic (`now.day >= 1` is always true) that makes it always schedule for "next month" instead of "current month if before the 1st". This does not affect Phase 5 behavior (notifications fire correctly in practice) but is worth noting for the 5-day reminder task.

**Primary recommendation:** Follow the `generate_financial_plan` → `PlanPreviewCard` pipeline exactly. Add `record_check_in` to `coach_tools.py`, handle it in `widget_renderer.dart`, and wire `CoachEntryPayload(source: notification, topic: 'monthlyCheckIn')` from the notification tap path.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Check-in Conversation Flow**
- Coach initiates in chat — on nudge tap or home card tap, coach sends "Salut ! C'est le moment de faire le point. Combien as-tu verse ce mois sur ton 3a ?" (adapted to the user's plan contributions)
- Natural language amount entry — user types "500" or "j'ai verse 500", parser extracts amount and creates MonthlyCheckIn entry
- Sequential multi-contribution handling — after first answer, coach asks about next PlannedMonthlyContribution ("Et sur ton epargne libre ?") until all plan items are covered
- Coach summarizes and saves — "Parfait, 500 CHF sur le 3a et 200 CHF en epargne libre. C'est note !" then PlanRealityCard updates inline in chat

**Notification & Nudge Timing**
- Check-in nudge fires on 1st of each month at 10:00 via existing NotificationService.scheduleNotification(), recurring monthly
- Single reminder after 5 days if user hasn't checked in — "Tu n'as pas encore fait ton point du mois. 2 minutes suffisent !"
- Nudge tap opens coach chat with check-in pre-loaded — coach immediately asks the first contribution question
- Use existing JITAI streakAtRisk trigger — fires 2 days before month-end if no check-in recorded for the current month

**Aujourd'hui Integration & Streak Display**
- PlanRealityCard goes in Section 2 on MintHomeScreen (after Chiffre Vivant + Premier Eclairage), only visible when user has >= 1 check-in
- Streak display integrated inside PlanRealityCard header — compact StreakBadgeWidget (already exists)
- When no check-in yet: show "Ton premier point" CTA card — "Fais ton premier point du mois pour voir ta progression ici", tap opens coach chat
- Coach references past check-in contextually during check-in flow — "Le mois dernier tu avais verse 500 CHF, tu continues sur cette lancee ?" injected via ConversationMemoryService

### Claude's Discretion
- Amount parsing implementation details (regex vs NLP)
- Exact notification string wording (must use i18n ARB keys)
- Animation timing for PlanRealityCard appearance on Aujourd'hui
- Error handling for edge cases (no plan yet, incomplete plan)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SUI-01 | Monthly check-in is proactively triggered (nudge/notification when it's time) | NotificationService._scheduleMonthlyCheckin() exists; 5-day reminder and JITAI streakAtRisk require new scheduling logic |
| SUI-02 | Check-in flow is conversational (coach asks "combien as-tu versé ce mois?") not a form | Requires new `record_check_in` tool in coach_tools.py + handler in widget_renderer.dart; follows generate_financial_plan pattern |
| SUI-03 | Progress visualization shows plan vs. reality (PlanRealityCard wired and visible on Aujourd'hui) | PlanRealityCard widget exists but is NOT imported in MintHomeScreen; requires section addition + CoachProfileProvider binding |
| SUI-04 | Coach references past check-ins ("le mois dernier tu avais versé X, ce mois...") | ConversationMemoryService.buildMemory() exists but does not include check-in amounts; requires enrichment |
| SUI-05 | Streak and engagement metrics visible to user (not just tracked silently) | StreakBadgeWidget exists; needs embedding in PlanRealityCard header or as standalone card on MintHomeScreen |
</phase_requirements>

---

## Standard Stack

### Core (all already in pubspec.yaml)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_local_notifications` | in use | Local push scheduling | Already initialized in app.dart, Europe/Zurich TZ set |
| `provider` | in use | ChangeNotifier state | Established project pattern (CoachProfileProvider, FinancialPlanProvider) |
| `shared_preferences` | in use | Check-in persistence, notification cooldowns | Used by NotificationService, NudgePersistence |
| `go_router` | in use | Deep-link routing on notification tap | NotificationService.pendingRoute consumed by MainNavigationShell |

### Supporting Services (all pre-existing, no new files needed)

| Service | File | What It Provides |
|---------|------|-----------------|
| `NotificationService` | `lib/services/notification_service.dart` | Monthly check-in scheduling, streak protection, pendingRoute for deep links |
| `StreakService` | `lib/services/streak_service.dart` | `compute(profile)` → `StreakResult` with currentStreak, badges, nextBadge |
| `PlanTrackingService` | `lib/services/plan_tracking_service.dart` | `evaluate()` → `PlanStatus` (adherenceRate, monthlyGapChf, nextActions) |
| `ConversationMemoryService` | `lib/services/coach/conversation_memory_service.dart` | `buildMemory()` → summary injected into LLM system prompt |
| `JitaiNudgeService` | `lib/services/coach/jitai_nudge_service.dart` | `streakAtRisk` trigger (already has NudgeType.streakAtRisk, fires when streak > 3 and no check-in) |
| `CoachProfileProvider` | `lib/providers/coach_profile_provider.dart` | `addCheckIn()`, `updateContributions()` — persistence + notifyListeners() |

### Widgets (all pre-existing)

| Widget | File | What It Provides |
|--------|------|-----------------|
| `PlanRealityCard` | `lib/widgets/coach/plan_reality_card.dart` | Adherence badge, progress bar, next actions, compound impact box |
| `StreakBadgeWidget` | `lib/widgets/coach/streak_badge.dart` | Fire icon, streak count, progress to next badge |
| `EarnedBadgesRow` | `lib/widgets/coach/streak_badge.dart` | Row of earned badges |

**No new packages required.** [VERIFIED: codebase grep]

---

## Architecture Patterns

### Pattern 1: Coach Tool → Flutter Widget (THE established pipe)

This is the only pattern to follow for SUI-02. The `generate_financial_plan` tool is the reference implementation.

```
Backend coach_tools.py  →  LLM picks tool  →  Backend returns tool_use block
    ↓
Flutter: CoachChatScreen receives response
    ↓
ChatToolDispatcher.normalize() converts ParsedToolCall → RagToolCall (lowercased name)
    ↓
WidgetRenderer.build() dispatches on call.name
    case 'record_check_in': → _buildCheckInSummaryCard(context, call.input)
    ↓
Inline widget appears in chat bubble
    ↓
Widget calls CoachProfileProvider.addCheckIn() → persists + notifyListeners()
    ↓
MintHomeScreen rebuilds: PlanRealityCard becomes visible
```

[VERIFIED: widget_renderer.dart lines 44-68, coach_tools.py structure, financial_plan_provider.dart]

### Pattern 2: Notification Tap → Coach with Pre-loaded Context

```
NotificationService schedules notification with payload: '/coach/checkin'
    ↓
User taps notification
    ↓
_onNotificationTap() stores pendingRoute = '/coach/checkin'
    ↓
MainNavigationShell.consumePendingRoute() reads it
    ↓
GoRouter redirects '/coach/checkin' → '/home?tab=1' (line 340 in app.dart)
    ↓
MintHomeScreen tab switch triggers _switchToCoachWithPayload()
```

**Gap identified**: The current `/coach/checkin` route is a plain redirect to `/home?tab=1` with no `CoachEntryPayload`. To open coach with a check-in pre-loaded, the notification payload must carry data that triggers the payload injection. Options:
- Option A (simpler): Change payload to `/home?tab=1&intent=monthlyCheckIn` and parse the query param in MainNavigationShell to build a `CoachEntryPayload(source: notification, topic: 'monthlyCheckIn')`.
- Option B: Keep `/coach/checkin` route but give it a proper handler that calls `_switchToCoachWithPayload`.

[VERIFIED: notification_service.dart line 376, app.dart line 340, main_navigation_shell.dart lines 82-95]

### Pattern 3: MintHomeScreen Conditional Section

```dart
// Established pattern (lines 178-201):
Builder(builder: (ctx) {
  final provider = ctx.watch<SomeProvider>();
  if (!provider.hasData) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: MintSpacing.xl),
    child: TheWidget(data: provider.data!),
  );
})
```

PlanRealityCard section follows this exact pattern, gated on `profile.checkIns.isNotEmpty`. [VERIFIED: mint_home_screen.dart lines 178-201]

### Pattern 4: Amount Parser (Claude's Discretion)

Recommended: simple regex for numeric extraction.

```dart
// Extracts first decimal number from free text: "j'ai versé 500 CHF" → 500.0
static double? parseAmount(String text) {
  final match = RegExp(r'\d[\d\']*(?:[.,]\d+)?').firstMatch(text);
  if (match == null) return null;
  return double.tryParse(
    match.group(0)!.replaceAll("'", '').replaceAll(',', '.'),
  );
}
```

Swiss format: `1'234.56` uses apostrophe as thousands separator. Parser must strip apostrophes before `double.tryParse`. [ASSUMED — based on Swiss number format knowledge, not tool-verified]

### Pattern 5: ConversationMemory Check-in Enrichment

`ConversationMemoryService.buildMemory()` currently builds its summary from `ConversationMeta` (titles, tags, dates). It does NOT have access to `CoachProfile.checkIns`. Two approaches:

- Option A (recommended): Pass the last check-in amount as a named parameter to `buildMemory()` and append it to the summary string. Example output: "Dernier check-in (mars 2026) : 604 CHF versés au total."
- Option B: Build a separate `buildCheckInMemory(CoachProfile)` helper that returns a 1-line string, injected separately into the system prompt by `ContextInjectorService`.

Option A is cleaner because the summary is already the single injection point consumed by the LLM. [VERIFIED: conversation_memory_service.dart lines 77-129]

### Anti-Patterns to Avoid

- **Creating a new check-in screen**: The flow is conversational — no `Scaffold`, no form. Everything happens inside `CoachChatScreen`.
- **Re-implementing StreakService logic**: `profile.streak` already computes the streak; `StreakService.compute(profile)` returns the full `StreakResult`. Never recompute inline.
- **Calling `notifyListeners()` during build**: `CoachProfileProvider.addCheckIn()` already defers to post-frame — don't add extra `setState` calls in the widget.
- **Duplicating planned contribution data**: PlanTrackingService reads from `profile.checkIns` and `profile.plannedContributions` — pass these directly; do not copy them.
- **Using `MintGlassCard` or `MintPremiumButton`**: Both are deprecated. Use `Card` with `elevation: 0` (as in existing PlanRealityCard) and standard `ElevatedButton`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Streak computation | Custom loop in widget | `StreakService.compute(profile)` | Already handles edge cases: Jan wraps, missed months, `DateTime.now()` normalization |
| Plan adherence score | Custom % calculation | `PlanTrackingService.evaluate()` | 80% threshold logic, average vs. total, gap CHF — all correct |
| Compound impact | FV formula inline | `PlanTrackingService.compoundProjectedImpact()` | FV annuity formula already there with 2% real return disclaimer |
| Notification scheduling | Custom timer | `NotificationService.scheduleCoachingReminders()` | TZ-aware, consent-checked, existing IDs avoid collisions |
| Memory injection | String building | `ConversationMemoryService.buildMemory()` | PII scrubbing, title sanitization, 500-char budget already in place |
| Amount parsing | Full NLP | Simple regex (see Pattern 4) | Input is always financial — "500", "j'ai versé 500", "CHF 500". Regex is sufficient and predictable. |

**Key insight:** Every domain service is tested in isolation. The integration risk is the wiring, not the logic.

---

## Common Pitfalls

### Pitfall 1: Check-in tool not registered in coach_tools.py
**What goes wrong:** Claude never emits `record_check_in` tool calls because the tool doesn't exist in the LLM tool list. Flutter-side handler in WidgetRenderer is unreachable.
**Why it happens:** `generate_financial_plan` was added to widget_renderer.dart (Phase 4) but its backend tool definition was not added to `coach_tools.py` — same gap exists for check-in.
**How to avoid:** Add `record_check_in` to the `COACH_TOOLS` list in `coach_tools.py` BEFORE wiring the Flutter side.
**Warning signs:** Coach never renders inline check-in widgets — falls back to text only.

### Pitfall 2: Notification payload doesn't carry check-in intent
**What goes wrong:** User taps notification → arrives on coach tab → blank chat (no pre-loaded question).
**Why it happens:** `/coach/checkin` is a plain redirect with no payload. `MainNavigationShell` processes the route change but builds no `CoachEntryPayload`.
**How to avoid:** Either add query param `?intent=monthlyCheckIn` to the payload and parse it, or refactor the redirect to call `_switchToCoachWithPayload` with a proper payload.
**Warning signs:** Success criteria 1 passes (nudge fires) but success criteria 2 fails (coach doesn't ask the question immediately).

### Pitfall 3: PlanRealityCard shows before data is ready
**What goes wrong:** Card renders with `PlanStatus(score: 0, completedActions: 0, totalActions: 0)` because `profile.plannedContributions` is empty.
**Why it happens:** `FinancialPlanProvider` stores the high-level `FinancialPlan` — it does NOT contain `PlannedMonthlyContribution` entries. Those live on `CoachProfile.plannedContributions`. The card must be gated on BOTH `checkIns.isNotEmpty` AND `plannedContributions.isNotEmpty`.
**How to avoid:** Gate: `profile.checkIns.isNotEmpty && profile.plannedContributions.isNotEmpty`.
**Warning signs:** Progress bar shows 0% for users who have check-ins but haven't set contributions via Phase 4 plan generation.

### Pitfall 4: Sequential multi-contribution chat state is lost on hot restart
**What goes wrong:** During a check-in conversation, coach tracks "which contribution we're asking about" as in-memory state. If the user backgrounds the app, the state is gone.
**Why it happens:** Conversational state lives in the LLM system prompt context, not in a persistent store.
**How to avoid:** Track check-in progress in SharedPreferences under a key like `_pending_checkin_month` (ISO month string). On coach open with `monthlyCheckIn` intent, check if a partial check-in exists and resume.
**Warning signs:** User answers first contribution question, backgrounds app, returns — coach starts over from the beginning.

### Pitfall 5: 5-day reminder scheduling conflict with monthly notification
**What goes wrong:** 5-day reminder fires but the monthly notification (ID 1000) was already cancelled when `scheduleCoachingReminders()` was called after the previous check-in. The reminder replaces it rather than supplementing it.
**Why it happens:** `scheduleCoachingReminders()` calls `cancelAll()` before scheduling — every call clears all existing notifications.
**How to avoid:** Use a distinct notification ID for the 5-day reminder (e.g., `_idCheckinReminder5d = 1001`). Alternatively, schedule both the 1st-of-month and 5th-of-month notifications in the same `scheduleCoachingReminders()` call.
**Warning signs:** Users who checked in on the 3rd no longer get a reminder on the 5th; users who haven't checked in never get the reminder.

### Pitfall 6: Swiss apostrophe in amount parsing
**What goes wrong:** User types "1'500" → `double.tryParse("1'500")` returns null → check-in records 0 CHF.
**Why it happens:** Swiss number formatting uses `'` as a thousands separator, not supported by Dart's `double.tryParse`.
**How to avoid:** Strip apostrophes before parsing: `text.replaceAll("'", "")`. Also handle comma as decimal: `text.replaceAll(',', '.')`.
**Warning signs:** Check-in records 0 for amounts over 999 CHF entered with Swiss formatting.

---

## Code Examples

### Add `record_check_in` tool to coach_tools.py (backend)

```python
# Source: follows existing pattern from coach_tools.py lines 107-140
{
    "name": "record_check_in",
    "description": (
        "Record the user's monthly check-in contributions. "
        "Use when the user has answered all contribution questions. "
        "Displays a summary card in chat and persists data to profile."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "month": {
                "type": "string",
                "description": "ISO month string YYYY-MM (e.g. '2026-04')"
            },
            "versements": {
                "type": "object",
                "description": "Map of contribution_id -> amount (e.g. {'3a_julien': 500.0})"
            },
            "summary_message": {
                "type": "string",
                "description": "Coach summary to display (e.g. 'Parfait, 500 CHF sur le 3a!')"
            }
        },
        "required": ["month", "versements", "summary_message"]
    }
}
```

### Handle `record_check_in` in widget_renderer.dart

```dart
// In WidgetRenderer.build() switch, after 'generate_financial_plan':
case 'record_check_in':
  return _buildCheckInSummaryCard(context, call.input, onInputSubmitted);
```

### PlanRealityCard section in MintHomeScreen

```dart
// Source: follows FinancialPlanCard section pattern (mint_home_screen.dart lines 178-201)
Builder(builder: (ctx) {
  final profile = ctx.watch<CoachProfileProvider>().profile;
  if (profile == null) return const SizedBox.shrink();
  if (profile.checkIns.isEmpty || profile.plannedContributions.isEmpty) {
    return _CheckInCtaCard(onTap: () => widget.onSwitchToCoach?.call(
      CoachEntryPayload(source: CoachEntrySource.homeChip, topic: 'monthlyCheckIn'),
    ));
  }
  final status = PlanTrackingService.evaluate(
    checkIns: profile.checkIns,
    contributions: profile.plannedContributions,
  );
  final streak = StreakService.compute(profile);
  final monthsToRetirement = _computeMonthsToRetirement(profile);
  final impact = PlanTrackingService.compoundProjectedImpact(
    status: status,
    monthsToRetirement: monthsToRetirement,
  );
  return Column(children: [
    StreakBadgeWidget(streak: streak),
    const SizedBox(height: MintSpacing.sm),
    PlanRealityCard(
      status: status,
      compoundImpact: impact,
      monthsToRetirement: monthsToRetirement,
    ),
  ]);
})
```

### Check-in memory enrichment in ConversationMemoryService

```dart
// Extend buildMemory() signature (or add a separate helper):
static String buildCheckInSummary(CoachProfile profile) {
  if (profile.checkIns.isEmpty) return '';
  final sorted = profile.checkIns.toList()
    ..sort((a, b) => b.month.compareTo(a.month));
  final last = sorted.first;
  final total = last.totalVersements.round();
  final monthStr = DateFormat('MMMM yyyy', 'fr').format(last.month);
  return 'Dernier check-in ($monthStr)\u00a0: $total CHF versés au total.';
}
// Inject via ContextInjectorService into system prompt alongside buildMemory() summary.
```

### Amount parser (Claude's Discretion)

```dart
static double? parseAmount(String text) {
  // Handles: "500", "j'ai versé 500", "1'500.50", "CHF 1500", "1 500"
  final match = RegExp(r"\d[\d'.\s]*(?:[.,]\d+)?").firstMatch(
    text.replaceAll('\u00a0', ' '),
  );
  if (match == null) return null;
  final clean = match.group(0)!
      .replaceAll("'", '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  return double.tryParse(clean);
}
```

---

## Runtime State Inventory

> Not applicable — this is a wiring/UI phase, not a rename or migration phase.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `flutter_local_notifications` | SUI-01 notifications | ✓ | in pubspec | — |
| `timezone` package | NotificationService TZ scheduling | ✓ | in pubspec | — |
| `shared_preferences` | Check-in persistence | ✓ | in pubspec | — |
| `provider` | CoachProfileProvider state | ✓ | in pubspec | — |
| FastAPI backend (Railway) | SUI-02 coach tool calls | ✓ | live (staging + prod) | — |

Step 2.6: No missing dependencies — all required packages are present.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) + pytest for backend |
| Config file | none (flutter test) / pytest.ini (backend) |
| Quick run command | `flutter test test/services/plan_tracking_service_test.dart test/services/streak_service_test.dart -x` |
| Full suite command | `flutter test && python3 -m pytest tests/ -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUI-01 | Monthly notification scheduled for 1st of month | unit | `flutter test test/services/notification_service_test.dart -x` | ✅ |
| SUI-01 | 5-day reminder scheduled when no check-in by day 5 | unit | `flutter test test/services/notification_service_test.dart -x` | ❌ Wave 0 |
| SUI-02 | `record_check_in` tool triggers MonthlyCheckIn creation | integration | `flutter test test/services/coach/check_in_flow_test.dart -x` | ❌ Wave 0 |
| SUI-02 | Amount parser handles Swiss formats (1'500, 500, CHF 500) | unit | `flutter test test/services/amount_parser_test.dart -x` | ❌ Wave 0 |
| SUI-03 | PlanRealityCard visible on home when checkIns >= 1 | widget | `flutter test test/screens/mint_home_screen_test.dart -x` | ❌ Wave 0 |
| SUI-03 | CTA card shown when no check-ins | widget | `flutter test test/screens/mint_home_screen_test.dart -x` | ❌ Wave 0 |
| SUI-04 | buildCheckInSummary returns correct last amount | unit | `flutter test test/services/conversation_memory_service_test.dart -x` | ❌ Wave 0 |
| SUI-05 | StreakBadgeWidget renders streak count correctly | widget | `flutter test test/widgets/streak_badge_test.dart -x` | ❌ Wave 0 |

Existing tests for underlying services (PlanTrackingService, StreakService, NotificationService) are already green. New tests cover the wiring joints only.

### Sampling Rate
- **Per task commit:** `flutter test test/services/plan_tracking_service_test.dart test/services/streak_service_test.dart -x`
- **Per wave merge:** `flutter test && python3 -m pytest tests/ -q`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/notification_service_test.dart` — add 5-day reminder test cases (file exists, add cases)
- [ ] `test/services/coach/check_in_flow_test.dart` — covers SUI-02 (new file)
- [ ] `test/services/amount_parser_test.dart` — covers Swiss format edge cases (new file)
- [ ] `test/screens/mint_home_screen_test.dart` — covers SUI-03 conditional rendering (new file)
- [ ] `test/services/conversation_memory_service_test.dart` — covers SUI-04 check-in summary (file may exist, verify)
- [ ] `test/widgets/streak_badge_test.dart` — covers SUI-05 streak rendering (new file)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Amount parser must handle null/empty/non-numeric input without crashing; clamp amounts to 0..999999 |
| V6 Cryptography | no | — |
| V7 Error Handling | yes | check-in persistence failures must not crash the UI — `addCheckIn()` is already guarded with null check |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| LLM prompt injection via check-in note | Tampering | ConversationStore.scrubPii() already scrubs; keep note field length-limited (max 200 chars) |
| Notification payload route injection | Tampering | Existing: ToolCallParser.isValidRoute() whitelist validates all routes before navigation |
| PII in check-in amount injected to LLM | Info Disclosure | Amount is a number, not a string — safe. Never pass full CoachProfile to LLM context. |

**Compliance note (LIFD art. 38):** Check-in records capital contributions (3a, LPP buyback). The disclaimer already in `checkinDisclaimer` ARB key covers the educational framing requirement. Do not add return projections to the check-in summary — the card shows adherence only.

---

## Open Questions

1. **Backend tool list for `record_check_in`**
   - What we know: `generate_financial_plan` is handled Flutter-side in widget_renderer.dart but is NOT in coach_tools.py (it was never defined there; Claude emits it via system prompt instruction)
   - What's unclear: Should `record_check_in` be added to coach_tools.py as a formal tool, or instructed via system prompt like `generate_financial_plan`?
   - Recommendation: Add it as a formal tool in coach_tools.py for type safety and to appear in Claude's tool list. This matches how other structured output tools work.

2. **CoachProfileProvider binding in MintHomeScreen**
   - What we know: MintHomeScreen currently watches `MintStateProvider` and `FinancialPlanProvider`. It does NOT watch `CoachProfileProvider`.
   - What's unclear: Adding a third provider watch adds rebuild complexity.
   - Recommendation: Read `CoachProfileProvider` via `context.watch` inside a `Builder` widget (the established pattern), same as `FinancialPlanProvider` in Section 1b.

3. **`_computeMonthsToRetirement` helper**
   - What we know: `PlanTrackingService.compoundProjectedImpact()` requires `monthsToRetirement`. `CoachProfile` has `birthYear` (int) but not `birthDate`. Reference age is 65 (men) per AVS constants.
   - Recommendation: Compute inline as `(profile.birthYear + 65 - DateTime.now().year) * 12`. This is an approximation acceptable for the educational disclaimer already in PlanRealityCard.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Swiss apostrophe `'` used as thousands separator — must be stripped before `double.tryParse` | Code Examples (amount parser) | Low: if wrong, amounts over 999 CHF parse incorrectly → 0.0 recorded |
| A2 | `generate_financial_plan` tool is instructed via system prompt rather than formal tool definition in coach_tools.py | Open Questions | Medium: if it IS in coach_tools.py somewhere not found, duplication risk for record_check_in |
| A3 | `ContextInjectorService` accepts additional string segments to inject alongside `ConversationMemoryService.buildMemory()` output | Architecture Patterns (Pattern 5) | Low: if not, needs a 2-line addition to ContextInjectorService |

---

## Sources

### Primary (HIGH confidence)
- `apps/mobile/lib/services/notification_service.dart` — verified scheduling logic, IDs, TZ setup, pendingRoute mechanism
- `apps/mobile/lib/services/streak_service.dart` — verified StreakResult shape, compute() signature
- `apps/mobile/lib/services/plan_tracking_service.dart` — verified PlanStatus shape, evaluate() and compoundProjectedImpact() signatures
- `apps/mobile/lib/widgets/coach/plan_reality_card.dart` — verified widget constructor (no streak parameter)
- `apps/mobile/lib/widgets/coach/streak_badge.dart` — verified StreakBadgeWidget constructor
- `apps/mobile/lib/services/coach/conversation_memory_service.dart` — verified buildMemory() signature and summary format
- `apps/mobile/lib/services/coach/jitai_nudge_service.dart` — verified streakAtRisk trigger conditions
- `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` — verified normalize() path
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — verified tool dispatch switch, generate_financial_plan pattern
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` — verified section structure, conditional card pattern
- `apps/mobile/lib/models/coach_profile.dart` lines 1084-1190 — verified MonthlyCheckIn and PlannedMonthlyContribution models
- `apps/mobile/lib/providers/coach_profile_provider.dart` lines 867-882 — verified addCheckIn() signature
- `apps/mobile/lib/providers/financial_plan_provider.dart` — verified that it does NOT contain check-in data
- `apps/mobile/lib/app.dart` line 340 — verified `/coach/checkin` redirect
- `apps/mobile/lib/models/coach_entry_payload.dart` — verified CoachEntrySource enum and toContextInjection()
- `services/backend/app/services/coach/coach_tools.py` — verified no existing record_check_in tool
- `apps/mobile/lib/l10n/app_fr.arb` lines 453-529 — verified existing check-in ARB keys

### Secondary (MEDIUM confidence)
- `.planning/phases/05-suivi-check-in/05-CONTEXT.md` — user decisions verified

### Tertiary (LOW confidence)
- A1, A2, A3 in Assumptions Log above

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components verified in codebase with file + line citations
- Architecture patterns: HIGH — generate_financial_plan pipeline verified as reference
- Pitfalls: HIGH — verified by tracing actual code paths (notification_service.dart scheduling logic, widget_renderer.dart dispatch, mint_home_screen.dart guard conditions)
- Test gaps: HIGH — verified by searching test/ directory

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable codebase — no fast-moving external dependencies)
