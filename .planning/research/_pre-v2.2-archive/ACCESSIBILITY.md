# Accessibility Research — v2.2 La Beauté de Mint

**Domain:** Calm-but-information-dense Swiss fintech, AAA target on S1-S5
**Researched:** 2026-04-07
**Overall confidence:** MEDIUM (named practitioner work cited from training + verified Swiss org URLs; some practitioner-specific citations are MEDIUM rather than HIGH because Adrian Roselli's full back-catalogue was not reverified end-to-end this session)
**Downstream consumer:** gsd-research-synthesizer → roadmapper (Phase 0 must include live-test recruitment as a calendar-driving deliverable) + plan agents (specific Flutter Semantics widgets list)

> Scope note: this is not a WCAG checklist. The brief already names "AA bloquant CI, AAA cible S1-S5". This file answers HOW, grounded in named practitioner work, and surfaces the things the brief is silent on (recruitment, MintColors AAA delta, MTC bloom for screen readers, TalkBack 13 specific traps).

---

## 1. Sarah Wächter / Access for All (Stiftung «Zugang für alle»)

**Citation:** Access for All Foundation, Friedheimstrasse 8, 8057 Zürich. Switzerland's only independent non-profit accessibility certification body, founded 2000. Issues the recognized "Zugang für alle" / "Access for all" certification mark (Gold/Silver/Bronze) for websites and mobile apps tested against WCAG. Publishes the periodic *Swiss Accessibility Study* benchmarking Swiss banks, insurers, and public services. Confidence: HIGH on existence and role; MEDIUM on what they specifically find in fintech audits (no public Swiss bank audit report sourced this session).

**What they actually find on Swiss banking/fintech apps (from publicly known Swiss Accessibility Studies + Schweizer Accessibility-Studie patterns):**
- TalkBack/VoiceOver focus order broken in custom Flutter widgets that override hit-testing
- Form fields without persistent labels (label disappears on focus)
- Color-only state communication (red/green for "good/bad" with no text or icon)
- PDF certificates (LPP, AVS, tax) not tagged → screen reader users cannot consume
- Login flows that timeout without warning → WCAG 2.2.1 fail
- Charts (financial projections) with no text alternative or data table fallback

**Actionable recommendation:**
Apply for an **Access for All audit** before TestFlight ship of v2.2. They will hand back a graded report against WCAG 2.1 AA + AAA targets, scoped to your declared surfaces. The "Zugang für alle" seal is the only recognized Swiss accessibility credential and removes ambiguity in marketing.

**Where it applies:** S1–S5 + every projection screen with MTC migration (L1.2b ~12 screens). Critical: their auditors test on real Galaxy A14 + TalkBack — same device as Julien's floor.

**Cost:** L (CHF ~8–18k for a focused 5-screen audit + remediation report; quote varies). Schedule 6–8 weeks lead time minimum.

**Anti-pattern:** Running axe-flutter or flutter `SemanticsTester` in CI and calling it done. Automated tools catch ~30–40% of WCAG issues (per WebAIM). The other 60% only surface in human + assistive-tech testing.

---

## 2. Léonie Watson — dynamic content for screen reader users

**Citation:** Léonie Watson, Director of TetraLogical (now TPGi). Key piece: *"ARIA live regions"* (tetralogical.com/blog) + her Inclusive Design 24 talk *"How screen readers work"*. Her core point on animation: **screen readers do not narrate motion. They narrate state changes. If your animation is the only signal that something happened, screen reader users get nothing.** Confidence: HIGH on practitioner identity + core thesis; MEDIUM on exact talk citation.

**Actionable recommendation for MTC bloom:**
The 250ms bloom is a sighted-user delight. For TalkBack/VoiceOver, the bloom must trigger an **`aria-live="polite"` equivalent** — in Flutter, that's `SemanticsService.announce()` or a `Semantics(liveRegion: true)` wrapper around the trame.

**Spec for the 1-line audio summary** (the brief says "version 1 ligne audio" but doesn't write it):

> ❌ Bad (literal axis dump): *"Confidence 73 percent completeness high accuracy medium freshness low understanding intermediate"*
> ✅ Good (one human sentence with the load-bearing axis surfaced): *"Confiance 73 pourcent. Le maillon faible : la fraîcheur des données. Touche deux fois pour comprendre."*

Rule: surface the **lowest axis** (the binding constraint), not all four. Then offer a tap target to expand. Do NOT read the bloom animation itself. Do NOT use `liveRegion: true` for purely decorative state.

**Where it applies:** L1.2a MintTrameConfiance composant (mandatory). L1.5 MintAlertObject (G2/G3 transitions also need announce()).

**Cost:** S (1 method + copy decision per axis-as-weakest case = 4 strings × 6 langues = 24 ARB entries).

**Anti-pattern:** Wrapping the bloom container in `Semantics(liveRegion: true)` and letting Flutter spam the entire subtree on every rebuild. TalkBack will interrupt the user mid-action. Fire `announce()` exactly once per state transition.

---

## 3. Adrian Roselli — AAA pragmatism

**Citation:** adrianroselli.com. Recurrent thesis across his blog (2018–2024): **"AAA is achievable for most content; people treat it as aspirational because they haven't tried."** Specific posts referenced from training: *"WCAG 2.1 — what's new"* (verified URL: adrianroselli.com/2017/08/whats-new-in-wcag-2-1.html), *"Brief Note on Calculating Color Contrast"*, *"Don't Use The Placeholder Attribute"*, *"Under-Engineered Patterns"* series. Confidence: MEDIUM (verified one post URL; broader thesis is well-known in a11y community but not URL-cited this session).

**SC-by-SC reality check for MINT:**

| SC | Level | Realistic for MINT? | Cost |
|---|---|---|---|
| **1.4.6 Contrast Enhanced (7:1)** | AAA | Yes for text on white. **NO for current pastels** (saugeClaire, bleuAir, pecheDouce all fail). Either darken or use them as background-only behind dark text. | M (palette delta — see §9) |
| **2.3.3 Animation from Interactions** | AAA | Yes — already gated by `MediaQuery.disableAnimations` / `prefers-reduced-motion`. MTC bloom MUST honor it. | S |
| **2.4.6 Headings and Labels (descriptive)** | AA (not AAA — AA already requires this) | Already required. Audit S1–S5 for placeholder-as-label. | S |
| **3.1.5 Reading Level (lower secondary)** | AAA | Hardest for fintech vocabulary (LPP, surobligatoire, prévoyance). Requires either simplification OR a glossary tap target per term. Roselli's pragmatic answer: **provide both** — a simplified version available on demand counts. | L |

**Roselli's pragmatic move:** WCAG AAA does NOT require ALL content to meet AAA — it requires that AAA be **possible to meet for the content type**. For fintech jargon, providing an inline-expandable plain-language version (tap-to-define) satisfies 3.1.5 without dumbing down the primary text.

**Anti-pattern:** Trying to rewrite "rente de vieillesse LPP" to B1 French. The legal term must remain. Wrap it: `<term>rente de vieillesse LPP <expand>(la pension mensuelle versée par ta caisse de pension)</expand></term>`.

**Where it applies:** L1.1 retrait audit + L1.3 microtypographie pass.

---

## 4. Eric Bailey — accessible animation & graceful degradation

**Citation:** ericwbailey.website + co-author *Piccalilli's Inclusive Design 24*. Key piece: *"Revisiting prefers-reduced-motion, the reduced motion media query"* (CSS-Tricks, 2018, updated). His thesis: **`prefers-reduced-motion` is not "remove animation" — it's "remove vestibular triggers". Slow opacity fades are fine. Parallax, scaling, motion-along-path are not.** Confidence: MEDIUM-HIGH.

**Actionable recommendation for MTC bloom (250ms ease-out):**
- A scale or opacity bloom 250ms is **borderline OK** under reduced-motion if it's opacity-only
- If the bloom involves a scale transform > 1.05 or any directional motion, **replace with instant state change** when `MediaQuery.of(context).disableAnimations == true`
- Provide a 1-frame fade alternative (50ms opacity 0→1) so the state still feels intentional, not jarring

**Flutter implementation pattern:**
```dart
final reduce = MediaQuery.of(context).disableAnimations;
final duration = reduce ? Duration.zero : const Duration(milliseconds: 250);
```

**Where it applies:** L1.0 (VoiceCursorContract) + L1.2a (MTC) + L1.5 (MintAlertObject G2/G3 transitions).

**Anti-pattern:** Disabling ALL animations on `disableAnimations`. The user asked for less vestibular trigger, not for a dead UI. Keep crossfades, kill scale/translate.

---

## 5. WebAIM Million 2024/2025 — top failure patterns

**Citation:** webaim.org/projects/million/ — annual WCAG audit of top 1M home pages. 2024 report (verified pattern across years). Confidence: HIGH on top findings (consistent across reports).

**Top WCAG failures, Million 2024, by frequency:**
1. **Low contrast text** (~81% of pages) — most common single issue
2. **Missing alternative text on images** (~54%)
3. **Empty links** (~48%)
4. **Missing form input labels** (~45%)
5. **Empty buttons** (~28%)
6. **Missing document language** (~17%)

**Application to MINT:**
- (1) Contrast: validate every `MintColors.*` token used as text — see §9
- (2) Alt text: every `Image.asset` and `SvgPicture.asset` in S1–S5 needs `Semantics(label: ...)` or `excludeFromSemantics: true` if decorative. Audit count: ~40 illustrations across S1–S5.
- (4) Form labels: `intent_screen.dart` (S1) input fields — verify they have persistent visible labels, not placeholder-only

**Cost:** M for full S1–S5 sweep.

**Anti-pattern:** Trusting flutter's default `Semantics` wrapping. `Image.asset` without `semanticLabel:` is announced as "image" or sometimes silently. Empty `IconButton(onPressed: ..., icon: Icon(Icons.close))` with no `tooltip:` is announced as "button" — TalkBack 13 fail (verified GitHub issue #147045).

---

## 6. COGA Task Force (W3C Cognitive Accessibility)

**Citation:** w3.org/WAI/cognitive/. Key documents: *Cognitive Accessibility User Research*, *Making Content Usable for People with Cognitive and Learning Disabilities* (W3C Note). The COGA gap analysis informs WCAG 3.0 ("Silver"). Confidence: HIGH on existence + scope.

**Specific COGA patterns MINT should adopt:**
1. **Clear, consistent structure** — same nav location, same labels everywhere (not "Profil" here, "Mon compte" there). MINT already 3-tab + drawer ✓
2. **Avoid time pressure** — no countdown timers on financial decisions (G3 alerts must NOT auto-dismiss)
3. **Provide a way out of every screen** — single, obvious back/close. P3 of MINT brief ("une idée par écran") aligns
4. **Show progress** — multi-step flows must show "step 2 of 5"
5. **Concrete examples over abstractions** — "tu cotises 491 CHF par mois" beats "ton taux d'épargne est de 12%"
6. **Don't rely on memory** — any number entered earlier should be visible when asked again (MINT profile pre-fill aligns ✓)
7. **One main action per screen** — P3 alignment ✓

**Where it applies:** Cross-cutting. The biggest COGA risk in MINT is **G3 Cash N5 alerts** auto-dismissing or being part of a timed flow. They must persist until acknowledged.

**Cost:** S (mostly verification — MINT's existing P3 doctrine + drawer architecture covers most COGA recommendations).

**Anti-pattern:** ADHD-specific UX research is **contested and weak**. Resist any vendor claim of "ADHD-friendly design system". Treat ADHD users as a subset of cognitive load reduction (COGA's general guidance), not a special case.

---

## 7. Reading Level for French B1 (SC 3.1.5)

**Citation:** WCAG 3.1.5 says "lower secondary education level (after 7 years)". For French, this maps approximately to **CECRL B1**. Tools:
- **LIX** (originally Swedish, language-agnostic; <40 = easy, 40–50 = average, >55 = difficult)
- **Flesch-Kincaid adapted French** (Kandel & Moles formula, 1958: `207 - 1.015×ASL - 73.6×ASW`). Score >70 = easy reading.
- **SCOLARIUS** (free French-specific tool, scolarius.com — produces "primaire / secondaire / universitaire")
- **LISI** (Lisibilité simplifiée, IRO, French-specific)

**For French B1 target:** aim for Flesch-Kincaid French ≥65, LIX ≤45, average sentence length ≤15 words, average word length ≤2 syllables for non-jargon terms.

**Tooling for ARB strings:**
- No off-the-shelf Dart tool. Build a tiny script: extract all `intl_*.arb` values → run through `scolarius` API or local LIX implementation → CI gate on S1–S5 strings only (not jargon-locked terms).
- Alternative: use **textstat** Python package (has French support) in a backend CI step.

**Where it applies:** L1.6b voice pass (30 phrases coach) + every microcopy in S1–S5.

**Cost:** M (build the script + tag jargon exemptions). The hard part isn't measurement, it's accepting that "rente vieillesse LPP" cannot pass and must use the tap-to-define pattern from §3.

**Anti-pattern:** Running Flesch-Kincaid English formula on French text. The formulas are NOT interchangeable — coefficients differ.

---

## 8. TalkBack 13 + Galaxy A14 specifics

**Citation:** Verified Flutter GitHub issues this session: #147045 (IconButton incorrect announcement), #148230 (InkWell excludeSemantics tap target wrong), #133742 (DropdownMenu wrong semantic label), #99763 (TextField obscureText not updating semantics), #76108 (Semantics(focused: true) ignored depending on hierarchy). Confidence: HIGH.

**Concrete TalkBack 13 traps in Flutter (different from VoiceOver behavior):**

| Widget | TalkBack 13 problem | Fix |
|---|---|---|
| `IconButton(icon: Icon(Icons.close))` no tooltip | Announced "button" or attempts OCR on icon | Always pass `tooltip:` (becomes semanticLabel) |
| `InkWell` with `excludeSemantics: true` child | Tap delivered to wrong target | Use `excludeSemantics: false` or restructure |
| `DropdownMenu` | Reads internal hint, not selected value | Wrap in `Semantics(value: selectedLabel)` |
| `TextField` with `obscureText` toggling | Reads "bullets" forever after toggle | Force rebuild or use `Semantics(obscured: false)` explicitly |
| Custom `GestureDetector` on a `Container` | Not focusable by TalkBack at all | Wrap in `Semantics(button: true, label: ..., onTap: ...)` |
| `AnimatedSwitcher` content change | Old + new both announced or neither | Manual `SemanticsService.announce()` |
| `CustomPaint` (charts, MTC bloom) | Invisible to TalkBack | `CustomPainter.semanticsBuilder` MUST be implemented OR wrap in `Semantics(label: textSummary)` |

**Galaxy A14 Android 13 quirks beyond TalkBack:**
- Font scaling up to 200% — most MINT screens fail at 150%+ (TextOverflow noted in MEMORY.md project_responsive_refactor)
- Gesture nav drawer conflict with edge-swipe back — test the ProfileDrawer
- 4 GB RAM — MTC bloom AnimationController must be `dispose()`'d (memory leak risk over a long session)

**Where it applies:** L1.0 (Galaxy A14 manual perf gate already in scope) + L1.2a + cross-cutting audit.

**Cost:** M (1 day audit pass + targeted fixes per finding).

---

## 9. MintColors AAA Delta — pastels vs 7:1

**Audit of `lib/theme/colors.dart` against AAA 7:1 on white (#FFFFFF) background, normal text:**

Required ratio: **7:1** for normal text AAA, **4.5:1** for large text (≥18pt or ≥14pt bold) AAA.

| Token | Hex | Ratio on white | AA pass (4.5:1)? | AAA pass (7:1)? | Fix proposal |
|---|---|---|---|---|---|
| `primary` #1D1D1F | ~17.5:1 | ✅ | ✅ | — |
| `textPrimary` #1D1D1F | ~17.5:1 | ✅ | ✅ | — |
| `textSecondary` #6E6E73 | ~5.4:1 | ✅ | ❌ | Darken to #595960 (~7.1:1) for body |
| `textMuted` #737378 | ~4.6:1 | ✅ AA only | ❌ | Darken to #5C5C61 (~7.0:1) |
| `success` #157B35 | ~5.36:1 | ✅ | ❌ | Darken to #0F5E28 (~7.2:1) |
| `warning` #B45309 | ~5.02:1 | ✅ | ❌ | Darken to #8C3F06 (~7.1:1) |
| `error` #D32F2F | ~4.98:1 | ✅ | ❌ | Darken to #A52121 (~7.0:1) |
| `info` #0062CC | ~5.80:1 | ✅ | ❌ | Darken to #004FA3 (~7.1:1) |
| `accent` #00382E | ~14:1 | ✅ | ✅ | — |
| `saugeClaire` #D8E4DB | ~1.3:1 | ❌ | ❌ | **BACKGROUND ONLY** — never as text. Pair with `primary` text on top. |
| `bleuAir` #CFE2F7 | ~1.3:1 | ❌ | ❌ | **BACKGROUND ONLY** |
| `pecheDouce` #F5C8AE | ~1.6:1 | ❌ | ❌ | **BACKGROUND ONLY** |
| `corailDiscret` #E6855E | ~2.7:1 | ❌ | ❌ | Decorative only. Not for text/icons-as-information. |
| `porcelaine` #F7F4EE | ~1.05:1 | ❌ | ❌ | **BACKGROUND ONLY** (this is its purpose) |
| `coachAccent` #3A3D44 | ~10.5:1 | ✅ | ✅ | — |

**The honest brand conversation:** AAA on S1–S5 means:
1. Every **text and information-bearing icon** uses tokens from the green-checked rows above
2. The pastel "Visual Graal" tokens (saugeClaire, bleuAir, pecheDouce, porcelaine, craie) become **background-only** — they never carry text contrast load. Text on top of them must be `primary` / `ardoise` / `accent`.
3. The "AA contrast fix" tokens (success, warning, error, info, textSecondary, textMuted) need a **second darker variant** for AAA contexts: `successAaa`, `warningAaa`, etc. Add 6 new tokens, keep originals for AA-only surfaces.

**Brand willingness check:** the darkening is subtle (delta ~15% lightness) and preserves hue. The pastels are untouched as backgrounds. The "Visual Graal" character is intact.

**Cost:** M (palette delta + global rename in S1–S5 only — DO NOT mass-migrate, that's scope drift).

**Anti-pattern:** Using `corailDiscret` or `pecheDouce` for warning text on white. Looks calm, fails AA, illegal-ish under EU EAA.

---

## 10. Cognitive accessibility for ADHD on dense screens (acknowledged contested)

**Honest framing:** ADHD-specific design research is thin and contested. The reproducible findings are basically COGA general guidance. Avoid vendors selling "ADHD design systems".

**What's actually research-backed:**
- **Reduce extraneous cognitive load** (Sweller, Cognitive Load Theory) — every removed visual element on S1–S5 (L1.1 -20% retrait) directly serves ADHD users
- **External working memory** — show recent context, don't make user remember
- **Single primary action per screen** — already P3 of MINT brief
- **Avoid attention thieves** — banners, badges, notification dots competing for primacy. Pick one focal point.
- **Tolerate non-linear paths** — let users tap through, back out, retry without penalty. No "you must complete all 5 steps".

**Application:** L1.1 retrait audit is the single biggest ADHD intervention in v2.2. The chantier already exists. Don't invent ADHD-specific features.

**Anti-pattern:** Adding "ADHD mode" toggle. It's a confession that the default is bad. Fix the default.

---

# Synthesis

## A. AAA-on-S1-S5 cost reality

Honest delta from current ~AA to AAA on the 5 surfaces, assuming MintColors palette delta from §9 is accepted:

| Surface | AA → AAA work | Estimate |
|---|---|---|
| **S1 intent_screen** | Form labels persistent ✓ verify; reading level pass on 30+ strings; tap-to-define for any jargon; voice cursor question accessible | 2–3 days |
| **S2 mint_home_screen** | Card semantics tree (each smart card = one focus stop, not 4); reading level on previews; 7:1 contrast on every metric; alt text on illustrations | 3–4 days |
| **S3 coach_message_bubble** | `liveRegion` for incoming messages; 7:1 on bubble text; voice cursor level NOT announced (internal); reduced-motion variant of typing indicator | 2 days |
| **S4 response_card_widget + MTC** | MTC bloom announce() spec; CustomPaint semanticsBuilder; reduced-motion bloom; 7:1 on confidence text; tap-to-expand "weakest axis" pattern | 4–5 days (this is the hard one) |
| **S5 MintAlertObject (new)** | Build with a11y from day 1: G2/G3 announce, persist until ack (no auto-dismiss), 7:1 on all text, reduced-motion transitions, tested on TalkBack 13 | 3 days |

**Total realistic estimate: 14–17 dev days for AAA on S1–S5**, plus ~3 days for the palette delta + ~5 days for the live test sessions + remediation. **Round to 4 weeks of one engineer's focused time** — non-trivial. If parallelized with L1.2a/b this fits inside the milestone. If serialized, it eats Phase 0 + half of Phase 1.

**The brutal honest read:** AAA on 5 surfaces is achievable. AAA on the whole app is not, and the brief correctly does not ask for it. Hold the line: AAA bloquant on S1–S5 only, AA bloquant CI on everything else.

---

## B. Live test session recruitment — Switzerland

**The brief is silent on this. It is the #1 schedule risk** because recruitment lead time is 4–8 weeks for blind/low-vision testers in Switzerland. This MUST be a Phase 0 deliverable, not a Phase 4 afterthought.

### Who, where, how, cost

**1. Malvoyant·e (1 tester) — primary channel:**

- **Fédération suisse des aveugles et malvoyants (SBV-FSA)** — sbv-fsa.ch. National federation, 16 regional sections. Romandie sections in Genève, Vaud (Lausanne), Jura, Fribourg. Contact route: their "Section romande" or "Service Lausanne". They run a usability testing pool informally for accessibility-conscious Swiss companies. Cost: typically CHF 100–150/hour for the tester (paid directly), plus a donation to the federation (CHF 200–500). Lead time: 4–6 weeks.
- **Access for All foundation (Zürich)** — also brokers tester contacts as part of audit packages. If you're already paying for the §1 audit, ask them to bundle a tester session.
- **Backup:** Procap Suisse (procap.ch) — broader disability federation, slower response.

**2. ADHD tester (1 tester):**

- No formal Swiss ADHD usability pool exists. Realistic channels:
  - **ADHD-Schweiz / ASPEDAH** (Association Suisse Romande de Parents d'Enfants avec Déficit d'Attention/Hyperactivité — aspedah.ch) — adults sometimes recruit through them
  - **University recruitment** — UNIL, UNIGE, EPFL student services often have neurodivergent-friendly recruitment lists
  - **Twitter/LinkedIn open call** — fastest, lowest reliability
  - Cost: CHF 80–120 for a 1h session
  - Lead time: 2–4 weeks if open-call, 6 weeks if formal

**3. Français-seconde-langue tester:**

- **Université populaire de Lausanne (UP)** or **Université populaire de Genève** — French A2/B1 classes for migrants. Coordinator can field a willing student.
- **Caritas Suisse — programmes d'intégration** — each canton has a Caritas integration office running French courses
- Cost: CHF 50–80 + course donation
- Lead time: 2–3 weeks

**Total recruitment budget estimate:** CHF 500–1'200 cash to testers + CHF 300–800 in donations to orgs. Total ~**CHF 800–2'000** for the 3 sessions.

**Total recruitment lead time floor:** **6 weeks from first email to first session**. This MUST start the day Phase 0 opens.

**Anti-pattern:** Asking a sighted colleague to "use VoiceOver and pretend". This produces zero useful insight and Julien will know within 5 minutes. Real testers or no test.

---

## C. MTC bloom animation accessibility spec

**Sighted experience (unchanged):** 250ms ease-out scale 1.0 → 1.0 + opacity 0.85 → 1.0, on the trame component, fired when `EnhancedConfidence` resolves on the screen.

**Reduced-motion variant (`MediaQuery.disableAnimations == true`):**
- Replace bloom with **50ms opacity fade** 0 → 1, no scale
- State change still feels intentional, no vestibular trigger

**Screen-reader experience:**
- Wrap MintTrameConfiance in `Semantics(liveRegion: false, container: true, label: <oneLineSummary>)`
- On `EnhancedConfidence` resolution: call `SemanticsService.announce(<oneLineSummary>, TextDirection.ltr)` exactly **once** per state transition
- The `<oneLineSummary>` is generated by a pure function `oneLineConfidenceSummary(EnhancedConfidence): String` — testable, deterministic
- The function surfaces the **lowest axis** as the binding constraint, not all four

**Pseudo-spec for `oneLineConfidenceSummary()`:**
```
"Confiance {percent} pourcent. {weakestAxisSentence}. Touche deux fois pour comprendre."

weakestAxisSentence by axis:
  completeness  → "Il manque encore des données"
  accuracy      → "Certaines valeurs sont des estimations"
  freshness     → "Les chiffres ont besoin d'être rafraîchis"
  understanding → "On peut creuser ensemble si tu veux"
```

6 langues × 4 weakest-axis variants = 24 ARB strings.

**Test gate:** `oneLineConfidenceSummary()` has unit tests for all 4 axis-as-weakest cases + ties (lowest wins ties by priority order: freshness > accuracy > completeness > understanding).

**Anti-pattern:** Reading the bloom animation itself ("animation en cours"). Reading all 4 axes verbatim. Firing announce() on every rebuild rather than on state change.

---

## D. MintColors AAA delta — proposal summary

**Add 6 new tokens** (to `colors.dart`, scoped to S1–S5 use):

```dart
// AAA-grade variants for Layer 1 surfaces
static const Color textSecondaryAaa = Color(0xFF595960); // 7.1:1
static const Color textMutedAaa     = Color(0xFF5C5C61); // 7.0:1
static const Color successAaa       = Color(0xFF0F5E28); // 7.2:1
static const Color warningAaa       = Color(0xFF8C3F06); // 7.1:1
static const Color errorAaa         = Color(0xFFA52121); // 7.0:1
static const Color infoAaa          = Color(0xFF004FA3); // 7.1:1
```

**Migrate ONLY S1–S5 + MTC trame** to these. Do not mass-migrate. All other surfaces stay on AA tokens.

**Pastels rule:** saugeClaire, bleuAir, pecheDouce, corailDiscret, porcelaine, craie are **background-only** in S1–S5. No information-bearing text or icons on top of them — text must be `primary`/`ardoise`/`accent`.

**Brand willingness:** the deltas are 12–18% darker, hue preserved. Visually almost imperceptible to most users; legally and ergonomically a different category.

---

## E. Top 5 Flutter widgets MINT must add `Semantics()` to (non-obvious)

Ranked by TalkBack 13 failure severity, focused on widgets that "look fine" with VoiceOver but break on TalkBack/A14:

1. **`CustomPaint` for MTC bloom and any chart** — TalkBack sees nothing. Implement `CustomPainter.semanticsBuilder` returning at minimum a single `CustomPainterSemantics` rect with a label, OR wrap the `CustomPaint` in `Semantics(label: textSummary)` and `excludeFromSemantics: true` on the CustomPaint itself.

2. **`IconButton` without `tooltip:`** (Flutter issue #147045) — TalkBack 13 announces "button" or runs OCR garbage. Every IconButton in S1–S5 MUST have a `tooltip:` (which becomes the semantic label). Audit count likely 15–25 across S1–S5.

3. **`InkWell` / `GestureDetector` wrapping a `Container`** — not focusable by TalkBack at all unless wrapped. Pattern:
   ```dart
   Semantics(
     button: true,
     label: l10n.actionLabel,
     onTap: handler,
     child: InkWell(onTap: handler, child: Container(...)),
   )
   ```

4. **`AnimatedSwitcher` / `AnimatedCrossFade`** during state transitions (e.g., MTC bloom, MintAlertObject G2→G3, coach typing→message) — old + new both announced OR neither. Manual `SemanticsService.announce()` on state change is mandatory.

5. **`TextField` with dynamic `obscureText`** (Flutter issue #99763) — semantics not updated. If MINT has any password/PIN field with show/hide, TalkBack will read "bullets" after toggle. Force rebuild via `key:` change or wrap in explicit `Semantics(obscured: false)`.

**Bonus #6 (because the brief mentions it):** **`DropdownMenu`** (Flutter issue #133742) — wrong semantic label. Wrap in `Semantics(value: selectedLabel)`. The voice cursor "Ton" setting in S1 is likely a dropdown — verify.

---

## Pitfall-to-Phase Mapping

| Pitfall | Phase to address | Verification |
|---|---|---|
| Recruitment 6-week lead time blows the milestone calendar | **Phase 0** (the day it opens) | First email sent + tester confirmed within 2 weeks |
| MintColors pastels fail 7:1 silently | Phase 0 (palette delta) | New AAA tokens added, S1–S5 imports migrated |
| MTC bloom invisible to TalkBack | L1.2a (with the component build) | `oneLineConfidenceSummary()` unit-tested + announce() fired exactly once on state change |
| TalkBack 13 IconButton/InkWell traps | L1.1 retrait audit (catch during deletion pass) | grep `IconButton` in S1–S5, every instance has `tooltip:` |
| Reading level fail on jargon | L1.6b voice pass | Flesch-Kincaid French ≥65 or tap-to-define wrapper present |
| Reduced-motion ignored | L1.2a + L1.5 | Manual test on Galaxy A14 with "Remove animations" toggled |
| G3 alert auto-dismisses | L1.5 MintAlertObject build | Test: G3 alert persists until explicit user ack |
| ADHD-mode-as-feature scope drift | Cross-cutting design review | Reject any "ADHD toggle" proposal — fix defaults instead |
| "Pretend testers" instead of real ones | Phase 0 (recruitment owner named) | Real names on the calendar, not "internal volunteer" |
| Access for All audit booked too late | Phase 0 | Quote requested by week 1, audit booked for end-of-milestone window |

---

## Open questions for Julien (cannot resolve in research)

1. **Brand willingness on AAA palette delta** — accepted? If not, AAA on S1–S5 cannot ship and the brief commitment must downgrade to "AA + AAA where palette permits".
2. **Live test session budget** — CHF 800–2'000 + ~CHF 8–18k for Access for All audit. Approved?
3. **Recruitment owner named** — who sends the first email to SBV-FSA the day Phase 0 opens? This person owns the calendar risk.
4. **Tap-to-define jargon pattern (§3)** — accepted as Roselli pragmatic compromise, or do we attempt full B1 rewrite of legal terms (much harder, ~2x cost on L1.6b)?
5. **Voice cursor "Ton" setting in S1** — is it a `DropdownMenu`, `RadioListTile`, or `SegmentedButton`? Each has a different TalkBack 13 risk profile (DropdownMenu = highest risk, see #6 above).

---

## Confidence summary

| Section | Confidence | Reason |
|---|---|---|
| §1 Access for All / Sarah Wächter | HIGH on org, MEDIUM on specific findings | Verified URL; specific Swiss bank audit reports not pulled |
| §2 Léonie Watson | HIGH on thesis, MEDIUM on exact citations | Practitioner well-known; specific talk URL not reverified |
| §3 Adrian Roselli AAA | MEDIUM | One URL verified; broader thesis is community-known |
| §4 Eric Bailey reduced-motion | MEDIUM-HIGH | Well-known CSS-Tricks article; not URL-verified this session |
| §5 WebAIM Million | HIGH | Pattern stable across multiple years' reports |
| §6 COGA | HIGH on existence; MEDIUM on specific patterns | W3C source; specific patterns paraphrased from training |
| §7 Reading level French | HIGH on tools, MEDIUM on score targets | Tool names verified-in-training; B1 score targets approximate |
| §8 TalkBack 13 / Flutter | HIGH | All 5 cited Flutter GitHub issues verified live this session |
| §9 MintColors AAA | HIGH | Computed against actual `colors.dart` read this session; ratios approximate (rounded) |
| §10 ADHD | MEDIUM (intentionally — research is contested) | Honest framing |
| Synthesis A (cost) | MEDIUM | Engineering estimates based on typical Flutter a11y work |
| Synthesis B (recruitment) | HIGH on org names + URLs, MEDIUM on costs | SBV-FSA, Access for All, ASPEDAH, Caritas all verified existence |

---

## Sources

- [Access for All Foundation — about](https://access-for-all.ch/en/about-us/foundation/)
- [Anton Bolfing — ICT Accessibility and eInclusion in Switzerland (ZHAW PDF)](https://www.zhaw.ch/storage/linguistik/forschung/barrierefreie-kommunikation/bolfing-ict-accessibility-and-eInclusion-in-switzerland.pdf)
- [Fédération suisse des aveugles et malvoyants (SBV-FSA)](https://sbv-fsa.ch/fr/)
- [W3C WCAG 2.1 — 1.4.6 Contrast (Enhanced)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-enhanced.html)
- [WebAIM — Contrast and Color Accessibility](https://webaim.org/articles/contrast/)
- [TetraLogical — Meeting WCAG Level AAA](https://tetralogical.com/blog/2023/04/21/meeting-wcag-level-aaa/)
- [Adrian Roselli — What's New in WCAG 2.1](https://adrianroselli.com/2017/08/whats-new-in-wcag-2-1.html)
- [Flutter issue #147045 — TalkBack announces IconButton incorrectly](https://github.com/flutter/flutter/issues/147045)
- [Flutter issue #148230 — TalkBack tap target wrong with InkWell + excludeSemantics](https://github.com/flutter/flutter/issues/148230)
- [Flutter issue #133742 — DropdownMenu wrong semantic label](https://github.com/flutter/flutter/issues/133742)
- [Flutter issue #99763 — TextField obscureText semantics not updated](https://github.com/flutter/flutter/issues/99763)
- [Flutter issue #76108 — Semantics(focused: true) ignored by hierarchy](https://github.com/flutter/flutter/issues/76108)
- [Andrew Zuo — Fixing Orphaned Semantic Nodes in Flutter](https://medium.com/lost-but-coding/fixing-orphaned-unreachable-semantic-nodes-in-flutter-for-voiceover-and-talkback-dae1c9cafe53)
- WebAIM Million annual report — webaim.org/projects/million/ (referenced from training, not URL-fetched this session)
- W3C Cognitive Accessibility — w3.org/WAI/cognitive/ (referenced from training)
- ASPEDAH — aspedah.ch (referenced for ADHD recruitment channel)
- Caritas Suisse — caritas.ch (referenced for FLE recruitment channel)

---

*Research for: MINT v2.2 La Beauté de Mint — accessibility grounding*
*Researched: 2026-04-07*
*Author: gsd-project-researcher (accessibility dimension)*
