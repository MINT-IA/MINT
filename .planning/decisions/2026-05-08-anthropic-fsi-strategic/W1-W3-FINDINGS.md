---
name: W1 + W3 whitecoding findings
description: Audit results for W1 (Progressive Disclosure on .claude/skills/) and W3 (autoresearch-i18n wiring path). MINT-owned skills are already compliant; W3 needs a different shape than « pre-commit hook ».
type: reference
date: 2026-05-08
parent: .planning/decisions/2026-05-08-anthropic-fsi-strategic/SYNTHESIS.md
status: Done (W1) / Refined (W3)
---

# W1 + W3 whitecoding findings

## W1 — Progressive Disclosure audit on `.claude/skills/`

### Method

For each `.claude/skills/*/SKILL.md` (87 skills), measured `description:` length in characters and body lines after frontmatter. Anthropic FSI doctrine : description ≤ 300 chars (loaded by default in agent's context match), body lazy-loaded only on trigger.

### Result

**MINT-owned skills (10) are 100 % compliant** :
- `mint-audit-complet` 246 chars / 486 lines
- `mint-backend-dev` 250 / 151
- `mint-commit` 198 / 156
- `mint-flutter-dev` 228 / 153
- `mint-office-hours` 168 / 206
- `mint-phase-audit` 232 / 256
- `mint-retro` 160 / 159
- `mint-review-pr` 179 / 207
- `mint-swiss-compliance` 264 / 112
- `mint-test-suite` 207 / 128

**Autoresearch-* skills (11) are 100 % compliant** : 170-266 chars description, 176-376 lines body.

**gstack third-party skills (66) have severe bloat** :
- `brainstorming` : **10 560 chars** (worst offender)
- `gsd-reapply-patches` : 9 953
- `systematic-debugging` : 9 815
- `subagent-driven-development` : 7 230
- `using-superpowers` : 5 363
- `using-git-worktrees` : 4 359
- `verification-before-completion` : 4 094
- `writing-skills` : 4 029
- `dispatching-parallel-agents` : 3 816
- `gsd-research-phase` : 3 213
- `writing-plans` : 3 301
- `gsd-thread` : 3 013
- `gsd-discuss-phase` : 3 131
- `test-driven-development` : 2 735
- (plus 17 others between 1 000 and 2 500 chars)

### Verdict

MINT skills already follow Progressive Disclosure. **No MINT action required.**

The 32 bloated gstack skills inflate every conversation's context window (each description loaded by default). Action option :
- **Out-of-scope here** — gstack maintainer to address.
- **MINT-side mitigation if needed** : disable unused gstack skills via `~/.claude/settings.json` (`disabled_skills` list), keeping only those Julien actually uses.

## W3 — `autoresearch-i18n` wiring : refined

### Original strategic wiki phrasing
« Wire `autoresearch-i18n` in lefthook pre-commit hook or autonomous loop. »

### Refinement after read

`autoresearch-i18n` ([apps/.claude/skills/autoresearch-i18n/SKILL.md:5](.claude/skills/autoresearch-i18n/SKILL.md)) is a Karpathy-style **fix loop** : « finds hardcoded strings → extracts to 6 ARB files → verifies with gen-l10n + tests → repeats ». It modifies code. Wiring it as a pre-commit hook would either :
- block every commit on a multi-iteration fix loop (bad UX)
- or run silently and corrupt the user's working tree

Both are wrong. The right shape :

| Wire | UX | Effort |
|---|---|---|
| **Pre-commit blocking lint** (detect-only, no fix) | Add `no_hardcoded_fr.py` + `accent_lint_fr.py` to [lefthook.yml](lefthook.yml) (both scripts already exist in [tools/checks/](tools/checks/), per CLAUDE.md §4 should be active but aren't) | **5 min** |
| **Autonomous nightly loop** (fix + open PR) | CronCreate-scheduled `autoresearch-i18n 40` running 03:00 UTC, opens auto-PR if violations found | **~30 min** |
| **Manual on-demand** | `make i18n-fix` shortcut wrapping the skill | **5 min** |

### Recommendation

**DO 1 & 3 in MINT scope, DEFER 2** :

1. ✅ **Activate `accent_lint_fr.py` + `no_hardcoded_fr.py` in lefthook.yml** as HARD pre-commit gates per CLAUDE.md §4 (which already documents them as active but the config shows them missing — gap between doc and reality). Detect-only, blocking.

2. ⏸ **Autonomous nightly loop** — useful but :
   - Needs a strategy for handling auto-PRs (Julien's review burden vs auto-merge risk).
   - Needs a triage policy when multiple offenders pile up.
   - Defer to Phase 2.

3. ✅ **`make i18n-fix` shortcut** — trivial, document only the existing skill invocation.

### Action items

| Item | Owner | Effort |
|---|---|---|
| Add `accent_lint_fr.py` + `no_hardcoded_fr.py` to lefthook.yml (HARD) | next dev session | 5 min |
| Verify lint scripts run cleanly on current `dev` HEAD before activation (else gate the activation behind a fix-PR) | next dev session | 10 min |
| Document `make i18n-fix` in `apps/mobile/Makefile` or `tools/scripts/` | next dev session | 5 min |
| Defer autonomous nightly loop to Phase 2 + spawn the GH Actions workflow when M2 model routing is shipped | Phase 2 | 30 min |

## Counter-arguments and data gaps

- **W1 « MINT skills are compliant »** is a claim about description length, not description **quality**. A 200-char description can still be vague, irrelevant, or misleading to the agent's match logic. A deeper audit would test : « does the description trigger the right skill on a sample of representative user prompts ? » Out of scope here, valid follow-up.
- **W3 activation of HARD lints might break current commits** if the codebase has accumulated violations. Need to run the lints on current HEAD first to know the baseline cost. If 100+ violations exist, activation needs a fix-PR before flipping the gate.
- **gstack bloat impact** is unmeasured. Each description loaded by default — but the agent might still be efficient in matching, or the bloat might inflate every API call by 20-40 KB. Without telemetry, hard to quantify the actual cost. Worth measuring with a tokenizer pass before raising the issue with gstack.
- **Data missing** : MINT internal benchmarks on token cost per skill load. Without that, « Progressive Disclosure ROI » is theoretical.
