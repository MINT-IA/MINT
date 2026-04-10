# Phase 1: P0a — Code Unblockers (rescoped 2026-04-07) - Context

**Gathered:** 2026-04-07 (assumptions mode, autonomous)
**Status:** Ready for planning

<domain>
## Phase Boundary

Kill the v2.1 code carryover that blocks Phase 2+:
1. Verify/wire the 4 providers that `mint_home_screen.dart` depends on (STAB-19).
2. Rename `chiffre_choc` → `premier_eclairage` across the live surface (STAB-20).
3. Send 6 a11y recruitment emails fire-and-forget + create the tracker (ACCESS-01).
4. Clear any P0a items in `.planning/backlog/STAB-carryover.md` (STAB-21).

**Explicitly deferred to Phase 12 ship gate** (not this phase): STAB-18 walkthrough, PERF-01..04 Galaxy A14 baseline.

**Out of scope:** any design/UX work, any Phase 2+ contracts/tokens/audits, any migration of surfaces to MTC.
</domain>

<decisions>
## Implementation Decisions

### D-01: Provider Registration (STAB-19) — Verification, not rewire
The 4 providers (`MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`) are **already registered** in `apps/mobile/lib/app.dart:1010-1013`. STAB-19 collapses to:
  1. `git grep ProviderNotFoundException apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` returns 0.
  2. `flutter analyze lib/` is 0 errors.
  3. Widget smoke test (`flutter test test/smoke/mint_home_smoke_test.dart`) pumps `MintHomeScreen` inside the app's MultiProvider shell and asserts no `ProviderNotFoundException`.
  4. No ProxyProvider upgrade needed — the 4 providers are independent `ChangeNotifier`s (verified: no cross-reads in their constructors).

### D-02: chiffre_choc → premier_eclairage Rename (STAB-20) — Atomic layered commits
Sequence (each commit independently revertable, each lands `flutter analyze 0 + flutter test green + pytest green` before the next):
  1. **Commit L1 — Backend source + tests:** rename `services/backend/app/services/onboarding/chiffre_choc_selector.py` → `premier_eclairage_selector.py`, rename `services/backend/tests/test_chiffre_choc.py` → `test_premier_eclairage.py`, update imports, `ruff check` 0, `pytest -q` green.
  2. **Commit L2 — Backend API schemas + OpenAPI regen:** rename Pydantic fields, regenerate `tools/openapi/openapi.json` (113 hits), commit the diff. CI drift guard green.
  3. **Commit L3 — Flutter sources (filenames + Dart classes):** rename `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart`, `instant_chiffre_choc_screen.dart`, `lib/services/chiffre_choc_selector.dart` + tests. Rename classes. Update all imports + GoRouter routes. `flutter analyze lib/` 0.
  4. **Commit L4 — ARB keys + gen-l10n:** rename in all 6 ARB files (`chiffreChoc*` → `premierEclairage*`), run `flutter gen-l10n`, commit regenerated `app_localizations_*.dart`. `flutter analyze` + `flutter test` green.
  5. **Commit L5 — Analytics events:** hard rename in `apps/mobile/lib/services/analytics_events.dart` (pre-launch, no warehouse contract → no dual-emit).
  6. **Commit L6 — Residue sweep + CI grep gate:** add `tools/checks/no_chiffre_choc.py` that fails CI on any match in `apps/mobile/lib/`, `services/backend/app/`, `apps/mobile/lib/l10n/`, `tools/openapi/`. Exclusions baked in: `.planning/**`, `docs/archive/**`, `apps/mobile/archive/**`, `CLAUDE.md` legacy note. Commit the gate.
  7. **Commit L7 — Docs + CLAUDE.md legacy note update:** flip the legacy note to "rename completed 2026-04-07".

### D-03: ACCESS-01 Tracker — Create skeleton, Julien sends emails
  - Claude creates `docs/ACCESSIBILITY_TEST_LAYER1.md` with columns: `Partner | Contact name | Email | Date sent | Reply received | Session date | Compte-rendu link | Status`.
  - 6 rows pre-filled: 2× SBV-FSA, 2× ASPEDAH, 2× Caritas.
  - Julien sends the 6 emails personally and flips the "Date sent" column.
  - Phase 1 completion requires: file exists, 6 rows present, Julien confirms "emails sent" in chat. Does NOT block on replies or session scheduling (fire-and-forget per ROADMAP line 58).

### D-04: Golden Test Infrastructure Foundation — Deferred to Phase 4 (expert decision 2026-04-07)
Two decisions taken in autonomous mode to reduce user-touch budget:
  - **D-04a:** A generic golden test helper (`test/goldens/helpers/screen_pump.dart`) + 5 `testWidgets` skeletons for S0-S5 are added as a new plan in **Phase 4** (L1.2a MTC + S4 Migration), NOT in Phase 1. Rationale: Phase 1 is pure code-unblocker, no UI surface touched. Phase 4 is the first phase that ships a surface (S4) and benefits from goldens immediately.
  - **D-04b:** The helper uses **dual device targets**: iPhone 14 Pro (390×844 @ 3.0x) + Galaxy A14 (1080×2408 @ 2.625x). Rationale: A14 goldens catch TextOverflow / width regressions without a physical device, which pre-filters bugs before Phase 10.5 Friction Pass and shortens that human touch.
  - **Consequence:** Phase 8c Polish Pass #1 becomes "Claude reads goldens + writes delta report", no human touch needed. **Touch budget drops from 7 to 6.** T3 is removed from the supervision plan.

### Claude's Discretion
  - Exact wording of the smoke test for STAB-19.
  - Whether to split Commit L3 into sub-commits per filename (only if `git mv` + import update exceeds ~40 file touch).
  - Exact column widths / markdown formatting of `ACCESSIBILITY_TEST_LAYER1.md`.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 scope + requirements
- `.planning/ROADMAP.md` §Phase 1 (lines 53-65) — full success criteria
- `.planning/REQUIREMENTS.md` — STAB-19, STAB-20, STAB-21, ACCESS-01 entries
- `.planning/backlog/STAB-carryover.md` — all carryover items, filter by P0a tag
- `.planning/research/SUMMARY.md` — STAB + ACCESS-01 research context

### Provider registration (STAB-19)
- `apps/mobile/lib/app.dart` lines 971-1013 (MultiProvider declaration)
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` lines 52, 124, 298, 332, 638 (provider consumption sites)
- `apps/mobile/lib/providers/mint_state_provider.dart`
- `apps/mobile/lib/providers/financial_plan_provider.dart`
- `apps/mobile/lib/providers/coach_entry_payload_provider.dart`
- `apps/mobile/lib/providers/onboarding_provider.dart`

### chiffre_choc rename surface (STAB-20)
- `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` (47 hits)
- `apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart` (31 hits)
- `apps/mobile/lib/services/chiffre_choc_selector.dart` (50 hits)
- `apps/mobile/test/services/chiffre_choc_selector_test.dart` (51 hits)
- `services/backend/app/services/onboarding/chiffre_choc_selector.py` (23 hits)
- `services/backend/tests/test_chiffre_choc.py` (37 hits)
- `tools/openapi/openapi.json` (113 hits — regenerated)
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` (6 files)
- `apps/mobile/lib/services/analytics_events.dart` (2 hits)
- `CLAUDE.md` (legacy note, line 3)

### ACCESS-01
- `docs/ACCESSIBILITY_TEST_LAYER1.md` — **does not exist, to be created**
- `.planning/REQUIREMENTS.md` — ACCESS-01 (partner list, email template hints if present)

### Expert decisions log
- This file §decisions D-04 — golden helper deferral + dual device targets
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/app.dart` MultiProvider — providers already declared, just verify.
- `apps/mobile/test/` existing smoke test patterns — reuse for STAB-19 verification.
- `tools/openapi/` codegen pipeline — will regenerate `openapi.json` cleanly post-rename.

### Established Patterns
- Atomic commits per layer is standard MINT git discipline (CLAUDE.md §4, `rules.md`).
- ARB rename workflow: edit all 6 → `flutter gen-l10n` → `flutter analyze` → commit all regenerated files.
- CI grep gates: precedent in `tools/checks/` (e.g., `no_llm_alert.py` planned for Phase 9).

### Integration Points
- STAB-19 touches only `app.dart` (no-op expected) and `mint_home_screen.dart` (runtime verification).
- STAB-20 touches every layer but Phase 2+ work depends on the rename being done — blocker for Phase 2 contracts.
- ACCESS-01 tracker lives in `docs/` — no code integration, feeds Phase 8b and Phase 12 gates.
</code_context>

<specifics>
## Specific Ideas

- CI grep gate must exclude `.planning/`, `docs/archive/`, `apps/mobile/archive/`, and the CLAUDE.md legacy note (these are historical records).
- `CLAUDE.md` legacy note stays but flips from "uses chiffre choc" → "rename completed 2026-04-07 — legacy term retained in archives only".
- Commit L6 residue sweep is the "acceptance test" — it must land green before Phase 1 closes.
</specifics>

<deferred>
## Deferred Ideas

- **STAB-18 walkthrough + PERF-01..04 Galaxy A14 baseline** — deferred to Phase 12 ship gate per ROADMAP rescope 2026-04-07.
- **Golden test helper + S0-S5 skeletons** — moved to Phase 4 (first phase that ships a surface). Phase 1 does not touch any UI surface, so goldens would have nothing to capture.
- **Dual-emit analytics shim** — rejected (no production warehouse contract; pre-launch telemetry only).
- **Deprecation alias for ARB keys** — rejected (no external ARB consumers; in-place rename is safe).
</deferred>

---

*Phase: 01-p0a-code-unblockers*
*Context gathered: 2026-04-07*
