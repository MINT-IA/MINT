---
phase: 08b-l1.3-microtypo-aaa-a11y
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/ACCESSIBILITY_TEST_LAYER1.md
autonomous: false
requirements: [ACCESS-02, ACCESS-09]
user_setup:
  - service: ACCESS-01 recruitment
    why: "Live accessibility session cannot happen without partner replies"
    dashboard_config:
      - task: "Julien must send the 6 recruitment emails (SBV-FSA x2, ASPEDAH x2, Caritas x2) if not already done"
        location: "Julien's personal email client; tracker at docs/ACCESSIBILITY_TEST_LAYER1.md"
must_haves:
  truths:
    - "EITHER ≥1 live a11y session compte-rendu is committed to docs/ACCESSIBILITY_TEST_LAYER1.md"
    - "OR ACCESS-09 descope decision is committed with exact AAA honesty gate language"
  artifacts:
    - path: "docs/ACCESSIBILITY_TEST_LAYER1.md"
      provides: "Updated tracker with compte-rendu OR ACCESS-09 descope decision block"
  key_links:
    - from: "Phase 8b ship decision"
      to: "ACCESS-01 recruitment status"
      via: "blocking checkpoint"
---

<objective>
Run the first live accessibility session with ≥1 of 3 partners (SBV-FSA,
ASPEDAH, Caritas) and commit a compte-rendu to `docs/ACCESSIBILITY_TEST_LAYER1.md`,
OR — if recruitment has slipped — commit the ACCESS-09 AAA honesty gate
descope decision using the exact language from D-10.

**This plan is GATED on ACCESS-01 email status.** At execution start,
Claude reads the tracker file and takes one of three forks (D-09).

Purpose: Close ACCESS-02 (≥1 session) or ACCESS-09 (honest descope). Either
outcome is acceptable; silent drift is not.

Output: Updated `docs/ACCESSIBILITY_TEST_LAYER1.md`.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-CONTEXT.md
@docs/ACCESSIBILITY_TEST_LAYER1.md
@.planning/REQUIREMENTS.md
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1: GATE — check ACCESS-01 email status with Julien</name>
  <what-built>
    Plans 01-03 have shipped AAA tokens, Spiekermann microtypo, liveRegion,
    and reduced-motion fallback on S0-S5. The code side of Phase 8b is done.
    Phase 8b completeness now depends on the live a11y session.
  </what-built>
  <how-to-verify>
    Open `docs/ACCESSIBILITY_TEST_LAYER1.md` and tell Claude which fork we're in:

    **Fork A — SESSION POSSIBLE:** emails sent + ≥1 partner replied + slot scheduled or held.
      Claude proceeds to Task 2 (session + compte-rendu).

    **Fork B — WAITING:** emails sent but no replies yet.
      Claude proceeds to Task 3 (defer session to Phase 12, stage honesty gate language, do NOT commit descope yet).

    **Fork C — NOT SENT:** Julien has not sent the 6 recruitment emails yet.
      ESCALATION: Claude halts Plan 04, reports to orchestrator. Julien must
      either (a) send the emails and re-run Plan 04 later, or (b) authorize
      early ACCESS-09 descope commit.

    Note: As of Phase 8b planning (2026-04-07), the tracker showed all 6 rows
    PENDING with no contact names, dates, or EMAIL SENT statuses. Fork C was
    the most likely state. Confirm current reality before proceeding.
  </how-to-verify>
  <resume-signal>Reply with "Fork A", "Fork B", or "Fork C" (+ any context)</resume-signal>
</task>

<task type="auto">
  <name>Task 2: [Fork A only] Run session + commit compte-rendu</name>
  <files>docs/ACCESSIBILITY_TEST_LAYER1.md</files>
  <action>
    ONLY execute if Task 1 returned Fork A.

    1. Update the tracker row for the participating partner: fill `Contact name`,
       `Email`, `Date sent`, `Reply received`, `Session date`.
    2. Run the session (Julien + tester + Claude as observer if remote).
       Protocol follows the audience targets:
       - **SBV-FSA (malvoyant):** VoiceOver/TalkBack pass on S0-S5, contrast
         subjective check, screen-reader narration of coach bubble.
       - **ASPEDAH (ADHD adult):** cognitive load, 4-line MUJI clarity,
         friction on onboarding intent chip.
       - **Caritas (français seconde langue):** copy clarity on the 6 surfaces,
         jargon flags, voice perception.
    3. Write compte-rendu as a new section `## Session 1 — <partner> — <date>`
       inside `docs/ACCESSIBILITY_TEST_LAYER1.md` with: participants, setup,
       tasks attempted, pass/fail per surface, quotes, findings, follow-ups.
    4. **AAA honesty gate decision:** commit ONE of these two lines at the
       bottom of the session section:
       - "**AAA met on S0-S5** — verified in Session 1 against <partner>."
       - "**AAA descoped to AA + documented gaps per ACCESS-09** — see `docs/AUDIT_CONTRAST_MATRIX.md` gaps list."
    5. Flip the participant's row `Status` to `DONE` and link the compte-rendu
       section.
  </action>
  <verify>
    <automated>grep -q "^## Session 1 —" docs/ACCESSIBILITY_TEST_LAYER1.md && grep -qE "AAA met on S0-S5|AAA descoped to AA" docs/ACCESSIBILITY_TEST_LAYER1.md</automated>
  </verify>
  <done>Compte-rendu committed, AAA gate decision committed, tracker row updated.</done>
</task>

<task type="auto">
  <name>Task 3: [Fork B only] Defer to Phase 12, stage descope language</name>
  <files>docs/ACCESSIBILITY_TEST_LAYER1.md</files>
  <action>
    ONLY execute if Task 1 returned Fork B.

    Add a section `## Phase 8b — Session deferred to Phase 12` with:
    - Reason: emails sent <date>, no replies received by Phase 8b ship.
    - Plan: session(s) land in Phase 12 per ROADMAP audit fix C4
      (target 3 sessions across 8b + 12 — we're trading "1 in 8b" for
      "all 3 in 12").
    - Risk: if no replies by Phase 12, ACCESS-09 descope triggers.
    - Pre-staged descope language (commit this inline as a quoted block
      but DO NOT mark as active — only Fork C or Phase 12 failure activates):

    > **ACCESS-09 descope trigger (Phase 8b).** Recruitment slipped despite
    > fire-and-forget emails. MINT v2.2 ships AA bloquant CI on all touched
    > surfaces + AAA aspirational on S0-S5 with known gaps documented in
    > `docs/AUDIT_CONTRAST_MATRIX.md`. False AAA claim is worse than honest AA.

    Phase 8b ships with ACCESS-02 PARTIAL (0/1 session) and ACCESS-09 ARMED.
  </action>
  <verify>
    <automated>grep -q "Phase 8b — Session deferred to Phase 12" docs/ACCESSIBILITY_TEST_LAYER1.md</automated>
  </verify>
  <done>Deferral note committed, descope language staged, orchestrator informed Phase 8b ships with ACCESS-02 partial.</done>
</task>

<task type="auto">
  <name>Task 4: [Fork C only] Escalate + commit explicit blocker note</name>
  <files>docs/ACCESSIBILITY_TEST_LAYER1.md</files>
  <action>
    ONLY execute if Task 1 returned Fork C and Julien has NOT authorized
    early descope.

    Add a section `## Phase 8b — BLOCKED on ACCESS-01 recruitment` with:
    - Status: 6 emails NOT sent as of <date>.
    - Blocker: Phase 8b cannot close ACCESS-02 without at least one session.
    - Action required: Julien to send the 6 recruitment emails per the
      "Instructions for Julien" section of this same file, then re-run
      Plan 04.
    - Parallel ship: Plans 01-03 (code side) SHIP anyway on
      `feature/v2.2-p0a-code-unblockers`. Phase 8b stays open until Plan 04
      resolves (session committed OR ACCESS-09 descope authorized).

    Return to orchestrator with explicit "PHASE 8b PARTIAL — Plans 01-03
    shipped, Plan 04 blocked on ACCESS-01 Julien action."

    If instead Julien authorizes early descope (Fork C with descope OK),
    commit the D-10 descope block verbatim as the active decision.
  </action>
  <verify>
    <automated>grep -qE "BLOCKED on ACCESS-01|ACCESS-09 descope trigger" docs/ACCESSIBILITY_TEST_LAYER1.md</automated>
  </verify>
  <done>Blocker committed and escalated OR descope committed per Julien's authorization.</done>
</task>

</tasks>

<verification>
- Exactly ONE of Tasks 2/3/4 executed (matching the fork from Task 1)
- `docs/ACCESSIBILITY_TEST_LAYER1.md` updated
- Orchestrator has explicit status: ACCESS-02 CLOSED / PARTIAL / BLOCKED
</verification>

<success_criteria>
- Phase 8b ships with one of:
  (a) ACCESS-02 closed via a real session + AAA gate decision committed, OR
  (b) ACCESS-02 partial with honest deferral to Phase 12, OR
  (c) ACCESS-09 descope committed with exact honesty gate language (D-10)
- No silent drift. No pretend AAA without a tester behind it.
</success_criteria>

<output>
Create `.planning/phases/08b-l1.3-microtypo-aaa-a11y/08b-04-SUMMARY.md` with
the fork taken, the committed content, and the Phase 8b close status.
</output>
