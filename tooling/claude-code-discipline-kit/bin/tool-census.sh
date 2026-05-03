#!/usr/bin/env bash
# tool-census.sh — Discipline 14: surface tools you didn't know you had
# Enumerates skills, lints, MCP servers, scripts; cross-references against usage log.

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
MODE="full"
SUGGEST_TASK=""

usage() {
  cat <<EOF
tool-census.sh — Discipline 14 (tool discoverability)

USAGE:
  bash bin/tool-census.sh                    # full inventory + usage stats
  bash bin/tool-census.sh --underused        # tools never used or > 30d
  bash bin/tool-census.sh --suggest "<task>" # 3 most relevant underused tools for task
  bash bin/tool-census.sh --json             # machine-readable
  bash bin/tool-census.sh --help

EXIT CODES:
  0 = census ran successfully
  1 = errors during enumeration

The script:
  1. Enumerates .claude/skills/, tools/, scripts/, .mcp.json, lefthook.yml, .github/workflows/
  2. Cross-references against .claude/usage/invocations.log if present
  3. Prints sorted by category: active (<7d), recent (7-30d), underused (30-90d), dormant (>90d), never
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --underused) MODE="underused"; shift ;;
    --suggest) MODE="suggest"; SUGGEST_TASK="${2:-}"; shift 2 ;;
    --json) MODE="json"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

cd "$PROJECT_DIR"

USAGE_LOG=".claude/usage/invocations.log"
NOW=$(date -u +%s)

# Enumerate skills
declare -a SKILLS=()
if [ -d .claude/skills ]; then
  for skill_dir in .claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    SKILLS+=("skill:$skill_name")
  done
fi

# Enumerate lints
declare -a LINTS=()
if [ -d tools/checks ]; then
  for lint in tools/checks/*.py tools/checks/*.sh tools/checks/*.dart; do
    [ -f "$lint" ] || continue
    LINTS+=("lint:$(basename "$lint")")
  done
fi

# Enumerate scripts
declare -a SCRIPTS=()
if [ -d scripts ]; then
  for script in scripts/*; do
    [ -f "$script" ] || continue
    SCRIPTS+=("script:$(basename "$script")")
  done
fi
if [ -d bin ]; then
  for script in bin/*; do
    [ -f "$script" ] || continue
    SCRIPTS+=("bin:$(basename "$script")")
  done
fi

# Enumerate MCP servers
declare -a MCP=()
if [ -f .mcp.json ]; then
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r srv; do
      MCP+=("mcp:$srv")
    done < <(jq -r '.mcpServers | keys[]' .mcp.json 2>/dev/null || true)
  fi
fi

# Categorize by usage
get_last_use() {
  local tool="$1"
  if [ -f "$USAGE_LOG" ]; then
    local last_line
    last_line=$(grep -F "$tool" "$USAGE_LOG" 2>/dev/null | tail -n 1 | awk '{print $1}' || true)
    if [ -n "$last_line" ]; then
      # ISO-8601 to epoch (macOS/BSD vs GNU compat)
      if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_line" +%s >/dev/null 2>&1; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_line" +%s
      else
        date -d "$last_line" +%s 2>/dev/null || echo 0
      fi
      return 0
    fi
  fi
  echo 0
}

categorize() {
  local epoch="$1"
  if [ "$epoch" -eq 0 ]; then
    echo "never"; return
  fi
  local age=$(( (NOW - epoch) / 86400 ))
  if [ "$age" -lt 7 ]; then echo "active"
  elif [ "$age" -lt 30 ]; then echo "recent"
  elif [ "$age" -lt 90 ]; then echo "underused"
  else echo "dormant"
  fi
}

# Output
ALL=("${SKILLS[@]}" "${LINTS[@]}" "${SCRIPTS[@]}" "${MCP[@]}")

if [ "$MODE" = "json" ]; then
  printf '{"project_dir": "%s", "scan_time": "%s", "tools": [' "$PROJECT_DIR" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  first=1
  for tool in "${ALL[@]}"; do
    name="${tool#*:}"
    last=$(get_last_use "$name")
    cat=$(categorize "$last")
    [ $first -eq 0 ] && printf ","
    first=0
    printf '\n  {"id": "%s", "category": "%s", "last_use_epoch": %s}' "$tool" "$cat" "$last"
  done
  printf '\n]}\n'
  exit 0
fi

# Human-readable output
if [ "$MODE" = "suggest" ]; then
  echo "Suggesting underused tools for task: \"$SUGGEST_TASK\""
  echo ""
  # Naive: print top 3 underused/never with names matching task keywords
  COUNT=0
  for tool in "${ALL[@]}"; do
    [ $COUNT -ge 3 ] && break
    name="${tool#*:}"
    last=$(get_last_use "$name")
    cat=$(categorize "$last")
    if [ "$cat" = "never" ] || [ "$cat" = "dormant" ] || [ "$cat" = "underused" ]; then
      # Match if any task word appears in tool name
      for word in $SUGGEST_TASK; do
        if echo "$name" | grep -qi "$word"; then
          printf "  → %-40s [%s]\n" "$tool" "$cat"
          COUNT=$((COUNT + 1))
          break
        fi
      done
    fi
  done
  if [ $COUNT -eq 0 ]; then
    echo "  (no underused tools matched task keywords — try broader terms or run --underused for full list)"
  fi
  exit 0
fi

if [ "$MODE" = "underused" ]; then
  echo "Underused tools (never used, dormant > 90d, or underused 30-90d):"
  echo ""
  for tool in "${ALL[@]}"; do
    name="${tool#*:}"
    last=$(get_last_use "$name")
    cat=$(categorize "$last")
    if [ "$cat" = "never" ] || [ "$cat" = "dormant" ] || [ "$cat" = "underused" ]; then
      printf "  %-50s [%s]\n" "$tool" "$cat"
    fi
  done
  exit 0
fi

# Full mode
echo "Tool census — $PROJECT_DIR"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

declare -A COUNTS
COUNTS[active]=0
COUNTS[recent]=0
COUNTS[underused]=0
COUNTS[dormant]=0
COUNTS[never]=0

for cat_filter in active recent underused dormant never; do
  echo "## $cat_filter"
  for tool in "${ALL[@]}"; do
    name="${tool#*:}"
    last=$(get_last_use "$name")
    cat=$(categorize "$last")
    if [ "$cat" = "$cat_filter" ]; then
      COUNTS[$cat]=$((${COUNTS[$cat]} + 1))
      printf "  %s\n" "$tool"
    fi
  done
  echo ""
done

echo "## Summary"
printf "  Active   (<7d):   %d\n" "${COUNTS[active]}"
printf "  Recent   (7-30d): %d\n" "${COUNTS[recent]}"
printf "  Underused(30-90): %d\n" "${COUNTS[underused]}"
printf "  Dormant  (>90d):  %d\n" "${COUNTS[dormant]}"
printf "  Never:            %d\n" "${COUNTS[never]}"
printf "  Total tools:      %d\n" "${#ALL[@]}"

if [ ! -f "$USAGE_LOG" ]; then
  echo ""
  echo "⚠ No invocation log at $USAGE_LOG — all tools categorized as 'never'."
  echo "   See docs/TOOL_DISCOVERY.md for how to wire usage logging."
fi
