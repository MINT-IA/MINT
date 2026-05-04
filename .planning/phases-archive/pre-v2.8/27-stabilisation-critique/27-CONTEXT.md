# Phase 27 — Stabilisation Critique : CONTEXT

## Goal
Le coach ne tombe plus JAMAIS sur le safe fallback. MSG2 (follow-up) fiable à 100%. Budget coût et débit bornés en prod. Rollback instant via feature flag.

## Root cause analysis

**Observation terrain (v2.6 gate 0)** : MSG2 échoue avec "coach IA pas disponible". Investigation : Claude émet `stop_reason="tool_use"` avec content blocks contenant UNIQUEMENT des tool_use (pas de texte). L'agent loop actuel (`coach_chat.py:_run_agent_loop`) sort silencieusement avec `final_answer=""`. Le guardrails filtre → fallback.

**Post-fix récent** (2026-04-13) : re-prompt quand `answer_text` vide ET tool_use présent. Fonctionne 90%. Les 10% restants : Claude émet tool_use + `stop_reason="end_turn"` (bug Sonnet 4.5 oct 2025).

**Décision architecture** (post deep research expert #1) :
- Ne jamais trust `stop_reason` → inspect content blocks explicitement.
- Remplacer `while tool_use` par **FSM explicite** avec states loggés : 6 états, chaque transition tracée.
- Graceful degradation Sonnet→Haiku + soft cap budget (jamais d'erreur visible).
- SLO-based auto-rollback (fallback_rate > 5% sur 5min → flag off).

## Key files (à lire avant planning)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — agent loop actuel, `_NoRagOrchestrator`, save_insight
- `services/backend/app/services/coach/claude_coach_service.py` — system prompt, tool_choice
- `services/backend/app/services/coach/compliance_guard.py` — fallback trigger
- `services/backend/app/services/coach/profile_extractor.py` — deterministic extractor (backup)

## Requirements addressed
- STAB-01 : MSG2 100% fiable (FSM + reflective check)
- STAB-02 : Retry Anthropic tenacity + model fallback chain
- STAB-03 : Idempotence SHA256 + Idempotency-Key header
- STAB-04 : Token budget adaptatif + soft cap
- STAB-05 : Feature flags Redis + SLO auto-rollback

## Constraints
- No new deps heavy (no LangGraph, no Unleash)
- Railway-compatible (pas de HSM, pas de service externe sauf Redis déjà là)
- Zero downtime deploy — feature flag permet rollback instant
- Julien dogfood first (user-scoped flag)

## Success Criteria
1. MSG2 follow-up renvoie réponse Claude valide dans 100% des scénarios Sophie (x10)
2. Retry automatique 429/529/503 (tenacity 3x, backoff exp)
3. Upload idempotent (SHA256 hit → response cache, pas re-Vision)
4. Token budget par user/jour cappé, dépassement = soft degradation (Sonnet→Haiku)
5. Feature flag `COACH_FSM_ENABLED` + `DOCUMENTS_V2_ENABLED` permet rollback sans redeploy
6. SLO auto-rollback si fallback_rate > 5% sur 5min

## Out of scope (deferred)
- Speculative MSG2 pré-génération (phase ultérieure)
- Prompt caching surgical break (après FSM validée)
- Hedged requests (overkill à 2000 users)
- pHash idempotence (simple SHA suffit v1)
- Content-addressable storage (B2B roadmap phase 4)
- Behavioral tiering (doctrine "MINT se rend inutile" — phase dédiée)

## Plans
- 27-01-PLAN : Agent loop FSM + reflective self-check + Anthropic retry + graceful degradation + feature flags + SLO rollback
