from __future__ import annotations

import ast
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_SHA = "fc1023fd73da8256acda8fbc438317ca391e7c74"
PROOF_NAME = "pillar3a-beneficiary-runtime-proof-fc1023fd7"
PROOF = ROOT / ".planning/runtime-evidence/phase-37/ret-ref-01" / PROOF_NAME
SCORECARD = (
    ROOT
    / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712"
    / "SCORECARD.md"
)
GAP_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"
TICKET_REGISTRY = (
    ROOT / ".planning/runtime-evidence/phase-37/ticket-evidence.json"
)

TRACKED_WRITER = (
    "apps/mobile/integration_test/"
    "g1_ret_ref_pillar3a_beneficiary_write_patrol_test.dart"
)
TRACKED_READER = (
    "apps/mobile/integration_test/"
    "g1_ret_ref_pillar3a_beneficiary_read_patrol_test.dart"
)
TRACKED_ORCHESTRATOR = (
    "tools/simulator/patrol_pillar3a_beneficiary_process_death.sh"
)

ARTIFACTS = {
    "README.md",
    "SHA256SUMS",
    "acquisition-summary.sanitized.json",
    "audit-dispositions.md",
    "audit-summary.sanitized.json",
    "github-ci-summary.sanitized.json",
    "maestro-summary.sanitized.json",
    "manifest.json",
    "metadata.sanitized.json",
    "patrol-suite-summary.sanitized.json",
    "quality-gate-scorecard.md",
    "recovery-dossier-pdf-summary.sanitized.json",
    "state-preservation-summary.sanitized.json",
}

BOUNDARY = {
    "activation": "NO-GO",
    "g1": "OPEN",
    "g1_score": "8.2/10",
    "g2": "FORBIDDEN",
    "g3": "FORBIDDEN",
    "pillar3a_beneficiary_atom": "GREEN",
    "production_default_off": True,
    "ret_ref": "ticket_only",
}


def _json(name: str) -> dict:
    return json.loads((PROOF / name).read_text(encoding="utf-8"))


def _git_show(path: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_SHA}:{path}"],
        text=True,
        capture_output=True,
        check=True,
    ).stdout


def _exact_runtime_expected_logs() -> list[str]:
    source = _git_show(TRACKED_ORCHESTRATOR)
    assignments = re.findall(
        r"^expected_logs = (\[.*?^\])$",
        source,
        flags=re.MULTILINE | re.DOTALL,
    )
    expected_lists = [ast.literal_eval(assignment) for assignment in assignments]
    assert len(expected_lists) == 2
    assert expected_lists[0] == expected_lists[1]
    assert all(isinstance(name, str) and name for name in expected_lists[0])
    return expected_lists[0]


def test_minimized_runtime_bundle_is_complete_and_bounded() -> None:
    assert PROOF.is_dir(), "TDD RED: exact 3a runtime proof bundle is missing"
    assert {path.name for path in PROOF.iterdir() if path.is_file()} == ARTIFACTS

    expected_output_count = len(_exact_runtime_expected_logs())
    assert expected_output_count == 26

    metadata = _json("metadata.sanitized.json")
    assert metadata == {
        "boundary": BOUNDARY,
        "cleanup_status": "passed",
        "distinct_process_pid_verified": True,
        "evidence_outputs_complete": True,
        "expected_output_count": expected_output_count,
        "production_build_install_passed": True,
        "production_default_off": {"after": True, "before": True},
        "production_reinstall_preserved_identity_and_state": True,
        "production_source_exported_exact": True,
        "production_source_physical": True,
        "pushed_sha_verified": True,
        "restoration_status": "restored",
        "retained_output_count": expected_output_count,
        "runtime_completed": True,
        "source_sha": SOURCE_SHA,
        "suite": {
            "reader": {"exit_code": 0, "failed": 0, "passed": 1},
            "writer": {"exit_code": 0, "failed": 0, "passed": 1},
        },
        "privacy": {
            "document_hash_retained": False,
            "private_fixture_used": False,
            "raw_document_bytes_retained": False,
            "simulator_identifier_retained": False,
            "synthetic_data_only": True,
            "xcresult_retained": False,
        },
        "writer_reader_build_isolation_verified": True,
    }

    patrol = _json("patrol-suite-summary.sanitized.json")
    assert patrol == {
        "assertion_trace": {
            "claim_basis": "tracked_contracts_plus_passing_exact_sha_runtime",
            "internal_assertions_exposed_by_xctest_output": False,
            "source_sha": SOURCE_SHA,
            "tracked_reader": TRACKED_READER,
            "tracked_writer": TRACKED_WRITER,
        },
        "boundary": BOUNDARY,
        "cold_reader": {"failed": 0, "passed": 1, "status": "PASS"},
        "contract": "g1_ret_ref_pillar3a_beneficiary",
        "native_writer": {"failed": 0, "passed": 1, "status": "PASS"},
        "status": "PASS",
    }

    maestro = _json("maestro-summary.sanitized.json")
    assert maestro == {
        "after": {
            "failures": 0,
            "production_default_off": True,
            "status": "SUCCESS",
            "tests": 1,
        },
        "before": {
            "failures": 0,
            "production_default_off": True,
            "status": "SUCCESS",
            "tests": 1,
        },
        "boundary": BOUNDARY,
    }

    github = _json("github-ci-summary.sanitized.json")
    assert github == {
        "boundary": BOUNDARY,
        "head_sha": SOURCE_SHA,
        "run_id": 29675502851,
        "status": "SUCCESS",
        "verified_gates": [
            "backend",
            "flutter_screens",
            "flutter_services",
            "flutter_widgets",
            "privacy",
            "repository_contracts",
            "vercel",
        ],
    }


def test_acquisition_recovery_dossier_and_pdf_claims_are_exact() -> None:
    acquisition = _json("acquisition-summary.sanitized.json")
    assert acquisition == {
        "boundary": BOUNDARY,
        "consent_purposes": ["visionExtraction", "transferUsAnthropic"],
        "durable_raw_document_material_absent": True,
        "external_document_io": "synthetic_in_process_adapter",
        "mutation_order": ["accept", "record"],
        "production_screens": [
            "RetirementDashboardScreen",
            "DocumentScanScreen",
            "ExtractionReviewScreen",
        ],
        "raw_document_vault_upload_attempted": False,
        "review_relation": "currentActiveUnpaid",
        "scan_session_purged_after_confirmation": True,
    }

    recovery = _json("recovery-dossier-pdf-summary.sanitized.json")
    assert recovery == {
        "boundary": BOUNDARY,
        "known_current_declared_handoff_visible": True,
        "network_forbidden_during_pdf_build": True,
        "pdf": {
            "builder": "PdfService.buildFinancialReportPdfBytes",
            "nontrivial_length_verified": True,
            "valid_document_header_verified": True,
        },
        "recovery_states_suppress_handoff": [
            "missingDocumentReference",
            "mismatchedDocumentReference",
            "invalidPresenceProvenance",
            "invalidRoot",
        ],
        "invalid_presence_reset_preserved_root_and_reference": True,
        "invalid_root_reset_durably_removed_root_and_reference": True,
        "report_route": "/rapport",
        "restored_handoff_visible": True,
    }

    state = _json("state-preservation-summary.sanitized.json")
    assert state == {
        "boundary": BOUNDARY,
        "cleanup_passed": True,
        "cold_reader_hydrated_exact_root_and_bnd": True,
        "production_reinstall_preserved_identity_and_state": True,
        "restoration_passed": True,
        "writer_reader_build_isolation_verified": True,
        "writer_reader_distinct_processes": True,
    }


def test_claims_are_traceable_to_exact_source_contracts() -> None:
    writer = _git_show(TRACKED_WRITER)
    for anchor in (
        "#retirement_pillar3a_beneficiary_insert_cta",
        "ConsentPurpose.visionExtraction",
        "ConsentPurpose.transferUsAnthropic",
        "expect(uploadAttempts, isEmpty, reason: 'raw PDF must never enter vault');",
        "expect(events, const <String>['accept', 'record']);",
        "expect(scanSessions.retainedSessionCount, 0);",
        "Pillar3aBeneficiaryRelation.currentActiveUnpaid",
        "expect(preferences.getInt(g1Pillar3aBeneficiaryWriterPidKey), pid);",
    ):
        assert anchor in writer, anchor

    reader = _git_show(TRACKED_READER)
    for anchor in (
        "if (writerPid == pid)",
        "await $.pumpWidgetAndSettle(const MintApp());",
        "testOnlyRootRouter.go('/rapport');",
        "Pillar3aBeneficiaryConsumerState.knownCurrentDeclared",
        "PdfService.buildFinancialReportPdfBytes(",
        "Pillar3aBeneficiaryReferenceResolution.missingDocumentReference",
        "Pillar3aBeneficiaryReferenceResolution.mismatchedDocumentReference",
        "Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance",
        "await documents.resetInvalidPillar3aBeneficiaryEvidence()",
        "expect(restoredAnswers, originalAnswers);",
        "reason: 'handoff reappears after exact restoration'",
    ):
        assert anchor in reader, anchor


def test_audit_lineage_closes_runtime_and_wrapper_gates_without_activation() -> None:
    audits = _json("audit-summary.sanitized.json")
    assert audits == {
        "boundary": BOUNDARY,
        "current_gate": {
            "aggregate_p0": 0,
            "aggregate_p1": 0,
            "verdict": "PASS_BOUNDED",
        },
        "final_delta_code": {
            "base_sha": "f20254a16",
            "p0": 0,
            "p1": 0,
            "p2": 0,
            "source_head": SOURCE_SHA,
            "verdict": "PASS",
        },
        "legal_cutoff_disposition": {
            "official_source_verified": True,
            "opp3_entry_into_force": "2027-06-01",
            "reform_decision_date": "2026-06-12",
            "status": "CLOSED",
        },
        "runtime_harness": {
            "code": {"p0": 0, "p1": 0, "p2": 2, "verdict": "PASS"},
            "product_domain": {
                "p0": 0,
                "p1": 1,
                "p2": 2,
                "verdict": "PASS_WITH_VERIFICATION_REQUEST",
            },
            "source_head": "f20254a16",
        },
        "wrapper_only": True,
    }


def test_manifest_checksums_and_global_state_are_exact() -> None:
    manifest = _json("manifest.json")
    assert manifest == {
        "artifact_allowlist": sorted(ARTIFACTS),
        "boundary": BOUNDARY,
        "logical_sources": [
            "accepted_exact_sha_runtime_metadata",
            "tracked_writer_and_reader_contracts_at_exact_sha",
            "github_clean_room_run_29675502851",
            "bounded_wrapper_audit_lineage",
        ],
        "privacy_policy": {
            "allowlist_only": True,
            "device_specific_evidence_retained": False,
            "private_fixture_data_retained": False,
            "raw_document_evidence_retained": False,
            "raw_runtime_output_retained": False,
        },
        "proof_name": PROOF_NAME,
        "source_sha": SOURCE_SHA,
    }

    checksum_entries: dict[str, str] = {}
    for line in (PROOF / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        digest, filename = line.split("  ", maxsplit=1)
        assert re.fullmatch(r"[0-9a-f]{64}", digest)
        checksum_entries[filename] = digest
    assert set(checksum_entries) == ARTIFACTS - {"SHA256SUMS"}
    for filename, digest in checksum_entries.items():
        assert hashlib.sha256((PROOF / filename).read_bytes()).hexdigest() == digest

    scorecard = SCORECARD.read_text(encoding="utf-8")
    matrix = GAP_MATRIX.read_text(encoding="utf-8")
    ledger = DATA_LEDGER.read_text(encoding="utf-8")
    screens = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    graph = WIRING_GRAPH.read_text(encoding="utf-8")
    combined = "\n".join((scorecard, matrix, ledger, screens, graph))
    for document in (scorecard, matrix, ledger, screens, graph):
        assert SOURCE_SHA in document
    assert PROOF_NAME in combined
    assert "exact 3a beneficiary" in combined
    assert "RET-REF remains `ticket_only`" in scorecard
    assert "G1 remains open at 8.2/10" in scorecard
    assert "G2/G3 remain forbidden" in scorecard

    pillar_row = next(
        line for line in matrix.splitlines() if line.startswith("| pillar3aBeneficiaryClause ")
    )
    assert " | live | " in pillar_row
    assert "exact_sha_native_runtime_fc1023fd7" in pillar_row
    assert "wrapper_runtime_audits" in pillar_row
    assert " | activation_decision | yes | G1-RET-REF-01 |" in pillar_row

    ticket_registry = json.loads(TICKET_REGISTRY.read_text(encoding="utf-8"))
    ticket = next(
        item
        for item in ticket_registry["tickets"]
        if item["ticket_id"] == "G1-RET-REF-01"
    )
    assert ticket["state"] == "ticket_only"
    assert ticket["accepted_sha"] is None


def test_bundle_contains_no_raw_or_device_specific_evidence() -> None:
    forbidden = (
        r"/Users/",
        r"/private/",
        r"/tmp/",
        r"\.xcresult\b",
        r"\.log\b",
        r"\.pdf\b",
        r"\.png\b",
        r"\.jpe?g\b",
        r"\.mov\b",
        r"\.mp4\b",
        r"\bUDID\b",
        r"device_sha256",
        r"document_sha",
        r"%PDF",
        r"test/golden",
    )
    for path in PROOF.iterdir():
        if not path.is_file() or path.name == "SHA256SUMS":
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in forbidden:
            assert re.search(pattern, text, flags=re.IGNORECASE) is None, (
                f"{path.name} contains forbidden pattern {pattern!r}"
            )
        assert re.search(r"\b[0-9a-f]{64}\b", text, flags=re.IGNORECASE) is None
