---
phase: 01-p0a-code-unblockers
milestone: v2.2 La Beauté de Mint
status: PARTIAL — STAB-19 + ACCESS-01 + STAB-21 closed; STAB-20 carved out to Phase 1.5
executed: 2026-04-07
branch: feature/v2.2-p0a-code-unblockers
requirements_closed: [STAB-19, ACCESS-01, STAB-21]
requirements_carved_out: [STAB-20]
---

# Phase 1 — P0a Code Unblockers — Summary

## One-liner

Phase 1 closes with 3 of 4 carryover items resolved on a clean feature branch;
STAB-20 (`chiffre_choc` → `premier_eclairage` rename) is carved out to a
dedicated Phase 1.5 after the executor discovered the live surface is
**186 files / 1,934 hits** — a domain refactor, not a localized rename.

---

## Requirements Closed

### STAB-19 — Provider registration verification

**Status:** CLOSED (verification-only per D-01)

The 4 providers (`MintStateProvider`, `FinancialPlanProvider`,
`CoachEntryPayloadProvider`, `OnboardingProvider`) were already registered in
`apps/mobile/lib/app.dart:1010-1013` under the STAB-13 ROOT-B fix from v2.1.
STAB-19 collapsed to a regression guard.

**Gates (all green):**
1. `git grep ProviderNotFoundException apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` → exit 1 (0 hits)
2. `flutter analyze lib/` → `No issues found!` (0 errors)
3. `flutter test test/smoke/mint_home_smoke_test.dart` → `+1: All tests passed!`

**Artifact:** `apps/mobile/test/smoke/mint_home_smoke_test.dart` — reconstructs
the relevant MultiProvider slice and asserts `tester.takeException()` is null
after pump+settle. Guards against future regression if the 4 providers are ever
removed from `app.dart`.

**Commit:** `test(p0a-stab19): add MintHomeScreen MultiProvider smoke test`

---

### ACCESS-01 — Layer 1 accessibility recruitment tracker

**Status:** CLOSED on Claude's side (skeleton + 6 rows created).
**Pending Julien action:** send 6 recruitment emails, fill `Date sent` +
`Contact name` + `Email` columns, flip status to `EMAIL SENT`, confirm in chat.
Per D-03, replies and session scheduling do NOT block Phase 1 — fire-and-forget.

**Artifact:** `docs/ACCESSIBILITY_TEST_LAYER1.md`

- Header with doctrine, budget (CHF 800–2'000), AAA honesty gate reference
- Tracker table with 9 columns (`# | Partner | Contact name | Email | Date sent | Reply received | Session date | Compte-rendu link | Status`)
- 6 pre-filled rows: 2× SBV-FSA (malvoyant·e), 2× ASPEDAH (ADHD), 2× Caritas (français-seconde-langue)
- Instructions block for Julien + downstream consumers (Phase 8b, Phase 12, ACCESS-09)

**Commit:** `docs(p0a-access01): create Phase 1 recruitment tracker`

---

### STAB-21 — `chiffre_choc_screen` split-exit bug

**Status:** MOOT-PENDING-DELETION

**Disposition:** Per ROADMAP Phase 1 success criterion #4 and PLAN-04
`<prior_sweep_analysis>`, STAB-21 is the alleged bug that the arrow button in
the onboarding `chiffre_choc_screen` TextField routes to `/coach/chat` without
calling `setMiniOnboardingCompleted(true)` first.

**Executor verification (2026-04-07):**
- `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` **does exist** on HEAD.
- `git grep -n "setMiniOnboardingCompleted" apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` → 0 hits.
- `git grep -n "context.go.*'/coach/chat'" apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` → 0 hits.
- The bug as described in ROADMAP does not appear to exist in the current file (the split-exit pathway and the provider flag it was supposed to set are both absent). Either the bug was silently fixed in v2.1 stabilisation or the ROADMAP entry was copied from an older snapshot.

**Decision:** Do NOT fix. Phase 10 (ONB-02 + ONB-03) deletes the onboarding
`chiffre_choc_screen` (→ `premier_eclairage_screen` after Phase 1.5) entirely
and rewrites the flow. STAB-21 is marked **MOOT-PENDING-DELETION** per ROADMAP
criterion #4 ("mark moot if Phase 10 still on track").

**Handoff note to Phase 10 planner:** if Phase 10 slips or is rescoped, re-open
STAB-21. Since no `setMiniOnboardingCompleted` call exists today, a fix would
require (a) adding the `miniOnboardingCompleted` flag read-side to
`OnboardingProvider`, (b) finding the actual exit paths of whatever screen
replaced the TextField arrow, and (c) wiring the flag before navigation —
**scope significantly larger than the ROADMAP one-liner suggests.** Re-plan
before executing.

**Also swept (no P0a items found):**

| Item | State | Phase 1 disposition |
|---|---|---|
| STAB-01..16 | DONE v2.1 | Not re-added (promotion guidance §1). |
| STAB-17 (manual tap-to-render walkthrough) | OPEN, human gate | Deferred to Phase 12 ship gate per ROADMAP rescope 2026-04-07. |
| STAB-19 (providers) | CLOSED above | — |
| STAB-20 (chiffre_choc rename) | **CARVED OUT to Phase 1.5** | See §Carveout below. |
| STAB-21 (split-exit bug) | MOOT-PENDING-DELETION | Phase 10 handles. |
| 12 orphan GoRouter routes (STAB-14 deferred) | OPEN, v3.0 | Not P0a. |
| ~65 NEEDS-VERIFY try/except (STAB-16 deferred) | OPEN | Not P0a. |
| Stale test `chat_tool_dispatcher_test.dart` | OPEN, lint hygiene | Not P0a. |
| ACCESS-01 | CLOSED above | — |

---

## Carveout — STAB-20 deferred to Phase 1.5

### Why this was escalated mid-execution

PLAN-02 / D-02 estimated the `chiffre_choc → premier_eclairage` rename at
**~10 explicit files / 719 hits** — a localized rename of the onboarding screen
+ its selector + backend counterpart + ARB keys + analytics.

Measured surface on `feature/v2.2-p0a-code-unblockers` HEAD:

```
git grep -lE 'chiffre_?choc|chiffreChoc|ChiffreChoc' \
  apps/mobile/lib services/backend/app apps/mobile/lib/l10n tools/openapi
# 186 files

git grep -cE 'chiffre_?choc|chiffreChoc|ChiffreChoc' ... | awk -F: '{s+=$2} END{print s}'
# 1934 total hits
```

**The delta is not "a few more files" — it's a different kind of rename.**
`chiffre_choc` is a **first-class domain concept** in the model layer and a
**per-life-event field** on ~50 life-event screens, not a feature name localized
to onboarding.

### Evidence of domain-level usage

| File | Usage |
|---|---|
| `apps/mobile/lib/models/response_card.dart` | Defines `class ChiffreChoc` — top-level Dart class consumed by coach response cards app-wide |
| `apps/mobile/lib/data/education_content.dart` | Public fields `chiffreChoc`, `chiffreChocUnit`, `chiffreChocLabel` on an `EducationContent` model |
| `apps/mobile/lib/providers/onboarding_provider.dart` | References `ChiffreChocType` enum; stores the type as a string and documents "must stay in sync with `ChiffreChocType` in `chiffre_choc_selector.dart`" |
| `apps/mobile/lib/screens/mariage_screen.dart` | `_buildChiffreChocRegime()` method + ARB keys `mariageChiffreChocDefault`, `mariageChiffreChocCommunaute` |
| ~49 other life-event screens | Same pattern — each has its own `_buildChiffreChocRegime()` + per-event ARB keys (`naissanceChiffreChoc*`, `expatChiffreChoc*`, `mortgageChiffreChoc*`, `arbitrageChiffreChoc*`, `independantsChiffreChoc*`, etc.) |

The CI grep gate (L6 in the original plan) **cannot land green** unless all 186
files are touched. And the CLAUDE.md doctrine flip (L7 "rename completed")
becomes a lie if the domain model still says `ChiffreChoc`.

### Categorized file inventory for Phase 1.5 planner

**Total: 186 files / 1,934 hits / 7 generated l10n files included.**

| Category | Count | Strategy hint |
|---|---|---|
| **Backend** (`services/backend/`) | 83 | Sub-split below |
| **OpenAPI** (`tools/openapi/`) | 2 | Regenerate, don't hand-edit (plan L2 intent) |
| **ARB source** (`apps/mobile/lib/l10n/app_*.arb`) | 6 | All 6 languages — preserve French diacritics |
| **ARB generated** (`apps/mobile/lib/l10n/app_localizations*.dart`) | 7 | Auto-regenerated by `flutter gen-l10n` |
| **Mobile models** (`lib/models/`) | 2 | `response_card.dart` (the `ChiffreChoc` class), `minimal_profile_models.dart` — **domain refactor** |
| **Mobile providers** (`lib/providers/`) | 1 | `onboarding_provider.dart` (`ChiffreChocType` enum sync) |
| **Mobile data** (`lib/data/`) | 1 | `education_content.dart` (model field rename) |
| **Mobile services** (`lib/services/`) | 27 | Includes `chiffre_choc_selector.dart` + 26 consumers across coach, financial_core, fiscal, mortgage, etc. |
| **Mobile screens — onboarding** (`lib/screens/onboarding/`) | 4 | `chiffre_choc_screen.dart`, `instant_chiffre_choc_screen.dart`, + 2 consumers (e.g., `intent_screen.dart`) |
| **Mobile screens — life events** (`lib/screens/`) | 33 | `mariage`, `naissance`, `expat`, `concubinage`, `deces_proche`, `demenagement_cantonal`, `first_job`, `independant`, `unemployment`, `fiscal_comparator`, `admin_analytics`, + subdirs: `arbitrage/`, `budget/`, `coach/`, `debt_prevention/`, `education/`, `independants/`, `lpp_deep/`, `mortgage/`, `pillar_3a_deep/` |
| **Mobile widgets** (`lib/widgets/`) | 18 | Educational inserts, premium components, coach cards |
| **Mobile other lib** | 2 | e.g. `app.dart` (route name references) |

**Backend sub-split (83 files):**

| Subcategory | Count | Notes |
|---|---|---|
| `app/api/v1/` endpoints | 19 | Routes, request/response handlers |
| `app/services/arbitrage/` | 6 | |
| `app/services/mortgage/` | 5 | |
| `app/services/independants/` | 5 | |
| `app/services/pillar_3a_deep/` | 4 | |
| `app/services/coach/` | 4 | |
| `app/services/retirement/` | 3 | |
| `app/services/onboarding/` | 3 | Includes `chiffre_choc_selector.py` (plan's L1 target) |
| `app/services/fiscal/` | 3 | |
| `app/services/family/` | 3 | |
| `app/services/debt_prevention/` | 3 | |
| `app/services/unemployment/`, `privacy_service.py`, `housing_sale_service.py`, `first_job/` | 4 | |
| Schemas + other app/ | ~21 | Pydantic models, settings, helpers — complete scan needed by Phase 1.5 planner |

### Recommended Phase 1.5 commit strategy (for the planner)

Instead of the 7 linear commits in the original PLAN-02, consider ~10–12 commits
split by **domain layer** so each can independently `flutter analyze 0 + test
green + pytest green`:

1. **B1** — Backend selector + tests (original L1, unchanged)
2. **B2** — Backend domain services (arbitrage, mortgage, independants, pillar_3a, coach, retirement, fiscal, family, debt_prevention, etc. — 50+ files)
3. **B3** — Backend API endpoints + Pydantic schemas (19 endpoint files + schemas)
4. **B4** — OpenAPI regen (single commit, full diff)
5. **F1** — Flutter model layer: `ResponseCard.ChiffreChoc` class → `PremierEclairage`, `EducationContent.chiffreChoc*` fields, `ChiffreChocType` enum in provider + selector
6. **F2** — Flutter onboarding screens (original L3's 4 files) + intent_screen consumer
7. **F3** — Flutter life-event screens (~33 files, `_buildChiffreChocRegime()` + call sites)
8. **F4** — Flutter services layer (27 consumer services)
9. **F5** — Flutter widgets layer (18 files)
10. **L1** — ARB source (6 files) + `flutter gen-l10n` (7 regenerated files) — **single commit** to keep source + generated in lockstep
11. **A1** — Analytics events (original L5, unchanged)
12. **G1** — Residue sweep + `tools/checks/no_chiffre_choc.py` CI grep gate (original L6)
13. **D1** — CLAUDE.md legacy note flip + docs sweep (original L7)

Each commit should touch ≤ ~40 files to keep review + rollback manageable.
Between each commit: `flutter analyze lib/ && flutter test && (cd services/backend && pytest -q)`.
If any commit lands red, `git reset --hard HEAD~1` and re-plan that slice —
don't fix forward.

### Phase 1.5 blockers to decide before planning

1. **`ResponseCard.ChiffreChoc` is a serialized class.** Is there any persisted
   JSON (SharedPreferences, SQLite, backend contract, event log) that uses
   `"chiffre_choc": {...}` as a key? If yes, a read-time alias is needed for
   backward compatibility. If no (pre-launch, no persistence), hard rename is
   safe — same doctrine as analytics events L5.
2. **`EducationContent` fields** feed into 18 educational inserts
   (`education/inserts/*.md`). Do those markdown files reference the field names
   via template variables? Phase 1.5 planner must grep `education/inserts/` and
   decide.
3. **ARB key migration.** Life-event ARB keys like `mariageChiffreChoc*` are
   consumed both by the life-event screens AND potentially by coach response
   templates. Grep `claude_coach_service.py` and RAG corpus for string
   references before renaming.
4. **Test fallout.** 12,892 existing tests will catch most breakage, but expect
   5–20 test-only fixes along the way (ARB-driven widget tests, golden tests,
   coach response assertions). Budget time.
5. **OpenAPI regen pipeline.** The original plan instructed "inspect
   `tools/openapi/` README first." That directory exists with `openapi.json`
   but its regen pipeline was not verified in Phase 1 (not in scope). Phase 1.5
   planner must verify the regen command exists and works before committing to
   B4; otherwise B4 becomes a hand-edit (not acceptable for 113+ hits).

---

## Test counts at Phase 1 close

- `flutter analyze lib/` → **0 issues**
- `flutter test test/smoke/mint_home_smoke_test.dart` → **1/1 passing** (STAB-19 smoke)
- Full `flutter test` suite: **not re-run at phase close** — Phase 1 touched only one new test file (`test/smoke/mint_home_smoke_test.dart`) and one doc file (`docs/ACCESSIBILITY_TEST_LAYER1.md`). The 8,137 existing Flutter tests and 4,755 backend tests are unchanged from Julien's baseline (`938c15ce`). Re-running is Phase 1.5's entry gate, not Phase 1's exit gate.
- `pytest` (backend): **not re-run** — no backend code touched in Phase 1.

---

## Branch status

**Branch:** `feature/v2.2-p0a-code-unblockers`
**Forked from:** `dev` at `938c15ce` (`docs(planning): land v2.2 Phase 1 P0a plans + ROADMAP 8c/10.5`)
**Commits ahead of dev:** 4 (STAB-19 smoke test, ACCESS-01 tracker, then this summary + Wave 3 disposition — see git log below)
**Unpushed to origin:** intentional per Julien's instruction — do not push until Phase 1.5 plans land so both phases can be orchestrated together.
**PR status:** NOT opened. Orchestration deferred to Julien.

---

## Deviations from plan

| # | Rule | Description | Resolution |
|---|---|---|---|
| 1 | Rule 4 (architectural) | PLAN-02 surface estimate was 10 files / 719 hits; actual is 186 files / 1,934 hits. `chiffre_choc` is a domain concept, not a localized feature name. | **STOPPED before any rename**, escalated to Julien, carved out to Phase 1.5 (Option C). |
| 2 | Rule 1 (bug doc) | ROADMAP line for STAB-21 describes a `setMiniOnboardingCompleted` bug that does not exist in the file on HEAD (`git grep` returns 0 hits). | Documented in §STAB-21 disposition; marked MOOT-PENDING-DELETION with a note to Phase 10 planner. |
| 3 | — (info-level lint) | Smoke test flagged `prefer_const_constructors` info on `MaterialApp`. | `// ignore: prefer_const_constructors` — the `child` MultiProvider contains non-const `ChangeNotifierProvider.create` lambdas, so `MaterialApp` cannot be const. |
| 4 | — (API) | Plan assumed Flutter l10n class was `AppLocalizations`; actual generated class is `S` (abstract). | Used `S.localizationsDelegates` / `S.supportedLocales` in smoke test. |

No Rules 1/2/3 auto-fixes were applied to production code because Phase 1 (after
the STAB-20 carveout) touches zero production Dart/Python files.

---

## Self-Check: PASSED

- [x] `apps/mobile/test/smoke/mint_home_smoke_test.dart` — FOUND
- [x] `docs/ACCESSIBILITY_TEST_LAYER1.md` — FOUND (6 rows, all columns present)
- [x] Commit 1 (smoke test) — in git log
- [x] Commit 2 (ACCESS-01 tracker) — in git log
- [x] Commit 3 (this summary) — landing now
- [x] `flutter analyze lib/` = 0 errors (re-run post-smoke-test)
- [x] `git grep ProviderNotFoundException apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` = exit 1
- [x] No STAB-20 rename files touched on this branch

---

*Phase 1 P0a — partial close — 2026-04-07*
