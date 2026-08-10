from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "user_data_capture_contract.py"
SCREEN = "apps/mobile/lib/screens/profile/profile_screen.dart"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), "--changed-file", SCREEN],
        capture_output=True,
        text=True,
    )


def _write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _complete_fixture(root: Path) -> None:
    _write(
        root,
        SCREEN,
        "class ProfileScreen {}\nTextFormField();\nvoid persistProfile() {}\n"
        "void showProfile() {}\nvoid editProfile() {}\nvoid deleteProfile() {}\n",
    )
    _write(root, "apps/mobile/lib/providers/profile_provider.dart", "void consumeProfile() {}\n")
    _write(root, "apps/mobile/test/profile_lifecycle_test.dart", "void profileLifecycle() {}\n")
    contract = {
        "schema_version": 1,
        "capture": True,
        "fact_ids": ["profile.display_name"],
        "canonical_write_ref": f"{SCREEN}#persistProfile",
        "visibility_ref": f"{SCREEN}#showProfile",
        "edit_ref": f"{SCREEN}#editProfile",
        "delete_ref": f"{SCREEN}#deleteProfile",
        "external_consumer_refs": [
            "apps/mobile/lib/providers/profile_provider.dart#consumeProfile"
        ],
        "lifecycle_test_ref": "apps/mobile/test/profile_lifecycle_test.dart#profileLifecycle",
    }
    _write(root, f"{SCREEN}.capture.json", json.dumps(contract))


def test_fails_when_capture_primitive_has_no_contract(tmp_path: Path) -> None:
    _write(tmp_path, SCREEN, "class ProfileScreen {}\nTextFormField();\n")

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "missing capture contract" in proc.stderr


def test_fails_when_delete_reference_is_missing(tmp_path: Path) -> None:
    _complete_fixture(tmp_path)
    contract_path = tmp_path / f"{SCREEN}.capture.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    del contract["delete_ref"]
    contract_path.write_text(json.dumps(contract), encoding="utf-8")

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "delete_ref" in proc.stderr


def test_fails_when_external_consumers_are_missing(tmp_path: Path) -> None:
    _complete_fixture(tmp_path)
    contract_path = tmp_path / f"{SCREEN}.capture.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    contract["external_consumer_refs"] = []
    contract_path.write_text(json.dumps(contract), encoding="utf-8")

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "external_consumer_refs" in proc.stderr


def test_complete_capture_contract_passes(tmp_path: Path) -> None:
    _complete_fixture(tmp_path)

    proc = _run(tmp_path)

    assert proc.returncode == 0, proc.stderr
    assert "OK user_data_capture_contract" in proc.stderr


def test_capture_false_requires_reason_and_forbids_write_calls(tmp_path: Path) -> None:
    _write(
        tmp_path,
        SCREEN,
        "class ProfileScreen {}\nTextField();\nvoid saveProfile() {}\n",
    )
    _write(
        tmp_path,
        f"{SCREEN}.capture.json",
        json.dumps({"schema_version": 1, "capture": False, "reason": "Display-only input"}),
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "capture:false" in proc.stderr
    assert "write call" in proc.stderr


def test_capture_false_cannot_waive_canonical_merge_answers(tmp_path: Path) -> None:
    _write(
        tmp_path,
        SCREEN,
        "class ProfileScreen {}\nTextField();\nvoid submit() { provider.mergeAnswers({}); }\n",
    )
    _write(
        tmp_path,
        f"{SCREEN}.capture.json",
        json.dumps({"schema_version": 1, "capture": False, "reason": "Claimed display-only"}),
    )

    proc = _run(tmp_path)

    assert proc.returncode == 1
    assert "capture:false" in proc.stderr
    assert "write call" in proc.stderr
