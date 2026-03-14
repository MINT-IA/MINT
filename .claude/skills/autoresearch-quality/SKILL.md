---
name: autoresearch-quality
description: Autonomous autoresearch loop for code quality. Scan once, fix fast, verify periodically. Karpathy-style with batch verification every 5 changes. Invoke with /autoresearch-quality or /autoresearch-quality 50.
compatibility: Requires Flutter SDK, Python 3.10+ with pytest, git.
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch Quality v2 — Karpathy-style edit→verify loop

## Philosophy (from Karpathy's autoresearch)

> "Modify code, train 5 minutes, check if improved, keep or discard, repeat."

Key principles applied:
1. **Scan once** — inventory ALL issues upfront, work through the list. Don't re-scan after every fix.
2. **Batch verify** — run `flutter analyze` every 5 changes (not every 1). It takes 3s each — that's 30s wasted per 10 fixes.
3. **Single primary metric** — focus on `analyze issue count` as the loss function. Other metrics are guards (must not regress).
4. **Priority scoring** — fix highest-impact issues first: warnings > info, unused_element > prefer_const.
5. **Time-boxed** — stop after 20 minutes wall-clock, not after N iterations.

## Metrics

### Primary metric (the "loss function")
```bash
cd apps/mobile && flutter analyze 2>&1 | tail -3
# Extract number: e.g. "1620 issues found"
```

### Guard metrics (must not regress, checked at verify checkpoints)
```bash
# Tests — run only at VERIFY checkpoints
cd apps/mobile && flutter test 2>&1 | tail -5

# Hardcoded strings
grep -rn "'\(Tu \|Ton \|Ta \|Tes \|Votre \|Notre \|Le \|La \|Les \|Un \|Une \|Des \|Ce \|Cette \|Il \|Elle \|En \|Pour \|Avec \|Dans \|Sur \|Par \)" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v test | grep -v _test | grep -v "// " | wc -l

# Banned terms
grep -rni "garanti\|certain\|assuré\|sans risque\|optimal\b\|meilleur\b\|parfait\b" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "// " | wc -l
```

## Loop Structure

### Phase 0: INVENTORY (run ONCE at start)

Capture the full issue list and sort by priority:

```bash
cd apps/mobile && flutter analyze 2>&1 > /tmp/mint-analyze.txt
```

Build a prioritized work queue from the output:

| Priority | Issue type | Why first |
|----------|-----------|-----------|
| P0 | `unused_import`, `unused_element` | 1 line delete, zero risk |
| P1 | `unnecessary_import`, `unnecessary_string_interpolations`, `unnecessary_brace_in_string_interps`, `unnecessary_string_escapes`, `unnecessary_to_list_in_spreads` | Mechanical, safe |
| P2 | `prefer_final_fields`, `no_leading_underscores_for_local_identifiers`, `non_constant_identifier_names`, `curly_braces_in_flow_control_structures` | Rename/restructure, low risk |
| P3 | `use_build_context_synchronously` | Requires understanding async flow |
| P4 | `deprecated_member_use` | API migration, moderate risk |
| P5 | `prefer_const_constructors`, `prefer_const_declarations`, `prefer_const_literals_to_create_immutables`, `unnecessary_const` | Bulk const changes, mechanical but noisy |
| SKIP | `avoid_print` in tests/integration_test | Don't touch test infrastructure |

Store the work queue in memory. Work through P0 → P1 → P2 → etc.

### Phase 1: BASELINE
Measure primary metric + guards. Create `autoresearch-quality-results.tsv` with header:
```
iteration	timestamp	commit_hash	metric_analyze	metric_tests	metric_hardcoded	metric_banned	status	description
```

### Phase 2: FIX BATCH (5 changes)

For each change in the batch:
1. Pick the next issue from the work queue
2. Read the file, apply the fix
3. `git add <file> && git commit -m "autoresearch-quality: <description>"`
4. Increment batch counter

**Do NOT run `flutter analyze` between changes in the same batch.**

### Phase 3: VERIFY (every 5 changes)

After 5 commits:
```bash
cd apps/mobile && flutter analyze 2>&1 | tail -3
```

- If issue count decreased or stayed same → **KEEP ALL 5**
- If issue count INCREASED → **bisect**: revert last commit, re-check. Repeat until the regression is isolated. Revert only the bad commit(s).

Guard check (less frequent — every 15 changes):
```bash
cd apps/mobile && flutter test 2>&1 | tail -5
```
If tests fail → revert all commits since last green test checkpoint.

### Phase 4: LOG
After each verify checkpoint, append to TSV:
```
batch_end	timestamp	last_commit	metric_analyze	tests_status	metric_hardcoded	metric_banned	status	description_summary
```

### Phase 5: REPEAT or STOP

Stop conditions (whichever comes first):
- **Time limit**: 20 minutes wall-clock elapsed
- **Iteration limit**: max iterations reached (default 100, override with arg)
- **Diminishing returns**: 2 consecutive verify checkpoints with 0 improvement
- **All P0-P2 exhausted**: only P3+ issues remain (higher risk, stop and report)

## Strict Rules

- **NEVER** touch `financial_core/` (calculators are audited separately)
- **NEVER** modify legal constants (LPP, AVS, LIFD values)
- **NEVER** create new files (except ARB keys in `app_fr.arb`)
- **ONE** change per commit (atomic, revertable)
- Group same-type fixes together in a batch (e.g., all `unused_import` in one batch)
- If tests break → revert to last green checkpoint, skip the problematic issue type
- TSV file created at project root: `autoresearch-quality-results.tsv`
- All `git add` and `git commit` commands MUST run from project root (`/Users/.../MINT`)

## Invocation

`/autoresearch-quality` — default 100 iterations, 20 min time limit
`/autoresearch-quality 50` — limit to 50 iterations
Can be combined with `/loop`: `/loop 30m /autoresearch-quality`

## Final Output

```
AUTORESEARCH-QUALITY SESSION SUMMARY
=====================================
Iterations: X (Y batches of 5)
KEEP: K changes
DISCARD: D reverted
Duration: Xm Ys
Throughput: Z fixes/min

METRICS DELTA:
  analyze issues:    before → after (Δ-N)
  test pass rate:    before → after
  hardcoded strings: before → after
  banned terms:      before → after

BY PRIORITY:
  P0 (unused imports/elements):  N fixed
  P1 (unnecessary patterns):     N fixed
  P2 (naming/style):             N fixed
  P3+ (complex):                 N skipped (report below)

TOP CHANGES:
  - <commit hash>: <description>
  - ...

REMAINING HIGH-VALUE ISSUES (P3+):
  - <file>:<line> <issue_type> — <description>
  - ...
```
