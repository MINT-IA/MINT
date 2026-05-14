#!/bin/bash
# Engram weekly digest → Discord #engram-exports (vibe-coding infra Phase 1)
#
# Pipes top-10 most-recent findings from engram (project=mint-ia-mint) into a
# Discord webhook message. Triggered by LaunchAgent timer (weekly Monday 09:00)
# OR manually: `bash tools/scripts/engram-export-discord.sh`
#
# Reads webhook URL from ~/.gstack/secrets/discord-engram-webhook (mode 600).
# Reads ENGRAM_DATA_DIR from ~/.zshrc (default /Volumes/FUN2/engram on Mac mini).

set -euo pipefail

WEBHOOK_FILE="$HOME/.gstack/secrets/discord-engram-webhook"
ENGRAM_BIN="${ENGRAM_BIN:-$HOME/.local/bin/engram}"
ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-/Volumes/FUN2/engram}"
PROJECT="${PROJECT:-mint-ia-mint}"
LIMIT="${LIMIT:-10}"

if [ ! -f "$WEBHOOK_FILE" ]; then
  echo "ERROR: webhook URL not found at $WEBHOOK_FILE" >&2
  exit 1
fi

if [ ! -x "$ENGRAM_BIN" ]; then
  echo "ERROR: engram binary not found at $ENGRAM_BIN" >&2
  exit 1
fi

WEBHOOK_URL=$(cat "$WEBHOOK_FILE")
export ENGRAM_DATA_DIR

# Get stats (count of findings) + recent findings
STATS=$("$ENGRAM_BIN" stats --project "$PROJECT" 2>/dev/null || echo "stats unavailable")
RECENT=$("$ENGRAM_BIN" search "" --project "$PROJECT" --limit "$LIMIT" 2>/dev/null || echo "search failed")

DATE=$(date '+%Y-%m-%d %H:%M')

# Build digest message (Discord 2000 char limit, truncate if needed)
DIGEST=$(cat <<EOF
**Engram digest — $DATE** (project: \`$PROJECT\`)

$STATS

**Top $LIMIT recent findings**:
\`\`\`
$RECENT
\`\`\`

_Source: Mac mini \`$ENGRAM_DATA_DIR\` · Inspect full DB via \`engram tui\` on Mac mini._
EOF
)

# Truncate to 1900 chars (leave headroom)
if [ ${#DIGEST} -gt 1900 ]; then
  DIGEST="${DIGEST:0:1850}...\n_(truncated; full log in engram TUI)_"
fi

# POST to webhook
PAYLOAD=$(python3 -c "
import json, sys, os
content = os.environ.get('DIGEST', '')
print(json.dumps({'content': content, 'username': 'engram-digest-bot'}))
" DIGEST="$DIGEST")

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Engram digest posted to Discord"
