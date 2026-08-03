from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch16_runtime_red_contract_guard import (
    ACCEPTANCE,
    ANALYSIS_OPTIONS,
    DESIGN_LAB_LIB,
    DESIGN_LAB_PUBSPEC,
    GENERATED_SEMANTIC_FIXTURE,
    GUARD,
    GUARD_TESTS,
    LEFTHOOK,
    MANIFEST,
    SEMANTIC_FIXTURE,
    WIDGET_TEST,
    WORKFLOW,
    GuardFailure,
    validate,
)


ROOT = Path(__file__).resolve().parents[3]


class Batch16RuntimeRedContractGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in (
            ACCEPTANCE,
            ANALYSIS_OPTIONS,
            DESIGN_LAB_PUBSPEC,
            MANIFEST,
            WIDGET_TEST,
            SEMANTIC_FIXTURE,
            GENERATED_SEMANTIC_FIXTURE,
            GUARD,
            GUARD_TESTS,
            LEFTHOOK,
            WORKFLOW,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        shutil.copytree(ROOT / DESIGN_LAB_LIB, self.root / DESIGN_LAB_LIB)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _manifest(self) -> tuple[Path, dict]:
        path = self.root / MANIFEST
        return path, yaml.safe_load(path.read_text())

    def _reject(self) -> None:
        with self.assertRaises(GuardFailure):
            validate(self.root)

    def test_current_red_contract_passes(self) -> None:
        validate(self.root)

    def test_missing_proof_id_is_rejected(self) -> None:
        path, data = self._manifest()
        del data["proof_map"]["refund_changes_other_row"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_missing_broader_canonical_proof_is_rejected(self) -> None:
        path, data = self._manifest()
        del data["proof_map"]["canonical_ttl_app_lifecycle_purge_callbacks"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_canonical_requirement_rewrite_is_rejected(self) -> None:
        path, data = self._manifest()
        data["proof_map"]["canonical_all_confirmed_full_matrix"][
            "canonical_requirement"
        ] = "narrowed"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_planned_test_name_drift_is_rejected(self) -> None:
        path, data = self._manifest()
        data["proof_map"]["refund_changes_other_row"]["planned_test_name"] = "generic_test"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_missing_widget_test_is_rejected(self) -> None:
        path, data = self._manifest()
        data["proof_map"]["refund_changes_other_row"]["test_name"] = "phantom_test"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_missing_assertion_anchor_is_rejected(self) -> None:
        path, data = self._manifest()
        data["proof_map"]["refund_changes_other_row"]["assertion_anchors"].append("never_present_anchor")
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_skipped_widget_test_is_rejected(self) -> None:
        path = self.root / WIDGET_TEST
        path.write_text(
            path.read_text().replace(
                "testWidgets('eligible_refund_exact_tombstone_and_replay', (tester) async {",
                "testWidgets('eligible_refund_exact_tombstone_and_replay', (tester) async { // skip: true",
            )
        )
        self._reject()

    def test_committed_or_green_status_is_rejected(self) -> None:
        path, data = self._manifest()
        data["status"] = "red_committed_runtime_forbidden"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_extra_or_missing_red_reason_is_rejected(self) -> None:
        path, data = self._manifest()
        data["expected_red_reason"].append("superficial_claim")
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_guard_only_obligation_cannot_masquerade_as_widget(self) -> None:
        path, data = self._manifest()
        data["proof_map"]["ci_binding_removed"] = data["proof_map"]["refund_changes_other_row"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / MANIFEST
        path.write_text(path.read_text() + "\nstatus: accepted\n")
        self._reject()

    def test_missing_locale_semantic_copy_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        del data["intents"]["batch16MintNotVerifiedMeaning"]["pt"]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._reject()

    def test_replaced_semantic_intent_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        data["intents"]["genericNonsense"] = data["intents"].pop(
            "batch16ProviderConfirmedNetMeaning"
        )
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._reject()

    def test_generated_semantic_fixture_drift_is_rejected(self) -> None:
        path = self.root / GENERATED_SEMANTIC_FIXTURE
        path.write_text(path.read_text().replace("MINT has not verified", "MINT verified"))
        self._reject()

    def test_removed_lefthook_binding_is_rejected(self) -> None:
        path = self.root / LEFTHOOK
        path.write_text(
            path.read_text().replace(
                "mint-next-batch16-runtime-red-contract-guard:",
                "mint-next-batch16-runtime-red-contract-disabled:",
            )
        )
        self._reject()

    def test_removed_ci_command_is_rejected(self) -> None:
        path = self.root / WORKFLOW
        path.write_text(
            path.read_text().replace(
                "python3 tools/checks/mint_next_batch16_runtime_red_contract_guard.py",
                "echo bypassed",
            )
        )
        self._reject()

    def test_ci_trust_hash_tamper_is_rejected(self) -> None:
        path = self.root / WORKFLOW
        path.write_text(path.read_text().replace("a", "b", 1))
        self._reject()

    def test_unlisted_executable_widget_test_is_rejected(self) -> None:
        path = self.root / WIDGET_TEST
        path.write_text(
            path.read_text().replace(
                "void main() {",
                "void main() {\n  testWidgets('undeclared_route', (tester) async {});",
            )
        )
        self._reject()

    def test_broad_or_missing_analyzer_exclusion_is_rejected(self) -> None:
        path = self.root / ANALYSIS_OPTIONS
        path.write_text(path.read_text().replace("test/design_lab_batch16_unresolved_navigation_test.dart", "test/**"))
        self._reject()

    def test_direct_network_capability_in_isolated_runtime_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text("import 'dart:io';\n" + path.read_text())
        self._reject()

    def test_output_dependency_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_PUBSPEC
        path.write_text(path.read_text().replace("dependencies:\n", "dependencies:\n  sentry: any\n"))
        self._reject()

    def test_raw_binary_messenger_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nvoid leak(Object value) => ServicesBinding.instance.defaultBinaryMessenger.send('leak', null);\n"
        )
        self._reject()

    def test_log_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(path.read_text() + "\nvoid leak(Object value) => print(value);\n")
        self._reject()

    def test_network_image_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = NetworkImage('https://invalid.example/private');\n"
        )
        self._reject()

    def test_channel_constructor_tearoff_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(path.read_text() + "\nfinal leak = MethodChannel.new;\n")
        self._reject()

    def test_flutter_restoration_persistence_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(path.read_text() + "\nfinal leak = RestorableString('private');\n")
        self._reject()

    def test_synchronous_debug_log_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text() + "\nvoid leak(String value) => debugPrintSynchronously(value);\n"
        )
        self._reject()

    def test_process_text_platform_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = DefaultProcessTextService();\n"
        )
        self._reject()

    def test_port_platform_message_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = PlatformDispatcher.instance.sendPortPlatformMessage;\n"
        )
        self._reject()

    def test_autofill_persistence_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = AutofillGroup(child: const SizedBox());\n"
        )
        self._reject()

    def test_whitespace_obfuscated_clipboard_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = Clipboard . setData;\n"
        )
        self._reject()

    def test_comment_obfuscated_network_image_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = Image /* bypass */ . network;\n"
        )
        self._reject()

    def test_fade_in_network_image_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = FadeInImage.assetNetwork(placeholder: 'x', image: 'https://invalid');\n"
        )
        self._reject()

    def test_platform_view_creation_params_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = AndroidView(viewType: 'x', creationParams: 'private');\n"
        )
        self._reject()

    def test_system_navigator_history_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = SystemNavigator.routeInformationUpdated(location: 'private');\n"
        )
        self._reject()

    def test_system_chrome_label_output_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(
            path.read_text()
            + "\nfinal leak = SystemChrome.setApplicationSwitcherDescription;\n"
        )
        self._reject()


if __name__ == "__main__":
    unittest.main()
