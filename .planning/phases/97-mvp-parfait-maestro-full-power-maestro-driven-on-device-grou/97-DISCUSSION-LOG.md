---
description: Phase 97 discuss-phase audit trail. Interactive mode per Julien explicit directive « je veux que ce soit toi qui prend les décisions ». PM Claude full-authority on 42 locked decisions (D-01..D-42). Julien input limited to validation/redirection of the macro framing.
---

# Phase 97: MVP-PARFAIT-MAESTRO-FULL-POWER — Discussion Log

> Audit trail only. Decisions in CONTEXT.md.

**Date :** 2026-05-11
**Phase :** 97-mvp-parfait-maestro-full-power
**Mode :** interactive (--interactive flag — Julien answers strategic choices, PM Claude makes the calls)
**Areas covered :** 6 gray areas presented in 2 batches (max 4 options per AskUserQuestion)

---

## Phase 97 framing (validation step)

**Q :** Phase 97 = 7-wave MAESTRO-FULL-POWER+MVP-PARFAIT structure, last phase of v2.9 milestone, TestFlight gate. Open now within v2.9 OR new v2.10 milestone OR scope-tighten OR pause?

**Julien answer :** « Open Phase 97 NOW within v2.9 milestone (Recommended) »

**Captured to :** D-31 wave structure, milestone scope.

---

## Gray areas (presented as 2 batches multiSelect)

### Batch 1 (auth + archetype + CI)

**Q :** quels areas en discuter ?

**Julien answer :** « 1. Auth strategy for Maestro flows, 2. Archetype matrix scope, 3. CI parallelism strategy, Non mais sérieusement, il faut absolument tout tester. Et pour ça, il faut vraiment un plan profond, détaillé, méthodique, state of the art. Tu as le product manager. Et tu es un expert autiste avec un QI de 200. Et tu es expert en stratégie de débugage. »

**Captured to :**
- D-01..D-04 auth strategy (HYBRID — local-mode bypass for smoke, real auth for regression)
- D-05..D-08 archetype matrix (ALL 8 per CLAUDE.md never #7, no subset)
- D-09..D-12 CI strategy (Mac mini self-hosted primary, Maestro Cloud fallback)

### Batch 2 (visual + reachability + ship gate)

**Q :** quels areas en discuter ?

**Julien answer :** « 4. Visual regression threshold + scope, 5. W5 reachability fix — which cards get MintCardActionBar first, 6. TestFlight ship gate criteria, De nouveau, tu es expert et tu fais vraiment le tout. Même si c'est... ça doit être méthodique, c'est évident, mais ton plan, il doit vraiment être exhaustif, n'est-ce pas? On veut mint qui fonctionne, point final. »

**Captured to :**
- D-13..D-16 visual regression (1% pixelmatch, 80 baselines = 10 screens × 8 archetypes)
- D-17..D-20 W5 reachability (ALL Aujourd'hui cards, testIDs everywhere, closes 999.6)
- D-21..D-26 TestFlight ship gate (5-gate × all 8 archetypes × 7-day soak, NO approved-with-issues)

---

## Julien clarification (post initial plan)

**Julien message :** « Quand je parle d'être méthodique, c'est parce que j'ai l'impression que franchement on a une centaine de bugs. Puis franchement, je pense qu'on a autant de choses qui sont complètement idiotes, illogiques qui ont été codés dans le noir. On peut pas tous les corriger en même temps. (...) Qu'est-ce qu'on répare? Qu'est-ce qu'on valide? Qu'est-ce qui est considéré comme réparer, validé, et qui est garantie sans régression plus tard. Et on avance. (...) Viens avec un plan qui est infaillible. »

**PM Claude response :** Plan révisé à 8 waves au lieu de 7. Ajout W6 méthodologie lockdown + W7 première itération 10 bugs P0. Milestone v2.10 MVP-CLEANUP en follow-up pour les ~85-90 bugs restants en sub-phases de 10. 7-step iteration cycle (PICK → REPRO → FIX → PASS → SUITE → LOCK → ADVANCE) défini comme méthodologie locked. Garanties no-regression via Maestro CI + visual diff + Sentry soak + bug registry lint state-machine.

**Captured to :**
- D-34 8-wave revised structure
- D-35 bug registry schema (YAML rows, severity scoring, state machine)
- D-36 7-step iteration cycle (PICK/REPRO/FIX/PASS/SUITE/LOCK/ADVANCE)
- D-37 no-regression guarantees (5 mechanisms)
- D-38 W7 success criterion (10/10 bugs P0 closed)
- D-39 bug ingestion sources (7 channels for W0 audit)
- D-40 v2.10 milestone cadence (10 bugs per sub-phase)
- D-41 deduplication (string-similarity > 80% lint warn)
- D-42 promotion rule (severity only goes UP, never DOWN)

---

## Final validation

**Q :** Plan Phase 97 révisé à 8 waves + 7-step cycle + milestone v2.10 follow-up. GO ?

**Julien answer :** « GO — lance W0 bug bash audit maintenant »

**Captured to :** PM Claude proceeds directly to W0 execution. mint-audit-complet skill + 4-expert parallel panel + manual sim ground-truth + HTML evidence history scan + TODO/FIXME grep dispatched in parallel.

---

## Auto-Resolved Items Summary

| Area | Source / decision | Locked in CONTEXT.md |
|------|-------------------|----------------------|
| Auth strategy | PM Claude expert call (hybrid local-mode + real-auth) | D-01..D-04 |
| Archetype matrix | Julien « tout tester » → ALL 8 | D-05..D-08 |
| CI strategy | PM Claude expert call (Mac mini primary, Maestro Cloud fallback) | D-09..D-12 |
| Visual regression | PM Claude expert call (1% pixelmatch, 80 baselines) | D-13..D-16 |
| W5 reachability scope | Julien « tout tester » → ALL Aujourd'hui cards | D-17..D-20 |
| Ship gate | Julien « MINT qui fonctionne point final » → full 5-gate × 8 archetypes × 7-day soak | D-21..D-26 |
| Tooling stack | PM Claude expert call (state-of-the-art Maestro 2.5.1 + pixelmatch + Sentry + simctl clone) | D-27..D-30 |
| Wave structure | Julien clarification → 8 waves (added W6 methodology + W7 first iteration) | D-31..D-33, D-34 |
| Iteration loop methodology | Julien « plan infaillible (...) qu'est-ce qu'on répare validé garantie no-regression » | D-34..D-42 |

All 42 decisions traceable to either Julien explicit input OR PM Claude expert-call per his full-authority grant.
