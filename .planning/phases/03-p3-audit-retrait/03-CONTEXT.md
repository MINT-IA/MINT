# Phase 3 — L1.1 Audit du Retrait (S0-S5) — CONTEXT

**Created:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Requirements:** AUDIT-03, AESTH-08
**Depends on:** Phase 1 (unblockers), Phase 2 (AAA tokens shipped, AUDIT-01/02 done)

<domain>
Pure audit phase. **Zero production code changes.** Output is a single markdown
document: `docs/AUDIT_RETRAIT_S0_S5.md`. No Dart edits, no ARB edits, no token
edits, no screenshot pipeline wiring. Static code read of the 6 S0-S5 source
files + a disciplined DELETE/KEEP/REPLACE pass per element, with math that
proves the -20% reduction target from AESTH-08 is achievable.

Downstream phases (8a MTC migration, 8b microtypo+AAA application, 8c polish
pass) consume this audit as their source-of-truth input list. No S0-S5 surface
gets touched in later phases without first appearing in this DELETE list.
</domain>

<decisions>

## D-01 — S0-S5 surface mapping (LOCKED)

The 6 surfaces audited in this phase, mapped to exact file paths:

| Surface | Name | File | Notes |
|---|---|---|---|
| **S0** | Landing | `apps/mobile/lib/screens/landing_screen.dart` | First-launch promise surface. Phase 7 rebuilds it; this audit inventories the current state so Phase 7 knows what to kill. |
| **S1** | Onboarding Intent | `apps/mobile/lib/screens/onboarding/intent_screen.dart` | The single chip-chooser Phase 10 will rewire to `/coach/chat`. Audit the current version. |
| **S2** | Home | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | Aujourd'hui tab. The biggest element budget of the 6. Highest-leverage DELETE targets. |
| **S3** | Coach Chat Bubble | `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` | Single chat bubble as rendered inside `coach_chat_screen.dart`. Audit the bubble widget, not the whole chat screen shell. |
| **S4** | Response Card | `apps/mobile/lib/widgets/coach/response_card_widget.dart` | The coach response card family that Phase 4 migrates to MTC first. |
| **S5** | MintAlertObject | **DOES NOT YET EXIST** — Phase 9 will create `apps/mobile/lib/widgets/mint_alert_object.dart`. Audit the closest current stand-in: `apps/mobile/lib/widgets/report/debt_alert_banner.dart` plus any inline alert rendering found inside S2/S4 via grep. Flag S5 as "pre-creation audit of legacy alert patterns" — the DELETE list for S5 is effectively the list of legacy patterns the Phase 9 typed API must NOT reproduce. |

Any ambiguity between the brief (v0.2.3 §5 naming: S1 onboarding intent / S2 home
/ S3 bubble coach / S4 carte résultat / S5 MintAlertObject) and the roadmap
(S0-S5 = 6 surfaces) is resolved by adding **S0 = landing** as the 6th surface.
Landing is in scope for AESTH-08 per Phase 3 Success Criteria in ROADMAP.md.

## D-02 — "Element" counting methodology (LOCKED)

An **element** = any **visible-to-user renderable** in the widget tree that
occupies screen real estate OR conveys information OR chrome. Counted as 1:

1. Any `Text`, `RichText`, `SelectableText`, or inline `TextSpan` that renders
   distinct user-visible copy (empty/whitespace `Text` excluded).
2. Any `Icon`, `SvgPicture`, `Image`, `CircleAvatar`, `CustomPaint` with a
   visible painter.
3. Any interactive primitive: `ElevatedButton`, `TextButton`, `IconButton`,
   `FilledButton`, `InkWell`/`GestureDetector` wrapping visible content,
   `Switch`, `Checkbox`, `Slider`, `Chip`, `ChoiceChip`, `DropdownMenu`,
   `TextField`, `TextFormField`.
4. Any decorative chrome with a distinct visual footprint: `Divider`, `Card`,
   `Container` **with** `BoxDecoration` (gradient, border, shadow, color fill)
   — containers that only apply padding/alignment do NOT count.
5. Any `Chart`/`CustomPainter` chart element (one count per chart, not per
   datapoint).
6. Any `Badge`, `Tooltip` visible body, `Tag`, progress indicator
   (`LinearProgressIndicator`, `CircularProgressIndicator`).

**Does NOT count (layout primitives):** `Column`, `Row`, `Stack`, `Padding`,
`SizedBox`, `Align`, `Center`, `Expanded`, `Flexible`, `SingleChildScrollView`,
`SafeArea`, `Material`, `Scaffold`, `AppBar` shell (its title/actions count
individually). Pure theme `Container` (only color/padding) does NOT count.

**Conditional branches:** if a widget is rendered conditionally and both
branches are reachable at runtime, count the **union** (each reachable branch
contributes its own elements). Document the branch in the audit row.

**Loops (`ListView.builder`, `List.generate`):** count the item template as
1 element per widget inside the template (not N for N items). Flag as "list
item × N" in the row.

**AppBar:** title = 1, each action icon = 1, each leading = 1, subtitle = 1.

Rule is applied by a single auditor (the executor) in one pass with greps. No
automated tool; discipline + citation of line number per count.

## D-03 — DELETE criteria (LOCKED)

An element is DELETE if **any** of the following applies:

- **D-03.a Anti-shame violation** — compares user to anyone but past self,
  displays a "level/score/progress bar tied to financial knowledge", contains
  imperative "tu dois/il faut" without conditional softening, explains a
  concept the user has not yet seen a personal stake in, or any of the 6
  anti-shame checkpoints in `feedback_anti_shame_situated_learning.md`. This
  criterion **overrides every KEEP argument**.
- **D-03.b Decorative noise** — pure ornament: gradient background with no
  information role, shadow-on-shadow, icon duplicating adjacent text, badge
  that restates the card state already visible.
- **D-03.c Redundancy** — same information rendered twice in the same viewport
  (e.g. percentage + progress bar + numeric label all for the same value).
- **D-03.d Token/AAA violation unfixable in place** — pastel used as
  information-bearing text on S0-S5 where AAA tokens are required, hex literal
  (`Color(0xFF...)`) with no migration target, contrast < 7:1 and no AAA token
  exists for the role. (If a fix exists via AAA token swap → REPLACE, not
  DELETE.)
- **D-03.e Chart clutter** — decorative chart element with no user-actionable
  meaning (gridline label overload, legend duplicating axis, axis labels on
  both sides).
- **D-03.f Retirement framing / banned vocabulary** — any element whose copy
  contains "chiffre choc", "retraite" defaulting, `_segmentsForAge`, or any
  CLAUDE.md §9 anti-pattern #16 violation. Flag immediately.
- **D-03.g Onboarding curriculum** — any element that teaches before the user
  has a personal stake (courses, progress bars, "learn more" buttons with no
  situated trigger).

## D-04 — KEEP criteria (LOCKED)

An element is KEEP if **all** of the following apply:
- Carries user-actionable information OR is a primary CTA OR is structural
  (the single headline, the single MTC slot, the single hypotheses footer).
- Passes the anti-shame doctrine with zero ambiguity (subject to D-03.a).
- Already on an AAA token OR on a neutral surface (craie/porcelaine background
  is KEEP; pastel as background is KEEP; pastel as text is DELETE).
- Is not redundant with another KEEP element in the same viewport.
- Survives a "if I remove this, does the user lose something?" test.

## D-05 — REPLACE criteria (LOCKED)

An element is REPLACE (not DELETE, not KEEP as-is) if it carries essential
meaning but its current rendering violates a rule that has a known migration
target:
- **D-05.a → AAA token swap** — text element on a legacy token with a 1:1 AAA
  counterpart in `colors.dart` (Phase 2 shipped `textSecondaryAaa`,
  `textMutedAaa`, `successAaa`, `warningAaa`, `errorAaa`, `infoAaa`).
- **D-05.b → MTC placeholder** — any inline confidence rendering, percentage
  badge, 4-axis bar, or "confidence" string that Phase 4 MTC component will
  absorb. Mark as `REPLACE → MTC.inline()` / `REPLACE → MTC.detail()` /
  `REPLACE → MTC.Empty(missingAxis)` per AUDIT-01 classification.
- **D-05.c → ARB extraction** — hardcoded user-facing string. Mark with the
  proposed ARB key name. Does not count as a reduction win but MUST be flagged.
- **D-05.d → MintAlertObject placeholder** — any inline G2/G3-flavored alert
  that Phase 9 will replace with the typed `MintAlertObject` API.
- **D-05.e → hypotheses footer slot** — numeric projection currently rendered
  without a visible hypotheses footer that MTC-07 (TRUST-01) requires.

REPLACE elements count as **1 pre / 1 post** in the reduction math (they do
not contribute to the -20% win), but they must be flagged so Phase 8a/8b know
which sites to touch. A REPLACE can become a DELETE if the replacement is
subsumed by another REPLACE (e.g. three confidence badges collapsing into one
MTC instance = 3 pre / 1 post, 2 deletions).

## D-06 — Reduction math (LOCKED)

For each surface S_i:
- `pre_count(S_i)` = sum of all counted elements before the audit pass.
- `target_count(S_i) = floor(pre_count(S_i) × 0.80)`.
- `post_count(S_i)` = KEEP + REPLACE (since REPLACE is 1→1 in raw count).
- **Pass condition per surface:** `post_count(S_i) ≤ target_count(S_i)`.
- **Aggregate pass:** `sum(post) ≤ floor(sum(pre) × 0.80)`.

If aggregate passes but a surface misses its per-surface target, flag the
surface in the "Gaps" section of the audit doc with a recommendation: either
find more DELETEs on that surface, OR explicitly exempt it with a written
rationale (e.g. "S3 bubble coach is already near-minimal; aggregate carries").

If **aggregate fails**, the audit doc MUST include a "SCOPE PATCH" section
recommending which surfaces need deeper cuts or which AESTH-08 clause needs
renegotiation BEFORE Phase 8a can start. This is a blocking output.

## D-07 — Anti-shame overrides everything (LOCKED)

Per `feedback_anti_shame_situated_learning.md`, any element that violates the
anti-shame doctrine is **DELETE with no appeal**. Specifically any:
- Financial level / skill tier / XP / streak tied to knowledge
- Social comparison ("top X%", "gens dans ta situation")
- "Complete your profile" / "fill in your data" framing
- Progress bar tied to financial understanding
- Imperative voice without conditional softening

These elements are tagged `DELETE — anti-shame` in the audit with explicit
citation of which checkpoint was tripped (1-6 in the feedback doc). This tag
is audit-escalated: if an element is anti-shame DELETE, it counts as a
DELETE even if a later phase might otherwise have KEPT it.

## D-08 — Screenshot evidence (DEFERRED)

ROADMAP Phase 3 Success Criteria #2 mentions "before/after screenshots pair
per surface". **Before** screenshots are in scope for this phase (the current
state of each surface on a Galaxy A14 emulator or the macOS Flutter desktop
target, committed to `.planning/phases/03-p3-audit-retrait/screenshots-before/`).
**After** screenshots are impossible this phase (no code changes). They land
in Phase 8c (Polish Pass #1) which owns the `-20% holds post-migration`
verification per its Success Criterion #3.

This phase ships **before screenshots + element counts** as the evidence pair;
"after screenshots" is explicitly deferred to 8c.

If capturing before-screenshots proves flaky (emulator setup, keystore, etc.),
the executor may degrade to **annotated line-number-cited code extracts** in
the audit doc as a substitute, and note the deferral. This is acceptable — the
element count is the load-bearing evidence, not the screenshots.

## D-09 — Scope boundary (LOCKED)

- Read-only code audit. No edits to `apps/mobile/lib/**`, no edits to `l10n/`,
  no edits to `theme/`, no edits to backend.
- The only file created is `docs/AUDIT_RETRAIT_S0_S5.md`.
- Optional: `.planning/phases/03-p3-audit-retrait/screenshots-before/*.png`
  if before-screenshots are captured (D-08).
- Commit count: exactly 1 commit (`docs(p3): audit du retrait S0-S5`).
- No flutter test run, no analyze run, no pytest run required for this phase
  (no code touched). The phase gate is "doc exists, math holds, committed".

## D-10 — Audit author discipline (LOCKED)

The audit is one executor, one pass, one commit. Per element row:
- `surface`, `file:line`, `element type`, `purpose (1 line)`, `verdict`,
  `rationale (1 line)`, `replacement target (if REPLACE)`.
- Markdown table per surface, aggregate summary table at the top.
- Executor does NOT propose fixes beyond what's already in D-05. This is an
  audit, not a redesign session.
- Executor does NOT run grep against files outside the 6 mapped surfaces.
  Inline alerts found INSIDE S2/S4 via search count toward S5 per D-01 note.

</decisions>

<canonical_refs>

## Source files (audit input)

- S0: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/landing_screen.dart`
- S1: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/intent_screen.dart`
- S2: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/main_tabs/mint_home_screen.dart`
- S3: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/coach/coach_message_bubble.dart`
- S4: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/coach/response_card_widget.dart`
- S5 stand-in: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/report/debt_alert_banner.dart` (plus inline alert patterns discovered inside S2/S4)

## Governing documents

- Doctrine: `/Users/julienbattaglia/Desktop/MINT/CLAUDE.md` (§1, §6, §9)
- Anti-shame: `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`
- Design system (12-token palette, screen categories): `/Users/julienbattaglia/Desktop/MINT/docs/DESIGN_SYSTEM.md`
- Brief v0.2.3 §5 (surfaces) + §6 L1.1 (chantier definition): `/Users/julienbattaglia/Desktop/MINT/visions/MINT_DESIGN_BRIEF_v0.2.3.md`
- Roadmap Phase 3 success criteria: `/Users/julienbattaglia/Desktop/MINT/.planning/ROADMAP.md` lines 101-111
- Requirements AUDIT-03 + AESTH-08: `/Users/julienbattaglia/Desktop/MINT/.planning/REQUIREMENTS.md` lines 56 + 82

## Upstream phase outputs consumed

- Phase 2 `docs/AUDIT_CONFIDENCE_SEMANTICS.md` — 42-site classification, used to tag REPLACE → MTC sites.
- Phase 2 `docs/AUDIT_CONTRAST_MATRIX.md` — per-token contrast table, used to tag REPLACE → AAA token swaps.
- Phase 2 `apps/mobile/lib/theme/colors.dart` — 6 AAA tokens live (`textSecondaryAaa` #555560, `textMutedAaa` #525256, `successAaa`, `warningAaa`, `errorAaa`, `infoAaa`).

## Downstream consumers

- Phase 4 (MTC + S4 migration) — reads the S4 DELETE list as the surface to prune pre-migration.
- Phase 7 (Landing v2 rebuild) — reads the S0 DELETE list as the "what to kill before rebuilding".
- Phase 8a (MTC 11-surface migration) — reads REPLACE → MTC tags as its migration map.
- Phase 8b (Microtypo + AAA application) — reads REPLACE → AAA token tags as its swap map.
- Phase 8c (Polish Pass #1) — reads the element count as the baseline for the post-migration -20% hold check.

</canonical_refs>

<code_context>

## Audit starting state (end of Phase 2)

- 6 AAA tokens **implemented** in `colors.dart` (strict 7:1 against both white
  and craie). Not yet applied to S0-S5 — that's Phase 8b.
- `VoiceCursorContract` codegen live; `Profile.voiceCursorPreference` /
  `n5IssuedThisWeek` / `fragileMode` fields shipped; no UI consumer yet.
- `docs/AUDIT_CONFIDENCE_SEMANTICS.md` classifies 42 confidence-rendering
  sites into 3 categories with per-category MTC decisions. The audit executor
  uses this to disambiguate which S0-S5 confidence elements become REPLACE →
  MTC and which stay untouched (the 7 logic-gate consumers).
- `docs/AUDIT_CONTRAST_MATRIX.md` is the per-pair contrast ground truth for
  REPLACE → AAA tag decisions.
- `MintTrameConfiance` does **not yet exist**. REPLACE → MTC tags are
  placeholders for Phase 4 / 8a to consume.
- `MintAlertObject` does **not yet exist**. REPLACE → MintAlertObject tags are
  placeholders for Phase 9 to consume.
- `chiffre_choc` domain rename (Phase 1.5) is shipped; if the executor finds
  any residue in the 6 surfaces, it's an automatic DELETE under D-03.f and
  should be flagged.
- The 4 broken providers (STAB-19, Phase 1) are wired; any "silent fallback"
  chrome on S2 home is auto-DELETE.

## Anti-patterns to spot on first read

- `Color(0xFF...)` hex literals → D-03.d or D-05.a
- Pastel (`saugeClaire`, `bleuAir`, `pecheDouce`, `corailDiscret`) used as
  text color → D-03.d (DELETE, no in-place fix for S0-S5)
- Hardcoded French string → D-05.c
- Inline `ConfidenceBanner`, `ConfidenceScoreCard`, inline percentage badges
  → D-05.b
- "Compléter ton profil" / "Remplis tes données" / progress bar → D-03.g or
  anti-shame DELETE
- `dart` string containing "chiffre", "choc", "retraite" as default framing
  → D-03.f

</code_context>
</content>
</invoke>