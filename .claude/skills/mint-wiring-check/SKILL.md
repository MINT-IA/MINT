---
name: mint-wiring-check
description: On-demand 4-level wiring check for Dart/Python files newly created or modified. Use after a Claude Code sub-agent (or any coding agent) finishes a task to verify the code is actually CÂBLÉ — not facade. Catches the W14-incident pattern (file exists, tests pass, but no real consumer imports it). Cheap counter-attack against "code de surface" before W2 mint-wiring-verifier full agent (backlog 999.3). Invoke with /mint-wiring-check <file-paths> or --staged or --since-commit <sha>.
metadata:
  author: mint-team
  version: "0.1.0"
  related:
    - .planning/audit/codebase-audit-2026-05-10/anthropic-financial-services-agents.md
    - CLAUDE.md §9 0-Trust Protocol
---

# MINT Wiring Check

## Role

You are a mechanical wiring verifier. You do NOT decide if code is "good" or
"clean". You decide one thing: is this newly-written code WIRED to a real
consumer, or is it a façade?

Your output is deterministic: every claim must cite a file path or a grep
result, and the final verdict is exit 0 (câblé) or exit 1 (façade).

## When to use

After any Claude Code session that produced new Dart or Python files,
especially when:

- a sub-agent (Explore, Task, gsd-executor, etc.) finished a coding task
- a `gh pr create` is about to be opened
- Julien wants to verify that "tests green" actually means "feature wired"
- before any claim of « shipped », « ready », « works », « validated »
  (CLAUDE.md §9 0-Trust banned phrases)

## What it does — the 4 levels

For each modified file, the check runs:

| Level | Question | Mechanism | Pass criterion |
|-------|----------|-----------|----------------|
| **N1** | File exists ? | `Path.exists()` | file is on disk |
| **N2** | Pas de stub / TODO / NotImplementedError ? | regex scan | no forbidden patterns in the file |
| **N3** | Public symbol importé / appelé chez ≥1 consommateur ? | recursive grep | ≥1 hit in another file in the repo |
| **N4** | Si Flutter screen/widget : trace dans `idb ui describe-all` ? | sim snapshot (optional) | sim text mentions the widget name |

N4 requires a running iOS simulator with `idb` available. v0.1 SKIPS N4 by
default — pass `--check-sim` to attempt it. If sim isn't running, N4 reports
`not-attempted` (NOT failed).

## Invocation

```bash
# Mode A — explicit file list
python3 tools/checks/wiring_check.py --files apps/mobile/lib/widgets/foo.dart services/backend/app/services/bar.py

# Mode B — staged files (use after `git add`, before `git commit`)
python3 tools/checks/wiring_check.py --staged

# Mode C — since-commit (replay over recent diff)
python3 tools/checks/wiring_check.py --since-commit HEAD~5

# Optional flags
--check-sim       # also attempt N4 sim describe-all (default: skip)
--strict          # also fail on N2 warnings (TODO without owner tag)
--allow-tests     # exempt test files from N3 (default: tests are exempt automatically)
```

## Output contract

For each file, prints one block:

```
[file path]
  N1 file exists           : PASS
  N2 no stub/TODO/NotImpl  : PASS  (or FAIL with line number)
  N3 imported by consumer  : PASS  (or FAIL — symbol "Foo" found 0× outside this file)
  N4 sim describe-all hit  : not-attempted  (or PASS / FAIL if --check-sim)
```

Final summary:

```
SUMMARY: 5 files checked — 4 PASS, 1 FAIL (façade)
```

Exit codes:
- `0` — all files pass N1+N2+N3 (N4 ignored unless `--check-sim`)
- `1` — at least one file fails N1, N2, or N3
- `2` — usage error (missing args, no files matched)

## What this is NOT

- Not a code reviewer — it doesn't judge style, perf, security
- Not a runtime gate — only invoked on demand, not in lefthook (yet)
- Not a substitute for the full `mint-wiring-verifier` agent (backlog 999.3)
- Not a substitute for end-user device walkthrough (CLAUDE.md §9 0-Trust)

## Examples

### Example 1 — passing file

```
$ python3 tools/checks/wiring_check.py --files apps/mobile/lib/services/audit_loop_service.dart
[apps/mobile/lib/services/audit_loop_service.dart]
  N1 file exists           : PASS
  N2 no stub/TODO/NotImpl  : PASS
  N3 imported by consumer  : PASS  (AuditLoopService referenced in 4 file(s))
  N4 sim describe-all hit  : not-attempted

SUMMARY: 1 files checked — 1 PASS, 0 FAIL
exit=0
```

### Example 2 — façade detected

```
$ python3 tools/checks/wiring_check.py --files apps/mobile/lib/widgets/orphan_card.dart
[apps/mobile/lib/widgets/orphan_card.dart]
  N1 file exists           : PASS
  N2 no stub/TODO/NotImpl  : PASS
  N3 imported by consumer  : FAIL — symbol "OrphanCard" found 0× outside this file
  N4 sim describe-all hit  : not-attempted

SUMMARY: 1 files checked — 0 PASS, 1 FAIL (façade)
exit=1
```

This is the W14 pattern (façade sans câblage). The fix is to either:
1. Wire `OrphanCard` to a parent widget / route / screen, OR
2. Delete the file (it shouldn't have been created).

## Why this matters

CLAUDE.md §9 0-Trust Protocol says claims like « shipped » or « ready »
require deterministic citation. `mint-wiring-check` provides one of those
citations — a mechanical exit code that proves the file is wired, not just
present.

The full `mint-wiring-verifier` agent (backlog 999.3) would automate the
invocation of this check after every sub-agent task. Until then, agents and
Julien must invoke it manually after coding sessions.

## Implementation

Backing script: `tools/checks/wiring_check.py` (stdlib-only Python 3.9+).
Tests: `tests/checks/test_wiring_check.py`.
