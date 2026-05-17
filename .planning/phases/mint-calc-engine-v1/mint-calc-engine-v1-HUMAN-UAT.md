---
status: partial
phase: mint-calc-engine-v1
source: [mint-calc-engine-v1-VERIFICATION.md]
started: 2026-05-17T08:38:44Z
updated: 2026-05-17T08:38:44Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. G2 Scénario A — grounding 422 coach avec profil incomplet (sim/device)
expected: Avec un profil vide ou minimal, le coach renvoie un envelope `CoachToolIncomplete` 422 (jamais un nombre fabriqué). UI Flutter affiche le narrator-asks template invitant à compléter les champs manquants.
how_to_run: Boot sim → app → coach screen → message « combien je touche à la retraite ? » sans avoir rempli le profil → confirmer le 422 + le message narrator-asks Mint-voiced.
result: [pending]

### 2. G2 Scénario B — invariant L4 mortgage-cap affiché correctement
expected: La règle LCC art. 28 (plafond 33% revenu brut) calcule un cap correct pour un profil donné et l'affiche avec citation art. visible.
how_to_run: Profil avec salaire 100 K CHF → coach screen → « combien je peux emprunter ? » → confirmer cap ~33 K/an, citation `LCC art. 28` présente.
result: [pending]

### 3. G2 Scénario C — Tool Search round-trip live (post staging pilot)
expected: La requête FR « si je divorce demain » (et autres FR queries Plan 09) surface `divorce_simulator` (ou autre tool pertinent du top-3) en production réelle via Anthropic Tool Search BM25. ⚠️ Bloqué jusqu'à activation `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` sur Railway staging (deferred-item #2).
how_to_run: Activer staging pilot → sim → coach screen → tester 5 queries Plan 09 → confirmer tool_call_id approprié dans chaque réponse via `idb ui describe-all` ou Sentry breadcrumb.
result: [pending]

### 4. G2 Scénario D — runtime verb gate déclenché live + Sentry breadcrumb
expected: Le runtime_verb_gate (Plan 18) intercepte un narrator output contenant un verbe banni (« le plus pertinent », etc.), retourne le template fallback « je n'ai pas cette donnée pour l'instant », et émet un breadcrumb Sentry `coach.verb_gate.fired`.
how_to_run: Injecter manuellement un verbe banni via une réponse Anthropic mockée OU attendre une occurrence naturelle sur staging → confirmer fallback affiché + breadcrumb Sentry dans les 30 min post-activation.
result: [pending]

### 5. G2 Scénario E — fenêtre Sentry 30 min post-merge dev→staging
expected: Pas d'augmentation du taux d'erreur Sentry sur les 30 min post-merge `dev → staging`. Aucun nouveau type d'exception coach-side.
how_to_run: Merge dev → staging (Stage 2 of 4 per CLAUDE.md §9.5) → ouvrir Sentry dashboard 30 min → comparer taux d'erreur baseline vs post-merge → confirmer aucune nouvelle exception.
result: [pending]

### 6. Tone review FR — 3 descriptions échantillonnées Plan 09
expected: Les 3 tool descriptions échantillonnées (verbatim dans [mint-calc-engine-v1-09-w2-tool-description-rewrite-SUMMARY.md](./mint-calc-engine-v1-09-w2-tool-description-rewrite-SUMMARY.md) § « Tone sample for Julien post-hoc review ») sonnent Mint-voiced, sans terme LSFin banni, avec accents FR corrects, et avec références légales (art. CC/LAVS/LPP/LIFD/LCC) précises.
how_to_run: Lire la section « Tone sample » du Plan 09 SUMMARY → pour chaque description, juger sur 3 axes : voix Mint (oui/non) · vocabulaire LSFin-safe (oui/non) · références légales exactes (oui/non) → si OK ack ; sinon lister les descriptions à reécrire.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps

(none yet — surface here when tests fail or unexpected behavior found)
