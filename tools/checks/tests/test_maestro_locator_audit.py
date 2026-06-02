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

