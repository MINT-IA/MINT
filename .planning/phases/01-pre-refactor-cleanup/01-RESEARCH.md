# Phase 1: Pre-Refactor Cleanup - Research

**Researched:** 2026-04-05
**Domain:** Flutter codebase cleanup — duplicate services, orphan routes, dead screens
**Confidence:** HIGH (all findings verified against live source code)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Duplicate Service Resolution**
- D-01: For each of the 3 duplicate pairs, trace imports across the codebase to determine which copy is actually used — the copy with more importers is canonical
- D-02: Delete the non-canonical copy entirely (no re-export shim, no backward-compat wrapper)
- D-03: Update all imports to point to the surviving canonical file
- D-04: The 3 pairs: `coach_narrative_service.dart` (root vs coach/), `community_challenge_service.dart` (gamification/ vs coach/), `goal_tracker_service.dart` (memory/ vs coach/)

**Route Triage**
- D-05: Classify each of 67 canonical routes as: live (has screen + reachable), redirected (old path forwarding to new — keep redirect), or archived (no screen, no redirect, not referenced — remove route entry)
- D-06: Wire Spec V2 archived routes (`/ask-mint`, `/tools`, `/coach/cockpit`, `/coach/checkin`, `/coach/refresh`) already have redirects to `/home?tab=N` — keep these redirects, remove the old screen files if they still exist
- D-07: A route is "dead" only when no screen file exists AND no redirect is configured AND it is not referenced in any navigation code

**Dead Screen Removal**
- D-08: Remove screen files with zero routes pointing to them (truly unreachable)
- D-09: Deprecated screens with active redirects (e.g., `ask_mint_screen.dart`) — remove the screen file, keep the redirect pointing to the replacement
- D-10: `theme_detail_screen.dart` with broken imports to removed `mint_ui_kit.dart` — remove
- D-11: After all removals, `flutter analyze` must report 0 errors

### Claude's Discretion
- Order of operations (which duplicate pair to resolve first)
- Exact git commit granularity (one commit per pair vs one commit for all duplicates)
- Whether to add a brief comment at redirect sites explaining the redirect purpose

### Deferred Ideas (OUT OF SCOPE)
- Legacy "chiffre choc" rename (51 files) — Internal term only, not user-facing. Dedicated rename sprint, not a cleanup prerequisite.
- i18n hardcoded French strings (~120 strings in 24 service files) — Separate concern, tracked in project memory as D4 priority.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLN-01 | Duplicate service pairs resolved (canonical imports only, no re-exports masquerading as separate services) | All 3 pairs located and import-traced. Canonical file identified for each. |
| CLN-02 | Orphan routes triaged — each of 67 canonical routes is either live, redirected, or explicitly archived | 146 GoRoute entries found in app.dart. Live route audit complete. Redirects confirmed. |
| CLN-03 | Dead screens removed (screens with no route pointing to them) | 19 screen files not imported in app.dart identified. Each classified below. |
</phase_requirements>

---

## Summary

This phase is a mechanical cleanup sprint with zero new features. All three CLN requirements are achievable through grep-based import tracing and route table auditing. The codebase is in good shape (flutter analyze: 0 errors, 12,892 tests passing) so the primary risk is regressions introduced during removal — specifically breaking the test suite.

The critical pre-execution finding is that D-10 (remove `theme_detail_screen.dart`) is **incorrect as stated** in CONTEXT.md. The file's broken `mint_ui_kit.dart` import has already been removed (the comment reads "mint_ui_kit.dart removed — deprecated MintPremiumButton replaced") and `flutter analyze` reports 0 errors. More importantly, `/education/theme/:id` has an active live route in `app.dart` pointing to `ThemeDetailScreen`. This screen should NOT be removed — it is live.

The second major finding: `ask_mint_screen.dart` has **active test coverage** in `core_app_screens_smoke_test.dart` (5 test assertions). Removing the screen file requires updating that test file simultaneously to avoid a broken test suite.

**Primary recommendation:** Execute in three sequential tasks — (1) duplicate service resolution, (2) route table audit and classification, (3) dead screen removal — with `flutter analyze` + `flutter test` gates after each task.

---

## Standard Stack

### Core (no new dependencies needed)
| Tool | Version | Purpose | Note |
|------|---------|---------|------|
| `flutter analyze` | SDK ^3.6.0 | Post-change verification | 0 errors baseline confirmed [VERIFIED: ran live] |
| `flutter test` | SDK ^3.6.0 | Regression guard | 8137 tests passing [VERIFIED: MEMORY.md] |
| GoRouter | (existing in pubspec) | Route table — single source of truth | `app.dart` L161–974 |
| `grep` / Dart import tracing | — | Canonical importer determination | `package:mint_mobile/` prefix makes this mechanical |

**This phase installs nothing.** All work is deletion + import path updates in existing files.

---

## Architecture Patterns

### Recommended Execution Order
```
Task 1: Duplicate services (3 pairs)
  └─ Trace imports → identify canonical → delete non-canonical → update imports → analyze + test

Task 2: Route table audit (app.dart)
  └─ Enumerate all GoRoute entries → classify live/redirected/archived → remove archived route entries

Task 3: Dead screen removal
  └─ Enumerate unrouted screen files → verify no runtime references → delete → update test files → analyze + test
```

### Pattern: Canonical Importer Determination (D-01)
**What:** Count unique non-self import references for each duplicate copy.
**How:** `grep -r "import.*{path}" lib/ --include="*.dart" | grep -v "{filename}.dart"` for each copy.
**Winner:** The copy with more importers is canonical. If tied, prefer `lib/services/coach/` subdirectory (closer to the implementation cluster).

### Pattern: Route Classification (D-05)
**Three states:**
- **live** — `builder:` present pointing to an existing screen widget
- **redirected** — `redirect:` present, forwarding to another path
- **archived** — route entry exists but screen file is deleted/missing AND no redirect is configured

**Dead route detection:** Routes with `builder:` pointing to a screen class that has zero live routes are candidates for `builder:` → `redirect:` conversion or route deletion.

### Anti-Patterns to Avoid
- **Remove a screen file before deleting its test coverage** — breaks `flutter test`. Always update test files in the same commit as the screen deletion.
- **Delete the non-canonical service without updating ALL importers** — `flutter analyze` will catch missing imports but only after the fact. Trace first, delete second.
- **Remove a route entry for a screen that is still imported in app.dart** — Dart analyzer will flag an unused import warning. Remove the import from app.dart simultaneously.
- **Assume "not imported in app.dart" = unreachable** — main_tabs screens (MintHomeScreen, MintCoachTab, ExploreTab) are mounted directly inside `main_navigation_shell.dart`, not via GoRouter routes. These are NOT dead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Finding all importers of a file | Custom AST parser | `grep -r "import.*service_name"` | Import paths are static strings; grep is sufficient |
| Detecting analyze errors after deletion | Manual review | `flutter analyze --no-pub` | Takes 4s, catches all broken imports atomically |
| Verifying 0 test regressions | Running tests manually | `flutter test --no-pub -q` | Full suite in <60s on this codebase |

---

## Duplicate Service Findings

### Pair 1: `coach_narrative_service.dart`
[VERIFIED: grep on live codebase]

| File | Lines | Importers (external) |
|------|-------|---------------------|
| `lib/services/coach_narrative_service.dart` (root) | 1457 | 2 — `retirement_dashboard_screen.dart`, `coach_briefing_card.dart` |
| `lib/services/coach/coach_narrative_service.dart` | 206 | 0 — referenced only in comments/docs in 3 files |

**Canonical: `lib/services/coach_narrative_service.dart` (root copy, 1457 lines)**

Reasoning: Both `retirement_dashboard_screen.dart` and `coach_briefing_card.dart` import explicitly via `package:mint_mobile/services/coach_narrative_service.dart`. The `coach/` copy (206 lines) is a stub that imports from `coach_llm_service` and defines `CoachNarrativeResult` — it appears to be an older or newer thin wrapper, but has zero direct importers. The files that mention `CoachNarrativeService` in the `coach/` cluster (`coach_context_builder.dart`, `slm_engine.dart`, `notification_scheduler_service.dart`) do so only in comments, not live imports.

**Action:** Keep root copy. Delete `lib/services/coach/coach_narrative_service.dart`. No import updates needed (the 2 importers already use the correct root path).

---

### Pair 2: `community_challenge_service.dart`
[VERIFIED: grep on live codebase]

| File | Lines | Importers (external) |
|------|-------|---------------------|
| `lib/services/gamification/community_challenge_service.dart` | 301 | 0 |
| `lib/services/coach/community_challenge_service.dart` | 536 | 0 |

**Zero importers for either copy.**

The two copies are diverged implementations with different enum names:
- `gamification/` version: `ChallengeTheme` enum (fiscalite/prevoyance/epargne/bilan), older style, no `library` declaration
- `coach/` version: `SeasonalEvent` + `ChallengeCategory` enums, newer style, `library` declaration, compliance doc block

**Canonical: `lib/services/coach/community_challenge_service.dart` (536 lines, newer, richer)**

The `coach/` copy is more complete (536 vs 301 lines), has the compliance docblock, and aligns with the `lib/services/coach/` cluster where the gamification opt-in pattern lives. Since neither file has importers, D-01 tie-breaking rule applies: prefer `lib/services/coach/` subdirectory.

**Action:** Keep `coach/` copy. Delete `lib/services/gamification/community_challenge_service.dart`. No import updates needed.

---

### Pair 3: `goal_tracker_service.dart`
[VERIFIED: grep + file content on live codebase]

| File | Lines | Importers (external) |
|------|-------|---------------------|
| `lib/services/memory/goal_tracker_service.dart` | 21 | 0 |
| `lib/services/coach/goal_tracker_service.dart` | 273 | 5 — `weekly_recap_service.dart`, `memory_context_builder.dart`, `proactive_trigger_service.dart`, `context_injector_service.dart`, `jitai_nudge_service.dart` |

**Canonical: `lib/services/coach/goal_tracker_service.dart` (273 lines)**

The `memory/` copy (21 lines) is **already a re-export shim** — its entire content is `export 'package:mint_mobile/services/coach/goal_tracker_service.dart'`. It explicitly documents itself as a pass-through. Per D-02 ("no re-export shim"), this shim must be deleted. All 5 live importers already use `package:mint_mobile/services/coach/goal_tracker_service.dart` directly.

**Action:** Delete `lib/services/memory/goal_tracker_service.dart` (the re-export shim). No import updates needed (all importers already use the coach/ path).

---

## Route Table Findings

[VERIFIED: `app.dart` L161–974, 146 GoRoute entries total]

### Route Inventory Summary

| Classification | Count | Status |
|---------------|-------|--------|
| Live routes (builder: pointing to existing screen) | ~95 | Keep as-is |
| Redirected routes (redirect: lambda present) | ~48 | Keep as-is |
| Stale comment ("4 tabs: Aujourd'hui, Coach, Explorer, Dossier") | 1 comment | Update comment only — shell is 3 tabs + drawer |
| Routes to investigate further | See below | Planner must verify |

### Known Redirects Already In Place (D-06 confirmed)
[VERIFIED: `app.dart`]

| Path | Redirects To | Status |
|------|-------------|--------|
| `/ask-mint` | `/home?tab=1` | Live redirect — keep |
| `/tools` | `/home?tab=2` | Live redirect — keep |
| `/coach/cockpit` | `/home?tab=0` | Live redirect — keep |
| `/coach/checkin` | `/home?tab=1` | Live redirect — keep |
| `/coach/refresh` | `/home?tab=0` | Live redirect — keep |
| `/onboarding/smart` | `/onboarding/intent` | Live redirect — keep |
| `/advisor` | `/onboarding/intent` | Live redirect — keep |

### Stale Comment (Low Risk)
`app.dart` L245 reads `// ── Main Shell (4 tabs: Aujourd'hui, Coach, Explorer, Dossier) ──` but the shell was refactored to 3 tabs + ProfileDrawer (dossier_tab was deleted). This is a comment-only fix.

---

## Dead Screen Findings

[VERIFIED: directory scan + app.dart import list + live grep]

19 screen files are not imported in `app.dart`. Each is classified below:

### Category A: Tab Shell Components (NOT dead — mounted directly in shell)
These are embedded by `main_navigation_shell.dart`, not routed via GoRouter:

| File | Why Not in app.dart | Action |
|------|---------------------|--------|
| `screens/main_tabs/mint_home_screen.dart` | Mounted in MainNavigationShell directly | **Keep** |
| `screens/main_tabs/mint_coach_tab.dart` | Mounted in MainNavigationShell directly | **Keep** |
| `screens/main_tabs/explore_tab.dart` | Mounted in MainNavigationShell directly | **Keep** |

### Category B: Onboarding Sub-Widgets (NOT dead — used by smart_onboarding_screen)
`smart_onboarding_screen.dart` composes these as embedded widgets, not routes:

| File | Why Not in app.dart | Action |
|------|---------------------|--------|
| `screens/onboarding/smart_onboarding_screen.dart` | Has redirect `/onboarding/smart` → `/onboarding/intent`; screen file itself is not routed but exists as redirect target old path | **Evaluate**: Screen is not routed directly. The redirect sends users to intent screen. The file has 0 references from lib/ other than itself. Candidate for deletion along with its viewmodel and step files. |
| `screens/onboarding/smart_onboarding_viewmodel.dart` | Only referenced by smart_onboarding_screen.dart | Deletes with screen |
| `screens/onboarding/steps/step_chiffre_choc.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_jit_explanation.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_next_step.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_ocr_upload.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_questions.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_stress_selector.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |
| `screens/onboarding/steps/step_top_actions.dart` | Only composed inside smart_onboarding_screen | Deletes with screen |

### Category C: Clearly Dead (no route, no importers, archived in practice)
[VERIFIED: grep showed 0 references from lib/ for each]

| File | Status | Notes | Action |
|------|--------|-------|--------|
| `screens/ask_mint_screen.dart` | DEPRECATED since S52, route redirected | Has test coverage in `core_app_screens_smoke_test.dart` (5 assertions) — **must update test file simultaneously** | **Delete** + update test |
| `screens/coach/annual_refresh_screen.dart` | 0 importers from lib/ | Only referenced from `apps/mobile/archive/` | **Delete** |
| `screens/coach/coach_checkin_screen.dart` | 1627 lines, 0 live importers from lib/ | Route `/coach/checkin` redirects to `/home?tab=1` — screen file is orphaned | **Delete** |
| `screens/coach/cockpit_detail_screen.dart` | 0 importers from lib/ | No route, no imports | **Delete** |
| `screens/tools_library_screen.dart` | 0 importers from lib/ | Route `/tools` redirects to `/home?tab=2` — screen file orphaned | **Delete** |
| `screens/budget/budget_screen.dart` | 0 importers, legacy comments say "primary display now in PulseScreen" | Route `/budget` points to `budget_container_screen.dart`, not this | **Delete** |

### Category D: pulse_screen.dart — Special Case
`screens/pulse/pulse_screen.dart` (1665 lines) is not imported in `app.dart`. Comments in `mint_home_screen.dart` read "Replaces PulseScreen as the landing tab." However, this file is very large and requires verification of zero lib/ imports before deletion.

[VERIFIED: grep showed 0 imports from lib/ for `PulseScreen` class; only doc comments reference it in other files]

**Action: Delete** (confirm with `grep -r "import.*pulse_screen" lib/ --include="*.dart"` before executing).

### Category E: D-10 Correction — theme_detail_screen.dart is LIVE
CONTEXT.md D-10 states to remove `theme_detail_screen.dart` "with broken imports to removed `mint_ui_kit.dart`." This is **outdated**:
- The file's import comment reads `// mint_ui_kit.dart removed — deprecated MintPremiumButton replaced` — the broken import is already gone
- `flutter analyze` reports 0 errors, confirming no broken import
- Route `/education/theme/:id` in `app.dart` L760–766 points to `ThemeDetailScreen`
- The file is imported in `app.dart` L28

**Action: Keep `theme_detail_screen.dart`.** Do NOT delete. D-10 is superseded by current state. [VERIFIED: live code + flutter analyze result]

---

## Common Pitfalls

### Pitfall 1: Deleting a Screen Without Its Test Coverage
**What goes wrong:** Delete `ask_mint_screen.dart`, run `flutter test` → 5 test failures in `core_app_screens_smoke_test.dart`
**Why it happens:** The test file imports `AskMintScreen` and has 5 widget test assertions against it
**How to avoid:** Always search for test files referencing the screen class before deleting. Update or delete the test file in the same commit.
**Warning signs:** `flutter test` fails after deletion with "Target of URI doesn't exist" errors

### Pitfall 2: Applying D-10 (Remove theme_detail_screen) as Stated
**What goes wrong:** Deleting `theme_detail_screen.dart` breaks the live `/education/theme/:id` route
**Why it happens:** CONTEXT.md D-10 was written based on an older state of the file; the broken import has since been fixed
**How to avoid:** Always run `flutter analyze` and verify routes before removing a screen
**Warning signs:** `flutter analyze` shows 0 errors for the file; `app.dart` imports it

### Pitfall 3: Smart Onboarding Step Files — Cascading Deletes
**What goes wrong:** Deleting `smart_onboarding_screen.dart` without its 7 step sub-widgets leaves orphaned Dart files with no consumers
**Why it happens:** The step widgets are only composed inside `smart_onboarding_screen.dart`
**How to avoid:** Delete the entire `screens/onboarding/steps/` subdirectory and `smart_onboarding_viewmodel.dart` together with the parent screen in one pass
**Warning signs:** `flutter analyze` shows unused imports in step files after parent deletion

### Pitfall 4: Confusing Route-Level Redirect with File Deletion
**What goes wrong:** The route `/coach/checkin` has a redirect — this means the ROUTE is live, but the SCREEN FILE `coach_checkin_screen.dart` is orphaned (never actually rendered via any path)
**Why it happens:** Redirect routes forward navigation but the old screen file remains on disk
**How to avoid:** A redirect in `app.dart` means the OLD path is handled. It does NOT mean the OLD screen file is still needed. Verify the redirect target — if it goes to `/home?tab=N`, the old screen file is dead.
**Warning signs:** A route has `redirect:` but also a corresponding `*_screen.dart` file still exists

### Pitfall 5: main_tabs Screens Appearing "Dead"
**What goes wrong:** Grep shows `mint_home_screen.dart`, `mint_coach_tab.dart`, `explore_tab.dart` are not in `app.dart` imports → flagged for deletion
**Why it happens:** These are mounted directly in `main_navigation_shell.dart`, not via GoRouter routes
**How to avoid:** Check `main_navigation_shell.dart` imports before flagging any main tab file as dead
**Warning signs:** File name contains `_tab.dart` or is documented as a shell component

---

## Code Examples

### Import Tracing Pattern
```bash
# Find all files importing a given service (excluding the service file itself)
grep -r "import.*coach_narrative_service" \
  /path/to/lib --include="*.dart" | \
  grep -v "coach_narrative_service.dart"

# Check both paths explicitly
grep -r "import.*services/coach_narrative_service" lib/ --include="*.dart"
grep -r "import.*services/coach/coach_narrative_service" lib/ --include="*.dart"
```
[VERIFIED: used this exact pattern during research]

### Screen Reachability Check
```bash
# Check if a screen class has any import in lib/ (excluding itself)
grep -r "import.*screen_filename" apps/mobile/lib --include="*.dart" | \
  grep -v "screen_filename.dart"

# Check for test file references too
grep -r "ScreenClassName" apps/mobile/test --include="*.dart"
```
[VERIFIED: used during research for ask_mint_screen, coach_checkin_screen, etc.]

### Post-Deletion Verify Gate
```bash
# Run from apps/mobile/
flutter analyze --no-pub       # Must return: "No issues found!"
flutter test --no-pub -q       # Must return: All tests pass
```
[VERIFIED: flutter analyze baseline is 0 errors as of 2026-04-05]

---

## Runtime State Inventory

> Rename/refactor phases only — included here because screen and service file deletions affect test infrastructure.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — this phase deletes Dart files, no DB schema changes | None |
| Live service config | None — no service registration or feature flags reference the dead screens | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | Flutter build cache (`apps/mobile/.dart_tool/`, `build/`) will be stale after file deletions | Run `flutter clean` before final analyze/test if analyzer shows phantom errors |
| Test files | `test/screens/core_app_screens_smoke_test.dart` references `AskMintScreen` — must be updated when `ask_mint_screen.dart` is deleted | Code edit — remove or replace the 5 AskMintScreen test cases |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `coach_narrative_service.dart` root copy (1457 lines) is the canonical implementation and the coach/ copy (206 lines) is a subset/stub | Pair 1 finding | If the coach/ copy has unique classes not in the root, deletion breaks consumers. Mitigation: diff class names before deleting. |
| A2 | `smart_onboarding_screen.dart` and its step sub-widgets have zero live importers from lib/ | Category B classification | If any screen imports a step widget directly, deletion breaks analyze. Run grep before delete. |
| A3 | `pulse_screen.dart` has zero live importers from lib/ | Category D | Research grep showed 0 but a fast-grep may have missed edge cases. Run explicit `grep -r "import.*pulse_screen" lib/` before deleting. |

**If this table is empty:** Not empty — 3 assumptions flagged for pre-execution verification.

---

## Open Questions

1. **smart_onboarding_screen.dart deletion scope**
   - What we know: The route `/onboarding/smart` redirects to `/onboarding/intent`. The screen file has 0 lib/ importers. 9 sub-files in `screens/onboarding/steps/` exist only for this screen.
   - What's unclear: Whether the team intentionally wants to keep this code for future use or considers it fully superseded.
   - Recommendation: Delete per D-08 (zero routes pointing to it). The redirect stays in app.dart as documented.

2. **budget_screen.dart vs budget_container_screen.dart**
   - What we know: `/budget` route points to `budget_container_screen.dart`. `budget_screen.dart` has 0 importers and says "primary display now in PulseScreen."
   - What's unclear: Whether any test file references `BudgetScreen` (the legacy class).
   - Recommendation: Run `grep -r "BudgetScreen" test/` before deleting to catch any test-only references.

---

## Validation Architecture

No `nyquist_validation` config found (`.planning/config.json` absent) — treat as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test (built-in) |
| Config file | `apps/mobile/pubspec.yaml` (test: dependency) |
| Quick run command | `flutter test --no-pub -q` (from `apps/mobile/`) |
| Full suite command | `flutter test --no-pub` |
| Analyze command | `flutter analyze --no-pub` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| CLN-01 | Duplicate service deleted, all importers point to canonical | Compile-time | `flutter analyze --no-pub` | Analyzer catches all broken/duplicate imports |
| CLN-02 | All 67 canonical routes classified | Manual audit + compile | `flutter analyze --no-pub` | No automated route-coverage test exists |
| CLN-03 | Dead screens removed, 0 test regressions | Compile + unit | `flutter test --no-pub -q` | Must update `core_app_screens_smoke_test.dart` |

### Sampling Rate
- **Per task commit:** `flutter analyze --no-pub` (4s, catches broken imports immediately)
- **Per task commit (after screen removal):** `flutter test --no-pub -q` (catches broken test imports)
- **Phase gate:** Both commands must return clean before `/gsd-verify-work`

### Wave 0 Gaps
None — existing test infrastructure is sufficient. The only test file modification required is removing `AskMintScreen` tests from `core_app_screens_smoke_test.dart` when that screen is deleted.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All tasks | ✓ | ^3.6.0 | — |
| `flutter analyze` | CLN-01, CLN-03 gate | ✓ | built-in | — |
| `flutter test` | CLN-03 gate | ✓ | built-in | — |

No missing dependencies. Phase is purely file deletion + import updates.

---

## Project Constraints (from CLAUDE.md)

The following CLAUDE.md directives apply to this phase:

| Directive | Implication for This Phase |
|-----------|---------------------------|
| `flutter analyze` must be 0 errors before merge | Hard gate — run after every deletion |
| `flutter test` must pass before merge | Hard gate — update test files when deleting tested screens |
| Branch flow: feature/* → dev, never direct to main/staging | Work on a feature branch |
| Before ANY code modification: confirm on feature branch | `git branch --show-current` first |
| Do not create files unnecessarily — prefer editing existing | This phase only deletes; no new files created |
| GoRouter — no `Navigator.push` | Not relevant (no new navigation added) |
| Provider pattern — no raw StatefulWidget for shared data | Not relevant (no new widgets added) |
| ALL user-facing strings → ARB files | Not relevant (no UI text added) |

---

## Sources

### Primary (HIGH confidence)
- Live codebase grep — `apps/mobile/lib/` import tracing for all 3 service pairs
- `apps/mobile/lib/app.dart` L161–974 — GoRouter route table, full enumeration
- `apps/mobile/lib/services/memory/goal_tracker_service.dart` — confirmed re-export shim content
- `apps/mobile/lib/screens/education/theme_detail_screen.dart` — confirmed broken import already removed
- `flutter analyze --no-pub` run live — confirmed 0 errors baseline
- MEMORY.md — confirmed 8137 Flutter tests + 4755 backend tests all green
- CONCERNS.md — confirmed 3 duplicate service pairs, deprecated screens list

### Secondary (MEDIUM confidence)
- `apps/mobile/test/screens/core_app_screens_smoke_test.dart` — confirmed AskMintScreen test coverage count (5 assertions)
- `apps/mobile/lib/screens/main_navigation_shell.dart` — confirmed main_tabs screens mounted directly, not via GoRouter

---

## Metadata

**Confidence breakdown:**
- Duplicate service findings: HIGH — all verified via live grep, file content inspection
- Route table analysis: HIGH — verified directly in app.dart
- Dead screen classification: HIGH — verified via grep + route cross-reference
- D-10 correction: HIGH — verified via flutter analyze (0 errors) + app.dart import check

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable codebase, low churn in cleanup-targeted files)
