# Claude Code Discipline pour MINT — anti-surface-code playbook

> Auteur : Claude (Product Leader) — synthèse recherche mai 2026
> Statut : Active rulebook — supersedes les défauts Claude Code natifs
> Pourquoi : MINT a la maladie « code en surface + app buggée ». Ce doc est le diagnostic + le traitement.

## Diagnostic — pourquoi ça arrive

La recherche 2026 (Anthropic best practices, Generative.inc, Marmelab, BMAD framework, Superpowers) converge sur un constat simple :

> Si Claude prend la bonne décision 80 % du temps sur chaque micro-décision, et qu'une feature contient 20 décisions, la proba que tout soit juste = 0,8²⁰ ≈ **1 %**.

Le surface-code n'est pas un défaut moral du LLM — c'est une conséquence statistique de **sauter la phase de plan** et de **ne pas valider en bout de chaîne**. Les 4 anti-patterns dominants observés dans MINT (cf. memories `feedback_pre_push_checklist`, `feedback_diff_against_existing_tool`, `feedback_design_panel_before_push`, `façade-sans-câblage W14 = 72 fichiers supprimés`) :

1. **Skip plan mode** → coder direct sur intuition après la 1re question.
2. **Mocker au lieu de wirer** → écrire un widget visuel sans le brancher à un service réel.
3. **Marquer ✅ sans vérification** → claim « done » avant de lancer la commande de vérification.
4. **No-root-cause fix** → patch du symptôme, pas de la cause (Iron Law violée).

## Traitement — les 7 disciplines obligatoires

### Discipline 1 — Plan-mode pour toute tâche non-triviale (gate avant code)

**Règle :** toute tâche avec ≥ 3 décisions distinctes ou ≥ 2 fichiers à modifier passe en plan-mode AVANT le premier `Edit/Write`.

- Comment : `/gsd-plan-phase` ou `/writing-plans` ou `Skill brainstorming` (voir `.claude/skills/`).
- Sortie attendue : un plan écrit (PLAN.md ou conversationnel) qui répond explicitement aux 5 questions :
  1. Goal (ce qu'on cherche à accomplir, pas ce qu'on va faire)
  2. Files touchés (liste exhaustive grep-vérifiée)
  3. Decisions ambiguës (chacune avec un trade-off explicite)
  4. Verification commands (les `pytest` / `flutter test` / `lint` qui doivent green)
  5. Definition of done (l'état observable post-merge)
- **Anti-pattern :** « je vais juste éditer ce fichier rapidement » sans plan = source #1 de surface-code.

### Discipline 2 — Iron Law (no fix without root cause investigation)

**Règle :** aucun fix proposé tant que le root cause n'est pas identifié *et écrit* (1 phrase suffit, mais elle doit exister).

- Comment : `/systematic-debugging` ou `/gsd-debug` ou `Skill investigate`.
- Process en 4 phases obligatoires : Investigation → Pattern Analysis → Hypothesis → Implementation.
- **3-Fix Rule :** après 3 tentatives de fix échouées, STOP et reassess l'architecture. Pas de « let me try one more thing ».
- **Anti-pattern :** patcher le symptôme (« j'ajoute un null-check ici ») sans comprendre pourquoi le null arrive.

### Discipline 3 — Subagent-driven development pour parallélisation

**Règle Anthropic :** si une tâche touche ≥ 10 fichiers ou contient ≥ 3 morceaux indépendants, utiliser des subagents.

- Comment : `Agent` tool avec subagent_type spécialisé. Pour MINT : `gsd-executor`, `gsd-phase-researcher`, `Explore`, `general-purpose`.
- Pattern : 1 implementer subagent + 1 spec-compliance-reviewer subagent + 1 code-quality-reviewer subagent (Superpowers two-stage).
- **Anti-pattern :** tout faire dans le main thread, contexte saturé, qualité se dégrade après 30k tokens.

### Discipline 4 — TDD inversé : test failing FIRST (RED-GREEN-REFACTOR)

**Règle :** Claude écrit naturellement implementation puis tests. Pour MINT, on inverse explicitement.

- Process : RED (write failing test, watch it fail) → GREEN (write minimal code, watch it pass) → REFACTOR → COMMIT.
- Comment : `/test-driven-development` ou `Skill subagent-driven-development`.
- Pour MINT spécifiquement : déjà 9326 tests + 4 bugs device en v2.2. Le ratio « tests green ≠ app fonctionnelle » dit que le problème n'est pas la quantité de tests mais qu'ils ne sont pas RED-first → ils valident l'implementation, pas le besoin.
- **Anti-pattern :** « je teste après ». Le test post-impl confirme que le code fait ce que le code fait, pas que le code fait ce qu'il doit faire.

### Discipline 5 — Verification-before-completion (evidence > assertions)

**Règle :** aucune claim de « done / fixed / passing » sans **avoir lancé la commande de vérification dans la même session** et lu le output.

- Comment : `/verification-before-completion` ou `Skill verification-before-completion`.
- Pour MINT : la pre-push checklist (memory `feedback_pre_push_checklist`) est non-négociable :
  1. `grep -rn '<func>('` sur tous les callers + update si signature changée
  2. Regen OpenAPI canonical (`generate_canonical.py`) ou `flutter gen-l10n` si schéma/ARB changé
  3. Full `pytest` + `flutter test` AVANT push
- **Anti-pattern :** « j'ai changé X, ça compile, je push ». Source des 4 cycles CI sur PR #439.

### Discipline 6 — Design panel + code review BEFORE merge (pas après)

**Règle MINT (memory `feedback_design_panel_before_push`) :** chaque écran Flutter create / revise / refactor → 4-person panel FIRST (UX + a11y + adversarial + engineering/wiring), apply critical fixes, THEN push.

- Comment : `Agent` × 4 en parallèle, ou `/mint-review-pr` pour le code review staff-engineer pattern.
- Pour reviews croisés : `/codex review` (codex CLI), `/gsd-review` (peer LLM review), `/review` (claude review).
- **Anti-pattern :** push d'un écran « petit fix », design panel skip, drift visuel/a11y se cumule.

### Discipline 7 — HTML evidence per phase (memory durable, audit trail)

**Règle MINT (memory `feedback_html_evidence_report`) :** chaque phase GSD produit + update `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html` (PRs, panel verdicts, test counts, deferred items). Cumulative `.planning/reports/SESSION-YYYY-MM-DD.html` rolls them up. **Jamais `/tmp/...` — perdu cross-session.**

- Pourquoi : sans evidence persistée, chaque session redémarre à zéro et reproduit les mêmes erreurs.
- C'est la version mini-LLM-Wiki du repo : on est déjà 70 % sur le pattern Karpathy pour la mémoire dev, formalisons-le.

---

## Disciplines additionnelles — Context Engineering (Patrick Debois, Anthropic, Manus, Horthy YC)

> Thèse Patrick Debois (QCon London 2026) : « Context is the new code ». Le contexte mérite la même infra que le code : version control, review, testing, CI/CD, monitoring. Aujourd'hui chez MINT on a `.planning/` (versioné ✓) mais pas testé, pas reviewé, pas linté. C'est notre prochaine couche de discipline.

### Discipline 8 — Context utilization < 40% en permanence (Horthy YC)

**Règle :** maintenir l'utilisation de la context window sous 40% pendant l'exécution. Au-dessus : qualité dégrade silencieusement (Liu 2024 « lost in the middle » + context rot transformer-architecture).

- **Mesure :** estimer mentalement à chaque point de décision. Si on a chargé 3 fichiers de 800 lignes + un PLAN + une recherche → on est probablement déjà à 35-45% sur Sonnet.
- **Actions au-dessus de 40% :**
  - **Compaction agressive** via `compact_20260112` (Anthropic API, 150K trigger threshold) ou résumé manuel du transcript en `<summary>` block
  - **Tool result clearing** via `clear_tool_uses_20250919` (drop re-fetchable results, garde tool_use record)
  - **Sub-agent dispatch** : isoler la tâche bruyante dans un sub-agent qui burn 10K tokens et retourne 1-2K condensés
  - **Just-in-time retrieval** : stocker juste les paths/URLs dans le contexte, pas le contenu — relire à la demande via `head`/`tail`
- **Anti-pattern :** « je vais charger les 5 fichiers d'un coup pour avoir tout le contexte ». Non. Lire 1, comprendre, décider quoi lire ensuite.
- **Ratio observé Horthy 2025 :** équipes qui maintiennent < 40% livrent 35K LOC en 7h sur codebase 300K. Au-dessus = thrashing.

### Discipline 9 — Research/Plan/Implement comme 3 artefacts séparés

**Règle :** ne plus mélanger « ce qu'on découvre » et « ce qu'on va faire ». Sépare en 2 fichiers + l'impl.

| Artefact | Lieu MINT | Contenu |
|---|---|---|
| RESEARCH | `.planning/phases/<phase>/RESEARCH.md` (déjà géré par `gsd-phase-researcher`) | Files, lignes, dépendances, exemples canoniques. **Pas de décisions.** |
| PLAN | `.planning/phases/<phase>/PLAN.md` | Goal, decisions, tasks atomic, verification, DoD. **Pas de découverte.** |
| IMPL | les commits | Le code lui-même. |

- Pourquoi : si Research et Plan sont mélangés, le contexte de l'impl re-lit toute la découverte → coût en tokens + dilution attention.
- Pour les phases existantes : utiliser `gsd-phase-researcher` qui produit RESEARCH.md consommé par `gsd-planner`. Skill déjà présent, sous-utilisé.

### Discipline 10 — KV-cache stability (impératif coût V3 wiki coach)

**Règle (Manus production lessons) :** le KV-cache hit rate est la métrique #1 pour les coûts LLM en production. Pour MINT V3 wiki-per-user (panel cost expert : $0.40-0.85/user/mois conditionnel à 60-70% cache hit), c'est non-négociable.

- **Préfixe stable du prompt** : aucun timestamp à la seconde, aucun random, aucun hash variable au début du system prompt
- **Append-only context** : ne jamais modifier les actions/observations passées (mute le cache)
- **Sérialisation déterministe** : ordre des clés JSON stable (Python `sort_keys=True`, Dart `JsonEncoder` custom)
- **Tools : mask, don't remove** : pour cacher un tool, masquer les logits via state machine, ne pas retirer la définition (qui invalide le cache)
- **Cache TTL 1h vs 5min** : pour les sessions mobiles MINT (bursty, 2-3 turns puis background), forcer TTL 1h via `cache_control: {type: 'ephemeral', ttl: '1h'}`
- **Coût :** Sonnet 4.6 cache read = 0.30$/MTok vs 3$/MTok non-caché = 10× moins cher. Sur 1.5M turns/mois à 10K MAU, cache hit 60% économise ~$2-3K/mois.
- **Métrique à monitorer** : log `cache_creation_input_tokens` + `cache_read_input_tokens` de chaque réponse Anthropic vers Datadog/Grafana. Alerte si hit-rate < 50% → drift de prefix prompt silencieux.

### Discipline 11 — Recitation pattern pour goal long-running (Manus)

**Règle :** dans les phases multi-PR ou tâches > 50 tool calls, **réécrire le goal et l'état du todo à chaque tour** dans la zone d'attention récente du modèle.

- Concrètement : `TodoWrite` à chaque transition d'étape (déjà fait par défaut), mais aussi écrire un `## État actuel` court dans le message texte avant chaque batch d'actions.
- Pourquoi : en context long (typique Phase 55 avec ses 3 PRs), le goal initial est en début de fenêtre, l'attention récente est sur les dernières actions. Sans récitation, le modèle drift loin du goal au tour 30+.
- Anti-pattern : enchaîner 50 tool calls sans jamais re-affirmer ce qu'on essaie d'accomplir → on fait des micro-décisions correctes qui dérivent macro.

### Discipline 12 — Garder les erreurs dans le contexte (contre-intuitif, Manus)

**Règle :** ne pas effacer les traces d'erreur passées du contexte. Le modèle apprend implicitement de ses échecs et décale ses prédictions.

- Anti-pattern : « le test a échoué, je clean le transcript et je retry » → le modèle reproduit la même erreur.
- Pattern correct : laisser l'erreur visible, ajouter un message « pourquoi ça a échoué » court, retry avec correction informée.
- Pour MINT : applicable à `/systematic-debugging` (Iron Law) — quand on essaie 3 fixes (3-Fix Rule), garder les 3 traces d'échec dans le contexte aide la 4e décision de scope-out vs. retry.

### Discipline 13 — Avoid few-shot drift sur tâches répétitives

**Règle (Manus) :** quand on traite N items similaires (ex : 18 life events × 8 archetypes = 144 wiki templates ; ou 6 ARB files × N keys), introduire de la variation contrôlée dans la sérialisation/ordre pour empêcher le modèle de tomber dans un pattern mécanique qui drift.

- Concret : varier l'ordre des sections, alterner les exemples canoniques utilisés, randomiser légèrement les system prompts.
- Anti-pattern : 144 templates générés en série identique → dérive systématique non détectée jusqu'à ce qu'un user signale.
- Pour MINT : applicable aux générateurs de pages wiki V3, et au skill `/autoresearch-i18n` qui doit traduire en 5 langues.

---

## Workflow MINT canonique étendu (avec context engineering)

```
┌──────────────────────────────────────────────────────────────┐
│ 0. CONTEXT BUDGET — vérifier utilization actuelle            │
│    Si > 40% → compaction / sub-agent / clear avant de partir │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 1. RESEARCH → RESEARCH.md (séparé du PLAN)                   │
│    Files, lignes, dépendances, exemples canoniques           │
│    Sub-agent Explore si > 3 fichiers inconnus                │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 2. PLAN → PLAN.md (Goal · Decisions · Tasks · Verif · DoD)   │
│    /gsd-discuss-phase ou /writing-plans                      │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 3. RED test failing first, run, watch fail                   │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 4. GREEN minimal impl                                        │
│    Subagents si ≥ 10 fichiers ou ≥ 3 work pieces             │
│    Récitation goal à chaque transition d'étape               │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 5. PANEL 4 experts en parallèle pour TOUT écran Flutter      │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 6. PRE-PUSH CHECKLIST                                        │
│    grep callers · regen canonical · full test suite          │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 7. EVIDENCE update phase HTML + session HTML                 │
│    Garder erreurs dans le contexte (pas clean)               │
└──────────────────────────────────────────────────────────────┘
```

## Sources additionnelles (Context Engineering)

- [Anthropic — Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic Cookbook — memory, compaction, tool clearing patterns](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
- [Manus — Context Engineering for AI Agents: Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [Dexter Horthy YC — Advanced Context Engineering for Agents (talk)](https://www.youtube.com/watch?v=IS_y40zY-hc)
- [Patrick Debois Tessl — Context Is the New Code (QCon London 2026)](https://www.youtube.com/watch?v=bSG9wUYaHWU)
- [Latitude — Complete Guide to Context Engineering for Coding Agents](https://latitude.so/blog/context-engineering-guide-coding-agents)
- [Martin Fowler — Context Engineering for Coding Agents](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)
- [Bojie Li — Claude's Context Engineering Secrets from Anthropic](https://01.me/en/2025/12/context-engineering-from-claude/)

## Workflow MINT canonique (toute tâche non-triviale)

```
┌──────────────────────────────────────────────────────────────┐
│ 1. PLAN   /gsd-discuss-phase ou /writing-plans               │
│    Goal · Files · Decisions · Verification · DoD             │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 2. RESEARCH (si > 3 fichiers inconnus)                       │
│    Agent Explore en parallèle, lecture codebase maps         │
│    AVANT grep (memory feedback_read_order_planning)          │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 3. RED    /test-driven-development                           │
│    Test failing first, run, watch it fail                    │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 4. GREEN  Implementation minimale                            │
│    Subagents si ≥ 10 fichiers ou ≥ 3 work pieces             │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 5. PANEL  4 experts en parallèle (UX/a11y/adversarial/wire)  │
│    pour TOUT écran Flutter touché                            │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 6. PRE-PUSH CHECKLIST                                        │
│    grep callers · regen canonical · full test suite          │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│ 7. EVIDENCE  Update phase HTML report + session HTML         │
│    PRs, panel verdicts, test counts, deferred items          │
└──────────────────────────────────────────────────────────────┘
```

## Gates structurels (lefthook / CI)

À ajouter au pre-commit hook si absent :

- `tools/checks/accent_lint_fr.py` — déjà présent ✓
- `tools/checks/no_hardcoded_fr.py` — déjà présent ✓
- `tools/checks/screen_registry_parity.py` — déjà présent ✓
- `tools/checks/no_legal_admission_in_public_docs.py` — déjà présent ✓
- **À ajouter** : `tools/checks/façade_without_wiring.py` — détecter widgets sans onTap/onPressed wired vers un service réel
- **À ajouter** : `tools/checks/no_dead_screen.py` — détecter écrans non référencés dans `app.dart` ou `screen_registry`
- **À ajouter** : `tools/checks/test_existed_before_impl.py` — git blame check : test commit ≤ impl commit pour chaque nouveau fichier `lib/screens/` ou `services/`

## Anti-patterns à bannir explicitement

| ❌ Pattern | ✅ Alternative |
|---|---|
| « Je vais juste éditer ce fichier » sans plan | `/gsd-discuss-phase --auto` ou plan inline 5 lignes |
| « Tests green, je push » sans pre-push checklist | grep callers + regen + full test, dans la même session |
| « J'ajoute un null-check ici, ça devrait fix le crash » | `/systematic-debugging` 4 phases avant le fix |
| « Je vais paralléliser plus tard » | Subagents dès ≥ 10 fichiers ou ≥ 3 pieces |
| « Le widget est joli, je push » | Design panel 4-experts AVANT push (memory feedback_design_panel_before_push) |
| « Je documenterai après » | HTML report update dans le même commit que le code |
| « Tests post-impl » (verifie le code par le code) | TDD RED-first (écrit le besoin AVANT le code) |
| Mock le service sur le path golden | Hit le vrai service Railway staging (memory feedback_app_targets_staging_always) |
| « Je passe à la phase suivante, ça marche dans le sim » | Device walkthrough autonome via idb (memory feedback_device_gates) |

## Sources

- [Anthropic — Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)
- [Generative.inc — The Complete Claude Code Guide 2026](https://www.generative.inc/the-complete-claude-code-guide-2026-planning-context-engineering-and-high-leverage-development)
- [Marmelab — Claude Code Tips I Wish I'd Had From Day One](https://marmelab.com/blog/2026/04/24/claude-code-tips-i-wish-id-had-from-day-one.html)
- [Anthropic — Subagent framework guide](https://code.claude.com/docs/en/sub-agents)
- [Superpowers — TDD enforcement framework](https://github.com/obra/superpowers)
- [Systematic Debugging Skill — Iron Law + 3-Fix Rule](https://mcpmarket.com/tools/skills/systematic-debugging-1769377756537)
- [InfoQ — Anthropic Agent-Based Code Review](https://www.infoq.com/news/2026/04/claude-code-review/)
- [BMAD AI SDLC framework](https://www.eesel.ai/blog/claude-code-best-practices)
- [TDD with Claude — RED-GREEN-REFACTOR](https://github.com/FlorianBruniaux/claude-code-ultimate-guide/blob/main/guide/workflows/tdd-with-claude.md)
- [Plan Mode 2026 guide](https://www.claudedirectory.org/blog/claude-code-plan-mode-guide)
- [UX Planet — CLAUDE.md Best Practices](https://uxplanet.org/claude-md-best-practices-1ef4f861ce7c)
