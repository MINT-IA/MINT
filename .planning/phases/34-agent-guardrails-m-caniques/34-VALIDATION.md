---
phase: 34
slug: agent-guardrails-m-caniques
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 34-RESEARCH.md §Validation Architecture + CONTEXT.md D-25/D-26.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (backend/infra lints) + bash self-test script |
| **Config file** | `services/backend/pytest.ini` (existing) — lints tested standalone |
| **Quick run command** | `bash tools/checks/lefthook_self_test.sh` |
| **Full suite command** | `bash tools/checks/lefthook_self_test.sh && bash tools/checks/lefthook_benchmark.sh` |
| **Estimated runtime** | ~8-12 seconds (self-test) + ~15-25 seconds (benchmark 5 runs) |

---

## Sampling Rate

- **After every task commit:** Run `bash tools/checks/lefthook_self_test.sh` (only the lint added)
- **After every plan wave:** Run full self-test + benchmark
- **Before `/gsd-verify-work`:** Full suite green + P95 <5s verified
- **Max feedback latency:** 30 seconds (well under ceiling)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-00-01 | 00 | 0 | GUARD-01 | — | lefthook.yml schema valid | integration | `lefthook validate` | ❌ W0 | ⬜ pending |
| 34-00-02 | 00 | 0 | GUARD-01 | — | baseline benchmark <5s measured | integration | `bash tools/checks/lefthook_benchmark.sh` | ❌ W0 | ⬜ pending |
| 34-00-03 | 00 | 0 | all | — | fixture files exist | unit | `test -d tools/checks/fixtures/` | ❌ W0 | ⬜ pending |
| 34-01-01 | 01 | 1 | GUARD-04 | — | accent_lint_fr FAIL on bad diff | unit | `pytest tools/checks/tests/test_accent_lint.py` | ❌ W0 | ⬜ pending |
| 34-01-02 | 01 | 1 | GUARD-04 | — | accent_lint_fr PASS on good diff | unit | same | ❌ W0 | ⬜ pending |
| 34-01-03 | 01 | 1 | GUARD-04 | — | pattern set reconciled w/ CLAUDE.md §2 | static | `diff <(...) <(...)` | ❌ W0 | ⬜ pending |
| 34-02-01 | 02 | 2 | GUARD-02 | — | bare `catch (e) {}` FAIL | unit | `pytest tools/checks/tests/test_no_bare_catch.py::test_dart_bare` | ❌ W0 | ⬜ pending |
| 34-02-02 | 02 | 2 | GUARD-02 | — | `except Exception: pass` FAIL | unit | `::test_python_bare` | ❌ W0 | ⬜ pending |
| 34-02-03 | 02 | 2 | GUARD-02 | — | `test/` path exempt | unit | `::test_test_dir_exempt` | ❌ W0 | ⬜ pending |
| 34-02-04 | 02 | 2 | GUARD-02 | — | `async *` stream exempt | unit | `::test_async_star_exempt` | ❌ W0 | ⬜ pending |
| 34-02-05 | 02 | 2 | GUARD-02 | — | `// lefthook-allow:bare-catch:` override | unit | `::test_inline_allow` | ❌ W0 | ⬜ pending |
| 34-02-06 | 02 | 2 | GUARD-02 | — | **diff-only mode ignores existing bare-catches** | unit | `::test_diff_only_mode` | ❌ W0 | ⬜ pending |
| 34-03-01 | 03 | 3 | GUARD-03 | — | hardcoded FR string in widget FAIL | unit | `pytest ...test_no_hardcoded_fr.py::test_widget_text` | ❌ W0 | ⬜ pending |
| 34-03-02 | 03 | 3 | GUARD-03 | — | string in `lib/l10n/` exempt | unit | `::test_l10n_exempt` | ❌ W0 | ⬜ pending |
| 34-03-03 | 03 | 3 | GUARD-03 | — | string in `lib/models/` exempt | unit | `::test_models_exempt` | ❌ W0 | ⬜ pending |
| 34-03-04 | 03 | 3 | GUARD-03 | — | `AppLocalizations.of(context)!.key` PASS | unit | `::test_i18n_call_pass` | ❌ W0 | ⬜ pending |
| 34-03-05 | 03 | 3 | GUARD-03 | — | technical string whitelist (`['"][A-Z]{2,5}['"]`) PASS | unit | `::test_acronym_pass` | ❌ W0 | ⬜ pending |
| 34-04-01 | 04 | 3 | GUARD-05 | — | missing key in `de` FAIL | unit | `pytest ...test_arb_parity.py::test_missing_key` | ❌ W0 | ⬜ pending |
| 34-04-02 | 04 | 3 | GUARD-05 | — | extra key in `it` FAIL | unit | `::test_extra_key` | ❌ W0 | ⬜ pending |
| 34-04-03 | 04 | 3 | GUARD-05 | — | placeholder type mismatch FAIL | unit | `::test_placeholder_mismatch` | ❌ W0 | ⬜ pending |
| 34-04-04 | 04 | 3 | GUARD-05 | — | baseline 6707 keys × 6 langs PASS | integration | `python3 tools/checks/arb_parity.py` | ❌ W0 | ⬜ pending |
| 34-05-01 | 05 | 3 | GUARD-06 | — | agent commit missing `Read:` trailer FAIL | unit | `pytest ...test_proof_of_read.py::test_missing_trailer` | ❌ W0 | ⬜ pending |
| 34-05-02 | 05 | 3 | GUARD-06 | — | agent commit with valid trailer PASS | unit | `::test_valid_trailer` | ❌ W0 | ⬜ pending |
| 34-05-03 | 05 | 3 | GUARD-06 | — | human commit (no `Co-Authored-By: Claude`) bypass | unit | `::test_human_commit_bypass` | ❌ W0 | ⬜ pending |
| 34-05-04 | 05 | 3 | GUARD-06 | — | `Read:` references non-existent file FAIL | unit | `::test_stale_read_reference` | ❌ W0 | ⬜ pending |
| 34-06-01 | 06 | 4 | GUARD-07 | — | `.github/workflows/bypass-audit.yml` valid | static | `yamllint .github/workflows/bypass-audit.yml` | ❌ W0 | ⬜ pending |
| 34-06-02 | 06 | 4 | GUARD-07 | — | audit counts `LEFTHOOK_BYPASS` in commits 7d | integration | workflow dry-run | ❌ W0 | ⬜ pending |
| 34-06-03 | 06 | 4 | GUARD-07 | — | `CONTRIBUTING.md` documents LEFTHOOK_BYPASS | static | `grep LEFTHOOK_BYPASS CONTRIBUTING.md` | ❌ W0 | ⬜ pending |
| 34-07-01 | 07 | 4 | GUARD-08 | — | 9 CI job steps removed | static | `! grep 'no_chiffre_choc\|landing_no_' .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 34-07-02 | 07 | 4 | GUARD-08 | — | `lefthook-ci.yml` runs hooks on PR range | integration | workflow green on test PR | ❌ W0 | ⬜ pending |
| 34-07-03 | 07 | 4 | GUARD-08 | — | CI time delta measured vs pre-phase baseline | integration | compare Actions duration | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Coverage:** 28 automated test cases mapped to 8 GUARD requirements (min 2 per REQ). 0 criterion reliant on human eyeball.

---

## Wave 0 Requirements

- [ ] `lefthook.yml` schema fix — move `skip:` under `pre-commit:` block (blocker from research A7)
- [ ] `tools/checks/fixtures/` directory with 15 fixture files enumerated in RESEARCH.md §Wave 0:
  - `fixtures/bare_catch_bad.dart` (known-bad)
  - `fixtures/bare_catch_good.dart` (logged + rethrown)
  - `fixtures/bare_except_bad.py` + `bare_except_good.py`
  - `fixtures/async_star_exempt.dart`
  - `fixtures/hardcoded_fr_bad_widget.dart` + `hardcoded_fr_good_widget.dart`
  - `fixtures/accent_bad.dart` + `accent_good.dart`
  - `fixtures/arb_drift_missing/{fr,en,de,es,it,pt}.arb` (de missing key)
  - `fixtures/arb_drift_placeholder/{fr,en}.arb` (type mismatch)
  - `fixtures/commit_with_read_trailer.txt`
  - `fixtures/commit_without_read_trailer.txt`
  - `fixtures/commit_human_no_claude.txt`
- [ ] `tools/checks/tests/` directory with `__init__.py` + pytest files per lint
- [ ] `tools/checks/lefthook_benchmark.sh` — measure P95 <5s on 5 runs (baseline before adding lints)
- [ ] Dart regex test harness — pytest can run Python-lints-scanning-Dart-fixtures without needing `dart` binary

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bypass audit weekly cron actually fires on Monday 09:00 UTC | GUARD-07 D-21 | Scheduled workflow requires 7-day observation window post-merge | Verify next Monday's Actions tab, confirm job ran, inspect any issue auto-created |
| CI time reduction matches claim | GUARD-08 success #5 | Requires comparing 30d rolling median duration pre/post merge | After merge, let 5 PRs land, compare `gh pr list --json timelineItems` durations |
| `LEFTHOOK_BYPASS=1` commit surfaces in audit within 7 days | GUARD-07 success #4 | End-to-end requires a deliberate bypass commit then weekly cron | Make 1 test bypass commit, wait 7 days, inspect weekly audit issue |

*Rationale: these 3 are observation-window dependent (cron schedules + aggregate CI metrics) — not suitable for pre-merge automated gates. All other 28 criteria are automated and must be green before `/gsd-verify-work`.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify ✓ (pytest every task)
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags (all commands exit 0/1, no TUI)
- [ ] Feedback latency <30s ✓ (per-lint pytest runs <5s)
- [ ] `nyquist_compliant: true` set in frontmatter (pending Wave 0 completion)

**Approval:** pending (will flip to `approved YYYY-MM-DD` when gsd-verifier confirms all 28 automated criteria green + 3 manual deferred with justification)
