# Contributing to MINT

Short-form conventions for anyone (human or agent) editing this repo.
Complete playbook lives in `CLAUDE.md`, `docs/AGENTS/*.md`, and
`.claude/skills/*/SKILL.md`.

## 1. First-time setup

```bash
git clone git@github.com:<org>/MINT.git
cd MINT
brew install lefthook
lefthook install
```

`lefthook install` is mandatory on every fresh clone — it registers git
hooks in `.git/hooks/*` pointing at lefthook's goroutine runners. Without
it, `git commit` bypasses every local lint (CI still catches regressions
via `.github/workflows/lefthook-ci.yml` once Plan 34-07 lands, but the
local feedback loop is broken).

Verify: `lefthook check-install` exits 0 when hooks are registered.

## 2. Pre-commit hooks (lefthook)

MINT uses lefthook 2.1.5+ for pre-commit gates (<5s budget, parallel).
Every `git commit` triggers `lefthook run pre-commit`. The active lints
as of Phase 34:

| Lint | Requirement | Scope | Purpose |
|------|-------------|-------|---------|
| `memory-retention-gate` | CTX-01 | `memory/topics/*.md` | 30-day retention gate |
| `map-freshness-hint` | CTX-01 | `*.{dart,py}` | hint only, never fails |
| `accent-lint-fr` | GUARD-04 | `*.{dart,py,arb}` (excl. non-FR arbs) | 14 canonical FR accent patterns |
| `no-bare-catch` | GUARD-02 | `*.{dart,py}` diff-only | refuses added `catch (e) {}` / `except Exception: pass` without logging/rethrow |
| `no-hardcoded-fr` | GUARD-03 | `apps/mobile/lib/{widgets,screens,features}/**/*.dart` | refuses FR strings outside AppLocalizations |
| `arb-parity` | GUARD-05 | `app_*.arb` | 6-lang key + placeholder parity |
| `proof-of-read` | GUARD-06 | `commit-msg` hook | Claude commits must reference a READ.md |

See `lefthook.yml` and `tools/checks/*.py` for source.

## 3. Pre-commit hooks & bypass policy (GUARD-07)

**Never use `git commit --no-verify`.** It is banned by Phase 34 convention
(GUARD-07 D-20). `--no-verify` leaves NO trace in the commit object, which
defeats the entire guardrail discipline and makes post-hoc auditing
impossible.

### Legitimate bypass: `LEFTHOOK_BYPASS=1`

When a genuinely urgent hotfix must skip a lint that is a known
false-positive for that specific change, use the env-var form:

```bash
LEFTHOOK_BYPASS=1 git commit -m "hotfix: <subject>

[bypass: <three-word-reason-minimum>] Details here.

Co-Authored-By: <you>"
```

Two signals land on the commit:

1. `LEFTHOOK_BYPASS=1` is the runtime env var that tells lefthook to skip
   its hooks. This signal is ephemeral (env vars vanish at process exit),
   so operators SHOULD also add...
2. `[bypass: <reason>]` in the commit message body — a voluntary marker
   that IS persisted in git history and grep-able by the weekly audit
   (Plan 34-06 D-21). The reason must be at least three words so the
   audit issue gives the reviewer enough context for manual triage.

### Weekly audit: `.github/workflows/bypass-audit.yml`

The workflow at `.github/workflows/bypass-audit.yml` (D-21) runs on two
triggers:

- **Schedule**: every Monday at 09:00 UTC
- **Push**: after every merge to `dev`

It greps commit bodies on `dev` for `LEFTHOOK_BYPASS` or `[bypass:`
markers over the previous 7 days. If the count exceeds **3** (D-22
threshold), it auto-creates a GitHub issue labelled `bypass-audit`
summarising the week so a maintainer can triage.

This audit is a **secondary awareness tool**. The primary ground-truth
catcher for bypass-induced regressions is
`.github/workflows/lefthook-ci.yml` (Plan 34-07, D-24), which re-runs
all lints on every PR. If a `LEFTHOOK_BYPASS` commit introduced a real
regression, lefthook-ci fails the PR loudly; the weekly audit only
flags usage patterns.

### Inline per-lint override (preferred over `LEFTHOOK_BYPASS`)

Most lints accept a per-line allow comment on the preceding line
(`// lefthook-allow:<lint>:<reason>` in Dart,
`# lefthook-allow:<lint>:<reason>` in Python). Examples:

```dart
// lefthook-allow:bare-catch: legitimate debug-only fallback path
try { x(); } catch (e) {}
```

```dart
// lefthook-allow:hardcoded-fr: error code shown only in debug builds
Text('ERR-404');
```

The reason must be at least three whitespace-separated words. Prefer
the inline override to `LEFTHOOK_BYPASS` whenever the false-positive is
localised to one line — it preserves every other lint check on the same
commit and leaves a durable, grep-able audit trail right next to the
exempted code.

### Known bypass vectors (banned by convention — detected retroactively)

Lefthook itself exposes several other env vars and flags that silently
disable hooks without leaving a signal in the commit body. **All are
banned by MINT convention — every one of them is a PR-blocking offence
and must never appear in a commit sequence, scripts, or CI config.**

Phase 34.1 audit (`.planning/phases/34-agent-guardrails-m-caniques/audits/01-ADVERSARIAL.md`)
inventoried the following vectors:

| Vector | Effect | Detection |
|--------|--------|-----------|
| `git commit --no-verify` / `-n` | Git skips ALL hooks | `lefthook-ci.yml` re-runs hooks on PR — catches the regression effect, not the bypass itself |
| `LEFTHOOK=0 git commit` | Undocumented lefthook kill-switch | `bypass-audit.yml` grep (extended in Phase 34.1 Fix #2) |
| `LEFTHOOK_EXCLUDE=<name>` | Targeted skip of one or more hooks | `bypass-audit.yml` grep (extended) |
| `LEFTHOOK_RUN_ONLY=<name>` | Runs only named hooks, silently skips the rest | `bypass-audit.yml` grep (extended) |
| `git -c core.hooksPath=/dev/null commit` | Per-invocation git flag defeats all hooks | `bypass-audit.yml` grep (extended) |
| `git rebase -i` with `squash` / `fixup` | Resulting commit NEVER fires `commit-msg` hook | `lefthook-ci.yml` invokes `proof_of_read.py` per commit in PR range — catches missing `Read:` trailers |
| `git cherry-pick <sha>` | Original message propagates; `commit-msg` hook does not re-fire against the new phase context | `lefthook-ci.yml` per-commit scan |
| Deleting `.git/hooks/commit-msg` manually | Local silent bypass of Claude proof-of-read | `lefthook-ci.yml` re-runs on PR — authoritative ground truth |

**Ground-truth authority**: `.github/workflows/lefthook-ci.yml`
re-runs every lint on every commit in a PR range. It is the primary
detector for the EFFECT of any bypass listed above (a regression
would fail the CI job regardless of how the bypass was performed).
`.github/workflows/bypass-audit.yml` is a secondary awareness tool
that flags voluntary signal patterns — use it to identify contributors
who are reaching for bypasses too often, not as your main security
gate.

**Operator discipline**: if you find yourself typing any of the
commands in the table above, stop and either (a) fix the underlying
problem so the lint passes cleanly, (b) add an inline `lefthook-allow`
override with a real reason, or (c) escalate to the maintainer. There
is no fourth path.

## 4. Agent commits (proof-of-read — GUARD-06)

Commits carrying `Co-Authored-By: Claude` MUST include a `Read:` trailer
pointing to a `.planning/phases/<phase>/<padded>-READ.md` file that lists
the files the agent actually consulted (one `- <path> — <why>` bullet
per file, per D-18). The commit-msg hook
(`tools/checks/proof_of_read.py`) enforces this. Human commits (no
Claude trailer) bypass automatically. `Read:` paths MUST start with
`.planning/phases/` (T-34-SPOOF-01 mitigation).

Example trailer block:

```
Read: .planning/phases/34-agent-guardrails-m-caniques/34-06-READ.md
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## 5. Benchmark

If pre-commit feels slow, run:

```bash
bash tools/checks/lefthook_benchmark.sh
```

Target: P95 <5s over 10 iterations (2 warmup discarded). Current P95 is
roughly 0.090s on M-series Mac with the 5 active pre-commit commands +
1 commit-msg command (Plan 34-05 measurement). If P95 regresses, open
an issue; the benchmark is also run weekly in CI as a regression guard.

## 6. CI split (Phase 34 GUARD-08, Plan 34-07 pending)

Fast grep-style gates run locally via lefthook. CI retains the heavy
jobs: `flutter test` suite, `pytest`, `flutter analyze`, `dart format`,
WCAG audit, PII scanner, OpenAPI contracts, Alembic migrations. See
`.github/workflows/ci.yml`.

An additional CI job `.github/workflows/lefthook-ci.yml` (lands with
Plan 34-07) re-runs `lefthook run pre-commit --all-files --force` on
every PR — this is the ground-truth audit that detects any local bypass
that introduced a regression (complementary to the weekly bypass count
audit described in section 3).
