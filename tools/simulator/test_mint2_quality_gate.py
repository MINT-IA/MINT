#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "tools" / "simulator" / "mint2_quality_gate.sh"
CONTENT_FLOW = (
    ROOT
    / "tools"
    / "simulator"
    / "flows"
    / "maestro-perfect-set"
    / "flow_mint2_content_quality_surfaces.yaml"
)


def _read_gate() -> str:
    return GATE.read_text(encoding="utf-8")


def test_mint2_quality_gate_script_exists():
    assert GATE.is_file(), "Mint2 quality gate runner is missing"


def test_mint2_quality_gate_targets_exact_iphone13mini_staging():
    src = _read_gate()

    assert 'DEVICE_NAME="MINT iPhone 13 mini RvC"' in src
    assert "https://mint-staging.up.railway.app/api/v1" in src
    assert "shutdown all" in src
    assert 'boot "$DEVICE_UDID"' in src
    assert "keychain \"$DEVICE_UDID\" reset" in src
    assert "API_BASE_URL=http://127.0.0.1" not in src
    assert "API_BASE_URL=http://localhost" not in src


def test_mint2_quality_gate_combines_layout_and_committed_maestro_flows():
    src = _read_gate()

    required_fragments = [
        "mint2_first_experience_iphone13mini_layout_test.dart",
        'flutter test "$LAYOUT_TEST"',
        "flow_mint2_first_experience_rente_capital_entry.yaml",
        "flow_mint2_lpp_dossier_account_claim.yaml",
        "flow_mint2_content_quality_surfaces.yaml",
        "maestro_with_watchdog.sh",
        "MINT_E2E_MINT2_FIRST_EXPERIENCE=true",
        "MINT_E2E_PROOF_ANCHORS=true",
        "scrub_ios_build_xattrs",
        "clear_extended_attributes",
        "com.apple.provenance",
        "Debug-iphonesimulator/App.framework",
        "codesign --remove-signature",
        "collect_flow_evidence",
        "simctl-final-screen.png",
        "ax-idb-describe-all.json",
        "idb ui describe-all",
        ".planning/runtime-evidence/mint2-quality-gate-",
        "run-summary.txt",
    ]
    for fragment in required_fragments:
        assert fragment in src, f"quality gate missing: {fragment}"


def test_mint2_quality_gate_does_not_delete_stale_app_framework():
    src = _read_gate()

    assert "rm -rf apps/mobile/build/ios/Debug-iphonesimulator/App.framework" not in src
    assert 'rm -rf "$app_framework"' not in src


def test_mint2_quality_gate_simulator_app_open_is_non_blocking():
    src = _read_gate()

    assert "open -a Simulator || true" in src


def test_mint2_quality_gate_dry_run_lists_contract():
    result = subprocess.run(
        ["bash", str(GATE), "--dry-run"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "MINT iPhone 13 mini RvC" in result.stdout
    assert "mint2_first_experience_iphone13mini_layout_test.dart" in result.stdout
    assert "flow_mint2_lpp_dossier_account_claim.yaml" in result.stdout
    assert "flow_mint2_content_quality_surfaces.yaml" in result.stdout
    assert "https://mint-staging.up.railway.app/api/v1" in result.stdout
    assert "keychain <UDID> reset" in result.stdout
    assert "xattr -cr apps/mobile/build/ios" in result.stdout
    assert "simctl-final-screen.png" in result.stdout
    assert "ax-idb-describe-all.json" in result.stdout


def test_mint2_content_quality_flow_blocks_stale_financial_residue():
    src = CONTENT_FLOW.read_text(encoding="utf-8")

    required_fragments = [
        "flow_mint2_first_experience_rente_capital_entry.yaml",
        "mintapp:///coach/chat",
        "mintapp:///profile/bilan",
        "37'600",
        "6'640",
        "Avoir LPP",
        "Marge libre",
        "NaN",
        "Infinity",
        "A RenderFlex overflowed",
        "takeScreenshot",
    ]
    for fragment in required_fragments:
        assert fragment in src, f"content quality flow missing: {fragment}"
