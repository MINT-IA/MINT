---
phase: 08b-l1.3-microtypo-aaa-a11y
type: context
created: 2026-04-07
branch: feature/v2.2-p0a-code-unblockers
---

# Phase 8b — L1.3 Microtypographie + AAA Token Application + First Live a11y Session

## Goal (outcome-shaped)

Every S0–S5 surface reads like it was set by Spiekermann (4pt grid, 45–75 char
measure, max 3 heading levels, Aesop-demoted headline numbers, MUJI 4-line
grammar on S4), every text/icon pair hits WCAG AAA 7:1 using the Phase 2
tokens, semantic color is reduced to one desaturated amber meaning "verifiable
fact requiring attention", coach bubbles announce themselves to screen readers
without stealing focus, reduced-motion fallbacks hold across the 3 motion
surfaces, and ≥1 live accessibility session is on the books with a written
compte-rendu **OR** the AAA honesty gate is triggered (ACCESS-09 descope).

## Decisions (LOCKED — non-negotiable)

### D-01 — S0–S5 file set is frozen from Phase 3 AUDIT_RETRAIT
Phase 8b touches exactly these 6 source files (no scope creep):
- **S0** `apps/mobile/lib/screens/landing_screen.dart`
- **S1** `apps/mobile/lib/screens/onboarding/intent_screen.dart`
- **S2** `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart`
- **S3** `apps/mobile/lib/widgets/coach/coach_message_bubble.dart`
- **S4** `apps/mobile/lib/widgets/coach/response_card_widget.dart`
- **S5** `apps/mobile/lib/widgets/report/debt_alert_banner.dart`

Inline alert patterns on S2/S4 per `docs/AUDIT_RETRAIT_S0_S5.md` line 525-529
are already absorbed into S2 / S4 rows — no extra files.

### D-02 — AAA token migration is MANUAL per-file, not a codemod
Rationale: only 15 REPLACE→AAA rows across 6 files (per AUDIT_RETRAIT line 620:
S0=7, S2=4, S3=1, S4=3). A sed/dart-fix codemod across the repo would risk
bleeding into out-of-scope files where pastels are legitimately still usable.
Manual edits scoped to the 6 files are faster AND safer than a codemod +
rollback.

Each swap MUST cite the row from `docs/AUDIT_RETRAIT_S0_S5.md` (e.g. "S0 R1").

### D-03 — AAA token swap map (copy-paste target for executor)
Token migrations for S0–S5 text/icon surfaces:
- `MintColors.textSecondary` → `MintColors.textSecondaryAaa` (#595960)
- `MintColors.textMuted` → `MintColors.textMutedAaa` (#5C5C61)
- `MintColors.success` (information-bearing) → `MintColors.successAaa` (#0F5E28)
- `MintColors.warning` (information-bearing) → `MintColors.warningAaa` (#8C3F06)
- `MintColors.error` (information-bearing) → `MintColors.errorAaa` (#A52121)
- `MintColors.info` (information-bearing) → `MintColors.infoAaa` (#004FA3)

**Background-only pastels kept as-is:** `saugeClaire`, `bleuAir`, `pecheDouce`,
`corailDiscret`, `porcelaine` — may remain as surface fills / dividers / ghosts,
but NEVER carry text or iconography on S0–S5 (AESTH-05).

### D-04 — One-color-one-meaning on S0–S5
Only `warningAaa` (#8C3F06) carries semantic weight on S0–S5 and only for
"verifiable fact requiring attention" (per AESTH-06). All other success /
error / info chips on S0–S5 text surfaces get neutralized to
`textPrimary` / `textSecondaryAaa`. Icons lose color tint unless they are the
single warningAaa slot.

Exception: destructive confirmations (e.g. debt banner CTA on S5) may retain
errorAaa — but capped at ONE occurrence per surface.

### D-05 — Heading level enforcement is lint + golden, not manual
- **Lint (AESTH-02):** extend `analysis_options.yaml` custom lint OR add a
  dart test in `test/design_system/heading_levels_test.dart` that parses the
  6 source files for widget tree `MintHeadingN` / `Text(... fontSize >= 24)`
  and asserts ≤ 3 distinct heading sizes per screen. If no MintHeadingN
  abstraction exists yet, the test enumerates via text-style lookup.
- **Golden (AESTH-01):** add pixel-snap assertion in a golden test at
  Galaxy A14 width (360×800). The test instruments Text widgets, reads their
  layout `Offset.dy % 4 == 0` and fails on any non-multiple-of-4 baseline.

Executor picks ONE mechanism per rule; if lint plumbing is too invasive,
a dart-side widget test is acceptable. Document the choice in the plan SUMMARY.

### D-06 — MUJI 4-line grammar on S4 is a widget constraint + lint comment
`response_card_widget.dart` gets an explicit section layout enforcing exactly
4 body slots in this order:
1. What this is (label / category)
2. What you're doing now (current state)
3. What happens without change (inline MTC slot if present)
4. What you could do next (suggested action)

No chrome between slots. Enforced by a comment banner in the widget AND a
widget test that counts direct children of the body `Column`.

### D-07 — Line length 45–75 char enforced via widget test at A14 width
`test/design_system/line_length_test.dart` renders each of the 6 surfaces
at 360×800, extracts visible `Text` widgets, computes per-line char count via
`TextPainter`, asserts `min ≥ 45 && max ≤ 75` on body copy (headlines
exempted). Failing strings get `SizedBox(width: …)` constraints or copy edits
in the same task.

### D-08 — liveRegion + reduced-motion audit scope
- **liveRegion:** `coach_message_bubble.dart` incoming messages wrap their
  Text in `Semantics(liveRegion: true, …)`. One test asserts semantics tree
  after a new incoming message.
- **Reduced-motion audit** covers 3 surfaces ONLY (per ACCESS-07):
  1. MTC bloom animation (wherever the MTC widget lives post-8a)
  2. Coach typing indicator
  3. Onboarding transitions (`intent_screen.dart` + any shared transition)
- Each site checks `MediaQuery.disableAnimationsOf(context)` and falls back
  to 50ms opacity-only OR skip entirely. Test: override `MediaQueryData` with
  `disableAnimations: true` and assert animation duration ≤ 50ms.

### D-09 — Live a11y session is GATED on ACCESS-01 email status
**Blocker status as of 2026-04-07:** per `docs/ACCESSIBILITY_TEST_LAYER1.md`
inspection, the recruitment tracker shows **all 6 rows PENDING**, no contact
names, no dates, no `EMAIL SENT` status. Julien has not yet sent the
ACCESS-01 recruitment emails.

**Fork:**
- **If emails sent + ≥1 reply received by Phase 8b execution start:**
  Plan 04 runs the session + commits compte-rendu to
  `docs/ACCESSIBILITY_TEST_LAYER1.md`.
- **If emails sent but no reply yet:** Plan 04 degrades to a "scheduling +
  wait" task. Session defers to Phase 12 ship gate per ROADMAP Phase 12
  audit fix C4 (target 3 sessions across 8b + 12).
- **If emails not sent:** Plan 04 BLOCKS. Executor escalates to orchestrator
  who escalates to Julien. Items 1–4 (Plans 01–03) ship regardless —
  Phase 8b is NOT fully complete until the session lands OR ACCESS-09
  descope decision is committed.

### D-10 — AAA honesty gate fallback (ACCESS-09)
If by end of Phase 8b execution no live session has happened AND no reply
is scheduled for Phase 12, Plan 04 commits a descope decision to
`docs/ACCESSIBILITY_TEST_LAYER1.md` with this exact language:

> **ACCESS-09 descope trigger (Phase 8b).** Recruitment slipped despite
> fire-and-forget emails. MINT v2.2 ships AA bloquant CI on all touched
> surfaces + AAA aspirational on S0–S5 with known gaps documented in
> `docs/AUDIT_CONTRAST_MATRIX.md`. False AAA claim is worse than honest AA.

This language is prepared in Plan 04 action but only committed if D-09
fork lands in the "no session" branch.

## Deferred Ideas (NOT in Phase 8b)

- **Codemod automation of token swaps** — deferred; manual is faster at 15 rows.
- **Expanding the S0–S5 set** — locked at 6 files; bigger surface area = later phases.
- **New MintHeadingN abstraction** — if it doesn't exist, the heading test uses
  TextStyle fontSize inspection instead of creating a new abstraction.
- **Voice flag for reduced-motion** — Phase 12 VOICE-13 concern, not here.
- **Sessions 2 + 3** — Phase 12 (per ROADMAP audit fix C4).
- **ACCESS-05 TalkBack 13 widget trap sweep** — Phase 9.
- **ACCESS-06 Flesch-Kincaid CI gate** — Phase 10.
- **ACCESS-03 AA floor CI** — Phase 12.

## Claude's Discretion

- Exact lint vs widget-test mechanism for AESTH-01 / AESTH-02 (per D-05).
- Whether to wrap body `Column` children in a named `_S4BodySlot` helper.
- Exact test file names and split between `test/design_system/` and
  `test/accessibility/`.
- Whether liveRegion wrapper lives in `coach_message_bubble.dart` directly
  or gets factored into a small `CoachAnnouncement` helper.

## Requirement Coverage

| Req       | Plan | Notes                                                  |
|-----------|------|--------------------------------------------------------|
| AESTH-01  | 02   | 4pt baseline golden test                               |
| AESTH-02  | 02   | 45–75 char line length + max 3 heading levels          |
| AESTH-03  | 02   | Headline numbers demoted to body weight on S4          |
| AESTH-05  | 01   | S0–S5 text surfaces → AAA tokens; pastels → bg only    |
| AESTH-06  | 01   | One-color-one-meaning: warningAaa only semantic color  |
| AESTH-07  | 02   | MUJI 4-line grammar on S4 response card                |
| ACCESS-02 | 04   | ≥1 live session compte-rendu (GATED)                   |
| ACCESS-04 | 01   | WCAG AAA 7:1 verified on S0–S5 post-swap               |
| ACCESS-07 | 03   | Reduced-motion fallback across 3 surfaces              |
| ACCESS-08 | 03   | liveRegion: true on coach_message_bubble incoming      |
| ACCESS-09 | 04   | AAA honesty gate fallback language prepared            |

All 11 Phase 8b requirements mapped. No orphans.

## Escalation

**ACCESS-01 email status is the single biggest risk to Phase 8b completeness.**
Orchestrator MUST confirm with Julien before dispatching Plan 04 executor:
1. Have the 6 recruitment emails been sent?
2. If yes, any replies in the inbox?
3. If no replies, is there appetite to ship Plans 01–03 and defer Plan 04?

Plans 01–03 are fully unblocked and can run in Wave 1 in parallel (different
files per plan except where D-01 overlaps — see wave assignment).
