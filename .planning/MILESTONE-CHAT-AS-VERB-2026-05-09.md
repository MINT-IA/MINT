---
name: MILESTONE-CHAT-AS-VERB-2026-05-09
description: Strategic pivot — MINT stops being a « chat app with calculators » and becomes a wiki-of-life-events with chat as a precision tool invocable from card-actions. 7 phases (4 architecture + 3 UI) sequenced over 4 weeks via GSD workflow.
type: milestone
date: 2026-05-09
status: PROPOSED → ACTIVE post-roadmap-approval
related:
  - .planning/decisions/2026-05-09-7-panel-comprehensive-audit/SYNTHESIS.md
  - .planning/MAESTRO-STRATEGY-MINT.md
  - .planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md (existing STUB to absorb)
sources:
  - 4-expert panel synthesis 2026-05-09 (Cleo strategist + Karpathy architect + adversarial agent + UI auditor)
  - Code base audit 2026-05-09 (52 fields wiki, 17 simulators, coach text-first)
  - PO directive 2026-05-09 « MINT n'est pas un chat. Wiki + simulations + minimum chat livraison. »
---

# MILESTONE — Chat-as-Verb Pivot

## Strategic frame

> MINT today is **70% structured wiki + simulators, 30% narration**. That's the asset. The problem is the design system has 18 months of drift, the LLM does 2 jobs poorly (extraction + delivery), and chat-tab sits as the destination instead of as a verb invocable from cards.
>
> **Pivot** : kill the chat-tab. Cards become the home. Tap « explique / simule / rassure-moi » on any card opens a 3-turn coached overlay grounded in that card's facts. Every number carries a citation chip. The narrator LLM is mathematically incapable of emitting an un-cited number.

## North-star metric

**Turns/user/week DOWN, DAU UP, quarter over quarter.** This inversion proves the wiki is winning.

## 7 phases (4 architecture + 3 UI)

| # | Phase | Type | Effort | Why now |
|---|---|---|---|---|
| 1 | **MVP-DESIGN-LINTS-V1** | UI | 2 d | Foundation. Stop the bleeding on tokens before any UI sweep. Block new violations, baseline existing. |
| 2 | **MVP-EXTRACTOR-V2** | Architecture | 3 d | Split the LLM into 2 distinct roles (extracteur fatter, narrateur thin). Independent of UI. Unblocks citation gate. |
| 3 | **MVP-FONTS-TOKENS-V2** | UI | 3 d | Land Supreme + Gambarino + Menthe-vive. Drop GoogleFonts.*. STUB exists. |
| 4 | **MVP-CTA-UNIFICATION-V1** | UI | 4 d | `MintCTA.{primary,secondary,tertiary,destructive}` replacing 9+ ad-hoc primitives + 10 ElevatedButton outliers. ~80 sweep sites. |
| 5 | **MVP-CITATION-GATE** | Architecture | 3 d | Post-process parser. Narrator output rejected if any number/legal claim is un-cited. Closes « ChatGPT clone » fear mechanically. |
| 6 | **MVP-DAG-INVALIDATION** | Architecture | 4 d | `inputs_hash` + `superseded_by` on every projection. Calculator refuses stale cache. Closes silent stale-projection bug. |
| 7 | **MVP-CHAT-AS-VERB** | Architecture | 5 d | Kill chat-tab. Card-actions intent bar. 3-turn cap. Source-card context propagation. |

**Total effort** ~24 days serial. Parallel-friendly chains (UI track + architecture track) compress to **~14 days critical path**.

## Dependency graph

```
                 ┌──────────────────────────┐
                 │  MVP-DESIGN-LINTS-V1 (2d)│  ← foundation; blocks UI sweep PRs
                 └────────────┬─────────────┘
                              │
       ┌──────────────────────┼─────────────────────┐
       ▼                      ▼                     ▼
┌──────────────┐    ┌──────────────────┐   ┌──────────────────┐
│ FONTS-TOKENS │    │ CTA-UNIFICATION  │   │ EXTRACTOR-V2 (3d)│
│ -V2 (3d)     │    │ (4d, ~80 sites)  │   │  (parallel)      │
└──────┬───────┘    └────────┬─────────┘   └────────┬─────────┘
       │                     │                      │
       └────────┬────────────┘                      │
                ▼                                   │
       ┌─────────────────────┐                      │
       │ CITATION-GATE (3d)  │ ◄────────────────────┘
       └────────┬────────────┘
                ▼
       ┌─────────────────────┐
       │ DAG-INVALIDATION 4d │
       └────────┬────────────┘
                ▼
       ┌─────────────────────┐
       │ CHAT-AS-VERB (5d)   │
       └─────────────────────┘
```

## 5-gate exit contract per phase (CLAUDE.md §9 + memory feedback_perimeter_5_gates)

| Gate | Description |
|---|---|
| G1 | Maestro flow under `tools/simulator/flows/maestro-perfect-set/` reproducing user-visible behavior (PASS) |
| G2 | Device verify by Julien on TestFlight OR Claude-via-Maestro on booted sim |
| G3 | dev CI green (flutter analyze, flutter test, pytest -q, schemathesis on touched routes) |
| G4 | Regression suite green (Flutter ≥ 229 model tests + new perimeter tests; backend ≥ 6047 + new) |
| G5 | LSFin banned-terms lint + accent_lint_fr.py + ARB parity (6 locales) |

## GSD workflow per phase

Each phase produces 4 artifacts in `.planning/phases/<phase>/` :

```
.planning/phases/MVP-DESIGN-LINTS-V1/
  RESEARCH.md       (gsd-phase-researcher — what exists, what to touch)
  PLAN.md           (gsd-planner — task breakdown, dependencies, atomic commits)
  EXEC.md           (gsd-executor — implementation log, deviations)
  VERIFICATION.md   (gsd-verifier — goal-backward proof of completion)
```

Plus optional :
```
  SECURITY.md       (gsd-security-auditor — for narrator/extractor phases)
  UI-SPEC.md        (gsd-ui-researcher — for UI phases)
  UI-REVIEW.md      (gsd-ui-auditor — for UI phases)
```

This is what « éviter les fenêtres dump contextuelles » means : each phase is a fresh context with bounded artifacts. No drift, no « we agreed last week ». Just the artifact stack per phase.

## Counter-arguments / risks (per memory feedback_design_panel_before_push)

1. **CTA sweep slips beyond 4d** — 80 sites is optimistic. Mitigation: pre-flight categorization Day 1 ; if >100 unique signatures, scope-cut to top-3 surfaces.
2. **CITATION-GATE retry loop blows token budget** — narrator hallucinates, parser rejects, retries. Mitigation: hard-cap retries at 1, fall back to templated « je n'ai pas la donnée ».
3. **DAG-INVALIDATION breaks existing profiles** — silent stale → loud no-projection. Mitigation: additive migration, hash nullable, calculator returns last-known-good with `staleness=high` flag.
4. **CHAT-AS-VERB user revolt** — testers expect chat tab. Mitigation: ship behind feature flag default-on, monitor `chat_overflow_turn_4`.
5. **FONTS license** — Fontshare ToS for App Store republication un-validated. Mitigation: license review gate before W1 merge ; fallback `GoogleFonts.inter` + Gambarino-only italic display.
6. **Adversarial counter-thesis** — « chat IS the product » steelman raised valid points (Cleo data, 100k token claim, capture-vs-delivery distinction). The 3-turn cap + chat-as-verb pattern is the **hypothesis being tested**, not a final design. If `chat_overflow_turn_4` fires for >40% of sessions, we walk back to chat-with-better-structure.

## Cross-cutting concerns

- **Maestro flow library** : 7 new flows (one per phase) under `tools/simulator/flows/maestro-perfect-set/`. Indexed.
- **ARB sweep** : ~132 ARB additions across 6 locales (CTA + chat-as-verb intents + citation-gate error strings). One parity check per PR.
- **Banned-terms / accent / LSFin** : pre-commit hook already wired ; narrator output additionally validated at runtime by CITATION-GATE parser.
- **Performance budget** : cold launch ≤ 2.5s at W3 + W4 close ; agent loop ≤ 30s on EXTRACTOR-V2 + CITATION-GATE eval suite.
- **Backward compat** : DAG-INVALIDATION is additive (hash nullable) ; existing profiles compute hash lazily on first read ; zero forced recomputation.

## Counter-thesis kept in record

Per the adversarial agent's steelman 2026-05-09 :
> « In Swiss financial lucidity, the CHAT IS THE PRODUCT. The wiki is the byproduct. Killing the chat to favor pre-computed dashboards reduces MINT to another budgeting app. »

This thesis is **rejected** for v1 of the milestone. Cleo data + Truebill exit support the wiki-first move. But the 3-turn cap is the falsifiable bet : if turn-4 overflow >40% in production, the milestone exits and we re-open the chat-first architecture as a post-mortem perimeter.

## Bottom line

After 4 weeks shipping this milestone, MINT is :

- A **wiki-of-life-events** as the home (cards = housing, family, retirement, FATCA-3a, debt-conso).
- Tap on a card → 3 intent buttons (« explique » / « simule » / « rassure-moi ») open a 3-turn coached overlay.
- Every number in coach output is cited (FactRef / ProjRef / LegalRef chip).
- The narrator LLM is mathematically incapable of un-cited claims.
- The design system has tokens enforced by analyzer, not by hope.
- Stale projections refuse to serve cached output.

User-facing change : chat tab disappears, cards become home, citation chips appear on every number.

Architectural change : 2 LLM roles (extractor + narrator), DAG-driven projection invalidation, post-process citation gate.

## Approval gate

This milestone is **PROPOSED**. Activates upon :
1. Julien acks the milestone scope.
2. `gsd-roadmapper` produces `.planning/ROADMAP-CHAT-AS-VERB.md` with phase order + dependencies + gates.
3. Phase 1 (`MVP-DESIGN-LINTS-V1`) opens via `gsd-phase-researcher` and produces `.planning/phases/MVP-DESIGN-LINTS-V1/RESEARCH.md`.
