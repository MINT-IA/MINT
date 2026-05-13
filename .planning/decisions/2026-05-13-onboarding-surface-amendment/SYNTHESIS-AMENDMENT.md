---
date: 2026-05-13
status: Proposed
authors: Julien Battaglia + Claude (Product Leader)
panel: surface-amendment (1 office-hours + 1 adversarial spec-reviewer subagent)
supersedes: —
superseded_by: —
description: Surface-axis amendment to the 2026-05-08 6-panel coach-onboarding SYNTHESIS — substance preserved verbatim, surface pivots from 6 OTP-style routes to chat-with-chips on MintChatOverlay (Pattern B) to reconcile with the chat-as-verb pivot shipped Phase 96 (#564) + #582.
related:
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
  - .planning/decisions/2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md
  - ~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-97.5-w3-t4-stripped-p004-regression-flow-design-20260513-082454.md
  - ~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-onboarding-v2-step01-intent-design-20260512-231610.md
---

# Onboarding V2 surface amendment — chat-with-chips on MintChatOverlay (Pattern B)

## TLDR

We pivot the Onboarding V2 SURFACE from « 6 OTP-style routes » to « chat-with-chips inside the existing `MintChatOverlay` widget » because MINT's post-onboarding surface became the chat overlay between 2026-05-08 (SYNTHESIS authored) and 2026-05-13 (this amendment) ; the SYNTHESIS substance (5 facts, 0 LLM tokens, BRACKET revenu, archetype-before-LLM, Premier Éclairage final, 5 adversarial QA tests) is preserved verbatim.

## Context

The 2026-05-08 6-panel SYNTHESIS at [`SYNTHESIS.md`](../2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md) decided the onboarding redesign on two axes simultaneously :

- **Substance axis** — 5 facts (intent + age + canton + statut + BRACKET revenu) collected via chips, 0 LLM tokens until Premier Éclairage, archetype detected pre-LLM via `updateFromSmartFlow()`, voice anti-promiscuous, ConfidenceBand 4-axis, LSFin BRACKET-not-CHF compliance, 5 adversarial QA tests (O5).
- **Surface axis** — 6 dedicated OTP-style routes (one per onboarding step : intent / age / canton / statut / revenu / éclairage — full ASCII URL paths in parent SYNTHESIS), each its own screen with eyebrow Supreme letterspaced + hero Gambarino italique 56-72px + sub anti-promiscuous + chips/picker + CTA. Redirect logic in `app.dart:283-301`. Architecture in [`STUB.md`](../2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md).

Between 2026-05-08 and 2026-05-13, MINT's post-onboarding surface changed under the panel's feet :

- `c7920464` (Phase 96, PR #564, 2026-05-09) — chat-as-verb pivot landed. Tap « Explique-moi » / « Rassure-moi » on a card opens `MintChatOverlay` modal. Chat became the verb of the product.
- `abb1b4e4` (Phase 97.5 W2 P004, PR #582, 2026-05-12) — `MintChatOverlay` populated-on-open shipped. Opener `NarrativeSleeve` paints synchronously in `didChangeDependencies`. Zero LLM call. Overlay's body is non-empty on first frame.
- `9050474d` (Phase 97.5 W3 T4 stripped, 2026-05-13) — P004 « populated-on-open » Maestro regression lock. The behaviour is now mechanically protected.

The 2026-05-08 SYNTHESIS picked « 6 OTP routes » on the explicit footing that the post-onboarding surface was generic chat (Status Quo §C4 of SYNTHESIS implied this). After Phase 96 + P004 shipped, the post-onboarding surface is **the chat overlay itself, populated on open**. The 6 OTP routes upstream of one chat overlay create a product seam : user experiences MINT as « form-fill onboarding → then chat ».

Julien surfaced the contradiction in office-hours 2026-05-13 :

> « Chat-with-chips : Mint parle, user tape chips, 0 token LLM, même surface chat-as-verb que post-onboarding coach. »

The contradiction is the trigger for this amendment.

## Decision

We adopt **Pattern B** as the Phase 97.6 First-Use Golden Path surface :

- **`MintChatOverlay` is extended with a SCRIPTED ONBOARDING MODE** driven by a new `OnboardingScriptedSeed` service.
- The widget renders a sequence of 5 scripted (Mint-message, chip-set) turns + 1 final (Premier Éclairage card-as-bubble) turn, all inside the same overlay surface the user lives on afterward.
- Chip taps plumb through `updateFromSmartFlow()` at `apps/mobile/lib/providers/coach_profile_provider.dart:688` identically to the OTP-screen alternative would have.
- The 2026-05-08 SYNTHESIS substance is preserved verbatim : 5 facts, 0 LLM tokens until Premier Éclairage, BRACKET revenu, archetype-before-LLM via `updateFromSmartFlow()`, anti-promiscuous voice, Premier Éclairage with `EnhancedConfidence` 4-axis, the 5 adversarial QA tests (O5) — all carry forward unchanged.
- The 2026-05-08 SYNTHESIS surface conclusion (6 OTP routes) is **superseded** by this amendment.

### Implementation shape (summary — full detail in [design doc](~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-97.5-w3-t4-stripped-p004-regression-flow-design-20260513-082454.md))

The full §Required Widget Surface Refactor lives in the design doc. Headline items :

- **Constructor variant** : `MintChatOverlay({SerializedCardContext? sourceCard, String? intent, OnboardingScript? script})` with assertion that exactly one of `(sourceCard + intent)` or `script` is non-null. Existing call sites (`cap_du_jour_banner.dart:69`, `confidence_score_card.dart:227`, `chat_as_verb_demo_screen.dart:142`) untouched in their call shape ; regression-protected via the tonight-locked P004 Maestro flow.
- **New turn type** : `_ChipTurn extends _ChatTurn` with `chips: List<ChipDescriptor>`, `onChipTap`, `disabled`.
- **Scripted driver state machine** replaces the `_openerSeeded` single-shot guard in onboarding mode.
- **Launch hook** in `app.dart` / `mint_shell.dart` post-login first-frame : if `!coachProfile.hasMinimumViableFacts`, call `MintChatOverlay.show(... script: OnboardingScript.standard(), isDismissible: false)`.
- **Net-new code** ~450 LOC : `hasMinimumViableFacts` getter on `CoachProfile` (~10 LOC), `OnboardingScriptedSeed` service + `OnboardingScript` data class (~150 LOC), `_ChipTurn` variant (~80 LOC), scripted driver state machine (~120 LOC), constructor variant + assertions + null-safety (~30 LOC + tests), launch hook (~20 LOC), input-disable + cap-bypass + swipe-lock (~40 LOC).
- **Honest effort estimate** : ~9-12 working days (Pattern A baseline ~10-14 days ; delta ~25%, not the optimistic ~40% an earlier draft of the design doc claimed before the spec-review subagent verified the widget code).

### What is NOT in scope for this amendment

- **Signup / authentication surface** — unchanged. First-Use Golden Path runs post-login. The Maestro golden flow exercises signup as a precondition turn, but signup itself is not redesigned in Phase 97.6.
- **Onboarding V2 perimeter STUB** at [`2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md`](../2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md) is superseded by Phase 97.6 RESEARCH (to be opened post-v2.9 ship). The perimeter STUB stays archived as historical context.
- **Anon `/onb` 8-step shell refactor** — separate perimeter, not coupled to this amendment.
- **D10 Hero-Plan modal + nLPD register-of-processing** — separate compliance perimeters per SYNTHESIS §O4 gaps.

## Counter-arguments and data gaps

### What does the strongest opposing view say ?

**Steel-man for staying with Pattern A (6 OTP routes)** :

The 2026-05-08 6-panel SYNTHESIS converged 5/6 on structured-first AVANT LLM. The convergence was strong because it was rigorous — token economy, LSFin compliance, archetype safety, behavioral retention, competitive wedge, UX hierarchy all pointed the same direction. Re-litigating the surface 5 days later on the strength of a single office-hours intuition is exactly the kind of premature re-decision that turns a wiki into noise.

Three concrete points the opposing view would make :

1. **Visual hierarchy degradation is real.** Pattern A's Gambarino italique 56-72px screen-hero is one of the load-bearing aesthetic choices of MINT v2 (PDF page 5, grammar rule #2 « italique : 2 écrans max »). Demoting it to bubble-line scale dilutes the brand impression in the user's first 60 seconds. A chat-bubble cannot do what a dedicated screen does for hierarchy.
2. **The « surface seam » framing is a hypothesis, not a measurement.** Pattern B claims users will feel a seam between OTP-onboarding and chat-coach. But MINT has zero TestFlight tester drop-off data on this seam. The Cleo / Pi.ai / Replika analogy is suggestive but not measured for Swiss financial coaching users. Pattern A might ship and produce zero observable seam-related drop-off ; we don't know.
3. **Widget surface refactor on a P004-regression-locked file is risk.** Tonight (2026-05-13) `9050474d` regression-locked `MintChatOverlay`'s populated-on-open behaviour via Maestro. Pattern B adds a constructor variant + new turn type + state machine to the same file. Every line of refactor risks breaking the P004 contract, which is a v2.9 ship-gate dependency. Pattern A's 6 separate widget files isolate the blast radius.

The opposing view's bottom line : *« Ship Pattern A as the 2026-05-08 panel decided. If the seam is real, measure it in v2.10 TestFlight ; if not, the surface coherence intuition was wrong. »*

### What does this source not address ?

**Empirical gaps in this amendment** :

- **Zero MINT-internal data on onboarding D7 retention or seam-related drop-off.** All Pattern B advantage claims rest on (a) the analogy with Cleo / Pi.ai / Replika chat-onboarding products, (b) the architectural principle « medium is the message », (c) Julien's product-felt-object intuition. None of these is a measurement on MINT's actual user population.
- **Zero published benchmark for chat-with-chips vs OTP-style onboarding in finance / coach apps.** The 2026-05-08 SYNTHESIS O6 (competitive intel) cited Cleo / Lunchmoney / Monarch but did not rank chat-onboarding-conversion-rate vs OTP-onboarding-conversion-rate. Externally that data may exist (Userpilot, Mixpanel benchmarks) ; we did not search before this amendment.
- **The « 9-12 working days » estimate is a back-of-envelope per the design doc §Net-new code breakdown, not a tasks-with-pessimistic-margins plan.** Honest enough for an ADR but not enough for a Phase 97.6 plan ; the GSD planner agent must produce that breakdown.
- **No iPhone SE 4.7« display pre-mock yet of (a) Premier Éclairage card-as-bubble, (b) intent step 6-chip row.** OQ-03 + OQ-04 in the design doc are explicit about this gap.
- **No measurement of the chat-as-verb pivot's effect on retention.** Phase 96 (#564) shipped 2026-05-09 ; we have ~4 days of post-merge data and no statistically meaningful retention signal yet. Pattern B's premise « MINT's medium is chat post-Phase-96 » is true at the code-shipped level but not yet validated at the user-behaviour level.
- **No survey of the 5 panel agents O1-O5 of the 2026-05-08 SYNTHESIS** asking them whether their verdict on Pattern A would change given the chat-as-verb pivot. That's a panel re-litigation Julien explicitly declined in D1 of office-hours 2026-05-13. The decline is reasonable (« the chat-as-verb pivot has already settled the surface axis in production code ») but it leaves the panel verdict reasoning frozen at 2026-05-08.

### What would change this conclusion ?

Concrete future signals that would force re-litigation of this amendment :

- **v2.10 TestFlight tester data shows Pattern B onboarding completion rate < 60%** (i.e. ≥40% drop-off in the 60-second flow). Re-open the surface axis ; consider partial fallback to Pattern A for high-drop-off steps.
- **Pattern B's widget surface refactor breaks the P004 Maestro regression flow** post-implementation. Re-evaluate whether Pattern B can land cleanly on a P004-protected widget or whether `MintChatOverlay` should be cloned into a separate `MintOnboardingChatOverlay` widget. Branch-and-isolate strategy as fallback.
- **`kChatMaxTurns = 3` server-side cap (`turn_cap.py:MAX_TURNS_PER_CARD`) turns out to apply to onboarding mode AND cannot be bypassed cleanly.** Re-evaluate whether onboarding's 6 turns must fold into 3 (probably non-viable per substance requirements) or whether a separate onboarding endpoint is needed.
- **Phase 97.6 W1 design pass produces a Premier Éclairage card-as-bubble layout that cannot fit iPhone SE without breaking grammar rule #4 (chiffre nu interdit) or #1 (1 idée / écran).** Re-evaluate whether Premier Éclairage stays in-overlay or extracts to a dedicated screen at the end of the chat sequence (hybrid surface).
- **A second-opinion panel run on this amendment** (e.g. spawning 3 fresh experts : chat-onboarding benchmark, MINT architecture coherence, adversarial QA) returns « Pattern A wins » with new data. We did not spawn this panel in office-hours 2026-05-13 (declined in D1 favour of preliminary-call + spec-review subagent). Could be invoked post-v2.9 ship as a Phase 97.6 RESEARCH input.

## Sources

- [`.planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md`](../2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md) — parent panel synthesis, substance preserved verbatim
- [`.planning/decisions/2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md`](../2026-05-08-perimeter-mvp-onboarding-v2-auth-first/STUB.md) — Pattern A perimeter STUB, superseded by Phase 97.6 RESEARCH
- [`~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-97.5-w3-t4-stripped-p004-regression-flow-design-20260513-082454.md`](file://~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-97.5-w3-t4-stripped-p004-regression-flow-design-20260513-082454.md) — 2026-05-13 office-hours design doc, full Pattern B blueprint including §Required Widget Surface Refactor + §OnboardingScriptedSeed interface sketch + 10 Decisions + 4 Open Questions
- [`~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-onboarding-v2-step01-intent-design-20260512-231610.md`](file://~/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-onboarding-v2-step01-intent-design-20260512-231610.md) — 2026-05-12 office-hours design doc, parent Path C decomposition (v2.9 + 97.6 = v2.10)
- `apps/mobile/lib/widgets/mint_chat_overlay.dart` — surface that Pattern B targets, verified code-level facts (constructor, launch path, single-shot opener, no chip-turn type, turn-cap, input-bar, swipe-dismiss) 2026-05-13
- `apps/mobile/lib/providers/coach_profile_provider.dart:688` — `updateFromSmartFlow()` reuse target, verified 2026-05-13
- PR #564 (Phase 94-97 chat-as-verb pivot) merged 2026-05-09
- PR #582 (Phase 97.5 W2 P004 MintChatOverlay populated-on-open) merged 2026-05-12T19:25:44Z
- PR #585 (DRAFT, shelved — Pattern A Step 01 INTENT scaffold) — to be closed as part of D-08 follow-up
- Commit `9050474d` (Phase 97.5 W3 T4 stripped — P004 populated-on-open Maestro regression lock) 2026-05-13

## Status & follow-up

- **Implementation tracking** : Phase 97.6 « MINT 2 First-Use Golden Path » to be opened post-v2.9 Internal Alpha ship (~2026-05-26). GSD RESEARCH agent reads both this amendment AND the parent SYNTHESIS. Working branch `feature/97.6-w1-onboarding-script-seed` to be created from D-08 cherry-pick of PR #585's 9 ARB keys.
- **Re-litigation triggers** : the 5 « what would change this conclusion » signals above. Concrete future-signal threshold to re-open this ADR.
- **Dependent ADRs** : none yet. If Phase 97.6 RESEARCH surfaces a fallback strategy (e.g. clone `MintChatOverlay` into `MintOnboardingChatOverlay` to isolate refactor blast-radius), file a follow-up ADR rather than amending this one.
- **Wiki lint posture** : counter-arguments + data gaps sections populated per Karpathy practice 3 + `tools/checks/wiki_lint.py` hard requirement. INDEX.md regen via `python3 tools/checks/wiki_lint.py index` after this file lands.
- **Status** : Proposed. Promote to Decided after Phase 97.6 W1 design pass closes OQ-01 (chip-row layout on iPhone SE) and OQ-02 (`kChatMaxTurns` interaction with backend) without invalidating the surface choice.

---

*Amendment authored 2026-05-13 in /office-hours session 6. Spec-reviewer subagent caught 3 BLOCKING factual claims in the parent design doc (« overlay already opens on app launch » false, « `hasMinimumViableFacts` reused » false, « 6-9 day estimate » optimistic) ; all fixed before this ADR was filed. The amendment is therefore based on a design doc that has been factually audited against the codebase rather than an unverified first draft.*
