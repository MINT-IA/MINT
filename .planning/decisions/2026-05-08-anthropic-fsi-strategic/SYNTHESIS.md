---
name: Anthropic FSI Webinar — Strategic Decision Wiki
description: Synthesis post-Critical-PM-review of the Anthropic « Claude for Financial Services » webinar (Lynn + Scully, mai 2026, 59 min). Frames the BYOK / portability decision as « contrainte de design », tranches the 5 W/M actions, names what the Critical PM review itself missed.
type: decision
date: 2026-05-08
status: Proposed
related:
  - .planning/decisions/2026-05-08-office-hours-mon-dossier/ANTHROPIC-FSI-WEBINAR-MAPPING.md
  - .planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md
  - .planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md
sources:
  - https://anthropic.ondemand.goldcast.io/on-demand/74ae0fc7-f591-442f-8fe1-244f409c1fb5
  - Press release « Agents for financial services » (Anthropic, mai 5 2026)
  - Practical deployment guide (Anthropic FSI cookbook)
---

# Anthropic FSI Webinar — Strategic Decision Wiki

## Re-frame

The Critical PM review (received 2026-05-08) tranches by default: « décider BYOK avant Phase 2 ». **I disagree.** The right strategic question for MINT is not « BYOK vs API server vs SLM cascade » — those are deployment topologies. The right question is :

> **« MINT keeps PORTABILITY as a design invariant, yes or no ? »**

If yes (recommended), every architectural choice must pass a portability gate. The deployment topology decision can mature on its own clock — M2 model routing ships now without committing to it.

If no, MINT couples to Anthropic infrastructure and ships faster short-term but locks Phase 2 into a vendor-specific stack.

This re-frame removes the false binary and unlocks immediate ROI.

## What the Critical PM review got right (90%)

- Mix of sources non-distingué in the third-party summary (press release + webinar + deployment guide conflated). Confirmed by my own WebFetch — I had only the webinar (b), not the press release (a). The third-party summary was richer on (a) but tracked aspirational marketing, not technical patterns.
- B2B → B2C transposition: the « 10 agents IB » + « FactSet/S&P/Moody's » + « M365 add-ins » are not applicable to MINT mobile B2C 18-99 retail CH.
- BYOK filter omitted by the third-party summary, which reinforces vendor-lock direction (« élargir partenariats »). Direct contradiction with `project_byok_scope.md`.
- Capabilities matrix : portable (Skills, Model routing, Progressive Disclosure, Cross-app sync pattern) vs lock-in moyen (Skill Creator, Plugin Marketplace) vs lock-in fort (Cloud Managed Agents, Anthropic-managed connectors, M365 add-ins).
- Six webinar capabilities under-treated by the third-party summary : Progressive Context Disclosure, Cross-Application Sync bidirectionnel temps réel, Skill Creator as standalone tool, Model Selection H/S/O, RBAC skill-scoped, Context Management chapter 8 + 17.

## What the Critical PM review missed (5 corrections)

### 1. 3 of the 10 IB agents ARE structurally applicable

The review tranches that the 10 agents IB do not transpose to B2C. **Wrong for 3 of them**, by structural analogy (auditor-of-situation pattern, regardless of who the situation belongs to) :

| Anthropic IB agent | MINT B2C analogue | Existing brick |
|---|---|---|
| **Earnings Reviewer** (reads transcripts, updates models, flags changes) | **Plan Reviewer** : re-evaluates `FinancialPlan` at each monthly check-in, detects staleness via `computeProfileHash`, fires a coach nudge if drift | `FinancialPlanProvider.isPlanStale` + `PlanTrackingService.evaluate()` already exist |
| **Statement Auditor** (reviews coherence + completeness + audit compliance) | **Tax Declaration Auditor** : annual scan of fiscal declaration + comparison to Y-1 + flag of missed 3a/LPP buyback | `TaxCalculator` + `EnhancedConfidence` 4-axis available |
| **KYC Screener** (entity files + compliance escalation) | **Archetype/FATCA Screener** : detects expat US / cross-border signals from chat, triggers FATCA disclosure pipeline | `coach_profile.dart:54-78` 8 archetypes enum, `coach_chat.py` filters |

This is not naïve transfer learning — it is a structural correspondence (auditing a stateful situation). Worth listing.

### 2. Data residency Suisse / nLPD art. 16 is a GREATER constraint than « lock-in BYOK »

The review mentions « audit logs nLPD-compliant côté MINT, PAS dans la console Claude » in passing. The systemic consequence is not made explicit :

> **Cloud Managed Agents = US-hosted Anthropic infrastructure = data residency violation** for Swiss personal finance (LPD/nLPD art. 16, exposes MINT users to CLOUD Act subpoena risk + cross-jurisdiction discovery).

So M3 (Cloud Managed Agents) is not just « lock-in BYOK » — it is **lock-in juridictionnel**. Harder to detangle, exposes a whole class of incidents (subpoena, government request, treaty-breach lawsuit) that BYOK choice does not.

The review should red-flag M3 as P0 NO regardless of BYOK decision.

### 3. Self-hosted cookbook is a third path the review does not name

The third-party summary noted in passing : « Managed Agent fourni comme cookbook que l'équipe déploie elle-même ». The review did not capitalize. **For MINT, this changes the option set** :

- Pattern Cloud Managed Agents (long-running agent + tool permissions + credentials vault + audit log) is **infrastructure-agnostic**. It can be self-hosted on Railway (MINT's existing EU-region infra) without using Anthropic-managed runtime.
- This converges with Vibe Engineering / Effect / Temporal (durable workflow infrastructure-agnostic, see `2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md` Q3 panel).

So MINT can have the Cloud Managed Agents **patterns** without the Anthropic infra **lock-in**. The dilemma « BYOK vs Cloud Managed » is false.

### 4. M2 model routing ships INDEPENDENT of BYOK decision

The review tranches « décide BYOK avant tout » by default. Too conservative. The Haiku/Sonnet/Opus routing works :
- In BYOK : user provides their key, MINT routes
- In API server : MINT routes server-side per `route × intent`
- In SLM cascade : SLM tries first, escalates to Haiku/Sonnet/Opus on confidence threshold

M2 is **port-stable** across all 3 deployment topologies. ROI measurable (-50-70 % token cost on simple ops, latency -30 %) in ~1.5 days of effort. **No need to freeze BYOK first.** The review acknowledges this in « par défaut Anthropic API server-side maintenant + design portable » then over-corrects to (C).

### 5. The coach orchestrator + N skills combo is not explicit

Both the third-party summary and the review oppose « 10 specialized agents vs 1 generalist agent ». Neither proposes the combo :

> **1 coach orchestrator (conversation entry point) + N specialized skills (life events, calculators, archetype risks) called via tool calling.**

This combo preserves MINT's UX (the coach stays the single conversational interface) while gaining the quality of specialized skills. It is what M1 implies but not stated as such. Worth naming explicitly because it changes the implementation : we don't need to build « 18 separate agents » UI ; we need to refactor the coach prompt into a router-orchestrator + N skill markdown files.

## Decisions (final)

### Design invariant adopted

**MINT keeps PORTABILITY as a design invariant.** Every architectural choice goes through a portability gate.

### Capability matrix (with the 5 corrections folded in)

| Capability | Portable BYOK | Portable SLM cascade | Lock-in juridictionnel CH | MINT verdict |
|---|---|---|---|---|
| **W1** Progressive Disclosure audit on 13+ skills `.claude/skills/` | ✅ pattern | ✅ pattern | None | **GO this week (~0.3j)** |
| **W3** `autoresearch-i18n` wired in lefthook pre-commit / autonomous loop | ✅ | ✅ | None | **GO this week (~0.2j)** |
| **W6** Press-release research note in `.planning/research/` distinct from webinar | n/a | n/a | None | **GO this week (~30 min)** |
| **M1** Skills modulaires per life event (coach orchestrator + N skills) | ✅ | ✅ | None | **Phase 2 candidate (5-8j)** |
| **M2** Model routing Haiku/Sonnet/Opus per route × intent | ✅ | ✅ | None | **Phase 2 priority — ships independent of BYOK decision (~1.5j)** |
| **M5** Connectors B2C self-built (bLink, ESTV, AVS portail) | ✅ | ✅ | None | **Phase 2-3 candidate** |
| **W2** Skill Creator for next custom skills | ⚠️ via user's Claude | ⚠️ | Moyen | **DEFER — wait until M1 stabilizes the skill format** |
| **W4** RBAC skill-scoped tool restrictions | ✅ if Claude Code supports | ⚠️ partial | None | **DEFER — file GH issue first to confirm support** |
| **W5** Plugin marketplace audit | ⚠️ MINT producer not consumer | ⚠️ | Moyen | **LOW priority — re-frame: MINT publishes mint-* skills, doesn't consume marketplace** |
| **M4** Skill Creator for product life-event content | ⚠️ | ⚠️ | Moyen | **DEFER Phase 3+** |
| **M3** Cloud Managed Agents on Anthropic infra | ❌ | ❌ | **HIGH — US-hosted inference + audit log** | **NO — incompatible with portability AND data residency CH** |
| Anthropic-managed connectors propriétaires (FactSet, Moody's MCP, S&P, etc.) | ❌ | ❌ | High | **NO — not relevant for B2C anyway** |
| M365 add-ins | ❌ | n/a | Moyen | **NO — wrong product category (mobile B2C)** |
| **NEW** : 3 IB agents → MINT analogues (Plan Reviewer / Tax Declaration Auditor / Archetype-FATCA Screener) | ✅ | ✅ | None | **Phase 2-3 candidates — once M1 ships, these are 3 specialized skills among the N** |
| **NEW** : Self-hosted cookbook on Railway (durable workflow patterns infra-agnostic) | ✅ | ✅ | None | **Phase 3 — converges with Vibe Engineering Effect Cluster pattern** |

### Concrete work this week (whitecoding, 0.5-1j cumulé)

1. **W1** Audit `description:` length in `.claude/skills/*/SKILL.md` for all 13+ skills, ensure body is lazy-loaded not eagerly stuffed in the description. Quick lint script.
2. **W3** Wire `autoresearch-i18n` as a lefthook pre-commit hook (already exists as a skill, just unlinked from automation). One yaml entry in `lefthook.yml`.
3. **W6** Open `.planning/research/2026-05-08-anthropic-fsi-press-release.md` to capture press release facts distinct from webinar patterns. Keeps future planning honest about marketing vs technical.

### Phase 2 priority (post-TestFlight, max ROI)

1. **M2** Model routing : audit Coach call sites + propose `archetype × intent → model` table + ship the routing layer. 1.5 days. Saves -50-70 % token cost on simple ops. **Ships now without freezing BYOK decision.**
2. **M1** Skills modulaires : refactor coach system prompt into router-orchestrator + N skills (one per life event, one per calculator family, one per archetype risk). 5-8 days. Unlocks the Phase 2 architectural reframing of Mon dossier (per OH panel + Anthropic FSI mapping).
3. **M5** Connectors B2C self-built (bLink CSV → API, ESTV scraping, AVS portail) when Phase 3 budget tracking lands.

### What we explicitly NOT do

- **M3** Cloud Managed Agents on Anthropic infra — P0 NO. Two reasons : portability (locks BYOK out) AND data residency CH (LPD/nLPD art. 16 + CLOUD Act exposure). Worse than « lock-in BYOK » alone.
- **M4** Skill Creator for product content — defer, decision overlap with M1 unclear.
- Anthropic-managed proprietary connectors (FactSet, Moody's MCP, S&P) — not relevant for B2C personal finance CH.
- Microsoft 365 add-ins — wrong product category.

## BYOK decision (parked, not blocked)

The BYOK / API server / SLM cascade choice is now **parked** — M2 model routing is port-stable across all three. We can mature the choice with real telemetry post-TestFlight :
- If users opt for BYOK at >40 % rate → ship BYOK
- If <10 % → API server + cascade SLM (cheaper, simpler, no key-management UX)
- If 10-40 % → hybrid (API server default, BYOK opt-in for power users)

The portability invariant guarantees we can pivot later without retrofit cost.

## Counter-arguments and data gaps

- **Portability invariant is itself a constraint with cost.** Adopting BYOK-portable patterns rules out Anthropic's faster path (managed agents, M365 add-ins, vendor connectors). For a startup in pivot, this might be over-cautious. Mitigation : the patterns we adopt (Skills, Model routing, Progressive Disclosure) have intrinsic value beyond portability — they reduce token cost, improve testability, simplify content authoring. Portability is a free side-benefit.
- **3 IB agents → MINT analogue (Plan Reviewer / Tax Auditor / FATCA Screener)** is a structural claim, not validated by user research. The analogy may not survive contact with real B2C journeys. Mitigation : these are Phase 2-3 candidates only ; we can validate with M1 prototype before committing.
- **Self-hosted Cloud Managed pattern on Railway** sounds clean but is non-trivial : Railway Background Workers are not a full agent runtime (no Anthropic-style RBAC vault, no out-of-the-box audit log console). Building self-hosted = ~1-2 weeks of plumbing. Re-validate ROI before Phase 3.
- **W4 RBAC skill-scoped** assumes Claude Code supports allow/deny lists per skill. Not confirmed in the docs I have access to. File a GH issue or check `~/.claude/settings.json` schema before committing.
- **Press release source** for the « 10 agents nommés » + « Vals AI 64.37 % » + « Citadel Eliza quote » is not the webinar. Anthropic marketing claims are not validated against independent benchmarks. Treat as aspirational.
- **Convergence Vibe Engineering ↔ Anthropic FSI** is real but I might be over-fitting. Two videos sampled close in time are not a trend. Mitigation : POC limité (M2 ships, then re-evaluate).
- **Data missing** : MINT internal benchmarks on token cost per chat session. The « -50-70 % » M2 ROI estimate is from Anthropic guidance, not measured on MINT. Calibrate post-implementation.

## Approval gate

Three actions to validate :

1. **Adopt the « portability invariant » as MINT's design contract** — yes/no decision Julien.
2. **Whitecoding this week** : W1 + W3 + W6 (~1j cumulé). Whitelisted, no blocker.
3. **Phase 2 plan** : add M2 (model routing) as the first ROI-positive Phase 2 deliverable, M1 (skills modulaires) as the architectural backbone. Defer M3 + M4 + W2 + W4 + W5.

## References

- Anthropic FSI webinar : https://anthropic.ondemand.goldcast.io/on-demand/74ae0fc7-f591-442f-8fe1-244f409c1fb5
- Vibe Engineering source : https://youtu.be/Wmp2Tku2PrI
- OH panel design doc : [.planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md](.planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md)
- OH FSI webinar mapping (level 1) : [.planning/decisions/2026-05-08-office-hours-mon-dossier/ANTHROPIC-FSI-WEBINAR-MAPPING.md](.planning/decisions/2026-05-08-office-hours-mon-dossier/ANTHROPIC-FSI-WEBINAR-MAPPING.md)
- Walker Q1-Q3 panel : [.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md](.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md)
- BYOK scope memory : `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/project_byok_scope.md`
- MINT MCP `.mcp.json` (4 tools : `get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`, `check_accent_patterns`)
- Coach chat screen : [apps/mobile/lib/screens/coach/coach_chat_screen.dart](apps/mobile/lib/screens/coach/coach_chat_screen.dart)
- FinancialPlanProvider (now wired post-PR #525) : [apps/mobile/lib/providers/financial_plan_provider.dart](apps/mobile/lib/providers/financial_plan_provider.dart)
