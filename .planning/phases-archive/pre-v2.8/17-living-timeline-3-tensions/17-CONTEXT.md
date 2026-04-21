# Phase 17: Living Timeline -- 3 Tensions - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Aujourd'hui tab comes alive with 3 tension cards (past earned, present pulsing, future ghosted) that reflect the user's actual financial state. Cards update dynamically from existing services. Replace the static landing screen. Tappable cards navigate to relevant context. Cleo loop indicator shows where user is in the cycle.

</domain>

<decisions>
## Implementation Decisions

### Tension Card Design & Data Sources
- Past (earned): completed commitments, accepted pre-mortems, documents uploaded. Solid background, checkmark, muted MintColors.
- Present (pulsing): active commitment intentions, open conversations, pending questions. Pulse animation (opacity 0.8→1.0, 2s), accent color.
- Future (ghosted): next landmark date, projected retirement gap, upcoming deadlines. Semi-transparent (0.4 opacity), dashed border, ghosted text.
- Provider-based `TensionCardProvider` — listens to CommitmentService, ConversationStore, PartnerEstimateService, FreshStartService. Recomputes on changes. No polling.
- Replace current Aujourd'hui tab content — same route `/home?tab=0`, new widget tree. Shell/tabs/drawer intact.

### Interaction & Loop Integration
- Tappable cards: past → commitment history, present → coach chat with tension context, future → projection screen. Via GoRouter deeplinks.
- Cleo loop indicator: small pill below cards showing cycle position (Insight/Plan/Conversation/Action/Memory). Subtle, not a progress bar.
- Empty state: single welcome card "Commence par parler au coach." Tapping navigates to coach tab. No 3 empty placeholder cards.
- Full i18n: category labels ("Acquis", "En cours", "A venir") in all 6 ARB files.

### Claude's Discretion
- Exact animation parameters
- Card layout spacing
- Tension selection algorithm (which specific items to show)
- Loop indicator visual design

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/screens/home/` — current Aujourd'hui tab
- `apps/mobile/lib/services/commitment_service.dart` — commitment data (Phase 14)
- `apps/mobile/lib/services/fresh_start_service.dart` — landmark dates (Phase 14)
- `apps/mobile/lib/services/coach/conversation_store.dart` — conversation history
- `apps/mobile/lib/theme/colors.dart` — MintColors palette
- `apps/mobile/lib/services/partner_estimate_service.dart` — couple data (Phase 16)

### Integration Points
- Replace Aujourd'hui tab content widget
- TensionCardProvider listens to multiple existing services
- GoRouter deeplinks for card taps
- i18n keys in all 6 ARB files

</code_context>

<specifics>
## Specific Ideas

- Pulse animation: opacity 0.8 → 1.0, 2-second loop, ease-in-out
- Ghosted: 0.4 opacity, dashed border (CustomPainter)
- Welcome card: "Commence par parler au coach. Tes premieres tensions apparaitront ici."
- Loop pill: "Action en cours" / "Insight recu" / "Memoire mise a jour"

</specifics>

<deferred>
## Deferred Ideas

- Full timeline (Phase 18 — nodes, aggregation, center of gravity)
- Timeline animation transitions
- Notification-triggered card highlights

</deferred>
