# Phase 5: Sober visual polish - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Expert-panel autonomous

<domain>
## Phase Boundary

On a sane architecture (Phase 1-4), apply sober visual polish to the 2 surviving surfaces: S0 Landing and Coach Chat. No Aesop/Things 3/Arc chase — sober is the goal. Remove banned visual fragments. Token audit.

**Requirements covered:** POLISH-01..04.

</domain>

<decisions>
## Implementation Decisions

### POLISH-01: S0 Landing rebuilt minimaliste
- Current landing has: wordmark "M I N T" + 6-7 line paragraph + CTA "Continuer (sans compte)" + privacy subtitle + legal footer = 5 text blocks.
- Target: 1 promesse (≤2 lignes), 1 CTA, 1 footer légal. 3 elements max. Passes 3s test.
- Copy direction: NOT "Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts." That's a list, not a promise.
- Better: "Mint te dit ce que personne n'a intérêt à te dire." Full stop. One sentence. The rest is discovered in conversation.
- CTA: "Commencer" (not "Continuer (sans compte)" — that's apologetic). Just "Commencer".
- Legal footer stays (compliance requirement): "Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin."
- Remove the privacy subtitle ("Rien ne sort de ton téléphone..."). That's the coach's job to explain when relevant.
- Wordmark stays: "M I N T" letter-spaced. It's the only MINT identity element that works.

### POLISH-02: Coach chat breathing room
- After Phases 2+3, the chat is the shell. It needs generous vertical rhythm.
- Increase message bubble padding (top/bottom), reduce density between turns.
- Clear focal point per turn: the latest message is visually dominant, older messages recede slightly (opacity or size).
- No competing UI chrome: the suggestion chips and consent chips from Phase 3 should be visually subordinate to the conversation text.
- Input field should be clean: no decorative elements, no "send" button that competes with the keyboard return key.

### POLISH-03: Banned visual fragments removed
- 3D logo cube (deleted with KILL-05 register screen — verify gone)
- Bordered gray ghost chips on intent (deleted with KILL-01 — verify gone)
- Generic Material 3 admin styling on any surviving drawer (ChatDrawerHost from Phase 3) — apply MINT tokens
- Any remaining `ElevatedButton.styleFrom()` with default Material styling → use MINT button tokens

### POLISH-04: Color/typography tokens audit
- Grep for `Color(0xFF` in all lib/ files → replace with `MintColors.*`
- Grep for `Outfit` font references → remove (deprecated per CLAUDE.md)
- Verify every surviving surface uses Montserrat (headings) and Inter (body) via GoogleFonts
- Verify `MintColors.*` from `lib/theme/colors.dart` is the only color source

### Claude's Discretion
- Exact padding values for chat message bubbles (recommendation: 16px vertical, 12px between turns)
- Whether to add a subtle fade-in animation on new messages (recommendation: yes, 200ms opacity)
- Whether the landing wordmark should be larger or stay current size
- Exact background color for landing (recommendation: `MintColors.surface` or very warm off-white)

</decisions>

<code_context>
## Existing Code Insights

- Landing screen: `apps/mobile/lib/screens/landing/landing_screen.dart` (or wherever it lives post-Phase 2)
- Coach chat: `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
- Chat bubbles: `apps/mobile/lib/widgets/coach/coach_message_bubble.dart`
- ChatDrawerHost: `apps/mobile/lib/widgets/coach/chat_drawer_host.dart` (Phase 3)
- MintColors: `apps/mobile/lib/theme/colors.dart`
- GoogleFonts: already imported, Montserrat + Inter in use

</code_context>

<specifics>
## Specific Ideas

- Sober means: nothing screams, nothing competes, nothing is clever. The app is warm paper with black ink and one green accent. Like a good handwritten letter.
- The landing should feel like opening a book. Quiet. The chat should feel like a conversation with someone who listens more than they talk.

</specifics>

<deferred>
## Deferred Ideas

- Micro-animations beyond basic fade-in → v2.4
- Custom font tuning (letter-spacing, line-height per style) → v2.4
- Dark mode → v2.4+

</deferred>
