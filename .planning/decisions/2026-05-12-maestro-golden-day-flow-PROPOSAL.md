---
description: Proposal for the « golden day-in-the-life » Maestro flow + MDM Pillar 0 inversion (sim-first then docs). Awaiting panel audit before any commit. Per memory `feedback_expert_panel_pattern`.
type: decision-proposal
status: PROPOSED — pending panel verdict
created: 2026-05-12
author: orchestrator (Claude Opus 4.7) after Julien directive 2026-05-12T09:00Z
---

# Proposal — Golden Day-in-the-Life Maestro Flow + MDM Pillar 0 inversion

## Context

Today's debug session surfaced two cognitive failure modes :

1. **8h on the periphery while the core flow was broken** (P003 — authenticated coach returns canned fallback on first prompt with full inline profile). Surfaced by Julien walking the app, not by my doc-reading.

2. **MDM v1 Pillar 0 (Session-state Project CAP) reads docs FIRST.** That's still doc-first. The proposal here is to invert : **sim walkthrough first, then docs**, so observation drives priority instead of registry rows.

## Two related changes

### Change 1 — MDM Pillar 0 inversion : « sim-first, docs-second »

Every session starts with :
1. Boot iPhone 17 Pro sim + log in as one archetype (rotating through 8).
2. Walk cold-launch → bêta dismiss → LandingScreen → wedge → account creation → onboarding chat → CapDuJourBanner → coach prompt → simulator → explorer → daily nudge. Note every defect surfaced in `.planning/cycles/_SESSION-<date>-OBSERVED.md`.
3. THEN read project-state docs (STATE.md, MILESTONE, CONTEXT, BUGS-REGISTRY, deferred-items, ROADMAP_V2, SOT, open PRs).
4. Triage : the next bug to attack = highest-impact OBSERVED defect crossed against registry position.
5. Cycle MDM Pillars 1-7.
6. Re-walk sim post-deploy → tick OBSERVED defect closed OR loop Pillar 1.

The rationale : observation > docs for priority anchoring. Doc-first is what produced today's morning drift.

### Change 2 — The « Golden Day-in-the-Life » composite Maestro flow

A single composite flow per archetype that walks the canonical user trajectory from cold install to lucidity output. Composable from 8 phase fragments. CI-blocking on every PR. Repeats until GREEN.

#### The 8 phases mapped to MINT surfaces

**Phase A — Anonymous wedge (pre-auth)**
```
cold-launch → bêta modal dismiss → LandingScreen
→ tap « Parle à Mint » → AnonymousChatScreen
→ inputText 3 turns with archetype-specific profile data
→ assertVisible : coach « premier éclairage » response
→ 3-turn cap hit → auth gate « Crée un compte »
```
Current state : ✅ shippable. `julien_swiss.yaml` + `lauren_expat_us.yaml` exist. P003 fix shipping today in PR #573 unblocks coach response quality.

**Phase B — Account creation**
```
→ tap « Créer un compte »
→ choose : magic-link / email-password / Apple Sign-In
→ for CI : email-password with test-user pré-provisioned
  (D-04 staging Railway : e2e-<archetype>@example.com)
→ assertVisible : email verification OR auto-confirm en staging
→ context.go('/home') → Aujourd'hui visible
```
Current state : ✅ shippable. Backend register endpoint GREEN. Magic-link + Apple Sign-In wired.

**Phase C — Onboarding minimal + profile-building chat**
```
→ AujourdhuiScreen affiche CapDuJourBanner « Parle-moi de toi »
→ tap → context.go('/coach/chat')
→ coach pose questions séquentielles :
    - âge ? → user répond → ProfileExtractor.write(birth_year)
    - canton ? → write(canton)
    - état civil ? → write(household_type)
    - revenus nets/mois ? → write(income_net_monthly)
    - épargne actuelle ? → write(total_savings)
    - LPP avoir ? → write(lpp_insured_salary)
→ assertVisible : factfindCompletionIndex >= 0.5 (chip « profil 60% »)
```
Current state : ⚠️ partial. ProfileExtractor exists but the guided question-by-question conversation is NOT wired today. The factfind UX is more « fill the form » than « guided conversation ». **Gap to file in Phase 97 W8 or v2.10.**

**Phase D — Document upload (FactFind boost)**
```
→ tap « Scanner un document » sur Aujourd'hui ou Coach
→ Maestro stub VisionKit avec fixture image
→ backend /api/v1/documents/upload → Vision API extracts
→ ExtractionReviewSheet (snap 0.3/0.6/0.95) confirms
→ Profile fields updated, factfindCompletionIndex → 0.8
→ DAG invalidation : inputs_hash change → snapshot superseded
```
Current state : ✅ shippable. Phase 28 shipped in v2.7. EXIF scrub shipped yesterday (T001 W7). VisionKit + ML Kit wired.

**Phase E — Financial overview generated**
```
→ retour Aujourd'hui
→ assertVisible : ScoreRevealScreen accessible (FRI 4-axis)
→ tap → replacement_ratio, months_liquidity, tax_saving_potential
→ assertVisible : « Confidence score 65% » avec enrichmentPrompts
→ takeScreenshot : 05-financial-overview.png
```
Current state : ✅ shippable. S54 FinancialHealthScoreService + ScoreRevealScreen.

**Phase F — Plan / Simulation / Recommendation**
```
→ AujourdhuiScreen CapDuJour « Optimise ton 3a 2026 »
→ tap MintCardActionBar « Simule » → /explorer?simulate=cap_du_jour
→ Pillar3aOptimizerScreen → run simulation avec profile data
→ assertVisible : « Marge fiscale 4'200 CHF » + {{cite:r3a_plafond_salarie_2026}}
→ ReturnContract : tap « Retour au coach » → ScreenReturn pushed
→ Aujourd'hui : coach follow-up sur la simulation
```
Current state : ⚠️ partial. P002 (0 production cards wired with MintCardActionBar) BLOCKS this — only ChatAsVerbDemoScreen has the action bar wired. **Close P002 first in Phase 97 W5.**

**Phase G — Daily use loop (J+1, J+7, J+30)**
```
→ environment date = J+1 (via MINT_E2E_FAKE_DATE dart-define)
→ launch app → StreakService détecte daily check-in
→ ProactiveTriggerService déclenche nudge JITAI (post-salary day)
→ user tap notification → /coach/chat?topic=monthly_review
→ coach demande « comment s'est passé ton mois ? »
→ environment date = J+7 → WeeklyRecapService génère summary
→ environment date = J+30 → achievements unlocked, badges S54
```
Current state : ⚠️ partial. Most services shipped (S54/S57/S59/S61) but **time-travel sim requires MINT_E2E_FAKE_DATE injection**. Not yet wired. Either dart-define or 3 separate flows with `simctl status_bar override`.

**Phase H — Lucidity output**
```
→ après 7 jours données accumulées
→ assertVisible : Eclairage card delivered dans coach (Phase 86)
→ tap → eclairage révèle piège évité / coût caché / action prochaine
→ tap deep-link interne → CantonalBenchmarkScreen (S60)
→ assertVisible : comparaison anonymisée, no social ranking language
→ retour Aujourd'hui
→ assertVisible : SessionReport préliminaire (precisionScore >= 0.7)
```
Current state : ⚠️ partial. Premier éclairage shipped (Phase 86). Cantonal benchmark shipped (S60). **SessionReport gaps known per SOT.md** : confidenceScore + chiffreChoc + alertes + simulationAssumptions + generatedLetters NOT yet implemented. **Phase 97 D-30 ship gate demands these fields.**

#### 8-archetype parameterization

Per Phase 97 D-05 (locked) : `swiss_native`, `expat_eu`, `expat_us` (FATCA), `cross_border`, `indep_with_lpp`, `indep_no_lpp`, `returning_swiss`, `near_retirement`.

Single flow file `golden_day_in_the_life.yaml` invoked 8 times via :
```
maestro test golden_day_in_the_life.yaml \
  --env MINT_E2E_ARCHETYPE=julien_swiss
maestro test golden_day_in_the_life.yaml \
  --env MINT_E2E_ARCHETYPE=expat_us
... × 6 more
```

Phase D-06 dart-define `MINT_E2E_ARCHETYPE` already plumbed (or to be wired).

#### CI mechanics

1. **Lefthook pre-commit** : smoke flow only (90s, cold-launch + 3 tabs + back). Block commit on fail.
2. **PR check GitHub Actions** : current phase flow. Block merge on fail.
3. **Nightly cron Mac mini** : full 32 flows × 8 archetypes. JUnit aggregated. HTML report.
4. **Pre-ship D-30 gate** : 7-day soak avec zéro RED sur golden-day composite.

#### Sequencing proposal (W8-W13, ~5-6 days)

| Week | Deliverable | Gate |
|---|---|---|
| W8 | Phase A + B + C composite (`julien_swiss` only) | Composite GREEN end-to-end |
| W9 | Phase D added | Document upload GREEN |
| W10 | Close P002 (MintCardActionBar wiring) + Phase F | Simulation flow GREEN |
| W11 | MINT_E2E_FAKE_DATE + Phase G | Time-travel sim GREEN J+1/J+7/J+30 |
| W12 | SessionReport completion + Phase H | Lucidity output GREEN |
| W13 | Parameterize × 8 archetypes + ship matrix | All 8 archetypes × composite GREEN |

## What is to be audited

1. Is the « sim-first » inversion of MDM Pillar 0 the right discipline ?
2. Is Maestro 2.5.1 actually capable of all 8 phases as described ? Specific gotchas ?
3. Is the 8-archetype dart-define parameterization the right approach vs separate flows per archetype ?
4. Does Phase C (« guided conversation profile-build ») match MINT's wiki-first positioning, or does it import a Cleo/Wealthfront chat-first pattern that contradicts v2.9 doctrine ?
5. Phase G time-travel sim : is the dart-define approach safe, or does it create a server-clock/client-clock split bug ?
6. CI mechanics : is Mac mini self-hosted runner adequate or does it create single-point-of-failure ? When does Maestro Cloud become unavoidable ?
7. LSFin compliance : does the day-in-the-life flow (especially document upload + advice) expose new LSFin Art 7-10 / nLPD Art 8 surface that needs explicit consent capture beyond what's already shipped ?
8. The « repeat until GREEN » discipline : how does flake handling work ? When is a 30-run statistical signal needed before declaring success ?
9. The W8-W13 sequencing : realistic, or are there hidden dependencies that block parallel work ?
10. Is the whole approach the right strategic move, OR is it putting infrastructure ahead of product (P002 wiring, P001 narrator quality) ?

## Counter-arguments and data gaps

**Counter-arguments (steelman against the proposal) :**

- *« Build the test before the feature is irresponsible »* — true critique. The proposal admits 4 of 8 phases (C / F / G / H) test features that aren't shipped. Counter-argument : Maestro flows define an EXECUTABLE SPEC ; writing the test first IS the requirement document. Risk : the test passes structurally before the feature is real, producing false confidence (see panel adversarial finding).
- *« 9 pillars + Pillar 0.a/b/c subdivisions = ceremony »* — see CLAUDE.md §7 #2 (Simplicity First). Counter-argument : each pillar is justified by a specific failure mode documented in MDM v1 §"Anti-patterns this method kills". Empirical : without Pillar 6 4-dim Cube, the 2026-05-11 W7 iter#6 « GREEN gates » claim shipped a broken TestFlight build. The Pillar 0 inversion is justified by today's same-day morning failure.
- *« Sim-first is a doctrine that LLM agents can fake »* — adversarial finding. The OBSERVED.md is self-attested. Counter-argument : the mechanical anti-game lint (TODO `tools/checks/observed_freshness.py`) is the regression lock layer ; without it the discipline is gameable.

**Data gaps (what we don't know yet) :**

- No measurement of MINT's current first-prompt → account-creation conversion rate. The proposal cites Cleo 30-45% pre-signup conversion as benchmark but MINT has no production measurement to compare against.
- No empirical data on Mac mini sim parallelism limits on the actual hardware (8GB vs 16GB vs 32GB). The panel cited industry numbers ; MINT-specific bench is needed.
- No staging environment SLA — the 7-day soak gate (D-22) assumes staging stays up that long ; Railway free tier has eviction rules unverified for this duration.
- No measurement of Anthropic API P95 latency from Railway staging — the 30s wall-time observed on P003 was a retry cascade ; baseline single-call P95 is unknown.
- The cost of MINT_E2E_FAKE_DATE Clock refactor : 60+ datetime call-sites identified but no LOC estimate or test coverage figure.
