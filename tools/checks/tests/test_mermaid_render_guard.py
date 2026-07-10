from __future__ import annotations

import json
import subprocess
from pathlib import Path

from tools.checks import mermaid_render_guard


def _root(tmp_path: Path) -> Path:
    diagrams = tmp_path / "docs/codex"
    diagrams.mkdir(parents=True)
    (diagrams / "WIRING_GRAPH.mmd").write_text("flowchart LR\n  A-->B\n", encoding="utf-8")
    return tmp_path


def test_mermaid_render_guard_writes_sandbox_config_and_checks_svg(monkeypatch, tmp_path: Path) -> None:
    root = _root(tmp_path)
    calls: list[list[str]] = []

    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: "/usr/bin/npx")

    def fake_run(args, cwd, text, capture_output, timeout):  # noqa: ANN001
        calls.append(args)
        puppeteer_config = Path(args[args.index("-p") + 1])
        output = Path(args[args.index("-o") + 1])
        assert cwd == root.resolve()
        assert text is True
        assert capture_output is True
        assert timeout == 120
        assert json.loads(puppeteer_config.read_text(encoding="utf-8")) == {
            "args": ["--no-sandbox", "--disable-setuid-sandbox"]
        }
        output.write_text("<svg>" + ("x" * 120) + "</svg>", encoding="utf-8")
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(mermaid_render_guard.subprocess, "run", fake_run)

    assert mermaid_render_guard.check(root) == []
    assert calls
    assert calls[0][:4] == ["npx", "-y", mermaid_render_guard.MERMAID_CLI, "-p"]


def test_mermaid_render_guard_requires_npx(monkeypatch, tmp_path: Path) -> None:
    root = _root(tmp_path)
    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: None)

    assert mermaid_render_guard.check(root) == ["npx is required to render MINT Mermaid diagrams"]


def test_mermaid_render_guard_reports_render_failure(monkeypatch, tmp_path: Path) -> None:
    root = _root(tmp_path)
    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: "/usr/bin/npx")

    def fake_run(args, cwd, text, capture_output, timeout):  # noqa: ANN001
        return subprocess.CompletedProcess(args, 1, "", "syntax error")

    monkeypatch.setattr(mermaid_render_guard.subprocess, "run", fake_run)

    errors = mermaid_render_guard.check(root)

    assert len(errors) == 1
    assert "WIRING_GRAPH.mmd failed to render: syntax error" in errors[0]


def test_mermaid_render_guard_rejects_empty_svg(monkeypatch, tmp_path: Path) -> None:
    root = _root(tmp_path)
    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: "/usr/bin/npx")

    def fake_run(args, cwd, text, capture_output, timeout):  # noqa: ANN001
        output = Path(args[args.index("-o") + 1])
        output.write_text("<svg></svg>", encoding="utf-8")
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(mermaid_render_guard.subprocess, "run", fake_run)

    errors = mermaid_render_guard.check(root)

    assert len(errors) == 1
    assert "produced an empty or invalid SVG" in errors[0]


def test_mermaid_render_guard_includes_optional_journey_diagrams(monkeypatch, tmp_path: Path) -> None:
    root = _root(tmp_path)
    optional = root / ".planning/journeys/diagrams"
    optional.mkdir(parents=True)
    (optional / "system_map.mmd").write_text("flowchart LR\n  B-->C\n", encoding="utf-8")
    rendered: list[str] = []

    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: "/usr/bin/npx")

    def fake_run(args, cwd, text, capture_output, timeout):  # noqa: ANN001
        diagram = Path(args[args.index("-i") + 1])
        output = Path(args[args.index("-o") + 1])
        rendered.append(str(diagram.relative_to(root)))
        output.write_text("<svg>" + ("x" * 120) + "</svg>", encoding="utf-8")
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(mermaid_render_guard.subprocess, "run", fake_run)

    assert mermaid_render_guard.check(root) == []
    assert rendered == [
        "docs/codex/WIRING_GRAPH.mmd",
        ".planning/journeys/diagrams/system_map.mmd",
    ]


def test_mermaid_render_guard_requires_wiring_graph(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(mermaid_render_guard.shutil, "which", lambda binary: "/usr/bin/npx")

    assert mermaid_render_guard.check(tmp_path) == [
        "missing required MINT Mermaid diagram: docs/codex/WIRING_GRAPH.mmd"
    ]
