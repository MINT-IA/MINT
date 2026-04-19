#!/usr/bin/env bash
# A4 spike (30.5-RESEARCH.md §Assumptions Log): validates stat mtime reliability
# on 60+ memory files.
#
# HIGH RISK if all files share identical mtime (mass `touch` rewrite) — the
# GC 30d rule would then archive ALL files at once or NONE, silently breaking
# CTX-01. Mitigation: sample 5 files, print mtimes + deltas; exit 1 if all 5
# identical.
#
# Exit codes:
#   0 — PASS (mtimes have variance) OR inconclusive (no files found, Plan 02
#       must create seed fixture)
#   1 — FAIL (mass-touch signature detected OR memory dir missing) — planner
#       must adopt fallback (frontmatter date OR git-log birthdate) in Plan 02

set -e
MEM_DIR="$HOME/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory"
if [ ! -d "$MEM_DIR" ]; then
  echo "A4: MEMORY DIR MISSING: $MEM_DIR — spike cannot run. Create directory or adjust path."
  exit 1
fi

SAMPLE=$(ls "$MEM_DIR"/*.md 2>/dev/null | head -5)
if [ -z "$SAMPLE" ]; then
  echo "A4: NO .md FILES at root of $MEM_DIR — may already be migrated to topics/, try topics/"
  SAMPLE=$(ls "$MEM_DIR"/topics/*.md 2>/dev/null | head -5)
fi

if [ -z "$SAMPLE" ]; then
  echo "A4: NO .md FILES FOUND anywhere — spike inconclusive. Plan 02 Task 2 must create seed fixture."
  exit 0
fi

echo "A4 sample mtimes:"
declare -a MTIMES
while IFS= read -r f; do
  M=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null)
  MTIMES+=("$M")
  echo "  $f mtime=$M ($(date -r $M 2>/dev/null || date -d @$M))"
done <<< "$SAMPLE"

# If all 5 identical → mass `touch` signature, mtime unreliable for GC.
UNIQUE=$(printf "%s\n" "${MTIMES[@]}" | sort -u | wc -l | tr -d ' ')
if [ "$UNIQUE" = "1" ]; then
  echo "A4: FAIL — all 5 mtimes identical. GC by mtime UNRELIABLE. Plan 02 Task 3 must fall back to frontmatter date."
  exit 1
fi
echo "A4: PASS — $UNIQUE distinct mtimes across 5 samples. GC by mtime is reliable."
exit 0
