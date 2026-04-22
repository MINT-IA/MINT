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

## Kill-switch

To disable the MCP server:
1. Remove `.mcp.json` from repo root.
2. `git revert` the CLAUDE.md trim commit.

See `.planning/phases/30.7-tools-d-terministes/30.7-04-SUMMARY.md` for
the exact commit hashes to revert.

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
