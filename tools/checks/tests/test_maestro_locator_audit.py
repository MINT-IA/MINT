import importlib.util
from pathlib import Path


def _load_module():
    module_path = Path(__file__).resolve().parents[1] / "maestro_locator_audit.py"
    spec = importlib.util.spec_from_file_location("maestro_locator_audit", module_path)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_dynamic_date_picker_locators_are_supported():
    audit = _load_module()

    assert audit.codebase_has_text(".*15.*juillet.*1992.*")
    assert audit.codebase_has_text("15.07.1992")


def test_unrelated_missing_locator_still_fails():
    audit = _load_module()

    assert not audit.codebase_has_text(".*not-a-real-mint-locator-2099.*")


def test_inline_maestro_object_locators_are_parsed_as_ids_not_text(tmp_path: Path):
    audit = _load_module()
    flow = tmp_path / "flow.yaml"
    flow.write_text(
        """
appId: ch.mint.app
---
- assertVisible: { id: "onboarding-bifurcation-continue" }
- tapOn: { id: "onboarding-canton-vd" }
- tapOn: { point: "50%,69%" }
""",
        encoding="utf-8",
    )

    texts, ids = audit.collect_locators(flow)

    assert texts == set()
    assert ids == {"onboarding-bifurcation-continue", "onboarding-canton-vd"}


def test_dynamic_value_key_templates_cover_e2e_and_axis_ids():
    audit = _load_module()

    assert audit.codebase_has_key("onboarding-entry-open")
    assert audit.codebase_has_key("onboarding-intent-explorer")
    assert audit.codebase_has_key("onboarding-bifurcation-continue")
    assert audit.codebase_has_key("onboarding-bifurcation-exit")
    assert not audit.codebase_has_key("onboarding-bifurcation-creuser")
    assert not audit.codebase_has_key("onboarding-bifurcation-plus-tard")
    assert audit.codebase_has_key("mint2-axis-lpp_rente_capital")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_axis_lpp_rente_capital")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_axis_absent")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_axisInWizardAnswers_false")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_wizardAnswers_0")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_claim_restart_clean")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_owner_claimed")
    assert audit.codebase_has_key("e2e_mint2_axis_claim_auth_present")
    assert not audit.codebase_has_key("mint2-axis-not_real_axis")
    assert not audit.codebase_has_key("e2e_mint2_axis_claim_axis_not_real_axis")
    assert not audit.codebase_has_key("e2e_mint2_axis_claim_wizardAnswers_not_numeric")
    assert not audit.codebase_has_key("e2e_mint2_axis_claim_auth_maybe")


def test_regex_locator_unescapes_parenthesized_labels():
    audit = _load_module()

    assert audit.codebase_has_text(r"Ton avoir LPP actuel \\\\(CHF\\\\)")


def test_arb_placeholders_cover_runtime_rendered_text():
    audit = _load_module()

    assert audit.codebase_has_text("Vaud · environ 7’250 CHF/mois net")


def test_bare_arb_placeholder_does_not_green_any_locator():
    audit = _load_module()

    assert not audit._template_matches_text("{amount}", "not-a-real-mint-locator-2099")
    assert not audit._template_matches_text("{amount} CHF", "not-a-real-mint-locator-2099 CHF")
