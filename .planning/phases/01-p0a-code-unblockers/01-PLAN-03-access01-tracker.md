---
phase: 01-p0a-code-unblockers
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/ACCESSIBILITY_TEST_LAYER1.md
autonomous: false
requirements: [ACCESS-01]
must_haves:
  truths:
    - "docs/ACCESSIBILITY_TEST_LAYER1.md exists with 6 pre-filled partner rows"
    - "Julien confirms in chat that the 6 recruitment emails have been sent"
  artifacts:
    - path: docs/ACCESSIBILITY_TEST_LAYER1.md
      provides: "ACCESS-01 tracker — partner contacts + email status + session status"
      contains: "| Partner | Contact name | Email | Date sent |"
  key_links:
    - from: docs/ACCESSIBILITY_TEST_LAYER1.md
      to: Phase 8b live a11y session + Phase 12 ship gate
      via: "tracker consumed downstream to confirm recruitment → session pipeline"
      pattern: "Session date"
---

<objective>
Create the ACCESS-01 recruitment tracker per D-03 (CONTEXT.md). Claude creates the file skeleton with 6 pre-filled partner rows; Julien sends the 6 recruitment emails personally and confirms in chat. Fire-and-forget per ROADMAP Phase 1 success criterion #1 — does NOT block on replies or session scheduling.

Purpose: Make sure recruitment is in flight before code-heavy phases begin, so sessions land in Phase 8b / Phase 12 on schedule.
Output: Committed tracker file + Julien's "emails sent" confirmation.
</objective>

<context>
@.planning/phases/01-p0a-code-unblockers/01-CONTEXT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create docs/ACCESSIBILITY_TEST_LAYER1.md skeleton with 6 pre-filled rows</name>
  <files>docs/ACCESSIBILITY_TEST_LAYER1.md</files>
  <action>
Create `docs/ACCESSIBILITY_TEST_LAYER1.md` with:

1. **Header block**:
   - Title: `# ACCESS-01 — Layer 1 Accessibility Test Tracker`
   - Subtitle: `> MINT v2.2 "La Beauté de Mint" — Phase 1 recruitment, Phase 8b + Phase 12 sessions`
   - Doctrine reminder: "Fire-and-forget recruitment per ROADMAP Phase 1 rescope 2026-04-07. Sessions land when code is ready (Phase 8b + Phase 12), not against a deadline. If recruitment slips, the milestone waits — we don't descope AAA."
   - Budget line: `Budget: CHF 800-2'000 per REQUIREMENTS.md ACCESS-01.`
   - AAA honesty gate reference: "If recruitment fails by end of Phase 1.1, apply ACCESS-09 descope (AA bloquant + AAA aspirational with known gaps documented)."

2. **Tracker table** with columns (exact header row):
   ```
   | # | Partner | Contact name | Email | Date sent | Reply received | Session date | Compte-rendu link | Status |
   ```

3. **6 pre-filled rows**. Contact name/email columns left blank (`—`) — Julien fills in with his personal contacts. Status = `PENDING`.
   - Row 1: SBV-FSA (partner 1, malvoyant·e #1)
   - Row 2: SBV-FSA (partner 1, malvoyant·e #2)
   - Row 3: ASPEDAH (partner 2, ADHD #1)
   - Row 4: ASPEDAH (partner 2, ADHD #2)
   - Row 5: Caritas (partner 3, français-seconde-langue #1)
   - Row 6: Caritas (partner 3, français-seconde-langue #2)

4. **Instructions block** for Julien under the table:
   - "To fill after sending: replace `—` with contact name + email + today's date in `Date sent`, flip Status to `EMAIL SENT`."
   - "Phase 1 completion requires: file exists (done by Claude) + 6 rows present (done by Claude) + Julien confirms 'emails sent' in chat. Replies and session scheduling do NOT block Phase 1."

5. **Downstream consumers** block: Phase 8b (ACCESS-02 first live session), Phase 12 (ACCESS-02 additional sessions + ship gate), ACCESS-09 (honesty gate).

Exact column widths and markdown polish are Claude's discretion per D-03.
  </action>
  <verify>
    <automated>test -f docs/ACCESSIBILITY_TEST_LAYER1.md &amp;&amp; grep -c '| SBV-FSA ' docs/ACCESSIBILITY_TEST_LAYER1.md | grep -q '^2$' &amp;&amp; grep -c '| ASPEDAH ' docs/ACCESSIBILITY_TEST_LAYER1.md | grep -q '^2$' &amp;&amp; grep -c '| Caritas ' docs/ACCESSIBILITY_TEST_LAYER1.md | grep -q '^2$' &amp;&amp; grep -q 'Date sent' docs/ACCESSIBILITY_TEST_LAYER1.md &amp;&amp; grep -q 'Compte-rendu' docs/ACCESSIBILITY_TEST_LAYER1.md</automated>
  </verify>
  <done>
- File exists at `docs/ACCESSIBILITY_TEST_LAYER1.md`
- Exactly 2 rows for each of SBV-FSA, ASPEDAH, Caritas
- Tracker columns present (including `Date sent` and `Compte-rendu`)
- Committed with message `docs(access-01): create Phase 1 recruitment tracker`
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Julien confirmation gate — 6 emails sent</name>
  <what-built>
Claude created `docs/ACCESSIBILITY_TEST_LAYER1.md` with 6 pre-filled rows (SBV-FSA ×2, ASPEDAH ×2, Caritas ×2). Julien now sends the 6 recruitment emails personally and flips the tracker's `Date sent` + `Status` columns.
  </what-built>
  <how-to-verify>
1. Open `docs/ACCESSIBILITY_TEST_LAYER1.md`.
2. For each of the 6 rows, send a recruitment email to your personal contact at that partner (SBV-FSA, ASPEDAH, Caritas). Use CHF 800-2'000 budget framing per REQUIREMENTS.md ACCESS-01.
3. Fill in `Contact name`, `Email`, `Date sent` (today's date), and flip `Status` to `EMAIL SENT`.
4. Commit the updated tracker: `docs(access-01): 6 recruitment emails sent`.
5. Confirm in chat: "ACCESS-01 — 6 emails sent" (or describe any blocker).

Phase 1 completion does NOT block on replies, session scheduling, or reply timing. Fire-and-forget.
  </how-to-verify>
  <resume-signal>Type "ACCESS-01 — 6 emails sent" or describe a blocker.</resume-signal>
</task>

</tasks>

<verification>
Phase 1 ACCESS-01 gate (per ROADMAP success criterion #1):
- `docs/ACCESSIBILITY_TEST_LAYER1.md` exists
- 6 rows present (2 per partner)
- Julien confirms in chat

Explicit non-gate: replies received / sessions scheduled / compte-rendu links — these land in Phase 8b and Phase 12.
</verification>

<success_criteria>
ACCESS-01 tracker file committed + Julien confirms emails sent. Phase 1 does not wait on partner replies.
</success_criteria>

<rollback>
Task 1 commit → `git revert HEAD` removes the tracker. Task 2 is a human action — rollback = Julien re-sends or updates the tracker.
</rollback>

<output>
After completion, create `.planning/phases/01-p0a-code-unblockers/01-03-SUMMARY.md` documenting:
- Tracker file path + column schema
- Date Julien confirmed "emails sent"
- Any notes on partner contact choices
</output>
