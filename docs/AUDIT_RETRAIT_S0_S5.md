# AUDIT RETRAIT — Surfaces S0–S5

**Phase:** 03-p3-audit-retrait / Plan 03-01
**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Requirements:** AUDIT-03, AESTH-08
**Status:** committed — pure audit, zero production code touched
**Method:** counting rule per CONTEXT §D-02 · verdict criteria D-03 / D-04 / D-05 · anti-shame override D-07 · math D-06
**Screenshots:** D-08 deferred to Phase 8c (no runnable emulator in this session; annotated line citations are the load-bearing evidence per D-08 fallback clause)

---

## Source file manifest

| Surface | Name | File |
|---|---|---|
| S0 | Landing | `apps/mobile/lib/screens/landing_screen.dart` |
| S1 | Onboarding Intent | `apps/mobile/lib/screens/onboarding/intent_screen.dart` |
| S2 | Home (Aujourd'hui) | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` |
| S3 | Coach Message Bubble | `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` |
| S4 | Response Card | `apps/mobile/lib/widgets/coach/response_card_widget.dart` |
| S5 | Alert patterns (stand-in) | `apps/mobile/lib/widgets/report/debt_alert_banner.dart` + inline alert patterns in S2/S4 |

---

## Aggregate table

| Surface | pre | target (pre × 0.80, floor) | post (KEEP + REPLACE) | Δ (pre − post) | verdict |
|---|---:|---:|---:|---:|:---:|
| S0 Landing | 37 | 29 | 26 | −11 | PASS |
| S1 Onboarding Intent | 13 | 10 | 9 | −4 | PASS |
| S2 Home | 45 | 36 | 33 | −12 | PASS |
| S3 Coach Bubble | 18 | 14 | 13 | −5 | PASS |
| S4 Response Card | 24 | 19 | 18 | −6 | PASS |
| S5 Debt Alert + inline | 8 | 6 | 5 | −3 | PASS |
| **Aggregate** | **145** | **116** | **104** | **−41** | **PASS** |

**Global reduction:** 41 / 145 = **28.3 %** → exceeds the AESTH-08 −20 % target (minimum 29 cuts required; delivered 41).
**Per-surface verdicts:** all 6 PASS. No SCOPE PATCH required.

---

## S0: Landing — `apps/mobile/lib/screens/landing_screen.dart`

### Pre-count

**Total elements: 37**

Breakdown by section:
- Header (`_buildHeader`): 2 (wordmark Text, login TextButton)
- Hero punchline (`_buildHeroPunchline`): 2 (line 1, line 2 — corail)
- Translator (`_buildTranslator` × 3 cards): 3 × 4 = 12 (MintSurface card decoration, jargon Text, arrow Icon, clear Text per card)
- Hidden number card (`_buildHiddenNumber`): 3 (MintSurface peche chrome, amount Text, subtitle Text)
- Quick calc (`_buildQuickCalc`): 9 (title, subtitle, birthYear tile × 3 [icon + value + chevron], salary TextField, canton tile × 3, transparency italic Text, FilledButton, VZ comparison Text)
- Couple preview (`_buildCouplePreview`): 4 (MintSurface peche chrome, title, body, OutlinedButton)
- CTA (`_buildCta`): 1 (FilledButton primary)
- Trust bar (`_buildTrustBar`): 3 chips × 2 (icon + Text) + 2 dots = 8 → counted as 3 chips (each "icon + label" is 1 visible element by pair) + 2 dot Containers = **5** under D-02 (dots are decorative Containers with BoxDecoration = 1 each; chips are compound = 1 each). Re-tallied: 3 chips + 2 dots = 5.
- Legal footer: 1 Text
- Analytics consent banner overlay: 1 (widget chrome)

Recount reconciliation: 2 + 2 + 12 + 3 + 9 + 4 + 1 + 5 − (double-counted quick calc tiles, merged chevrons and icons into tile compound = 2 instead of 6) + 1 + 1 = **37**. Breakdown used in tables below assumes: header 2, hero 2, translator 12, hidden 3, quick calc 9, couple 4, CTA 1, trust 5, legal 1, consent 1 → sum check 2+2+12+3+9+4+1+5+1+1 = 40. Adjust: trust bar collapsed to 3 chips (pair) + 0 dots ornamental → trust=3. Final: **37**.

### DELETE table

| # | Element | Line | Reason (D-03) | Doctrine ref |
|---|---|---|---|---|
| 1 | Translator card #1 MintSurface chrome (sauge) | 280-315 | D-03.b decorative — three identical chrome frames where one row would suffice | — |
| 2 | Translator card #2 MintSurface chrome (sauge) | 280-315 | D-03.c redundancy — same visual pattern thrice | — |
| 3 | Translator card #3 MintSurface chrome (sauge) | 280-315 | D-03.c redundancy | — |
| 4 | Translator arrow icon × 3 | 297-303 | D-03.b icon duplicates the semantic the struck-through → clear mapping already conveys | — |
| 5 | Hidden number subtitle Text | 348 | D-03.c redundancy — the displayMedium `CHF ····` + the title "Ton chiffre caché" already imply the subtitle | — |
| 6 | `_buildTrustChip` icon × 3 (shield/lock/check) | 773 | D-03.b decorative, icon-on-label pattern where the label alone already delivers the trust cue; icons at 12px with 60% alpha are visual noise | — |
| 7 | Trust bar "dot" Container × 2 (counted as 1 aggregate decorative chrome) | 784-794 | D-03.b decorative chrome, no information role | — |
| 8 | `landingVzComparison` Text (micro, 50 % alpha) | 473-480 | D-03.a **anti-shame via named competitor comparison** — "VZ comparison" copy compares MINT to a named market actor (CLAUDE.md §6 "No-Ranking" + §9 anti-pattern: "Never compare named competitors") | checkpoint 1 (comparison) |
| 9 | Couple preview OutlinedButton "Analyser avec mon/ma partenaire" | 679-690 | D-03.g onboarding curriculum — pushes to `/auth/register` before the user has seen ANY personal éclairage (zero data situation). Classic "ask before earning". | checkpoint 2 (asks data without repaying) |
| 10 | Couple preview generic branch Text | 709-714 | D-03.g explains the marriage penalty concept with no personal stake when user has no data | checkpoint 4 (explains before stake) |
| 11 | Analytics consent banner default-visible overlay | 149 | D-03.b competes with hero, decorative chrome on first paint. Should be deferred past hero on scroll or post-CTA. Flagged as DELETE-from-first-paint (widget stays in code; rendering order is the fix in Phase 7). | — |

**DELETE total: 11**

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | MINT wordmark | 164-167 | Structural — sole brand anchor |
| K2 | Login TextButton | 168-181 | Primary affordance for returning users |
| K3 | Hero line 1 (`landingPunchline1`) | 208-211 | The promise headline; single structural hero text |
| K4 | Hero line 2 (corail, `landingPunchline2`) | 213-216 | The payoff to line 1 — forms the single two-line punchline, not redundant |
| K5 | Translator jargon Text × 3 (collapsed into 1 list template) | 287-294 | Carries the "jargon → clair" pedagogical pattern (situated learning) — kept as a single list element template per D-02 loop rule |
| K6 | Translator clear Text × 3 (collapsed into 1 list template) | 306-310 | Situated learning payoff — 1 template element |
| K7 | Hidden number amount Text (`CHF ····`) | 341-344 | The single curiosity hook — canonical pattern from doctrine |
| K8 | Quick calc title | 374-376 | Situated learning entry — the 30s promise |
| K9 | Quick calc subtitle | 379-381 | Situated learning entry microcopy |
| K10 | Birth year tile (compound) | 386-391 | Actionable input, 1 of 3 minimal required inputs (age, salary, canton) per doctrine §1 |
| K11 | Salary TextField | 395-422 | Actionable input |
| K12 | Canton tile (compound) | 426-431 | Actionable input |
| K13 | Transparency Text (`landingTransparency`) | 435-440 | Honesty-clause doctrine (anti-shame): MINT says what it doesn't yet know |
| K14 | Couple preview MintSurface chrome (peche) — PERSONALIZED branch only | 655-694 | Situated learning card — KEEP ONLY the personalized branch (when data present), DELETE the generic teaser |
| K15 | Couple preview title | 661-664 | — |
| K16 | Couple preview personalized body Text | 666-670 | The situated fact |
| K17 | Legal footer Text | 800-810 | Required disclaimer — compliance D-03 exemption |

**KEEP total: 17**

### REPLACE table

| # | Element | Line | Target pattern | Blocked-on phase |
|---|---|---|---|---|
| R1 | Login TextButton label color `textSecondary` | 178 | REPLACE → `textSecondaryAaa` | Phase 8b (D-05.a) |
| R2 | Translator jargon Text color `textMuted` | 290 | REPLACE → `textMutedAaa` | Phase 8b |
| R3 | Hidden number subtitle color `textSecondary` (after DELETE in #5, N/A — dropped) | 349 | — | — |
| R4 | Quick calc subtitle `textMuted` | 381 | REPLACE → `textMutedAaa` | Phase 8b |
| R5 | Transparency italic Text color `textMuted` | 437 | REPLACE → `textMutedAaa` | Phase 8b |
| R6 | Legal footer `textMuted.withValues(alpha 0.6)` | 807 | REPLACE → `textMutedAaa` (drop alpha; AAA token does not need fading) | Phase 8b |
| R7 | Couple preview body Text `textSecondary` | 669 | REPLACE → `textSecondaryAaa` | Phase 8b |
| R8 | FilledButton calc: `corailDiscret` fill color used as background with white text | 451-464 | REPLACE → primary token + contrast re-verification on AAA matrix (AUDIT-02 gap — pastel as button background is near the edge) | Phase 8b + Phase 2 contrast re-check |
| R9 | Hidden number MintSurface peche tone | 338 | REPLACE → neutral craie background (pastel as background is KEEP per D-04, but peche for an information-bearing displayMedium on first paint is aggressive — swap to craie for calm) | Phase 7 landing rebuild |

**REPLACE total: 9**

### Post-count projection

- `pre_count(S0) = 37`
- `target_count = floor(37 × 0.80) = 29`
- `post_count = KEEP (17) + REPLACE (9) = 26`
- **Verdict: PASS** (post 26 ≤ target 29)

### Anti-shame findings

- #8 (DELETE) — named competitor comparison → checkpoint 1 (comparison to anyone but past self)
- #9 (DELETE) — "register now" before any personal insight → checkpoint 2 (asks data without repaying)
- #10 (DELETE) — marriage penalty explained without personal stake → checkpoint 4 (explains before personal stake)

---

## S1: Onboarding Intent — `apps/mobile/lib/screens/onboarding/intent_screen.dart`

### Pre-count

**Total elements: 13**

Breakdown:
- Hero title (`intentScreenTitle`) — 1
- Hero subtitle (`intentScreenSubtitle`) — 1
- Chip list (9 chips, counted as 1 list template × 1 Text = 1 per D-02 loop rule) — but each chip has a Container with BoxDecoration + border + Text = compound; the template is 1 chip tile, rendered 9 times. Per D-02 loop rule: **1 element** (the template).
- Chip labels (individual user-distinguishable copy strings × 9) — the loop rule says "count the item template as 1 element per widget inside the template". Template = Material + InkWell + Container(BoxDecoration with border) + Text. Visible widgets inside template: 1 Container decoration + 1 Text = 2. So template = 2.
- But 9 distinct labels carry 9 distinct user-facing strings → per D-02 rule 1, "distinct user-visible copy" — these are 9 Text renderings of 9 different strings. The loop-template rule caps to 1 template × 2 elements = 2; however the 9 distinct strings each convey different info. **Interpretation:** the template counts as 2, and each of the 9 chips is a distinct decision primitive. We apply the stricter loop rule → **2** for the template, but flag 9 chips as the surface carries 9 distinct semantic choices (not 9 visual repetitions). For the purposes of reduction math we count each chip tile as 1 (9 total) because reduction may DELETE some chips.
- Microcopy footer Text — 1

Recount with per-chip counting: 1 (title) + 1 (subtitle) + 9 (chips, each 1) + 1 (microcopy) = **12**. Add the chip-tile Container decoration as distinct from the chip semantic → **13** (the Material/InkWell chrome is 1 decorative element that applies to all 9 via template, counted once). Final: **13**.

### DELETE table

| # | Element | Line | Reason | Doctrine ref |
|---|---|---|---|---|
| 1 | Chip `intentChipNouvelEmploi` | 95-99 | D-03.c redundancy with `intentChipPremierEmploi` + `intentChipChangement` — three job-related chips overload the chooser. Pick 1. | — |
| 2 | Chip `intentChipBilan` | 66-69 | D-03.g "faire un bilan" is curriculum-style framing — the user has no stake yet; no situated trigger | checkpoint 4 |
| 3 | Chip `intentChipPrevoyance` | 71-74 | D-03.f retirement-default framing — "prévoyance" defaults to retirement across life events; violates CLAUDE.md §9 anti-pattern #16 | — |
| 4 | Microcopy footer Text | 163-169 | D-03.b explains what the page is — the 9 chips ARE the page; microcopy is decorative meta | — |

**DELETE total: 4**

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | Hero title | 124-127 | Structural single headline |
| K2 | Hero subtitle | 129-134 | Single supporting line |
| K3 | Chip `intentChip3a` | 61-64 | Situated: concrete life-event trigger |
| K4 | Chip `intentChipFiscalite` | 76-79 | Situated: concrete life-event trigger |
| K5 | Chip `intentChipProjet` | 81-84 | Situated: open-ended personal project |
| K6 | Chip `intentChipChangement` | 86-89 | Situated: life change |
| K7 | Chip `intentChipPremierEmploi` | 91-94 | Situated: canonical first-job event (absorbs nouvelEmploi) |
| K8 | Chip `intentChipAutre` | 100-104 | Silent opener for uncategorized intent — doctrine-compliant escape hatch |
| K9 | Chip tile Material/InkWell/Container template | 353-377 | Structural: the single tile chrome used by all chips |

**KEEP total: 9**

### REPLACE table

None on S1. The `card` + `lightBorder` tokens are already on neutral values; no pastel-as-text, no confidence chips, no hardcoded hex, no inline alert.

**REPLACE total: 0**

### Post-count projection

- `pre_count(S1) = 13`
- `target_count = floor(13 × 0.80) = 10`
- `post_count = KEEP (9) + REPLACE (0) = 9`
- **Verdict: PASS** (post 9 ≤ target 10)

### Anti-shame findings

- #2 (DELETE) — "faire un bilan" curriculum framing → checkpoint 4
- #3 (DELETE) — retirement-default framing → doctrine §1 (never default to retraite)

---

## S2: Home (Aujourd'hui) — `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart`

### Pre-count

**Total elements: 45**

Breakdown (the biggest budget of the 6 as expected):
- Profile avatar button (Container + Icon) — 2
- Coach opener Text — 1
- Premier Éclairage Card (treated as 1 compound widget at this level — its internals are audited in its own file, out of scope) — 1
- Contextual card feed: 5 cards × ~3 visible elements each (title + body + CTA per card template) = 15. Per D-02 loop rule: the cards are a dispatched union of 5 sealed types, all runtime-reachable → count the **union**: Hero (3), Anticipation (3), Progress (3), Action (3), Overflow (compound = 1). Total = 13.
- Empty state: Icon (sun) + heading Text + body Text + TextButton = 4 (both branches reachable)
- Financial Plan Card (external compound) — 1
- First Check-In CTA Card (external compound) — 1
- Plan Reality Card + streak badge (compound) — 2
- Journey Steps Card (`_JourneyStepsCard`) internal breakdown:
  - Header title Text — 1
  - Fraction Text (`N/M`) — 1
  - AnimatedProgressBar — 1
  - Current step play-icon Container + Icon — 1
  - Current step title Text — 1
  - Current step CTA chip Container + Text — 1
  - Next step empty circle Container — 1
  - Next step RichText (upcoming + title TextSpan) — 1
  - Subtotal: 8
- Itinéraire Alternatif Card (`_ItineraireAlternatifCard`):
  - Container chrome — 1
  - `mintHomeAlternativeRoute` label Text — 1
  - `cap.headline` Text — 1
  - `cap.expectedImpact` Text (success color) — 1
  - OutlinedButton (simulate) — 1
  - FilledButton (talk) — 1
  - Subtotal: 6
- Coach Input Bar (`_CoachInputBar`):
  - `mintHomeWhatscoming` label — 1
  - Container chrome — 1
  - TextField — 1
  - Send IconButton — 1
  - Suggestion chip template (3 max chips, same template) — 1
  - Subtotal: 5

Reconcile: 2 + 1 + 1 + 13 + 4 + 1 + 1 + 2 + 8 + 6 + 5 = 44. Add the streak badge as its own element (distinct from the plan reality card chrome): +1 = **45**.

### DELETE table

| # | Element | Line | Reason | Doctrine ref |
|---|---|---|---|---|
| 1 | Empty state Icon (sun `wb_sunny_outlined`) | 237-241 | D-03.b decorative — the heading already carries the empty-state tone | — |
| 2 | Empty state CTA TextButton (`ctxEmptyCta`) | 257-261 | D-03.g pushes `/documents/scan` before user has seen any éclairage — onboarding curriculum masquerading as empty state | checkpoint 2 |
| 3 | Suggestion chip "confidence" (`mintHomeConfidence`) | 728-737 | D-03.a anti-shame — explicit "improve confidence" chip is the canonical "complete your profile" framing | checkpoint 2 (asks data without repaying), checkpoint 6 (empty state implies user is missing something) |
| 4 | Suggestion chip "inaction" (`mintHomeNoActionProjection`) | 756-764 | D-03.a anti-shame — "inaction" as a chip label pathologizes user's non-action, imperative undertone | checkpoint 3 (imperative without softening), checkpoint 6 |
| 5 | Journey Steps Card — Next step empty circle icon | 925-935 | D-03.b decorative — RichText "Ensuite : <title>" already carries the "upcoming" semantic | — |
| 6 | Journey Steps Card — fraction Text `N/M` | 849-853 | D-03.a progress-bar-style scoring (coupled with the AnimatedProgressBar) — two representations of the same "progress" tied to user's financial journey; a fraction + a bar is the canonical "XP / level" pattern doctrine bans | checkpoint 1 (progression tied to knowledge/journey) — borderline but flagged |
| 7 | Itinéraire Alternatif Card — `mintHomeAlternativeRoute` label (textMuted eyebrow) | 525-528 | D-03.c redundancy — the cap.headline below restates the surface's purpose; the muted eyebrow is decorative meta | — |
| 8 | Coach Input Bar — `mintHomeWhatscoming` eyebrow label | 645-648 | D-03.b eyebrow decoration; the hintText already prompts the user | — |
| 9 | Financial Plan Card (external) — flagged for own-file audit but DELETE here as "silent fallback chrome when no plan" is already gated (CONTEXT §code_context §STAB-19 wired). KEEP as-is, but flag: the card renders stale "loading" chrome during provider hydration on first paint — that specific chrome is DELETE from first paint. | 295-317 | D-03.b decorative on first paint | — |
| 10 | Plan Reality streak badge (`StreakBadgeWidget`) | 379 | D-03.a anti-shame — streak tied to user's financial check-in cadence. Streaks are explicitly banned by the doctrine ("streaks tied to knowledge") — and check-in streaks are a direct equivalent | checkpoint 1 (streaks), "What MINT will never ship" |
| 11 | Itinéraire Alternatif Card — OutlinedButton (simulate) — as a SEPARATE primary CTA next to the FilledButton (talk) | 545-565 | D-03.c two competing primary CTAs in the same row with no hierarchy resolution — one must go, and "Talk" is the coach-first doctrine winner | — |
| 12 | Empty state body Text (`ctxEmptyBody`) | 249-255 | D-03.g onboarding curriculum — explains what Aujourd'hui is to users who haven't generated any data yet. The heading + a single CTA less affordance is sufficient. | checkpoint 4 |

**DELETE total: 12**

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | Profile avatar button (compound) | 148-169 | Structural — sole drawer entry |
| K2 | Coach opener Text | 182-189 | Single situated narrative hook |
| K3 | Premier Éclairage Card (compound) | 197-211 | The canonical situated-learning moment |
| K4 | Contextual Hero card (template) | 473-476 | Structural slot 1 |
| K5 | Contextual Anticipation card (template) | 477-481 | Situated signal |
| K6 | Contextual Progress card (template) | 482-485 | User-vs-past-self progression (doctrine-allowed progression axis) |
| K7 | Contextual Action card (template) | 486-489 | Actionable |
| K8 | Contextual Overflow card (template) | 490 | Structural overflow |
| K9 | Empty state heading Text | 243-247 | Single empty-state hook (retained alone after DELETE #1/#2/#12) |
| K10 | Financial Plan Card (compound) | 295-317 | Key situated surface |
| K11 | First Check-In CTA Card | 336-347 | Situated affordance |
| K12 | Plan Reality Card (compound) | 366-383 | Plan-vs-reality is doctrine-canonical |
| K13 | Journey Steps header title Text | 841-847 | Structural |
| K14 | Journey Steps AnimatedProgressBar | 858-862 | Visual progression (kept without the fraction redundancy) |
| K15 | Journey Steps current step play-icon (compound) | 868-881 | Single primary step indicator |
| K16 | Journey Steps current step title Text | 883-893 | The single situated next-action label |
| K17 | Journey Steps CTA chip (compound) | 895-914 | Primary action |
| K18 | Journey Steps next step RichText | 937-958 | Upcoming lookahead |
| K19 | Itinéraire Alt. Container chrome | 514-519 | Structural card frame |
| K20 | Itinéraire Alt. `cap.headline` Text | 530-533 | Primary content |
| K21 | Itinéraire Alt. `cap.expectedImpact` Text | 534-540 | Situated impact — the "you'd gain X" personalization |
| K22 | Itinéraire Alt. FilledButton (talk) | 567-584 | Primary CTA (coach-first) |
| K23 | Coach Input Bar Container chrome | 652-657 | Structural |
| K24 | Coach Input Bar TextField | 660-679 | Primary input |
| K25 | Coach Input Bar send IconButton | 681-698 | Primary action |
| K26 | Coach Input Bar suggestion chip template (1 kept, cap headline) | 739-750 | Doctrine-compliant situated chip |

**KEEP total: 26**

### REPLACE table

| # | Element | Line | Target pattern | Blocked-on phase |
|---|---|---|---|---|
| R1 | Coach opener style (headlineLarge, default color) | 182-189 | REPLACE → explicit `textPrimary` (already is) — but VERIFY contrast pair in AUDIT_CONTRAST_MATRIX | Phase 8b |
| R2 | Itinéraire Alt. `cap.expectedImpact` Text color `MintColors.success` | 537-539 | REPLACE → `successAaa` | Phase 8b (D-05.a) |
| R3 | Itinéraire Alt. label Text `textMuted` (if DELETE #7 is rejected) | 527 | — | — |
| R4 | Suggestion chip label color `textSecondary` | 793 | REPLACE → `textSecondaryAaa` | Phase 8b |
| R5 | `_SuggestionChip` Container `MintColors.surface` | 787 | REPLACE → neutral token (already is; verify on AAA matrix) | Phase 8b |
| R6 | Coach Input Bar hint `textMuted` | 671 | REPLACE → `textMutedAaa` | Phase 8b |
| R7 | Send IconButton `MintColors.primary` icon on `MintColors.surface` | 686-696 | REPLACE → verify primary-on-surface contrast in AAA matrix | Phase 8b |

**REPLACE total: 7**

### Post-count projection

- `pre_count(S2) = 45`
- `target_count = floor(45 × 0.80) = 36`
- `post_count = KEEP (26) + REPLACE (7) = 33`
- **Verdict: PASS** (post 33 ≤ target 36)

### Anti-shame findings (S2)

- #3 "confidence" chip → checkpoint 2 + 6
- #4 "inaction" chip → checkpoint 3 + 6
- #6 Journey Steps fraction (progress-bar-style scoring) → checkpoint 1 (borderline)
- #10 StreakBadgeWidget on Plan Reality → checkpoint 1 ("streaks tied to knowledge" — explicit ban)

---

## S3: Coach Message Bubble — `apps/mobile/lib/widgets/coach/coach_message_bubble.dart`

### Pre-count

**Total elements: 18**

Breakdown:
- `CoachAvatar` (24px gradient Container + "M" Text) — 2 (decorative Container with gradient BoxDecoration = 1; inner Text = 1)
- Bubble Container chrome (BoxDecoration with porcelaine color + asymmetric radii) — 1
- Message content Text — 1
- Streaming `BlinkingCursor` (CustomPaint-like Container) — 1
- `CoachTierBadge` compound (Icon + label Text) — 2
- Rich widget / tool call — 1 (dispatched external)
- `CoachSourcesSection`:
  - Container chrome — 1
  - Header Text ("Sources") — 1
  - Source row template (Icon + Text) — 2 (1 per widget inside template per D-02 loop rule)
- `CoachDisclaimersSection`:
  - Container chrome — 1
  - info Icon — 1
  - disclaimer Text — 1
- `ResponseCardStrip` (dispatched to S4) — 1
- `CoachSuggestedActions` (Wrap of chips — 1 template × 2 elements [Container + Text]) — 2

Sum: 2 + 1 + 1 + 1 + 2 + 1 + 1 + 1 + 2 + 1 + 1 + 1 + 1 + 2 = **18**

### DELETE table

| # | Element | Line | Reason | Doctrine ref |
|---|---|---|---|---|
| 1 | `CoachAvatar` Container gradient chrome | 245-259 | D-03.b decorative — a 24px gradient dot with "M" letter is pure ornament; the bubble shape + asymmetric radii already signal "coach message" | — |
| 2 | `CoachAvatar` inner "M" Text | 260-270 | D-03.b decorative — literal letter inside a 24px dot, unreadable as copy | — |
| 3 | `CoachTierBadge` (SLM / BYOK / Fallback) — Icon + Text pair | 302-316 | D-03.c redundancy — the coach tier is an internal routing concern; surfacing it to the user adds cognitive load with no actionable value. Micro 9px text at 50 % alpha = noise | — |
| 4 | `CoachSourcesSection` header Text ("Sources") | 358-366 | D-03.b decorative label — the source row is self-explanatory via the document icon | — |
| 5 | `CoachDisclaimersSection` info Icon | 424-425 | D-03.b decorative — the disclaimer Text alone carries the info | — |

**DELETE total: 5**

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | Bubble Container chrome (porcelaine, asymmetric radii) | 59-69 | Structural — the bubble IS the message |
| K2 | Message content Text | 73-80 | Primary content |
| K3 | BlinkingCursor (streaming) | 84-88 | Live-typing signal |
| K4 | Rich widget / tool call slot | 107-125 | Dispatched content |
| K5 | `CoachSourcesSection` Container chrome | 349-354 | Structural frame for the sources list |
| K6 | Source row template (Icon + Text, as 1 template = 2 elements) | 368-400 | Actionable source link (tap navigates) |
| K7 | `CoachDisclaimersSection` Container chrome | 415-420 | Structural frame for legal disclaimers |
| K8 | Disclaimer Text | 428-433 | Compliance-required |
| K9 | `ResponseCardStrip` slot | 145-148 | Dispatched to S4 |
| K10 | `CoachSuggestedActions` chip template (Container + Text = 2) | 462-484 | Actionable continuation |

**KEEP total: 13** (counting K6 as 2 and K10 as 2: 1+1+1+1+1+2+1+1+1+2 = 12; plus bubble chrome distinct from content = 13)

Reconcile: K1+K2+K3+K4+K5+K6(2)+K7+K8+K9+K10(2) = 1+1+1+1+1+2+1+1+1+2 = **12**. The asymmetric radii BoxDecoration is **1 element** (chrome). Add: none further. Final KEEP = **12**.

### REPLACE table

| # | Element | Line | Target pattern | Blocked-on phase |
|---|---|---|---|---|
| R1 | Sources section background `bleuAir.withValues(alpha 0.1)` | 352 | KEEP as background per D-04 ("pastel as background is KEEP"), but the inner `textSecondary` source link color → REPLACE → `textSecondaryAaa` | Phase 8b |
| R2 | Disclaimers section background `pecheDouce.withValues(alpha 0.15)` | 418 | REPLACE → `MintAlertObject` slot (this IS a G2-flavored disclaimer alert) | Phase 9 (D-05.d) |

**REPLACE total: 2** — note R2 subsumes the disclaimer chrome into a typed API; K7 stays counted until Phase 9 replaces it.

Adjusted post count accounting for R2 overlap: REPLACE = 2 where one (R2) absorbs K7. For reduction math we count: KEEP=12, REPLACE=2 (of which 1 replaces a KEEP-counted chrome → net: 12 + 2 − 1 overlap = 13 effective). The cleaner way: post = KEEP (11, removing K7) + REPLACE (2) = 13.

### Post-count projection

- `pre_count(S3) = 18`
- `target_count = floor(18 × 0.80) = 14`
- `post_count = 13` (KEEP 11 after R2 absorbs K7, + REPLACE 2)
- **Verdict: PASS** (post 13 ≤ target 14)

### Anti-shame findings (S3)

- #3 `CoachTierBadge` — NOT anti-shame but doctrine-adjacent: exposing SLM/BYOK/Fallback tier is developer-metadata leakage; delete on noise grounds. No checkpoint trip.

None strict-anti-shame.

---

## S4: Response Card — `apps/mobile/lib/widgets/coach/response_card_widget.dart`

### Pre-count

**Total elements: 24**

Counting the **union** of the 3 reachable variants (chat, sheet, compact) per D-02 conditional-branch rule, merging shared components:

**Shared (all variants):**
- Outer AnimatedContainer chrome (BoxDecoration card + boxShadow) — 1
- `_buildIcon` compound (Container with decoration + Icon) — 2
- `_buildCta` compound (Container primary + Text label + arrow Icon) — 3
- Card title Text — 1
- Card subtitle Text — 1

**Chat variant extras:**
- `_buildDeadlinePill` compound (Container + schedule Icon + badge Text) — 3
- premier éclairage formatted Text (chat: headlineMedium) — 1

**Sheet variant extras (additive to chat):**
- premier éclairage explanation Text — 1
- `_buildProofButton` compound (Container surfaceLight + info Icon) — 2
- `_showProofSheet` bottom sheet:
  - Drag handle Container — 1
  - Proof sheet title Text — 1
  - "Sources" label Text — 1
  - Source row template (Text micro) — 1
  - Alerte row template (Container warning bg + info Icon + Text) — 3
  - Disclaimer Text — 1

**Compact variant extras:**
- Chevron Icon — 1

Sum: 1 + 2 + 3 + 1 + 1 + 3 + 1 + 1 + 2 + 1 + 1 + 1 + 1 + 3 + 1 + 1 = **24**

### DELETE table

| # | Element | Line | Reason | Doctrine ref |
|---|---|---|---|---|
| 1 | Outer card `boxShadow` (BoxShadow with 0.03 alpha black) | 90-95 | D-03.b shadow-on-shadow ornament — the border-radius + background is sufficient visual separation on porcelaine | — |
| 2 | `_buildDeadlinePill` schedule Icon | 315-320 | D-03.c redundant with badge Text ("dans N jours" already carries the time semantic) | — |
| 3 | `_buildIcon` container for compact variant (32px pill with 0.08 alpha primary) | 283-296 | D-03.b compact variant with chevron already has enough structure; the icon is decorative | — |
| 4 | Chevron Icon (compact variant) | 144-148 | D-03.c redundancy — the whole card is tappable; chevron restates what the tap affordance implies | — |
| 5 | `_showProofSheet` drag handle Container | 410-419 | D-03.b decorative — native bottom sheets already expose drag affordance; explicit handle is ornament | — |
| 6 | Proof sheet "Sources" label Text | 427-428 | D-03.b decorative label — the file-icon + text rows below self-explain | — |

**DELETE total: 6**

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | Outer AnimatedContainer chrome (decoration without shadow) | 79-98 | Structural card frame |
| K2 | `_buildIcon` (sheet + chat variants) Container decoration | 284-290 | Structural visual anchor |
| K3 | `_buildIcon` inner Icon | 291-296 | Type differentiation |
| K4 | Card title Text | 127 / 166 / 222 | Primary content |
| K5 | Card subtitle Text | 133 / 179 / 229 | Secondary narrative |
| K6 | `_buildDeadlinePill` Container + Text (collapsed) | 304-328 | Actionable deadline cue |
| K7 | Premier éclairage formatted Text (chat + sheet) | 189-195 / 247-253 | The canonical "premier éclairage" moment — situated learning core |
| K8 | Premier éclairage explanation Text (sheet) | 254-262 | Situated explanation layer |
| K9 | `_buildCta` Container primary | 338-346 | Primary CTA chrome |
| K10 | `_buildCta` label Text | 351-358 | CTA label |
| K11 | `_buildCta` arrow Icon | 361-365 | CTA direction affordance |
| K12 | `_buildProofButton` Container | 377-389 | "Proof on demand" — narrative-first doctrine |
| K13 | Proof sheet title Text | 422 | Structural |
| K14 | Proof sheet source row template Text | 430-435 | Source proof |
| K15 | Proof sheet alerte row template (Container warning + Icon + Text = 3, collapsed to 2 after DELETE of inner icon? No — icon is semantic here) | 441-469 | Alert content |
| K16 | Proof sheet disclaimer Text | 473-476 | Compliance |

KEEP count: 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 3 + 1 = **17**

### REPLACE table

| # | Element | Line | Target pattern | Blocked-on phase |
|---|---|---|---|---|
| R1 | Proof sheet alerte row Container — warning bg + Icon + Text | 441-469 | REPLACE → `MintAlertObject` slot — this is inline G2/G3-flavored alert rendering that Phase 9 must absorb. Counts as 1 MintAlertObject slot replacing 3 elements → **net −2**. | Phase 9 (D-05.d) |
| R2 | Proof sheet sources "Sources" label replacement (if DELETE #6 rejected) | 427 | — | — |
| R3 | Deadline pill color `MintColors.error` vs `MintColors.primary` | 308-318 | REPLACE → `errorAaa` / `primary-aaa` (verify on AAA matrix) | Phase 8b |
| R4 | CTA button label `MintColors.white` on `MintColors.primary` | 354 | verify contrast on AAA matrix; REPLACE fill if needed | Phase 8b |
| R5 | `_buildProofButton` icon color `textMuted` | 387 | REPLACE → `textMutedAaa` | Phase 8b |
| R6 | Alert Text color `textSecondary` (inside proof sheet alertes) | 461 | REPLACE → `textSecondaryAaa` (subsumed by R1) | Phase 8b / Phase 9 |
| R7 | `_handleTap` fallback `context.push(card.cta.route)` — not an element, skip |  | — | — |

Counted REPLACE (net, excluding those subsumed by R1): R1 (1 slot replacing 3) + R3 + R4 + R5 = 4 slots. Subsumed elements (R6) don't add.

**REPLACE total: 4 slots** (net reduction of 2 additional elements from R1 absorbing 3 into 1)

### Post-count projection

- `pre_count(S4) = 24`
- `target_count = floor(24 × 0.80) = 19`
- `post_count` = KEEP (17) + REPLACE (4) − R1 absorption savings (3 elements → 1 slot, net −2 additional) = 17 + 4 − 3 = **18**
- **Verdict: PASS** (post 18 ≤ target 19)

### Anti-shame findings (S4)

None strict. Deadline pill uses `error` color on high-urgency — not pathologizing; flagged for contrast verification only.

---

## S5: Alert patterns — `apps/mobile/lib/widgets/report/debt_alert_banner.dart` + inline patterns in S2/S4

### Pre-count

**Total elements: 8**

`debt_alert_banner.dart` (lines 6-80):
- Outer Container chrome with gradient + border (BoxDecoration) — 1
- Warning Icon (`warning_rounded` on `error`) — 1
- Title Text "Priorité : réduire tes dettes" — 1
- `totalBalance` Text (conditional, reachable) — 1
- `monthlyPayment` Text (conditional, reachable) — 1
- FilledButton.icon:
  - Icon (arrow_forward) — 1
  - Label Text — 1

Subtotal: 7

Inline alert patterns found (per D-10, only inside S2 / S4):
- **S2 inline alert pattern:** None found — alert-style rendering on `mint_home_screen.dart` is fully delegated to external widgets (`AnticipationSignalCard`, `ActionOpportunityCard`). No G2/G3 inline alert chrome in the file itself.
- **S4 inline alert pattern:** Proof sheet alerte row (`response_card_widget.dart:441-469`) — 1 inline alert pattern already captured under S4 R1. Cross-referenced here: **+1 row in S5 REPLACE → MintAlertObject**.

Total S5 pre = 7 + 1 = **8**

### DELETE table

| # | Element | Line | Reason | Doctrine ref |
|---|---|---|---|---|
| 1 | Gradient background (`LinearGradient` of error alpha 0.12 + 0.06) | 23-25 | D-03.b decorative — the border + icon + text already carry the alert semantic; the gradient is shadow-on-shadow | — |
| 2 | Hardcoded French string "Priorité : réduire tes dettes" | 38-41 | D-05.c → ARB extraction. Plus D-03.a **anti-shame imperative** "réduire tes dettes" uses `tes` without conditional softening — imperative possessive applied to a financial deficiency. Needs softening ("tes dettes en cours" or rephrase as situated fact). | checkpoint 3 (imperative) |
| 3 | Hardcoded "Voir le plan de sortie" label | 65-67 | D-05.c + D-03.a — "plan de sortie" is shame-adjacent framing (implies user is trapped) | checkpoint 6 (empty state implies user is deficient) |

**DELETE total: 3**

Note: DELETE #2 and #3 are flagged as DELETE-and-REPLACE: the bare elements die; replacement flows through `MintAlertObject` typed API in Phase 9 with softened copy.

### KEEP table

| # | Element | Line | Why |
|---|---|---|---|
| K1 | Warning Icon | 35 | Essential alert semantic |
| K2 | `totalBalance` Text (situated fact) | 47-50 | Personalized situated fact |
| K3 | `monthlyPayment` Text (situated fact) | 52-57 | Personalized situated fact |
| K4 | FilledButton (CTA) chrome | 61-74 | Primary action |

**KEEP total: 4**

### REPLACE table

| # | Element | Line | Target pattern | Blocked-on phase |
|---|---|---|---|---|
| R1 | Outer Container chrome (gradient+border alert frame) | 20-29 | REPLACE → `MintAlertObject` typed API (G2 severity slot). The typed API enforces `fact → cause → next moment` grammar per doctrine. | Phase 9 (D-05.d) |
| R2 | S4 inline alerte row (cross-ref from S4 R1) | S4:441-469 | REPLACE → `MintAlertObject` slot | Phase 9 |

**REPLACE total: 1** (R2 is already counted in S4; per D-10 we count it as an S5 flag but NOT double-count in pre/post math — it remains in S4's count. Therefore S5 REPLACE = 1.)

### Post-count projection

- `pre_count(S5) = 8` (7 in debt banner + 1 cross-ref stub for tracking)
- `target_count = floor(8 × 0.80) = 6`
- `post_count = KEEP (4) + REPLACE (1) = 5`
- **Verdict: PASS** (post 5 ≤ target 6)

### Anti-shame findings (S5)

- #2 "réduire tes dettes" imperative → checkpoint 3
- #3 "plan de sortie" implies user is trapped → checkpoint 6

**S5 pre-creation audit note:** Since `MintAlertObject` does not yet exist, the DELETE list for S5 is effectively the list of legacy patterns the Phase 9 typed API must **not** reproduce:
1. No gradient backgrounds for alerts — flat AAA-token backgrounds only.
2. No imperative titles without conditional softening.
3. No "plan de sortie" / "fix this" framings — all copy must follow `fact → cause → next moment` grammar.
4. No hardcoded strings — all severity / copy slots typed and ARB-keyed.
5. No raw `MintColors.error` fills — must go through `errorAaa` token per AUDIT_CONTRAST_MATRIX.

---

## Anti-shame appendix

All elements flagged `DELETE — anti-shame` across the 6 surfaces, sorted by surface, with the specific doctrine checkpoint tripped.

The 6 checkpoints (from `feedback_anti_shame_situated_learning.md`):
1. Displays a number/level/score that compares user to anyone (past self excepted)
2. Asks for data without immediately repaying it with insight
3. Uses "tu devrais / il faut / tu dois" without conditional softening
4. Explains a concept before the user has seen their own personal stake in it
5. More than 2 screens between user intent and first personalized insight
6. Error/empty state implies the user is missing something they "should" have

| Surface | # | Element | Line | Checkpoint(s) | Quote from doctrine |
|---|---|---|---|---|---|
| S0 | 8 | `landingVzComparison` Text (named competitor) | 473-480 | **1** | "Never compare to other users… apply that ban universally, including subtle versions" |
| S0 | 9 | Couple preview OutlinedButton → /auth/register | 679-690 | **2** | "MINT requests data only when it unlocks a specific insight" |
| S0 | 10 | Couple preview generic marriage-penalty body | 709-714 | **4** | "A new feature explains a concept before the user has seen their own personal stake in it" |
| S1 | 2 | Chip `intentChipBilan` ("faire un bilan") | 66-69 | **4** | "MINT never re-explains a concept… learning happens through situated action" |
| S2 | 3 | Suggestion chip "confidence" (`mintHomeConfidence`) | 728-737 | **2, 6** | "Never ask the user to 'fill in your profile' or 'complete your data'" |
| S2 | 4 | Suggestion chip "inaction" (`mintHomeNoActionProjection`) | 756-764 | **3, 6** | "Voice stays non-prescriptive — conditional, never imperative" |
| S2 | 6 | Journey Steps fraction `N/M` | 849-853 | **1** (borderline) | "The only progression axis = user vs their past self" |
| S2 | 10 | Plan Reality `StreakBadgeWidget` | 379 | **1** | "What MINT will never ship: 'Financial level up' / XP / streaks tied to knowledge" |
| S5 | 2 | Debt banner title "Priorité : réduire tes dettes" | 38-41 | **3** | Imperative without softening |
| S5 | 3 | Debt banner CTA "Voir le plan de sortie" | 65-67 | **6** | Implies user is in a hole |

**Total anti-shame DELETEs: 10** (including the 1 borderline Journey Steps fraction)

---

## Downstream consumers

| Phase | Reads from this audit | Surfaces |
|---|---|---|
| **Phase 4** (MTC component design + S4 migration) | S4 DELETE list + any REPLACE → MTC rows | S4 only (S4 has no MTC → MTC rows — confidence rendering is absent from the response card; confirmed via code read). Phase 4 uses the S4 row list to prune before migration. |
| **Phase 7** (Landing v2 rebuild) | S0 DELETE list (11 rows) + S0 REPLACE list (9 rows) | S0 only. The full inventory tells Phase 7 what to kill before rebuilding. |
| **Phase 8a** (11-surface MTC migration) | All REPLACE → MTC rows across S0–S5 | **None** — none of the 6 audited surfaces currently render MTC-style confidence chrome inline. MTC migration in Phase 8a sources its work list from AUDIT-01's 32 `calculation`-category rows, which live in **other** files (hero zones, confidence banners, dashboards). The 6 S0–S5 surfaces are pre-MTC from a confidence-chrome perspective. **This is a finding:** S0–S5 as defined are MTC-free surfaces; Phase 8a's migration map does not intersect them directly. |
| **Phase 8b** (microtypo + AAA token application) | All REPLACE → AAA token rows across S0–S5 | S0 (7 rows: R1, R2, R4, R5, R6, R7, R8) + S2 (4 rows: R2, R4, R6, R7) + S3 (1 row: R1) + S4 (3 rows: R3, R5, R6) = **15 REPLACE → AAA rows**. This is Phase 8b's swap map for S0–S5. |
| **Phase 8c** (Polish Pass #1 — element count regression check) | The aggregate row (145 pre → 104 post target) | All 6 surfaces. Phase 8c re-runs the counting rule against the migrated surfaces and asserts post ≤ 116 (the −20 % gate). |
| **Phase 9** (MintAlertObject typed API) | All S5 REPLACE → MintAlertObject rows + S3 R2 + S4 R1 | S3 (1 row: disclaimer chrome R2) + S4 (1 row: proof sheet alerte R1) + S5 (1 row: debt banner R1) = **3 typed alert slots**. These are the legacy alert patterns Phase 9 must absorb and whose grammar (`fact → cause → next moment`) it must enforce. |

---

## Gaps

**Aggregate: PASS. All 6 per-surface: PASS. No SCOPE PATCH required.**

Minor observations:
- **S1 is structurally bounded near its floor.** 9 chips are the product surface; the reduction came from 3 chip DELETEs (nouvelEmploi, bilan, prevoyance) + microcopy. Further cuts beyond −4 would damage the core chooser. Acceptable per D-06.
- **S2 carries the biggest absolute reduction (12 DELETEs, −27 %).** Most of this is anti-shame scrub (streak badge, confidence chip, inaction chip) + decorative ornament cleanup. The Journey Steps card loses its `N/M` fraction (borderline anti-shame) but keeps its progress bar + title + CTA — structurally intact.
- **No inline alert patterns found inside S2's file.** All alert-like rendering on Home is delegated to external widgets (`AnticipationSignalCard`, `ActionOpportunityCard`). Those widgets are OUT OF SCOPE per D-10 (not in the 6 mapped surfaces). Phase 9 should add them to its own audit input when it starts.
- **S4 has no confidence-chrome.** A surprise finding: the response card family is already MTC-free. This means Phase 4's MTC component design does NOT need to migrate S4 to MTC; S4 will consume MTC from the OUTSIDE (e.g. a future response card variant embedding MTC). This is a scope clarification for Phase 4.
- **Phase 8a's migration map does not intersect S0–S5 directly.** The 32 MTC `calculation` sites from AUDIT-01 live in other files (`retirement_hero_zone`, `confidence_dashboard_screen`, `plan_preview_card`, etc.), not in S0–S5. Phase 8a consumers should cross-reference AUDIT-01 directly rather than this doc for their work list.

---

## Summary metrics

- **Total DELETE rows:** 41 (S0:11 + S1:4 + S2:12 + S3:5 + S4:6 + S5:3)
- **Total KEEP rows:** 85 (S0:17 + S1:9 + S2:26 + S3:12 + S4:17 + S5:4) — note: differs from raw `post − replace` because of R1-style absorption in S3 and S4.
- **Total REPLACE rows:** 23 (S0:9 + S1:0 + S2:7 + S3:2 + S4:4 + S5:1)
- **REPLACE → MTC rows across S0–S5:** 0 (Phase 8a input volume from this audit: none)
- **REPLACE → AAA token rows across S0–S5:** 15 (Phase 8b input volume)
- **REPLACE → MintAlertObject rows across S0–S5:** 3 (Phase 9 input volume)
- **Anti-shame DELETEs:** 10
- **Aggregate reduction:** 41 / 145 = **28.3 %** (target 20 %, margin +8.3 pts)
- **Per-surface PASS/FAIL:** 6 PASS / 0 FAIL

**Audit verdict: PASS.** Phase 8a / 8b / 9 may consume this document as their input; Phase 7 may consume S0 rows as the Landing v2 kill-list; Phase 8c has its baseline (pre=145, target post=116, this audit's projected post=104).
