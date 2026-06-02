"""Tests for tools/checks/ios_release_info_plist_drift.py."""
from __future__ import annotations

import importlib.util
import plistlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "ios_release_info_plist_drift.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("ios_release_info_plist_drift", SCRIPT)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _write_plist(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as fh:
        plistlib.dump(data, fh)


def _write_project(path: Path, *, debug_plist: str, release_refs: int = 2) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    release_lines = "\n".join(
        "INFOPLIST_FILE = Runner/Info.plist;" for _ in range(release_refs)
    )
    path.write_text(
        f'INFOPLIST_FILE = "{debug_plist}";\n{release_lines}\n',
        encoding="utf-8",
    )


def _patch_paths(monkeypatch, module, tmp_path: Path) -> tuple[Path, Path, Path]:
    runner_dir = tmp_path / "apps" / "mobile" / "ios" / "Runner"
    project = (
        tmp_path
        / "apps"
        / "mobile"
        / "ios"
        / "Runner.xcodeproj"
        / "project.pbxproj"
    )
    monkeypatch.setattr(module, "RUNNER_DIR", runner_dir)
    monkeypatch.setattr(module, "PROJECT", project)
    monkeypatch.setattr(module, "RELEASE_PLIST", runner_dir / "Info.plist")
    monkeypatch.setattr(module, "DEBUG_PLIST", runner_dir / "Info-Debug.plist")
    return runner_dir / "Info.plist", runner_dir / "Info-Debug.plist", project


def test_passes_when_debug_keys_are_debug_only(tmp_path, monkeypatch):
    module = _load_module()
    release_plist, debug_plist, project = _patch_paths(monkeypatch, module, tmp_path)

    _write_plist(release_plist, {"CFBundleName": "MINT"})
    _write_plist(
        debug_plist,
        {
            "CFBundleName": "MINT",
            "NSBonjourServices": ["_dartVmService._tcp"],
            "NSLocalNetworkUsageDescription": "Debug only.",
        },
    )
    _write_project(project, debug_plist="Runner/Info-Debug.plist")

    assert module.main() == 0


def test_fails_when_release_plist_contains_debug_keys(tmp_path, monkeypatch, capsys):
    module = _load_module()
    release_plist, debug_plist, project = _patch_paths(monkeypatch, module, tmp_path)

    _write_plist(release_plist, {"NSBonjourServices": ["_dartVmService._tcp"]})
    _write_plist(
        debug_plist,
        {
            "NSBonjourServices": ["_dartVmService._tcp"],
            "NSLocalNetworkUsageDescription": "Debug only.",
        },
    )
    _write_project(project, debug_plist="Runner/Info-Debug.plist")

    assert module.main() == 1
    assert "debug-only local-network key" in capsys.readouterr().err


def test_fails_when_debug_build_not_wired_to_debug_plist(
    tmp_path, monkeypatch, capsys
):
    module = _load_module()
    release_plist, debug_plist, project = _patch_paths(monkeypatch, module, tmp_path)

    _write_plist(release_plist, {"CFBundleName": "MINT"})
    _write_plist(
        debug_plist,
        {
            "NSBonjourServices": ["_dartVmService._tcp"],
            "NSLocalNetworkUsageDescription": "Debug only.",
        },
    )
    _write_project(project, debug_plist="Runner/Info.plist")

    assert module.main() == 1
    assert "Debug build is not wired" in capsys.readouterr().err
