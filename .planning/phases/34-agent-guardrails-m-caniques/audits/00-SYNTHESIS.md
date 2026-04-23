# Phase 34 — Deep Audit Synthesis

**Date:** 2026-04-23
**Auditor:** 5 parallel specialist agents (adversarial, codebase impact, git lifecycle, CI workflows, regex robustness)
**Scope:** Phase 34 shipped state — 5 lints + 2 CI workflows + commit-msg hook + bypass policy
**Method:** Empirical — every finding backed by reproducible test case on this machine

---

## TL;DR — 30 seconds

Phase 34 ships **plumbing that works on happy paths** (62 pytest green, self-test 6 sections green, lefthook valide, commit-msg hook auto-validates its own commits). But **the adversarial attack surface is Swiss cheese**: 30+ P0 findings across 5 dimensions. An agent or developer who reads lefthook docs escapes every gate in under 30 seconds with zero trace.

**What Phase 34 actually delivers today:**
- ✅ Protects against **honest mistakes** (developer forgets to run i18n, commits hardcoded FR, etc.)
- ✅ Catches **1 class of regression per lint on the happy path**
- ✅ Self-hosting is real: lefthook + proof-of-read ran on Phase 34's own commits

**What Phase 34 does NOT deliver:**
- ❌ Protection against **hostile agents/developers** (LEFTHOOK=0, rebase, cherry-pick all bypass)
- ❌ "All-green" gate for existing code (accent lint has 64–100% FP rate on production stems)
- ❌ CI-side enforcement (`lefthook-ci.yml` will FAIL on first PR due to invalid commands)
- ❌ Meaningful proof-of-read (accepts junk paths, stale phase refs, path traversal)

**Recommendation:** Don't block PR merges on `lefthook-ci.yml` until Phase 34.1 hardening pass (~1 day of work). Phase 34 as-is catches honest mistakes — merge it and plan 34.1.

---

## Severity matrix (aggregate across 5 audits)

| Dimension | P0 | P1 | P2 | Ship impact |
|-----------|----|----|----|-------------|
| Bypass convention | 5 | 3 | 1 | High — any user reading lefthook docs escapes |
| Regex completeness | 15 | 4 | 3 | High — common bare-catch forms miss |
| proof_of_read auth | 5 | 2 | 2 | Critical — essentially cosmetic |
| CI workflow correctness | 1 | 5 | 4 | High — first PR likely breaks branch protection |
| Git lifecycle holes | 7 | 3 | 5 | Medium — rebase/cherry-pick skip hooks |
| Perf claim reality | 0 | 2 | 3 | Medium — P95 is 28× higher than claimed |
| Scope claim accuracy | 0 | 1 | 2 | Low — FIX-06 debt is 27× worse than advertised |
| **TOTAL** | **33** | **20** | **20** | 73 findings |

---

## The Swiss-Cheese Problem (critical context)

Phase 34's theory of protection: commit passes through **5 pre-commit lints + 1 commit-msg hook + 1 weekly audit + 1 CI re-run** = 7 layers. Finding: **every layer leaks independently**:

| Bypass vector | Documented? | Catches in bypass-audit? | Catches in lefthook-ci? |
|---------------|-------------|--------------------------|--------------------------|
| `git commit --no-verify` | Banned in CONTRIBUTING | ❌ (no commit-body trace) | ✅ (if workflow runs) |
| `LEFTHOOK_BYPASS=1` | Documented as bypass | ✅ (grep) | ✅ |
| `LEFTHOOK=0 git commit` | ❌ not documented | ❌ regex is `LEFTHOOK_BYPASS`, not `LEFTHOOK` | ✅ |
| `LEFTHOOK_EXCLUDE=<name>` | ❌ not documented | ❌ | ✅ |
| `LEFTHOOK_RUN_ONLY=<name>` | ❌ not documented | ❌ | ✅ |
| `git -c core.hooksPath=/dev/null commit` | ❌ not documented | ❌ | ✅ |
| `git rebase -i squash/fixup` | `skip: [rebase]` in pre-commit | ❌ | **❌ (commit-msg skipped too)** |
| `git cherry-pick` | ❌ | ❌ | **❌ (commit-msg not re-fired)** |
| Delete `.git/hooks/commit-msg` manually | ❌ | ❌ | ✅ |

**But lefthook-ci.yml itself has P0 bugs** (see below) — it will fail on first PR, meaning the right-hand column is likely empty too.

**Net result:** a sufficiently motivated agent can ship hardcoded-FR + bare-catch + missing Read: to `dev` with zero lint firing locally or on CI.

---

## Domain-by-domain findings

### 1. Regex completeness — GUARD-02 / GUARD-03 / GUARD-04

**GUARD-02 no_bare_catch.py — 6 Dart P0s + 6 Python P0s empirically reproduced:**

Dart bypasses (all create `/tmp/evasion_*.dart`, stage, run lint, rc=0):
- `catch (ex) {}` — name not in `{e|_|err|error}`
- `catch (exception) {}` — same
- `catch (e, stack) {}` — two-arg catch ignored
- `on FormatException catch (e) {}` — typed catch syntax
- `catch (e) { /* comment only */ }` — comment body treated as content
- `catch (e) { null; }` / `catch (e) { return; }` — statement body without log

Python bypasses:
- **`try: x()\nexcept: pass`** — the canonical Python bare-except, `$` anchor forbids same-line content
- `except (ValueError, TypeError):` tuple catch
- `except Exception as e: pass` one-liner
- `except BaseException:` (catches SystemExit — more dangerous than bare)
- `except Exception:\n    ...` ellipsis body
- Comment-only body `except:\n  # TODO: log\n  pass`

**Fix cost:** ~30 min per language — widen regex to any single-identifier binding, multi-line aware, strip comments before check.

**GUARD-03 no_hardcoded_fr.py — 2 P0 bypasses:**
- `Text('BONJOUR')` — all-caps whitelist matches `['"][A-Z]{2,5}['"]`
- `Text('Oui')` — tail < 5 chars so `[A-Z][a-z]+.{5,}` misses

Plus ReDoS: `_TEXT_CAPITALISED` regex quadratic on unterminated `Text('A…` 50 KB input → 10.7 s hang. Shouldn't happen in practice (files aren't that large) but worth a pattern tightening.

**GUARD-04 accent_lint_fr — false-positive catastrophe:**
- Full production scan: **~1200 hits, 64–100% false-positive rate**
- `prevoyance` stem: 1011 matches, ~643 are code identifiers (`profile.prevoyance.avoirLppTotal`) — 64% FP
- `regler` stem: 86% FP — matches German `Regler` (= "slider")
- `liberer`, `preter`, `realiser`, `reperer`: 100% FP — only match test fixtures
- Unicode bypasses: fullwidth `ｃｒｅｅｒ`, Cyrillic `сrееr`, zero-width-space `c\u200Breer` all pass

**GUARD-05 arb_parity — 1 P0 + 1 P1:**
- Order drift `{name} {age}` vs `{age} {name}` passes (order-insensitive set compare)
- ICU walker misses placeholder names inside plural/select variant bodies: `{count, plural, one {{foo}} other {{bar}}}` emits only `count`

### 2. proof_of_read.py — the weakest of the 5

| Attack | Result |
|--------|--------|
| `Read: .planning/phases/30.5-context-sanity/30.5-CONTEXT.md` in Phase 34 commit | ✅ PASSES (no phase-match check) |
| `Read: .planning/phases/fake/junk.md` pointing to a file with one bullet | ✅ PASSES (no content validation) |
| `Read:` on commit subject line (not trailer) | ✅ PASSES (MULTILINE regex) |
| Multiple `Read:` trailers, first valid + others junk | ✅ PASSES (first-match) |
| `Read: .planning/phases/../../etc/passwd` | ✅ PASSES (T-34-SPOOF-01 not enforced — .. traversal allowed inside prefix) |
| Symlink `.planning/phases/fake.md → /etc/passwd` | ✅ PASSES (no readlink + prefix recheck) |
| `Co-authored-by: Claude` (Git-canonical lowercase) | ❌ treated as HUMAN commit → entire doctrine bypassed |
| `IsADirectoryError` when `Read:` points to a dir | 💥 Python crash |

**Fix cost:** ~2 hours. Add: phase-match check (current phase's READ.md only), path canonicalisation + re-prefix-check after resolve, case-insensitive `Co-Authored-By` match, bullet-format validator.

### 3. CI workflows — lefthook-ci.yml will FAIL on first PR

**P0 (supply chain + instability):** `curl | sh` installs lefthook from `master` (unpinned). Local min_version `2.1.5` vs CI = bleeding edge.

**P1 (workflow correctness):**
- `lefthook validate` is **not a valid subcommand** in lefthook 2.x. Upstream offers: `run / install / uninstall / add / dump / version`.
- `lefthook run commit-msg --file /tmp/msg.txt` — `--file` is **not a valid flag**. commit-msg expects positional `{1}` (our own lefthook.yml line 162 uses this convention).
- No `timeout-minutes:` — known iCloud stall > 5 min during Phase 34-07 execution (Deviation #1).
- `bypass-audit.yml` 7-day window drifts based on trigger (cron stable UTC, push arbitrary). Multi-day comment spam risk.
- `count=''` silent failure when `git log` errors (`|| true` masks both fetch + grep failures).

**P2:** GitHub-script template-literal injection via unquoted `${{ triage }}`.

**Net:** do NOT make lefthook-ci.yml a required check in branch protection. It will fail every PR.

### 4. Perf claim reality

- Phase 34-07 SUMMARY claims P95 = 0.110s. That's **empty-stage synthetic** benchmark.
- Realistic load (50 Dart + 20 Python staged): **P95 = 3.1s** — 28× higher, still < 5s budget.
- `no-chiffre-choc` alone: **50.6s** on any commit touching `.py|.dart|.arb` (measured by lifecycle auditor). This ALONE blows the 5s budget.
- Root cause: shell-loop + Python startup per-file. Needs diff-only mode (like GUARD-02).

### 5. Git lifecycle holes

**Silent bypasses** (verified on scratch branch):
- `git rebase -i` with `squash` or `fixup` → commit-msg hook never fires on resulting commit
- `git cherry-pick` → commit-msg never re-fires (original msg carries through unvalidated against new phase context)
- `git revert` → auto-generated message with no Read: trailer + Claude co-author from reverted commit → blocks the revert
- Pre-Phase-34 worktree / older branch checkout → `lefthook.yml` doesn't have commit-msg block → lefthook logs "skip: Hook commit-msg doesn't exist in the config" and commit lands unvalidated
- GitHub squash-merge → depends entirely on lefthook-ci.yml (which is broken — see #3)

### 6. Scope claims — reality check

- FIX-06 i18n migration claim: **~120 strings** in services/models.
- Actual scan of the same scope (with the new no_hardcoded_fr patterns): **3,469 strings**.
- That's **27× the estimate** → Phase 36 FIX-06 budget is structurally wrong. Needs re-sizing or descoping.

Plus: accent_lint_fr claimed 899 mobile violations for FIX-07. Full scan also hits **357 backend violations** unaccounted in that claim.

### 7. Non-obvious integration gaps

- iCloud duplicate files (`* 2.py`, etc.) — **confirmed 0 references from lefthook or lints, 0 commits since Phase 30.5**. Safe. (We removed 423 during this session as part of hygiene.)
- Memory-retention-gate gate fires correctly — HARD pass on old files, SOFT warning on MEMORY.md line count by design (D-02).
- 30.5 skeleton preserved through 34-00 schema migration ✓

---

## What to do now — 3 tiers

### Tier A — Ship Phase 34 as-is (recommended)

Phase 34 merges. The happy-path protection IS real — it catches honest mistakes, and that's most of the daily risk. The adversarial surface is known tech debt.

**Before merge:**
1. Don't add `lefthook-ci.yml` to branch protection yet (it'll fail)
2. Document known bypasses in CONTRIBUTING.md as "not currently enforced — Phase 34.1 scope"
3. Add `lefthook-ci.yml` as an **optional check** that gets tuned once Phase 34.1 fixes the invalid commands

### Tier B — Phase 34.1 hardening pass (~1 day)

Fix the Tier-1 P0s:
1. `proof_of_read.py`: phase-match + canonicalisation + case-insensitive + bullet validator (2h)
2. `no_bare_catch.py`: widen Dart/Python regex + on-catch syntax + multi-line (30 min each)
3. `lefthook-ci.yml`: replace `lefthook validate` with real subcommand; fix `--file` flag; pin lefthook version; add timeout (1h)
4. `bypass-audit.yml`: regex = `LEFTHOOK_BYPASS|LEFTHOOK=0|LEFTHOOK_EXCLUDE|LEFTHOOK_RUN_ONLY|core\.hooksPath|--no-verify` (15 min)
5. CONTRIBUTING.md: document every bypass vector + threat model (30 min)
6. `post-rewrite` hook to catch amend/rebase (30 min)

### Tier C — Phase 34.2 polish (~2 days, later)

Not blocking:
- `no_hardcoded_fr.py`: fix `Text('Oui')` whitelist + ReDoS pattern tightening
- `accent_lint_fr.py`: context-aware (skip code identifiers, handle conjugations, Unicode normalization)
- `no-chiffre-choc`: diff-only migration (fixes 50.6s → sub-second)
- `arb_parity.py`: ordered placeholder + plural/select variant parsing
- ReDoS fixtures in pytest

---

## Appendix: all audit files

| File | Lines | Focus |
|------|-------|-------|
| `01-ADVERSARIAL.md` | 312 | Bypass attempts + regex evasion |
| `02-CODEBASE-IMPACT.md` | 356 | Lints on real production code + diff-only verification |
| `03-GIT-LIFECYCLE.md` | 253 | amend/rebase/cherry-pick/merge edge cases |
| `04-CI-WORKFLOWS.md` | 243 | bypass-audit.yml + lefthook-ci.yml correctness |
| `05-REGEX-ROBUSTNESS.md` | 436 | Unicode, ReDoS, false-positives per stem |

All findings empirically reproduced — test fixtures preserved at `/tmp/audit_*/` (regenerable).

---

*Synthesized 2026-04-23 from 5 parallel audits, 1600 lines of findings.*
