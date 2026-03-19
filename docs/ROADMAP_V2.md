# MINT — Strategic Roadmap V2 (Benchmark-Driven)

> Date: March 2026 | Version: 2.0 | Production: v0.1.0
> Based on: `visions/MINT_Analyse_Strategique_Benchmark.md` (40+ apps, 18 research themes)
> Execution method: Autoresearch Dev Agents (`visions/MINT_Autoresearch_Dev_Agents.md`)

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

## Phase 1: "Le Conversationnel" (S51-S56, 0-6 months)

**Objective**: MINT parle. L'utilisateur pose des questions en langage naturel.

**Benchmark justification**:
- R1 (Chat AI): "Le chat est devenu la norme, pas une feature" — Cleo $250M ARR, bunq Finn 97% resolution
- R3 (Gamification): +48% engagement via streaks, +30% savings increase (academic research)
- 3a retroactif: unique 2026 market opportunity (new Swiss law), no competitor has it
- Financial Health Score: inspired by WHOOP Recovery Score — daily composite = daily return

| Sprint | Objective | Key Deliverables | Autoresearch Skills Used | Success Metric |
|--------|-----------|-----------------|--------------------------|----------------|
| S51 | Chat AI MVP (text) | ChatService, ChatScreen, ClaudeApiClient, ConversationMemory, SuggestionChips, TypingIndicator | `/autoresearch-prompt-lab`, `/autoresearch-compliance-hardener` | Chat functional with 85+ prompt quality score, 0 compliance violations |
| S52 | 3a Retroactif simulator | Retroactive3aSimulatorScreen, fiscal impact calc (1-10 year retroactive), comparison chart | `/autoresearch-calculator-forge` | 100% accuracy on 10-year retroactive scenarios, golden couple values correct |
| S53 | 13e Rente AVS integration | Updated AvsCalculator (base x 1.0833), new chiffre choc widget, impact on couple projections | `/autoresearch-calculator-forge` | Golden couple values correct +/-0.5%, all existing AVS tests still green |
| S54 | Financial Health Score v1 | FHS composite (debt 0-25 + savings 0-25 + retirement 0-25 + fiscal 0-25), daily score widget, gradient visualization | `/autoresearch-test-generation` | FHS computed for all 6 golden profiles (Julien, Lauren, Marco, Fatima, Hans, Marie) |
| S55 | Streaks + 10 Milestones | StreakEngine (with freeze), MilestoneService, 10 initial milestones, flamme widget | `/autoresearch-test-generation`, `/autoresearch-ux-polish` | All 10 milestones trigger correctly, streak logic handles edge cases (freeze, timezone, interruption) |
| S56 | RAG Knowledge Base v1 | 100+ Swiss finance docs (AVS, LPP, 3a, fiscal), retrieval pipeline, embedding store, source citation in chat | `/autoresearch-prompt-lab` | >80% retrieval accuracy on 200-question battery |

**KPIs Phase 1**: DAU/MAU > 25%, Retention J7 > 35%, Chat used by > 40% active users

---

## Phase 2: "Le Compagnon" (S57-S62, 6-12 months)

**Objective**: MINT s'adapte a ta vie. Il se souvient et evolue.

**Benchmark justification**:
- R2 (Lifecycle): Noom 7-phase model — content adaptation = long-term retention driver
- R4 (Memory): Cleo 3.0 — "the AI remembers everything" as key differentiator for trust
- R5 (Proactivity): JITAI research — 52% engagement at workflow boundaries (post-salary, pre-tax-deadline)
- R7 (Social): Cantonal benchmarks fill a gap no Swiss app addresses (anonymized, no ranking)

| Sprint | Objective | Key Deliverables | Autoresearch Skills Used | Success Metric |
|--------|-----------|-----------------|--------------------------|----------------|
| S57 | Lifecycle Engine (7 phases) | PhaseDetector (Demarrage/Construction/Acceleration/Consolidation/Transition/Retraite/Transmission), content adaptation by phase, tone switching per age group | `/autoresearch-coach-evolution`, `/autoresearch-ux-polish` | Content adapts correctly for all 7 phases, tone validation by eval suite |
| S58 | AI Memory (vector store) | Per-user vector store, cross-session context persistence, goal tracking over 30+ days, conversation summarization | `/autoresearch-prompt-lab` | AI recalls goals set 30+ days ago, context window management handles 100+ conversations |
| S59 | Weekly Recap AI | WeeklyRecapService, automated summary generation (budget, actions, progress), PDF export | `/autoresearch-prompt-lab`, `/autoresearch-compliance-hardener` | 85+ quality score on recap content, 0 compliance violations in generated text |
| S60 | Cantonal benchmarks (anonymized) | Aggregated comparison engine, opt-in only, display as "profils similaires" (never ranked), data aggregation pipeline | `/autoresearch-compliance-hardener` | 0 compliance violations, no ranked comparisons, no social comparison language |
| S61 | JITAI Proactive nudges | Trigger engine (salary receipt, tax deadline, birthday, contract anniversary), timing based on user usage patterns, positive framing | `/autoresearch-ux-polish` | 52%+ engagement on triggered nudges, 0 mid-task interruptions |
| S62 | Micro-challenges weekly | AdaptiveChallengeService, 50 challenges by archetype and phase, difficulty adaptation, FHS-linked rewards | `/autoresearch-coach-evolution` | Challenge completion rate > 30%, challenges correctly adapt to 8 archetypes |

**KPIs Phase 2**: Retention M3 > 40%, ConfidenceScore moyen > 55%, > 30% users with scanned doc

---

## Phase 3: "L'Expert" (S63-S68, 12-18 months)

**Objective**: MINT devient indispensable. Voice, humain, et communaute.

**Benchmark justification**:
- R6 (Voice): Cleo 3.0 two-way voice, bunq speech-to-speech — critical for 50+ age group (82% Gen Z use AI vs. lower adoption in 50+)
- R8 (Hybrid): Origin Financial model — AI + human = 52% trust increase (academic research)
- R9 (Multi-LLM): Monarch Money architecture — Claude primary + GPT-4o fallback = 99.9% uptime
- R10 (Agent): Albert autonomous agent — read-only agent (form pre-fill, letter generation) stays within MINT compliance posture

| Sprint | Objective | Key Deliverables | Autoresearch Skills Used | Success Metric |
|--------|-----------|-----------------|--------------------------|----------------|
| S63 | Voice AI (STT+TTS) | VoiceService, speech-to-text integration, text-to-speech with Swiss French, voice button in chat, accessibility for 50+ | `/autoresearch-prompt-lab` | Voice functional and tested with 50+ age group scenarios, latency < 3s |
| S64 | Multi-LLM redundancy | Claude primary + GPT-4o fallback + local model for sensitive calcs, automatic failover, response quality monitoring | `/autoresearch-compliance-hardener` | 99.9% uptime, 0 compliance breaches on fallback, consistent response quality across LLMs |
| S65 | Expert tier (human advisors) | Advisor matching by specialization (succession, expat, divorce), dossier preparation (AI pre-fills), session scheduling, advisor rating | `/autoresearch-compliance-hardener` | 52%+ trust increase with human validation, dossier preparation reduces advisor session time by 40% |
| S66 | Advanced gamification | Cantonal leagues (opt-in only), community challenges, milestone sharing (anonymized), seasonal events | `/autoresearch-ux-polish`, `/autoresearch-compliance-hardener` | No social comparison violations, 20%+ opt-in rate, no ranked leaderboards |
| S67 | RAG v2 (comprehensive) | 500+ docs, cantonal specifics for all 26 cantons, FAQ by caisse de pension, annual updates pipeline | `/autoresearch-calculator-forge` | >95% retrieval accuracy on expanded 500-question battery |
| S68 | Agent autonome v1 | Form pre-fill (tax declaration, 3a forms), letter generation (caisse de pension requests), fiscal dossier prep — all read-only, all require user validation before submission | `/autoresearch-compliance-hardener` | 0 unauthorized actions, user validation gate on 100% of outputs |

**KPIs Phase 3**: Retention M12 > 25%, NPS > 50, Revenue MRR > CHF 50K

---

## Phase 4: "La Reference" (S69+, 18-24 months)

**Objective**: MINT est le standard suisse.

| Sprint | Objective | Key Deliverables | Autoresearch Skills Used |
|--------|-----------|-----------------|--------------------------|
| S69-S70 | Institutional APIs | Direct connections with 2-3 pilot pension funds (Publica, BVK, CPEV), real-time balance retrieval, ConfidenceScore = 1.00 for connected data | `/autoresearch-compliance-hardener`, `/autoresearch-calculator-forge` |
| S71-S72 | B2B caisses + RH | White-label platform for employers, financial wellness corporate module, HR dashboard with aggregated (anonymized) employee wellness metrics | `/autoresearch-ux-polish`, `/autoresearch-compliance-hardener` |
| S73-S74 | Open Finance bLink | Auto account aggregation when Swiss pension APIs standardize, passive data enrichment (WHOOP-inspired), ConfidenceScore auto-upgrade on connection | `/autoresearch-calculator-forge` |
| S75+ | Expansion DACH | Adaptation for Germany (Riester/Rurup) and Austria (Pensionskonto) pension systems, multi-country lifecycle engine | `/autoresearch-calculator-forge`, `/autoresearch-i18n` |

---

## MONETIZATION (aligned with phases)

| Tier | Price | Phase 1 Content | Phase 2+ Content |
|------|-------|-----------------|------------------|
| **Free** | 0 CHF | Chiffre choc, 1 simulation/day, educational content, ConfidenceScore basique | Same |
| **Plus** | 9.90 CHF/mo | Chat AI unlimited, all simulators, FHS, streaks & milestones, PDF reports | + Weekly Recap AI, micro-challenges |
| **Pro** | 29.90 CHF/mo | Voice AI, long-term memory, proactive JITAI alerts, cantonal benchmarks, OCR unlimited | + JITAI nudges, lifecycle adaptation |
| **Expert** | 49.90 CHF/mo | Human advisor (2 sessions/mo), succession planning, complex arbitrage dossiers | + Agent autonome, institutional APIs |
| **B2B** | 5-15 CHF/employee/yr | White-label for employers/pension funds, aggregated wellness dashboard | Full platform, custom branding |

**Revenue model validation** (from benchmark):
- Cleo: $250M ARR on freemium chat model
- Betterment: 0.25% AUM with education-first approach
- Origin Financial: hybrid AI + human at premium pricing
- MINT advantage: Swiss depth (26 cantons, 8 archetypes) creates pricing power that foreign competitors cannot undercut

---

## RISKS & MITIGATIONS

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Cleo/Revolut launches Swiss product | Medium | High | Accelerate chat AI (S51) + Swiss depth (26 cantons, 8 archetypes, OCR CH docs) is unreplicable in < 18 months |
| Neobanks (Neon, Yuh) add coaching | High | Medium | ConfidenceScore + education depth = hard to replicate. Read-only posture = trust signal they cannot match |
| Open Banking adoption slow in CH | High | Low | MINT works without it — Open Banking is a bonus, not a dependency. Progressive profiling fills the gap |
| FINMA regulates educational tools | Low | High | ComplianceGuard + disclaimer + SoA already implemented. Safe Mode is a proactive defense |
| LLM quality regression / API outage | Medium | High | Multi-LLM architecture (S64) + local fallback for calculations + fallback templates already in codebase |
| User fatigue from gamification | Medium | Medium | Tie all gamification to real financial outcomes (FHS), not vanity metrics. Research shows outcome-linked gamification sustains engagement |

---

## NORTH STAR METRICS

| Metric | Baseline (v0.1.0) | Phase 1 (6mo) | Phase 2 (12mo) | Phase 3 (18mo) |
|--------|-------------------|---------------|----------------|----------------|
| Active users | 0 | 5K | 20K | 50K |
| DAU/MAU | -- | 25% | 30% | 35% |
| ConfidenceScore avg | ~35% | 45% | 55% | 65% |
| Actions implemented / user | 0 | 0.5 | 1.2 | 2.0 |
| Revenue MRR (CHF) | 0 | 10K | 30K | 80K |
| NPS | -- | 40 | 50 | 60 |
| Chat messages / active user / week | 0 | 5 | 12 | 20 |
| Test coverage (codebase) | ~55% | 70% | 80% | 85% |
| Compliance violations (cumulative) | 0 | 0 | 0 | 0 |

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

### Agent Interaction Dependencies

```
Chat AI Builder  <-- depends on -->  RAG Builder (knowledge for answers)
Chat AI Builder  <-- depends on -->  Prompt Lab (quality of responses)
Prompt Lab       <-- depends on -->  Compliance Hardener (guardrail validation)
Gamification     <-- depends on -->  Calculator Forge (FHS needs financial_core)
Test Factory     <-- validates -->   ALL other agents (safety net)
```

---

## COMPETITIVE MOAT ANALYSIS

Based on the benchmark of 40+ apps, MINT's defensible advantages:

| Moat | Depth | Replication Time | Source |
|------|-------|-----------------|--------|
| Swiss regulatory depth (26 cantons, LSFin compliance) | Deep | 18-24 months | Built into every calculator, compliance guard |
| ConfidenceScore system (5-level data source tracking) | Deep | 12 months | No competitor has formalized this |
| Safe Mode (proactive debt protection) | Unique | 6 months to copy, but cultural to embed | Ethical differentiator |
| 8 financial archetypes (expat_us, cross_border, etc.) | Deep | 12 months | Swiss-specific, requires deep domain knowledge |
| OCR for Swiss documents (AVS extracts, LPP certificates, tax declarations) | Medium | 6-12 months | Requires Swiss document corpus |
| Read-only posture (no money movement) | Strategic | Instant to copy, but competitors won't | Trust signal in Swiss market |
| B2B pension fund distribution | Strategic | 12-18 months | Requires institutional relationships |

---

## QUARTERLY REVIEW CADENCE

This roadmap is reviewed quarterly with the following checkpoints:

- **Q2 2026 (end Phase 1)**: Chat AI adoption rate, 3a retroactif accuracy, FHS validation
- **Q3 2026 (mid Phase 2)**: Lifecycle engine coverage, memory recall accuracy, retention M3
- **Q4 2026 (end Phase 2)**: JITAI engagement rates, cantonal benchmark opt-in, MRR trajectory
- **Q1 2027 (mid Phase 3)**: Voice adoption by age group, multi-LLM uptime, NPS
- **Q2 2027 (end Phase 3)**: Expert tier conversion, agent autonome safety record, MRR target

Each review updates sprint priorities based on: user feedback, metric performance, competitive landscape, and regulatory changes.

---

*This document is the strategic roadmap for MINT V2. It supersedes any previous roadmap documents. Updates are made quarterly based on metric performance and market evolution. All sprint execution uses autoresearch dev agents as defined in `visions/MINT_Autoresearch_Dev_Agents.md`.*
