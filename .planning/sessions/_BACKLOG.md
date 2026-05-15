---
description: Backlog priorisé des sessions /office-hours à programmer pour MINT. Chaque entrée a un trigger (quand l'ouvrir) + outline (de quoi on discute).
---

# Office-Hours Sessions Backlog

Sessions /office-hours MINT à programmer, dans l'ordre de priorité actuel. Chaque entrée précise le **trigger** (condition d'ouverture) et l'**outline** (sujets à challenger).

Convention : la première entrée est la plus prioritaire. Quand une session est ouverte et close avec son design doc APPROVED, on barre l'entrée + on ajoute une ligne `Done: <date> → <design-doc-path>`.

---

## 1. Persistent Specialist Agents Architecture

**Trigger** : ouvrir cette session **dès que Wave 0-4 du design doc 2026-05-14 a shippé** (TestFlight gate atteint, Coach vivant didactique + trajectoire visuelle + orchestrator en prod staging au minimum).

**Sujet** : MINT manque d'agents spécialistes persistants avec identité + mémoire propre + continuité across invocations. Aujourd'hui les skills + subagents + MCP tools sont **tous stateless** par invocation. Le pattern « panel d'experts » (memory `feedback_expert_panel_pattern`) re-instantie chaque session — aucune wisdom compounding par expert.

**Originel** : Julien identifié 2026-05-14 office-hours session 6, *« on n'a pas des agents spécialistes qu'on peut appeler à la demande... qui sont toujours les mêmes, avec les mêmes skills... qu'on n'a pas besoin de reprometer à chaque fois »*.

**Outline à challenger en session** :

1. **Diagnostic confirmation** — recherche web 2026-05-14 a confirmé : Anthropic + community ont shippé des primitives qui résolvent **PARTIELLEMENT** le gap. Détails dans §Références ci-dessous. **À re-confirmer en début de session** pour catch les évolutions entre maintenant et la session.
2. **Use cases concrets** — quels agents en priorité ? Liste candidate :
   - `@cso` (security)
   - `@lsfin-officer` (compliance Suisse)
   - `@swiss-fintech-expert` (3 piliers/AVS/LPP/fiscalité)
   - `@ux-critic-aesop` (design Tom Sachs/Aesop)
   - `@adversarial-tester` (red team)
   - `@karpathy-curator` (wiki schema)
   - + ce que la session sortira
3. **Trois niveaux à arbitrer** :
   - **L0 — Adopter `anthropics/claude-plugins-official` + `anthropics/skills` patterns** (~3-5 jours) : convertir mint-skills en plugins format Anthropic-officiel. **Résout 60% du gap** (callable par nom, system prompt versionné, tool restrictions) **sans dev neuf**. Pas de mémoire persistante.
   - **L1 — Skills with own `memory.md`** (~1 jour additionnel) : chaque skill spécialiste lit/écrit son fichier memory propre. Cheap, marche dans le harness existant. Pas de runtime identity — juste persistence file-based.
   - **L2 — Subagent profiles + context bundle wrapper** (~3 jours additionnels) : wrapper Bash/jq qui charge system_prompt + memory par expert et spawn Agent avec ce bundle. Versionnable per-expert.
   - **L3 — MCP server stateful** (~2 semaines) : MCP server expose `@cso.review(diff)`, server tient l'état + mémoire + historique des agents. Multi-client (Claude Code + claude.ai web + scripts). Architecture la plus propre, plus lourde à host.
4. **Karpathy alignment** — chaque agent persistant = une page dans une LLM Wiki (per CLAUDE.md §8 + memory `project_user_profile_wiki`). Pas un modèle vector-RAG. Same Karpathy pattern, applied à l'infra agents.
5. **Risks à challenger** : memory drift entre agents (CSO de mars vs CSO de septembre), maintenance overhead, race conditions multi-session, comment promote/demote/retire un agent.
6. **Premise dur** à valider : *« est-ce que la valeur compounding-expertise dépasse vraiment le coût d'infra ? »* — peut-être que `claude-plugins-official` + skills + project memory bien curé suffit pour 80% du value à 10% du coût.
7. **Specific MINT recon** : démarrer la session en lisant [`anthropics/financial-services`](https://github.com/anthropics/financial-services) — voir ce qu'Anthropic propose déjà pour services financiers, peut contenir des patterns directement réutilisables pour ton domaine Suisse fintech.

**Status** : NOT STARTED. À ouvrir post-Wave-4.

**Références internes MINT** :
- Memory : `feedback_persistent_specialist_agents_gap.md`
- Memory liée : `feedback_expert_panel_pattern.md`, `feedback_post_phase_panel_loop.md`, `project_user_profile_wiki.md`
- Karpathy Wiki Pattern : `.planning/handoff/pdfs/Karpathy-Wiki-Pattern-2026-05-06.pdf`

**Références externes (recherche web 2026-05-14)** :

*Anthropic officiel* :
- [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — directory officiel Anthropic-managed de Claude Code Plugins, contient déjà des agents préconçus (ex `code-simplifier/agents/`)
- [`anthropics/skills`](https://github.com/anthropics/skills) — public repo pour Agent Skills, registrable comme Claude Code Plugin marketplace
- [`anthropics/financial-services`](https://github.com/anthropics/financial-services) — **MINT-spécifique** : plugins self-contained pour services financiers, workflow end-to-end avec system prompt + skills
- [`anthropics/claude-agent-sdk-demos`](https://github.com/anthropics/claude-agent-sdk-demos) — démos Claude Agent SDK
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Advanced Patterns: Subagents, MCP, and Scaling — Anthropic PDF](https://resources.anthropic.com/hubfs/Claude%20Code%20Advanced%20Patterns_%20Subagents,%20MCP,%20and%20Scaling%20to%20Real%20Codebases.pdf)
- [How and when to use subagents — Claude blog](https://claude.com/blog/subagents-in-claude-code)

*Community* :
- [`VoltAgent/awesome-claude-code-subagents`](https://github.com/VoltAgent/awesome-claude-code-subagents) — 100+ subagents spécialisés
- [`wshobson/agents`](https://github.com/wshobson/agents) — multi-agent orchestration pour Claude Code
- [`affaan-m/everything-claude-code`](https://github.com/affaan-m/everything-claude-code) — agent harness performance system (Claude Code Hackathon Feb 2026)
- [buildwithclaude.com](https://buildwithclaude.com/) — marketplace plugins/subagents/commands/skills/hooks
- [subagents.app](https://subagents.app/agents) — directory de sub-agents
- [Claude Code Agent Teams, Subagents, and MCP : The 2026 Playbook](https://www.developersdigest.tech/blog/claude-code-agent-teams-subagents-2026)

**Verdict pré-session (à re-confirmer en début de session)** :
- ✅ Anthropic + community ont solidement adressé « agent callable par nom sans re-prompt » (`anthropics/claude-plugins-official` + skills + marketplaces)
- ❌ La **mémoire persistante per-agent across invocations** reste un gap non résolu côté Anthropic officiel (juin 2026 cutoff). C'est où MINT pourrait innover (niveaux L1-L3 sketched ci-dessus).
- ⚠️ **Possibilité que ce soit shippé entre maintenant et l'ouverture de la session** — Anthropic itère vite sur Claude Code. Re-WebSearch obligatoire en début de session.

---

## 2. Graphiti MCP — Temporal Knowledge Graph Reconnaissance (Phase 4+ candidate)

**Trigger** : ouvrir cette session **si** Phase 1-2 de vibe-coding-infra (entry #1) ship avec GO et que :
- engram findings volume > 1000 (≈ 6 mois de critic activity au rythme estimé)
- `engram mem_conflicts` beta surfaces des limites observables (faux positifs, miss cross-agent temporal patterns, ou drift detection lente)
- OU `@karpathy-curator` (Phase 2 critic) demande un graph-aware tool pour drift trimestrielle

**Sujet** : Graphiti ([github.com/getzep/graphiti](https://github.com/getzep/graphiti), par Zep.ai) = temporal knowledge graph framework MCP-compatible. Stocke entities + relations + timestamps + episode-based facts. Trois capabilities-clés que engram FTS5 ne couvre PAS nativement :

1. **Fact invalidation auto** — quand une décision passée devient obsolète (« on a accepté Provider en mars » → « non, on a switch Riverpod en juillet »), le graph détecte la contradiction temporellement.
2. **Decision lineage** — trace l'évolution d'une convention/architecture cross-PRs (ex: la règle « pas de `Navigator.push` » → comment elle a évolué, qui l'a challengée).
3. **Cross-agent correlation temporelle** — « le `@cso-mint` de mars a flaggué X, le `@lsfin-officer` de mai a flaggué ~X mais ne se sont pas vus » → surface ces patterns automatiquement.

**Origine** : flag externe agent audit 2026-05-14 challenging engram (savedAs engram finding #2 « infra-decision: engram challenged 2026-05-14 — KEEP verdict », topic `infra-decision`). Audit proposait Graphiti parmi alternatives. Verdict session : KEEP engram Phase 1-2, Graphiti **différé Phase 4+** comme candidat conditionnel.

**Outline à challenger en session** :

1. **Empirical limits check** — d'abord empiriquement valider qu'engram + `mem_conflicts` beta sont LIMITED (pas anticipé). Ouvrir cette session **uniquement** si engram montre vraiment des bottlenecks. Sinon over-engineering.
2. **Stack cost** — Graphiti requires Neo4j OR Postgres + extensions + Python runtime. Match avec Mac mini + Fun2 setup ? OR ça impose une infra parallèle ?
3. **Cypher learning curve** — query language non-trivial. `@karpathy-curator` doit pouvoir l'invoquer fluently. Coût formation/prompt ?
4. **Migration story** — engram findings vers Graphiti = pipeline export-ingest ? Idempotent ? Loss-less ?
5. **Vendor risk** — Zep est une startup (single-org). Similar à engram mais commercial-leaning. License terms à valider (Apache 2 a priori, mais cloud features paid).
6. **Use case précis** — `@karpathy-curator` Phase 2 doit faire memory drift trimestrielle. Combien de findings cross-agent à corréler ? Graphiti rentabilise à >1000 findings, en-dessous c'est overkill.
7. **Alternative hybride** — peut-on garder engram pour write-path + exporter une vue Graphiti read-only mensuelle pour audit drift ? Best of both ?

**Status** : NOT STARTED. À ouvrir **uniquement** si engram limits empiriquement observés (Phase 4+).

**Références internes MINT** :
- Engram finding #2 (mem_save 2026-05-14 11:52:27, topic `infra-decision`)
- Design doc `~/.gstack/projects/MINT-IA-MINT/julienbattaglia-dev-design-20260514-133000.md` §Post-decision audit
- Memory `feedback_audit_corpus_before_patching`

**Références externes** :
- [`getzep/graphiti`](https://github.com/getzep/graphiti) — repo
- [Zep documentation](https://docs.getzep.com/) — concepts temporal graph
- [Graphiti MCP wrapper](https://github.com/getzep/graphiti-mcp) — Claude Code integration

**Verdict pré-session (à re-confirmer)** :
- ⏳ Graphiti = sur-architecture pour Phase 1-2. engram suffit.
- ⏳ Phase 4+ candidat **conditionnel** : seulement si limites engram empiriques.
- ⚠️ Risque scope-creep : si on ouvre prématurément, on yak-shave une infra qu'on n'utilise pas.

---

## Comment maintenir ce backlog

- Quand tu identifies un nouveau topic à traiter en /office-hours dédié (pas dans la session courante), ajoute une entrée ici.
- Ordonne par priorité (top = next-up).
- Inclus toujours **Trigger** (condition d'ouverture) + **Outline** (5-7 bullets challengeable).
- Quand session close, barre l'entrée et ajoute `Done: <date> → <design-doc-path>`.
- Re-prioritize au début de chaque /office-hours en regardant ce fichier.
