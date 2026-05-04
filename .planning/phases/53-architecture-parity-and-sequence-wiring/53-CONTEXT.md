# Phase 53 — Architecture parity + Sequence wiring + Tab 1 commitment surface (CONTEXT)

**Status:** Drafting
**Origin:** 5-expert MINT panel synthesis at `.planning/decisions/2026-05-04-phase-53-target.md`. Convergence Experts 1 (Roadmap Sequencer) + 5 (Engineering Reviewer): the architectural foundation under Handoff 2 is unaudited, and the 10 declared `SequenceTemplate`s have ZERO production callers. Convergence Experts 2 (Product Strategist) + 4 (Coach Intelligence) on chat-vivant scenes is sequenced AFTER this phase as Phase 54 — Expert 5's explicit recommendation: « defer the full chat-vivant scene/canvas layer to Phase 54 once Sequence wiring proves the contract ».

**Goal (one sentence):** close Handoff 2 Vague A (`ScreenRegistry × app.dart` parity) + the minimum cut of Vague B (Sequence wiring) so a real user can complete one multi-screen life-event journey end-to-end starting from chat, with previously-silent persistent tools (commitments, check-ins) actually visible on Tab 1.

## Why now

Phase 52.1 + 52.2 closed the privacy foundation. Per the panel's load-bearing question for the next phase: « can a real user complete one multi-screen life-event journey end-to-end starting from chat ? » — today the answer is NO. The walker run at `.planning/walker/2026-05-02-092607/walker.log` shows 4 « identical 167 076-byte size » screenshots — the « canvas open » phase captured a screenshot of the seed screen because there is no canvas to reach. This is the « façade-sans-câblage » class Julien explicitly bans.

Without this phase, every new chat-vivant feature (Phase 54+) is built on a registry with 35 unaudited routes and a SequenceCoordinator nobody calls — exactly the « UI theatre » failure mode that bit Phase 52 (T-52-08 BLOCK).

## Scope (locked)

Three sub-plans, executed sequentially, each with its own PR:

### Plan 53-01 — `ScreenRegistry × app.dart` parity audit + lint

**Target:** close the 35-route gap (currently 111 `ScreenEntry` rows in `apps/mobile/lib/services/screens/screen_registry.dart` vs 146 `path:` declarations in `apps/mobile/lib/app.dart`).

**Deliverables:**
1. New `tools/checks/screen_registry_parity.py` — mirrors the working `tools/checks/route_registry_parity.py` pattern from Phase 32-04 (`MILESTONES.md:148-157`). Asserts every `path:` in `app.dart` has a matching `ScreenEntry` in the registry OR an explicit allow-list exclusion.
2. Wire the lint into `.github/workflows/ci.yml` as a CI gate (alongside the existing `route_registry_parity.py` step).
3. Fill the 35-route gap by adding `ScreenEntry` rows for every missing route, with `intentTag` / `behavior` / `requiredFields` / `fallbackRoute` populated per the existing pattern.
4. Coverage map produced as `.planning/phases/53-architecture-parity-and-sequence-wiring/SCREEN-REGISTRY-COVERAGE.md` — one row per route, status PASS/EXCLUDED.

**Hard exclusions:**
- Zero new screens (registry-only audit).
- Zero refactor of existing screens.
- No deletions — orphan routes are documented + flagged for separate Phase 55+ cleanup, not removed here.

### Plan 53-02 — `SequenceChatHandler` wiring end-to-end (one template)

**Target:** activate `SequenceTemplate.retirementPrep` end-to-end. The 10 templates currently have ZERO production callers; this plan ships ONE.

**Deliverables:**
1. Wire `SequenceChatHandler.handleStepReturn` into `coach_chat_screen.dart._handleRouteReturn` (the 2 documented injection points already commented in the handler header at `apps/mobile/lib/services/sequence/sequence_chat_handler.dart:45`).
2. Coach offers `retirementPrep` after a `retirement_choice` intent → `RoutePlanner.plan` → screen → `ScreenReturn` → `SequenceCoordinator.advance` → next prompt in chat.
3. Add E2E test `apps/mobile/test/integration/sequence_retirement_prep_e2e_test.dart` — drives the full loop: intent emission → screen open → screen return → next sequence step picked up in chat.
4. Walker rerun: produce a non-identical screenshot sequence proving the canvas IS reached this time (replaces the 4× 167 076-byte failure mode).

**Hard exclusions:**
- Only `retirementPrep` — the other 9 templates stay on the shelf for Phase 55+.
- No changes to template content (already declared in `models/sequence_template.dart:88-577`).
- No new tools added to the chat dispatcher.

### Plan 53-03 — Tab 1 « Mes engagements & check-ins » card

**Target:** make previously-silent persistent tools (commitments, check-ins) user-visible on the home tab. Today every `record_check_in` (`widget_renderer.dart:471`) and `show_commitment_card` (`widget_renderer.dart:652`) tool call persists silently and is then **invisible** outside the chat bubble that produced it.

**Deliverables:**
1. New widget `apps/mobile/lib/widgets/aujourdhui/commitments_and_checkins_card.dart` reading `CoachProfileProvider.monthlyCheckIns` + `CommitmentService.list()`.
2. Mount in `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` after the existing 5-card unified feed.
3. Tap → `/coach` resumes the conversation that produced them (use `chatSessionId` from the persisted record).
4. ARB keys × 6 locales: `aujourdhuiCommitmentsTitle`, `aujourdhuiCheckInsTitle`, `aujourdhuiCommitmentsEmpty`, `aujourdhuiResumeConversation`, etc. Run `flutter gen-l10n`.
5. Widget test asserting card renders for a profile with ≥ 1 commitment / check-in, hides when both empty.

**Hard exclusions:**
- No changes to commitment / check-in DATA model.
- No backend changes (read-only mobile-side surfacing).
- No design panel needed if card design follows existing `ContextualCard` pattern (Phase 6 deliverable per `MILESTONES.md`); if a NEW visual treatment is proposed, the 4-person design panel rule applies (`feedback_design_panel_before_push.md`).

## Locked decisions

### D-01 — Sequence FIRST plan: 53-01 (registry audit) before 53-02 (wiring)
Without the parity lint, Plan 53-02 might wire a sequence into a route that isn't in the registry, and the failure would be silent. 53-01 is the safety net for 53-02.

### D-02 — Plan 53-03 ships even if 53-02 needs revision
Tab 1 commitment surface is independent of sequence wiring — it reads existing persisted data. Decoupled to keep momentum if 53-02 hits unforeseen complexity.

### D-03 — Walker rerun is acceptance evidence, not pre-implementation gate
Plan 53-02's walker rerun runs at the END of the plan to PROVE the wiring works. Not at the start — the walker has known issues that Plan 51-07 was addressing on the other branch (cherry-pick those fixes per branch hygiene action below).

### D-04 — Phase 54 is gated on Phase 53 PASS
Chat-vivant scene injection (Phase 54, per Expert 4 + Expert 2 convergence) does NOT start until Phase 53 close-out audit returns PASS. The « foundation before scenes » sequencing is non-negotiable per Expert 5's walker evidence.

### D-05 — « marge fiscale » framing is dropped
The in-flight branch `feature/v2.9-phase-40-marge-fiscale` is misleading-named and touches none of « marge fiscale ». Per Expert 1: work-extract Plan 51-07 walker fixes (commits `0017b6f7`, `1746284c`, `e2da70f8`, `7660aa4f`) to a separate `fix/walker-archetype-determinism` PR (Phase 53 dependency), then delete the branch. « Marge fiscale » belongs in a future phase tied to the Decision Canvas template.

## Acceptance criteria (Phase 53 close-out)

1. **Parity:** `screen_registry_parity.py` lint exits 0; the 35-route gap is closed (111 → 146); CI gate active.
2. **Sequence wiring:** a walker rerun drives Coach offering `retirementPrep`, navigates to the screen, returns, and the chat picks up at the next sequence step. Screenshots are NOT identical-size.
3. **Tab 1 visibility:** at least one user-visible card on Aujourd'hui surfaces a previously-silent persistent tool (commitment OR check-in).
4. **Tests:** `flutter analyze` clean on touched files. New E2E test green. Existing test suites still green.
5. **Compliance lints:** `accent_lint_fr` + `no_e2ee_overclaim` + `no_legal_admission` + `check_banned_terms` all green.
6. **Close-out audit:** load-bearing question « can a real user complete one multi-screen life-event journey end-to-end starting from chat ? » must be answered YES, demonstrably, with walker evidence.
7. **HTML evidence:** `53-VERIFICATION-REPORT.html` updated on every PR landing in this phase.

## Out of scope (deferred)

- Chat-vivant scene injection (`MintSceneRachatLPP`, `MintInlineInsightCard`, `ChatProjectionService`, `ChatMessageKind.mintScene`) — Phase 54
- Doc scan confidence UX — Phase 55+ (the SESSION-2026-05-02-03 projection)
- AVS / Open Banking / Swiss e-ID integration — v2.13+ (e-ID postponed to Dec 2026, PSD3 force only 2027)
- The 9 unactivated `SequenceTemplate`s beyond `retirementPrep` — Phase 55+
- Orphan-route cleanup — Phase 55+ (registry audit documents but does not delete)
- BYOK copy audit (`byokPrivacyBody` and friends) — fold into Phase 55+ if the BYOK surface is still routable; currently flag-gated off per memory rule

## Branch hygiene action (do BEFORE Phase 53-01)

`feature/v2.9-phase-40-marge-fiscale`:
1. Cherry-pick walker fixes (commits `0017b6f7`, `1746284c`, `e2da70f8`, `7660aa4f`) to a separate `fix/walker-archetype-determinism` PR — merge BEFORE Plan 53-02 starts (walker is its acceptance evidence).
2. Move 51-07 docs + UAT logs to `.planning/phases/51-07/` archive (not load-bearing).
3. Fold Phase 50.1.1 i18n ARB drift planning stubs into Phase 53-01 ARB sweep.
4. Discard stale `golden_screenshots/` PNG diffs.
5. Delete the branch after extraction.

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Sequence wiring exposes broken `RoutePlanner.plan` calls (Expert 5: « only 1 production call site, used by 1 widget builder ») | Plan 53-01's parity lint catches missing entries before 53-02 tries to route. If `RoutePlanner` itself is broken, scope `RoutePlanner` repair as Plan 53-04 — do NOT silently expand 53-02. |
| Walker still produces identical screenshots after 53-02 (e.g. simulator sandbox issue, not code issue) | Manual device walkthrough fallback (per `feedback_device_gates.md`: « sim + idb are wired so Claude does device walkthroughs autonomously »). If both fail, halt and surface to Julien — do NOT fake the evidence. |
| Tab 1 card renders empty for fresh-test users → looks broken | Empty-state ARB string + dev-only seed data in walker scenarios. Hide the card entirely when both data sources are empty (no « no data » text — silent absence). |
| Plan 53-01 ARB sweep drifts the 6-locale parity (FR has @meta entries normally) | Run `flutter gen-l10n` after every ARB edit; assert key counts after = key counts before for each locale. |
| Cherry-pick conflicts on the walker fixes | Each cherry-pick is a single, focused commit on the walker subdirectory. If conflicts emerge, drop the offending commit and rewrite manually — do NOT carry the whole branch forward as-is. |

## References

- Decision artifact: `.planning/decisions/2026-05-04-phase-53-target.md`
- Handoff 2: `~/Downloads/handoff 2/00-README.md` + `ARCHITECTURE.md:215-220` + `02-chat-vivant-services.md`
- Masterplan: `docs/MINT_UX_GRAAL_MASTERPLAN.md:202-211`
- Existing parity lint pattern: `tools/checks/route_registry_parity.py`
- Registry: `apps/mobile/lib/services/screens/screen_registry.dart`
- Sequence handler: `apps/mobile/lib/services/sequence/sequence_chat_handler.dart:45`
- Aujourd'hui screen: `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart`
- Walker evidence to replace: `.planning/walker/2026-05-02-092607/walker.log`
