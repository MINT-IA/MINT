# Audit Façade Systémique — SYNTHESE (2026-04-18)

Dev tip : 17d91776 (post-merge PR #355 Wave A-MINIMAL).
3 panels indépendants — Panel A (services/providers mobile), Panel B (widget_renderer ↔ coach tools), Panel C (backend endpoints ↔ Flutter callers).

Doctrine : `feedback_facade_sans_cablage_absolu.md` — façade trouvée = hard-stop, pas finding à prioriser. APIs publiques sans caller prod = delete ou `@visibleForTesting`. Tool schema shippé sans routing = fix immédiat.

---

## Findings majeurs consolidés

### Criticité 1 — P0 ABSOLUS (cassent des features shippées en prod)

Priorisés ici parce qu'ils ne sont PAS de la dette passive : ils rendent du code Wave A + Gate 0 silencieusement mort.

1. **Panel B P0-1 — `save_fact` routé comme external, drop silencieux au widget_renderer**
   Impact : les 35 clés whitelisted `save_fact` ne sont jamais persistées. `ProfileModel.data` backend reste vide. `coach_profile_provider.syncFromBackend()` récupère du vide. Wave A PRIV-07 redaction est code mort. `NotificationsWiringService` debounce ne fire jamais faute de `ProfileModel.data` modifié (chaîne façade complète).
   Fichier : `services/backend/app/services/coach/coach_tools.py:57-91` (INTERNAL_TOOL_NAMES), `coach_chat.py:1893-1897` (routage).
   Fix : add `"save_fact"` + `"suggest_actions"` à INTERNAL_TOOL_NAMES. 2 lignes.

2. **Panel B P0-2 — `suggest_actions` même bug, Gate 0 #6 chips dynamiques = façade**
   Idem P0-1. `_compute_suggested_actions` (coach_chat.py:846) n'exécute jamais. Les chips affichées = seulement fallback regex. Gate 0 #6 livré façade.
   Fix : add `"suggest_actions"` à INTERNAL_TOOL_NAMES.

3. **Panel B bug mineur — `save_insight` lit `insight_type` au lieu de `type`**
   Fichier : `services/backend/app/api/v1/endpoints/coach_chat.py:1249`.
   Schema expose `type` (coach_tools.py:468), handler lit `insight_type` avec fallback `"fact"`. Si Anthropic SDK sérialise sous `type`, Wave A A0 (commit 570c574a) qui ajoute event est neutralisée : tous les events sauvés deviennent des `"fact"`.
   Fix : lire `tool_input.get("type", tool_input.get("insight_type", "fact"))` pour compat.

4. **Panel C — `POST /profiles` + `PATCH /profiles/{id}` jamais appelés par Flutter**
   Backend : `services/backend/app/api/v1/endpoints/profiles.py:99,229`.
   Flutter : `coach_profile_provider.updateProfile()` est 100% local, `ApiService.createProfile()` marqué `@Deprecated`. Seul `GET /profiles/me` est live.
   Conséquence : le profil backend n'est jamais mis à jour après onboarding. `ProfileModel.data` backend = snapshot figé. Faille fonctionnelle silencieuse. Couplé avec P0-1, le profil n'a aucun chemin de mise à jour.

### Criticité 2 — P0 doctrine hard-stop (code mort, doctrine Julien 2026-04-18)

Pas dangereux fonctionnellement mais contredit `feedback_facade_sans_cablage_absolu.md`.

5. **Panel A — 4 providers registered dans `app.dart` sans consumer prod**
   `UserActivityProvider` (1245), `ContextualCardProvider` (1257), `AnticipationProvider` (1256), `CoachEntryPayloadProvider` (1287). Docstrings mensongères. Duplication d'API existante (UserActivity duplique ReportPersistenceService).

6. **Panel A — ~32 services + widgets orphelins shippés en prod**
   Clusters : Anticipation (8), Voice (6), Recap (4 + doublon), DACH (4), B2B/Expert/Agent (10). Orphelins isolés : JITAI, Milestone, Affiliate, 2×Challenge, DailyEngagement, AnnualRefresh, PlanTracking, Dashboard, 3×Benchmark, OpenFinance, BankImport, Visibility, LlmFailover, MultiLlm, RagRetrieval, MilestoneV2, doublon services/coach/coach_narrative_service. Total ≈ 45 fichiers à delete.

7. **Panel C — Cluster `/coach/narrative` S35 entier façade (5 endpoints morts)**
   Backend : `coach.py:61,87,107,127,147` (narrative/greeting/score-summary/tip/premier-eclairage). Flutter utilise `/coach/chat` + fallback local. Schémas `schemas/coach.py` orphelins. Collision : `/coach/premier-eclairage` (façade) vs `/onboarding/premier-eclairage` (live) vs `/documents/premier-eclairage` (live) = 3 endpoints pour 1 concept.

### Criticité 3 — P1 dette (150 endpoints backend / orphelins dormants)

Panel C identifie 150 endpoints / 210 = 74% façade. Décision architecturale (Flutter authoritative via `financial_core/` vs backend authoritative) est la cause racine. Non bloquant, mais `/overview/me` (P0 cluster 2) + `/budget/me` CRUD (P0 cluster 3) + `/fri/*` (P0 cluster 4) + `/open-banking/*` (P0 cluster 5) sont shippés sans câblage.

Traités en backlog architectural post-Wave E, pas en Wave E-prime.

### Criticité 4 — P1 cleanup Panel B

7 intent tags `route_to_screen` orphelins : `compound_interest`, `debt_check`, `expert_consultation`, `leasing_simulation`, `life_event_unemployment`, `patrimoine_overview`, `pillar_3a_overview`. Dégradation UX silencieuse (coach émet → Flutter retourne null → SizedBox.shrink).

Commentaire menteur `coach_profile_provider.dart:183`.

### Criticité 5 — P2 YAGNI

Clusters backend entiers à décider plus tard : Family (14), Expat (10), Segments (3), Privacy (4), Reengagement (5), etc. Total ≈ 100+ endpoints. Décision architecturale.

---

## Routing tranché

Conformément à la doctrine "fix P0 avant Wave C", je lance une **Wave E-PRIME** chirurgicale AVANT Wave C :

### Wave E-PRIME — Scope et exclusions

**IN** (P0 absolus + P0 doctrine simples) :
- Panel B P0-1/P0-2 routing fix (3 lignes modifiées)
- Panel B save_insight bug fix
- Regression tests `test_no_tool_declared_without_routing` + `test_dispatcher_routes_save_fact_as_internal`
- Panel A 4 providers sans consumer + cascades services morts (delete ≈ 45 fichiers)
- Panel C delete cluster `/coach/narrative` backend (5 endpoints + schéma)
- Panel B P2-1 commentaire menteur corrigé

**OUT** (Wave dédiée ou backlog) :
- Panel C POST/PATCH profile sync → nouvelle Wave persistence (dépasse Wave E scope, touche architecture profile state)
- Panel C `/overview/me` câblage → mise à Wave D (dossier-first narrative)
- Panel C `/budget/me` CRUD → backlog (décision architecturale)
- Panel C `/fri/*` câblage → **Wave D** (FRI visible — exactement l'objectif Wave D)
- Panel C `/open-banking/*` → backlog (feature Phase 4)
- Panel C 150 endpoints calculatoires dédoublés → décision architecturale à faire après Wave F
- Panel B 7 intent tags orphelins → Wave E originale (alignement symbolique, pas cassé)
- Panel A FinancialHealthScoreService `@visibleForTesting` → inclus dans Wave E-PRIME (trivial)

**Justification du scope minimal** :
- Fix tous les P0 qui cassent des features shippées (criticité 1)
- Delete le code mort simple (criticité 2) pour respecter hard-stop doctrine
- Ne pas toucher les décisions architecturales (criticité 3-5) qui demandent alignement plus large

### Wave E-PRIME — Estimation

- Phase 1 (routing fixes + tests) : 30 min, 2-3 commits
- Phase 2 (deletes Panel A) : 3-4h, 8-10 commits atomiques par cluster
- Phase 3 (delete backend coach/narrative + nettoyage app.dart) : 30 min, 1-2 commits
- Phase 4 (flutter analyze + test + backend pytest + device walkthrough) : 1h
- Total : 5-6h, ≈ 12 commits, 1 PR "fix(facade): Wave E-prime — close P0 from 3-panel systemic audit"

Après Wave E-PRIME → Wave C (scan handoff coach) comme prévu.

---

## Annexes — liens vers panels

- [PANEL-A-SERVICES-PROVIDERS.md](PANEL-A-SERVICES-PROVIDERS.md) — 358 lignes, 45 fichiers flaggés
- [PANEL-B-WIDGET-TOOLS.md](PANEL-B-WIDGET-TOOLS.md) — 279 lignes, 2 P0 routing + 7 P1 intents + 1 bug + 1 commentaire menteur
- [PANEL-C-BACKEND-API.md](PANEL-C-BACKEND-API.md) — 518 lignes, 150 endpoints façade, 5 clusters P0, 8 clusters P1, 25+ clusters P2
