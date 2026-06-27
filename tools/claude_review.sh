#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/claude_review.sh [--cached] [--] [path...]

Runs a bounded Claude Code review on the current git diff.

Environment:
  MINT_CLAUDE_MODEL       Claude model alias, default: sonnet
  MINT_CLAUDE_TIMEOUT     timeout seconds, default: 900
  MINT_CLAUDE_MAX_BYTES   diff bytes sent to Claude, default: 12000
  MINT_CLAUDE_BUDGET_USD  optional print-mode budget cap, unset by default
  MINT_CLAUDE_OUTPUT      output format, default: json
  MINT_CLAUDE_TURNS       max turns, default: 5

Notes:
  - Intentionally does NOT use --bare. Local auth is claude.ai/keychain;
    --bare skips keychain/OAuth and requires ANTHROPIC_API_KEY/apiKeyHelper.
  - Uses print mode with JSON output by default. Codex reads the complete
    result field instead of relying on terminal streaming. Empty `result`
    is treated as failure because it usually means the turn ended on a
    tool call / hook / MCP interaction rather than a review message.
  - Disables Claude tool use/session persistence so reviews do not drift into
    MCP startup, repo exploration, or interactive agent behavior.
  - Keep file scopes tight. This is a review helper, not a full-repo auditor.
USAGE
}

cached=0
paths=()
while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --cached)
      cached=1
      shift
      ;;
    --)
      shift
      paths+=("$@")
      break
      ;;
    *)
      paths+=("$1")
      shift
      ;;
  esac
done

model="${MINT_CLAUDE_MODEL:-sonnet}"
timeout_seconds="${MINT_CLAUDE_TIMEOUT:-900}"
max_bytes="${MINT_CLAUDE_MAX_BYTES:-12000}"
budget_usd="${MINT_CLAUDE_BUDGET_USD:-}"
output_format="${MINT_CLAUDE_OUTPUT:-json}"
max_turns="${MINT_CLAUDE_TURNS:-5}"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH" >&2
  exit 127
fi

diff_args=()
if [[ "$cached" == "1" ]]; then
  diff_args+=(--cached)
fi
if ((${#paths[@]})); then
  diff_args+=(-- "${paths[@]}")
fi

diff_file="$(mktemp -t mint-claude-review-diff.XXXXXX)"
trap 'rm -f "$diff_file"' EXIT

if ((${#diff_args[@]})); then
  git diff "${diff_args[@]}" > "$diff_file"
else
  git diff > "$diff_file"
fi
if [[ ! -s "$diff_file" ]]; then
  echo "No diff to review." >&2
  exit 1
fi

diff_bytes="$(wc -c < "$diff_file" | tr -d ' ')"
truncated="no"
if ((diff_bytes > max_bytes)); then
  head -c "$max_bytes" "$diff_file" > "${diff_file}.truncated"
  mv "${diff_file}.truncated" "$diff_file"
  truncated="yes"
fi

review_prompt="Review this Mint diff for correctness, regressions, missing tests, security, and fintech trust issues. Focus on concrete blocking findings only.

Diff metadata:
bytes_sent=$(( diff_bytes > max_bytes ? max_bytes : diff_bytes ))
bytes_original=$diff_bytes
truncated=$truncated

Return:
- Blocking findings with file/line references, if any.
- Important non-blocking findings, if any.
- Missing high-risk tests, if any.
- Otherwise: \"No blocking findings.\""

claude_args=(
  -p
  --model "$model"
  --tools ""
  --disallowed-tools "mcp__plugin_engram_engram__*,Write,Edit,Bash"
  --no-session-persistence
  --output-format "$output_format"
  --permission-mode bypassPermissions
  --max-turns "$max_turns"
)
if [[ -n "$budget_usd" ]]; then
  claude_args+=(--max-budget-usd "$budget_usd")
fi

if [[ "$output_format" == "json" ]] && command -v jq >/dev/null 2>&1; then
  output_file="$(mktemp -t mint-claude-review-output.XXXXXX)"
  trap 'rm -f "$diff_file" "$output_file"' EXIT
  timeout "$timeout_seconds" claude "${claude_args[@]}" "$review_prompt" < "$diff_file" > "$output_file"
  result="$(jq -r '.result // empty' "$output_file")"
  if [[ -z "${result//[[:space:]]/}" ]]; then
    echo "Claude review produced empty JSON .result; raw output follows:" >&2
    cat "$output_file" >&2
    exit 2
  fi
  printf '%s\n' "$result"
else
  timeout "$timeout_seconds" claude "${claude_args[@]}" "$review_prompt" < "$diff_file"
fi
