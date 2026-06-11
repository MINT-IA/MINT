---
phase: mint-illogism-fixes
verified: 2026-06-12T00:30:00Z
status: human_needed
score: 20/21
overrides_applied: 0
human_verification:
  - test: "D7 /retraite does NOT show «4 infos suffisent» with a hydrated profile"
    expected: "/retraite shows projection or _buildProjectionUnavailable, never the onboarding State C, when /home displays profile data"
    why_human: "Device re-capture was blocked by onboarding-shell idb automation gap (sparse AX tree / custom-paint text-links not hittable). Fix is widget-test-verified (11/11 incl. exact settled-clear scenario, RED→GREEN against device-proven mechanism) but on-device green screenshot of the fixed /retraite is outstanding."
---

# Phase mint-illogism-fixes — Verification Report

**Phase Goal:** Fermer les 5 causes racines des illogismes user-facing de MINT — calculs divergents (W1), hypothèses d'archétype silencieuses (W2), estimations déguisées en faits (W3), erreurs de domaine (W4), surfaces muettes a11y (W5) — via mobile Flutter + onboarding UX uniquement.

**Verified:** 2026-06-12T00:30:00Z
**Status:** human_needed (all 21 must-haves verified or resolved; 1 outstanding human item: D7 on-device screenshot)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | **W1 — One canonical number per quantity**: avoir LPP, rente LPP, taux de remplacement, plafond 3a, économie 3a 3a each have a single source of truth via financial_core L1 | VERIFIED | `LppCalculator.accumulateAvoir`, `monthlyRenteFromAvoir`, `ReplacementRate`, `estimate3aTaxImpact(netProfessionalIncome:, isMarried:)` all exist and are wired in both profile engines. `financial_parity_test.dart` 45/45 passes (W1-W5+W6, 0-trust citation). Device: /home Avoir LPP 37'600 == RvC Avoir LPP 37'600 (item6 screenshots — was 8× apart pre-phase). |
| 2 | **W1 — No residual hardcoded rates**: sites using 0.068/0.058/0.34 hardcoded LPP rates, flat 0.75/0.78 net proxy, brut×0.20 for independent 3a ceiling are all eliminated | VERIFIED | `grep "0\.068\|0\.058" mariage_screen.dart response_card_service.dart` → 0 matches outside comments/canonical delegation. `grep "grossAnnualSalary \* pilier3aTauxRevenuSansLpp" tax_calculator.dart` → 0. `0.34` in `mint_scene_rente_trouee.dart` only in comments documenting removal. `2520 * years / 44` in cap_sequence_engine.dart only in comment on line 612. |
| 3 | **W2 — Archetype truth at onboarding**: 3 new scenes capture employment status, civil status (incl. divorce), and AVS gaps before financial data collection | VERIFIED | `mint_scene_statut_emploi.dart`, `mint_scene_etat_civil.dart`, `mint_scene_lacunes_avs.dart` exist; wired at lines 275/290/305 of `onboarding_shell_screen.dart`. Device: item2 screenshots confirm all 3 scenes appear in sequence and DossierStrip persists answers (PHASE-DEVICE-GATE item 2 PASS). |
| 4 | **W2 — Indépendant never gets phantom LPP**: both profile engines enforce LPP=0 via shared ArchetypePredicates, US-person gets global GoRouter redirect | VERIFIED | `archetype_predicates.dart` exists; `grep -c "ArchetypePredicates" coach_profile.dart` = 3; `grep -c "ArchetypePredicates" minimal_profile_service.dart` = 2. `archetypeRedirectTarget` wired in `app.dart` (1 match). `archetype_route_gate.dart` exists. Device: item3 screenshots — indépendant shows "LPP 0 CHF" and no phantom 76-95k; expat_us redirected to /waitlist from both /home and /mon-argent (PHASE-DEVICE-GATE items 3 PASS). Codex P1 gaps closed: router reactivity to async hydration (`c70e73337`), `Pillar3aRoomCalculator.annualCeiling` FATCA-gated (`8fbe74baa`). |
| 5 | **W2 — Ghost conjoint purged**: `fromWizardAnswers` no longer resurrects a `ConjointProfile` from residual `q_partner_*` keys when household is single; reads civil status (V2 form) over stale `q_household_type` | VERIFIED | `coach_profile.dart:3162-3189` gate implemented; Codex W5 closure `894940831` handles P1 (stale `q_household_type=single` + fresh `q_civil_status=marié`) and P2 (absent `q_household_type` + `q_civil_status` non-couple). 11/11 tests green in `mariage_whatif_labels_test.dart`. |
| 6 | **W3 — No fiction defaults**: RvC screen no longer pre-fills age='50'/salary='100000'/LPP='350000'; controllers start empty and source only from ProfileDataSource | VERIFIED | `_hasUsableInputs` guard at rente_vs_capital_screen.dart:448; `renteVsCapitalEmptyState` ARB key wired at lines 1311/1329. Device: Maestro `bug__ILLOG01__rvc_fiction_defaults.yaml` EXIT 0 cold + warm (PHASE-DEVICE-GATE item 1 PASS). Screenshots: w3-rvc-empty-state.png shows empty fields + state card, no fiction. |
| 7 | **W3 — ILLOG-02 AX tree populated**: RvC screen accessible tree has 29 elements (was 1); VoiceOver/Maestro can reach all fields | VERIFIED | Screen-root `Semantics(container:true, explicitChildNodes:true)` + per-field discrete labels in `rente_vs_capital_screen.dart`. Maestro `bug__ILLOG02__rvc_ax_tree_empty.yaml` EXIT 0 warm + cold (PHASE-DEVICE-GATE item 1 PASS). Device: idb AX shows 29 elements. item1-rvc-ax-tree-populated.png in evidence. |
| 8 | **W3 — Confidence Gate SOT §5**: hero fact card applies 3-state gate (gated<50 → no number; estimated → badge + uncertainty; known≥70 → bare number) wired on canonical EnhancedConfidence.combined | VERIFIED | `FactConfidenceState { known, estimated, gated }` enum in `rich_chat_widgets.dart:16`. `_buildFactCard` in `widget_renderer.dart` wired on canonical confidence. Codex W3 P2 fixed (legal fact cards not gated, `fd3e8814f`). RvC prefill route fixed (`b4ed7dea4`). 4/4 tests in `home_hero_confidence_test.dart` green. |
| 9 | **W3 — Single confidence source**: RvC consumes `EnhancedConfidence.combined` (canonical); misleading 50.0 floor from `_computeArbitrageConfidence` removed; allocation/location screens also unified | VERIFIED | `arbitrage_engine.dart` accepts `canonicalConfidence` param; floor 50.0 removed (Codex W3 F3 `9ee290814` extended to allocation/location screens). `confidence_source_unification_test.dart` 3/3 green. |
| 10 | **W4 — Divorce split bounded to marriage period**: split uses `(avoir_actuel - avoir_au_mariage).clamp(0,∞)` not total LPP | VERIFIED | `life_events_service.dart:148,162-172` implements bounded formula. `DivorceInput.avoirAuMariage1/avoirAuMariage2` nullable fields added. `life_events_divorce_test.dart` 5/5 passes (transfert=68125 not 168125 for test case). Codex W4 closure P3 fixed `totalLpp` preserved in incomplete result (`d7ed25240`). |
| 11 | **W4 — AVS gapFactor plumbed**: `minimal_profile_service` and `cap_sequence_engine` transmit `arrivalAge`/`lacunes`/`anneesContribuees` to `AvsCalculator`; no flat `2520×years/44` formula in production code | VERIFIED | `minimal_profile_service.dart` accepts `lacunes`/`anneesContribuees` params; `cap_sequence_engine._estimateAvsMonthly` delegates to `AvsCalculator`. Codex W4 P2 `423bfeed8` also plumbs `lacunesAVS`/`isFemale` into cap_sequence. `financial_parity_test.dart` Parity W4 — Rente AVS 4/4 green. `2520 * years / 44` only in comment. |
| 12 | **W4 — D10 3a suggestion capped to statutory ceiling**: BOTH the LLM-context path AND the `/mon-argent` coach whisper clamp to `min(marge, plafondRestant/moisRestants)` | VERIFIED | `BudgetLivingEngine.cappedMonthly3aSuggestion` exists and wired in `context_injector_service.dart`. `coach_whisper_service.dart` Rule 2 routes through `cappedMonthly3aSuggestion` (commit `a5118d6e2`, device re-verified). Device: `D10-mon-argent-whisper-1037-clamped-not-1541.png` — whisper shows 1037 CHF (1037×7=7258=legal ceiling), not 1541. Codex W4 P2 `d0df20471` also gates `3a_max` budget lever on eligibility. |
| 13 | **W4 — Affordability unified household income**: both routes to AffordabilityScreen produce the same `revenuBrutMenageFromProfile` | VERIFIED | `revenuBrutMenageFromProfile` and `resolveAffordabilityRevenu` helpers wired at affordability_screen.dart:37/51/64/110/168. `affordability_prefill_test.dart` 6/6 passes (couple → 196800 via both routes). |
| 14 | **W4 — LCC art. 28 citation corrected to ASB/FINMA**: no false mortgage-cap citation in runtime backend paths | VERIFIED | `grep -n "LCC art. 28" lucidity.py coach_tools.py` → 0 matches. `lucidity.py:48` shows `"Directives ASB (FINMA)"`. Codex W4 P2 `17f0adc9c` extended sweep to `coach_tools.py`, `anthropic_defer_loading_adapter.py`, `_payload.py`. Backend suite 7586 passed (plan 15 evidence). |
| 15 | **W5 — D7 /retraite no spurious empty state** (widget-test-verified, device re-capture pending) | VERIFIED (human pending) | `retirement_dashboard_screen.dart:95,128,143,417,432` — `_everHadProfile` guard; 3-branch predicate: !hasProfile → State C; _everHadProfile (post-render clear) → keeps projection; hasProfile → dashboard. 11/11 widget tests green including exact settled-clear scenario. Device probe log `D7-probe-hasProfile-true-then-false-settled-clear.log` proves root cause. Device re-capture blocked by onboarding-shell idb automation gap. **See human verification item.** |
| 16 | **W5 — D8 CTA routes to real onboarding with questions** | VERIFIED | `retirement_dashboard_screen.dart:1154-1159` — `Key('state_c_start_cta')` with `context.go('/onb')`. Maestro `tapOn "Commencer"` EXIT 0 landing on `/onb` OnboardingShellScreen with real age/canton/revenu fields (item5-D8 screenshots + log). |
| 17 | **W5 — D9 Mariage what-if declares hypotheses**: Revenu 2 default labeled as editable hypothesis when no real partner data; ghost conjoint not resurrect on household-single | VERIFIED | `mariage_screen.dart:58,103,305-308` — `_revenu2IsHypothesis` flag; `Key('mariage_revenu2_hypothesis_note')`. Ghost-conjoint gate at `coach_profile.dart:3162-3191` reads both `q_household_type` and `q_civil_status` (Codex W5 two-signal fix). Device: `D9-mariage-hypothesis-label.png` shows «Hypothèse modifiable» label. 5+6=11 tests green. |
| 18 | **W5 — D11 a11y labels localized**: «ouvrir-profil-drawer» and «coach-context-point-de-depart» no longer appear as raw keys in VoiceOver tree; machine identifier for Maestro preserved | VERIFIED | `explorer_screen.dart:25,29` — `Semantics(identifier:'ouvrir-profil-drawer', label: S.of(context)!.semanticsOpenProfile)`. `coach_packet_insight_card.dart:2` — same pattern. `grep -rn "label: '[a-z][a-z-]*-[a-z-]*[a-z]'" lib/` → 0. Device: `D11-explorer-localized-a11y.png`; Maestro `assertNotVisible "ouvrir-profil-drawer"` COMPLETED + `assertVisible id: "ouvrir-profil-drawer"` COMPLETED. |
| 19 | **W5 — «Document non disponible» i18n**: hardcoded French string migrated to AppLocalizations | VERIFIED | `app.dart:1226,1242` — `S.of(context)!.documentNonDisponible`. `grep "Document non disponible" app.dart` → 0 raw strings. ARB key present in all 6 locales. |
| 20 | **End-to-end W1 coherence**: same LPP value appears on /home, /mon-argent, and RvC for the same profile in the same session | VERIFIED | Device item6: `/home Avoir LPP 37'600` == RvC `37'600` (item6-home-avoir-lpp-37600.png + item6-rvc-avoir-lpp-37600-SAME-as-home.png). Independent: /home (no LPP) == RvC (LPP empty) == Prévoyance (LPP 0 CHF) all coherent (item3 screenshots). |
| 21 | **All suite gates green**: mobile flutter test 9446, backend 7586, flutter analyze clean at phase end | VERIFIED | PHASE-DEVICE-GATE documents mobile suite 9446 passed, backend 7586 passed. `flutter analyze` referenced clean at multiple plan close-outs. financial_parity_test.dart 45/45 (W1-W5+W6). |

**Score: 20/21 must-haves code-verified** (1 outstanding human item: D7 device re-capture)

---

### Deferred Items

Items explicitly out of phase scope (CONTEXT.md `<deferred>` block + `deferred-items.md`). Not actionable gaps.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Backend L2-L4 (comparer/éclairer/invariants) | mint-data-architecture-v1-02-deploy | CONTEXT.md §deferred: "hors scope, appartient à mint-data-architecture" |
| 2 | Coach temporal-gate false-refusal («cette année» → «Je n'ai pas cette donnée») | Separate backend phase | CONTEXT.md §deferred + engram obs #1592 |
| 3 | LCC art. 28 residual in `_payload.py`, `coach_tools.py`, `anthropic_defer_loading_adapter.py` | Closed by Codex W4 (`17f0adc9c`) | plan 15 deferred-items.md — now confirmed fixed in post-review gap closure |
| 4 | Pre-existing accent FR violations: `securite` → `sécurité` in `response_card_service.dart:983`, `premier_eclairage_selector.dart:257/259`, `tax_calculator.dart:263` | Separate accent FR PR | deferred-items.md rows 1-4; all explicitly hors-scope of their originating plan (Karpathy #3) |
| 5 | Married barème seed not in device registry (no married seed for walker) | Future seed registry PR | PHASE-DEVICE-GATE §Seeds: "all seeds hardcode `q_household_type: 'single'`"; plan 05 Task 2 married precision ≈1194 is widget-test-verified (26/26 parity) |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `financial_core/lpp_calculator.dart` | `accumulateAvoir` + `monthlyRenteFromAvoir` canonical L1 | VERIFIED | Both functions present (grep counts: 1/1) |
| `financial_core/replacement_rate.dart` | `ReplacementRate.percent/.fraction` | VERIFIED | File exists; 3 usages in services |
| `financial_core/archetype_predicates.dart` | LPP gates + canContribute3a | VERIFIED | File exists; 2+ usages in coach_profile + minimal_profile |
| `router/archetype_route_gate.dart` | Global FATCA redirect helper | VERIFIED | File exists; wired in `app.dart` |
| `screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart` | Employment status scene | VERIFIED | File exists; wired in shell at line 275 |
| `screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart` | Civil status scene | VERIFIED | File exists; wired in shell at line 290 |
| `screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart` | AVS gaps scene | VERIFIED | File exists; wired in shell at line 305 |
| `test/services/financial_parity_test.dart` | Parity harness W1-W6 | VERIFIED | 45 test cases across 19 parity groups |
| `test/screens/fatca_gate_test.dart` | Global gate regression | VERIFIED | 8 tests including async hydration |
| `test/services/suggestion_3a_cap_test.dart` | 3a cap regression | VERIFIED | 8 cases |
| `test/screens/retirement_dashboard_profile_test.dart` | D7/D8 regression | VERIFIED | 3+11 tests (incl. settled-clear scenario) |
| `test/screens/mariage_whatif_labels_test.dart` | D9 + ghost-conjoint | VERIFIED | 11 tests (6 ghost-conjoint including V2 signal priority) |
| `tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` | GREEN (was OPEN-RED) | VERIFIED | Maestro EXIT 0 cold + warm (device gate item 1) |
| `tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` | GREEN (was OPEN-RED) | VERIFIED | Maestro EXIT 0 cold + warm; 29 AX elements |
| `.planning/_walker/illogism-fixes/device-gate-20260611/` | Device gate evidence | VERIFIED | 19+ screenshots + logs present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `coach_profile.dart._estimateLppAvoir` | `LppCalculator.accumulateAvoir` | delegation | VERIFIED | `grep -c "LppCalculator." coach_profile.dart` ≥ 1 |
| `mariage_screen.dart` | `LppCalculator.monthlyRenteFromAvoir` | delegation | VERIFIED | 0.068 hardcoded → 0 matches |
| `minimal_profile_service.estimate3aTaxImpact` | `estimate3aTaxImpact(isMarried:, netProfessionalIncome:)` | parameter wiring | VERIFIED | `grep -n "isMarried" minimal_profile_service.dart` = 2 hits |
| `app.dart (redirect)` | `archetypeRedirectTarget` | function call | VERIFIED | 1 match in authenticated scope branch |
| `coach_profile.fromWizardAnswers` | household+civil_status gate | predicate guard | VERIFIED | `coach_profile.dart:3162-3191` dual-signal gate |
| `context_injector_service (BUDGET VIVANT)` | `BudgetLivingEngine.cappedMonthly3aSuggestion` | call + clamp | VERIFIED | wired in BUDGET VIVANT block |
| `coach_whisper_service Rule 2` | `BudgetLivingEngine.cappedMonthly3aSuggestion` | delegation | VERIFIED | commit `a5118d6e2`; 2 usages in coach_whisper_service.dart |
| `retirement_dashboard_screen._build` | `_everHadProfile` guard | state flag | VERIFIED | 6 references; line 432 check `else if (_everHadProfile)` |
| `retirement_dashboard_screen CTA` | `/onb` route | `context.go('/onb')` | VERIFIED | line 1159 |
| `life_events_service.simulate` | bounded CC art.122 formula | `clamp(0, ∞)` + `avoirAuMariage` | VERIFIED | lines 148/172 |
| `cap_sequence_engine._estimateAvsMonthly` | `AvsCalculator` with lacunes/arrivalAge | full param delegation | VERIFIED | Codex W4 `423bfeed8` extended from plan 13 |
| `affordability_screen (both routes)` | `revenuBrutMenageFromProfile` | helper call | VERIFIED | lines 64/110 |
| `ArbitrageEngine.compareRenteVsCapital` | `canonicalConfidence` param | optional param | VERIFIED | extended to allocation/location screens by Codex W3 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `RenteVsCapitalScreen` | `_lppTotalCtrl` | `_autoFillFromProfile` → `ProfileDataSource` or empty | Yes (real profile or empty; no fiction) | FLOWING |
| `ChatFactCard` (hero fact) | `confidenceState` | `_factConfidenceState` → `EnhancedConfidence.combined` from `CoachProfileProvider` | Yes (canonical 4-axis score) | FLOWING |
| `RetirementDashboardScreen` | `_projection` | `ForecasterService.project()` + `_everHadProfile` guard | Yes (real projection or recoverable error state) | FLOWING |
| `MariageScreen` | `_revenu2IsHypothesis` / `revenu2` | `profile.conjoint?.revenuBrutMensuel` or default=60000 with label | Yes (real when partner data exists, labeled hypothesis otherwise) | FLOWING |
| `AffordabilityScreen` | `_revenu` | `revenuBrutMenageFromProfile(profile)` → `CoachProfile.revenuBrutAnnuelCouple` | Yes (canonical couple income) | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Financial parity W1-W6 | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | 45/45 passes (documented in phase SUMMARYs) | PASS |
| FATCA global gate | `flutter test test/screens/fatca_gate_test.dart` | 8/8 passes incl. async hydration (plan 08 + Codex P1) | PASS |
| 3a suggestion cap | `flutter test test/services/suggestion_3a_cap_test.dart` | 8/8 passes | PASS |
| ILLOG-01 fiction defaults | Maestro `bug__ILLOG01__rvc_fiction_defaults.yaml` | EXIT 0 cold + warm (PHASE-DEVICE-GATE item 1) | PASS |
| ILLOG-02 AX tree | Maestro `bug__ILLOG02__rvc_ax_tree_empty.yaml` | EXIT 0 cold + warm; 29 AX elements | PASS |
| D10 whisper clamp | Device re-verify (refix section) | 1037 CHF (×7=7258 = legal ceiling), not 1541 | PASS |
| D7 /retraite settled-clear | `flutter test retirement_dashboard_profile_test.dart` | 11/11 incl. settled-clear scenario | PASS (widget; device pending) |
| Backend suite | `cd services/backend && python3 -m pytest tests/ -q` | 7586 passed, 116 skipped, 4 xfailed (plan 15 evidence) | PASS |

---

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes declared for this phase. Device gate walkthroughs (the phase's proof mechanism) are documented in `PHASE-DEVICE-GATE.md` with Maestro + idb evidence.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MATRIX-salarie_swiss-1/-2/-3/-4/-5 | 01,05,02,03 | Avoir LPP canonical, married barème, cross-screen parity, rente/replacement | SATISFIED | parity_test 45/45 |
| MATRIX-independent_no_lpp-1/-2/-3/-4/-5/-6 | 04,07,04,01,02,03 | Net plafond, convergence engines, LPP=0 gate, avoir/rente/replacement | SATISFIED | parity groups W4/Gates LPP |
| MATRIX-expat_us-1/-2/-3/-4/-5 | 08,08,01,02,03 | Global gate, 3a compute, avoir/rente/replacement | SATISFIED | fatca_gate_test 8/8; parity W6 6/6 |
| MATRIX-frontalier-1/-2/-3/-4/-5 | 08,01,02,03,01 | Cross-border 3a gate, avoir/rente/replacement | SATISFIED | ArchetypePredicates.canContribute3a; parity |
| MATRIX-cadre_divorce_hypo-1/-2/-3/-4/-5 | 07,01,02,03,12 | No LPP estimation for divorced, avoir/rente/replacement/split | SATISFIED | gate_divorce 4/4; life_events_divorce 5/5 |
| MATRIX-couple_acheteurs-1/-2/-3/-4 | 15,01,02,03 | Unified household income, avoir/rente/replacement | SATISFIED | affordability_prefill 6/6; parity |
| MATRIX-returning_swiss_gaps-1/-2/-3/-4/-5/-6 | 13,13,01,01,02,03 | AVS gaps plumbed, honest rente scene, avoir/rente/replacement | SATISFIED | parity W4 Rente AVS 4/4; storyboard 61/61 |
| MATRIX-jeune_diplome-2/-3/-5 | 13,03,11 | Career hypothesis label, replacement rate, liquidity tagged | SATISFIED | storyboard W4 3/3; plan 11 confidence_source 3/3 |
| MATRIX-D1 | 06 | Archetype truth captured at onboarding | SATISFIED | 3 new scenes wired; 39/39 onboarding tests |
| MATRIX-D2 | 11 | Hero gated when combined<50 | SATISFIED | home_hero_confidence_test 4/4 |
| MATRIX-D3 | 03 | Replacement rate divergence (63% vs 46.5%) closed | SATISFIED | parity W3 8/8 |
| MATRIX-D4 | 02 | Single rente/rachat conversion rate per case | SATISFIED | parity W2 6/6 |
| MATRIX-D5 | 10 | Fiction defaults eliminated from RvC | SATISFIED | ILLOG-01 Maestro EXIT 0 |
| MATRIX-D6 / ILLOG-02 | 09 | RvC AX tree populated | SATISFIED | ILLOG-02 Maestro EXIT 0; 29 elements |
| MATRIX-D7 | 16 | /retraite doesn't show «4 infos» when /home has data | SATISFIED (widget) / HUMAN (device) | 11/11 tests incl. settled-clear; device re-capture outstanding |
| MATRIX-D8 | 16 | CTA routes to real onboarding | SATISFIED | Maestro tapOn EXIT 0; device screenshot |
| MATRIX-D9 | 17 | Mariage what-if declares hypotheses | SATISFIED | D9-mariage-hypothesis-label.png; tests 11/11 |
| MATRIX-D10 | 14 + device-gate refix | 3a suggestion ≤ statutory ceiling | SATISFIED | whisper 1037 CHF (×7=7258); device screenshot |
| MATRIX-D11 | 17 | Raw AX key labels localized | SATISFIED | D11-explorer-localized-a11y.png; grep 0 raw labels |
| MATRIX-D12 | 11 | Confidence score source unified | SATISFIED | confidence_source_unification 3/3 |
| MATRIX-W5-i18n-hardcode | 17 | «Document non disponible» via AppLocalizations | SATISFIED | grep 0 in app.dart |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `apps/mobile/lib/l10n/app_fr.arb` | (deferred items only) | accent FR violations pre-existing: `securite` → `sécurité` in `response_card_service.dart:983/988`, `premier_eclairage_selector.dart:257/259`, `tax_calculator.dart:263` | WARNING | Pre-existing, documented in `deferred-items.md` rows 1-4; NOT introduced by this phase (Karpathy #3 explicitly stated); separate PR recommended |
| `services/backend/app/models/lucidity/_payload.py`, `coach_tools.py`, `anthropic_defer_loading_adapter.py` | various | «LCC art. 28» remaining beyond plan 15 one-liner | INFO — CLOSED | Codex W4 post-review gap closure `17f0adc9c` corrected all runtime backend paths; only `educational_content_service.py:228,233,234` left (correct citation for consumer credit) |
| `apps/mobile/lib/services/premier_eclairage_selector.dart` | 257,259 | Hardcoded FR strings (`securite`) in an alert string — pre-existing, not user-facing via ARB | INFO | Pre-existing debt, logged in deferred-items.md; out of scope (deferred-items.md row 3 + 11) |

**No BLOCKER-level anti-patterns**: no `TBD`/`FIXME`/`XXX` unreferenced debt markers in phase-modified files found in any SUMMARY. All deviations documented with fix commits.

---

### Human Verification Required

#### 1. D7 /retraite — on-device green screenshot of fixed behavior

**Test:** Seed a hydrated profile (via /onb walkthrough or known seed), navigate to /home (observe Avoir LPP shown), then navigate to /retraite tab — verify it shows the projection or `_buildProjectionUnavailable` state, never «4 infos suffisent — Commencer — 2 min» (State C).

**Expected:** /retraite renders the retirement dashboard or the «tes données sont là» recoverable projection state. State C only appears on a genuinely empty profile. The /home→/retraite inconsistency (D7) should be gone.

**Why human:** The onboarding-shell screen uses custom-paint text-links («Continuer sans compte» / «J'ai déjà un compte») with sparse AX trees — only 1 AX element, not hittable by idb taps or Maestro. A fully hydrated profile could not be deterministically driven to /retraite post-fix by automation. The fix is widget-test-verified (11/11, including the exact device-proven settled-clear mechanism). The device root cause was proven via an instrumented probe (`D7-probe-hasProfile-true-then-false-settled-clear.log`). What's outstanding is the on-device green screenshot confirming the fixed behavior end-to-end. Automating this requires either a seeded profile or solving the onboarding-shell AX gap (separate work).

---

### Gaps Summary

No BLOCKER gaps. One item requires human verification (D7 device screenshot) before the phase can be marked fully `passed`.

**Phase-level verdict: ACHIEVED WITH CAVEATS**

All 5 root causes addressed with code, tests, and device evidence:

- **W1 (canonical numbers):** One source per quantity — `LppCalculator.accumulateAvoir/.monthlyRenteFromAvoir`, `ReplacementRate`, `estimate3aTaxImpact(isMarried:, netProfessionalIncome:)`, `Pillar3aRoomCalculator.cappedMonthly3aSuggestion`. Financial parity harness 45/45. Device: /home = RvC = Prévoyance for the same profile (was 8× apart).

- **W2 (archetype gates):** 3 new onboarding scenes capture employment/civil/AVS. ArchetypePredicates L1 shared gate in both engines. Global GoRouter FATCA redirect (+ Codex P1 async reactivity fix). Ghost-conjoint reads both `q_household_type` and `q_civil_status` signals. Device: indépendant no phantom LPP; expat_us redirected to waitlist.

- **W3 (estimé-vs-connu discipline):** Fiction defaults eliminated from RvC. Confidence Gate 3-state on hero. Single canonical confidence source (Codex W3 extended to all arbitrage screens). Maestro ILLOG-01/02 EXIT 0.

- **W4 (domain corrections):** Divorce split bounded to marriage period with isIncomplete state. AVS gapFactor plumbed to all AVS estimators including cap_sequence (Codex W4). D10 whisper clamped on both LLM-context and deterministic paths. Affordability household income unified. LCC citation swept from all runtime backend paths (Codex W4).

- **W5 (honest surfaces):** D7 retirement dashboard no longer shows State C on hydrated profile (widget-test-proven; device re-capture pending). D8 CTA routes to real /onb. D9 what-if labels hypotheses; ghost conjoint fixed with dual-signal priority. D11 raw AX key labels localized. i18n hardcode migrated.

**One honest caveat:** D7 on-device green screenshot is outstanding due to onboarding-shell idb-tap automation gap. The fix is sound (device-proven root cause, widget-test-verified fix), but the on-device green capture has not been produced.

---

_Verified: 2026-06-12T00:30:00Z_
_Verifier: Claude (gsd-verifier)_
_Branch: qa/runtime-navigation-spine-20260602_
_Mobile suite at phase end: 9446 passed | Backend suite: 7586 passed | flutter analyze: clean_
