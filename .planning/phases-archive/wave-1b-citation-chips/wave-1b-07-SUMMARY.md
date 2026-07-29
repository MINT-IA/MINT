---
phase: wave-1b-citation-chips
plan: 07
subsystem: i18n
tags: [arb, i18n, flutter-gen-l10n, icu-plural, citation-chips, fr, en, de, es, it, pt]

# Dependency graph
requires:
  - phase: wave-1a-backend-tools-refactor
    provides: 6 server-side coach tools whose display names this plan localizes
  - phase: wave-1b-citation-chips (plans 01-04)
    provides: tool_call_id source kind contract + ToolCallCitationChip Dart model
provides:
  - 15 ARB keys × 6 locales = 90 entries (5 frame + 6 tool-name + 4 Q8 relative-time)
  - flutter gen-l10n regenerated AppLocalizations exposing 15 new getters/methods
  - ICU plural-aware methods for 3 count-bearing relative-time keys (int count signatures)
affects: [wave-1b-05, wave-1b-06, wave-1b-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ICU MessageFormat plural syntax for count-bearing localized strings"
    - "Strict CLAUDE.md TOP-5 i18n: tool display names live in ARB, not Dart const maps"

key-files:
  created:
    - .planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md
  modified:
    - apps/mobile/lib/l10n/app_fr.arb (75 lines added — 15 keys + @-metadata)
    - apps/mobile/lib/l10n/app_en.arb (15 lines added)
    - apps/mobile/lib/l10n/app_de.arb (15 lines added)
    - apps/mobile/lib/l10n/app_it.arb (15 lines added)
    - apps/mobile/lib/l10n/app_es.arb (15 lines added)
    - apps/mobile/lib/l10n/app_pt.arb (15 lines added)
    - apps/mobile/lib/l10n/app_localizations.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_{fr,en,de,it,es,pt}.dart (regen)

key-decisions:
  - "Q6_DECISION shipped: 90 entries (15 keys × 6 locales) instead of CONTEXT line 41's 30 entries — strict CLAUDE.md TOP rule #5 i18n compliance for the 6 tool display names + Q8 4 relative-time keys"
  - "Q8_DECISION shipped: 4 relative-time keys land in ARB (not Dart literals) to prevent silent FR-only leak in modal's computed_at row across en/de/es/it/pt"
  - "Atomic 6-locale commit: lefthook arb-parity-gate fails closed between locale-by-locale commits; Task 1+2 merged into single ARB commit (Rule 3 deviation)"

patterns-established:
  - "ICU plural syntax for count-bearing strings: {count, plural, =1{...} other{...}} — produces (int count) method signature in generated AppLocalizations"
  - "FR doesn't pluralize 'min'/'h'/'j' so =1 and other branches read identically — still required for code-gen"
  - "Atomic ARB updates across all 6 locales in a single commit (parity gate is the contract)"

requirements-completed: [WAVE1B-06]

# Metrics
duration: 5min
completed: 2026-05-15
---

# Phase wave-1b Plan 07: ARB Citation Keys Summary

**15 citation-chip ARB keys (frame + tool-name + ICU-plural relative-time) added to all 6 locales — 90 entries, flutter gen-l10n green, plans 05+06 compilable**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-15T08:03:51Z
- **Completed:** 2026-05-15T08:08:52Z
- **Tasks:** 2 (Task 1 FR+EN + Task 2 DE/IT/ES/PT + gen-l10n, merged into 2 commits)
- **Files modified:** 13 (6 ARB + 7 generated dart)

## Accomplishments

- 15 new ARB keys consistently added across fr/en/de/es/it/pt (90 total entries)
- 5 frame keys (Header, ChipLabel, ModalTitle, JsonViewerLabel, RememberCta) verbatim from RESEARCH §6.3
- 6 tool-display-name keys i18n'd (CLAUDE.md TOP rule #5 strict compliance, NOT a Dart const map)
- 4 Q8 relative-time keys with 3 ICU plural-aware methods (`(int count)` signatures)
- flutter gen-l10n regenerated 7 dart files; method signatures match plan spec (`String coachCitationChipLabel(String toolDisplayName)`, `String coachCitationRelativeMinutes(int count)`)
- All 5 deterministic gates green (JSON parse × 6, ARB parity, banned-terms × 6 locales, accent FR, flutter analyze 0 new errors)

## Task Commits

1. **Task 1+2 (merged): Add 15 ARB keys to 6 locales** — `49142b79` (feat)
2. **Task 2 cont.: flutter gen-l10n regen** — `886a6fd1` (chore)

_Task 1 and Task 2 were merged into the first commit because lefthook's `arb-parity-gate` fails closed on intermediate per-locale commits — atomic 6-locale update preserves the gate's fail-closed contract (Rule 3 deviation, documented below)._

## Files Created/Modified

- `apps/mobile/lib/l10n/app_fr.arb` — 15 new keys + @-metadata (FR reference, RESEARCH §6.3 verbatim)
- `apps/mobile/lib/l10n/app_en.arb` — 15 new keys (EN translations)
- `apps/mobile/lib/l10n/app_de.arb` — 15 new keys (DE translations, mechanical)
- `apps/mobile/lib/l10n/app_it.arb` — 15 new keys (IT translations, mechanical)
- `apps/mobile/lib/l10n/app_es.arb` — 15 new keys (ES translations, mechanical)
- `apps/mobile/lib/l10n/app_pt.arb` — 15 new keys (PT translations, mechanical)
- `apps/mobile/lib/l10n/app_localizations.dart` — abstract base class with 15 new getters/methods
- `apps/mobile/lib/l10n/app_localizations_{fr,en,de,it,es,pt}.dart` — per-locale concrete implementations

## Decisions Made

- **Q6_DECISION executed: 90 entries (NOT 30)** — strict CLAUDE.md TOP rule #5 i18n. Surfaced in plan frontmatter as the doctrine i18n path. 6 tool-display-name keys would otherwise live as a Dart `static const Map<String,String>` (legacy pattern), creating a silent FR-only leak to en/de/es/it/pt that ARB parity gate cannot detect.
- **Q8_DECISION executed: 4 relative-time keys land in ARB** — modal's `_relativeTime` helper reads ARB keys, not Dart literals. 3 of 4 (Minutes/Hours/Days) use ICU plural syntax to produce `(int count)` method signatures.
- **FR ICU plural identical branches**: FR doesn't pluralize « min »/« h »/« j » so `=1` and `other` branches read identically — required for code-gen to produce the `(int count)` signature.
- **Atomic 6-locale commit** — locale-by-locale commits would each fail the `arb-parity-gate` lefthook hook (correct behavior per CONTEXT D-06). One atomic commit across all 6 locales preserves the gate's fail-closed semantics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Merged Task 1 (FR+EN) and Task 2 (DE/IT/ES/PT) into a single ARB commit**

- **Found during:** Task 1 commit attempt
- **Issue:** Plan structured Task 1 (FR+EN) and Task 2 (DE/IT/ES/PT + gen-l10n) as separate commits. Lefthook `arb-parity-gate` fails closed between the two states (FR+EN have 15 new keys, DE/IT/ES/PT don't yet) — correct gate behavior per CONTEXT D-06.
- **Fix:** Composed all 6 locales' edits before staging, then committed as one atomic `feat(wave-1b-07): add 15 citation-chip ARB keys across 6 locales`. Generated dart files committed separately as `chore(wave-1b-07): flutter gen-l10n …`.
- **Files modified:** All 6 `app_*.arb` files in commit `49142b79`; 7 generated `app_localizations*.dart` in `886a6fd1`.
- **Verification:** `arb-parity-gate` ran via lefthook on commit `49142b79` and passed (0.06s, exit 0). `banned-terms-arb-gate` also passed.
- **Committed in:** `49142b79` (atomic ARB), `886a6fd1` (gen-l10n)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** Zero scope drift. The merged commit respects the gate's fail-closed contract more cleanly than two-step commits with a transient parity failure.

## 0-Trust Self-Check

Deterministic citations per CLAUDE.md §9.4:

| Claim | Evidence (cited) |
|---|---|
| ARB parity green | `python3 tools/checks/arb_parity.py` → `OK — 6 locale(s) parity (reference=fr, 6777 keys each)` exit 0 |
| Banned-terms clean (6 locales) | `python3 tools/checks/banned_terms_arb.py` → `OK — 6 locale(s) clean (no positive LSFin banned-term uses)` exit 0 |
| Accent lint clean on FR | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` exit 0 |
| FR JSON parses with all 15 keys | `python3 -c "json.load … 15 keys present"` → `fr: OK 7630 keys` |
| EN/DE/IT/ES/PT JSON parses with all 15 keys | same → `en: OK 7436 keys`, `de: OK 7436`, `it: OK 7436`, `es: OK 7436`, `pt: OK 7436` |
| flutter gen-l10n exit 0 | `cd apps/mobile && flutter gen-l10n` → exit 0 |
| Generated method signatures correct | `grep -n "coachCitationRelativeMinutes\|coachCitationChipLabel" apps/mobile/lib/l10n/app_localizations.dart` → `String coachCitationChipLabel(String toolDisplayName);` (line 14071), `String coachCitationRelativeMinutes(int count);` (line 14137) |
| flutter analyze no new errors | `cd apps/mobile && flutter analyze 2>&1 \| grep -cE "^\s+error "` → `0`; total `253 issues` (DOWN from baseline 273) |
| Commits exist on branch | `git log --oneline -3` → `886a6fd1 chore(wave-1b-07)…`, `49142b79 feat(wave-1b-07)…` |

**USER VALUE DELIVERED:** NONE end-user-visible YET (per CLAUDE.md §9.5 « PR opened ≠ shipped » trap). Plan 07 ships the i18n surface only. Plans 05 (CoachCitationChipsSection widget) + 06 (CoachCitationModal widget) consume these getters; the chip is only user-visible once those widgets render against real `citationChips` payloads from the backend (Plans 02-04 round-trip). End-to-end sim verification deferred to Plan 09 close-out (5-gate G1 Maestro flow).

## Issues Encountered

None — plan's `<interfaces>` block contained verbatim copy + DE/IT/ES/PT translations, plan executed cleanly. Only deviation was the commit-granularity reshape forced by the parity gate (documented above).

## User Setup Required

None — no external services touched.

## Next Phase Readiness

- **Plan 05 (CoachCitationChipsSection)** — can now compile against `S.coachCitationChipsHeader` + `S.coachCitationChipLabel(toolDisplayName)` + 6 `S.coachTool*` getters.
- **Plan 06 (CoachCitationModal)** — can now compile against `S.coachCitationModalTitle(toolDisplayName)` + `S.coachCitationJsonViewerLabel` + `S.coachCitationRememberCta` + 4 `S.coachCitationRelative*` getters (incl. 3 plural-aware `(int count)` methods).
- **Plan 09 close-out** — `wave_1b_close.sh` G5 gate will re-run `arb_parity.py` + `banned_terms_arb.py` + `accent_lint_fr.py`; all 3 already green on this branch.

## Self-Check: PASSED

All 9 claims above cited deterministically. No banned phrases used without citation per CLAUDE.md §9.1.

---
*Phase: wave-1b-citation-chips*
*Plan: 07*
*Completed: 2026-05-15*
