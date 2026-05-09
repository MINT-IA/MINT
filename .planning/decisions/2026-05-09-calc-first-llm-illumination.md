---
date: 2026-05-09
status: Proposed
authors: Julien (delegated decision) + PM Claude (synthesis)
panel: 7-pers (quant-actuarial / cleo-fintech / llm-architecture / ml-arbitrage / ux-voice / compliance / production-reliability)
supersedes: —
superseded_by: —
description: Pivot architectural — calc engine devient source de vérité, LLM réduit à narrateur d'illumination ; informe Phase 94 + nouveau 92.5 + extension 95/96.
related:
  - .planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison.md
  - decisions/ADR-20260419-v2.8-kill-policy.md
  - decisions/ADR-20260223-unified-financial-engine.md
  - .planning/audit/calc-first-architecture/expert-1-quant-actuarial.md
  - .planning/audit/calc-first-architecture/expert-2-cleo-fintech-research.md
  - .planning/audit/calc-first-architecture/expert-3-llm-illumination-architecture.md
  - .planning/audit/calc-first-architecture/expert-4-ml-arbitrage-optimization.md
  - .planning/audit/calc-first-architecture/expert-5-ux-voice-warmth.md
  - .planning/audit/calc-first-architecture/expert-6-compliance-swiss-brain.md
  - .planning/audit/calc-first-architecture/expert-7-production-reliability.md
---

# Calc-first MINT — LLM réduit à narrateur d'illumination

## TLDR

Le LLM ne calcule plus rien : `financial_core/` + arbitrage + Monte Carlo deviennent l'unique source de chiffres ; le narrateur écrit des templates avec placeholders cités (`{{cite:r3a_ceiling}}`) qu'un post-processor déterministe substitue, et toute génération libre d'un nombre est rejetée par un guard.

## Context

Stage 3 narrator eval (Phase 91, 2026-05-09, 50 fixtures × Haiku + Sonnet contre Anthropic API live) :

| Critère | Haiku 4.5 | Sonnet 4.5 | Ratio H/S |
|---|---|---|---|
| compliance | 34/50 | 30/50 | 1.13 |
| **doctrine (numbers_traceable + tools_first)** | **7/50** | **26/50** | **0.27** |
| banned_terms | 43/50 | 44/50 | 0.98 |
| anti_extractor_leak | 42/50 | 50/50 | 0.84 |
| calculator_grounded | 44/50 | 47/50 | 0.94 |
| **all_three_pass** | **5/50** | **21/50** | **0.24** |

Citation : `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison.md`.

Defect P0 marque : Haiku écrit `save_fact(key=incomeGrossYearly,value=80000,...)` et `<function_calls>` directement dans la réponse user-facing sur 8/13 fixtures `anti_extractor_leak` (Sonnet : 0/13). Sonnet est retenu par kill-policy ADR-20260419-v2.8 mais doctrine 26/50 reste un signal négatif fort sur la fiabilité narrateur en général.

Conclusion Julien (verbatim, 2026-05-09) :
> « le LLM doit être uniquement illumination des résultats pré-calculés, pas leur source. L'infra calc/arbitrage/simulator/algorithme/ML doit être complètement impeccable et un cran en avant du LLM. »

7 experts panel (read-only research + WebSearch ≥3× chacun, écrit dans `.planning/audit/calc-first-architecture/`) ont produit une convergence rare sur la direction et 6 axes d'action concrets.

## Decision

**Nous adoptons le pattern « calc-first + LLM illumination », à 4 niveaux :**

### N1 — Contrat narrateur fermé (closed-world numeric vocabulary)
Le narrateur n'écrit jamais un chiffre directement. Il écrit des placeholders `{{cite:<key>}}` (par exemple `{{cite:r3a_ceiling_2026}}`, `{{cite:user_avs_rente_low}}`). Un post-processor déterministe substitue le placeholder par la valeur calculée + lint qui rejette tout `\d+\s*(CHF|%|mois|ans|EUR)` non-cité.
> Source : Expert 3 — Anthropic Citations API (Endex hallucination 10%→0%).

### N2 — GroundingPack JSON par user-state
L'arbitrage_engine + monte_carlo_service émettent un `GroundingPack` JSON au narrateur : snapshot user + Pareto front N points + Sobol indices S1/ST + what-ifs précalculés + legal_constraints + credible intervals. Le narrateur lit, ne calcule pas.
> Source : Expert 4 — pattern QuantMCP (arxiv 2506.06622).

### N3 — Calc-rigor mécanique (3 axes)
3 nouveaux gates CI :
1. Différentiel Mobile↔Backend sur 200 fixtures gelées — toute divergence > tolérance bloque le merge.
2. Hypothesis property tests — 8 invariants (bornes, monotonicité, plafond couple, anticipation, arrondis).
3. ESTV oracle pin — 50 (input, expected) capturés depuis `swisstaxcalculator.estv.admin.ch`.
> Source : Expert 7 — Antithesis DST + Hypothesis PBT.

### N4 — UX warmth contract (NarrativeSleeve)
Le narrateur écrit dans un schéma `NarrativeSleeve {hook, caption, next_step, metaphor}` ; un linter interdit les nombres dans `hook` (ils vivent dans `caption`) et impose une métaphore par archetype × canton × event. Évite la dérive « Excel-with-voiceover ».
> Source : Expert 5 — Monarch behavioral analysis (Kristen Berman) + Wealthsimple voice principles.

### Mapping roadmap (proposé)

| Travail | Phase actuelle | Action proposée |
|---|---|---|
| N1 closed-world numeric vocabulary + LLM output guard | **94 MVP-CITATION-GATE** | Expansion (N1 + Expert 6 CalcTrace + AI_MODEL_REGISTRY) |
| N3 calc-rigor CI (différentiel + property + ESTV) | **nouveau 92.5 MVP-CALC-RIGOR-FOUNDATIONS** | Insertion (doit précéder 94, sinon 94 cite des chiffres non-vérifiés) |
| N2 GroundingPack data contract | **95 MVP-DAG-INVALIDATION** | Expansion (graph de dépendances → GroundingPack émis par DAG) |
| N4 NarrativeSleeve UX | **96 MVP-CHAT-AS-VERB** | Expansion (3-turn cap + sleeve linter + métaphores archetype/canton/event) |
| HMM regime-switching + CVaR + BVG mortality (Expert 1) | **backlog 999.x** | Carde-trier — 4-6 sem isolées, pas pré-TestFlight |
| Pareto NSGA-II multi-objectif (Expert 4) | **backlog 999.x** | Carde-trier — couplé à N2 mais peut être livré séparément |
| Compliance pivot lock-in (Expert 6) | **94 MVP-CITATION-GATE** | Inclus dans N1 (CalcTrace + AI registry + disclaimer LSFin systémique) |

**Cette décision implique de réécrire `91-VERIFICATION-REPORT.html` à la close-out de Phase 91 pour citer cette ADR comme « next milestone ».**

## Counter-arguments and data gaps

### What does the strongest opposing view say?

L'opposant le plus crédible : *« Sonnet fonctionne déjà à 21/50 = 42% qualité ; on ne devrait pas réarchitecturer un produit non-launched mais simplement améliorer le prompt. »* Le steel-man :

1. **Coût d'opportunité** : 6+ semaines de calc-rigor (N3) + DAG (N2) + linter (N1) + sleeve (N4) = report de TestFlight de 2-3 mois.
2. **Risque calculé** : Sonnet leak-rate 0/13 sur anti-extractor déjà acceptable. Le doctrine 26/50 vient peut-être de prompts trop longs (build_narrator_system_prompt ~30k chars) — un prompt plus dur (« interdiction d'écrire un nombre sans `<calc>...</calc>` tag ») suffirait peut-être.
3. **Cleo-différence** : Cleo a une chatbot personality forte qui camoufle les ratés (« roast me »). MINT n'a pas cette texture, donc ses ratés sont plus visibles, mais aussi plus durs à camoufler par sleeve.

Réponse au steel-man : la doctrine 26/50 = 48% ratés mécaniques sur les fixtures les plus simples. Un prompt-only fix peut amener à 60-70% mais ne ferme pas la borne supérieure (LLM peut toujours inventer). Le calc-first pivot est la seule architecture qui *ferme* la borne supérieure. Les 6 semaines sont incompressibles si on veut être journalist-defensible (RTS Mise au Point cite un chiffre faux = mort de marque).

### What does this source not address?

- **Pas de mesure live de l'impact UX** : on infère depuis Cleo / Monarch / Copilot.money mais on n'a pas testé un sleeve linter contre des users MINT réels.
- **Pas de coût quantifié** : 6 semaines en jours-homme estimées par les experts mais pas validé contre le calendrier Julien-solo.
- **Latence du post-processor** : Expert 3 cite « ≤+250ms p95 » comme budget mais aucun expert n'a mesuré la latence concrète d'un substitute Jinja-like sur Sonnet stream.
- **Pas de bench Mistral / Gemini / GPT-4o** : on a éliminé Haiku, retenu Sonnet par kill-policy. Si un autre modèle (Gemini 2.5 Pro, GPT-4o, Mistral Large) survit le 50-fixtures eval, le pivot calc-first est moins urgent. Cette question reste ouverte.

### What would change this conclusion?

- Si **un modèle alternatif** (Gemini, GPT-4o, Mistral) score ≥ 35/50 doctrine sur les mêmes 50 fixtures, on pourrait skip N1 + N4 et juste pinner ce modèle.
- Si **TestFlight P1** est requis sous 4 semaines (urgence presse / investor), on retient seulement N1 + N3 et reporte N2 + N4 en post-launch.
- Si **un user test pilote (≥10 utilisateurs MINT)** révèle que la voix Sonnet brute est jugée « assez bien » pour le P1, on accepte le risque numbers_traceable et on déplace N1 + N4 en backlog v3.0.

## Sources

- `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison.md` — Stage 3 eval mechanical results
- `.planning/audit/calc-first-architecture/expert-1-quant-actuarial.md` — HMM/CVaR + BVG mortality + 5 SST scenarios
- `.planning/audit/calc-first-architecture/expert-2-cleo-fintech-research.md` — Cleo 3.0 « deterministic tools do the math », Erica BoA, Klarna handoff
- `.planning/audit/calc-first-architecture/expert-3-llm-illumination-architecture.md` — closed-world vocabulary + Anthropic Citations API
- `.planning/audit/calc-first-architecture/expert-4-ml-arbitrage-optimization.md` — Sobol + Pareto NSGA-II + GroundingPack
- `.planning/audit/calc-first-architecture/expert-5-ux-voice-warmth.md` — NarrativeSleeve + métaphores + linter no-num-in-hook
- `.planning/audit/calc-first-architecture/expert-6-compliance-swiss-brain.md` — FINMA Guidance 08/2024 §III + ESMA 2024 + LSFin art. 3 let. c
- `.planning/audit/calc-first-architecture/expert-7-production-reliability.md` — Antithesis DST + Hypothesis PBT + ESTV oracle
- `decisions/ADR-20260419-v2.8-kill-policy.md` — Sonnet fallback contract
- `decisions/ADR-20260223-unified-financial-engine.md` — financial_core/ as source of truth (anchor existant)

## Status & follow-up

- **Status :** Proposed — awaits Julien confirmation pour roadmap injection (94 expansion + 92.5 insertion + 95/96 expansion + 999.x backlog).
- **Implementation tracking :** PRs to be opened per phase post-confirmation.
- **Re-litigation triggers :**
  - Modèle alternatif (Gemini/GPT-4o/Mistral) qui passe ≥ 35/50 doctrine sur le même 50-fixtures eval
  - TestFlight P1 requis < 4 semaines
  - User test pilote ≥10 users MINT révèle voix Sonnet brute « suffisante »
  - Audit légal externe (CHF 8-15k per Expert 6) qui contredit la lecture FINMA Guidance 08/2024

---
*Synthèse 7-experts panel — 2026-05-09 — Phase 91 close-out artifact.*
