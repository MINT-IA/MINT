---
name: mint-review-pr
description: "Staff engineer review of a diff with persistent memory across PRs (engram MCP). Checks bugs, compliance, regressions, i18n, archetypes. Recalls prior findings, accumulates new ones with prior_finding_refs. Fix-First pattern: AUTO-FIX trivial issues, ASK for judgment calls. Use with /review-pr."
compatibility: Requires Flutter SDK + git + engram MCP (plugin:engram:engram, see docs/AGENTS/VIBE-CODING-INFRA.md)
memory: local
metadata:
  author: mint-team
  version: "2.0"
  source: "GStack /review (Fix-First + specialist passes) + Superpowers spec-reviewer (Do Not Trust) + vibe-coding infra Phase 1 (engram persistent memory)"
---

# Review PR v1 — Staff Engineer Review

> "Do Not Trust the Report. The implementer finished suspiciously quickly.
> Their report may be incomplete, inaccurate, or optimistic.
> You MUST verify everything independently."

## When to use this skill

- After completing a feature (before /mint-commit)
- When the user says "review ce diff" or "verifie mon code"
- Before any PR to dev

## HARD GATE

**Do NOT approve or say "looks good" without running EVERY verification command yourself.**
If you haven't run the command in THIS message, you cannot claim it passes.

## Step 0: Recall prior findings (engram MCP, MANDATORY)

Before reading the diff, query your accumulated memory of prior reviews. You DO have memory across sessions via the `plugin:engram:engram` MCP server (see `docs/AGENTS/VIBE-CODING-INFRA.md`).

For each major file/topic touched by the diff, search engram :

```
mem_search <query> --project mint-ia-mint
```

Useful queries to run :
- `mem_search "file:apps/mobile/lib/screens/<filename>"` — past findings on this file
- `mem_search "topic:flutter:state-management"` — past findings on state management patterns
- `mem_search "topic:lsfin:banned-terms"` — past banned-term flags + accepted exceptions
- `mem_search "topic:financial_core:duplicate-calc"` — past calculation duplication flags
- `mem_search "category:anti-facade"` — past facade-sans-cablage flags

For each hit returned, note the `obs_id` — you'll need it for `prior_finding_refs` in Step 5.5.

**If `mem_search` returns nothing** : either this is the first review of this surface (legitimate), OR engram is disconnected (`claude mcp list` should show `plugin:engram:engram → ✓ Connected`). If disconnected, flag this BEFORE proceeding — do not silently lose memory.

## Step 1: Read the diff (MANDATORY)

```bash
cd /Users/julienbattaglia/Desktop/MINT
git fetch origin dev
git diff dev...HEAD --stat
git diff dev...HEAD
```

Read the FULL diff. Not a summary. Not "I see 5 files changed". Read every line.

## Step 2: Run mechanical checks (MANDATORY)

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter analyze
flutter test
```

```bash
cd /Users/julienbattaglia/Desktop/MINT/services/backend
python3 -m pytest tests/ -q
```

If ANY check fails → STOP. Fix first, then restart review.

## Step 3: 8 specialist passes on the diff

Read the diff again for each pass. One concern at a time.

### Pass 1 — BUGS
For each changed file:
- Null safety: any `!` operator without guard? Any `.first` without `.firstOrNull`?
- Dispose: any controller/stream created without dispose in `dispose()`?
- Context after await: any `context.read` or `context.go` after an `await`?
- Edge cases: what happens with 0? negative? null? empty list?

### Pass 2 — COMPLIANCE (CLAUDE.md §6)
Grep the diff for:
```bash
git diff dev...HEAD | grep -i "garanti\|certain\|assuré\|assure\|sans risque\|optimal\|meilleur\|parfait\|conseiller"
```
- Banned terms in user-facing strings → BLOCKER
- "conseiller" → must use "specialiste" → BLOCKER
- Missing disclaimer on calculator output → BLOCKER
- Missing source (law article) on calculation → WARNING
- Missing confidence score on projection → WARNING
- Social comparison ("top X%", "percentile", "mieux que") → BLOCKER
- PII in logs (IBAN, SSN, employer, exact salary) → BLOCKER

### Pass 3 — REGRESSIONS
- Does the change modify a function used by other screens?
- Does it change a model field that other services read?
- Does it change a route path that other screens link to?
```bash
# For each modified function/class, check consumers:
grep -rn "FunctionOrClassName" apps/mobile/lib/ --include="*.dart" | head -20
```

### Pass 4 — i18n
```bash
git diff dev...HEAD | grep -n "Text('" | grep -v "S.of\|AppLocalizations\|widget\|test"
```
- Hardcoded French strings → BLOCKER (must use ARB files)
- New ARB keys only in fr → BLOCKER (must be in all 6: fr, en, de, es, it, pt)
- Missing `flutter gen-l10n` after ARB change → WARNING

### Pass 5 — DESIGN SYSTEM
```bash
git diff dev...HEAD | grep -n "Color(0x\|Colors\.\|Navigator\.push\|Navigator\.of.*push"
```
- Hardcoded colors → BLOCKER (use MintColors.*)
- Raw Material colors → BLOCKER (use MintColors.*)
- Navigator.push for navigation → BLOCKER (use context.go/push)
- Navigator.pop for dialogs → OK (legitimate)

### Pass 6 — FINANCIAL CORE
```bash
git diff dev...HEAD | grep -n "_calcul\|calculate\|compute\|estimate\|forecast\|project\|\* 0\.\|/ 12\|/ 44"
```
- Local calculation functions (ANY language: `_calculate`, `_calculer`, `_compute`) → BLOCKER if they duplicate financial_core/
- Inline calculations (`salary * 0.30`, `total / 12`, `years / 44`) → WARNING, check if financial_core has this logic
- Check: is the calculation imported from `financial_core.dart`?
- New calculation → must have law source + disclaimer + confidence score

### Pass 7 — ARCHETYPES
For each new feature/screen:
- Does it assume swiss_native? (check for hardcoded "CH" or default archetype)
- Does it handle expat_us differently? (FATCA implications)
- Does it handle independent_no_lpp? (different 3a max, no 2e pilier)

### Pass 8 — ANTI-FACADE (4 niveaux)
For each NEW file created:
1. **Existe** — the file is created ✓
2. **Substantiel** — it has real logic, not stubs or TODOs
3. **Cable** — it is imported and called from somewhere. WHO calls it?
4. **Donnees** — real data flows through it. Not just mocks.

```bash
# For each new file, check wiring:
grep -rn "new_file_name\|NewClassName" apps/mobile/lib/ --include="*.dart"
```

If a file exists but nobody imports it → BLOCKER ("facade sans cablage")

### Step 3.5 — Run compliance hardener

After the 8 manual passes, run the autonomous compliance tester:
```
/autoresearch-compliance-hardener 10
```
This catches adversarial cases that the grep-based Pass 2 misses.

## Step 4: Classify findings

### AUTO-FIX (apply without asking):
- Dead code removal
- Missing imports
- Trivial formatting
- Unused variables

### ASK (require user judgment):
- Security concerns
- Race conditions
- Design decisions
- Fixes > 20 lines
- Behavior changes visible to user
- Enum completeness

### BLOCKER (PR cannot merge):
- Banned compliance terms
- Hardcoded strings/colors
- Facade sans cablage (file exists but not wired)
- Flutter analyze errors
- Test failures
- Duplicate calculations outside financial_core

## Step 5: Produce the report

```
## Review Report

**Branch**: [branch name]
**Files changed**: [N]
**Verdict**: [PASS | PASS WITH WARNINGS | BLOCKED]

### BLOCKERS (must fix before merge)
- [ ] [file:line] — [description]

### WARNINGS (should fix, not blocking)
- [ ] [file:line] — [description]

### AUTO-FIXED (already applied)
- [file:line] — [description]

### ANTI-FACADE CHECK
| New file | Existe | Substantiel | Cable | Donnees |
|----------|--------|-------------|-------|---------|
| file.dart | ✅ | ✅ | ✅/❌ | ✅/❌ |

### VERIFICATION (commands run in THIS message)
- flutter analyze: [result]
- flutter test: [result]
- pytest: [result]

### MEMORY (engram findings cited from prior reviews)
- prior_finding_refs: [list of obs_ids cited in this review, or "none — first review of this surface"]
- new findings persisted: [count from Step 5.5]
```

## Step 5.5: Persist findings to engram (MANDATORY before Step 6)

For each BLOCKER and WARNING in the report, call `mem_save` so the next review of this surface inherits the context.

```
mem_save "<title>" "<message>" --type review-finding --project mint-ia-mint --scope local
```

Convention `--title` : `<category>: <file>:<line> — <one-liner>` (e.g. `anti-pattern: onboarding_screen.dart:142 — Provider state outside ChangeNotifier`).

Convention `--message` (structured) :

```
What:    <one-paragraph description of the finding>
Why:     <why this is a problem in MINT context — cite CLAUDE.md rule or memory if applicable>
Where:   file=<path>, line=<int>, pr_number=<N>, pr_sha=<sha>
Learned: <pattern or principle to remember for future PRs>
Severity: P0 | P1 | P2 | nit
Category: anti-pattern | regression | acceptance | warning | anti-facade | banned-term | i18n | financial-duplicate
Recommendation: <concrete fix or accepted-exception rationale>
prior_finding_refs: [<obs_id_1>, <obs_id_2>, ...]  // engram obs_ids from Step 0 search that this finding cites
```

**Topic key convention** : `<area>:<sub-area>:<specific>` — e.g. `flutter:state-management:provider-pattern`, `lsfin:banned-terms:garanti`, `financial_core:avs-calc:duplicate`. Use these in `mem_search` queries for cross-PR retrieval.

**`prior_finding_refs` rule** : if a finding from Step 0 mem_search is **directly relevant** to this finding (same file, same anti-pattern, same banned-term family), include its `obs_id` in `prior_finding_refs`. This is the **compounding observable** metric for Phase 1 gate 2026-05-21 — ≥3 of first 5 PRs must have at least one finding with non-null `prior_finding_refs`.

**Do NOT persist** : trivial AUTO-FIXED items (dead code, missing imports, formatting). Persist only findings that capture a pattern future reviews should re-recognize.

After all findings persisted, sanity check :

```
mem_search "pr_sha:<sha-of-current-pr>" --project mint-ia-mint
```

Should return the count of findings just saved.

## Step 6: Gate for /mint-commit

If verdict is BLOCKED → tell the user explicitly:
"This PR has N blockers. Do NOT run /mint-commit until they are fixed."

If verdict is PASS or PASS WITH WARNINGS → tell the user:
"Review passed. You can run /mint-commit."

**Note**: There is no automated enforcement between this skill and /mint-commit.
The gate is advisory. The user decides. But the skill MUST be explicit about the verdict.

## What this skill does NOT do

- Write code (report findings, don't fix — unless AUTO-FIX category)
- Create plans (this is post-implementation review)
- Commit (use /mint-commit after review passes)

## Anti-performativity rule

When receiving feedback on YOUR review:
- Do NOT say "You're absolutely right!" or "Great point!"
- VERIFY the feedback independently before acting on it
- If someone says "this is fine actually" → re-check yourself. Trust your analysis.
