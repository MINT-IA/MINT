# Requirements: MINT v2.0 -- Mint Systeme Vivant

**Defined:** 2026-04-06
**Core Value:** User opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere -- then knows exactly what to do next.

## v2.0 Requirements

Requirements for milestone v2.0. Each maps to roadmap phases.

### Le Parcours Parfait

- [x] **PATH-01**: Lea (22, VD, firstJob) completes full golden path: landing -> auth -> onboarding intent -> premier eclairage -> financial plan -> first check-in prompt
- [x] **PATH-02**: User can authenticate via magic link (primary) or Apple Sign-In (secondary), with email+password as fallback
- [x] **PATH-03**: Onboarding collects intent + 3 inputs (age, revenu, canton) and delivers premier eclairage within 5 minutes total
- [x] **PATH-04**: Coach responses for firstJob intent are contextual, use VD regional voice (septante/nonante), and pass 4-layer insight engine
- [x] **PATH-05**: Every screen in Lea's path has loading states, error states, empty states, and smooth transitions
- [x] **PATH-06**: Integration test covers full Lea journey and fails if any link breaks

### Intelligence Documentaire

- [x] **DOC-01**: User can capture a financial document via camera, gallery (screenshot), or PDF upload
- [x] **DOC-02**: LLM Vision (Claude) extracts structured fields from Swiss financial documents (certificat LPP, certificat de salaire, attestation 3a, police d'assurance)
- [x] **DOC-03**: Per-field confidence thresholds enforced (salary >= 0.90, LPP capital >= 0.95) -- below threshold triggers in-app verification screen
- [x] **DOC-04**: LPP plan type detected (legal / surobligatoire / 1e) before conversion rate extraction -- 1e defaults to capital-only projection with explicit warning
- [x] **DOC-05**: Cross-field coherence checks validate obligatoire + surobligatoire ~ total (catches 10x hallucination errors)
- [x] **DOC-06**: Extracted fields auto-populate CoachProfile via ProfileEnrichmentDiff (never direct writes) with user confirmation
- [x] **DOC-07**: Immediate premier eclairage generated from newly extracted data after document processing
- [x] **DOC-08**: Original document image deleted immediately after extraction (nLPD compliance) -- audit log retained
- [x] **DOC-09**: LLM extraction includes mandatory `source_text` field for traceability -- extraction without source_text is rejected
- [x] **DOC-10**: Pre-extraction validation rejects non-financial documents with friendly error message

### Moteur d'Anticipation

- [x] **ANT-01**: Swiss fiscal calendar triggers fire for 3a deadline (Dec 31), cantonal tax declaration deadlines, and LPP rachat windows
- [x] **ANT-02**: Profile-driven triggers detect salary increase -> 3a max recalculation, age milestone -> LPP bonification rate change
- [x] **ANT-03**: All alerts use AlertTemplate enum (Educational: title + fact + source + simulatorLink) -- never personalized imperatives
- [x] **ANT-04**: ComplianceGuard.validateAlert() validates every alert before display -- blocks "tu devrais", benefit claims, banned terms
- [x] **ANT-05**: Frequency cap: max 2 anticipation signals per user per week on Aujourd'hui
- [x] **ANT-06**: Card ranking: priority_score = timeliness x user_relevance x confidence -- top 2 as cards, rest in expandable section
- [x] **ANT-07**: Dismissal UX: each signal card has "Got it" or "Remind me later" -- snooze logic per trigger type
- [x] **ANT-08**: Triggers are rule-based (zero LLM cost, deterministic) -- LLM used only for optional narrative enrichment

### Memoire Narrative

- [x] **BIO-01**: FinancialBiography stores facts, decisions, events with causal/temporal links -- local-only, never sent to external APIs
- [x] **BIO-02**: Biography encrypted at rest (AES-256 via flutter_secure_storage key + sqflite)
- [x] **BIO-03**: Coach receives AnonymizedBiographySummary only (max 2K tokens) -- no names, exact salary, employer, IBAN, identifiable dates
- [x] **BIO-04**: Coach references biography naturally ("Ton salaire a augmente a un peu moins de 100k") -- never cites upload dates, filenames, or exact amounts
- [x] **BIO-05**: Privacy control screen ("Ce que MINT sait de toi") lets user view, edit, delete each fact with source and date
- [x] **BIO-06**: Data freshness decay model: annual fields decay after 12 months, volatile fields after 3 months -- stale fields flagged and excluded from projections
- [x] **BIO-07**: Coach guardrails for caisse data: always dates the source, uses conditional language, never presents extracted data as current fact
- [x] **BIO-08**: When data freshness-adjusted weight drops below 0.60, coach proactively prompts for document refresh

### Interface Contextuelle

- [x] **CTX-01**: Aujourd'hui displays max 5 cards: hero stat + narrative, anticipation signal, progress/milestone, action opportunity, expandable "See more"
- [x] **CTX-02**: Card ranking updates once per session (app launch), not on scroll -- deterministic per session
- [x] **CTX-03**: Coach opener is biography-aware and LSFin compliant -- ends with user-initiated action, never imperatives
- [x] **CTX-04**: Each card deep-links to relevant simulator or tool
- [x] **CTX-05**: Completed action demotes its triggering card in priority ranking
- [x] **CTX-06**: 3-tab shell (Aujourd'hui, Coach, Explorer) + ProfileDrawer remain unchanged -- no tab removal

### QA & Visual

- [ ] **QA-01**: 9 personas (Lea, Marc, Sophie, Thomas, Anna, Pierre, Julia, Laurent, Nadia) each complete golden path integration tests
- [ ] **QA-02**: Each persona includes >= 1 error recovery scenario with defined UX (blurry doc, wrong income, FATCA missing, etc.)
- [ ] **QA-03**: Golden Screenshots (Niveau 1): pixel diff > 1.5% = red in CI, 2 phone sizes x FR + 1 DE golden per phase, updated only with PR justification
- [ ] **QA-04**: Patrol Integration Tests (Niveau 2): real navigation on emulator (iOS 17 iPhone 15 + Android API 34 Pixel 7), screenshot at each key step, visual checklist per screenshot
- [ ] **QA-05**: Patrol runs at end of phase (both platforms), dev->staging (iOS only), staging->main (both platforms -- full regression)
- [ ] **QA-06**: Coach compliance test suite: zero banned terms, ComplianceGuard 100%, no PII in system prompt, confidence score > 0
- [ ] **QA-07**: DE + IT financial terminology accuracy >= 85% in coach responses -- below threshold triggers language-specific prompt tuning
- [ ] **QA-08**: Accessibility: WCAG 2.1 AA on all new screens (VoiceOver + TalkBack, contrast >= 4.5:1, tap targets >= 44pt, font scaling 200%)
- [ ] **QA-09**: Document Factory generates realistic Swiss test documents (SVG templates with persona-specific values, exportable as PDF)
- [ ] **QA-10**: Cross-cutting: every phase includes ComplianceGuard validation, flutter analyze 0 errors, flutter test + pytest pass

### Compliance (Cross-Cutting)

- [ ] **COMP-01**: ComplianceGuard validates ALL new output channels: alerts (ANT), narrative refs (BIO), coach openers (CTX), extraction insights (DOC)
- [x] **COMP-02**: No stale data as truth: every reference to user data is dated or conditioned -- projections disclose data age
- [x] **COMP-03**: FinancialBiography data never leaves device -- AnonymizedBiographySummary only in LLM prompts
- [x] **COMP-04**: Document images deleted in `finally` blocks (not just happy path) -- deletion audit log retained 2 years
- [ ] **COMP-05**: All new user-facing strings in 6 ARB files via AppLocalizations -- zero hardcoded strings

## v3.0 Requirements (Deferred)

### Connexions Externes

- **EXT-01**: bLink production OAuth (requires SFTI membership + per-bank contracts)
- **EXT-02**: Pension fund API integration (no live API exists yet)
- **EXT-03**: Tax adapter with cantonal rules JSON
- **EXT-04**: Email forwarding adapter for document ingestion

### Advanced Features

- **ADV-01**: Background processing for anticipation (WorkManager)
- **ADV-02**: Cloud sync for FinancialBiography with E2E encryption
- **ADV-03**: Voice AI integration
- **ADV-04**: Multi-LLM routing

## Out of Scope

| Feature | Reason |
|---------|--------|
| bLink production | SFTI membership + per-bank contracts = 18-24 months |
| bLink sandbox | Deferred to v3.0 -- sandbox without production path is low-value code |
| Background anticipation processing | WorkManager complexity; foreground-only sufficient for v2.0 |
| FinancialBiography cloud sync | Requires E2E encryption architecture; local-only for v2.0 |
| Voice AI | Phase 3 strategic roadmap |
| Money movement / transactions | Never (compliance -- read-only always) |
| Product recommendations / ranking | Never (LSFin compliance) |
| Transaction categorization | Scope creep risk; violates LSFin |
| Email forwarding adapter | v3.0 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PATH-01 | Phase 1 | Complete |
| PATH-02 | Phase 1 | Complete |
| PATH-03 | Phase 1 | Complete |
| PATH-04 | Phase 1 | Complete |
| PATH-05 | Phase 1 | Complete |
| PATH-06 | Phase 1 | Complete |
| DOC-01 | Phase 2 | Complete |
| DOC-02 | Phase 2 | Complete |
| DOC-03 | Phase 2 | Complete |
| DOC-04 | Phase 2 | Complete |
| DOC-05 | Phase 2 | Complete |
| DOC-06 | Phase 2 | Complete |
| DOC-07 | Phase 2 | Complete |
| DOC-08 | Phase 2 | Complete |
| DOC-09 | Phase 2 | Complete |
| DOC-10 | Phase 2 | Complete |
| ANT-01 | Phase 4 | Complete |
| ANT-02 | Phase 4 | Complete |
| ANT-03 | Phase 4 | Complete |
| ANT-04 | Phase 4 | Complete |
| ANT-05 | Phase 4 | Complete |
| ANT-06 | Phase 4 | Complete |
| ANT-07 | Phase 4 | Complete |
| ANT-08 | Phase 4 | Complete |
| BIO-01 | Phase 3 | Complete |
| BIO-02 | Phase 3 | Complete |
| BIO-03 | Phase 3 | Complete |
| BIO-04 | Phase 3 | Complete |
| BIO-05 | Phase 3 | Complete |
| BIO-06 | Phase 3 | Complete |
| BIO-07 | Phase 3 | Complete |
| BIO-08 | Phase 3 | Complete |
| CTX-01 | Phase 5 | Complete |
| CTX-02 | Phase 5 | Complete |
| CTX-03 | Phase 5 | Complete |
| CTX-04 | Phase 5 | Complete |
| CTX-05 | Phase 5 | Complete |
| CTX-06 | Phase 5 | Complete |
| QA-01 | Phase 6 | Pending |
| QA-02 | Phase 6 | Pending |
| QA-03 | Phase 6 | Pending |
| QA-04 | Phase 6 | Pending |
| QA-05 | Phase 6 | Pending |
| QA-06 | Phase 6 | Pending |
| QA-07 | Phase 6 | Pending |
| QA-08 | Phase 6 | Pending |
| QA-09 | Phase 6 | Pending |
| QA-10 | Phase 6 | Pending |
| COMP-01 | Phase 6 | Pending |
| COMP-02 | Phase 3 | Complete |
| COMP-03 | Phase 3 | Complete |
| COMP-04 | Phase 2 | Complete |
| COMP-05 | Phase 6 | Pending |

**Coverage:**
- v2.0 requirements: 53 total
- Mapped to phases: 53
- Unmapped: 0

---
*Requirements defined: 2026-04-06*
*Last updated: 2026-04-06 after roadmap creation*
