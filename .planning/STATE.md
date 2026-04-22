---
gsd_state_version: 1.0
milestone: v2.8
milestone_name: L'Oracle & La Boucle — Overview
status: executing
stopped_at: Completed 34-06-PLAN.md (GUARD-07 LEFTHOOK_BYPASS convention + weekly bypass-audit.yml workflow, D-20/D-21/D-22 triplet shipped, 4 deviations all Rule 1/2 additive, commits 75e1d6d7 + ba9cf0a3, 6/8 Phase 34 REQs complete, observation-window deferrals documented for /gsd-verify-work)
last_updated: "2026-04-22T21:14:09.121Z"
last_activity: 2026-04-22
progress:
  total_phases: 9
  completed_phases: 5
  total_plans: 30
  completed_plans: 29
  percent: 97
---

# GSD State: MINT v2.8 — L'Oracle & La Boucle

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19)

**Core value:** Toute route user-visible marche end-to-end et on le prouve mécaniquement ; on sait en <60s ce qui casse ; aucun agent ne peut ignorer son contexte ; Julien ouvre MINT 20 min sans taper un mur.
**Current focus:** Phase 34 — Agent Guardrails mécaniques

## Architecture Decisions (pre-phase, v2.8)

- **Nom**: "L'Oracle & La Boucle" (pas "Pilote & Compression"). Capture le geste central.
- **Rule inversée scellée**: 0 feature nouvelle. Tout ajout = out of scope by default.
- **Compression transversale**: chaque phase tue du code mort au passage, pas phase isolée.
- **Sentry existant étendu**, pas Datadog/Amplitude/PostHog (un seul vecteur = moins de surface nLPD + moins de divergence).
- **Système flags custom étendu** ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) + endpoint `/config/feature-flags`), pas LaunchDarkly.
- **lefthook pre-commit local**, pas juste CI gates (feedback <5s vs 2-5 min).
- **Phase numbering continué** depuis v2.7 (30 terminé) → **30.5, 30.6 (decimal inserts post-panel-debate), puis 31-36**.
- **Research activée** (Julien a choisi "Research first") — 4 researchers parallèles sur observabilité fintech mobile. Synthèse dans `.planning/research/SUMMARY.md`.
- **Phase debate résolu** (4 panels: Claude Code architect / peer tools / academic / devil's advocate) — MEMORY.md truncation = P0 runtime confirmé, lints mécaniques ROI > refonte éditoriale, AST proof-of-read = theater, `UserPromptSubmit` hook ciblé remplace AST, Phase 30.6 Tools Déterministes ajoutée (insight Panel C).
- **Kill-policy scellée** via [ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si v2.8 exit avec REQ table-stake unmet, la feature est KILLED via flag. Pas de v2.9 stabilisation.
- **Budget Phase 36 non-empruntable** (2-3 sem MINIMUM) — forces honest sizing de 31-35.

## Current Position

Phase: 34 (Agent Guardrails mécaniques) — EXECUTING
Plan: 8 of 8
Status: Ready to execute
Last activity: 2026-04-22
Next: `/gsd-verify-work 30.7` on `feature/S30.7-tools-deterministes` — 5/5 plans have SUMMARY, CLAUDE.md -30% trim @ 43a38dff, kill-switch rehearsed + Julien approved 2026-04-22, J0 fresh-session smoke deferred to post-merge operational validation (non-blocking). Also pending: `/gsd-verify-work 32` on `feature/v2.8-phase-32-cartographier` (3 RISK entries await Julien ack for nyquist_compliant flip).

Progress: [██████████] 100% (5/9 phases, 22/22 plans) — Phase 30.7 5/5 shipped (30.7-00 wave0 + 30.7-01 tools 1+2 + 30.7-02 tools 3+4 + 30.7-03 mcp-server + 30.7-04 CLAUDE.md trim -30%) ; Phase 32 6/6 shipped (reconcile + registry + cli + admin-ui + parity-lint + ci-docs-validation).

## Build Order

```
30.5 → 30.6 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36
```

- **30.5 Context Sanity** (5j non-empruntable) — foundation, CTX-05 spike gate go/no-go
- **30.6 Tools Déterministes** (2-3j) — MCP tools on-demand, ~16k tokens/session saved
- **31 Instrumenter** (1.5 sem, can borrow from 34) — Sentry Replay + error boundary 3-prongs + trace_id round-trip
- **34 Guardrails** (1.5 sem, can borrow from 31, parallel with 31) — lefthook + 5 lints + CI thinning. **GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05 starts.**
- **32 Cartographier** (1 sem, can borrow from 33) — route registry + /admin/routes dashboard
- **33 Kill-switches** (1 sem, can borrow from 32, parallel with 32) — GoRouter middleware + FeatureFlags ChangeNotifier + 4 P0 kill flags provisioned for Phase 36
- **35 Boucle Daily** (1 sem) — mint-dogfood.sh simctl + auto-PR threshold
- **36 Finissage E2E** (2-3 sem **non-empruntable**) — 4 P0 fixes + 388 catches → 0 + device walkthrough 20 min

## Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 30.5 | Context Sanity | 5j | **non-empruntable** | 5 | CTX-05 spike |
| 30.6 | Tools Déterministes | 2-3j | — | 4 | — |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — |
| 35 | Boucle Daily | 1 sem | — | 5 | — |
| **36** | **Finissage E2E** | **2-3 sem MIN** | **never** | **9** | 4 P0 kill flags + device walkthrough |

**Total estimate:** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

**v2.8 Execution Log:**

| Phase-Plan      | Duration | Tasks | Files | Completed  |
|-----------------|----------|-------|-------|------------|
| 32-02-cli       | 7 min    | 2     | 11    | 2026-04-20 |
| 32-03-admin-ui  | 11 min   | 2     | 11    | 2026-04-20 |
| 32-04-parity-lint | 5 min  | 1     | 6     | 2026-04-20 |
| Phase 32 P05 | 9min | 3 tasks | 5 files |
| Phase 30.7 P00 | 28 min | 3 tasks | 12 files |
| Phase 30.7 P01 | 15 min | 2 tasks | 4 files |
| Phase 30.7 P02 | 4min | 2 tasks | 4 files |
| Phase 30.7 P30.7-03 | 5min | 2 tasks | 5 files |
| Phase 30.7 P30.7-04 | 35 min | 2 tasks (T1 trim + T2 checkpoint) | 1 file (CLAUDE.md) | 2026-04-22 |
| Phase 34 P00 | 10 min | 2 tasks | 28 files |
| Phase 34 P01 | 6 min | 1 tasks | 7 files |
| Phase 34 P02 | ~8min | 2 tasks | 4 files |
| Phase 34 P03 | ~4min | 2 tasks | 5 files |
| Phase 34 P04 | 8min | 2 tasks | 7 files |
| Phase 34 P05 | 15min | 2 tasks | 7 files |
| Phase 34 P06 | 3min | 2 tasks | 3 files |

## Accumulated Context

### Decisions (v2.8 pre-phase)

- **v2.8 name**: "L'Oracle & La Boucle" captures instrumentation-first + daily loop
- **0 feature nouvelle** scellée via kill-policy ADR
- **Compression transversale**: chaque phase tue du code mort au passage
- **Extend existing Sentry** (not Datadog/Amplitude/PostHog) — bump `sentry_flutter` 8→9.14.0
- **Extend custom flags** (not LaunchDarkly) — converge 2 backend systems (env-backed read + Redis-backed write)
- **lefthook 2.1.5** for pre-commit local (not CI-only) — target <5s
- **Sentry Replay Flutter 9.14.0** with `maskAllText=true` + `maskAllImages=true` nLPD-safe defaults non-négociables
- **Headers manuels `sentry-trace` + `baggage` sur `http: ^1.2.0`** (pas migration Dio)
- **Binary-per-route flags** (pas cohort/percentage)
- **4 P0 kill flags provisioned in Phase 33** before Phase 36 begins: `enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`

### Phase 34-06 Decisions (GUARD-07 bypass convention + weekly audit, shipped 2026-04-22)

- **34-06** (commits `75e1d6d7` → `ba9cf0a3`): GUARD-07 activated via D-20/D-21/D-22 inseparable triplet. CONTRIBUTING.md extended from 34-05 bootstrap (31 → 155 lines, 6 sections) with §3 bypass policy locking LEFTHOOK_BYPASS=1 as SOLE authorised bypass + `[bypass: <three-word-reason-minimum>]` commit-body marker (RESEARCH Open Question 6 recommendation) + explicit ban on `--no-verify` (no trace in commit object = defeats audit). `.github/workflows/bypass-audit.yml` shipped: Monday 09:00 UTC schedule cron + push-to-dev + workflow_dispatch triggers; grep regex `LEFTHOOK_BYPASS|\[bypass:` on 7-day `origin/dev` window; auto-issue label `bypass-audit` when count > 3 (D-22).
- **Voluntary-signal design accepted** (RESEARCH Pitfall 6 + Open Question 6) — there is NO way to mechanically force operators to use `LEFTHOOK_BYPASS=1` instead of `--no-verify`. The weekly audit measures AWARENESS (did the operator voluntarily signal the bypass?); the ground-truth REGRESSION detector remains Plan 34-07 `lefthook-ci.yml` (D-24). Every audit surface (CONTRIBUTING §3, workflow header, issue body) cites Plan 34-07 explicitly — resolves RESEARCH Open Question 6 on complementarity.
- **4 Rule 1/2 auto-fixes (all strictly additive, no scope creep)**:
  - `workflow_dispatch` trigger added (Rule 2) — plan + RESEARCH Example 5 skeleton only listed schedule + push; without manual trigger, observation-window validation would require waiting until Monday 09:00 UTC for first firing.
  - Idempotent issue creation via `listForRepo({state: 'open', labels: 'bypass-audit'})` → comment-on-existing vs create-new branch (Rule 2) — both schedule AND push can fire the same week; title includes week-tag YYYY-MM-DD so GitHub's native title dedup would not help.
  - Triage body includes short hashes + authors + subjects via secondary `git log --pretty='- %h %an — %s'` pass (Rule 2) — plan body only included count + manual triage command; maintainer needs the commit list IN the issue.
  - Grep regex expanded from `LEFTHOOK_BYPASS` (plan literal) to `LEFTHOOK_BYPASS|\[bypass:` (Rule 1 bug) — CONTRIBUTING.md §3 recommends operators type `[bypass: <reason>]` in commit body as PERSISTED audit signal (env var never touches commit object); using grep-for-env-var-only would under-count every well-behaved bypass.
- **Traceability table in CONTRIBUTING.md §2** — 7 active lints mapped 1:1 to GUARD-01..06 requirements with scope + purpose, ready for onboarding any new dev (human or agent).
- **Pattern C established (reusable)**: issue-creation idempotency via `listForRepo` preferable to GitHub's native dedup when titles include dynamic tags (week/date/build). Pattern applicable to any future scheduled audit that also accepts post-event triggers.
- **Zero threat flags** — plan adds docs + CI workflow only. No new endpoints, no new auth paths, no schema changes. `permissions: issues: write` on default GITHUB_TOKEN (A9 — same scope as `sync-branches.yml` baseline).
- **No user setup required** — workflow uses default `GITHUB_TOKEN` (A9 confirmed). No external secrets, no dashboard configuration beyond pre-existing "Allow GitHub Actions to create and approve pull requests" setting already used by `sync-branches.yml`.
- **3 observation-window verifications documented** (VALIDATION.md §Manual-Only) — (1) Monday cron actually firing requires 7-day wait; (2) synthetic >3 detection requires deliberate operator bypasses over a week; (3) lefthook-ci.yml complementarity requires Plan 34-07 shipped + PRs through both gates. All 3 flagged `verify_type: observation_window` in SUMMARY — NOT gating for `/gsd-verify-work 34-06`.
- **Requirements-completed: [GUARD-07]** — 6/8 Phase 34 requirements done (GUARD-02 + GUARD-03 + GUARD-04 + GUARD-05 + GUARD-06 + GUARD-07). Only GUARD-01 (lefthook foundation, implicitly shipped 34-00) and GUARD-08 (CI thinning + lefthook-ci.yml) remain — both owned by Plan 34-07 which is now unblocked.

### Phase 34-05 Decisions (GUARD-06 proof_of_read commit-msg hook + D-04→D-27 amendment, shipped 2026-04-22)

- **34-05** (commits `bab21843` → `3789426a` → `d4b5196e`): GUARD-06 activated via first-ever `commit-msg:` top-level block in `lefthook.yml`. `tools/checks/proof_of_read.py` ships stdlib-only Python 3.9 (147 LOC, argparse + re + pathlib). `check_commit_msg(msg, repo_root) -> (int, List[str])` pure function + `main()` wraps with argparse (`--commit-msg-file {1}` + `--repo-root` for test harness). Exit 0 = pass (human commit OR valid proof-of-read), 1 = fail. Technical English diagnostics throughout, no i18n (M-1 carve-out + Pitfall 8 self-compliance via `accent_lint_fr.py --file proof_of_read.py rc=0`).
- **D-04 AMENDED in-flight via CONTEXT D-27** — Phase 34 originally stated "pas de commit-msg dans cette phase"; this plan surgically authorised ONE commit-msg block dedicated to proof-of-read. Inline YAML comment in `lefthook.yml` cites both `D-04 AMENDED` and `D-27` for traceability. No other Phase 34 lint migrates to commit-msg. Scope discipline statement inline: "future commit-msg lints require a new CONTEXT amendment on top of D-27".
- **T-34-SPOOF-01 mitigation live** — hardcoded `ALLOWED_READ_PREFIX = '.planning/phases/'` constant. `Read:` trailer pointing at `/dev/null`, `/etc/passwd`, or unrelated relative paths (`README.md`) rejected with rc=1. 2 pytest cases (`test_read_path_outside_planning_fail` absolute + `test_read_path_relative_outside_planning_fail` relative) enforce. Rejected realpath-canonicalisation alternative: the threat is "point at real-but-irrelevant file", not "chroot escape"; a prefix check is cheaper + more auditable.
- **D-17 human bypass short-circuits before Read: enforcement** — `TRAILER_CLAUDE.search(msg)` returns None → exit 0 silently with `[proof_of_read] OK - human commit (no Claude trailer), bypass`. Plain `git commit -m "fix typo"` from Julien lands without Read: trailer requirement.
- **12/12 pytest green in 0.02s** covering: valid Claude+Read:+bullets PASS, missing Read: FAIL, missing file FAIL, human bypass PASS, T-34-SPOOF-01 absolute + relative FAIL, D-18 no-bullet FAIL, empty message PASS, 3 Wave 0 fixture round-trips, case-sensitivity contract. Full matrix for D-16/D-17/D-18 + security.
- **Self-test 6th section green** — `lefthook_self_test.sh` now runs human-bypass PASS + Claude-no-Read: FAIL against Wave 0 fixtures (`commit_human_no_claude.txt` + `commit_without_read_trailer.txt`). PASS-with-Read: round-trip stays in pytest `tmp_path` to avoid depending on live working-tree state. Reminder banner updated: Plan 05 commit-msg hook scans COMMIT_EDITMSG (not files) so Pitfall 7 fixture-exclusion N/A for it.
- **P95 pre-commit benchmark unchanged at 0.090s** — commit-msg runs on a separate hook trigger, so the 5s `pre-commit:` budget (GUARD-01 success criterion #1) is untouched. 55x headroom preserved with 5 active pre-commit commands + 1 commit-msg command.
- **End-to-end self-compliance proven LIVE** — executor installed the commit-msg hook (`lefthook install --force` → `.git/hooks/commit-msg` registered) AFTER shipping the script + tests commit (`3789426a`, not gated) but BEFORE the lefthook wiring commit (`d4b5196e`, gated). `d4b5196e` passed the hook with a fresh `Read: .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md` trailer referencing the 14-bullet receipt file created at plan start. NO `--no-verify` used anywhere.
- **Chicken-and-egg bootstrap strategy** — executor pre-created `.planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md` in the RED commit (`bab21843`) so all 3 plan commits carry valid `Read:` trailers. Reusable pattern for future agent work: READ.md lands WITH the first commit of a plan, not after.
- **CONTRIBUTING.md bootstrap** — new file with 2 short sections: "Pre-commit hooks (lefthook)" + "Agent commits (proof-of-read — GUARD-06)" with example trailer block. Kept minimal per plan's no-expansion instruction; Plan 34-06 will add the LEFTHOOK_BYPASS section.
- **Requirements-completed: [GUARD-06]** — 5/8 Phase 34 requirements done (GUARD-02 + GUARD-03 + GUARD-04 + GUARD-05 + GUARD-06). Plans 34-06 (GUARD-07 bypass convention + audit) + 34-07 (GUARD-08 CI thinning) pending.
- **LOC deviation [Rule 2 - doc]** — plan target ~80 LOC / acceptance 60-120; actual 147 LOC. Excess is substantive docstring (D-27 amendment live + T-34-SPOOF-01 rationale + D-17 bypass contract + exit code table) prioritised per user's emphasis. Behavioural logic itself is ~70 LOC. `min_lines: 60` frontmatter contract met.

### Phase 34-04 Decisions (GUARD-05 arb_parity stdlib + depth-aware ICU walker, shipped 2026-04-22)

- **34-04** (commits `b3fd76b0` → `30c7c900` → `d91976f1`): GUARD-05 activated via D-13 key-set + placeholder parity lint on 6 ARB files (fr/en/de/es/it/pt). `tools/checks/arb_parity.py` ships stdlib-only Python 3.9 (361 LOC, json + re + argparse). Exit 0 on clean, 1 on drift. Production baseline empirically clean: 6707 non-@ keys × 6 langs, 568 placeholder-bearing @keys verified.
- **Depth-aware ICU walker replaces RESEARCH Pattern 4 regex (Rule 1 auto-fix)** — the suggested one-liner `\{\s*([A-Za-z_]...)(?:[},]|\s)` falsely captures select variant labels: `{sex, select, male {il} female {elle} other {iel}}` returns `{sex, il, elle, iel}` not `{sex}`. Walker tracks stack of clause kinds (placeholder / plural_or_select / variant_body) and only emits identifiers at name-position. Single O(n) pass.
- **ICU_KEYWORDS filter REMOVED at emission time (Rule 1 auto-fix)** — MINT production ARB uses `plural`/`number`/`date` as real placeholder names: `stepOcrContinueWith` + `stepOcrSnackSuccess` have placeholder literally named `plural` (referenced as `{plural}` for pluralisation suffix), `mortgageJourneyStepLabel` uses `number`, `mintHomeDeltaSince` / `planCard_targetDate` / `pensionFundSyncDate` / `dossierUpdatedOn` use `date`. Filtering would false-negative 7+ production keys. Walker structure already consumes type tokens (after first comma) via a dedicated branch that never touches `names.add()`, so no keyword blacklist needed.
- **3 pre-existing translation drifts fixed (Rule 1 auto-fix)** — `forfaitFiscalSemanticsLabel` in es/it/pt was missing the final `Savings: {savings}` sentence (truncated translations). FR + EN + DE had the full 3-placeholder template. Added idiomatic target-language sentences: es `. Ahorro: {savings}.`, it `. Risparmio: {savings}.`, pt `. Economia: {savings}.`. Proves GUARD-05 caught a real production bug on first run — RESEARCH baseline claim of "all 6 langs PASS today" (lines 388-410) was stale, based on key-set comparison only, not placeholder-set comparison.
- **Full 6-file scan per pre-commit event** — lefthook glob `apps/mobile/lib/l10n/app_*.arb` triggers the command when ANY ARB is staged; script internally scans all 6 via default `--dir`. Drift is a cross-file property (one language dropping a key must fail regardless of which file triggered the hook), so `{staged_files}` expansion would be unsound.
- **pytest 14/14 green** covering: 4 fixture-directory scenarios (parity_pass, missing-key, extra-key, placeholder-drift), 7 extract_placeholders unit tests (simple, plural, select, typed, multiple, empty, DateTime), 2 defensive tests (missing file, malformed JSON), 1 production baseline integration. All in 0.06s.
- **Self-test extended per D-25** — `lefthook_self_test.sh` 5th section runs bad fixture (`arb_drift_missing` with de missing `goodbye` → must rc=1) + clean fixture (`arb_parity_pass` → must rc=0). Pitfall-7 reminder banner now cites Plans 01+02+03+04.
- **P95 benchmark 0.100s** — unchanged from Plan 03 (6 pre-commit commands active; 50x headroom vs 5s D-26 budget). GUARD-01 success criterion #1 uncompromised.
- **Self-compliance (Pitfall 8) green** — `accent_lint_fr.py --file tools/checks/arb_parity.py` rc=0; `--file lefthook.yml` rc=0. Technical English diagnostics throughout, no i18n (M-1 carve-out for dev tooling precedent from Plan 32-03 admin).
- **Requirements-completed: [GUARD-05]** — 4/8 Phase 34 requirements done (GUARD-04 Plan 01 + GUARD-02 Plan 02 + GUARD-03 Plan 03 + GUARD-05 Plan 04). Plans 34-05/06/07 still pending.
- **FIX-06 Phase 36 decoupling confirmed** — GUARD-05 is the active prevention gate; FIX-06 (MintShell ARB parity audit) is the first human-driven full audit behind the gate. Thanks to GUARD-05 running today, the baseline was cleaned of 1 real drift — Phase 36 starts from a clean baseline.
- **LOC deviation documented** — plan estimated 100-180 LOC; actual 361 LOC. Walker is inherently more complex than RESEARCH's one-line regex (plus extensive algorithm documentation). LOC budget assumed a regex solution that turned out unsound; correctness wins over LOC target.

### Phase 34-03 Decisions (GUARD-03 no_hardcoded_fr D-08/D-09/D-10, shipped 2026-04-22)

- **34-03** (commits `1de6c2ba` → `6f58a21f` → `199f501f`): GUARD-03 activated via D-08 glob-scoped lefthook hook. `tools/checks/no_hardcoded_fr.py` rewrote 137 → 262 LOC (stdlib-only Python 3.9-compat) with 4 D-09 primary patterns (`_TEXT_CAPITALISED`, `_TEXT_ACCENT`, `_TITLE_PARAM`, `_LABEL_PARAM`) + 2 fallbacks (`_QUOTED_ACCENT`, `_QUOTED_FR_WORDS` early-ship) + 2 whitelist patterns (`_ACRONYM`, `_NUMERIC`) + D-10 preceding-line override. 11/11 pytest green in 0.03s.
- **D-08 scope at glob layer, NOT in script** — `glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"` narrows pre-commit to widget code only; lib/l10n, lib/models, lib/services, test, integration_test stay out of scope naturally. Script's DEFAULT_SCOPE stays at `apps/mobile/lib` for manual `--scope` audits. Resolves RESEARCH Open Question 3 without script refactor. Full-codebase i18n audit (~120 strings services/models per D4) remains Phase 36 FIX-06 scope.
- **Preceding-line override mirrors Plan 34-02 verbatim** — `_override_in_preceding_line(lines, idx)` API shape + `_OVERRIDE = re.compile(r"//\s*lefthook-allow:hardcoded-fr:\s*(\S+(?:\s+\S+){2,})")` >=3-word reason enforcement. Same-line override also accepted via `_line_is_exempt` IGNORE_MARKERS + `_OVERRIDE.search(line)`. Phase 34 convention now established across GUARD-02 + GUARD-03 (Plans 04/05 will mirror).
- **Whitelist negative-signal gating** — `_is_whitelisted_string()` fires only when line has no FR accent AND no FR function-word signal. Prevents `Text('ERR: erreur grave')` from bypassing via acronym prefix. Not in D-09 text but required for whitelist sanity; Claude discretion per CONTEXT "structure interne des nouveaux scripts Python — Claude flexible".
- **Ordered pattern dispatch (most-specific → least)** — first match on a line wins (`continue` after append). Ensures `title: 'Bonjour monde'` yields `hardcoded-fr-title`, not generic `hardcoded-fr-words`. Single row per line.
- **lefthook.yml 5 pre-commit commands + parallel:true preserved** — `no-hardcoded-fr` appended after `no-bare-catch`. `{staged_files}` pattern means zero cost on commits that don't touch the widget glob. Benchmark P95 0.110s unchanged (5 commands, 45x headroom vs 5s budget). GUARD-01 success criterion #1 uncompromised.
- **Self-test extended per D-25** — `lefthook_self_test.sh` 4th section runs bad fixture (must rc=1) + good fixture (must rc=0) via direct `python3 --file` invocation. Pitfall-7 reminder banner cites Plans 01+02+03. Full self-test rc=0 with 4 sections green.
- **Self-compliance (Pitfall 8) green** — `accent_lint_fr.py --file tools/checks/no_hardcoded_fr.py` rc=0; `--file lefthook.yml` rc=0 (Plan 02 Pitfall-8 fix preserved). Technical English throughout.
- **Real widget no-false-positive** — `python3 tools/checks/no_hardcoded_fr.py --file apps/mobile/lib/widgets/mint_shell.dart` rc=0 on Julien's i18n-wired reference. Glob-scoped pre-commit + existing i18n discipline align.
- **Requirements-completed: [GUARD-03]** — 3/8 Phase 34 requirements done (GUARD-04 Plan 01 + GUARD-02 Plan 02 + GUARD-03 Plan 03). Plans 34-04/05/06/07 still pending.
- **Phase 36 FIX-06 decoupling confirmed** — ~120 existing hardcoded FR strings in services/models remain in-place without blocking commits. Pre-commit glob restricts scope to widgets/screens/features only. FIX-06 can converge backlog by batch knowing no new widget-layer FR enters without override.

### Phase 34-02 Decisions (GUARD-02 no_bare_catch diff-only lint, shipped 2026-04-22)

- **34-02** (commits `ef9ede9c` → `794eaf14` → `51e56adc`): GUARD-02 activated day-1 via D-07 diff-only mode. `tools/checks/no_bare_catch.py` (255 LOC stdlib-only Python 3.9) scans ONLY lines ADDED in `git diff --staged --unified=0 --no-renames --diff-filter=AM` — decouples Phase 34 from Phase 36 FIX-05 migration of 388 existing bare-catches (332 mobile + 56 backend). Empirically proven: file with pre-existing bare-catch + unrelated line added → rc=0; same file + NEW bare-catch added → rc=1 with exactly 1 violation (not 2).
- **Preceding-line override semantics (B1 fix)** — `_override_in_preceding(lines, added_line_no, is_python)` helper accepts `// lefthook-allow:bare-catch: <reason>` / `# lefthook-allow:bare-catch: <reason>` comments on the line IMMEDIATELY PRECEDING the bare-catch (not just same-line). Reason length >=3 whitespace-separated words enforced in shared `_has_valid_override`. This is the Phase 34 convention that Plan 34-03 `no_hardcoded_fr.py` must mirror.
- **EXEMPT_PATH_PREFIXES strict 4-prefix scope (W1 fix)** — EXACTLY `apps/mobile/test/`, `apps/mobile/integration_test/`, `services/backend/tests/`, `tests/checks/fixtures/`. NO broad `tests/` — that would exempt any future top-level `tests/` directory beyond D-06 authorised scope. Unit-tested via `test_test_dir_exempt` + `test_integration_test_exempt` + `test_services_backend_tests_exempt`.
- **parallel: true flipped** (D-02) — all 4 current pre-commit commands (memory-retention-gate + map-freshness-hint + accent-lint-fr + no-bare-catch) proven read-only per RESEARCH Pattern 6. Inline YAML comment justifies the flip; 30.5 D-04 caveat about `.git/index.lock` races does not apply (no command writes to the index). Benchmark P95 0.110s with 4 commands + parallel (vs 0.100s sequential Plan 01 with 3 commands) — modest goroutine overhead, still 45x headroom vs 5s budget.
- **pytest GUARD-02** — 12 cases covering D-05 detection (Dart bare-catch empty + Python bare-except pass + Python bare-except colon EOL), D-06 exemptions (3 test-path variants + async* generator + preceding-line override valid + preceding-line override insufficient reason), D-07 diff-only (CRITICAL pre-existing-ignored + new-addition-flagged), and positive case (logged + rethrown passes). All 12 green in 0.90s.
- **Self-test extended per D-25** — `lefthook_self_test.sh` now runs 2 direct-invocation checks via a temp git repo ($TMP_LINT via mktemp + EXIT trap cleanup): stages bad.dart (empty catch) → lint must FAIL; stages good.dart (Sentry + rethrow) → lint must PASS. Uses `--repo-root $TMP_LINT` harness to isolate from main working tree. Full self-test rc=0 with 3 green sections (retention + accent + no_bare_catch).
- **Rule 1 blocking auto-fix** — Plan 01 inherited a Pitfall-8 drift in its lefthook.yml inline comment (literal quoted ASCII-flattened stem in prose matched `\b<stem>\b` regex). Plan 01 SUMMARY claimed `accent_lint_fr.py --file lefthook.yml` rc=0 but the comment drift landed after that check was run. Rewrote the comment to cite CLAUDE.md §2 authoritatively without quoting stems verbatim. `accent_lint_fr.py --file lefthook.yml` now rc=0.
- **Self-compliance (Pitfall 8) green** — `accent_lint_fr.py --file tools/checks/no_bare_catch.py` rc=0; technical English diagnostics throughout, no FR prose, no ARB i18n (M-1 carve-out Phase 32-03 admin precedent).
- **Requirements-completed: [GUARD-02]** — 2/8 Phase 34 requirements done (GUARD-04 Plan 01 + GUARD-02 Plan 02). Plan 34-03/04/05/06/07 still pending.
- **FIX-05 Phase 36 decoupling confirmed** — D-07 diff-only mode ensures only NEW bare-catches fail the gate. The 388 existing bare-catches remain in-place without blocking commits. FIX-05 can now converge the backlog by batch (backend 56 first per CONTEXT §Deferred) knowing no new entries enter on staged diffs.

### Phase 34-01 Decisions (GUARD-04 accent-lint activation, shipped 2026-04-22)

- **34-01** (commits `613aeb6b` → `066fb178`): GUARD-04 activated. `tools/checks/accent_lint_fr.py` PATTERNS list reconciled with CLAUDE.md §2 canonical 14 stems per D-11 — 3 Phase 30.5 early-ship extras removed (`specialistes`/`gerer`/`progres`), 3 missing canonical patterns added (`prevoyance`/`reperer`/`cle`). CLAUDE.md §2 is authoritative over MEMORY.md feedback snapshot that seeded the early-ship list.
- **Lefthook accent-lint-fr command** wired into `lefthook.yml` pre-commit: glob `*.{dart,py,arb}` with explicit excludes for 5 non-FR ARBs (app_{en,de,es,it,pt}.arb per D-12) + `tests/checks/fixtures/**` + `tests/checks/test_accent_lint_fr.py` + `tools/mcp/mint-tools/tests/**` (Pitfall 7 — test files that legitimately contain ASCII stems as parametrize/test data must be exempted). Shell loop wrapper pattern (`for f in {staged_files}; do python3 ... --file "$f" || rc=1; done`) established as reusable idiom for single-file Python lints under lefthook.
- **Phase 30.7 TOOL-04 parametrize cases updated in lockstep** — Rule 1 blocking auto-fix: `test_accent_lint_scan_text.py` + `test_check_accent_patterns.py` both had parametrize cases on the 3 removed stems. Updated both with matching D-11 comments. 44/44 MCP TOOL-04 tests green post-reconcile. MCP tool contract (`scan_text` signature `(int, str, str)`) preserved — no MCP wrapper code changed.
- **Self-compliance (Pitfall 8) auto-fix** — Rule 2: initial docstring enumerated stems inline ("missing 3 canonical patterns (prevoyance/reperer/cle)"), fired `\\bprevoyance\\b` etc on the lint's own source. Rephrased to reference CLAUDE.md §2 authoritatively without naming stems in docstring body. `accent_lint_fr.py --file <self>` exits 0.
- **pytest GUARD-04** — 13 cases covering cardinality (`len(PATTERNS) == 14`), canonical stem set equality, new-stem firing (`prevoyance`/`reperer`/`cle`), removed-stem silence (`specialistes`/`gerer`/`progres`), fixture scan (accent_bad/accent_good), MCP signature guard. All 13 green in 0.01s.
- **Self-test extended per D-25** — `lefthook_self_test.sh` now runs 2 direct-invocation checks (bad fixture must exit 1, good fixture must exit 0) before the Pitfall-7 reminder banner. 30.5 retention-gate test preserved. Full self-test rc=0.
- **Benchmark preserved** at P95 0.100s with 3 commands active (vs Wave 0 baseline 0.120s with 2) — 50x headroom vs 5s budget. GUARD-01 <5s success criterion uncompromised. accent-lint-fr adds ~0.02-0.03s per invocation on typical staged diff.
- **Hook fires end-to-end (not façade)** — verified by staging a temp `.dart` file with `creer` → `lefthook run pre-commit` prints `🥊 accent-lint-fr (0.02 seconds)` with `exit status 1` (failing emoji = catches violation correctly).
- **FIX-07 Phase 36 scope confirmed** — 899 existing violations on `apps/mobile/lib` when scanned full-scope (incl. 32 in generated `app_localizations_en.dart` using `prevoyance` as variable name from the ARB key). Plan 34-01 goal = ACTIVATE gate to prevent NEW regressions, NOT CONVERGE existing code. The lint is now the moving-target guard; FIX-07 batches backfill knowing no new violations enter on staged diffs.

### Phase 34-00 Decisions (Wave 0 scaffolding, shipped 2026-04-22)

- **34-00** (commits `59c8b1a8` → `5a8ffb33`): lefthook.yml schema migrated (`skip:` moved from top-level to nested under `pre-commit:`) — `lefthook validate` now exits 0 (was `skip: Value is array but should be object` per RESEARCH A7). 30.5 D-01 skeleton preserved verbatim (memory-retention-gate + map-freshness-hint). `parallel: false` maintained in Wave 0; Plan 34-02 flips to true once no-bare-catch (read-only) lands per RESEARCH Pattern 6.
- **Baseline P95 captured empirically: 0.120s** over 8 runs (after 2-run warmup discard). Far below 5s budget (D-26). Plan 34-07 will enforce `tools/checks/lefthook_benchmark.sh --assert-p95=5` against this measurable baseline instead of a moving target. Budget headroom: 4.88s for 5 Phase 34 lints.
- **26 fixture files landed** under `tests/checks/fixtures/` covering GUARD-02/03/04/05/06 contracts: 5 bare-catch (Dart/Python bad+good + async_star_exempt), 2 hardcoded-fr widgets (bad + good with inline `lefthook-allow:` override demo), 2 accent (bad ASCII-flattened + good accented), 14 ARB (6 parity_pass + 6 drift_missing with de missing `goodbye` + 2 drift_placeholder with fr/en type mismatch), 3 commit-msg (Claude+Read trailer / Claude-only / human-only).
- **Pitfall 7 exclusion contract documented** in `tools/checks/lefthook_self_test.sh` — 3-line reminder banner printed on every self-test run: every new lint in Plans 34-01..05 must add `tests/checks/fixtures/**` to its `exclude:` list to prevent fixture-triggered self-regression. T-34-07 threat register mitigation.
- **Pytest scaffolding** (`tests/checks/conftest.py`) provides `fixtures_dir` Path fixture + `tmp_git_repo` factory for Plans 34-02 diff-only tests. 18 tests collect clean (pre-existing Phase 32 tests + 0 Phase 34 tests yet — conftest importable without errors).
- **D-27 anticipation**: commit-msg fixtures landed in Wave 0 even though GUARD-06 is Plan 34-05 scope. Atomic fixture set > fragmented per-plan additions. Single write, multiple plan consumers.
- **Scope discipline**: pre-existing iCloud duplicate directories (`tests/checks/fixtures 2/`, `tools/checks/` ` 2.py` / ` 3.py` files per CONTEXT §Duplicates-to-watch) deliberately NOT touched — flagged as backlog, not in-scope for Phase 34.

### Phase 30.7-04 Decisions (CLAUDE.md Atomic Trim -30%, shipped 2026-04-22)

- **30.7-04** (commit `43a38dff`): atomic CLAUDE.md trim 121 → 80 lines / 8019 → 5608 bytes / 2004 → 1402 est-tokens — **-30% on 3/3 dimensions** (lines -33.9%, bytes -30.1%, est_tokens -30.0%). Kill-policy -20% floor UNUSED, no escalation needed.
- **TOOL-01..04 discoverability preserved**: §3 MCP TOOLS stanza inlined 2 dense lines naming all 4 tools (`get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`, `check_accent_patterns`). Cross-pointers in NEVER #1 (validate_arb_parity) + NEVER #5 (check_banned_terms — body replaced by MCP pointer, not silently deleted) so agents hit the tool call-site in context rather than rederiving rules from memory.
- **Liu 2024 byte-invariance preserved**: TOP 5 RULES CRITIQUES + BOTTOM 5 RULES CRITIQUES blocks kept byte-for-byte (modulo trailing whitespace), Rule #1 top-3 banned terms (« garanti » / « optimal » / « meilleur ») + Rule #2 `creer → créer` accent rule verbatim in both windows. Bracket lint `python3 tools/checks/claude_md_bracket.py` exits 0 post-trim ; 10 NEVER triplets preserved (grep -c == 10).
- **Kill-switch rehearsal PASSED 2026-04-22** (T2 Step 3): `git revert 43a38dff` restores baseline exactly (121 / 8019 / 2004 matches `.claude_md_baseline.json`), `git reset --hard 43a38dff` re-applies trim cleanly, `--assert-delta 30` exits 0 post-reset with 3/3 PASS. Reversibility empirically mitigates threat T-30.7-04-03 (kill-switch broken + agents see neither rules nor tools). Restoration time <5s.
- **Julien semantic cold-read APPROVED 2026-04-22** (T2 Step 1): all load-bearing info preserved ; meta-workflow conventions (Co-Authored-By attribution, LEFTHOOK_BYPASS escape hatch) moved OUT of CLAUDE.md body but still discoverable via `.claude/skills/mint-commit/SKILL.md` + `rules.md` + hook reminders — acceptable trade-off for -30% target.
- **J0 fresh-session smoke (T2 Step 5) DEFERRED to post-merge operational validation** on creator's machine — requires fresh Claude Code session + `.mcp.json` first-run approval + `get_swiss_constants("pillar3a")` invocation. NOT a code gate, NOT a merge blocker — tool contract is already exercised by 78/78 Wave 2 pytest integration tests.
- **Trim methodology** (2 compression passes): pass 1 merged §1 IDENTITY + §2 ARCHITECTURE (reclaim header overhead), compressed §4 ROLE ROUTING to 1 inline sentence, §5 DEV RULES from 5 bullets → 2, §6 NEVER triplets to one-liner `❌ X · ✅ Y · ⚠️ Z` format, §7 QUICK LINKS to 1 line. Pass 2 dropped file to 76 lines (below bracket-lint's 80-line minimum for 2×WINDOW_LINES bracketing) ; fixed by splitting NEVER #1 + NEVER #5 from `· ` separator format into 3-line bullet format (net +4 lines, -4 bytes) + bonus `"Quickref. Role detail" → "Detail"` trim (-15 bytes) that pushed bytes from 5623 to 5608, crossing the -30% threshold (5613).
- **Token budget impact**: projected savings ~600 tokens/session × N sessions = massive cumulative gain for every future Claude Code session auto-loading CLAUDE.md. Phase 30.7 ship status: 4/4 tools live via MCP stdio + `.mcp.json` committed + CLAUDE.md trim verified + kill-switch rehearsed + 18+ tests green.

### Phase 30.6 Decisions (Context Sanity Advanced, shipped 2026-04-19)

- **CTX-03** (plan 00, `fb85cc9e`): CLAUDE.md refonte 429L → 121L quickref with bracketing TOP+BOTTOM + 10 triplets + AGENTS split into 3 role-scoped files, SHA-pinned backup for revert-safety
- **CTX-04** (plan 01, `89b6fb61`): `.claude/hooks/mint-context-injector.js` UserPromptSubmit hook with 5 patterns, top-3 dedup, 500ms fail-open, `MINT_NO_CONTEXT_INJECT=1` override
- **CTX-05** (plan 02, spike `38a3950b`, merge `0d86d215`): `sentry_flutter 9.14.0` + SentryWidget + `options.privacy.maskAllText/maskAllImages = true` — 5/5 mechanical grid + 0 dashboard regression, **Kill-policy D-01 NOT triggered, PHASE SHIPS**
- **Dashboard deltas vs baseline-J0**: metric A drift rate +2.4 pts (noise band, <10 pts gate); metric B context hit rate +14.2 pts (positive — hook catches more rule-hits = working); metric C token cost -37.7% (memory gc win from CTX-01 confirmed)
- **sentry_flutter 9.14.0 API learning**: `options.privacy.*` owns masks (not `.experimental.replay.*`); `options.replay.*` owns sampling rates; `tracePropagationTargets` is `final List<String>` (mutate via `..clear()..addAll([...])`)

### Phase 32-05 Decisions (Wave 4b CI + Docs + J0 Validation, shipped 2026-04-20)

- **32-05** (commits `69d6d87c` → `acd02c65`): 4 CI jobs wired into `.github/workflows/ci.yml` — `route-registry-parity` (D-12 §1, invokes Plan 04 lint), `mint-routes-tests` (D-12 §2, DRY_RUN pytest over Plans 02+03+04 = 26 tests), `admin-build-sanity` (D-12 §3, grep scan ENABLE_ADMIN=1 in testflight.yml+play-store.yml, T-32-05 mitigation), `cache-gitignore-check` (D-09 §3, T-32-02 residual). `ci-gate` needs[] extended; baseline clean pre-commit (no pre-existing ENABLE_ADMIN=1 leak).
- **`docs/SETUP-MINT-ROUTES.md` shipped**: Keychain setup with `-U -A` hardening + scope lock (`project:read + event:read + org:read` only, DO-NOT list including `member:*`) + 7-row commands table + 5-row env vars table + 5 nLPD controls D-09 §1-§5 with Art. 5/6/7/9/12 mapping + 6-row troubleshooting + Phase 35/36/CI integration refs. Technical English, no FR user-facing prose, banned LSFin terms grep empty.
- **`README.md` Developer Tools section added** with link to SETUP-MINT-ROUTES.md.
- **`tools/simulator/walker.sh --admin-routes` mode added**: rebuilds booted sim with `--dart-define=ENABLE_ADMIN=1`, reinstalls, launches, opens `mint://admin/routes` deep link (soft-fail if scheme missing), captures 5 screenshots to `.planning/phases/32-cartographier/screenshots/walker-$(date +%Y-%m-%d)/`. Alias `--scenario=admin-routes` normalized to `--admin-routes` before case dispatch. `MINT_WALKER_DRY_RUN=1` short-circuits. Both invocations verified exit 0 DRY_RUN.
- **Tree-shake gate (J0 Task 1) PASS on device target (not simulator)**: Flutter 3.41.6 rejects `--release` and `--profile` on simulator (documented deviation Rule 3). Built `flutter build ios --release --no-codesign --dart-define=ENABLE_ADMIN=0` → 8.86 MB Mach-O arm64. `strings Runner | grep -c kRouteRegistry` = 0. `grep -c "Retirement scenarios hub"` = 0. No admin symbols leaked. Tree-shake contract verified empirically.
- **6 J0 gates verdict: AMBER** (3 PASS + 3 BLOCKED + 0 FAIL). PASS: Task 1 tree-shake, Task 4 parity lint (exit 0, 140 routes parity OK), Task 5 DRY_RUN pytest (26/26 green). BLOCKED: Task 2 SentryNavigatorObserver (Keychain denied to non-interactive subprocess + staging DSN env unset), Task 3 batch OR-query live (same env reason; client-side `_build_batch_query(30)`=302 chars PASS), Task 6 walker.sh screenshots (Xcode CodeSign failed on simulator rebuild — L3 partial, autonomous must NOT self-patch per feedback_tests_green_app_broken).
- **M-4 strict 3-branch hierarchy applied**: `nyquist_compliant: false` STAYS false per strict rule — Task 2 is BLOCKED, not PASS, so flip condition not met. 3 §Risks entries (A/B operator choice each) written to `32-VALIDATION.md` awaiting Julien acknowledgment. The previous "soft defer / acceptable for now" wording was explicitly rejected per plan M-4 fix.
- **Per-Task Verification Map flipped**: all 34 rows in `32-VALIDATION.md` table from `⬜ pending` → `✅ green` (Wave 0-4 empirically verified via pytest/flutter test/parity lint). 6 J0 gates documented separately in new `## J0 Empirical Results — 2026-04-20` matrix.
- **VALIDATION.md frontmatter final**: `status: executed`, `wave_0_complete: true`, `nyquist_compliant: false`, `j0_verdict: AMBER`, `j0_pass_count: 3`, `j0_blocked_count: 3`, `j0_fail_count: 0`.

### Phase 32-04 Decisions (Wave 4 Parity Lint MAP-04, shipped 2026-04-20)

- **32-04** (commit `189aa0d6`): `tools/checks/route_registry_parity.py` ships stdlib-only Python 3.9 lint (argparse + re + pathlib + typing) with DOTALL regex over `GoRoute|ScopedGoRoute(path:...)`. Runtime 30ms (1000x under 30s CI budget). Extracts 148 path literals from app.dart (includes `/admin/routes` compile-conditional) vs 147 `kRouteRegistry` keys → 140 comparison paths parity OK after symmetric KNOWN-MISSES subtraction. Exits 0/1/2 per sysexits.h.
- **KNOWN-MISSES exemption strategy**: explicit allow-list sets `_ADMIN_CONDITIONAL` (1 entry: `/admin/routes`) + `_NESTED_PROFILE_CHILDREN` (7 tuples for `/profile/<child>` pairings) in the lint source. Rejected regex-guard preprocessing (fragile syntax variance) and separate allow-list file (scope bloat). Static allow-list is deterministic, auditable, fails loud on new entries not in the list (no_shortcuts_ever).
- **Symmetric subtraction for Category 5 nested children**: lint strips bare-segment from app.dart side AND composed `/profile/<segment>` from registry side. Asymmetric exemption would let ghost registry keys go unnoticed. Tuple form `(segment, composed)` in `_NESTED_PROFILE_CHILDREN` makes the pairing explicit, prevents half-updates.
- **KNOWN-MISSES.md amended**: Category 5 rewritten to document allow-list strategy (dropping stale `--resolve-nested` flag reference); Category 7 (admin-only compile-conditional routes) added with 3-option decision trail + maintenance policy for Phase 33 `/admin/flags`.
- **Shell wrapper anti-façade test** (`test_shell_wrapper_invokes_lint_and_propagates_exit_code`): `bash .lefthook/route_registry_parity.sh` asserted to exit 0 + forward "parity OK" stdout on pristine HEAD. Wrappers that exist but don't invoke the lint are `feedback_facade_sans_cablage` at the Bash level — tested end-to-end, not just chmod +x.
- **`lefthook.yml` + `.github/workflows/ci.yml` INTENTIONALLY UNTOUCHED**: per D-12 §5 the hook wiring is Phase 34 GUARD-01 scope (avoids merge conflict with GUARD-02 bare-catch work); CI job is Plan 32-05 scope. Git diff on both files is empty for this commit — scope discipline.
- **pytest 9/9 green** (9 cases, not the plan's stated 6): added 3 beyond plan scope — shell-wrapper-exists + shell-wrapper-invokes-lint + sort/dedup strictness. Pure additive coverage for anti-façade + regression-prevention.
- **Python 3.9 strict compat**: verified via `python3 -m py_compile`. Uses `from __future__ import annotations` + `typing.List/Optional/Set/Tuple` (not PEP 585 builtins). Zero PEP 604 unions, no match/case, no dict|dict merge. Dev 3.9.6 ↔ CI 3.11 forward-compat safe.

### Phase 32-03 Decisions (Wave 3 Admin UI MAP-02b + MAP-05, shipped 2026-04-20)

- **32-03** (commits `1639c3f0` → `95c21137`): `/admin/routes` pure schema viewer shipped behind compile-time `ENABLE_ADMIN` + runtime `FeatureFlags.isAdmin` double gate (D-10 local-only; NO backend call). 147 routes × 15 RouteOwner ExpansionTiles with `Semantics` labels (a11y). Footer points to `./tools/mint-routes health` for live status (D-06 CLI-exclusive health contract). AdminShell reusable for Phase 33 `/admin/flags` without refactor. 4 Wave 0 Flutter stubs flipped live (16 tests) + 1 new pytest (3 tests) — all green.
- **MAP-05 wired end-to-end**: all 43 arrow-form legacy redirects in app.dart converted to block-form `(_, state) { MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/x'); return '/x'; }`. Per-site coverage asserted by `tests/tools/test_redirect_breadcrumb_coverage.py` parsing the 43-row RECONCILE-REPORT inventory — not a fragile `grep -c == 43` total count (M-3 fix). Sum check (43 == Σ redirect_branches == 43) cross-validates. 9 block-form Category 6 redirects (scope guards, FF gates, param-passing) intentionally left unwired.
- **Behavioural breadcrumb test via `Sentry.init(beforeBreadcrumb: ...)` hook** (M-2 fix): captures real `Breadcrumb` objects from `MintBreadcrumbs.adminRoutesViewed` + `legacyRedirectHit`, asserts exact `data.keys.toSet()` equality (`{route_count, feature_flags_enabled_count}` when snapshotAgeMinutes null; `{route_count, feature_flags_enabled_count, snapshot_age_minutes}` when provided; `{from, to}` for redirects). Int-only structural check (`isNot(isA<String>())`) forbids String values (anti-PII gate). Supersedes Wave 0 source-string grep stub — behavioural contract matches nLPD Art. 12 processing record.
- **M-1 English carve-out** declared in every admin file header (`admin_gate.dart`, `admin_shell.dart`, `routes_registry_screen.dart`): exact literal `// Dev-only admin surface per D-03 + D-10 (CONTEXT v4). English-only by executor discretion — no i18n/ARB keys. Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**`. Phase 34 GUARD-03 can exempt the admin tree safely with an explicit provenance trail.
- **MintBreadcrumbs pre-landed in Task 1 commit** (Rule 3 blocking auto-fix): plan structured `legacyRedirectHit` + `adminRoutesViewed` as Task 2 File 1, but `RoutesRegistryScreen.initState` calls `adminRoutesViewed` at mount. Compile-time dependency won — helpers land with Task 1. 43-site wiring + tests still owned by Task 2.
- **Pytest indexes callsites by source path, not line number**: wiring 43 arrow-form redirects (1 line) into 4-line block forms shifts every downstream line in app.dart. `_extract_callback_body_by_source(src, source_path)` walks backward to `ScopedGoRoute(` then forward via balanced-paren tracking. Source paths are stable identifiers; line numbers are not.
- **Widget-test viewport trick**: `tester.view.physicalSize = Size(800, 20000)` so ListView.builder materialises all 15 owner tiles (default 800x600 only fits ~10). Also `find.byWidgetPredicate((w) => w is ListTile && w.dense == true)` to exclude ExpansionTile's internal-header ListTiles (otherwise naive `find.byType(ListTile)` returns 147+15=162).
- **Tree-shake empirical proof deferred to Plan 32-05 Wave 4 J0 Task 1**: `if (AdminGate.isAvailable) ...[ ScopedGoRoute(...) ]` is the compile-time guarantee; binary-grep `strings Runner | grep -c kRouteRegistry == 0` validates. Plan 32-05 also wires `admin-build-sanity` CI job scanning prod build YAMLs for accidental `--dart-define=ENABLE_ADMIN=1`.

### Phase 32-02 Decisions (Wave 2 CLI MAP-02a + MAP-03, shipped 2026-04-20)

- **32-02** (commits `458b0dab` → `317ccdb7`): `./tools/mint-routes` Python 3.9-compat CLI shipped with 3 subcommands (health, redirects, reconcile) + purge-cache + `--verify-token`. Task-split 2-phase: Task 1 skeleton with `NotImplementedError` stubs (pytest collects clean, no `ImportError`); Task 2 wires sentry_client + redaction + dry_run + replaces all 4 stubs. 14/14 pytest green, 0 skipped; 2/2 Flutter `route_meta_json_test.dart` green.
- **Keychain service name reused: `SENTRY_AUTH_TOKEN`** (matches Phase 31 `sentry_quota_smoke.sh:72`) — CONTEXT D-02 literal `mint-sentry-auth` **amended** inline. Zero onboarding friction: operator configures the Keychain entry ONCE for Phase 31 + 32 together.
- **nLPD D-09 controls active**: 5-pattern redaction (IBAN_CH, IBAN_ANY, AVS 756.xxxx.xxxx.xx added as A2 defensive default, EMAIL, CHF >100) + recursive `user.{id,email,ip_address,username}` key stripper + 7d cache TTL auto-purge + `purge-cache` operator wipe + `--verify-token` scope enforcer (allowed: project:read + event:read + org:read; extras => exit 78).
- **Token NEVER in argv** (T-32-03 mitigation): urllib.request with `Authorization: Bearer` header only. Test `test_keychain_fallback_token_never_in_argv` asserts no `--auth-token` string appears in sentry_client.py source. sentry-cli subprocess pattern explicitly rejected.
- **Schema contract published**: `apps/mobile/lib/routes/route_health_schema.dart::kRouteHealthSchemaVersion = 1`. Python↔Dart parity enforced byte-exactly by `test_json_output_schema_matches_dart_contract` regex-parsing the Dart source for the literal and asserting equality with Python `__schema_version__`. Any future drift fails the test loudly.
- **Exit codes (sysexits.h D-02 locked)**: 0/2/71/75/78. Graceful degradation on 414 (batch too large → 1 req/sec sequential fallback) and 429 (4s backoff → partial index). 401/403 → exit 78 with scope-diagnostic stderr.
- **Batch size default = 30** (147 paths → 5 chunks: 30+30+30+30+27). D-11 J0 empirical validation deferred to Plan 32-05 Task 3.
- **`reconcile` subcommand** graceful no-op until Plan 32-04 ships `tools/checks/route_registry_parity.py`: WARN to stderr + exit 0 (not crash). Auto-switches to lint-driven exit when script lands.
- **Python 3.9-compat throughout**: no PEP 604 `X | Y` unions, no `match/case`, no `dict | dict` merge. stdlib-only (urllib + subprocess + json + re). Zero external deps. CI 3.11 forward-compat verified.

### Phase 31-02 Decisions (Wave 2 backend OBS-03, shipped 2026-04-19)

- **31-02** (commits `6ea76af5` → `e39d3480`): `global_exception_handler` extended with 3-tier trace_id fallback (inbound `sentry-trace` > `trace_id_var` ContextVar > fresh `uuid4`). 500 JSON body surfaces `trace_id` + `sentry_event_id`. `X-Trace-Id` response header cohabits with LoggingMiddleware emission. FIX-077 nLPD `%.100s` log truncation preserved.
- **3-tier fallback over plan's 2-tier** (Rule 1 deviation) — RED phase surfaced `trace_id_var.get("-")` returning default `"-"` when handler runs in exception-handler scope (BaseHTTPMiddleware+`call_next` interaction). Added `uuid4()` 3rd tier to guarantee non-empty trace_id on all 500 responses. Future exception paths should reuse this pattern.
- **`sentry-sdk[fastapi]` pinned `==2.53.0`** in `services/backend/pyproject.toml` (was `>=2.0.0,<3.0.0`). Upgrade gated by rerunning `tools/simulator/trace_round_trip_test.sh` against staging.
- **A2 (proxy strip) VERIFIED** — Railway delivered `sentry-trace` header intact through `/auth/login` (422 response proves header was not stripped by CDN/proxy). X-MINT-Trace-Id fallback NOT needed.
- **A1 (auto-read cross-project link) PARTIAL** — capability documented upstream but unproven end-to-end here (staging 422 path never fires the 500 handler; cross-project link requires real Sentry event pair). Flip VERIFIED in Plan 31-04 quota probe.
- **DEFERRED: test-only raise_500 endpoint (accepted limitation per revision Info 7)** — `trace_round_trip_test.sh` PASS-PARTIAL via `/auth/login` 422 path is the accepted ship state for Phase 31. Re-evaluate Phase 32 or Phase 35.
- **Test fixture pattern** — app-level exception handler tests register a raising route via `@app.get` in a pytest fixture, use `TestClient(app, raise_server_exceptions=False)`, and pop the route from `app.router.routes` in teardown. Precedent: `tests/test_coach_chat_endpoint.py:91`.
- **Full backend suite: 5958 passed + 6 skipped** (baseline 5955+9; delta +3/-3 expected). Zero regression on pre-existing tests.

### Phase 31-00 Decisions (Wave 0 scaffolding + J0 walker, shipped 2026-04-19)

- **31-00** (plan 00, commits `6c265341` → `a8699856`): 17/17 Wave 0 scaffolds landed (8 Flutter test stubs + 1 pytest stub + 3 Python lints + 4 shell/simulator helpers + 1 README + integration_test/.gitkeep), `sentry-cli 3.3.5` installed, `.gitignore` extended with `.planning/walker/`.
- **OBS-01 SHIPPED via CTX-05 + Wave 0 audit** — `verify_sentry_init.py` reports 8/8 invariants green on current `main.dart`; no new mobile code for OBS-01. Any future edit dropping `maskAllText`/`maskAllImages`/`sendDefaultPii=false`/`SentryWidget`/`tracePropagationTargets`/`onErrorSampleRate=1.0` fails the lint mechanically (Pitfall 10 mitigation).
- **walker.sh smoke PASS** — `MINT_WALKER_DRY_RUN=1 bash tools/simulator/walker.sh --smoke-test-inject-error` exits 0 in ~61s (< 3 min budget). Façade-sans-câblage Pitfall 10 mitigated: the script was EXERCISED, not just shipped.
- **Open Question #4 resolved empirically** — staging `/_test/inject_error` HTTP 404 (endpoint absent); fallback to malformed JSON `POST /auth/login` HTTP 422 works (backend reachable + error handler active). Plan 31-02 will add the dedicated test endpoint backend-side.
- **Portable `to()` wrapper** added to walker.sh (Rule 2 deviation): macOS ships without `timeout`; walker now chains `gtimeout` → `timeout` → bare fallback with `WARN`. `brew install coreutils` executed on dev host to provide `gtimeout` (9.10). No hard dependency on coreutils for correctness.
- **D-03 4-level breadcrumb categories locked** as string literals in Flutter stub test descriptions: `mint.compliance.guard.{pass,fail}`, `mint.coach.save_fact.{success,error}`, `mint.feature_flags.refresh.{success,failure}`. Wave 1 implementers cannot drift the naming scheme.
- **`nyquist_compliant: true`** and **`wave_0_complete: true`** now set in `31-VALIDATION.md` frontmatter — Wave 1/2 (Plans 31-01, 31-02) unblocked.
- **`SENTRY_AUTH_TOKEN` operator setup** deferred (human-action auth gate). walker.sh + sentry_quota_smoke.sh gracefully WARN-and-continue when absent. Non-blocking for Wave 1 mobile; blocks Wave 4 quota probe only.

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Known Good Foundations (to capitalize)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

## Session Continuity

Last session: 2026-04-22T21:14:09.117Z
Stopped at: Completed 34-06-PLAN.md (GUARD-07 LEFTHOOK_BYPASS convention + weekly bypass-audit.yml workflow, D-20/D-21/D-22 triplet shipped, 4 deviations all Rule 1/2 additive, commits 75e1d6d7 + ba9cf0a3, 6/8 Phase 34 REQs complete, observation-window deferrals documented for /gsd-verify-work)
Resume file: None

---
*Last activity: 2026-04-22 — Phase 30.7 Tools Déterministes 5/5 plans shipped (Wave 0 scaffolding → Wave 1 tools 1-4 → Wave 2 MCP server + .mcp.json → Wave 3 CLAUDE.md trim -30%). TOOL-01..04 all complete. Next: `/gsd-verify-work 30.7` then unblock (31∥34) parallel window.*
