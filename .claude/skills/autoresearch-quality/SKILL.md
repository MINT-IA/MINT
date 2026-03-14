---
name: autoresearch-quality
description: Autonomous autoresearch loop for code quality. Iterates edit→commit→verify→keep/discard on 4 mechanical metrics (analyze, tests, hardcoded strings, banned terms). Invoke with /autoresearch-quality or /autoresearch-quality 50.
compatibility: Requires Flutter SDK, Python 3.10+ with pytest, git.
allowed-tools: Bash(flutter:*) Bash(pytest:*) Bash(grep:*) Bash(git:*) Bash(wc:*) Bash(cd:*) Bash(tail:*) Bash(date:*) Bash(echo:*)
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Quality — Karpathy-style edit→verify loop

## Purpose

You are an **autonomous quality improvement agent**. You iterate in a loop: find ONE problem, fix it atomically, verify metrics, keep or revert. No opinions, no refactoring sprees — just mechanical, measurable improvements.

## Metrics (measure ALL 4 at every iteration)

### 1. Flutter analyze — target: 0 issues
```bash
cd apps/mobile && flutter analyze 2>&1 | tail -3
```

### 2. Tests green — target: 100% pass
```bash
cd apps/mobile && flutter test 2>&1 | tail -5
cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3
```

### 3. Hardcoded FR strings — target: 0
```bash
grep -rn "'\(Tu \|Ton \|Ta \|Tes \|Votre \|Notre \|Le \|La \|Les \|Un \|Une \|Des \|Ce \|Cette \|Il \|Elle \|En \|Pour \|Avec \|Dans \|Sur \|Par \)" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v test | grep -v _test | grep -v "// " | wc -l
```

### 4. Banned terms — target: 0
```bash
grep -rni "garanti\|certain\|assuré\|sans risque\|optimal\b\|meilleur\b\|parfait\b" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "// " | wc -l
```

## Loop (8 phases per iteration)

### Phase 1: BASELINE
Measure all 4 metrics. On first iteration, create `autoresearch-quality-results.tsv` with header:
```
iteration	timestamp	commit_hash	metric_analyze	metric_tests	metric_hardcoded	metric_banned	status	description
```

### Phase 2: SCAN
Identify ONE specific problem from the metrics (1 analyze warning, 1 hardcoded string, 1 banned term). Pick the lowest-hanging fruit first.

### Phase 3: FIX
Apply ONE atomic change (1 file, minimal diff). Never batch multiple fixes.

### Phase 4: COMMIT
```bash
git add <file> && git commit -m "autoresearch-quality: <short description>"
```

### Phase 5: VERIFY
Re-measure all 4 metrics.

### Phase 6: DECIDE
- All metrics equal or better → **KEEP**
- Any metric regresses → `git revert HEAD --no-edit` → **DISCARD**

### Phase 7: LOG
Append one line to `autoresearch-quality-results.tsv`:
```
iteration	timestamp	commit_hash	metric_analyze	metric_tests	metric_hardcoded	metric_banned	status	description
```

### Phase 8: REPEAT
Next iteration. Stop when max iterations reached OR all metrics at 0.

## Strict Rules

- **NEVER** touch `financial_core/` (calculators are audited separately)
- **NEVER** modify legal constants (LPP, AVS, LIFD values)
- **NEVER** create new files (except ARB keys in `app_fr.arb`)
- **ONE** change per iteration (atomic, revertable)
- If tests break → revert immediately, no attempt to fix
- **Maximum 100 iterations** per session (override with argument: `/autoresearch-quality 50`)
- TSV file created at project root: `autoresearch-quality-results.tsv`

## Invocation

The user types `/autoresearch-quality` or `/autoresearch-quality 50` (to limit iterations).
Can be combined with `/loop`: `/loop 30m /autoresearch-quality`

Parse the argument as max iterations (default 100).

## Final Output

At session end (max iterations or no problems left), display:

```
AUTORESEARCH-QUALITY SESSION SUMMARY
=====================================
Iterations: X
KEEP: Y changes
DISCARD: Z reverted
Duration: ~Nm

METRICS DELTA:
  analyze issues:    before → after (delta)
  test pass rate:    before → after
  hardcoded strings: before → after (delta)
  banned terms:      before → after (delta)

TOP CHANGES:
  - <commit hash>: <description>
  - ...
```
