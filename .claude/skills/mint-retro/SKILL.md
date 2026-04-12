---
name: mint-retro
description: "Retrospective quantifiee. Analyse git log, compte commits/tests/LOC, detecte hotspots, persiste les learnings. Use with /retro or /retro 7 (derniers N jours)."
compatibility: Requires git
metadata:
  author: mint-team
  version: "1.0"
  source: "GStack /retro (git analysis + snapshot) + Hermes learnings (persistent memory)"
---

# Retro v1 — Retrospective quantifiee

> "What gets measured gets improved. What gets persisted gets remembered."

## When to use this skill

- End of a sprint
- End of a week
- After a major PR merge
- When the user asks "qu'est-ce qu'on a fait ?" or "retrospective"

## Input

- `/retro` — analyse les 7 derniers jours (defaut)
- `/retro 14` — analyse les 14 derniers jours
- `/retro 30` — analyse le dernier mois

## The Retro Pipeline (6 steps)

### Step 1: Git analysis

```bash
cd /Users/julienbattaglia/Desktop/MINT

# Commits in period
git log --oneline --since="N days ago" --no-merges

# Files changed (hotspots)
git log --since="N days ago" --no-merges --pretty=format: --name-only | sort | uniq -c | sort -rn | head -20

# Lines added/removed
git diff --stat $(git log --since="N days ago" --format=%H | tail -1)..HEAD

# Commit types breakdown (use precise patterns to avoid false positives)
git log --oneline --since="N days ago" --no-merges | grep -cE "^[a-f0-9]+ feat[:(]"
git log --oneline --since="N days ago" --no-merges | grep -cE "^[a-f0-9]+ fix[:(]"
git log --oneline --since="N days ago" --no-merges | grep -cE "^[a-f0-9]+ test[:(]"
git log --oneline --since="N days ago" --no-merges | grep -cE "^[a-f0-9]+ refactor[:(]"
git log --oneline --since="N days ago" --no-merges | grep -cE "^[a-f0-9]+ (i18n|coach|compliance|ux|nav|prompt)[:(]"

# NOTE: This analyzes the CURRENT branch only. For a global view, checkout dev first.
```

### Step 2: Test health

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter test 2>&1 | tail -3

cd /Users/julienbattaglia/Desktop/MINT/services/backend
python3 -m pytest tests/ -q 2>&1 | tail -3
```

Extract: total tests, passed, failed, skipped.

### Step 3: Code quality

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter analyze 2>&1 | tail -3
```

### Step 4: Hotspot analysis

From Step 1 file list, identify:
- **Top 5 most modified files** — these are risk areas
- **Files in financial_core/ that changed** — high-impact changes
- **Files modified but never tested** — run this mechanically:

```bash
# For each hotspot, check if a corresponding test exists
for f in $(git log --since="N days ago" --no-merges --pretty=format: --name-only | sort | uniq -c | sort -rn | head -5 | awk '{print $2}'); do
  test_name=$(basename "$f" .dart)
  match=$(find apps/mobile/test/ -name "*${test_name}*" 2>/dev/null | head -1)
  if [ -z "$match" ]; then echo "NO TEST: $f"; else echo "HAS TEST: $f → $match"; fi
done
```

### Step 5: Produce the report

```
## Retro [date_debut] → [date_fin]

### Metriques
| Metrique | Valeur |
|----------|--------|
| Commits | N |
| Fichiers touches | N |
| Lignes ajoutees | +N |
| Lignes supprimees | -N |
| Tests Flutter | N passed / N total |
| Tests Backend | N passed / N total |
| Analyze issues | N |

### Breakdown par type
| Type | Count |
|------|-------|
| feat | N |
| fix | N |
| test | N |
| refactor | N |
| autoresearch | N |

### Hotspots (fichiers les plus modifies)
| Fichier | Modifications | Tests associes |
|---------|--------------|----------------|
| app.dart | N fois | ✅/❌ |
| ... | ... | ... |

### Ce qui a marche
- [points positifs identifies dans les commits]

### Ce qui a casse
- [bugs fixes, regressions, problemes rencontres]

### Risques identifies
- [fichiers chauds sans tests]
- [financial_core/ modifie — impact potentiel multi-domaines]
- [dettes techniques accumulees]

### Prochaines actions
1. [action concrete]
2. [action concrete]
3. [action concrete]
```

### Step 6: Persist (2 outputs)

**6a. Update MEMORY.md** — Use the Edit tool to update the "CURRENT STATE" section:
- Replace the test count with the fresh numbers
- Replace the date with today
- Add 1 line about what changed ("Navigation cleanup: dossier_tab supprime, 8137 tests")

**6b. Append to retro history** — For inter-sprint comparison, append a JSON line:
```bash
echo '{"date":"'$(date +%Y-%m-%d)'","commits":N,"feat":N,"fix":N,"tests_flutter":N,"tests_backend":N,"analyze_issues":N,"top_hotspot":"file.dart","top_hotspot_count":N}' >> /Users/julienbattaglia/Desktop/MINT/.claude/retro-history.jsonl
```

This file grows over time. Future retros can compare: "Last week we had 8137 tests, this week 8200 = +63."

## What this skill does NOT do

- Fix bugs (use /autoresearch-quality)
- Write tests (use /autoresearch-test-generation)
- Create features (use /mint-flutter-dev or /mint-backend-dev)
- Commit code (use /mint-commit)
- It ONLY measures and reports. Zero code modifications.

## Learnings format

If the retro reveals non-obvious patterns, save them as project memories:

Example: "financial_core/avs_calculator.dart modified 12 times in 14 days → needs stabilization before next feature sprint"

Only save learnings that are:
- Non-obvious (not derivable from git log alone)
- Actionable (changes future behavior)
- Durable (still relevant in 2+ weeks)
