# Roadmap: MINT

## Milestones

- ✅ **v1.0** — 8 phases (shipped before 2026-04)
- ✅ **v2.0 Mint Système Vivant** — 6 phases (shipped 2026-04-07) — see [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)
- ✅ **v2.1 Stabilisation v2.0** — 1 phase (shipped 2026-04-07) — see [milestones/v2.1-ROADMAP.md](milestones/v2.1-ROADMAP.md)
- 🚧 **v2.2 La Beauté de Mint (Design v0.2.3)** — 13 phases (planned 2026-04-07, expert-audit patched) — phase numbering reset

## Phases

<details>
<summary>✅ v2.0 Mint Système Vivant (Phases 1-6) — SHIPPED 2026-04-07</summary>

- [x] Phase 1: Le Parcours Parfait (5/5 plans)
- [x] Phase 2: Intelligence Documentaire (4/4 plans)
- [x] Phase 3: Mémoire Narrative (4/4 plans)
- [x] Phase 4: Moteur d'Anticipation (3/3 plans)
- [x] Phase 5: Interface Contextuelle (2/2 plans)
- [x] Phase 6: QA Profond (6/6 plans)

**Total:** 24 plans, 47 tasks. Audit: passed_with_tech_debt.

</details>

<details>
<summary>✅ v2.1 Stabilisation v2.0 (Phase 7) — SHIPPED 2026-04-07</summary>

- [x] Phase 7: Stabilisation v2.0 (6/6 plans) — Coach tools E2E, 6-axis façade audit, CI green. STAB-17 carried to v2.2.

</details>

### 🚧 v2.2 La Beauté de Mint (Phases 1-13, reset, expert-audit patched)

- [ ] **Phase 1: P0a — Code Unblockers (rescoped, STAB-20 carved out)** — 4 providers wired ✅, ACCESS-01 tracker created ✅, STAB-21 moot pending Phase 10. STAB-20 carved out to Phase 1.5 after executor discovered 186-file domain-refactor surface (not a localized rename). STAB-18 + PERF baseline DEFERRED to Phase 12.
- [ ] **Phase 1.5: P0a.1 — chiffre_choc Domain Rename (NEW, carved out 2026-04-07)** — Domain refactor: rename `ChiffreChoc` class in `response_card.dart`, `EducationContent.chiffreChoc*` fields, `ChiffreChocType` enum, `_buildChiffreChocRegime()` across ~50 life-event screens, per-event ARB keys in 6 files, backend selector + schemas + OpenAPI regen, analytics events, CI grep gate. 186 files / 1934 hits / layered atomic commits. Unblocks Phase 2 contracts.
- [ ] **Phase 2: P0b — Contracts & Audits + AAA Tokens + Voice Spec v0.5** — VoiceCursorContract SoT + codegen + CI drift, Profile 3 voice fields (preference + n5Counter + fragileMode), 6 AAA tokens implemented, VoiceCursorSpec v0.5 extract (5 levels + narrator wall + sensitive list), Krippendorff tooling, 2 pre-migration audits.
- [ ] **Phase 3: L1.1 Audit du Retrait (S0-S5)** — DELETE/KEEP list per surface, -20% visual element reduction evidenced.
- [ ] **Phase 4: L1.2a MTC Component + S4 Migration** — MintTrameConfiance v1 built (consumes Voice Spec v0.5 for audio-tone consistency), bloom 250ms, S4 first consumer shipped.
- [ ] **Phase 5: L1.6a Voice Cursor Spec (full)** — Extends v0.5 to full spec, 50 phrases frozen, anti-examples, few-shot + cost-delta decision, pacing rules.
- [ ] **Phase 6: L1.4 Voix Régionale VS/ZH/TI** — 3 ARB files, custom delegate, backend dual-system killed, 3 native validators (coordinated with Phase 11 tester pool per audit fix B2).
- [ ] **Phase 7: L1.7 Landing v2 (S0 rebuild)** — Variante A paragraphe-mère, zero financial_core imports, consumes Phase 2 AAA tokens.
- [ ] **Phase 8a: L1.2b — MTC 11-Surface Migration** — Coverage gate, sentence-subject lint, no_legacy_confidence_render grep.
- [ ] **Phase 8b: L1.3 — Microtypographie + AAA Token Application + First Live a11y Session** — Spiekermann 4pt grid, AAA tokens applied to S0-S5, ≥1 live session compte-rendu.
- [ ] **Phase 8c: Polish Pass #1 (cross-surface aesthetic supervision)** — NEW. Claude in active supervision mode walks every S0-S5 surface post-migration: screenshot diffs, micro-typo coherence, chromatic consistency cross-surface, before/after element count. Spawns design-reviewer agent. Outputs `docs/POLISH_PASS_1.md` with delta proposals. No code commits — proposals feed back into Phase 8b refinements OR open hot-fix tasks.
- [ ] **Phase 9: L1.5 MintAlertObject (S5)** — Typed API, G2/G3 grammar, TalkBack 13 sweep, no_llm_alert grep gate.
- [ ] **Phase 10: L1.8 Onboarding v2** — Delete 5 screens, intent → chat, screens-before-first-insight = 2, post-deletion test count ≥ pre-deletion.
- [ ] **Phase 10.5: Friction Pass (golden path device test)** — NEW. Julien runs the new landing→intent→chat golden path on real Galaxy A14. Notes every frottement (timing, copy, animation, color, pacing). Claude re-processes notes into iterations on Phase 7+10 surfaces. The "très belle avant les humains" gate.
- [ ] **Phase 11: L1.6b Phrase Rewrite + Krippendorff Validation** — 30 phrases rewritten, α ≥ 0.67 (overall + N4 + N5), reverse-test passes, N5 server gate live, auto-fragility live.
- [ ] **Phase 12: L1.6c "Ton" UX Setting + Ship Gate** — User-facing Ton chooser, target 3 live sessions across Phases 8b+12, ComplianceGuard regression on all output channels, all CI gates green, Julien A14 manual pass.

## Phase Details

### Phase 1: P0a — Code Unblockers (rescoped 2026-04-07: "très belle avant les humains")
**Goal**: Kill the v2.1 code carryover that blocks Phase 2+ (broken providers + chiffre_choc rename). Send a11y recruitment emails as fire-and-forget for later phases. STAB-17 walkthrough and Galaxy A14 baseline DEFERRED to Phase 12 ship gate — they're "ready for humans" gates, not "start coding" gates.
**Depends on**: Nothing (sequential gate, code-only)
**Requirements**: STAB-19, STAB-20, STAB-21, ACCESS-01
**Success Criteria** (what must be TRUE):
  1. **ACCESS-01 fire-and-forget (rescoped):** 6 recruitment emails (2 per partner: SBV-FSA, ASPEDAH, Caritas) sent by Julien personally — but no longer day-1 critical. Sessions land when code is ready (Phase 8b + Phase 12 polish), not against a deadline. If recruitment slips, the milestone waits — we don't descope AAA. Tracker in `docs/ACCESSIBILITY_TEST_LAYER1.md`.
  2. `git grep 'ProviderNotFoundException' apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` returns 0 AND the 4 providers (`MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`) are registered in `app.dart` MultiProvider.
  3. **STAB-20 atomic-commit rollback path:** the 719-occurrence sweep ships as a sequence of atomic commits per layer (filenames first, then refs, then ARB keys, then OpenAPI/analytics), each independently revertable. CI grep gate `git grep -E 'chiffre_?choc|chiffreChoc' apps/mobile/lib/ services/backend/app/ apps/mobile/lib/l10n/` returns 0 at end of phase (allowed in `.planning/`, `docs/archive/`).
  4. STAB-21 (chiffre_choc_screen split-exit bug) noted as "moot — screen deleted in Phase 10" or fixed if Phase 10 slips.
**DEFERRED to Phase 12** (rescoped 2026-04-07): STAB-18 manual tap-render walkthrough, PERF-01..04 Galaxy A14 baseline. These are humans-ready gates, not code-start gates. The autonomous run does not block on Julien being on his couch with a device.
**Pitfalls to watch**: P10 chiffre_choc sweep incomplete; P19 Phase 0 bloat (now slim, 4 REQs only).
**Plans**: TBD
**Status note (2026-04-07)**: STAB-19 + ACCESS-01 shipped on `feature/v2.2-p0a-code-unblockers`. STAB-21 disposition = moot pending Phase 10. STAB-20 carved out to Phase 1.5 after executor discovered the rename is a domain refactor (186 files, 1934 hits, touches ResponseCard class + EducationContent fields + ChiffreChocType enum + ~50 life-event screens), not a localized sweep.

### Phase 1.5: P0a.1 — chiffre_choc → premier_eclairage Domain Rename
**Goal**: Execute the full domain rename of `chiffre_choc` / `ChiffreChoc` / `chiffreChoc` across the entire live codebase as a sequence of atomic, layered commits. Unblock Phase 2 contracts which cannot define new fields referencing the old domain name.
**Depends on**: Phase 1 (feature branch + ACCESS-01 tracker already on that branch)
**Requirements**: STAB-20 (carved out from Phase 1)
**Success Criteria** (what must be TRUE):
  1. **Model layer renamed**: `ResponseCard.ChiffreChoc` class → `PremierEclairage`; `EducationContent.chiffreChoc*` fields → `premierEclairage*`; `ChiffreChocType` enum → `PremierEclairageType`. All call sites updated. `flutter analyze lib/` = 0 errors.
  2. **Life-event screens migrated**: ~50 screens (`mariage`, `naissance`, `expat`, `mortgage/*`, `arbitrage/*`, `independants/*`, etc.) — `_buildChiffreChocRegime()` renamed + per-event ARB keys (`mariageChiffreChoc*` → `mariagePremierEclairage*`) renamed.
  3. **ARB + gen-l10n**: all 6 ARB files renamed (every `*ChiffreChoc*` key), `flutter gen-l10n` regenerated, `app_localizations_*.dart` updated, `flutter test` green.
  4. **Backend**: `chiffre_choc_selector.py` → `premier_eclairage_selector.py`, schemas renamed, OpenAPI regenerated (113 hits), `pytest -q` green, `ruff check` 0.
  5. **Analytics events**: hard-renamed (no dual-emit — pre-launch, no warehouse contract).
  6. **CI grep gate**: `tools/checks/no_chiffre_choc.py` scans `apps/mobile/lib/`, `services/backend/app/`, `apps/mobile/lib/l10n/`, `tools/openapi/`; excludes `.planning/**`, `docs/archive/**`, `apps/mobile/archive/**`, CLAUDE.md legacy note. Wired into CI. Green.
  7. **CLAUDE.md legacy note** flipped from "uses chiffre choc" → "rename completed 2026-04-07 — legacy term retained in archives only".
  8. **Atomic commit discipline**: each commit layer (backend / model / life-event screens / ARB / analytics / CI gate / docs) is independently revertable. `flutter analyze` + `flutter test` + `pytest -q` green between every commit.
  9. **Test count**: post-rename `flutter test` aggregate count ≥ pre-rename count (no silent test drops).
**Pitfalls to watch**: P10 (rename residue); regression risk across ~50 life-event screens; ARB generator drift; OpenAPI regen pipeline gotchas; hardcoded string audit tests that assert the literal "chiffre_choc".
**Plans**: TBD

### Phase 2: P0b — Contracts & Audits
**Goal**: Land the VoiceCursorContract single source of truth + pre-migration audits + the 6 AAA tokens so Phases 4, 5, 7, 9 can start without rework.
**Depends on**: Phase 1
**Requirements**: CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04, CONTRACT-05, CONTRACT-06, AUDIT-01, AUDIT-02, AESTH-04 (moved from Phase 8 per audit fix C1)
**Success Criteria** (what must be TRUE):
  1. `tools/contracts/voice_cursor.json` committed with 5-level × 3-gravity × 3-relation matrix, guardrails, sensitive topics, narrator wall exemption list; CI drift guard regenerates Dart `.g.dart` + Pydantic `.py` and `git diff --exit-code` is green on every PR.
  2. **VOICE_CURSOR_SPEC_v0.5 extract (audit fix A2):** `docs/VOICE_CURSOR_SPEC.md` exists with ONLY the 5-level definitions + narrator wall exemption list + sensitive topics list filled in. The full spec (anti-examples, pacing rules, 50 phrases, precedence cascade explanation) lands in Phase 5. This v0.5 extract gives Phase 4 MTC the tonal anchor it needs for the 24 audio ARB strings (MTC-05) without making Phase 5 a hard prerequisite of Phase 4.
  3. **CONTRACT-05 extended (audit fix A1):** `Profile` Pydantic + Dart + SQLA gets all 3 voice cursor fields in this phase, not Phase 11: (a) `voiceCursorPreference: Literal['soft','direct','unfiltered'] = 'direct'`, (b) `n5IssuedThisWeek: int = 0` (rolling counter for VOICE-09 server gate), (c) `fragileModeEnteredAt: Optional[datetime]` (for VOICE-10 auto-fragility). Single migration, single touch on the 73 CoachProfile consumers.
  4. `resolveLevel(gravity, relation, preference, sensitiveFlag, fragileFlag, n5Budget)` pure function exists with ≥80 unit tests covering matrix + precedence cascade + sensitive-topic + fragile-mode + N5-budget edges.
  5. `docs/AUDIT_CONFIDENCE_SEMANTICS.md` committed with all ~40 hits classified into `extraction-confidence` / `data-freshness` / `calculation-confidence` and per-category MTC decision.
  6. `docs/AUDIT_CONTRAST_MATRIX.md` committed with every S0-S5 text/background token pair + WCAG ratio + AAA/AA/fail classification, identifying the 6 tokens for AESTH-04.
  7. **AESTH-04 6 AAA tokens implemented in `apps/mobile/lib/theme/colors.dart` (audit fix C1):** `textSecondaryAaa` (#595960), `textMutedAaa` (#5C5C61), `successAaa` (#0F5E28), `warningAaa` (#8C3F06), `errorAaa` (#A52121), `infoAaa` (#004FA3). Brand sign-off by Julien committed in commit message. Tokens exist before Phase 7 Landing v2 ships so LAND-05 "AAA from day 1" is buildable. Token APPLICATION on S0-S5 still happens in Phase 8b.
  8. Krippendorff tooling provisioned: `tools/voice-cursor-irr/` directory with `compute_alpha.py`, `requirements.txt`, README, ratings CSV template.
**Pitfalls to watch**: P8 cursor precedence undefined; P5 MTC semantic conflation (AUDIT-01 mitigates); P13 AAA contrast vs brand pastels (AUDIT-02 mitigates).
**Plans**: TBD

### Phase 3: L1.1 Audit du Retrait (S0-S5)
**Goal**: Produce an explicit, per-surface DELETE/KEEP list for every visual element on S0-S5 and evidence the -20% element reduction target.
**Depends on**: Phase 1
**Requirements**: AUDIT-03, AESTH-08
**Success Criteria** (what must be TRUE):
  1. `docs/AUDIT_RETRAIT_S0_S5.md` committed listing every visual element on S0-S5 with an explicit DELETE or KEEP verdict.
  2. Before/after element count per surface demonstrates ≥20% reduction, evidenced by screenshots pair per surface in the audit doc.
  3. L1.2b migration list and L1.3 microtypographie map both reference the DELETE list as their input — no surface touched without passing through the audit first.
**Pitfalls to watch**: P5 MTC semantic loss; P13 AAA contrast.
**Plans**: TBD
**UI hint**: yes

### Phase 4: L1.2a MTC Component + S4 Migration
**Goal**: Build `MintTrameConfiance` v1 as the single confidence rendering primitive and ship it as the first consumer on S4 (`response_card_widget.dart`).
**Depends on**: Phase 1 (PERF baseline), Phase 2 (AUDIT-01 confidence semantics)
**Requirements**: MTC-01, MTC-02, MTC-03, MTC-04, MTC-05, MTC-06, MTC-07, MTC-08, MTC-09, TRUST-01, TRUST-03
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` exports `.inline()`, `.detail()`, `.audio()` constructors + `MTC.Empty(missingAxis)` state; no public `score: double` getter (grep gate).
  2. Bloom animation runs 250ms ease-out, scale 0.96→1 + opacity 0→1, respects `MediaQuery.disableAnimations` (fallback 50ms opacity-only); Patrol golden at t=0/125/250ms.
  3. `BloomStrategy` enum with `firstAppearance`, `onlyIfTopOfList`, `never`; feed contexts default `onlyIfTopOfList` with 60ms stagger.
  4. S4 `response_card_widget.dart` consumes MTC.inline; `oneLineConfidenceSummary()` returns WEAKEST axis only (24 ARB strings, 4 variants × 6 langs); Semantics announce fires exactly once on state change (TalkBack 13 + VoiceOver verified).
  5. Hypotheses footer (VZ pattern) rendered at rest under every MTC consumer (max 3 lines); projections below confidence floor render `MTC.Empty` not faded numbers.
  6. Galaxy A14 manual perf gate passed by Julien on the S4 surface (0 dropped frames during bloom, scroll FPS within baseline).
**Pitfalls to watch**: P4 silent coverage loss; P6 bloom jitter; P16 MTC sortable trap; P20 vestibular bloom.
**Plans**: 3 plans
- [ ] 04-01-PLAN.md — MintTrameConfiance component build (widget + BloomStrategy + painter + ARB + ≥45 unit tests)
- [ ] 04-02-PLAN.md — S4 migration: response_card_widget consumes MTC + Phase 3 DELETE list pruning
- [ ] 04-03-PLAN.md — Golden test infrastructure: dual-device screen_pump helper + 5 S4 baseline goldens + CI wiring
**UI hint**: yes

### Phase 5: L1.6a Voice Cursor Spec (full)
**Goal**: Extend the v0.5 extract from Phase 2 into the full authoritative voice cursor spec + 50 frozen reference phrases + few-shot tone-locking mitigation — the editorial charter every downstream voice phase reads.
**Depends on**: Phase 2 (CONTRACT-01..06 + VOICE_CURSOR_SPEC v0.5 extract)
**Requirements**: VOICE-01, VOICE-02, VOICE-03, VOICE-07, VOICE-11, VOICE-12
**Success Criteria** (what must be TRUE):
  1. `docs/VOICE_CURSOR_SPEC.md` extended from Phase 2's v0.5 extract to cover: full 5 level definitions, gravity × relation routing matrix, precedence cascade ordering, sentence-subject rule, pacing/silence rules per level (the v0.5 extract already shipped: 5 levels skeleton + narrator wall + sensitive topics list).
  2. 50 reference phrases (10 per level) committed and cryptographically frozen (git SHA recorded in spec doc) BEFORE any tester sees them; no re-rolling allowed.
  3. Per-level anti-examples documented ("what N4 is NOT", "what N5 is NOT") to lock down drift post-validation.
  4. **Few-shot tone-locking + cost-delta decision (audit fix B5):** 3 verbatim N4 + 3 N5 examples embedded in `claude_coach_service.py` system prompt. `docs/COACH_COST_DELTA.md` committed with measured token delta (~1-2k/call expected) AND explicit decision logged: `accept` / `mitigate-via-prompt-caching` / `reduce-few-shot-count`. Production cost surface MUST have an owner before Phase 11 ships.
  5. Narrator wall enforced at call sites: settings, error toasts, network failures, legal disclaimers, onboarding system text do NOT pass through voice cursor routing (grep gate on exemption list).
  6. Context bleeding mitigations: system prompt rebuilt fresh each turn, explicit register-reset clause, `[N5]` tag in history, 150ms breath separator on G3→G1 transitions.
**Pitfalls to watch**: P1 tone-locking; P2 context bleeding; P8 precedence undefined.
**Plans**: TBD

### Phase 6: L1.4 Voix Régionale VS/ZH/TI
**Goal**: Ship the 3 canton ARB carve-outs, kill the backend dual-system, and lock regional voice to base languages only — validated by named natives.
**Depends on**: Phase 1 (ACCESS-01 recruitment), Phase 2 (codegen infra)
**Requirements**: REGIONAL-01, REGIONAL-02, REGIONAL-03, REGIONAL-04, REGIONAL-05, REGIONAL-06, REGIONAL-07
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/l10n_regional/app_regional_{vs,zh,ti}.arb` exist with ~30 keys each (90 total) in base languages only (fr-CH / de-CH / it-CH); header comment `// LOCALE-LOCKED`.
  2. `l10n_regional.yaml` second gen_l10n config + custom `LocalizationsDelegate` (~40 LOC) resolve `(canton, base_lang)` with silent fallback to main ARB; sibling-key lint enforces REGIONAL-07.
  3. `regional_microcopy_codegen.py` generates `services/backend/app/services/coach/regional_microcopy.py` from the ARB files; `claude_coach_service.py` imports it; legacy `REGIONAL_MAP` + `_REGIONAL_IDENTITY` constants DELETED in the same MR.
  4. CI guard `git grep 'REGIONAL_MAP\s*=' services/backend/` returns 0 (red build on regression).
  5. 3 named native validators (1 VS, 1 ZH, 1 TI) listed in `docs/VOICE_PASS_LAYER1.md` with sign-off date on their 30 strings each.
**Pitfalls to watch**: P11 regional validators recruitment; P12 backend dual-system not deleted; P18 ARB fallback.
**Plans**: 4 plans
- [ ] 06-01-PLAN.md — Pre-audit: walk backend + mobile regional code → docs/REGIONAL_VOICE_AUDIT.md
- [ ] 06-02-PLAN.md — Backend consolidation: regional_microcopy_codegen.py + delete REGIONAL_MAP/_REGIONAL_IDENTITY + CI guards
- [ ] 06-03-PLAN.md — ARB carve-outs: 3 files (VS/ZH/TI) + custom delegate + Profile.canton wiring + widget tests + native sign-off
- [ ] 06-04-PLAN.md — Validator coordination doc (Phase 11 pool piggyback)

### Phase 7: L1.7 Landing v2 (S0 Rebuild)
**Goal**: Rebuild the S0 landing as a calm promise surface — zero numbers, zero inputs, Variante A paragraphe-mère, AAA from day 1.
**Depends on**: Phase 1 (STAB-20 sweep), Phase 2 (AESTH-04 6 AAA tokens implemented, audit fix C1)
**Requirements**: LAND-01, LAND-02, LAND-03, LAND-04, LAND-05, LAND-06
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/screens/landing_screen.dart` rebuilt with zero `financial_core` imports (compile-time lint), zero input fields, zero projected numbers, zero retirement vocabulary.
  2. Layout contains exactly: one paragraphe-mère (Variante A, ~30 words), one primary CTA ("Continuer (sans compte)"), one privacy micro-phrase, one legal footer line.
  3. Banned-terms lint passes: "Commencer", "Démarrer", "Voir mon chiffre", "Ton chiffre en X secondes", "chiffre choc" return 0 hits in LAND-touched files.
  4. AAA contrast (7:1) verified via `wcagContrastRatio()` widget test on every text surface of S0; routes directly to `/onboarding/intent`.
**Pitfalls to watch**: P10 chiffre_choc sweep residue; P13 AAA contrast.
**Plans** (3):
  - [ ] 07-01-PLAN.md — Paragraphe-mère i18n authoring (fr master + 5 translations)
  - [ ] 07-02-PLAN.md — Landing screen rebuild + CI lint gates + smoke test
  - [ ] 07-03-PLAN.md — Dual-device golden tests + AAA contrast assertions
**UI hint**: yes

### Phase 8a: L1.2b — MTC 11-Surface Migration (audit fix B1: split from monster Phase 8)
**Goal**: Kill the dual-system by migrating all 11 remaining confidence-rendering surfaces to MTC. Coverage gate prevents silent regression.
**Depends on**: Phase 3 (DELETE list), Phase 4 (MTC component), Phase 2 (AUDIT-01 confidence semantics)
**Requirements**: MTC-10, MTC-11, MTC-12, TRUST-02
**Success Criteria** (what must be TRUE):
  1. All 11 rendering surfaces (confidence_score_card, confidence_banner, trajectory_view, futur_projection_card, coach_briefing_card, retirement_hero_zone, indicatif_banner, narrative_header, retirement_dashboard_screen, cockpit_detail_screen, confidence_blocks_bar) consume MTC; the 7 logic-gate consumers remain untouched per an explicit DO-NOT-MIGRATE list committed in the MR.
  2. Pre/post lcov delta on confidence consumers ≥ 0% (silent coverage drop = red build).
  3. `tools/checks/no_legacy_confidence_render.py` grep gate returns 0 outside `mint_trame_confiance.dart`.
  4. Sentence-subject rule (TRUST-02) enforced via ARB lint across the 11 migrated surfaces.
  5. Galaxy A14 manual scroll-FPS + bloom check by Julien on the migrated home surface.
**Pitfalls to watch**: P4 silent coverage loss; P5 MTC semantic conflation.
**Plans**: 3 plans
- [ ] 08a-01-PLAN.md — Extend ResponseCard + backend schema with EnhancedConfidence? (wire format D-05, round-trip test)
- [ ] 08a-02-PLAN.md — Migrate 11 surfaces to MintTrameConfiance in 3 batches (coach / profile / home+retirement) + 6 ARB files + A14 checkpoint
- [ ] 08a-03-PLAN.md — Coverage gate (no_legacy_confidence_render.py) + TRUST-02 ARB lint (sentence_subject_arb_lint.py) + CI wiring + MTC-12 lcov baseline + MIGRATION_RESIDUE_8a.md
**UI hint**: yes

### Phase 8b: L1.3 — Microtypographie + AAA Token Application + First Live a11y Session (audit fix B1: split)
**Goal**: Apply Spiekermann microtypographie pass on S0-S5, migrate text to AAA tokens (already implemented in Phase 2 per audit fix C1), run the first live accessibility session.
**Depends on**: Phase 8a (MTC migration shipped), Phase 2 (AESTH-04 tokens implemented), Phase 1 (ACCESS-01 emails sent day 1)
**Requirements**: AESTH-01, AESTH-02, AESTH-03, AESTH-05, AESTH-06, AESTH-07, ACCESS-02, ACCESS-04, ACCESS-07, ACCESS-08, ACCESS-09
**Success Criteria** (what must be TRUE):
  1. 4pt baseline grid snap rule + 45-75 char line length + max 3 heading levels enforced on S0-S5 (manual review + lint); headline numbers demoted to body weight on S4 (Aesop rule); MUJI 4-line grammar on S4 response cards.
  2. S0-S5 text surfaces migrated to AAA tokens (`textSecondaryAaa`, `textMutedAaa`, etc. — already in `colors.dart` since Phase 2). Pastels (saugeClaire, bleuAir, pecheDouce, corailDiscret, porcelaine) demoted to background-only on S0-S5.
  3. One-color-one-meaning rule enforced: single desaturated amber (`warningAaa`) for "verifiable fact requiring attention" on S0-S5; all other semantic colors neutralized.
  4. `liveRegion: true` semantics on coach_message_bubble incoming; reduced-motion fallback verified across MTC bloom + coach typing + onboarding transitions.
  5. ≥1 live a11y test session completed (1 of the 3 partners: SBV-FSA OR ASPEDAH OR Caritas) with compte-rendu committed to `docs/ACCESSIBILITY_TEST_LAYER1.md`. AAA honesty gate decision committed: "AAA met on S0-S5" OR "descoped to AA + documented gaps per ACCESS-09".
**Pitfalls to watch**: P13 AAA contrast brand pastels; P14 live tests recruitment lead time.
**Plans**: TBD
**UI hint**: yes

### Phase 8c: Polish Pass #1 (cross-surface aesthetic supervision)
**Goal**: Claude-supervised aesthetic delta pass on every S0-S5 surface post-8b. Screenshot diffs, micro-typo coherence, chromatic cross-surface consistency, before/after element count. No code commits in this phase — outputs a delta proposal document fed back as hot-fix tasks or into Phase 8b refinements. Julien validates proposals before any downstream apply.
**Depends on**: Phase 8a (MTC migration shipped), Phase 8b (microtypo + AAA applied + first a11y session)
**Requirements**: AESTH-01, AESTH-02, AESTH-03, AESTH-05, AESTH-06, AESTH-07 (cross-surface regression), STAB-20 (residue sweep)
**Success Criteria** (what must be TRUE):
  1. Per-surface screenshot diff (S0, S1, S2, S3, S4, S5) captured post-8b vs pre-migration baseline; committed to `docs/POLISH_PASS_1.md`.
  2. Cross-surface coherence audit: typography scale, spacing rhythm, chromatic palette, MTC bloom timing, motion curves — one table per axis, discrepancies flagged.
  3. Element count delta verified: -20% target from Phase 3 holds post-8b (no regression from reintroduced polish).
  4. Delta proposal list: each item tagged (hot-fix-now / refine-in-8b / defer-to-post-milestone), each with surface + file + one-line rationale.
  5. Julien sign-off on proposal list committed as `docs/POLISH_PASS_1.md` footer before Phase 9 begins.
**Pitfalls to watch**: P15 editorial drift; cross-surface regression from isolated per-surface work.
**Plans**: TBD
**UI hint**: yes (supervision-only, no code commits)

### Phase 9: L1.5 MintAlertObject (S5)
**Goal**: Build S5 as a typed, rule-fed alert primitive that imports VoiceCursorContract and enforces G2/G3 grammar at the component API level.
**Depends on**: Phase 2 (CONTRACT-01..06), Phase 4 (optional, MTC patterns)
**Requirements**: ALERT-01, ALERT-02, ALERT-03, ALERT-04, ALERT-05, ALERT-06, ALERT-07, ALERT-08, ALERT-09, ALERT-10, ACCESS-05
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/widgets/mint_alert_object.dart` exposes typed API `MintAlertObject({required Gravity gravity, required String fact, required String cause, required String nextMoment})` — no arbitrary `String message` accepted (compiler-enforced).
  2. MINT is sentence subject on every negative statement (ARB lint); G2 renders in calm register, G3 renders with grammatical break + priority float; `card_ranking_service.dart` tiebreaker floats G3 to top.
  3. Imports generated `voice_cursor_contract.g.dart` for gravity → N-level routing — zero hardcoded mapping; fed by `AnticipationProvider` / `NudgeEngine` / `ProactiveTriggerService`, never by LLM output. **Audit fix C2:** explicit grep gate `tools/checks/no_llm_alert.py` committed in this phase, runs in CI, scans for any `MintAlertObject(` instantiation in files importing `claude_*_service` and fails the build.
  4. G3 persists until acknowledged (COGA pattern), acknowledgement stored in biography; `SemanticsService.announce()` fires on G2→G3 with `liveRegion: true`.
  5. Patrol integration test covers 6 golden states (G2/G3 × soft/direct/unfiltered + sensitive-topic guard + fragile-mode guard).
  6. TalkBack 13 widget-trap sweep completed on S5 (CustomPaint semanticsBuilder, IconButton tooltips, InkResponse, AnimatedSwitcher keys, obscureText labels, DropdownMenu semantics).
  7. G3 politique default = information-only; external action API prepared but disabled until partner routing signed (documented in component docstring).
**Pitfalls to watch**: P8 precedence; P16 sortable trap; P14 live tests.
**Plans**: TBD
**UI hint**: yes

### Phase 10: L1.8 Onboarding v2
**Goal**: Delete 5 onboarding screens, wire intent → chat directly, and drop screens-before-first-insight from 5 to 2.
**Depends on**: Phase 7 (landing rebuilt), Phase 1 (chiffre_choc sweep)
**Requirements**: ONB-01, ONB-02, ONB-03, ONB-04, ONB-05, ONB-06, ONB-07, ONB-08, ONB-09, ONB-10, ACCESS-06
**Success Criteria** (what must be TRUE):
  1. 5 screens + routes deleted: `quick_start_screen`, `chiffre_choc_screen`, `instant_chiffre_choc_screen`, `promise_screen`, `plan_screen`; `git grep` on each filename returns 0; GoRouter has no dangling references (redirect shims cover any external deep links).
  2. `intent_screen.dart` `_isFromOnboarding == true` branch routes to `/coach/chat` with chip payload (not `/onboarding/quick-start`); `chiffre_choc_selector` import removed.
  3. `OnboardingProvider` removed from `app.dart` MultiProvider; state migrated to `CoachProfileProvider` + `CapMemoryStore`; `data_block_enrichment_screen.dart` preserved as JIT deep-link (GoRouter reachability test green). **Audit fix C3:** post-deletion test count ≥ pre-deletion test count; `flutter test` aggregate count captured in MR description; tests that depended on the deleted provider migrated, not dropped silently.
  4. E2E golden path test passes: `S0 landing → /onboarding/intent (1 chip) → /coach/chat` with screens-before-first-insight = 2 and friction time < 20 seconds measured in the test.
  5. Flesch-Kincaid French reading level CI gate green on onboarding ARB strings (target B1); jargon tap-to-define inline expansion present for unavoidable terms.
**Pitfalls to watch**: P10 chiffre_choc sweep residue; P14 live tests.
**Plans**: TBD
**UI hint**: yes

### Phase 10.5: Friction Pass (golden path device test)
**Goal**: Julien runs the new S0 landing → intent → /coach/chat golden path on a real Galaxy A14 device and captures every frottement (timing, copy, animation, color, pacing, tap target). Claude re-processes notes into concrete iteration items against Phase 7 (landing) and Phase 10 (onboarding) surfaces. This is the "très belle avant les humains" gate — fail = return to Phase 7/10 for fixes.
**Depends on**: Phase 7 (landing v2), Phase 10 (onboarding v2)
**Requirements**: PERF-01, PERF-02, PERF-03 (A14 baseline subset), ONB-04, ONB-07, AESTH-05, AESTH-07
**Success Criteria** (what must be TRUE):
  1. Galaxy A14 physical device walkthrough completed by Julien: cold start → S0 → intent chip → chat first message → first insight. Screen recording committed to `docs/FRICTION_PASS_1.mp4` or frame dump to `docs/FRICTION_PASS_1/`.
  2. Friction notes captured in `docs/FRICTION_PASS_1.md`: one entry per frottement with (timestamp, surface, axis [timing/copy/motion/color/pacing/tap], severity [block/polish/nit], proposed fix).
  3. Claude processes notes into a tagged iteration list: block-items become hot-fix tasks reopening Phase 7 or 10 scope; polish-items queue for Phase 12 pre-ship; nits deferred to post-milestone.
  4. All block-items resolved and re-verified on the same A14 device before Phase 11 begins. Second walkthrough recording confirms zero remaining blockers.
  5. Cold start < 2.5s, first-frame-to-interactive < 3s, first chat message round-trip < 4s on A14 (preliminary, full PERF baseline lives in Phase 12).
**Pitfalls to watch**: P14 device availability; friction notes that describe symptoms without surfaces; polish creep into blockers.
**Plans**: TBD
**UI hint**: yes (device-test + iteration loop)

### Phase 11: L1.6b Phrase Rewrite + Krippendorff Validation
**Goal**: Rewrite the 30 most-used coach phrases to match the spec, and statistically prove tone-locking works via weighted ordinal Krippendorff α.
**Depends on**: Phase 5 (spec), Phase 2 (Krippendorff tooling)
**Requirements**: VOICE-04, VOICE-05, VOICE-06, VOICE-08, VOICE-09, VOICE-10, VOICE-14
**Success Criteria** (what must be TRUE):
  1. 30 most-used coach phrases (extracted from `claude_coach_service.py` + 6-language ARB) audited and rewritten per spec; before/after documented in `docs/VOICE_PASS_LAYER1.md`.
  2. Krippendorff α validation: 15 testers × 50 frozen reference phrase set × blind N1-N5 classification → overall α ≥ 0.67 AND per-level N4 α ≥ 0.67 AND per-level N5 α ≥ 0.67 (weighted ordinal); report committed to `docs/VOICE_CURSOR_TEST.md`.
  3. Reverse-Krippendorff generation test: 10 trigger contexts → Claude at N4 → 10 outputs rated blind → ≥70% classified as N4 (anti-tone-locking gate); fail = system prompt fix before ship.
  4. ComplianceGuard extended with 50 adversarial N4/N5 phrases testing prescription drift (imperative-without-hedge, banned terms at high register); red build on regression.
  5. N5 server-side hard gate: `Profile.n5IssuedThisWeek` rolling 7-day counter, backend auto-downgrades N5→N4 when ≥1; replay test on synthetic crisis cluster asserts ≤1 N5/week.
  6. Auto-fragility detector: ≥3 G2/G3 events in 14 days → fragile mode (N3 cap, 30 days); user-visible "MINT a remarqué…" disclosure logged to biography.
  7. `@meta level:` annotation required on every new ARB phrase; CI grep gate rejects additions without it.
**Pitfalls to watch**: P1 tone-locking; P3 N5 editorial cap; P9 ComplianceGuard drift; P15 editorial drift; P17 sample size.
**Plans**: TBD

### Phase 12: L1.6c "Ton" UX Setting + "Ready for Humans" Ship Gate (rescoped 2026-04-07)
**Goal**: Expose the user-facing "Ton" setting (soft/direct/unfiltered) wired to `Profile.voiceCursorPreference`. Close all CI gates. Run the deferred-from-Phase-1 manual gates (STAB-18 walkthrough + Galaxy A14 perf baseline) — now framed as "is v2.2 ready to be shown to a real human?", not "TestFlight ASAP".
**Depends on**: Phase 11, Phase 2 (Profile field), Phase 5 (spec), Phase 10.5 (friction pass)
**Requirements**: VOICE-13, ACCESS-03, PERF-05, STAB-18 (deferred from Phase 1), PERF-01, PERF-02, PERF-03, PERF-04 (deferred from Phase 1)
**Success Criteria** (what must be TRUE):
  1. `intent_screen.dart` (first launch) and `ProfileDrawer` (settings) expose a 3-option "Ton" chooser (`soft` / `direct` (default) / `unfiltered`) that writes `Profile.voiceCursorPreference` via API; UX label = "Ton", word "curseur" never user-visible (grep gate).
  2. WCAG 2.1 AA floor CI gate (`meetsGuideline(textContrastGuideline, androidTapTargetGuideline)`) is green on EVERY touched surface, not just S0-S5.
  3. `BloomStrategy` custom lint green: no MTC instantiation without explicit strategy; default `onlyIfTopOfList` in feed contexts, `firstAppearance` in standalone.
  4. Julien signs the Galaxy A14 manual perf gate across cold start + scroll + bloom on S0-S5 post-integration; results appended to `A14_BASELINE.md`.
  5. **Tighten live session target (audit fix C4):** target 3 sessions across Phases 8b + 12 (full brief target). Acceptable descope: 2 sessions ONLY if a partner ghosted despite Phase 1 day-1 emails AND a written "AAA descoped to AA + documented gaps" decision is committed per ACCESS-09. Ghosting + silent drop is NOT acceptable.
  6. **Audit fix B4: final ComplianceGuard regression run** on every output channel touched in v2.0/v2.1/v2.2 (alerts, biography, openers, extraction, MintAlertObject, all 30 rewritten coach phrases, voice cursor outputs at all 5 levels). Zero ComplianceGuard rule violations. Report committed to `docs/COMPLIANCE_REGRESSION_v2.2.md`.
  7. All v2.2 CI gates green: flutter analyze lib/ 0, flutter test, pytest, ruff 0, codegen drift guards, contrast matrix, Flesch-Kincaid, chiffre_choc grep, REGIONAL_MAP grep, no_legacy_confidence_render grep, no_llm_alert grep, banned-terms grep, sentence-subject ARB lint, `@meta level:` lint.
**Pitfalls to watch**: P2 context bleeding (final multi-turn regression pass); P14 live tests; P15 editorial drift (handoff to post-milestone cadence).
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1. Le Parcours Parfait | v2.0 | 5/5 | Complete | 2026-04-06 |
| 2. Intelligence Documentaire | v2.0 | 4/4 | Complete | 2026-04-06 |
| 3. Mémoire Narrative | v2.0 | 4/4 | Complete | 2026-04-06 |
| 4. Moteur d'Anticipation | v2.0 | 3/3 | Complete | 2026-04-06 |
| 5. Interface Contextuelle | v2.0 | 2/2 | Complete | 2026-04-06 |
| 6. QA Profond | v2.0 | 6/6 | Complete | 2026-04-07 |
| 7. Stabilisation v2.0 | v2.1 | 6/6 | Complete | 2026-04-07 |
| **v2.2 — phase numbering reset** | | | | |
| 1. P0a Unblockers & Perf Baseline | v2.2 | 0/? | Not started | — |
| 2. P0b Contracts & Audits + AAA Tokens + Spec v0.5 | v2.2 | 0/? | Not started | — |
| 3. L1.1 Audit du Retrait | v2.2 | 0/? | Not started | — |
| 4. L1.2a MTC + S4 | v2.2 | 0/? | Not started | — |
| 5. L1.6a Voice Cursor Spec (full) | v2.2 | 0/? | Not started | — |
| 6. L1.4 Voix Régionale | v2.2 | 0/? | Not started | — |
| 7. L1.7 Landing v2 | v2.2 | 0/? | Not started | — |
| 8a. L1.2b MTC 11-Surface Migration | v2.2 | 0/? | Not started | — |
| 8b. L1.3 Microtypo + AAA Application + Live a11y #1 | v2.2 | 0/? | Not started | — |
| 9. L1.5 MintAlertObject | v2.2 | 0/? | Not started | — |
| 10. L1.8 Onboarding v2 | v2.2 | 0/? | Not started | — |
| 11. L1.6b Rewrite + Krippendorff | v2.2 | 0/? | Not started | — |
| 12. L1.6c "Ton" UX + Ship Gate | v2.2 | 0/? | Not started | — |
