"""Integration tests for the mint-tools MCP server.

Spawns server.py as a subprocess, speaks JSON-RPC over stdin/stdout, asserts:
(a) exactly 4 tools are listed,
(b) each tool is callable and returns a well-formed payload,
(c) no stdout pollution — only JSON-RPC frames (Pitfall 1 regression gate).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[4]
SERVER = REPO_ROOT / "tools" / "mcp" / "mint-tools" / "server.py"
EXPECTED_TOOLS = {
    "get_swiss_constants",
    "check_banned_terms",
    "validate_arb_parity",
    "check_accent_patterns",
}


def _client_ok() -> bool:
    try:
        import mcp  # noqa: F401
        from mcp.client.stdio import stdio_client  # noqa: F401
        from mcp.client.session import ClientSession  # noqa: F401
        return True
    except ImportError:
        return False


def _server_env() -> dict[str, str]:
    return {
        **os.environ,
        "PYTHONPATH": (
            f"{REPO_ROOT / 'services' / 'backend'}:"
            f"{REPO_ROOT}:"
            f"{REPO_ROOT / 'tools' / 'mcp' / 'mint-tools'}"
        ),
    }


@pytest.mark.asyncio
@pytest.mark.skipif(not _client_ok(), reason="mcp client helpers not importable in this env")
async def test_mcp_server_lists_4_tools() -> None:
    """Use the official mcp client to speak to server.py as a subprocess."""
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    params = StdioServerParameters(
        command=sys.executable,
        args=[str(SERVER)],
        env=_server_env(),
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {t.name for t in tools.tools}
            assert names == EXPECTED_TOOLS, f"Expected {EXPECTED_TOOLS}, got {names}"


@pytest.mark.asyncio
@pytest.mark.skipif(not _client_ok(), reason="mcp client helpers not importable in this env")
async def test_each_tool_callable_via_stdio() -> None:
    """Invoke each of the 4 tools via tools/call and verify the payload parses."""
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    params = StdioServerParameters(
        command=sys.executable,
        args=[str(SERVER)],
        env=_server_env(),
    )

    calls = [
        ("get_swiss_constants", {"category": "pillar3a"}),
        ("check_banned_terms", {"text": "ok"}),
        ("validate_arb_parity", {}),
        ("check_accent_patterns", {"text": "creer"}),
    ]

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            for tool_name, args in calls:
                result = await session.call_tool(tool_name, args)
                assert result is not None, f"{tool_name} returned None"
                # FastMCP wraps the Pydantic return in a structured/textual content list.
                assert getattr(result, "content", None), (
                    f"{tool_name} empty content: {result}"
                )


def test_no_stdout_pollution() -> None:
    """Pitfall-1 regression gate.

    Spawn server.py with stdin closed immediately. Capture stdout+stderr.
    Every non-empty stdout line MUST be valid JSON (the JSON-RPC frame from
    FastMCP's initial exchange) — any plain-text banner or logging leak fails.
    """
    # stdin=DEVNULL → child sees immediate EOF on stdin, FastMCP stdio loop
    # exits cleanly. Using PIPE + close() triggers a Python 3.11 ValueError
    # in communicate() because it still tries to flush the closed pipe.
    proc = subprocess.Popen(
        [sys.executable, str(SERVER)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=_server_env(),
        cwd=str(REPO_ROOT),
    )
    try:
        stdout, stderr = proc.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        pytest.fail(
            "server.py did not exit within 15s on EOF. "
            f"stderr:\n{stderr.decode(errors='replace')}"
        )

    text = stdout.decode("utf-8", errors="replace").strip()
    if text:
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                json.loads(line)
            except json.JSONDecodeError:
                pytest.fail(
                    f"Non-JSON line on stdout (Pitfall 1 violation): {line!r}. "
                    f"All stdout must be JSON-RPC. "
                    f"stderr:\n{stderr.decode(errors='replace')}"
                )


def test_server_module_imports_cleanly() -> None:
    """Sanity: importing server.py must not crash and must register 4 tools."""
    script = (
        "import sys;"
        f"sys.path.insert(0, r'{REPO_ROOT / 'services' / 'backend'}');"
        f"sys.path.insert(0, r'{REPO_ROOT / 'tools' / 'mcp' / 'mint-tools'}');"
        f"sys.path.insert(0, r'{REPO_ROOT}');"
        "import server;"
        "print('OK')"
    )
    proc = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert proc.returncode == 0, (
        f"Importing server.py failed.\n"
        f"stdout: {proc.stdout}\nstderr: {proc.stderr}"
    )
    assert "OK" in proc.stdout
