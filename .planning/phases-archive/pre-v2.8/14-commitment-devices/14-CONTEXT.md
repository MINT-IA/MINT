# Phase 14: Commitment Devices - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

MINT transforms insights into action. Every Layer 4 coach response includes a concrete implementation intention (WHEN/WHERE/IF-THEN). Landmark dates trigger proactive messages. Irrevocable decisions get a pre-mortem prompt. Covers: system prompt directives, commitment device storage, notification scheduling, fresh-start anchor detection, pre-mortem flow, CoachContext injection for memory recall.

</domain>

<decisions>
## Implementation Decisions

### Implementation Intentions
- System prompt directive in `build_system_prompt`: "After every Layer 4 insight, propose a WHEN/WHERE/IF-THEN implementation intention." Coach generates it as natural text, backend parses into structured `CommitmentDevice`.
- Backend DB table `commitment_devices` (id, user_id, type, when_text, where_text, if_then_text, status, created_at, reminder_at). Persisted via new internal tool `record_commitment`.
- Inline chat widget `CommitmentCard` — WHEN/WHERE/IF-THEN fields, editable. User taps "Accept" or edits fields, then "Save". Dismiss = swipe away.
- Coach proposes intentions only on Layer 4 insights (personal perspective + action step) — not every message. Detection via system prompt directive, not code logic.

### Fresh-Start Anchors & Proactive Messages
- 5 landmark types: birthday, month-1 (1er du mois), year-start (1er janvier), job anniversary (from `firstEmploymentYear`), 1-year MINT anniversary.
- Local notification (existing `notification_service.dart` Tier 1 pattern) with deeplink to coach chat. When user taps, coach has pre-loaded context about why today matters.
- Backend fresh-start endpoint `/api/v1/coach/fresh-start` returns personalized message based on user profile + commitment history. Called by notification tap deeplink.
- Rate limiting: max 1 per landmark date, max 2 per month. Birthday + year-start coincidence (Jan 1 birthday) = 2 messages OK.

### Pre-Mortem for Irrevocable Decisions
- 3 irrevocable types trigger pre-mortem: EPL (propriete), capital withdrawal (2e/3a pilier), 3a closure. Detected via intent tags `housing_purchase_epl`, `retirement_capital_choice`, `pillar_3a_closure`.
- Coach-initiated in conversation: "Imagine qu'on est en 2027 et que cette decision s'est mal passee. Qu'est-ce qui aurait pu arriver?" Stores user's free-text response via `save_pre_mortem` internal tool.
- Backend `pre_mortem_entries` table (user_id, decision_type, decision_context, user_response, created_at). Injected into CoachContext memory block as "RISQUES IDENTIFIES" section.
- Auto-referenced: when CoachContext detects topic matching a prior pre-mortem decision type, inject: "L'utilisateur a fait un pre-mortem le {date} concernant {type}. Il a dit craindre que: {response}. Reference naturellement."

### Claude's Discretion
- DB migration details (Alembic vs raw SQL)
- CommitmentCard widget styling details
- Notification scheduling internals (exact vs inexact alarms)
- Fresh-start message content generation approach

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `services/backend/app/services/coach/claude_coach_service.py` — `build_system_prompt()` with 4-layer engine, intensity levels, lifecycle tone
- `services/backend/app/services/coach/coach_tools.py` — existing tool definitions (route_to_screen, save_insight, set_goal, retrieve_memories)
- `apps/mobile/lib/services/notification_service.dart` — Tier 1-2 local notifications with deeplinks
- `apps/mobile/lib/services/memory/coach_memory_service.dart` — CoachInsight storage (max 50, FIFO)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — agent loop with internal tool interception

### Established Patterns
- Internal tools intercepted by backend (INTERNAL_TOOL_NAMES), never reach Flutter
- ComplianceGuard validation on all LLM output
- CoachContext built from profile + memory block (non-identifying aggregates)
- Notification scheduling via `flutter_local_notifications` with deeplinks

### Integration Points
- System prompt directives in `claude_coach_service.py` for intention/pre-mortem prompting
- New internal tools in `coach_tools.py` (record_commitment, save_pre_mortem)
- New backend handlers in `coach_chat.py` for commitment/pre-mortem tools
- Notification scheduler extension for commitment reminders
- CoachContext enrichment with commitment history and pre-mortem entries

</code_context>

<specifics>
## Specific Ideas

- Pre-mortem prompt: "Imagine qu'on est en 2027 et que cette decision s'est mal passee. Qu'est-ce qui aurait pu arriver?"
- Post-auth coach reference: "En mars tu avais dit craindre que..."
- CommitmentCard fields: WHEN (quand), WHERE (ou/comment), IF-THEN (si X arrive, alors Y)
- Fresh-start notification: personalized to financial situation, not generic "Bonne annee!"

</specifics>

<deferred>
## Deferred Ideas

- Push notifications (v2.6 — requires push infra)
- Graduation Protocol integration (long-term direction)
- Commitment analytics dashboard (v2.6+)
- Social accountability features (never — no social comparison)

</deferred>
