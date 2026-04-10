---
phase: 01-p0a-code-unblockers
plan: 04
type: execute
wave: 3
depends_on: ["01-02"]
files_modified:
  - .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md
autonomous: true
requirements: [STAB-21]
must_haves:
  truths:
    - "Every P0a-tagged item in .planning/backlog/STAB-carryover.md has an explicit disposition in this phase"
    - "STAB-21 (chiffre_choc_screen split-exit bug) is either marked moot-after-rename or fixed"
  artifacts:
    - path: .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md
      provides: "Backlog sweep disposition document"
  key_links:
    - from: .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md
      to: .planning/backlog/STAB-carryover.md
      via: "disposition reference per item"
      pattern: "STAB-"
---

<objective>
Sweep `.planning/backlog/STAB-carryover.md` for any P0a-tagged items not already covered by PLAN-01 (STAB-19), PLAN-02 (STAB-20), or PLAN-03 (ACCESS-01). Resolve STAB-21 explicitly. Document disposition for any other in-scope items. If none found beyond STAB-21, produce a short "no additional P0a items" note.

Purpose: Ensure no carryover item slips silently into later phases.
Output: SUMMARY disposition document + any necessary code fix for STAB-21.
</objective>

<context>
@.planning/phases/01-p0a-code-unblockers/01-CONTEXT.md
@.planning/backlog/STAB-carryover.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
</context>

<prior_sweep_analysis>
Per Claude's read of `.planning/backlog/STAB-carryover.md` during planning (2026-04-07):

| Item | Status | Disposition for Phase 1 |
|------|--------|-------------------------|
| STAB-01..16 | DONE in v2.1 | Do NOT re-add. Promotion guidance §1. |
| STAB-17 (manual tap-to-render walkthrough) | OPEN, human gate | **DEFERRED to Phase 12** per ROADMAP rescope 2026-04-07 + CONTEXT.md D-01 domain note. NOT Phase 1 scope. |
| STAB-19 (providers) | OPEN | Covered by PLAN-01. |
| STAB-20 (chiffre_choc rename) | OPEN | Covered by PLAN-02. |
| STAB-21 (chiffre_choc_screen split-exit bug) | OPEN | **This plan (see Task 1).** |
| 12 orphan GoRouter routes (STAB-14 deferred) | OPEN, v3.0 | Not P0a. Deferred per STAB-carryover §2. |
| ~65 NEEDS-VERIFY try/except (STAB-16 deferred) | OPEN | Not P0a. Opportunistic per STAB-carryover §3. |
| Stale test `chat_tool_dispatcher_test.dart` (STAB-01 follow-up) | OPEN, lint hygiene | Not P0a. Out of scope per STAB-carryover §4. |
| ACCESS-01 | OPEN | Covered by PLAN-03. |

**Conclusion:** Only STAB-21 is a P0a item not already covered by PLAN-01..03.
</prior_sweep_analysis>

<tasks>

<task type="auto">
  <name>Task 1: Dispose of STAB-21 (chiffre_choc_screen split-exit bug)</name>
  <files>.planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md</files>
  <action>
Per ROADMAP Phase 1 success criterion #4: "STAB-21 noted as 'moot — screen deleted in Phase 10' or fixed if Phase 10 slips."

Phase 10 is in the same milestone (v2.2 La Beauté de Mint) and explicitly deletes `chiffre_choc_screen.dart` / `premier_eclairage_screen.dart` (post-rename) via ONB-02 + ONB-03. Therefore STAB-21 is **moot-pending-deletion**.

However, because this plan runs AFTER PLAN-02 (which renamed the file to `premier_eclairage_screen.dart`), re-verify the bug location and document it.

Execute:

1. Re-run sweep of `.planning/backlog/STAB-carryover.md` to confirm no new P0a items were added between planning time and execution time.

2. Verify STAB-21 location: `git grep -n 'setMiniOnboardingCompleted' apps/mobile/lib/screens/onboarding/premier_eclairage_screen.dart` — the bug is that the arrow button in the TextField routes to `/coach/chat` WITHOUT calling `setMiniOnboardingCompleted(true)` first.

3. **Decision per ROADMAP criterion #4:**
   - If Phase 10 is still on the roadmap and not slipped → mark STAB-21 **MOOT-PENDING-DELETION** in the SUMMARY. Do NOT fix (screen dies in Phase 10).
   - If Phase 10 has slipped (check with Julien via brief chat confirmation) → apply the minimal fix: add `await context.read<OnboardingProvider>().setMiniOnboardingCompleted(true);` before the `context.go('/coach/chat')` call. Respect CLAUDE.md §9 anti-pattern #1 (context.read before await, not after).

4. Create `.planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md` with:
   - Backlog sweep disposition table (reproduce the table from `<prior_sweep_analysis>` above, with any new items found at execution time appended).
   - STAB-21 decision + rationale (MOOT-PENDING-DELETION or FIXED).
   - If FIXED: commit SHA + test reference.
   - Confirmation that PLAN-01..03 cover all other P0a items.

5. Commit: `docs(stab-21): backlog sweep + disposition for Phase 1 P0a` (or if code fix applied: `fix(stab-21): wire setMiniOnboardingCompleted before split exit to /coach/chat`).
  </action>
  <verify>
    <automated>test -f .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md &amp;&amp; grep -q 'STAB-21' .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md &amp;&amp; grep -qE 'MOOT-PENDING-DELETION|FIXED' .planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md</automated>
  </verify>
  <done>
- SUMMARY exists with full disposition table
- STAB-21 marked either MOOT-PENDING-DELETION or FIXED (with commit reference)
- If fixed: `flutter analyze lib/` = 0, `flutter test` green
- If moot: explicit reference to Phase 10 ONB-02/ONB-03 + note to Phase 10 planner: "if Phase 10 slips, re-open STAB-21 as a fix task"
- Commit landed
  </done>
</task>

</tasks>

<verification>
- `.planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md` exists
- Contains disposition for every open item in `.planning/backlog/STAB-carryover.md`
- STAB-21 resolved (moot or fixed)
- If code was touched: `flutter analyze lib/` + `flutter test` green
</verification>

<success_criteria>
Every P0a-tagged item in the STAB carryover has an explicit disposition in Phase 1. No silent slippage to Phase 2+.
</success_criteria>

<rollback>
Single commit → `git revert HEAD`. If a code fix was applied, the revert restores the pre-fix state (Phase 10 still dispatches the deletion).
</rollback>

<output>
The SUMMARY file IS the output. No additional `.planning/phases/01-p0a-code-unblockers/01-04-SUMMARY.md` step needed — Task 1 produces it.
</output>
