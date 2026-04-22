# Phase 34: Agent Guardrails mécaniques - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-04-22
**Phase:** 34-agent-guardrails-m-caniques
**Mode:** discuss --auto (Claude picked recommended defaults from REQUIREMENTS.md + ROADMAP)
**Areas analyzed:** Lefthook structure, GUARD-02 bare-catch, GUARD-03 hardcoded-FR, GUARD-04 accents, GUARD-05 ARB parity, GUARD-06 proof-of-read, GUARD-07 bypass convention, GUARD-08 CI thinning, Test strategy

## Auto-resolved decisions

Every decision marked "recommended default" per the following rationale hierarchy:
1. **Prescriptive requirements** — REQUIREMENTS.md GUARD-01..08 already lock most answers (5 success criteria in ROADMAP + 8 REQs = 26 decisions).
2. **Codebase evidence** — existing `lefthook.yml` skeleton, `accent_lint_fr.py`, `memory_retention.py` patterns, CLAUDE.md §2 14 accent patterns.
3. **Prior phase decisions** — Phase 30.5 D-04 scoped lefthook skeleton to MEMORY gate only, Phase 34 completes on the rails.
4. **Kill-policy ADR** — 1 outil = lefthook, pas de multi-hook-tool.

## Areas presented (no user interaction — --auto mode)

### Area 1: Lefthook structure (GUARD-01)
| Option | Rationale | Selected |
|--------|-----------|----------|
| Single `lefthook.yml` with tag-grouped sections | Preserves 30.5 skeleton; `parallel: true` now enabled (30.5 D-04 scope released) | ✓ |
| Split into `lefthook.yml` + `lefthook-local.yml` | Adds template, not needed yet | |
| Multi-file `.lefthook/*.yml` | Lefthook supports includes but we have 7 commands — over-engineered | |

**Decisions locked:** D-01 (single file), D-02 (parallel: true, <5s budget), D-03 (changed-files glob), D-04 (brew install, min_version 2.1.5)

### Area 2: GUARD-02 bare-catch strategy
| Option | Rationale | Selected |
|--------|-----------|----------|
| Regex-first + diff-only + opt-in override | Ships fast, decouples from FIX-05 migration | ✓ |
| AST-based (tree-sitter) | Requires dep, slows hooks, overkill for bare-catch | |
| Grandfathered via allowlist file | Moving target, not maintainable | |

**Decisions locked:** D-05 (regex patterns), D-06 (exceptions), D-07 (diff-only mode = decouple from FIX-05)

### Area 3: GUARD-03 i18n lint scope
| Option | Rationale | Selected |
|--------|-----------|----------|
| `lib/widgets/` + `lib/screens/` + `lib/features/` only | Matches REQ GUARD-03 "widgets Dart hors `lib/l10n/`"; services D4 = Phase 36 FIX-06 | ✓ |
| Full `lib/` including services | Scope creep — 120 service strings out of phase | |
| Only `lib/widgets/` | Too restrictive — screens also have hardcoded strings | |

**Decisions locked:** D-08 (scope), D-09 (FR patterns + whitelist), D-10 (inline override)

### Area 4: GUARD-04 accents lint
| Option | Rationale | Selected |
|--------|-----------|----------|
| Reuse existing `accent_lint_fr.py`, activate for .dart/.py/.arb | Lint already shipped Phase 30.5 for CTX-02 drift | ✓ |
| Rewrite with new patterns | No evidence current patterns insufficient | |
| Add to other ARB files (en, de, etc.) | Non-FR ARBs don't need accent enforcement | |

**Decisions locked:** D-11 (reuse), D-12 (scope .dart/.py/app_fr.arb, no override — decree)

### Area 5: GUARD-05 ARB parity definition
| Option | Rationale | Selected |
|--------|-----------|----------|
| Strict: missing OR extra OR placeholder-mismatch = fail | Highest rigor, unambiguous failure signal | ✓ |
| Warn on placeholder drift, fail on key drift | Weaker — placeholder mismatch causes runtime crashes | |
| Fail missing only, ignore extra | Extra keys pollute bundle, should fail | |

**Decisions locked:** D-13 (strict 3-way drift), D-14 (JSON-based, no ICU dep), D-15 (grandfathering: cross-language parity only, not Dart-side orphans)

### Area 6: GUARD-06 proof-of-read convention
| Option | Rationale | Selected |
|--------|-----------|----------|
| Commit trailer `Read: .planning/.../READ.md` + existing `Co-Authored-By: Claude` detection | Fallback léger explicite, no AST/SDK dep | ✓ |
| Full AST PreToolUse hook via Claude Agent SDK | DIFF-04, deferred Phase 36 — hors scope | |
| File-path grep in commit body | Fragile, many false positives | |

**Decisions locked:** D-16 (trailer format), D-17 (script checks trailer + file exists), D-18 (READ.md format: bullets + rationale), D-19 (DIFF-04 deferred)

### Area 7: GUARD-07 bypass convention
| Option | Rationale | Selected |
|--------|-----------|----------|
| `LEFTHOOK_BYPASS=1` env var + weekly CI audit + GitHub issue if >3/week | Grep-able, documented in CONTRIBUTING.md | ✓ |
| Disable `--no-verify` technically | Impossible — git owns that flag | |
| Slack alert instead of issue | No Slack integration in this repo | |

**Decisions locked:** D-20 (convention), D-21 (weekly audit workflow), D-22 (3/week threshold)

### Area 8: GUARD-08 CI thinning map
| Option | Rationale | Selected |
|--------|-----------|----------|
| Exhaustive migration map (10 checks named), heavies stay, single `lefthook-ci` job catches bypass | Matches REQ "10 grep-style gates migrent vers lefthook-first" | ✓ |
| Keep CI as-is, add lefthook on top | Violates success_criteria #5 (-2min CI time) | |
| Move everything to lefthook, no CI gates | Dangerous — bypass would ship anything | |

**Decisions locked:** D-23 (migration map), D-24 (single CI job as bypass catcher)

### Area 9: Test strategy
| Option | Rationale | Selected |
|--------|-----------|----------|
| Self-test + benchmark, both scriptable | Validates lints + enforces <5s budget continuously | ✓ |
| Manual testing only | Regression-prone, success_criteria #1 has numeric threshold | |
| CI-only self-test | Slower feedback loop, misses local-dev drift | |

**Decisions locked:** D-25 (extend existing `lefthook_self_test.sh`), D-26 (new `lefthook_benchmark.sh`, P95 <5s)

## Scope creep redirected

- None. ROADMAP Phase 34 + REQUIREMENTS GUARD-01..08 are tightly scoped. All "bigger" ideas (FIX-05, FIX-06, FIX-07, DIFF-04, dead ARB cleanup, hook expansion) already have explicit phases/deferrals.

## Deferred Ideas

See `<deferred>` section of CONTEXT.md — all are already in REQUIREMENTS.md as future phase requirements (Phase 36 FIX-*, v2.9 backlog).

## Claude's Discretion

- Internal code style of 4 new Python lints (argparse, logging, error format) — Claude can match `memory_retention.py` idiom.
- Lefthook tag names (`[safety]`, `[i18n]`, etc.) — readability preference.
- Self-test fixture naming.
- Bypass-audit GitHub issue template.
