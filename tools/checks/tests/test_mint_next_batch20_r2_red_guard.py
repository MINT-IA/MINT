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

from tools.checks import mint_next_batch20_r2_red_guard as guard


ROOT = Path(__file__).resolve().parents[3]
FILES = (
    guard.REGISTRY,
    guard.SCOPE,
    guard.COPY,
    guard.DATASET,
    guard.TEST,
    guard.FIXTURE,
    guard.PUBSPEC,
    guard.PUBSPEC_LOCK,
    guard.L10N_CONFIG,
)


def _sha_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class Batch20R2RedGuardTest(unittest.TestCase):
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
            lambda d: d["gates"]["R2"].__setitem__("runtime_implemented", True),
            "claims implementation",
        )

    def test_runtime_acceptance_claim_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"].__setitem__("runtime_accepted", True),
            "claims acceptance",
        )

    def test_blocked_R3_cannot_claim_acceptance(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R3"].__setitem__("runtime_accepted", True),
            "blocked gate widened: R3",
        )

    def test_later_gate_cannot_count_for_R2(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"].__setitem__("later_gate_evidence_counts_for_R2", True),
            "later evidence",
        )

    def test_forbidden_claims_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda d: d.__setitem__("forbidden_claims", []),
            "forbidden claims drifted",
        )

    def test_broad_flutter_suite_cannot_replace_targeted_file(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"].__setitem__("command", ["flutter", "test", "--machine"]),
            "command is not exact",
        )

    def test_no_pub_cannot_be_dropped(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"]["command"].remove("--no-pub"),
            "command is not exact",
        )

    def test_gate_reordering_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["ordered_gates"].__setitem__(0, "R3"),
            "gate order drifted",
        )

    def test_expected_summary_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"]["expected_summary"].__setitem__("failed", 12),
            "expected summary drifted",
        )

    def test_missing_obligation_mapping_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"]["obligation_test_names"].pop("R2_11"),
            "obligation coverage drifted",
        )

    def test_subgate_coverage_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"]["subgates"]["R2a_arrival_states_and_national_search"].remove("R2_12"),
            "subgate coverage drifted",
        )

    def test_sentinel_binding_drift_is_rejected(self) -> None:
        self._registry_mutation(
            lambda d: d["gates"]["R2"]["expected_red_sentinels"].__setitem__(
                "R2_02 arrival focuses the heading not a raised keyboard and the question carries the meaning without a body",
                "R2_99",
            ),
            "RED sentinel binding drifted",
        )

    # --- regle13 lesson (c): supersession by pin, never re-attested ---
    def test_supersedes_pin_cannot_be_removed(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"].pop("supersedes"),
            "authority schema drifted",
        )

    def test_supersedes_pin_cannot_flip_to_live_reattestation(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"]["supersedes"].__setitem__("no_live_reattestation_of_r1", False),
            "supersession pin drifted or re-attested",
        )

    def test_supersedes_accepted_commit_cannot_drift(self) -> None:
        self._registry_mutation(
            lambda d: d["authority"]["supersedes"].__setitem__("r1_green_accepted_commit", "deadbeef"),
            "supersession pin drifted or re-attested",
        )

    # --- pinned content digests ---
    def _corrupt(self, relative: Path) -> None:
        path = self.root / relative
        path.write_bytes(path.read_bytes() + b"\n# tamper\n")

    def test_scope_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.SCOPE)
        with self.assertRaisesRegex(guard.GuardFailure, "scope digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_dataset_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.DATASET)
        with self.assertRaisesRegex(guard.GuardFailure, "dataset digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_test_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.TEST)
        with self.assertRaisesRegex(guard.GuardFailure, "test digest drifted"):
            guard.validate(self.root, check_git=False)

    def test_fixture_digest_drift_is_rejected(self) -> None:
        self._corrupt(guard.FIXTURE)
        with self.assertRaisesRegex(guard.GuardFailure, "fixture digest drifted"):
            guard.validate(self.root, check_git=False)

    # --- regle13 lesson: R2 runtime must remain UNIMPLEMENTED (lib inventory) ---
    def test_new_fused_runtime_file_is_rejected(self) -> None:
        (self.root / guard.LIB_ROOT / "fact_lieu_r2.dart").write_text("// implemented\n")
        with self.assertRaisesRegex(guard.GuardFailure, "runtime source inventory"):
            guard.validate(self.root, check_git=False)

    def test_lib_source_edit_is_rejected(self) -> None:
        app = self.root / guard.LIB_ROOT / "design_lab_app.dart"
        app.write_text(app.read_text() + "\n// tamper\n")
        with self.assertRaisesRegex(guard.GuardFailure, "runtime source inventory"):
            guard.validate(self.root, check_git=False)

    # --- mandate step 4: per-locale copy semantics (patch digest to reach logic) ---
    def _mutate_copy(self, mutation) -> None:
        path = self.root / guard.COPY
        data = yaml.safe_load(path.read_text())
        mutation(data)
        text = yaml.safe_dump(data, sort_keys=False, allow_unicode=True)
        path.write_text(text)
        # keep the digest gate satisfied so the semantic gate is the one that bites
        patcher = patch.object(guard, "EXPECTED_COPY_SHA256", _sha_text(text))
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_copy_coefficient_jargon_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "fact_commune_gloss_communal_def",
                d["copy"]["fr"]["fact_commune_gloss_communal_def"] + " coefficient communal.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "jargon"):
            guard.validate(self.root, check_git=False)

    def test_copy_steuerfuss_jargon_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["de"].__setitem__(
                "fact_commune_gloss_communal_def",
                d["copy"]["de"]["fact_commune_gloss_communal_def"] + " Steuerfuss.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "jargon"):
            guard.validate(self.root, check_git=False)

    def test_copy_dropping_communal_tax_concept_is_rejected(self) -> None:
        def mutation(d):
            block = d["copy"]["fr"]
            for key in (
                "fact_commune_gloss_communal_term",
                "fact_commune_gloss_communal_def",
                "fact_commune_gloss_communal_metaphor",
                "fact_commune_communal_hint",
            ):
                block[key] = block[key].replace("communal", "cantonal")
        self._mutate_copy(mutation)
        with self.assertRaisesRegex(guard.GuardFailure, "communal tax can apply"):
            guard.validate(self.root, check_git=False)

    def test_copy_dropping_modal_concept_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "fact_commune_gloss_communal_def",
                d["copy"]["fr"]["fact_commune_gloss_communal_def"].replace("peut prélever", "prélève"),
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "stay modal"):
            guard.validate(self.root, check_git=False)

    def test_copy_privacy_dropping_search_scope_is_rejected(self) -> None:
        # A privacy line that names the committed choice instead of the search
        # query drops the search keyword entirely.
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "fact_commune_privacy", "Ton choix reste sur ton téléphone."
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "search query only"):
            guard.validate(self.root, check_git=False)

    def test_copy_privacy_extending_to_committed_commune_is_rejected(self) -> None:
        # The exact bypass: keep the honest search keyword but ALSO claim the
        # committed commune stays on device (it joins the profile). Must still be
        # rejected even though the search-scope keyword is present.
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "fact_commune_privacy", "Ta recherche et ta commune restent sur ton téléphone."
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "exceeds the data contract"):
            guard.validate(self.root, check_git=False)

    def test_copy_privacy_naming_search_without_locality_is_rejected(self) -> None:
        # The bypass: a line that names the search but asserts the OPPOSITE of
        # locality ("sent to our servers") must not pass on the search word alone.
        self._mutate_copy(
            lambda d: d["copy"]["en"].__setitem__(
                "fact_commune_privacy", "Your search is sent to our servers."
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "stays local/on-device"):
            guard.validate(self.root, check_git=False)

    def test_copy_church_not_marked_excluded_is_rejected(self) -> None:
        # Mentioning the church tax without negating it (dropping "we don't count
        # it here") is rejected: the concept must convey exclusion, not presence.
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__(
                "fact_commune_gloss_eglise_def",
                "Certaines Églises reconnues prélèvent cet impôt ecclésiastique.",
            )
        )
        with self.assertRaisesRegex(guard.GuardFailure, "excluded here"):
            guard.validate(self.root, check_git=False)

    def test_copy_reintroducing_a_body_sentence_is_rejected(self) -> None:
        # The commune-directe amendment removed the body sentence: any re-added
        # fact_commune_body breaks key parity.
        self._mutate_copy(
            lambda d: d["copy"]["fr"].__setitem__("fact_commune_body", "Une phrase de trop.")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "key set drifted"):
            guard.validate(self.root, check_git=False)

    def test_copy_placeholder_parity_drift_is_rejected(self) -> None:
        self._mutate_copy(
            lambda d: d["copy"]["en"].__setitem__("fact_commune_match_count", "municipalities found")
        )
        with self.assertRaisesRegex(guard.GuardFailure, "placeholder parity"):
            guard.validate(self.root, check_git=False)

    def test_fallback_locale_copy_is_rejected(self) -> None:
        # A lazy fallback (en := fr) is caught by the locale-specific concept
        # keywords (fr wording fails the English concept checks) or, failing
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


class Batch20R2ClassifierTest(unittest.TestCase):
    """Directly exercise run_expected_red's machine-stream classifier with
    synthetic streams (the critical, otherwise untested, RED verdict path)."""

    def _stream(
        self,
        *,
        load: str = "success",
        drop_sentinel: str | None = None,
        forbidden_on: str | None = None,
        extra_pass: bool = False,
    ) -> str:
        lines: list[str] = []
        nid = 0

        def start(name: str) -> int:
            nonlocal nid
            nid += 1
            lines.append(json.dumps({"type": "testStart", "test": {"id": nid, "name": name}}))
            return nid

        load_id = start("loading test/design_lab_batch20_commune_r2_test.dart")
        lines.append(json.dumps({"type": "testDone", "testID": load_id, "result": load, "hidden": True}))
        for name in sorted(guard.EXPECTED_TEST_NAMES):
            tid = start(name)
            failing = name in guard.EXPECTED_FAILED_NAMES
            if extra_pass and name == "R2_02 arrival focuses the heading not a raised keyboard and the question carries the meaning without a body":
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
        lines.append(json.dumps({"type": "done", "success": False, "time": 100}))
        return "\n".join(lines) + "\n"

    def _run(self, stream: str):
        fake = subprocess.CompletedProcess(args=["flutter"], returncode=1, stdout=stream, stderr="")
        with patch.object(guard, "_run_candidate_command", return_value=fake):
            guard.run_expected_red(ROOT, check_git=False)

    def test_classifier_accepts_the_sealed_red_stream(self) -> None:
        self._run(self._stream())  # positive control: the exact 2/13/0 shape

    def test_classifier_rejects_load_failure(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "failed to compile or load"):
            self._run(self._stream(load="error"))

    def test_classifier_rejects_missing_sentinel(self) -> None:
        name = "R2_09 selecting a commune announces the commune and its derived canton atomically as one node"
        with self.assertRaisesRegex(guard.GuardFailure, "exact named behavioural assertion"):
            self._run(self._stream(drop_sentinel=name))

    def test_classifier_rejects_harness_error_diagnostic(self) -> None:
        name = "R2_10 no match prompts a spelling check and reveals a help link that escalates to r3 in the no match state only"
        with self.assertRaisesRegex(guard.GuardFailure, "harness/runtime error"):
            self._run(self._stream(forbidden_on=name))

    def test_classifier_rejects_summary_drift(self) -> None:
        with self.assertRaisesRegex(guard.GuardFailure, "unexpected RED failures|test inventory drifted|error-event inventory"):
            self._run(self._stream(extra_pass=True))


if __name__ == "__main__":
    unittest.main()
