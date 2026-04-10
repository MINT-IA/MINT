# Phase 3: Chat-as-shell rebuild - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Expert-panel autonomous

<domain>
## Phase Boundary

The chat becomes the entry, the distributor, the consent surface, the data-capture surface, the tone-setter. Every former destination becomes a chat-summoned contextual drawer.

After Phase 2, MINT is landing → chat. Phase 3 adds intelligence back: the chat can summon calculators, ask for consent, capture profile data, set tone preference — all inline, all contextual, all dismissible.

**Requirements covered:** CHAT-01..05.

</domain>

<decisions>
## Implementation Decisions

### CHAT-01: Cold start → chat direct
- Post-Phase 2, the landing CTA already routes to `/coach/chat`. Verify this works for both anonymous (local mode) and registered users.
- The coach chat must have a **context-appropriate opener** — not "Bonjour, comment puis-je t'aider ?" but something that reflects this is the user's entry point to MINT. The backend `claude_coach_service.py` already has opener logic with regional voice — verify it fires on first cold-start visit.
- If the user has never visited before (no profile, no history): opener should be warm, curious, zero-jargon. "Salut. Qu'est-ce qui te tracasse en ce moment ?" style. Not "Bienvenue dans MINT, voici ce que je peux faire pour toi" (that's marketing, not conversation).

### CHAT-02: Summon mechanism (drawers)
- **Architecture:** the chat needs a way to open contextual surfaces (calculators, profile forms, document upload) as bottom sheets or modal overlays that dismiss back to the conversation.
- **Implementation:** add a `ChatDrawerService` (or similar) that the coach tool-calling system can invoke. When the coach says "let me show you your 3a projection", it triggers a tool call that opens the 3a calculator as a bottom sheet over the chat. User views it, dismisses it, conversation continues.
- **Existing tool calls:** the backend already has `route_to_screen`, `generate_document`, `generate_financial_plan`, `record_check_in` tool calls (validated in v2.1). These need to be rewired from "navigate to a destination screen" to "summon a drawer over the chat".
- **Key change:** `route_to_screen` tool call handler in `coach_chat_screen.dart` currently does `context.go('/path')` — change to `showModalBottomSheet()` or equivalent with the target widget. The widget is the same screen file (preserved in Phase 2), just rendered as a sheet instead of a full-page destination.

### CHAT-03: Inline consent
- When the coach needs a permission (e.g., "Personnalisation IA" to send data to Claude), it asks in conversation: "Pour personnaliser mes réponses, j'ai besoin d'envoyer tes données financières agrégées à mon fournisseur IA. Ça te va ?" with accept/decline chips.
- **One consent at a time.** Never a list. Never nLPD article numbers. Never conservation durations. Just a human sentence.
- **Store consent in the existing consent provider/service** — the business logic from the deleted Centre de contrôle still exists as a service, wire it to the chat response.
- The user can revoke any consent later by asking the coach: "Désactive la personnalisation IA".

### CHAT-04: Profile data via chat
- When the coach needs data (age, canton, revenu) for a projection, it ASKS in conversation: "Pour te montrer ta situation, j'ai besoin de ton âge, ton canton, et ton revenu approximatif. On y va ?"
- Use existing chat input surfaces (text field, suggestion chips) for data capture. NOT form fields. NOT sliders.
- Data flows to CoachProfileProvider, same as before — just the entry point changes from form to conversation.
- Profile pre-fill rule (from memory `feedback_profile_prefill_architecture.md`): if we already know the user's canton (from prior conversation), don't ask again. The chat is contextual.

### CHAT-05: Tone preference in chat
- First conversation, after the opener, the coach can ask: "Au fait, tu préfères que je sois plutôt doux, direct, ou sans filtre ?" with 3 suggestion chips.
- Store on `Profile.voiceCursorPreference` (backend already supports this).
- This replaces the deleted "Ton de Mint" bottom sheet from onboarding.
- Ask ONCE, early in the first conversation. Don't re-ask unless the user says "change ton ton".

### Claude's Discretion
- Exact copy for the consent sentences (must be human, warm, zero-jargon — but the exact words are Claude's to craft in context)
- Whether ChatDrawerService is a new class or an extension of the existing tool-call handler
- Animation/transition style for drawers (recommend: standard Material bottom sheet, 300ms, nothing fancy — Phase 5 polishes)
- Whether suggestion chips for tone preference appear as part of the coach message bubble or as a separate UI element below it

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — the shell, already handles tool calls
- `apps/mobile/lib/services/coach/tool_call_handler.dart` (or similar) — processes `route_to_screen`, `generate_document` etc.
- `apps/mobile/lib/providers/coach_profile_provider.dart` — profile data store
- Consent service/provider (preserved from Phase 2 deletion — the screen was deleted, the service stayed)
- All calculator/simulator screen files (preserved from Phase 2 — ready to be rendered as drawers)
- Backend `claude_coach_service.py` with opener logic, regional voice, compliance guard

### Established Patterns
- Tool calling: backend returns tool_use → frontend handler executes → result fed back to conversation
- Provider state management for profile, auth, consent
- GoRouter for primary navigation (but drawers use `showModalBottomSheet`, not GoRouter)

### Integration Points
- `coach_chat_screen.dart` — primary edit target (summon mechanism, inline consent, data capture)
- Tool call handler — rewire `route_to_screen` from `context.go` to drawer summon
- CoachProfileProvider — data capture writes here
- Consent provider/service — inline consent writes here
- Landing screen CTA — already routes to /coach/chat (verify)

</code_context>

<specifics>
## Specific Ideas

- The chat-as-shell is MINT's natural positioning since day one. This phase isn't adding a feature — it's removing the wrong abstraction (destination screens) and letting the correct one (conversation) breathe.
- The summon mechanism is the key architectural piece. Get it right and Phase 5's visual polish has a clean surface to work with.
- Suggestion chips for tone preference and consent are existing Flutter patterns — no invention needed.

</specifics>

<deferred>
## Deferred Ideas

- Advanced drawer animations / transitions → Phase 5
- Profile completion tracking (non-gamified) → Phase 4 or later
- Multi-calculator comparison in a single drawer → v2.4
- Voice input for data capture → Phase 3 strategic roadmap

</deferred>
