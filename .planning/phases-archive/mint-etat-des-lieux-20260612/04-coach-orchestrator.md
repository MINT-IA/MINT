---
name: coach-orchestrator-audit
description: État des lieux + cible du coach AI MINT — pourquoi « un rachat c'est retirer ton capital » a pu passer, et comment le forcer à grounder définitions ET chiffres, rendre des widgets, et ne plus perdre les faits de chat. Audit file:line + cible orchestrateur + plan eval + challenge du framing fondateur.
status: Proposed
date: 2026-06-12
---

# Coach Orchestrator — Audit & Cible (état des lieux 2026-06-12)

## TLDR

Le coach MINT a une **infrastructure de grounding sophistiquée mais exclusivement numérique**. Citation gate, hallucination detector, runtime verb/freshness/temporal gates, tool_use mandate : tout opère sur des *chiffres* (CHF, %, durées, articles de loi). Le bug « un rachat = retirer ton capital 2e pilier » est une **définition inversée sans aucun chiffre** — elle traverse les 5 gates et les 6 doctrine-checks intacte, parce qu'**il n'existe aucun outil ni registre de définitions, et `tool_choice` reste `auto` sur la surface authentifiée**. Le LLM définit les concepts suisses depuis ses propres poids, en texte libre, et personne ne vérifie la sémantique. C'est le trou P0.

Trou P0-bis : la **perte de faits chat→profil**. `save_fact` (authentifié) écrit dans `ProfileModel.data` côté **backend/DB**, tandis que les écrans mobiles lisent `CoachProfile` (SecureStorage **local**). Le « 50 ans » dit en chat n'atteint jamais l'écran qui lit le profil local : split-brain de persistance, pas un oubli LLM.

La cible : (1) un **registre de connaissances suisses curé** (wiki, pas vector-soup) qui devient la SEULE source de définitions, exposé via un outil `explain_concept` à invocation **forcée** dès qu'une définition de concept réglementé est demandée ; (2) un **validateur de définition** (claim→concept mapping) qui rejette/re-prompt quand le texte affirme une définition non sourcée ; (3) un **protocole generative-UI à catalogue fermé** (A2UI / Flutter GenUI-style) sur la base du `widget_renderer` existant — pas de layouts générés ; (4) un **pipeline chat→profil unifié** (une seule source de vérité) ; (5) un **eval harness étendu** couvrant les définitions, pas seulement les chiffres.

Challenge du fondateur (obligatoire, §6) : « orchestrateur LLM unique » est le mauvais cadre — le bon est **routeur déterministe + LLM contraint + composants curés**. « Magnifiques écrans générés » ne doit JAMAIS vouloir dire layouts générés par le LLM : ça veut dire composants MINT curés, remplis par des payloads schema-validés. Et une conversation qui rend des widgets/graphes/simulations a un coût/latence réel à arbitrer (§6.2).

---

## 1. Carte de l'état actuel (file:line)

### 1.1 Le pipeline de génération authentifié

| Couche | Fichier:ligne | Rôle | Couvre les définitions ? |
|---|---|---|---|
| System prompt builder | `services/backend/app/services/coach/claude_coach_service.py:804-914` (`_build_prompt`) | Compose ~600 lignes : doctrine, archétypes, life events, voice | NON — texte libre |
| Connaissances suisses (in-prompt) | `claude_coach_service.py:740-748` | Bloc « CONNAISSANCES SUISSES » : rachat=déduction fiscale (correct ICI), EPL, rente vs capital | Présent dans le prompt, mais **« n'utilise ces faits QUE si la conversation l'amène »** → le LLM est **libre de définir depuis ses poids** |
| Tools passés au LLM | `coach_tools.py:126-1203` (`COACH_TOOLS`), `get_llm_tools():1230` | 28 outils : show_*, route_to_screen, save_fact, get_* | **AUCUN outil `explain_concept`/`get_definition`** |
| Appel Anthropic | `services/backend/app/services/rag/llm_client.py:214-283` | `messages.create(...)`, `max_tokens=600` | `tool_choice = {"type":"auto"}` (**ligne 227**) — jamais forcé |
| Agent loop + gates | `services/backend/app/api/v1/endpoints/coach_chat.py` (5785 lignes) | verb→freshness→temporal→citation gate, tool_use enforcement | tous **numériques** |
| Citation gate | `citation_parser.py:70-120` | 5 regex : currency / percent / legal-article / duration / regulatory-name | **chiffres uniquement** |
| Hallucination detector | `hallucination_detector.py:136-274` | extrait CHF/%/durées, compare aux constantes légales | **chiffres uniquement** |
| Doctrine checks (6) | `doctrine_checks.py:42-47` | numeric_anchor, concision, banned_terms, action_or_handoff, archetype_aware, escalation_aware | **AUCUN check de correction sémantique** |
| ComplianceGuard | `compliance_guard.py:355-496` | L1 banned terms → L3 hallucination numérique | banned terms + chiffres |
| Citation registry | `citation_registry.py` (~18 clés) | `r3a_plafond_*`, `lpp_taux_conv_*`, `lifd_art_*`… | **valeurs réglementaires datées uniquement — zéro définition de concept** |

### 1.2 La surface anonyme (DIFFÉRENTE — et ironiquement plus sûre sur ce point)

`anonymous_chat.py:178-218` : un **détecteur de mots-clés finance** (`_FINANCE_KW`, ligne 183) **resserre `tool_choice` de `auto` à `{"type":"tool","name":"get_regulatory_constant"}`** quand la question contient 3a/lpp/avs/plafond/rente/etc. (ligne 204-208). C'est exactement le pattern de tool-forcing qui manque côté authentifié — mais il ne force qu'un outil *numérique* (`get_regulatory_constant`), pas une définition.

### 1.3 La surface mobile (rendu + capture de faits)

- `apps/mobile/lib/widgets/coach/widget_renderer.dart:52-80+` — `WidgetRenderer.build()` : `switch (call.name)` sur ~14 cases (`show_fact_card`, `show_budget_snapshot`, `show_score_gauge`, `ask_user_input`, `route_to_screen`, `generate_financial_plan`, `record_check_in`, `generate_document`, `show_commitment_card`, `save_partner_estimate`…). **C'est déjà un catalogue de composants curés** — la bonne base pour la generative-UI.
  - `show_fact_card` → `_buildFactCard(context, call.input)` : le `content`, le `source` et le `highlight_value` sont **100% générés par le LLM** (`coach_tools.py:139-160`). Une fact-card peut donc afficher une définition inversée avec une source inventée.
- `apps/mobile/lib/services/coach/context_injector_service.dart:33-61` — construit le `memoryBlock` injecté dans le system prompt (lifecycle, mémoire conversation, goals, plan). Anonymisation par topics, pas valeurs exactes.
- **Split-brain de persistance** :
  - `save_fact` authentifié → `coach_chat.py:2380+` (`_persist_extracted_fact`) → `ProfileModel.data` en **DB backend** (whitelist de clés `coach_chat.py:2099+`).
  - Les écrans mobiles lisent `apps/mobile/lib/models/coach_profile.dart` (`CoachProfile`) en **SecureStorage local**.
  - `save_fact` n'est **pas** dans le `switch` de `widget_renderer.dart` (c'est un `INTERNAL_TOOL_NAMES`, `coach_tools.py:104`) → le mobile ne reçoit jamais l'écho de la valeur pour mettre à jour son store local. → Le « 50 ans » dit en chat vit en DB backend, jamais dans le `CoachProfile` que l'écran lit. **C'est le bug rapporté.**

### 1.4 Defer-loading adapter (scaffolding, pas câblé)

`tool_registry/anthropic_defer_loading_adapter.py:1-55` — wire l'Anthropic Tool Search Tool (BM25 `tool-search-tool-2025-10-19`) : 5 chip-emitters always-on + 60+ calculateurs `defer_loading:True` chargés JIT. **Explicitement « NOT wired into the coach narrator yet ».** C'est de l'échafaudage. La cible §3 doit décider de son rôle (il est pertinent pour la scalabilité d'un outillage à 60+ calculs, mais c'est orthogonal au trou définitions).

---

## 2. Liste des trous, classée par sévérité

### P0 — Définitions non groundées (le bug `rachat`)
**Le LLM génère les définitions de concepts suisses depuis ses poids, sans outil ni registre, sans validateur sémantique, avec `tool_choice=auto`.** Aucune des 8+ couches de défense ne contient de chiffre à inspecter sur un énoncé définitionnel. Trust collapse + exposition LSFin art. 8 (qualité de l'information). C'est le trou structurel — tout le reste de l'infra grounding est une cathédrale construite autour des seuls *nombres*.

### P0 — Split-brain chat→profil
`save_fact` écrit en DB backend ; les écrans lisent SecureStorage local ; aucun pont. Tout fait dit en conversation est perdu pour le reste de l'app. Casse la promesse « accompagne lifelong » : le coach ne se souvient pas, et les écrans n'héritent pas.

### P1 — `show_fact_card.content` + `.source` LLM-générés
Même après un fix définitions, la fact-card reste un canal d'émission de définition libre (le `source` peut être inventé : « LPP art. 79b » collé sur une définition fausse). Tant que `content`/`source` ne viennent pas du registre, la fact-card est un trou.

### P1 — Tool-forcing absent côté authentifié
Le pattern existe (anonyme, `anonymous_chat.py:204`) mais n'est pas porté sur la surface principale. Le system prompt dit « MANDATORY save_fact » mais `tool_choice=auto` ne le garantit pas (le commentaire `llm_client.py:223` le reconnaît : « Sonnet sometimes skips tool_use entirely »).

### P2 — Eval ne couvre pas les définitions
`citation_gate_eval_50.jsonl` + `narrator_eval_50.jsonl` + `test_coach_doctrine_eval.py` : fixtures orientées chiffres/citations/doctrine. **Aucune fixture « définition inversée »** du type rachat. Un eval qui aurait attrapé ce bug n'existe pas.

### P2 — Catalogue generative-UI non contractualisé
`widget_renderer` est un bon catalogue de fait, mais il n'y a pas de **schéma de payload validé** par widget côté backend→mobile (les inputs sont des `dict` libres). Drift silencieux possible (l'historique du fichier mentionne déjà des orphan cases supprimés). Pas de contrat = pas de génération sûre de « beaux écrans ».

### P3 — `get_regulatory_constant` forcé seulement par mots-clés (anonyme)
Heuristique regex fragile ; un synonyme non listé (« mon deuxième pilier », « cotisation prévoyance ») ne déclenche pas le force. À durcir par classification d'intent plutôt que keyword-match.

---

## 3. Conception cible : l'orchestrateur groundé

### 3.0 Principe directeur
**Le LLM n'est jamais une source de vérité — ni pour les chiffres (déjà acquis), ni pour les définitions (à acquérir).** Tout fait de domaine (chiffre OU définition OU règle) vient d'un store déterministe avec un trace ID. Le LLM orchestre, formule, accompagne ; il ne *connaît* rien d'autoritatif.

### 3.a Contrat de génération groundée

1. **Registre de connaissances suisses curé (wiki, pas vector-soup)** — per décision projet `project_user_profile_wiki` : pages par concept (`rachat_lpp`, `epl`, `rente_vs_capital`, `3a`, `libre_passage`, `splitting_avs`, `fatca`…), chacune avec : définition canonique FR validée par un humain, source légale exacte, contre-sens fréquents (« ce que ce n'est PAS »), liens nommés vers concepts liés. Structure identique au `.planning/` wiki (CLAUDE.md §8). **Étend `citation_registry.py`** d'une nouvelle famille `concept:<key>` (description_fr → definition_fr canonique).
2. **Définitions UNIQUEMENT depuis le registre** — un nouvel outil `explain_concept(concept_key)` retourne la page wiki. Le LLM ne paraphrase pas la définition : il la **cite** (placeholder `{{cite:concept_<key>}}`), exactement comme il cite déjà un chiffre via `{{cite:tool_*}}`. La grammaire de citation (`citation_grammar.py`) est étendue à la famille `concept_*`.
3. **Refus/re-prompt sur définition nue** — un **validateur de définition** (nouveau, voir 3.b) détecte les énoncés définitionnels (« un X, c'est… », « X signifie… », « X = … » sur un terme du registre) et exige soit un `{{cite:concept_<key>}}` adossé à un `tool_use(explain_concept)` réel, soit reformule en « je vérifie ça pour toi » + invocation. Sans source : rejet → re-prompt → fallback templaté (réutilise le pattern `_enforce_tool_use_for_citations` de `coach_chat.py:773`).

### 3.b Mécanique de tool-forcing (API Claude actuelle)

> Modèle : `claude-sonnet-4-5` (cf. `anonymous_chat.py:200`). Vérifier model-id/pricing via la skill `claude-api` avant tout réglage de coût.

1. **Classifier d'intent → `tool_choice` ciblé.** Remplacer le keyword-regex anonyme par le classifier d'intent déjà présent (`coach_chat._classify_user_intent`). Si l'intent est « demande de définition d'un concept réglementé » → `tool_choice={"type":"tool","name":"explain_concept"}` (forcé). Si « demande de chiffre » → forcer `get_regulatory_constant`/calculateur. Sinon `auto`. Porter ce mécanisme sur la surface **authentifiée** (aujourd'hui absent — `llm_client.py:227` est `auto` en dur).
2. **`disable_parallel_tool_use=False`** conservé (permet save_fact multiples + explain + calcul dans le même tour).
3. **Validateur structurel post-génération** (déterministe, pas LLM-as-judge — per `johnsonlee.io` cité CLAUDE.md §9 : vérifier du probabiliste avec du probabiliste = pas de vérif) : regex de détection de pattern définitionnel sur le lexique du registre (closed-world : on connaît la liste des concepts). C'est le pendant *sémantique* du citation gate numérique. Pas de NLP lourd — un détecteur de surface « DEFINIENDUM is/c'est/signifie DEFINIENS » où DEFINIENDUM ∈ registre.
4. **Structured outputs** pour les payloads de widget (3.c) — JSON Schema validé côté backend avant forward au mobile.

### 3.c Protocole generative-UI (catalogue fermé)

État de l'art convergent (A2UI v0.9 Google, Flutter GenUI SDK, MCP Apps SEP-1865, AI SDK generative UI) : **le client maintient un catalogue de composants pré-approuvés ; l'agent ne peut demander QUE des composants du catalogue, avec des données validées par schéma. Format déclaratif, pas de code exécutable.** C'est EXACTEMENT ce que `widget_renderer.dart` est déjà à 80%. Cible :

1. **Contractualiser chaque widget** : pour chaque case du `switch` (`widget_renderer.dart`), un Pydantic schema backend + son miroir Dart, validé avant render. Le LLM émet un `tool_use` dont l'`input` est rejeté s'il ne matche pas le schéma (échec → pas de render, fallback texte).
2. **Étendre le catalogue, pas le mode** : graphes/tables/timelines = **nouveaux composants curés** (`show_projection_chart`, `show_comparison_table`, `show_scenario_band`), pas du HTML/layout généré. Les données numériques de ces composants viennent des calculateurs (financial_core L1 / backend L2-L4 per CLAUDE.md §4), pas du LLM.
3. **Le LLM choisit le composant + fournit le payload ; il ne dessine jamais le layout.** (Voir challenge §6.3.)

### 3.d Pipeline conversation→profil

1. **Une seule source de vérité.** Décider : soit le profil canonique est backend (`ProfileModel.data`) et le mobile le lit via API (pas SecureStorage divergent), soit l'inverse. Vu CLAUDE.md §4 (financial_core L1 = mobile-canonical, offline-capable), le plus cohérent : **le mobile possède le profil L1**, le backend en reçoit une copie pour le contexte coach, et `save_fact` retourne au mobile (via la réponse HTTP) la valeur extraite pour mise à jour du `CoachProfile` local. Aujourd'hui `save_fact` est `INTERNAL` (jamais forwardé) — **le sortir du forward-block** et le router au mobile comme un fait confirmable.
2. **UX de confirmation** : un fait extrait du chat n'écrit pas silencieusement. Carte « J'ai noté : 50 ans — c'est juste ? [Oui] [Corriger] » (réutilise `chat_data_capture.dart` / `ask_user_input`). Confirmation = write event-log.
3. **Event-log write** : aligné sur l'ADR data-architecture `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md`. Chaque fait confirmé = un event horodaté, pas un overwrite.

### 3.e Document upload → faits profil (cas phare : certificat LPP)

1. `document_vision_service.py` existe déjà (vision Claude). Cible : extraction → **mapping vers clés profil canoniques** (`avoirLpp`, `lppInsuredSalary`, `tauxConversion`, `lppCertificateYear`…) → même pipeline de confirmation que 3.d (jamais d'écriture silencieuse d'un OCR).
2. Le certificat LPP devient un **fait daté** (« selon ton certificat de mars 2026 ») — le prompt biography-awareness (`claude_coach_service.py:518-541`) gère déjà le dating ; il faut que la donnée *arrive* dans le store que la biography lit.
3. Trace ID : la valeur extraite porte l'ID du document source → citable (`{{cite:doc_<id>}}`), inspectable par l'utilisateur.

### 3.f Eval harness

1. **Étendre les fixtures** : ajouter une catégorie `definition_grounding` à `citation_gate_eval_50.jsonl` — N fixtures « piège définitionnel » dont **le cas rachat exact** (« c'est quoi un rachat LPP ? » → doit invoquer `explain_concept`, doit citer la définition canonique, doit échouer si le texte dit « retirer »). C'est la régression-test mécanique qui aurait attrapé le bug.
2. **Scorers déterministes d'abord** (per Braintrust/FinLFQA) : format, présence du `tool_use(explain_concept)`, présence du placeholder `{{cite:concept_*}}`, absence de la chaîne inversée connue. Code-based, reproductible (CLAUDE.md §9 ground-truth déterministe).
3. **LLM-as-judge en complément seulement** (per Conv-FinRe : instable, sensible à la longueur) pour le ton/utilité — jamais pour la correction factuelle. Rubrique tiered 1-5 (accuracy / numerical correctness / evidence entailment) à la FinLFQA.
4. **Brancher sur `/autoresearch-prompt-lab` + `/autoresearch-compliance-hardener`** : le compliance-hardener génère déjà des tests adversariaux pour casser les guards — lui donner explicitement la classe « définition inversée » comme cible. `prompt-lab` optimise le prompt contre les fixtures immuables → ajouter les fixtures définition au set immuable.

---

## 4. Plan eval (séquencé)

1. Écrire la fixture `rachat-inversion` (+ 10-15 variantes définitionnelles) → la faire **échouer** contre le coach actuel (prouve le trou de façon déterministe, CLAUDE.md §9).
2. Construire le registre `concept:*` (10-15 concepts P0 : rachat, EPL, rente vs capital, 3a, libre passage, splitting, FATCA, frontalier, coordination LPP, EPL-blocage-3-ans).
3. `explain_concept` tool + grammaire `concept_*` + validateur définitionnel + tool-forcing par intent (authentifié).
4. Re-run fixtures → vert. Brancher au CI (gate régression définitions, comme le citation gate l'est pour les chiffres).
5. `autoresearch-compliance-hardener` en boucle sur la classe définition jusqu'à 0 brèche.

---

## 5. Sources (état de l'art 2025-2026)

- Grounding LLM finance régulée : [arxiv 2509.14180 (behaviorally-grounded finance LLM)](https://arxiv.org/html/2509.14180v1) · [COLING 2025 Financial Regulations Challenge](https://arxiv.org/pdf/2412.11159) — « targeted retrieval for regulatory info + calculation verification yields highest marginal improvement ».
- Verifiable generation par références symboliques : [arxiv 2311.09188](https://arxiv.org/pdf/2311.09188) — le pattern « placeholder→résolution » de MINT est exactement ça, à étendre aux définitions.
- Generative UI à catalogue fermé : [Google A2UI v0.9](https://developers.googleblog.com/a2ui-v0-9-generative-ui/) (« catalog of trusted, pre-approved components ; declarative, not executable ») · [Flutter GenUI SDK](https://github.com/flutter/genui) · [TELUS sur MCP Apps / OpenAI Apps SDK / A2UI](https://www.telusdigital.com/insights/data-and-ai/article/accelerating-genui-ecosystem-mcp-apps-openai-apps-sdk-and-google-a2ui).
- Eval advice financier : [Braintrust LLM eval guide](https://www.braintrust.dev/articles/llm-evaluation-guide) (code-based vs LLM-judge) · [FinLFQA attributed generation](https://arxiv.org/pdf/2510.06426) · [Conv-FinRe](https://arxiv.org/pdf/2602.16990) (instabilité LLM-judge).

---

## 6. Challenge du framing fondateur (obligatoire)

### 6.1 « Orchestrateur LLM unique » → le bon cadre est routeur + LLM contraint + composants curés
Le fondateur décrit un LLM qui « pendant la conversation rend des widgets, lance des simulations, fait de l'arbitrage ». Le risque : tout confier à un seul LLM généraliste invite précisément le bug rachat (le LLM *décide* tout, donc *hallucine* parfois). Le bon modèle est un **orchestrateur mince** : le LLM est le *chef d'orchestre du dialogue* mais (a) les **définitions** viennent d'un registre, (b) les **chiffres** des calculateurs, (c) les **simulations/arbitrages** des moteurs déterministes (financial_core L1 + backend L2-L4, CLAUDE.md §4 — re-implémenter une simulation Monte-Carlo dans le LLM violerait NEVER #3). Un seul LLM oui ; mais **désarmé sur les faits**. Pas besoin d'un router multi-LLM/specialists pour le MVP (sur-ingénierie, Karpathy #2) — un seul LLM + `tool_choice` forcé par intent suffit. Le multi-specialist se justifierait seulement si la latence d'un tour à 5 outils devient le goulot (à mesurer, pas à présumer).

### 6.2 Réalisme latence/coût d'une conversation qui rend des widgets
`max_tokens=600` (`llm_client.py:216`), prompt caching actif (`router.py`). Mais un tour qui : classifie l'intent → force `explain_concept` → re-call avec tool_result → éventuellement force un calculateur → re-call → valide → rend un widget, c'est **3-4 allers-retours LLM** + N calculs. À ~1-3s par hop, une réponse « riche » peut coûter 5-10s et 3-4× le coût d'un tour texte. Implications : (a) les chip-emitters always-on / defer-loading (`anthropic_defer_loading_adapter.py`) sont la bonne direction pour borner le coût d'outillage ; (b) il faut un **budget de hops par tour** (le `turn_cap.py` existe pour les tours, pas pour les hops) ; (c) tout n'a pas besoin d'être génératif — une définition est un **lookup**, pas une génération (cf. 6.3). Mesurer P95 latence avant de promettre « widgets en temps réel ».

### 6.3 Ce que « magnifiques écrans générés » ne doit PAS être
**Layouts générés par le LLM = anti-pattern.** A2UI/Flutter GenUI convergent justement vers l'inverse : catalogue de composants curés, remplis par payloads schema-validés. Pour MINT, « bel écran » = un composant `MintUI` curé (design system, MintColors, i18n ARB — CLAUDE.md §5 NEVER #1/#2/#5), pas un layout improvisé qui violera le design system, l'a11y, l'i18n, ou affichera un terme banni. Le LLM **choisit** le composant et **fournit les données** (groundées) ; il ne dessine pas. Le `widget_renderer` existant est déjà cette discipline — la cible est de la **contractualiser** (schémas), pas de l'ouvrir. « Génératif » s'applique au *choix + remplissage*, jamais à la *structure visuelle*. Sinon : chaque écran généré redevient une surface où une définition inversée et un terme LSFin banni peuvent ré-apparaître hors de tout gate.

### 6.4 Le piège du « accompagne lifelong »
La promesse d'accompagnement lifelong est cassée AUJOURD'HUI par le split-brain §1.3, pas par un manque de features. Avant d'ajouter des simulations et des écrans générés, **le pipeline chat→profil→écrans doit être unifié** (3.d). Un coach qui ne retient pas « 50 ans » d'un tour à l'autre ne peut pas accompagner 30 ans. C'est le prérequis non-négociable, et il est moins sexy que la generative-UI — mais c'est l'ordre correct.
