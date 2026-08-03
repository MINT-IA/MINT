from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

from tools.checks import mint_next_batch19_r1_red_guard as guard


ROOT = Path(__file__).resolve().parents[3]
FILES = (
    guard.REGISTRY,
    guard.SCOPE,
    guard.COPY,
    guard.TEST,
    guard.FIXTURE,
    guard.PUBSPEC,
    guard.PUBSPEC_LOCK,
    guard.L10N_CONFIG,
)


class Batch19R1RedGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        shutil.copytree(ROOT / guard.LIB_ROOT, self.root / guard.LIB_ROOT)
        shutil.copytree(ROOT / guard.ASSETS_ROOT, self.root / guard.ASSETS_ROOT)
        guard.validate(self.root, check_git=False)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _registry_mutation(self, mutation, expected: str) -> None:
        path = self.root / guard.REGISTRY
        data = yaml.safe_load(path.read_text())
        mutation(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        with self.assertRaisesRegex(guard.GuardFailure, expected):
            guard.validate(self.root, check_git=False)

    def test_current_candidate_contract_passes(self) -> None:
        guard.validate(self.root, check_git=False)

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / guard.REGISTRY
        path.write_text(path.read_text() + "\nstatus: expected_red\n")
        with self.assertRaisesRegex(guard.GuardFailure, "duplicate YAML key"):
            guard.validate(self.root, check_git=False)

    def test_runtime_implementation_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"].__setitem__("runtime_implemented", True),
            "claims implementation",
        )

    def test_runtime_acceptance_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"].__setitem__("runtime_accepted", True),
            "claims acceptance",
        )

    def test_blocked_R2_cannot_claim_acceptance(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R2"].__setitem__("runtime_accepted", True),
            "blocked gate widened: R2",
        )

    def test_global_production_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda data: data.__setitem__("production_ready", True),
            "top-level schema drifted",
        )

    def test_subgate_inventory_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"].pop("subgates"),
            "R1 registry schema drifted",
        )

    def test_forbidden_claims_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda data: data.__setitem__("forbidden_claims", []),
            "forbidden claims drifted",
        )

    def test_later_gate_cannot_count_for_R1(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"].__setitem__(
                "later_gate_evidence_counts_for_R1", True
            ),
            "later evidence",
        )

    def test_broad_flutter_suite_cannot_replace_targeted_file(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"].__setitem__(
                "command", ["flutter", "test", "--machine"]
            ),
            "command is not exact",
        )

    def test_flutter_test_cannot_re_resolve_after_isolated_pub_get(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"]["command"].remove("--no-pub"),
            "command is not exact",
        )

    def test_gate_reordering_is_rejected(self) -> None:
        self._registry_mutation(
            lambda data: data["ordered_gates"].__setitem__(0, "R2"),
            "gate order drifted",
        )

    def test_missing_obligation_mapping_is_rejected(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"]["obligation_test_names"].pop(
                "R1_12"
            ),
            "obligation coverage drifted",
        )

    def test_unrelated_green_test_cannot_replace_obligation(self) -> None:
        self._registry_mutation(
            lambda data: data["gates"]["R1"]["obligation_test_names"].__setitem__(
                "R1_12", "unrelated smoke test"
            ),
            "named-test inventory drifted",
        )

    def test_test_mutation_plus_registry_rebinding_is_rejected(self) -> None:
        test_path = self.root / guard.TEST
        test_path.write_text(test_path.read_text().replace("findsOneWidget,", "findsNothing,", 1))
        registry_path = self.root / guard.REGISTRY
        registry = yaml.safe_load(registry_path.read_text())
        import hashlib

        registry["gates"]["R1"]["candidate_binding"]["test_sha256"] = hashlib.sha256(
            test_path.read_bytes()
        ).hexdigest()
        registry_path.write_text(yaml.safe_dump(registry, sort_keys=False, allow_unicode=True))
        with self.assertRaisesRegex(guard.GuardFailure, "candidate source binding drifted"):
            guard.validate(self.root, check_git=False)

    def test_fixture_label_mutation_is_rejected(self) -> None:
        path = self.root / guard.FIXTURE
        path.write_text(path.read_text().replace('"GE": "Genève"', '"GE": "Geneva"', 1))
        with self.assertRaisesRegex(guard.GuardFailure, "fixture labels drifted: fr"):
            guard.validate(self.root, check_git=False)

    def test_fixture_executable_spread_is_rejected(self) -> None:
        path = self.root / guard.FIXTURE
        path.write_text(path.read_text().replace('  "AG",', '  ...<String>["AG"],', 1))
        with self.assertRaisesRegex(guard.GuardFailure, "executable or unparsed"):
            guard.validate(self.root, check_git=False)

    def test_symlinked_artifact_is_rejected(self) -> None:
        path = self.root / guard.FIXTURE
        copy = self.root / "fixture-copy.dart"
        path.replace(copy)
        path.symlink_to(copy)
        with self.assertRaisesRegex(guard.GuardFailure, "not a regular file"):
            guard.validate(self.root, check_git=False)

    def test_any_unreviewed_runtime_source_mutation_is_rejected(self) -> None:
        path = self.root / guard.LIB_ROOT / "design_lab_app.dart"
        path.write_text(path.read_text() + "\n// Even harmless drift requires a new reviewed candidate.\n")
        with self.assertRaisesRegex(guard.GuardFailure, "source inventory or digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_channel_and_platform_constructor_bypasses_are_rejected(self) -> None:
        mutations = (
            "const channel = MethodChannel.new('mint.exfil');",
            "const channel = MethodChannel .new('mint.exfil');",
            "final optional = OptionalMethodChannel('mint.exfil');",
            "final optionalNew = OptionalMethodChannel.new('mint.exfil');",
            "final background = BackgroundIsolateBinaryMessenger.instance;",
            "final custom = createBinaryMessenger();",
            "Image.network('https://evil.example/leak');",
            "final image = NetworkImage('https://evil.example/leak');",
            "Clipboard.setData(const ClipboardData(text: 'secret'));",
            "import 'dart:html' as h;",
            "SystemChannels.platform.invokeMethod<void>('exfil');",
            "PlatformDispatcher.instance.sendPlatformMessage('exfil', null, (_) {});",
            "WidgetsBinding.instance.defaultBinaryMessenger.send('mint.exfil', null);",
            "final leak = print;",
            "final debugLeak = debugPrint;",
            "final callLeak = (print).call;",
            "final spacedLeak = debugPrint .call;",
            "debugPrintThrottled('mint.exfil');",
            "final throttledLeak = debugPrintThrottled;",
            "debugPrintStack(label: 'mint.exfil');",
            "debugDumpApp();",
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    shutil.copytree(self.root, root, dirs_exist_ok=True)
                    path = root / guard.LIB_ROOT / "design_lab_app.dart"
                    path.write_text(path.read_text() + f"\n{mutation}\n")
                    with self.assertRaisesRegex(guard.GuardFailure, "source inventory or digest drifted"):
                        guard.validate(root, check_git=False)

    def test_dev_dependency_alias_cannot_widen_capabilities(self) -> None:
        path = self.root / guard.PUBSPEC
        path.write_text(
            path.read_text().replace(
                "dev_dependencies:\n",
                "dev_dependencies:\n  innocent:\n    path: /tmp/attacker-package\n",
                1,
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "pubspec digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_lockfile_drift_is_rejected(self) -> None:
        path = self.root / guard.PUBSPEC_LOCK
        path.write_text(path.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "pubspec lock digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_non_dart_runtime_input_drift_is_rejected(self) -> None:
        path = self.root / guard.LIB_ROOT / "l10n" / "app_fr.arb"
        path.write_text(path.read_text().replace("MINT", "M1NT", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "source inventory or digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_l10n_config_drift_is_rejected(self) -> None:
        path = self.root / guard.L10N_CONFIG
        path.write_text(path.read_text() + "\n# drift\n")
        with self.assertRaisesRegex(guard.GuardFailure, "auxiliary input inventory or digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_asset_drift_is_rejected(self) -> None:
        path = self.root / guard.ASSETS_ROOT / "fonts" / "Supreme-Regular.otf"
        path.write_bytes(path.read_bytes() + b"drift")
        with self.assertRaisesRegex(guard.GuardFailure, "auxiliary input inventory or digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_nonexistent_batch18_harness_is_rejected(self) -> None:
        path = self.root / guard.TEST
        path.write_text(path.read_text().replace("MintNextDesignLabApp(", "MintNextDesignLabApp.batch18Harness(", 1))
        with self.assertRaisesRegex(guard.GuardFailure, "nonexistent harness"):
            guard.validate(self.root, check_git=False)

    def test_accepted_scope_mutation_is_rejected(self) -> None:
        path = self.root / guard.SCOPE
        path.write_text(path.read_text().replace("runtime_surface: hidden_design_lab_only", "runtime_surface: product"))
        with self.assertRaisesRegex(guard.GuardFailure, "accepted scope digest drifted"):
            guard.validate(self.root, check_git=False)

    def _machine_output(
        self,
        *,
        load: str = "success",
        green_name: str | None = None,
        timeout_name: str | None = None,
    ) -> str:
        events: list[dict] = []
        test_id = 1
        events.extend([
            {"type": "testStart", "test": {"id": test_id, "name": "loading /tmp/r1.dart"}},
            {"type": "testDone", "testID": test_id, "result": load, "hidden": True},
        ])
        for name in sorted(guard.EXPECTED_TEST_NAMES):
            test_id += 1
            prefix = ""
            if name.startswith(("R1_01", "R1_05", "R1_11")):
                prefix = "R1a_catalog_origin_and_generation "
            elif name.startswith(("R1_04", "R1_06", "R1_07", "R1_10", "R1_12")):
                prefix = "R1b_local_search_privacy "
            elif name.startswith(("R1_08", "R1_09", "R1_13")):
                prefix = "R1c_selection_semantics_and_layout "
            result = (
                "success"
                if name == green_name
                or name.startswith("R1_14")
                or name.startswith("R1_01 baseline")
                else "error"
            )
            events.append({"type": "testStart", "test": {"id": test_id, "name": prefix + name}})
            if result == "error":
                message = (
                    "Test timed out after 30 seconds"
                    if name == timeout_name
                    else "The following TestFailure was thrown\n"
                    f"[{guard.EXPECTED_RED_SENTINELS[name]}] intended missing behavior"
                )
                events.append({"type": "print", "testID": test_id, "message": message})
                events.append({"type": "error", "testID": test_id, "error": "expected"})
            events.append({"type": "testDone", "testID": test_id, "result": result, "hidden": False})
        events.append({"type": "done", "success": False, "time": 1})
        return "\n".join(json.dumps(event) for event in events)

    def test_compile_or_load_failure_is_not_expected_red(self) -> None:
        completed = subprocess.CompletedProcess([], 1, self._machine_output(load="error"), "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "compile or load"):
                guard.run_expected_red(self.root, check_git=False)

    def test_unexpected_green_runtime_test_is_not_red_evidence(self) -> None:
        green = next(iter(guard.EXPECTED_FAILED_NAMES))
        completed = subprocess.CompletedProcess([], 1, self._machine_output(green_name=green), "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "unexpected RED failures"):
                guard.run_expected_red(self.root, check_git=False)

    def test_timeout_cannot_count_as_expected_behavioral_red(self) -> None:
        timed_out = next(iter(guard.EXPECTED_FAILED_NAMES))
        completed = subprocess.CompletedProcess(
            [], 1, self._machine_output(timeout_name=timed_out), ""
        )
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "exact named behavioral assertion"):
                guard.run_expected_red(self.root, check_git=False)

    def test_wrong_obligation_marker_cannot_count_as_red(self) -> None:
        output = self._machine_output().replace(
            '[R1_12] intended missing behavior',
            '[R1_03] intended missing behavior',
            1,
        )
        completed = subprocess.CompletedProcess([], 1, output, "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "exact named behavioral assertion"):
                guard.run_expected_red(self.root, check_git=False)

    def test_stderr_cannot_be_hidden_by_valid_named_failures(self) -> None:
        completed = subprocess.CompletedProcess([], 1, self._machine_output(), "compiler warning")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "emitted stderr"):
                guard.run_expected_red(self.root, check_git=False)

    def test_extra_hidden_error_cannot_coexist_with_expected_red(self) -> None:
        lines = self._machine_output().splitlines()
        lines.insert(-1, json.dumps({"type": "testStart", "test": {"id": 999, "name": "hidden crash"}}))
        lines.insert(-1, json.dumps({"type": "error", "testID": 999, "error": "boom"}))
        lines.insert(-1, json.dumps({"type": "testDone", "testID": 999, "result": "error", "hidden": True}))
        completed = subprocess.CompletedProcess([], 1, "\n".join(lines), "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "unexpected hidden"):
                guard.run_expected_red(self.root, check_git=False)

    def test_duplicate_final_done_event_is_rejected(self) -> None:
        output = self._machine_output() + "\n" + json.dumps(
            {"type": "done", "success": False, "time": 2}
        )
        completed = subprocess.CompletedProcess([], 1, output, "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "final done event"):
                guard.run_expected_red(self.root, check_git=False)

    def test_orphan_test_start_is_rejected(self) -> None:
        lines = self._machine_output().splitlines()
        lines.insert(-1, json.dumps({"type": "testStart", "test": {"id": 999, "name": "orphan"}}))
        completed = subprocess.CompletedProcess([], 1, "\n".join(lines), "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "testStart/testDone"):
                guard.run_expected_red(self.root, check_git=False)

    def test_unknown_machine_event_is_rejected(self) -> None:
        output = self._machine_output() + "\n" + json.dumps({"type": "surprise"})
        completed = subprocess.CompletedProcess([], 1, output, "")
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "unknown R1 machine event"):
                guard.run_expected_red(self.root, check_git=False)

    def test_non_json_stdout_is_rejected(self) -> None:
        completed = subprocess.CompletedProcess(
            [], 1, self._machine_output() + "\nnot-json", ""
        )
        with patch.object(guard, "_run_candidate_command", return_value=completed):
            with self.assertRaisesRegex(guard.GuardFailure, "non-JSON stdout"):
                guard.run_expected_red(self.root, check_git=False)

    def test_process_timeout_is_rejected(self) -> None:
        with patch.object(
            guard,
            "_run_candidate_command",
            side_effect=subprocess.TimeoutExpired(["flutter"], 120),
        ):
            with self.assertRaisesRegex(guard.GuardFailure, "command timed out"):
                guard.run_expected_red(self.root, check_git=False)


if __name__ == "__main__":
    unittest.main()
