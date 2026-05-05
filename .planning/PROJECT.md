# MINT — Fondation

## What This Is

MINT is a Swiss financial lucidity & education app (Flutter + FastAPI) that gives users financial peace-of-mind, clarity, and control with near-zero effort. MINT is a living dossier that collects, understands, and reveals what matters about the user's financial life. Infrastructure plumbing is fixed (v2.4). This milestone transforms MINT from working infrastructure into a product that hooks, converts, and retains users through the anonymous→value→premium flow and the 5 expert audit innovations.

## Core Value

**Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.**

## Current Milestone: v2.12 Production-Ready Sim Validation

**Goal :** Aucun TestFlight tant que Claude n'a pas validé que l'app tourne PARFAITEMENT sur simulator — 4 archetypes × 3 langues × 7 quality gates. Le walker est la machine de vérité ; Julien ne fait aucun test. Le STAMP-08 (`.planning/phases/89-stamp/STAMP-PASS-<date>.html`) est la seule autorisation de tag v2.12.0.

**Doctrine v2.12 :** No-Ship-Without-Perfect-Sim. Pas de wishful thinking. 9 jours effort, 4 phases sequential, 32 REQs panel-locked.

**4 phases planned (86-89, post v2.11) :**

- **Phase 86 — Walker green réel 4 archetypes (FR)** (3.0d) : calibration walker_premier_eclairage.sh + tooling upgrades (`--retry-once`, `--record-trace`, `--locale=<fr|de|en>`). 8 SIMQ-* REQs.
- **Phase 87 — Bare-catches sweep Wave 1 (15 paths critiques)** (2.0d) : ~15 paths (walker-touched 6 + data-integrity 5 + UI-services 3 + top-1 ranked 1). Reste ledger `BARE_CATCH_DEBT.md`. Wave 2 → v2.13. 8 OBSV-* REQs.
- **Phase 88 — Cross-language walker FR+DE+EN × 4 archetypes = 12 walks** (2.0d) : 0 retries policy, DE golden bake separate (DE strings +30% length), no-ellipsis assertion 4-card éclairage. 8 XLOC-* REQs.
- **Phase 89 — Quality stamp + No-Ship-Until-Perfect gate** (2.0d) : 7-gate mechanical checklist. STAMP-PASS = autorisation TestFlight. 8 STAMP-* REQs.

**7 quality gates (Phase 89) :**
1. Walker green 12 walks exit 0, 0 retries
2. Cold-launch P50 ≤ 2.5s sur iPhone sim (5 boots)
3. Frame jank < 1% > 16ms sur 4-card éclairage scroll-and-tap 5s
4. VoiceOver smoke 1 archetype × 3 langues, reading order déterministe via `Semantics.sortKey`
5. Sentry ≥ 8 breadcrumb categories distincts au walker run staging dans 2 min
6. ARB parity 6-lang exit 0 (déjà LANG-03)
7. `BARE_CATCH_DEBT.md` ledger + `tools/checks/no_new_bare_catch.py` lint blocking

**Carry-forward de v2.11 :** PRs #490-#496 absorbées (eclairage E2E + walker tooling + sim hygiene + i18n). v2.12 = la mise à l'épreuve mécanique de v2.11.

**Out of scope (deferred to v2.13) :** IT/ES/PT walker (ARB-parity covers TI strings, visual gate hors scope), auth-tier regression archetype (anonymous-flow first), Wave 2 bare-catches (next 50), couple mode wiring (data layer cracked), iPhone SE / iPad viewports (single sim target = iPhone 17 Pro). v2.9 phases 40-43 (vignettes/scènes/canvas) re-deferred.

**Previous milestone v2.11 — wiring shipped (PRs #490-#496) but runtime UNVALIDATED.** v2.12 = the validation gate.

## Previous Milestone: v2.8 L'Oracle & La Boucle (shipped 2026-04-25 with gaps)

5 phases shipped (30.5 Context Sanity Core + 30.6 Advanced + 30.7 Tools Déterministes + 31 Instrumenter + 32 Cartographier) + 13 decimal patches (30.8-30.20: LAND-01 fix, FIX-02 anonymous CTA, doc extraction uplift, error mapping, etc.). 4 phases unshipped (33/34/35/36) — carried forward to v2.9 or deferred. Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md).

## Requirements

### Validated

- ✓ AVS calculations (rente, couple, 13th, gaps, deferral) — golden tests pass, values verified
- ✓ Capital withdrawal tax (progressive brackets, married discount) — golden tests pass
- ✓ Constants sync (Flutter ↔ backend, 2025/2026 values) — verified
- ✓ Confidence scorer (11 components, Bayesian, 86 usages) — well wired
- ✓ Design system (MintColors, MintTextStyles, MintSpacing) — 0 hardcoded colors
- ✓ Compliance guard (5 layers, PII scrubbing, disclaimer injection) — functional
- ✓ CI pipeline (7 workflows, accessibility/readability gates) — healthy
- ✓ Token security (JWT in SecureStorage, BYOK in SecureStorage) — proper compartmentation
- ✓ MEMORY.md retention + dashboard agent-drift — v2.8 (CTX-01..02)
- ✓ CLAUDE.md restructure + UserPromptSubmit hook — v2.8 (CTX-03..05)
- ✓ MCP tools déterministes (get_swiss_constants / check_banned_terms / validate_arb_parity / check_accent_patterns) — v2.8 (TOOL-01..04)
- ✓ Sentry Replay Flutter 9.14.0 + global error boundary 3-prongs + trace_id round-trip — v2.8 (OBS-01..07)
- ✓ Route registry-as-code 150 routes + /admin/routes + parity lint — v2.8 (MAP-01..05)
- ✓ LPP CPE / HOTELA extractor 8→15/18 fields + 56 regression tests — v2.8 (decimal 30.18-30.20)
- ✓ Tax LIFD-citation false-positive fix + AVS IK table heuristic — v2.8 (decimal 30.19)
- ✓ Anonymous flow `/anonymous/intent` route wired + error mapping — v2.8 (decimal 30.14-30.15)
- ✓ Backend README first-run + ANTHROPIC_API_KEY documented — v2.8 (decimal 30.16)
- ✓ MVP wedge T9 email-demain killed + DESIGN.md spec — v2.8 (decimal 30.17)

### Active

See `.planning/REQUIREMENTS.md` for v2.8 requirements (OBS-*, MAP-*, FLAG-*, GUARD-*, LOOP-*, FIX-*).

### Out of Scope (v2.8)

- **Any new user-facing feature** — 0 feature nouvelle, règle scellée
- Monte Carlo UI, withdrawal sequencing UI, tornado sensitivity — reporté v2.9+
- Privacy Nutrition Label + Data Vault + Trust Mode + Graduation Protocol v1 (proposé initialement comme "v2.8 La Confiance") — déplacé vers v2.9
- Premium gate wiring (Stripe/RevenueCat) — v2.9+
- LaunchDarkly / feature flags tiers — on étend le système custom existant ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart))
- Datadog RUM / Amplitude / PostHog — Sentry reste le seul vecteur (Replay suffit pour v2.8)
- Patrol E2E tests — sim-level walkthrough suffit pour la boucle daily
- OpenTelemetry — nice-to-have, pas bloquant pour l'oracle v2.8

## Context

### Codebase State (2026-04-19, entrée v2.8)
- Flutter: 0 compile errors, ~9327 tests pass (28 skipped, pre-existing pumpAndSettle failures catalogués)
- Backend: Railway staging + production live, ~5925 tests pass
- v2.7 code-complete: LLMRouter Sonnet→Haiku fallback, SLOMonitor auto-rollback, `DocumentUnderstandingResult` canonical, envelope encryption AES-256-GCM, ISO 29184 consent, VisionGuard Haiku judge, Bedrock EU router (off), 17 Vision cassettes + golden flow pytest
- Wave E-PRIME mergée (PR #356 → dev f35ec8ff) : 42K LOC supprimées, 72 fichiers mobile + 4 backend deleted (autonomous_agent, visibility, plan_tracking, benchmark cascade)
- Wave C scan-handoff en cours sur branche courante `feature/wave-c-scan-handoff-coach` (PLAN.md écrit, 3 panels pre-exec en background)
- **Dégâts catalogués entrant v2.8**: 388 bare catches silencieux (332 mobile + 56 backend), flow anonyme mort malgré `AnonymousChatScreen` implémenté, `save_fact` unsync backend→front, MintShell labels hardcodés FR, UUID profile crash, Coach tab routing stale, 23 redirects legacy
- **Leviers existants à capitaliser**: Sentry backend+mobile wirées (sample 10%), 148 GoRoute documentées ([docs/ROUTE_POLICY.md](docs/ROUTE_POLICY.md) + [docs/NAVIGATION_GRAAL_V10.md](docs/NAVIGATION_GRAAL_V10.md) + [docs/SCREEN_INTEGRATION_MAP.md](docs/SCREEN_INTEGRATION_MAP.md)), système flags custom 8 flags + endpoint backend `/config/feature-flags`, ~10 CI gates mécaniques dans [tools/checks/](tools/checks/), [docs/DEVICE_GATE_V27_CHECKLIST.md](docs/DEVICE_GATE_V27_CHECKLIST.md), [tools/e2e_flow_smoke.sh](tools/e2e_flow_smoke.sh)
- Source de vérité identité/mission: `docs/MINT_IDENTITY.md` + `.planning/architecture/13-AUDIT.md`
- Doctrine opérationnelle v2.8: "pas de raccourcis, pas de simplifications, tout doit être parfait" (cf. memory/feedback_no_shortcuts_ever.md)

## Constraints

- **Device gate**: Every phase verified by creator (Julien) via `flutter run --release` on iPhone connected to Mac Mini
- **No retirement framing**: MINT is NOT a retirement app. 18 life events. Every fix must serve 18-99 equally.
- **Branch protocol**: feature/* → dev → staging → main. Never push to staging/main directly.
- **Compliance**: All coach output through ComplianceGuard. No banned terms. Educational only.
- **Sequential execution**: One plan at a time to avoid conflicts (lesson learned from cascading agent damage)
- **No new features**: Recovery only. Fix what's broken, don't add capabilities.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wire Flutter to /coach/chat endpoint (not add server-key to /rag/query) | /coach/chat already has agent loop, tools, server-key fallback, system prompt | — Pending |
| Archive old GSD project, start fresh | The recovery IS the project now, not a milestone on the old roadmap | ✓ Good |
| Fine-grained phases (8-12) | Each incident isolated, verifiable independently, prevents cascading failures | — Pending |
| Sequential execution, no parallel plans | Parallel agents caused the current mess — one change at a time | — Pending |
| All workflow agents enabled (research, plan check, verifier) | Maximum rigor to prevent repeating the facade-without-wiring pattern | — Pending |
| Device gate (flutter run --release on iPhone) | 9256 tests green + audit passed ≠ app works. Only device walkthrough proves it. | ✓ Good — doctrine appliquée v2.7 |
| **v2.8**: Rename "Pilote & Compression" → "L'Oracle & La Boucle" | Nom initial ne capturait pas le geste : instrumentation-first + daily loop. Compression devient transversale, pas phase dédiée. | — Pending |
| **v2.8**: Étendre système flags custom, ne PAS adopter LaunchDarkly | 8 flags + endpoint `/config/feature-flags` + server override déjà en place. Adding LaunchDarkly = dette + vendor lock-in pour zéro gain. | — Pending |
| **v2.8**: Sentry Replay Flutter + global error boundaries, pas Datadog/Amplitude/PostHog | Sentry déjà wirée. Ajouter un vendor de plus = surface d'attaque + coût nLPD + divergence sources de vérité. | — Pending |
| **v2.8**: lefthook pre-commit local, pas juste CI | CI gates post-push = feedback 2-5 min. Pre-commit local = feedback <5s. Réduit 10× les PR cassées. | — Pending |
| **v2.8**: 0 feature nouvelle, règle scellée | Wave E-PRIME a supprimé 42K LOC de façade. Ajouter sans finir = replantation du problème. Compression > création. | — Pending |
| **v2.8**: Phases 31-36, continuent numérotation v2.7 | Continuité historique > restart. v2.7 termine à 30, v2.8 commence à 31. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-25 after v2.8 close (gaps_found, 5/9 phases shipped + 13 decimals) and v2.9 « Coach Visuel Hybride » open*
