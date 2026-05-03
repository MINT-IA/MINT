#!/usr/bin/env bash
# doctor.sh — Diagnose project's discipline state
# Reports what's installed, what's wired, what's missing, what's stale.

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

ok() { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ⚠ %s\n" "$*"; }
miss() { printf "  ✗ %s\n" "$*"; }
sect() { printf "\n[%s]\n" "$*"; }

cd "$PROJECT_DIR"

echo "Discipline Doctor — diagnosing $PROJECT_DIR"
echo ""

# Kit install state
sect "Kit install"
if [ -f .claude-code-discipline.lock ]; then
  VERSION=$(grep '^version:' .claude-code-discipline.lock | awk '{print $2}')
  INSTALLED=$(grep '^installed_at:' .claude-code-discipline.lock | awk '{print $2}')
  ok "Kit installed: v$VERSION at $INSTALLED"
else
  miss "No .claude-code-discipline.lock — kit not installed (run bootstrap.sh --apply)"
fi

# Disciplines doc
sect "Discipline docs"
[ -f docs/CLAUDE_CODE_DISCIPLINE.md ] && ok "docs/CLAUDE_CODE_DISCIPLINE.md present" || miss "docs/CLAUDE_CODE_DISCIPLINE.md missing"
[ -f docs/ANTI_PATTERNS.md ] && ok "docs/ANTI_PATTERNS.md present" || miss "docs/ANTI_PATTERNS.md missing"
[ -f docs/TOOL_DISCOVERY.md ] && ok "docs/TOOL_DISCOVERY.md present" || miss "docs/TOOL_DISCOVERY.md missing"

# Skill
sect "Skills"
if [ -f .claude/skills/claude-code-discipline/SKILL.md ]; then
  ok "claude-code-discipline skill installed"
else
  miss "claude-code-discipline skill missing — invoke via /claude-code-discipline won't work"
fi

if [ -d .claude/skills/using-superpowers ]; then
  ok "obra/superpowers detected — disciplines 1-7 deferred to it"
fi
if ls .claude/skills/ 2>/dev/null | grep -q "^gsd-"; then
  GSD_COUNT=$(ls .claude/skills/ 2>/dev/null | grep -c "^gsd-" || echo 0)
  ok "GSD framework detected ($GSD_COUNT skills) — discipline 9 R/P/I → gsd-*"
fi

# CLAUDE.md
sect "CLAUDE.md"
if [ -f CLAUDE.md ]; then
  ok "CLAUDE.md present"
  if grep -q "discipline:project-specific:begin" CLAUDE.md; then
    ok "Project-specific marker block present"
    if ! grep -q "discipline:project-specific:end" CLAUDE.md; then
      miss "Project-specific :begin without :end — broken marker, fix before lefthook fails"
    fi
  else
    warn "No discipline:project-specific marker block — kit upgrades may not preserve customizations"
  fi
else
  miss "No CLAUDE.md — Claude Code won't auto-load project context"
fi

# Lints
sect "Lints"
if [ -f tools/checks/lint_status_audit.py ]; then
  ok "lint_status_audit.py installed"
  if [ -f tools/checks/STATUS.md ]; then
    LINT_COUNT=$(ls tools/checks/*.py tools/checks/*.sh tools/checks/*.dart 2>/dev/null | wc -l | tr -d ' ')
    STATUS_COUNT=$(grep -c "^|" tools/checks/STATUS.md 2>/dev/null || echo 0)
    ok "tools/checks/STATUS.md present ($LINT_COUNT lints / $STATUS_COUNT documented entries)"
  else
    warn "tools/checks/STATUS.md missing — every lint must be classified (CI / pre-commit / manual)"
  fi
else
  miss "lint_status_audit.py missing"
fi

# Lefthook
sect "Lefthook"
if [ -f lefthook.yml ]; then
  ok "lefthook.yml present"
  if grep -q "lefthook.discipline.yml" lefthook.yml 2>/dev/null; then
    ok "lefthook.yml extends discipline overlay"
  else
    warn "lefthook.discipline.yml NOT extended — add 'extends: lefthook.discipline.yml' to your lefthook.yml"
  fi
fi
if [ -f lefthook.discipline.yml ]; then
  ok "lefthook.discipline.yml overlay installed"
else
  warn "No lefthook.discipline.yml — pre-commit gates from kit not active"
fi

# Tool census
sect "Tool census"
if [ -f bin/tool-census.sh ]; then
  ok "tool-census.sh installed"
  if [ -f .claude/usage/invocations.log ]; then
    LINES=$(wc -l < .claude/usage/invocations.log | tr -d ' ')
    ok ".claude/usage/invocations.log present ($LINES invocations logged)"
  else
    warn "No .claude/usage/invocations.log — tool utilization stats unavailable. See docs/TOOL_DISCOVERY.md"
  fi
else
  miss "tool-census.sh missing"
fi

# Evidence pattern
sect "Evidence (discipline 7)"
if [ -d .planning ]; then
  EVIDENCE_COUNT=$(find .planning -name "*VERIFICATION*.html" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$EVIDENCE_COUNT" -gt 0 ]; then
    ok ".planning/ has $EVIDENCE_COUNT verification HTML report(s)"
  else
    warn ".planning/ exists but no VERIFICATION-REPORT.html — evidence pattern not in use"
  fi
else
  warn "No .planning/ directory — discipline 7 (HTML evidence) not in use"
fi

# Summary
sect "Summary"
echo "  Run 'bash bin/tool-census.sh --underused' to surface unused tools."
echo "  Run 'bash bin/bootstrap.sh --apply' to upgrade kit components."
echo "  Read docs/CLAUDE_CODE_DISCIPLINE.md for the full 14 disciplines."
echo ""
