from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def _mode_body(script: str, mode: str) -> str:
    marker = f"  {mode})"
    start = script.index(marker)
    return script[start : script.index("    ;;\n", start)]


def test_architecture_audit_includes_gate_and_crosswalk_proofs() -> None:
    script = (ROOT / "tools/checks/claude_external_audit.sh").read_text()
    body = _mode_body(script, "architecture")

    assert "docs/codex/DATA_LEDGER_GATE_SPEC.md" in body
    assert "services/backend/app/services/confidence/source_crosswalk.py" in body
    assert "tools/checks/tests/test_source_crosswalk.py" in body
    assert "tools/checks/tests/test_codex_ledger_parity.py" in body
    assert "tools/checks/tests/test_patrol_p0_gate_contract.py" in body
    assert "services/backend/app/api/v1/endpoints/coach_chat.py" in body
    assert "services/backend/tests/test_save_fact_tool.py" in body
    assert "apps/mobile/lib/services/financial_core/property_transmission_calculator.dart" in body
    assert "apps/mobile/lib/services/dossier/dossier_payload_service.dart" in body
    assert "apps/mobile/test/services/dossier/dossier_payload_service_test.dart" in body
    assert "apps/mobile/lib/screens/simulator_3a_screen.dart" in body
    assert "apps/mobile/lib/services/local_profile_owner_service.dart" in body
    assert "apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart" in body
    assert "apps/mobile/lib/providers/coach_profile_provider.dart" in body
    assert "apps/mobile/test/screens/simulator_3a_fatca_screen_test.dart" in body
    assert "apps/mobile/test/patrol/transmit_property_patrol_test.dart" in body
    assert "apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart" in body
    assert "apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart" in body
    assert "apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart" in body
    assert "apps/mobile/test/routing/no_domain_data_in_extra_test.dart" in body
    assert "apps/mobile/lib/providers/scan_session_provider.dart" in body
    assert "docs/codex/P0_CASE_VARIABLE_REGISTRY.json" in body
    assert "docs/codex/ANDROID_RUNTIME_BLOCKERS.md" in body
    assert ".github/workflows/android-runtime-patrol.yml" in body
    assert "apps/mobile/ios/mint_xcode_tools/codesign" in body
    assert "tools/checks/ios_simulator_build_with_mint_codesign.sh" in body
