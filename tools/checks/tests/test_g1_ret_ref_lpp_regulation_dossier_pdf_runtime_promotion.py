from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_SHA = "274736a50bca659579fe26f68ae4e600469e3a9a"
PROOF = (
    ROOT
    / ".planning/runtime-evidence/phase-37/ret-ref-01"
    / "lpp-regulation-dossier-pdf-runtime-proof-274736a50"
)
SCORECARD = (
    ROOT
    / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712"
    / "SCORECARD.md"
)
GAP_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
TRACKED_READER = (
    "apps/mobile/integration_test/g1_ret_ref_lpp_regulation_read_patrol_test.dart"
)
TRACKED_DOSSIER_TEST = (
    "apps/mobile/test/screens/advisor/financial_report_lpp_regulation_handoff_test.dart"
)
TRACKED_PDF_TEST = "apps/mobile/test/services/lpp_regulation_handoff_pdf_test.dart"
PROOF_PATH = "phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/"

ARTIFACTS = {
    "README.md",
    "SHA256SUMS",
    "audit-dispositions.md",
    "audit-summary.sanitized.json",
    "dossier-pdf-summary.sanitized.json",
    "maestro-summary.sanitized.json",
    "manifest.json",
    "metadata.sanitized.json",
    "patrol-suite-summary.sanitized.json",
    "quality-gate-scorecard.md",
    "state-preservation-summary.sanitized.json",
}

BOUNDARY = {
    "activation": "NO-GO",
    "closed_gap": "pdf_dossier_caveat_parity",
    "dossier_pdf_slice": "GREEN",
    "g1": "OPEN",
    "g1_score": "8.2/10",
    "g2": "FORBIDDEN",
    "g3": "FORBIDDEN",
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


def test_dossier_pdf_runtime_bundle_is_complete_and_bounded() -> None:
    assert PROOF.is_dir(), "TDD RED: dossier/PDF runtime proof bundle is missing"
    assert {path.name for path in PROOF.iterdir() if path.is_file()} == ARTIFACTS

    metadata = _json("metadata.sanitized.json")
    assert metadata["source_sha"] == SOURCE_SHA
    assert metadata["boundary"] == BOUNDARY
    assert metadata["pushed_sha_verified"] is True
    assert metadata["runtime_completed"] is True
    assert metadata["evidence_outputs_complete"] is True
    assert metadata["expected_output_count"] == 22
    assert metadata["retained_output_count"] == 22
    assert metadata["suite"] == {"exit_code": 0, "failed": 0, "passed": 2}
    assert metadata["distinct_process_pid_verified"] is True
    assert metadata["patrol_full_isolation_zero_verified"] is True
    assert metadata["production_default_off"] == {"after": True, "before": True}
    assert metadata["cleanup_status"] == "passed"
    assert metadata["restoration_status"] == "restored"
    assert metadata["privacy"] == {
        "document_hash_retained": False,
        "private_fixture_used": False,
        "raw_document_bytes_retained": False,
        "simulator_identifier_retained": False,
        "synthetic_data_only": True,
        "xcresult_retained": False,
    }

    patrol = _json("patrol-suite-summary.sanitized.json")
    assert patrol == {
        "assertion_trace": {
            "internal_assertions_exposed_by_xctest_output": False,
            "source_sha": SOURCE_SHA,
            "tracked_reader": TRACKED_READER,
        },
        "boundary": BOUNDARY,
        "contract": "g1_ret_ref_lpp_regulation",
        "failed_tests": 0,
        "passed_tests": 2,
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


def test_dossier_and_pdf_claims_are_exact_and_traceable() -> None:
    summary = _json("dossier-pdf-summary.sanitized.json")
    assert summary["boundary"] == BOUNDARY
    assert summary["assertion_trace"] == {
        "claim_basis": "tracked_contracts_plus_passing_native_and_host_suites",
        "internal_assertions_exposed_by_xctest_output": False,
        "source_sha": SOURCE_SHA,
        "suite_failed_tests": 0,
        "suite_passed_tests": 2,
        "tracked_dossier_test": TRACKED_DOSSIER_TEST,
        "tracked_pdf_text_test": TRACKED_PDF_TEST,
        "tracked_reader": TRACKED_READER,
    }
    assert summary["dossier"] == {
        "handoff_section_identifier": "financial_report_lpp_regulation_handoff",
        "production_composition_root": "MintApp",
        "production_route": "/rapport",
        "recovery_states_suppress_handoff": [
            "legacyMissingFundRelationship",
            "mismatchedDocumentReference",
            "missingDocumentReference",
        ],
        "resolved_handoff_visible": True,
        "specialist_topics": [
            "buyback",
            "conversion",
            "flexibleRetirement",
            "disability",
            "survivors",
            "divorce",
        ],
    }
    assert summary["pdf"] == {
        "host_text_contract": {
            "forbidden_sensitive_tokens_absent": True,
            "null_handoff_section_absent": True,
            "ordered_allowlisted_content_present": True,
            "passed_tests": 3,
            "production_bytes_extracted_with_pdftotext": True,
            "status": "PASS",
        },
        "native_runtime": {
            "builder": "PdfService.buildFinancialReportPdfBytes",
            "nontrivial_length_verified": True,
            "valid_document_header_verified": True,
        },
        "share_sheet_or_external_app_proven": False,
    }
    assert summary["authority"] == {
        "financial_amounts_inferred": False,
        "fund_identity_objectively_proven": False,
        "fund_relationship_verification": "declared_unverified",
        "legal_applicability_inferred": False,
    }


def test_claims_exist_in_exact_source_contracts() -> None:
    reader = _git_show(TRACKED_READER)
    for anchor in (
        "await $.pumpWidgetAndSettle(const MintApp());",
        "await bootstrap.start();",
        "await provider.waitForReportAnswers();",
        "testOnlyRootRouter.go('/rapport');",
        "'financial_report_screen'",
        "'financial_report_lpp_regulation_handoff'",
        "LppRegulationSpecialistHandoff.tryFromEvidence(resolved)",
        "PdfService.buildFinancialReportPdfBytes(",
        "expect(pdfBytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);",
        "expect(pdfBytes.length, greaterThan(1000));",
        "LppRegulationReferenceResolution.missingDocumentReference",
        "LppRegulationReferenceResolution.mismatchedDocumentReference",
        "LppRegulationRecoveryReason.legacyMissingFundRelationship",
        "await ReportPersistenceService.saveLppEvidenceAnswers(originalAnswers);",
        "reason: 'temporary recovery states must restore the exact BND'",
    ):
        assert anchor in reader, anchor

    resolved_report = reader.index("await expectReport(hasHandoff: true);")
    pdf = reader.index("PdfService.buildFinancialReportPdfBytes(")
    missing = reader.index("LppRegulationReferenceResolution.missingDocumentReference")
    mismatch = reader.index(
        "LppRegulationReferenceResolution.mismatchedDocumentReference"
    )
    legacy = reader.index("LppRegulationRecoveryReason.legacyMissingFundRelationship")
    restored = reader.index(
        "await ReportPersistenceService.saveLppEvidenceAnswers(originalAnswers);"
    )
    assert resolved_report < pdf < missing < mismatch < legacy < restored

    dossier_test = _git_show(TRACKED_DOSSIER_TEST)
    for anchor in (
        "dossier renders exact typed handoff and six unanswered topics",
        "financial_report_lpp_regulation_handoff",
        "retirementLppRegulationHandoffBoundary",
        "retirementLppRegulationHandoffPrivacy",
        "dossier omits handoff section when typed authority is null",
    ):
        assert anchor in dossier_test, anchor

    pdf_test = _git_show(TRACKED_PDF_TEST)
    for anchor in (
        "real financial-report bytes contain one ordered safe LPP handoff",
        "Process.run(",
        "'pdftotext'",
        "final expectedInOrder = <String>[",
        "null handoff keeps a valid PDF with no regulation handoff copy",
        "share wrapper delegates byte construction and only shares bytes",
    ):
        assert anchor in pdf_test, anchor


def test_audit_lineage_records_passes_remediation_and_budget_refusal() -> None:
    audits = _json("audit-summary.sanitized.json")
    assert audits["boundary"] == BOUNDARY
    assert audits["dossier_wiring"] == {
        "code": {"p0": 0, "p1": 0, "p2": 3, "verdict": "PASS"},
        "product_domain": {
            "p0": 0,
            "p1": 1,
            "p2": 2,
            "verdict": "P1_FOUND",
        },
        "remediated_p1": "pdf_handoff_omission",
        "remediated_by": "9055cf47b",
        "source_sha": "0c12f9c84",
    }
    assert audits["pdf_export"] == {
        "code": {"p0": 0, "p1": 0, "p2": 2, "verdict": "PASS"},
        "product_domain": {
            "p0": 0,
            "p1": 0,
            "p2": 3,
            "verdict": "PASS",
        },
        "source_sha": "9055cf47b",
    }
    assert audits["runtime_delta"] == {
        "code": {
            "diff_budget_lines": 2500,
            "diff_prompt_lines": 2579,
            "verdict": "REFUSED_DIFF_BUDGET",
        },
        "full_diff_audited": False,
        "product_domain": {"verdict": "NOT_RUN"},
        "runtime_claim_basis": "executable_exact_sha_gates",
        "source_sha": "df217f8c0",
    }
    assert audits["bootstrap"] == {
        "code": {"p0": 0, "p1": 0, "p2": 1, "verdict": "PASS"},
        "product_domain": {
            "p0": 0,
            "p1": 0,
            "p2": 2,
            "verdict": "PASS",
        },
        "source_sha": "274736a50",
    }
    assert audits["current_gate"] == {
        "aggregate_p0": 0,
        "aggregate_p1": 0,
        "runtime_full_diff_audited": False,
        "verdict": "PASS_BOUNDED",
    }


def test_state_manifest_and_checksums_cover_only_the_allowlist() -> None:
    state = _json("state-preservation-summary.sanitized.json")
    assert state == {
        "boundary": BOUNDARY,
        "cleanup_passed": True,
        "post_suite_state_captured": True,
        "production_reinstall_preserved_identity_and_state": True,
        "required_runtime_state_present_after_final_maestro": True,
        "restoration_passed": True,
        "writer_reader_distinct_processes": True,
    }

    manifest = _json("manifest.json")
    assert manifest["source_sha"] == SOURCE_SHA
    assert manifest["boundary"] == BOUNDARY
    assert manifest["artifact_allowlist"] == sorted(ARTIFACTS)
    assert manifest["logical_sources"] == [
        "accepted_exact_sha_runtime_metadata",
        "accepted_sanitized_suite_and_maestro_summaries",
        "tracked_reader_contract_at_exact_sha",
        "tracked_dossier_and_pdf_text_contracts_at_exact_sha",
        "bounded_component_audit_lineage",
    ]
    assert manifest["privacy_policy"] == {
        "allowlist_only": True,
        "device_specific_evidence_retained": False,
        "private_fixture_data_retained": False,
        "raw_document_evidence_retained": False,
        "raw_runtime_output_retained": False,
    }

    checksum_lines = (PROOF / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    checksum_entries: dict[str, str] = {}
    for line in checksum_lines:
        digest, filename = line.split("  ", maxsplit=1)
        assert re.fullmatch(r"[0-9a-f]{64}", digest)
        checksum_entries[filename] = digest

    expected = ARTIFACTS - {"SHA256SUMS"}
    assert set(checksum_entries) == expected
    for filename, digest in checksum_entries.items():
        assert hashlib.sha256((PROOF / filename).read_bytes()).hexdigest() == digest


def test_global_g1_state_closes_only_pdf_dossier_caveat_parity() -> None:
    scorecard = re.sub(r"\s+", " ", SCORECARD.read_text(encoding="utf-8"))
    gap_matrix = re.sub(r"\s+", " ", GAP_MATRIX.read_text(encoding="utf-8"))

    for text in (scorecard, gap_matrix):
        assert SOURCE_SHA in text
        assert PROOF_PATH in text
        assert "PDF/dossier caveat parity is closed" in text
        assert "RET-REF remains `ticket_only`" in text
        assert "G1 remains open at 8.2/10" in text
        assert "G2/G3 remain forbidden" in text
        assert "activation" in text

    assert "dossier_pdf_parity_runtime_274736a50" in gap_matrix
    assert "pdf_dossier_caveat_parity" not in gap_matrix
    assert "activation_decision" in gap_matrix

    local_scorecard = (PROOF / "quality-gate-scorecard.md").read_text(encoding="utf-8")
    assert "**Dossier/PDF slice** | **10.0** | **9.6**" in local_scorecard
    assert "G1 | OPEN — 8.2/10" in local_scorecard
    assert "RET-REF | `ticket_only`" in local_scorecard
    assert "G2 / G3 | FORBIDDEN" in local_scorecard


def test_codex_contracts_record_the_same_bounded_promotion() -> None:
    paths = (
        "docs/codex/DATA_LEDGER.md",
        "docs/codex/DATA_QUEST.md",
        "docs/codex/SCREEN_CONTRACTS.md",
        "docs/codex/MAESTRO_FLOWS.md",
        "docs/codex/SPEC_REALITY_AUDIT_G1.md",
        "docs/codex/WIRING_GRAPH.mmd",
    )
    for path in paths:
        text = re.sub(r"\s+", " ", (ROOT / path).read_text(encoding="utf-8"))
        assert SOURCE_SHA in text, path
        assert PROOF_PATH in text, path
        assert "PDF/dossier caveat parity is closed" in text, path

    wiring = (ROOT / "docs/codex/WIRING_GRAPH.mmd").read_text(encoding="utf-8")
    for anchor in ("LRR_DOSSIER", "LRR_PDF", "LRR_DOSSIER_RUNTIME"):
        assert anchor in wiring
    assert "OPEN: PDF/dossier caveat parity" not in wiring


def test_bundle_contains_no_raw_or_device_specific_evidence() -> None:
    forbidden = (
        r"/Users/",
        r"/private/",
        r"/tmp/",
        r"\.xcresult\b",
        r"\.log\b",
        r"\.xml\b",
        r"\.pdf\b",
        r"\.png\b",
        r"\.jpe?g\b",
        r"\.mov\b",
        r"\.mp4\b",
        r"\bUDID\b",
        r"device_sha256",
        r"document_sha",
        r"%PDF",
        r"private fixture name",
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
