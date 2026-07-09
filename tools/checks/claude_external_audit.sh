#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'EOF'
Usage:
  tools/checks/claude_external_audit.sh code <base-ref>
  tools/checks/claude_external_audit.sh specs
  tools/checks/claude_external_audit.sh architecture

Env: CLAUDE_AUDIT_MODEL, CLAUDE_AUDIT_EFFORT, CLAUDE_AUDIT_ALLOW_MAX,
CLAUDE_AUDIT_WORKTREE, CLAUDE_AUDIT_BARE, CLAUDE_AUDIT_SETTINGS,
CLAUDE_AUDIT_SETTING_SOURCES, CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS,
CLAUDE_AUDIT_MAX_BUDGET_USD, CLAUDE_AUDIT_MAX_DIFF_LINES,
CLAUDE_AUDIT_ALLOW_LARGE_DIFF, CLAUDE_AUDIT_RERUN,
CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN, CLAUDE_AUDIT_DRY_RUN.
EOF
}
die() {
  echo "claude_external_audit: $*" >&2
  exit 2
}
mode="${1:-}"
case "$mode" in
  -h|--help|"")
    usage
    exit 0
    ;;
  code|specs|architecture)
    ;;
  *)
    usage >&2
    die "unknown mode '$mode'"
    ;;
esac
[[ -n "${CLAUDE_AUDIT_MAX_TURNS:-}" ]] && die "CLAUDE_AUDIT_MAX_TURNS is not supported by the installed Claude CLI; bound the prompt instead"
rerun="${CLAUDE_AUDIT_RERUN:-0}"
case "$rerun" in 0|1) ;; *) die "CLAUDE_AUDIT_RERUN must be 0 or 1" ;; esac
if [[ -n "${CLAUDE_AUDIT_MODEL:-}" ]]; then
  model="$CLAUDE_AUDIT_MODEL"
elif [[ "$rerun" == "1" ]]; then
  model="sonnet"
else
  model="opus"
fi
effort="${CLAUDE_AUDIT_EFFORT:-high}"
case "$effort" in low|medium|high|xhigh|max) ;; *) die "unsupported effort '$effort'" ;; esac
if [[ "$effort" == "max" && "${CLAUDE_AUDIT_ALLOW_MAX:-}" != "1" ]]; then
  die "refusing --effort max without CLAUDE_AUDIT_ALLOW_MAX=1; use high for bounded PR audits"
fi
if [[ "$rerun" == "1" && "$model" != *sonnet* && "${CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN:-}" != "1" ]]; then
  die "CLAUDE_AUDIT_RERUN=1 must use a sonnet model; reserve non-sonnet reruns for final confirmation/P0 disputes with CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1"
fi
repo_root="$(git rev-parse --show-toplevel)"
worktree="${CLAUDE_AUDIT_WORKTREE:-$repo_root}"
max_diff_lines="${CLAUDE_AUDIT_MAX_DIFF_LINES:-2500}"
case "$max_diff_lines" in ""|*[!0-9]*) die "CLAUDE_AUDIT_MAX_DIFF_LINES must be a non-negative integer" ;; esac
setting_sources="${CLAUDE_AUDIT_SETTING_SOURCES:-user}"
case "${CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS:-0}" in
  0|1) ;;
  *) die "CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS must be 0 or 1" ;;
esac
IFS=',' read -r -a setting_source_parts <<< "$setting_sources"
for setting_source in "${setting_source_parts[@]}"; do
  case "$setting_source" in
    user) ;;
    project|local)
      if [[ "${CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS:-0}" != "1" ]]; then
        die "project/local settings can load repo hooks; keep CLAUDE_AUDIT_SETTING_SOURCES=user or set CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS=1 for a named debug run"
      fi
      ;;
    *)
      die "CLAUDE_AUDIT_SETTING_SOURCES must be a comma-separated list of user,project,local"
      ;;
  esac
done
prompt_file="$(mktemp "${TMPDIR:-/tmp}/mint-claude-audit.XXXXXX")"
trap 'rm -f "$prompt_file"' EXIT

count_diff_lines() {
  git -C "$repo_root" diff "$@" | wc -l | tr -d '[:space:]'
}

enforce_code_diff_budget() {
  local base_ref="$1"
  local branch_lines staged_lines unstaged_lines total_lines
  branch_lines="$(count_diff_lines --no-ext-diff --unified=80 "${base_ref}...HEAD")"
  staged_lines="$(count_diff_lines --cached --no-ext-diff --unified=80)"
  unstaged_lines="$(count_diff_lines --no-ext-diff --unified=80)"
  total_lines=$((branch_lines + staged_lines + unstaged_lines))

  if (( total_lines > max_diff_lines )) && [[ "${CLAUDE_AUDIT_ALLOW_LARGE_DIFF:-}" != "1" ]]; then
    die "diff prompt is ${total_lines} lines, above CLAUDE_AUDIT_MAX_DIFF_LINES=${max_diff_lines}; split the PR or set CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1 for a named final-release/P0 dispute"
  fi
}

write_header() {
  local audit_mode="$1"
  cat >"$prompt_file" <<EOF
You are the MINT external auditor.

Audit mode: ${audit_mode}
Repo root: ${repo_root}

Hard rules:
- Treat checked-in code and tests as source of truth; do not trust docs blindly.
- Return exactly one verdict: PASS or NO-GO.
- Findings must be grouped as P0/P1/P2 with file:line evidence when possible.
- P0/P1 findings must include a concrete reproduction or code path.
- Ignore speculative rewrites; focus on correctness, privacy, compliance, routing, tests, and facade-without-wiring risks.
- If evidence is missing, say what command or file would prove it.

EOF
}

case "$mode" in
  code)
    base_ref="${2:-}"
    [[ -n "$base_ref" ]] || die "code mode requires a base ref"
    git -C "$repo_root" rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null || die "unknown base ref '$base_ref'"
    enforce_code_diff_budget "$base_ref"
    write_header "code"
    {
      echo "Base ref: ${base_ref}"
      echo "Diff line budget: ${max_diff_lines} lines (override requires CLAUDE_AUDIT_ALLOW_LARGE_DIFF=1)."
      echo
      echo "Current branch/status:"
      echo '```text'
      git -C "$repo_root" status --short --branch
      echo '```'
      echo
      echo "Diff stat:"
      echo '```text'
      git -C "$repo_root" diff --stat "${base_ref}...HEAD"
      echo '```'
      echo
      echo "Full diff:"
      echo '```diff'
      git -C "$repo_root" diff --no-ext-diff --unified=80 "${base_ref}...HEAD"
      echo '```'
      echo
      echo "Staged worktree diff:"
      echo '```diff'
      git -C "$repo_root" diff --cached --no-ext-diff --unified=80
      echo '```'
      echo
      echo "Unstaged worktree diff:"
      echo '```diff'
      git -C "$repo_root" diff --no-ext-diff --unified=80
      echo '```'
    } >>"$prompt_file"
    ;;
  specs)
    write_header "specs"
    cat >>"$prompt_file" <<'EOF'
Audit the five executable specs under docs/codex/ against live repo code:
- DATA_LEDGER.md
- SCREEN_CONTRACTS.md
- WIRING_GRAPH.mmd
- DATA_QUEST.md
- MAESTRO_FLOWS.md

Start with WIRING_GRAPH.mmd invariants. For each cited file:line, API, route,
key, and invariant, classify verified / obsolete / false with code evidence.
EOF
    ;;
  architecture)
    write_header "architecture"
    cat >>"$prompt_file" <<'EOF'
Audit the current architecture decision or phase evidence. Read AGENTS.md,
CLAUDE.md, docs/MINT_AGENT_WORKFLOW.md, and the files referenced by the
caller. Challenge docs against live code and report unresolved P0/P1 risks.
EOF
    ;;
esac

claude_args=(-p --model "$model" --effort "$effort" --safe-mode
  --strict-mcp-config --mcp-config '{"mcpServers":{}}'
  --disable-slash-commands --no-session-persistence
  --setting-sources "$setting_sources"
  --permission-mode dontAsk --tools Read,Grep,Bash --add-dir "$worktree"
  --exclude-dynamic-system-prompt-sections)

[[ -n "${CLAUDE_AUDIT_MAX_BUDGET_USD:-}" ]] && claude_args+=(--max-budget-usd "$CLAUDE_AUDIT_MAX_BUDGET_USD")
[[ -n "${CLAUDE_AUDIT_SETTINGS:-}" ]] && claude_args+=(--settings "$CLAUDE_AUDIT_SETTINGS")

if [[ "${CLAUDE_AUDIT_BARE:-}" == "1" ]]; then
  if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${CLAUDE_AUDIT_SETTINGS:-}" ]]; then
    die "--bare skips OAuth/keychain; set ANTHROPIC_API_KEY or CLAUDE_AUDIT_SETTINGS with apiKeyHelper"
  fi
  claude_args+=(--bare)
fi

if [[ "${CLAUDE_AUDIT_DRY_RUN:-}" == "1" ]]; then
  # CI validates this path; live Claude auth/flag drift is checked by reviewers.
  printf 'claude'
  printf ' %q' "${claude_args[@]}"
  printf '\n'
  echo '--- PROMPT_BEGIN ---'
  cat "$prompt_file"
  echo '--- PROMPT_END ---'
  exit 0
fi

claude "${claude_args[@]}" <"$prompt_file"
