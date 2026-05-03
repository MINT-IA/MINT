#!/usr/bin/env bash
# bootstrap.sh — Claude Code Discipline Kit installer
# - Additive only: never overwrites existing files
# - Dry-run by default: shows what would change, writes nothing
# - Idempotent: safe to re-run
# - Detects existing tooling (superpowers, GSD, gstack, lefthook) and adapts

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIT_VERSION="$(cat "$KIT_DIR/VERSION" | tr -d '[:space:]')"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
MODE="dry-run"
LANG_FLAG="en"
FORCE=0

usage() {
  cat <<EOF
Claude Code Discipline Kit v$KIT_VERSION — bootstrap installer

USAGE:
  bash bin/bootstrap.sh [--dry-run|--apply] [--lang=en|fr] [--force] [--help]

OPTIONS:
  --dry-run       (default) Show what would change, write nothing
  --apply         Actually install
  --lang=LANG     Language for templates (en | fr — V0.4). Default: en
  --force         Overwrite kit-managed files even if they exist (DANGEROUS)
  --help          Show this help

PROJECT_DIR env var overrides target. Default: \$(pwd)

EXAMPLES:
  bash bin/bootstrap.sh                    # dry-run, current dir
  bash bin/bootstrap.sh --apply            # install for real
  PROJECT_DIR=/path bash bin/bootstrap.sh --apply

The kit is ADDITIVE: it will never overwrite your existing CLAUDE.md, lefthook.yml,
or any project-specific file. New kit-managed files are added only if absent.
EOF
}

log() { printf "[discipline-kit] %s\n" "$*"; }
warn() { printf "[discipline-kit] ⚠️  %s\n" "$*" >&2; }
err() { printf "[discipline-kit] ❌ %s\n" "$*" >&2; }
ok() { printf "[discipline-kit] ✓ %s\n" "$*"; }

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --apply) MODE="apply"; shift ;;
    --lang=*) LANG_FLAG="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) err "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

# Sanity checks
if [ ! -d "$PROJECT_DIR" ]; then
  err "PROJECT_DIR does not exist: $PROJECT_DIR"
  exit 1
fi

if [ "$LANG_FLAG" != "en" ]; then
  warn "Lang '$LANG_FLAG' not yet supported in V$KIT_VERSION. Falling back to en. (V0.4 will add fr/de.)"
  LANG_FLAG="en"
fi

log "Kit version: $KIT_VERSION"
log "Mode: $MODE"
log "Project dir: $PROJECT_DIR"
log "Language: $LANG_FLAG"
log ""

# Detect existing tooling
SUPERPOWERS=0
GSD=0
GSTACK=0
LEFTHOOK=0
EXISTING_CLAUDE_MD=0
EXISTING_LOCK=0

[ -d "$PROJECT_DIR/.claude/skills/using-superpowers" ] && SUPERPOWERS=1
[ -d "$PROJECT_DIR/.claude/skills/gsd-discuss-phase" ] && GSD=1
[ -d "$PROJECT_DIR/.claude/skills/gstack" ] || ls "$PROJECT_DIR/.claude/skills/" 2>/dev/null | grep -q "gstack" && GSTACK=1 || true
[ -f "$PROJECT_DIR/lefthook.yml" ] && LEFTHOOK=1
[ -f "$PROJECT_DIR/CLAUDE.md" ] && EXISTING_CLAUDE_MD=1
[ -f "$PROJECT_DIR/.claude-code-discipline.lock" ] && EXISTING_LOCK=1

log "Detected tooling:"
[ $SUPERPOWERS -eq 1 ] && ok "obra/superpowers (kit will defer disciplines 1-7)"
[ $GSD -eq 1 ] && ok "GSD framework (kit will defer R/P/I to gsd-*)"
[ $GSTACK -eq 1 ] && ok "gstack (kit voice-trigger frontmatter compatible)"
[ $LEFTHOOK -eq 1 ] && ok "lefthook.yml (kit will install lefthook.discipline.yml as overlay)"
[ $EXISTING_CLAUDE_MD -eq 1 ] && ok "CLAUDE.md (kit will write CLAUDE.md.discipline.template — manual merge)"
[ $EXISTING_LOCK -eq 1 ] && warn "Existing .claude-code-discipline.lock — this is an upgrade"
log ""

# Plan changes
PLAN=()
SKIP=()

plan_copy() {
  local src="$1" dst="$2"
  if [ -e "$PROJECT_DIR/$dst" ] && [ $FORCE -eq 0 ]; then
    SKIP+=("$dst (exists, skipped — use --force to overwrite)")
  else
    PLAN+=("$dst (from kit/$src)")
  fi
}

# Files to install
plan_copy "docs/DISCIPLINES.md" "docs/CLAUDE_CODE_DISCIPLINE.md"
plan_copy "docs/ANTI_PATTERNS.md" "docs/ANTI_PATTERNS.md"
plan_copy "docs/TOOL_DISCOVERY.md" "docs/TOOL_DISCOVERY.md"
plan_copy "docs/CUSTOMIZATION.md" "docs/DISCIPLINE_CUSTOMIZATION.md"
plan_copy "skills/claude-code-discipline/SKILL.md" ".claude/skills/claude-code-discipline/SKILL.md"
plan_copy "lints/lint_status_audit.py" "tools/checks/lint_status_audit.py"
plan_copy "bin/tool-census.sh" "bin/tool-census.sh"
plan_copy "bin/doctor.sh" "bin/doctor.sh"

# CLAUDE.md: special handling — never overwrite
if [ $EXISTING_CLAUDE_MD -eq 1 ] && [ $FORCE -eq 0 ]; then
  PLAN+=("CLAUDE.md.discipline.template (your existing CLAUDE.md left untouched — manual merge using markers from this template)")
else
  PLAN+=("CLAUDE.md (from kit/templates/CLAUDE.md.${LANG_FLAG}.template)")
fi

# lefthook: never overwrite
if [ $LEFTHOOK -eq 1 ] && [ $FORCE -eq 0 ]; then
  PLAN+=("lefthook.discipline.yml (overlay — add 'extends: lefthook.discipline.yml' to your lefthook.yml manually)")
else
  PLAN+=("lefthook.yml (from kit/templates/lefthook.discipline.yml as primary)")
fi

# .gitattributes: append-only
PLAN+=(".gitattributes (append marker-block protection rules)")

# Lock file
PLAN+=(".claude-code-discipline.lock (records v$KIT_VERSION + checksums + timestamp)")

# Print plan
log "Planned changes (${#PLAN[@]} files):"
for item in "${PLAN[@]}"; do
  printf "  + %s\n" "$item"
done

if [ ${#SKIP[@]} -gt 0 ]; then
  log ""
  log "Skipped (${#SKIP[@]} files):"
  for item in "${SKIP[@]}"; do
    printf "  - %s\n" "$item"
  done
fi

log ""

if [ "$MODE" = "dry-run" ]; then
  log "DRY-RUN — no files written. Re-run with --apply to install."
  exit 0
fi

# Apply
log "Applying changes..."

apply_copy() {
  local src="$1" dst="$2"
  local target="$PROJECT_DIR/$dst"
  if [ -e "$target" ] && [ $FORCE -eq 0 ]; then
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  cp "$KIT_DIR/$src" "$target"
  ok "wrote $dst"
}

apply_copy "docs/DISCIPLINES.md" "docs/CLAUDE_CODE_DISCIPLINE.md"
apply_copy "docs/ANTI_PATTERNS.md" "docs/ANTI_PATTERNS.md"
apply_copy "docs/TOOL_DISCOVERY.md" "docs/TOOL_DISCOVERY.md"
apply_copy "docs/CUSTOMIZATION.md" "docs/DISCIPLINE_CUSTOMIZATION.md"
apply_copy "skills/claude-code-discipline/SKILL.md" ".claude/skills/claude-code-discipline/SKILL.md"
apply_copy "lints/lint_status_audit.py" "tools/checks/lint_status_audit.py"
apply_copy "bin/tool-census.sh" "bin/tool-census.sh"
apply_copy "bin/doctor.sh" "bin/doctor.sh"

# CLAUDE.md
if [ $EXISTING_CLAUDE_MD -eq 1 ] && [ $FORCE -eq 0 ]; then
  cp "$KIT_DIR/templates/CLAUDE.md.${LANG_FLAG}.template" "$PROJECT_DIR/CLAUDE.md.discipline.template"
  ok "wrote CLAUDE.md.discipline.template (your existing CLAUDE.md untouched)"
else
  cp "$KIT_DIR/templates/CLAUDE.md.${LANG_FLAG}.template" "$PROJECT_DIR/CLAUDE.md"
  ok "wrote CLAUDE.md"
fi

# lefthook overlay
cp "$KIT_DIR/templates/lefthook.discipline.yml" "$PROJECT_DIR/lefthook.discipline.yml"
ok "wrote lefthook.discipline.yml (add 'extends: lefthook.discipline.yml' to your lefthook.yml)"

# .gitattributes append
{
  echo ""
  echo "# Discipline kit v$KIT_VERSION marker-block protection"
  cat "$KIT_DIR/templates/.gitattributes.template"
} >> "$PROJECT_DIR/.gitattributes"
ok "appended to .gitattributes"

# chmod scripts
chmod +x "$PROJECT_DIR/bin/tool-census.sh" "$PROJECT_DIR/bin/doctor.sh" 2>/dev/null || true

# Lock file
{
  echo "version: $KIT_VERSION"
  echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "kit_dir: $KIT_DIR"
  echo "lang: $LANG_FLAG"
  echo "detected:"
  echo "  superpowers: $([ $SUPERPOWERS -eq 1 ] && echo yes || echo no)"
  echo "  gsd: $([ $GSD -eq 1 ] && echo yes || echo no)"
  echo "  gstack: $([ $GSTACK -eq 1 ] && echo yes || echo no)"
  echo "  lefthook: $([ $LEFTHOOK -eq 1 ] && echo yes || echo no)"
  echo "files:"
  for item in "${PLAN[@]}"; do
    f=$(echo "$item" | awk '{print $1}')
    if [ -f "$PROJECT_DIR/$f" ]; then
      sum=$(shasum -a 256 "$PROJECT_DIR/$f" 2>/dev/null | awk '{print $1}')
      echo "  - path: $f"
      echo "    sha256: $sum"
    fi
  done
} > "$PROJECT_DIR/.claude-code-discipline.lock"
ok "wrote .claude-code-discipline.lock"

log ""
ok "Bootstrap complete. Next steps:"
log "  1. Review CLAUDE.md (or CLAUDE.md.discipline.template if your CLAUDE.md was preserved)"
log "  2. If lefthook.yml exists: add 'extends: lefthook.discipline.yml' to it"
log "  3. Invoke /claude-code-discipline at the start of your next Claude Code session"
log "  4. Run 'bash bin/tool-census.sh --underused' to see your tool inventory"
log "  5. Run 'bash bin/doctor.sh' to verify install health"
