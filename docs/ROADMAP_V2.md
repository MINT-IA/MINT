# MINT — Strategic Roadmap V2 (Benchmark-Driven)

> Date: March 2026 | Version: 2.1 | Production: v0.9.1
> Based on: `visions/MINT_Analyse_Strategique_Benchmark.md` (40+ apps, 18 research themes)
> Execution method: Autoresearch Dev Agents (`visions/MINT_Autoresearch_Dev_Agents.md`)
> Last sync: 2026-03-21 — status column added, deliverables corrected against code

---

## EXECUTION PRINCIPLE

Every sprint uses autoresearch dev skills as primary execution method:
- `/autoresearch-calculator-forge` for financial calculations
- `/autoresearch-test-generation` for test coverage
- `/autoresearch-prompt-lab` for AI coaching prompts
- `/autoresearch-compliance-hardener` for compliance testing
- `/autoresearch-ux-polish` for UX refinement
- `/autoresearch-quality` for bug hunting
- `/autoresearch-i18n` for internationalization
- `/autoresearch-coach-evolution` for content quality

Each agent follows the Karpathy loop: modify code, execute tests, measure metric, keep if improved, reject if degraded, iterate. Every sprint deliverable is validated by automated test suites before merge.

---

## STATUS LEGEND

| Status | Meaning |
|--------|---------|
| `shipped` | Feature is in production code, tested, fully functional |
| `foundation` | Core service/class exists but wiring to UI or full feature incomplete |
| `partial` | Some deliverables shipped, others not started or stubbed |
| `planned` | Not yet started |

---

## Phase 1: "Le Conversationnel" (S51-S56, 0-6 months)

**Objective**: MINT parle. L'utilisateur pose des questions en langage naturel.

**Benchmark justification**:
- R1 (Chat AI): "Le chat est devenu la norme, pas une feature" — Cleo $250M ARR, bunq Finn 97% resolution
- R3 (Gamification): +48% engagement via streaks, +30% savings increase (academic research)
- 3a retroactif: unique 2026 market opportunity (new Swiss law), no competitor has it
- Financial Health Score: inspired by WHOOP Recovery Score — daily composite = daily return

| Sprint | Objective | Status | What actually shipped | Notes |
|--------|-----------|--------|-----------------------|-------|
| S51 | Chat AI MVP | `shipped` | `CoachChatScreen`, `CoachLlmService`, `ConversationMemoryService`, `ConversationStore`, `ComplianceGuard`, `HallucinationDetector`, `FallbackTemplates`, suggestion chips, typing indicator | Claude API live on staging + prod with BYOK |
| S52 | UX Cohesion | `shipped` | 4-tab shell (Aujourd'hui/Coach/Explorer/Dossier), 7 Explorer hubs, `CapEngine` (12-rule heuristic), `CapMemoryStore`, `ActionSuccess` bottom sheet, `GoalTracker`, life events detection, MintTextStyles/MintSpacing/MintMotion tokens, 0 GoogleFonts in lib/ | Roadmap label was "3a Retroactif simulator" — actual sprint pivoted to UX cohesion. Retroactive 3a screen exists at `/3a-retroactif` with `Retroactive3aCalculator` service, but was part of prior sprint work |
| S53 | Gate Closer | `shipped` | Honesty clause enforcement, disability gap fixes, AVS couple caps (LAVS art. 35 applied correctly), all 18 life events coverage, LPP split logic | 13e rente AVS not found in codebase — not yet implemented |
| S54 | Financial Health Score v1 | `shipped` | `FinancialHealthScoreService` (4-axis composite), `ScoreRevealScreen`, `StreakService` (with badges and milestones), `MilestoneV2Service`, achievements screen | FHS service exists and is functional; UI wiring to daily widget is partial |
| S55 | North Star screens | `shipped` | `QuickStartScreen` V2, `RetirementDashboardScreen` V2, `LandingScreen` V10, `ScoreRevealScreen`, 12 screens redesigned to Hero Plan / Decision Canvas templates | Sprint label was "Streaks + 10 Milestones" in old roadmap — actual S55 was visual premium |
| S56 | Chat Central | `shipped` | Claude API live (tool calling), `CoachOrchestrator`, `ContextInjectorService`, lightning menu wiring, `ProactiveTriggerService` (7 triggers), `RegionalVoiceService` (26 cantons), `RagRetrievalService` (FAQ fallback + cantonal context), `VoiceService` (stub backend + config), `WeeklyRecapService` (service layer), Dossier tab reorganization | RAG v2 file-based retrieval wired; vector store embedding pipeline not yet implemented. Voice service exists with stub backend — real STT/TTS not integrated |

**KPIs Phase 1**: DAU/MAU > 25%, Retention J7 > 35%, Chat used by > 40% active users

---

## Phase 2: "Le Compagnon" (S57-S62, 6-12 months)

**Objective**: MINT s'adapte a ta vie. Il se souvient et evolue.

**Benchmark justification**:
- R2 (Lifecycle): Noom 7-phase model — content adaptation = long-term retention driver
- R4 (Memory): Cleo 3.0 — "the AI remembers everything" as key differentiator for trust
- R5 (Proactivity): JITAI research — 52% engagement at workflow boundaries (post-salary, pre-tax-deadline)
- R7 (Social): Cantonal benchmarks fill a gap no Swiss app addresses (anonymized, no ranking)

| Sprint | Objective | Status | What actually shipped | Notes |
|--------|-----------|--------|-----------------------|-------|
| S57 | Lifecycle Engine + ScreenRegistry + ReadinessGate | `shipped` | `LifecyclePhase` (7-phase enum), `LifecycleDetector`, `LifecycleContentService`, `LifecycleAdaptation`, `ScreenRegistry` (109 surfaces with intentTag/behavior/requiredFields), `ReadinessGate` (3 levels) | Lifecycle engine pure functions; content adaptation wiring to coach system prompt is partial |
| S58 | AI Memory + RoutePlanner + ReturnContract | `foundation` | `RoutePlanner` service exists, `ScreenRegistry` complete, `GoalTrackerService` exists | `ReturnContract` / `ScreenReturn` model not found in codebase. `route_to_screen` tool in `coach_tools.py` not verified. Cross-session vector store not implemented |
| S59 | Weekly Recap AI | `foundation` | `WeeklyRecapService` (service layer complete), `WeeklyRecapScreen` (screen exists at `/coach/weekly-recap`) | Screen is implemented but route in app.dart shows it as live; quality of generated content depends on BYOK |
| S60 | Cantonal benchmarks | `shipped` | `CantonalBenchmarkService` (full 26-canton data), `CantonalBenchmarkScreen` at `/cantonal-benchmark`, no social comparison language | Service and screen fully implemented with compliance-safe language |
| S61 | JITAI Proactive nudges | `shipped` | `JitaiNudgeService` (trigger engine), `ProactiveTriggerService` (7 triggers: lifecycle change, weekly recap, goal milestone, seasonal, inactivity, confidence improvement, new cap) | Nudge delivery to UI is partial — trigger logic complete, notification wiring depends on `NotificationService` |
| S62 | Micro-challenges weekly | `shipped` | `AdaptiveChallengeService` (challenges by archetype and phase), `MilestoneV2Service`, `SeasonalEventService`, `CommunityChallengeService` | Challenge completion UI wiring partial; service layer complete |

**KPIs Phase 2**: Retention M3 > 40%, ConfidenceScore moyen > 55%, > 30% users with scanned doc

---

## Phase 3: "L'Expert" (S63-S68, 12-18 months)

**Objective**: MINT devient indispensable. Voice, humain, et communaute.

**Benchmark justification**:
- R6 (Voice): Cleo 3.0 two-way voice, bunq speech-to-speech — critical for 50+ age group
- R8 (Hybrid): Origin Financial model — AI + human = 52% trust increase (academic research)
- R9 (Multi-LLM): Monarch Money architecture — Claude primary + GPT-4o fallback = 99.9% uptime
- R10 (Agent): Albert autonomous agent — read-only agent (form pre-fill, letter generation) stays within MINT compliance posture

| Sprint | Objective | Status | What actually shipped | Notes |
|--------|-----------|--------|-----------------------|-------|
| S63 | Voice AI (STT+TTS) | `foundation` | `VoiceService` (class with stub backend), `VoiceConfig`, `VoiceChatIntegration`, `RegionalVoiceService` (26-canton flavor for system prompt) | Stub backend only — no real STT/TTS provider integrated. Regional voice flavor is for text coaching, not audio |
| S64 | Multi-LLM redundancy | `foundation` | `MultiLlmService` (class with provider health tracking, Claude primary + GPT-4o fallback) | Service layer exists; production failover not verified. Local model for sensitive calcs not implemented |
| S65 | Expert tier (human advisors) | `planned` | — | No advisor matching, dossier prep for human sessions, or scheduling implemented |
| S66 | Advanced gamification | `planned` | — | Community challenge service exists as skeleton; cantonal leagues not implemented |
| S67 | RAG v2 (comprehensive) | `foundation` | `RagRetrievalService` (3 document pools: concepts, cantons, FAQ; keyword-based scoring; source citations) | File-based keyword retrieval implemented. Vector embeddings not implemented. Document count: 45+ concepts, 26 cantonal docs (pending), 10 FAQ docs (pending) |
| S68 | Agent autonome v1 | `planned` | — | No form pre-fill, letter generation, or fiscal dossier prep implemented |

**KPIs Phase 3**: Retention M12 > 25%, NPS > 50, Revenue MRR > CHF 50K

---

## Phase 4: "La Reference" (S69+, 18-24 months)

**Objective**: MINT est le standard suisse.

| Sprint | Objective | Status | Autoresearch Skills Used |
|--------|-----------|--------|--------------------------|
| S69-S70 | Institutional APIs | `planned` | `/autoresearch-compliance-hardener`, `/autoresearch-calculator-forge` |
| S71-S72 | B2B caisses + RH | `planned` | `/autoresearch-ux-polish`, `/autoresearch-compliance-hardener` |
| S73-S74 | Open Finance bLink | `planned` | `/autoresearch-calculator-forge` |
| S75+ | Expansion DACH | `planned` | `/autoresearch-calculator-forge`, `/autoresearch-i18n` |

---

## MONETIZATION (aligned with phases)

| Tier | Price | Phase 1 Content | Phase 2+ Content |
|------|-------|-----------------|------------------|
| **Free** | 0 CHF | Chiffre choc, 1 simulation/day, educational content, ConfidenceScore basique | Same |
| **Plus** | 9.90 CHF/mo | Chat AI unlimited, all simulators, FHS, streaks & milestones, PDF reports | + Weekly Recap AI, micro-challenges |
| **Pro** | 29.90 CHF/mo | Voice AI, long-term memory, proactive JITAI alerts, cantonal benchmarks, OCR unlimited | + JITAI nudges, lifecycle adaptation |
| **B2B** | 5-15 CHF/employee/yr | White-label for employers/pension funds, aggregated wellness dashboard | Full platform, custom branding |

**Expert Session (add-on, not a tier)**:
- 129 CHF/session — consultation with a certified specialist (planificateur, fiscaliste, notaire)
- AI pre-fills dossier (profile + projections + questions) → specialist productive from minute 1
- Available to Pro subscribers as add-on
- MINT earns commission (10-20%) on specialist marketplace — no loss-leader risk

---

## RISKS & MITIGATIONS

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Cleo/Revolut launches Swiss product | Medium | High | Accelerate chat AI (S51) + Swiss depth (26 cantons, 8 archetypes, OCR CH docs) is unreplicable in < 18 months |
| Neobanks (Neon, Yuh) add coaching | High | Medium | ConfidenceScore + education depth = hard to replicate. Read-only posture = trust signal they cannot match |
| Open Banking adoption slow in CH | High | Low | MINT works without it — Open Banking is a bonus, not a dependency. Progressive profiling fills the gap |
| FINMA regulates educational tools | Low | High | ComplianceGuard + disclaimer + SoA already implemented. Safe Mode is a proactive defense |
| LLM quality regression / API outage | Medium | High | MultiLlmService (S64 foundation) + local fallback for calculations + fallback templates in codebase |
| User fatigue from gamification | Medium | Medium | Tie all gamification to real financial outcomes (FHS), not vanity metrics |

---

## NORTH STAR METRICS

| Metric | Baseline (v0.9.1) | Phase 1 (6mo) | Phase 2 (12mo) | Phase 3 (18mo) |
|--------|-------------------|---------------|----------------|----------------|
| Active users | staging | 5K | 20K | 50K |
| DAU/MAU | -- | 25% | 30% | 35% |
| ConfidenceScore avg | ~35% | 45% | 55% | 65% |
| Actions implemented / user | 0 | 0.5 | 1.2 | 2.0 |
| Revenue MRR (CHF) | 0 | 10K | 30K | 80K |
| NPS | -- | 40 | 50 | 60 |
| Chat messages / active user / week | 0 | 5 | 12 | 20 |
| Test coverage (codebase) | ~65% | 70% | 80% | 85% |
| Compliance violations (cumulative) | 0 | 0 | 0 | 0 |

---

## ACTUAL CODEBASE STATE (2026-03-21)

### What is fully shipped and production-ready

- 4-tab shell (Aujourd'hui / Coach / Explorer / Dossier)
- 7 Explorer hubs with 60+ flows reachable
- `CapEngine` (12-rule heuristic scoring) + `CapMemoryStore`
- `CoachChatScreen` with Claude API + tool calling + compliance guard
- `ConversationMemoryService` (cross-session persistence)
- `FinancialHealthScoreService` (4-axis composite)
- `StreakService` + `MilestoneV2Service` + `AchievementsScreen`
- `LifecyclePhase` (7-phase enum) + `LifecycleDetector` + `LifecycleContentService`
- `ScreenRegistry` (109 surfaces) + `ReadinessGate` + `RoutePlanner`
- `CantonalBenchmarkService` + `CantonalBenchmarkScreen`
- `JitaiNudgeService` + `ProactiveTriggerService` (7 triggers)
- `AdaptiveChallengeService` + `SeasonalEventService`
- `RegionalVoiceService` (26 cantons — text prompt flavor, not audio)
- `RagRetrievalService` (keyword-based, 3 doc pools)
- `MultiLlmService` (Claude primary + fallback config)
- `WeeklyRecapService` + `WeeklyRecapScreen`
- `Retroactive3aCalculator` + `Retroactive3aScreen`
- Financial core: 11 calculators (AVS, LPP, Tax, FRI, Monte Carlo, Arbitrage, Confidence, Withdrawal Sequencing, Tornado Sensitivity, Housing Cost, Coach Reasoner)
- 110+ screens, 6428+ tests green, flutter analyze 0 errors

### What is foundation / partial

- Voice AI: `VoiceService` exists with stub backend — no real STT/TTS provider integrated
- `ReturnContract` / `ScreenReturn` model: referenced in docs, not confirmed in code
- RAG v2: keyword retrieval works; vector embeddings not implemented
- AI Memory vector store: `ConversationMemoryService` handles conversation history, not semantic cross-session recall
- Weekly Recap content quality: depends on BYOK configuration
- Notification delivery: `NotificationService` exists; full JITAI delivery pipeline not verified

### What is planned (not started)

- 13e rente AVS in calculator
- Expert tier (human advisor matching)
- Form pre-fill / autonomous agent (S68)
- Institutional API connections (S69+)
- B2B white-label (S71+)
- Real STT/TTS integration (S63)
- Cantonal leagues and community features (S66)

---

## AUTORESEARCH AGENT DEPLOYMENT SCHEDULE

Each phase activates specific agents. Agents run nightly (8h sessions) on dedicated branches.

### Phase 1 Agents (active from S51)

| Agent | Nightly Output | Cumulative / Week | Primary Sprint |
|-------|---------------|-------------------|----------------|
| Calculator Forge | ~96 scenarios tested | ~480 scenarios | S52-S53 |
| Prompt Lab | ~48 prompt variants tested | ~240 variants | S51, S56 |
| Test Factory | ~160 new tests | ~800 tests | S51+ (continuous) |
| Chat AI Builder | ~15 components | ~75 components | S51 |
| RAG Builder | ~48 documents | ~240 documents | S56 |
| Compliance Hardener | ~50 adversarial tests | ~250 tests | S51+ (continuous) |

### Phase 2 Agents (activated at S57)

| Agent | Purpose | Primary Sprint |
|-------|---------|----------------|
| Coach Evolution | Lifecycle content adaptation, tone calibration | S57, S62 |
| UX Polish | Phase transition screens, nudge UI, challenge cards | S57, S61 |
| Prompt Lab (extended) | Memory integration, weekly recap prompts | S58-S59 |

### Phase 3 Agents (activated at S63)

| Agent | Purpose | Primary Sprint |
|-------|---------|----------------|
| Prompt Lab (voice) | Voice prompt optimization, STT/TTS integration | S63 |
| Compliance Hardener (multi-LLM) | Cross-LLM compliance validation | S64 |
| Perf Optimizer | Pre-launch performance tuning | S63+ |

---

## COMPETITIVE MOAT ANALYSIS

| Moat | Depth | Replication Time | Source |
|------|-------|-----------------|--------|
| Swiss regulatory depth (26 cantons, LSFin compliance) | Deep | 18-24 months | Built into every calculator, compliance guard |
| ConfidenceScore system (4-axis data source tracking) | Deep | 12 months | No competitor has formalized this |
| Safe Mode (proactive debt protection) | Unique | 6 months to copy, but cultural to embed | Ethical differentiator |
| 8 financial archetypes (expat_us, cross_border, etc.) | Deep | 12 months | Swiss-specific, requires deep domain knowledge |
| OCR for Swiss documents (AVS extracts, LPP certificates, tax declarations) | Medium | 6-12 months | Requires Swiss document corpus |
| Read-only posture (no money movement) | Strategic | Instant to copy, but competitors won't | Trust signal in Swiss market |
| B2B pension fund distribution | Strategic | 12-18 months | Requires institutional relationships |

---

## QUARTERLY REVIEW CADENCE

- **Q2 2026 (end Phase 1)**: Chat AI adoption rate, 3a retroactif accuracy, FHS validation
- **Q3 2026 (mid Phase 2)**: Lifecycle engine coverage, memory recall accuracy, retention M3
- **Q4 2026 (end Phase 2)**: JITAI engagement rates, cantonal benchmark opt-in, MRR trajectory
- **Q1 2027 (mid Phase 3)**: Voice adoption by age group, multi-LLM uptime, NPS
- **Q2 2027 (end Phase 3)**: Expert tier conversion, agent autonome safety record, MRR target

---

*This document is the strategic roadmap for MINT V2. Updated 2026-03-21 with status column reflecting actual code state. All sprint execution uses autoresearch dev agents as defined in `visions/MINT_Autoresearch_Dev_Agents.md`.*
