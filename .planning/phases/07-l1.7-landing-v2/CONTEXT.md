# Phase 7 — L1.7 Landing v2 (S0 Rebuild) — CONTEXT

**Date:** 2026-04-07
**Branch:** feature/v2.2-p0a-code-unblockers
**Requirements covered:** LAND-01, LAND-02, LAND-03, LAND-04, LAND-05, LAND-06 (6 REQs)
**Depends on:** Phase 1 (STAB-19 providers wired), Phase 1.5 (chiffre_choc domain rename), Phase 2 (AAA tokens implemented in `colors.dart`)
**Scope:** Mobile only. Web landing Variante C is explicitly out of v2.2 scope (per REQUIREMENTS.md LAND-03).

---

## 1. Intent

Rebuild `apps/mobile/lib/screens/landing_screen.dart` (currently 861 LOC, 37 visual elements, 6 `financial_core`/services imports) as a **calm promise surface**. Zero numbers, zero inputs, zero `financial_core`, zero retirement vocabulary. The landing says *"MINT sait quoi te dire quand tu seras prête"* — it does not start a flow, it opens a door.

The landing must pass the gate:
> "MINT ne te dit pas quoi faire. MINT te dit qu'elle sait quoi te dire quand tu seras prête."

It must work identically for a 22-year-old first-job worker, a 45-year-old divorcing parent, and a 68-year-old widow. **Never retirement framing.** Never age-targeting. Never "commencer", "démarrer", "découvrez".

---

## 2. Locked Decisions (non-negotiable)

### D-01 — Paragraphe-mère French master text (from LAND-03, REQUIREMENTS.md)

> **"Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts. Calmement. Sans te vendre quoi que ce soit."**

- 28 words (target ~30). Locked. No rewrite. No "variante A bis".
- Mentions six life-domains (assurances, 3a, salaire, bail, couple, impôts) — deliberately *not* retirement, *not* pension, *not* LPP/AVS. The "3a" reference is the only pillar token and is kept because it is public vocabulary every Swiss resident knows, not retirement-specific.
- Anti-shame audited: zero imperative, zero shame trigger, zero second-person command.

### D-02 — Primary CTA copy

> **"Continuer (sans compte)"**

- Locked per LAND-02. Parenthetical "(sans compte)" is load-bearing — it carries the privacy/no-account promise at the moment of commitment. Do not split it to a separate line.
- Banned alternatives (LAND-04): "Commencer", "Démarrer", "Voir mon chiffre", "Ton chiffre en X secondes", "Découvrir", "Parler au coach", "Explorer".
- Routes to **`/onboarding/intent`** (LAND-06). Not `/onboarding/promise`, not `/onboarding/quick-start`.

### D-03 — Privacy micro-phrase (directly below CTA)

> **"Rien ne sort de ton téléphone tant que tu ne le décides pas."**

- Locked per LAND-02. Single line. `textSecondaryAaa` on `craie` background.

### D-04 — Legal footer line

> **"Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin."**

- Single line at the bottom, `textMutedAaa`. Compliance anchor (CLAUDE.md §6).

### D-05 — Zero other elements

The landing contains **exactly four text surfaces**:
1. MINT wordmark (header, top-left)
2. Paragraphe-mère (vertical center, weight-carrying)
3. CTA pill + privacy micro-phrase (below paragraph, generous gap)
4. Legal footer line (bottom-safe-area)

No: hero chart, no score, no confidence dial, no trust chips, no testimonials, no social proof, no numbers of any kind, no input fields, no translator cards, no hidden-number teaser, no couple preview, no VZ comparison, no analytics consent on first paint, no login button (defer login to `/onboarding/intent` or a discreet tap target in the wordmark row only — see D-12).

### D-06 — Layout system

- **Craie background** (`MintColors.craie` #FCFBF8) flat, no gradient, no porcelain wash. The gradient would compete with the paragraph for weight. Calm = flat.
- **Vertical rhythm:** `SafeArea` → `Spacer(flex: 2)` → wordmark → `Spacer(flex: 3)` → paragraph → `Spacer(flex: 1)` → CTA + privacy line → `Spacer(flex: 2)` → legal footer → `SafeArea`. The generous top space is deliberate — empty space carries the "calme" signal.
- **Horizontal:** `EdgeInsets.symmetric(horizontal: 32)` on phone, clamped to `maxWidth: 560` on tablet/web. Paragraph reads in ~4 lines on iPhone 14 Pro, ~3 lines on Galaxy A14.
- **No decorative chrome:** no cards, no borders, no shadows, no dividers, no dots, no icons anywhere on the landing except inside the CTA pill (and even there: none — just text).

### D-07 — Typography scale (weight-carrying decision)

The paragraph carries the entire surface. Token selection:

- **Paragraphe-mère:** `Theme.of(context).textTheme.headlineSmall` (Montserrat, weight 500, ~24sp) with `height: 1.45` and `letterSpacing: -0.2`. Color: `MintColors.textPrimary` (full black on craie, AAA guaranteed). Rationale: headlineSmall is heavy enough to anchor the screen without feeling like a marketing headline; bodyLarge would feel like microcopy, displayMedium would feel like a slogan. 500 weight (not 600) keeps it calm.
- **Wordmark:** existing MINT wordmark at its existing size, `textPrimary`.
- **CTA pill text:** `labelLarge` (Inter 16sp weight 500), color `craie` on a `textPrimary`-filled pill. This gives a strictly AAA-compliant button (black on cream = inverse). No primary color fill — primary is reserved for later surfaces; here the CTA reads as "a door", not "a product button".
- **Privacy micro-phrase:** `bodySmall` (Inter 13sp) with `textSecondaryAaa` on craie. Verified AAA via Phase 2 contrast matrix.
- **Legal footer:** `bodySmall` at 12sp with `textMutedAaa` on craie. AAA per Phase 2.

### D-08 — Motion

- **Entry bloom:** paragraph fades in (`Opacity` 0→1) + translates up 8px over **250ms ease-out**, delayed 120ms after first frame. CTA + privacy line fade in at 400ms. Legal footer fades at 600ms. Wordmark appears immediately (no animation). Arc-style, not marketing.
- **Reduced-motion fallback:** if `MediaQuery.accessibleNavigation` or `MediaQuery.disableAnimations` is true → all elements appear instantly at final opacity. No exception.
- **No loop animation**, no parallax, no shimmer, no gradient sweep. Stillness is the point.

### D-09 — Accessibility (AAA, day 1)

- Every text surface uses Phase 2 AAA tokens where the default token fails 7:1 on craie. Concretely: paragraph uses `textPrimary` (pure dark, trivially AAA), CTA uses inverse (craie on textPrimary pill, trivially AAA), privacy uses `textSecondaryAaa`, legal uses `textMutedAaa`.
- **Minimum tap target:** CTA pill height = 56dp (exceeds 48dp Material spec).
- **Semantic landmarks:** `Semantics(container: true, header: true)` on wordmark; `Semantics(label: paragraphe-mère text)` wraps the paragraph Text (redundant but explicit for TalkBack 13 sweep in Phase 9); CTA is a `Semantics(button: true, label: 'Continuer sans compte')`.
- **Text-scale AAA:** the layout must survive `textScaleFactor = 1.3` without overflow. Golden test covers this (see Plan 03).
- **Reduced motion:** see D-08.
- **Dynamic Type / system font:** Montserrat + Inter already flex with system scale.

### D-10 — Regional voice: neutral on landing

**Decision:** the landing does NOT vary by canton. Regional voice (VS/ZH/TI) kicks in post-intent, inside the coach context. Rationale:
- Regional voice needs a `Profile.residenceCanton` to resolve; on the landing, there is no profile.
- Trying to detect canton from locale/IP is invasive and violates the "rien ne sort de ton téléphone" promise.
- The paragraphe-mère is canonical MINT voice (central calm, precise, Franco-Swiss neutral). Regional flavor is a post-onboarding reward, not a landing hook.

Locked. No regional variant of the paragraphe-mère. No canton detection on S0.

### D-11 — Zero financial_core / zero services imports

`landing_screen.dart` imports only:
- `package:flutter/material.dart`
- `package:go_router/go_router.dart`
- `package:flutter_gen/gen_l10n/app_localizations.dart`
- `apps/mobile/lib/theme/colors.dart`

**Forbidden imports** (CI-checked in Plan 02):
- anything under `lib/services/financial_core/`
- anything under `lib/services/` except none
- `lib/models/profile*.dart`
- `lib/providers/` (landing is stateless — no provider reads)

### D-12 — Login affordance

**Decision:** no login button on the landing. Returning users tap the MINT wordmark (long-press or single tap on a small caret next to wordmark) which routes to `/auth/login`. Default path for all first-paint users is `/onboarding/intent`.

Rationale: a visible "Login" button on a promise surface invites "start a product flow" framing. Hidden-but-discoverable login preserves calm for first-paint while remaining accessible to returning users. If this proves too hidden in Phase 10.5 (Julien A14 friction pass), reopen.

### D-13 — Translations

Paragraphe-mère must ship in all 6 ARB locales (fr master, en, de, es, it, pt). French is locked per D-01; the other five are authored in Plan 01 with anti-shame audit per locale and reviewed against MINT_IDENTITY.md principles in each language.

CTA, privacy micro-phrase, legal footer: same — all 6 locales, Plan 01 scope.

---

## 3. Deferred Ideas (not in this phase)

- Hero chart, animated score, confidence dial → killed, not deferred. Do not reintroduce post-launch.
- Login button as primary CTA → deferred to Phase 10.5 friction pass verdict.
- Web landing Variante C (the longer split-test variant) → explicitly out of v2.2 scope per LAND-03.
- A/B testing of paragraphe-mère variants → not in v2.2. Variante A is locked.
- Regional paragraphe-mère variants → rejected (D-10).
- Analytics consent banner on first paint → deferred past hero scroll or post-CTA (per S0 audit row #11). The banner still exists in code; the landing just does not render it on first paint. Landing is one screen and does not scroll, so the banner renders only post-CTA on the next route.

---

## 4. Claude's Discretion

- Exact `Spacer` flex ratios can be tuned if golden tests reveal awkward balance on Galaxy A14 (D-06 gives starting values).
- Entry bloom duration can be tuned 200–300ms if 250ms feels too snappy/slow on device (D-08 starting value).
- Wordmark size: use existing asset/style unless it visually fights the paragraph.
- Whether the CTA pill has a hairline border or is fully filled: fully filled is the default; hairline-only is a fallback if fully filled reads too "marketing".
- German translation register: "du" (informal) not "Sie". Italian: "tu". Spanish: "tú". Portuguese: "tu". (Locked — MINT is always informal per CLAUDE.md §6.)

---

## 5. S0 Audit Consumption

Phase 3 `AUDIT_RETRAIT_S0_S5.md §S0` provides a DELETE (11) / KEEP (17) / REPLACE (9) list for the *current* landing. **For Phase 7, this list is informational only** — we are doing a full rebuild, not a trim. The KEEP items (translator cards, quick calc, couple preview, trust bar) are **not** preserved. They belong to the old "feature landing" mental model that Variante A explicitly rejects.

Concretely, the rebuild **deletes all 37 current elements** and replaces them with the 4 surfaces of D-05. Post-count = 4. The `-20%` reduction gate is trivially satisfied (37 → 4 = −89%).

The audit's REPLACE rows (R1–R9) about AAA tokens still apply — the rebuild uses Phase 2 AAA tokens from day 1, so the replacement happens natively (LAND-05).

---

## 6. Candidate paragraphe-mère drafts considered (for record)

The master text is LOCKED at D-01. For completeness, three drafts considered during requirements work (do not re-open):

- **Draft A (LOCKED):** "Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts. Calmement. Sans te vendre quoi que ce soit."
- **Draft B (considered, rejected):** "Mint lit ce que tu signes, traduit ce que tu ne comprends pas, et te dit calmement ce qui compte. Sans rien vendre, sans rien te prendre, sans te presser."  — Rejected: verb "lit" implies document scanning capability, over-promise on day 1.
- **Draft C (considered, rejected, web-reserved):** "Personne n'a intérêt à te dire la vérité sur ton argent. Ni ton assurance, ni ta banque, ni ta caisse, ni même ton employeur. Mint, si. Calmement. Sans rien te vendre." — Rejected for mobile: names institutions, risks adversarial framing, too long (38 words). Reserved for web per LAND-03.

---

## 7. Plans

1. **07-01-PLAN.md** — Paragraphe-mère i18n authoring: author en/de/es/it/pt translations of D-01, D-02, D-03, D-04; run per-locale anti-shame audit; update 6 ARB files; regen l10n.
2. **07-02-PLAN.md** — Landing screen rebuild: delete current `landing_screen.dart` body, reimplement per §2 D-01..D-13; consume AAA tokens; add CI lint for forbidden imports and banned terms; wire route to `/onboarding/intent`.
3. **07-03-PLAN.md** — Golden tests: iPhone 14 Pro + Galaxy A14 goldens; reduced-motion fallback; text-scale 1.3 overflow; AAA contrast assertions via `wcagContrastRatio()`.

---

## 8. Decision coverage matrix

| REQ | Plan | Task | Coverage |
|------|------|------|----------|
| LAND-01 (rebuild, zero imports) | 07-02 | T1+T2 | Full |
| LAND-02 (4 surfaces layout) | 07-02 | T1 | Full |
| LAND-03 (paragraphe-mère text) | 07-01 | T1 | Full (fr master) + T2 (5 translations) |
| LAND-04 (banned terms lint) | 07-02 | T3 | Full |
| LAND-05 (AAA day 1) | 07-02 + 07-03 | T1 + T2 | Full |
| LAND-06 (routes to /onboarding/intent) | 07-02 | T1 | Full |

All 6 requirements covered, each Full.
