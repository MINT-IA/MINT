---
gsd_state_version: 1.0
milestone: v2.11
milestone_name: Walker-Validated E2E + Eclairage Wiring
status: roadmap_complete
stopped_at: 2026-05-05 — ROADMAP.md shipped after v2.10 5-audit synthesis. 6 phases (80-85) sequential, 30/30 REQs mapped, no orphans, no duplicates. Phase 85 = LAST gate before TestFlight 2.11.0 cut. Phantom-contract doctrine baked in (each contract has end-to-end test proving it is alive ; walker = machine de vérité). Ready for `/gsd-plan-phase 80` to decompose Phase 80 (Eclairage E2E wiring Flutter) into ≤ 4 plans.
last_updated: "2026-05-05T20:15:00.000Z"
last_activity: 2026-05-05
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State: MINT v2.11 — Walker-Validated E2E + Eclairage Wiring

## 5 audits 2026-05-05 (research artifacts)

A. Walker tap coords vs Phase 71a/73 — `cliclick` desktop logical px (pas device px), iPhone 17 Pro = 1206×2622 (pas 1179×2556 hero_bboxes), 6 screenshots run #1 identiques = walker bloqué silencieusement par beta modal.
B. Backend pipeline — Railway UP, contract eclairage Phase 71b absent du shipped code, cross-language drift DE→FR confirmé, 2 soft-flag LSFin.
C. MINT_E2E_FORCE_ECLAIRAGE_KIND — getter déclaré coach_orchestrator.dart:142, ZÉRO callsite, dead code.
D. Beta modal + walker idempotence — `isDismissible: false`, sim erase skipped en archetype mode, wait_for_ui returns happy on stuck UI.
E. i18n + animation — LocaleProvider FR hardcoded (OK), iPhone 17 Pro res 1206×2622, iOS 26 keyboard hide 350ms, Liquid Glass blur SHA flap risk.

## v2.11 Phase plan (sequential, 6 phases — ROADMAP shipped 2026-05-05)

| # | Phase | Goal | REQs | Effort |
|---|-------|------|------|--------|
| 80 | Eclairage E2E wiring (Flutter) | Wire forcedEclairageKind + CoachProfileSeeds.activeSeed + PremierEclairageSelector into anonymous render path, kReleaseMode-gated | ECLW-01..05 (5) | 1.5d |
| 81 | Backend eclairage contract | AnonymousChatRequest.archetype + AnonymousChatResponse.eclairage Pydantic schema + deterministic emitter pin par env var + LSFin compliance | ECLB-01..05 (5) | 2.0d |
| 82 | Walker coord-system overhaul | osascript sim-window pos+size runtime + recalibrate hero_bboxes 1206×2622 + Dynamic Island exclude + ≥2 stable hashes + beta dismiss step | WALKC-01..06 (6) | 2.0d |
| 83 | Sim hygiene + state isolation | simctl erase per archetype + MINT_DISABLE_BETA_MODAL dart-define + defensive uninstall + gitignore walker outputs + runtime preflight | SIMH-01..05 (5) | 1.0d |
| 84 | Cross-language drift fix | build_discovery_system_prompt(language) honored + ARB key parity CI gate active | LANG-01..03 (3) | 1.5d |
| 85 | Walker green 4 archetypes + TestFlight 2.11.0 | Final run + golden bake + version bump 2.11.0+1 + IPA upload + run-id evidence in TF description | WALKR-01..06 (6) | 2.0d |

**Total : ~10 days effort. Phase 85 = LAST gate before TestFlight cut.**

**Coverage : 30 / 30 REQs mapped, 0 orphans, 0 duplicates (cf. REQUIREMENTS.md traceability table).**

## Critical path

```
80 (Flutter spec) → 81 (backend matches) → 82 (walker calibrates wired stack) → 83 (sim hygiene) → 84 (i18n) → 85 (LAST GATE: walker green ×4 + TestFlight)
```

No parallelization. Each phase merges to `dev` before next opens. Avoids the v2.10 phantom-contract trap (Phase 71b PR #486 assumed Phase 71a contract that wasn't shipped on `dev`).

## Project Reference

See: .planning/PROJECT.md (v2.11 milestone declaration)
See: .planning/REQUIREMENTS.md (30 REQs, traceability filled)
See: .planning/ROADMAP.md (6 phases detail, success criteria, risks)

**Core value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça.
**Current focus:** v2.11 — roadmap complete, ready for `/gsd-plan-phase 80`.

## Constraints (from Julien — 2026-05-05)

- No human-in-the-loop testing — Claude validates everything via simulator iPhone (Mac mini)
- Image budget : max 1-2 screenshots per checkpoint shown to Julien
- TestFlight = Claude-validated only
- No new PRs outside the 6 v2.11 phases
- Phases sequential 80→81→82→83→84→85, no parallelization
- Each phase ≤ 2.5 days, ≤ 4 plans, must ship a PR-able artifact

## Doctrine v2.11 (Anti–Phantom-Contract)

1. Wire mécaniquement, pas documentation : every contract has an end-to-end test that proves it is alive.
2. Walker = la machine de vérité : if the walker doesn't validate it, it's not shipped.
3. No PR without runtime evidence : every PR attaches walker dry-run log / pytest output / widget test output.
4. Pre-push checklist mandatory (memory rule `feedback_pre_push_checklist`) : grep callers + regen OpenAPI/ARB + full pytest+flutter test BEFORE push.
5. Sequential merges to `dev` : no parallel phase PRs.

## Session Continuity

Last session: 2026-05-05T20:15:00.000Z
Stopped at: ROADMAP.md shipped — 6 phases (80-85), 30/30 REQs mapped sequentially. STATE.md + REQUIREMENTS.md traceability updated. No orphans, no duplicates, no parallelization. Ready for `/gsd-plan-phase 80` to decompose Phase 80 (Eclairage E2E wiring Flutter) into ≤ 4 plans.
Resume file: .planning/ROADMAP.md (Phase 80 detail)

---
*Last activity: 2026-05-05 — v2.11 roadmap_complete. Next : `/gsd-plan-phase 80`.*

# (legacy v2.8 state archived below for reference) ## v2.8 — L'Oracle & La Boucle

(historical context preserved — see git history of this file for the full v2.8 execution log if needed. Truncated here to keep the active v2.11 frontmatter and phase plan readable.)
