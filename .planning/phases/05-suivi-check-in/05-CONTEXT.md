# Phase 5: Suivi & Check-in - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Users are proactively nudged to check in monthly, check-ins feel conversational rather than form-like, and progress against the plan is visible on Aujourd'hui. This phase wires together existing infrastructure (NotificationService, MonthlyCheckIn model, StreakService, PlanTrackingService, PlanRealityCard, ConversationMemoryService) into a cohesive check-in experience.

</domain>

<decisions>
## Implementation Decisions

### Check-in Conversation Flow
- Coach initiates in chat — on nudge tap or home card tap, coach sends "Salut ! C'est le moment de faire le point. Combien as-tu verse ce mois sur ton 3a ?" (adapted to the user's plan contributions)
- Natural language amount entry — user types "500" or "j'ai verse 500", parser extracts amount and creates MonthlyCheckIn entry
- Sequential multi-contribution handling — after first answer, coach asks about next PlannedMonthlyContribution ("Et sur ton epargne libre ?") until all plan items are covered
- Coach summarizes and saves — "Parfait, 500 CHF sur le 3a et 200 CHF en epargne libre. C'est note !" then PlanRealityCard updates inline in chat

### Notification & Nudge Timing
- Check-in nudge fires on 1st of each month at 10:00 via existing NotificationService.scheduleNotification(), recurring monthly
- Single reminder after 5 days if user hasn't checked in — "Tu n'as pas encore fait ton point du mois. 2 minutes suffisent !"
- Nudge tap opens coach chat with check-in pre-loaded — coach immediately asks the first contribution question
- Use existing JITAI streakAtRisk trigger — fires 2 days before month-end if no check-in recorded for the current month

### Aujourd'hui Integration & Streak Display
- PlanRealityCard goes in Section 2 on MintHomeScreen (after Chiffre Vivant + Premier Eclairage), only visible when user has >= 1 check-in
- Streak display integrated inside PlanRealityCard header — compact StreakBadgeWidget (already exists)
- When no check-in yet: show "Ton premier point" CTA card — "Fais ton premier point du mois pour voir ta progression ici", tap opens coach chat
- Coach references past check-in contextually during check-in flow — "Le mois dernier tu avais verse 500 CHF, tu continues sur cette lancee ?" injected via ConversationMemoryService

### Claude's Discretion
- Amount parsing implementation details (regex vs NLP)
- Exact notification string wording (must use i18n ARB keys)
- Animation timing for PlanRealityCard appearance on Aujourd'hui
- Error handling for edge cases (no plan yet, incomplete plan)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotificationService` (lib/services/notification_service.dart): scheduling, consent-aware, i18n-ready
- `MonthlyCheckIn` model in `CoachProfile` (lib/models/coach_profile.dart:1084-1141): versements, expenses, note, completedAt
- `PlannedMonthlyContribution` (lib/models/coach_profile.dart:1144-1190): id, label, amount, category
- `StreakService` (lib/services/streak_service.dart): compute(), badges (1/3/6/12-month milestones)
- `StreakBadgeWidget` (lib/widgets/coach/streak_badge.dart): fire icon, progress bar
- `PlanTrackingService` (lib/services/plan_tracking_service.dart): evaluate(), adherence, gap, compound impact
- `PlanRealityCard` (lib/widgets/coach/plan_reality_card.dart): adherence badge, progress bar, next actions
- `ConversationMemoryService` (lib/services/coach/conversation_memory_service.dart): buildMemory(), summary injection
- `JitaiNudgeService` (lib/services/coach/jitai_nudge_service.dart): weeklyCheckIn + streakAtRisk triggers
- `NudgeEngine` + `NudgePersistence` (lib/services/nudge/): evaluation, dismissal, cooldown

### Established Patterns
- Tool dispatch: coach emits tool_use → ChatToolDispatcher normalizes → WidgetRenderer displays inline widget
- Provider state: ChangeNotifier + FinancialPlanProvider with staleness detection via profile hash
- Home screen sections: conditional cards based on user state (hasPlan, hasCheckIn, etc.)
- Coach chat: CoachChatScreen with message history, real-time LLM, tool calling

### Integration Points
- MintHomeScreen (lib/screens/main_tabs/mint_home_screen.dart): add PlanRealityCard section
- ChatToolDispatcher: add check-in tool handling (INITIATE_CHECK_IN, RECORD_CHECK_IN)
- CoachProfile: checkIns list + contributionPlan already exist
- FinancialPlanProvider: listen for check-in updates to refresh PlanRealityCard
- NotificationService: schedule monthly check-in + reminder notifications
- JITAI nudge service: wire streakAtRisk trigger to check-in state

</code_context>

<specifics>
## Specific Ideas

- Check-in must feel like a 2-minute conversation, not a form — the coach drives the flow
- PlanRealityCard reuses existing widget but needs streak integration in header
- "Ton premier point" CTA card is a lightweight widget, not the full PlanRealityCard
- Cross-session memory reference must be natural ("le mois dernier tu avais verse X") not robotic

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
