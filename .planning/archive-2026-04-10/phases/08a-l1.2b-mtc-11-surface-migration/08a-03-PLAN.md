---
phase: 08a-l1.2b-mtc-11-surface-migration
plan: 03
type: execute
wave: 3
depends_on: [08a-02]
files_modified:
  - tools/checks/no_legacy_confidence_render.py
  - tools/checks/sentence_subject_arb_lint.py
  - tools/checks/tests/test_no_legacy_confidence_render.py
  - tools/checks/tests/test_sentence_subject_arb_lint.py
  - .github/workflows/ci.yml
  - tools/checks/lcov_confidence_baseline.json
  - docs/MIGRATION_RESIDUE_8a.md
autonomous: true
requirements: [MTC-11, MTC-12, TRUST-02]
must_haves:
  truths:
    - "no_legacy_confidence_render.py fails the build if ANY of the D-07 grep patterns hits a file outside the allowlist"
    - "sentence_subject_arb_lint.py fails the build on any negative ARB string not using MINT-as-subject among the diff vs dev"
    - "CI runs both lints on every PR, blocking merge on a red build"
    - "Pre-migration lcov baseline for confidence consumers is committed, and the post-migration run is asserted ≥ baseline"
    - "7 DO-NOT-MIGRATE files listed verbatim in an in-script allowlist matching AUDIT-01 §DO-NOT-MIGRATE"
  artifacts:
    - path: tools/checks/no_legacy_confidence_render.py
      provides: "coverage gate CI script"
    - path: tools/checks/sentence_subject_arb_lint.py
      provides: "TRUST-02 sentence-subject ARB lint"
    - path: .github/workflows/ci.yml
      provides: "CI wiring for both lints"
    - path: tools/checks/lcov_confidence_baseline.json
      provides: "MTC-12 pre-migration test count baseline"
    - path: docs/MIGRATION_RESIDUE_8a.md
      provides: "documented list of non-11 calculation sites not yet migrated"
  key_links:
    - from: .github/workflows/ci.yml
      to: tools/checks/no_legacy_confidence_render.py
      via: "CI step executes the script and fails on non-zero exit"
      pattern: "no_legacy_confidence_render"
    - from: .github/workflows/ci.yml
      to: tools/checks/sentence_subject_arb_lint.py
      via: "CI step executes the script on ARB diff vs dev"
      pattern: "sentence_subject_arb_lint"
---

<objective>
Build the coverage gate and the TRUST-02 ARB lint, wire them into CI, capture the MTC-12 lcov baseline, and document any migration residue. This plan is the mechanical enforcement layer: after it lands, Phase 8a regressions become impossible to merge silently.

Purpose: Prevent silent coverage loss (P4 pitfall) and silent TRUST-02 violations.
Output: 2 lint scripts + their tests + CI wiring + baseline snapshot + residue doc.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-CONTEXT.md
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-01-PLAN.md
@.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-02-PLAN.md
@docs/AUDIT-01-confidence-semantics.md
@.github/workflows/ci.yml
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: no_legacy_confidence_render.py coverage gate</name>
  <files>
    tools/checks/no_legacy_confidence_render.py
    tools/checks/tests/test_no_legacy_confidence_render.py
  </files>
  <behavior>
    - Test 1: Script run on a clean tree (post Plan 08a-02) returns exit 0 with no hits.
    - Test 2: Script run against a fake tree injecting `_confidenceColor(0.7)` in `lib/widgets/home/confidence_score_card.dart` returns exit 1 with a clear error pointing at the file + line + pattern.
    - Test 3: Script run against a fake tree injecting `_confidenceColor(0.7)` in one of the 7 DO-NOT-MIGRATE allowlist files returns exit 0 (file-path exemption works).
    - Test 4: Script run against a fake tree with `confidence < 70` in `confidence_scorer.dart` (engine source, allowlisted) returns exit 0.
    - Test 5: Script run against the MTC file itself (`widgets/trust/mint_trame_confiance.dart`) returns exit 0 regardless of patterns inside — trust dir is allowlisted.
    - Test 6: Script run against a hit in a NON-11 file NOT in the allowlist returns exit 1 with an explicit hint pointing to `MIGRATION_RESIDUE_8a.md` as the escape valve.
  </behavior>
  <action>
    Create `tools/checks/no_legacy_confidence_render.py` (Python 3, stdlib only, no extra deps):

    1. Define the allowlist (copy from CONTEXT §D-07, including the 7 DO-NOT-MIGRATE verbatim from AUDIT-01 §DO-NOT-MIGRATE — paste all 7 file paths).
    2. Define the pattern list (copy verbatim from CONTEXT §D-07 grep patterns).
    3. Walk `apps/mobile/lib/` with os.walk, read each `.dart` file, run each regex. For any hit whose file is NOT in the allowlist, record (file, line, pattern, snippet).
    4. If any hit collected → print a formatted report (grouped by file) → exit 1. Else exit 0.
    5. Exit 1 report ends with: "To fix: migrate the file to MintTrameConfiance (see Phase 8a CONTEXT §D-01), OR add it to docs/MIGRATION_RESIDUE_8a.md with a justified reason + ticket ID."
    6. Support a `--verbose` flag that lists allowlisted matches too (for debugging).

    Write tests in `tools/checks/tests/test_no_legacy_confidence_render.py` using pytest + tmp_path fixtures. The tests construct fake `lib/` trees and invoke the script as a module.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tools/checks/tests/test_no_legacy_confidence_render.py -q && python3 tools/checks/no_legacy_confidence_render.py</automated>
  </verify>
  <done>
    Script exists, tests green, clean-tree run returns 0, all 6 behaviors pass.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: sentence_subject_arb_lint.py TRUST-02 gate</name>
  <files>
    tools/checks/sentence_subject_arb_lint.py
    tools/checks/tests/test_sentence_subject_arb_lint.py
  </files>
  <behavior>
    - Test 1: A fake diff adding the FR ARB key `emptyStateTrust: "Tu n'as pas rempli ton profil."` fails with an explicit error: "TRUST-02 violation: negative statement must use MINT as subject".
    - Test 2: Same fake diff with `"MINT ne voit pas encore assez de données pour s'engager."` passes.
    - Test 3: A positive statement like `"Mint pense que le taux peut varier."` is not constrained (no fire).
    - Test 4: EN diff `"You don't have enough data yet."` fails; `"MINT doesn't have enough data yet."` passes.
    - Test 5: DE diff `"Du hast nicht genug Daten."` fails; `"MINT hat noch nicht genug Daten."` passes.
    - Test 6: Keys UNCHANGED vs dev are not checked (diff-only scope).
  </behavior>
  <action>
    Create `tools/checks/sentence_subject_arb_lint.py`:

    1. Detect diff vs `dev`: `subprocess.run(['git', 'diff', '--unified=0', 'dev...HEAD', '--', 'apps/mobile/lib/l10n/'])`, parse added/modified ARB key-value pairs. JSON-parse the ARB file at HEAD for context.
    2. For each changed key+value, check if the value is a "negative-class" statement: contains one of the trigger lemmas (FR: `\bpas\b`, EN: `\bnot\b|n't`, DE: `\bnicht\b`, IT: `\bnon\b`, ES: `\bno\b`, PT: `\bnão\b`). Positive statements skip the check.
    3. For negative-class values, check the subject: must START (tolerant of leading quote, markdown, non-breaking space, small adverbs) with the language-specific MINT form: `MINT`, `Mint`. Forbidden subjects: `Tu`, `Vous`, `You`, `Du`, `Tu` (IT/ES/PT).
    4. On violation: print file:key:value + rule + fix example → exit 1. Else exit 0.
    5. Support `--base <ref>` to override the diff base (default `dev`) for tests.
    6. Support `--all` to run the full repo sweep (used by a nightly job, not by PR CI).

    Write tests in `tools/checks/tests/test_sentence_subject_arb_lint.py` using a tmp git repo fixture with minimal `dev` + `HEAD` ARB files exercising all 6 behaviors.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tools/checks/tests/test_sentence_subject_arb_lint.py -q</automated>
  </verify>
  <done>
    Script exists, tests green, 6 behaviors pass, integrates with git diff.
  </done>
</task>

<task type="auto">
  <name>Task 3: CI wiring + lcov baseline + migration residue doc</name>
  <files>
    .github/workflows/ci.yml
    tools/checks/lcov_confidence_baseline.json
    docs/MIGRATION_RESIDUE_8a.md
  </files>
  <action>
    1. **CI wiring** — Edit `.github/workflows/ci.yml`. Add a new job step (or extend the existing Python checks step) that runs:
       ```yaml
       - name: No legacy confidence render (Phase 8a gate)
         run: python3 tools/checks/no_legacy_confidence_render.py
       - name: Sentence-subject ARB lint (TRUST-02)
         run: python3 tools/checks/sentence_subject_arb_lint.py --base origin/dev
       ```
       Place both steps so they run on every PR targeting `dev`, `staging`, `main`. Do not skip on any branch.

    2. **lcov baseline** — Run `flutter test --coverage` once on the tip of `dev` BEFORE this plan's changes (or at the tip of 08a-02 before merge) and capture the number of test cases covering the files listed in CONTEXT §D-01 (the 11 surfaces) + the MTC file itself. Store in `tools/checks/lcov_confidence_baseline.json`:
       ```json
       {
         "captured_at": "2026-04-07T...",
         "phase": "08a",
         "test_count_on_confidence_consumers": <N>,
         "files": { "apps/mobile/lib/widgets/home/confidence_score_card.dart": <tests_hitting_it>, ... }
       }
       ```
       Add a CI step that re-runs the same measurement on HEAD and asserts `test_count >= baseline.test_count_on_confidence_consumers`. MTC-12 satisfied.

    3. **Migration residue doc** — Create `docs/MIGRATION_RESIDUE_8a.md` with a table listing every calculation-confidence hit from AUDIT-01 that is NOT in the 11 and NOT in the 7 DO-NOT-MIGRATE. For each: file, AUDIT-01 row, reason for deferral (transitively absorbed by one of the 11 / out of Phase 8a scope / future phase), owner, ticket ID (or `TBD`). This is the escape valve the coverage gate points at.

       Examples of residue: `confidence_dashboard_screen.dart` (absorbed by MTC.detail deep-dive route, no separate migration), `widget_renderer.dart` (server-driven chip, migrates when CONTRACT-05 ships), `financial_plan_card.dart` (home Pulse — defer to Phase 8c polish), 4 arbitrage screens (defer to Phase 9 arbitrage sweep), `instant_premier_eclairage_screen.dart` + `premier_eclairage_screen.dart` (defer to Phase 10 onboarding v2), `mint_ligne.dart` (transitively absorbed — tier colors now come from MTC tokens via design system, file stops reading raw confidence directly — verify in residue doc).

    4. Regenerate lockfiles or ci-cache if needed (unlikely).
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 tools/checks/no_legacy_confidence_render.py && python3 tools/checks/sentence_subject_arb_lint.py --base origin/dev && test -f tools/checks/lcov_confidence_baseline.json && test -f docs/MIGRATION_RESIDUE_8a.md && grep -q no_legacy_confidence_render .github/workflows/ci.yml && grep -q sentence_subject_arb_lint .github/workflows/ci.yml</automated>
  </verify>
  <done>
    CI runs both gates on every PR. lcov baseline committed. Residue doc published. Coverage gate + ARB lint + MTC-12 all enforced by CI.
  </done>
</task>

</tasks>

<verification>
- Coverage gate green on the post-08a-02 tree.
- TRUST-02 ARB lint green on the diff vs dev.
- CI workflow syntax valid (`yq` or `actionlint` if available).
- lcov baseline file present + referenced from CI.
- Residue doc published with every deferred file accounted for.
</verification>

<success_criteria>
The MTC migration cannot regress silently. Any future PR that re-introduces a legacy confidence rendering pattern on a non-allowlisted file, or adds a negative ARB string without MINT-as-subject, or drops test coverage on confidence consumers, fails the build mechanically.
</success_criteria>

<output>
After completion, create `.planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-03-SUMMARY.md`.
</output>
