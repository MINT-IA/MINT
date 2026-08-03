from __future__ import annotations

import hashlib
import re
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.checks.mint_next_batch16_runtime_guard import (
    ACCEPTANCE,
    ANALYSIS_OPTIONS,
    DESIGN_LAB_LIB,
    DESIGN_LAB_PUBSPEC,
    GENERATED_SEMANTIC_FIXTURE,
    GUARD,
    GUARD_TESTS,
    LEFTHOOK,
    MANIFEST,
    NAVIGATION,
    OFFICIAL_SOURCES,
    PARENT_CONTRACT,
    SCOPE,
    SEMANTIC_FIXTURE,
    WIDGET_TEST,
    WORKFLOW,
    TRUST_HASHES,
    REVIEWED_PAYLOAD_FILES,
    RUNTIME_FILES,
    GuardFailure,
    _reviewed_payload_sha256,
    validate,
)


ROOT = Path(__file__).resolve().parents[3]
WRITTEN_CONTRACT_WORKFLOW = Path(".github/workflows/mint-next-batch16-runtime.yml")


class Batch16RuntimeGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for relative in (
            ACCEPTANCE,
            PARENT_CONTRACT,
            ANALYSIS_OPTIONS,
            DESIGN_LAB_PUBSPEC,
            MANIFEST,
            NAVIGATION,
            OFFICIAL_SOURCES,
            SCOPE,
            WIDGET_TEST,
            SEMANTIC_FIXTURE,
            GENERATED_SEMANTIC_FIXTURE,
            GUARD,
            GUARD_TESTS,
            LEFTHOOK,
            WORKFLOW,
            WRITTEN_CONTRACT_WORKFLOW,
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
            validate(self.root, require_accepted=False)

    def _rebind_trust_hash(self, relative: Path) -> None:
        workflow = self.root / WORKFLOW
        source = workflow.read_text()
        variables = [key for key, value in TRUST_HASHES.items() if value == relative]
        if variables:
            digest = hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
            source, count = re.subn(
                rf"(?m)^(\s*{re.escape(variables[0])}:\s*)[0-9a-f]{{64}}[ \t]*$",
                rf"\g<1>{digest}",
                source,
            )
            self.assertEqual(count, 1)
            workflow.write_text(source)
        if relative in (SCOPE, NAVIGATION):
            acceptance = self.root / ACCEPTANCE
            acceptance_data = yaml.safe_load(acceptance.read_text())
            digest_key = (
                "contract_sha256" if relative == SCOPE else "navigation_sha256"
            )
            acceptance_data["mechanical_binding"]["digest_binding"][digest_key] = (
                hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
            )
            acceptance.write_text(yaml.safe_dump(acceptance_data, sort_keys=False))
            written_workflow = self.root / WRITTEN_CONTRACT_WORKFLOW
            written_source = written_workflow.read_text()
            acceptance_digest = hashlib.sha256(acceptance.read_bytes()).hexdigest()
            written_source, count = re.subn(
                r"(?m)^(\s*EXPECTED_BATCH16_ACCEPTANCE_SHA256:\s*)"
                r"[0-9a-f]{64}[ \t]*$",
                rf"\g<1>{acceptance_digest}",
                written_source,
            )
            self.assertEqual(count, 1)
            written_workflow.write_text(written_source)
        if relative in REVIEWED_PAYLOAD_FILES:
            manifest = self.root / MANIFEST
            manifest_data = yaml.safe_load(manifest.read_text())
            if relative in RUNTIME_FILES:
                manifest_data["runtime_files_sha256"][str(relative)] = (
                    hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
                )
            receipts = manifest_data.get("roast_receipts", [])
            if receipts:
                payload_digest = _reviewed_payload_sha256(self.root)
                for receipt in receipts:
                    receipt["reviewed_payload_sha256"] = payload_digest
                manifest.write_text(yaml.safe_dump(manifest_data, sort_keys=False))
                source = workflow.read_text()
                manifest_digest = hashlib.sha256(manifest.read_bytes()).hexdigest()
                source, count = re.subn(
                    r"(?m)^(\s*EXPECTED_BATCH16C_GREEN_MANIFEST_SHA256:\s*)"
                    r"[0-9a-f]{64}[ \t]*$",
                    rf"\g<1>{manifest_digest}",
                    source,
                )
                self.assertEqual(count, 1)
                workflow.write_text(source)

    def test_current_accepted_contract_is_internally_coherent(self) -> None:
        validate(self.root)

    def test_candidate_cannot_masquerade_as_accepted(self) -> None:
        path, data = self._manifest()
        data["status"] = "candidate_hidden_runtime"
        data["acceptance_boundary"]["hidden_batch16_runtime"] = "candidate"
        del data["roast_receipts"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        fixture = self.root / SEMANTIC_FIXTURE
        fixture_data = yaml.safe_load(fixture.read_text())
        fixture_data["status"] = "candidate_for_swiss_roast"
        fixture.write_text(yaml.safe_dump(fixture_data, sort_keys=False))
        self._rebind_trust_hash(MANIFEST)
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "still a candidate"):
            validate(self.root)

    def test_missing_accepted_roast_receipt_is_rejected(self) -> None:
        path, data = self._manifest()
        data["roast_receipts"].pop()
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_trust_hash(MANIFEST)
        with self.assertRaisesRegex(GuardFailure, "receipt inventory"):
            validate(self.root)

    def test_nonzero_accepted_roast_receipt_is_rejected(self) -> None:
        path, data = self._manifest()
        data["roast_receipts"][0]["severity_counts"]["P2"] = 1
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_trust_hash(MANIFEST)
        with self.assertRaisesRegex(GuardFailure, "not unanimous zero"):
            validate(self.root)

    def test_rehashed_runtime_mutation_invalidates_roast_payload_receipts(self) -> None:
        relative = DESIGN_LAB_LIB / "design_lab_app.dart"
        runtime = self.root / relative
        runtime.write_text(runtime.read_text() + "\n// hostile reviewed-payload mutation\n")
        path, data = self._manifest()
        data["runtime_files_sha256"][str(relative)] = hashlib.sha256(
            runtime.read_bytes()
        ).hexdigest()
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._rebind_trust_hash(MANIFEST)
        with self.assertRaisesRegex(GuardFailure, "not unanimous zero"):
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

    def test_acceptance_and_proof_obligation_cannot_disappear_together(self) -> None:
        acceptance = self.root / ACCEPTANCE
        acceptance_data = yaml.safe_load(acceptance.read_text())
        del acceptance_data["mechanical_binding"]["runtime_hostile_mutations_planned"][
            "doubt_to_help_exact_origin"
        ]
        acceptance.write_text(yaml.safe_dump(acceptance_data, sort_keys=False))
        manifest, manifest_data = self._manifest()
        del manifest_data["proof_map"]["doubt_to_help_exact_origin"]
        manifest.write_text(yaml.safe_dump(manifest_data, sort_keys=False))
        self._rebind_trust_hash(MANIFEST)
        with self.assertRaisesRegex(
            GuardFailure, "accepted runtime roast receipt is not unanimous zero"
        ):
            validate(self.root, require_accepted=False)

    def test_scope_parent_contract_digest_must_match_real_file(self) -> None:
        path = self.root / PARENT_CONTRACT
        path.write_text(path.read_text() + "\n# unauthorized drift\n")
        with self.assertRaisesRegex(GuardFailure, "scope parent contract digest drifted"):
            validate(self.root, require_accepted=False)

    def test_public_entrypoint_cannot_promote_hidden_batch16_harness(self) -> None:
        main = self.root / DESIGN_LAB_LIB / "main.dart"
        main.write_text(
            main.read_text().replace(
                "MintNextDesignLabApp(", "MintNextDesignLabApp.batch16Harness("
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "main.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN hidden runtime promoted through public entrypoint"
        ):
            validate(self.root, require_accepted=False)

    def test_public_constructor_cannot_enable_hidden_batch16_harness(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        app.write_text(
            app.read_text().replace(
                "_enableBatch16Unresolved = false,",
                "_enableBatch16Unresolved = true,",
                1,
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN Batch16 flag dataflow drifted"
        ):
            validate(self.root, require_accepted=False)

    def test_batch14_constructor_cannot_enable_hidden_batch16_harness(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        source = app.read_text()
        public_boundary = source.index("const MintNextDesignLabApp.batch14Harness")
        target = source.index("_enableBatch16Unresolved = false,", public_boundary)
        source = source[:target] + source[target:].replace(
            "_enableBatch16Unresolved = false,",
            "_enableBatch16Unresolved = true,",
            1,
        )
        app.write_text(source)
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN Batch16 flag dataflow drifted"
        ):
            validate(self.root, require_accepted=False)

    def test_constructor_comment_decoy_cannot_enable_batch16(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        app.write_text(
            app.read_text().replace(
                "_enableBatch16Unresolved = false,",
                "// _enableBatch16Unresolved = false,\n"
                "       _enableBatch16Unresolved = !false,",
                1,
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(GuardFailure, "GREEN Batch16 flag dataflow drifted"):
            validate(self.root, require_accepted=False)

    def test_journey_flag_forwarding_cannot_force_batch16(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        app.write_text(
            app.read_text().replace(
                "enableBatch16Unresolved: _enableBatch16Unresolved,",
                "enableBatch16Unresolved: true,",
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(GuardFailure, "GREEN Batch16 flag dataflow drifted"):
            validate(self.root, require_accepted=False)

    def test_journey_flag_expression_cannot_promote_public_route(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        app.write_text(
            app.read_text().replace(
                "enableBatch16Unresolved: _enableBatch16Unresolved,",
                "enableBatch16Unresolved: _enableBatch16Unresolved || "
                "!_enableBatch14MultiProvider,",
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(GuardFailure, "GREEN Batch16 flag dataflow drifted"):
            validate(self.root, require_accepted=False)

    def test_editor_consumer_cannot_force_batch16_controls(self) -> None:
        editor = self.root / DESIGN_LAB_LIB / "multi_provider_amount_editor.dart"
        editor.write_text(
            editor.read_text().replace(
                "if (widget.enableBatch16) ...[", "if (true) ...["
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "multi_provider_amount_editor.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN Batch16 editor consumer dataflow drifted"
        ):
            validate(self.root, require_accepted=False)

    def test_editor_consumer_expression_cannot_promote_batch16(self) -> None:
        editor = self.root / DESIGN_LAB_LIB / "multi_provider_amount_editor.dart"
        editor.write_text(
            editor.read_text().replace(
                "if (widget.enableBatch16) ...[",
                "if (widget.enableBatch16 || true) ...[",
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "multi_provider_amount_editor.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN Batch16 editor consumer dataflow drifted"
        ):
            validate(self.root, require_accepted=False)

    def test_adjacent_operator_cannot_bypass_flag_line_inventory(self) -> None:
        app = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        source = app.read_text().replace(
            "_DesignNode.factContributedAmount =>\n"
            "                            widget.enableBatch14MultiProvider",
            "_DesignNode.factContributedAmount =>\n"
            "                            true ||\n"
            "                            widget.enableBatch14MultiProvider",
        )
        source = source.replace(
            "enableBatch16:\n"
            "                                          widget.enableBatch16Unresolved,",
            "enableBatch16:\n"
            "                                          true ||\n"
            "                                          widget.enableBatch16Unresolved,",
        )
        app.write_text(source)
        self._rebind_trust_hash(DESIGN_LAB_LIB / "design_lab_app.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN canonical Batch16 route source drifted"
        ):
            validate(self.root, require_accepted=False)

    def test_obfuscated_public_entrypoint_promotion_is_rejected(self) -> None:
        main = self.root / DESIGN_LAB_LIB / "main.dart"
        main.write_text(
            main.read_text().replace(
                "MintNextDesignLabApp(",
                "// MintNextDesignLabApp(\n  MintNextDesignLabApp /* bypass */ .batch16Harness(",
            )
        )
        self._rebind_trust_hash(DESIGN_LAB_LIB / "main.dart")
        with self.assertRaisesRegex(
            GuardFailure, "GREEN hidden runtime promoted through public entrypoint"
        ):
            validate(self.root, require_accepted=False)

    def test_new_unreviewed_runtime_wrapper_is_rejected(self) -> None:
        wrapper = self.root / DESIGN_LAB_LIB / "public_batch16.dart"
        wrapper.write_text(
            "import 'design_lab_app.dart';\n"
            "MintNextDesignLabApp publicApp() => "
            "const MintNextDesignLabApp.batch16Harness();\n"
        )
        with self.assertRaisesRegex(
            GuardFailure, "GREEN runtime library inventory drifted"
        ):
            validate(self.root, require_accepted=False)

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

    def test_wrong_green_status_is_rejected(self) -> None:
        path, data = self._manifest()
        data["status"] = "accepted_without_runtime_proof"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self._reject()

    def test_extra_or_missing_green_proof_is_rejected(self) -> None:
        path, data = self._manifest()
        data["green_proof_commands"].append("echo superficial")
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
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "six-locale coverage drifted"):
            validate(self.root, require_accepted=False)

    def test_replaced_semantic_intent_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        data["intents"]["genericNonsense"] = data["intents"].pop(
            "batch16ProviderConfirmedNetMeaning"
        )
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "Swiss semantic intent inventory drifted"):
            validate(self.root, require_accepted=False)

    def test_missing_intent_provenance_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        del data["intent_provenance"]["batch16ActuallyCreditedMeaning"]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(
            GuardFailure, "intent provenance does not cover the exact semantic inventory"
        ):
            validate(self.root, require_accepted=False)

    def test_unknown_official_source_link_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        data["intent_provenance"]["batch16AnnualOrdinaryTotalMeaning"][
            "source_ids"
        ] = ["unknown_blog"]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "intent source linkage invalid"):
            validate(self.root, require_accepted=False)

    def test_product_inference_masquerading_as_official_fact_is_rejected(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        del data["intent_provenance"]["batch16RefundVsAllZeroMeaning"][
            "classification"
        ]
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        self._reject()

    def test_stale_official_source_review_is_rejected(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["checked_at"] = "2025-12-31"
        data["retrieved_at"] = "2025-12-31T00:50:00+01:00"
        data["review_due_at"] = "2026-01-01"
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        fixture = self.root / SEMANTIC_FIXTURE
        fixture_data = yaml.safe_load(fixture.read_text())
        for key in ("checked_at", "retrieved_at", "review_due_at"):
            fixture_data["provenance"][key] = data[key]
        fixture.write_text(
            yaml.safe_dump(fixture_data, sort_keys=False, allow_unicode=True)
        )
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "review is stale"):
            validate(self.root, require_accepted=False)

    def test_future_dated_source_review_is_rejected_after_honest_rehash(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["checked_at"] = "2099-12-30"
        data["retrieved_at"] = "2099-12-30T00:50:00+02:00"
        data["review_due_at"] = "2099-12-31"
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        fixture = self.root / SEMANTIC_FIXTURE
        fixture_data = yaml.safe_load(fixture.read_text())
        fixture_data["provenance"]["checked_at"] = data["checked_at"]
        fixture_data["provenance"]["retrieved_at"] = data["retrieved_at"]
        fixture_data["provenance"]["review_due_at"] = data["review_due_at"]
        fixture.write_text(
            yaml.safe_dump(fixture_data, sort_keys=False, allow_unicode=True)
        )
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "future-dated"):
            validate(self.root, require_accepted=False)

    def test_unbounded_source_review_horizon_is_rejected_after_honest_rehash(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["review_due_at"] = "9999-12-31"
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        fixture = self.root / SEMANTIC_FIXTURE
        fixture_data = yaml.safe_load(fixture.read_text())
        fixture_data["provenance"]["review_due_at"] = data["review_due_at"]
        fixture.write_text(
            yaml.safe_dump(fixture_data, sort_keys=False, allow_unicode=True)
        )
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(GuardFailure, "horizon exceeds 180 days"):
            validate(self.root, require_accepted=False)

    def test_invalid_source_dates_are_rejected_after_honest_rehash(self) -> None:
        registry = self.root / OFFICIAL_SOURCES
        registry_data = yaml.safe_load(registry.read_text())
        registry_data["checked_at"] = "not-a-date"
        registry_data["retrieved_at"] = "not-a-timestamp"
        registry.write_text(
            yaml.safe_dump(registry_data, sort_keys=False, allow_unicode=True)
        )
        fixture = self.root / SEMANTIC_FIXTURE
        fixture_data = yaml.safe_load(fixture.read_text())
        fixture_data["provenance"]["checked_at"] = "not-a-date"
        fixture_data["provenance"]["retrieved_at"] = "not-a-timestamp"
        fixture.write_text(
            yaml.safe_dump(fixture_data, sort_keys=False, allow_unicode=True)
        )
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        self._reject()

    def test_removed_inference_boundary_is_rejected_after_honest_rehash(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["review_boundaries"][
            "product_safety_inferences_not_direct_official_quotes"
        ].remove(
            "a_full_refund_at_one_provider_does_not_prove_every_provider_is_zero"
        )
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        self._reject()

    def test_unwritten_details_control_is_rejected_after_honest_rehash(self) -> None:
        path = self.root / SCOPE
        source = path.read_text().replace(
            "    - unresolved_help_rules_disclosure\n", ""
        )
        path.write_text(source)
        self._rebind_trust_hash(SCOPE)
        with self.assertRaisesRegex(
            GuardFailure, "rules disclosure is absent from the written control inventory"
        ):
            validate(self.root, require_accepted=False)

    def test_missing_details_navigation_edge_is_rejected_after_honest_rehash(self) -> None:
        path = self.root / NAVIGATION
        path.write_text(
            path.read_text().replace(
                "  Help_Unresolved --> Help_Unresolved: Voir / masquer les règles\\naucune mutation; même origine\n",
                "",
            )
        )
        self._rebind_trust_hash(NAVIGATION)
        with self.assertRaisesRegex(GuardFailure, "written navigation edge absent"):
            validate(self.root, require_accepted=False)

    def test_non_official_source_domain_is_rejected(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["sources"][0]["url"] = "https://example.com/unreviewed"
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        with self.assertRaisesRegex(GuardFailure, "non-official source domain"):
            validate(self.root, require_accepted=False)

    def test_unversioned_official_source_is_rejected(self) -> None:
        path = self.root / OFFICIAL_SOURCES
        data = yaml.safe_load(path.read_text())
        data["sources"][0]["version"] = ""
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(OFFICIAL_SOURCES)
        with self.assertRaisesRegex(GuardFailure, "source metadata incomplete"):
            validate(self.root, require_accepted=False)

    def test_fixture_and_registry_dates_must_match(self) -> None:
        path = self.root / SEMANTIC_FIXTURE
        data = yaml.safe_load(path.read_text())
        data["provenance"]["checked_at"] = "2026-08-02"
        path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True))
        self._rebind_trust_hash(SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(
            GuardFailure, "semantic fixture provenance drifted from official registry"
        ):
            validate(self.root, require_accepted=False)

    def test_generated_semantic_fixture_drift_is_rejected(self) -> None:
        path = self.root / GENERATED_SEMANTIC_FIXTURE
        path.write_text(path.read_text().replace("MINT has not verified", "MINT verified"))
        self._rebind_trust_hash(GENERATED_SEMANTIC_FIXTURE)
        with self.assertRaisesRegex(
            GuardFailure, "generated Dart semantic fixture drifted from reviewed YAML"
        ):
            validate(self.root, require_accepted=False)

    def test_removed_lefthook_binding_is_rejected(self) -> None:
        path = self.root / LEFTHOOK
        path.write_text(
            path.read_text().replace(
                "mint-next-batch16-runtime-guard:",
                "mint-next-batch16-runtime-disabled:",
            )
        )
        self._reject()

    def test_removed_ci_command_is_rejected(self) -> None:
        path = self.root / WORKFLOW
        path.write_text(
            path.read_text().replace(
                "python3 tools/checks/mint_next_batch16_runtime_guard.py",
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
        path.write_text(path.read_text() + "\nanalyzer:\n  exclude:\n    - test/design_lab_batch16_unresolved_navigation_test.dart\n")
        self._reject()

    def test_direct_network_capability_in_isolated_runtime_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text("import 'dart:io';\n" + path.read_text())
        self._reject()

    def test_benign_runtime_source_drift_is_rejected(self) -> None:
        path = self.root / DESIGN_LAB_LIB / "design_lab_app.dart"
        path.write_text(path.read_text() + "\n")
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
