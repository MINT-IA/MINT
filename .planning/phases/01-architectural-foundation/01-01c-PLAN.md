---
phase: 01-architectural-foundation
plan: 01c
type: execute
wave: 1
depends_on: [01-01a, 01-01b]
parent_plan: 01-01-PLAN.md
files_modified:
  - .planning/phases/01-architectural-foundation/01-VERIFICATION.md
autonomous: true
requirements: [DEVICE-01]
---

# Plan 01-01c: Proof-of-fire + VERIFICATION.md + Phase 1 close

**Depends on:** 01-01a (router migrated) and 01-01b (5 gates + fixtures green) both complete.

## Scope

1. **Proof-of-fire demonstration:** create a single throwaway commit on a sacrificial branch (NOT the feature branch) that intentionally introduces one of the 3 v2.2 P0 patterns into the migrated router (e.g., add a `context.go('/profile/consent')` call from an onboarding-scope screen). Run `flutter test apps/mobile/test/architecture/` and capture the RED output. Discard the branch. Save the captured output to `.planning/phases/01-architectural-foundation/proof_of_fire.txt`.
2. **Re-run full verification on the feature branch:**
   - `flutter analyze apps/mobile/lib/` (must be 0 errors, 0 warnings)
   - `flutter test apps/mobile/test/architecture/` (all 5 gates + would-have-fired suite green)
   - `flutter test` full mobile suite (no regression vs baseline)
3. **Write `01-VERIFICATION.md`** with frontmatter:
   ```yaml
   status: passed
   phase: 1
   reqs_covered: [NAV-01, NAV-02, GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, DEVICE-01]
   ```
   Body documents:
   - Test counts before/after (Flutter mobile suite)
   - flutter analyze status
   - The 5 gates' file paths and what each catches
   - The 3 would-have-fired fixture results (which v2.2 P0 each replicates and that the gate fires red)
   - The proof-of-fire output excerpt
   - Gate 0 status: "Phase 1 ships zero user-facing change. Gate 0 = CI dashboard screenshot showing the 5 architecture tests green on the PR. Awaiting Julien's screenshot capture (next step after this plan)."
4. **Commit:** `chore(01): close phase 1 architectural foundation [DEVICE-01]`

## Out of scope

- Any code change beyond the throwaway proof-of-fire branch (which is discarded)
- Phase 2 work (deletion spree)
- The Gate 0 iPhone walkthrough (Phase 1 has no user-facing change; Gate 0 here is the CI screenshot)

## Verification gates

This sub-plan IS the verification step for Phase 1. Its own gate is: VERIFICATION.md exists with `status: passed`, all 8 REQs ticked, proof_of_fire.txt exists with non-empty captured red output.
