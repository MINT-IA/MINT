"""Tests for tools/checks/regulatory_freshness_monitor.py."""

from __future__ import annotations

import importlib.util
from datetime import timedelta
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "regulatory_freshness_monitor.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("regulatory_freshness_monitor", SCRIPT)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_monitor_passes_before_review_sla_expires(capsys):
    module = _load_module()
    latest_review = max(
        p.reviewed_at for p in module.RegulatoryRegistry.instance().get_all() if p.reviewed_at
    )

    rc = module.main(["--as-of", (latest_review + timedelta(days=90)).isoformat()])

    assert rc == 0
    assert "Regulatory freshness OK" in capsys.readouterr().out


def test_monitor_warns_without_failing_by_default(tmp_path, capsys):
    module = _load_module()
    markdown_out = tmp_path / "freshness.md"
    github_output = tmp_path / "github_output.txt"
    latest_review = max(
        p.reviewed_at for p in module.RegulatoryRegistry.instance().get_all() if p.reviewed_at
    )
    stale_date = (latest_review + timedelta(days=91)).isoformat()

    rc = module.main(
        [
            "--as-of",
            stale_date,
            "--markdown-out",
            str(markdown_out),
            "--github-output",
            str(github_output),
        ]
    )

    assert rc == 0
    captured = capsys.readouterr()
    assert "::warning::Regulatory constants review due" in captured.err
    assert "Regulatory Constants Review Due" in markdown_out.read_text(encoding="utf-8")
    github_lines = github_output.read_text(encoding="utf-8").splitlines()
    assert github_lines
    assert github_lines[0].startswith("stale_count=")
    assert int(github_lines[0].split("=", 1)[1]) > 0

    strict_rc = module.main(["--as-of", stale_date, "--strict"])
    assert strict_rc == 1
