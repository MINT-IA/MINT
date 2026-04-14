# Phase 24: Coach Widgets & Suggestions - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated from Gate 0 findings

<domain>
## Phase Boundary

Fix: coach can't show inline widgets or contextual suggestions. Suggestion chips are static/hardcoded ("C'est grave si je fais rien", "Rente ou capital") after EVERY response. Coach should show inline widgets (fact cards, route suggestions) via tool calls, and suggestion chips should be contextual.

Requirements: WID-01, WID-02, WID-04, UX-04

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All choices at Claude's discretion.

Key investigation:
- Where are the static suggestion chips defined? (coach_chat_screen.dart?)
- Are they hardcoded or from a config?
- Does widget_renderer.dart already handle show_fact_card and route_to_screen tools?
- Does the coach actually CALL these tools? (check system prompt)
- What's the navigation flow when route_to_screen is tapped?

Fix approach:
- UX-04: Remove hardcoded chips. Replace with chips from coach tool calls (if coach calls route_to_screen, those become chips).
- WID-01/WID-02/WID-04: Verify widget_renderer handles all tool types. Fix any broken rendering.

</decisions>

<code_context>
## Existing Code Insights

widget_renderer.dart already handles: route_to_screen, show_fact_card, show_commitment_card, ask_user_input, save_partner_estimate, check_in_summary.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — investigate and fix.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
