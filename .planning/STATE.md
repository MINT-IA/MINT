---
gsd_state_version: 1.0
milestone: v2.8
milestone_name: L'Oracle & La Boucle
status: roadmap_created, awaiting_phase_planning
stopped_at: ROADMAP.md written (8 phases, 48 REQ mapped 1:1). REQUIREMENTS.md traceability updated. Next — /gsd-plan-phase 30.5
last_updated: "2026-04-19T12:00:00.000Z"
last_activity: 2026-04-19
milestone_status: roadmap_created
previous_milestone: v2.7 Coach Stabilisation + Document Digestion (code-complete, awaiting device-gate GATE-01 iPhone + GATE-02 Android)
current_phase: 30.5
progress:
  total_phases: 8
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State: MINT v2.8 — L'Oracle & La Boucle

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19)

**Core value:** Toute route user-visible marche end-to-end et on le prouve mécaniquement ; on sait en <60s ce qui casse ; aucun agent ne peut ignorer son contexte ; Julien ouvre MINT 20 min sans taper un mur.
**Current focus:** Roadmap created (8 phases : 30.5, 30.6, 31, 32, 33, 34, 35, 36). Awaiting `/gsd-plan-phase 30.5` to decompose Phase 30.5 Context Sanity into executable plans.

## Architecture Decisions (pre-phase, v2.8)

- **Nom**: "L'Oracle & La Boucle" (pas "Pilote & Compression"). Capture le geste central.
- **Rule inversée scellée**: 0 feature nouvelle. Tout ajout = out of scope by default.
- **Compression transversale**: chaque phase tue du code mort au passage, pas phase isolée.
- **Sentry existant étendu**, pas Datadog/Amplitude/PostHog (un seul vecteur = moins de surface nLPD + moins de divergence).
- **Système flags custom étendu** ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) + endpoint `/config/feature-flags`), pas LaunchDarkly.
- **lefthook pre-commit local**, pas juste CI gates (feedback <5s vs 2-5 min).
- **Phase numbering continué** depuis v2.7 (30 terminé) → **30.5, 30.6 (decimal inserts post-panel-debate), puis 31-36**.
- **Research activée** (Julien a choisi "Research first") — 4 researchers parallèles sur observabilité fintech mobile. Synthèse dans `.planning/research/SUMMARY.md`.
- **Phase debate résolu** (4 panels: Claude Code architect / peer tools / academic / devil's advocate) — MEMORY.md truncation = P0 runtime confirmé, lints mécaniques ROI > refonte éditoriale, AST proof-of-read = theater, `UserPromptSubmit` hook ciblé remplace AST, Phase 30.6 Tools Déterministes ajoutée (insight Panel C).
- **Kill-policy scellée** via [ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si v2.8 exit avec REQ table-stake unmet, la feature est KILLED via flag. Pas de v2.9 stabilisation.
- **Budget Phase 36 non-empruntable** (2-3 sem MINIMUM) — forces honest sizing de 31-35.

## Current Position

Phase: Not started (roadmap created)
Plan: —
Status: Roadmap created, awaiting phase planning
Last activity: 2026-04-19 — ROADMAP.md written, 8 phases defined (30.5 → 36), 48 REQ mapped 1:1
Next: `/gsd-plan-phase 30.5` (Context Sanity, 5j non-empruntable, foundation)

Progress: [░░░░░░░░░░] 0% (0/8 phases, 0/0 plans)

## Build Order

```
30.5 → 30.6 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36
```

- **30.5 Context Sanity** (5j non-empruntable) — foundation, CTX-05 spike gate go/no-go
- **30.6 Tools Déterministes** (2-3j) — MCP tools on-demand, ~16k tokens/session saved
- **31 Instrumenter** (1.5 sem, can borrow from 34) — Sentry Replay + error boundary 3-prongs + trace_id round-trip
- **34 Guardrails** (1.5 sem, can borrow from 31, parallel with 31) — lefthook + 5 lints + CI thinning. **GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05 starts.**
- **32 Cartographier** (1 sem, can borrow from 33) — route registry + /admin/routes dashboard
- **33 Kill-switches** (1 sem, can borrow from 32, parallel with 32) — GoRouter middleware + FeatureFlags ChangeNotifier + 4 P0 kill flags provisioned for Phase 36
- **35 Boucle Daily** (1 sem) — mint-dogfood.sh simctl + auto-PR threshold
- **36 Finissage E2E** (2-3 sem **non-empruntable**) — 4 P0 fixes + 388 catches → 0 + device walkthrough 20 min

## Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 30.5 | Context Sanity | 5j | **non-empruntable** | 5 | CTX-05 spike |
| 30.6 | Tools Déterministes | 2-3j | — | 4 | — |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — |
| 35 | Boucle Daily | 1 sem | — | 5 | — |
| **36** | **Finissage E2E** | **2-3 sem MIN** | **never** | **9** | 4 P0 kill flags + device walkthrough |

**Total estimate:** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

## Accumulated Context

### Decisions (v2.8 pre-phase)

- **v2.8 name**: "L'Oracle & La Boucle" captures instrumentation-first + daily loop
- **0 feature nouvelle** scellée via kill-policy ADR
- **Compression transversale**: chaque phase tue du code mort au passage
- **Extend existing Sentry** (not Datadog/Amplitude/PostHog) — bump `sentry_flutter` 8→9.14.0
- **Extend custom flags** (not LaunchDarkly) — converge 2 backend systems (env-backed read + Redis-backed write)
- **lefthook 2.1.5** for pre-commit local (not CI-only) — target <5s
- **Sentry Replay Flutter 9.14.0** with `maskAllText=true` + `maskAllImages=true` nLPD-safe defaults non-négociables
- **Headers manuels `sentry-trace` + `baggage` sur `http: ^1.2.0`** (pas migration Dio)
- **Binary-per-route flags** (pas cohort/percentage)
- **4 P0 kill flags provisioned in Phase 33** before Phase 36 begins: `enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Known Good Foundations (to capitalize)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

## Session Continuity

Last session: 2026-04-19T12:00:00.000Z
Stopped at: ROADMAP.md written post-panel-debate (8 phases, 48 REQ mapped, build order + budget table + kill-policy reference). REQUIREMENTS.md traceability updated. PROJECT.md already aligned.
Resume file: `.planning/ROADMAP.md` (review) → then `/gsd-plan-phase 30.5` (Context Sanity kickoff)

---
*Last activity: 2026-04-19 — v2.8 ROADMAP.md created, 8 phases (30.5 → 36), 48 REQ mapped 1:1, build order 30.5 → 30.6 → (31∥34) → (32∥33) → 35 → 36*
