from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.checks.mint_next_batch8_lpp_runtime_guard import APP, L10N, validate


class Batch8LppRuntimeGuardTest(unittest.TestCase):
    def test_current_runtime_passes(self) -> None:
        self.assertEqual(validate(), [])

    def test_rejects_dead_button_binding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.dart"
            path.write_text(APP.read_text().replace("action:fact_lpp_affiliation.choose_yes", "action:dead"), encoding="utf-8")
            self.assertIn("Batch8 Flutter binding missing: action:fact_lpp_affiliation.choose_yes", validate(app_path=path))

    def test_rejects_harmful_copy_or_amount(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text())
                if source.name == "app_fr.arb":
                    data["withoutLppBody"] = "Tu es inéligible. CHF 99 999."
                (target / source.name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            errors = validate(l10n_path=target)
            self.assertIn("Batch8 exact French runtime copy drift: withoutLppBody", errors)
            self.assertIn("Batch8 LPP slice leaks an amount, threshold or percentage", errors)

    def test_rejects_six_locale_key_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for source in L10N.glob("app_*.arb"):
                data = json.loads(source.read_text())
                if source.name == "app_de.arb":
                    data.pop("lppQuestionTitle")
                (target / source.name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            self.assertIn("Batch8 ARB keys differ across six locales", validate(l10n_path=target))


if __name__ == "__main__":
    unittest.main()
