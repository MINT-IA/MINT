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

1. **Diagnostic confirmation** — vérifier que le gap est toujours réel (peut-être Anthropic ou gstack ont shippé une feature entre-temps qui résout)
2. **Use cases concrets** — quels agents en priorité ? Liste candidate :
   - `@cso` (security)
   - `@lsfin-officer` (compliance Suisse)
   - `@swiss-fintech-expert` (3 piliers/AVS/LPP/fiscalité)
   - `@ux-critic-aesop` (design Tom Sachs/Aesop)
   - `@adversarial-tester` (red team)
   - `@karpathy-curator` (wiki schema)
   - + ce que la session sortira
3. **Trois niveaux à arbitrer** :
   - **L1 — Skills with own `memory.md`** (~1 jour) : chaque skill spécialiste lit/écrit son fichier memory propre. Cheap, marche dans le harness Claude Code existant. Pas de runtime identity — juste persistence file-based.
   - **L2 — Subagent profiles + context bundle wrapper** (~3 jours) : wrapper Bash/jq qui charge system_prompt + memory par expert et spawn Agent avec ce bundle. Versionnable per-expert.
   - **L3 — MCP server stateful** (~2 semaines) : MCP server expose `@cso.review(diff)`, server tient l'état + mémoire + historique des agents. Multi-client (Claude Code + claude.ai web + scripts). Architecture la plus propre, plus lourde à host.
4. **Karpathy alignment** — chaque agent persistant = une page dans une LLM Wiki (per CLAUDE.md §8 + memory `project_user_profile_wiki`). Pas un modèle vector-RAG. Same Karpathy pattern, applied à l'infra agents.
5. **Risks à challenger** : memory drift entre agents (CSO de mars vs CSO de septembre), maintenance overhead, race conditions multi-session, comment promote/demote/retire un agent.
6. **Premise dur** à valider : *« est-ce que la valeur compounding-expertise dépasse vraiment le coût d'infra ? »* — peut-être que Skills + project memory bien curé suffit pour 80% du value à 10% du coût.

**Status** : NOT STARTED. À ouvrir post-Wave-4.

**Références** :
- Memory : `feedback_persistent_specialist_agents_gap.md`
- Memory liée : `feedback_expert_panel_pattern.md`, `feedback_post_phase_panel_loop.md`, `project_user_profile_wiki.md`
- Karpathy Wiki Pattern : `.planning/handoff/pdfs/Karpathy-Wiki-Pattern-2026-05-06.pdf`

---

## Comment maintenir ce backlog

- Quand tu identifies un nouveau topic à traiter en /office-hours dédié (pas dans la session courante), ajoute une entrée ici.
- Ordonne par priorité (top = next-up).
- Inclus toujours **Trigger** (condition d'ouverture) + **Outline** (5-7 bullets challengeable).
- Quand session close, barre l'entrée et ajoute `Done: <date> → <design-doc-path>`.
- Re-prioritize au début de chaque /office-hours en regardant ce fichier.
