---
title: "Expert 4 — ML / Optimisation pour l'arbitrage et la simulation MINT"
role: Senior quantitative ML / optimisation expert (personal finance arbitrage, MC + sensitivity, decision-under-uncertainty)
mode: read-only research
date: 2026-05-09
status: Proposed
---

## TL;DR

L'engine MINT (`arbitrage_engine.dart`, `monte_carlo_service.dart`, `tornado_sensitivity_service.dart`) est solide sur le déterministe (Pillar-1/2/3a, taxe LIFD art. 38, conversion LPP, AVS art. 35) mais reste **scénario-flat** : il compare 3-4 trajectoires figées (full rente, full capital, mixte) au lieu d'**optimiser une politique**. Pour atteindre l'objectif Julien (« calc/arbitrage doivent être impeccables et un cran en avant du LLM »), trois leviers SOTA : (1) **stochastic dynamic programming / HJB** pour produire la politique optimale d'allocation/retrait par état (âge, wealth, risk-aversion) ; (2) **Pareto front multi-objectifs** (revenu médian × ruin-prob × bequest × tax-drag) au lieu d'un terminal-value scalaire ; (3) **Sobol global sensitivity** (via SALib) pour remplacer le tornado OAT qui rate les interactions taxe×rendement×inflation. La sortie ne doit plus être trois courbes mais un **« Q&A grounding pack »** : politique optimale par état, frontière Pareto annotée, contributions Sobol par variable, scénarios « what-if » pré-calculés. Le LLM n'invente plus, il narre.

---

## Q1 — ML / optimisation techniques qui amélioreraient matériellement MINT

### 1.1 État actuel (grounding par lecture des engines)

Lecture : `apps/mobile/lib/services/financial_core/arbitrage_engine.dart:74-200` (`compareRenteVsCapital`) et `apps/mobile/lib/services/financial_core/monte_carlo_service.dart:64-567` (`MonteCarloProjectionService.simulate`) + `tornado_sensitivity_service.dart:74-150`.

Ce qui est déjà bon :
- **MC sequence-of-returns** correctement modélisé (annual draws, calibration Pictet BVG-25 σ≈6.5%, equity σ=12%, inflation SNB μ=1%/σ=0.7%, lignes 130-160 de `monte_carlo_service.dart`).
- **Indexation AVS** propre (cumul `avsFactor[y]`, fix FIX-005 sur start-year).
- **Couple cap LAVS art. 35** + 13e rente correctement câblés (lignes 192-206).
- **Sensitivity** sur 4 leviers (rendement_capital, taux_retrait, tc_oblig, tc_surob) `arbitrage_engine.dart:206-332`.

Ce qui manque :
- **Politique d'allocation/retrait** : `arbitrage_engine` compare 3 stratégies pré-définies (full rente / full capital / 50-50 oblig-surob). Aucune optimisation sur la **séquence de retrait** (3a year-N puis LPP year-N+5 puis libre last) ni sur le **mix capital % continu** entre 0 et 100. La frontière efficiente n'est pas calculée.
- **Multi-objectifs scalarisés** : tout est ramené à un `terminalValue` ou un `revenuMensuelAt65`. Aucune notion de Pareto entre {revenu médian, ruin-prob, bequest héritiers, tax-drag, regret-vs-rente}.
- **Sensitivity OAT only** (`tornado_sensitivity_service.dart` + `arbitrage_engine.dart:_addTornadoSensitivity`). Rate les interactions (rendement × inflation, age × longévité, taux_retrait × σ-equity).
- **Pas de Bellman / dynamic programming** : chaque MC path est une politique fixe (SWR 4% constant, conversion-rate fixe), donc la simulation mesure le risque d'**une** stratégie au lieu de chercher la **stratégie optimale conditionnée à chaque état**.
- **Pas d'incertitude paramétrique** : les σ et μ sont calibrés en dur (P0-M1 audit). Aucun posterior bayésien sur les hypothèses, donc aucun moyen de propager « je suis plus/moins sûr de mon return assumption ».

### 1.2 Techniques SOTA classées par ROI MINT

| # | Technique | Gain MINT | Effort | Risque |
|---|---|---|---|---|
| 1 | **Sobol global SA (SALib)** remplace tornado OAT | Capture interactions ; ranking honnête des leviers | 2-3 j | Faible (lib mature, JOSS-publiée) |
| 2 | **Pareto front multi-objectifs (pymoo NSGA-II)** sur (rente_age, capital_pct, lpp_buyback_path, 3a_drawdown_order) | Frontière éducative : « voici les 7 stratégies non-dominées sur tes 4 objectifs » | 1-2 sem | Moyen (visualisation à concevoir) |
| 3 | **HJB / SDP discret** pour politique optimale conditionnée à wealth-state | Politique « si tu as X CHF à 64 ans, retire Y du 3a » au lieu de SWR fixe | 3-4 sem | Élevé (curse of dimensionality) |
| 4 | **Bayesian uncertainty propagation** (PyMC/numpyro) sur μ_lpp, σ_eq, inflation | Bandes p10-p90 honnêtes, intervalles de crédibilité sur ruin-prob | 2 sem | Moyen (calibration prior swiss) |
| 5 | **Distributional RL (FinRL / VD-MEAC)** pour rebalancing dynamique | Politique adaptative état-dépendante après la retraite | 4-6 sem | Élevé (interprétabilité, LSFin compliance) |
| 6 | **Scenario tree (recombining lattice)** pour 18 life-events | Frame chaque event comme branche probabiliste pricée → narrator parle de chaque branche | 2-3 sem | Moyen |

### 1.3 Recommandation lecture-prioritaire

**Niveau 1 (immédiat, 2-3 j)** : SALib + Pareto front. Les deux briques nourrissent le LLM avec des objets structurés (S1/ST indices ; frontière Pareto) qui n'existent pas encore. Le narrator passe d'un « il y a 3 options » à « voici quelles variables drivent réellement la décision et quelles stratégies sont non-dominées ».

**Niveau 2 (impact-mais-coûteux)** : HJB/SDP discret sur grille (age × wealth × annuitization-fraction). Permet de remplacer SWR 4% par une politique état-conditionnée (cf. Bellman lifecycle work, Rust 1989, Cocco-Gomes-Maenhout 2005). Reporté car effort >3 sem et risque d'explosion d'état pour 8 archetypes × 18 life events.

**Niveau 3 (à éviter pour MINT v2.x)** : Distributional RL post-retraite. Gain marginal vs SDP discret + énorme risque interprétabilité (FINMA / LSFin art. 7-10 demandent traçabilité). À reconsidérer post-Series-A si justifié.

---

## Q2 — Top SOTA implementations à copier

| Tool / Paper | URL | Takeaway 1-line |
|---|---|---|
| **SALib** (JOSS 2017, Saltelli sampling) | <https://github.com/SALib/SALib> | Drop-in Python lib, Sobol/Morris/FAST/PAWN ; Saltelli sampler N×(2D+2) suffit pour 4-8 inputs MINT (D=4 → 1024 samples × 1k MC = 1M, faisable backend) |
| **pymoo** (Blank-Deb 2020, NSGA-II/III) | <https://pymoo.org/> | Framework state-of-art pour Pareto multi-objectifs ; supporte contraintes (ex : LPP art. 79b 3-yr blockage) en natif via `Constraint` class |
| **FinRL** (AI4Finance) | <https://github.com/AI4Finance-Foundation/FinRL> | Bibliothèque RL finance open-source, PPO/A2C, sert de baseline si on va vers RL post-retraite (skip pour v2.x) |
| **QuantMCP** (arxiv 2506.06622, 2025) | <https://arxiv.org/abs/2506.06622> | Pattern direct pour MINT : LLM grounded par MCP tool calls retournant données financières structurées vérifiables — exactement le « Q&A grounding pack » que Julien demande |
| **Cocco-Gomes-Maenhout** (RFS 2005, lifecycle DP) | <https://academic.oup.com/rfs/article/18/2/491/1599892> | Référence académique pour la formulation Bellman lifecycle (consumption + portfolio + labor + housing) — base théorique du SDP MINT |
| **Habit Formation paper** (arxiv 2602.02816, 2026) | <https://arxiv.org/abs/2602.02816> | HJB variational inequality pour retirement + annuitization decisions sous habit formation — directement applicable au choix LPP rente vs capital |
| **VD-MEAC** (Frontiers 2025) | <https://www.frontiersin.org/articles/10.3389/frai.2025.1709493> | Distributional RL + max entropy pour portfolio mgmt — référence pour Niveau 3 (skip v2.x) |
| **Risk-Aware DRL** (arxiv 2511.11481) | <https://arxiv.org/html/2511.11481> | Reward Sharpe + max drawdown + vol caps — pattern pour reward design si on fait du RL |

**Top pick à porter en priorité** : **SALib pour Sobol** (1 jour de wrapping Python backend → expose `/api/v1/sensitivity/sobol`) puis **pymoo pour Pareto front** (3-5 jours). Ces deux ne demandent aucune révolution architecturale et nourrissent immédiatement le narrator avec des objets que le LLM ne sait pas inventer.

---

## Q3 — Quelle data structure l'engine doit-il émettre pour que « le LLM n'ait rien à inventer » ?

### 3.1 Le mauvais idéal — un graphe de décisions complet

Tentation : émettre un arbre de décisions ouvert (« si tu as 100k 3a et 800k LPP, fais X ; sinon Y »). Refusé : explosion combinatoire (8 archetypes × 18 events × 4 retirement ages × 3 capital splits × …) et chaque feuille devient une recommandation déguisée — collision avec **rule #4 (no-promise LSFin art. 7-10)** et **NEVER #8** (« ✅ Ne jamais promettre des rendements »).

### 3.2 Le bon idéal — un « Grounding Pack » par user-state

Inspiré du pattern QuantMCP (arxiv 2506.06622) et du « structural injection » (research.aimultiple.com context engineering). Une seule structure JSON, deterministically computed, que le LLM lit verbatim et narre. **Le LLM choisit le ton, jamais les chiffres.**

```jsonc
GroundingPack {
  // 1. État courant (snapshot calculé, pas inféré)
  "state": {
    "user_id_hash": "...",
    "as_of": "2026-05-09",
    "archetype": "expat_us_fatca",
    "age": 42,
    "horizon_years": 30,
    "wealth_state": { "lpp": 320000, "3a": 45000, "libre": 180000, "real_estate_net": 220000 }
  },

  // 2. Frontière Pareto (pymoo NSGA-II) — N stratégies NON-DOMINÉES
  "pareto_front": [
    {
      "id": "P1",
      "policy": { "retirement_age": 63, "capital_pct": 0.30, "rachat_lpp_per_year": 6800, "drawdown_order": ["3a","libre","lpp_capital"] },
      "objectives": { "median_income_chf": 6200, "ruin_prob": 0.18, "bequest_p50_chf": 80000, "tax_drag_lifetime": 145000, "regret_vs_full_rente": -8400 },
      "dominated_by": [],
      "regime_robustness": { "low_return": "p10=4200", "high_inflation": "p10=3850" }
    },
    // … 5 to 9 non-dominated points
  ],

  // 3. Sobol indices (SALib, S1 + ST) — quels leviers comptent réellement
  "sensitivity": {
    "method": "sobol_saltelli_n1024",
    "output_var": "median_income_at_67",
    "indices": [
      { "var": "lpp_return_mu",    "S1": 0.34, "ST": 0.41, "S1_conf95": 0.03 },
      { "var": "retirement_age",   "S1": 0.22, "ST": 0.29, "S1_conf95": 0.02 },
      { "var": "inflation_path",   "S1": 0.11, "ST": 0.18, "S1_conf95": 0.02 },
      { "var": "longevity",        "S1": 0.07, "ST": 0.09, "S1_conf95": 0.01 }
    ],
    "interaction_top": [{ "pair": ["lpp_return", "inflation"], "S2": 0.06 }]
  },

  // 4. MC bands annotated avec confidence
  "monte_carlo": {
    "num_paths": 1000,
    "median_at_67_chf": 6450,
    "p10_at_67_chf": 4280,
    "p90_at_67_chf": 8910,
    "ruin_probability": 0.14,
    "ruin_prob_credible_interval_95": [0.11, 0.18],  // Bayesian uncertainty propagation
    "calibration_sources": ["Pictet BVG-25 2000-2024", "SNB CPI 2010-2024"]
  },

  // 5. What-if pré-calculés (le LLM ne calcule pas)
  "what_ifs": [
    { "delta": "+1 year retirement", "median_income_delta_chf": +320, "ruin_prob_delta": -0.04 },
    { "delta": "rachat LPP 30k now", "median_income_delta_chf": +180, "tax_savings_chf": 7800, "blockage_until": "2029-05-09" }
  ],

  // 6. Constraints actives (LSFin / Swiss law) — pour que LLM les cite jamais ne les contourne
  "legal_constraints": [
    { "code": "LPP_ART_79B_3YR_BLOCKAGE", "active": true, "expires": "2027-08-12", "rachat_amount": 30000 },
    { "code": "OPP3_ART_3", "active": false }
  ],

  // 7. Confidence scoring (existing 4-axis)
  "confidence": {
    "completeness": 82, "accuracy": 76, "freshness": 95, "understanding": 60,
    "blocking_gaps": ["surobligatoire_split_inconnu", "conjoint_lpp_certificate_absent"]
  }
}
```

**Pourquoi ça verrouille le LLM** :

1. **Pareto front explicite** — le LLM ne peut pas suggérer une stratégie absente de la liste : elle est dominée. Il choisit le narratif (« tu privilégies P3 si bequest compte ») mais jamais le chiffre.
2. **Sobol indices** — le narrator ne peut plus dire « le rendement importe peu » : si S1=0.34, le ranking est mécanique. Anti-hallucination.
3. **What-ifs précalculés** — éliminent la tentation d'extrapoler. Le LLM lit `median_income_delta_chf: +320`, point.
4. **Legal_constraints citables** — chaque mention « blocage 3 ans LPP art. 79b » est sourçable au pack, pas hallucinée.
5. **Credible intervals** — la ruin-prob n'est plus « 14% » seul mais « 14% [11-18%] » (cf. Bayesian Methods in Finance, Jacquier-Polson 2011), forçant le narrator à parler en bandes.

### 3.3 Pourquoi pas un graphe / pas une time-series seule

- **Graphe de décisions** : explose en taille, nourrit overfitting LLM (« j'ai vu cette branche, je recommande »). Évacué.
- **Time-series annotée seule** : insuffisante car ne capture pas les arbitrages multi-objectifs ; le LLM doit reconstruire la décision → invente.
- **Q&A pack** combine les trois : snapshot d'état (statique) + frontière Pareto (décisions admissibles) + Sobol (drivers) + what-ifs (deltas) + contraintes (verrous). Le narrator devient un **lecteur** du pack, pas un calculateur.

---

## 3 propositions concrètes pour la roadmap MINT

### Proposition A — « SOBOL-FIRST » (P0, 2-3 jours, low risk)

**But** : remplacer (ou augmenter) le tornado OAT par un Sobol global qui capture les interactions.

**Files concernés** :
- `apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart` → garder pour visualisation rapide (UX), mais marquer `// PHASE-OUT post-Sobol`.
- `services/backend/app/services/` (à créer) `sensitivity/sobol_service.py` — wrap SALib.
- `services/backend/app/api/v1/endpoints/` (à créer) `sensitivity.py` — POST `/api/v1/sensitivity/sobol` ; retour JSON avec S1/ST/S2 + 95% CI.
- `services/backend/app/schemas/sensitivity.py` — Pydantic v2 camelCase.

**Algorithme** : Saltelli sample N=1024 sur D=8 inputs (lpp_mu, lpp_sigma, inflation_mu, equity_mu, equity_sigma, retirement_age, longevity, salary_growth) → run engine wrapper → SALib `sobol.analyze`.

**Gain narrator** : passe de « le rendement LPP est important (swing 12%) » à « S1=0.34, ST=0.41, donc 34% de la variance vient seul du rendement LPP, 7% des interactions avec inflation ». Honest et anti-hallucination.

**Counter-argument à acknowledge** : Saltelli demande O(N×(2D+2)) runs = 1024×18 = 18432 MC. Avec MC 1000-paths = 18M tirages. À 100µs/path c'est 30 min — donc backend-only, jamais sur device. Acceptable.

**Référence** : <https://salib.readthedocs.io/en/latest/user_guide/basics.html>

---

### Proposition B — « PARETO-NSGAII » (P1, 1-2 semaines, medium risk)

**But** : émettre 5-9 stratégies non-dominées au lieu de 3 fixes.

**Files concernés** :
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` (read-only, sert d'oracle scoring).
- `services/backend/app/services/arbitrage/` (existing) → ajout `pareto_optimizer.py`.
- `services/backend/app/services/arbitrage/arbitrage_models.py` → ajout `ParetoFrontPoint` schema (existing path).
- `services/backend/app/api/v1/endpoints/arbitrage.py` → nouveau POST `/arbitrage/pareto` qui retourne `ParetoFront[]`.

**Variables de décision** (pymoo `Problem.n_var`) :
- `retirement_age` ∈ [58, 70]
- `capital_pct` ∈ [0.0, 1.0]
- `rachat_lpp_per_year` ∈ [0, 50000] CHF
- `drawdown_order` ∈ {6 permutations de [3a, libre, lpp_capital]}

**Objectifs** (à minimiser) :
- −median_income_at_67
- ruin_probability
- −bequest_p50
- tax_drag_lifetime

**Contraintes** :
- LPP art. 79b 3-yr blockage (rachat → no capital w/d for 36 months)
- OPP3 max contribution (CHF 7258 employed / 35280 indep, 2026)
- 3a drawdown : 1 année par compte, max 2 comptes/an pour étalement

**Algorithme** : NSGA-II (pymoo) avec pop=80, gen=40 → 60s pour un user (acceptable async backend).

**Counter-argument** : Pareto avec 4 objectifs → frontière en 4D, dur à visualiser. Mitigation : projeter en 2D (revenu × ruin) avec couleur=bequest et taille=tax_drag, ou utiliser parallel coordinates.

**Référence** : <https://pymoo.org/getting_started/part_1.html> + Blank-Deb arxiv 2002.04504.

---

### Proposition C — « GROUNDING PACK » data contract (P0, 4-5 jours, structural)

**But** : matérialiser le `GroundingPack` (§3.2) comme contrat backend-LLM, *avant* d'investir dans HJB/RL.

**Files concernés** :
- `services/backend/app/schemas/grounding_pack.py` (à créer) — Pydantic v2.
- `services/backend/app/services/grounding/` (à créer) — `assembler.py` qui appelle :
  - `MonteCarloProjectionService` (port Dart→Python ou bridge isolate→backend),
  - `SobolService` (Prop A),
  - `ParetoOptimizer` (Prop B),
  - `ConfidenceScorer` (existing `apps/mobile/lib/services/financial_core/confidence_scorer.dart`).
- `services/backend/app/api/v1/endpoints/grounding.py` — GET `/api/v1/grounding-pack/{user_id}`.
- `apps/mobile/lib/services/coach/` (existing) — `coach_reasoner.dart` (line: `apps/mobile/lib/services/financial_core/coach_reasoner.dart`) — refactorer pour consommer `GroundingPack` au lieu de re-calculer côté client.

**Pattern narrator** : prompt système devient « Tu reçois un GroundingPack en JSON. Tu n'inventes AUCUN chiffre. Tu réfères toujours `pareto_front[i].id` ou `sensitivity.indices[j]`. Si pack absent → "je n'ai pas assez de données" ». Ré-aligne avec doctrine 7 (numbers_traceable) + 0-trust §9.

**Counter-argument** : duplication monte_carlo (Dart side `apps/mobile/lib/services/financial_core/monte_carlo_service.dart`, Python side à créer). Mitigation : single-source en Python backend, expose REST, Dart en lecture seule. Aligne avec rule #4 (financial_core SOT) mais **renverse** la SOT actuelle (Dart→Python). Décision à prendre par Julien : SOT côté backend Python plus testable, MC peut tourner sur device en lecture-cache.

**Référence pattern** : QuantMCP <https://arxiv.org/abs/2506.06622> + LLM grounding via MCP tools.

---

## Counter-argument principal — où l'over-engineering ML fait mal

> *« Toute brique ML/optimisation rajoutée doit survivre à 3 tests : maintenance 2 ans, audit FINMA/LSFin, dev qui hérite du code dans 6 mois. »*

### Interprétabilité (le vrai coût caché)

- **Distributional RL** (Niveau 3) : politique post-retraite output d'un actor-critic neural. **Aucun moyen de répondre** à « pourquoi tu retires 4200 CHF du 3a cette année ? ». LSFin art. 9 (information du client) demande explicabilité. Échec test FINMA potentiel. **À ne PAS implémenter v2.x**.
- **Bellman SDP discret** : politique state-action lisible (« si wealth ∈ [800k, 1M] et age=64 → retire 5% libre »). Interprétable, mais **curse of dimensionality** : pour 8 archetypes × 6 wealth-bins × 12 ages × 4 capital-splits = 2304 cellules de politique → matrices à versionner, calibrer, re-tester à chaque update LPP/AVS. Coût maintenance.
- **Pareto NSGA-II** : interprétable (chaque point = une politique paramétrique compacte). Plus simple à expliquer à un journaliste/régulateur que RL.
- **Sobol** : trivialement interprétable (S1 + ST avec CI). Aucun risque de boîte noire.

→ **Conclusion** : Pareto + Sobol passent les 3 tests. SDP marginal, RL non.

### Maintenance — recalibration drift

Chaque outil ML demande recalibration :
- **MC** : déjà calibré Pictet BVG-25 + SNB. Re-calibrer annuellement = 1 j ingénieur. OK.
- **Sobol** : pas de calibration (lit MC), juste recompute. OK.
- **Pareto** : recompute on-demand. OK.
- **SDP** : value-function à recompute pour chaque change (LPP conversion-rate, AVS reform 2026). 3-5 j chaque.
- **RL** : retraining pipeline + monitoring drift + safety-net. 1-2 sem trimestriellement.

→ **Coût annualisé MINT estimé** :
- Sobol+Pareto : ~10 j/an.
- + SDP : +20 j/an.
- + RL : +60 j/an + ML engineer dédié.

À 5 personnes équipe MINT v2.x, RL coûte ~25% d'un FTE. **Non**.

### Le piège overconfidence

Plus l'engine produit d'output « optimisé », plus le LLM (et l'utilisateur) pense que c'est « la bonne réponse ». L'arbitrage actuel (3 trajectoires, sensibilité tornado) est *bénéfiquement* simple : il dit « il y a 3 façons de voir, tu choisis ». Une frontière Pareto avec 7 points peut être perçue comme **plus** prescriptive (« le robot a calculé l'optimum »). Mitigation contractuelle : disclaimer fort + always-on regime_robustness column + S1/ST visibles → l'utilisateur voit « 41% du résultat dépend de ton return assumption », il sait que la réponse est conditionnelle.

→ **Garde-fou** : tout output ML doit afficher *au moins une* dimension d'incertitude (CI bayésienne ou ST Sobol). Sinon, faux confort.

---

## Data gaps & contre-arguments

### Data gaps
- **Calibration swiss-spécifique manquante pour Sobol** : ranges des inputs (lpp_mu ∈ [0.5%, 2.5%]?). À documenter dans `services/backend/app/services/sensitivity/calibration.py`.
- **Pareto contraintes archetype-spécifiques** : un FATCA-US ne peut pas contribuer 3a (existing flag `canContribute3a`). Le moteur Pareto doit consommer ces flags, pas les hardcoder.
- **Bayesian priors** : aucun prior swiss-specific sur μ_lpp publié (paper rare). Solution short-term : prior non-informatif + update via Pictet BVG-25 likelihood.

### Counter-arguments à mes propositions
1. **« Pareto front éduque mais ne décide pas »** : juste — c'est *un feature*, pas un bug, vu LSFin no-promise. Mais Julien doit accepter que la sortie devient « voici 7 options non-dominées » et pas « voici la meilleure ». Aligné rule #1 (banned « optimal »).
2. **« Sobol est lent »** : oui, 1024 MC × 1k paths = 1M sims. Solution : pre-compute par archetype × age-bucket × wealth-bucket → cache Redis 24h. Pas real-time, mais background-job.
3. **« GroundingPack est un nouveau contrat fragile »** : oui, schema breaking changes coûtent. Mitigation : Pydantic v2 + versioning explicite (`GroundingPack.schema_version = "v1"`) + contract tests Dart-side.

---

## Verification log

- Lecture engines : `apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (567 lignes), `arbitrage_engine.dart` lignes 1-350, `tornado_sensitivity_service.dart` lignes 1-150, `arbitrage_models.dart` lignes 1-80.
- WebSearch ×6 (MC OS, Bellman lifecycle, Sobol/OAT, Pareto, distributional RL, Bayesian robo + grounding pack).
- Citations ≥4 ✓ (SALib, pymoo, FinRL, QuantMCP, Cocco-Gomes-Maenhout, Habit Formation arxiv 2602.02816, VD-MEAC Frontiers 2025).
- Banned LSFin terms scan : aucun « garanti », « optimal » (sauf en citation banned-list), « meilleur », « certain », « assuré », « sans risque », « parfait » utilisé prescriptivement ✓.
- 0-trust : aucune affirmation « shipped » / « ready ». Tout est « proposed » / « to be implemented ».

## Sources

- [SALib GitHub](https://github.com/SALib/SALib)
- [SALib JOSS paper](https://www.theoj.org/joss-papers/joss.00097/10.21105.joss.00097.pdf)
- [pymoo](https://pymoo.org/) + [Blank-Deb arxiv 2002.04504](https://arxiv.org/pdf/2002.04504)
- [FinRL](https://github.com/AI4Finance-Foundation/FinRL)
- [QuantMCP — Grounding LLMs in Verifiable Financial Reality (arxiv 2506.06622)](https://arxiv.org/abs/2506.06622)
- [Habit Formation, Labor Supply, Retirement & Annuitization (arxiv 2602.02816)](https://arxiv.org/abs/2602.02816)
- [Behaviourally adaptive optimization for retirement wealth allocation, ScienceDirect 2025](https://www.sciencedirect.com/science/article/pii/S2468227625003436)
- [Bellman equation — Wikipedia](https://en.wikipedia.org/wiki/Bellman_equation)
- [Variance-based sensitivity analysis — Wikipedia](https://en.wikipedia.org/wiki/Variance-based_sensitivity_analysis)
- [Smart Tangency Portfolio — Deep RL for Dynamic Rebalancing (MDPI 2025)](https://www.mdpi.com/2227-7072/13/4/227)
- [Portfolio mgmt via value distribution RL (Frontiers AI 2025)](https://www.frontiersin.org/articles/10.3389/frai.2025.1709493/full)
- [Risk-Aware DRL for Dynamic Portfolio Optimization (arxiv 2511.11481)](https://arxiv.org/html/2511.11481)
- [Application of Bayesian Computation in Finance — pymc-labs](https://www.pymc-labs.com/blog-posts/bayesian-computation-in-finance)
- [Bayesian Methods in Finance — Jacquier & Polson 2011](https://people.bu.edu/jacquier/papers/bayesfinance.2011.pdf)
- [Robo-Advising: Learning Investors' Risk Preferences via Portfolio Choices (Oxford JFE 2021)](https://academic.oup.com/jfec/article-abstract/19/2/369/5695780)
