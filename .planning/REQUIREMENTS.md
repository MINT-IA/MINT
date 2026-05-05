# Requirements: MINT v2.10 — Le Premier Éclairage (Cleo-grade)

**Defined:** 2026-05-05
**Roadmap:** 2026-05-05 (revised post-panel)
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça.

## Panel Revisions Log (2026-05-05, 5-expert audit)

5 specialists audited the v2.10 plan against the codebase. 4 APPROVE-WITH-CHANGES + 1 REJECT (timeline only). 8 revisions integrated:

| # | Revision | Source | Applied to |
|---|---|---|---|
| 1 | ECL-01 reformulated as conditional CHF range (no absolute) | 3-piliers actuarial (LSFin art. 8/11/12) | ECL-01 |
| 2 | ECL-05 added — LSFin disclaimer pre-card non-dismissible | 3-piliers actuarial (LSFin art. 8 al. 1 lit. b) | ECL-05 (NEW) |
| 3 | COMP-01 banned terms expanded (+8 terms) | 3-piliers actuarial | ECL-04 (inline) |
| 4 | Archetypes swapped — drop lauren_expat_us + sarah_indep, add couple_acheteurs_lausanne + jeune_diplome_zurich + cadre_40_55_lpp_rachat | Swiss-fintech strategist | WALK-02 + WALK-02b |
| 5 | ANON-05 reduced 2-3 turns → **1-2 turns** before insight | Cleo-school PM | ANON-05 |
| 6 | ANON-08 added — 3 chip-suggestions sous input (life-events) | Cleo-school PM | ANON-08 (NEW) |
| 7 | Phase 71 retargets `anonymous_intent_screen.dart` (260L, the felt-pills) NOT `anonymous_chat_screen.dart` (939L) | Codebase archeologist | ROADMAP.md Phase 71 |
| 8 | Phase 74 creates new `walker_premier_eclairage.sh` + image-diff tool ; not extension of `walker_audit_tap_render.sh` (regex rejects new archetypes + scope is internal-tabs walker) | Codebase archeologist | ROADMAP.md Phase 74 (effort 2.0d → 3.5-4.0d) |

**Timeline reality check (adversarial cynic):** 11.5d planned × 1.85 multiplier = ~21d effort + 5-7d Apple TestFlight latency = **5-6 weeks wall-clock** (not 2). Phase 70 split into 70a (lefthook+ARB blocking) + 70b (PR triage parallel to 71). Parallelize 72+73. Add Phase 74.5 device-smoke obligatoire (0.5d) before 75. Brand line decision deferred to Phase 73 design panel (3 candidates: « L'argent, en clair. » mockup vs « Ce que ta caisse de pension ne t'expliquera jamais. » vs « La finance suisse, sans les angles morts. »).

**Default coach opener (Cleo-school panel-proposed) :** « Salut. Avant de te montrer un truc utile sur ta vie financière en Suisse, dis-moi : c'est quoi le sujet qui te trotte en tête en ce moment — un emploi, un logement, ta LPP, ou autre chose ? »

## v2.10 Requirements (active scope)

Periphery serré : 4 surfaces utilisateur + 1 gate walker + hygiène repo. Pas plus.

### Landing v3 (éditorial)

- [ ] **LAND-01**: User opens MINT app and sees a single editorial hero phrase « L'argent, en clair. » in Fraunces serif italic.
- [ ] **LAND-02**: User reads sub-title « Ta Suisse financière, traduite. » in Inter Regular below the hero phrase.
- [ ] **LAND-03**: User sees the MINT wordmark in the top-left corner, sans-serif compact, no exaggerated letterSpacing.
- [ ] **LAND-04**: User taps a single primary CTA « Commencer → » styled as `RoundedRectangleBorder(14px)`, black ink, white text.
- [ ] **LAND-05**: User can tap a secondary link « Déjà là ? Se connecter » placed under the primary CTA.
- [ ] **LAND-06**: User sees a cream background (`MintColors.warmWhite` or `porcelaineHero`) with zero chrome (no card, no shadow, no decorative gradient).
- [ ] **LAND-07**: User tapping « Commencer » lands on `/anonymous/chat` ; tapping « Se connecter » lands on `/auth/login` with `?redirect=` preserved when applicable.

### Anonymous Chat (Cleo-grade)

- [ ] **ANON-01**: User does not see the legacy 6 felt-state pills (« Je paye, je signe, mais je comprends pas tout », etc.) — pills layer is removed entirely.
- [ ] **ANON-02**: User lands on a chat-first surface with empty input field and exactly one coach opener message visible.
- [ ] **ANON-03**: Coach opener is one short concrete question in Cleo voice (adult, clear, witty without joking) — no menu of phrases.
- [ ] **ANON-04**: Each user reply triggers at most one coach question per turn (no question stacking, no multi-bullet answers).
- [ ] **ANON-05**: Within **1-2 turns** the coach delivers the Premier Éclairage insight payload (ECL-01). Cleo-school panel evidence: Cleo never imposed >1 turn before first insight ; 3-msg friction = drop-off.
- [ ] **ANON-08**: Below the empty input field, the user sees three short chip-suggestions (`« Premier emploi »`, `« Acheter un appart »`, `« Comprendre ma LPP »`) — life-event prompts to break blank-canvas paralysis. Tap = pre-fill input, user can edit or send. NOT a covering pills layer.
- [ ] **ANON-06**: User killing the app and reopening within 7 days resumes the same conversation (PR-A AnonymousChatPersistence — already shipped via #480).
- [ ] **ANON-07**: User registering an account triggers `clear()` of the anonymous transcript (consent boundary — already shipped via #482).

### Premier Éclairage rendering

- [ ] **ECL-01**: Coach delivers a single insight as a hero card in chat with a **conditional CHF range** (`« jusqu'à ~CHF X / an pourrait être en jeu, selon ton canton et ton taux marginal »`) — never an absolute figure for an anonymous (no-KYC) user. Default insight = unused 3a fiscal margin (plafond OPP3 art. 7 = CHF 7'258 salarié, ~CHF 1'500-2'500 économie d'impôt selon canton/taux). Includes a one-line « pourquoi ça compte » + soft account-creation hint.
- [ ] **ECL-02**: Account-creation hint renders as a tappable link (not a modal), copy = « Crée ton compte pour suivre ça » or equivalent that does not push.
- [ ] **ECL-03**: Backend prompt for the anonymous tier is `anonymous_eclairage_prompt.py` (PR #481 — currently DRAFT, must be merged in Phase 70). No other prompt is used in the anonymous path.
- [ ] **ECL-04**: Coach output contains zero LSFin banned terms — list expanded post-3-piliers panel: original 7 (« garantit / garantito / optimal / parfait / certain / assuré / sans risque ») PLUS « idéal », « il faut » (prescriptif art. 3 al. 3), « vous économiserez / tu économises » (futur certain de gain art. 12), « rentable », « profiter de », « opportunité » (incitation décision FINMA Circ. 2013/8 marg. 23), « sûr », « avantage fiscal seul » (without `pourrait`). Verified via `check_banned_terms` MCP at request time.
- [ ] **ECL-05**: Before the first coach message, the user sees a persistent system bubble carrying the LSFin art. 8 disclaimer: « Information éducative basée sur le droit suisse en vigueur. Ce n'est pas un conseil financier personnalisé — pour ta situation, parles-en à un·e spécialiste. » Non-dismissible until ECL-01 fires.

### Walker E2E + golden (4 archetypes)

- [ ] **WALK-01**: `walker_audit_tap_render.sh --no-dry-run --archetype <X>` runs end-to-end on iPhone 17 simulator from cold-launch to ECL-01 insight render.
- [ ] **WALK-02**: Walker exit code is `0` for archetypes (Swiss-fintech panel revision — drop niche FATCA/indep, add CH-PMF segments) : `julien_swiss` (cadre, salarié), `couple_acheteurs_lausanne` (LPP-rachat + 3a + nantissement, le moment fiscal CH), `jeune_diplome_zurich` (premier salaire, segment Yuh-killer), `cadre_40_55_lpp_rachat` (cœur de la marge fiscale CH).
- [ ] **WALK-02b**: `lauren_expat_us` (FATCA) walker test deferred to v2.11 — when it ships, walker MUST verify (a) coach does NOT propose 3a insight to US person, (b) FATCA disclaimer renders (« Tu es US person — les règles 3a et fonds suisses ont des implications IRS spécifiques. »).
- [ ] **WALK-03**: Walker captures screenshots at four checkpoints — landing, anonymous_chat (after coach opener), ECL insight rendered, register CTA exposed.
- [ ] **WALK-04**: Visual diff vs locked landing mockup ≤ 4 % pixel difference in the hero zone on iPhone 17 viewport.
- [ ] **WALK-05**: Walker output archived in `.planning/walker/<run-id>/` where run-id = `YYYY-MM-DD-<git-sha-short>`.
- [ ] **WALK-06**: Per-archetype walker run completes in ≤ 120 s wall-clock on Mac mini.

### Compliance (LSFin + public-repo discipline)

- [ ] **COMP-01**: 0 banned terms across 6 ARB files (FR/EN/DE/IT/ES/PT), enforced by `tools/checks/banned_terms_arb.py` blocking in pre-commit lefthook.
- [ ] **COMP-02**: `tools/checks/no_legal_admission_in_public_docs.py` blocking in pre-commit lefthook (repo is public ; per Sprint 1 panel recommendation).

### Hygiene (release-blocker)

- [ ] **HYG-01**: PRs in flight #478, #479, #480, #481, #482 are merged or closed before TestFlight 2.10.0 cut. No PR left in « pending review » at ship.
- [ ] **HYG-02**: Phase 56 PRs (#470, #472) explicitly decided — merged into dev or closed as deferred-post-v2.10.
- [ ] **HYG-03**: PROJECT.md + STATE.md aligned on v2.10 (no mismatch between declared milestone and yaml-front-matter).
- [ ] **HYG-04**: 0 dirty worktrees with unstaged tracked changes at TestFlight cut. All worktrees either committed-or-removed.
- [ ] **HYG-05**: TestFlight 2.10.0 build visible in App Store Connect with attached walker run-id evidence.

## Out of Scope (anti scope-creep — explicit exclusions)

| Feature | Reason |
|---------|--------|
| Wiki coach v3 (per-user knowledge graph) | Post-TestFlight milestone ; ADR-20260503 referenced but not yet written. |
| Couple mode wiring (UI ↔ financial_core) | Data layer cracked ; 2-3 weeks of work to fix properly ; not on the v2.10 ship path. |
| FIX-03 save_fact `responseMeta.profileInvalidated` | Carry-forward — does not block the anonymous tier (no save_fact in anonymous chat). |
| FIX-04 Coach tab routing stale after chat-AI response | Carry-forward — only affects authenticated tier. |
| 388 bare-catches sweep (332 mobile + 56 backend) | Carry-forward to v2.11 ; observability tooling is wired (Sprint 0 #478) so the bleed is visible. |
| Coach chat full redesign (post-auth) | Out — only anonymous chat redesigned in v2.10. |
| Aujourd'hui / Dossier / Explorer redesign | Out — touched only via navigation parity, not visually redesigned. |
| Multi-step onboarding wedge (T9-style 8-step) | Out — chat-first replaces it ; T9 wedge stays in code as fallback but is not the v2.10 entry. |
| Banking API + LPP API integration | v3.0+ ; not in 2026 scope. |
| Vignettes / Scènes / Canvas (v2.9 doctrine) | Deferred — those phases (40-43) are NOT v2.10 ; revisited post-TestFlight. |
| BYOK (Bring Your Own Key) testing | Out per memory `project_byok_scope` ; ServerKey only for v2.10. |

## Traceability (filled by roadmap 2026-05-04)

| Requirement | Phase | Status |
|-------------|-------|--------|
| LAND-01 | 73 | Pending |
| LAND-02 | 73 | Pending |
| LAND-03 | 73 | Pending |
| LAND-04 | 73 | Pending |
| LAND-05 | 73 | Pending |
| LAND-06 | 73 | Pending |
| LAND-07 | 73 | Pending |
| ANON-01 | 71 | Pending |
| ANON-02 | 71 | Pending |
| ANON-03 | 71 | Pending |
| ANON-04 | 71 | Pending |
| ANON-05 | 72 | Pending |
| ANON-06 | 71 | Pending (PR-A #480 ships it ; validated behind new UI in 71) |
| ANON-07 | 71 | Pending (PR-B #482 ships it ; validated behind new UI in 71) |
| ECL-01 | 72 | Pending |
| ECL-02 | 72 | Pending |
| ECL-03 | 72 | Pending (PR-C #481 ships it ; prompt-path assertion in 72) |
| ECL-04 | 71 | Pending |
| WALK-01 | 74 | Pending |
| WALK-02 | 74 | Pending |
| WALK-03 | 74 | Pending |
| WALK-04 | 74 | Pending |
| WALK-05 | 74 | Pending |
| WALK-06 | 74 | Pending |
| COMP-01 | 70 | Pending |
| COMP-02 | 70 | Pending |
| HYG-01 | 70 | Pending |
| HYG-02 | 70 | Pending |
| HYG-03 | 70 | Pending |
| HYG-04 | 70 | Pending |
| HYG-05 | 75 | Pending |

**Coverage:**
- v2.10 requirements: 31 total
- Mapped to phases: **31** ✓ (100%)
- Unmapped: 0 ✓
- Phases: 6 (70 / 71 / 72 / 73 / 74 / 75)

**Phase distribution:**
- Phase 70 (Hygiene + LSFin lint): 6 REQs (HYG-01..04, COMP-01, COMP-02)
- Phase 71 (Anonymous Chat redesign): 7 REQs (ANON-01..04, ANON-06, ANON-07, ECL-04)
- Phase 72 (Premier Éclairage rendering): 4 REQs (ANON-05, ECL-01, ECL-02, ECL-03)
- Phase 73 (Landing v3 éditorial): 7 REQs (LAND-01..07)
- Phase 74 (Walker E2E + golden): 6 REQs (WALK-01..06)
- Phase 75 (TestFlight 2.10.0 cut): 1 REQ (HYG-05)

## Constraints from Julien (operational, 2026-05-05)

- No human-in-the-loop testing. Claude validates everything via simulator iPhone (Mac mini) before any visual is shown to Julien.
- Image budget : max 1-2 screenshots per checkpoint surfaced to Julien. Full gallery archived under `.planning/walker/<run-id>/`.
- TestFlight = Claude-validated only. No human device gate.
- No new PRs until v2.10 roadmap approved.

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-05-04 — roadmap shipped, 31/31 REQs mapped to phases 70-75, traceability complete.*
