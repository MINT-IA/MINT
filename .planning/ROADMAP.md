# Roadmap: MINT v2.0 Mint Systeme Vivant

## Overview

Transform MINT from a well-wired but passive app into a living financial intelligence system. Six phases build sequentially on a data dependency chain: first the golden path baseline works flawlessly, then documents flow in and enrich the profile, then biography captures the narrative, then anticipation rules fire on that data, then the Aujourd'hui surface integrates everything into ranked cards, and finally 9-persona QA gates the release. Each phase delivers a coherent, independently verifiable capability.

## Phases

- [ ] **Phase 1: Le Parcours Parfait** - Lea golden path end-to-end flawless (landing to check-in)
- [ ] **Phase 2: Intelligence Documentaire** - Photo/PDF upload to LLM extraction to profile enrichment to instant insight
- [ ] **Phase 3: Memoire Narrative** - Local-only encrypted financial biography with anonymized coach integration
- [ ] **Phase 4: Moteur d'Anticipation** - Rule-based proactive alerts (fiscal, profile, legislative triggers)
- [ ] **Phase 5: Interface Contextuelle** - Smart Aujourd'hui cards ranked by relevance (max 5 cards)
- [ ] **Phase 6: QA Profond** - 9 personas, error recovery, accessibility, multilingual validation, release gate

## Phase Details

### Phase 1: Le Parcours Parfait
**Goal**: A new user (Lea: 22, VD, firstJob) flows from landing to first check-in prompt without friction, dead ends, or broken states
**Depends on**: Nothing (first phase)
**Requirements**: PATH-01, PATH-02, PATH-03, PATH-04, PATH-05, PATH-06
**Success Criteria** (what must be TRUE):
  1. Lea (22, VD, firstJob) completes the full path from landing through auth, onboarding, premier eclairage, plan generation, to check-in prompt without manual intervention
  2. Every screen in the path handles loading, error, and empty states gracefully (no blank screens, no unhandled exceptions)
  3. Coach responses for firstJob intent use VD regional voice and pass the 4-layer insight engine (factual, human, personal, questions)
  4. An integration test covers the full Lea journey and fails CI if any link in the chain breaks
**Plans**: 5 plans
Plans:
- [x] 01-01-PLAN.md -- State widgets (MintLoadingState, MintErrorState) + landing page refinement + i18n keys
- [x] 01-02-PLAN.md -- Magic link auth backend + login screen redesign + post-auth routing
- [x] 01-03-PLAN.md -- Onboarding pipeline wiring (intent -> quick_start -> chiffre_choc -> plan -> coach) + 4-layer engine
- [ ] 01-04-PLAN.md -- Lea golden path integration test
- [x] 01-05-PLAN.md -- Apple Sign-In (iOS secondary auth method)
**UI hint**: yes

### Phase 2: Intelligence Documentaire
**Goal**: Users can photograph or upload a Swiss financial document and see their profile instantly enriched with extracted data they confirm
**Depends on**: Phase 1
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07, DOC-08, DOC-09, DOC-10, COMP-04
**Success Criteria** (what must be TRUE):
  1. User can capture a document via camera, gallery, or PDF upload and see structured fields extracted with per-field confidence badges
  2. LPP plan type (legal / surobligatoire / 1e) is detected before conversion rate extraction -- 1e plans show capital-only projection with explicit warning
  3. Extracted fields flow into CoachProfile via ProfileEnrichmentDiff with user confirmation screen -- never direct writes
  4. Original document image is deleted immediately after extraction (including error paths via finally blocks), with audit log retained
  5. A premier eclairage is generated from the newly extracted data within seconds of document processing
**Plans**: TBD
**UI hint**: yes

### Phase 3: Memoire Narrative
**Goal**: MINT remembers the user's financial story over time and the coach references it naturally without exposing private data
**Depends on**: Phase 2
**Requirements**: BIO-01, BIO-02, BIO-03, BIO-04, BIO-05, BIO-06, BIO-07, BIO-08, COMP-02, COMP-03
**Success Criteria** (what must be TRUE):
  1. Financial events (document scans, life events, decisions) are recorded in an encrypted local-only store and never sent to external APIs
  2. Coach references biography naturally ("Ton salaire a augmente a un peu moins de 100k") using only AnonymizedBiographySummary (max 2K tokens, no PII)
  3. User can view, edit, and delete each stored fact with its source and date via the privacy control screen ("Ce que MINT sait de toi")
  4. Stale data (annual fields > 12 months, volatile fields > 3 months) is flagged, excluded from projections, and triggers a coach prompt for document refresh
  5. Every reference to user data in projections and coach responses is dated or conditioned -- no stale data presented as current fact
**Plans**: TBD
**UI hint**: yes

### Phase 4: Moteur d'Anticipation
**Goal**: MINT proactively surfaces timely financial signals before the user thinks to ask
**Depends on**: Phase 3
**Requirements**: ANT-01, ANT-02, ANT-03, ANT-04, ANT-05, ANT-06, ANT-07, ANT-08
**Success Criteria** (what must be TRUE):
  1. Swiss fiscal calendar triggers fire correctly for 3a deadline (Dec 31), cantonal tax deadlines, and LPP rachat windows
  2. Profile-driven triggers detect salary increase (3a max recalculation) and age milestone (LPP bonification rate change) automatically
  3. All alerts use the AlertTemplate enum (Educational format) and pass ComplianceGuard.validateAlert() before display -- zero banned terms, zero imperatives
  4. Frequency cap enforced: max 2 anticipation signals per user per week, with dismissal/snooze logic per trigger type
  5. Triggers are deterministic rule-based (zero LLM cost) with LLM used only for optional narrative enrichment
**Plans**: TBD

### Phase 5: Interface Contextuelle
**Goal**: The Aujourd'hui tab shows a living, ranked set of cards that reflect what matters most to the user right now
**Depends on**: Phase 4
**Requirements**: CTX-01, CTX-02, CTX-03, CTX-04, CTX-05, CTX-06
**Success Criteria** (what must be TRUE):
  1. Aujourd'hui displays max 5 cards (hero stat, anticipation signal, progress, action opportunity, expandable overflow) ranked by priority_score = timeliness x relevance x confidence
  2. Card ranking is deterministic per session (computed at app launch, not on scroll) and completed actions demote their triggering card
  3. Coach opener is biography-aware and LSFin compliant, ending with user-initiated action (never imperatives)
  4. Each card deep-links to the relevant simulator or tool, and the 3-tab shell + ProfileDrawer remain unchanged
**Plans**: TBD
**UI hint**: yes

### Phase 6: QA Profond
**Goal**: All v2.0 capabilities are validated across 9 personas, hostile scenarios, accessibility standards, and multilingual accuracy before release
**Depends on**: Phase 5
**Requirements**: QA-01, QA-02, QA-03, QA-04, QA-05, QA-06, QA-07, QA-08, QA-09, QA-10, COMP-01, COMP-05
**Success Criteria** (what must be TRUE):
  1. All 9 personas (Lea, Marc, Sophie, Thomas, Anna, Pierre, Julia, Laurent, Nadia) complete golden path integration tests including at least 1 error recovery scenario each
  2. Golden Screenshots (pixel diff > 1.5% = red in CI) and Patrol integration tests (iOS 17 + Android API 34) pass on both platforms
  3. ComplianceGuard achieves 100% coverage on all new output channels (alerts, narrative refs, coach openers, extraction insights) with zero banned terms and zero PII in system prompts
  4. WCAG 2.1 AA met on all new screens (VoiceOver + TalkBack, contrast >= 4.5:1, tap targets >= 44pt, font scaling 200%)
  5. All new user-facing strings exist in 6 ARB files via AppLocalizations -- zero hardcoded strings, DE + IT financial terminology accuracy >= 85%

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Le Parcours Parfait | 0/5 | Planned | - |
| 2. Intelligence Documentaire | 0/TBD | Not started | - |
| 3. Memoire Narrative | 0/TBD | Not started | - |
| 4. Moteur d'Anticipation | 0/TBD | Not started | - |
| 5. Interface Contextuelle | 0/TBD | Not started | - |
| 6. QA Profond | 0/TBD | Not started | - |
