---
description: "CONTEXT locké pour M1 Grounded Coach — premier milestone de la refondation lucidity-spine (ADR 2026-06-12). Deux objectifs indissociables : (A) blindage compliance périmètre éducation stricte (décision fondateur 2026-06-12, bulletproof) et (B) grounding des claims du coach (zéro définition/assertion financière non sourcée). Inputs : rapports 01 + 04 de l'état des lieux."
---

# CONTEXT — mint-grounded-coach-m1

## Décisions LOCKED (ne pas re-litiger)

1. **Périmètre compliance : ÉDUCATION STRICTE, bulletproof** (fondateur, 2026-06-12). Toute sortie d'arbitrage = comparaison de scénarios éducative à hypothèses explicites. Jamais de recommandation personnalisée classée. Le CODE doit matcher le périmètre, pas seulement le prompt.
2. **Grounding contract** : aucune assertion financière (définition, règle, mécanisme) sans source déterministe — registre de concepts curé (wiki, pas vector-soup) ou calculateur tracé. Le LLM est « désarmé sur les faits » : un seul LLM orchestrateur, pas de router+specialists (état des lieux 04 §10).
3. **Fixture-first** : la fixture d'éval « rachat-inversion » (et la classe d'inversions du top-50 d'assertions suisses) doit être écrite et ROUGE contre le coach actuel AVANT les fixes (preuve déterministe), puis verte en CI.
4. **Activer-ou-supprimer** : les gates dark (`COACH_DUAL_LLM_ENABLED`, `COACH_BUNDLE_COMPILER_ENABLED`, `COACH_CITATION_GATE_ENABLED` — config.py:71,80,91) et le `coach_reasoner` non câblé sont soit activés/câblés dans M1, soit supprimés. Plus de façades (NEVER #6).
5. **Gate de sortie du milestone** : walkthrough persona réel sur sim (style W1-cadre-50) sans P1 sur les surfaces coach + suites vertes + fixtures d'inversion vertes.

## Inputs obligatoires pour le planner

- `.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md` (trous du pipeline, contrat de conseil, findings domaine)
- `.planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md` (design cible : explain_concept, claim-checker, show_fact_card gating, save_fact return path, eval harness)
- `.planning/decisions/2026-06-12-refondation-lucidity-spine.md` (cadre)
- `.planning/phases/mint-sense-making/walkthroughs/W1-cadre-50.md` (preuves device, WTF-01/03/04)

## Scope IN (workstreams)

- **WS-A Compliance hardening (prioritaire)** : reframe des sorties `coach_reasoner` (risques/hypothèses/sources en forme éducative comparée) + `get_couple_optimization` ; gardes prescriptives BLOQUANTES (le fallback ComplianceGuard ne doit plus tolérer >0 terme prescriptif/banni, vs >5 aujourd'hui — compliance_guard.py:442,451) ; suppression de l'escape hatch `known_values` (compliance_guard.py:494) ; cohérence prompt↔code du périmètre.
- **WS-B Grounded definitions** : registre de concepts suisses curé (top ~50 assertions : rachat, EPL, splitting, bonifications, pilier 3a/3b, taux de conversion, lacunes…) ; outil `explain_concept` avec `tool_choice` forcé sur intent (le pattern existe déjà sur anonymous_chat.py:204 — le généraliser à la surface authentifiée rag/llm_client.py:227) ; claim-checker déterministe à détection d'inversions ; `show_fact_card` gated (content+source validés contre le registre).
- **WS-C Façades** : activer-ou-supprimer les 3 gates dark ; câbler `coach_reasoner` en forme éducative ou le supprimer.
- **WS-D Data path + domaine** : `save_fact` retourne la valeur au mobile (fix split-brain minimal — le cutover spine complet est M2, PAS ici) ; corrections domaine : `avs.reference_age_women` 65.0 → 64.5 pour 2026 (registry.py:504), prose EPL/79b alignée sur les arrêts TF du 26.02.2026 (blocage 3 ans = tout retrait en capital, capital entier).
- **WS-E Eval harness** : fixtures inversions en CI (RED d'abord), scorers déterministes, extension du gate citation aux concepts.

## Scope OUT (ne pas déborder)

- Cutover event-log complet (M2). Refonte IA/navigation 5 surfaces (M3). Register redesign (M3). Boucle document upload (M4). Réécriture des docs produit (PR quick-wins séparé déjà identifié dans 05-docs-audit).

## Contraintes projet

- i18n 6 ARB + accents FR + termes bannis LSFin (CLAUDE.md TOP rules) ; financial_core L1 canonical ; 0-TRUST citations ; backend pytest + mobile suites vertes à chaque vague ; revue Codex CLI par vague (pattern validé phase illogism) ; device gate par vague quand surface visible.
