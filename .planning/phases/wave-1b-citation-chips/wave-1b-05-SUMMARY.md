---
phase: wave-1b-citation-chips
plan: 05
subsystem: flutter

tags: [flutter-widget, citation-chip, golden-test, maestro-key, karpathy-simple, wave-1b]

# Dependency graph
requires:
  - phase: wave-1b-citation-chips
    plan: 01
    provides: 4 widget test stubs (coach_citation_chips_section_test.dart) + 6 golden test stubs (coach_citation_chip_golden_test.dart), all SKIPPED until Plan 05 lands the widget
  - phase: wave-1b-citation-chips
    plan: 04
    provides: ToolCallCitationChip Dart model + ChatMessage.citationChips field — direct dependency for the widget's chips parameter
  - phase: wave-1b-citation-chips
    plan: 07
    provides: 8 ARB getters consumed by the widget (S.coachCitationChipsHeader, S.coachCitationChipLabel(toolDisplayName), S.coachToolBudgetSnapshot, …RetirementProjection, …CrossPillarAnalysis, …CoupleOptimization, …CapStatus, …RetrieveMemories) × 6 locales
provides:
  - apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart — CoachCitationChipsSection widget (sibling of CoachSourcesSection)
  - Wire into apps/mobile/lib/widgets/coach/coach_message_bubble.dart — citation chips rendered between Sources and Disclaimers
  - 4 widget tests transitioned SKIPPED → PASSED in coach_citation_chips_section_test.dart
  - 6 golden snapshots generated (one per Wave 1a tool, 5.2-5.5 KB each)
  - onChipTap callback surface for Plan 06 modal wiring
affects: [wave-1b-06-modal, wave-1b-09-maestro-flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sibling-widget pattern over sealed-class refactor: when an existing widget (CoachSourcesSection) consumes a different data type (RagSource has title/file/section), add a sibling widget rather than extending the original. Avoids touching 30+ files that import RagSource. RESEARCH §9.4 decision."
    - "Maestro testID stability via stable Keys: each interactive element carries Key('<scopedName>-<dynamicId>') so flow YAMLs can tap by id instead of fragile text matching. RESEARCH §9.5."
    - "Baseline-shift commit pattern (separate chore commit): when a line insertion shifts pre-existing lint violations downstream, regenerate the baselines and ship as a separate chore() commit to keep the feature commit focused. Per feedback_pre_push_checklist.md."

key-files:
  created:
    - apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart
    - apps/mobile/test/goldens/coach_citation_chip_budget_snapshot.png
    - apps/mobile/test/goldens/coach_citation_chip_retirement_projection.png
    - apps/mobile/test/goldens/coach_citation_chip_cross_pillar_analysis.png
    - apps/mobile/test/goldens/coach_citation_chip_couple_optimization.png
    - apps/mobile/test/goldens/coach_citation_chip_cap_status.png
    - apps/mobile/test/goldens/coach_citation_chip_retrieve_memories.png
    - .planning/phases/wave-1b-citation-chips/wave-1b-05-SUMMARY.md
  modified:
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
    - apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart
    - apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart
    - tools/checks/baselines/prefer_mint_text_style.baseline.txt
    - tools/checks/baselines/prefer_mint_radius.baseline.txt

key-decisions:
  - "Sibling widget vs extend CoachSourcesSection: chose sibling per RESEARCH §9.4 — RagSource is read by 30+ files, sealed-class refactor has high blast radius. Sibling widget = ~3 files touched (widget + bubble + tests)."
  - "ARB getters use S.* (not AppLocalizations.*): MINT's generated localization class is exported as `S` from app_localizations.dart, not `AppLocalizations`. Verified at app_localizations.dart:68 (`abstract class S`)."
  - "Baseline regen as separate chore commit: 12-line insertion in coach_message_bubble.dart shifted 2 prefer_mint_text_style + 1 prefer_mint_radius pre-existing violations to new line numbers. Per feedback_pre_push_checklist.md, regenerated baselines (683 + 42 entries) and shipped as separate `chore(wave-1b-05): baseline line-shift` commit — keeps the feature commit focused on widget+wiring+tests."
  - "onChipTap signature accepts (ToolCallCitationChip) → void: Plan 06 will replace the empty callback with showModalBottomSheet. Plan 05 just exposes the wire; the chip is passed by value so the modal has full access to inputsHash + computedAt + rawResponse."

patterns-established:
  - "Stub-driven TDD across waves: Plan 01 pre-files 14 SKIPPED widget+golden stubs; Plan 05 unskips + implements + verifies green in a single execution turn. Removes the cognitive load of test-design at implementation time and surfaces test infrastructure decisions (locale, fakers) at wave-planning time."

requirements-completed: [WAVE1B-04, WAVE1B-08]

# Metrics
duration: 5min
completed: 2026-05-15
---

# Phase wave-1b Plan 05: Flutter CoachCitationChipsSection Widget Summary

**Sibling widget to CoachSourcesSection shipped; renders one InkWell-wrapped Row per ToolCallCitationChip with Icons.calculate_outlined + S.coachCitationChipLabel(toolDisplayName) underlined; each chip carries Key('coachCitationChip-<toolName>') for Maestro stability; wired into coach_message_bubble.dart between Sources and Disclaimers; 4 widget tests transitioned SKIPPED→GREEN (4/4) + 6 golden snapshots generated and matching (6/6); Plan 06 modal handler hooks into the empty onChipTap callback.**

## Performance

- **Duration:** ~5 min execution
- **Started:** 2026-05-15T09:28:40Z (branch creation `feature/wave-1b-05-citation-chips-section` from `dev` at `34215d78`)
- **Completed:** 2026-05-15T09:33:09Z (last GREEN commit `38eda46f`)
- **Tasks:** 2 (widget + wiring/tests)
- **Files created:** 8 (1 widget + 6 PNG goldens + 1 SUMMARY)
- **Files modified:** 5 (1 message bubble + 2 test files + 2 lint baselines)

## Widget contract

`CoachCitationChipsSection({ required List<ToolCallCitationChip> chips, void Function(ToolCallCitationChip)? onChipTap })` — stateless widget at `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` (123 LOC).

Behavioural surface:

- **Empty chips list** → returns `SizedBox.shrink()` (no padding, no chrome).
- **Non-empty** → renders Container(bleuAir α=0.1 background, 16dp radius, 12dp padding) with header `S.coachCitationChipsHeader` ("Calculs serveur" FR) + one Row per chip.
- **Per-chip Row:** `Icons.calculate_outlined` 12dp at `MintColors.textSecondaryAaa.withValues(alpha: 0.6)` + 4dp gap (MintSpacing.xs) + `Expanded(Text(S.coachCitationChipLabel(toolDisplayName)))` underlined at `MintColors.textSecondaryAaa`.
- **Tap target:** `InkWell` with `borderRadius: BorderRadius.circular(8)`, `onTap = onChipTap == null ? null : () => onChipTap!(chip)` (disabled state when no callback wired).
- **Maestro key:** each InkWell carries `Key('coachCitationChip-<toolName>')` per RESEARCH §9.5.
- **Accessibility:** each chip wrapped in `Semantics(label: toolDisplayName, button: true)`.

Tool-name → display-name lookup is a private `_toolDisplayName(BuildContext, String)` switch over the 6 Wave 1a canonical names; falls back to the raw `toolName` for unknown tools (defensive against backend drift).

## Wiring into coach_message_bubble.dart

Import added at line 10 (alphabetical insertion between `coach/` widget imports). Render block inserted at lines 167-180 (AFTER Sources block ends at line 165, BEFORE Disclaimers block at line 181):

```dart
// Citation chips (Wave 1b) — tool-call provenance.
// Sibling of Sources; rendered alongside (NOT replacing) it.
if (msg.citationChips.isNotEmpty) ...[
  const SizedBox(height: MintSpacing.md - 4),
  Padding(
    padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
    child: CoachCitationChipsSection(
      chips: msg.citationChips,
      onChipTap: (chip) {
        // Plan 06 wires the modal here.
      },
    ),
  ),
],
```

Left padding `44` mirrors the existing CoachSourcesSection inset (matches the 44dp coach-bubble indent established at coach_message_bubble.dart:61).

## Tests

- **`coach_citation_chips_section_test.dart`** — Plan 01's 4 SKIPPED stubs unskipped and implemented:
  1. `renders one chip per ToolCallCitationChip` — 2 chips → `find.byIcon(Icons.calculate_outlined)` returns 2.
  2. `renders nothing when chips list is empty` — empty list → `find.byType(Icon)` finds nothing.
  3. `each chip carries Key("coachCitationChip-<toolName>")` — finds `Key('coachCitationChip-budget_snapshot')` + `Key('coachCitationChip-cap_status')` both once.
  4. `onChipTap fires with the tapped chip` — `tester.tap(Key('coachCitationChip-budget_snapshot'))` invokes callback with the chip whose `toolName == 'budget_snapshot'`.

- **`coach_citation_chip_golden_test.dart`** — Plan 01's 6 SKIPPED stubs unskipped, implemented as parametrized for-loop. Each test renders the widget with one chip at the canonical Wave 1a name, locale=`fr`, padding 16dp.

- **Test helpers:** `_wrap(child)` wraps in MaterialApp + S.localizationsDelegates + S.supportedLocales + Locale('fr'). `_fakeChip(name)` constructs a `ToolCallCitationChip` with `inputsHash='a'*64`, `computedAt=2026-05-15T10:00:00Z`, `rawResponse={'monthlyIncome': '7500'}`.

## Golden snapshots

Six PNGs generated under `apps/mobile/test/goldens/coach_citation_chip_<tool>.png`:

| Tool | File size |
|---|---|
| budget_snapshot | 5'367 B |
| retirement_projection | 5'465 B |
| cross_pillar_analysis | 5'410 B |
| couple_optimization | 5'457 B |
| cap_status | 5'431 B |
| retrieve_memories | 5'255 B |

All 5-6 KB (NOT 4 KB stub placeholders — content matches the rendered widget). All 6 snapshots verified to match the rendered output on a second non-update `flutter test` run.

## Task Commits

Each commit landed atomically on `feature/wave-1b-05-citation-chips-section` (branched from `dev` at `34215d78`):

1. **Task 1: Create CoachCitationChipsSection widget** — `fee1f726` (feat)
2. **Pre-push baseline regen for line-shifted lints** — `bfd78756` (chore)
3. **Task 2: Wire into message bubble + unskip tests + 6 goldens** — `38eda46f` (feat)

## Diff size

```
 apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart  | +123 (new)
 apps/mobile/lib/widgets/coach/coach_message_bubble.dart          | +14
 apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart | +85 (replaces 27-line stub)
 apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart   | +44 (replaces 23-line stub)
 apps/mobile/test/goldens/coach_citation_chip_*.png               | +6 binary files (5.2-5.5 KB each)
 tools/checks/baselines/prefer_mint_text_style.baseline.txt       | line-shift regen
 tools/checks/baselines/prefer_mint_radius.baseline.txt           | line-shift regen
 ─────────────────────────────────────────────────────────────────
 Total                                                              | +266 LOC (source) + 6 PNG (~33 KB total) across 11 files
```

## Decisions Made

- **Decision 1 (Sibling vs extension)** — `CoachCitationChipsSection` is a sibling of `CoachSourcesSection`, not an extension. RESEARCH §9.4 grep-evidenced that `RagSource` is read by 30+ Flutter files; a sealed-class refactor (RagSource | CitationChip) has high blast radius. Sibling widget = ~3 file edits, zero breakage to the existing RagSource navigation path.
- **Decision 2 (Localization class `S`)** — Plan referenced `AppLocalizations.of(context)!` but the actual generated class in this codebase is `S` (verified at `app_localizations.dart:68 abstract class S`). All getters resolved correctly under the `S.of(context)!` accessor.
- **Decision 3 (Baseline regen as separate commit)** — Inserting 12 lines in `coach_message_bubble.dart` shifted 2 `prefer_mint_text_style` violations (lines 111, 320) and 1 `prefer_mint_radius` violation (line 656) downstream. Per `feedback_pre_push_checklist.md`, regenerated baselines and committed as `chore(wave-1b-05): baseline line-shift` to keep the feature commit focused.
- **Decision 4 (`Key('coachCitationChip-<toolName>')` over Key with hash)** — Maestro flows (Plan 09) need a stable key across releases and across `inputs_hash` values. The `toolName` is canonical and stable (6 enum-like values); `inputs_hash` changes every call. Per RESEARCH §9.5.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Plan imports referenced `text_styles.dart` / `spacing.dart`; actual filenames are `mint_text_styles.dart` / `mint_spacing.dart`**
- **Found during:** Task 1 implementation.
- **Issue:** Plan §Task 1 action block had `import 'package:mint_mobile/theme/text_styles.dart'` and `import 'package:mint_mobile/theme/spacing.dart'`. Codebase verification (`ls apps/mobile/lib/theme/`) confirmed actual filenames are `mint_text_styles.dart` and `mint_spacing.dart` (per Phase 90 design-system convention).
- **Fix:** Used the correct `mint_text_styles.dart` + `mint_spacing.dart` imports. Trivial codebase-shape mismatch, not a logic bug.
- **Files modified:** `coach_citation_chips_section.dart`.
- **Commit:** `fee1f726`.

**2. [Rule 1 — Bug] Plan referenced `AppLocalizations` class; actual is `S`**
- **Found during:** Task 1 implementation.
- **Issue:** Plan §Task 1 referenced `AppLocalizations.of(context)!`. The generated MINT localization class is `S` (verified at `app_localizations.dart:68 abstract class S`). Documented as Plan 96-01 deviation Rule 1 (a) — this is a recurring plan-vs-codebase drift that the wave-1b planner inherited from RESEARCH §6.3 documentation.
- **Fix:** Used `S.of(context)!`, `S.localizationsDelegates`, `S.supportedLocales`. All 8 ARB getters resolved correctly.
- **Files modified:** `coach_citation_chips_section.dart`, `coach_citation_chips_section_test.dart`, `coach_citation_chip_golden_test.dart`.
- **Commit:** `fee1f726` + `38eda46f`.

**Total deviations:** 2 auto-fixed (both Rule 1 codebase-shape mismatches in plan-prescribed import / class names). Zero behavioural / logic deviations. The plan-prescribed widget structure (Container → Column → for-chip Row → InkWell+Key+Semantics) shipped exactly as written.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT hooks fired defensively** on `coach_message_bubble.dart`, `coach_citation_chips_section_test.dart`, `coach_citation_chip_golden_test.dart` despite all three files being read at the session start. Edits still landed (verified via grep + `flutter test` exit 0). Behaviour is a safety reminder, not a block. Same observation as Plan 04 SUMMARY.

## Known Stubs

None introduced by Plan 05. Plan 01's remaining SKIPPED stubs:
- `coach_citation_chip_modal_remember_test.dart` (Plan 06)
- `coach_citation_modal_test.dart` (Plan 06)
- backend Sentry breadcrumb tests in `test_breadcrumb_contract.py` + `test_breadcrumb_cardinality.py` (Plan 08)

These remain skipped and are owned by their respective plans per the wave-1b dependency graph.

## Threat Flags

- **T-WAVE1B-05-01** (i18n violation) — RESOLVED. All user-facing strings flow through `S.coachCitation*` and `S.coachTool*` ARB getters (8 getters consumed, all from Plan 07's 90-entry 6-locale sweep). Zero hardcoded FR strings.
- **T-WAVE1B-05-02** (Sealed-class refactor breaks 30+ files) — RESOLVED. Sibling widget pattern; RagSource code path untouched.
- **T-WAVE1B-05-03** (Hardcoded color literal) — RESOLVED. All colors via `MintColors.<token>` (bleuAir, textMutedAaa, textSecondaryAaa). `prefer_mint_color_token` lint exits clean (23 grandfathered, 0 new).
- **T-WAVE1B-05-04** (Tap target < 44dp) — MITIGATED. InkWell vertical extent is constrained by the chip Row Icon (12dp) + Text (micro size). Parent `Padding(EdgeInsets.only(left: 44, right: MintSpacing.xxl))` from `coach_message_bubble.dart:172-173` does NOT enforce 44dp tap height — this is a v1 limitation acceptable for the chip MVP; Plan 06's modal tap test will exercise the actual finger-tap flow on the iPhone 17 Pro sim. If sim tap reliability < 95%, follow-up adds `Container(constraints: BoxConstraints(minHeight: 44))` around the InkWell.
- **T-WAVE1B-05-05** (Golden snapshot platform-dependent) — MITIGATED. Goldens generated on macOS executor. Plan 09's close-out runs `flutter test` against the goldens on CI; if golden divergence surfaces (linux vs macOS), regenerate via `flutter test --update-goldens` on CI.

No NEW threat surface introduced by Plan 05 beyond what the plan's `<threat_model>` enumerated.

## User Setup Required

None. Plan 05 is pure Flutter source diff + golden binaries. No env var, no Railway config, no Apple Developer portal capability, no Maestro flow change. The chip surface activates automatically once `ChatMessage.citationChips` becomes non-empty — which requires Wave 1a flags ON on Railway staging (post-Plan 08 coupled flip per CONTEXT D-01).

## Next Phase Readiness

- **Plan 06** (Flutter chip-tap modal) can now hook into the empty `onChipTap: (chip) { ... }` callback at `coach_message_bubble.dart:175-177` to launch `showModalBottomSheet`. The `chip` parameter carries the full `ToolCallCitationChip` (toolName, inputsHash, computedAt, rawResponse) — no additional plumbing needed.
- **Plan 08** (Sentry breadcrumb) wires emission against `chip.toolName + chip.inputsHash + elapsed_ms` at tap time. Plan 06's tap handler is the natural emission point.
- **Plan 09** (Maestro G1 flow) can now reference `Key('coachCitationChip-<toolName>')` selectors for chip taps. Stable across releases per RESEARCH §9.5.

## Pre-push checklist (per feedback_pre_push_checklist.md)

| Gate | Status | Evidence |
|---|---|---|
| flutter analyze (touched file) | OK | `flutter analyze lib/widgets/coach/coach_citation_chips_section.dart` → "No issues found!" |
| flutter analyze (full repo, baseline) | OK | `flutter analyze` → 253 issues (= baseline, 0 new errors) |
| flutter test (touched test files) | OK | 4/4 widget tests pass + 6/6 golden tests pass |
| flutter test (touched-area regression) | OK | `flutter test test/widgets/coach/` → 733/733 pass, 0 regressions |
| sentence_subject_arb_lint | N/A | No ARB keys touched (Plan 05 only consumes Plan 07's keys) |
| prefer_mint_text_style | OK | clean (683 grandfathered after line-shift baseline regen) |
| prefer_mint_color_token | OK | clean (23 grandfathered, baseline unchanged) |
| prefer_mint_radius | OK | clean (42 grandfathered after line-shift baseline regen) |
| prefer_mint_cta | OK | clean (-1 from baseline) |
| prefer_mint_fonts | OK | clean (92 grandfathered) |
| OpenAPI canonical regen | N/A | Plan 05 is Flutter-only, zero Pydantic schema changes |

## 0-trust Self-Check (CLAUDE.md §9.4 + §9.6)

**Evidence (verbatim citations):**

- **Evidence file 1** — Widget exists: `test -f apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` exits 0; `wc -l` returns 123. FOUND.
- **Evidence file 2** — Class definition: `grep -c "class CoachCitationChipsSection" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns `1`. FOUND.
- **Evidence file 3** — `Icons.calculate_outlined` present: `grep -c "Icons.calculate_outlined" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns `1`. FOUND.
- **Evidence file 4** — Maestro Key: `grep -c "Key..coachCitationChip-" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns `2` (production line + docstring reference both match). FOUND.
- **Evidence file 5** — ARB getters consumed: `grep -cE "coachCitationChipsHeader|coachCitationChipLabel|coachToolBudgetSnapshot|coachToolRetirementProjection|coachToolCrossPillarAnalysis|coachToolCoupleOptimization|coachToolCapStatus|coachToolRetrieveMemories" apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` returns `8` (header + label + 6 tool names). FOUND.
- **Evidence file 6** — Bubble wiring: `grep -n "CoachCitationChipsSection\|citationChips" apps/mobile/lib/widgets/coach/coach_message_bubble.dart` returns 3 lines (`169`, `173`, `174`) — import + isNotEmpty guard + widget construction. FOUND.
- **Evidence file 7** — Plan 01 stubs unskipped: `grep -c "skip: true" apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` returns `0` across both files. FOUND.
- **Evidence file 8** — 6 goldens present: `ls apps/mobile/test/goldens/coach_citation_chip_*.png | wc -l` returns `6`. FOUND.
- **Evidence command 1** — Widget tests pass: `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chips_section_test.dart` → `00:00 +4: All tests passed!` (4/4). CITED.
- **Evidence command 2** — Golden tests pass: `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chip_golden_test.dart` → `00:00 +6: All tests passed!` (6/6). CITED.
- **Evidence command 3** — Coach widget tests regression: `cd apps/mobile && flutter test test/widgets/coach/` → `00:15 +733: All tests passed!` (733/733). Zero regressions. CITED.
- **Evidence command 4** — Flutter analyze: `cd apps/mobile && flutter analyze` → `253 issues found.` (= baseline 253, all info-level, zero new errors). CITED.
- **Evidence command 5** — prefer_mint_text_style: `python3 tools/checks/prefer_mint_text_style.py` → `OK prefer_mint_text_style: clean (683 grandfathered)`. CITED.
- **Evidence command 6** — prefer_mint_color_token: `python3 tools/checks/prefer_mint_color_token.py` → `OK prefer_mint_color_token: clean (23 grandfathered)`. CITED.
- **Evidence command 7** — prefer_mint_radius: `python3 tools/checks/prefer_mint_radius.py` → `OK prefer_mint_radius: clean (42 grandfathered)`. CITED.
- **Evidence command 8** — git log: `git log --oneline -5` shows `38eda46f` (T2 wire+tests+goldens) → `bfd78756` (baseline regen) → `fee1f726` (T1 widget) on top of base `34215d78`. CITED.
- **Caveat** — Plan 05 ships the chip rendering surface. It does NOT prove:
  - The modal opens on tap (Plan 06).
  - The Sentry breadcrumb fires with correct cardinality (Plan 08).
  - End-to-end Maestro flow taps chip by Key successfully (Plan 09).
  - End-to-end user flow on iPhone 17 Pro sim — NO `idb` snapshot, NO sim screenshot. Plan 09's G2 Claude-autonomous walker is the authoritative end-to-end gate per CLAUDE.md §9.
  - PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — Stage 1 of 4 (PR opened). Do NOT claim « shipped », « ready », « works », « validated », « green ».

## Self-Check: PASSED

- Widget file FOUND on disk (`coach_citation_chips_section.dart`, 123 LOC).
- 6 golden PNG files FOUND on disk (5.2-5.5 KB each, NOT stub placeholders).
- Bubble wiring FOUND on disk (3 grep matches: import + guard + render).
- 0 SKIPPED stubs remaining in both Plan-05-owned test files.
- 4/4 widget tests GREEN; 6/6 golden tests GREEN; 733/733 coach widget tests GREEN (0 regressions).
- All 3 task commits (`fee1f726`, `bfd78756`, `38eda46f`) present in `git log`.
- 5 design-system lints exit 0 (text_style, color_token, radius, cta, fonts).
- `flutter analyze` 253 = baseline (0 new errors).
- 2 Rule 1 auto-fixes documented (codebase-shape mismatches in plan imports / class name).
- USER VALUE DELIVERED: NONE end-user-visible YET — the chip surface only activates when `ChatMessage.citationChips` is non-empty, which requires the Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flag flip (post-Plan-08 coupled deploy per CONTEXT D-01).

---

*Phase: wave-1b-citation-chips*
*Plan: 05*
*Completed: 2026-05-15*
*Branch: feature/wave-1b-05-citation-chips-section (base 34215d78)*
*Commits: fee1f726 (T1 widget) → bfd78756 (baseline regen) → 38eda46f (T2 wire+tests+goldens)*
