#!/usr/bin/env bash
# mint-tools MCP launcher — auto-heals env so the server starts no matter
# what state pyenv / system python / venv is in. Idempotent.
#
# Strategy (first that works, in order):
#   1. existing .venv/bin/python (fast path)
#   2. python3.11 in PATH (pyenv shim or direct install)
#   3. pyenv direct prefix (/Users/$USER/.pyenv/versions/3.11.9/bin/python3.11)
#   4. /usr/bin/python3 (last-resort system)
#
# After picking python: ensure .venv exists with `mcp` installed. If not,
# bootstrap from requirements.txt.
#
# All output goes to stderr — the .mcp.json caller reads stdin/stdout as
# the JSON-RPC channel.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VENV="$SCRIPT_DIR/.venv"
VENV_PY="$VENV/bin/python"
REQ="$SCRIPT_DIR/requirements.txt"

log() { echo "[mint-tools-launcher] $*" >&2; }

# Find a python3.11 to bootstrap the venv with
find_bootstrap_python() {
  if command -v python3.11 >/dev/null 2>&1; then
    echo "python3.11"; return 0
  fi
  local pyenv_311="/Users/$USER/.pyenv/versions/3.11.9/bin/python3.11"
  if [ -x "$pyenv_311" ]; then
    echo "$pyenv_311"; return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    local v
    v=$(python3 -c 'import sys; print(sys.version_info[:2])' 2>/dev/null || echo "")
    case "$v" in
      "(3, 1"[0-9]*) echo "python3"; return 0 ;;
    esac
  fi
  return 1
}

# Verify a venv has the mcp module
venv_has_mcp() {
  [ -x "$VENV_PY" ] && "$VENV_PY" -c "import mcp" 2>/dev/null
}

if ! venv_has_mcp; then
  log "venv missing or broken, bootstrapping..."
  BOOTSTRAP_PY="$(find_bootstrap_python || true)"
  if [ -z "$BOOTSTRAP_PY" ]; then
    log "ERROR: no Python 3.10+ found. Install Python 3.11 (e.g. 'pyenv install 3.11.9') and retry."
    exit 1
  fi
  log "using $BOOTSTRAP_PY to create venv"
  rm -rf "$VENV"
  "$BOOTSTRAP_PY" -m venv "$VENV"
  "$VENV_PY" -m pip install --quiet --upgrade pip
  "$VENV_PY" -m pip install --quiet -r "$REQ"
  log "venv ready"
fi

# Self-test before handing off to the MCP runtime
if ! "$VENV_PY" -c "from mcp.server.fastmcp import FastMCP" 2>&1; then
  log "ERROR: venv exists but mcp module not importable. Wipe .venv and retry."
  exit 1
fi

# Hand off to the actual server. exec replaces this shell so signal handling
# is direct.
export PYTHONPATH="$REPO_ROOT/services/backend:$SCRIPT_DIR:${PYTHONPATH:-}"
exec "$VENV_PY" "$SCRIPT_DIR/server.py"
