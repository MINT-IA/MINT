from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

from tools.checks import mint_next_batch22_r4_red_guard as guard


ROOT = Path(__file__).resolve().parents[3]
FILES = (
    guard.REGISTRY,
    guard.SCENARIOS_SCOPE,
    guard.ETAT_CIVIL_SCOPE,
    guard.COPY,
    guard.FIXTURES,
    guard.TEST,
    guard.FIXTURE,
    guard.PUBSPEC,
    guard.PUBSPEC_LOCK,
    guard.L10N_CONFIG,
)


def _sha_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class Batch22R4RedGuardTest(unittest.TestCase):
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

    # --- baseline ---
    def test_current_candidate_contract_passes(self) -> None:
        guard.validate(self.root, check_git=False)

    def test_duplicate_yaml_key_is_rejected(self) -> None:
        path = self.root / guard.REGISTRY
        path.write_text(path.read_text() + "\nstatus: expected_red\n")
        with self.assertRaisesRegex(guard.GuardFailure, "duplicate YAML key"):
            guard.validate(self.root, check_git=False)

    # --- registry lifecycle / claims ---
    def test_runtime_implementation_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"].__setitem__("runtime_implemented", True),
            "claims implementation",
        )

    def test_runtime_acceptance_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"].__setitem__("runtime_accepted", True),
            "claims acceptance",
        )

    def test_blocked_runtime_global_cannot_claim_a_state(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["runtime_global"].__setitem__("runtime_accepted", True),
            "blocked gate widened: runtime_global",
        )

    def test_later_gate_cannot_count_for_R4(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"].__setitem__("later_gate_evidence_counts_for_R4", True),
            "later evidence",
        )

    def test_forbidden_claims_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda d: d.__setitem__("forbidden_claims", []),
            "forbidden claims drifted",
        )

    def test_broad_flutter_suite_cannot_replace_targeted_file(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"].__setitem__("command", ["flutter", "test", "--machine"]),
            "command is not exact",
        )

    def test_no_pub_cannot_be_dropped(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"]["command"].remove("--no-pub"),
            "command is not exact",
        )

    def test_gate_reordering_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["ordered_gates"].__setitem__(0, "runtime_global"),
            "gate order drifted",
        )

    def test_expected_summary_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"]["expected_summary"].__setitem__("failed", 13),
            "expected summary drifted",
        )

    def test_missing_obligation_mapping_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"]["obligation_test_names"].pop("R4_11"),
            "obligation coverage drifted",
        )

    def test_subgate_coverage_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"]["subgates"]["R4a_scenarios_versement"].remove("R4_02"),
            "subgate coverage drifted",
        )

    def test_sentinel_binding_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R4"]["expected_red_sentinels"].__setitem__(
                "R4_02 scenarios_versement nominal shows the choose line at least two scenario effect ranges and never a single bare number",
                "R4_99",
            ),
            "RED sentinel binding drifted",
        )

    def test_runtime_regating_scope_widening_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["runtime_regating"]["regated_files"].append(
                "product/mint_next/batch7/design_lab/lib/secret.dart"
            ),
            "runtime regating scope drifted",
        )

    def test_deferred_integration_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["deferred_integration"]["green_gate_semantics"].__setitem__(
                "acceptance_means", "runtime_only_no_wiring"
            ),
            "deferred integration governance unit drifted",
        )

    def test_deferred_integration_removal_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d.pop("deferred_integration"),
            "registry top-level schema drifted",
        )

    # --- fix 3: joint satisfiability of the obligations (the etat_civil.continue class) ---
    def test_joint_satisfiability_catches_continue_no_status_to_committed(self) -> None:
        contradictory = (
            "testWidgets('R4_14 x', (tester) async {\n"
            "  await _reachEtatCivil(tester, sentinel: '[R4_14]');\n"
            "  await _tapVisible(tester, 'action:etat_civil.continue');\n"
            "  expect(_key('status:etat_civil.selection'), findsOneWidget);\n"
            "});\n"
        )
        with self.assertRaisesRegex(guard.GuardFailure, "joint-satisfiability"):
            guard._validate_joint_satisfiability(contradictory)

    def test_joint_satisfiability_accepts_the_committed_status_path(self) -> None:
        # a continue that first commits a status is satisfiable
        ok = (
            "testWidgets('R4_x x', (tester) async {\n"
            "  await _reachEtatCivil(tester, sentinel: '[R4_x]');\n"
            "  await _tapVisible(tester, 'choice:etat_civil.concubinage');\n"
            "  await _tapVisible(tester, 'action:etat_civil.continue');\n"
            "  expect(_key('status:etat_civil.selection'), findsOneWidget);\n"
            "});\n"
        )
        guard._validate_joint_satisfiability(ok)  # must not raise

    def test_joint_satisfiability_accepts_the_error_no_selection_path(self) -> None:
        # the sanctioned no-commit continue tap: it expects error_no_selection.
        ok = (
            "testWidgets('R4_14 x', (tester) async {\n"
            "  await _reachEtatCivil(tester, sentinel: '[R4_14]');\n"
            "  await _tapVisible(tester, 'action:etat_civil.continue');\n"
            "  expect(_key('status:etat_civil.error_no_selection'), findsOneWidget);\n"
            "});\n"
        )
        guard._validate_joint_satisfiability(ok)  # must not raise

    def test_live_test_is_jointly_satisfiable(self) -> None:
        guard._validate_joint_satisfiability((ROOT / guard.TEST).read_text(encoding="utf-8"))

    # --- regle13 lesson (c): supersession by pin, never re-attested ---
    def test_supersedes_pin_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"].pop("supersedes"),
            "authority schema drifted",
        )

    def test_supersedes_pin_cannot_flip_to_live_reattestation(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"]["supersedes"].__setitem__("no_live_reattestation_of_r3", False),
            "supersession pin drifted or re-attested",
        )

    def test_supersedes_accepted_commit_cannot_drift(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"]["supersedes"].__setitem__("r3_green_accepted_commit", "deadbeef"),
            "supersession pin drifted or re-attested",
        )

    # --- pinned content digests ---
    def _corrupt(self, relative: Path) -> None:
        path = self.root / relative
        path.write_bytes(path.read_bytes() + b"\n# tamper\n")

    def test_scenarios_scope_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.SCENARIOS_SCOPE)
        with self.assertRaisesRegex(guard.GuardFailure, "scenarios scope digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_etat_civil_scope_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.ETAT_CIVIL_SCOPE)
        with self.assertRaisesRegex(guard.GuardFailure, "etat_civil scope digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_fixtures_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.FIXTURES)
        with self.assertRaisesRegex(guard.GuardFailure, "engine fixtures digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_test_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.TEST)
        with self.assertRaisesRegex(guard.GuardFailure, "test digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_compile_fixture_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.FIXTURE)
        with self.assertRaisesRegex(guard.GuardFailure, "compile fixture digest drifted"):
            guard.validate(self.root, check_git=False)

    # --- lib inventory: R4 runtime must remain UNIMPLEMENTED ---
    def test_new_r4_runtime_file_is_rejected(self) -> None:
        (self.root / guard.LIB_ROOT / "scenarios_versement.dart").write_text("// implemented\n")
        with self.assertRaisesRegex(guard.GuardFailure, "runtime source inventory"):
            guard.validate(self.root, check_git=False)

    def test_lib_source_edit_is_rejected(self) -> None:
        app = self.root / guard.LIB_ROOT / "design_lab_app.dart"
        app.write_text(app.read_text() + "\n// tamper\n")
        with self.assertRaisesRegex(guard.GuardFailure, "runtime source inventory"):
            guard.validate(self.root, check_git=False)

    # --- mandate step 1: per-locale copy semantics (patch digest to reach logic) ---
    def _mutate_copy(self, mutation) -> None:
        path = self.root / guard.COPY
        data = yaml.safe_load(path.read_text())
        mutation(data)
        text = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
        path.write_text(text)
        new_sha = _sha_text(text)
        # keep BOTH digest gates satisfied so the semantic gate is the one that
        # bites: the guard's own EXPECTED_COPY_SHA256 AND the registry's declared
        # authority.immutable_copy_sha256 (the guard cross-checks the two).
        patcher = patch.object(guard, "EXPECTED_COPY_SHA256", new_sha)
        patcher.start()
        self.addCleanup(patcher.stop)
        reg_path = self.root / guard.REGISTRY
        reg = yaml.safe_load(reg_path.read_text())
        reg["authority"]["immutable_copy_sha256"] = new_sha
        reg_path.write_text(yaml.safe_dump(reg, sort_keys=False, allow_unicode=True))

    def test_copy_banned_lsfin_term_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_choose_line",
                d["copy"]["fr"]["scenarios_choose_line"] + " Effet garanti.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "promise/superlative"):
            guard.validate(self.root, check_git=False)

    def test_copy_marginal_rate_jargon_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_choose_line",
                d["copy"]["fr"]["scenarios_choose_line"] + " Selon ton taux marginal.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "marginal-rate/coefficient jargon"):
            guard.validate(self.root, check_git=False)

    def test_copy_locality_claim_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_disclaimer",
                d["copy"]["fr"]["scenarios_disclaimer"] + " Tout reste sur ton téléphone.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "locality/on-device"):
            guard.validate(self.root, check_git=False)

    def test_copy_effect_collapsed_to_single_number_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__("scenarios_effect", "2000 CHF d’impôt en moins")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "low-to-high range"):
            guard.validate(self.root, check_git=False)

    def test_copy_disclaimer_negation_dropped_is_rejected(self) -> None:
        # dropping « pas un conseil » turns the estimate line into a promise.
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_disclaimer",
                "Ce sont des estimations fiables.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "not advice"):
            guard.validate(self.root, check_git=False)

    def test_copy_disclaimer_estimate_dropped_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_disclaimer",
                "Pas un conseil. Le montant exact figure sur ta taxation.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "frame the payoff as an estimate"):
            guard.validate(self.root, check_git=False)

    def test_copy_liquidity_locked_dropped_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_liquidity",
                "L’argent versé sur un 3a est disponible jusqu’à la retraite.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "money is locked"):
            guard.validate(self.root, check_git=False)

    def test_copy_liquidity_retirement_dropped_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "scenarios_liquidity",
                "L’argent versé sur un 3a reste bloqué, sauf exceptions prévues par la loi.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "locked until retirement"):
            guard.validate(self.root, check_git=False)

    def test_copy_concubinage_ruling_dropped_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "etat_civil_gloss_concubinage_def",
                "En couple non marié, vous partagez vos dépenses.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "single/separate treatment"):
            guard.validate(self.root, check_git=False)

    def test_copy_key_parity_drift_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__("scenarios_extra", "Une clé de trop.")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "key set drifted"):
            guard.validate(self.root, check_git=False)

    def test_copy_placeholder_parity_drift_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["en"].__setitem__("scenarios_remaining", "You can still pay in this year.")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "placeholder parity"):
            guard.validate(self.root, check_git=False)

    def test_copy_required_placeholder_contract_drift_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["required_placeholders"].append("stray")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "required-placeholder contract drifted"):
            guard.validate(self.root, check_git=False)

    def test_fallback_locale_copy_is_rejected(self) -> None:
        # A lazy fallback (en := fr) is caught by the locale-specific disclaimer
        # concept (fr wording fails the English « estimate » check) or, failing
        # that, by the byte-identical net — either way the en locale is rejected.
        self._mutate_copy(lambda d: d["copy"].__setitem__("en", dict(d["copy"]["fr"])))
        with self.assertRaisesRegex(guard.GuardFailure, r"copy \[en\]"):
            guard.validate(self.root, check_git=False)

    # --- regle13 lesson (b) + (d): delta-scoped git boundary on the REAL repo ---
    def _red_commit(self) -> str | None:
        end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(guard.ALLOWED_DIFF_PATHS)],
            cwd=ROOT, capture_output=True, text=True,
        ).stdout.strip()
        return end if re.fullmatch(r"[0-9a-f]{40}", end) else None

    def test_anchor_is_red_commit_parent(self) -> None:
        red = self._red_commit()
        if red is None:
            self.skipTest("RED files not yet committed")
        parent = subprocess.run(
            ["git", "rev-parse", f"{red}^"], cwd=ROOT, capture_output=True, text=True,
        ).stdout.strip()
        self.assertEqual(
            parent, guard.ANCHOR,
            "regle13 (d): the RED guard ANCHOR must be exactly RED_COMMIT^",
        )

    def test_committed_red_delta_is_scoped(self) -> None:
        if self._red_commit() is None:
            self.skipTest("RED files not yet committed")
        # regle13 (b): the committed RED delta touches only ALLOWED_DIFF_PATHS.
        guard.validate(ROOT, check_git=True)


class Batch22R4ClassifierTest(unittest.TestCase):
    """Directly exercise run_expected_red's machine-stream classifier with
    synthetic streams (the critical, otherwise untested, RED verdict path) —
    including the simulated-GREEN smoke (leçon d: the guard must FAIL, not pass,
    the day the runtime lands green)."""

    def _stream(
        self,
        *,
        load: str = "success",
        drop_sentinel: str | None = None,
        forbidden_on: str | None = None,
        extra_pass: bool = False,
        all_green: bool = False,
    ) -> str:
        lines: list[str] = []
        nid = 0

        def start(name: str) -> int:
            nonlocal nid
            nid += 1
            lines.append(json.dumps({"type": "testStart", "test": {"id": nid, "name": name}}))
            return nid

        load_id = start("loading test/design_lab_batch22_r4_test.dart")
        lines.append(json.dumps({"type": "testDone", "testID": load_id, "result": load, "hidden": True}))
        for name in sorted(guard.EXPECTED_TEST_NAMES):
            tid = start(name)
            failing = name in guard.EXPECTED_FAILED_NAMES
            if all_green:
                failing = False  # the runtime landed: every obligation now passes
            if extra_pass and name == "R4_02 scenarios_versement nominal shows the choose line at least two scenario effect ranges and never a single bare number":
                failing = False  # a behavioural obligation silently "passed"
            if failing:
                sentinel = guard.EXPECTED_RED_SENTINELS[name]
                marker = "" if drop_sentinel == name else f"[{sentinel}] "
                harness = "\nCould not find a generator for route" if forbidden_on == name else ""
                lines.append(json.dumps({
                    "type": "error", "testID": tid,
                    "error": f"TestFailure: {marker}expected findsOneWidget{harness}",
                    "stackTrace": "package:...test.dart",
                }))
                result = "error"
            else:
                result = "success"
            lines.append(json.dumps({"type": "testDone", "testID": tid, "result": result, "hidden": False}))
        # a RED suite's final done event reports success=False (14 tests failed);
        # only the simulated-GREEN suite (all_green) reports success=True — and it
        # is rejected earlier on returncode 0, before the done event is inspected.
        lines.append(json.dumps({"type": "done", "success": all_green, "time": 100}))
        return "\n".join(lines) + "\n"

    def _run(self, stream: str, *, returncode: int = 1):
        fake = subprocess.CompletedProcess(args=["flutter"], returncode=returncode, stdout=stream, stderr="")
        with patch.object(guard, "_run_candidate_command", return_value=fake):
            guard.run_expected_red(ROOT, check_git=False)

    def test_classifier_accepts_the_sealed_red_stream(self) -> None:
        self._run(self._stream())  # positive control: the exact 2/14/0 shape

    def test_classifier_rejects_load_failure(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "failed to compile or load"):
            self._run(self._stream(load="error"))

    def test_classifier_rejects_missing_sentinel(self) -> None:
        name = "R4_09 fact_etat_civil shows three civil status cards none preselected and no wheel or keyboard"
        with self.assertRaisesRegex(guard.GuardFailure, "exact named behavioural assertion"):
            self._run(self._stream(drop_sentinel=name))

    def test_classifier_rejects_harness_error_diagnostic(self) -> None:
        name = "R4_06 the plafond glossary sheet opens focus trapped and restores to the anchor"
        with self.assertRaisesRegex(guard.GuardFailure, "harness/runtime error"):
            self._run(self._stream(forbidden_on=name))

    def test_classifier_rejects_summary_drift(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "unexpected RED failures|test inventory drifted|error-event inventory"):
            self._run(self._stream(extra_pass=True))

    def test_classifier_rejects_all_green_runtime(self) -> None:
        # simulated-GREEN smoke: when the R4 runtime lands and every test passes,
        # the RED guard must FAIL (returncode 0, no expected failures) — it never
        # certifies a green suite as an honest RED.
        with self.assertRaisesRegex(guard.GuardFailure, r"exit was 0, expected 1"):
            self._run(self._stream(all_green=True), returncode=0)


if __name__ == "__main__":
    unittest.main()
