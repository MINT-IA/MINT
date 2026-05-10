---
description: Architecture review of `anthropics/financial-services` (May 2026 release) and whether MINT should migrate from a dual-LLM coach (extractor JSON + narrator) to a coordinator-with-specialist-subagents pattern. Verdict in §6.
audience: Julien + MINT product/AI team
status: Proposed (research, not decision)
date: 2026-05-10
counter_arguments: §5
data_gaps: §8
related:
  - /Users/julienbattaglia/Desktop/MINT.nosync/.planning/decisions/2026-05-09-calc-first-llm-illumination.md
  - /Users/julienbattaglia/Desktop/MINT.nosync/.planning/audit/calc-first-architecture/expert-2-cleo-fintech-research.md
  - /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/api/v1/endpoints/coach_chat.py
  - /Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/coach/coach_tools.py
---

# `anthropics/financial-services` — adoption review for MINT

> Julien (2026-05-10) : « comment ca fonctionne et pourquoi on n'a pas des agents specialises comme cela en place pour MINT. Vraiment creer une entreprise avec des departments. Chaque agent est un specialiste du department, c'est bien ca l'idee ? »

> Short answer up front : **partly yes — that IS the mental model — but the concrete repo targets a different shape of work than MINT.** It is built for **B2B internal-staff workflows in capital markets / wealth-management firms** (« an analyst's pitch deck », « a fund admin's GL recon »). MINT is a **B2C end-user coach** for an individual's life. The « departments » metaphor maps cleanly to MINT-internal calc surfaces, but mapping it to **runtime user-facing subagents** would be over-engineering relative to what the calc-first ADR (2026-05-09) already locks in. Concrete proposal in §7.

---

## 1. What is `anthropics/financial-services` structurally ?

### 1.1 Architecture, in one diagram

```
                         ┌──────────────────────────────────┐
                         │  CLAUDE COWORK (web UI)  OR      │
                         │  CLAUDE MANAGED AGENTS API       │
                         │  (POST /v1/agents, beta header   │
                         │   managed-agents-2026-04-01)     │
                         └──────────────┬───────────────────┘
                                        │ users dispatch by name
                                        ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │  agent-plugins/  (12 NAMED END-TO-END WORKFLOW AGENTS)                  │
   │                                                                         │
   │   pitch-agent           market-researcher       earnings-reviewer       │
   │   model-builder         valuation-reviewer      gl-reconciler           │
   │   month-end-closer      statement-auditor       kyc-screener            │
   │   meeting-prep-agent    ...                                             │
   │                                                                         │
   │  Each is a self-contained agent.yaml :                                  │
   │     name / model / system: {file:..., append:...}                       │
   │     tools: [agent_toolset_20260401, mcp_toolset]                        │
   │     skills: [<reference into vertical-plugins/>]                        │
   │     callable_agents:                ◀── subagent delegation (preview)   │
   │       - manifest: ./subagents/reader.yaml                               │
   │       - manifest: ./subagents/critic.yaml                               │
   │       - manifest: ./subagents/resolver.yaml                             │
   │     mcp_servers: [<connector envs>]                                     │
   └─────────────────────────────────────────────────────────────────────────┘
                                        │ pulls skills (synced) from
                                        ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │  vertical-plugins/  (SHARED SKILL + COMMAND BUNDLES, by FSI domain)     │
   │                                                                         │
   │   financial-analysis    ←─── CORE : comps / DCF / LBO / 3-stmt          │
   │       + 11 MCP data connectors (Daloopa, FactSet, S&P, Moody's, ...)    │
   │   investment-banking    : CIMs, teasers, buyer lists, merger models     │
   │   equity-research       : earnings notes, initiations, thesis tracking  │
   │   private-equity        : sourcing, IC memos, portfolio monitoring      │
   │   wealth-management     : client-review, financial-plan, rebalance,     │
   │                           tax-loss-harvesting, investment-proposal      │
   │   fund-admin            : GL recon, accruals, NAV tie-out               │
   │   operations            : KYC parsing, rules-grid evaluation            │
   └─────────────────────────────────────────────────────────────────────────┘
                                        │
   ┌─────────────────────────────────────────────────────────────────────────┐
   │  partner-built/         (LSEG bond-RV/swap-curve, S&P tear-sheets, ...) │
   │  managed-agent-cookbooks/  (one dir per agent + leaf-worker subagents)  │
   │  scripts/orchestrate.py    (reference handoff_request event loop)       │
   │  scripts/sync-agent-skills.py  (verticals → agents skill propagation)   │
   └─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 What pattern is this exactly ?

Not (a) a coordinator + N specialists hub (no mandatory orchestrator), not (c) a tool-calling library (it is more than tools). It is closest to **(b) a sequence-of-skills-per-named-agent + optional orchestrator that delegates to leaf-worker subagents**. Specifically :

- **Top level = named workflow agents.** Each is « one analyst's job » (Pitch Agent, GL Reconciler). They are independently deployable. Users pick one by name.
- **Inside each = an agent.yaml with skills + tools + optional callable_agents.** Skills are reusable instructions / methods bundled in from `vertical-plugins/` ; tools are MCP connectors and the standard agent toolset (read, grep, ...) ; callable_agents are leaf-worker subagents (`reader`, `critic`, `resolver`).
- **No mandatory coordinator.** Orchestration is optional and lives in `scripts/orchestrate.py` as a reference event loop for `handoff_request` events. The Cowork mode has no orchestrator at all — users dispatch agents by name.
- **Skills are the compositional unit.** A skill (e.g. `comps`, `dcf`, `client-review`) is a markdown / YAML bundle of « when-to-use + step-by-step methodology + I/O contract ». It is authored once in `vertical-plugins/` and synced into each agent that references it via `sync-agent-skills.py`.

### 1.3 The « departments », by name

The wealth-management vertical is the closest neighbour to MINT (B2C personal finance) :

| Skill | One-line role |
|---|---|
| `client-review` | Periodic review of a client portfolio + situation |
| `client-report` | Comprehensive client status / performance report |
| `financial-plan` | Customised plan aligned with goals + risk tolerance |
| `investment-proposal` | Recommendation + rationale draft |
| `portfolio-rebalance` | Bring asset allocation back to target |
| `tax-loss-harvesting` | Identify + execute TLH opportunities |

The other « departments » (Pitch Agent, GL Reconciler, KYC Screener, Earnings Reviewer, Model Builder, Valuation Reviewer, Month-End Closer, Statement Auditor, Meeting Prep Agent, Market Researcher) are all **B2B staff-facing**. They produce deliverables for a banker, fund admin, or equity analyst — not for an end-user account-holder.

### 1.4 Communication

- **Intra-agent (skill ↔ skill within one agent)** : file-based markdown / YAML, no runtime compilation. Skills are bundled into the agent's prompt context at start-up.
- **Inter-agent (subagent delegation)** : `callable_agents` declared in `agent.yaml`, addressed via `handoff_request` events in the orchestration loop. Subagents « operate in the same session as the main agent and only report results to it » (Anthropic docs). Preview feature, not GA.
- **Data connectors** : MCP servers, configured at the vertical-plugin level, shared across all agents. Read-only by default ; transactions / sign-off is staged for human review (governance-by-design).
- **Pricing** : token bill at standard model rates + **$0.08 per session-hour** of runtime.

---

## 2. What MINT runs today — the actual numbers

Citations (file `path:line`, May 10 2026 working tree) :

| Surface | File | LOC | Role |
|---|---|---|---|
| HTTP entrypoint | `services/backend/app/api/v1/endpoints/coach_chat.py:2638` | 3354 (file) | `POST /api/v1/coach/chat` |
| Stage 2 LLM extractor | `services/backend/app/services/coach/llm_extractor.py:1` | 288 | JSON-only Sonnet, regex floor preserved |
| Extractor wrapper | `coach_chat.py:1386` `_run_extractor_stage` | (in-file) | Sequential before narrator, 10s timeout, 30s cache |
| Narrator agent loop | `coach_chat.py:2339` `_run_agent_loop` | (in-file) | Tool_use / tool_result loop, max iterations + token budget |
| Narrator tool list | `coach_tools.py:1257` `get_narrator_llm_tools` | 1274 (file) | Excludes `save_fact` + `save_insight` per Phase 91 W2 |
| System prompt builder | `claude_coach_service.py:895` `build_narrator_system_prompt` | 1100 (file) | Lifecycle + regional + plan |

That is the **entire** runtime AI surface : two LLM calls (extractor → narrator) wrapped in a tool-using agent loop, with **27 distinct tools** declared in `coach_tools.py` (counted via `grep '"name":'`) :

```
delivery       : show_fact_card, show_budget_snapshot, show_score_gauge,
                 show_commitment_card, route_to_screen, ask_user_input,
                 suggest_actions, generate_document, generate_financial_plan
state read     : retrieve_memories, get_budget_status, get_retirement_projection,
                 get_cross_pillar_analysis, get_cap_status, get_couple_optimization,
                 get_regulatory_constant
state write    : save_fact (extractor only), save_insight (excluded),
                 set_goal, mark_step_completed, record_check_in,
                 record_commitment, save_pre_mortem, save_provenance,
                 save_earmark, remove_earmark, save_partner_estimate,
                 update_partner_estimate
```

That is **already a tool-driven agent**. It is just not packaged as N named agents with N skill bundles — it is one narrator with 27 tools and a strict system prompt. Cleo's published architecture (~40 tools, single narrator) is structurally the same shape. See `.planning/audit/calc-first-architecture/expert-2-cleo-fintech-research.md:31-71`.

The 7-expert panel pattern (`.planning/audit/calc-first-architecture/`) is **dev-time**, not runtime — it is summoned by Julien during strategic decisions, never by an end-user.

---

## 3. Side-by-side : Anthropic vs MINT today vs MINT-with-pattern

| Axis | `anthropics/financial-services` | MINT today (post-Phase 91 W2) | MINT-with-pattern (hypothetical) |
|---|---|---|---|
| **Audience** | B2B staff (analyst, fund admin, banker) | B2C end-user (Lauren, Julien) | B2C end-user |
| **Top-level unit** | 12 named agents (Pitch, GL, KYC, ...) | 1 narrator + 1 extractor | N specialists (Tax-Advisor, Pillar3-Optimizer, Mortgage-Stressor, Compliance-Linter, ...) |
| **Composition unit** | Skill (markdown + YAML method bundles) | Tool (function with input_schema) | Skill bundles per specialist |
| **Number of LLM hops per turn** | 1 to N (orchestrator + leaf workers, preview) | Extractor (1) → narrator agent loop (1..N tool iterations) | Coordinator → 1..K specialists → coordinator narrator |
| **Source of numbers** | Tools + MCP + Excel | Tools (`get_*`) → financial_core/ + rules_engine | Same tools, fanned out per specialist |
| **Fact extraction** | Implicit (skill-driven) | Dedicated JSON-only Sonnet, sequential, regex floor | Same |
| **Deterministic guard** | Governance-by-design (human sign-off before any binding output) | ComplianceGuard + banned_terms lint + accent_lint + (Phase 94) citation gate | Same + per-specialist contract |
| **Latency baseline** | Session-hour billing implies long-running tasks | ~2-6 s per turn, single Anthropic call + tools | Multiplied by K (specialists) — see §4 |
| **Cost baseline** | Token + $0.08 / session-hour | Token only | Token × K + (if Managed Agents) $0.08 × session-hour |
| **Failure mode** | Subagent silent failure, governance catches | Hallucinated number → caught by Phase 94 citation gate | Coordinator picks wrong specialist → wrong domain answer (new failure mode) |

**The structural finding** : MINT's 27-tool narrator is already the « one-agent-with-skills-as-tools » pattern. Going to N specialists adds a routing problem (« which specialist owns this turn ? ») without solving any *unsolved* problem in MINT today. The unsolved problem identified by Stage 3 eval is **the LLM authoring numbers** — and that is the calc-first ADR's target, not an agent-count target.

---

## 4. Migration cost (honest estimate)

**Scope : implement coordinator + 4 specialists (Tax-Advisor, Pillar3-Optimizer, Mortgage-Stressor, Compliance-Linter), wired into the existing `_run_agent_loop`.**

| Axis | Estimate | Confidence |
|---|---|---|
| LOC delta | +800 to +1500 backend (4 specialist YAMLs + coordinator router + per-specialist system prompts + tool partitioning + tests) | Medium |
| Implementation weeks | 3-5 weeks for one engineer-equivalent (incl. eval rebuild on 50 fixtures × 4 specialists) | Medium-low — eval rebuild is the long pole |
| Latency tax (P50) | +1 LLM hop minimum (coordinator picks specialist) → **~+2-4 s P50** if specialist is sequential, **~+1.5 s** if parallel-fanout. Today's coach is ~2-6 s. After migration : ~4-10 s. | High |
| Token cost | **+30-60 % per turn** (coordinator system prompt + specialist system prompt + duplicated profile context). Worst case 2-3× if all specialists fire on multi-domain questions. | Medium-high |
| Maintenance | 4 specialist prompts × every doctrine update (banned terms, accent lint, calc-first contract) = **4× the prompt-eng surface**. Phase 91 eval already showed prompt drift between Haiku/Sonnet at 1× ; this multiplies it. | High |
| New failure modes | Routing error (« Lauren asks about a 3a contribution mid-mortgage question » → who owns ?), context fragmentation (specialist A doesn't know what specialist B answered upstream), N-way regression on every prompt change | High |
| Sunk cost recovered | The 27 existing tools survive. Most code stays. The cost is router + specialist boundaries, not rewrite. | High |

**Pre-TestFlight value** : negative. TestFlight ship blocker is dev → staging merge + walker green (per `feedback_app_targets_staging_always.md` + `project_testflight_ship_path.md`). Adding a multi-agent layer pre-TestFlight delays ship without addressing any TestFlight gate.

**Post-TestFlight value** : conditional. If post-launch user data shows the narrator tripping on cross-domain handoffs (« I asked about my mortgage but you started talking 3a »), then specialist routing earns its keep. Until that signal is observed in production, it is speculative.

---

## 5. Counter-argument (steel-man : « ne pas adopter, c'est de l'over-engineering »)

The strongest case **for** keeping MINT mono-narrator + specialist-tools (rather than specialist-agents) :

1. **Cleo's public architecture proves a single narrator + ~40 tools at MINT's domain scale is sufficient** (`expert-2-cleo-fintech-research.md:31-71`). Cleo is the closest peer in scope (B2C personal finance chatbot, banking truth via aggregator). Their pivot was *toward* this pattern, not away from it. They did not need named specialists to hit 81 % on real-world money questions.
2. **Stage 3 eval's failure mode (Sonnet 21/50 doctrine pass, Haiku 5/50) is not « narrator confused which department to call »**. It is « narrator authored a number it should have read from a tool ». That is a calc-first / citation-gate problem. Adding specialists does not fix it ; the calc-first ADR (2026-05-09) does. Solving the right problem first is more important than adopting the fashionable pattern.
3. **Karpathy #2 (Simplicity First, `CLAUDE.md` §7)** : « 200 lines that could be 50 → rewrite ». A coordinator-plus-4-specialists is the « 200 lines » version of a 27-tool narrator that already routes by tool name. The router IS the tool dispatcher.
4. **0-trust §9.4 sim survival test** : if Julien opens his sim today, would N specialists make the « Definis ton budget » empty-state any better ? No — that bug was rendering / wiring, not LLM topology. Multi-agent does not survive Julien's sim test.
5. **Maintenance × 4** : the doctrine surface (banned LSFin terms, accents, archetype detection, anti-extractor-leak, calculator-grounded) is currently audited once per turn against one prompt. Specialists multiply audit cost linearly. Phase 91 already showed prompt drift between two models is non-trivial ; eight prompts is worse.
6. **The repo's own audience signal** : 11 of 12 named agents are B2B staff-facing. The wealth-management vertical exists but is the smallest, has 6 skills (not agents), and its skills (`client-review`, `portfolio-rebalance`, ...) describe a *human advisor's* deliverables, not an end-user's daily life. MINT is end-user-facing ; that is a different product surface.
7. **Anthropic's own published guidance** is « give the LLM the calc engine, don't make the LLM be the calc engine » (per Financial Modeling World Cup result, `expert-2-cleo-fintech-research.md:96-100`). That points to calc-first, not multi-agent.

**Where the counter-argument is weak** : if MINT later adds genuinely separate user surfaces (e.g. a *partner* mode for couples optimisation that has its own legal context, a *fiduciaire* B2B mode for tax preparers), then specialists earn their seat. But those are post-TestFlight surfaces.

---

## 6. Verdict

> **Adopt the *patterns* (skill-as-bundle, calc-first, governance-staging) — do not adopt the *runtime topology* (named-agents + coordinator) yet.**

The repo is a permission slip and reference architecture for ambitious B2B FSI staff workflows. MINT's coach is a B2C narrator that already implements 80 % of the same pattern under different packaging. The remaining 20 % gap (`skills/` as first-class folder, `mcp_servers` as canonical connector layer, leaf-worker subagent template) is **infrastructure adjacent**, not *correcting a current MINT defect*. The current MINT defect is calc-first / citation-gate (ADR 2026-05-09), already in flight as Phases 92.5 / 94 / 95 / 96.

---

## 7. Three concrete proposals

Each anchored to existing MINT roadmap (Phases 91 done, 92 in flight, 92.5 / 94 / 95 / 96 in calc-first ADR). None are « adopt Anthropic Managed Agents wholesale ». All preserve the calc-first commitment.

### 7.1 Proposal A (low-cost, high-leverage) — Adopt the **skill-bundle authoring layer**, not the runtime

**What** : restructure `services/backend/app/services/coach/` so that **doctrine + tool-set + system-prompt** for a given user-state become a *skill bundle* on disk, in the spirit of Anthropic's `vertical-plugins/.../skills/`. One bundle = one markdown (when-to-use + methodology + I/O contract) + one tool-allowlist + one prompt-fragment + one fixture set.

Initial bundles, named to match MINT-internal calc surfaces (mirrors `financial_core/`) :

- `pillar3a-optimizer` (3a ceiling, with/without LPP, anticipated draw)
- `lpp-projector` (rente projection, LPP gap, buy-back)
- `tax-explainer` (cantonal × federal, deductions stack)
- `mortgage-stressor` (LTV, affordability, cantonal stress test)
- `compliance-narrator` (banned terms / accents / archetype detection)
- `life-event-router` (18 events, archetype × canton matrix)

**Runtime** : still one narrator. Bundles are **compile-time** : a build step (think `sync-agent-skills.py`) emits a single `system_prompt.md` per archetype × event by concatenating bundles, lints them with `accent_lint_fr.py` + `check_banned_terms()`, and ships them into `claude_coach_service.build_narrator_system_prompt`.

**Integrates with calc-first ADR** : each bundle declares which `GroundingPack` keys (N2) it expects + which `{{cite:<key>}}` placeholders (N1) it is allowed to emit. The citation-gate (Phase 94) reads the bundle's allowlist when validating output.

**Cost** : ~+400 LOC, 1-2 weeks. **Maintenance** : doctrine becomes auditable per-bundle instead of buried in 1100-line `claude_coach_service.py`. **Latency** : zero (compile-time).

**Phase target** : insert as **92.5 sub-task** OR open a new **Phase 93** (« skill-bundle compiler ») between 92.5 and 94, since 94 will read the bundles' citation allowlists.

### 7.2 Proposal B (medium-cost, deferred) — One **leaf-worker subagent** for the Compliance-Linter, not for the calculators

**What** : when LSFin / accent / archetype / banned-term audit complexity grows (post-launch, with real user logs), spin out a **single leaf-worker subagent** : `compliance-narrator-auditor`. It re-reads the narrator's draft answer + the GroundingPack and either approves, edits, or rejects. Pattern is the `critic` / `resolver` leaf-worker shape from Anthropic cookbooks (per WebFetch of `gl-reconciler/agent.yaml` callable_agents).

This is the **only** specialist subagent that is high-value for MINT, because :

- Compliance is already the clearest contract (`compliance_guard.py`, `doctrine_checks.py`, banned terms list) — easy to specialise.
- Failure here is recoverable on a second LLM hop (rewrite) without new user-visible state.
- Latency tax is bounded (1 extra hop, only on draft rejection — most turns skip it).
- Calculators do NOT need to be subagents — they are deterministic, they are tools, full stop. Calc-first ADR forbids letting an LLM author numbers ; a « Tax-Advisor subagent » is exactly what calc-first rules out.

**Cost** : ~+300 LOC, 2 weeks. **Latency** : +1.5 s ONLY on draft rejection (~10-15 % of turns by Stage 3 eval projection). **Phase target** : **post-TestFlight Phase 97 or 98**, conditional on Phase 94 citation-gate showing residual compliance leaks > target.

### 7.3 Proposal C (research, not commit) — Pin the **Anthropic Managed Agents API** as a future-deployment option, not migrate now

**What** : add a 1-page ADR (`.planning/decisions/2026-05-12-managed-agents-deferral.md`, status Proposed) that records :

- Managed Agents API costs **$0.08 / session-hour** + standard token rates (per WebSearch, May 2026).
- `callable_agents` is preview-only ; not GA ; subject to API-shape change.
- MINT's runtime is FastAPI on Railway with its own session-state ; switching to Managed Agents changes the trust boundary (Anthropic-hosted session state vs MINT-controlled DB).
- Defer adoption until at least one of three triggers fires :
  1. Production traffic shows narrator tripping on cross-domain turns at >2 % rate.
  2. A B2B partner-mode product surface is greenlit (different tenant, different doctrine).
  3. Anthropic's `callable_agents` exits preview AND publishes session-state portability guarantees compatible with LPD art. 6.

**Cost** : ~1 hour to write. **Value** : prevents future « should we have adopted this ? » re-litigation (`feedback_expert_panel_pattern.md`). **Phase target** : standalone ADR file, no phase gate.

---

## 8. Data gaps

- Latency claim « +2-4 s per coordinator hop » is from public Anthropic blog snippets + LangChain multi-agent docs ; I have not benchmarked Managed Agents directly. If we go to Proposal B, we should benchmark on staging before commit.
- Token-cost « +30-60 % » is from arxiv 2603.22651 hierarchical multi-agent paper, not measured on MINT's own prompt distribution.
- Whether Anthropic's `callable_agents` preview supports MINT's concurrency profile (peak ~50 chat sessions) is undocumented. Worth a question to Anthropic DevRel before ADR.

## 9. Counter-argument to my own verdict

The strongest case **for** doing this now anyway :

- If TestFlight launch surfaces a class of failure where the narrator cannot decide between two doctrine modes (e.g. expat_us with FATCA vs Swiss native), specialists become the cleanest fix and we will wish we had Proposal A's bundle layer in place.
- The cost of Proposal A (compile-time skill bundles) is small enough that doing it pre-TestFlight is cheap insurance — the cost only grows if we wait until 27 tools become 50.
- Anthropic's published direction signals where Claude tooling will *invest* over the next 12 months. Being early-adopter on the file layout (not the runtime) lowers integration cost when Managed Agents go GA.

That is precisely why **Proposal A is recommended for adoption**, **B is deferred**, and **C is recorded as ADR not commit**.

---

## Sources

- [GitHub — anthropics/financial-services](https://github.com/anthropics/financial-services)
- [Anthropic — Agents for financial services (May 2026)](https://www.anthropic.com/news/finance-agents)
- [Claude Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview)
- [DeepWiki — anthropics/financial-services Getting Started](https://deepwiki.com/anthropics/financial-services/1.1-getting-started)
- [Mark Craddock — Five patterns to steal from Anthropic Financial Services Plugins](https://medium.com/arckit/five-patterns-to-steal-from-anthropics-financial-services-plugins-a9728e3c3114)
- [arxiv 2603.22651 — Benchmarking Multi-Agent LLM Architectures for Financial Document Processing](https://arxiv.org/html/2603.22651)
- [Augment Code — Multi-Agent Orchestration: A Practical Architecture Without the Buzzwords](https://www.augmentcode.com/guides/multi-agent-orchestration-architecture-guide)
- [AWS — Agentic AI in Financial Services: Choosing the Right Pattern for Multi-Agent Systems](https://aws.amazon.com/blogs/industries/agentic-ai-in-financial-services-choosing-the-right-pattern-for-multi-agent-systems/)
- [Hockeystack — Optimizing Latency and Cost in Multi-Agent Systems](https://www.hockeystack.com/applied-ai/optimizing-latency-and-cost-in-multi-agent-systems)
- Internal : `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/decisions/2026-05-09-calc-first-llm-illumination.md`
- Internal : `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/audit/calc-first-architecture/expert-2-cleo-fintech-research.md`
- Internal : `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/api/v1/endpoints/coach_chat.py`
- Internal : `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/coach/coach_tools.py`
- Internal : `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/coach/llm_extractor.py`
