# Phase 18: Living Timeline -- Full Timeline - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Aujourd'hui becomes a single-screen center of gravity — a living timeline with tappable nodes that aggregates documents, conversations, commitments, couple data, and projections. Evolves Phase 17's 3-tension cards into a full scrollable timeline with month grouping, 5 node types, and lazy loading for performance.

</domain>

<decisions>
## Implementation Decisions

### Timeline Architecture
- Evolution, not replacement — 3 tension cards become sticky summary header. Full timeline scrolls below with individual nodes.
- 5 node types: DocumentNode (uploaded docs), ConversationNode (coach chats), CommitmentNode (accepted intentions), CoupleNode (partner estimates), ProjectionNode (future scenarios). Each with distinct icon + color.
- Vertical scroll, single column, chronological (newest at top). Each node = card with icon, title, date, 1-line summary.
- `TimelineProvider` extends `TensionCardProvider` — adds node-level data. Computes once on init, caches.
- SliverList.builder with lazy loading — render visible nodes + 2 buffer. Max 50 nodes. "Charger plus" pagination.

### Node Interactions & Performance
- Context-specific navigation on tap: DocumentNode → document viewer, ConversationNode → coach chat, CommitmentNode → commitment detail, CoupleNode → couple questions, ProjectionNode → projection screen.
- 1-2 ghosted future nodes max, based on real data (retirement gap, next landmark, upcoming reminders).
- Month grouping with sticky headers ("Avril 2026", "Mars 2026"). Current month expanded, past collapsible.
- Performance target: smooth scroll on older iPhones. No complex animations on nodes (only header pulse from Phase 17).

### Claude's Discretion
- Node card visual details (padding, shadows, icons)
- Month group collapse animation
- Pagination threshold and loading indicator
- Node deduplication logic

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` — Phase 17 screen (3-tension cards)
- `apps/mobile/lib/providers/tension_card_provider.dart` — Phase 17 provider (extend this)
- `apps/mobile/lib/widgets/tension/tension_card_widget.dart` — Phase 17 card widget (keep as header)
- `apps/mobile/lib/services/commitment_service.dart` — commitment data
- `apps/mobile/lib/services/fresh_start_service.dart` — landmark dates
- `apps/mobile/lib/services/coach/conversation_store.dart` — conversation history

### Integration Points
- Extend AujourdhuiScreen with timeline below tension header
- TimelineProvider extends TensionCardProvider
- GoRouter deeplinks for node taps
- i18n for month names and node labels

</code_context>

<specifics>
## Specific Ideas

- Sticky header: 3 tension cards from Phase 17 stay visible on scroll
- Month headers: "Avril 2026" with collapse chevron
- Node icons: document (file), conversation (chat bubble), commitment (checkmark), couple (people), projection (crystal ball)
- Empty timeline: "Ton histoire financiere se construit ici."

</specifics>

<deferred>
## Deferred Ideas

- Timeline search/filter
- Timeline export (PDF)
- Animated node transitions
- Cross-couple timeline merge

</deferred>
