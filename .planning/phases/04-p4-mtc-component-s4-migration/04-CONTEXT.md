# Phase 4 — L1.2a MintTrameConfiance (MTC) Component + S4 Migration — CONTEXT

**Created:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Requirements:** MTC-01, MTC-02, MTC-03, MTC-04, MTC-05, MTC-06, MTC-07, MTC-08, MTC-09, TRUST-01, TRUST-03
**Depends on:** Phase 1 (unblockers), Phase 2 (AUDIT-01 + AAA tokens + VoiceCursorContract), Phase 3 (S4 DELETE/KEEP/REPLACE list)

---

## BLOCKED ON: T1 VZ Teardown (NOT BLOCKING — soft request)

The MTC API can be designed and built from MINT's internal doctrine alone. The plans below execute end-to-end without external input. **However**, the only known-great Swiss reference for confidence/trust UI is **VZ Finanzplanung**. Without VZ screenshots, MTC v1 is derived purely from MINT principles (anti-shame, weakest-axis, hypotheses footer, MUJI 4-line). With them, the executor calibrates against an existing visual grammar.

**The ask** — Julien provides 5 screenshots, captured from the live VZ app or website, into `.planning/phases/04-p4-mtc-component-s4-migration/refs-vz/` with the filenames below:

| # | File | What to capture |
|---|---|---|
| 1 | `vz-01-landing-trust.png` | VZ landing page or logged-out home — any place a trust signal, certification badge, FINMA reference, or "verified by" appears. The marketing surface where they tell you they're trustworthy before you've seen any number. |
| 2 | `vz-02-projection-uncertainty.png` | A projection or retirement screen that shows uncertainty (a band, a range, a +/- delta, an "estimated" label, anything that says "we are not certain"). |
| 3 | `vz-03-comparison-confidence.png` | A product comparison, arbitrage, or "vs" screen where each option carries a confidence indicator (data freshness, source quality, calculation reliability). |
| 4 | `vz-04-risk-band.png` | A risk profile, scenario, or stress-test screen that renders bands/ranges (not a single number). The "best case / base case / worst case" surface. |
| 5 | `vz-05-we-dont-know.png` | Any "we don't know yet" moment in VZ UX — a missing-data prompt, an empty state, a "please complete X to see Y" pattern. If VZ has no such moment, capture the screen where you'd expect it and label it `vz-05-no-such-moment.png`. |

**Disposition:** the executor on Plan 04-01 checks `refs-vz/` at the start of the task. If 5 screenshots are present → reference them when making visual decisions on bloom timing, axis density, footer rendering, and `MTC.Empty` state. If absent → execute purely from MINT doctrine (`feedback_anti_shame_situated_learning.md` + DESIGN_SYSTEM.md + this CONTEXT.md). The plan does not gate on the screenshots; it gates only on Phase 2 + Phase 3 deliverables.

---

<domain>
Build the single confidence rendering primitive for MINT — `MintTrameConfiance` (MTC) — and ship it as the first consumer on S4 (`response_card_widget.dart`). Establish the golden test infrastructure (dual-device `screen_pump.dart` helper) that downstream phases (8a 11-surface migration, 8b microtypo, 8c polish pass, 9 alert) reuse.

This phase is **production-code-bearing**. Three plans, three commits minimum, atomic per concern.
</domain>

<decisions>

## D-01 — Component name + path (LOCKED, deviation from REQUIREMENTS-listed path)

**Name:** `MintTrameConfiance` (per REQUIREMENTS MTC-01 wording, brief v0.2.3 §L1.2). Public class `MintTrameConfiance`. Family acronym `MTC` used in code comments only. The legacy name `MintTrustChip` / `MintTrustBand` from `docs/AUDIT-01-confidence-semantics.md` is **rejected** — that doc was written before the brief locked "MintTrameConfiance" as the user-facing concept name. The audit doc remains accurate semantically (one widget absorbs the listed sites); only the class name changes.

**Path:** `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` (per REQUIREMENTS MTC-01: `lib/widgets/trust/`, despite the user prompt suggesting `lib/widgets/mtc/`). Rationale: `widgets/trust/` is the concept folder Phase 8a will populate with siblings (`extraction_confidence_chip.dart`, `data_block_confidence_bar.dart` — both called out in AUDIT-01 as sibling components). Single folder = single mental model.

No `.g.dart` codegen for MTC itself. The voice cursor contract is the only generated file in this area.

## D-02 — Constructor surface (LOCKED)

Three named constructors per REQUIREMENTS MTC-01 + one empty state per MTC-02:

```dart
MintTrameConfiance.inline({
  required EnhancedConfidence confidence,
  required BloomStrategy bloomStrategy,
  VoiceLevel? audioTone,        // optional, defaults to null = no audio binding
  bool isTopOfList = false,     // consumed by BloomStrategy.onlyIfTopOfList
  Key? key,
});

MintTrameConfiance.detail({
  required EnhancedConfidence confidence,
  required BloomStrategy bloomStrategy,
  required List<String> hypotheses,  // MTC-07: max 3, enforced via assert in debug
  VoiceLevel? audioTone,
  Key? key,
});

MintTrameConfiance.audio({
  required EnhancedConfidence confidence,
  required VoiceLevel audioTone,     // required here, this is the audio surface
  required BloomStrategy bloomStrategy,
  Key? key,
});

MintTrameConfiance.empty({
  required ConfidenceAxis missingAxis,   // MTC-02: 4-axis enum, the weakest
  required String enrichCtaKey,          // ARB key for the prompt
  Key? key,
});
```

**Hard rule (MTC-08):** no public `score: double` getter. The component never exposes a sortable scalar. Compliance — prevents the renderer from being used for ranking/comparison surfaces.

The `EnhancedConfidence` model (4-axis: completeness × accuracy × freshness × understanding) already exists in the financial_core layer; MTC consumes it as-is. No model changes in this phase.

## D-03 — `BloomStrategy` enum location (LOCKED)

Co-located with the component in `mint_trame_confiance.dart` (NOT in the voice cursor contract file). Rationale: bloom is a presentation concern, not a tonal contract. The voice cursor contract stays focused on N1-N5 + gravity + relation; widening it to a presentation enum would break its single-responsibility.

```dart
enum BloomStrategy {
  firstAppearance,    // Standalone surfaces (S4 detail, hero zones). Bloom every time the widget mounts fresh.
  onlyIfTopOfList,    // Feed contexts (ContextualCard ranked home). Bloom only when isTopOfList == true. 60ms stagger handled by parent feed.
  never,              // Reduced-motion explicit opt-out, or already-seen-this-session caching by parent.
}
```

PERF-05 lint (deferred to Phase 12) will eventually enforce `BloomStrategy` is always passed explicitly. In Phase 4 it's `required` in the constructor signature, which gives compile-time enforcement now without needing the lint.

## D-04 — Confidence axis visualization (LOCKED, anti-shame override)

**No 4-bar visualization. No combined scalar number rendered.** The MTC inline surface renders:

1. A short **trame pattern** (a horizontal track at fixed height 4dp) whose visual density encodes the WEAKEST axis only — not all four. Three states: `dense` (weakest ≥ 0.7), `medium` (0.4-0.7), `sparse` (< 0.4 → triggers `MTC.empty()` instead at the top-of-card check). The track is rendered via `CustomPaint` with a single deterministic painter; ≥ 3 unit tests per state.
2. A **one-line summary string** from `oneLineConfidenceSummary(EnhancedConfidence) → String` (MTC-05). 24 ARB strings = 4 weakest-axis variants × 6 languages. The string surfaces the weakest axis only ("Calculé sur des hypothèses encore vagues sur ton AVS." not "completeness 0.8, accuracy 0.4, freshness 0.9, understanding 0.6").
3. **No headline number.** Per AESTH-03 (Aesop rule): the sentence carries the rhythm, not the number.

The `.detail()` constructor adds the hypotheses footer (TRUST-01: max 3 lines, visible at rest, user-editable in a future phase — Phase 4 ships read-only). The `.audio()` constructor adds a single semantic label suitable for screen-reader/audio rendering, no painter.

This is the doctrine. If Julien provides VZ screenshots in `refs-vz/` AND VZ uses a per-axis bar pattern that calibrates with anti-shame, the executor MAY add a debug-mode 4-axis breakdown gated behind `kDebugMode` only — never in release builds. Default: weakest-axis-only, full stop.

## D-05 — Reduced-motion behavior (LOCKED)

Per MTC-03 + ACCESS-07:

- Default bloom: 250ms ease-out, opacity 0→1, scale 0.96→1.
- `MediaQuery.disableAnimations == true` OR `BloomStrategy.never` → fallback: 50ms opacity-only fade-in (no scale, no ease curve, just `Opacity` animated linearly). The element STILL appears — never instant-pop, never invisible. The 50ms gives screen readers a chance to fire `SemanticsService.announce()` cleanly.
- `BloomStrategy.onlyIfTopOfList && isTopOfList == false` → no bloom at all, the element renders in its final state on first frame.

Patrol golden snapshots at t=0ms / t=125ms / t=250ms for the default path; one snapshot at t=50ms for the reduced-motion path.

## D-06 — Voice cursor consumption (LOCKED)

MTC `.audio()` constructor takes a `VoiceLevel` parameter (the resolved level from `voice_cursor_contract.dart`). The audio rendering adapts its semantic label intensity to the level — N1/N2 use a calmer phrasing variant, N3 the neutral default, N4/N5 the direct variant. **There is no skin/color shift on voice level** (anti-feature in REQUIREMENTS line 187 — "Visuel reste calme"). The level only affects the audio semantic label and the phrasing of the one-line summary, not the trame pattern, not the color, not the bloom timing.

The `.inline()` and `.detail()` constructors accept an `audioTone` parameter (nullable). When non-null, the same phrasing adaptation applies to the rendered one-line summary string. When null, MTC uses the default-N3 phrasing variant. This makes MTC tonally consistent across its 3 surfaces without forcing every caller to resolve a level.

MTC does NOT call `resolveLevel()` itself — the caller resolves the level upstream (closer to the conversation context) and passes it in. MTC is a pure widget; no service lookup, no provider read.

## D-07 — S4 migration scope (LOCKED)

`response_card_widget.dart` currently does NOT render any confidence UI (verified by grep — `confidence`, `trust`, `axis`, `EnhancedConfidence` all absent in lib/widgets/coach/response_card_widget.dart). Therefore the S4 migration is an **introduction**, not a replacement:

1. Add a new `MintTrameConfiance.inline(...)` slot inside the response card body, positioned per the MUJI 4-line grammar from AESTH-07 (line 4 of the 4-line response is the MTC). The card receives an optional `EnhancedConfidence?` parameter via its existing constructor; if non-null AND the response is a calculation/projection answer, render the MTC slot. If null OR a non-projection answer (chat reply, education content), no MTC.
2. The Phase 3 audit doc's S4 DELETE/KEEP/REPLACE list is consulted as the **pruning input** — any S4 element flagged DELETE in `docs/AUDIT_RETRAIT_S0_S5.md` for `response_card_widget.dart` is removed in this same plan (Plan 04-02). This prevents Phase 8a from being the only place pruning happens; Phase 4 honors the audit on its own surface.
3. The card's caller (`coach_chat_screen.dart` or wherever response cards are mounted) is updated minimally to pass `confidence: response.confidence` when available. This is a 1-3 line change at the call site, NOT a deeper refactor.

**Out of scope for Plan 04-02:** the other 11 MTC surfaces (Phase 8a), the hypotheses footer real-data wiring (Phase 4 ships hypotheses footer with MTC.detail constructor accepting `List<String>`, but S4 uses `.inline()` which has no footer — the footer infrastructure is shipped, the live wiring lands in Phase 8a per surface), the audio surface live wiring (no caller in Phase 4).

## D-08 — Golden test coverage (LOCKED)

Per MTC-09 + Plan 04-03 deliverables. The golden infrastructure ships with **5 baseline goldens** total, all on S4:

1. `s4_mtc_default.png` — S4 with MTC.inline, default bloom complete (t=250ms), iPhone 14 Pro 390×844 @ 3.0x.
2. `s4_mtc_default_a14.png` — same content, Galaxy A14 1080×2408 @ 2.625x.
3. `s4_mtc_low_confidence.png` — S4 with `MTC.empty(missingAxis: completeness)`, iPhone.
4. `s4_mtc_reduced_motion.png` — S4 with MTC.inline, `MediaQuery.disableAnimations: true`, t=50ms snapshot, iPhone.
5. `s4_no_mtc.png` — S4 control: a non-projection response with `confidence: null`, no MTC slot rendered, iPhone. Proves the slot is conditional, not always-on.

Bloom-progress goldens (t=0/125/250ms) are **unit-test** assertions on the `Animation<double>` value, NOT golden image diffs. Image diffing 3 frames of an animation creates flake risk and adds little value over asserting the curve.

The 4 confidence-level variants requested in the user prompt (low / medium-low / medium-high / high) are tested as **unit tests** on the `_TramePainter` deterministic state machine (`dense` / `medium` / `sparse` → triggers empty), NOT as goldens. Same rationale: golden image diffs on a 4dp track are flake-prone.

## D-09 — Test count delta (LOCKED expectation, executor verifies)

Plan 04-01 (component build): **+45 tests minimum**.
- 12 unit tests on `BloomStrategy` enum + selector logic
- 12 unit tests on `_TramePainter` (3 states × 4 axis sources)
- 8 unit tests on `oneLineConfidenceSummary` (4 weakest axis × ARB key resolution)
- 6 widget tests on the 4 constructors (inline/detail/audio/empty)
- 4 widget tests on reduced-motion fallback (Animation value at t=0/25/50ms + `disableAnimations` true)
- 3 semantics tests on `SemanticsService.announce` firing exactly once on state change (MTC-06)

Plan 04-02 (S4 migration): **+12 tests minimum**.
- 4 widget tests on `response_card_widget` rendering MTC slot conditionally (with/without confidence, projection/non-projection)
- 3 widget tests on the existing S4 elements still rendering (no regression)
- 3 ARB key resolution tests for the new `oneLineConfidenceSummary` ARB strings (4 keys × 6 langs verified at least once)
- 2 semantics tests on the response card with MTC mounted

Plan 04-03 (golden infra): **+5 golden snapshot files** + **+3 helper unit tests on `screen_pump.dart`**.

**Pre-Phase-4 baseline:** 9134 Flutter tests (per Phase 2 SUMMARY). **Post-Phase-4 floor:** 9134 + 45 + 12 + 3 = **9194 tests**. Phase gate: `flutter test` reports ≥ 9194 passing. Silent test drop = red.

## D-10 — Hardcoded color audit (LOCKED)

`mint_trame_confiance.dart` MUST contain ZERO `Color(0xFF...)` literals. Every color comes from `MintColors` (the 12-token palette + the 6 AAA tokens shipped in Phase 2). The trame painter uses `MintColors.textMutedAaa` for the dense state, `MintColors.textSecondaryAaa` for medium, and falls through to the empty state for sparse. The audio constructor uses `MintColors.textPrimary` for the semantic label only.

CI grep gate (added in Plan 04-01): `git grep 'Color(0x' apps/mobile/lib/widgets/trust/` returns 0.

## D-11 — Semantics + liveRegion (LOCKED)

Per MTC-06 + ACCESS-08:

- `MintTrameConfiance.inline()` and `.detail()` wrap their root in a `Semantics(liveRegion: false, label: ..., child: ...)`. liveRegion is FALSE for the visual trame — we don't want screen readers re-announcing on every rebuild during scroll.
- `SemanticsService.announce(label, TextDirection.ltr)` fires **exactly once** on the transition from "no MTC mounted" → "MTC mounted with this confidence object". Implemented via a `didUpdateWidget` guard comparing the previous `EnhancedConfidence` reference.
- `MintTrameConfiance.audio()` wraps in `Semantics(liveRegion: true, ...)` — this IS the audio surface; live region is correct here.
- `MintTrameConfiance.empty()` wraps in `Semantics(liveRegion: false, label: <enrich CTA>, button: true, ...)` — empty state IS interactive, semantically a button.

Tested on TalkBack 13 + VoiceOver during Phase 8b live a11y session (deferred consumer of this contract). Phase 4 unit-tests the `announce()` call count via a fake `SemanticsBinding`.

## D-12 — Scope boundary (LOCKED)

In scope for Phase 4:
- `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` (new)
- `apps/mobile/lib/widgets/trust/bloom_strategy.dart` — OPTIONAL split if `mint_trame_confiance.dart` exceeds 400 LOC; otherwise co-located.
- `apps/mobile/lib/widgets/coach/response_card_widget.dart` (modify, S4 first consumer)
- 1 caller of response_card_widget updated minimally (pass `confidence:` parameter)
- 24 ARB strings added to all 6 ARB files (`apps/mobile/lib/l10n/app_*.arb`) for `oneLineConfidenceSummary` (4 keys × 6 langs)
- `flutter gen-l10n` regenerated
- `test/widgets/trust/mint_trame_confiance_test.dart` (new, ~45 tests)
- `test/widgets/coach/response_card_widget_mtc_test.dart` (new or extended, ~12 tests)
- `test/goldens/helpers/screen_pump.dart` (new, golden test helper)
- `test/goldens/helpers/screen_pump_test.dart` (new, ~3 unit tests on the helper)
- `test/goldens/s4/*.png` (5 golden files, generated via `flutter test --update-goldens` on first run)
- `.github/workflows/ci.yml` minimal addition for golden test job (single-device only on CI; dual-device runs locally only — Galaxy A14 manual gate per PERF-04)

Out of scope:
- The other 11 MTC migration surfaces (Phase 8a)
- Live hypotheses footer wiring with real `Profile` data (Phase 8a)
- Audio surface live wiring (no caller in Phase 4)
- Galaxy A14 in-CI automation (deferred to v2.3)
- AAA token application to S4 text surfaces beyond the MTC slot itself (Phase 8b)
- AESTH-03 demote-headline-numbers on S4 (Phase 8b — that's a separate AESTH change)

Commit count: 3 (one per plan), atomic, each independently revertable.

## D-13 — Galaxy A14 manual perf gate (DEFERRED to phase exit)

ROADMAP Phase 4 Success Criterion #6 requires Julien's manual A14 pass on the S4 surface (0 dropped frames during bloom, scroll FPS within baseline). This is **not a plan task** — no executor can run it. Plans 04-01 / 04-02 / 04-03 ship code; Julien runs the device gate AFTER all 3 plans land, BEFORE Phase 4 is marked complete.

A `## A14 Manual Gate` checklist is added at the bottom of each plan's `<verification>` section so it's not lost.

</decisions>

<canonical_refs>

## Source files (read targets)

- S4 file (modify target): `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/coach/response_card_widget.dart`
- Voice cursor contract (import): `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/voice/voice_cursor_contract.dart`
- AAA tokens (import): `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/theme/colors.dart`
- EnhancedConfidence model: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/financial_core/confidence_scorer.dart`

## Audit inputs consumed

- `/Users/julienbattaglia/Desktop/MINT/docs/AUDIT-01-confidence-semantics.md` — 42-site classification, used to confirm S4 is NOT a pre-existing site (it's a NEW MTC introduction)
- `/Users/julienbattaglia/Desktop/MINT/docs/AUDIT_RETRAIT_S0_S5.md` — Phase 3 DELETE/KEEP/REPLACE list, S4 section drives Plan 04-02 pruning
- `/Users/julienbattaglia/Desktop/MINT/docs/VOICE_CURSOR_SPEC.md` — Phase 2 v0.5 extract, drives the 4 phrasing variants for `oneLineConfidenceSummary`

## Governing documents

- `/Users/julienbattaglia/Desktop/MINT/CLAUDE.md` (§5 EnhancedConfidence, §7 design tokens, §9 anti-pattern #15 hardcoded colors)
- `/Users/julienbattaglia/Desktop/MINT/visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.2 (MTC chantier definition)
- `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md` — overrides any other doctrine
- `/Users/julienbattaglia/Desktop/MINT/docs/DESIGN_SYSTEM.md` — 12-token palette + screen categories

## Downstream consumers (informs API stability)

- Phase 8a (MTC 11-surface migration) — every constructor in D-02 must be stable; breaking changes after Phase 4 means rework on all 11 sites
- Phase 8c (Polish Pass #1) — reuses `screen_pump.dart` helper from Plan 04-03
- Phase 9 (MintAlertObject) — reuses `screen_pump.dart`
- Phase 12 (Ship gate) — reuses dual-device golden infra for the final A14 manual pass

</canonical_refs>

<code_context>

## Phase 4 starting state (post-Phase 3)

- Voice cursor contract live, `resolveLevel()` pure function tested
- 6 AAA tokens in `colors.dart`, strict 7:1 verified
- `docs/AUDIT-01-confidence-semantics.md` committed, 42 sites classified, S4 confirmed absent from pre-existing list
- `docs/AUDIT_RETRAIT_S0_S5.md` committed, S4 DELETE/KEEP/REPLACE list available
- `docs/VOICE_CURSOR_SPEC.md` v0.5 extract committed, narrator wall + sensitive list locked
- `chiffre_choc → premier_eclairage` rename complete; CI grep gate green
- All 4 broken providers wired
- 9134 Flutter tests baseline / 5043 backend tests baseline
- `MintTrameConfiance` does **not exist**
- `screen_pump.dart` golden helper does **not exist** — Phase 4 creates it
- `response_card_widget.dart` currently has NO confidence rendering (verified by grep) — Phase 4 introduces the slot

## Anti-patterns to refuse during build

- Adding a public `score: double` getter on MTC (violates MTC-08, fails compliance grep)
- Rendering all 4 confidence axes as 4 stacked bars (violates D-04 weakest-axis rule)
- Hardcoded `Color(0x...)` anywhere in `widgets/trust/` (violates CLAUDE.md §9 #15 + D-10)
- `MTC` blooming on every card in a feed simultaneously (violates `BloomStrategy.onlyIfTopOfList` default for feed contexts, REQUIREMENTS anti-feature line 188)
- Skin/color shift on voice cursor level (REQUIREMENTS anti-feature line 187, "Visuel reste calme")
- `MTC` calling `resolveLevel()` internally (violates D-06 — MTC is a pure widget, no service lookup)
- Bloom firing in reduced-motion mode without the 50ms opacity fallback (violates ACCESS-07)
- Adding the MTC slot unconditionally to S4 (must be conditional on `confidence != null && response.isProjection`, per D-07)
- Skipping the 5-golden coverage on Plan 04-03 (violates D-08)

</code_context>

<expected_plans>

| # | Plan | Wave | Files | Tests delta |
|---|---|---|---|---|
| 04-01 | MintTrameConfiance component build (widget + BloomStrategy + painter + ARB + unit tests) | 1 | `widgets/trust/mint_trame_confiance.dart`, ARB ×6, `test/widgets/trust/mint_trame_confiance_test.dart` | +45 |
| 04-02 | S4 migration: response_card_widget consumes MTC + Phase 3 DELETE list pruning | 2 (depends on 04-01) | `widgets/coach/response_card_widget.dart`, 1 caller, `test/widgets/coach/response_card_widget_mtc_test.dart` | +12 |
| 04-03 | Golden test infrastructure: `screen_pump.dart` dual-device helper + 5 S4 baseline goldens + CI wiring | 2 (depends on 04-01, parallel to 04-02) | `test/goldens/helpers/screen_pump.dart`, `test/goldens/s4/*.png`, `.github/workflows/ci.yml` | +3 helper tests + 5 goldens |

Wave 1: 04-01 alone (component must exist before consumers/goldens).
Wave 2: 04-02 + 04-03 in parallel (different file ownership: S4 widget vs test infra).

</expected_plans>
</content>
</invoke>