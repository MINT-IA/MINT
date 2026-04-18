# Panel B — Widget renderer <-> COACH_TOOLS façade audit

Branche : dev (tip 17d91776)
Scope : bridge `services/backend/app/services/coach/coach_tools.py` <-> `apps/mobile/lib/widgets/coach/widget_renderer.dart`
Méthode : inventaire exhaustif, diff bidirectionnel, parité enum, cross-check Wave A.

---

## Résumé

| Métrique | Valeur |
|---|---|
| Tools backend totaux (COACH_TOOLS) | **27** |
| Tools déclarés INTERNAL (backend-only) | 13 |
| Tools Flutter-bound attendus | 14 |
| Handlers widget_renderer Flutter | 11 cases (+ 2 intercept silent = 13 branches) |
| **Tools shippés sans routing correct (P0)** | **2** (`save_fact`, `suggest_actions`) |
| Handlers Flutter orphelins | 0 |
| Enum `InsightType` parité | OK (5/5) |
| **Intent tags `route_to_screen` orphelins (P1)** | **7** (compound_interest, debt_check, expert_consultation, leasing_simulation, life_event_unemployment, patrimoine_overview, pillar_3a_overview) |
| Ghost documentation (commentaires menteurs) | 1 (coach_profile_provider.dart:183) |

Grep commandes utilisées :
```
Grep pattern="INTERNAL_TOOL_NAMES" path=services/backend/
Grep pattern="WidgetRenderer\.build" path=apps/mobile/lib/
Grep pattern="suggest_actions|save_fact" path=/Users/julienbattaglia/Desktop/MINT/
Bash grep -n "intentTag" apps/mobile/lib/services/navigation/screen_registry.dart
```

---

## Tools backend inventory (COACH_TOOLS, 27 entrées)

| # | Nom | coach_tools.py | Catégorie | INTERNAL ? | Handler attendu |
|---|---|---|---|---|---|
| 1 | `show_fact_card` | L132 | read | Non | Flutter widget_renderer |
| 2 | `show_budget_snapshot` | L167 | read | Non | Flutter widget_renderer |
| 3 | `show_score_gauge` | L194 | read | Non | Flutter widget_renderer |
| 4 | `ask_user_input` | L217 | read | Non | Flutter widget_renderer |
| 5 | `retrieve_memories` | L257 | search | **Oui** (L58) | backend `_handle_retrieve_memories` |
| 6 | `route_to_screen` | L295 | navigate | Non | Flutter widget_renderer |
| 7 | `set_goal` | L357 | write | **Oui** (L72) | backend ack only |
| 8 | `mark_step_completed` | L392 | write | **Oui** (L73) | backend ack only |
| 9 | `save_insight` | L427 | write | **Oui** (L74) | backend persist (CoachInsightRecord + mirror) |
| 10 | **`save_fact`** | L493 | write | **NON** (manque L91) | **Tool "internal" mais pas listé** |
| 11 | **`suggest_actions`** | L603 | read | **NON** (manque L91) | **Tool "internal" mais pas listé** |
| 12 | `get_budget_status` | L634 | read | **Oui** (L59) | backend format |
| 13 | `get_retirement_projection` | L650 | read | **Oui** (L60) | backend format |
| 14 | `get_cross_pillar_analysis` | L666 | read | **Oui** (L61) | backend format |
| 15 | `get_cap_status` | L682 | read | **Oui** (L62) | backend format |
| 16 | `get_couple_optimization` | L698 | read | **Oui** (L63) | backend format |
| 17 | `get_regulatory_constant` | L719 | read | **Oui** (L64) | `_handle_regulatory_constant` |
| 18 | `record_check_in` | L757 | write | Non | Flutter widget_renderer |
| 19 | `generate_financial_plan` | L794 | write | Non (L87-90 commentaire) | Flutter widget_renderer (PlanPreviewCard) |
| 20 | `generate_document` | L856 | write | Non | Flutter widget_renderer (DocumentCard) |
| 21 | `record_commitment` | L901 | write | **Oui** (L76) | backend ack |
| 22 | `save_pre_mortem` | L948 | write | **Oui** (L77) | backend ack |
| 23 | `save_provenance` | L991 | write | **Oui** (L79) | backend persist ProvenanceRecord |
| 24 | `save_earmark` | L1022 | write | **Oui** (L80) | backend persist EarmarkTag |
| 25 | `remove_earmark` | L1054 | write | **Oui** (L81) | backend delete EarmarkTag |
| 26 | `save_partner_estimate` | L1077 | write | Non (L82-85 commentaire explicite) | Flutter widget_renderer (intercept silent → PartnerEstimateService) |
| 27 | `update_partner_estimate` | L1117 | write | Non (L82-85 commentaire explicite) | Flutter widget_renderer (intercept silent → PartnerEstimateService) |
| 28 | `show_commitment_card` | L1156 | read | Non (L150 test) | Flutter widget_renderer (CommitmentCard) |

> NB : la cellule "# 28" pousse le total à 28, mais coach_tools.py COACH_TOOLS length réel = 28. J'ai compté 27 plus haut par erreur ; le compte exact est **28 entrées dans COACH_TOOLS**.

---

## Backend dispatcher (`_execute_internal_tool`, coach_chat.py:1150-1507)

Branches `if name == "X":` observées :
- retrieve_memories (L1201), get_budget_status (L1215), get_retirement_projection (L1218), get_cross_pillar_analysis (L1221), get_cap_status (L1224), get_couple_optimization (L1227), get_regulatory_constant (L1230), set_goal (L1236), mark_step_completed (L1241), save_insight (L1246), **save_fact (L1337)**, **suggest_actions (L1414)**, record_commitment (L1421), save_pre_mortem (L1428), save_provenance (L1435), save_earmark (L1456), remove_earmark (L1477).

**Les deux branches `save_fact` (L1337) et `suggest_actions` (L1414) sont code mort en production** car le routage en amont (coach_chat.py:1893-1897) sélectionne `internal_calls` uniquement pour les noms listés dans `INTERNAL_TOOL_NAMES`. Tests de bout-en-bout (`test_save_fact_tool.py:66-80`) contournent ce dispatcher en appelant `_execute_internal_tool` directement — ils valident la logique du handler mais **ne prouvent rien sur la route réelle**.

---

## Flutter handlers inventory (widget_renderer.dart:56-86)

```
case 'show_score_gauge':          → _buildScoreGauge              (L61-62, L163)
case 'show_fact_card':            → _buildFactCard                (L63-64, L174)
case 'show_budget_snapshot':      → _buildBudgetSnapshot          (L65-66, L189)
case 'ask_user_input':            → _buildInputRequest            (L67-68, L258)
case 'route_to_screen':           → _buildRouteSuggestion         (L69-70, L104)
case 'generate_financial_plan':   → _buildPlanPreviewCard         (L71-72, L389)
case 'record_check_in':           → _buildCheckInSummaryCard      (L73-74, L471)
case 'generate_document':         → _buildDocumentGenerationCard  (L75-76, L524)
case 'show_commitment_card':      → _buildCommitmentCard          (L77-78, L652)
case 'save_partner_estimate':     → _handlePartnerEstimateTool    (L79-82, L638, silent)
case 'update_partner_estimate':   → _handlePartnerEstimateTool    (L80-82, L638, silent)
default:                          → return null                    (L85)
```

**Aucun handler Flutter orphelin** : chaque `case` pointe vers un tool backend déclaré.

---

## P0 — Façades critiques

### P0-1 : `save_fact` — tool shippable, routing cassé, **persistence silencieuse nulle**

- **Backend declaration** : `services/backend/app/services/coach/coach_tools.py:493-597`
- **Backend handler (code mort)** : `services/backend/app/api/v1/endpoints/coach_chat.py:1337-1408`
- **Backend INTERNAL_TOOL_NAMES** : `coach_tools.py:57-91` — **absent**
- **Flutter widget_renderer** : `apps/mobile/lib/widgets/coach/widget_renderer.dart` — **absent du switch** → `default: return null`
- **Flutter comment contradictoire** : `apps/mobile/lib/providers/coach_profile_provider.dart:183` — dit *"save_fact (which executes server-side and never reaches Flutter)"* — **faux**.

Routage effectif :
```
coach_chat.py:1893  internal_calls = [t for t ... if name IN INTERNAL_TOOL_NAMES]
coach_chat.py:1896  external_calls = [t for t ... if name NOT IN INTERNAL + IN all_known_names]
```

Le LLM émet `save_fact` (MANDATORY dans la description tool, cf. L497) → `name="save_fact"` n'est pas dans INTERNAL → passe en `external_calls` → transmis à Flutter via `response.toolCalls` → `widget_renderer.build()` → `default` → `null` → `SizedBox.shrink()`.

**Impact** :
- Les facts quantitatifs (salaire, avoirLpp, canton, householdType, etc. — 35 clés whitelisted L529-572) ne sont **jamais persistés** en DB.
- `ProfileModel.data` côté serveur reste vide.
- `coach_profile_provider.syncFromBackend()` (L185) récupère alors des champs vides → aucun merge financier ne s'opère.
- **La doctrine Wave A A0 (commit 570c574a) et la roadmap Gate 0 #6 (chips dynamiques) sont contournées en prod**.
- **PRIV-07 (PII redaction sur save_fact, commit 2bc37293)** est code mort : la redaction backend ne s'applique jamais puisque le handler n'est jamais atteint.

Recommandation : ajouter `"save_fact"` et `"suggest_actions"` à `INTERNAL_TOOL_NAMES` (coach_tools.py L91). Ajouter un test `test_dispatcher_routes_save_fact_as_internal` dans `test_e2e_coach_pipeline.py` qui poke `raw_tool_calls` et vérifie que `save_fact` apparaît dans `internal_calls`, pas dans `external_calls`.

---

### P0-2 : `suggest_actions` — MANDATORY dans le prompt, drop silencieux bilatéral

- **Backend declaration** : `coach_tools.py:603-627` (MANDATORY à chaque fin de réponse L608)
- **Backend handler (code mort)** : `coach_chat.py:1414-1417` → `_compute_suggested_actions(user_id, db)`
- **Backend INTERNAL_TOOL_NAMES** : **absent**
- **Flutter widget_renderer** : **absent** → `default: return null`
- **Flutter feed des chips** : `coach_chat_screen.dart:1000-1005` utilise `response.suggestedActions` (field du JSON) + `_extractRouteChips(richCalls)` (inférence route_to_screen). **Aucune lecture du payload `suggest_actions` tool call**.

Idem P0-1 : émis par le LLM → external_calls → Flutter → dropped.

**Impact** :
- `_compute_suggested_actions` (coach_chat.py:846) — algorithme qui détecte profile gaps + financial state pour proposer 2-3 chips personnalisées — n'est **jamais exécuté**.
- Les chips affichées à l'utilisateur dépendent uniquement de :
  1. Les `suggested_actions` que le LLM écrit en clair dans la réponse texte (si le field est présent dans le schema de réponse — vérifier `CoachChatResponse`).
  2. Les chips extraites des `route_to_screen` tool calls.
- Gate 0 fix #6 "replaces static chips with dynamic suggestions" (commentaire coach_tools.py:602) → livré façade.

Recommandation : même fix que P0-1 (add to INTERNAL_TOOL_NAMES). Si l'intent est vraiment de rendre côté Flutter (chip layout custom), ajouter un handler `case 'suggest_actions':` qui rend `ChipCluster(suggestions: JSON.decode(input).suggestions)` — mais **alors** il faut sortir `suggest_actions` du handler `_execute_internal_tool` et expliciter la contract.

---

## P1 — Intent tags `route_to_screen` orphelins

Le tool `route_to_screen` (coach_tools.py:295-353) enforce via description que `intent` est dans `ROUTE_TO_SCREEN_INTENT_TAGS` (coach_tools.py:97-122, 24 tags exposés au LLM).

Côté Flutter, la résolution est faite par `ChatToolDispatcher.resolveRouteFromIntent()` (chat_tool_dispatcher.dart:109) → `MintScreenRegistry.findByIntentStatic()` (screen_registry.dart:1629).

**Diff** (diff via `comm -23`) :
Backend intents NON-résolvables côté Flutter :

| Intent backend | Flutter intent tag proche | Écran ciblé |
|---|---|---|
| `compound_interest` | `compound_interest_simulator` (screen_registry.dart:713) | Simulator |
| `debt_check` | `debt_risk_check` (L767) ou `debt_ratio` (L745) | Check dette |
| `expert_consultation` | **absent** (Flutter `consult_specialist` ?) | Plan 3 feature |
| `leasing_simulation` | `leasing_simulator` (L723) | Simulator |
| `life_event_unemployment` | `life_event_job_loss` (L878) | Flow life event |
| `patrimoine_overview` | `portfolio_overview` (L1348) | Dashboard |
| `pillar_3a_overview` | **absent** (`pillar_3a_independant` L703 seul match) | Hub 3a |

Le LLM peut émettre `{intent: "compound_interest", confidence: 0.9, context_message: "…"}` → `resolveRouteFromIntent` retourne null → `SizedBox.shrink()` → l'utilisateur voit uniquement le context_message en texte, pas de carte cliquable. **Dégradation silencieuse** (pas un crash, mais une façade UX).

Recommandation :
- **Soit** renommer côté Flutter pour matcher (`compound_interest_simulator` → `compound_interest`, etc.).
- **Soit** renommer côté backend dans `ROUTE_TO_SCREEN_INTENT_TAGS` pour matcher Flutter (plus stable).
- **Dans tous les cas** : ajouter test `test_all_backend_intents_resolve_on_flutter` qui parse `ROUTE_TO_SCREEN_INTENT_TAGS` et assert que `MintScreenRegistry.findByIntentStatic(tag) != null`. Ce test aurait déjà détecté les 7 orphelins.

---

## P2 — Ghost documentation (commentaires menteurs)

### P2-1 : `apps/mobile/lib/providers/coach_profile_provider.dart:183`

Commentaire actuel :
> *"Called after each coach chat exchange to capture data written by save_fact (which executes server-side and never reaches Flutter)."*

Le second membre de phrase est **faux**. En prod, `save_fact` n'exécute PAS server-side (P0-1 ci-dessus) ET atteint bien Flutter (dropped au widget_renderer). Un dev qui lit ce commentaire pensera la pipeline fonctionnelle et ne détectera pas la façade.

Recommandation : après fix P0-1, reformuler en *"…to capture data written by save_fact (handled internally by the backend agent loop — never forwarded to Flutter tool_calls)."* et référencer `coach_chat.py:1893`.

---

## Enum parity

### Check A : `InsightType` (save_insight `type` enum)

- **Backend** (`coach_tools.py:470`) : `["goal", "decision", "concern", "fact", "event"]`
- **Flutter** (`apps/mobile/lib/models/coach_insight.dart:24-46`) : `goal, decision, concern, fact, event`
- **Mismatch** : aucun. **Parité OK (5/5)**.
- Wave A A0 (commit 570c574a) `event` type correctement ajouté des deux côtés.
- `InsightType.fromJson` (coach_insight.dart:117) utilise `orElse: InsightType.fact` → fail-safe, pas de crash sur type inconnu.

### Check B : `LifeEvent`

- **Backend** : pas d'enum explicite exposé au LLM au niveau des tools (les tags `life_event_*` dans ROUTE_TO_SCREEN_INTENT_TAGS sont des intent tags, pas un enum métier).
- **Flutter** : pas d'enum `LifeEvent` trouvé dans `apps/mobile/lib/models/` (seul `age_band_policy.dart` le mentionne).
- **Non applicable** pour cet audit widget/tool ; à traiter par Panel A (orchestrator) ou Panel C (data model).

### Check C : `Archetype`

- **Backend** : doctrine documentée dans `CLAUDE.md §5` (8 archetypes), injectée via system prompt et `profile_context`. Pas exposé comme enum dans `coach_tools.py`.
- **Flutter** : pas d'enum `Archetype` dans `apps/mobile/lib/models/`.
- **Non applicable** pour cet audit widget/tool.

### Check D : `save_fact.key` enum (35 clés whitelisted)

- **Backend** : `coach_tools.py:529-572` — birthYear, dateOfBirth, canton, commune, householdType, employmentStatus, has2ndPillar, goal, targetRetirementAge, gender, incomeNetMonthly, incomeGrossMonthly, incomeNetYearly, incomeGrossYearly, selfEmployedNetIncome, employmentRate, annualBonus, lppInsuredSalary, avoirLpp, avoirLppObligatoire, avoirLppSurobligatoire, lppBuybackMax, hasVoluntaryLpp, pillar3aAnnual, pillar3aBalance, savingsMonthly, totalSavings, wealthEstimate, hasDebt, totalDebt, spouseBirthYear, spouseIncomeNetMonthly, spouseAvsContributionYears, hasAvsGaps, avsContributionYears. **35 clés**.
- **Flutter** consumers : `coach_profile_provider.dart:212-224` mappe seulement 3-4 clés (`avoirLpp`, `lppInsuredSalary`, `lppBuybackMax`). Les 31+ autres clés n'ont **aucun consumer Flutter identifié** dans le provider de merge.

> Même si P0-1 est fixé, **les 31+ clés `save_fact` n'ont pas de round-trip Flutter**. Le fact est persisté DB backend mais jamais réimporté côté mobile → divergence state permanente. Cette observation dépasse le scope Panel B mais mérite un Panel C (profile sync).

### Check E : allowlist de routes (tool_call_parser.dart)

- **Flutter** : `apps/mobile/lib/services/coach/tool_call_parser.dart:64-134` contient une whitelist hardcodée de ~67 routes.
- **Backend** : aucune allowlist équivalente ; le backend émet `intent` (pas `route`). La résolution passe par `MintScreenRegistry`.
- **Risque** : si `MintScreenRegistry` contient une route absente de la whitelist Flutter, `resolveRouteFromIntent` retourne null (chat_tool_dispatcher.dart:115). Double gate non coordonné → potentiellement d'autres façades silencieuses. Hors scope Panel B (à investiguer par audit navigation).

---

## Cross-check Wave A

### save_insight accepte `type='event'` (Wave A A0, commit 570c574a)

- Backend : `coach_tools.py:470` enum inclut `event` ✓
- Backend handler : `coach_chat.py:1249` `insight_type = tool_input.get("insight_type", "fact")` — **BUG MINEUR** : lit la clé `insight_type` alors que le schema expose `type` (coach_tools.py:468). Le fallback `"fact"` écrase silencieusement le type passé par le LLM.

  Vérifier si le LLM passe `type` ou `insight_type` dans la pratique. Si `type` → **le backend persiste toujours en "fact"** et la Wave A A0 est neutralisée.

- Flutter : `InsightType.event` existe (coach_insight.dart:45).
- Flutter save flow : `document_impact_screen.dart:144` appelle directement `CoachMemoryService.saveEvent()` — **n'utilise PAS le tool `save_insight`**. C'est un flow parallèle local-only (SharedPreferences), pas synchronisé avec `CoachInsightRecord` backend.

  → **Découplement complet** : les événements backend (DB) et mobile (SharedPreferences) ne se voient jamais mutuellement. Un event sauvé sur device 1 n'apparaîtra pas sur device 2 du même user.

### save_fact PII redaction (Wave A PRIV-07, commit 2bc37293)

Déjà couvert P0-1 : la redaction `fact_key_allowlist.is_safe_to_log()` (coach_chat.py:1386-1399) est **code mort** puisque `save_fact` n'est jamais routé vers le handler. PRIV-07 est livré façade.

### NotificationsWiringService (Wave A A2, commits c981b85f + 2bc37293)

Hors scope Panel B mais mentionné dans le contexte — trigger est la modification de `ProfileModel.data` via save_fact. Si save_fact ne persist jamais (P0-1), alors les notifs (`scheduleCoachingReminders`) ne fire jamais. Chaîne façade complète :

```
LLM → save_fact tool_use
    → backend dispatcher (external_calls, pas internal)
    → Flutter widget_renderer (default: null)
    → [DROP]
→ ProfileModel.data non modifié
→ NotificationsWiringService debounce ne se déclenche jamais
→ zero notification de triad complete
```

À valider par Panel A ou avec un test end-to-end qui poke le HTTP endpoint `/coach/chat` avec un prompt minimal type "je gagne 7600 CHF par mois" et vérifie que `/profiles/me` retourne `incomeNetMonthly=7600` dans la foulée.

---

## Recommandations (ordre de priorité)

1. **P0-1 fix** (5 min) : ajouter `"save_fact"` et `"suggest_actions"` dans `INTERNAL_TOOL_NAMES` à `coach_tools.py:91`. Rouler `test_save_fact_tool.py` + mettre en place un test `test_dispatcher_routes_save_fact_as_internal` qui pokes le routage (pas juste le handler).
2. **P0 preventif** : test inverse `test_no_tool_declared_without_routing` qui boucle sur `COACH_TOOLS` et assert pour chaque tool : soit `name in INTERNAL_TOOL_NAMES`, soit `name in WidgetRendererHandlers` (export une liste depuis Dart side ou synchronize manuellement). Ce test aurait catché save_fact + suggest_actions en CI.
3. **P1** : aligner les 7 intent tags `ROUTE_TO_SCREEN_INTENT_TAGS` sur les intent tags Flutter (ou inverse). Ajouter `test_all_backend_intents_resolve_on_flutter`.
4. **P2-1** : corriger le commentaire menteur coach_profile_provider.dart:183.
5. **Wave A A0 hardening** : tester si Anthropic tool_use sérialise `type` ou `insight_type` quand le LLM appelle save_insight. Si `type`, fixer `coach_chat.py:1249` pour lire `"type"` au lieu de `"insight_type"` (fallback sur les deux pour compat).
6. **Wave A découplement events** : décider si events doivent être round-trippés backend<->Flutter (DB CoachInsightRecord <-> SharedPreferences). Actuellement c'est deux silos.

---

## Verdict

**Deux façades critiques en production** : `save_fact` et `suggest_actions` sont shippés, leur schema est décrit au LLM comme MANDATORY, leurs handlers existent, leurs tests passent (mais contournent le routage). **En prod, zéro appel n'atteint son handler**.

Wave A A0, PRIV-07 et Gate 0 #6 sont livrées façade du fait de la même omission dans `INTERNAL_TOOL_NAMES` (coach_tools.py:57-91).

Doctrine Julien 2026-04-18 (hard-stop façade) respectée → **hard-stop avant Wave C**. Fix 5 min côté backend, mais prouve l'absence de test de routage end-to-end → ajouter le test inverse est prioritaire pour que cette famille de bugs ne repasse plus.
