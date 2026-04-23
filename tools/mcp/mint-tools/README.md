# mint-tools — Dev-time MCP server

Dev-time MCP (Model Context Protocol) server exposing four deterministic
tools to Claude Code agents working in this repository. Tools replace the
full-text constants and lint tables that used to live in `CLAUDE.md`,
trading ~16k always-loaded tokens for on-demand invocation.

## Tools shipped

| Name                      | Purpose                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `get_swiss_constants`     | Returns versioned LPP / AVS / 3a / mortgage / tax constants from `RegulatoryRegistry`.     |
| `check_banned_terms`      | Wraps `ComplianceGuard` Layer 1 — detects LSFin-prohibited phrasing and proposes rewrites. |
| `validate_arb_parity`     | Wraps `tools/checks/arb_parity.py` (Phase 34). Graceful fallback until Phase 34 ships.     |
| `check_accent_patterns`   | Wraps `tools/checks/accent_lint_fr.py` — flags ASCII-flattened French accents.             |

Runtime: Python 3.11+, stdio transport, single-process. No network I/O.

## Install (Python 3.11 required)

Host `python3` is 3.9.6 on macOS Tahoe — the `mcp` SDK needs >=3.10.
We pin to 3.11 via pyenv so the interpreter is reproducible.

```bash
# from tools/mcp/mint-tools/
python3.11 --version           # expect 3.11.x
python3.11 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
```

`.venv/` is gitignored both in this directory and at the repo root.

## Verify install

```bash
.venv/bin/python -c "import mcp; print(mcp.__version__)"   # expect >=1.9, <2.0
```

## Run tests

```bash
.venv/bin/pytest tests/ -q
```

The first test to run is `test_interpreter_version.py`, which fails
loud if pytest was launched under Python <3.10.

## First-run (Claude Code)

On the first Claude Code session after this phase ships, an approval prompt
appears for the project-scope MCP server. Click **Accept** once. Subsequent
sessions load `mint-tools` automatically.

If the prompt is dismissed or denied, the 4 tools become invisible to agents
and they silently fall back to CLAUDE.md body — but CLAUDE.md has been trimmed
in Wave 3 (Plan 30.7-04). Recovery:

1. Reopen Claude Code in the repo root.
2. Accept the prompt.
3. Confirm tool discovery: start a fresh session and ask the agent to call
   `get_swiss_constants("pillar3a")`. A non-empty constants list proves the
   server is live.

## Verify the server locally (no Claude Code)

```bash
cd tools/mcp/mint-tools
.venv/bin/pytest tests/test_server_integration.py -v
```

All tests green means the server is correctly wired. The gate is
`test_no_stdout_pollution` — if it fails, the server leaks non-JSON to stdout
and Claude Code will report `Connection closed` or `malformed JSON` at session
start.

Smoke alternative:

```bash
.venv/bin/python server.py </dev/null ; echo "exit=$?"
```

Should return `exit=0` within ~1 s (the cold-start cost is dominated by
ComplianceGuard's HallucinationDetector init, measured at ~150 ms on the
reference host — see 30.7-01-SUMMARY.md).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ModuleNotFoundError: mcp` when Claude Code starts | `python3.11` on PATH lacks the `mcp` SDK | Install `mcp>=1.9,<2.0` in that interpreter, OR edit `.mcp.json` to point `command` at this sub-project's venv: `tools/mcp/mint-tools/.venv/bin/python3.11` |
| `python3.11: command not found` | pyenv global is `system`; shim unresolved | `pyenv global 3.11.9` (or add local `.python-version`). Alternative: use absolute path to `~/.pyenv/versions/3.11.9/bin/python3.11` in `.mcp.json`. |
| `ModuleNotFoundError: app` at first tool call | `PYTHONPATH` drifted or MCP server spawned from wrong cwd | Verify `.mcp.json` `env.PYTHONPATH` contains `./services/backend`. The server.py also performs a defensive `sys.path.insert` so standalone launches work. |
| `Connection closed` / `malformed JSON-RPC` | stdout pollution (Pitfall 1) | Run `.venv/bin/pytest tests/test_server_integration.py::test_no_stdout_pollution -v` — it captures the leak with context. |

## Kill-switch

To disable the MCP server and restore the pre-Phase-30.7 context:

1. **Unregister the server:** `mv .mcp.json .mcp.json.disabled` (or `rm .mcp.json`).
2. **Restore CLAUDE.md body:** `git revert <trim-commit-sha>` — see the Wave 3
   SUMMARY for the commit SHA.
3. Restart Claude Code. Agents now see the full CLAUDE.md again.

The Python code stays on disk for a retry. No data loss.

See `.planning/phases/30.7-tools-d-terministes/30.7-04-SUMMARY.md` for
the exact commit hashes to revert once Wave 3 ships.

## Layout

```
tools/mcp/mint-tools/
  pyproject.toml         # pytest config + package metadata
  requirements.txt       # pinned mcp, pydantic, pytest
  .gitignore             # venv + caches
  README.md              # this file
  .venv/                 # local venv (gitignored)
  tests/                 # pytest suite
    __init__.py
    conftest.py
    test_interpreter_version.py
    test_accent_lint_scan_text.py
    measure_context_budget.py
    .claude_md_baseline.json
```

Tool source modules (`server.py`, `tools/*.py`) land in Wave 1. This
Wave 0 package only carries the scaffolding required to host them.
