---
phase: mint-calc-engine-v1
plan: 19
subsystem: testing
tags: [lefthook, lint, parity, concern-c, ast, regex, profile-context, coach-chat, flutter, python, pre-commit]

# Dependency graph
requires:
  - phase: mint-calc-engine-v1-01
    provides: _PROFILE_SAFE_FIELDS canonical set at coach_chat.py
  - phase: mint-calc-engine-v1-09
    provides: tool_description_rubric.py pattern (tools/checks/ lint shape precedent)
  - phase: mint-calc-engine-v1-18
    provides: banned_terms_python.py NFKC pattern + tools/checks/tests/ layout
provides:
  - tools/checks/profile_safe_fields_parity.py — Concern C parity lint
  - tools/checks/tests/test_profile_safe_fields_parity.py — 11-test suite
  - lefthook pre-commit wiring (SOFT-WARN mode pending baseline closure)
  - Documented baseline drift: 40 server-only fields + 5 Flutter-only fields
affects: [mint-calc-engine-v1-20-wave-close, future Flutter profileContext PR closing baseline drift]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AST-based server symbol extraction (ast.walk + ast.Constant filter)"
    - "Block-scoped Dart regex with balanced-brace walking (profileContext: { ... })"
    - "LookupError for symbol-missing vs empty-set ambiguity resolution"
    - "SOFT-WARN lefthook mode (|| true) for incremental rollout when baseline diff exists"

key-files:
  created:
    - tools/checks/profile_safe_fields_parity.py
    - tools/checks/tests/test_profile_safe_fields_parity.py
  modified:
    - lefthook.yml

key-decisions:
  - "Flutter extraction scans the 4 ACTUAL profileContext call-sites (coach_orchestrator.dart x3, coach_chat_api_service.dart, coach_narrative_service.dart, coaching_service.dart), NOT coach_context_builder.dart as the original PLAN.md proposed — coach_context_builder builds a local CoachContext object, no profile_context keys live there"
  - "SOFT-WARN lefthook mode (|| true) chosen because baseline drift is 40+5=45 fields — HARD mode would block 100% of commits touching either side until a separate Flutter PR closes the gap"
  - "AST extractor raises LookupError on symbol-missing OR unsupported value shape, distinguishing 'extractor failed' (CLI exit 2) from 'symbol genuinely empty' (CLI exit 0)"

patterns-established:
  - "Pattern: parity-lint at tools/checks/ shape — extract two sides via deterministic parsers (AST + regex) + assert set equality + actionable diff. Reusable for future cross-stack contracts (ARB↔Pydantic, OpenAPI↔Dart models, etc.)"
  - "Pattern: lefthook SOFT-WARN bootstrap — wire new gate as |, surface drift in stdout, promote to HARD only after baseline closure documented"

requirements-completed: [Concern-C]

# Metrics
duration: 38min
completed: 2026-05-17
---

# Phase mint-calc-engine-v1 Plan 19: W4 — `_PROFILE_SAFE_FIELDS` parity lint Summary

**Concern C parity lint ships with documented 45-field baseline drift — 40 server-canonical fields Flutter never sends + 5 Flutter-only fields server silently drops. Lint wired SOFT-WARN into lefthook ; promote to HARD post-baseline closure.**

## Performance

- **Duration:** 38 min
- **Started:** 2026-05-17 (live session)
- **Completed:** 2026-05-17
- **Tasks:** 3 (RED test + GREEN impl + lefthook wiring) + Engram save
- **Files modified:** 3 (2 created, 1 modified)
- **HEAD before:** `a01fb925` (Plan 18 close)
- **HEAD after:** `9be9b8d6` (Task 2 lefthook wiring)

## Accomplishments

- Concern C parity lint live (`tools/checks/profile_safe_fields_parity.py`, 296 LOC).
- 11/11 lint self-tests green covering AST extractor primitives + Dart regex extractor + CLI behavior on in-sync, server-only-extra, flutter-only-extra, and empty-set edge cases.
- Lefthook pre-commit hook wired across the 5 canonical files (1 server + 4 Flutter call-sites). SOFT-WARN mode via `|| true` because the baseline diff would block all unrelated commits.
- Baseline drift fully enumerated in this SUMMARY for the follow-up Flutter PR.
- Zero regression on backend test suite (`cd services/backend && pytest tests/ -q` → **7264 passed, 63 skipped, 3 xfailed** — identical to Plan 18 baseline).
- Engram observation #145 saved (`pattern`, topic_key `calc_engine:w4:profile_safe_fields_parity_lint`).

## Task Commits

1. **Task 1 RED** — `98684ca1` — `test(mint-calc-engine-v1-19): add failing tests for Concern C parity lint`
2. **Task 1 GREEN** — `e91017df` — `feat(mint-calc-engine-v1-19): ship Concern C parity lint`
3. **Task 2** — `9be9b8d6` — `feat(mint-calc-engine-v1-19): wire Concern C parity lint into lefthook pre-commit`
4. **Task 3** — Engram save (no commit ; observation #145).

_Plan metadata commit pending — added in the final docs commit alongside SUMMARY + STATE + ROADMAP updates._

## Files Created/Modified

- `tools/checks/profile_safe_fields_parity.py` (NEW, 296 LOC) — Concern C parity lint. AST extractor on Python server symbol + balanced-brace Dart regex extractor + actionable-diff CLI.
- `tools/checks/tests/test_profile_safe_fields_parity.py` (NEW, 289 LOC) — 11 tests covering extractor + CLI primitives.
- `lefthook.yml` (+21 lines, position 209-230) — new `profile_safe_fields_parity` hook in SOFT-WARN mode (`|| true`) with glob over server + 4 Flutter call-sites.

## Decisions Made

1. **Flutter extraction targets actual call-sites, not `coach_context_builder.dart` per original PLAN.md.** Verified by `grep -rn "profile_context\|profileContext" apps/mobile/lib/`: 5 distinct files build profile_context maps (coach_orchestrator x3, coach_chat_api_service, coach_narrative_service, coaching_service). `coach_context_builder.dart` builds a local `CoachContext` object — it does NOT contain the key list sent to the server. Original PLAN's regex on `coach_context_builder.dart` would have matched `'fri_total'`-like keys inside the `knownValues` map (only 9 keys) and missed the 30+ keys actually sent. Documented in Deviations section below.

2. **SOFT-WARN lefthook mode (`|| true`).** Baseline drift is 45 fields total — wiring as HARD would block every commit touching `coach_chat.py` or any of the 4 Flutter files until a dedicated Flutter PR closes the gap. SOFT mode surfaces the drift to every developer (stdout diff prints during pre-commit) but doesn't block unrelated work. Promotion to HARD documented in lefthook.yml inline comment.

3. **LookupError sentinel for extractor failure.** Original first impl returned empty set on both « symbol missing » and « symbol = `set()` ». This made the « both sides empty » edge case ambiguous (test_cli_empty_set_edge_case failed at exit 2 instead of 0). Refactored extractor to raise `LookupError` for « symbol not found OR unsupported value shape » + return empty set only for genuinely-empty set/list/tuple/frozenset literals. CLI catches LookupError → exit 2, distinguishes from exit 0 (in-sync, possibly empty).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] PLAN.md Flutter-side extraction target was incorrect**

- **Found during:** Task 1 RED test design (analyzing `coach_context_builder.dart` content)
- **Issue:** PLAN.md proposed regex-extracting Dart field names from `apps/mobile/lib/services/coach/coach_context_builder.dart`. That file declares a `CoachContextBuilder.build()` constructor with camelCase Dart parameters (`friTotal`, `avoirLpp`…) that produce a local `CoachContext` object with a `knownValues` map containing 9 snake_case keys (`fri_total`, `replacement_ratio`, `months_liquidity`, `tax_saving`, `confidence_score`, `capital_final`, `epargne_3a`, `avoir_lpp`, `salaire_brut`). The keys ACTUALLY sent to the backend live elsewhere — in 5 different files that construct `profileContext: { ... }` map literals or mutate them (`profileContext['k'] = v`).
- **Fix:** Re-targeted the Dart extractor at the 4 real call-site files (`coach_orchestrator.dart` x3 maps, `coach_chat_api_service.dart`, `coach_narrative_service.dart`, `coaching_service.dart`) via a balanced-brace walk from `profileContext: {` to its matching close-brace, then snake_case key regex inside the block. Plus a separate regex for `profileContext['key'] = ...` mutations (used by `coach_chat_api_service.dart:94-97` for partner aggregates).
- **Files modified:** `tools/checks/profile_safe_fields_parity.py` (Flutter extractor + DEFAULT_FLUTTER list)
- **Verification:** `test_extract_flutter_fields_real_orchestrator_has_canton` validates the real orchestrator file extraction; `test_extract_flutter_fields_ignores_keys_outside_profilecontext` validates the block-scope restriction.
- **Committed in:** `e91017df` (Task 1 GREEN)

**2. [Rule 3 - Blocking] `_REPO_ROOT` parents level was wrong (`parents[1]` → `parents[2]`)**

- **Found during:** First live run against the repo (`python3 tools/checks/profile_safe_fields_parity.py`)
- **Issue:** Initial impl set `_REPO_ROOT = Path(__file__).resolve().parents[1]`, which evaluates to `tools/` (parent of `tools/checks/profile_safe_fields_parity.py`). DEFAULT_SERVER then concatenated to `tools/services/backend/...` and the file didn't exist.
- **Fix:** Changed to `parents[2]` (correct repo root).
- **Files modified:** `tools/checks/profile_safe_fields_parity.py:56`
- **Verification:** Live run after fix returns the real drift diff (40 server-only + 5 Flutter-only fields). Tests still pass since they use absolute paths via `_REPO_ROOT` (which now resolves correctly).
- **Committed in:** Same commit as the GREEN impl (`e91017df`).

---

**Total deviations:** 2 auto-fixed (1 plan-presupposition bug, 1 implementation path bug)
**Impact on plan:** Plan delivered as intended (Concern C parity lint + tests + lefthook wiring). PLAN.md's Flutter-side strategy was wrong; the working implementation diverged to scan the 4 real call-sites instead. Threat model + success criteria unchanged.

## Pre-existing parity gap (baseline 2026-05-17)

**State today: NOT in sync.** The lint exits 1 against `main` HEAD `9be9b8d6` with this exact diff.

### 40 server-only fields (server expects but no Dart call-site sends)

These are PII-safe keys that `_PROFILE_SAFE_FIELDS` whitelists for the coach context but no Flutter file currently emits in any `profileContext` map literal. The coach is grounding-blind to all of them today :

```
active_goal, annual_3a_contribution, avoir_lpp, avs_annual_estimate,
avs_contribution_years, avs_rente, cap_cta, cap_expected_impact,
cap_headline, cap_why_now, capital_final, civil_status, conjoint_age,
conjoint_salary, couple_avs_monthly, couple_marriage_annual_delta,
couple_optimization, data_source, employment_status, epargne_3a,
existing_3a_ytd, has_2nd_pillar, is_married, lpp_balance_total,
lpp_buyback_max, lpp_buyback_potential, lpp_capital, lpp_certificate_year,
lpp_conversion_rate, marital_status, monthly_expenses, monthly_income,
monthly_retirement_income, months_to_retirement, number_of_children,
planned_contributions, salaire_brut, sequence_completed, sequence_total,
years_since_last_buyback
```

**Notable groundings missing :** `capital_final`, `avoir_lpp`, `epargne_3a`, `salaire_brut`, `lpp_capital`, `lpp_balance_total` — these are exactly the values the coach must cite per the « numeric grounding contract » documented in the `coach_context_builder.dart` doc header (lines 13-24). Some are emitted INSIDE the local `CoachContext.knownValues` map via Flutter's `CoachContextBuilder.build()`, then SPREAD into the orchestrator's profileContext via `...ctx.knownValues.map((k, v) => MapEntry(k, ...))` — but only if `> 0`. So when the user hasn't filled their LPP avoir, the field is never sent → coach has no grounding number to cite → fallback templates kick in.

**Couple / family fields (15) missing :** the whole `is_married`/`conjoint_*`/`couple_*`/`marital_status`/`number_of_children` cluster never flows to the server. These are mostly populated only when the user opens the « couple » sub-flow.

**Cap/plan fields (6) missing :** `cap_headline`, `cap_why_now`, `cap_cta`, `cap_expected_impact`, `active_goal`, `sequence_completed`, `sequence_total` — these are server-side concepts the coach grounding contract anticipated but Flutter doesn't yet emit. May be P2-rolled-out feature still in progress.

### 5 Flutter-only fields (Flutter sends but server drops them silently)

```
data_reliability       — coach_orchestrator.dart:958-959 (server-key path)
financial_summary      — coach_narrative_service.dart:1206 + coaching_service.dart:247
first_name             — coach_narrative_service.dart:1205 + orchestrator x3 (lines 564, 796, 933)
partner_confidence     — coach_chat_api_service.dart:97 (P16 COUP-04 partner aggregate)
partner_declared       — coach_chat_api_service.dart:95 (same)
```

**Risk assessment :**
- `first_name` — minor. Coach personalization « Bonjour [first_name] » uses it via `build_coach_context(first_name=...)` (server side) but server pulls first_name from `_user.profile` directly, NOT from body. Flutter sending it is redundant but not harmful. Server drops silently → OK.
- `financial_summary` — heuristic markdown chunk built by Flutter (« Age : X / Canton : Y / Avoir 3a : Z »). Server doesn't expect free-form blob ; it builds its own grounding from typed fields. Silently dropped, harmless.
- `data_reliability` — map `{field_key: source_enum}` used by Flutter `HallucinationDetector` for local UI tolerance bands. Not consumed server-side. Dropped silently.
- `partner_declared` / `partner_confidence` — **CRITICAL FINDING for separate ticket.** P16 COUP-04 added these to `coach_chat_api_service.dart:94-97` (in-place mutation of profileContext AFTER orchestrator builds it). They're NOT in `_PROFILE_SAFE_FIELDS` so the server drops them. The whole Phase 16 COUP-04 partner-aggregate flow → coach context is dead. Either the server is missing these in the whitelist, OR Phase 16 abandoned that path. Worth raising as a Phase 16 retrospective item.

### Recommended follow-up

A dedicated Flutter PR (« Plan 19-followup: close Concern C parity baseline »):
1. Add the 40 server-only fields to `coach_orchestrator.dart` server-key profileContext map (line 932-962) — read from `ctx.knownValues` + `ProfileProvider` where the data lives.
2. Decide on the 5 Flutter-only fields :
   - Drop `first_name` / `financial_summary` / `data_reliability` from Flutter (server already has cleaner sources).
   - **Add `partner_declared` + `partner_confidence` to server `_PROFILE_SAFE_FIELDS`** if Phase 16 COUP-04 still alive — otherwise drop Flutter mutation.
3. Promote lefthook hook from SOFT (`|| true`) to HARD (drop `|| true`).
4. Re-run `python3 tools/checks/profile_safe_fields_parity.py` → MUST exit 0.

## Issues Encountered

- 2 pre-existing test failures observed (`test_at_least_seven_endpoint_files_grounded`, `test_coach_chat_wiring_pack_kwarg_threaded`) when running from repo root cwd. Confirmed pre-existing via `git log` (last touched in Plan 06 commit `cf747899`, well before Plan 19). They pass when run from `services/backend/` cwd, indicating cwd-sensitivity in their `open()` calls, not a Plan 19 regression. **Total backend regression run from `services/backend/` cwd : 7264 passed (identical to Plan 18 baseline).**

## User Setup Required

None — lint is fully mechanical, no external config or secrets.

## 0-TRUST citations

Per CLAUDE.md §9, evidence required for every claim :

| Claim | Evidence |
|------|---------|
| "Lint exists and is ≥60 LOC" | `wc -l tools/checks/profile_safe_fields_parity.py` → 296 lines |
| "11 self-tests green" | `python3 -m pytest tools/checks/tests/test_profile_safe_fields_parity.py -q` → `11 passed in 0.17s` |
| "Lefthook hook fires" | `lefthook run pre-commit --command profile_safe_fields_parity --file services/backend/app/api/v1/endpoints/coach_chat.py --force` → `✔️ profile_safe_fields_parity (0.04 seconds)` with full drift diff printed to stdout |
| "Backend regression intact at 7264" | `cd services/backend && python3 -m pytest tests/ -q` → `7264 passed, 63 skipped, 3 xfailed, 1 warning in 117.41s` (exit 0, identical to Plan 18 SUMMARY-cited baseline) |
| "Server _PROFILE_SAFE_FIELDS at coach_chat.py:957" | `grep -n "_PROFILE_SAFE_FIELDS" services/backend/app/api/v1/endpoints/coach_chat.py` → `957:_PROFILE_SAFE_FIELDS = {` (PLAN.md cited 875 — drifted +82 lines since plan write 2026-05-16) |
| "Engram observation #145 saved" | `engram save ... --type pattern` → `Memory saved: #145 "Concern C parity lint live (Phase mint-calc-engine-v1 Plan 19)" (pattern)` |
| "Drift = 40 server-only + 5 flutter-only" | `python3 tools/checks/profile_safe_fields_parity.py` → exit 1 with the enumerated diff (see Pre-existing parity gap section above) |

## What I have NOT done (0-TRUST §9.4 self-audit)

- **Have NOT** fixed the baseline 40+5 drift. Per `<deviation_protocol>` : Plan 19 ships the lint ; the Flutter-side fix is a separate ticket.
- **Have NOT** promoted lefthook hook to HARD mode. SOFT (`|| true`) until baseline closed.
- **Have NOT** run the test suite from the simulator/device. The lint is mechanical — no Flutter screen affected, no runtime change, no need.
- **Have NOT** added a CI workflow YAML for this lint. lefthook pre-commit is the only entry point. If a developer bypasses lefthook (`LEFTHOOK=0`), the lint won't fire — accepted risk given SOFT mode (no fail propagation matters anyway).
- **Have NOT** validated that the `lefthook run` test simulates a real pre-commit identically — Lefthook 2.1.6 with `core.hooksPath` skipping sync is the live state, so the hook would still execute on commit because the entry is in lefthook.yml even if the hooks-path drift is reported as warning. Verified separately via successful `lefthook run --command ... --force` exit 0.

## Threat Flags

None — Plan 19 introduces a lint script + lefthook entry. No new network surface, no auth path, no schema change, no LSFin user-facing output.

## Self-Check: PASSED

- `tools/checks/profile_safe_fields_parity.py` — FOUND (verified via `[ -f ... ]`)
- `tools/checks/tests/test_profile_safe_fields_parity.py` — FOUND
- `lefthook.yml` profile_safe_fields_parity entry — FOUND (grep returns 2 matches lines 210, 227)
- Commit `98684ca1` (RED) — FOUND (`git log --oneline | grep 98684ca1`)
- Commit `e91017df` (GREEN) — FOUND
- Commit `9be9b8d6` (lefthook) — FOUND
- Engram observation #145 — FOUND (CLI return value)

## Next Phase Readiness

- Plan 20 (W4 wave close + engram doctrine) can proceed — no blockers from Plan 19.
- Plan 19 surfaces a P2 follow-up Flutter ticket : close the 40+5 baseline parity diff. Add to backlog ; not a Plan 20 prerequisite.

---
*Phase: mint-calc-engine-v1, Plan 19*
*Completed: 2026-05-17*
