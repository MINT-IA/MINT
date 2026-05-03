#!/usr/bin/env bash
# uninstall.sh — Clean removal of the kit
# Reads .claude-code-discipline.lock to know exactly which files to remove.
# Project-specific marker block content (between discipline:project-specific:begin/end)
# is PRESERVED in CLAUDE.md.

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
MODE="dry-run"

usage() {
  cat <<EOF
Claude Code Discipline Kit — uninstall

USAGE:
  bash bin/uninstall.sh [--dry-run|--apply] [--keep-claude-md] [--help]

OPTIONS:
  --dry-run         (default) Show what would be removed
  --apply           Actually remove
  --keep-claude-md  Don't touch CLAUDE.md (preserve all of it; you'll have orphan kit references)
  --help            Show this help

The uninstall reads .claude-code-discipline.lock to know exactly which files
the kit installed. Files added by you (project-specific scripts, your skills,
your lints, your CLAUDE.md project-specific markers) are NEVER removed.
EOF
}

KEEP_CLAUDE_MD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --apply) MODE="apply"; shift ;;
    --keep-claude-md) KEEP_CLAUDE_MD=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

cd "$PROJECT_DIR"

if [ ! -f .claude-code-discipline.lock ]; then
  echo "No .claude-code-discipline.lock found. Kit not installed in $PROJECT_DIR." >&2
  echo "If you installed without lock file, manual removal required." >&2
  exit 1
fi

VERSION=$(grep '^version:' .claude-code-discipline.lock | awk '{print $2}')
echo "Uninstalling Claude Code Discipline Kit v$VERSION from $PROJECT_DIR"
echo "Mode: $MODE"
echo ""

# Read files from lock
FILES=$(grep '^  - path:' .claude-code-discipline.lock | awk '{print $3}')

echo "Will remove ${MODE}:"
for f in $FILES; do
  if [ -f "$f" ]; then
    echo "  - $f"
  fi
done

if [ $KEEP_CLAUDE_MD -eq 0 ]; then
  if [ -f CLAUDE.md ] && grep -q "discipline:" CLAUDE.md; then
    echo "  - CLAUDE.md (kit-managed sections only — project-specific marker content PRESERVED)"
  fi
fi

echo ""

if [ "$MODE" = "dry-run" ]; then
  echo "DRY-RUN — nothing removed. Re-run with --apply."
  exit 0
fi

# Apply
for f in $FILES; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "  removed: $f"
  fi
done

# Strip kit-managed sections from CLAUDE.md, preserve project-specific block
if [ $KEEP_CLAUDE_MD -eq 0 ] && [ -f CLAUDE.md ] && grep -q "discipline:" CLAUDE.md; then
  # Save the project-specific block
  PROJECT_BLOCK=$(awk '/discipline:project-specific:begin/,/discipline:project-specific:end/' CLAUDE.md)
  if [ -n "$PROJECT_BLOCK" ]; then
    {
      echo "# CLAUDE.md"
      echo ""
      echo "> The Claude Code Discipline Kit was uninstalled. Your project-specific rules below are preserved."
      echo ""
      echo "$PROJECT_BLOCK"
    } > CLAUDE.md
    echo "  CLAUDE.md: kit-managed sections removed, project-specific block preserved"
  else
    rm -f CLAUDE.md
    echo "  CLAUDE.md: removed (no project-specific block to preserve)"
  fi
fi

# Remove lock
rm -f .claude-code-discipline.lock
echo "  removed: .claude-code-discipline.lock"

# Optional: remove .gitattributes lines we appended
# (Conservative: warn rather than auto-edit)
if grep -q "Discipline kit v" .gitattributes 2>/dev/null; then
  echo ""
  echo "⚠ .gitattributes still has discipline-kit lines. Remove manually if desired."
fi

echo ""
echo "Uninstall complete."
