# Session Handoff — 2026-05-21 (Evening)

**Branch** : `dev` (clean @ `be6d7e61`)
**Staging** : `origin/staging` @ `09d4560c` (PR #669 — coach citation polish + pubspec 66 deployed)
**Status** : Sub-phase 01.4 ✓ closed earlier today. Sub-phase 01.5 PR-1 backend ✓ shipped to dev. **PR-2 mobile + PR-3 Maestro NOT started cleanly — restart from a fresh session.**

---

## What shipped this session (4 PRs)

| PR | Sujet | Commit |
|---|---|---|
| [#668](https://github.com/MINT-IA/MINT/pull/668) | `fix(coach)` citation chip polish — coach narrates « OPP3 art. 7 » inline + pubspec 61→66 | `52e57af5` (dev) |
| [#669](https://github.com/MINT-IA/MINT/pull/669) | dev → staging promote | `09d4560c` (staging) |
| [#670](https://github.com/MINT-IA/MINT/pull/670) | `fix(fastlane)` retry non-idempotent — false-positive TestFlight failure | `0d60983d` (dev) |
| [#671](https://github.com/MINT-IA/MINT/pull/671) | `feat(backend)` POST /api/v1/waitlist + WaitlistEntry model — sub-phase 01.5 PR-1 | `be6d7e61` (dev) |

**Coach citation polish verified live on staging** : curl probe à 17:50 UTC returned « 7258 CHF par an (OPP3 art. 7 al. 1) — et ce plafond augmente chaque année… ». Maestro hero regex `(OPP3|art.7|art.38|LIFD)` matches. 01.4 NIT closed.

**TestFlight build 66** : EST dans App Store Connect (uploaded 17:43:20 UTC). Workflow CI false-positive failure fixed in PR #670. **Julien doit manuellement submit build 66 to « Beta Testeurs » dans ASC quand previous build clears Apple's review queue.**

---

## Sub-phase 01.5 planning artifacts (all in `.planning/phases/01.5-archetype-hard-gate-fatca/`)

- `01.5-CONTEXT.md` (135 lines) — sub-phase scope, 5-gate exit contract
- `01.5-MAPPER-archetype-detection.md` (253 lines) — silent-fallback line épinglé : `coach_profile.dart:1875` + duplicate `fri_computation_service.dart:237-238`
- `01.5-SECURITY-fatca-scope.md` (205 lines) — FATCA P0 + LSFin art. 7-10 + nLPD audit ; VERDICT « waitlist + opt-in is sufficient »
- `01.5-UI-waitlist-spec.md` (284 lines) — WaitlistScreen design contract, 12 ARB keys, zero new widgets needed (uses `MintTextField` + `FilledButton` + `MintColors.inkPrimary`)
- `01.5-PLAN.md` (194 lines) — original 3-PR atomic sequence (PR-1 backend ✓ done, PR-2 mobile, PR-3 Maestro)
- **`01.5-REVIEWS.md`** (NEW this session) — **5-AI consensus** : 3 internal Claude sub-agents (qa-expert + code-reviewer + architect-review) + 2 external CLIs (Codex + Gemini) all converge on **atomic PR-2 with composite panel review AFTER final integrated diff**. **7 risks consolidated (R1-R7) that must be mitigated.**

---

## The 5-AI consensus on PR-2 — READ THIS BEFORE STARTING NEXT SESSION

| Reviewer | Verdict | Critical contribution |
|---|---|---|
| **qa-expert** | B atomique | « shipping a partial fix that leaves the bug live is willful, not negligent. Materially worse legal posture than today. » |
| **code-reviewer** | SHIP_WITH_PROPAGATION (= atomique) | usTaxPerson propagation à 6 mobile sites (==/hashCode/copyWith/fromJson/toJson/factories/updateFromSmartFlow) |
| **architect-review** | B atomique | PR-2a additive-only is already broken on `flutter analyze` (statement-form enum switches sans default) ; mid-state regression risk via `precision_service._lppYears('expat_us')` |
| **Codex** | B atomique + AFTER panel | **R4** mobile cached profile migration (tri-state) + **R5** runtime kill switch |
| **Gemini** | B atomique + AFTER panel | **R6** backend Pydantic profile schema gap + **R7** legacy user lockout migration flag |

### 7 consolidated risks (must mitigate BEFORE composite panel runs)

- **R1** — Exhaustiveness sweep : add `case FinancialArchetype.unknown` to 2 statement-form enum switches (`coach_chat_screen.dart:1722` `_archetypeToBackendName`, `lifecycle_phase_service.dart:371`). Re-grep `switch.*FinancialArchetype` before push.
- **R2** — String-slug defense-in-depth : handle `'unknown'` in `precision_service._lppYears` (return 0) + `prompt_registry._archetypeLabel` (return « Profil en validation »). Do NOT rely on gate to prevent the call.
- **R3** — Read-site regression tests BEFORE push : `test/models/coach_profile_archetype_test.dart` + `test/services/fri_computation_service_archetype_test.dart` (8+ tests).
- **R4** (Codex) — Mobile cached profile migration : **tri-state `usTaxPerson` end-to-end** (never coerce null→false in gate logic) + recompute archetype on app start + regression test « old JSON without new keys » + telemetry counter `gate_decision_by_signal_state`.
- **R5** (Codex) — Runtime kill switch / feature flag for coach rendering when archetype=unknown OR signal set incomplete. Per « if this is truly P0 legal exposure, require a short-term runtime kill switch so rollback pressure never reopens the exact same liability window. »
- **R6** (Gemini) — Backend Pydantic schema gap : `services/backend/app/schemas/profile.py` does NOT contain `us_tax_person` + `nationality` fields. **Mobile→backend→mobile sync ERASES the FATCA signal every roundtrip** unless these fields are added to `ProfileBase` + `ProfileUpdate` + `Profile` (response) in the same atomic window. Gemini audit confirmed Pydantic v2 with NO camelCase alias_generator (fields are declared camelCase directly).
- **R7** (Gemini) — Legacy User Lockout migration flag : changing `nationality == null` fallback from `swissNative` to `unknown` will immediately kick every existing user without a completed profile to the waitlist. Hard re-onboarding for a large segment. Need a migration flag OR be prepared for the churn.

### Revised scope (5-AI verdict — ~25-30 files, not 18)

- **Mobile** (~18-22 files) : Patch C detection + propagation R1+R2+R4 + Patch B WaitlistScreen + ARB + Patch D US-tax-person onboarding Q + GoRouter + gate + Patch E walker seed + R5 feature flag + R7 migration logic + R3 tests
- **Backend** (~3-5 files) : R6 Pydantic schema (`schemas/profile.py`) + alembic migration if needed + tests + OpenAPI canonical regen (`tools/openapi/generate_canonical.py`)
- **Planning** : update PLAN.md to reflect 7 risks + new file list

---

## Recommended next-session approach

### Option A — `/gsd-execute-phase 01.5-archetype-hard-gate-fatca` (orchestrated)

**Caveat** : 01.5-PLAN.md may not be structured as GSD wave-parallelizable plans (single monolithic file, not `XX-YY-PLAN.md` per wave). Likely needs to be re-split into wave plans first via `/gsd-plan-phase --reviews` so the orchestrator can dispatch executors per wave.

### Option B — `/gsd-plan-phase 01.5-archetype-hard-gate-fatca --reviews` (re-plan with REVIEWS.md)

This is **probably the right next move**. The orchestrator reads `01.5-REVIEWS.md` (just committed) and regenerates `01.5-PLAN.md` as wave-structured plans incorporating the 7 risks. Then `/gsd-execute-phase 01.5-...` dispatches gsd-executor agents per wave with clean context.

### Option C — Direct sub-agent spawning (raw `Agent` calls)

This is what I tried this session and made a mess of. **Don't do this.** Each spawn was logical but the orchestration burden + context-bleed in main thread became unmanageable. GSD orchestration exists specifically to avoid this.

### After PR-2 ships : Codex review

Per Codex + Gemini explicit verdict : composite panel review **AFTER final integrated diff**, not in parallel. Run `/codex review` on the merged PR-2 diff. Cross-AI tiebreaker before merge.

---

## Engram observations saved this session

- `#296` Phase 01.4 citation chip polish SHIPPED + verified live 2026-05-21 (coach narrates OPP3 art. 7 inline) — decision
- `#297` Fastlane TestFlight retry pattern non-idempotent — fixed PR #670 2026-05-21 — bugfix

Sub-phase 01.5 PR-1 backend (PR #671 = `be6d7e61`) NOT yet saved to engram — next session should save it as :
- `mint:phase-01.5:pr-1-backend-shipped` (decision) — title « Sub-phase 01.5 PR-1 backend (POST /api/v1/waitlist) shipped 2026-05-21 »

---

## Uncommitted state

This handoff + `01.5-REVIEWS.md` are committed by the same close-out commit so the next session has the full audit trail.

Working tree should be clean post-commit.

---

## How next session resumes (after /clear)

1. `git pull` — verify `git log -5` shows `be6d7e61` (PR #671 backend) and the close-out commit
2. Read this file + `.planning/phases/01.5-archetype-hard-gate-fatca/01.5-REVIEWS.md` (the 5-AI consensus + 7 risks)
3. Re-plan PR-2 via `/gsd-plan-phase 01.5-archetype-hard-gate-fatca --reviews` (regenerates 01.5-PLAN.md as wave-structured plans incorporating the 7 risks)
4. Run `/gsd-execute-phase 01.5-archetype-hard-gate-fatca` (orchestrator dispatches gsd-executor agents per wave with clean context)
5. After PR-2 merged : `/codex review` on the diff before final merge
6. PR-3 Maestro flow + 5-gate close-out

**Default recommendation** : re-plan + orchestrate via GSD. The 5-AI verdict + 7 risks lock the architectural decisions ; next session only needs to execute methodically.

---

## What went wrong this session (lessons for next time)

1. **Tried to batch ~25-30 files in main thread context** — should have invoked `/gsd-execute-phase` immediately when PR-2 scope expanded beyond 5-10 files.
2. **Spun on architectural decision (atomic vs split)** for too long instead of trusting PLAN.md's original atomic recommendation. Should have spawned the 5 reviewers earlier, in parallel, before starting edits.
3. **Manually spawned raw `Agent` calls** when `/gsd-execute-phase` was the right abstraction. Julien called this out : « tu dois lancer GSD, non ? ».
4. **Composite panel timing assumption wrong** : I proposed « panel IN PARALLEL with code-writing ». Codex + Gemini both said AFTER final diff. Trust the cross-AI verdict on timing.

**Lock** for next session : if PR scope > 10 files OR cross-cutting (mobile + backend), invoke `/gsd-execute-phase` immediately. Do NOT batch in main thread.
