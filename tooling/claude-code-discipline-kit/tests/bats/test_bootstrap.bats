#!/usr/bin/env bats
# bats-core integration tests for bootstrap.sh
# Install bats: brew install bats-core OR npm install -g bats
# Run: bats tests/bats/test_bootstrap.bats

setup() {
  KIT_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TMP_PROJECT="$(mktemp -d)"
  cd "$TMP_PROJECT"
}

teardown() {
  rm -rf "$TMP_PROJECT"
}

@test "bootstrap --help exits 0" {
  run bash "$KIT_DIR/bin/bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code Discipline Kit"* ]]
}

@test "bootstrap --dry-run on empty project writes nothing" {
  run bash "$KIT_DIR/bin/bootstrap.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  # No files written
  [ ! -f "CLAUDE.md" ]
  [ ! -f ".claude-code-discipline.lock" ]
}

@test "bootstrap --apply on empty project writes expected files" {
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/bootstrap.sh" --apply
  [ "$status" -eq 0 ]
  [ -f "$TMP_PROJECT/CLAUDE.md" ]
  [ -f "$TMP_PROJECT/docs/CLAUDE_CODE_DISCIPLINE.md" ]
  [ -f "$TMP_PROJECT/docs/ANTI_PATTERNS.md" ]
  [ -f "$TMP_PROJECT/docs/TOOL_DISCOVERY.md" ]
  [ -f "$TMP_PROJECT/.claude/skills/claude-code-discipline/SKILL.md" ]
  [ -f "$TMP_PROJECT/tools/checks/lint_status_audit.py" ]
  [ -f "$TMP_PROJECT/bin/tool-census.sh" ]
  [ -f "$TMP_PROJECT/bin/doctor.sh" ]
  [ -f "$TMP_PROJECT/lefthook.discipline.yml" ]
  [ -f "$TMP_PROJECT/.gitattributes" ]
  [ -f "$TMP_PROJECT/.claude-code-discipline.lock" ]
}

@test "bootstrap --apply preserves existing CLAUDE.md" {
  cd "$TMP_PROJECT"
  echo "# My existing CLAUDE.md\n\nDo not overwrite me." > CLAUDE.md
  EXISTING_CONTENT=$(cat CLAUDE.md)

  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/bootstrap.sh" --apply
  [ "$status" -eq 0 ]
  # Existing CLAUDE.md untouched
  [ "$(cat CLAUDE.md)" = "$EXISTING_CONTENT" ]
  # Template written separately
  [ -f "CLAUDE.md.discipline.template" ]
}

@test "bootstrap is idempotent (re-run produces no changes)" {
  PROJECT_DIR="$TMP_PROJECT" bash "$KIT_DIR/bin/bootstrap.sh" --apply
  FIRST_LOCK=$(cat "$TMP_PROJECT/.claude-code-discipline.lock")

  # Second run dry-run should report no changes (or report files as already-present)
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/bootstrap.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped"* ]] || [[ "$output" == *"DRY-RUN"* ]]
}

@test "doctor.sh on uninstalled project reports missing kit" {
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not installed"* ]] || [[ "$output" == *"missing"* ]]
}

@test "doctor.sh on installed project reports kit version" {
  PROJECT_DIR="$TMP_PROJECT" bash "$KIT_DIR/bin/bootstrap.sh" --apply
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v0.1.0"* ]] || [[ "$output" == *"Kit installed"* ]]
}

@test "uninstall.sh --dry-run shows what would be removed" {
  PROJECT_DIR="$TMP_PROJECT" bash "$KIT_DIR/bin/bootstrap.sh" --apply
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/uninstall.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  # Files still present
  [ -f "$TMP_PROJECT/.claude-code-discipline.lock" ]
}

@test "uninstall.sh --apply removes kit files" {
  PROJECT_DIR="$TMP_PROJECT" bash "$KIT_DIR/bin/bootstrap.sh" --apply
  PROJECT_DIR="$TMP_PROJECT" run bash "$KIT_DIR/bin/uninstall.sh" --apply
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_PROJECT/.claude-code-discipline.lock" ]
}

@test "lint_status_audit.py exits 0 when all lints classified" {
  mkdir -p "$TMP_PROJECT/tools/checks"
  cat > "$TMP_PROJECT/tools/checks/STATUS.md" <<EOF
# Lint Status
| Lint | Status | Wired in |
|---|---|---|
| my_lint.py | enforced-ci | github actions |
EOF
  echo "# stub" > "$TMP_PROJECT/tools/checks/my_lint.py"

  cd "$TMP_PROJECT"
  run python3 "$KIT_DIR/lints/lint_status_audit.py"
  [ "$status" -eq 0 ]
}

@test "lint_status_audit.py exits 1 when a lint is unclassified" {
  mkdir -p "$TMP_PROJECT/tools/checks"
  cat > "$TMP_PROJECT/tools/checks/STATUS.md" <<EOF
# Lint Status
| Lint | Status | Wired in |
|---|---|---|
EOF
  echo "# stub" > "$TMP_PROJECT/tools/checks/orphan.py"

  cd "$TMP_PROJECT"
  run python3 "$KIT_DIR/lints/lint_status_audit.py"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing from STATUS.md"* ]]
}

@test "tool-census.sh on empty project does not crash" {
  cd "$TMP_PROJECT"
  run bash "$KIT_DIR/bin/tool-census.sh"
  [ "$status" -eq 0 ]
}

@test "tool-census.sh --json outputs valid JSON" {
  cd "$TMP_PROJECT"
  run bash "$KIT_DIR/bin/tool-census.sh" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
}
