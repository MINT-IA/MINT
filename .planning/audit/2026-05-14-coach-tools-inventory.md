---
description: Inventaire 28 backend coach tools + audit infra anti-hallucination existante (HallucinationDetector S34, CitationParser Phase 94, ComplianceGuard, bundles Phase 93.5) pour informer Wave 1a/1b/1c refined scope. Read-only audit, livrable Wave 0 Sub-Agent B.
name: 2026-05-14-coach-tools-inventory
type: audit
---

# 2026-05-14 — Coach Tools Inventory + Anti-Hallucination Infra Audit

## TLDR

Les 28 tools `COACH_TOOLS` se répartissent en 7 READ-numérique (Wave 1a cibles), 1 SEARCH (memory), 1 NAVIGATE (route_to_screen), 17 WRITE/READ-rendering. Tous les 7 READ numérique sont actuellement câblés sur `ctx`/CoachContext (data Flutter-injectée) — ZÉRO appel direct à un service Python backend ; c'est exactement le drift identifié par le design doc. L'infra anti-hallucination Wave 1b (NumericClaimExtractor + ToolUseTraceMatcher + Re-prompt loop + Honest fallback) existe déjà à **~85% câblée** sous d'autres noms (`HallucinationDetector` S34 + `citation_parser.gate` Phase 94 D-08..D-13 + `FALLBACK_TEMPLATED_TEXT` D-10 + 6 bundles Phase 93.5 avec `allowed_tools`/`citation_allowlist` + `narrative_sleeve_lint` D-16). Wave 1b doit donc être re-cadré en « wiring + extension » (build the missing 15%) plutôt qu'« build from scratch » — gain estimé ~5-8 jours réinvestissables Wave 2.

---

## Section 1 — Inventaire des 28 tools

Source unique : [coach_tools.py:126-1188](services/backend/app/services/coach/coach_tools.py). Handlers internes : [coach_chat.py:1871-2098](services/backend/app/api/v1/endpoints/coach_chat.py) (dispatcher) et [coach_chat.py:2249-2471](services/backend/app/api/v1/endpoints/coach_chat.py) (formatters).

Catégories code-internes : NAVIGATE / READ / WRITE / SEARCH (cf. `ToolCategory` enum [coach_tools.py:46-50](services/backend/app/services/coach/coach_tools.py)).

| # | Tool name | Category | Source actuel | Service cible Wave 1 (Python backend) | Risque halluc. num. | Wave 1a refactor ? |
|---|---|---|---|---|---|---|
| 1 | `show_fact_card` | READ (rendering) | Flutter widget (forwarded) | n/a (LLM-emit titre+content+source, pas de calcul) | LOW | N — pas de chiffrage interne |
| 2 | `show_budget_snapshot` | READ (rendering) | Flutter widget (forwarded) | n/a (Flutter récupère localement) | NONE — rendering only | N |
| 3 | `show_score_gauge` | READ (rendering) | Flutter widget (forwarded) | n/a (FRI score précomputé Flutter) | NONE | N |
| 4 | `ask_user_input` | READ (rendering) | Flutter widget (forwarded) | n/a (input chip) | NONE | N |
| 5 | **`retrieve_memories`** | SEARCH | INTERNAL — `_handle_retrieve_memories(topic, memory_block)` [coach_chat.py:1898-1910](services/backend/app/api/v1/endpoints/coach_chat.py) | `app.services.memory.*` (n'existe PAS encore — actuellement le `memory_block` est passé en argument depuis ProfileModel) | LOW (texte libre) | **Y — wire à un service mémoire formel** (BM25 / pgvector, cf. Karpathy wiki §user-profile) |
| 6 | `route_to_screen` | NAVIGATE | Flutter widget (forwarded) | n/a (RoutePlanner Flutter) | NONE | N |
| 7 | `set_goal` | WRITE | INTERNAL — ack only [coach_chat.py:1933-1936](services/backend/app/api/v1/endpoints/coach_chat.py) | `app.models.coach_insight.CoachInsightRecord` (v3.0 — actuellement ack-only string) | NONE | N (déjà ack) |
| 8 | `mark_step_completed` | WRITE | INTERNAL — ack only [coach_chat.py:1938-1941](services/backend/app/api/v1/endpoints/coach_chat.py) | CapSequence persistence (v3.0) | NONE | N |
| 9 | `save_insight` | WRITE | INTERNAL — DB persist [coach_chat.py:1943-2030](services/backend/app/api/v1/endpoints/coach_chat.py) (CoachInsightRecord) | déjà câblé `app.models.coach_insight` | NONE | N |
| 10 | `save_fact` | WRITE | INTERNAL (audit Wave E-PRIME) — ProfileModel.data write | déjà câblé via coach_chat.py:1337 | LOW (fact echo) | N |
| 11 | `suggest_actions` | READ (génère chips) | INTERNAL — coach_chat.py:1414 | déjà câblé (pas de chiffrage numérique direct) | LOW | N |
| 12 | **`get_budget_status`** | READ (numérique) | INTERNAL — `_format_budget_status(ctx)` [coach_chat.py:2249-2269](services/backend/app/api/v1/endpoints/coach_chat.py) lit `ctx["monthly_income"]`, `ctx["monthly_expenses"]`, `ctx["months_liquidity"]` (data injectée Flutter, jamais re-calculée backend) | **À créer côté backend** — pas d'équivalent direct. Options : (a) extension `app.services.coaching_engine.CoachingEngine` (pour computeFromProfile), (b) endpoint dédié `/budget/snapshot` qui lit `app.models.profile.ProfileModel` puis applique financial_core. | **HIGH** — chiffres CHF mensuels servis à LLM | **Y — recompute server-side** depuis profil persistant |
| 13 | **`get_retirement_projection`** | READ (numérique) | INTERNAL — `_format_retirement_projection(ctx)` [coach_chat.py:2272-2298](services/backend/app/api/v1/endpoints/coach_chat.py) lit `ctx["replacement_ratio"]`, `ctx["lpp_capital"]`, `ctx["avs_rente"]`, `ctx["monthly_retirement_income"]` (Flutter-injectée) | `app.services.retirement.avs_estimation_service.AvsEstimationService` + `app.services.retirement.lpp_conversion_service.LppConversionService` + `app.services.retirement.retirement_budget_service.RetirementBudgetService` ([retirement/*.py](services/backend/app/services/retirement/)) | **HIGH** — rente AVS/LPP, replacement ratio | **Y — server-side projection** |
| 14 | **`get_cross_pillar_analysis`** | READ (numérique) | INTERNAL — `_format_cross_pillar_analysis(ctx)` [coach_chat.py:2301-2327](services/backend/app/api/v1/endpoints/coach_chat.py) lit `ctx["annual_3a_contribution"]`, `ctx["lpp_buyback_max"]`, `ctx["tax_saving_potential"]` + appel `get_3a_ceiling()` | `app.services.arbitrage.allocation_annuelle.compare_allocation_annuelle` + `app.services.arbitrage.rachat_vs_marche` + `app.services.pillar_3a_deep.*` ([arbitrage/*.py](services/backend/app/services/arbitrage/), [pillar_3a_deep/*.py](services/backend/app/services/pillar_3a_deep/)) | **HIGH** — économie fiscale CHF, rachat max CHF | **Y — server-side cross-pillar** |
| 15 | **`get_cap_status`** | READ (numérique) | INTERNAL — `_format_cap_status(ctx)` [coach_chat.py:2330-2358](services/backend/app/api/v1/endpoints/coach_chat.py) lit `ctx["cap_headline"]`, `ctx["cap_cta"]`, `ctx["cap_expected_impact"]` (CapEngine Flutter-side, [coach_chat.py:503](services/backend/app/api/v1/endpoints/coach_chat.py) le confirme) | **N'existe PAS côté backend Python**. CapEngine est Flutter-only ([coach_chat.py:2332](services/backend/app/api/v1/endpoints/coach_chat.py): « Cap data comes from CapEngine on the Flutter side »). Wave 1a doit décider : port CapEngine → Python OU conserver Flutter-source + accepter le risque (texte cap, pas un chiffre central). | **MEDIUM** — `cap_expected_impact` peut contenir CHF | **Y partiel** — décision de port CapEngine, sinon ce tool reste READ-from-ctx avec doc explicite |
| 16 | **`get_couple_optimization`** | READ (numérique) | INTERNAL — `_format_couple_optimization(ctx)` [coach_chat.py:2361-2415](services/backend/app/api/v1/endpoints/coach_chat.py) lit `ctx["couple_optimization"]` (Flutter `CoupleOptimizer` pré-computé) | **N'existe PAS côté backend Python** (grep `couple_optim` → seul match : coach_chat.py + coach_tools.py). Options : (a) port `CoupleOptimizer` Flutter → Python service, (b) keep Flutter-source for v1, document risk. | **HIGH** — `saving_delta` CHF, `monthly_reduction` AVS CHF, `annual_delta` mariage CHF | **Y** — port-to-Python ou pin avec garde stricte |
| 17 | **`get_regulatory_constant`** | READ (numérique) | INTERNAL — `_handle_regulatory_constant(tool_input)` [coach_chat.py:2418-2471](services/backend/app/api/v1/endpoints/coach_chat.py) appelle `app.services.regulatory.registry.RegulatoryRegistry.instance().get(key, jurisdiction)` | **Déjà câblé correctement** ([registry.py](services/backend/app/services/regulatory/registry.py)) — c'est l'unique tool sur 7 qui appelle déjà un service backend canonique. | LOW (registry returns canonique + source + effective_from) | **N — already wired** (juste à confirmer dans la 5-gate Wave 1c) |
| 18 | `record_check_in` | WRITE | Flutter (forwarded) | n/a (mobile-side persistence) | LOW (sums versements user-supplied) | N |
| 19 | `generate_financial_plan` | WRITE | Flutter widget (forwarded) — calculators Flutter | financial_core Flutter (intentionnel — coach_tools.py:803 « calculators Flutter-side, NOT LLM ») | MEDIUM (LLM narrative seul, chiffres par calculators) | N (narrative-only) |
| 20 | `generate_document` | WRITE | Flutter widget (forwarded) | n/a | NONE | N |
| 21 | `record_commitment` | WRITE | INTERNAL — ack (P14) | déjà câblé (ack-only, persistence dédié) | NONE | N |
| 22 | `save_pre_mortem` | WRITE | INTERNAL — ack (P14) | déjà câblé | NONE | N |
| 23 | `save_provenance` | WRITE | INTERNAL — DB (P15) | déjà câblé | NONE | N |
| 24 | `save_earmark` | WRITE | INTERNAL — DB (P15) | déjà câblé | NONE | N |
| 25 | `remove_earmark` | WRITE | INTERNAL — DB (P15) | déjà câblé | NONE | N |
| 26 | `save_partner_estimate` | WRITE | Flutter widget (forwarded) — SecureStorage local | n/a (P16 by design — partner data stays on device) | NONE | N |
| 27 | `update_partner_estimate` | WRITE | Flutter widget (forwarded) — SecureStorage local | n/a | NONE | N |
| 28 | `show_commitment_card` | READ (rendering) | Flutter widget (forwarded) | n/a | NONE | N |

**Recap Wave 1a (7 cibles design doc) :**
- 6/7 confirmés `Y refactor obligatoire` : `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`, `retrieve_memories`.
- 1/7 (`get_regulatory_constant`) **déjà câblé** sur RegulatoryRegistry — ne nécessite que validation Wave 1c.
- 2/6 (`get_cap_status`, `get_couple_optimization`) **bloqués par absence de service Python équivalent** — décision d'arbitrage Wave 1a : port to Python ou keep Flutter-source.

**Tools secondaires à risque numérique non-listés Wave 1a (à surveiller Wave 2+) :**
- `show_fact_card` — `highlight_value` field accepte des chiffres LLM-générés. Faible volume mais peut bypasser la gate si pas dans la même string que `{{cite:<key>}}`.
- `generate_financial_plan` — `monthly_amount` est suggéré par LLM (cf. schema). Mitigation existante : « computed by calculators, NOT by the LLM » mais le `narrative` libre peut citer des chiffres.

---

## Section 2 — Audit infra anti-hallucination existante

Tous les modules sont sous [services/backend/app/services/coach/](services/backend/app/services/coach/). Statut codes : `active` = appelé par coach_chat.py / claude_coach_service.py ; `legacy` = remplacé par autre module ; `transition` = ship Wave/Phase N, wiring Phase N+1.

| Module | Rôle (1 phrase) | Lignes | Status | Gap identifié |
|---|---|---|---|---|
| **`HallucinationDetector`** ([hallucination_detector.py](services/backend/app/services/coach/hallucination_detector.py)) | Extrait nombres LLM (`CHF_PATTERN`, `PCT_PATTERN`, `DURATION_PATTERN`) puis compare contre `known_values` + whitelist constantes légales (`LEGAL_CONSTANTS_CHF` + `LEGAL_CONSTANTS_PCT`) avec tolérance `±5% CHF / ±2pts %`. | 274 | **active** (intégré dans `ComplianceGuard.validate` via `self._detector` [compliance_guard.py:353](services/backend/app/services/coach/compliance_guard.py)) | (a) `known_values` doit être préparé par le caller — pas de pipeline auto qui agrège les outputs des 6 READ tools de Section 1 vers ce dict. (b) Pas de mapping `tool_name → expected_value_key` — c'est précisément le ToolUseTraceMatcher manquant Wave 1b. |
| **`CitationParser`** (`citation_parser.gate(...)`, [citation_parser.py:524-710](services/backend/app/services/coach/citation_parser.py)) | Closed-world citation gate Phase 94 — 5 regex (currency / pct / legal / duration / regulatory), strip `{{cite:<key>}}` placeholders, vérifie adjacency-cited via `citation_allowlist`, retry hard-cap=1 (D-08), reprompt verbatim FR D-09/D-13, fallback verbatim FR D-10. | 734 | **active** (gated derrière `settings.COACH_CITATION_GATE_ENABLED` ; appelé `claude_coach_service.py:3445-3504` `_run_narrator_with_gate`) | Closed-world : exige clé dans CITATION_REGISTRY ([citation_registry.py:65-178](services/backend/app/services/coach/citation_registry.py), 18 clés v1 baseline). Pas de mapping numeric-claim → tool-name encore. P003 (2026-05-12) ajouté user-input exemption — couvre déjà les chiffres user-supplied. |
| **`CitationRegistry`** ([citation_registry.py](services/backend/app/services/coach/citation_registry.py)) | Frozen mapping `{key → CitationSource}` 18 entrées baseline (4 pillar3a / 4 lpp / 5 tax / 5 mortgage). 5 `source_kind` : `profile / reasoning / tool_call_id / adr / spec`. `resolve(key, ctx) → str` Wave 0 stub retourne `description_fr`. | 206 | **transition** (Phase 95 GroundingPack JSON contract va le remplacer) | `source_kind="tool_call_id"` jamais peuplée — c'est l'extension naturelle pour Wave 1b ToolUseTraceMatcher (clé → tool-name + tool-call hash). |
| **`CitationGrammar`** ([citation_grammar.py](services/backend/app/services/coach/citation_grammar.py)) | Compose FR doctrine fragment pour narrator system prompt — header + vocabulaire 18 clés + 3 exemples verbatim. `build_intent_scoped_citation_grammar(intents)` Phase 94.2 réduit la liste 18 → keys pertinentes à l'intent. | 399 | **active** (consumed par `CitationGrammarBundle` [bundle_compiler.py:205-207](services/backend/app/services/coach/bundle_compiler.py)) | Grammar côté prompt enseignée. Mais le mapping per-numeric-claim → tool-required reste à expliciter (« si tu cites 7'258, tu DOIS appeler `get_regulatory_constant(key='pillar3a.max_with_lpp')` ») — n'existe pas. |
| **`ComplianceGuard`** ([compliance_guard.py](services/backend/app/services/coach/compliance_guard.py)) | 5-layer pipeline : banned terms (`BANNED_TERMS` ~80 entries inflections + gerunds), prescriptive lang, hallucination via `HallucinationDetector`, disclaimer auto-injection, length limits. `validate(text, ctx, component_type) → ComplianceResult`. | 742 | **active** (legacy narrator path + new narrator path through `_run_narrator_with_gate`) | OK. Pas de gap propre — c'est l'orchestrateur Layer 3 qui consomme le detector. |
| **`DoctrineChecks`** ([doctrine_checks.py](services/backend/app/services/coach/doctrine_checks.py)) | 6 checks 0-100 score : numeric_anchor, concision, banned_terms, action_or_handoff, archetype_aware, escalation_aware. Wave 6.5 post-LLM eval. | 573 | **active** (eval-side : `tests/test_coach_doctrine_eval` et runtime warnings) | Eval scorer, pas un gate runtime. |
| **`NarrativeSleeveLint`** ([narrative_sleeve_lint.py](services/backend/app/services/coach/narrative_sleeve_lint.py)) | Phase 96 D-16 — `lint_sleeve(sleeve)` swap `hook` field si contient un digit, vers `HOOK_FALLBACK` verbatim FR. `_DIGIT_RE = re.compile(r"\d", re.UNICODE)` + SIGALRM 100ms budget anti-DoS. | 106 | **active** (chaîne middleware AFTER citation gate, BEFORE response serialization) | Très ciblé (hook field seulement). |
| **`GroundingPack`** ([grounding_pack.py](services/backend/app/services/coach/grounding_pack.py)) | Phase 95 DAG-INVALIDATION — JSON contract `ProjectionGroundingPack` avec `inputs_hash` SHA256, `entries: dict[str, GroundingPackEntry]`, `pareto_points` [3], `what_ifs` dict[5] (sensitivity), `legal_constraints`, `superseded_by` UUID. | 121 | **transition** (Phase 95 ship, Phase 96 wiring narrator templates) | Modèle data, pas un gate. C'est la « ground truth » pack que `citation_parser._substitute_placeholders` consommera. |
| **`BundleCompiler`** ([bundle_compiler.py](services/backend/app/services/coach/bundle_compiler.py)) | Phase 93.5 — `compile_bundles(intents, ctx, language) → CompiledBundle` (prompt + allowed_tools sorted-union + citation_allowlist sorted-union + activated_bundles + dropped). Token budget drop right-to-left. | 269 | **active** ([claude_coach_service.py:1131](services/backend/app/services/coach/claude_coach_service.py)) | OK. C'est l'orchestrateur prompt + per-request allow-list. |
| **6 bundles** [bundles/*.py](services/backend/app/services/coach/bundles/) | Doctrine fragments + `allowed_tools` + `citation_allowlist` par intent. Phase 93.5 D-09 always-on : `compliance_narrator`. Intent-driven : `lpp_projector`, `tax_explainer`, `mortgage_stressor`, `pillar3a_optimizer`, `life_event_router`. Phase 94 add : `citation_grammar`. | total ~600 | **active** | OK. Mais `allowed_tools` est statiquement déclaré — pas de mapping numeric-claim → tool-name dynamique. Cf. [lpp_projector.py:73-76](services/backend/app/services/coach/bundles/lpp_projector.py), [tax_explainer.py:69-72](services/backend/app/services/coach/bundles/tax_explainer.py), etc. |
| **`TurnCap`** ([turn_cap.py](services/backend/app/services/coach/turn_cap.py)) | Phase 96 D-08..D-11 — in-memory counter par `(session_id, source_card_id)` ; retourne `TURN_CAP_TERMINAL_TEMPLATE` verbatim FR à turn 4 sans LLM call. Mitigation T-96-W2-TurnCountTamper. | 128 | **active** | OK. Orthogonal anti-hallucination (anti-rabbit-hole). |
| **`Sensitivity`** ([sensitivity.py](services/backend/app/services/coach/sensitivity.py)) | Phase 95 D-11 — `compute_what_ifs(base_inputs, compute_fn)` uni-variate ±10% sur 5 PERTURB_KEYS, retourne 5 `GroundingPackEntry`. | 94 | **transition** (Phase 95 ship, Phase 96 W2 narrator wiring) | Pas un gate, c'est la data pour what-ifs grounding. |
| **`Pareto`** ([pareto.py](services/backend/app/services/coach/pareto.py)) | Phase 95 D-10 — 3-point scalarisation (fiscal_pure / liquidity_prioritized / ruin_reduction_prioritized) → 3 `ParetoPoint`. | 96 | **transition** | Idem sensitivity. |
| **`StalenessChecker`** ([staleness.py](services/backend/app/services/coach/staleness.py)) | Phase 95 DAG-03 — `staleness_high(stored_hash, current_hash) → bool`. Pure function. | 36 | **transition** (Phase 96 W2 wiring arbitrage_engine consumer) | Pas un gate runtime encore. |
| `FallbackTemplates` ([fallback_templates.py](services/backend/app/services/coach/fallback_templates.py)) | Deterministic FR templates personnalisés `CoachContext`-driven sans LLM call. | 157 | **active** | Fallback compliance-safe quand LLM rejeté. |

---

## Section 3 — Gap analysis Wave 1b (% déjà câblé)

Le design doc Wave 1b prévoyait 4 composants. Voici le mapping vers l'existant :

### 3.1 `NumericClaimExtractor` ≈ `HallucinationDetector` + `citation_parser` regex
- **Existant** : `HallucinationDetector.CHF_PATTERN` / `PCT_PATTERN` / `DURATION_PATTERN` / `PLAIN_NUMBER_PATTERN` ([hallucination_detector.py:45-57](services/backend/app/services/coach/hallucination_detector.py)) + 5 regex Phase 94 `_RE_CURRENCY` / `_RE_PERCENT` / `_RE_LEGAL_ARTICLE` / `_RE_DURATION` / `_RE_REGULATORY` ([citation_parser.py:68-91](services/backend/app/services/coach/citation_parser.py)).
- **État** : **95% câblé**. Les deux extracteurs cohabitent (S34 legacy + Phase 94 closed-world). Légère duplication mais robustes individuellement.
- **Gap résiduel** : convergence / dédup des deux familles regex si Wave 1b veut un extracteur unique. Optionnel : utiliser uniquement `citation_parser` regex (plus récents, Phase 94 D-02).

### 3.2 `ToolUseTraceMatcher` ≈ partiel (citation gate adjacent check + tool_use_id tracking)
- **Existant partiel** :
  - `citation_parser._has_adjacent_cite(response, s, e, allowlist)` vérifie présence `{{cite:<key>}}` dans fenêtre ±80 chars ([citation_parser.py:431+](services/backend/app/services/coach/citation_parser.py)).
  - Allowlist per-request dérivé `CompiledBundle.citation_allowlist` ([bundle_compiler.py:255-257](services/backend/app/services/coach/bundle_compiler.py)).
  - `CitationSource.source_kind="tool_call_id"` modèle existe ([citation_registry.py:54](services/backend/app/services/coach/citation_registry.py)) mais ZÉRO entrée actuellement utilise cette source_kind (les 18 baseline sont toutes `spec` ou `reasoning`).
- **État** : **40% câblé** (l'infra adjacency-check existe ; le mapping numeric-claim → tool-call-id n'est PAS construit).
- **Gap réel** : ajouter un registry runtime `{numeric_claim_pattern → (tool_name, key)}` qui, sur chaque match regex, vérifie qu'un `tool_use` block correspondant a été émis dans le tour. C'est le wiring concret de `source_kind="tool_call_id"` resté inutilisé.

### 3.3 `Re-prompt loop` ≈ `citation_parser.gate(is_retry=False/True)` D-08
- **Existant** : retry hard-cap=1 ([citation_parser.py:528-585](services/backend/app/services/coach/citation_parser.py)). Reprompt addendum verbatim FR D-09 `REPROMPT_ADDENDUM_UNCITED` + D-13 `REPROMPT_ADDENDUM_BANNED_CLAIM` ([citation_parser.py:132-242](services/backend/app/services/coach/citation_parser.py)). Wiring dans `_run_narrator_with_gate` ([claude_coach_service.py:3434-3504](services/backend/app/services/coach/claude_coach_service.py)).
- **État** : **100% câblé**.
- **Gap résiduel** : aucun. Hard-cap=1 est la décision projet (CONTEXT D-08).

### 3.4 `Honest fallback` ≈ `FALLBACK_TEMPLATED_TEXT` D-10
- **Existant** : verbatim FR string constant `FALLBACK_TEMPLATED_TEXT = "Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, dis-moi un peu plus sur ta situation..."` ([citation_parser.py:246-250](services/backend/app/services/coach/citation_parser.py)). Aussi `HOOK_FALLBACK` D-16 pour narrative sleeve hook ([narrative_sleeve_lint.py:43](services/backend/app/services/coach/narrative_sleeve_lint.py)). Aussi `TURN_CAP_TERMINAL_TEMPLATE` Phase 96 D-10 ([turn_cap.py:17-18](services/backend/app/services/coach/turn_cap.py)).
- **État** : **100% câblé**.
- **Note importante** : « Coach forced-tool-invocation pattern » (memory user) demande à ce qu'on n'utilise PAS ce fallback quand la donnée EXISTE dans le registry — il faut alors REJECT + re-prompt forcing tool call. Wave 1b doit s'assurer que le fallback ne se déclenche pas pour des chiffres récupérables via `get_regulatory_constant`.

### 3.5 Verdict global Wave 1b
**Wave 1b est ~85% déjà câblé**. Les 15% manquants sont :
1. **`source_kind="tool_call_id"` peuplée** : étendre `CITATION_REGISTRY` (ou GroundingPack Phase 95) avec entrées qui pointent vers un tool-name + nom-de-paramètre. Ex. `r3a_plafond_salarie_2026 → tool="get_regulatory_constant", key="pillar3a.max_with_lpp"`. ~1 jour.
2. **Mapping numeric-claim regex → required tool** : un dispatcher qui, sur match `_RE_CURRENCY` (ou `_RE_PERCENT`), vérifie si le numerique tombe dans la plage d'un registry entry → exige un `tool_use_id` matching dans le tour. ~2 jours.
3. **Eval data pipeline `known_values`** : actuellement `HallucinationDetector.detect(known_values)` est appelé avec un dict que personne ne peuple proprement à partir des 6 READ tools. Wave 1a (qui re-wire les 6 tools sur services Python) produit naturellement ce dict. ~0.5 jour additionnel quand 1a fini.

**Ratio build vs wiring restant** : ~3.5 jours build pur (component 1+2) + ~0.5 jour wiring trivial post-1a. **Build vs wiring : ~70% build / 30% wiring**, sur un scope global réduit ~75% par rapport au design initial.

---

## Section 4 — Recommandations Wave 1 refined scope

### Wave 1a — Re-wire 7 READ tools (effort refined)

| Tool | Service Python cible (confirmé) | Effort estimé (refined) | Note |
|---|---|---|---|
| `get_budget_status` | À créer : `app.services.coaching_engine.compute_budget_snapshot(profile_id)` ou endpoint dédié | 1.5j | Pas de service backend existant pour budget snapshot ; mais financial_core Flutter porte déjà la logique → port simple. |
| `get_retirement_projection` | `app.services.retirement.{avs_estimation_service, lpp_conversion_service, retirement_budget_service}` | 1.5j | Services existent déjà. Wave 1a = chainer les 3 + injecter `inputs_hash`. |
| `get_cross_pillar_analysis` | `app.services.arbitrage.allocation_annuelle.compare_allocation_annuelle` + `app.services.pillar_3a_deep.*` | 2j | Riche service backend déjà existant. Logique de dérivation `tax_saving_potential` à clarifier (provenance financial_core Flutter). |
| `get_cap_status` | **Decision needed Wave 1a** : (a) port `CapEngine` Flutter → Python service (3-5j), OR (b) keep Flutter source + document risk + ajouter garde « cap_expected_impact must not contain CHF without {{cite:}} » | 0.5j (option b) / 4j (option a) | Recommandation Claude : option b en Wave 1a, port différé Wave 2 (le cap impact est texte coaching, pas chiffre central). |
| `get_couple_optimization` | Idem : (a) port `CoupleOptimizer` Flutter → Python (3j), OR (b) keep Flutter + garde stricte | 0.5j (b) / 3j (a) | Recommandation Claude : option a (port to Python) car les 4 chiffres CHF émis sont sensibles. |
| `get_regulatory_constant` | **Déjà câblé** `app.services.regulatory.registry.RegulatoryRegistry` | 0j (juste tests Wave 1c) | RAS. |
| `retrieve_memories` | À formaliser : `app.services.memory.*` (n'existe pas) OU keep `_handle_retrieve_memories(memory_block)` wrapper sur ProfileModel | 1.5j | Karpathy wiki pattern (project_user_profile_wiki memory) : per-user pages, BM25/named links, pas chunk-and-embed. |

**Effort total Wave 1a refined** : **~10.5 jours** (avec recommandations CapEngine=Flutter / CoupleOptimizer=Python). Vs estimation initiale design doc « 1 semaine » → re-aligner.

### Wave 1b — Planner (re-scoped 85% câblé)

- **Build** : (1) extension CITATION_REGISTRY avec `source_kind="tool_call_id"` entries ~1j, (2) numeric-claim → required-tool dispatcher ~2j. **Total build ~3 jours.**
- **Wiring** : (3) connecter Wave 1a tool outputs vers `HallucinationDetector.known_values` dict ~0.5j.
- **Effort total Wave 1b refined** : **~3.5 jours** (vs design initial « 1.5 sem build » → gain ~5-7 jours).
- **Anti-pattern à éviter** : NE PAS reconstruire `NumericClaimExtractor` / `ToolUseTraceMatcher` from scratch en parallèle de l'existant — c'est du dead-code-en-double S34/Phase94. Étendre les modules en place.

### Wave 1c — Citation gate + parity tests

- **Déjà partiellement fait** : `narrative_sleeve_lint.lint_sleeve` est un gate runtime ; `citation_parser.gate` est un gate runtime ; `ComplianceGuard.validate` est un gate runtime ; `DoctrineChecks` est un eval scorer. Quatre gates fonctionnels.
- **À ajouter Wave 1c** :
  - Parity tests « pour chaque tool dans Wave 1a, l'output Flutter (legacy) === l'output Python (new) à ±0.01 CHF / ±0.1pt% » → ~2 jours
  - Add 5-gate verification ([feedback_perimeter_5_gates](memory)) : G1 sim walker / G2 device / G3 dev CI / G4 regression tests / G5 LSFin+accent+ARB lint
  - Backfill `CITATION_REGISTRY` avec entrées tool_call_id (cf. Wave 1b) ~inclus dans 1b
- **Effort Wave 1c refined** : ~2-3 jours.

### Tools secondaires READ-numérique à risque (Wave 2+)

Sur les 21 tools non-Wave-1a :
- **NAVIGATE/WRITE (rendering only)** : 16 tools — risque numérique NONE ou faible (chiffres user-supplied uniquement).
- **READ secondaires à surveiller** :
  - `show_fact_card.highlight_value` — string LLM-éditée pouvant contenir CHF/% sans `{{cite:}}`. Mitigation : déjà couvert par `citation_parser.gate` quand activé (closed-world).
  - `generate_financial_plan.narrative` — texte LLM libre, risque chiffrage. Le `monthly_amount` field est intentionnellement coach-suggested (cf. coach_tools.py:822). Mitigation existante : « computed by calculators » par contrat schema mais texte non gated.
  - `suggest_actions` — peut contenir des chiffres dans les suggestions (rare). Best-effort.
- **Sans risque numérique réel** : les 13 ack-only / Flutter-rendered tools (`set_goal`, `mark_step_completed`, `save_insight`, `save_fact`, `record_check_in`, `record_commitment`, `save_pre_mortem`, `save_provenance`, `save_earmark`, `remove_earmark`, `save_partner_estimate`, `update_partner_estimate`, `show_commitment_card`, `ask_user_input`, `show_score_gauge`, `show_budget_snapshot`, `route_to_screen`, `generate_document`).

---

## Section 7 — Caveats

Ce que je n'ai PAS pu vérifier en profondeur faute de temps / contrainte read-only :

1. **`claude_coach_service.py` (66KB, ~2000 lignes)** : lu uniquement les sections wiring (compile_bundles import, `_run_narrator_with_gate` 3434-3504, citation_parser import 65-66). N'ai pas lu :
   - Le `_classify_user_intent` et la dispatching logic ;
   - Le legacy narrator path complet pour confirmer que `ComplianceGuard.validate` est appelé sur 100% des sorties (cas BYOK off, anonymous path, etc.) ;
   - Le system prompt template `_BASE_SYSTEM_PROMPT` (pour vérifier qu'il enseigne déjà « invoque get_regulatory_constant si tu cites un chiffre légal » — partial cf. `citation_grammar.py` qui enseigne la grammaire mais pas la liaison numeric→tool).
2. **`coach_chat.py` (~3600 lignes)** : lu les sections dispatcher (1900-2030) et formatters (2249-2471). N'ai pas vérifié :
   - Le wiring `extract_user_input_numbers(body.message)` côté endpoint réel ;
   - Le passage `user_input_numbers=` à `citation_parser.gate` ;
   - Les eclatements logiques entre `coach_chat.py` (endpoint) et `claude_coach_service` (orchestrateur).
3. **Tests** : pas inspecté les fichiers `tests/test_citation_gate/`, `tests/bundles/`, `tests/test_coach_chat_persistence_gate.py`. La couverture réelle des regex et des gates est probablement détaillée mais je n'ai pas confirmé.
4. **Couple optimizer + CapEngine côté Flutter** : confirmé absents côté backend Python via grep ; n'ai pas inspecté le Flutter pour mesurer la complexité du port. Estimations (3-5j port CapEngine, 3j port CoupleOptimizer) sont des best-guess.
5. **GroundingPack consommateurs** : `pareto.py` / `sensitivity.py` / `bootstrap_ci.py` ship les entries mais le wiring vers `citation_parser._substitute_placeholders` est annoncé Phase 96. N'ai pas vérifié si Phase 96 est shippée ou encore in-flight (drift audit suggère Phase 95-96 en transition).
6. **`memory_block`** : passé en paramètre à `_handle_retrieve_memories` mais provenance pas suivie (sans doute construit dans `claude_coach_service.py` à partir de `CoachInsightRecord` DB + ProfileModel.data). Donc Wave 1a `retrieve_memories` refactor doit clarifier ce contract.
7. **`feature_flags`** : `COACH_CITATION_GATE_ENABLED` apparaît comme settings flag. État staging/prod actuel non vérifié — si OFF en prod, alors la gate Phase 94 ne tourne pas et le « 85% câblé » devient « 85% codé mais 0% effectif en prod ». À confirmer Wave 1a kickoff.

---

**Output produit par Sub-Agent B, Wave 0** — read-only audit, 0 modification source code. À consommer par Wave 1 design refinement avant kickoff Wave 1a.
