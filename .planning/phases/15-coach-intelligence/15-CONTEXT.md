# Phase 15: Coach Intelligence - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Coach becomes relationally aware. Tracks who recommended what financial product (provenance) and respects that users mentally separate their monies (earmarks). All through natural conversation — never form-style questions. Covers: system prompt directives for provenance/earmark detection, conversation memory extensions, backend earmark storage, CoachContext injection for both provenance and earmarks.

</domain>

<decisions>
## Implementation Decisions

### Provenance Tracking
- System prompt directive in `build_system_prompt`: "Quand l'utilisateur mentionne un produit financier (3a, LPP, assurance), demande naturellement qui le lui a propose. Formule: 'Au fait, ce [produit], c'est qui qui te l'a propose ?'"
- Extend existing `conversation_memory_service` + `save_insight` with `provenance` metadata field (who, product, institution). No new DB table — reuse CoachInsight model.
- CoachContext injection: add "PROVENANCE CONNUE" section to memory block. System prompt: "Reference naturellement les provenances connues."
- Detection trigger: first mention of any financial product in a conversation. Coach asks once per product, stores, never asks again.

### Earmark Detection
- System prompt directive: "Quand l'utilisateur associe de l'argent a une relation ou une origine ('l'argent de mamie', 'le compte pour les enfants'), appelle save_earmark pour enregistrer."
- Backend `earmark_tags` table (user_id, label, source_description, amount_hint, created_at). New `save_earmark` internal tool. Injected into CoachContext as "ARGENT MARQUE" section.
- Financial analyses respect earmarks via CoachContext injection: "Les fonds marques ne sont JAMAIS agreges dans 'patrimoine total'. Affiche-les separement."
- Earmark management via conversation only: "Oublie le tag sur l'argent de mamie" → `remove_earmark` internal tool. No settings screen.

### Claude's Discretion
- Earmark amount_hint precision (exact vs approximate)
- Provenance metadata schema details
- Migration approach for earmark_tags table

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `services/backend/app/services/coach/claude_coach_service.py` — build_system_prompt() with existing directives
- `services/backend/app/services/coach/coach_tools.py` — existing internal tools (save_insight, record_commitment, etc.)
- `apps/mobile/lib/services/memory/coach_memory_service.dart` — CoachInsight storage
- `services/backend/app/api/v1/endpoints/coach_chat.py` — internal tool handlers, memory block builder

### Established Patterns
- Internal tools: intercepted by backend, never reach Flutter (INTERNAL_TOOL_NAMES)
- CoachContext memory injection: sections like "ENGAGEMENTS ACTUELS", "RISQUES IDENTIFIES" (from Phase 14)
- System prompt directives: _IMPLEMENTATION_INTENTION, _PRE_MORTEM_PROTOCOL patterns

### Integration Points
- System prompt directives in claude_coach_service.py
- New internal tools in coach_tools.py (save_earmark, remove_earmark)
- Backend handlers in coach_chat.py
- CoachContext enrichment with provenance and earmark sections

</code_context>

<specifics>
## Specific Ideas

- Provenance question: "Au fait, ce 3a, c'est qui qui te l'a propose ?"
- Provenance reference: "le 3a que ton banquier t'a propose chez UBS..."
- Earmark detection: "l'argent de mamie", "le compte pour les enfants"
- Never aggregate earmarked money: appears separately in all projections

</specifics>

<deferred>
## Deferred Ideas

- Provenance-based conflict of interest detection (v2.6+)
- Earmark visualization in timeline (Phase 17-18)
- Cross-couple earmark tracking (Phase 16 handles couple, not earmarks)

</deferred>
