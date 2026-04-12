# MINT Documentation Status Matrix

> Created: 2026-03-21 | Last reviewed: 2026-03-25
> Purpose: Single-glance status of every doc — last update, accuracy vs code, what's drifted.
> Update this file whenever a doc is significantly modified or when codebase diverges.

---

## Status legend

| Status | Meaning |
|--------|---------|
| `current` | Accurate, no known drift from code |
| `partially outdated` | Some sections accurate, specific claims or lists diverge from code |
| `significantly outdated` | Major claims no longer reflect code or product |
| `obsolete` | Superseded — do not use for decisions |

| Sync | Meaning |
|------|---------|
| `synced` | Verified against code this session |
| `minor drift` | Small discrepancies found but not blocking |
| `major drift` | Significant mismatches — code is the truth |
| `not checked` | Not verified against code |
| `N/A` | Doc does not describe code behaviour |

---

## Master documents

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `CLAUDE.md` | 2026-03-21 | `current` | `synced` | Constants, team, compliance rules all accurate |
| `docs/MINT_UX_GRAAL_MASTERPLAN.md` | 2026-03-21 | `current` | `synced` | §3 updated with actual state; §13 phases corrected |
| `docs/DOCUMENTATION_OPERATING_SYSTEM.md` | 2026-03-21 | `current` | `N/A` | Updated task-to-doc mapping; ROADMAP_V2 added |

---

## Roadmap and planning

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `docs/ROADMAP_V2.md` | 2026-03-25 | `current` | `synced` | Status column added; S51-S68 deliverables corrected vs actual code. Re-verified 2026-03-25. |
| `docs/SPRINT_TRACKER.md` | 2026-03-17 | `partially outdated` | `minor drift` | Covers S0-S50 accurately; S51-S56 not listed (covered by ROADMAP_V2) |
| `docs/P8_EXECUTION.md` | unknown | `not checked` | `not checked` | Billing invariants — not reviewed this session |
| `docs/P6_BILLING_INVARIANTS.md` | unknown | `not checked` | `not checked` | Not reviewed this session |

---

## Navigation and architecture

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `docs/NAVIGATION_GRAAL_V10.md` | 2026-03-25 | `current` | `synced` | §8, §9 routes verified against app.dart; destinations updated to DONE. ScreenRegistry confirmed at 111 entries (2026-03-25). |
| `docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md` | unknown | `partially outdated` | `minor drift` | ScreenRegistry and RoutePlanner exist in code; ReturnContract/ScreenReturn not confirmed in code |
| `docs/APP_WEB_LONG_TERM_ARCHITECTURE.md` | unknown | `not checked` | `not checked` | Not reviewed this session |

---

## Design system and UX

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `docs/DESIGN_SYSTEM.md` | 2026-03-25 | `partially outdated` | `minor drift` | MintColors, MintTextStyles, MintSpacing, MintMotion all implemented. MintSurface and MintLoadingSkeleton documented. MintEntrance and MintTextField exist in code (`widgets/premium/`) but are NOT documented in DESIGN_SYSTEM.md. Outfit deprecated, MintGlassCard deprecated. |
| `docs/VOICE_SYSTEM.md` | unknown | `current` | `N/A` | Editorial guidelines — not code-dependent |
| `docs/MINT_SCREEN_BOARD_101.md` | 2026-03-25 | `current` | `synced` | 113 active surfaces verified against `find screens/ -name "*.dart"` (121 files, 8 helpers excluded). 3 screens added: weekly_recap, expert_tier, smart_onboarding. ScreenRegistry: 111 entries. |
| `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` | unknown | `partially outdated` | `not checked` | 75 proposals — some implemented, status per-widget not tracked here |
| `docs/UX_V2_COACH_CONVERSATIONNEL.md` | unknown | `significantly outdated` | `major drift` | Describes old 3-tab coach-centric UI. App moved to 4-tab shell with coach as one tab |
| `docs/AUDIT_REPORT_2026-03-13.md` | 2026-03-13 | `partially outdated` | `minor drift` | Point-in-time audit. S52 closed many findings. |
| `docs/AUDIT_CROSS_FUNCTIONAL.md` | unknown | `partially outdated` | `minor drift` | Point-in-time audit |
| `docs/audits/AUDIT_PHASE0_PULSE_V3.md` | unknown | `significantly outdated` | `major drift` | Pulse screen replaced by 4-tab shell |

---

## Coach AI and services

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `docs/BLUEPRINT_COACH_AI_LAYER.md` | 2026-03-25 | `partially outdated` | `minor drift` | References `coach_dashboard_screen.dart` (replaced by `CoachChatScreen`). Agent loop (tool_use -> execute -> re-call LLM) implemented in `coach_chat.py` + `coach_tools.py` but not explicitly documented in blueprint. `structured_reasoning.py` with `ReasoningOutput` exists in code. `ReturnContract` listed as S58 task (§Tx) — not confirmed shipped. Core architecture accurate. |
| `docs/MINT_CAP_ENGINE_SPEC.md` | unknown | `current` | `synced` | CapEngine + CapMemoryStore both implemented per spec |
| `docs/CAPENGINE_IMPLEMENTATION_CHECKLIST.md` | unknown | `current` | `synced` | Phases 0-4 complete |

---

## Financial and compliance

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `SOT.md` | unknown | `not checked` | `not checked` | Data contracts — not reviewed this session |
| `LEGAL_RELEASE_CHECK.md` | unknown | `not checked` | `N/A` | Pre-release checklist |
| `DefinitionOfDone.md` | unknown | `not checked` | `N/A` | Sprint criteria |
| `docs/ONBOARDING_ARBITRAGE_ENGINE.md` | unknown | `partially outdated` | `minor drift` | Onboarding routes changed (wizard → quick-start) |
| `docs/TOP_10_SWISS_CORE_JOURNEYS.md` | unknown | `current` | `N/A` | Strategic reference — not code-dependent |
| `docs/CICD_ARCHITECTURE.md` | unknown | `not checked` | `not checked` | CI/CD pipeline — not reviewed this session |

---

## Vision documents

| Document | Last Updated | Status | Sync with Code | Notes |
|----------|-------------|--------|----------------|-------|
| `docs/VISION_UNIFIEE_V1.md` | old | `obsolete` | `N/A` | Archive stratégique. Useful for principles, not direction. |
| `visions/MINT_Analyse_Strategique_Benchmark.md` | unknown | `current` | `N/A` | Benchmark reference — still valid |
| `visions/MINT_Autoresearch_Dev_Agents.md` | unknown | `current` | `N/A` | 10 dev agents — sprint execution method |
| `visions/MINT_Autoresearch_Agents.md` | unknown | `current` | `N/A` | 10 veille agents (post-launch) |
| `visions/vision_product.md` | unknown | `current` | `N/A` | Core promise |
| `visions/vision_compliance.md` | unknown | `current` | `N/A` | LSFin/FINMA/nLPD |

---

## Archive (do not use for decisions)

| Document | Status |
|----------|--------|
| `docs/archive/MINT_COACH_VIVANT_ROADMAP.md` | `obsolete` — superseded by ROADMAP_V2 |
| `docs/archive/UX_REDESIGN_COACH.md` | `obsolete` — superseded by MINT_UX_GRAAL_MASTERPLAN |
| `docs/archive/PLAN_ACTION_10_CHANTIERS.md` | `obsolete` |
| `docs/archive/UX_AUDIT_PERSONAS_JOURNEYS.md` | `obsolete` |
| `docs/archive/REFONTE_ONBOARDING_DASHBOARD.md` | `obsolete` — onboarding rebuilt |
| `docs/archive/WIZARD_*` | `obsolete` — wizard replaced by quick-start + chat |
| `docs/archive/AUDIT_PHASE0_PULSE*` | `obsolete` — Pulse replaced by 4-tab shell |
| `docs/S53_GATE_CLOSER_AGENT_PROMPT.md` | sprint artifact — `partially outdated` |

---

## Known contradictions resolved this session

1. **ROADMAP_V2 sprint labels vs actual code**: S52 was "3a Retroactif" in roadmap but actually delivered UX cohesion. S54 was "FHS" but S55 was the visual premium sprint. Labels corrected.
2. **NAVIGATION_GRAAL_V10 §8.1 status**: Listed tabs as "Créer" — they are DONE. Updated.
3. **NAVIGATION_GRAAL_V10 §9 routes**: Listed `/onboarding/quick-start` — actual route is `/onboarding/quick`. Corrected.
4. **MINT_UX_GRAAL_MASTERPLAN §3**: Listed "Ce qu'il faut rendre explicite" as pending — `ScreenRegistry`, `ReadinessGate`, `RoutePlanner` all exist. Updated to "État actuel".
5. **MINT_UX_GRAAL_MASTERPLAN §13**: Phase 3 referenced "7 événements de vie" — correct count is 18. Fixed.
6. **ROADMAP_V2 S58**: Listed `ReturnContract` as shipped — not confirmed in code. Marked as `foundation`.
7. **ROADMAP_V2 "ConfidenceScore system (5-level)"**: CLAUDE.md §5 correctly documents 5 source levels; §13 (moat) said "5-level", now says "4-axis" to distinguish the scoring dimensions from the source tiers.

---

*This matrix is the documentation audit trail. Update the "Last Updated" column and status whenever a doc changes.*
