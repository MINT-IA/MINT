---
handoff: chat-vivant
received: 2026-04-19
source: Cloud Design (external design system)
target_milestone: v2.9
status: planted (not executable as-is)
---

# Review — Chat Vivant HandOff (2026-04-19)

> Archived from `~/Downloads/HandOff/` into the repo on 2026-04-19 to preserve the specification. Do NOT execute the 11 prompts in `prompts.md` directly — see frictions below.

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

## Before kicking off v2.9

- [ ] Phase 31 Instrumenter shipped (current focus, in progress)
- [ ] Run `/gsd-discuss-phase` on v2.9 kickoff with expert panel on F1 + F2 + F3 to lock decisions
- [ ] Map each handoff prompt (0-10) to one of V1/V2/V3/V4 phases
- [ ] Decide Flutter port priority: pnpm at root OR `pubspec.yaml` fonts bundle vs `google_fonts` runtime load (license check on Fraunces weights)
- [ ] Verify prototype HTML can be opened on Julien's local browser (reference during V1 port)

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
