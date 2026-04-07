# Requirements: MINT v2.2 La Beauté de Mint (Design v0.2.3)

**Defined:** 2026-04-07
**Core Value:** A user opens MINT and within 3 minutes receives a personalized, surprising insight — then knows exactly what to do next.
**Doctrine:** Mint protège sans juger. Mint prouve sans surjouer. Mint parle peu — mais avec l'intensité juste, du murmure au coup de poing verbal.

**Source documents:**
- `.planning/research/SUMMARY.md` — 6-report synthesis
- `visions/MINT_DESIGN_BRIEF_v0.2.3.md` — governing brief
- `.planning/backlog/STAB-carryover.md` — v2.1 carryover (STAB-17, broken providers)

**Expert challenge already applied** (see PROJECT.md Key Decisions for full rationale):
- Krippendorff α weighted ordinal for L1.6 spec validation, editorial review for iteration
- MintTrameConfiance as single rendering layer everywhere (no dual system with legacy)
- VoiceCursorContract as Phase 0 deliverable
- i18n carve-out for regional microcopy (canton-scoped ARB namespaces)
- Galaxy A14 manual gate this milestone (Android-in-CI deferred to v2.3)
- Précision horlogère cut from Layer 1 (only MTC bloom remains)
- L+O Variante 1 locked: rebuild landing + delete 5 onboarding screens
- Phase 0 two-phase split (P0a unblockers / P0b contracts & audits parallel to L1.1)

---

## v2.2 Requirements (Active)

All 96 requirements below are v2.2 scope. Each maps to exactly one phase (see Traceability table).

### STAB — Stabilisation carryover (v2.1 → v2.2 Phase 1)

- [ ] **STAB-18**: Manual tap-to-render walkthrough on Galaxy A14 by Julien. Fill `AUDIT_TAP_RENDER.md` (scaffold from v2.1), sign bottom block, triage any FAIL into follow-up work. Gates TestFlight.
- [ ] **STAB-19**: Wire 4 broken providers in `mint_home_screen.dart` (`MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`) in `app.dart` MultiProvider. Remove the try/catch silent fallback at lines 124 and 638 — registering alone is insufficient.
- [ ] **STAB-20**: `chiffre_choc` → `premier_eclairage` rename sweep across 719 occurrences in 174 files (5 Dart filenames via `git mv`, 2 Python filenames, 6 ARB × ~25 keys, GoRouter routes, class names, analytics events, OpenAPI endpoint, test files). CI grep gate returns 0 in `lib/`, `app/`, `l10n/` (allowed in `.planning/`, `docs/archive/`).
- [ ] **STAB-21**: Fix `chiffre_choc_screen` coach-path split-exit bug — arrow button in TextField must call `setMiniOnboardingCompleted(true)` before routing to `/coach/chat`. Moot if the screen is deleted in L1.8, but must be fixed if deletion slips.

### PERF — Galaxy A14 performance baseline & gates

- [ ] **PERF-01**: Galaxy A14 cold start baseline captured (`flutter run --profile -d <A14_id> --trace-startup`), documented in `.planning/perf/A14_BASELINE.md`. Target `timeToFirstFrameMicros < 2500ms`.
- [ ] **PERF-02**: Scroll FPS baseline on Aujourd'hui home (10s sustained scroll) captured. Target median ≥ 55, p95 ≥ 50.
- [ ] **PERF-03**: MTC bloom frame budget captured (250ms bloom = 16 frames at 60fps). Target 0 dropped frames.
- [ ] **PERF-04**: A14 manual gate protocol documented: Julien reruns cold start + scroll + bloom before every L1.2a/b/3 merge. No automated CI gate this milestone.
- [ ] **PERF-05**: `BloomStrategy` enum enforced via custom lint — no MTC instantiation without explicit strategy. Default `onlyIfTopOfList` in feed contexts, `firstAppearance` in standalone.

### CONTRACT — VoiceCursorContract + Profile field + codegen

- [ ] **CONTRACT-01**: `tools/contracts/voice_cursor.json` source of truth created with 5-level enum (N1-N5), 3-gravity enum (G1-G3), relation enum (new/established/intimate), routing matrix, precedence cascade ordering, sensitive topics list, narrator wall exemption list.
- [ ] **CONTRACT-02**: Dart codegen to `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` via custom script. Committed (offline-safe).
- [ ] **CONTRACT-03**: Python codegen to `services/backend/app/schemas/voice_cursor.py` via `datamodel-code-generator >= 0.25`. Committed (offline-safe).
- [ ] **CONTRACT-04**: CI drift guard — regenerate both on PR, `git diff --exit-code`. Red build on drift.
- [ ] **CONTRACT-05**: `Profile` voice cursor fields added (3 fields, 1 migration): (a) `voiceCursorPreference: Literal['soft','direct','unfiltered'] = 'direct'`, (b) `n5IssuedThisWeek: int = 0` (rolling 7-day counter consumed by VOICE-09 server gate), (c) `fragileModeEnteredAt: Optional[datetime] = None` (consumed by VOICE-10 auto-fragility detector). All in `services/backend/app/schemas/profile.py` Pydantic v2 + `apps/mobile/lib/models/coach_profile.dart` + nullable SQLAlchemy columns + read-time migration. Audit fix A1 — adding all 3 in Phase 2 prevents Phase 11 schema-discovery block.
- [ ] **CONTRACT-06**: `resolveLevel(gravity, relation, preference, sensitiveFlag, fragileFlag, n5Budget) → N1..N5` pure function in VoiceCursorContract with ≥ 80 unit tests covering matrix + precedence cascade + edges.

### AUDIT — Pre-migration audits (gate L1.1 + L1.2b)

- [ ] **AUDIT-01**: `AUDIT_CONFIDENCE_SEMANTICS.md` — classify all ~40 confidence-rendering hits into 3 categories (`extraction-confidence`, `data-freshness`, `calculation-confidence`). Decide per category: MTC absorbs / sibling component / stays untouched. Gates L1.2b scope.
- [ ] **AUDIT-02**: `AUDIT_CONTRAST_MATRIX.md` — enumerate every text/background token pair across S0-S5, compute WCAG contrast ratios, classify AAA pass / AA-only / fail. Identifies the 6 token upgrades for AESTH-04.
- [ ] **AUDIT-03**: Audit du retrait on S0-S5 produces an explicit DELETE / KEEP list for visual elements (-20% target). Feeds L1.2b migration and L1.3 microtypographie on day 1.

### MTC — MintTrameConfiance component + 11-surface migration

- [ ] **MTC-01**: `MintTrameConfiance` Flutter component v1 at `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart`. Three constructors: `.inline()`, `.detail()`, `.audio()`.
- [ ] **MTC-02**: `MTC.Empty(missingAxis)` state — renders below-confidence-floor projections as a "missing data" prompt, never as a faded number. Linear hide-when-low pattern.
- [ ] **MTC-03**: Bloom animation 250ms ease-out, opacity 0→1, scale 0.96→1, honors `MediaQuery.disableAnimations` (WCAG 2.3.3 — fallback to 50ms opacity-only).
- [ ] **MTC-04**: `BloomStrategy` enum: `firstAppearance`, `onlyIfTopOfList`, `never`. Feed contexts (ContextualCard ranked home) default `onlyIfTopOfList` with 60ms stagger.
- [ ] **MTC-05**: `oneLineConfidenceSummary(EnhancedConfidence) → String` pure function — surfaces the WEAKEST axis only, not all four. 24 ARB strings (4 weakest-axis variants × 6 languages).
- [ ] **MTC-06**: `SemanticsService.announce()` fires exactly once on state change, never on rebuild. TalkBack 13 + VoiceOver verified.
- [ ] **MTC-07**: Hypotheses footer slot (VZ pattern) — 3-line max, visible at rest under the MTC. Renders the top 3 user-editable hypotheses behind the rendered number.
- [ ] **MTC-08**: No public `score: double` getter on MTC. Compliance: prevents sorting / ranking via the component API.
- [ ] **MTC-09**: S4 migration (`response_card_widget.dart`) — first consumer, ships with L1.2a. Patrol golden test + semantic announce test.
- [ ] **MTC-10**: MTC migration to 11 rendering surfaces (as enumerated in ARCHITECTURE §B.1): `confidence_score_card`, `confidence_banner`, `trajectory_view`, `futur_projection_card`, `coach_briefing_card`, `retirement_hero_zone`, `indicatif_banner`, `narrative_header`, `retirement_dashboard_screen`, `cockpit_detail_screen`, `confidence_blocks_bar`. Each PR includes swap + test + golden + A14 verify checklist.
- [ ] **MTC-11**: 7 logic-gate consumers (that read `confidence.combined` int only) remain UNTOUCHED. Explicit DO-NOT-MIGRATE list committed.
- [ ] **MTC-12**: Pre-migration lcov baseline captured. Post-migration L1.2b PR gate requires MTC-equivalent tests ≥ pre-migration test count. Silent coverage drop = red build.

### AESTH — Aesthetic / microtypographie / AAA palette

- [ ] **AESTH-01**: 4pt baseline grid snap rule enforced across S0-S5 (Spiekermann). Custom lint or manual review.
- [ ] **AESTH-02**: Line length 45-75 characters, never > 80. 3 heading levels max per screen. Tested on Galaxy A14 screen width.
- [ ] **AESTH-03**: Demote headline numbers to body weight on S4 (Aesop rule: sentence carries rhythm, not the number).
- [ ] **AESTH-04**: 6 new AAA tokens added to `colors.dart`: `textSecondaryAaa` (#595960), `textMutedAaa` (#5C5C61), `successAaa` (#0F5E28), `warningAaa` (#8C3F06), `errorAaa` (#A52121), `infoAaa` (#004FA3). Brand sign-off by Julien required before merge.
- [ ] **AESTH-05**: S0-S5 text surfaces migrated to AAA tokens. Pastels (saugeClaire, bleuAir, pecheDouce, corailDiscret, porcelaine) = background-only, never information-bearing text in S0-S5.
- [ ] **AESTH-06**: One-color-one-meaning rule — single desaturated amber token (`warningAaa`) for "verifiable fact requiring attention". All other semantic colors demoted to neutral on S0-S5.
- [ ] **AESTH-07**: MUJI 4-line grammar for S4 response cards: (1) what this is, (2) what you're doing now, (3) what happens without change [MTC inline here], (4) what you could do next. No chrome.
- [ ] **AESTH-08**: L1.1 -20% visual element reduction target achieved per surface (S0-S5), evidenced by before/after screenshot + element count in audit report.

### VOICE — Curseur d'intensité spec + rewrite + validation

- [ ] **VOICE-01**: `docs/VOICE_CURSOR_SPEC.md` written. Contains: 5-level definitions N1-N5, gravity × relation routing matrix, precedence cascade ordering (sensitivity guard → fragility cap → N5 budget → gravity floor → preference cap → matrix default), narrator wall exemption list (settings, error toasts, network failures, legal disclaimers), sentence-subject rule ("MINT n'a pas pu"), pacing/silence rules per level.
- [ ] **VOICE-02**: 50 reference phrases written (10 per level) — frozen pre-validation, committed before any tester sees them. No re-rolling after validation starts.
- [ ] **VOICE-03**: Anti-example per level documented — what N4 is NOT, what N5 is NOT. Prevents post-validation drift.
- [ ] **VOICE-04**: 30 most-used coach phrases audited and rewritten per spec (extracted from `claude_coach_service.py` + ARB files 6 languages). Before/after documented in `docs/VOICE_PASS_LAYER1.md`.
- [ ] **VOICE-05**: Krippendorff α validation protocol: 15 testers × 50 reference phrase set × blind classification N1-N5. Weighted ordinal IRR. Overall α ≥ 0.67, per-level N4 and N5 α ≥ 0.67 separately. Report committed to `docs/VOICE_CURSOR_TEST.md`.
- [ ] **VOICE-06**: Generation-side reverse-Krippendorff test — 10 trigger contexts sent to Claude at N4 via system prompt, 10 generated outputs rated blind by same testers. Pass: ≥ 70% classified as N4. Fail: system prompt is tone-locked, fix before ship. This is the anti-tone-locking gate.
- [ ] **VOICE-07**: Few-shot tone-locking mitigation — 3 verbatim N4 examples + 3 N5 examples embedded in coach system prompt. Token cost delta documented in `docs/COACH_COST_DELTA.md` with explicit decision logged: accept / mitigate via Anthropic prompt caching / reduce few-shot count. Audit fix B5 — production cost surface needs an owner before Phase 11 ships.
- [ ] **VOICE-08**: ComplianceGuard extended with 50 adversarial N4/N5 phrases testing for prescription drift (imperative-without-hedge pattern, banned terms at high register). Red build on any ComplianceGuard regression.
- [ ] **VOICE-09**: N5 server-side hard gate — `Profile.n5IssuedThisWeek` rolling 7-day counter, backend auto-downgrades N5 → N4 when ≥ 1. Editorial rule alone is insufficient.
- [ ] **VOICE-10**: Auto-fragility detector — ≥ 3 G2/G3 events in 14 days auto-enters fragile mode (N3 cap, 30 days), no self-declaration required. Implicit detection logged to biography with user-visible "MINT a remarqué que..." disclosure.
- [ ] **VOICE-11**: Context bleeding prevention — system prompt rebuilt fresh each turn, explicit register-reset clause, `[N5]` tag in conversation history, visual breath separator (150ms pause) on G3→G1 transitions.
- [ ] **VOICE-12**: Narrator wall enforced — settings, error toasts, network failures, legal disclaimers, onboarding flow system text NEVER pass through voice cursor routing. Exemption list in VoiceCursorContract, enforced at call site.
- [ ] **VOICE-13**: User "Ton" setting in `intent_screen.dart` (first launch) + `ProfileDrawer` (settings). 3-option chooser: `soft` / `direct` (default) / `unfiltered`. Writes `Profile.voiceCursorPreference` via API. Mot "curseur" reste interne; UX label = "Ton".
- [ ] **VOICE-14**: Editorial review commitment post-Krippendorff — every new ARB phrase added post-L1.6b ships with `@meta level:` annotation, CI grep gate rejects additions without it. Prevents editorial drift.

### ALERT — MintAlertObject (S5) with typed API

- [ ] **ALERT-01**: `apps/mobile/lib/widgets/mint_alert_object.dart` created. API: `MintAlertObject({required Gravity gravity, required String fact, required String cause, required String nextMoment})`. Compiler-enforced; no arbitrary `String message` accepted.
- [ ] **ALERT-02**: MINT is always the sentence subject ("MINT n'a pas pu", never "Tu n'as pas pu"). Stripe grammar pattern. Enforced by code review + ARB pattern lint.
- [ ] **ALERT-03**: G2 rendering = direct grammar in calm register (soulignement direct). G3 rendering = grammatical break + priority float (rupture grammaticale, couleur, mouvement subtil, ton direct, action immédiate).
- [ ] **ALERT-04**: G3 priority float wired to `card_ranking_service.dart` — 1-line change that floats G3 MintAlertObject to top of ContextualCard feed.
- [ ] **ALERT-05**: G3 persists until acknowledged — no auto-dismiss. COGA cognitive accessibility pattern. Acknowledgement stored in biography.
- [ ] **ALERT-06**: Imports `voice_cursor_contract.g.dart` for gravity → N-level routing. No hardcoded mapping.
- [ ] **ALERT-07**: Not a coach tool — MintAlertObject is fed by `AnticipationProvider` / `NudgeEngine` / `ProactiveTriggerService` (rule-based v2.0 plumbing), never by LLM output. Compliance: no LLM-generated alerts.
- [ ] **ALERT-08**: `SemanticsService.announce()` on G2 → G3 transitions. `liveRegion: true` semantics.
- [ ] **ALERT-09**: Patrol integration tests — 6 golden states (G2/G3 × soft/direct/unfiltered preference, + sensitive-topic guard, + fragile-mode guard).
- [ ] **ALERT-10**: G3 politique (Stiegler) — default information-only, external action API prepared but disabled until partner routing signed. Documented in component docstring.

### TRUST — Hypotheses footer + sentence-subject rule + hide-when-low

- [ ] **TRUST-01**: Hypotheses footer component rendered under every projection card that uses MTC. 3-line max, visible at rest. Lists the top 3 user-editable hypotheses behind the number.
- [ ] **TRUST-02**: Sentence-subject rule enforced in all v2.2-touched ARB strings: MINT is the subject of negative statements ("MINT n'a pas pu", "MINT ne voit pas encore", never "Tu n'as pas pu"). Custom ARB lint.
- [ ] **TRUST-03**: Confidence floor policy — any projection below confidence threshold renders `MTC.Empty(missingAxis)` prompting user action, never a faded number with a confidence badge. Applied to all 11 MTC migration surfaces.

### REGIONAL — Voix régionale VS/ZH/TI + backend dual-system kill

- [ ] **REGIONAL-01**: 3 ARB files created: `app_regional_vs.arb`, `app_regional_zh.arb`, `app_regional_ti.arb`. ~30 microcopy keys per canton = 90 strings total. Base languages only (fr-CH for VS, de-CH for ZH, it-CH for TI).
- [ ] **REGIONAL-02**: Second `l10n_regional.yaml` gen_l10n config added. Custom `LocalizationsDelegate` (~40 LOC) resolves `(canton, base_lang)` lookup with fallback to main ARB.
- [ ] **REGIONAL-03**: `RegionalVoiceService.forCanton()` extended to consume the new delegate. No legacy constants.
- [ ] **REGIONAL-04**: `regional_microcopy_codegen.py` replaces hand-coded `REGIONAL_MAP` (line 58) and `_REGIONAL_IDENTITY` (line 133) in `services/backend/app/services/claude_coach_service.py`. Legacy constants DELETED in same MR (zero-debt rule).
- [ ] **REGIONAL-05**: CI guard — `git grep 'REGIONAL_MAP\s*=' services/backend/` must return 0. Red build on legacy regression.
- [ ] **REGIONAL-06**: 3 native validators recruited (1 VS, 1 ZH, 1 TI) and named in `docs/VOICE_PASS_LAYER1.md`. Each signs off on their 30 strings before merge.
- [ ] **REGIONAL-07**: Regional microcopy **overrides**, never **introduces** — every regional key has a base-language sibling in the main ARB. Lint enforced.

### LAND — Landing v2 (S0) rebuild

- [ ] **LAND-01**: `apps/mobile/lib/screens/landing_screen.dart` rebuilt. Zero `financial_core` imports (assertive compile-time check via lint). Zero input fields. Zero projected numbers. Zero retirement vocabulary.
- [ ] **LAND-02**: Layout: one paragraphe-mère (~30 words), one primary CTA pill ("Continuer (sans compte)"), one privacy micro-phrase ("Rien ne sort de ton téléphone tant que tu ne le décides pas."), one legal footer line.
- [ ] **LAND-03**: Paragraphe-mère = Variante A: "Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts. Calmement. Sans te vendre quoi que ce soit." Variante C reserved as split test for web landing only (out of v2.2 mobile scope).
- [ ] **LAND-04**: Banned terms check in LAND-01..03: "Commencer", "Démarrer", "Voir mon chiffre", "Ton chiffre en X secondes", "chiffre choc". Lint + manual review.
- [ ] **LAND-05**: Ships with AAA from day 1 using AESTH-04 tokens. 7:1 on every text surface.
- [ ] **LAND-06**: Routes directly to `/onboarding/intent` (not `/onboarding/promise`, not `/onboarding/quick-start`).

### ONB — Onboarding v2 (delete 5 screens, wire intent → chat)

- [ ] **ONB-01**: `quick_start_screen.dart` + route `/onboarding/quick-start` deleted.
- [ ] **ONB-02**: `chiffre_choc_screen.dart` + route `/onboarding/chiffre-choc` deleted.
- [ ] **ONB-03**: `instant_chiffre_choc_screen.dart` + route `/chiffre-choc-instant` deleted.
- [ ] **ONB-04**: `promise_screen.dart` + route `/onboarding/promise` deleted. Age segmentation violation (CLAUDE.md §1) resolved by deletion.
- [ ] **ONB-05**: `plan_screen.dart` + route `/onboarding/plan` deleted. Façade-sans-câblage (`_stepsForIntent` ignores argument) resolved by deletion.
- [ ] **ONB-06**: `intent_screen.dart` rewired — `_isFromOnboarding == true` branch routes to `/coach/chat` with chip payload, not to `/onboarding/quick-start`. `chiffre_choc_selector` import removed.
- [ ] **ONB-07**: `OnboardingProvider` deprecated. State migrated to `CoachProfileProvider` + `CapMemoryStore`. `app.dart` MultiProvider entry removed.
- [ ] **ONB-08**: `data_block_enrichment_screen.dart` preserved (JIT deep-link tool, not part of the onboarding pipeline). Verified by GoRouter reachability test.
- [ ] **ONB-09**: `app.dart` GoRouter guards updated — post-login users never route into deleted screens. Redirect shims for any external deep links.
- [ ] **ONB-10**: E2E golden path test: `S0 landing → /onboarding/intent (1 chip) → /coach/chat`. Screens-before-first-insight = 2. Friction < 20 seconds measured.

### ACCESS — WCAG 2.1 AAA on S0-S5 + live test sessions + TalkBack 13

- [ ] **ACCESS-01**: Recruitment kickoff day 1 of Phase 0: first emails sent to SBV-FSA (1 malvoyant·e), ASPEDAH (1 ADHD), Caritas (1 français-seconde-langue). Budget CHF 800-2'000.
- [ ] **ACCESS-02**: 3 live accessibility test sessions completed during milestone. Compte-rendu committed to `docs/ACCESSIBILITY_TEST_LAYER1.md`.
- [ ] **ACCESS-03**: WCAG 2.1 AA floor bloquant CI on every touched surface (not just S0-S5). `flutter_test` `meetsGuideline(androidTapTargetGuideline, textContrastGuideline)`.
- [ ] **ACCESS-04**: WCAG 2.1 AAA cible on S0-S5. 7:1 contrast on every text/icon pair. Pure-Dart 30-LOC AAA contrast helper in `test/accessibility/`.
- [ ] **ACCESS-05**: TalkBack 13 widget trap sweep on S0-S5 — fix: CustomPaint (add `semanticsBuilder`), IconButton without tooltip (add), InkWell on Container (replace with `InkResponse` or add Semantics), AnimatedSwitcher (add key + Semantics), TextField obscureText toggle (add Semantics label), DropdownMenu (add Semantics on chooser for VOICE-13 "Ton" setting).
- [ ] **ACCESS-06**: Flesch-Kincaid French reading level CI gate on S0-S5 ARB strings. Target B1 (lower secondary). Jargon tap-to-define inline expansion for unavoidable terms ("rente vieillesse LPP").
- [ ] **ACCESS-07**: Reduced-motion handling verified across MTC bloom, coach typing indicator, onboarding transitions. `MediaQuery.disableAnimations` fallback to 50ms opacity-only or skip.
- [ ] **ACCESS-08**: `liveRegion: true` semantics on coach_message_bubble incoming messages. Screen reader hears new coach output without focus shift.
- [ ] **ACCESS-09**: AAA honesty gate — if tester recruitment fails by end of L1.1, descope to "AA bloquant CI + AAA aspirational with known gaps documented". False AAA claim is worse than honest AA. Decision committed to `docs/ACCESSIBILITY_TEST_LAYER1.md`.

---

## Out of Scope (explicit boundaries for v2.2)

### Deferred to v2.3+

| Feature | Reason |
|---------|--------|
| Android-in-CI automation (Firebase Test Lab) | Infra investment out of v2.2 budget. Manual Galaxy A14 gate this milestone. Investigation documented in STACK.md. |
| MintColors AAA tokens applied outside S0-S5 | Surgical migration this milestone. Rest of app touched opportunistically in future milestones. |
| 12 orphan GoRouter routes from v2.1 AUDIT_ORPHAN_ROUTES.md | Not touched unless a chantier lands on that code. |
| ~65 NEEDS-VERIFY try/except blocks from v2.1 AUDIT_SWALLOWED_ERRORS.md | Best-effort by grep pattern, address opportunistically. |
| Voix régionale beyond VS/ZH/TI | Additional cantons in v2.3. |
| Access for All Swiss certification (Zugang für alle) | CHF 8-18k, 6-8w lead. Decide post-v2.2 based on live session results. |
| Full app AAA migration | Too big. S0-S5 only this milestone. |
| Multi-LLM routing | Phase 3 roadmap. |
| Voice AI surfaces | Phase 3 roadmap. |
| Lock Screen widget | Layer 2 prototype, not shipped. |

### Anti-features (do NOT build — rejection rationale)

| Anti-feature | Rejection rationale |
|---|---|
| Skin/color shift on voice cursor levels (Cleo) | Visuel reste calme — brief doctrine, non-negotiable |
| MTC bloom firing on every card in a feed simultaneously | A14 perf drop + vestibular accessibility. `BloomStrategy.onlyIfTopOfList` default |
| MintAlertObject with free-form `String message` | Typed API enforces grammar at the component level |
| Multiple accent colors as hierarchy on S0-S5 | One color, one meaning (Spiekermann) |
| Quick-calc on landing | The conversation IS the first value — Headspace + VZ pattern |
| Hardcoded 4-step plan on any onboarding screen | Façade-sans-câblage. Delete plan_screen, coach chat IS the plan |
| "ADHD mode" toggle | Fix the default. Adding a mode confesses the default is bad |
| "Curseur" exposed to users | Internal term only. UX label is "Ton" |
| Comparaison sociale ("top X% des Suisses") | Banned CLAUDE.md §6 |
| "Chiffre choc" wording anywhere | Banned doctrine, replaced by "premier éclairage" |

---

## Traceability

Phases assigned by `gsd-roadmapper` 2026-04-07, then expert-audit patched (Phase 8 split into 8a/8b, AESTH-04 moved to Phase 2, CONTRACT-05 extended to 3 fields). 96/96 requirements mapped to 13 phases (no orphans, no duplicates).

| Requirement | Phase | Status |
|-------------|-------|--------|
| STAB-18 | Phase 1 | Pending |
| STAB-19 | Phase 1 | Pending |
| STAB-20 | Phase 1 | Pending |
| STAB-21 | Phase 1 | Pending |
| PERF-01 | Phase 1 | Pending |
| PERF-02 | Phase 1 | Pending |
| PERF-03 | Phase 1 | Pending |
| PERF-04 | Phase 1 | Pending |
| PERF-05 | Phase 12 | Pending |
| CONTRACT-01 | Phase 2 | Pending |
| CONTRACT-02 | Phase 2 | Pending |
| CONTRACT-03 | Phase 2 | Pending |
| CONTRACT-04 | Phase 2 | Pending |
| CONTRACT-05 | Phase 2 | Pending |
| CONTRACT-06 | Phase 2 | Pending |
| AUDIT-01 | Phase 2 | Pending |
| AUDIT-02 | Phase 2 | Pending |
| AUDIT-03 | Phase 3 | Pending |
| MTC-01 | Phase 4 | Pending |
| MTC-02 | Phase 4 | Pending |
| MTC-03 | Phase 4 | Pending |
| MTC-04 | Phase 4 | Pending |
| MTC-05 | Phase 4 | Pending |
| MTC-06 | Phase 4 | Pending |
| MTC-07 | Phase 4 | Pending |
| MTC-08 | Phase 4 | Pending |
| MTC-09 | Phase 4 | Pending |
| MTC-10 | Phase 8a | Pending |
| MTC-11 | Phase 8a | Pending |
| MTC-12 | Phase 8a | Pending |
| AESTH-01 | Phase 8b | Pending |
| AESTH-02 | Phase 8b | Pending |
| AESTH-03 | Phase 8b | Pending |
| AESTH-04 | Phase 2 | Pending (moved from Phase 8 per audit fix C1) |
| AESTH-05 | Phase 8b | Pending |
| AESTH-06 | Phase 8b | Pending |
| AESTH-07 | Phase 8b | Pending |
| AESTH-08 | Phase 3 | Pending |
| VOICE-01 | Phase 5 | Pending |
| VOICE-02 | Phase 5 | Pending |
| VOICE-03 | Phase 5 | Pending |
| VOICE-04 | Phase 11 | Pending |
| VOICE-05 | Phase 11 | Pending |
| VOICE-06 | Phase 11 | Pending |
| VOICE-07 | Phase 5 | Pending |
| VOICE-08 | Phase 11 | Pending |
| VOICE-09 | Phase 11 | Pending |
| VOICE-10 | Phase 11 | Pending |
| VOICE-11 | Phase 5 | Pending |
| VOICE-12 | Phase 5 | Pending |
| VOICE-13 | Phase 12 | Pending |
| VOICE-14 | Phase 11 | Pending |
| ALERT-01 | Phase 9 | Pending |
| ALERT-02 | Phase 9 | Pending |
| ALERT-03 | Phase 9 | Pending |
| ALERT-04 | Phase 9 | Pending |
| ALERT-05 | Phase 9 | Pending |
| ALERT-06 | Phase 9 | Pending |
| ALERT-07 | Phase 9 | Pending |
| ALERT-08 | Phase 9 | Pending |
| ALERT-09 | Phase 9 | Pending |
| ALERT-10 | Phase 9 | Pending |
| TRUST-01 | Phase 4 | Pending |
| TRUST-02 | Phase 8a | Pending |
| TRUST-03 | Phase 4 | Pending |
| REGIONAL-01 | Phase 6 | Pending |
| REGIONAL-02 | Phase 6 | Pending |
| REGIONAL-03 | Phase 6 | Pending |
| REGIONAL-04 | Phase 6 | Pending |
| REGIONAL-05 | Phase 6 | Pending |
| REGIONAL-06 | Phase 6 | Pending |
| REGIONAL-07 | Phase 6 | Pending |
| LAND-01 | Phase 7 | Pending |
| LAND-02 | Phase 7 | Pending |
| LAND-03 | Phase 7 | Pending |
| LAND-04 | Phase 7 | Pending |
| LAND-05 | Phase 7 | Pending |
| LAND-06 | Phase 7 | Pending |
| ONB-01 | Phase 10 | Pending |
| ONB-02 | Phase 10 | Pending |
| ONB-03 | Phase 10 | Pending |
| ONB-04 | Phase 10 | Pending |
| ONB-05 | Phase 10 | Pending |
| ONB-06 | Phase 10 | Pending |
| ONB-07 | Phase 10 | Pending |
| ONB-08 | Phase 10 | Pending |
| ONB-09 | Phase 10 | Pending |
| ONB-10 | Phase 10 | Pending |
| ACCESS-01 | Phase 1 | Pending |
| ACCESS-02 | Phase 8b | Pending |
| ACCESS-03 | Phase 12 | Pending |
| ACCESS-04 | Phase 8b | Pending |
| ACCESS-05 | Phase 9 | Pending |
| ACCESS-06 | Phase 10 | Pending |
| ACCESS-07 | Phase 8b | Pending |
| ACCESS-08 | Phase 8b | Pending |
| ACCESS-09 | Phase 8b | Pending |

**Coverage:**
- v2.2 requirements: **96 total**
- Mapped to phases: **96** ✓
- Unmapped: **0**
- Duplicates: **0**

---

## Open decision gates (answer asynchronously, block specific chantiers only)

These do NOT block milestone start. They gate specific chantiers and each has an expert-recommended default.

| # | Question | Blocks | Expert default |
|---|----------|--------|----------------|
| 1 | VZ app teardown (5 screenshots from Julien) before L1.2a hypotheses footer API finalized | MTC-07 API lock (Phase 4) | Yes, 1 hour. Do before L1.2a coding starts. |
| 2 | Brand palette sign-off — accept darkening 6 tokens ~15% for AAA on S0-S5 | AESTH-04, AESTH-05 (Phase 8) | Accept. Delta imperceptible to most users; EAA exposure outweighs aesthetic cost. |
| 3 | Access for All Swiss audit (CHF 8-18k, 6-8w lead) this milestone? | v2.2 ship positioning only | Skip for v2.2. Schedule v2.3 if results merit. |
| 4 | Focus mode (ambient dim at N4/N5, Reichenstein pattern) — stretch goal or must-ship? | L1.6 scope (Phase 11/12) | Stretch. Promote to must-ship only if A14 baseline (PERF-01) shows headroom. |

---

*Requirements defined: 2026-04-07*
*Last updated: 2026-04-07 after roadmapper mapped 96/96 REQs to 12 phases*
