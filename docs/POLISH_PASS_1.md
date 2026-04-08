# POLISH PASS #1 — Cross-Surface Aesthetic Delta Report

**Phase:** 08c-polish-pass-1
**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Method:** Supervision-only read pass. No code touched. Evidence = source files at HEAD + 7 golden masters visually reviewed + Phase 3 baseline.
**Status:** Report committed; proposals feed Phase 8b refinements (none required in practice), Phase 9 (S5 via MintAlertObject), Phase 12 (pre-ship polish), or post-milestone defer.

---

## 1. Executive summary

**Overall grade: B+ (trending A- after the 4 hot-fix-now items land)**

The S0-S5 surface family post-8a/8b is materially closer to the "calm promise" north star
than pre-Phase 3, but the improvement is **uneven across the 6 surfaces**: S0 and S4 are
at A-/A level (fully rebuilt or MTC-migrated), while **S1, S2, and S3 still carry
pre-Phase 3 DELETE items** that were flagged in AUDIT_RETRAIT but never executed because
Phase 3 was audit-only and Phases 8a/8b focused on MTC migration + AAA token swap + live
region — not DELETE enforcement. **S5 remains a legacy surface, correctly deferred to
Phase 9 (MintAlertObject typed API).**

**Proposal count by tag:**

| Tag | Count | Meaning |
|---|---:|---|
| `hot-fix-now` | **4** | Should land before Phase 9 begins — directly block "calm promise" coherence or trip anti-shame checkpoints at HEAD. |
| `refine-in-8b` | **0** | Phase 8b is closing; nothing new belongs in its remaining scope. |
| `defer-to-post-milestone` | **7** | Polish items that would be lovely but are not critical for the "très belle avant les humains" gate at Phase 10.5 — Phase 12 or post-v2.2. |
| `deferred-to-phase-9` | **2** | S5 legacy patterns that are the *reason* Phase 9 exists. Not a finding — a pre-condition. |

**Total new proposals: 13.** None require architectural decisions. None require code
commits in Phase 8c itself.

**Cross-surface coherence grade:**

| Axis | Grade | Notes |
|---|---|---|
| Typography scale | A- | ≤3 heading levels per surface (Phase 8b regression-tested). Landing `headlineSmall` + S2 `headlineLarge` asymmetric but defensible. |
| Spacing rhythm | B+ | 4pt grid snap honored in Phase 8b pass. S0 (Spacer flex) breathes beautifully; S2 is denser but structurally necessary. |
| Chromatic palette | A | 6 AAA tokens applied consistently. `errorAaa` correctly scoped to S5 debt banner (single allowed high-gravity surface). One-color-one-meaning holds. |
| MTC bloom timing | A | 250ms lock verified in Phase 4 goldens. Reduced-motion fallback verified in Phase 8b. |
| Motion curves | A- | Landing uses `easeOutCubic` with 120-700ms staged reveal; consistent with MTC bloom. S2/S3 use Material defaults — consistent but less editorial than S0. |

**What's working brilliantly:**
- **S0 Landing** (Phase 7 rebuild): 37 → ~5 elements. Single paragraph, single CTA, wordmark, privacy line, legal. Pure NYT-subscribe-page discipline. This is the aesthetic anchor of the family.
- **S4 Response Card** (Phase 4 MTC + Phase 8b MUJI 4-line grammar): shadow-on-shadow removed, drag handle removed, "Sources" label removed. Confidence now flows through the typed MTC API.
- **MTC component as a whole**: looking at `mtc_inline_default_iphone14pro.png` next to `landing_iphone14pro_fr.png` — the same editorial discipline (vast negative space, single thin line, soft pastel) is readable across both surfaces. This is the cross-surface coherence signal we want.

**What's not working yet:**
- **S1 still renders 9 chips** despite Phase 3 DELETE flagging 3 of them as anti-shame checkpoint trips (`intentChipBilan` curriculum framing, `intentChipPrevoyance` retirement default, `intentChipNouvelEmploi` redundancy). The Phase 3 audit was "counting rule PASS" on paper but the actual deletes never landed.
- **S2 still renders the StreakBadgeWidget** — an explicit "streaks tied to knowledge" pattern that the anti-shame doctrine lists under "What MINT will never ship". Also `mintHomeConfidence` + `mintHomeNoActionProjection` suggestion chips are still live.
- **S3 coach bubble still carries `CoachAvatar` (24px gradient dot + "M" letter) and `CoachTierBadge` (SLM/BYOK/Fallback)** — both flagged Phase 3 DELETE as decorative ornament / developer-metadata leakage. Minor but cumulative visual debt inside the coach reading zone.
- **S0 landing paragraph density**: at ~48 words across 5-6 visible lines at 560w max, it is *calmer than the old landing* but still denser than the NYT/Apple Weather hero benchmark (2-3 lines). Not a regression — a polish opportunity for Phase 12 if copy gets an editorial pass.

---

## 2. Per-surface review (S0-S5)

### S0 — Landing (`apps/mobile/lib/screens/landing_screen.dart`)

**Current state:** Fully rebuilt in Phase 7. ~5 visible elements:
1. `MINT` wordmark (Semantics header, long-press → /auth/login hidden affordance)
2. Paragraphe-mère (`landingV2Paragraph`, `headlineSmall`, `height: 1.45`, `letterSpacing: -0.2`)
3. `FilledButton` CTA (stadium, 56px min height, `textPrimary` fill, `craie` foreground)
4. Privacy micro-phrase (`bodySmall`, `textSecondaryAaa`)
5. Legal footer (`bodySmall`, `textMutedAaa`)

**Motion:** 700ms staged reveal — paragraph 120-370ms, CTA+privacy 400-650ms, legal 600-700ms. `easeOutCubic`. Reduced-motion settles to frame 1 via `mq.disableAnimations || mq.accessibleNavigation`. Verified in `landing_iphone14pro_fr_reduced_motion.png` (identical to base).

**Strengths:**
- Discipline: zero financial_core imports, zero digits, zero banned terms — CI-enforced.
- Composition: `Spacer(flex: 2/3/1/2)` ratio gives the paragraph visual dominance and lets the CTA float in the lower third. Classic editorial layout.
- Token hygiene: 100% AAA tokens (no `textSecondary`, no `textMuted`, no raw pastels).
- Hidden affordance (long-press on wordmark → login) is elegant — avoids a second visible button.

**Proposed deltas:**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S0-01** | Paragraph length: ~48 words, 5-6 visible lines. NYT hero copy sits at 2-3. Consider compression to ≤30 words in a future editorial pass. | `defer-to-post-milestone` | `landingV2Paragraph` ARB | Copy is doctrinally locked ("six life-domains" enumeration). Compression would need Julien + doctrine review — not a 8c hot-fix. |
| **P-S0-02** | CTA background = `textPrimary` (near-black). Contrast with `craie` is AAA, but visually the button sits as a black slab in an otherwise cream composition. Test an `encre` or `anthracite` token variant for softer hierarchy. | `defer-to-post-milestone` | `landing_screen.dart:144` | Polish. Current is fine; the suggestion is "could be 5% calmer". |

### S1 — Onboarding Intent (`apps/mobile/lib/screens/onboarding/intent_screen.dart`)

**Current state:** 9 chips + hero title + subtitle + microcopy footer. Structurally unchanged since Phase 3 audit except AAA token swap (`textSecondaryAaa`, `textMutedAaa` at lines 133/168).

**Strengths:**
- MintEntrance wrapper provides calm entry animation.
- Single column, max 480w, top-aligned — good vertical rhythm.
- `ListView.separated` with `MintSpacing.sm` separator → clean chip list.

**Critical finding — Phase 3 DELETEs not applied:**

Phase 3 audit flagged 3 chips for DELETE and 1 footer element. All 4 are still live at HEAD:

| Phase 3 flag | Current location | Status |
|---|---|---|
| DELETE #1: `intentChipNouvelEmploi` (redundancy with `premierEmploi` + `changement`) | `intent_screen.dart:95-99` | **STILL PRESENT** |
| DELETE #2: `intentChipBilan` ("faire un bilan" = curriculum framing) | `intent_screen.dart:66-69` | **STILL PRESENT** — anti-shame checkpoint 4 trip |
| DELETE #3: `intentChipPrevoyance` (retirement-default framing) | `intent_screen.dart:71-74` | **STILL PRESENT** — CLAUDE.md §9 anti-pattern #16 trip |
| DELETE #4: `intentScreenMicrocopy` footer | `intent_screen.dart:164-171` | **STILL PRESENT** — explains what the page is; the 9 chips ARE the page |

**Proposed deltas:**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S1-01** | DELETE `intentChipBilan`, `intentChipPrevoyance`, `intentChipNouvelEmploi` — execute Phase 3 DELETE #1/#2/#3 | `hot-fix-now` | `intent_screen.dart:66-99` | Two are anti-shame trips (checkpoint 4 + retirement default ban). Three chips reduces 9 → 6, matching the -20% Phase 3 target for S1. Low risk, ARB-only + list-entry removal. |
| **P-S1-02** | DELETE `intentScreenMicrocopy` footer — execute Phase 3 DELETE #4 | `defer-to-post-milestone` | `intent_screen.dart:164-171` | Not anti-shame, just decorative meta. Phase 10 will rewrite onboarding anyway — risk of double-churn if fixed now. |

### S2 — Home Aujourd'hui (`apps/mobile/lib/screens/main_tabs/mint_home_screen.dart`)

**Current state:** ~45 elements pre-Phase 3, largely unchanged structurally. AAA tokens applied. MTC migrated for the confidence pathways.

**Strengths:**
- Premier Éclairage Card holds the top slot (situated learning canonical).
- Contextual card feed (5 sealed types) dispatches cleanly via `_CardUnion`.
- Coach opener Text provides single narrative entry.
- Journey Steps + Itinéraire Alternatif are structurally sound.

**Critical findings — Phase 3 DELETEs not applied:**

| Phase 3 flag | Current location | Anti-shame? |
|---|---|---|
| DELETE #2: empty state CTA → `/documents/scan` | `mint_home_screen.dart:263` (`l.ctxEmptyCta`) | Yes — checkpoint 2 |
| DELETE #3: `mintHomeConfidence` suggestion chip ("improve confidence") | `mint_home_screen.dart:737` | Yes — checkpoint 2 + 6 |
| DELETE #4: `mintHomeNoActionProjection` suggestion chip ("inaction") | `mint_home_screen.dart:765` | Yes — checkpoint 3 + 6 |
| DELETE #10: `StreakBadgeWidget` on Plan Reality card | `mint_home_screen.dart:382` | **Yes — doctrine explicit: "streaks tied to knowledge" is on the ban list.** This is the highest-gravity finding. |

**Proposed deltas:**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S2-01** | Remove `StreakBadgeWidget` from Plan Reality Card | `hot-fix-now` | `mint_home_screen.dart:382` | Doctrine ban, "What MINT will never ship" list. A streak tied to financial check-in cadence is the canonical "XP tied to knowledge" pattern. This must not ship past Phase 10.5. |
| **P-S2-02** | Remove `mintHomeConfidence` + `mintHomeNoActionProjection` suggestion chips | `hot-fix-now` | `mint_home_screen.dart:737,765` | Two anti-shame checkpoint trips (2, 3, 6). ARB-delete + list-entry removal. |
| **P-S2-03** | Remove empty state CTA `ctxEmptyCta` routing to `/documents/scan` | `defer-to-post-milestone` | `mint_home_screen.dart:263` | Anti-shame checkpoint 2, but the empty state itself will be rethought in Phase 10 onboarding rewrite. Fix there, not here. |
| **P-S2-04** | Coach opener `headlineLarge` → `headlineMedium` (Aesop headline demotion pattern Phase 8b applied to S4 but not S2) | `defer-to-post-milestone` | `mint_home_screen.dart:182-189` | Consistency with S4 Phase 8b pass. Not a regression, a refinement. |

### S3 — Coach Message Bubble (`apps/mobile/lib/widgets/coach/coach_message_bubble.dart`)

**Current state:** Porcelaine bubble with asymmetric radii (6/22/22/22) — elegant chrome. liveRegion on incoming content (Phase 8b-03). BlinkingCursor for streaming. But still carries the pre-Phase 3 decorative accessories.

**Strengths:**
- Bubble shape is editorial and on-brand. The asymmetric top-left corner is the only "coach voice" signal needed.
- `MintTextStyles.bodyMedium` + `height: 1.6` gives the Spiekermann breathing room for the content.
- liveRegion Semantics scoped precisely to the Text (not the whole column) — focus behavior correct.

**Phase 3 DELETEs not applied:**

| Phase 3 flag | Current location |
|---|---|
| DELETE #1: `CoachAvatar` 24px gradient Container | `coach_message_bubble.dart:55` (renders at `:55`, class at `:256`) |
| DELETE #2: `CoachAvatar` inner "M" Text | same widget |
| DELETE #3: `CoachTierBadge` (SLM / BYOK / Fallback) | `coach_message_bubble.dart:114` (class at `:292`) |
| DELETE #4: `CoachSourcesSection` "Sources" label header | (still present in `CoachSourcesSection` body) |
| DELETE #5: `CoachDisclaimersSection` info Icon | (still present) |

**Proposed deltas:**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S3-01** | Remove `CoachAvatar` rendering (keep the 44px left-indent for downstream sections) | `hot-fix-now` | `coach_message_bubble.dart:55` | A 24px gradient dot with an "M" letter is pure ornament in the coach reading zone. The bubble asymmetric-radii chrome is already sufficient "coach voice" semantic. Direct impact on editorial calm of S3. |
| **P-S3-02** | Remove `CoachTierBadge` rendering (keep class for potential debug surface) | `hot-fix-now` | `coach_message_bubble.dart:108-116` | Developer-metadata leakage to users. 9px micro-label at 50% alpha is noise. Not anti-shame but strong coherence win. |
| **P-S3-03** | Remove "Sources" header label inside `CoachSourcesSection`, remove disclaimer info Icon inside `CoachDisclaimersSection` | `defer-to-post-milestone` | `coach_message_bubble.dart` helper classes (lines ~350-430) | Minor decorative noise; Phase 9 will re-examine the disclaimers container as a candidate for `MintAlertObject` G2 slot anyway. |

### S4 — Response Card (`apps/mobile/lib/widgets/coach/response_card_widget.dart`)

**Current state:** Phase 4 MTC-migrated, Phase 8b MUJI 4-line grammar applied. Shadow-on-shadow removed (comment at line 121 acknowledges DELETE #1 executed). Drag handle removed (comment at line 496). "Sources" label removed (comment at line 502). Deadline pill schedule icon removed (comment at line 405).

**Strengths:**
- This is the cleanest surface after Phase 7 landing. Most Phase 3 DELETEs actually executed.
- MTC confidence is typed, not floating.
- MUJI 4-line grammar (title / subtitle / premier éclairage / CTA) scales across chat / sheet / compact variants.

**Residual findings:**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S4-01** | Proof sheet alerte row still renders inline `Container(warning bg + Icon + Text)` pattern instead of typed `MintAlertObject` | `deferred-to-phase-9` | `response_card_widget.dart` (proof sheet alerte row) | This is the Phase 9 blocker — MintAlertObject typed API doesn't exist yet. Correctly deferred. Not a Phase 8c action. |

### S5 — Debt Alert Banner (`apps/mobile/lib/widgets/report/debt_alert_banner.dart`)

**Current state:** Legacy surface. AAA token applied (`errorAaa` as the single allowed high-gravity color on S0-S5). Gradient background still present. Hardcoded French strings. Imperative "réduire tes dettes" copy. "Voir le plan de sortie" label still present.

**Strengths:**
- Single `errorAaa` scoping is correct — this is doctrinally the one place on S0-S5 where full error color is allowed (D-04 destructive-confirm exception, noted in code comments at lines 24, 37, 43, 74).
- Personalized facts (`totalBalance`, `monthlyPayment`) present — situated, not decorative.

**Findings (all correctly deferred):**

| # | Item | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S5-01** | Gradient background, hardcoded strings, imperative "réduire tes dettes", "plan de sortie" framing — all 5 Phase 3 DELETE items for S5 | `deferred-to-phase-9` | `debt_alert_banner.dart:23-28, 42, 70` | Phase 9 MintAlertObject rebuild will replace the entire banner with the typed API. Phase 3 explicitly scoped S5 transforms to Phase 9. Not a Phase 8c regression — a pre-condition for Phase 9. |

---

## 3. Cross-surface coherence tables

### 3.1 Typography scale

| Surface | Heading levels used | Body style | Color tokens used | Verdict |
|---|---|---|---|---|
| S0 Landing | `titleMedium` (wordmark) + `headlineSmall` (paragraph) | `bodySmall` (privacy, legal) | `textPrimary`, `textSecondaryAaa`, `textMutedAaa`, `craie` | ✅ 2 levels, AAA clean |
| S1 Intent | `MintTextStyles.headlineLarge` (title) + `bodyLarge` (subtitle) + `bodySmall` (microcopy) | — | `textPrimary`, `textSecondaryAaa`, `textMutedAaa` | ✅ 1 heading level, AAA clean |
| S2 Home | `headlineLarge` (coach opener) + various card titles | `bodyMedium` / `bodySmall` | Mixed — `textPrimary`, AAA tokens, `success`, `warning` | ⚠️ Coach opener `headlineLarge` is louder than S4 which uses demoted `headlineMedium` post-8b. Minor inconsistency. |
| S3 Bubble | — (no heading, `bodyMedium` only) | `bodyMedium` with `height: 1.6` | `textPrimary` | ✅ 0 heading levels — correct for a message surface |
| S4 Response Card | `headlineMedium` (title, demoted from Large in Phase 8b) | `bodyMedium` / `bodySmall` | `textPrimary`, `textSecondaryAaa`, `textMutedAaa`, MTC tokens | ✅ 1 heading level, Aesop demotion applied |
| S5 Debt Banner | `labelLarge` (title) | `bodySmall`, `bodyMedium` | `errorAaa`, `textPrimary`, `textSecondaryAaa` | ✅ 0 true headings (labelLarge is a label) |

**Discrepancy:** S2 coach opener at `headlineLarge` breaks parity with S4 `headlineMedium`. Same visual grammar across the coach-adjacent surfaces would improve cross-surface coherence. Flagged as **P-S2-04** (`defer`).

### 3.2 Spacing rhythm (4pt grid + breathing)

| Surface | Primary spacing tokens | Breathing ratio (whitespace / content) | Verdict |
|---|---|---|---|
| S0 Landing | `Spacer(flex: 2/3/1/2)` + `EdgeInsets.symmetric(32)` | ~60/40 whitespace-dominant | ✅ NYT-level breathing |
| S1 Intent | `MintSpacing.sm/lg/xl/xxxl` | ~50/50 | ✅ Clean |
| S2 Home | `MintSpacing.*` throughout + card paddings | ~30/70 content-dominant (5 cards + input bar) | ⚠️ Structurally necessary — S2 is the command center — but the contrast with S0/S4 is jarring if a user goes S0 → S1 → S2 in sequence. |
| S3 Bubble | `MintSpacing.md` symmetric | Per-bubble breathing is correct; vertical rhythm between bubbles = 20px bottom pad | ✅ |
| S4 Response Card | `MintSpacing.md` (sheet), `MintSpacing.sm+4` (compact) | ~50/50 | ✅ |
| S5 Debt Banner | `EdgeInsets.all(16)` + `SizedBox(height: 8, 12)` | ~40/60 | ⚠️ Hardcoded numeric insets instead of MintSpacing tokens — consistency drift. |

**Discrepancy:** S5 uses raw `EdgeInsets.all(16)` / `SizedBox(height: 8)` numeric literals instead of `MintSpacing.*` tokens. Will be fixed in Phase 9 rebuild. Flagged under P-S5-01.

### 3.3 Chromatic palette

| Surface | Background | Primary text | Secondary text | Accent | Verdict |
|---|---|---|---|---|---|
| S0 Landing | `craie` | `textPrimary` | `textSecondaryAaa`, `textMutedAaa` | `textPrimary` (CTA fill) | ✅ Monochrome discipline |
| S1 Intent | `porcelaine` | `textPrimary` | `textSecondaryAaa`, `textMutedAaa` | neutral | ✅ |
| S2 Home | mixed card backgrounds | `textPrimary` | `textSecondaryAaa` (post-8b) | `successAaa` (Itinéraire impact), `primary` (input send) | ✅ AAA applied |
| S3 Bubble | `porcelaine` bubble on main bg | `textPrimary` | — | — | ✅ Monochrome |
| S4 Response Card | `card` token | `textPrimary` | `textSecondaryAaa`, `textMutedAaa` | `errorAaa` (deadline pill urgent), `primary` (CTA) | ✅ Phase 8b applied |
| S5 Debt Banner | `errorAaa` alpha gradient | `textPrimary`, `errorAaa` (title) | `textSecondaryAaa` | `errorAaa` (icon + CTA fill) | ✅ Single allowed error surface |

**One-color-one-meaning check:** ✅ Holds. `errorAaa` appears only in S5 debt banner + S4 deadline pill (semantic: verifiable fact requiring attention). `successAaa` appears only in S2 Itinéraire impact (semantic: user gain). `warningAaa` reserved for Phase 9. `infoAaa` unused on S0-S5 at HEAD.

### 3.4 MTC bloom timing + motion curves

| Surface | Motion behavior | Duration | Curve | Reduced-motion fallback |
|---|---|---|---|---|
| S0 Landing | Staged fade-in (paragraph → CTA → legal) | 700ms total, 3 intervals | `easeOutCubic` | ✅ `mq.disableAnimations` → `_controller.value = 1.0` |
| S1 Intent | MintEntrance wrapper | ~400ms | MintEntrance default | ✅ (MintEntrance honors MQ) |
| S2 Home | Material defaults (card entry), AnimatedProgressBar | variable | Material standard | ✅ |
| S3 Bubble | BlinkingCursor on streaming | cursor cycle | — | ✅ (Phase 8b-03 verified) |
| S4 Response Card | AnimatedContainer variant switching | 200ms | `easeOut` | ✅ |
| S4 MTC sub-component | Bloom timing | **250ms** locked | `easeOut` | ✅ (Phase 4 verified) |
| S5 Debt Banner | static | — | — | ✅ (no motion) |

**Verdict:** ✅ MTC 250ms bloom is the only hard-locked timing; all other motion is in the 200-700ms range with `easeOut*` curves. Consistent enough. Landing's 700ms staged reveal is 3× the MTC bloom — intentional, it's a first-paint hero moment.

---

## 4. Element count delta (Phase 3 baseline vs HEAD)

**Phase 3 `AUDIT_RETRAIT_S0_S5.md` aggregate:** pre 145 → target 116 → post 104 (−28.3%, PASS).

**HEAD estimate (visual + grep audit):**

| Surface | Phase 3 pre | Phase 3 target | Phase 3 post (planned) | HEAD actual (estimated) | Delta vs planned | Notes |
|---|---:|---:|---:|---:|---:|---|
| S0 Landing | 37 | 29 | 26 | **~5** | **−21 better** | Phase 7 rebuild went far beyond the Phase 3 plan (full rewrite, not just DELETE). |
| S1 Intent | 13 | 10 | 9 | **~13** | **+4 worse** | Phase 3 DELETEs not applied — still 9 chips + microcopy footer. |
| S2 Home | 45 | 36 | 33 | **~45** | **+12 worse** | Phase 3 DELETEs not applied — StreakBadge, suggestion chips, empty state CTA all still live. |
| S3 Bubble | 18 | 14 | 13 | **~18** | **+5 worse** | Phase 3 DELETEs not applied — avatar, tier badge, sources label, disclaimer icon all still live. |
| S4 Response Card | 24 | 19 | 18 | **~18** | **0** | Phase 4 MTC rebuild + Phase 8b pass executed most DELETEs. On target. |
| S5 Debt Banner | 8 | 6 | 5 | **~7** | **+2** | Legacy; Phase 9 will replace. Acceptable. |
| **Aggregate** | **145** | **116** | **104** | **~106** | **+2** | Miss is concentrated on S1/S2/S3; S0 overcompensates. |

**Conclusion:** Aggregate is **within 2 elements of the Phase 3 plan** (106 vs 104), but this is misleading — S0 overshot by 21, masking S1/S2/S3 shortfalls of +4/+12/+5. **Per-surface -20% target is NOT currently met on S1, S2, S3.** Hot-fix items P-S1-01, P-S2-01, P-S2-02, P-S3-01, P-S3-02 together close ~9 of those 21 regression elements, bringing the aggregate to ~97 (below target).

**Regression root cause:** Phase 3 was scoped as audit-only. Phase 4 executed the DELETEs for S4 (MTC rebuild naturally subsumes them). Phase 7 rebuilt S0 from scratch. Phases 8a/8b focused on MTC migration (non-S0-S5 surfaces) + AAA token swap + microtypo — **none of these phases executed the Phase 3 DELETE list for S1/S2/S3.** This is a scope gap in the phase plan, not a bug. Phase 8c surfaces it. The 4 hot-fix proposals close it.

---

## 5. Delta proposal list (tagged, master table)

| # | Surface | Tag | File:line | Rationale |
|---|---|---|---|---|
| **P-S1-01** | S1 | `hot-fix-now` | `intent_screen.dart:66-99` | Delete 3 chips (Bilan, Prevoyance, NouvelEmploi). 2 anti-shame trips + 1 redundancy. |
| **P-S2-01** | S2 | `hot-fix-now` | `mint_home_screen.dart:382` | Delete StreakBadgeWidget on Plan Reality — doctrine ban list. |
| **P-S2-02** | S2 | `hot-fix-now` | `mint_home_screen.dart:737,765` | Delete `mintHomeConfidence` + `mintHomeNoActionProjection` suggestion chips (anti-shame checkpoints 2/3/6). |
| **P-S3-01** | S3 | `hot-fix-now` | `coach_message_bubble.dart:55,256-290` | Remove CoachAvatar 24px gradient dot + "M" letter from render tree. |
| **P-S3-02** | S3 | `hot-fix-now` | `coach_message_bubble.dart:108-116,292` | Remove CoachTierBadge from render tree (developer metadata leakage). |
| P-S0-01 | S0 | `defer-to-post-milestone` | `landingV2Paragraph` ARB | Consider paragraph compression to ≤30 words in Phase 12 editorial pass. |
| P-S0-02 | S0 | `defer-to-post-milestone` | `landing_screen.dart:144` | Test softer CTA fill token (anthracite vs textPrimary). |
| P-S1-02 | S1 | `defer-to-post-milestone` | `intent_screen.dart:164-171` | Delete intentScreenMicrocopy footer in Phase 10 onboarding rewrite. |
| P-S2-03 | S2 | `defer-to-post-milestone` | `mint_home_screen.dart:263` | Delete empty state CTA in Phase 10 onboarding rewrite (anti-shame checkpoint 2). |
| P-S2-04 | S2 | `defer-to-post-milestone` | `mint_home_screen.dart:182-189` | Demote coach opener headline Large → Medium for S4 parity. |
| P-S3-03 | S3 | `defer-to-post-milestone` | `coach_message_bubble.dart` (Sources + Disclaimers helper classes) | Remove "Sources" label + disclaimer info Icon; Phase 9 MintAlertObject may absorb disclaimer container. |
| P-S4-01 | S4 | `deferred-to-phase-9` | `response_card_widget.dart` proof sheet alerte row | Replace inline alert pattern with typed MintAlertObject — Phase 9 is the only correct place. |
| P-S5-01 | S5 | `deferred-to-phase-9` | `debt_alert_banner.dart:20-86` | Full rebuild through MintAlertObject — Phase 9. |

**Summary:**
- **5 hot-fix-now** (estimated ≤2h aggregate, zero architectural risk, pure delete-and-retest operations with ARB adjustments)
- **6 defer-to-post-milestone** (Phase 12 pre-ship polish)
- **2 deferred-to-phase-9** (by design, not regressions)

**Hot-fix execution proposal:** A single mini-phase `08d-phase-3-delete-enforcement` (1 plan, ~5 tasks) could land all 5 hot-fixes in one commit sequence before Phase 9 begins. This would close the Phase 3 DELETE gap and bring per-surface element counts into Phase 3 compliance. Alternative: fold into Phase 9 as a prerequisite cleanup.

---

## 6. Visual benchmarks reminder

Per `feedback_vz_content_not_visual.md` — MINT's visual grammar is **NOT** VZ. VZ's brain
(rigor, Swiss-law citations, multi-scenario) is the model; VZ's visual layout (dense
tables, info-dump pages) is the anti-model.

**Actual visual references for S0-S5:**

| Benchmark | What to borrow | Surface it most informs |
|---|---|---|
| **NYT** (subscribe page, homepage hero) | Editorial discipline; vast whitespace; one paragraph; one CTA; serif restraint | S0 Landing |
| **Apple Weather** | Situated atmospheric clarity; color as environmental mood, not decoration | S2 Home atmosphere |
| **Things 3** (Cultured Code) | Obsessive spacing rhythm; 4pt grid; micro-typography | S1, S4 |
| **Arc Browser** (The Browser Company) | Command palette calm; peripheral UI retreats until summoned | S2 Coach Input Bar, S3 bubble |
| **Stripe** (dashboard, docs) | Information density done right; MTC-style confidence primitives; tables that breathe | MTC component, S4 |
| **Aesop** (product pages) | Monochrome discipline; headline demotion; editorial line breaks | S2, S4 (Phase 8b applied) |
| **MUJI** (catalog, editorial) | 4-line grammar; no decorative flourish; product = content | S4 MUJI grammar (Phase 8b applied) |

**Currently aligned:** S0 (NYT), S4 (MUJI + Stripe), MTC (Stripe).
**Currently drifting:** S2 (closer to "classic Flutter app dashboard" than Apple Weather — but this is structurally necessary for the command center role and not something Phase 8c can rewrite).
**Cross-surface coherence risk:** a user going S0 → S1 → S2 experiences an aesthetic step-down from "NYT calm" to "functional Flutter" that should be smoothed in Phase 12 with further S2 decomposition.

---

## 7. Anti-shame audit

Tested against the 6 checkpoints from `feedback_anti_shame_situated_learning.md`:

1. Compares user to anyone (past self excepted)
2. Asks for data without immediately repaying with insight
3. Uses "tu devrais / il faut / tu dois" without conditional softening
4. Explains a concept before the user has seen their personal stake in it
5. More than 2 screens between user intent and first personalized insight
6. Error/empty state implies user is missing something they "should" have

| Surface | Element | Checkpoint | Status | Resolution |
|---|---|---|---|---|
| S0 | `landingVzComparison` (named competitor) | 1 | ✅ RESOLVED (Phase 7 rebuild deleted it) | — |
| S0 | Couple preview OutlinedButton → /auth/register | 2 | ✅ RESOLVED (Phase 7 rebuild deleted it) | — |
| S0 | Couple marriage-penalty generic text | 4 | ✅ RESOLVED (Phase 7 rebuild deleted it) | — |
| S1 | `intentChipBilan` ("faire un bilan") | 4 | ❌ **LIVE** | **P-S1-01 hot-fix** |
| S1 | `intentChipPrevoyance` (retirement default) | CLAUDE §9#16 | ❌ **LIVE** | **P-S1-01 hot-fix** |
| S2 | Empty state CTA → /documents/scan | 2 | ❌ LIVE (deferred to Phase 10) | P-S2-03 defer |
| S2 | `mintHomeConfidence` chip ("improve confidence") | 2, 6 | ❌ **LIVE** | **P-S2-02 hot-fix** |
| S2 | `mintHomeNoActionProjection` ("inaction") | 3, 6 | ❌ **LIVE** | **P-S2-02 hot-fix** |
| S2 | StreakBadgeWidget | 1 + doctrine ban list | ❌ **LIVE — highest gravity** | **P-S2-01 hot-fix** |
| S2 | Journey Steps fraction `N/M` | 1 (borderline) | ❌ LIVE | Not flagged — borderline, Phase 12 polish. |
| S4 | Deadline pill `errorAaa` | — | ✅ Not anti-shame, contrast-verified | — |
| S5 | "réduire tes dettes" imperative | 3 | ❌ LIVE (deferred to Phase 9 MintAlertObject) | P-S5-01 defer-to-9 |
| S5 | "plan de sortie" framing | 6 | ❌ LIVE (deferred to Phase 9) | P-S5-01 defer-to-9 |

**Summary:**
- **3 hot-fix anti-shame items** (P-S1-01, P-S2-01, P-S2-02) — must land before Phase 10.5 "très belle avant les humains" gate.
- **1 deferred-correctly to Phase 10** (P-S2-03 empty state CTA).
- **2 deferred-correctly to Phase 9** (S5 copy via MintAlertObject).
- **1 borderline not flagged** (Journey Steps fraction — under the ambient "progression axis = user vs past self" exception since it's a personal plan journey, not a knowledge score; revisit in Phase 12 if user research pushes back).

**Highest gravity:** StreakBadgeWidget on S2 is the single finding that trips the **explicit doctrine ban list** ("streaks tied to knowledge" is listed under "What MINT will never ship"). This must not be live when the first live a11y session runs in Phase 12, and must not be live at Phase 10.5 friction pass.

---

## 8. Conclusion and next actions

Phase 8c confirms that **the cross-surface coherence of S0-S5 is materially better than the Phase 3 baseline** on motion, color, typography, and microtypo axes — all Phase 8a/8b deliverables held up and are visible in the goldens. **However, the Phase 3 DELETE enforcement is incomplete** on S1, S2, and S3, concentrated into 5 hot-fix items that collectively:

- Close 3 anti-shame checkpoint trips (S1 Bilan + Prevoyance, S2 confidence/inaction chips, S2 StreakBadge)
- Remove the single doctrine-ban-list violation currently in the code (S2 StreakBadge)
- Close the S1/S2/S3 per-surface element count regression against the -20% Phase 3 target
- Improve S3 coach bubble editorial calm (CoachAvatar + CoachTierBadge removal)

**None of the 5 hot-fixes require architectural decisions.** All are delete-and-retest operations with ARB entry removal. Estimated aggregate effort: ≤2 hours + test suite.

### Recommended next actions

1. **Open mini-phase `08d-phase-3-delete-enforcement`** (or fold into Phase 9 as prerequisite cleanup plan) — execute P-S1-01, P-S2-01, P-S2-02, P-S3-01, P-S3-02 in a single plan. This closes the Phase 3 DELETE debt and brings S1/S2/S3 into per-surface compliance.
2. **Route the 6 defer items into the Phase 12 pre-ship polish backlog** with a dedicated `POLISH_PASS_2.md` entry template so they're not lost.
3. **Keep P-S4-01 and P-S5-01 as Phase 9 prerequisites** — they are the *reason* MintAlertObject exists.
4. **Do NOT open Phase 9 until the 5 hot-fixes land** — the doctrine ban list violation (StreakBadge) is a blocker for any "très belle avant les humains" gate and Phase 9 adds to S5 rather than cleans S2.

**Phase 8c exit state:** REPORT COMMITTED. Zero code touched. Proposals tagged. Ready for orchestrator decision on mini-phase 08d vs Phase 9 prerequisite fold-in.

---

*— Claude Polish Pass #1, 2026-04-07*
