from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "claude_hooks_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_valid_fixture(root: Path) -> None:
    hooks_dir = root / ".claude/hooks"
    hooks_dir.mkdir(parents=True)
    (hooks_dir / "guard.js").write_text("console.log('ok');\n", encoding="utf-8")
    settings = {
        "hooks": {
            "PreToolUse": [
                {
                    "matcher": "Bash",
                    "hooks": [
                        {
                            "type": "command",
                            "command": "node .claude/hooks/guard.js",
                        }
                    ],
                }
            ]
        },
        "permissions": {
            "deny": [
                "Bash(git reset --hard:*)",
                "Bash(git checkout --:*)",
                "Bash(git clean:*)",
                "Bash(git push --force:*)",
                "Bash(rm -rf:*)",
                "Bash(claude --bare:*)",
                "Bash(claude --dangerously-skip-permissions:*)",
            ]
        },
    }
    (root / ".claude/settings.json").write_text(
        json.dumps(settings),
        encoding="utf-8",
    )


def test_guard_passes_for_portable_hook_config(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK claude_hooks_guard" in proc.stderr


def test_guard_fails_for_absolute_node_runtime(tmp_path: Path) -> None:
    _write_valid_fixture(tmp_path)
    settings_path = tmp_path / ".claude/settings.json"
    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    settings["hooks"]["PreToolUse"][0]["hooks"][0][
        "command"
    ] = '"/Users/julienbattaglia/.nvm/versions/node/v22.22.2/bin/node" .claude/hooks/guard.js'
    settings_path.write_text(json.dumps(settings), encoding="utf-8")

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "absolute Node runtime" in proc.stderr

