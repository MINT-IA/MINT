---
handoff: chat-vivant
received: 2026-04-19
source: Cloud Design (external design system)
target_milestone: v2.9
target_phase: v2.9 Phase 3 (sub-phases 3.1 → 3.5)
status: deferred-locked-by-ADR
locked_by: decisions/ADR-20260420-chat-vivant-deferred-v2.9-phase3.md
last_reviewed: 2026-04-20
prerequisites:
  - v2.8 Phase 32-36 shipped clean (kill-policy respected)
  - Phase 31 creator-device gate green (physical iPhone + live DSN)
  - v2.9 Phase 1 Wave E-PRIME debts wired (POST/PATCH profile, /overview/me, /budget CRUD, /fri/*, 7 intent tags)
  - v2.9 Phase 2 BirthDate migration landed
  - v2.9 Phase 2.5 V0 prep (ChatMessage.kind + FeatureFlags.enableChatVivant + ScenePayload stub)
---

# Review — Chat Vivant HandOff (2026-04-19, refreshed 2026-04-20)

> **DEFERRED to v2.9 Phase 3 per ADR-20260420.** Do not execute any handoff prompt until prerequisites above are complete. See `decisions/ADR-20260420-chat-vivant-deferred-v2.9-phase3.md` for full rationale (5 prerequisites, 5 sub-phases, tripwires). Archived from `~/Downloads/HandOff/` into the repo on 2026-04-19 to preserve the specification.

## Verdict

**Exceptional external spec, aligned 100% with MINT doctrine** (feedback_chat_is_everything, feedback_conversation_driven_ux, feedback_no_banality_wow, Cleo 3.0 loop). Best handoff received on this project.

**Not executable as-is** due to 3 frictions the handoff ignores.

## What's valuable (copy verbatim into future plans)

1. **Vision tagline** — "Le chat ne raconte plus, il montre." Direct alignment with conversation-driven UX doctrine.
2. **3-level projection grammar** (inlineInsight / scene / canvas) — clean mental model, maps to Claude Artifacts pattern.
3. **Architecture Flutter** — SceneRegistry + ChatProjectionService + ReturnContract. Clean pattern, reusable.
4. **6 invariants non-négociables** (no emoji, one hero number per view, Fraunces for em/signatures, phrase de recul, hypotheses visible, CTA noirs).
5. **JSX prototype** (`prototype/chat-vivant/*.jsx`) as reference for visual port.
6. **11 prompts scope-limited** — if the 3 frictions are resolved, these prompts become actionable.

## 3 frictions the handoff ignores

### F1. Scenes inline duplicate existing Explorer screens
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` **exists** (full screen).
- `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart` **exists** (full screen).
- `apps/mobile/lib/domain/rente_vs_capital_calculator.dart` **exists** (calculation logic).

The handoff proposes `MintSceneRenteCapital` + `MintSceneRachatLPP` as inline widgets — creating 2 surfaces for the same logic. Duplication risk.

**Decision needed before exec**: (a) scene consumes the calculator (single source of truth) + existing screen is kept as Explorer detail view, OR (b) accept duplication and plan a refactor post-V2.

### F2. `Stream<ChatMessage>` refactor scope under-estimated
Handoff says "2-3 days dev concentré". Reality: `CoachOrchestrator` has **3 code paths** (Anonymous, BYOK, ServerKey) across 800+ lines. Converting `Future<CoachResponse>` → `Stream<ChatMessage>` touches all 3 + all consumers.

**P50 estimate**: 5-7 days with tests + creator-device gate. Budget 3 weeks calendar for the full milestone.

### F3. i18n 6 languages absent from handoff
Prototype strings are FR-hardcoded. MINT ships in 6 languages (fr/en/de/es/it/pt). ~30 new strings × 6 = **180 ARB entries** to add.

## Recommended execution path (v2.9 milestone, 3-4 phases)

| Phase | Scope | Budget |
|---|---|---|
| V1 | Fraunces tokens + `MintReveal`, `MintTypingDots`, `MintInlineInsightCard`, `MintRatioCard` | 2-3j |
| V2 | `MintLifeLineSlider`, `MintSceneRenteCapital`, `MintSceneRachatLPP` + refactor calculators (single source of truth — resolves F1) | 3-4j |
| V3 | `MintCanvasProjection` + chapitres + verdict + `ReturnContract` + i18n ARB 6 languages (resolves F3) | 3-4j |
| V4 | Refactor `Stream<ChatMessage>` in `CoachOrchestrator` + `SceneRegistry` + `ChatProjectionService` + feature flag `chatVivant` (resolves F2) | 4-5j |

**Total P50**: 12-16 calendar days (~3 weeks solo with creator-device gate between V3 and V4).

## Before kicking off v2.9 Phase 3 Chat Vivant (prerequisites locked by ADR-20260420)

- [x] Phase 31 Instrumenter shipped (PR #367, f17e56c2, 2026-04-20 — awaiting merge)
- [ ] Phase 31 creator-device gate (Julien iPhone physique + Sentry DSN live)
- [ ] v2.8 Phase 32 Cartographier shipped
- [ ] v2.8 Phase 33 Kill-switches shipped
- [ ] v2.8 Phase 34 GUARD-02 bare-catch ban ACTIF
- [ ] v2.8 Phase 35 Boucle Daily (mint-dogfood.sh) shipped
- [ ] v2.8 Phase 36 Finissage E2E shipped + creator-device gate Julien 20 min cold-start PASS
- [ ] v2.9 Phase 1 Wave E-PRIME debts wired (POST/PATCH profile, /overview/me, /budget CRUD, /fri/*, 7 intent tags orphelins)
- [ ] v2.9 Phase 2 BirthDate migration landed
- [ ] v2.9 Phase 2.5 V0 prep (ChatMessage.kind enum + FeatureFlags.enableChatVivant + ScenePayload stub, 0.5j)
- [ ] v2.9 Phase 3.1 `/gsd-discuss-phase` chat-vivant — résoudre F1 (calculator partagé, scène read-only), F2 (stream refactor scope), F3 (i18n 180 entries)
- [ ] v2.9 Phase 3.1 session de réduction design avec Julien (thumb 48pt, phrase d'orientation post-recul, Canvas v2.9 ou v2.10)
- [ ] i18n traduction 180 entries démarré parallèle depuis Phase 3.1 (long pole, pas sur chemin critique)
- [ ] Fraunces font delivery checklist (LTE fallback test, pubspec bundling vs google_fonts runtime decision)
- [ ] Verify prototype HTML can be opened on Julien's local browser (reference during Phase 3.2 port)
- [ ] Map each handoff prompt (0-10) to one of Phase 3.2/3.3/3.4/3.5 sub-phases

## Source files

All source material preserved in this directory:
- `00-README.md` — handoff reading order
- `01-vision.md` — 3-level projection grammar + editorial grammar
- `02-architecture.md` — 3 Flutter services spec
- `03-components.md` — 8 widgets with signatures + tokens + structure
- `04-animations.md` — timings + curves mapping to Flutter
- `05-integration.md` — CoachOrchestrator + IntentResolver extension
- `06-test-plan.md` — golden tests + invariants testables
- `prompts.md` — 11 ready-to-paste prompts (don't run as-is, see frictions above)
- `prototype/MINT — Chat vivant.html` — reference HTML to open in browser
- `prototype/chat-vivant/*.jsx` — 8 React components to port to Flutter
- `prototype/captures/*.png` — 6 visual reference screenshots

---

*Reviewed 2026-04-19 during Phase 30.6 Advanced ship session. Planted as v2.9 milestone seed in ROADMAP.md. To wake after Phase 31 Instrumenter completes.*
