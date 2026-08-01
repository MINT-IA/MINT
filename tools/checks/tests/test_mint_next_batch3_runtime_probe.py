from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
PROBE = REPO / "tools/checks/mint_next_batch3_runtime_probe.py"
HTML = Path("product/mint_next/batch3/prototype/index.html")


def run_mutation(tmp_path: Path, old: str, new: str) -> subprocess.CompletedProcess[str]:
    target = tmp_path / HTML
    target.parent.mkdir(parents=True)
    source = (REPO / HTML).read_text()
    assert old in source
    target.write_text(source.replace(old, new, 1))
    return subprocess.run(
        [sys.executable, str(PROBE), "--root", str(tmp_path)],
        capture_output=True,
        text=True,
        timeout=30,
    )


@pytest.mark.parametrize(
    ("old", "new"),
    [
        ("if(index<5){index++;render()}", "if(index<5){render()}"),
        ("overlay.classList.remove('hidden')", "overlay.classList.add('hidden')"),
        ("b:{cls:'direction-b',resultStep:3", "b:{cls:'direction-b',resultStep:4"),
        ("back.onclick=()=>{if(index>0){index--;render()}}", "back.onclick=()=>{if(index>0){state.corrections[dir]={};index--;render()}}"),
    ],
)
def test_runtime_probe_rejects_theatrical_or_broken_paths(tmp_path: Path, old: str, new: str):
    result = run_mutation(tmp_path, old, new)
    assert result.returncode == 1, result.stdout + result.stderr
