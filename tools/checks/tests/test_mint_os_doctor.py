from __future__ import annotations

import plistlib
from pathlib import Path

from tools.checks import mint_os_doctor


def _write_plist(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as plist:
        plistlib.dump(data, plist)


def _write_repo(root: Path) -> None:
    mobile = root / "apps" / "mobile"
    (mobile / "test" / "patrol").mkdir(parents=True)
    (mobile / "test" / "patrol" / "mint_runtime_smoke_test.dart").write_text(
        "const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');\nvoid main() {}\n",
        encoding="utf-8",
    )
    (mobile / "pubspec.yaml").write_text(
        """
name: mint_mobile
dev_dependencies:
  patrol: ^4.6.1

patrol:
  app_name: Mint
  test_directory: test/patrol
  ios:
    bundle_id: ch.mint.app
""",
        encoding="utf-8",
    )
    for rel in (
        "tools/simulator/maestro_env.sh",
        "tools/simulator/maestro_with_watchdog.sh",
        "tools/checks/mermaid_render_guard.py",
        "tools/checks/claude_external_audit.sh",
        "docs/MINT_AGENT_WORKFLOW.md",
    ):
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    runbook = root / ".github" / "workflows" / "patrol.md"
    runbook.parent.mkdir(parents=True, exist_ok=True)
    runbook.write_text("--dart-define=MINT_PATROL_CLI=true\n", encoding="utf-8")
    release_plist = {
        "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mint"]}],
        "NSCameraUsageDescription": "camera",
    }
    debug_plist = {
        **release_plist,
        "NSBonjourServices": ["_dartobservatory._tcp", "_dartVmService._tcp", "_flutter-devtools._tcp"],
        "NSLocalNetworkUsageDescription": "debug local network",
    }
    _write_plist(root / "apps/mobile/ios/Runner/Info.plist", release_plist)
    _write_plist(root / "apps/mobile/ios/Runner/Info-Debug.plist", debug_plist)


def test_repo_only_doctor_passes_when_os_contract_files_exist(tmp_path: Path) -> None:
    _write_repo(tmp_path)

    results = mint_os_doctor.check_repo(tmp_path)

    assert {result.status for result in results} == {"pass"}


def test_repo_only_doctor_fails_when_patrol_contract_is_missing(tmp_path: Path) -> None:
    _write_repo(tmp_path)
    (tmp_path / "apps" / "mobile" / "pubspec.yaml").write_text(
        "name: mint_mobile\n",
        encoding="utf-8",
    )

    results = mint_os_doctor.check_repo(tmp_path)

    assert any(result.name == "repo.patrol" and result.status == "fail" for result in results)


def test_repo_only_doctor_fails_when_release_plist_contains_debug_network_keys(tmp_path: Path) -> None:
    _write_repo(tmp_path)
    _write_plist(
        tmp_path / "apps/mobile/ios/Runner/Info.plist",
        {
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mint"]}],
            "NSBonjourServices": ["_dartVmService._tcp"],
            "NSLocalNetworkUsageDescription": "debug only",
        },
    )

    results = mint_os_doctor.check_repo(tmp_path)

    assert any(result.name == "repo.ios_plist_split" and result.status == "fail" for result in results)


def test_host_doctor_accepts_pub_cache_patrol_and_beads(
    monkeypatch,
    tmp_path: Path,
) -> None:
    for rel in (
        ".pub-cache/bin/patrol",
        ".maestro/bin/maestro",
        ".local/bin/claude",
        "bin/npx",
        "bin/bd",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
        path.chmod(0o755)

    def fake_which(binary: str) -> str | None:
        if binary == "npx":
            return str(tmp_path / "bin" / "npx")
        if binary == "bd":
            return str(tmp_path / "bin" / "bd")
        if binary == "claude":
            return str(tmp_path / ".local" / "bin" / "claude")
        return None

    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(mint_os_doctor.shutil, "which", fake_which)
    monkeypatch.setattr(mint_os_doctor, "_run_version", lambda *args, **kwargs: "tool-version")

    results = mint_os_doctor.check_host(tmp_path)

    by_name = {result.name: result for result in results}
    assert by_name["host.patrol_cli"].status == "pass"
    assert by_name["host.maestro_cli"].status == "pass"
    assert by_name["host.mermaid_cli"].status == "pass"
    assert by_name["host.claude_cli"].status == "pass"
    assert by_name["host.beads_cli"].status == "pass"


def test_host_doctor_warns_when_beads_is_missing(
    monkeypatch,
    tmp_path: Path,
) -> None:
    for rel in (
        ".pub-cache/bin/patrol",
        ".maestro/bin/maestro",
        ".local/bin/claude",
        "bin/npx",
    ):
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
        path.chmod(0o755)

    def fake_which(binary: str) -> str | None:
        if binary == "npx":
            return str(tmp_path / "bin" / "npx")
        if binary == "claude":
            return str(tmp_path / ".local" / "bin" / "claude")
        return None

    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(mint_os_doctor.shutil, "which", fake_which)
    monkeypatch.setattr(mint_os_doctor, "_run_version", lambda *args, **kwargs: "tool-version")

    results = mint_os_doctor.check_host(tmp_path)

    by_name = {result.name: result for result in results}
    assert by_name["host.beads_cli"].status == "warn"
