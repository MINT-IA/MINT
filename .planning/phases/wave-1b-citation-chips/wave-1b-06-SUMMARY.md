---
phase: wave-1b-citation-chips
plan: 06
subsystem: flutter

tags: [flutter-widget, citation-modal, bottom-sheet, i18n-arb, karpathy-simple, wave-1b]

# Dependency graph
requires:
  - phase: wave-1b-citation-chips
    plan: 01
    provides: 3 widget test stubs in coach_citation_modal_test.dart + 1 stub in coach_citation_chip_modal_remember_test.dart, all SKIPPED until Plan 06 lands the modal
  - phase: wave-1b-citation-chips
    plan: 04
    provides: ToolCallCitationChip Dart model (toolName, inputsHash, computedAt, rawResponse)
  - phase: wave-1b-citation-chips
    plan: 05
    provides: CoachCitationChipsSection widget + empty onChipTap callback in coach_message_bubble.dart for Plan 06 wiring
  - phase: wave-1b-citation-chips
    plan: 07
    provides: 11 ARB getters consumed by the modal — coachCitationModalTitle(String), coachCitationJsonViewerLabel, coachCitationRememberCta, 6 coachTool* names, 4 coachCitationRelative* keys (3 ICU plural-aware)
provides:
  - apps/mobile/lib/widgets/coach/coach_citation_modal.dart — showCoachCitationModal top-level function + _CoachCitationModalBody widget
  - Wire into apps/mobile/lib/widgets/coach/coach_message_bubble.dart — onChipTap invokes showCoachCitationModal with SnackBar acknowledgement for Souviens-toi CTA
  - 4 widget tests transitioned SKIPPED → PASSED (3 in coach_citation_modal_test.dart, 1 in coach_citation_chip_modal_remember_test.dart)
affects: [wave-1b-08-sentry-breadcrumb, wave-1b-09-maestro-flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Modal-as-function vs Modal-as-Widget: top-level Future<void> showCoachCitationModal(context, chip, {onRememberTap}) mirrors response_card_widget._showProofSheet — caller passes context, no separate widget construction. Karpathy #2 — single call site, no over-abstraction."
    - "ARB getter via generated `S` class (NOT AppLocalizations): MINT's generated localization class is `S` not `AppLocalizations` (Plan 05 deviation Rule 1 inherited)."
    - "Defensive Karpathy #1 surfacing of dropped scope: Q7_DECISION (flag_state badge dropped) documented as a class-level docstring comment so future readers know why the modal has 5 sections instead of CONTEXT line 40's 6."

key-files:
  created:
    - apps/mobile/lib/widgets/coach/coach_citation_modal.dart
    - .planning/phases/wave-1b-citation-chips/wave-1b-06-SUMMARY.md
  modified:
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
    - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart
    - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart
    - tools/checks/baselines/prefer_mint_text_style.baseline.txt
    - tools/checks/baselines/prefer_mint_radius.baseline.txt

key-decisions:
  - "Q7_DECISION shipped — flag_state badge dropped in v1. Rationale: flag_state is not in any Pydantic response model (only in coach_breadcrumbs.py:31 Sentry payload), chip only renders when inputs_hash is present (i.e. flag=on), so the badge would always read on with zero information content (Karpathy #2 simplicity). If Wave 2 introduces partial flags / cohorts, the badge can be added back."
  - "Q8_DECISION shipped — 4 relative-time ARB keys consumed. _relativeTime(DateTime, S) reads coachCitationRelativeJustNow / Minutes / Hours / Days (3 ICU plural-aware). Plan 07 already shipped the 4 keys × 6 locales = 24 entries on 2026-05-15 (commit 49142b79). Dart literals for à l'instant / il y a N would have been a silent FR-only leak in EN/DE/ES/IT/PT — validate_arb_parity checks ARB completeness, not Dart literal leakage, so the lint gate wouldn't catch it."
  - "Souviens-toi CTA wired with SnackBar acknowledgement, not persistence. The optional onRememberTap callback fires + closes the modal; the bubble's wiring emits a SnackBar so Maestro G1 (Plan 09) can assert the CTA fired. save_insight tool persistence is documented as a Wave 2 follow-up (out of scope per plan must_haves)."
  - "Tool-display-name lookup duplicated from CoachCitationChipsSection (Plan 05). 8-line switch over 6 tool names is acceptable duplication per Karpathy #2; refactor to a shared helper if a 3rd consumer appears."

patterns-established:
  - "Modal pattern for tool-call provenance: showModalBottomSheet at maxHeight 0.85, 20dp top radius, drag handle, header, hash row, time row, ExpansionTile JSON viewer, full-width CTA. Reusable for future provenance modals (e.g. RAG source modal, projection-pack modal)."

requirements-completed: [WAVE1B-05, WAVE1B-08]

# Metrics
duration: ~6min
completed: 2026-05-15
---

# Phase wave-1b Plan 06: Coach Citation Modal Summary

**showCoachCitationModal top-level function lands at apps/mobile/lib/widgets/coach/coach_citation_modal.dart (227 LOC); modal renders 5 sections (drag handle + tool-name header + truncated 16-char inputs_hash + relative computed_at via 4 ARB keys + collapsible ExpansionTile JSON viewer pretty-printed via JsonEncoder.withIndent + Souviens-toi CTA); coach_message_bubble.dart onChipTap callback (left empty in Plan 05) now invokes the modal with SnackBar acknowledgement for the CTA (save_insight persistence deferred to Wave 2 per plan must_haves); Q7_DECISION shipped (flag_state badge dropped because chip only renders when flag=on); Q8_DECISION shipped (relative-time strings via 4 ARB keys, no Dart literal leak); 4 widget tests transitioned SKIPPED→GREEN (4/4), 737/737 coach widget tests pass with zero regressions vs Plan 05's 733/733 baseline.**

## Performance

- **Duration:** ~6 min execution
- **Started:** 2026-05-15T09:50:04Z (branch creation `feature/wave-1b-06-citation-modal` from `dev` at `ab64b07c`)
- **Completed:** 2026-05-15T09:55:44Z (last GREEN commit `6f0faad0`)
- **Tasks:** 2 (modal widget + bubble wiring/tests)
- **Files created:** 2 (1 modal widget + 1 SUMMARY)
- **Files modified:** 5 (1 message bubble + 2 test files + 2 lint baselines)

## Widget contract

`showCoachCitationModal(BuildContext context, ToolCallCitationChip chip, {void Function(ToolCallCitationChip)? onRememberTap}) → Future<void>` — top-level function at `apps/mobile/lib/widgets/coach/coach_citation_modal.dart`. Returns the future of the `showModalBottomSheet<void>` call.

Modal body (`_CoachCitationModalBody`, private StatelessWidget):

- **maxHeight** = 85% of screen height (`MediaQuery.of(context).size.height * 0.85`).
- **Shape** = top-only rounded rectangle, 20dp radius (matches `response_card_widget._showProofSheet` precedent).
- **5 sections** (Karpathy #2 — exactly what plan asks, no extras):
  1. **Drag handle** — 40×4dp `MintColors.porcelaine` rounded rect (informational only; native bottom-sheet already exposes drag).
  2. **Header** — `s.coachCitationModalTitle(toolDisplayName)` rendered as `MintTextStyles.titleMedium()`. Example FR: "Source du calcul : Budget actuel".
  3. **inputs_hash row** — `Icons.fingerprint` 14dp + `SelectableText` of `chip.inputsHash.substring(0, 16) + '…'` (U+2026 ellipsis, NOT three dots) in `MintTextStyles.micro` monospace.
  4. **computed_at row** — `Icons.schedule` 14dp + `Text(_relativeTime(chip.computedAt, s))` reading 4 ARB keys (Q8_DECISION).
  5. **JSON viewer** — `Theme(dividerColor: MintColors.transparent) ⟶ ExpansionTile` (`Key('coachCitationModalJsonExpansion')`, `tilePadding: EdgeInsets.zero`) wrapping a `bleuAir α=0.1` container with a `SelectableText` of `JsonEncoder.withIndent('  ').convert(chip.rawResponse)` in monospace. Default = collapsed.
  6. **Souviens-toi CTA** — `TextButton.icon` (`Key('coachCitationModalRememberCta')`, `Icons.bookmark_outline`) with `label: Text(s.coachCitationRememberCta)`. `onPressed` invokes `onRememberTap!(chip)` then `Navigator.of(context).pop()`. Disabled when `onRememberTap == null`.

## Wiring into coach_message_bubble.dart

Import added at line 11 (alphabetical, between `coach_citation_chips_section.dart` and `response_card_widget.dart`):

```dart
import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';
```

`onChipTap` callback at lines 175-193 (Plan 05 left this empty) now invokes:

```dart
onChipTap: (chip) {
  showCoachCitationModal(
    context,
    chip,
    onRememberTap: (c) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.coachCitationRememberCta),
          duration: const Duration(seconds: 2),
        ),
      );
    },
  );
},
```

Per plan: the SnackBar is a placeholder acknowledgement for Maestro G1 (Plan 09) to assert the CTA fired. `save_insight` tool persistence is documented as a Wave 2 follow-up.

## ARB getters consumed (Plan 07 already shipped)

| Getter | Type | Purpose |
|---|---|---|
| `coachCitationModalTitle(String toolDisplayName)` | parametrized | Modal header — "Source du calcul : {toolDisplayName}" |
| `coachCitationJsonViewerLabel` | simple | ExpansionTile header text — "Voir le détail du calcul (JSON)" |
| `coachCitationRememberCta` | simple | CTA + SnackBar text — "Souviens-toi de cette source" |
| `coachCitationRelativeJustNow` | simple | "à l'instant" (Q8_DECISION) |
| `coachCitationRelativeMinutes(int count)` | ICU plural | "il y a {count} min" (Q8_DECISION) |
| `coachCitationRelativeHours(int count)` | ICU plural | "il y a {count} h" (Q8_DECISION) |
| `coachCitationRelativeDays(int count)` | ICU plural | "il y a {count} j" (Q8_DECISION) |
| `coachToolBudgetSnapshot` | simple | "Budget actuel" |
| `coachToolRetirementProjection` | simple | "Projection retraite" |
| `coachToolCrossPillarAnalysis` | simple | "Analyse cross-piliers" |
| `coachToolCoupleOptimization` | simple | "Optimisation couple" |
| `coachToolCapStatus` | simple | "État des plafonds" |
| `coachToolRetrieveMemories` | simple | "Souvenirs" |

13 getters total (header + JSON label + CTA + 4 relative-time + 6 tool names). All consumed via `S.of(context)!.<getter>` (NOT `AppLocalizations.of(context)!.<getter>` — Plan 05 deviation Rule 1 inherited).

## Tests

- **`coach_citation_modal_test.dart`** — Plan 01's 3 SKIPPED stubs unskipped and implemented:
  1. `opens bottom sheet on chip tap` — taps button that calls `showCoachCitationModal`, asserts `Key('coachCitationModalJsonExpansion')` renders. Also asserts the `onOpened` callback fired (lifecycle check).
  2. `shows truncated 16-char inputs_hash` — feeds `inputsHash = 'a' * 64`, asserts `find.text('${'a' * 16}…')` finds one widget (U+2026 ellipsis, not three dots).
  3. `JSON viewer is collapsible (ExpansionTile)` — feeds `rawResponse: {'monthlyIncome': '7500'}`, asserts pre-expand `find.textContaining('monthlyIncome')` is empty, then taps the expansion key and asserts it now renders.

- **`coach_citation_chip_modal_remember_test.dart`** — Plan 01's 1 SKIPPED stub unskipped and implemented:
  4. `Souviens-toi CTA fires onRememberTap with the chip` — opens modal with `onRememberTap: (c) => remembered = c`, taps `Key('coachCitationModalRememberCta')`, asserts `remembered.toolName == 'budget_snapshot'`.

- **Test helpers:** `_wrap({onOpened})` wraps in `MaterialApp` + `S.localizationsDelegates` + `S.supportedLocales` + `Locale('fr')` + Builder-scoped ElevatedButton that invokes the modal (avoids context-from-outside issues).

## Task Commits

Each commit landed atomically on `feature/wave-1b-06-citation-modal` (branched from `dev` at `ab64b07c`):

1. **Task 1: Create coach_citation_modal.dart** — `cd842900` (feat)
2. **Pre-push baseline regen for line-shifted lints** — `9f475812` (chore)
3. **Task 2: Wire into bubble + unskip 4 modal tests** — `6f0faad0` (feat)

## Diff size

```
 apps/mobile/lib/widgets/coach/coach_citation_modal.dart                | +227 (new)
 apps/mobile/lib/widgets/coach/coach_message_bubble.dart                | +20 -2
 apps/mobile/test/widgets/coach/coach_citation_modal_test.dart          | +71 -16
 apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart | +46 -12
 tools/checks/baselines/prefer_mint_text_style.baseline.txt             | 2-line shift regen
 tools/checks/baselines/prefer_mint_radius.baseline.txt                 | 1-line shift regen
 ───────────────────────────────────────────────────────────────────────
 Total                                                                    | +355 LOC across 5 files (+ 1 SUMMARY)
```

## Decisions Made

- **Decision 1 (Q7_DECISION — flag_state badge dropped)** — Confirmed at exec start by reviewing Pydantic models (no `flag_state` field) + Sentry breadcrumb model (`coach_breadcrumbs.py:31`, Python-only). Chip only renders when `inputs_hash` is in the response, which only happens when the rollout flag is on, so the badge has zero information content. Modal ships 5 sections instead of CONTEXT line 40's 6.
- **Decision 2 (Q8_DECISION — 4 relative-time ARB keys)** — Plan 07 already shipped the 4 keys × 6 locales on 2026-05-15 (commit `49142b79`). `_relativeTime(DateTime, S)` reads them; signature changes from the alternative `_relativeTime(DateTime)` returning Dart literals (rejected as silent FR-only leak in 5 other locales).
- **Decision 3 (Souviens-toi = SnackBar, not save_insight wiring)** — Plan must_haves explicitly say "Plan 06 only wires the UI, persistence is documented as a Wave 2 follow-up". SnackBar emits a 2-second acknowledgement that Maestro G1 (Plan 09) can assert; backend `save_insight` integration deferred.
- **Decision 4 (`MintColors.transparent` over `Colors.transparent`)** — Lint `prefer_mint_color_token` flagged `Colors.transparent` at line 175 (`dividerColor` for the JSON ExpansionTile). `MintColors.transparent` token exists (`colors.dart:15`), used instead. Same fix as Plan 96-01 deviation (a).
- **Decision 5 (lint-ignore on `fontFamily: 'monospace'`)** — `prefer_mint_fonts` lint flags any raw `fontFamily:` use. The hash row + JSON viewer need monospace rendering for character alignment; no `MintTextStyles.monospace()` token exists in the design system (`mint_text_styles.dart`). Per the lint's own `// lint-ignore: prefer_mint_fonts` escape hatch, added the directive at both sites (lines 146, 200). Alternative — adding a `MintTextStyles.monospace()` token — was out of scope.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Plan referenced `AppLocalizations` class; actual is `S`**
- **Found during:** Task 1 implementation.
- **Issue:** Plan §Task 1 prescribed `AppLocalizations.of(context)!`. The generated MINT localization class is `S` (verified at `app_localizations.dart:14077-14149` for the wave-1b keys; same Rule 1 codebase-shape mismatch Plan 96-01 + Plan 05 documented).
- **Fix:** Used `S.of(context)!`, `S.localizationsDelegates`, `S.supportedLocales`. The `_relativeTime` helper signature changed from `_relativeTime(DateTime, AppLocalizations)` to `_relativeTime(DateTime, S)`. All 11 ARB getters resolved correctly.
- **Files modified:** `coach_citation_modal.dart`, `coach_citation_modal_test.dart`, `coach_citation_chip_modal_remember_test.dart`, `coach_message_bubble.dart` (existing import already used `S`).
- **Commits:** `cd842900` + `6f0faad0`.

**2. [Rule 1 — Bug] Plan imports referenced `text_styles.dart` / `spacing.dart`; actual filenames are `mint_text_styles.dart` / `mint_spacing.dart`**
- **Found during:** Task 1 implementation.
- **Issue:** Plan §Task 1 action block had `import 'package:mint_mobile/theme/text_styles.dart'` and `import 'package:mint_mobile/theme/spacing.dart'`. Same Rule 1 inherited from Plan 05 deviation (a).
- **Fix:** Used the correct `mint_text_styles.dart` + `mint_spacing.dart` imports.
- **Files modified:** `coach_citation_modal.dart`.
- **Commit:** `cd842900`.

**3. [Rule 2 — Missing critical functionality] `prefer_mint_color_token` lint failed on `Colors.transparent`**
- **Found during:** Task 1 post-write design-lint sweep.
- **Issue:** `dividerColor: Colors.transparent` at line 175 violates `prefer_mint_color_token` (any `Colors.<name>` is a design-system bypass).
- **Fix:** Replaced with `MintColors.transparent` (token exists at `colors.dart:15`). Lint exits clean.
- **Files modified:** `coach_citation_modal.dart`.
- **Commit:** `cd842900`.

**4. [Rule 2 — Missing critical functionality] `prefer_mint_fonts` lint failed on 2 `fontFamily: 'monospace'` sites**
- **Found during:** Task 1 post-write design-lint sweep.
- **Issue:** `fontFamily: 'monospace'` at lines 146 + 200 (hash + JSON `SelectableText`) violates `prefer_mint_fonts` which bans raw `fontFamily:` outside the design-system module.
- **Fix:** Added `// lint-ignore: prefer_mint_fonts` directives at both sites per the lint's own escape-hatch. Monospace rendering is required for character-alignment of the 16-char hash + JSON pretty-print; no `MintTextStyles.monospace()` token exists (out-of-scope refactor to add one).
- **Files modified:** `coach_citation_modal.dart`.
- **Commit:** `cd842900`.

**5. [Rule 3 — Blocking] `prefer_mint_text_style` + `prefer_mint_radius` baseline line-shifts from bubble wiring**
- **Found during:** Task 2 post-edit design-lint sweep.
- **Issue:** Inserting 18 lines in the `onChipTap` block (lines 175-192 — `showCoachCitationModal` + SnackBar) shifted 3 pre-existing violations:
  - `coach_message_bubble.dart:111: fontSize: 15` → `:112`
  - `coach_message_bubble.dart:320: fontSize: 10` → `:338`
  - `coach_message_bubble.dart:656: BorderRadius.circular(1)` → `:674`
- **Fix:** Per `feedback_pre_push_checklist.md` + Plan 05 pattern, ran `python3 tools/checks/prefer_mint_text_style.py --update-baseline` + `python3 tools/checks/prefer_mint_radius.py --update-baseline`. Committed the regen as a separate `chore(wave-1b-06): baseline line-shift` commit to keep the feature commit focused on behavioral diff.
- **Files modified:** `tools/checks/baselines/prefer_mint_text_style.baseline.txt`, `tools/checks/baselines/prefer_mint_radius.baseline.txt`.
- **Commit:** `9f475812`.

**Total deviations:** 5 auto-fixed (2 × Rule 1 codebase-shape inherited from Plan 05, 2 × Rule 2 design-lint compliance, 1 × Rule 3 line-shift baseline regen). Zero behavioural / logic deviations. The plan-prescribed modal structure (drag-handle → header → hash → time → ExpansionTile JSON → CTA) shipped exactly as written.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT hooks fired defensively** on `coach_citation_modal.dart`, `coach_message_bubble.dart`, both test files even though all four were read at session start. Edits landed (verified via grep + `flutter test` exit 0). Same observation as Plan 04 / 05 SUMMARYs — behavior is a safety reminder, not a block.

## Known Stubs

None introduced by Plan 06. Plan 01's remaining SKIPPED stubs after Plan 06:

- backend Sentry breadcrumb tests in `test_breadcrumb_contract.py` + `test_breadcrumb_cardinality.py` (Plan 08).

All Flutter-side Plan 01 stubs (Plans 05 + 06) are now unskipped.

## Threat Flags

- **T-WAVE1B-06-01** (PII leak in modal JSON) — MITIGATED in design. Modal is user-initiated (user taps own chip on own data). Sentry Replay (Phase 31) masks all text via `maskAllText=true`. iOS sim screen recordings are local-only.
- **T-WAVE1B-06-02** (flag_state badge dropped vs CONTEXT line 40) — DOCUMENTED. Q7_DECISION rationale surfaced at top of plan + in modal class docstring + in this SUMMARY. Alternative path (add `flag_state` to Pydantic models) documented if Julien rejects.
- **T-WAVE1B-06-03** (tap propagation closes modal immediately) — MITIGATED. `showModalBottomSheet` builder uses scoped `ctx`. Test 1 explicitly asserts the bottom sheet renders post-tap.
- **T-WAVE1B-06-04** (Souviens-toi persists without consent) — RESOLVED. Plan 06 ships UI only; SnackBar is non-persisting acknowledgement. `save_insight` wiring deferred to Wave 2 per must_haves.
- **T-WAVE1B-06-05** (Hardcoded FR strings violate i18n) — RESOLVED. All 11 user-facing strings flow through `S.coach*` ARB getters (Plan 07's 90-entry 6-locale sweep). Zero Dart literals.
- **T-WAVE1B-06-06** (Relative-time Dart literals leak FR-only) — RESOLVED. `_relativeTime(DateTime, S)` reads 4 ARB keys. `grep -cE "'à l\\'instant'|'il y a [0-9]+"` returns 0 in `coach_citation_modal.dart`. Q8_DECISION enforced.

No NEW threat surface introduced by Plan 06 beyond the plan's `<threat_model>` enumeration.

## User Setup Required

None. Plan 06 is pure Flutter source diff. No env var, no Railway config, no Apple Developer portal capability, no Maestro flow change. The modal activates automatically once a user taps a `CoachCitationChipsSection` chip — which requires Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flags ON (post-Plan-08 coupled flip per CONTEXT D-01).

## Next Phase Readiness

- **Plan 08** (Sentry breadcrumb) can hook into the modal's `onRememberTap` callback OR the bubble's `onChipTap` to emit `coach.citation.tool_call_id.<tool>.emitted` per CONTEXT line 37. The 5-kwarg payload (tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state) requires the bubble to know `flag_state`; if the Pydantic model doesn't carry it (verified absent in Plan 06 audit), Plan 08 will need to either (a) add the field to the Pydantic response or (b) compute it from the config flag at emission time. Recommend (b) per Karpathy #2.
- **Plan 09** (Maestro G1 flow) can now reference `Key('coachCitationModalJsonExpansion')` + `Key('coachCitationModalRememberCta')` selectors. The full happy-path flow is now: tap card → "Explique-moi" → coach replies with citation chip → `Key('coachCitationChip-budget_snapshot')` tap → `Key('coachCitationModalJsonExpansion')` tap → assert JSON visible → `Key('coachCitationModalRememberCta')` tap → assert SnackBar text matches `coachCitationRememberCta`.

## Pre-push checklist (per feedback_pre_push_checklist.md)

| Gate | Status | Evidence |
|---|---|---|
| flutter analyze (touched file) | OK | `flutter analyze lib/widgets/coach/coach_citation_modal.dart` → "No issues found!" |
| flutter analyze (full repo, baseline) | OK | `flutter analyze` → 253 issues (= baseline, 0 new errors) |
| flutter test (touched test files) | OK | 4/4 tests pass on `coach_citation_modal_test.dart` + `coach_citation_chip_modal_remember_test.dart` |
| flutter test (touched-area regression) | OK | `flutter test test/widgets/coach/` → 737/737 pass (+4 vs Plan 05 baseline 733/733 = exact match, zero regressions) |
| sentence_subject_arb_lint | N/A | No ARB keys touched (Plan 06 only consumes Plan 07's keys) |
| prefer_mint_text_style | OK | clean (683 grandfathered after line-shift baseline regen) |
| prefer_mint_color_token | OK | clean (23 grandfathered) — `MintColors.transparent` swap |
| prefer_mint_radius | OK | clean (42 grandfathered after line-shift baseline regen) |
| prefer_mint_cta | OK | clean (-1 from baseline) |
| prefer_mint_fonts | OK | clean (92 grandfathered) — 2 lint-ignores for `fontFamily: 'monospace'` |
| OpenAPI canonical regen | N/A | Plan 06 is Flutter-only, zero Pydantic schema changes |

## 0-trust Self-Check (CLAUDE.md §9.4 + §9.6)

**Evidence (verbatim citations):**

- **Evidence file 1** — Modal file exists: `test -f apps/mobile/lib/widgets/coach/coach_citation_modal.dart` exits 0; `wc -l` returns 227. FOUND.
- **Evidence file 2** — `showCoachCitationModal` declared exactly once: `grep -c "Future<void> showCoachCitationModal" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 1. FOUND.
- **Evidence file 3** — 3 structural patterns present: `grep -cE "showModalBottomSheet|ExpansionTile|JsonEncoder.withIndent" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 3. FOUND.
- **Evidence file 4** — flag_state badge dropped: `grep -cE "flag_state|flagState" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 0. FOUND (Q7_DECISION respected).
- **Evidence file 5** — 4 relative-time ARB keys consumed: `grep -cE "coachCitationRelativeJustNow|coachCitationRelativeMinutes|coachCitationRelativeHours|coachCitationRelativeDays" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 6 (production usage + 1 docstring reference for each = ≥4). FOUND (Q8_DECISION respected).
- **Evidence file 6** — No Dart-literal relative-time leak: `grep -cE "'à l\\'instant'|'il y a [0-9]+"` returns 0. FOUND.
- **Evidence file 7** — `S.coach*` ARB getter consumption: `grep -cE "s\.coach[A-Z]" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 9 (header + JSON label + CTA + 6 tool names). FOUND.
- **Evidence file 8** — Bubble wiring: `grep -n "showCoachCitationModal\|coach_citation_modal" apps/mobile/lib/widgets/coach/coach_message_bubble.dart` returns 2 lines (import at :11, call at :178). FOUND.
- **Evidence file 9** — Plan 01 modal stubs unskipped: `grep -c "skip: 'Wave 1b\|skip: true" apps/mobile/test/widgets/coach/coach_citation_modal_test.dart apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart` returns 0 across both files. FOUND.
- **Evidence command 1** — Modal tests pass: `cd apps/mobile && flutter test test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart` → `00:00 +4: All tests passed!` (4/4). CITED.
- **Evidence command 2** — Touched-area regression: `cd apps/mobile && flutter test test/widgets/coach/` → `00:12 +737: All tests passed!` (737/737, +4 vs Plan 05 baseline 733/733). CITED.
- **Evidence command 3** — Flutter analyze: `cd apps/mobile && flutter analyze` → `253 issues found.` (= baseline 253, all info-level, zero new errors). CITED.
- **Evidence command 4** — prefer_mint_color_token: `python3 tools/checks/prefer_mint_color_token.py` → `OK prefer_mint_color_token: clean (23 grandfathered)`. CITED.
- **Evidence command 5** — prefer_mint_text_style: `python3 tools/checks/prefer_mint_text_style.py` → `OK prefer_mint_text_style: clean (683 grandfathered)`. CITED.
- **Evidence command 6** — prefer_mint_radius: `python3 tools/checks/prefer_mint_radius.py` → `OK prefer_mint_radius: clean (42 grandfathered)`. CITED.
- **Evidence command 7** — prefer_mint_cta: `python3 tools/checks/prefer_mint_cta.py` → `OK prefer_mint_cta: clean (-1 from baseline)`. CITED.
- **Evidence command 8** — prefer_mint_fonts: `python3 tools/checks/prefer_mint_fonts.py` → `OK prefer_mint_fonts: clean (92 grandfathered)`. CITED.
- **Evidence command 9** — git log: `git log --oneline -3` shows `6f0faad0` (T2 wire+tests) → `9f475812` (baseline regen) → `cd842900` (T1 modal) on top of base `ab64b07c`. CITED.
- **Caveat** — Plan 06 ships the modal rendering surface and its 4 unit-test guards. It does NOT prove:
  - Sentry breadcrumb fires on tap (Plan 08).
  - End-to-end Maestro flow taps chip → modal → JSON expand → Souviens-toi (Plan 09).
  - End-to-end user flow on iPhone 17 Pro sim — NO `idb` snapshot, NO sim screenshot. Plan 09's G2 Claude-autonomous walker is the authoritative end-to-end gate per CLAUDE.md §9.
  - PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — Stage 1 of 4 (PR opened). Do NOT claim « shipped », « ready », « works », « validated », « green ».
  - `save_insight` persistence — out of scope per plan must_haves; deferred to Wave 2.

## Self-Check: PASSED

- Modal file FOUND on disk (`coach_citation_modal.dart`, 227 LOC).
- Bubble wiring FOUND on disk (2 grep matches: import + call site).
- 0 SKIPPED stubs remaining in both Plan-06-owned test files.
- 4/4 modal tests GREEN; 737/737 coach widget tests GREEN (0 regressions vs Plan 05 baseline 733/733).
- All 3 task commits (`cd842900`, `9f475812`, `6f0faad0`) present in `git log`.
- 5 design-system lints exit 0 (color_token, text_style, radius, cta, fonts).
- `flutter analyze` 253 = baseline (0 new errors).
- 5 deviations auto-fixed and documented (2 × Rule 1 inherited codebase-shape, 2 × Rule 2 design-lint compliance, 1 × Rule 3 line-shift baseline regen).
- Q7_DECISION shipped: zero `flag_state` UI surface.
- Q8_DECISION shipped: 4 ARB keys consumed, zero Dart literal leak.
- USER VALUE DELIVERED: NONE end-user-visible YET — the modal opens only when a `ToolCallCitationChip` is tapped, which requires Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flags ON (post-Plan-08 coupled flip per CONTEXT D-01). PR opened against `dev`, NOT merged. Stage 1 of 4 per CLAUDE.md §9.5.

---

*Phase: wave-1b-citation-chips*
*Plan: 06*
*Completed: 2026-05-15*
*Branch: feature/wave-1b-06-citation-modal (base ab64b07c)*
*Commits: cd842900 (T1 modal) → 9f475812 (baseline regen) → 6f0faad0 (T2 wire + tests)*
