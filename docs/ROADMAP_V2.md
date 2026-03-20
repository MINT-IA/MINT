# MINT — Strategic Roadmap V2.1 (Post-S53)

> Date: March 2026 | Version: 2.1 | Production: v0.3.0
> Based on: `visions/MINT_Analyse_Strategique_Benchmark.md` + Cleo analysis + actuarial review
> Execution method: Autoresearch Dev Agents + S53 Gate Closer pattern
> Companion docs: `TOP_10_SWISS_CORE_JOURNEYS.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `MINT_CAP_ENGINE_SPEC.md`

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

## Phase 1: "Le Plan Vivant" (S51-S56)

**Objective**: MINT devient plan-first, coach-orchestrated. L'utilisateur voit sa progression, pas un dashboard.

**Direction post-S53**: La priorite n'est plus "ajouter du chat". C'est:
- plus de plan (Cap du jour -> Plan du jour)
- plus de memoire utile
- plus de progression visible par objectif
- plus de preuve accessible
- Top 10 Suisse irreprochables avant le long tail

**Benchmark justification**:
- Cleo Autopilot: insight -> plan -> action -> memory (on prend la boucle, pas l'execution automatique)
- 3 piliers suisses: terrain differenciateur principal (OFAS, AVS/AI, LPP)
- Reframing rule + clause d'honnetete: transparence suisse > promesse marketing

| Sprint | Objective | Status | Key Deliverables |
|--------|-----------|--------|-----------------|
| S51 | Chat AI MVP | DONE | ChatService, SLM+BYOK, ConversationMemory, SuggestionChips, ComplianceGuard |
| S52 | UX Cohesion + CapEngine V1 | DONE | 4-tab shell, 7 hubs, CapEngine (12 heuristiques), ActionSuccess, voice system 5/5 piliers, 6392 tests green |
| S53 | Gate Closer + LPP doctrine | DONE | Honesty clause, disability gap, couple caps, 18/18 life events, LPP oblig/suroblig split, concubinage core, 6428 tests green |
| S54 | Plan du jour + memoire renforcee | NEXT | CapSequence (prereqs/phases), ProjectionSnapshot, "ce qui a change", progression X/Y par objectif |
| S55 | Top 10 irreprochables | PLANNED | Chaque parcours coeur audite: template, cap, progression, preuves, compliance. Gate Closer pattern. |
| S56 | Coach contextuel avance | PLANNED | financialLiteracyLevel complete, reformulation calme, handoff structure, RAG v1 |

**KPIs Phase 1**: DAU/MAU > 25%, Retention J7 > 35%, Actions completed / user > 0.5

---

## Phase 2: "Le Compagnon" (S57-S62, 6-12 months)

**Objective**: MINT s'adapte a ta vie. Il se souvient et evolue.

**Direction post-S53**: La memoire n'est pas une feature Phase 2 — c'est le fondement de Phase 1.
Ce qui reste pour Phase 2: lifecycle adaptation, proactivite, benchmarks cantonaux, OB-ready architecture.

**Benchmark justification**:
- R2 (Lifecycle): Noom 7-phase model — content adaptation = long-term retention driver
- R5 (Proactivity): JITAI research — 52% engagement at workflow boundaries
- R7 (Social): Cantonal benchmarks fill a gap no Swiss app addresses (anonymized, no ranking)
- Open Finance: Conseil federal 2024 — architecturer pour l'OB maintenant, connecter plus tard

| Sprint | Objective | Key Deliverables | Success Metric |
|--------|-----------|-----------------|----------------|
| S57 | Lifecycle Engine (7 phases) | PhaseDetector, content adaptation by phase, tone switching | Content adapts for all 7 phases |
| S58 | OB-ready architecture | Data source awareness in CapEngine, CTA OB dormants, confidence boost path | Architecture prete, 0 dependance OB reelle |
| S59 | Weekly Recap AI | WeeklyRecapService, summary (budget, actions, progress), PDF export | 85+ quality score, 0 compliance violations |
| S60 | Cantonal benchmarks (anonymized) | Aggregated comparison, opt-in only, "profils similaires" (never ranked) | 0 compliance violations, no ranking |
| S61 | JITAI Proactive nudges | Trigger engine (salary, tax deadline, birthday), positive framing | 52%+ engagement on triggered nudges |
| S62 | Caps menage avances | Couple optimization cross-profile, multi-goal household, retraite a deux | Caps menage couvrent les 5 grands arbitrages couple |

**KPIs Phase 2**: Retention M3 > 40%, ConfidenceScore moyen > 55%, > 30% users with scanned doc

---

## Phase 3: "L'Expert" (S63-S68, 12-18 months)

**Objective**: MINT devient indispensable. Voice sobre, humain accessible, mise en scene premium.

**Direction post-S53**: Voice mode reporte ici (pas Phase 1/2) car:
- marche quadrilingue (FR 23%, DE 63%, IT 8%, EN expats)
- interactions financieres sensibles (pas de LPP a voix haute dans le train)
- cout de maintenance 4 langues disproportionne avant product-market fit

| Sprint | Objective | Key Deliverables | Success Metric |
|--------|-----------|-----------------|----------------|
| S63 | Voice AI sobre (FR+DE) | VoiceService STT+TTS, voice button en chat, ton calme, accessibilite 50+ | Latence < 3s, 0 compliance violations |
| S64 | Multi-LLM redundancy | Claude primary + GPT-4o fallback + local model, automatic failover | 99.9% uptime, consistent quality |
| S65 | Expert tier (human advisors) | Advisor matching, AI pre-fills dossier, session scheduling | Dossier prep reduit session time 40% |
| S66 | Mise en scene premium | Less cards, more layers, hero hierarchy, proof accessible immediately | UX audit score > 9/10 on Top 10 |
| S67 | RAG v2 (comprehensive) | 500+ docs, 26 cantons, FAQ by caisse, annual updates pipeline | >95% retrieval accuracy |
| S68 | Agent autonome v1 (read-only) | Form pre-fill, letter generation, fiscal dossier — user validation gate 100% | 0 unauthorized actions |

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
| **B2B** | 5-15 CHF/employee/yr | White-label for employers/pension funds, aggregated wellness dashboard | Full platform, custom branding |

**Expert Session (add-on, not a tier)**:
- 129 CHF/session — consultation with a certified specialist (planificateur, fiscaliste, notaire)
- AI pre-fills dossier (profile + projections + questions) → specialist productive from minute 1
- Available to Pro subscribers as add-on
- MINT earns commission (10-20%) on specialist marketplace — no loss-leader risk
- Why not a tier: a 49.90 CHF/mo tier with 2 human sessions/mo is economically unviable (specialist costs 150-300 CHF/hr)

**Revenue model validation** (from benchmark):
- Cleo: $250M ARR on freemium chat model
- Betterment: 0.25% AUM with education-first approach
- Origin Financial: hybrid AI + human at premium pricing
- MINT advantage: Swiss depth (26 cantons, 8 archetypes) creates pricing power that foreign competitors cannot undercut

---

## WHAT WE EXPLICITLY DON'T BUILD

| Feature | Why not | Reference |
|---------|---------|-----------|
| Autopilot / execution automatique | LSFin interdit, trust suisse incompatible | CLAUDE.md §6 |
| Recommandation de souscription/produit | No-advice, read-only | CLAUDE.md §6 |
| Voice mode avant Phase 3 | Quadrilinguisme, sensibilite, cout | Roadmap analysis post-S53 |
| Gamification criarde / roast | Voix MINT calme, pas insolente | VOICE_SYSTEM.md |
| Score/ranking social | Interdit CLAUDE.md §6 | No-Social-Comparison |
| LLM opaque qui remplace les hypotheses | Transparence suisse non negociable | Masterplan §9 |
| Faux levier quand aucun n'existe | Clause d'honnetete | CapEngine Spec §7 |

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
