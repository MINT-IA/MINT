# Phase 53 target — synthesis of 5-expert MINT panel

**Date:** 2026-05-04
**Status:** Proposed (panel synthesis; supersedes the « Phase 53 = doc scan confidence UX » projection from `SESSION-2026-05-02-03.html`)
**Decision authority:** Julien (panel synthesised by Claude in autonomous mode per `feedback_expert_panel_pattern.md`)
**Origin:** post-Phase-52.2 close-out — what ships next?

## Question

After Phase 52.1 + 52.2 fully closed (T-52-08 audit PASS, cloud-sync OFF demonstrably stops every PII write through the chat dispatcher), what is the next-phase target?

## Panel composition (5 parallel experts)

| Expert | Mandate | Verdict |
|---|---|---|
| Roadmap Sequencer | Read Handoff 2 + ROADMAP_V2 + MILESTONES; what does the roadmap actually queue? | **Vague A — `ScreenRegistry × app.dart` parity audit** (Handoff 2 ARCHITECTURE.md:215-220) |
| Engineering / Wiring Reviewer | What's the most painful broken end-to-end path a real user hits? | **`SequenceChatHandler` wiring + Tab 1 commitment surface** (Vague B+C minimum cut). 35-route gap (111 ScreenRegistry vs 146 paths). 10 SequenceTemplates with ZERO production callers. |
| Product Strategist | Highest market-leverage move; Cleo-style demo; Swiss positioning | **Chat Vivant Niveau 1+2 projection layer** (in-thread scenes for `rente_vs_capital` + `rachat_lpp`) — 5 calendar days TTM |
| Coach Intelligence Architect | Next coaching-intelligence move on solid privacy foundation | **Phase 53.1 — single chat-vivant scene injection MVP** (`MintSceneRachatLPP` end-to-end with `SceneRegistry` + `mintScene` ChatMessageKind + `show_scene` backend tool) |
| Adversarial Trust Reviewer | Journalist cold-read; quotable weak spot | **P0 hot-fix — Phase 52.3 « truth-in-crypto sweep »**: false « end-to-end encryption » claim at doc-scan auth gate in 6 locales contradicts `.planning/decisions/2026-05-02-data-residency.md:24,67` (E2EE deferred to v3.0) |

## Convergence analysis

**Two-axis split.** Experts 1 + 5 (architecture/wiring) converge on « foundation first ». Experts 2 + 4 (chat-vivant scenes) converge on « visible product moat ». Expert 3 is orthogonal — a P0 hot-fix that ships regardless.

**Cross-validation:** Expert 5 (Engineering) **independently confirms** Expert 1's gap (« 111 `ScreenEntry` rows vs 146 `path:` declarations in `app.dart` — a 35-route gap »), AND **independently confirms** Expert 4's chat-vivant gap (« `grep MintSceneRenteCapital|SceneRegistry|mintScene` returns zero hits — chat-vivant layer is 100% absent, not even a stub »).

**Expert 5 explicitly recommends sequencing:** « Defer the full chat-vivant scene/canvas layer (MintSceneRenteCapital + ChatProjectionService + ChatMessage.kind) to Phase 54 once Sequence wiring proves the contract. » This breaks the tie between « foundation » and « scenes » in favor of foundation-first.

**Walker evidence (Expert 5):** the prior walker run (`/Users/julienbattaglia/Desktop/MINT.nosync/.planning/walker/2026-05-02-092607/walker.log`) shows 4 « identical 167 076-byte size » screenshots — the « canvas open » phase captured a screenshot of the seed screen because **there is no canvas to reach**. Confirms the wiring gap is not theoretical.

## Decision (Proposed)

**Sequence three phases, ship in order, do not parallelize:**

### Phase 52.3 (NOW — ~1 day, in flight as PR #442)
**« Truth-in-crypto sweep »** — fix the false E2EE claim in 6 ARB locales + add `tools/checks/no_e2ee_overclaim.py` lint + wire into CI. **Non-negotiable.** Trust regression at the moment of consent.

### Phase 53 (next — 1 week)
**« Architecture parity + Sequence wiring + Tab 1 commitment surface »** (Handoff 2 Vague A + Vague B minimum cut)

Three sub-plans inside Phase 53:

| Plan | Scope | Owner-lens |
|---|---|---|
| **53-01** | Ship `tools/checks/screen_registry_parity.py` (mirror of Phase 32-04 `route_registry_parity.py` pattern, see `MILESTONES.md:148-157`); fill the 35-route gap in `apps/mobile/lib/services/screens/screen_registry.dart`; wire the lint into CI. **Hard exclude:** zero new screens, zero refactor of existing screens. | Expert 1 + Expert 5 convergence |
| **53-02** | Wire `SequenceChatHandler.handleStepReturn` into `coach_chat_screen.dart._handleRouteReturn` (the 2 documented injection points already commented in the handler header). Activate ONE template end-to-end: `SequenceTemplate.retirementPrep` (most-walked archetype). Coach offers it after a `retirement_choice` intent → `RoutePlanner.plan` → screen → `ScreenReturn` → `SequenceCoordinator.advance` → next prompt in chat. | Expert 5 |
| **53-03** | Add « Mes engagements & check-ins » card to `aujourdhui_screen.dart` reading `CoachProfileProvider.monthlyCheckIns` + `CommitmentService.list()`. Tap → `/coach` resumes the conversation that produced them. **Goal:** make the silent persistence of commitment / check-in tools user-visible. ARB keys × 6 locales. | Expert 5 |

**Acceptance criteria:**
- New `screen_registry_parity` lint green; 35-route gap closed (111 → 146)
- A walker run can actually drive the Coach offering retirement_prep template, navigate to the screen, return, and the chat picks up at the next sequence step (replacing the « identical 167 076-byte canvas » failure mode)
- Tab 1 surfaces at least one user-visible card from a previously-silent persistent tool (commitment OR check-in)
- Re-run T-53-XX close-out audit — load-bearing question « can a real user complete one multi-screen life-event journey end-to-end starting from chat ? » must be answered YES, demonstrably

### Phase 54 (after — 1 week, gated on Phase 53 PASS)
**« Chat Vivant scene injection »** (Handoff 2 Vague C, single-scene MVP per Expert 4):
- Implement `SceneRegistry` + `ChatMessageKind.mintScene` + `ChatProjectionService` + `ScenePayload`
- Ship ONE scene end-to-end: `MintSceneRachatLPP` (rachat is fiscal-frame, not retirement-frame — aligns with « lucidité, pas protection » pivot)
- Backend tool: `show_scene(sceneId, seed)` wired into `widget_renderer.dart` switch + `coach_tools.py` READ category
- System-prompt clause: « Quand l'utilisateur évoque rachat / impôts / LPP, émets `show_scene` au lieu d'expliquer en prose »
- Risk mitigation per Expert 4: read calculator inputs from `Pillar3aBuybackCalculator` (financial_core source of truth, NEVER recompute), apply `compliance_guard.dart` to scene payload strings, rate-limit « max 1 scene per 5 turns »

## What gets demoted

- The prior session's « Phase 53 = doc scan confidence UX » projection is **superseded**. Doc-scan UX work is a candidate for Phase 55+; current plumbing is functional.
- The « marge fiscale » framing on the in-flight branch `feature/v2.9-phase-40-marge-fiscale` is dropped (per Expert 1: « the branch name itself is misleading — touches none of marge fiscale »).
- AVS / Open Banking / e-ID integration explicitly deferred (Expert 2: « [Swiss e-ID postponed to Dec 2026], PSD3 force only 2027 — building API integration plumbing now is premature »).

## Branch hygiene action

`feature/v2.9-phase-40-marge-fiscale` — **work-extract then delete** (Expert 1):
1. Cherry-pick Plan 51-07 walker fixes (commits `0017b6f7`, `1746284c`, `e2da70f8`, `7660aa4f`) to a separate `fix/walker-archetype-determinism` PR — walker is a Phase 53 dependency.
2. Move 51-07 docs + UAT logs to `.planning/phases/51-07/` archive (not load-bearing).
3. Fold Phase 50.1.1 i18n ARB drift planning stubs into Phase 53 ARB sweep (it's small).
4. Discard stale `golden_screenshots/` PNG diffs (uncommitted noise).
5. Delete the branch after extraction.

## Sources used by the panel (web research)

- [Cleo 3.0 announcement](https://web.meetcleo.com/blog/introducing-cleo-3-0)
- [Cleo Becomes the First AI Money Coach That Speaks, Thinks and Remembers](https://www.businesswire.com/news/home/20250729690058/en/Cleo-Becomes-the-First-AI-Money-Coach-That-Speaks-Thinks-and-Remembers)
- [Sacra — Cleo revenue & growth](https://sacra.com/c/cleo/)
- [Swiss e-ID postponed to Dec 2026](https://www.biometricupdate.com/202603/why-switzerland-postponed-the-rollout-of-its-digital-id)
- [Open Banking in Switzerland overview](https://fintechnews.ch/open-banking/open-banking-in-switzerland-an-overview/32199/)
- [PSD2/PSD3 Switzerland implementation](https://www.trustbuilder.com/en/psd2-psd3-directive-future-payments-europe/)

## Internal artifacts referenced

- `~/Downloads/handoff 2/00-README.md` (« Architecture d'abord. Toujours. ») + `ARCHITECTURE.md:215-220` (Vague A definition) + `02-chat-vivant-services.md` (scene contract)
- `docs/MINT_UX_GRAAL_MASTERPLAN.md:202-211` (« ce qui reste à serrer » table — ScreenRegistry audit row 1)
- `docs/CHAT_CENTRAL_SPEC.md` (« le chat n'est pas une feature de MINT. Le chat EST MINT »)
- `tools/checks/route_registry_parity.py` (Phase 32-04 pattern to mirror for Phase 53-01)
- `apps/mobile/lib/services/screens/screen_registry.dart` (target of Phase 53-01)
- `apps/mobile/lib/services/sequence/sequence_chat_handler.dart:45` (target of Phase 53-02)
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` (target of Phase 53-03)

---

*Methodology note: 5 parallel sub-agents, each given a distinct domain mandate, required to read project artifacts and (where relevant) WebSearch with cited sources. Synthesis by Claude; decision authority remains with Julien.*

*Memory: this decision encodes the « foundation before scenes » sequencing — if any future session contemplates re-prioritizing chat-vivant scenes ahead of the architecture parity work, re-read Expert 5's walker evidence first.*
