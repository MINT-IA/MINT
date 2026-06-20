import json
import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools/simulator/mint2_real_device_restore_gate.sh"


def _device(name: str, tunnel: str, ddi: bool) -> dict:
    return {
        "identifier": "EA7D1126-5BAD-5005-818E-698D205196F1",
        "connectionProperties": {
            "tunnelState": tunnel,
        },
        "deviceProperties": {
            "name": name,
            "ddiServicesAvailable": ddi,
        },
        "hardwareProperties": {
            "marketingName": "iPhone 13 mini",
            "platform": "iOS",
            "reality": "physical",
            "serialNumber": "SHOULD_NOT_LEAK",
            "udid": "00008110-000E65903EA8201E",
            "ecid": 4052319874850846,
        },
    }


def _write_fixture(tmp_path: Path, devices: list[dict]) -> Path:
    fixture = tmp_path / "devicectl.json"
    fixture.write_text(json.dumps({"result": {"devices": devices}}))
    return fixture


def _run_gate(tmp_path: Path, fixture: Path) -> subprocess.CompletedProcess[str]:
    env = {
        **os.environ,
        "MINT2_DEVICECTL_JSON": str(fixture),
        "MINT2_REAL_DEVICE_ARTIFACTS": str(tmp_path / "evidence"),
        "MINT2_DEVICE_NAME": "Jul",
    }
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def test_real_device_restore_gate_blocks_when_target_device_is_unavailable(tmp_path):
    fixture = _write_fixture(tmp_path, [_device("Jul", "unavailable", False)])

    result = _run_gate(tmp_path, fixture)

    assert result.returncode == 2
    assert "VERDICT: BLOCKED_NO_AVAILABLE_DEVICE" in result.stdout
    verdict = json.loads((tmp_path / "evidence/verdict.json").read_text())
    assert verdict["restoreProofClaimed"] is False
    assert verdict["matchingPhysicalCount"] == 1
    assert verdict["matchingAvailableCount"] == 0


def test_real_device_restore_gate_redacts_device_identifiers(tmp_path):
    fixture = _write_fixture(tmp_path, [_device("Jul", "unavailable", False)])

    _run_gate(tmp_path, fixture)

    inventory_text = (tmp_path / "evidence/device-inventory-redacted.json").read_text()
    assert "SHOULD_NOT_LEAK" not in inventory_text
    assert "00008110-000E65903EA8201E" not in inventory_text
    assert "4052319874850846" not in inventory_text
    assert "identityHash" in inventory_text


def test_real_device_restore_gate_reports_ready_but_not_proven_when_device_available(
    tmp_path,
):
    fixture = _write_fixture(tmp_path, [_device("Jul", "connected", True)])

    result = _run_gate(tmp_path, fixture)

    assert result.returncode == 0
    assert "VERDICT: READY_FOR_MANUAL_RESTORE_PROOF" in result.stdout
    verdict = json.loads((tmp_path / "evidence/verdict.json").read_text())
    assert verdict["restoreProofClaimed"] is False
    assert verdict["matchingAvailableCount"] == 1


def test_real_device_restore_gate_dry_run_lists_contract():
    result = subprocess.run(
        ["bash", str(SCRIPT), "--dry-run"],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0
    assert "xcrun devicectl list devices" in result.stdout
    assert "device-inventory-redacted.json" in result.stdout
    assert "BLOCKED_NO_AVAILABLE_DEVICE" in result.stdout
