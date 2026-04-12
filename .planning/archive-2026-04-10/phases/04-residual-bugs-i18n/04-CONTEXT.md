# Phase 4: Residual bugs & i18n hygiene - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Expert-panel autonomous

<domain>
## Phase Boundary

Close bugs that did not dissolve via deletion and finish nav cleanup. This is a cleanup phase — small, targeted fixes.

**Requirements covered:** BUG-03, BUG-04, NAV-03, NAV-04, NAV-05, NAV-06.

</domain>

<decisions>
## Implementation Decisions

### BUG-03: Diacritic regression root-cause
- The Centre de contrôle showed `Donnees`, `necessaires`, `Execution`, `agregees`, `ameliorer`, `federale` instead of proper accented characters.
- Root-cause hypothesis: either (a) the ARB strings themselves lack diacritics, (b) the backend microcopy codegen strips accents, or (c) a font fallback issue.
- **Action:** grep for the unaccented strings in ARB files and Dart source. Fix at source. If the Centre de contrôle was deleted in Phase 2, verify the same encoding bug doesn't leak elsewhere (e.g., legal pages, other screens using similar text paths).
- If the strings were ONLY in the deleted Centre de contrôle, this bug is dissolved and BUG-03 can be marked verified-gone.

### BUG-04: "Ton de Mint" segmented control truncation
- The bottom sheet showed 3 options with truncated subtitles "On y va dou...", "Voici ce que...", "Pas de filtre..."
- Phase 2 deleted the Ton bottom sheet. Phase 3 replaced it with CHAT-05 suggestion chips in the chat.
- **If the Ton bottom sheet is fully gone** (deleted in Phase 2 or replaced in Phase 3), BUG-04 is dissolved. Verify by grepping for `TonChooserSheet` or `ton_chooser` in the codebase.
- If any remnant exists, delete it.

### NAV-03: Legal pages public scope
- CGU and politique de confidentialité links must open in public scope (not authenticated).
- Phase 1 scope-tagged routes. Verify CGU/privacy routes have `RouteScope.public`.
- If the links were removed in Phase 2 deletion (with the register screen), verify no dead links remain anywhere.

### NAV-04: Zero non-trivial cycles (verification)
- Phase 1 GATE-01 (cycle DFS test) is green. This req is satisfied by the existing CI gate.
- Verify: run `flutter test apps/mobile/test/architecture/route_cycle_test.dart` — still green after Phases 2 and 3 changes.

### NAV-05: Every route has forward exit to /coach/chat (verification)
- After Phase 2 deletion, most dead-end routes are gone. Verify remaining routes have forward exits.
- This can be a new test or a manual review of the route graph post-deletion.

### NAV-06: Remove all Navigator.push legacy calls
- Grep for `Navigator.push`, `Navigator.of(context).push`, `Navigator.of(context).pushReplacement` in the entire `apps/mobile/lib/` directory.
- Replace each with GoRouter equivalent (`context.go` or `context.push`).
- If zero found (Phase 2 may have deleted the files containing them), NAV-06 is verified-clean.

### Claude's Discretion
- Whether to add a route reachability test (NAV-05) to the permanent CI suite or just verify manually
- How thorough to be on diacritic grep (all ARB files vs just fr)

</decisions>

<code_context>
## Existing Code Insights

- Phase 1 installed 5 CI gates including cycle DFS and scope-leak
- Phase 2 deleted 14 files including Centre de contrôle and Ton chooser
- Phase 3 added chat features but no new navigation patterns
- Most NAV-03..06 items may already be resolved by Phase 1+2 changes

</code_context>

<specifics>
## Specific Ideas

- This phase may be very fast if most bugs dissolved via deletion. Start by verifying what's already gone before writing new code.
- "Verify and close" is a valid task output — not every req needs new code.

</specifics>

<deferred>
## Deferred Ideas

None — this is the cleanup phase.

</deferred>
