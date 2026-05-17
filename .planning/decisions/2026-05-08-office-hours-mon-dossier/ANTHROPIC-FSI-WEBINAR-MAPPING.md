---
name: Anthropic FSI webinar — mapping vers MINT
description: « Claude for Financial Services: Putting Agents to Work » (Nick Lynn + Owen Scully, 59 min). Mapping des patterns Skills/Templates/Sub-agents/Connectors vers le stack MINT et l'Office Hours « Mon dossier ».
type: reference
date: 2026-05-08
source: https://anthropic.ondemand.goldcast.io/on-demand/74ae0fc7-f591-442f-8fe1-244f409c1fb5
related: .planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md
status: Proposed
---

# Anthropic FSI webinar — mapping vers MINT

## Source

- Talk : « Claude for Financial Services: Putting Agents to Work »
- Speakers : Nick Lynn (Head of Product, Financial Services), Owen Scully (Applied AI Team Leader)
- Plateforme : Goldcast on-demand (Anthropic event 74ae0fc7-f591-442f-8fe1-244f409c1fb5)
- Durée : 59 min
- Date d'accès : 2026-05-08

## Architecture Anthropic présentée

**« Claude is one thinking engine »** en 3 couches :
1. Foundation models (Haiku / Sonnet / Opus)
2. Platform layer (APIs, tools, managed agents)
3. Applications (custom workflows)

**3 building blocks pour déployer** :
- Connectors (MCP-based, ex: S&P Global, FactSet, Moody's, LSEG, GuidePoint, D&B, Verisk)
- Skills (markdown reusable instruction sets, progressive disclosure)
- Sub-agents (specialized agents)

## Patterns directement applicables à MINT

### 1. Skills system + progressive disclosure
**Description Anthropic** : skill = markdown avec « When to use this skill » trigger, output format, conditional logic. Description chargée en métadonnée ; full skill loaded on-demand quand Claude détecte trigger match. Permet de gérer le contexte malgré 1M tokens window.

**Application MINT** : refactoriser le system prompt monolithique de [coach_chat_screen.dart](apps/mobile/lib/screens/coach/coach_chat_screen.dart) (qui charge LSFin + voice + archetype + memory à chaque message) en N skills :
- 1 skill par life event (18 skills)
- 1 skill par calculator family (AVS, LPP, 3a, fiscalité, immobilier, succession)
- 1 skill par archetype risk (FATCA US, frontalier, indépendant_no_lpp)
- Voice/LSFin/banned-terms restent dans system prompt base (cross-cutting)

**ROI** : -60-80% tokens par message coach ; ajout d'un life event = écrire 1 markdown, pas refactoriser le prompt.

### 2. Agent Templates per workflow
**Description Anthropic** : 10 templates pre-built (Pitch Builder, Valuation Review, Earnings Analysis, Model Building…). Chaque template = packaging de skills + connectors + workflow.

**Application MINT** : N templates pour les 18 life events :
- `housing_purchase_template` : skills mortgage_simulator + tax_imputed_rental + EPL_buyback + LPP_advance + comp_locataire_vs_proprietaire ; connector cantonal_tax_API
- `lpp_buyback_template` : skills LPP_buyback_max + tax_deduction + retirement_replacement_ratio
- `divorce_template` : skills LPP_split + AVS_split + matrimonial_regime_simulator
- `expat_us_arrival_template` : skills FATCA_disclosure + PFIC_warning + double_taxation
- (etc.)

**Cela résout directement les 4 critiques de l'OH-6 (Office Hours panel)** :
- « 5/8 archétypes pas câblés » → un template par (life event × archétype) rend explicite ce qui est câblé. Pas de wiring = pas de template = pas d'entrée dossier.
- « 90% empty state » → template s'amorce dès 1ère interaction coach. Dossier se remplit progressivement.
- « Façade-sans-câblage » → template DÉCLARE ses calculators ; test mécanique vérifie callability. Façade impossible.
- « Drift régulatoire » → chaque skill embarque disclaimers + banned-terms + confidence requirements. Compliance distribuée.

### 3. Sub-agents parallel pattern
**Description Anthropic** : Maya's Valuation Review spawne 1 sub-agent par portfolio company. Chacun ingère financials et exécute analyse en parallèle. Console live observe tous les sub-agents.

**Application MINT** : « analyse mon dossier complet » spawne en parallèle :
- sub-agent AVS (calcule rente projetée vs cotisations actuelles)
- sub-agent LPP (avoir + lacune rachat + projection)
- sub-agent 3a (max non utilisé + tax saving potentiel)
- sub-agent immobilier (capacité hypothécaire si plan housing actif)
- sub-agent fiscalité (deductions vs revenu actuel)

Chaque sub-agent reçoit un **slim CoachContext typé** (pattern Vibe Engineering aligné — convergence des 2 vidéos).

### 4. Skill Creator meta-tool
**Description Anthropic** : user demande en langage naturel (« crée un skill earnings deck PowerPoint »), Claude génère le skill markdown auto-utilisable.

**Application MINT** : permettre à l'éditorial (toi, Julien, ou un Swiss-brain expert externe) d'ajouter un life event sans toucher Flutter/Python :
- Description : « quand l'user mentionne qu'il devient bientôt résident suisse depuis l'étranger, charge ces calculators et pose ces questions »
- Skill Creator génère le markdown
- Skill immédiatement disponible côté coach

**ROI massif** sur la vélocité 18 life events × 8 archétypes (≈ 144 combinaisons potentielles).

### 5. Model routing par tâche
**Description Anthropic** : « Start with Sonnet, evaluate; move to Haiku for speed, Opus for deep analysis. »

**Application MINT** :
- Cap du jour + nudges quotidiens + tone chips → Haiku (économie tokens 80%)
- Coach chat normal + Hero Plan + extraction LPP → Sonnet (default)
- Arbitrage multi-step (rente vs capital + Monte Carlo + tornado sensitivity) → Opus

**Aujourd'hui** : MINT utilise ServerKey Claude (probablement Sonnet par défaut sur tous les paths). ROI mesurable et trivial à implémenter (`coach_chat_api_service.dart` selon route → model).

## Patterns adjacents (intéressants, Phase 2+)

### Cloud Managed Agents (async exécution)
- **Pattern** : agents tournent autonomement sur infra Anthropic, full observability via console.
- **Cas MINT possible** : overnight job CSV/Camt.053 OCR + catégorisation + projection annuelle.
- **Friction** : Swiss data residency (LPD/nLPD art. 16) — l'infra Anthropic = US-bound. À évaluer pour Phase 2 si data residency contracts dispo, sinon rester on-device + backend Railway EU.

### Connectors via MCP
- **Pattern** : MCP servers exposent S&P/FactSet/LSEG/etc. avec auth + streaming uniformes.
- **MINT today** : `.mcp.json` ([CLAUDE.md §3](CLAUDE.md)) avec `mint-tools` (4 tools : `get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`, `check_accent_patterns`).
- **Phase 2 possible** : connector bLink (quand API dispo), connector ESTV (Administration fédérale des contributions, tax tables cantonal), connector OFAS (AVS rentes officielles).

### Cross-app context syncing
- **Pattern** : changement Excel propage vers PowerPoint via Cloud agent watch.
- **MINT possible** : changement plan financier propage vers Aujourd'hui card + coach context + Mon argent breakdown — c'est exactement le **propagation event-sourced** proposé en panel Vibe Engineering hier (`RolloverDecidedEvent` → `MonthlySavingsContributed` → `FinancialPlanService.contributeMonthlySavings`).
- **Convergence** : les 2 vidéos pointent dans la même direction (events typés + état dérivé + propagation cross-surface).

## Patterns NON applicables

- **Microsoft 365 integration** (Excel / PowerPoint / Word / Outlook) — MINT est mobile-first B2C, pas enterprise B2B.
- **Investment banking pitch builder** — mauvais segment.
- **LBO models / comp sheets** — corporate finance, pas personal finance.
- **RBAC enterprise par teams** — overkill pour MVP single-user MINT (à reconsidérer si MINT lance un canal partenaires/B2B2C plus tard).

## Conséquences pour Office Hours « Mon dossier »

**Verdict OH-1 à OH-6 d'hier** : ship 0.5j drawer entry « Mon plan », defer le 4e tab Dossier full, rename « Dossier » → « Mon plan ». Verdict basé sur 4 critiques (90% empty, 5/8 archétypes pas câblés, façade, drift régulatoire).

**Ce que ce webinar ajoute** : le pattern **Skills + Templates + Sub-agents** rend les 4 critiques attaquables. Si MINT adopte ce pattern, le dossier full devient viable parce que :
- les templates explicitent le câblage (résout 5/8 archétypes)
- s'amorcent dès 1ère interaction (résout 90% empty)
- déclarent leurs calculators (résout façade)
- embarquent leur compliance (résout drift)

**Mais cela ne change pas le verdict 0.5j drawer pour TestFlight Q3.** Le pattern Skills+Templates est un investissement architectural Phase 2-3 (estimé 3-6 semaines), qui DOIT venir APRÈS le drawer ship. Le drawer reste le bon premier pas.

**Ce qui devrait être ajouté au DESIGN.md d'hier** : une section « Phase 2 — Skills + Templates as the architectural reframing ». Reformule la migration vers un Dossier full comme une migration vers une **architecture skill-driven**, pas comme un agrandissement de drawer en tab.

## Action items proposés (à valider avant ré-ouverture OH)

1. **Pas d'action immédiate sur le drawer** — il reste 0.5j shippable comme convenu hier.
2. **Quand on ré-ouvrira OH** : amender le DESIGN.md d'hier avec une section « Phase 2 architectural reframing » qui pose le pattern Skills+Templates comme le path vers le Dossier full (vs juste un drawer agrandi).
3. **POC mesurable** : tester le model routing (Haiku pour Cap du jour, Sonnet/Opus selon route) — ROI évaluable en 1 sprint, indépendant du Dossier.
4. **Phase 3 candidate** : Skill Creator meta-tool qui permet à Julien d'ajouter un life event sans coder. Massif sur la velocité éditoriale.

## Counter-arguments and data gaps

- **Le pattern Anthropic FSI est conçu pour B2B enterprise (analystes IB, fund accounting)** — peut ne pas mapper 1:1 sur du B2C retail. La complexité des « comp sheets / pitch decks » n'a pas d'équivalent direct chez le retail Swiss.
- **Les templates Anthropic FSI assument une licence FSC/équivalent** — MINT n'a pas cette licence. Les templates MINT doivent rester strictement éducatifs (verbes interdits LSFin) pour ne pas dériver en zone régulée. Risque que la pression « plus de capabilities = plus de drift régulatoire » revienne.
- **Sub-agents asynchrones sur Anthropic infra** — non viable pour MINT à cause de la résidence des données suisses (LPD/nLPD art. 16). Devra rester on-device ou backend EU. La pattern reste valable, juste pas l'infra.
- **Skill Creator meta-tool** — risque que des skills générés en langage naturel échappent aux gates LSFin. Il faut un linter sur le markdown généré (banned-terms, archetype-coverage, calculator-callability) avant qu'il soit enabled.
- **Données manquantes** : aucun benchmark interne MINT sur le coût/token actuel des messages coach. Le « -60-80% tokens » est une estimation Anthropic ; à mesurer post-implémentation.
- **Convergence des 2 vidéos** : Vibe Engineering (Effect TS, durable workflow) + Anthropic FSI (Skills + Templates + Sub-agents) pointent dans la même direction architecturale. Le risque est de surinterpréter une convergence émergente comme une obligation. À tester par POC limité avant commit Phase 2.

## Références

- Vidéo : https://anthropic.ondemand.goldcast.io/on-demand/74ae0fc7-f591-442f-8fe1-244f409c1fb5
- Office Hours design doc : [.planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md](.planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md)
- Walker Q1-Q3 panel : [.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md](.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md)
- Vibe Engineering (vidéo précédente) : https://youtu.be/Wmp2Tku2PrI
- MINT MCP today : [.mcp.json](.mcp.json) + CLAUDE.md §3
- Coach chat screen : [apps/mobile/lib/screens/coach/coach_chat_screen.dart](apps/mobile/lib/screens/coach/coach_chat_screen.dart)
